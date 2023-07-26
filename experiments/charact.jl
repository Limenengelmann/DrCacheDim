#lower_bound = function (Hmin, Hmax) return Inf; end
lower_bound = function(Hmin, Hmax) return Hmin["LAMBDA"]*Hmin["CSCALE"]*Hmin["COST"] + (1-Hmin["LAMBDA"])*Hmax["MAT"] end

max_iter = 500
parallel_sim = 10
sim_fa = false
base_constr = true
