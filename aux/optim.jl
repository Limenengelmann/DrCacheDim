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
@assert(length(ARGS) == 3, "Wrong usage!")

const pSIM = ARGS[1]
const pRES  = ARGS[2]
Base.MainInclude.include(ARGS[3])

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
    cost = (H["COST"] != nothing) ? round(H["COST"]) : 0
    lat = (H["LAT"] != nothing)   ? round(H["LAT"])  : 0
    val = (H["VAL"] != nothing)   ? round(H["VAL"])  : 0
    @printf("%2d %2d | %2d %2d | %2d %2d | %2d %2d | %9d %9d %9d\n", get_vec(H)..., cost, lat, val)
end
function print_hierarchy(H::Nothing)
    @printf("%2s %2s | %2s %2s | %2s %2s | %2s %2s | %9s %9s %9s\n", "x", "x", "x", "x", "x", "x", "x", "x", "x", "x", "x")
end

function print_hierarchy(S::Array)
    println("Sets are taken log2!")
    @printf("s0 w0   s1 w1   s2 w2   s3 w3 |      cost        lat        val\n")
    for H in S
        print_hierarchy(H)
    end
end

function print_constraints(b)
    if b == nothing
        @printf("% 3s % 3s | % 3s % 3s | % 3s % 3s | % 3s % 3s |\n", "x", "x", "x", "x", "x", "x", "x", "x")
        @printf("% 3s % 3s | % 3s % 3s | % 3s % 3s | % 3s % 3s |\n", "x", "x", "x", "x", "x", "x", "x", "x")
    else
        @printf("% 3d % 3d | % 3d % 3d | % 3d % 3d | % 3d % 3d |\n", b[1:2:end]...)
        @printf("% 3d % 3d | % 3d % 3d | % 3d % 3d | % 3d % 3d |\n", b[2:2:end]...)
    end
end

function print_problem(P)
    Hmin, Hmax, H_cen, _, b = P
    println("Hmin, H_cen, Hmax, [vec, COST, LAT, VAL]:")
    print_hierarchy(Hmin)
    print_hierarchy(H_cen)
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
    if P == nothing || H == nothing
        return false
    end
    Hmin, Hmax = P[1:2]
    if Hmin == nothing || Hmax == nothing
        return false
    end
    return prod(get_vec(Hmin) .<= get_vec(H) .<= get_vec(Hmax))
end

function run_cachesim!(batch)
    # expects list of hierarchies
    S = []
    ind = []
    for (i,H) in enumerate(batch)
        #TODO this does not work, since we copy most hierarchies
        if !(H["COST"] != nothing) || !(H["VAL"] != nothing) || !(H["LAT"] != nothing)
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
        fRES = open(pRES, "r")
        r = ""
        while (! eof(fRES))
            r = r * read(fRES, String)
        end
        close(fRES)
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

function sim_problems!(PList)
    batch = []
    for (i, P) in enumerate(PList)
        Hmin, Hmax, H_cen, H_fa, b = P
        #@assert((Hmin != nothing) && (Hmax != nothing) && (H_cen != nothing) && (H_fa != nothing), "Incomplete Problem found!")
        #@assert((Hmin != nothing) && (Hmax != nothing) && (H_cen != nothing), "Incomplete Problem found!")
        if sim_fa
            push!(batch, Hmin, Hmax, H_cen, H_fa)
        else
            push!(batch, Hmin, Hmax, H_cen)
        end
    end
    run_cachesim!(batch)
    i = 1
    while length(batch) > 0
        Hmin, Hmax, H_cen = popfirst!(batch), popfirst!(batch), popfirst!(batch)
        H_fa = nothing
        if sim_fa
            H_fa = popfirst!(batch)
        end
        PList[i][1:end-1] .= Hmin, Hmax, H_cen, H_fa
        i+=1
    end
end

function add_constraints!(M, h, b)
    #Base constraints
    @constraint(M, h[SETS0] <= h[SETS1])
    @constraint(M, h[SETS1] <= h[SETS2])
    @constraint(M, h[SETS2] <= h[SETS3])

    #Parameter bounds
    @constraint(M, A*h .<= b)
end

# sometimes Hmin and Hmax are much more accurate bounds, since b does not reflect our other constraints
# so we essentially use Hmin <= H <=  Hmax as bounds instead
function tighten_bounds!(Hmin, Hmax, b)
    if Hmin == nothing || Hmax == nothing || b == nothing
        return nothing
    end

    b[1:2:end] = -get_vec(Hmin)
    b[2:2:end] =  get_vec(Hmax)
    return b
end

#XXX approximation, correct would be to search for the smallest cost and the lowest latency hierarchy
#XXX but given the way we split and our constraints, we are still guaranteed the unique existence of this min and max
#XXX If that was not the case, we could add lexical ordering to the objective, to have a better approximation
function get_new_min_max(Hmin, Hmax, H_cen, b_minus, b_plus)
    hmin = get_vec(Hmin)    # unused
    hmax = get_vec(Hmax)    # unused
    hcen = get_vec(H_cen)

    Hmin_new = nothing
    Hmax_new = nothing

    if (b_plus != nothing)
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
            Hmin_new = clean_copy(H_cen)
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
                                                                      
    if (b_minus != nothing)
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
            Hmax_new = clean_copy(H_cen)
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
        H_cen = clean_copy(Hmin)
        set_vec!(H_cen, round.(value.(h)))
    else
        println(M)
        solution_summary(M)
        println(c)
        println(hmin)
        println(hmax)
        println(value.(h))
        H_cen = nothing
        @assert(false, "Could not find H_cen! '$ts'")
    end

    return H_cen
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
    #cap_m[1], cap_m[end] = cap_m[end], cap_m[1]
    #conf_m[1], conf_m[end] = conf_m[end], conf_m[1]

    #TODO this order is basically constant..
    #TODO maybe normalise differently, but how ?
    I_cap = sortperm(cap_m, rev=true)
    I_cap = I_cap .* 2 .- 1
    I_conf = sortperm(conf_m, rev=true)
    I_conf = I_conf .* 2
    
    append!(I_cap, I_conf)
    # zip both arrays into one list of length length(PARAMS)
    #return PARAMS[collect(Iterators.flatten(zip(I_conf, I_cap)))]
    return PARAMS[I_cap]
end

#TODO split not on constraint difference, but on HMIN HMAX diff, since both can be largely different!
#TODO split on the largest gap
function split(Hmin, Hmax, H, H_fa, b)
    hmin = get_vec(Hmin)
    hmax = get_vec(Hmax)
    h = get_vec(H)
    h_fa = get_vec(H_fa)
    #h_dm = get_vec(H_dm)    # unused
    b_minus, b_plus = copy(b), copy(b)
    found = false

    split_dirs = PARAMS
    if sim_fa 
        split_dirs = get_split_dirs(H, H_fa)
    else
        #split_dirs = shuffle(PARAMS)
        #split_dirs = [SETS1, SETS2, SETS3, WAYS1, WAYS2, WAYS3, SETS0, WAYS0]
        # greedy problem size split: find largest difference to split on (keeps problems roughly equal?
        #split_dirs = PARAMS[sortperm(hmax .- hmin, rev=true)]
        # greedy bound accuracy split: find smallest difference to split on
        split_dirs = PARAMS[sortperm(hmax .- hmin)]
        #split_dirs = PARAMS
    end
    #display(split_dirs)
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
            println("[julia] Split normally on $split_on")
        elseif d == 1
            # in case domain has width 1 (e.g. only 2 possibilities for param split_on)
            # we keep problem sizes equal
            found = true
            # constraints H_i[split_on] == b_lower
            b_u_new = -b_l
            # constraints H_i[split_on] == b_upper
            b_l_new = -b_u
            println("[julia] Split smartly on $split_on")
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
    #println("[julia] Start: \n$r")
    Start = YAML.load(r)
    Hmin, Hmax, H0 = Start[1:3]
    # for debugging
    H_opt = length(Start) > 3 ? Start[4] : nothing

    #jcfg params
    global lower_bound  = (lower_bound != nothing)  ? lower_bound  : default_bound
    global max_iter     = (max_iter != nothing)     ? max_iter     : 10
    global parallel_sim = (parallel_sim != nothing) ? parallel_sim : 1
    global sim_fa       = (sim_fa != nothing)       ? sim_fa       : false

    println("[julia] Start Hierarchy:")
    print_hierarchy(H0)
    println("[julia] Lower bound:")
    print_hierarchy(Hmin)
    println("[julia] Upper bound:")
    print_hierarchy(Hmax)
    if H_opt != nothing
        println("[julia] Optimum:")
        print_hierarchy(H_opt)
    end

    feasible = prod(get_vec(Hmax) .- get_vec(Hmin) .+ 1)
    println("[julia] Counting ca. $feasible feasible hierarchies! (Excluding base constraints)")

    # Define constraints as b s.t. A*h <= b, A is a global constant
    b0 = get_b(Hmin, Hmax)
    P0 = [Hmin, Hmax, H0, nothing, b0]

    if !(H0["VAL"] != nothing)
        H0["VAL"]  = Inf
    end

    first_iter   = true
    Best_H       = H0
    P_best       = P0
    Problems     = [P0]
    Simulated    = []
    iter         = 1
    purged       = 0
    P_buffer     = []

    #XXX Graceful termination on SIGINT seems impossible
    while length(Problems) > 0 && iter < max_iter
        println("-------------------------------------Starting Iter $iter-----------------------------------")
        @printf("[julia] Starting new iteration. %d problems and at most %d iterations left.\n", length(Problems), max_iter-iter)
        @printf("[julia] Current best:\n");
        print_hierarchy(Best_H)
        while length(P_buffer) < parallel_sim && length(Problems) > 0
            P_cur = popfirst!(Problems)
            Hmin_cur, Hmax_cur, H_cen, H_fa, b = P_cur
            H_cen = first_iter ? H0 : get_center(Hmin_cur, Hmax_cur, b)
            H_fa = sim_fa ? get_full_associativity(H_cen) : nothing
            first_iter = false
            P_cur[1:4] .= Hmin_cur, Hmax_cur, H_cen, H_fa
            push!(P_buffer, P_cur)    # breadth first search
        end

        #TODO lookup table for hierarchies in Simulated (e.g. memoize run_cachesim)
        sim_problems!(P_buffer)
        append!(Simulated, P_buffer)

        while length(P_buffer) > 0
            P_cur = popfirst!(P_buffer)
            # calculate lower bound
            Hmin_cur, Hmax_cur, H_cen, H_fa, b = P_cur
            if ! sim_fa
                H_fa = H_cen    # ignore H_fa, but give it some reasonable values so we don't spam have to check sim_fa everywhere
            end
            #Some logging & debugging
            if is_in_P(P_cur, H_opt)
                println("[julia] Current Problem: ******************************************************** contains optimum!")
            else
                println("[julia] Current Problem:")
            end
            print_problem(P_cur)

            batch = [Hmin_cur, Hmax_cur, H_cen, H_fa] # cannot assign directly to batch (run_cachesim replaces its elements)
            Vals = [Hmin_cur["VAL"], Hmax_cur["VAL"], H_cen["VAL"], H_fa["VAL"]]
            H_Best_P = batch[argmin(Vals)]

            if H_Best_P["VAL"] < Best_H["VAL"]
                #TODO: If H0 is invalid, it could stay the optimum
                println("[julia] vvvvv New optimum!")
                print_hierarchy(H_Best_P)
                println("[julia] ^^^^^ New optimum!")
                Best_H = H_Best_P
                P_best = P_cur
            end

            #XXX: bound only correct if objective fun is the sum of cost and latency!
            if lower_bound(Hmin_cur, Hmax_cur) >= Best_H["VAL"]
                # discard
                purged += 1
                println("[julia] Purged")
            else
                b_minus, b_plus = split(Hmin_cur, Hmax_cur, H_cen, H_fa, b)
                Hmin_new, Hmax_new = get_new_min_max(Hmin_cur, Hmax_cur, H_cen, b_minus, b_plus)
                tighten_bounds!(Hmin_cur, Hmax_new, b_minus)
                tighten_bounds!(Hmin_new, Hmax_cur, b_plus)

                println("[julia] Split into:")
                P_minus = [Hmin_cur, Hmax_new, nothing, nothing, b_minus]
                is_in_P(P_minus, H_opt) ? println("****Contains opt****") : ()
                print_problem(P_minus)

                P_plus = [Hmin_new, Hmax_cur, nothing, nothing, b_plus]
                is_in_P(P_plus, H_opt) ? println("****Contains opt****") : ()
                print_problem(P_plus)

                added = 0
                if ((Hmax_new != nothing) && (b_minus != nothing))
                    push!(Problems, P_minus)
                    added += 1
                end

                if ((Hmin_new != nothing) && (b_plus != nothing))
                    push!(Problems, P_plus)
                    added += 1
                end

                println("[julia] Added $added new problem[s].")
            end
        end
        iter += 1
    end
    #XXX push for Dicts, append for Lists of Dicts!
    push!(Simulated, P_best)
    Simulated_H = []
    for (i, P) in enumerate(Simulated)
        append!(Simulated_H, P[1:4])
    end
    push!(Simulated_H, Best_H)

    #TODO checked hierarchies printing seems weird, optimum sometimes not inside?
    println("[julia] Checked hierarchies:")
    for (i, P) in enumerate(Simulated)
        @printf("--------------------------Problem %d-----------------------------------------\n", i)
        print_problem(P)
    end
    #i=1
    #while i<=length(Simulated)-4
    #    @printf("-----------------------------Iter %d-----------------------------------------\n", round(i / 3)+1)
    #    print_hierarchy.(Simulated[i:i+2])
    #    i+=4    # skip fully associative run
    #end
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
    s = YAML.write(Simulated_H)
    #println("[julia] Sending results: >$s<")
    println("[julia] Sending results.")
    write(pSIM, s)
    println("[julia] Finished.")
    return true
end

solve()

println("[julia] Exiting.")
