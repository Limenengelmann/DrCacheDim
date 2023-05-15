import YAML; using JuMP; import Ipopt; using LinearAlgebra; import Alpine

cd("/home/elimtob/Workspace/mymemtrace");

LVLS = ["L1I", "L1D", "L2", "L3"]

#TODO load from sqlite instead, this is too slow
data = YAML.load_file("results/keep/imagick_r_test_sim_4000.yml")

scaleAMAT = 1e-3

c_sol = [512, 8, 64, 12, 1024, 20, 16384, 8, 480000*scaleAMAT]

header = ("L1Isets", "L1Iassoc", "L1Dsets", "L1Dassoc", "L2sets", "L2assoc", "L3sets", "L3assoc", "AMAT")

C = Matrix{Real}(undef,  length(header), length(data))

i = 1

for d in data
    global i
	c = Real[]
	for lvl in LVLS
		local a = d[lvl]["cfg"]["assoc"]
		local s = d[lvl]["cfg"]["size"] / 64 / a # sets = size/64/assoc
		push!(c, s, a)
	end
	push!(c, d["AMAT"]*scaleAMAT)
	#println(c)
    #set correct simulated AMAT if the target configuration is within the simulated params 
    if norm(c[1:end-1] - c_sol[1:end-1]) < 1e-6
        c_sol[end] = c[end];
    end
	C[:,i] = c; i+=1
end
println(c_sol)

#C
#c_sol .- C[:,1:end]

#data[1]["L1I"]

print("-------------------------------------------------------------------------")

calibrate = Model(Ipopt.Optimizer)

set_silent(calibrate)

#w0 = ones(length(header))
#w0 = zeros(length(header))
w0 = rand(length(header))*9
#w0 = [1,2,3,4,5,6,7,8,1]

@variable(calibrate, w[i=1:length(header)] >= 0.1, start=w0[i])

@constraint(calibrate, w[9] == 1) # weights relative to latency weight

@constraint(calibrate, [i=1:2:7], w[i] <= w[i+1]) # sets < assoc (wrt. cost)

A = [1 0 0 0 -1  0  0  0 0
	 0 0 1 0 -1  0  0  0 0
     0 0 0 0  1  0 -1  0 0
	 0 1 0 0  0 -1  0  0 0
	 0 0 0 1  0 -1  0  0 0
	 0 0 0 0  0  1  0 -1 0]

@constraint(calibrate, A*w .>= 0) #

#sum(C, dims = 2)

z = size(C, 2) * c_sol - sum(C, dims=2)

dot(1:9,z)

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

println(value.(w))

println(f(value.(w)...))	#objective value
