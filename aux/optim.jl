#!/usr/bin/julia
using YAML 
using Printf
using LinearAlgebra
using Random

using JuMP
using Juniper
using Alpine
using Ipopt
using HiGHS
using Pavito
using AmplNLWriter, Bonmin_jll

@printf("[julia] Got %d args\n", length(ARGS))
for a in ARGS
    println("[julia] ", a)
end
@assert(length(ARGS) == 2, "Wrong usage!")

const pSIM = ARGS[1]
const pRES  = ARGS[2]

const L1I = "L1I"
const L1D = "L1D"
const L2 = "L2"
const L3 = "L3"
const LEVELS = [L1I L1D L2 L3]
const SETS0 = 1 
const WAYS0 = 2
const SETS1 = 3
const WAYS1 = 4
const SETS2 = 5
const WAYS2 = 6
const SETS3 = 7
const WAYS3 = 8
const PARAMS = [SETS0 WAYS0 SETS1 WAYS1 SETS2 WAYS2 SETS3 WAYS3]
# constraint matrix A*h <= b
const A = zeros(2*length(PARAMS), length(PARAMS))
for p in PARAMS
    A[2*p-1, p] = -1
    A[2*p, p] = 1
end

#JuMP Optimizers
const IPOPT = MOI.OptimizerWithAttributes(
    Ipopt.Optimizer,
    MOI.Silent() => true,
    #"sb" => "yes",
    "max_iter" => 9999,
)

const HIGHS = MOI.OptimizerWithAttributes(
    HiGHS.Optimizer,
    "presolve" => "on",
    "log_to_console" => false,
    MOI.Silent() => true,
    # "small_matrix_value" => 1e-12,
    # "allow_unbounded_or_infeasible" => true,
)

const JUNIPER = MOI.OptimizerWithAttributes(
    Juniper.Optimizer,
    MOI.Silent() => true,
    "feasibility_pump" => true,
    "mip_solver" => HIGHS,
    "nl_solver" => IPOPT,
)

const PAVITO = MOI.OptimizerWithAttributes(
    Pavito.Optimizer,
    MOI.Silent() => true,
    "mip_solver" => HIGHS,
    "cont_solver" => IPOPT,
    "mip_solver_drives" => false,
)

const BONMIN = AmplNLWriter.Optimizer(Bonmin_jll.amplexe)

##############################################################

function print_hierarchy(H::Dict)
    cost = H["COST"] == nothing ? 0 : round(H["COST"])
    lat = H["LAT"] == nothing ? 0 : round(H["LAT"])
    val = H["VAL"] == nothing ? 0 : round(H["VAL"])
    @printf("%2d %2d | %2d %2d | %2d %2d | %2d %2d | %9d %9d %9d\n", get_vec(H)..., cost, lat, val)
end

function print_hierarchy(S::Array)
    println("Sets are taken log2!")
    @printf("s0 w0   s1 w1   s2 w2   s3 w3 |      cost        lat        val\n")
    for H in S
        print_hierarchy(H)
    end
end

function print_constraints(b)
    @printf("% 3d % 3d | % 3d % 3d | % 3d % 3d | % 3d % 3d |\n", b[1:2:end]...)
    @printf("% 3d % 3d | % 3d % 3d | % 3d % 3d | % 3d % 3d |\n", b[2:2:end]...)
end

function print_problem(P)
    Hmin, Hmax, b = P
    println("Hmin, Hmax [vec, COST, LAT, VAL]:")
    print_hierarchy(Hmin)
    print_hierarchy(Hmax)
    println("Constraints: -h <= -b_l & h <= b_u")
    print_constraints(b)
end

#NOTE we assume 64 byte linesize
function get_sets(H, lvl)
    s = nothing
    try
        s = Int(log2(H[lvl]["cfg"]["size"] / 64 / H[lvl]["cfg"]["assoc"]))
    catch
        error("Inexact exact error on get_sets $lvl")
    end
    return s
end

function get_ways(H, lvl)
    return Int(H[lvl]["cfg"]["assoc"])
end

function set_ways_and_sets!(H, lvl, w, s)
    # only set sets and ways, since sets depends on the correct associativity
    @assert(w > 0, "Cannot have assoc 0!")
    H[lvl]["cfg"]["assoc"] = Int(w)
    @assert(0 <= s && s < 64, "s must be between 0 and 64 [2^0 <= sets <= 2^63]")
    size = 2^s * w * 64
    @assert(size > 0, "Cannot have size 0!")
    H[lvl]["cfg"]["size"] = Int(size)
end

function get_vec(H)
    h = Int[]
    append!(h, get_sets(H, L1I), get_ways(H, L1I))
    append!(h, get_sets(H, L1D), get_ways(H, L1D))
    append!(h, get_sets(H, L2 ), get_ways(H, L2 ))
    append!(h, get_sets(H, L3 ), get_ways(H, L3 ))
    return h
end

function clean_copy(H)
    H_ = deepcopy(H)
    # Reset Cost Val and Lat, since H_ will mostly represent a different hierarchy
    H_["COST"], H_["VAL"], H_["LAT"] = nothing, nothing, nothing
    return H_
end

function set_vec!(H, h)
    set_ways_and_sets!(H, L1I, h[WAYS0], h[SETS0])
    set_ways_and_sets!(H, L1D, h[WAYS1], h[SETS1])
    set_ways_and_sets!(H, L2, h[WAYS2], h[SETS2])
    set_ways_and_sets!(H, L3, h[WAYS3], h[SETS3])
end

function get_full_associativity(H)
    H_fa = clean_copy(H)
    for lvl in LEVELS
        w = get_sets(H_fa, lvl)*get_ways(H_fa, lvl)
        s = 1
        set_ways_and_sets!(H_fa, lvl, w, s)
    end
    return H_fa
end

function get_direct_mapped(H)
    H_dm = clean_copy(H)
    for lvl in LEVELS
        w = 1
        s = get_sets(H_dm, lvl)*get_ways(H_dm, lvl)
        set_ways_and_sets!(H_dm, lvl, w, s)
    end
    return H_dm
end

function get_b(Hmin, Hmax)
    hmax = get_vec(Hmax)
    hmin = get_vec(Hmin)
    b = zeros(2*length(hmax), 1)
    # A*h <= b
    for p in PARAMS
        b[2*p-1] = -hmin[p]
        b[2*p] = hmax[p]
    end
    return b
end

function get_lower_upper_b(b, param)
    @assert(param in PARAMS, "param not in PARAMS!")
    return b[2*param-1], b[2*param]
end

function set_lower_upper_b!(b, param, b_l, b_u)
    @assert(param in PARAMS, "param not in PARAMS!")
    b[2*param-1] = b_l
    b[2*param] = b_u
end

function get_problem_size(P)
    #TODO
end

function is_in_P(P, H)
    Hmin, Hmax, b = P
    return prod(get_vec(Hmin) .<= get_vec(H) .<= get_vec(Hmax))
end

function run_cachesim!(batch)
    # expects list of hierarchies
    S = []
    ind = []
    for (i,H) in enumerate(batch)
        #TODO this does not work, since we copy most hierarchies
        if H["COST"] == nothing || H["VAL"] == nothing || H["LAT"] == nothing
            push!(S, H)
            push!(ind, i)
        end
    end
    @printf("[julia] Writing %d/%d hierarchies to pSIM.\n", length(S), length(batch))
    #println("Before:")
    #print_hierarchy(batch)

    #TODO why does this influence the amount of splits
    #S = batch
    #ind = 1:length(batch)
    if length(S) > 0
        s = YAML.write(S)
        #println(s)
        #@printf("[julia] sending \n>%s<\n", s)
        write(pSIM, s)
        #@printf("[julia] Reading from pRES.\n")
        r = read(pRES, String)
        #@printf("[julia] Read \n>%s<\n", r)
        #println("[julia] Parsing..")
        R = YAML.load(r)
        #println("[julia] Reading done.")
        #@printf("[julia] s:\n>%s<\nr:\n>%s<\n", s, r)
        @assert(length(S) == length(R), "Got less results than requested!")
        #@printf("[julia] typeof(S): '%s', length: %d, typeof(R): '%s', length: %d\n", typeof(S), length(S), typeof(R), length(R))
        #println("[julia] S: $S\nR: $R")
        #println("[julia] S[1]: $S1\nR[1]: $R1}")
        #@assert(typeof(S) == typeof(R), "Types mismatch!")
        for (i,v) in enumerate(S)
            @assert(get_vec(S[i]) == get_vec(R[i]), "Batch order got mixed up!")
        end

        batch[ind] = R
    end
    #println("After:")
    #print_hierarchy(batch)
    return batch
end

function add_constraints!(M, h, b)
    #Base constraints
    @constraint(M, h[SETS0] <= h[SETS1])
    @constraint(M, h[SETS1] <= h[SETS2])
    @constraint(M, h[SETS2] <= h[SETS3])

    #Parameter bounds
    @constraint(M, A*h .<= b)
end

function get_new_min_max(Hcen, Hmin, Hmax, b_minus, b_plus)
    #TODO determine when we should not split further (maybe solution becomes infeasible?)
    hcen = get_vec(Hcen)
    hmin = get_vec(Hmin)    # unused
    hmax = get_vec(Hmax)    # unused

    Hmin_new = nothing
    Hmax_new = nothing

    if b_plus != nothing
        M = Model(HIGHS)
        #M = Model(() -> BONMIN)
        #set_silent(M)
        @variable(M, h[i=1:length(hcen)], Int, start=hcen[i])
        add_constraints!(M, h, b_plus)
        @objective(M, Min, sum(h))
        #set_start_value(h, hcen)
        #set_start_value(all_variables(M), hcen)
        optimize!(M)
        ts = termination_status(M)
        if(ts == OPTIMAL)
            hmin_new = value.(h)
            Hmin_new = clean_copy(Hcen)
            set_vec!(Hmin_new, hmin_new)
        elseif ts == INFEASIBLE
            Hmin_new = nothing
        else
            Hmin_new = nothing
            println(M)
            solution_summary(M)
            @assert(false, "Unexpected termination status '$ts' while searching Hmin!")
        end
    end
    #println(Hmax_new)
                                                                      
    if b_minus != nothing
        M = Model(HIGHS)
        #set_silent(M)
        @variable(M, h[i=1:length(hcen)], Int, start=hcen[i])
        add_constraints!(M, h, b_minus)
        @objective(M, Max, sum(h))
        #set_start_value(h, hcen)
        #set_start_value(all_variables(M), hcen)
        optimize!(M)
        ts = termination_status(M)
        if(ts == OPTIMAL)
            hmax_new = value.(h)
            Hmax_new = clean_copy(Hcen)
            set_vec!(Hmax_new, hmax_new)
        elseif ts == INFEASIBLE
            Hmax_new = nothing
        else
            Hmax_new = nothing
            println(M)
            solution_summary(M)
            @assert(false, "Unexpected termination status '$ts' while searching Hmax!")
        end
        #println(Hmin_new)
    end

    return Hmin_new, Hmax_new
end

function get_center(Hmin, Hmax, b)
    hmin = get_vec(Hmin)
    hmax = get_vec(Hmax)
    c = (hmax .+ hmin)./2

    #M = Model(
    #    optimizer_with_attributes(
    #        Pavito.Optimizer,
    #        #"nlp_solver" => IPOPT,
    #        "cont_solver" => IPOPT,
    #        "mip_solver" => HIGHS,
    #    ),
    #)
    #M = Model(
    #      optimizer_with_attributes(
    #        Juniper.Optimizer,
    #        "nl_solver" => IPOPT,
    #        "mip_solver" => HIGHS,
    #       ),
    #)
    #M = Model(optimizer_with_attributes(Juniper.Optimizer, "nl_solver"=>ipopt))
    #M = Model(() -> AmplNLWriter.Optimizer(Bonmin_jll.amplexe))
    M = Model(JUNIPER)
    #set_silent(M)
    @variable(M, h[i=1:length(hmin)], Int, start=round(c[i]))
    add_constraints!(M, h, b)

    #TODO calculate proper center of mass (maximize slack to constraints)
    @objective(M, Min, sum((h[i]- c[i])^2 for i in 1:length(c)))
    optimize!(M)
    ts = termination_status(M)
    # Here the exact optimum is not necessary
    if(ts == OPTIMAL || ts == LOCALLY_SOLVED || ts == ALMOST_OPTIMAL)
        Hcen = clean_copy(Hmin)
        set_vec!(Hcen, round.(value.(h)))
    else
        println(M)
        solution_summary(M)
        println(c)
        println(hmin)
        println(hmax)
        println(value.(h))
        Hcen = nothing
        @assert(false, "Could not find H_cen! '$ts'")
    end

    return Hcen
end

function get_split_dirs(H, H_fa)
    # analyse misses in H and suggest split directions accordingly
    all_m  = [0,0,0,0]  # all misses
    comp_m = [0,0,0,0]  # compulsory misses
    cap_m  = [0,0,0,0]  # capacity misses
    conf_m = [0,0,0,0]  # conflict misses
    for (i, lvl) in enumerate(LEVELS)
        all_m[i]  = H[lvl]["stats"]["Misses"]
        comp_m[i] = H[lvl]["stats"]["Compulsory misses"]
        conf_m[i] = all_m[i] - H_fa[lvl]["stats"]["Misses"]
        cap_m[i] = all_m[i] - comp_m[i] - conf_m[i]
    end
    
    cap_m  = cap_m ./ all_m
    conf_m  = conf_m ./ all_m
    
    # sort prio: L1D > L2 > L3 > L1I, SETS > WAYS (e.g. cap_m > conf_m)
    # switch L1I and L3 prio
    # TODO this swap is useless rn
    cap_m[1], cap_m[end] = cap_m[end], cap_m[1]
    conf_m[1], conf_m[end] = conf_m[end], conf_m[1]

    #TODO this order is basically constant..
    #TODO maybe normalise differently, but how ?
    I_cap = sortperm(cap_m)
    I_cap = I_cap .* 2 .- 1
    I_conf = sortperm(conf_m)
    I_conf = I_conf .* 2
    
    append!(I_cap, I_conf)
    # zip both arrays into one list of length length(PARAMS)
    #return PARAMS[collect(Iterators.flatten(zip(I_conf, I_cap)))]
    return PARAMS[I_cap]
end

function split(H, H_fa, b)
    h = get_vec(H)
    h_fa = get_vec(H_fa)
    #h_dm = get_vec(H_dm)    # unused
    b_minus, b_plus = copy(b), copy(b)
    found = false

    #TODO get_split_dirs could also be hardcoded because it never really changes order
    split_dirs = [WAYS1, SETS1]
    split_dirs = PARAMS
    split_dirs = shuffle(PARAMS)
    split_dirs = get_split_dirs(H, H_fa)
    display(split_dirs)
    for split_on in split_dirs
        h_s = h[split_on]
        b_l, b_u = get_lower_upper_b(b, split_on)
        d = b_u + b_l   # "width" of problem in direction split_on (b_l is negative)
        b_l_new, b_u_new = nothing, nothing
        if d >= 2
            # normal split on H_cen[split_on]
            # the assert doesn't make sense for H0
            #@assert(b_l < h_s < b_u, "Unexpected H_cen while splitting!")
            found = true
            # constraint H_i[split_on] <= H[split_on]
            b_u_new = h_s
            # constraint H_i[split_on] > H[split_on] <=> -H_i[split_on] <= -H[split_on]-1
            b_l_new = -h_s-1
        elseif d == 1
            # in case domain has width 1 (e.g. only 2 possibilities for param split_on)
            # we keep problem sizes equal
            found = true
            # constraints H_i[split_on] == b_lower
            b_u_new = -b_l
            # constraints H_i[split_on] == b_upper
            b_l_new = -b_u
        end
        if found
            # d == 0 -> cannot split further in this direction!
            set_lower_upper_b!(b_minus, split_on, b_l, b_u_new)
            set_lower_upper_b!(b_plus, split_on, b_l_new, b_u)
            break
        end
    end
    return found ? [b_minus, b_plus] : [nothing, nothing]
end

function default_bound(Hmin, Hmax)
    return Hmin["COST"] + Hmax["LAT"]
end

function lat_limit_bound(Hmin, Hmax)
    limit = 100000
    lat = Hmax["LAT"] > limit ? Inf : Hmax["LAT"]
    return Hmin["COST"] + lat
end

#TODO if initial value is better than any feasible value, an infeasible opt is returned
function solve()
    println("[julia] Reading Start Hierarchy")
    r = read(pRES, String)
    H0 = YAML.load(r)

    #XXX Maybe send Hmin, Hmax together with H0?
    Hmin = clean_copy(H0)
    real_lower = [6, 8, 6, 2, 9, 4, 11, 8]
    set_vec!(Hmin, real_lower)
    Hmax = clean_copy(H0)
    #XXX number of sets are exponents
    #Upper Bounds:
    real_upper = [6, 8, 9, 16, 10, 20, 14, 64]
    set_vec!(Hmax, real_upper)
    # Solution (for testing)
    H_opt = clean_copy(H0)
    #set_vec!(H_opt, [6, 8, 6, 16, 10, 16, 12, 32])
    set_vec!(H_opt, [6, 8, 6, 16, 10, 16, 12, 64])

    bound = default_bound

    println("[julia] Start Hierarchy:")
    print_hierarchy(H0)
    println("[julia] Lower bound:")
    print_hierarchy(Hmin)
    println("[julia] Upper bound:")
    print_hierarchy(Hmax)
    feasible = prod(real_upper .- real_lower .+ 1)
    println("[julia] Counting ca. $feasible feasible hierarchies! (Excluding base constraints)")

    # Define constraints as b s.t. A*h <= b, A is a global constant
    b0 = get_b(Hmin, Hmax)
    P0 = [Hmin, Hmax, b0]


    first_iter = true
    #H0["VAL"]  = Inf
    Best_H     = H0
    Problems   = [P0]
    Simulated  = []
    max_iter = 1000
    iter = 1
    purged = 0

    #XXX Graceful termination on SIGINT seems impossible
    while length(Problems) > 0 && iter < max_iter
        println("-------------------------------------Starting Iter $iter-----------------------------------")
        @printf("[julia] Starting new iteration. %d problems and at most %d iterations left.\n", length(Problems), max_iter-iter)
        R = []
        P_cur = popfirst!(Problems)    # breadth first search
        Hmin_cur, Hmax_cur, b = P_cur
        # calculate lower bound

        H_cen = first_iter ? H0 : get_center(Hmin_cur, Hmax_cur, b)
        H_fa = get_full_associativity(H_cen)
        first_iter = false
        #TODO get COST without simulating, e.g. add extra boolean field SIMULATE, which can be read by Optim.pm
        Hmin_cur, H_cen, Hmax_cur, H_fa = run_cachesim!([Hmin_cur, H_cen, Hmax_cur, H_fa])
        batch = [Hmin_cur, H_cen, Hmax_cur, H_fa] # cannot assign directly to batch (run_cachesim replaces its elements)

        #Some logging
        if is_in_P(P_cur, H_opt)
            println("[julia] Current Problem: ******************************************************** contains optimum!")
        else
            println("[julia] Current Problem:")
        end
        print_problem(P_cur)
        println("[julia] Current H center:")
        print_hierarchy(H_cen)

        Vals = [Hmin_cur["VAL"], H_cen["VAL"], Hmax_cur["VAL"]]
        H_Best_P = batch[argmin(Vals)]

        if H_Best_P["VAL"] < Best_H["VAL"]
            #TODO: If H0 is invalid, it could stay the optimum
            print_hierarchy(H_Best_P)
            println("[julia] ^^^^^ New optimum!")
            Best_H = H_Best_P
        end

        #XXX: bound only correct if objective fun is the sum of cost and latency!
        if bound(Hmin_cur, Hmax_cur) >= Best_H["VAL"]
            # discard
            purged += 1
            println("[julia] Purged")
        else

            b_minus, b_plus = split(H_cen, H_fa, b)
            Hmin_new, Hmax_new = get_new_min_max(H_cen, Hmin_cur, Hmax_cur, b_minus, b_plus)
            P_minus, P_plus = nothing, nothing
            if (Hmax_new != nothing && b_minus != nothing)
                P_minus = [Hmin_cur, Hmax_new, b_minus]
                push!(Problems, P_minus)
            end
            if (Hmin_new != nothing && b_plus != nothing)
                P_plus = [Hmin_new, Hmax_cur, b_plus]
                push!(Problems, P_plus)
            end

            println("[julia] Adding new problem[s]:")
            if P_minus != nothing
                is_in_P(P_minus, H_opt) ? println("****Contains opt****") : ()
                print_problem(P_minus)
            end
            if P_plus != nothing
                is_in_P(P_plus, H_opt) ? println("****Contains opt****") : ()
                print_problem(P_plus)
            end

            #TODO lookup table for hierarchies in Simulated (e.g. memoize run_cachesim)
            append!(Simulated, batch)
        end
        iter += 1
    end
    #XXX push for Dicts, append for Lists of Dicts!
    push!(Simulated, Best_H)

    #TODO checked hierarchies printing seems weird, optimum sometimes not inside?
    println("[julia] Checked hierarchies:")
    i=1
    while i<length(Simulated)-3
        @printf("-----------------------------Iter %d-----------------------------------------\n", round(i / 3)+1)
        print_hierarchy.(Simulated[i:i+2])
        i+=4    # skip fully associative run
    end
    println("[julia] Best hierarchy:")
    print_hierarchy(Best_H)
    @printf("[julia] Exited loop with %d queued problems after %d/%d iters.\n", length(Problems), iter, max_iter)
    println("[julia] Purged $purged subproblems")
    println("[julia] Sending DONE")
    #send DONE, read to sync, and THEN send the final results..
    write(pSIM, "DONE")
    println("[julia] Waiting for returned DONE...")
    r = read(pRES, String)
    @assert(r == "DONE", "Expected 'DONE', got >$r< instead!")
    # Return all results
    s = YAML.write(Simulated)
    #println("[julia] Sending results: >$s<")
    println("[julia] Sending results.")
    write(pSIM, s)
    println("[julia] Finished.")
    return true
end

solve()

println("[julia] Exiting.")
