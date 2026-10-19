"""Executable tests for the additive UP2 cross-mesh transfer slice.

The nominal assertions call the transfer and diffusion functions themselves;
no expected result is manufactured by the test.  This file is a supplied
Julia lane and is intentionally not run by the Python-only handoff.
"""

using Test
using FusionConceptAI
using LinearAlgebra
using SparseArrays

const _CM_ROOT = normpath(joinpath(@__DIR__, "../../.."))
const _DCCE_ROOT = _CM_ROOT
const _DCCE = FusionConceptAI
FusionConceptAI.load_genome_v5_components!()
FusionConceptAI.load_vnext_t2_components_v2!()
isdefined(Main, :FusionRuntimeV4) ||
    include(joinpath(_CM_ROOT, "src", "RuntimeV4", "FusionRuntimeV4.jl"))
Base.include(FusionConceptAI, joinpath(_CM_ROOT, "src", "RuntimeV4",
    "DeclaredG123DiffusionExecutionV1.jl"))
Base.include(FusionConceptAI, joinpath(_CM_ROOT, "src", "RuntimeV4",
    "DeclaredSpatialCompositionExecutionV1.jl"))
Base.include(FusionConceptAI, joinpath(_CM_ROOT, "src", "RuntimeV4",
    "DeclaredDiffusionCompileExecuteV1.jl"))
Base.include(FusionConceptAI, joinpath(_CM_ROOT, "src", "RuntimeV4",
    "DeclaredCrossMeshConservativeTransferExecutionV1.jl"))
isdefined(Main, :InHouseCoupledMHDGlobalSolveV1) ||
    Base.include(Main, joinpath(_CM_ROOT, "src", "RuntimeV4",
        "InHouseCoupledMHDGlobalSolveV1.jl"))
const _CM_GLOBAL_SOLVER = Main.InHouseCoupledMHDGlobalSolveV1

_cm_g2_regional(args...) = nothing
_cm_g2_interface(args...) = nothing
_cm_g2_outer(args...) = nothing
_cm_g2_conservation(args...) = nothing
_cm_g2_jacobian(args...) = nothing

function _cm_missing_closure_model(;candidate_hash=repeat("a",64),dofs=2,pressure_index=1)
    solver = _CM_GLOBAL_SOLVER
    callbacks = (_cm_g2_regional, _cm_g2_interface, _cm_g2_outer,
        _cm_g2_conservation, _cm_g2_jacobian)
    provider_context_hash = solver.coupled_mhd_provider_context_hash_v1(callbacks...)
    solver.make_global_model_v1(candidate_hash=candidate_hash,
        region_ids=("core",), region_dofs=(dofs,), single_region=true,
        pressure_indices=(pressure_index,), regional_equation_ids=(("core_eq_1",),),
        outer_constraint_ids=(("outer_eq_1",),),
        global_conservation_ids=("global_conservation_1",),
        closure_evidence=(pressure_topology=nothing,current_topology=nothing,
            B_out=nothing,K_outer=nothing,return_current_path=nothing),
        provider_id="test_only/missing_closures", provider_source_path=@__FILE__,
        provider_context_hash=provider_context_hash,
        regional_evaluator=callbacks[1], interface_evaluator=callbacks[2],
        outer_evaluator=callbacks[3], conservation_evaluator=callbacks[4],
        jacobian_oracle=callbacks[5])
end

function _cm_policy()
    _CM_GLOBAL_SOLVER.make_global_policy_v1(acceptance_ref="test-only",
        contract_source_path=@__FILE__,max_updates=1,wall_seconds=1.0,
        residual_tolerance=1e-6,constraint_tolerance=1e-8,
        stationarity_tolerance=1e-8,bound_dual_tolerance=1e-8,
        complementarity_tolerance=1e-8,step_tolerance=1e-8,
        minimum_step=2.0^-10,armijo_fraction=1e-4,max_backtracks=2,
        max_active_set_iterations=2,stagnation_window=1)
end

# A test-only, identity-residual fixture exercises the existing global MHD
# assembly/solve API with the *entire* remeshed native vector. It validates
# adapter dispatch and candidate binding only; its closures are explicitly
# nonphysical and do not stand in for C771 MHD closure evidence.
function _cm_remesh_global_api_fixture(expected_state, candidate_hash, pressure_indices)
    solver = _CM_GLOBAL_SOLVER
    expected = Float64.(collect(expected_state))
    n = length(expected)
    region_id = "remeshed_native_state"
    equation_ids = Tuple("remeshed_state_$(i)" for i in 1:n)
    outer_ids = ("screen_fixture_outer_zero",)
    conservation_ids = ("screen_fixture_conservation_zero",)
    envelope(region, context) = (candidate_hash=context.candidate_hash,
        provider_semantic_hash=context.provider_semantic_hash,
        provider_context_hash=context.provider_context_hash, region_id=region)
    residual_only(x) = Float64.(collect(x)) .- expected
    regional = (region, x, closures, context) -> begin
        region == region_id || throw(ArgumentError("unexpected screen fixture region"))
        merge(envelope(region, context), (equation_ids=equation_ids,
            residual=residual_only(x), jacobian=spdiagm(0 => ones(Float64, n))))
    end
    interface = (args...) -> throw(ArgumentError("single-region fixture has no interface"))
    outer = (region, x, closures, context) -> begin
        merge(envelope(region, context), (constraint_ids=outer_ids,
            residual=[0.0], jacobian=spzeros(Float64, 1, n)))
    end
    conservation = (x, closures, context) -> merge(envelope("global", context),
        (conservation_ids=conservation_ids, residual=[0.0],
            jacobian=spzeros(Float64, 1, n)))
    oracle = (operation, region, x, closures, context) -> begin
        J = operation === :regional ? begin
            Jfd = zeros(Float64, n, n)
            for j in 1:n
                h = 2.0^-20 * (1.0 + abs(Float64(x[j])))
                xp = Float64.(collect(x)); xm = copy(xp)
                xp[j] += h; xm[j] -= h
                Jfd[:,j] = (residual_only(xp) .- residual_only(xm)) ./ (2h)
            end
            sparse(Jfd)
        end : spzeros(Float64, 1, n)
        body = if operation === :regional
            (equation_ids=equation_ids, jacobian=J,
                jacobian_oracle_hash=string(solver.canonical_hash(
                    solver._callback_identity(oracle))))
        elseif operation === :outer
            (constraint_ids=outer_ids, jacobian=J,
                jacobian_oracle_hash=string(solver.canonical_hash(
                    solver._callback_identity(oracle))))
        else
            (conservation_ids=conservation_ids, jacobian=J,
                jacobian_oracle_hash=string(solver.canonical_hash(
                    solver._callback_identity(oracle))))
        end
        merge(envelope(region, context), body)
    end
    callbacks = (regional, interface, outer, conservation, oracle)
    context_hash = solver.coupled_mhd_provider_context_hash_v1(callbacks...)
    payload = (classification=:preparation, test_only=true, physical=false,
        purpose=:global_consumer_vector_dispatch_fixture)
    closures = NamedTuple{solver._REQUIRED_CLOSURES}(Tuple(
        solver.make_closure_evidence_v1(kind, candidate_hash,
            "preparation/test_only/physical=false/up2-remesh-api-fixture",
            @__FILE__, payload) for kind in solver._REQUIRED_CLOSURES))
    model = solver.make_global_model_v1(candidate_hash=candidate_hash,
        region_ids=(region_id,), region_dofs=(n,), single_region=true,
        pressure_indices=Tuple(Int.(pressure_indices)), regional_equation_ids=(equation_ids,),
        outer_constraint_ids=(outer_ids,), global_conservation_ids=conservation_ids,
        closure_evidence=closures,
        provider_id="preparation/test_only/physical=false/up2-remesh-api-fixture",
        provider_source_path=@__FILE__, provider_context_hash=context_hash,
        regional_evaluator=regional, interface_evaluator=interface,
        outer_evaluator=outer, conservation_evaluator=conservation,
        jacobian_oracle=oracle)
    model, _cm_policy()
end

# Reuse the established current-source thermal G123 builder without loading
# unrelated test definitions or executing their top-level lifecycle. This path reads the checked-out candidate
# sources directly and creates its T0 records with `frozen_context=source_root`;
# it does not load the canceled frozen-runtime/T2 authorization.
const _CM_THERMAL_TEST = joinpath(_CM_ROOT, "test", "RuntimeV4",
    "DeclaredDiffusionCompileExecute", "thermal_slab_actual_source_focused_test.jl")
const _THERMAL_SLAB_CANDIDATE_DIR = "test/fixtures/thermal_slab/thermal-slab-up4-v5-20261001"
function _cm_source_case_definition(ex)
    if ex isa Expr && ex.head === :function
        signature = ex.args[1]
        if signature isa Expr && signature.head === :call &&
                signature.args[1] === :_thermal_build_source_case
            return ex
        end
    end
    nothing
end
Base.include(_cm_source_case_definition, Main, _CM_THERMAL_TEST)
isdefined(Main, :_thermal_build_source_case) || error("existing source-case builder was not loaded")

# The additive slice is loaded into FusionConceptAI explicitly; bind its
# public test seams locally so the focused runner exercises that same module
# entry without relying on package export state.
const DeclaredCrossMeshCellV1 = FusionConceptAI.DeclaredCrossMeshCellV1
const DeclaredCrossMeshIdentityV1 = FusionConceptAI.DeclaredCrossMeshIdentityV1
const DeclaredCrossMeshV1 = FusionConceptAI.DeclaredCrossMeshV1
const DeclaredCrossMeshUnitV1 = FusionConceptAI.DeclaredCrossMeshUnitV1
const DeclaredCrossMeshAccountV1 = FusionConceptAI.DeclaredCrossMeshAccountV1
const DeclaredCrossMeshAccountsV1 = FusionConceptAI.DeclaredCrossMeshAccountsV1
const declared_cross_mesh_identity_v1 = FusionConceptAI.declared_cross_mesh_identity_v1
const declared_cross_mesh_v1 = FusionConceptAI.declared_cross_mesh_v1
const declared_cross_mesh_transfer_v1 = FusionConceptAI.declared_cross_mesh_transfer_v1
const execute_declared_cross_mesh_v1 = FusionConceptAI.execute_declared_cross_mesh_v1
const dcce_compile_execute_v1 = FusionConceptAI.dcce_compile_execute_v1

function _cm_actual_consumer_case()
    source_case = _thermal_build_source_case()
    built = source_case.built
    input = FusionConceptAI.dgd_input_v1(built.candidate_ref,
        built.g1.declaration, built.g2.declaration, built.g3.declaration,
        source_case.t0.transport)
    identity = declared_cross_mesh_identity_v1(input)
    spatial = source_case.spatial
    nsource = length(spatial.old_geometry.edges) - 1
    ntarget = length(spatial.new_geometry.edges) - 1
    source = declared_cross_mesh_v1(identity, :source,
        "thermal-slab:one-cell-source", "thermal-slab:x-domain",
        Tuple(spatial.old_geometry.edges);
        owners=ntuple(i -> "owner:thermal-source:$i", nsource))
    target = declared_cross_mesh_v1(identity, :target,
        "thermal-slab:$(ntarget)-cell-target", "thermal-slab:x-domain",
        Tuple(spatial.new_geometry.edges);
        owners=ntuple(i -> "owner:thermal-target:$i", ntarget))
    exponents = Tuple(Int(x) for x in built.g1.declaration.u.physical_type.units.exponents)
    unit = DeclaredCrossMeshUnitV1("K", exponents)
    accounts = DeclaredCrossMeshAccountsV1(
        DeclaredCrossMeshAccountV1("account:thermal-source", :source, unit,
            :minus, first(source.dof_ownership)),
        DeclaredCrossMeshAccountV1("account:thermal-target", :target, unit,
            :plus, first(target.dof_ownership)),
        DeclaredCrossMeshAccountV1("account:thermal-external", :external, unit,
            :plus, "owner:thermal-external"),
        DeclaredCrossMeshAccountV1("account:thermal-return", :target, unit,
            :plus, first(target.dof_ownership)))
    (source_case=source_case, input=input, identity=identity,
        source=source, target=target, accounts=accounts)
end

function _cm_spatial_with_old_state(spatial, source_state)
    FusionConceptAI.DeclaredSpatialCaseV1(spatial.old_geometry,
        spatial.new_geometry, source_state, spatial.field, spatial.boundary,
        spatial.composition; case_ref=spatial.case_ref)
end

function _cm_accounts_with_unit(accounts, unit)
    reunit(account) = DeclaredCrossMeshAccountV1(account.account_ref,
        account.side, unit, account.orientation, account.owner_ref)
    DeclaredCrossMeshAccountsV1(reunit(accounts.source), reunit(accounts.target),
        reunit(accounts.external), reunit(accounts.return_account))
end

function _cm_cross_mesh_binding(c, source_state; target_mesh=c.target,
        accounts=c.accounts)
    receipt = declared_cross_mesh_transfer_v1(c.input, c.identity, c.source,
        target_mesh, source_state; accounts=accounts)
    (receipt=receipt, identity=c.identity, source_mesh=c.source,
        target_mesh=target_mesh, source_state=source_state, accounts=accounts)
end

function _cm_case()
    # DCM-only contract tests use a minimal synthetic identity object. They
    # deliberately carry no G123 declarations or T0 source records.
    candidate = QualifiedRefV1("synthetic://candidate/up2-cross-mesh", "v5")
    declarations = ntuple(i -> begin
        layer = (:G1, :G2, :G3)[i]
        (layer=layer, source_ref="synthetic://source/$(layer)",
            source_bytes=(sha256=FusionConceptAI._dcm_hash((source=layer,)),),
            axes=(:payload_schema, :canonicalization, :receipt))
    end, 3)
    hashes = (g1_body_hash=FusionConceptAI._dcm_hash(:g1_body),
        g2_body_hash=FusionConceptAI._dcm_hash(:g2_body),
        g3_body_hash=FusionConceptAI._dcm_hash(:g3_body),
        bundle_hash=FusionConceptAI._dcm_hash(:bundle))
    input = (candidate_ref=candidate, hashes=hashes,
        bundle=(declarations=declarations,))
    identity = declared_cross_mesh_identity_v1(input)
    source = declared_cross_mesh_v1(identity, :source, "mesh:source-2", "space:up2",
        (0.0, 0.5, 1.0); owners=("owner:s1", "owner:s2"))
    target = declared_cross_mesh_v1(identity, :target, "mesh:target-4", "space:up2",
        (0.0, 0.25, 0.5, 0.75, 1.0);
        owners=("owner:t1", "owner:t2", "owner:t3", "owner:t4"))
    unit = DeclaredCrossMeshUnitV1("field-SI")
    accounts = DeclaredCrossMeshAccountsV1(
        DeclaredCrossMeshAccountV1("account:source", :source, unit, :minus, "owner:s1"),
        DeclaredCrossMeshAccountV1("account:target", :target, unit, :plus, "owner:t1"),
        DeclaredCrossMeshAccountV1("account:external", :external, unit, :plus, "owner:external"),
        DeclaredCrossMeshAccountV1("account:return", :target, unit, :plus, "owner:t1"))
    (input=input, identity=identity, source=source, target=target, accounts=accounts)
end

@testset "candidate-bound cross-mesh state is consumed by the existing FV solve" begin
    c = _cm_actual_consumer_case()
    source_state = Tuple(c.source_case.spatial.old_state)
    @test length(c.source.cells) == 1
    @test length(c.target.cells) == 4
    source_edges = Tuple(cell.lower for cell in c.source.cells)
    source_edges = (source_edges..., last(c.source.cells).upper)
    target_edges = Tuple(cell.lower for cell in c.target.cells)
    target_edges = (target_edges..., last(c.target.cells).upper)
    @test source_edges == Tuple(c.source_case.spatial.old_geometry.edges)
    @test target_edges == Tuple(c.source_case.spatial.new_geometry.edges)
    binding = _cm_cross_mesh_binding(c, source_state)
    receipt = binding.receipt
    @test receipt.status === :ready
    @test receipt.source_mesh_hash == c.source.mesh_hash
    @test receipt.target_mesh_hash == c.target.mesh_hash
    @test length(receipt.transferred_state) == length(c.target.cells)
    @test receipt.source_integrated_total ≈ receipt.target_integrated_total atol=1e-12
    @test receipt.source_overlap_coverage ≈ 1.0 atol=1e-12
    @test receipt.target_overlap_coverage ≈ 1.0 atol=1e-12
    @test receipt.transferred_state == ntuple(_ -> only(source_state),
        length(c.target.cells))

    function run_dcce(state, transfer_binding)
        spatial_case = _cm_spatial_with_old_state(c.source_case.spatial, state)
        dcce_compile_execute_v1(c.input.candidate_ref, c.input.g1, c.input.g2,
            c.input.g3, c.input.bundle, spatial_case;
            cross_mesh_transfer_binding=transfer_binding)
    end
    consumed = run_dcce(source_state, binding)
    ordinary = run_dcce(source_state, nothing)
    @test consumed.numerical.status === :ready
    @test consumed.numerical.fv.status === :ready
    @test consumed.numerical.fv.cross_mesh_transfer_receipt_hash == receipt.receipt_hash
    @test length(consumed.numerical.fv.cross_mesh_account_binding_hash) == 64
    @test consumed.numerical.fv.cross_mesh_account_binding_hash ==
        FusionConceptAI._dcce_hash((source=c.accounts.source,
            target=c.accounts.target, external=c.accounts.external,
            return_account=c.accounts.return_account))
    @test consumed.numerical.fv.initial_state == receipt.transferred_state
    @test consumed.numerical.fv.matrix == ordinary.numerical.fv.matrix
    @test consumed.numerical.fv.rhs == ordinary.numerical.fv.rhs
    @test collect(consumed.numerical.fv.solution) ≈
        collect(ordinary.numerical.fv.solution) atol=1e-12
    @test consumed.numerical.fv.warm_start_initial_residual_norm > 0.0
    @test consumed.numerical.fv.refinement_solve_count == 1
    @test consumed.numerical.fv.residual_norm ≤ 1e-12

    A = reduce(vcat, (permutedims(collect(row)) for row in consumed.numerical.fv.matrix))
    b = collect(consumed.numerical.fv.rhs)
    y = collect(receipt.transferred_state)
    r0 = maximum(abs.(A * y .- b))
    @test consumed.numerical.fv.warm_start_initial_residual_norm ≈ r0 atol=1e-12

    edited_source_state = (only(source_state) + 1.0,)
    edited_binding = _cm_cross_mesh_binding(c, edited_source_state)
    edited = run_dcce(edited_source_state, edited_binding)
    @test edited.numerical.fv.initial_state == edited_binding.receipt.transferred_state
    @test edited.numerical.fv.warm_start_initial_residual_norm !=
        consumed.numerical.fv.warm_start_initial_residual_norm
    @test collect(edited.numerical.fv.solution) ≈
        collect(consumed.numerical.fv.solution) atol=1e-12

    foreign_identity = DeclaredCrossMeshIdentityV1(
        QualifiedRefV1("foreign://candidate", "v5"), c.identity.source_hash,
        c.identity.body_hash, c.identity.bundle_hash, c.identity.axis_hashes)
    foreign_binding = merge(binding, (identity=foreign_identity,))
    rejected = run_dcce(source_state, foreign_binding)
    @test rejected.status === :fail_closed
    @test rejected.code === :cross_mesh_receipt_replay_mismatch
    @test rejected.numerical === nothing

    wrong_unit = DeclaredCrossMeshUnitV1("wrong-time-unit",
        (0, 0, 1, 0, 0, 0, 0))
    @test Tuple(wrong_unit.exponents) !=
        Tuple(c.input.g1.u.physical_type.units.exponents)
    wrong_accounts = _cm_accounts_with_unit(c.accounts, wrong_unit)
    wrong_unit_binding = _cm_cross_mesh_binding(c, source_state;
        accounts=wrong_accounts)
    @test wrong_unit_binding.receipt.status === :ready
    wrong_unit_out = run_dcce(source_state, wrong_unit_binding)
    @test wrong_unit_out.status === :fail_closed
    @test wrong_unit_out.code === :cross_mesh_g1_unit_mismatch
    @test wrong_unit_out.aggregate.solver_calls == 0
    @test wrong_unit_out.numerical === nothing

    g1_unit = Tuple(Int(x) for x in c.input.g1.u.physical_type.units.exponents)
    scaled_unit = DeclaredCrossMeshUnitV1("noncanonical-scale", g1_unit;
        scale_to_si=2.0)
    @test Tuple(scaled_unit.exponents) ==
        Tuple(c.input.g1.u.physical_type.units.exponents)
    scaled_accounts = _cm_accounts_with_unit(c.accounts, scaled_unit)
    scaled_binding = _cm_cross_mesh_binding(c, source_state;
        accounts=scaled_accounts)
    @test scaled_binding.receipt.status === :ready
    scaled_out = run_dcce(source_state, scaled_binding)
    @test scaled_out.status === :fail_closed
    @test scaled_out.code === :cross_mesh_g1_unit_mismatch
    @test scaled_out.aggregate.solver_calls == 0

    stale_edges = collect(c.source_case.spatial.new_geometry.edges)
    stale_edges[2] += (last(stale_edges) - first(stale_edges)) / 100
    stale_target = declared_cross_mesh_v1(c.identity, :target,
        "thermal-slab:four-cell-stale-target", "thermal-slab:x-domain",
        Tuple(stale_edges); owners=c.target.dof_ownership)
    stale_binding = _cm_cross_mesh_binding(c, source_state;
        target_mesh=stale_target)
    @test stale_binding.receipt.status === :ready
    stale_out = run_dcce(source_state, stale_binding)
    @test stale_out.status === :fail_closed
    @test stale_out.code === :cross_mesh_target_geometry_mismatch
    @test stale_out.aggregate.solver_calls == 0
end

@testset "axisymmetric native-state remesh calls original profile evaluator" begin
    law = (psi_axis_wb_per_rad=1.0, psi_boundary_wb_per_rad=0.0,
        Raxis_m=2.0, fvac_T_m=1.0, mu0_N_per_A2=1.0,
        L_A_per_m2=1.0, Beta0=0.5)
    source_domain = (n=4, ndof=22, mask=trues(4), pressure_dofs=[17,18,19,20],
        law=law, toroidal_coordinate=:native_Bphi_T_v1,
        native_field_model_id=:plasma_spline_plus_exact_pf_potential_jet_v1,
        vary_profile_coefficients=true, coefficient_columns=(21,22),
        accepted_coefficients=(0.5,0.5), dynamic_profile_span=false,
        span_columns=(), dynamic_geometry_data=(Raxis=[2.0,4.0],Zaxis=[-1.0,1.0],
            nr=2,nz=2,n=4,ndof=22,mask=trues(4),pressure_dofs=[17,18,19,20]))
    source_state = Float64[]
    for psi in (0.25,0.75,0.5,0.5)
        append!(source_state, (0.0,1.0,0.0,psi))
    end
    append!(source_state, (0.01,0.01,0.01,0.01,0.5,0.5))
    original = (data,x) -> FusionConceptAI._ccp_full_native_profile_evaluate(data,x)
    candidate_hash = repeat("a",64)
    # First produce the real remapped state from this established native test
    # fixture. Bind the explicit test-only global API model to that exact full
    # vector, then rerun the tiny remap to exercise its consumer seam.
    remapped_seed = FusionConceptAI.declared_axisymmetric_remesh_v1(source_domain,
        source_state, (2.0,3.0,4.0), (-1.0,0.0,1.0),
        (false,false,false,false,true,false,false,false,false);
        candidate_identity=(candidate_hash=candidate_hash,),
        gauge_anchor=(R_m=3.0,Z_m=0.0,psi_Wb_per_rad=0.5),
        expected_native_field_model_id=:plasma_spline_plus_exact_pf_potential_jet_v1,
        profile_evaluator=original)
    target_pressure_indices = Tuple(filter(>(0), remapped_seed.domain.pressure_dofs))
    global_model, global_policy = _cm_remesh_global_api_fixture(
        remapped_seed.state, candidate_hash, target_pressure_indices)
    mapped = FusionConceptAI.declared_axisymmetric_remesh_v1(source_domain,
        source_state, (2.0,3.0,4.0), (-1.0,0.0,1.0),
        (false,false,false,false,true,false,false,false,false);
        candidate_identity=(candidate_hash=candidate_hash,),
        gauge_anchor=(R_m=3.0,Z_m=0.0,psi_Wb_per_rad=0.5),
        expected_native_field_model_id=:plasma_spline_plus_exact_pf_potential_jet_v1,
        profile_evaluator=original,
        coupled_mhd_consumer=(solver_module=_CM_GLOBAL_SOLVER,
            model=global_model, policy=global_policy,
            expected_candidate_hash=candidate_hash))
    @test mapped.status === :evaluated_screen_only
    @test mapped.receipt.state_coordinate === :native_Bphi_T_v1
    @test mapped.receipt.pressure_unit == "Pa"
    @test mapped.receipt.plasma_current.integrand == "J_phi dR dZ"
    @test mapped.receipt.pressure_volume_energy.integrand == "2pi*R*p dR dZ"
    @test length(mapped.state) == 4*9+1+2
    @test mapped.evaluation.status === :evaluated_full_native_F_and_core_pressure_rows
    @test length(mapped.evaluation.residual) == 10
    @test mapped.receipt.downstream_consumer.status === :evaluated_full_native_F_and_core_pressure_rows
    @test mapped.receipt.downstream_consumer.invocation ===
        :original_candidate_native_profile_and_pressure_residual_evaluator
    @test mapped.receipt.downstream_consumer.consumed_state_sha256 == mapped.receipt.target_state_hash
    @test mapped.receipt.coupled_mhd_global_consumer.status === :evaluated_screen_only
    @test mapped.receipt.coupled_mhd_global_consumer.assembly_status === :assembled
    @test mapped.receipt.coupled_mhd_global_consumer.solver_status === :converged
    @test mapped.receipt.coupled_mhd_global_consumer.state_dofs == length(mapped.state)
    @test mapped.receipt.coupled_mhd_global_consumer.model_hash == global_model.model_hash
    @test mapped.receipt.coupled_mhd_global_consumer.policy_hash == global_policy.policy_hash
    @test mapped.receipt.coupled_mhd_global_consumer.policy_acceptance_ref == "test-only"
    @test mapped.receipt.coupled_mhd_global_consumer.physical_authority === false
    @test mapped.receipt.coupled_mhd_global_consumer.remapped_state_sha256 == mapped.receipt.target_state_hash
    @test mapped.receipt.downstream_consumer.acceptance === :diagnostics_only_thresholds_unfrozen
    @test mapped.receipt.pressure_volume_energy.acceptance ===
        :diagnostics_only_conservation_tolerance_unfrozen
    @test mapped.receipt.plasma_current.acceptance ===
        :diagnostics_only_current_tolerance_unfrozen
    @test mapped.receipt.target_divergence.acceptance ===
        :diagnostics_only_divB_budget_unfrozen
    @test mapped.receipt.target_divergence.production_mhd_operator ===
        :five_point_centered_cylindrical_divB
    @test mapped.receipt.target_divergence.production_stencil_consistency.status ===
        :compared_same_interior
    @test mapped.receipt.target_divergence.production_stencil_consistency.rows > 0
    @test isfinite(mapped.receipt.target_divergence.production_stencil_consistency.max_abs_difference_T_per_m)
    @test isfinite(mapped.receipt.target_divergence.production_stencil_consistency.RMS_difference_T_per_m)
    @test mapped.accepted === false
    @test mapped.formal_up2_credit === false
    wrong_gauge = FusionConceptAI.declared_axisymmetric_remesh_v1(source_domain,
        source_state, (2.0,3.0,4.0), (-1.0,0.0,1.0),
        (false,false,false,false,true,false,false,false,false);
        candidate_identity=(candidate_hash="test-candidate",),
        gauge_anchor=(R_m=3.0,Z_m=0.0,psi_Wb_per_rad=0.6),
        expected_native_field_model_id=:plasma_spline_plus_exact_pf_potential_jet_v1,
        profile_evaluator=original)
    @test wrong_gauge.status === :fail_closed
    wrong_mask = FusionConceptAI.declared_axisymmetric_remesh_v1(source_domain,
        source_state, (2.0,3.0,4.0), (-1.0,0.0,1.0), falses(9);
        candidate_identity=(candidate_hash="test-candidate",),
        gauge_anchor=(R_m=3.0,Z_m=0.0,psi_Wb_per_rad=0.5),
        expected_native_field_model_id=:plasma_spline_plus_exact_pf_potential_jet_v1,
        profile_evaluator=original)
    @test wrong_mask.status === :fail_closed
    boundary_mask = FusionConceptAI.declared_axisymmetric_remesh_v1(source_domain,
        source_state, (2.0,3.0,4.0), (-1.0,0.0,1.0), trues(9);
        candidate_identity=(candidate_hash="test-candidate",),
        gauge_anchor=(R_m=3.0,Z_m=0.0,psi_Wb_per_rad=0.5),
        expected_native_field_model_id=:plasma_spline_plus_exact_pf_potential_jet_v1,
        profile_evaluator=original)
    @test boundary_mask.status === :fail_closed
    wrong_model = FusionConceptAI.declared_axisymmetric_remesh_v1(source_domain,
        source_state, (2.0,3.0,4.0), (-1.0,0.0,1.0),
        (false,false,false,false,true,false,false,false,false);
        candidate_identity=(candidate_hash="test-candidate",),
        gauge_anchor=(R_m=3.0,Z_m=0.0,psi_Wb_per_rad=0.5),
        expected_native_field_model_id=:another_field_model,
        profile_evaluator=original)
    @test wrong_model.status === :fail_closed
    negative_source = copy(source_state); negative_source[17] = -1e-4
    negative_pressure = FusionConceptAI.declared_axisymmetric_remesh_v1(source_domain,
        negative_source, (2.0,3.0,4.0), (-1.0,0.0,1.0),
        (false,false,false,false,true,false,false,false,false);
        candidate_identity=(candidate_hash="test-candidate",),
        gauge_anchor=(R_m=3.0,Z_m=0.0,psi_Wb_per_rad=0.5),
        expected_native_field_model_id=:plasma_spline_plus_exact_pf_potential_jet_v1,
        profile_evaluator=original)
    @test negative_pressure.status === :fail_closed
    failed_consumer = FusionConceptAI.declared_axisymmetric_remesh_v1(source_domain,
        source_state, (2.0,3.0,4.0), (-1.0,0.0,1.0),
        (false,false,false,false,true,false,false,false,false);
        candidate_identity=(candidate_hash="test-candidate",),
        gauge_anchor=(R_m=3.0,Z_m=0.0,psi_Wb_per_rad=0.5),
        expected_native_field_model_id=:plasma_spline_plus_exact_pf_potential_jet_v1,
        profile_evaluator=(data,x)->(status=:numerical_fail,residual=zeros(data.nrows),
            jacobian=spzeros(data.nrows,length(x))))
    @test failed_consumer.status === :fail_closed
    @test failed_consumer.code === :axisymmetric_remesh_rejected
    diagnostic_negative = copy(source_state); diagnostic_negative[1] = 1.0e6
    measured_only = FusionConceptAI.declared_axisymmetric_remesh_v1(source_domain,
        diagnostic_negative, (2.0,3.0,4.0), (-1.0,0.0,1.0),
        (false,false,false,false,true,false,false,false,false);
        candidate_identity=(candidate_hash="test-candidate",),
        gauge_anchor=(R_m=3.0,Z_m=0.0,psi_Wb_per_rad=0.5),
        expected_native_field_model_id=:plasma_spline_plus_exact_pf_potential_jet_v1,
        profile_evaluator=original)
    @test measured_only.status === :evaluated_screen_only
    @test measured_only.accepted === false
    @test measured_only.receipt.source_divergence.max_abs_T_per_m > 0
    @test isfinite(measured_only.receipt.plasma_current.absolute_defect_A)
    @test measured_only.receipt.source_divergence.acceptance ===
        :diagnostics_only_divB_budget_unfrozen
    @test measured_only.receipt.plasma_current.acceptance ===
        :diagnostics_only_current_tolerance_unfrozen
end

@testset "axisymmetric integral units separate current from volume energy" begin
    R=(2.0,4.0); Z=(-1.0,1.0); mask=trues(4)
    mu0=2.0; Jphi=3.0
    Br=Float64[-mu0*Jphi,-mu0*Jphi,mu0*Jphi,mu0*Jphi]
    Bz=zeros(4)
    current=FusionConceptAI._dcm_toroidal_current_v1(R,Z,mask,Br,Bz,mu0)
    @test current.integral_A ≈ Jphi*(R[2]-R[1])*(Z[2]-Z[1]) atol=1e-12
    volume_like=Jphi*2pi*((R[2]^2-R[1]^2)/2)*(Z[2]-Z[1])
    @test !isapprox(current.integral_A,volume_like;rtol=0,atol=1e-12)
    pressure_energy=FusionConceptAI._dcm_pressure_integral_v1(R,Z,mask,ones(4))
    @test pressure_energy ≈ 2pi*((R[2]^2-R[1]^2)/2)*(Z[2]-Z[1]) atol=1e-12
end

@testset "native remesh linear constraint projections" begin
    D=FusionConceptAI
    pressure=D._dcm_nonnegative_integral_projection_v1([2.0,-2.0],[1.0,1.0],0.5)
    @test pressure.values ≈ [0.5,0.0] atol=1e-14
    @test all(>=(0.0),pressure.values)
    @test dot([1.0,1.0],pressure.values) ≈ 0.5 atol=1e-14
    @test length(pressure.active)==1

    R=[1.0,1.5,2.0,2.5]; Z=[-1.0,-0.25,0.5,1.25]
    mask=trues(length(R)*length(Z)); mu0=4pi*1e-7
    psi=[0.2R[i]^2+0.3Z[j]^2+0.1R[i]*Z[j] for i in eachindex(R),j in eachindex(Z)] |> vec
    dr=D._dcm_derivative_matrix_v1(R,length(R),length(Z),true)
    dz=D._dcm_derivative_matrix_v1(Z,length(R),length(Z),false)
    invr=repeat(1.0 ./ R,inner=length(Z))
    Br=-(invr .* (dz*psi)); Bz=invr .* (dr*psi)
    expected=D._dcm_toroidal_current_v1(R,Z,mask,Br,Bz,mu0).integral_A
    row=D._dcm_psi_current_row_v1(R,Z,mask,mu0)
    @test dot(row,psi) ≈ expected rtol=1e-12 atol=1e-12

    evaluator=(data,state)->(status=:evaluated_full_native_F_and_core_pressure_rows,
        residual=[2.0*state[1]+3.0*state[2],5.0*state[2]],jacobian=sparse([2.0 3.0; 0.0 5.0]))
    sample=(status=:evaluated_full_native_F_and_core_pressure_rows,residual=[1.0,4.0],
        jacobian=sparse([2.0 3.0; 0.0 5.0]))
    fd=D.declared_native_profile_fd_probe_v1(evaluator,(;),[0.0,0.0],sample;columns=[1])
    @test fd.status===:evaluated_native_profile_residual_jacobian_fd
end

@testset "production divB diagnostic uses row-local floating-axis spacing" begin
    R=(1.0,1.5,2.000000000000001,2.500000000000001)
    Z=(-1.0,-0.5,1.0e-15,0.500000000000002)
    nr,nz=length(R),length(Z)
    Br=Float64[R[i]^2*1.0e16+Z[j]*1.0e12 for i in 1:nr for j in 1:nz]
    Bz=Float64[Z[j]^2*1.0e16+R[i]*1.0e12 for i in 1:nr for j in 1:nz]
    actual=FusionConceptAI._dcm_axisymmetric_production_divB_v1(R,Z,Br,Bz)
    @test actual.status === :evaluated
    @test actual.production_stencil_accepted
    row=only(filter(r->r.i==2 && r.j==2,actual.rows))
    k=(row.i-1)*nz+row.j
    dr=(R[row.i+1]-R[row.i-1])/2
    dz=(Z[row.j+1]-Z[row.j-1])/2
    expected=(Br[k+nz]-Br[k-nz])/(2dr)+Br[k]/R[row.i]+(Bz[k+1]-Bz[k-1])/(2dz)
    @test row.dr_m == dr
    @test row.dz_m == dz
    @test row.divB_T_per_m == expected
    mean_dr=(R[end]-R[1])/(nr-1); mean_dz=(Z[end]-Z[1])/(nz-1)
    old_global_mean=(Br[k+nz]-Br[k-nz])/(2mean_dr)+Br[k]/R[row.i]+(Bz[k+1]-Bz[k-1])/(2mean_dz)
    @test row.divB_T_per_m != old_global_mean
end

@testset "UP2 candidate-bound two-to-four cross-mesh conservation" begin
    c = _cm_case()
    transfer = declared_cross_mesh_transfer_v1(c.input, c.identity, c.source, c.target,
        (0.25, 0.75); accounts=c.accounts)
    @test transfer.status === :ready
    out = execute_declared_cross_mesh_v1(c.input, c.identity, c.source, c.target,
        (0.25, 0.75); accounts=c.accounts, left_boundary=0.0, right_boundary=1.0)
    @test out.status === :ready
    @test out.code === :one_dimensional_diffusion_solved
    @test out.accepted === false
    @test out.claim_ceiling === :screen_only
    @test out.screen_only
    @test out.formal_up2_credit === false && out.formal_up_credit === false
    @test out.formal_r_credit === false && out.no_up2
    @test out.provider_calls == 0 && out.mesh_calls == 0
    @test out.solver_invocations == 1
    @test length(out.transfer.transferred_state) == 4
    @test out.source_mesh_hash != out.target_mesh_hash
    @test out.transfer.source_integrated_total ≈ 0.5 atol=1e-12
    @test out.transfer.target_integrated_total ≈ 0.5 atol=1e-12
    @test out.transfer.transferred_state == (0.25, 0.25, 0.75, 0.75)
    @test out.transfer.overlap_lengths == [0.25 0.25 0.0 0.0; 0.0 0.0 0.25 0.25]
    @test out.transfer.overlap_proportions == [1.0 1.0 0.0 0.0; 0.0 0.0 1.0 1.0]
    @test abs(out.transfer.global_defect) ≤ 1e-12
    @test out.transfer.source_overlap_coverage ≈ 1.0 atol=1e-12
    @test out.transfer.target_overlap_coverage ≈ 1.0 atol=1e-12
    @test all(abs(x) ≤ 1e-12 for x in out.transfer.local_defects)
    @test length(out.transfer.interface_defects) == 1
    @test all(abs(x) ≤ 1e-12 for x in out.transfer.interface_defects)
    @test out.transfer.interface_faces[1] == "0.5:owner:s1->owner:s2"
    @test out.diffusion.matrix == [8.0 -4.0 0.0 0.0; -4.0 8.0 -4.0 0.0;
        0.0 -4.0 8.0 -4.0; 0.0 0.0 -4.0 8.0]
    @test out.diffusion.rhs == [0.25, 0.25, 0.75, 4.75]
    @test all(isapprox.(out.diffusion.solution, [0.4, 0.7375, 1.0125, 1.1]; atol=1e-12))
    @test out.diffusion.residual_norm ≤ 1e-12
    @test out.diffusion.solver_invocations == 1
end

@testset "UP2 cross-mesh typed negative dispatch" begin
    c = _cm_case()
    negatives = Dict{String,Tuple{Symbol,Symbol}}()
    wrong_candidate = QualifiedRefV1("foreign://candidate", "v5")
    bad_identity = DeclaredCrossMeshIdentityV1(wrong_candidate, c.identity.source_hash,
        c.identity.body_hash, c.identity.bundle_hash, c.identity.axis_hashes)
    x = execute_declared_cross_mesh_v1(c.input, bad_identity, c.source, c.target, (0.25,0.75); accounts=c.accounts)
    negatives["wrong_candidate"] = (x.status,x.code)
    @test x.status === :fail_closed && x.code === :candidate_mismatch

    bad_body = DeclaredCrossMeshIdentityV1(c.identity.candidate_ref, c.identity.source_hash,
        "forged-body-hash", c.identity.bundle_hash, c.identity.axis_hashes)
    x = execute_declared_cross_mesh_v1(c.input, bad_body, c.source, c.target, (0.25,0.75); accounts=c.accounts)
    negatives["wrong_body"] = (x.status,x.code)
    @test x.status === :fail_closed && x.code === :body_hash_mismatch

    outside = declared_cross_mesh_v1(c.identity, :target, "mesh:target-outside", "space:up2",
        (2.0, 2.5, 3.0, 3.5, 4.0); owners=("owner:t1","owner:t2","owner:t3","owner:t4"))
    x = execute_declared_cross_mesh_v1(c.input,c.identity,c.source,outside,(0.25,0.75);accounts=c.accounts)
    negatives["noncovering_overlap"] = (x.status,x.code)
    @test x.status === :terminal_deferred

    bad_orientation = DeclaredCrossMeshAccountsV1(
        c.accounts.source, DeclaredCrossMeshAccountV1("account:target", :target,
            c.accounts.target.unit, :minus, "owner:t1"), c.accounts.external, c.accounts.return_account)
    x = execute_declared_cross_mesh_v1(c.input,c.identity,c.source,c.target,(0.25,0.75);accounts=bad_orientation)
    negatives["orientation"] = (x.status,x.code)
    @test x.status === :fail_closed

    bad_unit = DeclaredCrossMeshAccountsV1(c.accounts.source,
        DeclaredCrossMeshAccountV1("account:target", :target, DeclaredCrossMeshUnitV1("seconds",(0,0,1,0,0,0,0)), :plus, "owner:t1"),
        c.accounts.external,c.accounts.return_account)
    x = execute_declared_cross_mesh_v1(c.input,c.identity,c.source,c.target,(0.25,0.75);accounts=bad_unit)
    negatives["unit"] = (x.status,x.code)
    @test x.status === :fail_closed

    missing = DeclaredCrossMeshAccountsV1(c.accounts.source,c.accounts.target,nothing,c.accounts.return_account)
    x = execute_declared_cross_mesh_v1(c.input,c.identity,c.source,c.target,(0.25,0.75);accounts=missing)
    negatives["missing_external"] = (x.status,x.code)
    @test x.status === :terminal_deferred

    zero_measure = declared_cross_mesh_v1(c.identity,:target,"mesh:zero","space:up2",
        (0.0,0.25,0.5,0.75,1.0);owners=("owner:t1","owner:t2","owner:t3","owner:t4"),
        cell_measures=(0.25,0.25,0.25,0.0))
    x = execute_declared_cross_mesh_v1(c.input,c.identity,c.source,zero_measure,(0.25,0.75);accounts=c.accounts)
    negatives["zero_measure"] = (x.status,x.code)
    @test x.status === :numerical_fail

    mismatched_measure = declared_cross_mesh_v1(c.identity,:target,"mesh:mismatched","space:up2",
        (0.0,0.25,0.5,0.75,1.0);owners=("owner:t1","owner:t2","owner:t3","owner:t4"),
        cell_measures=(0.25,0.25,0.25,0.2501))
    x = execute_declared_cross_mesh_v1(c.input,c.identity,c.source,mismatched_measure,(0.25,0.75);accounts=c.accounts)
    negatives["mismatched_measure"] = (x.status,x.code)
    @test x.status === :fail_closed && x.code === :mismatched_measure

    nonfinite = execute_declared_cross_mesh_v1(c.input,c.identity,c.source,c.target,(NaN,0.75);accounts=c.accounts)
    @test nonfinite.status === :numerical_fail
    shape = execute_declared_cross_mesh_v1(c.input,c.identity,c.source,c.target,(0.25,);accounts=c.accounts)
    @test shape.status === :fail_closed
    wrong_owner = DeclaredCrossMeshAccountsV1(c.accounts.source,
        DeclaredCrossMeshAccountV1("account:target",:target,c.accounts.target.unit,:plus,"owner:foreign"),
        c.accounts.external,c.accounts.return_account)
    owner = execute_declared_cross_mesh_v1(c.input,c.identity,c.source,c.target,(0.25,0.75);accounts=wrong_owner)
    @test owner.status === :fail_closed && owner.code === :owner_mismatch
    forged_mesh = DeclaredCrossMeshV1(c.target.side,c.target.mesh_ref,c.target.space_ref,c.target.cells,
        c.target.dof_ownership,c.target.identity,"forged-mesh-hash")
    mesh_hash = execute_declared_cross_mesh_v1(c.input,c.identity,c.source,forged_mesh,(0.25,0.75);accounts=c.accounts)
    @test mesh_hash.status === :fail_closed && mesh_hash.code === :mesh_hash_mismatch
    wrong_side_0 = DeclaredCrossMeshV1(:source,c.target.mesh_ref,c.target.space_ref,c.target.cells,
        c.target.dof_ownership,c.target.identity,"")
    wrong_side = DeclaredCrossMeshV1(wrong_side_0.side,wrong_side_0.mesh_ref,wrong_side_0.space_ref,
        wrong_side_0.cells,wrong_side_0.dof_ownership,wrong_side_0.identity,
        FusionConceptAI._dcm_hash(FusionConceptAI._dcm_mesh_body(wrong_side_0)))
    side = execute_declared_cross_mesh_v1(c.input,c.identity,c.source,wrong_side,(0.25,0.75);accounts=c.accounts)
    @test side.status === :fail_closed && side.code === :mesh_side_mismatch
    axis_bad = DeclaredCrossMeshIdentityV1(c.identity.candidate_ref,c.identity.source_hash,
        c.identity.body_hash,c.identity.bundle_hash,("wrong-axis",c.identity.axis_hashes[2],c.identity.axis_hashes[3]))
    axis = execute_declared_cross_mesh_v1(c.input,axis_bad,c.source,c.target,(0.25,0.75);accounts=c.accounts)
    @test axis.status === :fail_closed && axis.code === :axis_hash_mismatch

    @test_throws ArgumentError DeclaredCrossMeshUnitV1("nan-scale"; scale_to_si=NaN)
    @test_throws ArgumentError DeclaredCrossMeshUnitV1("zero-scale"; scale_to_si=0.0)
    @test_throws ArgumentError DeclaredCrossMeshUnitV1("negative-scale"; scale_to_si=-1.0)

    # A deliberately overlapping target mesh has exact per-cell geometry but
    # source coverage above one; coverage must be an equality gate, not a
    # lower-bound gate.  The explicit hash keeps this negative on the executor.
    overlap_cells = (DeclaredCrossMeshCellV1("cell:target:1", 0.0, 0.75; owner_ref="owner:t1"),
        DeclaredCrossMeshCellV1("cell:target:2", 0.25, 1.0; owner_ref="owner:t2"))
    overlap_mesh_0 = DeclaredCrossMeshV1(:target, "mesh:overcoverage", "space:up2",
        overlap_cells, ("owner:t1", "owner:t2"), c.identity, "")
    overlap_mesh = DeclaredCrossMeshV1(overlap_mesh_0.side, overlap_mesh_0.mesh_ref,
        overlap_mesh_0.space_ref, overlap_mesh_0.cells, overlap_mesh_0.dof_ownership,
        overlap_mesh_0.identity, FusionConceptAI._dcm_hash(FusionConceptAI._dcm_mesh_body(overlap_mesh_0)))
    x = execute_declared_cross_mesh_v1(c.input,c.identity,c.source,overlap_mesh,(0.25,0.75);accounts=c.accounts)
    negatives["overcoverage"] = (x.status,x.code)
    @test x.status === :terminal_deferred && x.code === :overcovering_overlap

    # Finite arithmetic conservation defects are fail-closed, not numerical
    # failures.  This payload is intentionally large enough to expose a
    # reproducible floating-point defect above the 1e-12 gate.
    defect_mesh = declared_cross_mesh_v1(c.identity,:target,"mesh:defect","space:up2",
        (0.0,0.1,0.4,0.6,0.9,1.0);
        owners=("owner:t1","owner:t2","owner:t3","owner:t4","owner:t5"))
    defect = execute_declared_cross_mesh_v1(c.input,c.identity,c.source,defect_mesh,
        (1.0e15,-999999999999999.0);accounts=c.accounts)
    negatives["nonzero_defect"] = (defect.status,defect.code)
    @test defect.status === :fail_closed && defect.code === :conservation_defect
    # Identity is checked before numeric state, so a foreign candidate cannot
    # be masked by a NaN numerical payload.
    priority = execute_declared_cross_mesh_v1(c.input,bad_identity,c.source,c.target,(NaN,0.75);accounts=c.accounts)
    @test priority.status === :fail_closed && priority.code === :candidate_mismatch
    @test !isempty(negatives)
end

@testset "remesh adapter dispatches only to existing CoupledMHD APIs" begin
    model = _cm_missing_closure_model()
    receipt = FusionConceptAI.declared_axisymmetric_global_consumer_v1(
        _CM_GLOBAL_SOLVER,model,[0.0,1.0],_cm_policy();
        expected_candidate_hash=repeat("a",64))
    @test receipt.status === :typed_absent
    @test receipt.invocation === :existing_inhouse_coupled_mhd_global_assembly_and_solve_v1
    @test receipt.assembly_status === :typed_absent
    @test receipt.solver_status === :typed_absent
    @test !receipt.physical_authority && !receipt.engineering_authority
    @test :pressure_topology in receipt.assembly_missing_closures
    @test :return_current_path in receipt.solver_missing_closures
    mismatch = FusionConceptAI.declared_axisymmetric_global_consumer_v1(
        _CM_GLOBAL_SOLVER,model,[0.0,1.0],_cm_policy();
        expected_candidate_hash=repeat("b",64))
    @test mismatch.status === :fail_closed
end

println("DECLARED_CROSS_MESH_CONSERVATIVE_TRANSFER_V1_JULIA_COMMAND_DEFINED=true")
println("DECLARED_CROSS_MESH_CONSERVATIVE_TRANSFER_V1_JULIA_OR_DESC_EXECUTED=false")
