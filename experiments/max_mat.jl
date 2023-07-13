# use default bound
max_mat = 507100167 #avrg MAT for imagick_r, H_local
#lower_bound = function (Hmin, Hmax) return Inf; end
lower_bound = function (Hmin, Hmax) return Hmax["MAT"] > max_mat ? Inf : Hmin["COST"] end

max_iter = 100
parallel_sim = 10
sim_fa = false
