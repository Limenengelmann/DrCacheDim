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

@enum LVLS L1I L1D L2 L3
@enum HRCH s0=1 w0 s1 w1 s2 w2 s3 w3    # arrays start at 1

function run_cachesim()
    return 0
end

@printf("[julia] Got %d args\n", length(ARGS))
for a in ARGS
    println("[julia] ", a)
end
@assert(length(ARGS) == 2, "Wrong usage!")

pSIM = ARGS[1]
pRES  = ARGS[2]

@printf("[julia] Sending requests to %s and receiving results from %s\n", pSIM, pRES)
runs = 10
for i=1:runs
    println("[julia] reading from pRES")
    s = read(pRES, String)
    println("[julia] Done reading from pRES")
    #@printf("[julia] Got Yaml: %s\n", s)
    S = YAML.load(s)    # soooo slow
    for i=1:10000
        push!(S, S[1])
    end
    println("[julia] writing to pSIM")
    #TODO random sleep
    sleep(0.3);
    write(pSIM, YAML.write(S))
    println("[julia] Done writing to pSIM")
end

println("[julia] Done looping. Sending donezo")
write(pSIM, "DONE")
println("[julia] Donezo")

bla = (1,2,3,4,5,6,7,8,9)
for h in instances(HRCH)
    @printf("[julia] %s: %d -> %d\n", h, Int(h), bla[Int(h)])
end
println("[julia] Exiting")
