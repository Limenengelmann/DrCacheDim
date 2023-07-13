max_cost = 4144497
#lower_bound = function (Hmin, Hmax) return Inf; end
# XXX: depends on the objective function used!
lower_bound = function (Hmin, Hmax) return Hmin["COST"] > max_cost ? Inf : Hmax["MAT"] end

max_iter = 100
parallel_sim = 10
sim_fa = false
