const ROOT = normpath(joinpath(@__DIR__, "../../../../../"))
include(joinpath(ROOT, "src/RuntimeV4/M4Isolated/ManufacturedEquationIRV1.jl"))
include(joinpath(ROOT, "src/RuntimeV4/M4Isolated/ManufacturedResidualLoweringV1.jl"))
include(joinpath(ROOT, "src/RuntimeV4/M4Isolated/ManufacturedDiscreteControlV1.jl"))
include(joinpath(ROOT, "src/RuntimeV4/M4Isolated/ManufacturedCoupledSolveControlV1.jl"))

ir = manufactured_equation_ir_v1()
a = lower_manufactured_residual(ir).declaration
left = build_manufactured_discrete_control(a, 2, 2, 2).control
right = build_manufactured_discrete_control(a, 2, 2, 2).control
right_bad = ManufacturedDiscreteControlV1(right.schema, right.residual, right.equation_id,
    right.domain_id, right.grid, right.topology, right.boundary, right.units,
    right.source_id, "FOREIGN-SOURCE-OWNER", right.conservation_owner,
    right.provenance, right.faces, right.cell_balances, right.claim_ceiling,
    right.evidence_scope)
good = build_manufactured_coupled_solve_control(left, right).control
bad = ManufacturedCoupledSolveControlV1(good.schema, good.left, right_bad,
    good.left_region_id, good.right_region_id, good.grid_counts, good.interface,
    good.block_matrix, good.rhs, good.equation_id, good.source_id,
    good.source_owner, good.conservation_owner, good.units, good.provenance,
    good.cell_solutions, good.block_residuals, good.block_residual,
    good.claim_ceiling, good.evidence_scope)
result = validate_manufactured_coupled_solve_control(bad)
@assert !result.valid
@assert result.status == :typed_failure
@assert any(f.code == :foreign_c_input && startswith(f.path, "right.") for f in result.failures)
println("replayed_right_source_owner_bypass=typed_failure")
println("failure_codes=$(sort!(String[string(f.code) for f in result.failures]))")
