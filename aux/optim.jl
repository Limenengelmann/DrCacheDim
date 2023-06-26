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
    Hmin_new = deepcopy(Hcen)
    Hmax_new = deepcopy(Hcen)

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
        set_vec!(Hmin_new, hmin_new)
    elseif(ts == INFEASIBLE)
        Hmin_new = nothing 
    else
        println(M)
        solution_summary(M)
        @assert(false, "Unexpected termination status '$ts' while searching Hmin!")
    end
    #println(Hmax_new)
                                                                      
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
        set_vec!(Hmax_new, hmax_new)
    elseif(ts == INFEASIBLE)
        Hmax_new = nothing 
    else
        println(M)
        solution_summary(M)
        @assert(false, "Unexpected termination status '$ts' while searching Hmax!")
    end
    #println(Hmin_new)

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

    split_on = SETS1    #TODO proper split

    # constraint H_i[split_on] .<= H[split_on]
    A_minus = vcat(A, zeros(1, length(h)))
    A_minus[end, split_on] = 1
    b_minus = vcat(b, h[split_on])

    # constraint H_i[split_on] .> H[split_on] <=> -H_i[split_on] .<= -H[split_on]-1
    A_plus = vcat(A, zeros(1, length(h)))
    A_plus[end, split_on] = -1
    b_plus = vcat(b, -h[split_on]-1)

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
    A0 = []
    b0 = []
    P0 = [Hmin, Hmax, A0, b0]

    first_iter = true
    H0["VAL"]  = Inf
    Best_H     = H0
    Problems   = [P0]
    Simulated  = []

    #TODO Dont add the same constraints over and over
    #TODO Graceful termination on SIGINT
    while length(Problems) > 0
        println("[julia] Checking new problem")
        Hmin_cur, Hmax_cur, A, b = popfirst!(Problems)    # breadth first search
        # calculate lower bound
        #TODO get COST without simulating, e.g. add extra boolean field SIMULATE, which can be read by Optim.pm
        R = run_cachesim([Hmin_cur, Hmax_cur])
        Hmin_cur, Hmax_cur = R
        #XXX: bound only correct if objective fun is the sum of cost and latency!
        Bound = Hmin_cur["COST"] + Hmax_cur["LAT"]
        #Some logging
        @printf("%d problems in queue. Checking:\n", length(Problems))
        hmin_cur = get_vec(Hmin_cur)
        hmax_cur = get_vec(Hmax_cur)
        display(vcat(hmin_cur', hmax_cur'))
        display(Matrix(hcat(A, b)))
        if Bound >= Best_H["VAL"]
            # discard
            println("Purged")
            continue
        end
        H = first_iter ? H0 : get_center(Hmin_cur, Hmax_cur, A, b)
        first_iter = false
        append!(R, run_cachesim([H]))
        H = R[end]

        if H["VAL"] < Best_H["VAL"]
            Best_H = H
        end
        #TODO pick direction (simulate fully associative/direct mapped pendant)
        A_minus, b_minus, A_plus, b_plus = split(H, H, H, A, b)
        Hmin_new, Hmax_new = get_new_min_max(H, Hmin_cur, Hmax_cur, A_minus, b_minus, A_plus, b_plus)
        if (Hmax_new != nothing)
            push!(Problems, [Hmin_cur, Hmax_new, A_minus, b_minus])
        end
        if (Hmin_new != nothing)
            push!(Problems, [Hmin_new, Hmax_cur, A_plus, b_plus])
        end

        #TODO lookup table for hierarchies in Simulated (e.g. memoize run_cachesim)
        append!(Simulated, R)
    end

    append!(Simulated, Best_H)

    println("[julia] No more problems, sending DONE")
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
