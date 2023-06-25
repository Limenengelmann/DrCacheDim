#!/usr/bin/julia
using YAML 
using Printf

#using LinearAlgebra
#using JuMP
#using Alpine
#using Ipopt
#
## NLP optimizer
#ipopt = optimizer_with_attributes(Ipopt.Optimizer,
#                                        MOI.Silent() => true,
#                                        "sb" => "yes",
#                                        "max_iter"   => 9999)
#
## Global optimizer
#alpine = optimizer_with_attributes(Alpine.Optimizer,
#                                         "nlp_solver" => ipopt)
#
#m = Model(alpine)

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
    return H[lvl]["cfg"]["size"] / H[lvl]["cfg"]["assoc"]
end

function set_sets(H, lvl, s)
    H[lvl]["cfg"]["size"] = s * H[lvl]["cfg"]["assoc"]
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

function solve()
    println("[julia] Reading H protype.")
    r = read(pRES, String)
    println("[julia] Parsing..")
    H = YAML.load(r)

    H0 = H

    Hmin = deepcopy(H0)
    set_sets(Hmin, L1D, get_sets(H0, L1D)/2)
    Hmax = deepcopy(H0)
    set_sets(Hmax, L1D, get_sets(H0, L1D)*2)
    P0 = [Hmin, Hmax]   # TODO how to add constraints
    #println(Hmin, Hmax)

    Problems = [P0]
    Simulated = []

    while length(Problems) > 0
        println("[julia] Checking new problem")
        P = pop!(Problems)
        #TODO pick direction (simulate fully associative/direct mapped pendant)
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
