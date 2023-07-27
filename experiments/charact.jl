#lower_bound = function (Hmin, Hmax) return Inf; end
#lower_bound = function(Hmin, Hmax) return Hmin["LAMBDA"]*Hmin["CSCALE"]*Hmin["COST"] + (1-Hmin["LAMBDA"])*Hmax["MAT"] end
lower_bound = nothing

max_iter = 500
parallel_sim = 20
sim_fa = false
base_constr = true
