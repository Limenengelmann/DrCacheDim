### A Pluto.jl notebook ###
# v0.19.25

using Markdown
using InteractiveUtils

# ╔═╡ 6edc6896-13c0-46df-afe5-14675a8fc2e6
import YAML; using JuMP; import Ipopt; using LinearAlgebra; import Alpine

# ╔═╡ ab7ffb3d-e310-43d4-8bff-8241e0b5d271
cd("/home/elimtob/Workspace/mymemtrace");

# ╔═╡ 1aa2daed-e843-4adb-80b1-b1f7006ca2c9
LVLS = ["L1I", "L1D", "L2", "L3"]

# ╔═╡ f3956216-70e9-410a-9ee0-abd8300f0e48
data = YAML.load_file("results/imagick_r_sim_117911.yml")

# ╔═╡ d4970aba-fa12-47c3-93b2-724df8e9eae9
scaleAMAT = 1e-3

# ╔═╡ c7c4a801-f8cb-4c2f-8323-a53f749572e8
c_sol = [512, 8, 64, 12, 1024, 20, 16384, 8, 1.130623488695e7*scaleAMAT]

# ╔═╡ 0188012b-3d05-4064-bb49-0e5774461b8f
header = ("L1Isets", "L1Iassoc", "L1Dsets", "L1Dassoc", "L2sets", "L2assoc", "L3sets", "L3assoc", "AMAT")

# ╔═╡ cdd74a56-eac4-4e08-a62a-63d83f38955b
C = Matrix{Real}(undef,  length(header), length(data))

# ╔═╡ 5ca13ce4-aeed-4e3e-a60e-ada01adfadd1
i = 1

# ╔═╡ 3800cbd1-8926-4569-b443-1dd5d537b2ca
for d in data
	c = Real[]
	for lvl in LVLS
		local a = d[lvl]["cfg"]["assoc"]
		local s = d[lvl]["cfg"]["size"] / 64 / a # sets = size/64/assoc
		push!(c, s, a)
	end
	push!(c, d["AMAT"]*scaleAMAT)
	println(c)
	C[:,i] = c; i+=1
end

# ╔═╡ a7fb9de9-22b0-4826-8730-0c2f23fa894a
C

# ╔═╡ 6a25e6c8-10c6-474f-b4ee-799b978c3d84
c_sol .- C[:,1:end]

# ╔═╡ 78f6bfe9-967a-40b8-9fcf-2af46841106e
data[1]["L1I"]

# ╔═╡ 874f9508-9c52-4368-b701-df3517977c74
calibrate = Model(Ipopt.Optimizer)

# ╔═╡ a4665e27-f9fa-4336-a7fe-3a84f6c0d26b
set_silent(calibrate)

# ╔═╡ 3c67b67c-a12e-49c0-8616-831fcdb33ce3
w0 = ones(length(header))
#w0 = zeros(length(header))

# ╔═╡ 2dda5412-aa02-41e2-846a-d14374a92aef
@variable(calibrate, w[i=1:length(header)] >= 0.1, start=w0[i])

# ╔═╡ ea8f2cc3-2e45-49b6-b52f-d35fd1a86a02
@constraint(calibrate, w[9] == 1) # weights relative to latency weight

# ╔═╡ 9528c6df-1f35-4654-ab75-63e014d9bfc1
@constraint(calibrate, [i=1:2:7], w[i] <= w[i+1]) # sets < assoc (wrt. cost)

# ╔═╡ 490d4692-4559-4ac2-9074-5609109cf544
A = [1 0 0 0 -1  0  0  0 0
	 0 0 1 0 -1  0  0  0 0
     0 0 0 0  1  0 -1  0 0
	 0 1 0 0  0 -1  0  0 0
	 0 0 0 1  0 -1  0  0 0
	 0 0 0 0  0  1  0 -1 0]

# ╔═╡ e1288f8a-17bd-4e28-a9f4-33af8931a452
@constraint(calibrate, A*w .>= 0) # sets < assoc (wrt. cost)

# ╔═╡ 51cd50f6-358d-4b7b-99d9-9a988fe6c91a
sum(C, dims = 2)

# ╔═╡ 1cc1804f-c26a-4e32-9b0b-9da862972fdb
z = size(C, 2) * c_sol - sum(C, dims=2)

# ╔═╡ 5fe5c7d2-d24d-4d2b-b60e-6d7794b0a4e7
dot(1:9,z)

# ╔═╡ 27f5d9cb-daa8-4003-ab5e-c6e34d315988
f(w...) = begin 
res = 0
for c in eachcol(C)
	wc = dot(w, c_sol - c)
	wc = wc >= 0 ? wc + 10000 : wc
	res += wc
end
return res
end

# ╔═╡ d3e99dc8-eff8-4020-8f03-8c381330f9ed
f(1,2,3,4,5,6,7,8,9)

# ╔═╡ c79f2841-c0c2-4b38-93b1-3fb568166307
g(w...) = dot(w,z)

# ╔═╡ f451285b-77f1-4720-9b00-4befb10ac9ed
register(calibrate, :f, length(header), f, autodiff = true)

# ╔═╡ 57ed28bd-3f2f-471e-a2a5-d094d15b9a73
register(calibrate, :g, length(header), g, autodiff = true)

# ╔═╡ 9fbb750e-ffb1-4d2a-860b-1add424dcb0b
#@NLexpression(calibrate, Min, f(w...))
#@NLexpression(calibrate, Min, g(w...))
@objective(calibrate, Min, dot(w,z))

# ╔═╡ 5f0c87bb-6717-4f46-887d-d0cade333346
optimize!(calibrate)

# ╔═╡ 49545a64-616b-491b-8984-ecbedb58df0a
print(calibrate)

# ╔═╡ 92eadf71-1d58-4eea-9f5c-60db6ddaa136
solution_summary(calibrate, verbose=true)

# ╔═╡ 49736cc8-67cb-43f0-8452-9ae372ac10ab
value.(w)

# ╔═╡ 7def7b33-4694-4f9e-9c64-6ee652f12582
f(value.(w)...)	#objective value

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
Alpine = "07493b3f-dabb-5b16-a503-4139292d7dd4"
Ipopt = "b6b21f68-93f8-5de0-b562-5493be1d77c9"
JuMP = "4076af6c-e467-56ae-b986-b466b2749572"
LinearAlgebra = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
YAML = "ddb6d928-2868-570f-bddf-ab3f9cf99eb6"

[compat]
Alpine = "~0.5.4"
Ipopt = "~1.2.1"
JuMP = "~1.10.0"
YAML = "~0.4.8"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.8.5"
manifest_format = "2.0"
project_hash = "d1193ad0c2b25417b41deec003b76e7f08f1f1c7"

[[deps.ASL_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "6252039f98492252f9e47c312c8ffda0e3b9e78d"
uuid = "ae81ac8f-d209-56e5-92de-9978fef736f9"
version = "0.1.3+0"

[[deps.Alpine]]
deps = ["Combinatorics", "JuMP", "LinearAlgebra", "MathOptInterface", "Pkg", "Statistics"]
git-tree-sha1 = "238386a9b06dca3f9ee8f39ba2b20cfc506bc99e"
uuid = "07493b3f-dabb-5b16-a503-4139292d7dd4"
version = "0.5.4"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"
version = "1.1.1"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[deps.BenchmarkTools]]
deps = ["JSON", "Logging", "Printf", "Profile", "Statistics", "UUIDs"]
git-tree-sha1 = "d9a9701b899b30332bbcb3e1679c41cce81fb0e8"
uuid = "6e4b80f9-dd63-53aa-95a3-0cdb28fa8baf"
version = "1.3.2"

[[deps.Bzip2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "19a35467a82e236ff51bc17a3a44b69ef35185a2"
uuid = "6e34b625-4abd-537c-b88f-471c36dfa7a0"
version = "1.0.8+0"

[[deps.ChainRulesCore]]
deps = ["Compat", "LinearAlgebra", "SparseArrays"]
git-tree-sha1 = "c6d890a52d2c4d55d326439580c3b8d0875a77d9"
uuid = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
version = "1.15.7"

[[deps.ChangesOfVariables]]
deps = ["ChainRulesCore", "LinearAlgebra", "Test"]
git-tree-sha1 = "485193efd2176b88e6622a39a246f8c5b600e74e"
uuid = "9e997f8a-9a97-42d5-a9f1-ce6bfc15e2c0"
version = "0.1.6"

[[deps.CodecBzip2]]
deps = ["Bzip2_jll", "Libdl", "TranscodingStreams"]
git-tree-sha1 = "2e62a725210ce3c3c2e1a3080190e7ca491f18d7"
uuid = "523fee87-0ab8-5b00-afb7-3ecf72e48cfd"
version = "0.7.2"

[[deps.CodecZlib]]
deps = ["TranscodingStreams", "Zlib_jll"]
git-tree-sha1 = "9c209fb7536406834aa938fb149964b985de6c83"
uuid = "944b1d66-785c-5afd-91f1-9de20f533193"
version = "0.7.1"

[[deps.Combinatorics]]
git-tree-sha1 = "08c8b6831dc00bfea825826be0bc8336fc369860"
uuid = "861a8166-3701-5b0c-9a16-15d98fcdc6aa"
version = "1.0.2"

[[deps.CommonSubexpressions]]
deps = ["MacroTools", "Test"]
git-tree-sha1 = "7b8a93dba8af7e3b42fecabf646260105ac373f7"
uuid = "bbf7d656-a473-5ed7-a52c-81e309532950"
version = "0.3.0"

[[deps.Compat]]
deps = ["Dates", "LinearAlgebra", "UUIDs"]
git-tree-sha1 = "7a60c856b9fa189eb34f5f8a6f6b5529b7942957"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "4.6.1"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"
version = "1.0.1+0"

[[deps.DataStructures]]
deps = ["Compat", "InteractiveUtils", "OrderedCollections"]
git-tree-sha1 = "d1fff3a548102f48987a52a2e0d114fa97d730f0"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.18.13"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[deps.DiffResults]]
deps = ["StaticArraysCore"]
git-tree-sha1 = "782dd5f4561f5d267313f23853baaaa4c52ea621"
uuid = "163ba53b-c6d8-5494-b064-1a9d43ac40c5"
version = "1.1.0"

[[deps.DiffRules]]
deps = ["IrrationalConstants", "LogExpFunctions", "NaNMath", "Random", "SpecialFunctions"]
git-tree-sha1 = "a4ad7ef19d2cdc2eff57abbbe68032b1cd0bd8f8"
uuid = "b552c78f-8df3-52c6-915a-8e097449b14b"
version = "1.13.0"

[[deps.DocStringExtensions]]
deps = ["LibGit2"]
git-tree-sha1 = "2fb1e02f2b635d0845df5d7c167fec4dd739b00d"
uuid = "ffbed154-4ef7-542d-bbb7-c09d3a79fcae"
version = "0.9.3"

[[deps.Downloads]]
deps = ["ArgTools", "FileWatching", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"
version = "1.6.0"

[[deps.FileWatching]]
uuid = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"

[[deps.ForwardDiff]]
deps = ["CommonSubexpressions", "DiffResults", "DiffRules", "LinearAlgebra", "LogExpFunctions", "NaNMath", "Preferences", "Printf", "Random", "SpecialFunctions", "StaticArrays"]
git-tree-sha1 = "00e252f4d706b3d55a8863432e742bf5717b498d"
uuid = "f6369f11-7733-5829-9624-2563aa707210"
version = "0.10.35"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[deps.InverseFunctions]]
deps = ["Test"]
git-tree-sha1 = "49510dfcb407e572524ba94aeae2fced1f3feb0f"
uuid = "3587e190-3f89-42d0-90ee-14403ec27112"
version = "0.1.8"

[[deps.Ipopt]]
deps = ["Ipopt_jll", "LinearAlgebra", "MathOptInterface", "OpenBLAS32_jll", "SnoopPrecompile"]
git-tree-sha1 = "392d19287155a54d0053360a90dd1b43037a8ef2"
uuid = "b6b21f68-93f8-5de0-b562-5493be1d77c9"
version = "1.2.1"

[[deps.Ipopt_jll]]
deps = ["ASL_jll", "Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "MUMPS_seq_jll", "OpenBLAS32_jll", "Pkg", "libblastrampoline_jll"]
git-tree-sha1 = "97c0e9fa36e93448fe214fea5366fac1ba3d1bfa"
uuid = "9cc047cb-c261-5740-88fc-0cf96f7bdcc7"
version = "300.1400.1000+0"

[[deps.IrrationalConstants]]
git-tree-sha1 = "630b497eafcc20001bba38a4651b327dcfc491d2"
uuid = "92d709cd-6900-40b7-9082-c6be49f344b6"
version = "0.2.2"

[[deps.JLLWrappers]]
deps = ["Preferences"]
git-tree-sha1 = "abc9885a7ca2052a736a600f7fa66209f96506e1"
uuid = "692b3bcd-3c85-4b1f-b108-f13ce0eb3210"
version = "1.4.1"

[[deps.JSON]]
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "31e996f0a15c7b280ba9f76636b3ff9e2ae58c9a"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.4"

[[deps.JuMP]]
deps = ["LinearAlgebra", "MathOptInterface", "MutableArithmetics", "OrderedCollections", "Printf", "SnoopPrecompile", "SparseArrays"]
git-tree-sha1 = "4ec0e68fecbbe1b78db2ddf1ac573963ed5adebc"
uuid = "4076af6c-e467-56ae-b986-b466b2749572"
version = "1.10.0"

[[deps.LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"
version = "0.6.3"

[[deps.LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"
version = "7.84.0+0"

[[deps.LibGit2]]
deps = ["Base64", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"

[[deps.LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"
version = "1.10.2+0"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"

[[deps.Libiconv_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "c7cb1f5d892775ba13767a87c7ada0b980ea0a71"
uuid = "94ce4f54-9a6c-5748-9c1c-f9c7231a4531"
version = "1.16.1+2"

[[deps.LinearAlgebra]]
deps = ["Libdl", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[deps.LogExpFunctions]]
deps = ["ChainRulesCore", "ChangesOfVariables", "DocStringExtensions", "InverseFunctions", "IrrationalConstants", "LinearAlgebra"]
git-tree-sha1 = "0a1b7c2863e44523180fdb3146534e265a91870b"
uuid = "2ab3a3ac-af41-5b50-aa03-7779005ae688"
version = "0.3.23"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[deps.METIS_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "1fd0a97409e418b78c53fac671cf4622efdf0f21"
uuid = "d00139f3-1899-568f-a2f0-47f597d42d70"
version = "5.1.2+0"

[[deps.MUMPS_seq_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "METIS_jll", "OpenBLAS32_jll", "Pkg", "libblastrampoline_jll"]
git-tree-sha1 = "f429d6bbe9ad015a2477077c9e89b978b8c26558"
uuid = "d7ed1dd3-d0ae-5e8e-bfb4-87a502085b8d"
version = "500.500.101+0"

[[deps.MacroTools]]
deps = ["Markdown", "Random"]
git-tree-sha1 = "42324d08725e200c23d4dfb549e0d5d89dede2d2"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.10"

[[deps.Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[deps.MathOptInterface]]
deps = ["BenchmarkTools", "CodecBzip2", "CodecZlib", "DataStructures", "ForwardDiff", "JSON", "LinearAlgebra", "MutableArithmetics", "NaNMath", "OrderedCollections", "Printf", "SnoopPrecompile", "SparseArrays", "SpecialFunctions", "Test", "Unicode"]
git-tree-sha1 = "58a367388e1b068104fa421cb34f0e6ee6316a26"
uuid = "b8f27783-ece8-5eb3-8dc8-9495eed66fee"
version = "1.14.1"

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"
version = "2.28.0+0"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"
version = "2022.2.1"

[[deps.MutableArithmetics]]
deps = ["LinearAlgebra", "SparseArrays", "Test"]
git-tree-sha1 = "3295d296288ab1a0a2528feb424b854418acff57"
uuid = "d8a4904e-b15c-11e9-3269-09a3773c0cb0"
version = "1.2.3"

[[deps.NaNMath]]
deps = ["OpenLibm_jll"]
git-tree-sha1 = "0877504529a3e5c3343c6f8b4c0381e57e4387e4"
uuid = "77ba4419-2d1f-58cd-9bb1-8ffee604a2e3"
version = "1.0.2"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"
version = "1.2.0"

[[deps.OpenBLAS32_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "9c6c2ed4b7acd2137b878eb96c68e63b76199d0f"
uuid = "656ef2d0-ae68-5445-9ca0-591084a874a2"
version = "0.3.17+0"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"
version = "0.3.20+0"

[[deps.OpenLibm_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "05823500-19ac-5b8b-9628-191a04bc5112"
version = "0.8.1+0"

[[deps.OpenSpecFun_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "13652491f6856acfd2db29360e1bbcd4565d04f1"
uuid = "efe28fd5-8261-553b-a9e1-b2916fc3738e"
version = "0.5.5+0"

[[deps.OrderedCollections]]
git-tree-sha1 = "d321bf2de576bf25ec4d3e4360faca399afca282"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.6.0"

[[deps.Parsers]]
deps = ["Dates", "SnoopPrecompile"]
git-tree-sha1 = "478ac6c952fddd4399e71d4779797c538d0ff2bf"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.5.8"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"
version = "1.8.0"

[[deps.Preferences]]
deps = ["TOML"]
git-tree-sha1 = "47e5f437cc0e7ef2ce8406ce1e7e24d44915f88d"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.3.0"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[deps.Profile]]
deps = ["Printf"]
uuid = "9abbd945-dff8-562f-b5e8-e1ebf5ef1b79"

[[deps.REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[deps.Random]]
deps = ["SHA", "Serialization"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"
version = "0.7.0"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[deps.SnoopPrecompile]]
deps = ["Preferences"]
git-tree-sha1 = "e760a70afdcd461cf01a575947738d359234665c"
uuid = "66db9d55-30c0-4569-8b51-7e840670fc0c"
version = "1.0.3"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[deps.SparseArrays]]
deps = ["LinearAlgebra", "Random"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[deps.SpecialFunctions]]
deps = ["ChainRulesCore", "IrrationalConstants", "LogExpFunctions", "OpenLibm_jll", "OpenSpecFun_jll"]
git-tree-sha1 = "ef28127915f4229c971eb43f3fc075dd3fe91880"
uuid = "276daf66-3868-5448-9aa4-cd146d93841b"
version = "2.2.0"

[[deps.StaticArrays]]
deps = ["LinearAlgebra", "Random", "StaticArraysCore", "Statistics"]
git-tree-sha1 = "63e84b7fdf5021026d0f17f76af7c57772313d99"
uuid = "90137ffa-7385-5640-81b9-e52037218182"
version = "1.5.21"

[[deps.StaticArraysCore]]
git-tree-sha1 = "6b7ba252635a5eff6a0b0664a41ee140a1c9e72a"
uuid = "1e83bf80-4336-4d27-bf5d-d5a4f845583c"
version = "1.4.0"

[[deps.Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[[deps.StringEncodings]]
deps = ["Libiconv_jll"]
git-tree-sha1 = "33c0da881af3248dafefb939a21694b97cfece76"
uuid = "69024149-9ee7-55f6-a4c4-859efe599b68"
version = "0.3.6"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"
version = "1.0.0"

[[deps.Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"
version = "1.10.1"

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[deps.TranscodingStreams]]
deps = ["Random", "Test"]
git-tree-sha1 = "0b829474fed270a4b0ab07117dce9b9a2fa7581a"
uuid = "3bb67fe8-82b1-5028-8e26-92a6c54297fa"
version = "0.9.12"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[deps.YAML]]
deps = ["Base64", "Dates", "Printf", "StringEncodings"]
git-tree-sha1 = "dbc7f1c0012a69486af79c8bcdb31be820670ba2"
uuid = "ddb6d928-2868-570f-bddf-ab3f9cf99eb6"
version = "0.4.8"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"
version = "1.2.12+3"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl", "OpenBLAS_jll"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
version = "5.1.1+0"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"
version = "1.48.0+0"

[[deps.p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
version = "17.4.0+0"
"""

# ╔═╡ Cell order:
# ╠═6edc6896-13c0-46df-afe5-14675a8fc2e6
# ╠═ab7ffb3d-e310-43d4-8bff-8241e0b5d271
# ╠═1aa2daed-e843-4adb-80b1-b1f7006ca2c9
# ╠═f3956216-70e9-410a-9ee0-abd8300f0e48
# ╠═d4970aba-fa12-47c3-93b2-724df8e9eae9
# ╠═c7c4a801-f8cb-4c2f-8323-a53f749572e8
# ╠═0188012b-3d05-4064-bb49-0e5774461b8f
# ╠═cdd74a56-eac4-4e08-a62a-63d83f38955b
# ╠═5ca13ce4-aeed-4e3e-a60e-ada01adfadd1
# ╠═3800cbd1-8926-4569-b443-1dd5d537b2ca
# ╠═a7fb9de9-22b0-4826-8730-0c2f23fa894a
# ╠═6a25e6c8-10c6-474f-b4ee-799b978c3d84
# ╠═78f6bfe9-967a-40b8-9fcf-2af46841106e
# ╠═874f9508-9c52-4368-b701-df3517977c74
# ╠═a4665e27-f9fa-4336-a7fe-3a84f6c0d26b
# ╠═3c67b67c-a12e-49c0-8616-831fcdb33ce3
# ╠═2dda5412-aa02-41e2-846a-d14374a92aef
# ╠═ea8f2cc3-2e45-49b6-b52f-d35fd1a86a02
# ╠═9528c6df-1f35-4654-ab75-63e014d9bfc1
# ╠═490d4692-4559-4ac2-9074-5609109cf544
# ╠═e1288f8a-17bd-4e28-a9f4-33af8931a452
# ╠═51cd50f6-358d-4b7b-99d9-9a988fe6c91a
# ╠═1cc1804f-c26a-4e32-9b0b-9da862972fdb
# ╠═5fe5c7d2-d24d-4d2b-b60e-6d7794b0a4e7
# ╠═27f5d9cb-daa8-4003-ab5e-c6e34d315988
# ╠═d3e99dc8-eff8-4020-8f03-8c381330f9ed
# ╠═c79f2841-c0c2-4b38-93b1-3fb568166307
# ╠═f451285b-77f1-4720-9b00-4befb10ac9ed
# ╠═57ed28bd-3f2f-471e-a2a5-d094d15b9a73
# ╠═9fbb750e-ffb1-4d2a-860b-1add424dcb0b
# ╠═5f0c87bb-6717-4f46-887d-d0cade333346
# ╠═49545a64-616b-491b-8984-ecbedb58df0a
# ╠═92eadf71-1d58-4eea-9f5c-60db6ddaa136
# ╠═49736cc8-67cb-43f0-8452-9ae372ac10ab
# ╠═7def7b33-4694-4f9e-9c64-6ee652f12582
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
