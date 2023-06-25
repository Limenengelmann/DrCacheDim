#!/usr/bin/julia
using YAML 
using Printf

using LinearAlgebra
using JuMP
using Alpine
using Ipopt
using HiGHS

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

function get_sets(H, lvl)
    return Int(log2(H[lvl]["cfg"]["size"] / H[lvl]["cfg"]["assoc"]))
end

function set_sets(H, lvl, s)
    H[lvl]["cfg"]["size"] = 2^s * H[lvl]["cfg"]["assoc"]
end

function get_ways(H, lvl)
    return H[lvl]["cfg"]["assoc"]
end

function set_ways(H, lvl, w)
    H[lvl]["cfg"]["assoc"] = w
end

function get_vec(H)
    h = []
    for lvl in LEVELS
        append!(h, get_sets(H, lvl), get_ways(H, lvl))
    end
    return h
end

function set_vec(H, h)
    set_sets(H, L1I, h[SETS0])
    set_ways(H, L1I, h[WAYS0])
    set_sets(H, L1D, h[SETS1])
    set_ways(H, L1D, h[WAYS1])
    set_sets(H, L2, h[SETS2])
    set_ways(H, L2, h[WAYS2])
    set_sets(H, L3, h[SETS3])
    set_ways(H, L3, h[WAYS3])
end

function get_full_associativity(H)
    H_fa = deepcopy(H)
    for lvl in LEVELS
        set_ways(H_fa, lvl, get_sets(H_fa, lvl)*get_ways(H_fa, lvl))
        set_sets(H_fa, lvl, 1)
    end
    return H_fa
end

function get_direct_mapped(H)
    H_dm = deepcopy(H)
    for lvl in LEVELS
        set_sets(H_dm, lvl, get_sets(H_dm, lvl)*get_ways(H_dm, lvl))
        set_ways(H_dm, lvl, 1)
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

function new_model(H0, Hmin, Hmax)
    h0 = get_vec(H0)
    hmin = get_vec(Hmin)
    hmax = get_vec(Hmax)
    # NLP optimizer
    #ipopt = optimizer_with_attributes(Ipopt.Optimizer,
    #                                    MOI.Silent() => true,
    #                                    "sb" => "yes",
    #                                    "max_iter"   => 9999)

    ## Global optimizer
    #alpine = optimizer_with_attributes(Alpine.Optimizer,
    #                                     "nlp_solver" => ipopt)

    M = Model(HiGHS.Optimizer)
    #set_silent(M)
    @variable(M, h[i=1:length(h0)], Int, start=h0[i])
    # base constraints
    @constraint(M, [i=1:length(h0)], hmin[i] <= h[i] <= hmax[i])
    @constraint(M, h[SETS0] <= h[SETS1])
    @constraint(M, h[SETS1] <= h[SETS2])
    @constraint(M, h[SETS2] <= h[SETS3])
    return M, h
end

function split(H, H_fa, H_dm)
    #TODO simulate fully associative, direct mapped pendant to H
    h = get_vec(H)
    A = zeros(Int, 1, length(h))
    # constraint H_i[SETS1] .>= H[SETS1]
    A[SETS1] = 1
    b = h[SETS1]    # TODO
    return A, b
end

function solve()
    println("[julia] Reading H protype.")
    r = read(pRES, String)
    H0 = YAML.load(r)

    Hmin = deepcopy(H0)
    #FIXME realistic bounds
    set_vec(Hmin, [4,1,4,1,4,1,4,1])
    Hmax = deepcopy(H0)
    #FIXME realistic bounds
    set_vec(Hmax, [2^29,16,2^29,16,2^29,16,2^29,16])
    # Define constraints as (A, b) s.t. A*h <= b
    P0 = [Hmin, Hmax, [], []]   # TODO how to add constraints

    Problems = [P0]
    Simulated = []

    while length(Problems) > 0
        println("[julia] Checking new problem")
        h_min, h_max, A, b = popfirst!(Problems) #TODO FIFO
        #TODO pick direction (simulate fully associative/direct mapped pendant)

        M, h = new_model(H0, Hmin, Hmax)
        @objective(M, Max, sum(h))
        optimize!(M)
        @assert(termination_status(M) == OPTIMAL, "Could not find H_max")
        solution_summary(M)
        Hmax_new = value.(h)
        #println(Hmax_new)

        M, h = new_model(H0, Hmin, Hmax)
        @objective(M, Min, sum(h))
        optimize!(M)
        @assert(termination_status(M) == OPTIMAL, "Could not find H_min")
        solution_summary(M)
        Hmin_new = value.(h)
        #println(Hmin_new)

        A_new, b_new = split(H, H, H)

        #TODO split into new problems (add new constraints)
        #TODO find new Hmin, Hmax, H0
        batch = []
        #TODO only run problems, that have not been simulated yet (maybe use some lookup table)
        append!(batch, P)
        R = run_cachesim(batch)
        append!(Simulated, R)
    end

    println("[julia] No more problems, sending DONE")
    #send DONE, read to sync, and THEN send the final results..
    write(pSIM, "DONE")
    println("[julia] Waiting for returned DONE...")
    r = read(pRES, String)
    @assert(r == "DONE", "Expected 'DONE', got >$r< instead!");
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
