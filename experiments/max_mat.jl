max_mat = 240583570.61653
#lower_bound = function (Hmin, Hmax) return Inf; end
#lower_bound = function (Hmin, Hmax) return Hmax["MAT"] > max_mat ? Inf : Hmin["COST"] end
lower_bound = function (Hmin, Hmax) return Hmax["MAT"] > max_mat ? Inf : default_bound(Hmin, Hmax) end

max_iter = 100
parallel_sim = 10
sim_fa = false
base_constr = true
