println("FREEGS_EXEC_TEST_STAGE=file_entry");flush(stdout)
_freegs_exec_stage_t0=time()
println("FREEGS_EXEC_TEST_STAGE=using_Test_BEGIN");flush(stdout)
using Test
println("FREEGS_EXEC_TEST_STAGE=using_Test_END elapsed_s=",time()-_freegs_exec_stage_t0);flush(stdout)
_freegs_exec_stage_t0=time()
println("FREEGS_EXEC_TEST_STAGE=using_SparseArrays_BEGIN");flush(stdout)
using SparseArrays
println("FREEGS_EXEC_TEST_STAGE=using_SparseArrays_END elapsed_s=",time()-_freegs_exec_stage_t0);flush(stdout)
_freegs_exec_stage_t0=time()
println("FREEGS_EXEC_TEST_STAGE=fixture_include_BEGIN");flush(stdout)
include(joinpath(@__DIR__,"runtime_v4_freegs_axisymmetric_lcfs_trace_tests.jl"))
println("FREEGS_EXEC_TEST_STAGE=fixture_include_END elapsed_s=",time()-_freegs_exec_stage_t0);flush(stdout)
_freegs_exec_stage_t0=time()
println("FREEGS_EXEC_TEST_STAGE=using_FusionConceptAI_BEGIN");flush(stdout)
using FusionConceptAI
println("FREEGS_EXEC_TEST_STAGE=using_FusionConceptAI_END elapsed_s=",time()-_freegs_exec_stage_t0);flush(stdout)
_freegs_exec_stage_t0=time()
println("FREEGS_EXEC_TEST_STAGE=example_include_BEGIN");flush(stdout)

include(joinpath(@__DIR__, "..", "examples",
    "runtime_v4_freegs_axisymmetric_execution.jl"))
println("FREEGS_EXEC_TEST_STAGE=example_include_END elapsed_s=",time()-_freegs_exec_stage_t0);flush(stdout)
const F = FreeGSAxisymmetricRuntime
get(ENV,"FUSION_FREEGS_MHD_REGION","0") == "1" &&
    get(ENV,"FUSION_FREEGS_MHD_COMPONENT","0") != "1" &&
    error("regional MHD requires the existing FUSION_FREEGS_MHD_COMPONENT=1 mode")
get(ENV,"FUSION_FREEGS_NATIVE_GRID_MHD","0") == "1" &&
    get(ENV,"FUSION_FREEGS_MHD_COMPONENT","0") != "1" &&
    error("native-grid regional MHD requires FUSION_FREEGS_MHD_COMPONENT=1")
if get(ENV,"FUSION_FREEGS_MHD_COMPONENT","0") == "1"
    Base.include(F,joinpath(@__DIR__,"..","src","RuntimeV4","CandidateCoupledPhysicsV4.jl"))
    Base.include(F,joinpath(@__DIR__,"..","src","RuntimeV4","InHouseCoupledMHDGlobalSolveV1.jl"))
end

# The actual interior subset is only a prepared regional model. These throwing
# providers name missing inputs; no numerical outer/conservation rows are made.
_freegs_unavailable_full_domain_provider(args...) =
    error("actual computational outer/interface/conservation model has not been supplied")
function test_actual_freegs_single_region_preparation(F,context,artifacts;region=nothing)
    prep_started=time()
    println("FREEGS_SINGLE_PREP_ENTER");flush(stdout)
    region === nothing && (region=F.freegs_axisymmetric_mhd_native_grid_region(context,artifacts))
    @test region isa F.FreeGSAxisymmetricMHDRegionV4
    phase_started=time()
    println("FREEGS_SINGLE_CALLBACKS_BEGIN");flush(stdout)
    callbacks=F.freegs_axisymmetric_mhd_regional_callbacks(region)
    println("FREEGS_SINGLE_CALLBACKS_END elapsed_s=",time()-phase_started);flush(stdout)
    S=F.InHouseCoupledMHDGlobalSolveV1
    absent=NamedTuple{S._REQUIRED_CLOSURES}(ntuple(_->nothing,5))
    provider_set=(callbacks.regional_evaluator,_freegs_unavailable_full_domain_provider,
        _freegs_unavailable_full_domain_provider,_freegs_unavailable_full_domain_provider,
        callbacks.jacobian_oracle)
    n=length(region.initial_state); m=length(callbacks.equation_ids)
    phase_started=time()
    println("FREEGS_SINGLE_CONTEXT_HASH_BEGIN");flush(stdout)
    provider_context_hash=S.coupled_mhd_provider_context_hash_v1(provider_set...)
    println("FREEGS_SINGLE_CONTEXT_HASH_END elapsed_s=",time()-phase_started);flush(stdout)
    phase_started=time()
    println("FREEGS_SINGLE_MODEL_BEGIN dofs=",n," rows=",m);flush(stdout)
    model=S.make_global_model_v1(candidate_hash=region.candidate_hash,single_region=true,
        region_ids=(region.region_id,),region_dofs=(n,),pressure_indices=collect(callbacks.pressure_indices),
        regional_equation_ids=(collect(callbacks.equation_ids),),interface_edges=(),
        local_dof_to_global=(collect(1:n),),local_test_row_to_global=(collect(1:m),),
        pressure_indices_global=true,
        outer_constraint_ids=(("unprovided_computational_outer_equations",),),
        global_conservation_ids=("unprovided_full_domain_conservation",),closure_evidence=absent,
        provider_id="prepared/native-grid-interior-with-unprovided-full-domain-model",
        provider_source_path=@__FILE__,provider_context_hash=provider_context_hash,
        regional_evaluator=provider_set[1],interface_evaluator=provider_set[2],outer_evaluator=provider_set[3],
        conservation_evaluator=provider_set[4],jacobian_oracle=provider_set[5])
    println("FREEGS_SINGLE_MODEL_END elapsed_s=",time()-phase_started);flush(stdout)
    phase_started=time()
    println("FREEGS_SINGLE_ASSEMBLY_BEGIN");flush(stdout)
    assembly=S.assemble_coupled_mhd_global_v1(model,collect(region.initial_state))
    println("FREEGS_SINGLE_ASSEMBLY_END elapsed_s=",time()-phase_started," status=",assembly.status);flush(stdout)
    phase_started=time()
    println("FREEGS_SINGLE_ASSERTIONS_BEGIN");flush(stdout)
    @test assembly.status === :typed_absent
    @test assembly.missing_closures == S._REQUIRED_CLOSURES
    @test !assembly.capability_signature.complete
    @test model.local_dof_to_global == (Tuple(1:n),)
    @test model.pressure_indices == Tuple(1:4:n)
    @test model.interface_edges == ()
    @test !assembly.physical_authority
    println("FREEGS_SINGLE_ASSERTIONS_END elapsed_s=",time()-phase_started);flush(stdout)
    normalization=F.freegs_axisymmetric_pressure_axis_normalization_callbacks(context,artifacts,region)
    gauge=normalization.evaluate(region.initial_state)
    gauge_oracle=normalization.jacobian_oracle(region.initial_state)
    mapping=normalization.mapping
    @test normalization.candidate_hash==region.candidate_hash
    @test normalization.upstream_output_hash==region.upstream_output_hash
    @test mapping.target_pressure_Pa==F._freegs_context_binding(context).declaration.profile.axis_pressure_pa
    @test mapping.axis_RZ_m==(artifacts.receipt.summary.magnetic_axis_r_m,artifacts.receipt.summary.magnetic_axis_z_m)
    @test length(mapping.pressure_dofs)==4 && length(unique(mapping.pressure_dofs))==4
    @test all(i->i in callbacks.pressure_indices,mapping.pressure_dofs)
    @test size(gauge.jacobian)==(1,n) && SparseArrays.nnz(gauge.jacobian)==4
    @test maximum(abs,SparseArrays.nonzeros(gauge.jacobian-gauge_oracle);init=0.0)<=64eps(Float64)
    @test gauge.residual==[gauge.axis_pressure_Pa-mapping.target_pressure_Pa]
    @test abs(only(gauge.residual))>1.0 # Actual discrete baseline is not a zero placeholder.
    for (k,column) in enumerate(mapping.pressure_dofs)
        changed=collect(region.initial_state); changed[column]+=1.0
        altered=normalization.evaluate(changed)
        @test isapprox(only(altered.residual)-only(gauge.residual),mapping.weights[k];rtol=0,atol=1e-10)
        @test altered.jacobian==gauge.jacobian
    end
    foreign=(candidate_hash=repeat("0",64),context_hash=context.context_hash)
    @test_throws ArgumentError F.freegs_axisymmetric_pressure_axis_normalization_callbacks(foreign,artifacts,region)
    @test_throws ArgumentError F._ccp_axis_pressure_normalization_map(region,nothing,mapping.target_pressure_Pa)
    @test_throws ArgumentError F._ccp_axis_pressure_normalization_map(region,(NaN,0.0),mapping.target_pressure_Pa)
    @test_throws ArgumentError F._ccp_axis_pressure_normalization_map(region,(0.0,0.0),mapping.target_pressure_Pa)
    @test !normalization.pressure_topology_closed && !normalization.global_conservation_supplied
    @test !normalization.closure_evidence_created && !normalization.coupled_solve_attempted
    @test normalization.missing_closures==S._REQUIRED_CLOSURES
    println("FREEGS_NATIVE_AXIS_PRESSURE_NORMALIZATION_JSON="*canonical_json((
        candidate_hash=region.candidate_hash,upstream_output_hash=region.upstream_output_hash,
        region_hash=region.region_hash,mapping=mapping,residual_Pa=only(gauge.residual),
        evaluated_axis_pressure_Pa=gauge.axis_pressure_Pa,oracle_columns=4,
        oracle_max_abs_error=maximum(abs,SparseArrays.nonzeros(gauge.jacobian-gauge_oracle);init=0.0),
        pressure_topology_closed=false,global_conservation_supplied=false,
        closure_evidence_created=false,coupled_solve_attempted=false)))

    println("FREEGS_SINGLE_REGION_MODEL_PREPARED_JSON="*canonical_json((
        candidate_hash=region.candidate_hash,region_hash=region.region_hash,model_hash=model.model_hash,
        status=assembly.status,missing_closures=assembly.missing_closures,
        native_grid_coverage=region.grid_coverage.kind,regional_dofs=n,regional_rows=m,
        global_assembly_executed=false,coupled_solve_attempted=false,
        computational_outer_model=:not_supplied,conservation_model=:not_supplied,
        physical_validation=false)))
    flush(stdout)
    println("FREEGS_SINGLE_PREP_EXIT elapsed_s=",time()-prep_started);flush(stdout)
end

println("FREEGS_EXEC_TEST_STAGE=typed_binding_testset_BEGIN");flush(stdout)
_freegs_exec_stage_t0=time()
@testset "typed G2 axisymmetric declaration and subject binding" begin
    @test F.validate_forward_chain_context(freegs_context) == freegs_context.context_hash
    @test canonical_hash(freegs_axisymmetric_declaration) ==
        freegs_axisymmetric_declaration.declaration_hash
    expected_fields=freegs_pressure_domain_mode ?
        (freegs_axisymmetric_declaration,freegs_pressure_domain) :
        (freegs_axisymmetric_declaration,)
    @test freegs_candidate.field_geometry_genome_ref.fields == expected_fields
    if freegs_pressure_domain_mode
        domain=freegs_pressure_domain
        @test domain.boundary_node_id==F._FREEGS_LCFS_NODE
        @test domain.exterior_pressure_pa==0.0
        @test domain.classification_rule===:receipt_bound_native_flux_connected_core_mask
        @test domain.open_flux_policy===:exterior_vacuum_even_when_psi_n_below_one
        graph=freegs_candidate.field_geometry_genome_ref.graph
        @test count(n->n.node_id==domain.plasma_region_id && n.node_kind===:region,graph.nodes)==1
        @test count(n->n.node_id==domain.vacuum_region_id && n.node_kind===:region,graph.nodes)==1
        @test count(n->n.node_id==domain.interface_node_id && n.node_kind===:interface,graph.nodes)==1
        @test count(n->n.node_id==domain.boundary_node_id && n.node_kind===:boundary,graph.nodes)==1
        println("FREEGS_EXEC_TEST_STAGE=typed_binding_authored_source_BEGIN");flush(stdout)
        stage_t0=time()
        source=F.freegs_axisymmetric_authored_source_values(freegs_context)
        println("FREEGS_EXEC_TEST_STAGE=typed_binding_authored_source_END elapsed_s=",time()-stage_t0);flush(stdout)
        @test source.exterior_pressure_Pa===0.0
        @test source.boundary_node_id==domain.boundary_node_id
        @test source.pressure_domain_declaration_status===:authored_law_only
        @test source.pressure_domain_geometry_map_status===:typed_absent
        @test source.pressure_domain_consumer_status===:not_executed
        @test source.model_scope===:authored_LCFS_bounded_plasma_and_zero_pressure_exterior_no_delta_sheet_closed_TF
        @test_throws ArgumentError F._freegs_authored_source_values(
            freegs_candidate.mechanism_genome_ref,freegs_candidate.realization_control_genome_ref,
            freegs_axisymmetric_declaration.domain)
        wrong_scope=F.AxisymmetricPressureDomainV1(domain.plasma_region_id,domain.vacuum_region_id*"-other",
            domain.interface_node_id,domain.boundary_node_id,0.0,domain.classification_rule,domain.open_flux_policy)
        @test_throws ArgumentError F._freegs_authored_source_values(
            freegs_candidate.mechanism_genome_ref,freegs_candidate.realization_control_genome_ref,
            freegs_axisymmetric_declaration.domain;pressure_domain=wrong_scope)
        @test_throws ArgumentError F.AxisymmetricPressureDomainV1(domain.plasma_region_id,
            domain.vacuum_region_id,domain.interface_node_id,domain.boundary_node_id,1.0,
            domain.classification_rule,domain.open_flux_policy)
        @test_throws ArgumentError F.AxisymmetricPressureDomainV1(domain.plasma_region_id,
            domain.vacuum_region_id,domain.interface_node_id,domain.boundary_node_id,0.0,
            :psi_n_less_than_one,domain.open_flux_policy)
    else
        @test freegs_pressure_domain===nothing
        if freegs_authored_mode
            expected_declaration_id=freegs_stationary_critical_mode ?
                "authored-stationary-cubic-spline-critical-points-v2" :
                "authored-finite-volume-no-sheet-closed-distributed-TF-v1"
            @test freegs_axisymmetric_declaration.declaration_id==expected_declaration_id
            source=F.freegs_axisymmetric_authored_source_values(freegs_context)
            @test source.pressure_domain===nothing
            @test source.pressure_domain_declaration_status===:typed_absent
            @test source.pressure_domain_geometry_map_status===:typed_absent
            @test source.pressure_domain_consumer_status===:typed_absent
        end
    end
    @test freegs_subject.bindings == (freegs_subject_binding,)
    @test freegs_subject_binding.field_geometry_genome_hash ==
        field_geometry_hash(freegs_candidate.field_geometry_genome_ref)
    @test freegs_subject_binding.field_geometry_graph_hash ==
        canonical_hash(freegs_compiled.field_geometry_graph)
    @test freegs_subject_binding.mission_hash ==
        F._runtime_decl_hash(freegs_mission_payload)
    @test freegs_subject_binding.bounds_hash ==
        F._runtime_decl_hash(freegs_bounds_payload)
    @test freegs_subject_binding.scenario_hash == freegs_context.scenario_hash
    @test canonical_hash(freegs_subject_binding) == freegs_subject_binding.binding_hash
    @test_throws MethodError F.AxisymmetricEquilibriumBindingV4(
        freegs_axisymmetric_declaration, freegs_subject_binding.field_geometry_genome_hash,
        freegs_subject_binding.field_geometry_graph_hash,
        freegs_subject_binding.field_geometry_graph_binding_hash,
        freegs_subject_binding.mission_hash, freegs_subject_binding.bounds_hash,
        freegs_subject_binding.scenario_hash, freegs_subject_binding.binding_hash)
end

println("FREEGS_EXEC_TEST_STAGE=typed_binding_testset_END elapsed_s=",time()-_freegs_exec_stage_t0);flush(stdout)
@testset "strict typed FreeGS input and negative boundaries" begin
    println("FREEGS_EXEC_TEST_STAGE=solver_input_main_BEGIN");flush(stdout)
    stage_t0=time()
    input = F.freegs_axisymmetric_solver_input(freegs_context)
    println("FREEGS_EXEC_TEST_STAGE=solver_input_main_END elapsed_s=",time()-stage_t0);flush(stdout)
    @test input.context_hash == string(freegs_context.context_hash)
    @test input.physical_subject_hash == string(freegs_subject.physical_subject_hash)
    @test input.field_geometry_graph_hash ==
        string(freegs_subject_binding.field_geometry_graph_hash)
    @test input.binding_hash == string(freegs_subject_binding.binding_hash)
    @test input.solver_input.machine.coils isa Tuple
    @test length(input.solver_input.machine.coils) == 4
    @test input.solver_input.domain.boundary == "freeBoundaryHagenow"
    @test input.solver_input.profile.kind == "ConstrainPaxisIp"
    @test !occursin("physical=true", canonical_json(input))
    @test !occursin("freegs_pointcoil_wall_control_v1", canonical_json(input))

    @test_throws ArgumentError F.AxisymmetricDomainV4(0.1, 2.0, -1.0, 1.0, 64, 65)
    @test_throws ArgumentError F.AxisymmetricFilamentCoilV4("", 1.0, 0.0)
    @test_throws ArgumentError F.AxisymmetricSolverControlsV4(1.0, 1.0e-10, 100)
    @test_throws ArgumentError F.AxisymmetricEquilibriumDeclarationV4(
        "too-few-coils", freegs_axisymmetric_declaration.domain,
        freegs_axisymmetric_declaration.coils[1:3],
        freegs_axisymmetric_declaration.profile,
        freegs_axisymmetric_declaration.constraints,
        freegs_axisymmetric_declaration.solver)

    untyped_subject = F.ExecutablePhysicalSubjectV4(
        freegs_compiled.prefix_hash,
        freegs_candidate.canonical_hashes.genome_bundle_hash,
        freegs_compiled.minimality_scope.mission_hash,
        freegs_compiled.minimality_scope.bounds_hash,
        ((binding_kind="caller_dictionary_replacement",),),
        (freegs_scenario,), (materialization="untyped-negative",),
        F.derive_capability_obligations(freegs_compiled))
    untyped_context = F.make_forward_chain_context(
        freegs_candidate, freegs_compiled, registry, freegs_mission_payload,
        freegs_bounds_payload, freegs_comparison_scope, freegs_scenario_scope,
        untyped_subject, freegs_scenario)
    @test_throws ArgumentError F.freegs_axisymmetric_solver_input(untyped_context)

    bad_binding = F.AxisymmetricEquilibriumBindingV4(F._FREEGS_AXISYMMETRIC_TOKEN,
        freegs_subject_binding.declaration,
        digest256_text("foreign-g2-genome"),
        freegs_subject_binding.field_geometry_graph_hash,
        freegs_subject_binding.field_geometry_graph_binding_hash,
        freegs_subject_binding.mission_hash, freegs_subject_binding.bounds_hash,
        freegs_subject_binding.scenario_hash, freegs_subject_binding.binding_hash)
    bad_subject = F.ExecutablePhysicalSubjectV4(
        freegs_compiled.prefix_hash,
        freegs_candidate.canonical_hashes.genome_bundle_hash,
        freegs_compiled.minimality_scope.mission_hash,
        freegs_compiled.minimality_scope.bounds_hash,
        (bad_binding,), (freegs_scenario,), (materialization="forged-negative",),
        F.derive_capability_obligations(freegs_compiled))
    bad_context = F.make_forward_chain_context(
        freegs_candidate, freegs_compiled, registry, freegs_mission_payload,
        freegs_bounds_payload, freegs_comparison_scope, freegs_scenario_scope,
        bad_subject, freegs_scenario)
    @test_throws ArgumentError F.freegs_axisymmetric_solver_input(bad_context)

    # Legacy positional construction preserves the absence/default semantics.
    d = freegs_axisymmetric_declaration
    legacy_constraints = F.AxisymmetricShapeConstraintsV4(
        d.constraints.xpoints_m, d.constraints.isoflux_m, d.constraints.tikhonov_gamma)
    @test F.canonical_hash(legacy_constraints) == F.canonical_hash(d.constraints)
    legacy_input = F.freegs_axisymmetric_solver_input(freegs_context)
    legacy_constraints_payload = (xpoints_m=d.constraints.xpoints_m,
        isoflux_m=d.constraints.isoflux_m, gamma=d.constraints.tikhonov_gamma)
    legacy_solver_input = merge(legacy_input.solver_input,
        (constraints=legacy_constraints_payload,))
    @test canonical_json(legacy_input) == canonical_json(merge(legacy_input,
        (solver_input=legacy_solver_input,)))
    @test legacy_constraints.current_lims_A_per_turn === nothing
    @test legacy_constraints.max_total_current_A === nothing
    per_turn = ntuple(_ -> (-2.0, 2.0), length(d.coils))
    bounded = F.AxisymmetricShapeConstraintsV4(d.constraints.xpoints_m,
        d.constraints.isoflux_m, d.constraints.tikhonov_gamma;
        current_lims_A_per_turn=per_turn, max_total_current_A=5.0)
    @test bounded.current_lims_A_per_turn == per_turn
    @test bounded.max_total_current_A == 5.0
    @test_throws ArgumentError F.AxisymmetricShapeConstraintsV4(d.constraints.xpoints_m,
        d.constraints.isoflux_m, d.constraints.tikhonov_gamma;
        current_lims_A_per_turn=((1.0, -1.0),))
    @test_throws ArgumentError F.AxisymmetricShapeConstraintsV4(d.constraints.xpoints_m,
        d.constraints.isoflux_m, d.constraints.tikhonov_gamma; max_total_current_A=-1.0)
    @test_throws ArgumentError F.AxisymmetricEquilibriumDeclarationV4(
        "qa-current-limit-cardinality", d.domain,
        (d.coils..., F.AxisymmetricFilamentCoilV4("QA_EXTRA", 1.5, 0.0)),
        d.profile, bounded, d.solver)

    base_binding = F._freegs_context_binding(freegs_context)
    bounded_declaration = F.AxisymmetricEquilibriumDeclarationV4(
        "qa-bounded-declaration", d.domain, d.coils, d.profile, bounded, d.solver;
        outer_face_map=d.outer_face_map, exterior_field_model=d.exterior_field_model)
    binding_body = F._freegs_binding_body(F.canonical_hash(bounded_declaration),
        base_binding.field_geometry_genome_hash, base_binding.field_geometry_graph_hash,
        base_binding.field_geometry_graph_binding_hash, base_binding.mission_hash,
        base_binding.bounds_hash, base_binding.scenario_hash)
    bounded_binding = F.AxisymmetricEquilibriumBindingV4(F._FREEGS_AXISYMMETRIC_TOKEN,
        bounded_declaration, base_binding.field_geometry_genome_hash,
        base_binding.field_geometry_graph_hash, base_binding.field_geometry_graph_binding_hash,
        base_binding.mission_hash, base_binding.bounds_hash, base_binding.scenario_hash,
        F.canonical_hash(binding_body))
    bounded_payload = F._freegs_solver_payload(bounded_binding)
    @test bounded_payload.capture_control_result === true
    @test bounded_payload.constraints.current_lims_A_per_turn == per_turn
    @test bounded_payload.constraints.max_total_current_A == 5.0

    ids = Tuple(c.coil_id for c in d.coils)
    currents = Dict(String(id) => 0.0 for id in ids)
    call = (success=true, message="fake optimizer success", iterations=1,
        objective=0.0, candidate_currents_a_per_turn=currents)
    shape_doc(; current_map=currents, calls=(call,)) = F.JSON3.read(F.JSON3.write((
        coil_control=(mode="shape_controlled", status="slsqp_success",
            optimizer_calls=calls, coil_currents_a_per_turn=current_map),)))
    accepted = F._freegs_validate_coil_control(shape_doc(), "shape_controlled",
        ids, (), per_turn, 5.0)
    @test accepted.status === :slsqp_success && accepted.optimizer_calls == 1
    bad_candidate = merge(call, (candidate_currents_a_per_turn=
        merge(currents, Dict(String(first(ids)) => 3.0)),))
    @test_throws ArgumentError F._freegs_validate_coil_control(
        shape_doc(; calls=(bad_candidate,)), "shape_controlled", ids, (), per_turn, 5.0)
    @test_throws ArgumentError F._freegs_validate_coil_control(
        shape_doc(; current_map=merge(currents, Dict(String(first(ids)) => 3.0))),
        "shape_controlled", ids, (), per_turn, 5.0)
    @test_throws ArgumentError F._freegs_validate_coil_control(
        shape_doc(; calls=()), "shape_controlled", ids, (), per_turn, 5.0)

    fixed_rows = Tuple((String(id), 0.25) for id in ids)
    fixed_payload = F._freegs_solver_payload(base_binding;
        coil_current_mode=:fixed_current_forward,
        fixed_coil_currents_A_per_turn=fixed_rows)
    @test fixed_payload.coil_current_mode == "fixed_current_forward"
    @test Tuple(row.current_A_per_turn for row in fixed_payload.machine.coils) ==
        ntuple(_ -> 0.25, length(ids))
    fixed_map = Dict(first(row) => last(row) for row in fixed_rows)
    fixed_doc(calls=()) = F.JSON3.read(F.JSON3.write((coil_control=(
        mode="fixed_current_forward", status="fixed_current_forward",
        optimizer_calls=calls, coil_currents_a_per_turn=fixed_map),)))
    fixed_ok = F._freegs_validate_coil_control(fixed_doc(), "fixed_current_forward",
        ids, fixed_rows, per_turn, 5.0)
    @test fixed_ok.status === :fixed_current_forward && fixed_ok.optimizer_calls == 0
    @test_throws ArgumentError F._freegs_validate_coil_control(fixed_doc(),
        "fixed_current_forward", ids, ((first(ids), 0.5), fixed_rows[2:end]...), per_turn, 5.0)
    @test_throws ArgumentError F._freegs_validate_coil_control(fixed_doc((call,)),
        "fixed_current_forward", ids, fixed_rows, per_turn, 5.0)
end

if freegs_authored_mode || get(ENV,"FUSION_FREEGS_SOURCE_PRECHECK","0")=="1"
println("FREEGS_EXEC_TEST_STAGE=generic_source_testset_BEGIN");flush(stdout)
_freegs_exec_stage_t0=time()
@testset "actual generic G1/G3 no-sheet and closed TF source execution" begin
    domain=freegs_axisymmetric_declaration.domain
    build(;kwargs...)=F.build_freegs_authored_source_genomes(_fixture_mechanism,_fixture_realization,domain;kwargs...)
    println("FREEGS_EXEC_TEST_STAGE=generic_source_build_base_BEGIN");flush(stdout)
    stage_t0=time()
    a=build(); v=a.values
    println("FREEGS_EXEC_TEST_STAGE=generic_source_build_base_END elapsed_s=",time()-stage_t0);flush(stdout)
    @test v.status===:evaluated_authored_G1_G3_sources
    @test v.K_cylindrical_A_per_m==(0.0,0.0,0.0)
    @test v.NI_A_turn==5_000_000.0
    @test v.vacuum_f_tm==1.0
    @test v.closed_path_m[1]==v.closed_path_m[end]
    @test mechanism_hash(a.mechanism)!=mechanism_hash(_fixture_mechanism)
    @test realization_control_hash(a.realization)!=realization_control_hash(_fixture_realization)
    @test F._freegs_authored_source_values(_fixture_mechanism,_fixture_realization,domain).status===:typed_absent
    @test_throws ArgumentError F._freegs_authored_source_values(a.mechanism,_fixture_realization,domain)
    @test_throws ArgumentError F._freegs_authored_source_values(_fixture_mechanism,a.realization,domain)
    b=build(NI_scale=1.1)
    @test isapprox(b.values.NI_A_turn,5_500_000.0;rtol=64eps(Float64))
    @test isapprox(b.values.vacuum_f_tm,1.1;rtol=64eps(Float64))
    @test realization_control_hash(b.realization)!=realization_control_hash(a.realization)
    @test b.values.g3_program_hashes!=v.g3_program_hashes
    @test_throws ArgumentError build(sheet_value=(0.0,1.0,0.0))
    @test_throws ArgumentError build(sheet_unit=F._FREEGS_SOURCE_UNITS.magnetic)
    @test_throws ArgumentError build(NI_scale=NaN)
    @test_throws ArgumentError build(path=((0.08,0.0,-1.2),(0.08,0.0,1.2),
        (2.1,0.0,1.2),(2.1,0.0,-1.2),(0.09,0.0,-1.2)))
    @test_throws ArgumentError build(path=((0.2,0.0,-1.2),(0.2,0.0,1.2),
        (2.1,0.0,1.2),(2.1,0.0,-1.2),(0.2,0.0,-1.2)))
    reverse_source=build(path=reverse(v.closed_path_m))
    @test reverse_source.values.vacuum_f_tm==-v.vacuum_f_tm
    @test_throws ArgumentError F.AxisymmetricConstrainPaxisIpProfileV4(
        10_000.0,1_000_000.0,reverse_source.values.vacuum_f_tm,1.0,2.0,1.0)
    points=((0.1,-1.0),(0.8,0.0),(1.3,0.2),(2.0,1.0))
    ev=F.evaluate_freegs_authored_sources(v;sample_RZ=points)
    shifted=F.evaluate_freegs_authored_sources(v;sample_RZ=points,NI_A_turn=v.NI_A_turn+1000)
    @test maximum(abs.(collect(shifted.TF_Bphi_T)-collect(ev.TF_Bphi_T)-1000*collect(ev.TF_dBphi_dNI_T_per_A)))<1e-13
    @test all(isapprox(2pi*points[i][1]*ev.TF_Bphi_T[i],v.mu0_N_per_A2*v.NI_A_turn;
        rtol=64eps(Float64),atol=0.0) for i in eachindex(points))
    @test_throws ArgumentError F.evaluate_freegs_authored_sources(v;sample_RZ=((0.05,0.0),))
    @test_throws ArgumentError F.evaluate_freegs_authored_sources(v;sample_RZ=points,NI_A_turn=Inf)
    if freegs_authored_mode
        println("FREEGS_EXEC_TEST_STAGE=generic_source_solver_input_BEGIN");flush(stdout)
        stage_t0=time()
        input=F.freegs_axisymmetric_solver_input(freegs_context)
        println("FREEGS_EXEC_TEST_STAGE=generic_source_solver_input_END elapsed_s=",time()-stage_t0);flush(stdout)
        println("FREEGS_EXEC_TEST_STAGE=generic_source_binding_BEGIN");flush(stdout)
        stage_t0=time()
        bound=F.freegs_axisymmetric_authored_source_values(freegs_context;sample_RZ=points)
        println("FREEGS_EXEC_TEST_STAGE=generic_source_binding_END elapsed_s=",time()-stage_t0);flush(stdout)
        @test input.solver_input.profile.vacuum_f_tm==bound.vacuum_f_tm
        @test bound.candidate_hash==string(freegs_context.candidate_hash)
        @test bound.mechanism_hash==string(mechanism_hash(freegs_candidate.mechanism_genome_ref))
        @test bound.realization_hash==string(realization_control_hash(freegs_candidate.realization_control_genome_ref))
        # A changed candidate-owned NI cannot reuse the old G2 vacuum F input.
        changed=CandidateStatePackageV4("authored-TF-NI-mismatch-negative",_fixture_mission,
            b.mechanism,freegs_field_genome,b.realization,registry)
        compiled=F.compile_candidate(changed,registry;mission_payload=freegs_mission_payload,
            bounds_payload=freegs_bounds_payload,comparison_scope=freegs_comparison_scope,
            scenario_scope=freegs_scenario_scope)
        binding=F.make_axisymmetric_equilibrium_binding(compiled,registry,freegs_mission_payload,
            freegs_bounds_payload,freegs_comparison_scope,freegs_scenario_scope,freegs_scenario,
            freegs_axisymmetric_declaration)
        subject=F.ExecutablePhysicalSubjectV4(compiled.prefix_hash,
            changed.canonical_hashes.genome_bundle_hash,compiled.minimality_scope.mission_hash,
            compiled.minimality_scope.bounds_hash,(binding,),(freegs_scenario,),
            (materialization="authored-NI-mismatch-negative",),F.derive_capability_obligations(compiled))
        changed_context=F.make_forward_chain_context(changed,compiled,registry,freegs_mission_payload,
            freegs_bounds_payload,freegs_comparison_scope,freegs_scenario_scope,subject,freegs_scenario)
        @test changed_context.candidate_hash!=freegs_context.candidate_hash
        @test_throws ArgumentError F.freegs_axisymmetric_solver_input(changed_context)
    end
    println("FREEGS_AUTHORED_SOURCE_PRECHECK_JSON="*canonical_json((
        status=:executed_generic_source_programs,authored_mode=freegs_authored_mode,
        candidate_hash=string(freegs_context.candidate_hash),g1_program_hash=v.g1_program_hash,
        g3_program_hashes=v.g3_program_hashes,NI_A_turn=v.NI_A_turn,vacuum_f_tm=v.vacuum_f_tm,
        K_A_per_m=v.K_cylindrical_A_per_m,closed_path_m=v.closed_path_m,
        TF_scope=:independent_source_not_internal_plasma_total,
        old_candidate_laws=:typed_absent,physical_validation=false,engineering_validation=false)))
    flush(stdout)
end
println("FREEGS_EXEC_TEST_STAGE=generic_source_testset_END elapsed_s=",time()-_freegs_exec_stage_t0);flush(stdout)
end
if get(ENV,"FUSION_FREEGS_SOURCE_PRECHECK","0")=="1"
    replay_dir=get(ENV,"FUSION_FREEGS_LCFS_REPLAY_ARTIFACT_DIRECTORY","")
    if !isempty(replay_dir)
        dir=abspath(replay_dir)
        input_json=read(joinpath(dir,"solver_input.canonical.json"),String)
        output_json=read(joinpath(dir,"solver_output.json"),String)
        receipt_json=read(joinpath(dir,"execution_receipt.canonical.json"),String)
        saved=F.JSON3.read(receipt_json); input=F.JSON3.read(input_json)
        replay_stdout=isfile(joinpath(dir,"solver_stdout.raw")) ?
            read(joinpath(dir,"solver_stdout.raw"),String) : String(saved.stdout)
        replay_stderr=isfile(joinpath(dir,"solver_stderr.raw")) ?
            read(joinpath(dir,"solver_stderr.raw"),String) : String(saved.stderr)
        binding=F._freegs_context_binding(freegs_context)
        points=Tuple((Float64(p[1]),Float64(p[2])) for p in input.solver_input.sample_points_rz_m)
        @testset "saved authored LCFS bytes through existing consumer" begin
            @test freegs_authored_mode
            parsed=F._freegs_parse_summary(replay_stdout,freegs_context,binding,output_json;
                sample_points_rz_m=points,sample_constitutive_fields=input.solver_input.sample_constitutive_fields,
                sample_lcfs_trace=input.solver_input.sample_lcfs_trace)
            receipt=F._freegs_make_receipt(freegs_context,binding;status=parsed.status,
                interpreter_hash=F.Digest256(saved.interpreter_hash.value),runner_code_hash=F.Digest256(saved.runner_code_hash.value),
                freegs_version=parsed.freegs_version,environment_hash=parsed.environment_hash,
                input_hash=F._freegs_sha256_text(input_json),backend_input_hash=parsed.backend_input_hash,
                output_hash=F._freegs_sha256_text(output_json),backend_result_hash=parsed.result_hash,
                stdout=replay_stdout,stderr=replay_stderr,exit_code=saved.exit_code,summary=parsed.summary,
                gap_kind=parsed.gap_kind,reason=parsed.reason)
            @test F.canonical_json(receipt)*"\n"==receipt_json
            # Saved producer hashes remain receipt history; byte fidelity is
            # established by the reconstructed receipt and actual input/output.
            tampered_receipt_json=replace(receipt_json,
                string(receipt.runner_code_hash)=>string(F._freegs_sha256_text("tampered historical runner hash"));
                count=1)
            @test tampered_receipt_json!=receipt_json
            validate_saved_receipt_bytes = function(raw_receipt_json)
                F.canonical_json(receipt)*"\n"==raw_receipt_json ||
                    throw(ArgumentError("saved execution receipt bytes mismatch"))
                F.validate_freegs_axisymmetric_receipt(freegs_context,receipt)
            end
            @test_throws ArgumentError validate_saved_receipt_bytes(tampered_receipt_json)
            @test F.validate_freegs_axisymmetric_receipt(freegs_context,receipt)==receipt.receipt_hash
            accepted_samples=F._freegs_accepted_field_samples(parsed,receipt.status,receipt.exit_code)
            source_response=F._freegs_read_hagenow_source_response(dir,output_json)
            if F._freegs_hagenow_source_metadata(F.JSON3.read(output_json))===nothing
                @test source_response===nothing
            else
                @test source_response!==nothing
            end
            legacy_three=F.FreeGSAxisymmetricExecutionArtifactsV4(receipt,input_json,output_json)
            legacy_four=F.FreeGSAxisymmetricExecutionArtifactsV4(receipt,input_json,output_json,accepted_samples)
            @test legacy_three.hagenow_source_response===nothing
            @test legacy_four.hagenow_source_response===nothing
            artifacts=F.FreeGSAxisymmetricExecutionArtifactsV4(receipt,input_json,output_json,
                accepted_samples,source_response)
            native_region=nothing
            if get(ENV,"FUSION_FREEGS_NATIVE_GRID_MHD","0") == "1"
                native_region=F.freegs_axisymmetric_mhd_native_grid_region(freegs_context,artifacts)
                native_region isa F.FreeGSAxisymmetricMHDRegionV4 ||
                    error("saved native input did not produce an actual regional cross map")
                indices=first(native_region.sample_stencils)
                @test length(indices)==5 && length(unique(indices))==5
                @test all(i->begin
                    c=artifacts.field_samples_rz_m[i].constitutive
                    c.status===:present && c.core_mask==1.0 && 0<c.psi_normalized<1
                end,indices)
            else
                indices=Tuple(length(points)-5:length(points)-1)
            end
            full_profile_trace=test_actual_freegs_lcfs_trace(F,freegs_context,artifacts,indices)
            if native_region !== nothing
                # Reuse the exact trace built by the LCFS tests, then call the
                # full-profile test as a sibling as in the fresh consumer.
                println("FREEGS_SAVED_FULL_PROFILE_CALL_BEGIN");flush(stdout)
                try
                    Base.invokelatest(test_actual_freegs_full_support_profile,F,freegs_context,artifacts,full_profile_trace,native_region)
                catch profile_error
                    profile_bt=catch_backtrace()
                    println(stderr,"FREEGS_SAVED_FULL_PROFILE_CALL_ERROR type=",typeof(profile_error))
                    for (frame_index,frame) in enumerate(Iterators.take(stacktrace(profile_bt,true),20))
                        println(stderr,"FREEGS_SAVED_FULL_PROFILE_FRAME ",frame_index,
                            " func=",frame.func," file=",frame.file," line=",frame.line,
                            " from_c=",frame.from_c," inlined=",frame.inlined)
                    end
                    flush(stderr)
                    rethrow()
                end
                println("FREEGS_SAVED_FULL_PROFILE_CALL_RETURNED");flush(stdout)
                println("FREEGS_BEFORE_SINGLE_PREP");flush(stdout)
                test_actual_freegs_single_region_preparation(F,freegs_context,artifacts;region=native_region)
                println("FREEGS_AFTER_SINGLE_PREP");flush(stdout)
            end
        end
        println("FREEGS_SAVED_AUTHORED_LCFS_HELPER_PRECHECK_COMPLETE")
    end
    println("FREEGS_AUTHORED_SOURCE_PRECHECK_COMPLETE_NO_PROVIDER_CALLS")
    flush(stdout)
    exit(0)
end

@testset "real pinned FreeGS integration is screen-only" begin
    artifacts = F.execute_freegs_axisymmetric_screen(freegs_context)
    receipt = artifacts.receipt
    current_runner_hash=F._freegs_sha256_file(F._FREEGS_CONTROLLED_RUNNER)
    current_interpreter_hash=F._freegs_sha256_file(F._FREEGS_PINNED_PYTHON)
    @test receipt.runner_code_hash==current_runner_hash
    @test receipt.interpreter_hash==current_interpreter_hash
    @test F._freegs_assert_current_execution_producer_hashes(
        current_runner_hash,current_interpreter_hash)===nothing
    @test_throws ArgumentError F._freegs_assert_current_execution_producer_hashes(
        F._freegs_sha256_text("changed runner"),current_interpreter_hash)
    @test_throws ArgumentError F._freegs_assert_current_execution_producer_hashes(
        current_runner_hash,F._freegs_sha256_text("changed interpreter"))
    @test receipt.status == :physical_model_screen
    @test receipt.exit_code == 0
    @test receipt.freegs_version == "0.8.2"
    @test receipt.summary !== nothing
    @test receipt.summary.iterations > 0
    @test receipt.summary.final_relative_change <= freegs_axisymmetric_declaration.solver.rtol
    @test receipt.input_hash == F._freegs_sha256_text(artifacts.input_json)
    @test receipt.output_hash == F._freegs_sha256_text(artifacts.output_json)
    @test_throws ArgumentError F._freegs_parse_summary(receipt.stdout,
        freegs_context, freegs_subject_binding, artifacts.output_json * "tampered")
    @test F.validate_freegs_axisymmetric_receipt(freegs_context, receipt) ==
        receipt.receipt_hash
    @test receipt.claim_ceiling == screen_only
    @test !receipt.physical_validation
    @test !receipt.engineering_validation
    @test !receipt.p5_ready
    @test !receipt.terminal_authority
    default_parsed = F._freegs_parse_summary(receipt.stdout, freegs_context,
        freegs_subject_binding, artifacts.output_json)
    @test propertynames(default_parsed) == (:status, :freegs_version, :environment_hash,
        :result_hash, :backend_input_hash, :summary, :field_samples_rz_m, :gap_kind, :reason)

    test_currents = Tuple((String(c.coil_id), 0.0) for c in freegs_axisymmetric_declaration.coils)
    cold_forward = F.freegs_axisymmetric_solver_input(freegs_context;
        coil_current_mode=:fixed_current_forward,
        fixed_coil_currents_A_per_turn=test_currents)
    cold_expected = F.freegs_axisymmetric_solver_input(freegs_context;
        coil_current_mode=:fixed_current_forward,
        fixed_coil_currents_A_per_turn=test_currents, initial_plasma_psi_wb_per_rad=nothing)
    @test canonical_json(cold_forward) * "\n" == canonical_json(cold_expected) * "\n"
    @test !hasproperty(cold_forward.solver_input, :initial_plasma_psi_wb_per_rad)
    source_psi = fill(0.125, freegs_axisymmetric_declaration.domain.nx,
        freegs_axisymmetric_declaration.domain.ny)
    warm_forward = F.freegs_axisymmetric_solver_input(freegs_context;
        coil_current_mode=:fixed_current_forward,
        fixed_coil_currents_A_per_turn=test_currents,
        initial_plasma_psi_wb_per_rad=source_psi)
    warm_psi = warm_forward.solver_input.initial_plasma_psi_wb_per_rad
    @test warm_psi == Tuple(Tuple(Float64(v) for v in row) for row in eachrow(source_psi))
    @test length(warm_psi) == freegs_axisymmetric_declaration.domain.nx
    @test all(row -> length(row) == freegs_axisymmetric_declaration.domain.ny, warm_psi)
    @test all(isfinite, Iterators.flatten(warm_psi))
    @test_throws ArgumentError F.freegs_axisymmetric_solver_input(freegs_context;
        coil_current_mode=:fixed_current_forward,
        fixed_coil_currents_A_per_turn=test_currents,
        initial_plasma_psi_wb_per_rad=fill(0.0,
            freegs_axisymmetric_declaration.domain.nx - 1,
            freegs_axisymmetric_declaration.domain.ny))
    nonfinite_psi = [collect(row) for row in warm_psi]
    nonfinite_psi[1][1] = NaN
    @test_throws ArgumentError F.freegs_axisymmetric_solver_input(freegs_context;
        coil_current_mode=:fixed_current_forward,
        fixed_coil_currents_A_per_turn=test_currents,
        initial_plasma_psi_wb_per_rad=nonfinite_psi)
    rows_forward = F.freegs_axisymmetric_solver_input(freegs_context;
        coil_current_mode=:fixed_current_forward,
        fixed_coil_currents_A_per_turn=test_currents,
        initial_plasma_psi_wb_per_rad=[collect(row) for row in eachrow(source_psi)])
    @test rows_forward.solver_input.initial_plasma_psi_wb_per_rad == warm_psi
    ragged_psi = [collect(row) for row in eachrow(source_psi)]
    ragged_psi[1] = ragged_psi[1][1:end-1]
    @test_throws ArgumentError F.freegs_axisymmetric_solver_input(freegs_context;
        coil_current_mode=:fixed_current_forward,
        fixed_coil_currents_A_per_turn=test_currents,
        initial_plasma_psi_wb_per_rad=ragged_psi)
    @test_throws ArgumentError F.freegs_axisymmetric_solver_input(freegs_context;
        coil_current_mode=:shape_controlled,
        initial_plasma_psi_wb_per_rad=source_psi)
    nonfinite_psi[1][1] = Inf
    @test_throws ArgumentError F.freegs_axisymmetric_solver_input(freegs_context;
        coil_current_mode=:fixed_current_forward,
        fixed_coil_currents_A_per_turn=test_currents,
        initial_plasma_psi_wb_per_rad=nonfinite_psi)

    # Synthetic payloads exercise current handback byte hashes without a second solve.
    handback_ids = Tuple(c.coil_id for c in freegs_axisymmetric_declaration.coils)
    handback_currents = Dict(String(id) => 0.0 for id in handback_ids)
    handback_call = (success=true, message="synthetic QA receipt", iterations=1,
        objective=0.0, candidate_currents_a_per_turn=handback_currents)
    handback_result_hash = F._freegs_sha256_text("synthetic QA backend result")
    handback_input = canonical_json(F.freegs_axisymmetric_solver_input(
        freegs_context; capture_control_result=true)) * "\n"
    handback_output = F.JSON3.write((result_hash=string(handback_result_hash),
        context_hash=string(freegs_context.context_hash),
        binding_hash=string(freegs_subject_binding.binding_hash),
        coil_control=(mode="shape_controlled", status="slsqp_success",
            optimizer_calls=(handback_call,),
            coil_currents_a_per_turn=handback_currents))) * "\n"
    handback_receipt = F.FreeGSAxisymmetricExecutionReceiptV4(
        F._FREEGS_AXISYMMETRIC_TOKEN, :physical_model_screen,
        receipt.context_hash, receipt.physical_subject_hash, receipt.scenario_hash,
        receipt.binding_hash, receipt.interpreter_path, receipt.interpreter_hash,
        receipt.runner_path, receipt.runner_code_hash, receipt.freegs_version,
        receipt.environment_hash, F._freegs_sha256_text(handback_input),
        receipt.backend_input_hash, F._freegs_sha256_text(handback_output),
        handback_result_hash, receipt.stdout, receipt.stderr, 0, receipt.summary,
        :none, "synthetic hash-bound handback test")
    handback_artifacts = F.FreeGSAxisymmetricExecutionArtifactsV4(
        handback_receipt, handback_input, handback_output)
    @test F.freegs_optimized_coil_current_state(freegs_context, handback_artifacts) ==
        Tuple((String(id), 0.0) for id in handback_ids)
    @test_throws ArgumentError F.freegs_optimized_coil_current_state(freegs_context,
        F.FreeGSAxisymmetricExecutionArtifactsV4(handback_receipt,
            handback_input * "tampered", handback_output))
    @test_throws ArgumentError F.freegs_optimized_coil_current_state(freegs_context,
        F.FreeGSAxisymmetricExecutionArtifactsV4(handback_receipt,
            handback_input, handback_output * "tampered"))
end

@testset "FreeGS RZ field sample input, parser, and accepted result" begin
    declaration = freegs_axisymmetric_declaration
    default_input = F.freegs_axisymmetric_solver_input(freegs_context)
    @test propertynames(default_input.solver_input) ==
        (:machine, :domain, :profile, :constraints, :solver)
    @test !hasproperty(default_input.solver_input, :sample_points_rz_m)
    empty_input = F.freegs_axisymmetric_solver_input(freegs_context;
        sample_points_rz_m=())
    @test canonical_json(default_input) == canonical_json(empty_input)
    default_input_bytes = canonical_json(default_input) * "\n"
    empty_input_bytes = canonical_json(empty_input) * "\n"
    @test default_input_bytes == empty_input_bytes
    @test F._freegs_sha256_text(default_input_bytes) == F._freegs_sha256_text(empty_input_bytes)

    domain = declaration.domain
    points = ((domain.r_min_m, domain.z_min_m), (1.15, 0.0),
        (domain.r_max_m, domain.z_max_m), (1.15, 0.0))
    @test F._freegs_sample_points(points, domain) == points
    @test_throws ArgumentError F._freegs_sample_points(((domain.r_min_m - 0.01, 0.0),), domain)
    @test_throws ArgumentError F._freegs_sample_points(((domain.r_min_m, domain.z_min_m - 0.01),), domain)
    @test_throws ArgumentError F._freegs_sample_points(((NaN, 0.0),), domain)
    @test_throws ArgumentError F._freegs_sample_points(((1.0, Inf),), domain)
    @test_throws ArgumentError F._freegs_sample_points(((true, 0.0),), domain)
    @test_throws ArgumentError F._freegs_sample_points(((1.0,),), domain)

    requested = ((1.0, -0.2), (1.4, 0.3))
    rows = ((R_m=1.0, Z_m=-0.2, psi_wb_per_rad=0.8, Br_T=0.3, Bz_T=1.2),
        (R_m=1.4, Z_m=0.3, psi_wb_per_rad=1.7, Br_T=1.7, Bz_T=1.1))
    valid_json = F.JSON3.write((field_samples_rz_m=rows,))
    parsed = F._freegs_parse_field_samples(valid_json, requested)
    @test length(parsed) == 2
    @test Tuple((row.R_m, row.Z_m) for row in parsed) == requested
    @test propertynames(first(parsed)) == (:R_m, :Z_m, :psi_wb_per_rad, :Br_T, :Bz_T)
    @test all(isfinite, (value for row in parsed for value in values(row)))
    @test F._freegs_accepted_field_samples((field_samples_rz_m=parsed,),
        :physical_model_screen, 0) == parsed
    @test isempty(F._freegs_accepted_field_samples((field_samples_rz_m=parsed,),
        :recoverable_gap_unknown, 0))
    @test isempty(F._freegs_accepted_field_samples((field_samples_rz_m=parsed,),
        :physical_model_screen, 1))
    @test_throws ArgumentError F._freegs_parse_field_samples("{}", requested)
    @test_throws ArgumentError F._freegs_parse_field_samples(
        F.JSON3.write((field_samples_rz_m=(rows[1],),)), requested)
    wrong_order = reverse(rows)
    @test_throws ArgumentError F._freegs_parse_field_samples(
        F.JSON3.write((field_samples_rz_m=wrong_order,)), requested)
    wrong_fields = ((R_m=1.0, Z_m=-0.2, psi_wb_per_rad=0.8, Br_T=0.3), rows[2])
    @test_throws ArgumentError F._freegs_parse_field_samples(
        F.JSON3.write((field_samples_rz_m=wrong_fields,)), requested)
    wrong_coordinate = ((R_m=1.01, Z_m=-0.2, psi_wb_per_rad=0.8, Br_T=0.3, Bz_T=1.2), rows[2])
    @test_throws ArgumentError F._freegs_parse_field_samples(
        F.JSON3.write((field_samples_rz_m=wrong_coordinate,)), requested)
    null_value = ((R_m=1.0, Z_m=-0.2, psi_wb_per_rad=nothing, Br_T=0.3, Bz_T=1.2), rows[2])
    @test_throws ArgumentError F._freegs_parse_field_samples(
        F.JSON3.write((field_samples_rz_m=null_value,)), requested)
    bool_value = ((R_m=1.0, Z_m=-0.2, psi_wb_per_rad=true, Br_T=0.3, Bz_T=1.2), rows[2])
    @test_throws ArgumentError F._freegs_parse_field_samples(
        F.JSON3.write((field_samples_rz_m=bool_value,)), requested)

    sample_points = ((1.0, -0.2), (1.4, 0.3), (1.0, -0.2))
    artifacts = F.execute_freegs_axisymmetric_screen(freegs_context;
        sample_points_rz_m=sample_points)
    receipt = artifacts.receipt
    @test receipt.status == :physical_model_screen
    @test receipt.exit_code == 0
    @test length(artifacts.field_samples_rz_m) == length(sample_points)
    @test Tuple((row.R_m, row.Z_m) for row in artifacts.field_samples_rz_m) == sample_points
    @test all(isfinite, (value for row in artifacts.field_samples_rz_m for value in values(row)))
    @test F.JSON3.read(artifacts.output_json)[:field_samples_rz_m] !== nothing
    summary_line = only(filter(line -> startswith(line, "FUSION_FREEGS_V4\t"),
        split(receipt.stdout, '\n')))
    summary_fields = split(summary_line, '\t'; keepempty=true)
    @test length(summary_fields) == 24
    @test length(summary_fields[9:22]) == 14
    @test receipt.claim_ceiling == screen_only
    @test !receipt.physical_validation && !receipt.engineering_validation
    @test !receipt.p5_ready && !receipt.terminal_authority
    println("FREEGS_RZ_SAMPLE_ACTUAL_JSON=" * canonical_json((
        context_hash=string(freegs_context.context_hash),
        binding_hash=string(freegs_subject_binding.binding_hash),
        output_hash=string(receipt.output_hash), result_hash=string(receipt.backend_result_hash),
        field_samples_rz_m=artifacts.field_samples_rz_m)))
    flush(stdout)
end


@testset "FreeGS final-psi constitutive sampling is opt-in and support-limited" begin
    domain = freegs_axisymmetric_declaration.domain
    @test_throws ArgumentError F.freegs_axisymmetric_solver_input(freegs_context;
        sample_constitutive_fields=true)
    ordinary = F.freegs_axisymmetric_solver_input(freegs_context;
        sample_points_rz_m=((1.0, 0.0),))
    explicit_false = F.freegs_axisymmetric_solver_input(freegs_context;
        sample_points_rz_m=((1.0, 0.0),), sample_constitutive_fields=false)
    @test canonical_json(ordinary) == canonical_json(explicit_false)
    @test !hasproperty(ordinary.solver_input, :sample_constitutive_fields)
    present = (status="present", reason="native_core_final_psi",
        native_R_m=1.0, native_Z_m=0.0, psi_normalized=0.5,
        Btor_T=1.1, pressure_Pa=100.0, Jphi_A_per_m2=1000.0,
        psi_native_wb_per_rad=0.8, psi_axis_wb_per_rad=0.4, psi_boundary_wb_per_rad=1.2,
        core_mask=1.0, pprime_Pa_per_flux=500.0, ffprime_T2_m2_per_flux=500.0 * 4e-7pi,
        mu0_N_per_A2=4e-7pi)
    numerical_fields = propertynames(present)[3:end]
    absent = merge((status="typed_absent", reason="not_native_grid"),
        NamedTuple{numerical_fields}(ntuple(_ -> nothing, length(numerical_fields))))
    row = (R_m=1.0, Z_m=0.0, psi_wb_per_rad=0.8, Br_T=0.3, Bz_T=1.2)
    parse_row = c -> only(F._freegs_parse_field_samples(
        F.JSON3.write((field_samples_rz_m=(merge(row, (constitutive=c,)),),)),
        ((1.0, 0.0),); sample_constitutive_fields=true)).constitutive
    @test parse_row(present).status === :present
    @test parse_row(absent).status === :typed_absent
    for bad in (merge(present, (Btor_T=nothing,)), merge(present, (pressure_Pa=true,)),
            merge(present, (psi_normalized=1.1,)),
            merge(present, (native_R_m=1.01,)), merge(present, (reason="not_native_grid",)),
            merge(present, (core_mask=0.5,)), merge(present, (mu0_N_per_A2=0.0,)),
            merge(present, (psi_boundary_wb_per_rad=0.4,)),
            merge(absent, (Jphi_A_per_m2=0.0,)), merge(absent, (reason="unknown",)))
        @test_throws ArgumentError parse_row(bad)
    end
    @test_throws ArgumentError F._freegs_parse_constitutive(
        Dict{Symbol,Any}(pairs(merge(present, (Jphi_A_per_m2=Inf,)))), 1.0, 0.0)
    @test_throws ArgumentError F._freegs_parse_field_samples(
        F.JSON3.write((field_samples_rz_m=(row,),)), ((1.0, 0.0),);
        sample_constitutive_fields=true)
    @test_throws ArgumentError F._freegs_parse_field_samples(
        F.JSON3.write((field_samples_rz_m=(merge(row, (constitutive=present,)),),)),
        ((1.0, 0.0),))

    # All midplane native points ensure an actual supported interior point is
    # exercised, alongside nonnative points and domain boundaries; order/duplicates stay exact.
    native_grid_mode = get(ENV,"FUSION_FREEGS_NATIVE_GRID_MHD","0") == "1"
    native = Tuple((R, 0.0) for R in range(domain.r_min_m, domain.r_max_m; length=domain.nx))
    component_points = if get(ENV,"FUSION_FREEGS_MHD_COMPONENT","0") == "1"
        rnodes = range(domain.r_min_m,domain.r_max_m;length=domain.nx)
        znodes = range(domain.z_min_m,domain.z_max_m;length=domain.ny)
        i = 1+5*(domain.nx-1)÷8; j = (domain.ny+1)÷2
        ((rnodes[i],znodes[j]),(rnodes[i-1],znodes[j]),(rnodes[i+1],znodes[j]),
            (rnodes[i],znodes[j-1]),(rnodes[i],znodes[j+1]))
    else
        ()
    end
    region_points = if get(ENV,"FUSION_FREEGS_MHD_REGION","0") == "1"
        rnodes = range(domain.r_min_m,domain.r_max_m;length=domain.nx)
        znodes = range(domain.z_min_m,domain.z_max_m;length=domain.ny)
        ic = 1+5*(domain.nx-1)÷8; jc = (domain.ny+1)÷2
        ((Tuple((rnodes[ic+d],znodes[jc]) for d in -2:2))...,
         (Tuple((rnodes[ic+d],znodes[jc+e]) for d in -1:1 for e in (-1,1)))...)
    else
        ()
    end
    points = native_grid_mode ? F.freegs_axisymmetric_mhd_native_grid_sample_points(freegs_context) :
        ((1.0, -0.2), (domain.r_min_m, domain.z_min_m), native...,
         (domain.r_max_m, domain.z_max_m), region_points..., component_points..., (1.0, -0.2))
    requested_artifact_directory = native_grid_mode ?
        get(ENV,"FUSION_FREEGS_NATIVE_GRID_ARTIFACT_DIRECTORY","") :
        get(ENV,"FUSION_FREEGS_ARTIFACT_DIRECTORY","")
    native_grid_mode && isempty(requested_artifact_directory) &&
        error("native-grid FreeGS run requires FUSION_FREEGS_NATIVE_GRID_ARTIFACT_DIRECTORY")
    artifact_directory = isempty(requested_artifact_directory) ? nothing : abspath(requested_artifact_directory)
    artifact_directory === nothing || !ispath(artifact_directory) ||
        error("FreeGS provider artifact directory must be fresh")
    lcfs_mode=get(ENV,"FUSION_FREEGS_LCFS_TRACE","0")=="1"
    lcfs_mode && isempty(component_points) && error("LCFS topology gate requires FUSION_FREEGS_MHD_COMPONENT=1")
    artifacts = F.execute_freegs_axisymmetric_screen(freegs_context;
        artifact_directory=artifact_directory,
        sample_points_rz_m=points, sample_constitutive_fields=true,sample_lcfs_trace=(lcfs_mode || native_grid_mode))
    if artifact_directory !== nothing
        write(joinpath(artifact_directory,"solver_stdout.raw"),artifacts.receipt.stdout)
        write(joinpath(artifact_directory,"solver_stderr.raw"),artifacts.receipt.stderr)
        @test read(joinpath(artifact_directory,"solver_input.canonical.json"),String) == artifacts.input_json
        @test read(joinpath(artifact_directory,"solver_output.json"),String) == artifacts.output_json
        @test read(joinpath(artifact_directory,"execution_receipt.canonical.json"),String) == canonical_json(artifacts.receipt)*"\n"
        @test read(joinpath(artifact_directory,"solver_stdout.raw"),String) == artifacts.receipt.stdout
        @test read(joinpath(artifact_directory,"solver_stderr.raw"),String) == artifacts.receipt.stderr
        println("FREEGS_PROVIDER_ARTIFACTS_ACTUAL_JSON="*canonical_json((
            candidate_hash=string(freegs_context.candidate_hash),
            context_hash=string(freegs_context.context_hash),
            input_hash=string(artifacts.receipt.input_hash),output_hash=string(artifacts.receipt.output_hash),
            stdout_hash=string(F._freegs_sha256_text(artifacts.receipt.stdout)),
            stderr_hash=string(F._freegs_sha256_text(artifacts.receipt.stderr)),
            preserved_files=("solver_input.canonical.json","solver_output.json",
                "execution_receipt.canonical.json","solver_stdout.raw","solver_stderr.raw"),
            physical_validation=false)))
        flush(stdout)
    end
    @test artifacts.receipt.status == :physical_model_screen
    @test artifacts.receipt.exit_code == 0
    samples = artifacts.field_samples_rz_m
    @test length(samples) == length(points)
    @test Tuple((s.R_m, s.Z_m) for s in samples) == points
    supported = filter(s -> s.constitutive.status === :present, samples)
    @test !isempty(supported)
    @test all(s -> isfinite(s.constitutive.Btor_T) &&
        isfinite(s.constitutive.pressure_Pa) && isfinite(s.constitutive.Jphi_A_per_m2) &&
        0 <= s.constitutive.psi_normalized <= 1, supported)
    for s in supported
        c = s.constitutive
        @test c.core_mask == 1.0
        @test c.mu0_N_per_A2 == 4e-7pi
        @test isapprox(c.psi_native_wb_per_rad, s.psi_wb_per_rad; rtol=1e-12, atol=1e-14)
        @test isapprox(c.psi_normalized,
            (c.psi_native_wb_per_rad - c.psi_axis_wb_per_rad) /
            (c.psi_boundary_wb_per_rad - c.psi_axis_wb_per_rad); rtol=1e-12, atol=1e-14)
        pressure_term = c.native_R_m * c.pprime_Pa_per_flux
        field_term = c.ffprime_T2_m2_per_flux / (c.mu0_N_per_A2 * c.native_R_m)
        @test abs(c.Jphi_A_per_m2 - (pressure_term + field_term)) <=
            64eps(Float64) * max(1.0, abs(pressure_term), abs(field_term))
    end
    @test samples[1].constitutive.reason === (native_grid_mode ? :domain_boundary : :not_native_grid)
    @test samples[2].constitutive.status === :typed_absent
    @test samples[2].constitutive.reason === :domain_boundary
    for s in samples[1:2]
        @test s.constitutive.status === :typed_absent
        @test all(key -> getproperty(s.constitutive, key) === nothing, numerical_fields)
    end
    native_grid_mode || (@test samples[1] == samples[end])
    @test artifacts.receipt.claim_ceiling == screen_only
    @test !artifacts.receipt.physical_validation && !artifacts.receipt.engineering_validation
    @test !artifacts.receipt.p5_ready && !artifacts.receipt.terminal_authority
    if !isempty(component_points)
        @testset "actual FreeGS axisymmetric local MHD component and KKT row partition" begin
            receipt = artifacts.receipt
            # Use the explicit five requests in ordinary mode and their native-grid
            # indices in the opt-in full-grid mode.
            indices = native_grid_mode ? Tuple(findfirst(==(p),points) for p in component_points) :
                Tuple(length(points)-5:length(points)-1)
            component = F.freegs_axisymmetric_mhd_component(freegs_context,artifacts,indices)
            @test_throws ArgumentError F.freegs_axisymmetric_mhd_component(freegs_context,
                (receipt=receipt,input_json=artifacts.input_json,output_json=artifacts.output_json,
                 field_samples_rz_m=artifacts.field_samples_rz_m),indices)
            @test component.status === :sampled_axisymmetric_mhd_component
            @test component.candidate_hash == string(freegs_context.candidate_hash)
            @test component.upstream_output_hash == string(receipt.output_hash)
            @test component.claim_ceiling === screen_only
            @test component.jacobian_scope === :twenty_sampled_values_at_fixed_coordinates
            @test component.state_units == Tuple(mod1(i,4) == 1 ? "Pa" : "T" for i in 1:20)
            @test !component.coupled_solve_attempted && !component.physical_validation
            @test !component.interface_executed && !component.exterior_executed
            @test !component.global_conservation_executed && !component.terminal_authority
            @test component.missing_closures ==
                (:pressure_topology,:current_topology,:B_out,:K_outer,:return_current_path)
            @test all(i -> samples[i].constitutive.status === :present, indices)
            @test length(component.residual) == 4 && size(component.jacobian) == (4,20)
            @test all(isfinite,component.residual) && all(isfinite,component.jacobian)
            @test F.norm(component.jacobian) > 0
            x = collect(component.state); fd = zeros(4,20)
            for j in 1:20
                scale = mod1(j,4) == 1 ? maximum(abs,x[1:4:end]) : maximum(abs,x[2:4:end])+maximum(abs,x[3:4:end])+maximum(abs,x[4:4:end])
                step = 1e-3*max(scale,1.0)
                plus=copy(x); minus=copy(x); plus[j]+=step; minus[j]-=step
                fd[:,j] = (F._ccp_axisymmetric_mhd_stencil(plus,component.coordinates_m,component.mu0_N_per_A2).residual-
                    F._ccp_axisymmetric_mhd_stencil(minus,component.coordinates_m,component.mu0_N_per_A2).residual)/(2step)
            end
            fd_error = maximum(abs.(component.jacobian-fd)./max.(1.0,abs.(component.jacobian)))
            @test fd_error < 1e-6
            perturbed = copy(x); perturbed[3] += 0.01
            changed = F._ccp_axisymmetric_mhd_stencil(perturbed,component.coordinates_m,component.mu0_N_per_A2)
            @test F.norm(changed.residual-component.residual) > 0
            @test F.norm(changed.jacobian-component.jacobian) > 0
            # This is row assembly, not a constrained/nonlinear solve: four
            # local rows do not close twenty independent sampled variables.
            identity = (candidate_hash=component.candidate_hash,
                context_hash=component.context_hash, upstream_output_hash=component.upstream_output_hash,
                sample_indices=indices, stencil_order=component.stencil_order,
                state_fields=component.state_fields, state_units=component.state_units,
                row_units=component.row_units, coordinates_m=component.coordinates_m,
                mu0_N_per_A2=component.mu0_N_per_A2, component_source_hash=string(F._ccp_sha(F._CCP_SOURCE)),
                scope=:fixed_coordinate_local_stencil)
            partition = F.InHouseCoupledMHDGlobalSolveV1.weighted_residual_kkt_partition_v1(
                candidate_hash=component.candidate_hash, consumer_identity=identity,
                least_squares_row_ids=("local_force_R","local_force_phi","local_force_Z","local_divB"),
                least_squares_residual=component.residual, least_squares_jacobian=component.jacobian,
                least_squares_row_scales=(1.0,1.0,1.0,1.0))
            @test partition.raw_least_squares_residual == component.residual
            @test Matrix(partition.raw_least_squares_jacobian) == component.jacobian
            @test isempty(partition.equality_row_ids)
            @test !partition.physical_authority && !partition.emits_evidence
            @test partition.claim_ceiling === :numerical_mechanism_only
            unsupported = F.freegs_axisymmetric_mhd_component(freegs_context,artifacts,
                (1,indices[2:end]...))
            @test unsupported.status === :typed_absent
            @test unsupported.reason === :five_native_core_points_required
            @test unsupported.residual === nothing && unsupported.jacobian === nothing
            @test_throws ArgumentError F.freegs_axisymmetric_mhd_component(freegs_context,artifacts,
                (indices[1],indices[3],indices[2],indices[4],indices[5]))
            @test_throws ArgumentError F.freegs_axisymmetric_mhd_component(freegs_context,artifacts,
                (indices[1],indices[1],indices[3],indices[4],indices[5]))
            tampered = F.FreeGSAxisymmetricExecutionArtifactsV4(receipt,
                artifacts.input_json,artifacts.output_json*" ",artifacts.field_samples_rz_m)
            @test_throws ArgumentError F.freegs_axisymmetric_mhd_component(freegs_context,tampered,indices)
            forged_samples = (merge(samples[1],(Br_T=samples[1].Br_T+1.0,)),samples[2:end]...)
            forged = F.FreeGSAxisymmetricExecutionArtifactsV4(receipt,
                artifacts.input_json,artifacts.output_json,forged_samples)
            @test_throws ArgumentError F.freegs_axisymmetric_mhd_component(freegs_context,forged,indices)
            println("FREEGS_AXISYMMETRIC_MHD_COMPONENT_ACTUAL_JSON="*canonical_json((
                candidate_hash=component.candidate_hash, context_hash=component.context_hash,
                upstream_output_hash=component.upstream_output_hash, sample_indices=indices,
                coordinates_m=component.coordinates_m, state=component.state,
                row_units=component.row_units, residual=Tuple(component.residual),
                jacobian=Tuple(Tuple(component.jacobian[i,j] for j in 1:20) for i in 1:4),
                curl_current_A_m2=Tuple(component.current_cylindrical_A_m2),
                constitutive_Jphi_A_m2=component.center_constitutive_Jphi_A_m2,
                jacobian_fd_max_scaled_error=fd_error, partition_hash=partition.partition_hash,
                scope=:local_component_only, missing_closures=component.missing_closures)))
            flush(stdout)
        end
    end


    if !isempty(region_points)
        @testset "actual FreeGS shared-node regional MHD callbacks" begin
            # Three neighboring radial crosses: 12 PDE rows, 11 physical nodes,
            # and 44 shared p/Br/Bphi/Bz DOFs, with no fabricated closure rows.
            rnodes = range(domain.r_min_m,domain.r_max_m;length=domain.nx)
            znodes = range(domain.z_min_m,domain.z_max_m;length=domain.ny)
            ic = 1+5*(domain.nx-1)÷8; jc = (domain.ny+1)÷2
            offset = 2 + length(native) + 1
            indexof(i,j) = native_grid_mode ? only(findall(==((rnodes[i],znodes[j])),points)) :
                offset + only(findall(==((rnodes[i],znodes[j])),region_points))
            stencils = Tuple(Tuple(indexof(i,j) for (i,j) in
                ((ic+d,jc),(ic+d-1,jc),(ic+d+1,jc),(ic+d,jc-1),(ic+d,jc+1)))
                for d in -1:1)
            region = F.freegs_axisymmetric_mhd_region(freegs_context,artifacts,stencils;
                region_id="actual_native_core_patch")
            @test region isa F.FreeGSAxisymmetricMHDRegionV4
            @test length(region.coordinates_m) == 11
            @test length(region.initial_state) == 44
            @test length(region.local_stencils) == 3
            @test length(unique(Iterators.flatten(region.local_stencils))) == 11
            a = F.evaluate_freegs_axisymmetric_mhd_region(region,region.initial_state)
            @test size(a.jacobian) == (12,44)
            @test length(a.residual) == 12
            @test a.regional_state_dependent && a.shared_native_node_dofs
            @test a.missing_closures == F._CCP_AXISYMMETRIC_MISSING_CLOSURES
            @test !a.interface_executed && !a.exterior_executed && !a.global_conservation_executed
            @test !a.coupled_solve_attempted && !a.physical_validation && !a.terminal_authority
            # Every regional row reproduces its accepted five-point component.
            for k in 1:3
                c = F.freegs_axisymmetric_mhd_component(freegs_context,artifacts,stencils[k])
                @test a.residual[4(k-1)+1:4k] == c.residual
                dofs = [4(node-1)+field for node in region.local_stencils[k] for field in 1:4]
                @test Matrix(a.jacobian[4(k-1)+1:4k,dofs]) == c.jacobian
            end
            callbacks = F.freegs_axisymmetric_mhd_regional_callbacks(region)
            regional_identity = F.InHouseCoupledMHDGlobalSolveV1._callback_identity(callbacks.regional_evaluator)
            oracle_identity = F.InHouseCoupledMHDGlobalSolveV1._callback_identity(callbacks.jacobian_oracle)
            @test regional_identity.methods != oracle_identity.methods
            @test callbacks.missing_closures == a.missing_closures
            @test !callbacks.full_model_constructed && !callbacks.coupled_solve_attempted
            # Direct callback ABI screen. This context is not a full solver model.
            direct_context = (candidate_hash=region.candidate_hash,
                provider_semantic_hash=string(canonical_hash(F.semantic_view(region))),
                provider_context_hash=string(canonical_hash((regional_identity,oracle_identity))),
                jacobian_oracle_hash=string(canonical_hash(oracle_identity)))
            closure_absence = NamedTuple{a.missing_closures}(ntuple(_ -> nothing,5))
            block = callbacks.regional_evaluator(region.region_id,region.initial_state,
                closure_absence,direct_context)
            oracle = callbacks.jacobian_oracle(:regional,region.region_id,region.initial_state,
                closure_absence,direct_context)
            @test block.residual == a.residual && block.jacobian == a.jacobian
            @test block.equation_ids == a.equation_ids
            @test oracle.jacobian_oracle_hash == direct_context.jacobian_oracle_hash
            defect = maximum(abs,Matrix(block.jacobian)-oracle.jacobian)
            frozen_tolerance = 64eps(Float64)*max(1.0,maximum(abs,block.jacobian),maximum(abs,oracle.jacobian))
            @test defect <= frozen_tolerance
            # Exercise the existing validator on real rows, including a deliberate
            # wrong Jacobian. This minimal validator record is not a full model.
            validator_record = (candidate_hash=region.candidate_hash,
                region_id=region.region_id,
                provider_semantic_hash=direct_context.provider_semantic_hash,
                provider_context_hash=direct_context.provider_context_hash,
                jacobian_oracle=callbacks.jacobian_oracle,closure_evidence=closure_absence)
            validator_pass = F.InHouseCoupledMHDGlobalSolveV1._check_jacobian_oracle(
                validator_record,:regional,region.region_id,region.initial_state,a.equation_ids,
                :equation_ids,block.jacobian,"actual regional positive";provider_context=direct_context)
            @test validator_pass.passed
            wrong_jacobian = copy(block.jacobian)
            wrong_jacobian[1,1] += 1e-4*max(1.0,maximum(abs,block.jacobian))
            @test_throws ArgumentError F.InHouseCoupledMHDGlobalSolveV1._check_jacobian_oracle(
                validator_record,:regional,region.region_id,region.initial_state,a.equation_ids,
                :equation_ids,wrong_jacobian,"deliberately wrong regional Jacobian";
                provider_context=direct_context)
            # One actual shared center Bphi perturbs PDE rows in all three crosses.
            center_node = region.local_stencils[2][1]
            x = collect(region.initial_state); x[4(center_node-1)+3] += 0.01
            changed = callbacks.regional_evaluator(region.region_id,x,closure_absence,direct_context)
            @test all(k -> F.norm(changed.residual[4(k-1)+1:4k]-block.residual[4(k-1)+1:4k]) > 0,1:3)
            @test F.norm(changed.jacobian-block.jacobian) > 0
            oracle_changed = callbacks.jacobian_oracle(:regional,region.region_id,x,closure_absence,direct_context)
            changed_defect = maximum(abs,Matrix(changed.jacobian)-oracle_changed.jacobian)
            @test changed_defect <= 64eps(Float64)*max(1.0,maximum(abs,changed.jacobian),maximum(abs,oracle_changed.jacobian))
            partition = F.InHouseCoupledMHDGlobalSolveV1.weighted_residual_kkt_partition_v1(
                candidate_hash=region.candidate_hash,
                consumer_identity=(candidate_hash=region.candidate_hash,region_hash=region.region_hash,
                    context_hash=region.context_hash,upstream_output_hash=region.upstream_output_hash,
                    scope=:open_native_core_regional_patch),
                least_squares_row_ids=a.equation_ids,least_squares_residual=block.residual,
                least_squares_jacobian=block.jacobian,least_squares_row_scales=ntuple(_ -> 1.0,12))
            @test partition.raw_least_squares_residual == block.residual
            @test partition.raw_least_squares_jacobian == block.jacobian
            @test isempty(partition.equality_row_ids) && !partition.physical_authority
            # Input and applicability negatives retain actual-byte validation.
            @test_throws ArgumentError F.freegs_axisymmetric_mhd_region(freegs_context,artifacts,
                (stencils[1],stencils[1]))
            absent = F.freegs_axisymmetric_mhd_region(freegs_context,artifacts,
                ((1,stencils[1][2:end]...),stencils[2]))
            @test absent.status === :typed_absent
            @test absent.missing_closures == a.missing_closures
            negative_pressure = collect(region.initial_state); negative_pressure[1] = -1.0
            @test_throws ArgumentError F.evaluate_freegs_axisymmetric_mhd_region(region,negative_pressure)
            @test_throws ArgumentError callbacks.regional_evaluator("foreign",region.initial_state,closure_absence,direct_context)
            @test_throws ArgumentError callbacks.regional_evaluator(region.region_id,region.initial_state,
                closure_absence,merge(direct_context,(candidate_hash=repeat("0",64),)))
            @test_throws ArgumentError callbacks.jacobian_oracle(:outer,region.region_id,
                region.initial_state,closure_absence,direct_context)
            println("FREEGS_AXISYMMETRIC_MHD_REGION_ACTUAL_JSON="*canonical_json((
                candidate_hash=region.candidate_hash,context_hash=region.context_hash,
                upstream_output_hash=region.upstream_output_hash,region_hash=region.region_hash,
                coordinates_m=region.coordinates_m,local_stencils=region.local_stencils,
                sample_stencils=region.sample_stencils,initial_state=region.initial_state,
                equation_ids=a.equation_ids,residual=Tuple(a.residual),
                jacobian=F._ccp_tuple(Matrix(a.jacobian)),oracle_max_abs_defect=defect,
                oracle_frozen_tolerance=frozen_tolerance,changed_oracle_max_abs_defect=changed_defect,
                changed_residual=Tuple(changed.residual),missing_closures=a.missing_closures,
                shared_node_count=11,regional_rows=12,regional_dofs=44,
                direct_regional_callback_executed=true,full_model_constructed=false,
                coupled_solve_attempted=false,physical_validation=false,terminal_authority=false)))
        end
    end

    if get(ENV,"FUSION_FREEGS_NATIVE_GRID_MHD","0") == "1"
        @testset "actual full native R-major grid shared-node MHD map" begin
            domain = freegs_axisymmetric_declaration.domain
            @test (domain.nx,domain.ny) == (129,129)
            requested_grid = F.freegs_axisymmetric_mhd_native_grid_sample_points(freegs_context)
            R = Tuple(range(domain.r_min_m,domain.r_max_m;length=domain.nx))
            Z = Tuple(range(domain.z_min_m,domain.z_max_m;length=domain.ny))
            coordinate_tol = 16eps(Float64)*max(1.0,abs(domain.r_min_m),abs(domain.r_max_m),
                abs(domain.z_min_m),abs(domain.z_max_m))
            expected_grid = Tuple((R[i],Z[j]) for i in eachindex(R) for j in eachindex(Z))
            @test requested_grid == expected_grid
            @test length(requested_grid) == 129*129
            @test points == requested_grid
            artifact_dir = abspath(get(ENV,"FUSION_FREEGS_NATIVE_GRID_ARTIFACT_DIRECTORY",""))
            @test !isempty(get(ENV,"FUSION_FREEGS_NATIVE_GRID_ARTIFACT_DIRECTORY",""))
            @test artifact_directory == artifact_dir
            @test artifacts.receipt.status === :physical_model_screen
            @test artifacts.receipt.exit_code == 0
            @test length(artifacts.field_samples_rz_m) == length(requested_grid)
            @test Tuple((s.R_m,s.Z_m) for s in artifacts.field_samples_rz_m) == requested_grid
            @test all(s -> all(isfinite,(s.R_m,s.Z_m,s.psi_wb_per_rad,s.Br_T,s.Bz_T)),
                artifacts.field_samples_rz_m)
            payload = F.JSON3.read(artifacts.input_json).solver_input
            @test payload.sample_constitutive_fields === true
            @test payload.sample_lcfs_trace === true
            @test Tuple((Float64(p[1]),Float64(p[2])) for p in payload.sample_points_rz_m) == requested_grid

            trace = F.freegs_axisymmetric_lcfs_trace_samples(freegs_context,artifacts)
            @test trace.status === :present
            support = trace.current_support
            @test support.status === :present
            @test support.axis_order === :R_then_Z
                @test all(i -> abs(support.R_m[i]-R[i]) <= coordinate_tol,eachindex(R))
                @test all(j -> abs(support.Z_m[j]-Z[j]) <= coordinate_tol,eachindex(Z))
            samples = artifacts.field_samples_rz_m
            flat(i,j) = (i-1)*length(Z)+j
            for i in eachindex(R), j in eachindex(Z)
                c = samples[flat(i,j)].constitutive
                if support.core_mask[i][j] == 1.0
                    if c.status === :present
                        @test c.core_mask == 1.0
                        @test all(isfinite,(c.pressure_Pa,c.Btor_T,c.Jphi_A_per_m2))
                    else
                        @test c.status === :typed_absent
                            @test c.reason in (:not_native_grid,:core_mask_unavailable,:outside_supported_core,
                            :domain_boundary,:unsupported_fvac_branch)
                        @test c.core_mask === nothing
                        @test all(k -> getproperty(c,k) === nothing,
                            (:native_R_m,:native_Z_m,:psi_normalized,:Btor_T,:pressure_Pa,
                             :Jphi_A_per_m2,:psi_native_wb_per_rad,:psi_axis_wb_per_rad,
                             :psi_boundary_wb_per_rad,:core_mask,:pprime_Pa_per_flux,
                             :ffprime_T2_m2_per_flux,:mu0_N_per_A2))
                    end
                else
                    @test c.status === :typed_absent
                        @test c.reason in (:not_native_grid,:core_mask_unavailable,:outside_supported_core,
                        :domain_boundary,:unsupported_fvac_branch)
                    @test c.core_mask === nothing
                    @test all(k -> getproperty(c,k) === nothing,
                        (:native_R_m,:native_Z_m,:psi_normalized,:Btor_T,:pressure_Pa,
                         :Jphi_A_per_m2,:psi_native_wb_per_rad,:psi_axis_wb_per_rad,
                         :psi_boundary_wb_per_rad,:core_mask,:pprime_Pa_per_flux,
                         :ffprime_T2_m2_per_flux,:mu0_N_per_A2))
                end
            end
            expected_missing = Tuple((flat(i,j),samples[flat(i,j)].constitutive.reason)
                for i in eachindex(R) for j in eachindex(Z)
                if support.core_mask[i][j] == 1.0 &&
                    samples[flat(i,j)].constitutive.status === :typed_absent)
            expected_absent = Tuple((flat(i,j),support.core_mask[i][j],
                samples[flat(i,j)].constitutive.reason)
                for i in eachindex(R) for j in eachindex(Z)
                if samples[flat(i,j)].constitutive.status === :typed_absent)

            region = F.freegs_axisymmetric_mhd_native_grid_region(freegs_context,artifacts)
            @test region isa F.FreeGSAxisymmetricMHDRegionV4
            @test region.grid_coverage.axis_order === :R_then_Z
            coverage = region.grid_coverage
            @test coverage.grid_shape == (129,129)
            @test coverage.native_linear_index == "(i-1)*nz+j"
            @test coverage.node_native_ids == Tuple(sort(collect(coverage.node_native_ids)))
            @test coverage.native_node_order === :r_major_native_linear_index
            @test coverage.node_order === :r_major_i_then_j
            @test length(unique(coverage.center_native_ids)) == coverage.assembled_center_count
            @test all(id -> 1 <= id <= length(requested_grid),coverage.node_native_ids)
            @test all(id -> samples[id].constitutive.core_mask == 1.0,coverage.node_native_ids)
            @test all(id -> begin
                i = (id-1) ÷ length(Z)+1; j = mod1(id,length(Z))
                1 < i < length(R) && 1 < j < length(Z)
            end,coverage.center_native_ids)
            expected_centers = Tuple(flat(i,j) for i in 2:length(R)-1 for j in 2:length(Z)-1
                if all(id -> samples[id].constitutive.status === :present,
                    (flat(i,j),flat(i-1,j),flat(i+1,j),flat(i,j-1),flat(i,j+1))))
            @test coverage.center_native_ids == expected_centers
            @test coverage.missing_core_native_samples == expected_missing
            @test coverage.typed_absent_native_samples == expected_absent
            @test coverage.excluded_core_center_count > 0
            @test coverage.plasma_boundary_rows === :typed_absent
            @test coverage.lcfs_boundary_to_grid_map === :typed_absent
            @test coverage.exterior_B === :typed_absent
            @test coverage.K_outer === :typed_absent
            @test coverage.return_current_path_closure === :typed_absent
            @test all(isfinite,region.initial_state)
            @test all(i -> region.initial_state[i] >= 0.0,1:4:length(region.initial_state))
            @test all(k -> coverage.node_native_ids[region.local_stencils[k][1]] ==
                region.sample_stencils[k][1],eachindex(region.local_stencils))
            @test all(k -> Tuple(coverage.node_native_ids[id] for id in region.local_stencils[k]) ==
                region.sample_stencils[k],eachindex(region.local_stencils))
            for (k,id) in enumerate(coverage.node_native_ids)
                @test abs(region.coordinates_m[k][1]-samples[id].R_m) <= coordinate_tol
                @test abs(region.coordinates_m[k][2]-samples[id].Z_m) <= coordinate_tol
            end
            @test coverage.node_current_area_weights_m2 == Tuple(
                support.area_weight_m2[(id-1)÷length(Z)+1][mod1(id,length(Z))]
                for id in coverage.node_native_ids)
            @test coverage.node_axisymmetric_volume_weights_m3 == Tuple(
                2pi*region.coordinates_m[k][1]*coverage.node_current_area_weights_m2[k]
                for k in eachindex(region.coordinates_m))

            evaluated = F.evaluate_freegs_axisymmetric_mhd_region(region,region.initial_state)
            @test length(evaluated.residual) == 4coverage.assembled_center_count
            @test size(evaluated.jacobian) == (length(evaluated.residual),4length(region.coordinates_m))
            @test SparseArrays.issparse(evaluated.jacobian)
            @test SparseArrays.nnz(evaluated.jacobian) <= 80coverage.assembled_center_count
            row_counts = zeros(Int,length(evaluated.residual))
            for row in first(SparseArrays.findnz(evaluated.jacobian))
                row_counts[row] += 1
            end
            @test maximum(row_counts) <= 20
            @test all(isfinite,evaluated.residual) && all(isfinite,SparseArrays.nonzeros(evaluated.jacobian))
            @test length(unique(evaluated.equation_ids)) == length(evaluated.equation_ids)
            @test evaluated.missing_closures == F._CCP_AXISYMMETRIC_MISSING_CLOSURES
            @test !evaluated.coupled_solve_attempted && !evaluated.physical_validation

            callbacks = F.freegs_axisymmetric_mhd_regional_callbacks(region)
            rid = F.InHouseCoupledMHDGlobalSolveV1._callback_identity(callbacks.regional_evaluator)
            oid = F.InHouseCoupledMHDGlobalSolveV1._callback_identity(callbacks.jacobian_oracle)
            context = (candidate_hash=region.candidate_hash,
                provider_semantic_hash=string(canonical_hash(F.semantic_view(region))),
                provider_context_hash=string(canonical_hash((rid,oid))),
                jacobian_oracle_hash=string(canonical_hash(oid)))
            absent = NamedTuple{evaluated.missing_closures}(ntuple(_ -> nothing,5))
            block = callbacks.regional_evaluator(region.region_id,region.initial_state,absent,context)
            oracle = callbacks.jacobian_oracle(:regional,region.region_id,region.initial_state,absent,context)
            @test block.residual == evaluated.residual
            @test block.jacobian == evaluated.jacobian
            @test SparseArrays.issparse(oracle.jacobian)
            @test size(oracle.jacobian) == size(evaluated.jacobian)
            @test SparseArrays.nnz(oracle.jacobian) <= 80coverage.assembled_center_count
            oracle_difference = SparseArrays.sparse(block.jacobian-oracle.jacobian)
            oracle_defect = isempty(SparseArrays.nonzeros(oracle_difference)) ? 0.0 :
                maximum(abs,SparseArrays.nonzeros(oracle_difference))
            @test oracle_defect <=
                64eps(Float64)*max(1.0,maximum(abs,SparseArrays.nonzeros(block.jacobian)))

            # Selected finite differences exercise one physical node shared by rows
            # in distinct crosses without allocating a dense global oracle matrix.
            uses = [count(node -> node == n,Iterators.flatten(region.local_stencils))
                for n in eachindex(region.coordinates_m)]
            shared_node = findfirst(>(1),uses)
            @test shared_node !== nothing
            selected_columns = (4(shared_node-1)+2,4(shared_node-1)+3,4(shared_node-1)+4)
            x = collect(region.initial_state)
            field_scale = maximum(abs,x[2:4:end])+maximum(abs,x[3:4:end])+maximum(abs,x[4:4:end])
            h = 1e-3*max(field_scale,1.0)
            for column in selected_columns
                plus=copy(x); minus=copy(x); plus[column]+=h; minus[column]-=h
                rp=callbacks.regional_evaluator(region.region_id,plus,absent,context).residual
                rm=callbacks.regional_evaluator(region.region_id,minus,absent,context).residual
                fd=(rp-rm)/(2h)
                analytic=Vector(block.jacobian[:,column])
                @test maximum(abs.(fd-analytic)./max.(1.0,abs.(analytic))) < 1e-6
            end
            test_actual_freegs_single_region_preparation(F,freegs_context,artifacts;region=region)
            full_profile_trace=Base.invokelatest(test_actual_freegs_lcfs_trace,
                F,freegs_context,artifacts,first(region.sample_stencils);native_region=region)
            @test coverage.core_node_count > coverage.assembled_center_count
            println("FREEGS_NATIVE_GRID_REGION_ACTUAL_JSON="*canonical_json((
                candidate_hash=region.candidate_hash,context_hash=region.context_hash,
                upstream_output_hash=region.upstream_output_hash,region_hash=region.region_hash,
                grid_shape=coverage.grid_shape,axis_order=coverage.axis_order,
                native_sample_count=length(samples),core_node_count=coverage.core_node_count,
                node_count=length(region.coordinates_m),center_count=coverage.assembled_center_count,
                dof_count=length(region.initial_state),row_count=length(evaluated.residual),
                residual_finite=all(isfinite,evaluated.residual),jacobian_nnz=SparseArrays.nnz(evaluated.jacobian),
                oracle_nnz=SparseArrays.nnz(oracle.jacobian),oracle_max_abs_defect=oracle_defect,
                selected_shared_fd_columns=selected_columns,
                missing_closures=evaluated.missing_closures,
                coupled_solve_attempted=false,physical_validation=false)))
            flush(stdout)
        end
    end


    if lcfs_mode && !native_grid_mode
        indices=Tuple(length(points)-5:length(points)-1)
        test_actual_freegs_lcfs_trace(F,freegs_context,artifacts,indices)
    end

    println("FREEGS_CONSTITUTIVE_SAMPLE_ACTUAL_JSON=" * canonical_json((
        output_hash=string(artifacts.receipt.output_hash), field_samples_rz_m=samples)))
    flush(stdout)
end
