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

@enum LEVELS L1I L1D L2 L3
@enum HIERARCHY SETS0=1 WAYS0 SETS1 WAYS1 SETS2 WAYS2 SETS3 WAYS3    # arrays start at 1

#XXX Maybe formulate a small class around the datastructure H, for easier printing
# equality checks if necessary
struct H_T
    D::Dict{String, Any}
    H_T(H::NTuple{8,Int}) = new(
                                Dict("AMAT"=>nothing,
                                     "VAL"=>nothing,
                                     "H"=>H
                                    )
                               )
    H_T(AMAT::Float64, VAL::Float64, H::NTuple{8,Int}) = new(
                                                             Dict(
                                                                  "AMAT"=>AMAT, 
                                                                  "VAL"=>VAL, 
                                                                  "H"=>H
                                                                 )
                                                            )
end

@printf("[julia] Got %d args\n", length(ARGS))
for a in ARGS
    println("[julia] ", a)
end
@assert(length(ARGS) == 2, "Wrong usage!")

const pSIM = ARGS[1]
const pRES  = ARGS[2]

function comm_test()
    @printf("[julia] Sending requests to %s and receiving results from %s\n", pSIM, pRES)
    runs = 10
    for i=1:runs
        println("[julia] reading from pRES")
        #XXX read opens the pipe, reads until EOF, and closes it
        s = read(pRES, String)
        println("[julia] Done reading from pRES")
        #@printf("[julia] Got Yaml: %s\n", s)
        S = YAML.load(s)    # slow
        for i=1:0
            push!(S, S[1])
        end
        yS = YAML.write(S)
        @printf("[julia] Writing %d bytes to pSIM\n", length(yS))
        sleep(rand());
        wrote = write(pSIM, YAML.write(S))
        @printf("[julia] Done writing to pSIM. Wrote %d bytes.\n", wrote)
    end

    println("[julia] Done looping. Sending donezo")
    write(pSIM, "DONE")
    println("[julia] Donezo")
    return 0
end

function run_cachesim(S)
    # expects list of hierarchies
    s = YAML.write(S)
    #println(s)
    #@printf("[julia] sending '%s'\n", s)
    write(pSIM, s)
    r = read(pRES, String)
    R = YAML.load(r)
    for i in enumerate(S)
        @assert(S[i]["H"] == R[i]["H"], "Batch order got mixed up!")
    end
    return R
end

function solve()
    H0 = Dict("AMAT"=>nothing,
              "VAL"=>nothing,
              "H"=>[
                    64,
                    8,
                    64,
                    12,
                    256,
                    20,
                    1024,
                    8,
                ]
             )
    #FIXME: This does not modify Hmin, Hmax at all?
    Hmin = copy(H0)
    Hmin["H"][Int(SETS1)] /= 2
    Hmax = copy(H0)
    Hmax["H"][Int(SETS1)] *= 2
    P0 = [Hmin, Hmax]   # TODO how to add constraints

    Problems = [P0]
    Simulated = []

    while length(Problems) > 0
        P = pop!(Problems)
        #TODO pick direction (simulate fully associative/direct mapped pendant)
        #TODO split into new problems (add new constraints)
        #TODO find new Hmin, Hmax, H0
        batch = P
        R = run_cachesim(batch)
        append!(Simulated, R)
    end

    #TODO send DONE, read, and THEN send the final results..
    # Return all results
    s = YAML.write(Simulated)
    println(s)
    write(pSIM, s)
    return true
end

#@assert(comm_test() == 0, "comm_test failed?")
solve()

println("[julia] Exiting.")
