max_cost = 3641180.16
#lower_bound = function (Hmin, Hmax) return Inf; end
# XXX: depends on the objective function used!
#lower_bound = function (Hmin, Hmax) return Hmin["COST"] > max_cost ? Inf : Hmax["MAT"] end
lower_bound = function (Hmin, Hmax) return Hmin["COST"] > max_cost ? Inf : default_bound(Hmin, Hmax) end

max_iter = 100
parallel_sim = 10
sim_fa = false
base_constr = true
