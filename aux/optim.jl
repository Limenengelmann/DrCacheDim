#!/usr/bin/julia
using YAML 
using Printf

using LinearAlgebra
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

function print_problem(P)
    Hmin, Hmax, A, b = P
    println("[julia] Hmin, Hmax:")
    display(transpose(Matrix(hcat(get_vec.([Hmin, Hmax])...))))
    println("[julia] Constraints: A|b")
    display(Matrix(hcat(A, b)))
end

#XXX we assume 64 byte linesize
function get_sets(H, lvl)
    return Int(log2(H[lvl]["cfg"]["size"] / 64 / H[lvl]["cfg"]["assoc"]))
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
    for lvl in LEVELS
        append!(h, get_sets(H, lvl), get_ways(H, lvl))
    end
    return h
end

function set_vec!(H, h)
    #XXX set_ways first
    set_ways_and_sets!(H, L1I, h[WAYS0], h[SETS0])
    set_ways_and_sets!(H, L1D, h[WAYS1], h[SETS1])
    set_ways_and_sets!(H, L2, h[WAYS2], h[SETS2])
    set_ways_and_sets!(H, L3, h[WAYS3], h[SETS3])
end

function get_full_associativity(H)
    H_fa = deepcopy(H)
    for lvl in LEVELS
        w = get_sets(H_fa, lvl)*get_ways(H_fa, lvl)
        s = 1
        set_ways_and_sets!(H_fa, lvl, w, s)
    end
    return H_fa
end

function get_direct_mapped(H)
    H_dm = deepcopy(H)
    for lvl in LEVELS
        w = 1
        s = get_sets(H_dm, lvl)*get_ways(H_dm, lvl)
        set_ways_and_sets!(H_dm, lvl, w, s)
    end
    return H_dm
end

function run_cachesim(S)
    # expects list of hierarchies
    s = YAML.write(S)
    #println(s)
    #@printf("[julia] sending \n>%s<\n", s)
    #@printf("[julia] Writing to pSIM.\n")
    write(pSIM, s)
    #@printf("[julia] Reading from pRES.\n")
    r = read(pRES, String)
    #@printf("[julia] Read \n>%s<\n", r)
    #println("[julia] Parsing..")
    R = YAML.load(r)
    #println("[julia] Reading done.")
    #@printf("[julia] s:\n>%s<\nr:\n>%s<\n", s, r)
    @assert(length(S) == length(R), "Result length not equal to batch length!")
    #@printf("[julia] typeof(S): '%s', length: %d, typeof(R): '%s', length: %d\n", typeof(S), length(S), typeof(R), length(R))
    #println("[julia] S: $S\nR: $R")
    #println("[julia] S[1]: $S1\nR[1]: $R1}")
    #@assert(typeof(S) == typeof(R), "Types mismatch!")
    for (i,v) in enumerate(S)
        @assert(get_vec(S[i]) == get_vec(R[i]), "Batch order got mixed up!")
    end
    return R
end

function add_constraints!(M, h, Hmin, Hmax, A, b)
    #Base constraints
    hmin = get_vec(Hmin)
    hmax = get_vec(Hmax)
    @constraint(M, [i=1:length(hmin)], hmin[i] <= h[i] <= hmax[i])
    @constraint(M, h[SETS0] <= h[SETS1])
    @constraint(M, h[SETS1] <= h[SETS2])
    @constraint(M, h[SETS2] <= h[SETS3])

    if (length(b) > 0)
        @constraint(M, A*h .<= b)
    end
end

function get_new_min_max(Hcen, Hmin, Hmax, A_minus, b_minus, A_plus, b_plus)
    #TODO determine when we should not split further (maybe solution becomes infeasible?)
    hcen = get_vec(Hcen)
    hmin = get_vec(Hmin)
    hmax = get_vec(Hmax)

    Hmin_new = nothing
    Hmax_new = nothing

    if A_plus != nothing && b_plus != nothing
        #println(hmin)
        #println(hcen)
        #println(hmax)
        M = Model(HIGHS)
        #set_silent(M)
        @variable(M, h[i=1:length(hcen)], Int, start=hcen[i])
        add_constraints!(M, h, Hmin, Hmax, A_plus, b_plus)
        @objective(M, Min, sum(h))
        #set_start_value(h, hcen)
        #set_start_value(all_variables(M), hcen)
        optimize!(M)
        ts = termination_status(M)
        if(ts == OPTIMAL)
            hmin_new = value.(h)
            Hmin_new = deepcopy(Hcen)
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
                                                                      
    if A_minus != nothing && b_minus != nothing
        M = Model(HIGHS)
        #set_silent(M)
        @variable(M, h[i=1:length(hcen)], Int, start=hcen[i])
        add_constraints!(M, h, Hmin, Hmax, A_minus, b_minus)
        @objective(M, Max, sum(h))
        #set_start_value(h, hcen)
        #set_start_value(all_variables(M), hcen)
        optimize!(M)
        ts = termination_status(M)
        if(ts == OPTIMAL)
            hmax_new = value.(h)
            Hmax_new = deepcopy(Hcen)
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

function get_center(Hmin, Hmax, A, b)
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
    add_constraints!(M, h, Hmin, Hmax, A, b)

    #TODO calculate proper center of mass (max slack to constraints)
    @objective(M, Min, sum((h[i]- c[i])^2 for i in 1:length(c)))
    #set_start_value(h, hmin)
    #set_start_value(all_variables(M), hmin)
    optimize!(M)
    ts = termination_status(M)
    # Here the exact optimum is not necessary
    if(ts == OPTIMAL || ts == LOCALLY_SOLVED || ts == ALMOST_OPTIMAL)
        Hcen = deepcopy(Hmin)
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

function split(H, H_fa, H_dm, A, b)
    h = get_vec(H)
    h_fa = get_vec(H_fa)
    h_dm = get_vec(H_dm)
    A_minus, b_minus = nothing, nothing
    A_plus, b_plus = nothing, nothing

    #TODO proper split
    # Consider: 
    # - The present types of misses
    # - Which components can be moved actually (e.g. are not fixed by constraints)
    split_on = SETS1    #TODO proper split
    #split_on = rand(1:length(h))    #TODO proper split

    # constraint H_i[split_on] .<= H[split_on]
    a_minus = zeros(Int, 1, length(h))
    a_minus[split_on] = 1
    # check if the new constraint is redundant
    r = findfirst(all(A .== a_minus, dims=2))
    if r != nothing
        # Don't create a problem, if constraints stay the same
        # and ensure upper bounds only shrink
        if b[r[1]] > h[split_on]
            A_minus = copy(A)
            b_minus = copy(b)
            b_minus[r[1]] = h[split_on]
        end
    else
        A_minus = vcat(A, a_minus)
        b_minus = vcat(b, h[split_on])
    end

    # constraint H_i[split_on] .> H[split_on] <=> -H_i[split_on] .<= -H[split_on]-1
    a_plus = zeros(Int, 1, length(h))
    a_plus[split_on] = -1
    # check if the new constraint is redundant
    # and ensure lower bounds only grow
    r = findfirst(all(A .== a_plus, dims=2))
    if r != nothing
        if b[r[1]] < -h[split_on]-1
            A_plus = copy(A)
            b_plus = copy(b)
            b_plus[r[1]] = -h[split_on]-1
        end
    else
        A_plus = vcat(A, a_plus)
        b_plus = vcat(b, -h[split_on]-1)
    end

    return A_minus, b_minus, A_plus, b_plus
end

function solve()
    println("[julia] Reading H protype.")
    r = read(pRES, String)
    H0 = YAML.load(r)

    #XXX Maybe send Hmin, Hmax together with H0?
    Hmin = deepcopy(H0)
    #FIXME more realistic bounds
    set_vec!(Hmin, [4,1,4,1,4,1,4,1])
    Hmax = deepcopy(H0)
    #FIXME more realistic bounds
    #XXX number of sets are exponents
    set_vec!(Hmax, [16,16,16,16,16,20,16,64])
    # Define constraints as (A, b) s.t. A*h <= b
    A0 = zeros(Int, 0, 8)
    b0 = zeros(Int, 0, 1)
    P0 = [Hmin, Hmax, A0, b0]

    first_iter = true
    H0["VAL"]  = Inf
    Best_H     = H0
    Problems   = [P0]
    Simulated  = []
    max_iter = 20
    purged = 0

    #TODO Dont add the same constraints over and over
    #XXX Graceful termination on SIGINT seems impossible
    while length(Problems) > 0 && max_iter > 0
        println("[julia] Checking new problem")
        R = []
        P_cur = popfirst!(Problems)    # breadth first search
        Hmin_cur, Hmax_cur, A, b = P_cur
        # calculate lower bound
        #TODO get COST without simulating, e.g. add extra boolean field SIMULATE, which can be read by Optim.pm
        Hmin_cur, Hmax_cur = run_cachesim([Hmin_cur, Hmax_cur])

        #Some logging
        @printf("[julia] %d problems in queue. Checking:\n", length(Problems))
        print_problem(P_cur)

        #XXX: bound only correct if objective fun is the sum of cost and latency!
        Bound = Hmin_cur["COST"] + Hmax_cur["LAT"]
        if Bound >= Best_H["VAL"]
            # discard
            purged += 1
            println("[julia] Purged")
            continue
        end
        H_cen = first_iter ? H0 : get_center(Hmin_cur, Hmax_cur, A, b)
        first_iter = false
        H_cen, = run_cachesim([H_cen])
        if H_cen["VAL"] < Best_H["VAL"]
            Best_H = H_cen
        end
        println("[julia] Checked hierarchy:")
        display(transpose(get_vec(H_cen)))

        #TODO pick direction (simulate fully associative/direct mapped pendant)
        A_minus, b_minus, A_plus, b_plus = split(H_cen, H_cen, H_cen, A, b)
        Hmin_new, Hmax_new = get_new_min_max(H_cen, Hmin_cur, Hmax_cur, A_minus, b_minus, A_plus, b_plus)
        P_minus, P_plus = nothing, nothing
        if (Hmax_new != nothing && A_minus != nothing)
            P_minus = [Hmin_cur, Hmax_new, A_minus, b_minus]
            push!(Problems, P_minus)
        end
        if (Hmin_new != nothing && A_plus != nothing)
            P_plus = [Hmin_new, Hmax_cur, A_plus, b_plus]
            push!(Problems, P_plus)
        end

        println("[julia] Adding new problem[s]:")
        P_minus != nothing ? print_problem(P_minus) : ()
        P_plus != nothing ? print_problem(P_plus) : ()

        #TODO lookup table for hierarchies in Simulated (e.g. memoize run_cachesim)
        append!(Simulated, [Hmin_cur, H_cen, Hmax_cur])
        max_iter -= 1
    end
    #XXX push for Dicts, append for Lists of Dicts!
    push!(Simulated, Best_H)

    println("[julia] No more problems, sending DONE")
    println("[julia] Purged $purged subproblems")
    println("[julia] Checked hierarchies:")
    i=1
    while i<length(Simulated)-3
        display(transpose(Matrix(hcat(get_vec.(Simulated[i:i+2])...))))
        i+=3
    end
    println("[julia] Best hierarchy:")
    display(transpose(get_vec(Best_H)))

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
