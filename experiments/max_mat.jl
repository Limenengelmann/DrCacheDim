max_mat = 9346990
#lower_bound = function (Hmin, Hmax) return Inf; end
#lower_bound = function (Hmin, Hmax) return Hmax["MAT"] > max_mat ? Inf : Hmin["COST"] end
lower_bound = function (Hmin, Hmax) return Hmax["MAT"] > max_mat ? Inf : default_bound(Hmin, Hmax) end

max_iter = 10000
parallel_sim = 10
sim_fa = false
base_constr = true
