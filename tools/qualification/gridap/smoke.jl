using Gridap
using LinearAlgebra

println("julia_version=", VERSION)
println("gridap_version=", Base.pkgversion(Gridap))
println("platform=", Sys.MACHINE)

model = CartesianDiscreteModel((0.0, 1.0, 0.0, 1.0), (4, 4))
reffe = ReferenceFE(lagrangian, Float64, 1)
V0 = TestFESpace(model, reffe; conformity=:H1, dirichlet_tags="boundary")
Ug = TrialFESpace(V0, 0.0)
Ω = Triangulation(model)
dΩ = Measure(Ω, 2)
f(x) = 1.0
a(u, v) = ∫(∇(v) ⋅ ∇(u)) * dΩ
b(v) = ∫(v * f) * dΩ
op = AffineFEOperator(a, b, Ug, V0)
uh = solve(LinearFESolver(LUSolver()), op)
free = num_free_dofs(V0)
println("mesh_cells=", num_cells(model))
println("free_dofs=", free)
println("solution_norm=", norm(get_free_values(uh)))
@assert free > 0
@assert all(isfinite, get_free_values(uh))
println("GRIDAP_POISSON_OK")
