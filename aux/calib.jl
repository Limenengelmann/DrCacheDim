import YAML 
using LinearAlgebra
using Printf

using JuMP
import Ipopt 
import Alpine

#XXX: CHANGEME
cd("/home/elimtob/Workspace/mymemtrace")
SIMF = "results/keep/imagick_r_1000.yml"
SIMF = "results/keep/cachetest_1000.yml"
LOCAL = "results/keep/cachetest_local.yml"
scaleAMAT = 1e-3

LVLS = ["L1I", "L1D", "L2", "L3"]
header = ("L1Isets", "L1Iassoc", "L1Dsets", "L1Dassoc", "L2sets", "L2assoc", "L3sets", "L3assoc", "AMAT")
# Indices for code readability

s1I = 1; a1I = 2;
s1D = 3; a1D = 4;
s2  = 5; a2  = 6;
s3  = 7; a3  = 8;
amat = 9;

data = YAML.load_file(SIMF)
local_hierarchy = YAML.load_file(LOCAL);
#c_sol = [512, 8, 64, 12, 1024, 20, 16384, 8, 480000*scaleAMAT]
c_sol = []
for lvl in LVLS
    local a = local_hierarchy[1][lvl]["cfg"]["assoc"]
    local s = local_hierarchy[1][lvl]["cfg"]["size"] / 64 / a # sets
    push!(c_sol, s, a)
end
push!(c_sol, local_hierarchy[1]["AMAT"]*scaleAMAT)
println(c_sol)

C = Matrix{Real}(undef,  length(header), length(data))

i = 1
for d in data
    global i
	c = Real[]
	for lvl in LVLS
		local a = d[lvl]["cfg"]["assoc"]
		local s = d[lvl]["cfg"]["size"] / 64 / a # sets
		push!(c, s, a)
	end
	push!(c, d["AMAT"]*scaleAMAT)
	#println(c)
    #set correct simulated AMAT if the target configuration is within the simulated params 
    #if norm(c[1:end-1] - c_sol[1:end-1]) < 1e-6
    #    c_sol[amat] = c[amat];
    #end
	C[:,i] = c; i+=1
end

#C
#c_sol .- C[:,1:end]

#data[1]["L1I"]

print("-------------------------------------------------------------------------")

calibrate = Model(Ipopt.Optimizer)

set_silent(calibrate)

#w0 = ones(length(header))
#w0 = zeros(length(header))
#w0 = rand(length(header))*9
w0 = [1000, 2000, 1000, 2000, 100, 200, 10, 20, 1]
#w0 = [1,2,3,4,5,6,7,8,1]

@variable(calibrate, w[i=1:length(header)] >= 0.1, start=w0[i])

@constraint(calibrate, w[amat] == 1) # weights relative to latency weight

@constraint(calibrate, [i=s1I:2:s3], w[i] <= w[i+1]) # sets < assoc (wrt. cost)

@constraint(calibrate, 1000 >= w[s1I] >= 100)
@constraint(calibrate, 1000 >= w[s1D] >= 100)
@constraint(calibrate, 100  >= w[s2]  >= 10 )
@constraint(calibrate, 10   >= w[s3]  >= 1  )
@constraint(calibrate, 2000 >= w[a1I] >= 200)
@constraint(calibrate, 2000 >= w[a1D] >= 200)
@constraint(calibrate, 200  >= w[a2]  >= 20 )
@constraint(calibrate, 20   >= w[a3]  >= 2  )
#@constraint(calibrate, w[a3]  <= 20)
#A = [1 0 0 0 -1  0  0  0 0
#	 0 0 1 0 -1  0  0  0 0
#     0 0 0 0  1  0 -1  0 0
#	 0 1 0 0  0 -1  0  0 0
#	 0 0 0 1  0 -1  0  0 0
#	 0 0 0 0  0  1  0 -1 0]
#@constraint(calibrate, A*w .>= 0) #

#sum(C, dims = 2)

z = vec(size(C, 2) * c_sol - sum(C, dims=2))

#dot(1:9,z)

f(w...) = begin
    res = 0
    for c in eachcol(C)
        wc = dot(w, c_sol - c)
        wc = wc >= 0 ? wc + 1 : wc
        res += wc
    end
    return res
end

#f(1,2,3,4,5,6,7,8,9)

g(w...) = dot(w,z)

register(calibrate, :f, length(header), f, autodiff = true)
register(calibrate, :g, length(header), g, autodiff = true)

#@NLexpression(calibrate, Min, f(w...))
@NLexpression(calibrate, Min, g(w...))
#@objective(calibrate, Min, dot(w,z))

optimize!(calibrate)
print(calibrate)
solution_summary(calibrate, verbose=true)

W = value.(w)
println(typeof(W), size(W))
println(typeof(z), size(z))
@printf("Objective value: %f\nResults:\n", g(W...));
for (i,h) in enumerate(header)
    @printf("%10s: %.2f\n", h, W[i])
end

@printf("Optimal cache in '%s':\n", SIMF)
best = argmin(C' * W)
for (i,h) in enumerate(header)
    @printf("%10s: %.2f\n", h, C[i, best])
end
