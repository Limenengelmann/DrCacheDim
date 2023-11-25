using Polyhedra
using JuMP
using GLMakie
using GeometryBasics

function do_plot()
    model = Model()
    @variable(model, 1 <= x <= 3)
    @variable(model, 1 <= y <= 4)
    @variable(model, 2 <= z <= 4)
    @constraint(model, x <= y)
    @constraint(model, y <= z)

    H = hrep(model)
    display(H)
    p = polyhedron(H)
    M = Polyhedra.Mesh(p)
    display(M)

    diff = Vec3f(1.0)
    spec = Vec3f(1.0)
    ambi = Vec3f(1.0)
    #lpos = Vec3f(4,0,-10)
    lpos = Vec3f(0)
    colr = :red

    mesh_ = GeometryBasics.mesh(M)

    cmap = resample_cmap(:Spectral_11, length(mesh_.position))
    colors1 = [sum(v .^ 2) for (i,v) in enumerate(mesh_.position)]

    #fig = Figure()
    #pl = PointLight(lpos, RGBf(20, 20, 20))
    #al = AmbientLight(ambi)
    #lscene = LScene(fig[1, 1], show_axis=false, scenekw = (lights = [pl, al], backgroundcolor=:black, clear=true))
    #lscene = LScene(fig[1, 1], show_axis=false)
    fig,ax,p = mesh(M, color=colors1, interpolate=true, shading=true, diffuse = diff, specular = spec, ambient=ambi, lightposition=lpos)
    #p = mesh!(lscene, M, shading=true)#, diffuse = diff, specular = spec, ambient=ambi, lightposition=lpos)
    #fig = volume(M, shading=true)#, diffuse::Vec3f = Vec3f(0.6), specular::Vec3f = Vec3f(0.5))
    fig2 = wireframe!(ax, M)
    ax.show_axis=true
    display(fig)
    #hidedecorations!(ax, grid = true)
    #display(fig2)
    #readline(stdin)
end
