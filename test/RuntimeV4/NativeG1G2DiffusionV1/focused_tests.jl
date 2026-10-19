const NG12_TEST_EPOCH_NS = time_ns()

function ng12_diagnostic_value(f)
    try
        string(f())
    catch error
        "unsupported:" * string(typeof(error))
    end
end

function ng12_stage(label::AbstractString; detail="")
    elapsed_ms = div(time_ns() - NG12_TEST_EPOCH_NS, 1_000_000)
    suffix = isempty(detail) ? "" : " detail=" * detail
    println("NG12_STAGE stage=", label, " elapsed_ms=", elapsed_ms,
        " gc_live_bytes=", ng12_diagnostic_value(Base.gc_live_bytes),
        " jit_total_bytes=", ng12_diagnostic_value(Base.jit_total_bytes),
        " process_maxrss_bytes=", ng12_diagnostic_value(Sys.maxrss),
        " gc_time_ns=", ng12_diagnostic_value(Base.gc_time_ns), suffix)
    flush(stdout)
end

ng12_stage("entry.before_imports";
    detail="julia_version=" * string(VERSION) *
        ",active_project=" * ng12_diagnostic_value(Base.active_project) *
        ",load_path=" * join(LOAD_PATH, "|") *
        ",heap_size_hint_bytes=" *
            ng12_diagnostic_value(() -> Base.JLOptions().heap_size_hint))

using Test
ng12_stage("entry.after_using_test")
using SHA
ng12_stage("entry.after_using_sha")
using Serialization
ng12_stage("entry.after_using_serialization")
import JSON3

ng12_stage("entry.before_fixture_include")
include(joinpath(@__DIR__, "fixture_and_oracle.jl"))
ng12_stage("entry.after_fixture_include")

function ng12_expect_code(f, text)
    try
        f()
        false
    catch error
        occursin(text, sprint(showerror, error))
    end
end

function ng12_rehashed_report(report; levels=report.levels,
        candidate_ref=report.candidate_ref, gaps=report.gaps,
        errors=report.errors, status=report.status)
    l2_orders = NG12_R._ng12_orders(ntuple(i -> levels[i].l2_error, 3))
    h1_orders = NG12_R._ng12_orders(
        ntuple(i -> levels[i].h1_seminorm_error, 3))
    args = (candidate_ref, report.t1_package_hash, report.plan_hash,
        report.solver_input_hash, report.protocol_hash, levels, l2_orders,
        h1_orders, status, report.resolution, report.accepted,
        report.claim_ceiling, report.numerical_scope,
        report.physical_status, errors, gaps)
    NG12_R.NativeG1G2GridapReportV1(args...,
        NG12_G.canonical_hash(NG12_R._ng12_report_body(args...)))
end

function ng12_rehashed_q1_field_state(state;
        candidate_ref=state.candidate_ref,
        package_hash=state.package_hash,
        semantic_identity=state.semantic_identity,
        t0_bundle_hash=state.t0_bundle_hash,
        plan_hash=state.plan_hash,
        g1_declaration_hash=state.g1_declaration_hash,
        g2_declaration_hash=state.g2_declaration_hash,
        g2_source_ref=state.g2_source_ref,
        g2_source_hash=state.g2_source_hash,
        g2_mesh_ref=state.g2_mesh_ref,
        g2_chart_ref=state.g2_chart_ref,
        source_sign=state.source_sign,
        level=state.level,
        cell_counts=state.cell_counts,
        physical_domain=state.physical_domain,
        component_field_ids=state.component_field_ids,
        component_units=state.component_units,
        component_orientations=state.component_orientations,
        component_dof_values=state.component_dof_values,
        dof_coordinates=state.dof_coordinates,
        cell_dof_ids=state.cell_dof_ids,
        free_to_full=state.free_to_full,
        boundary_to_full=state.boundary_to_full,
        face_owners=state.face_owners,
        face_dof_full_ids=state.face_dof_full_ids,
        g2_entity_ownership=state.g2_entity_ownership,
        cell_owner_domain=state.cell_owner_domain,
        cell_owner_refs=state.cell_owner_refs,
        partition_count=state.partition_count,
        halo_status=state.halo_status,
        halo_owner_refs=state.halo_owner_refs)
    coords=Tuple(Tuple(Float64.(Tuple(p))) for p in dof_coordinates)
    cell_ids=Tuple(Tuple(Int(id) for id in ids) for ids in cell_dof_ids)
    cell_coords=Tuple(Tuple(coords[id] for id in ids) for ids in cell_ids)
    mesh_hash=NG12_G.canonical_hash((domain="native-g1g2-q1-space-v2-region-map",
        cell_counts=cell_counts, physical_domain=physical_domain,
        dof_coordinates=coords, cell_dof_ids=cell_ids,
        face_owners=face_owners, face_dof_full_ids=face_dof_full_ids,
        g2_entity_ownership=g2_entity_ownership,
        cell_owner_domain=cell_owner_domain, cell_owner_refs=cell_owner_refs))
    args=(candidate_ref, package_hash, semantic_identity, t0_bundle_hash,
        plan_hash, g1_declaration_hash, g2_declaration_hash, g2_source_ref,
        g2_source_hash, g2_mesh_ref, g2_chart_ref, source_sign, level,
        cell_counts, physical_domain, mesh_hash, component_field_ids,
        component_units, component_orientations, component_dof_values,
        coords, cell_ids, cell_coords, free_to_full, boundary_to_full,
        face_owners, face_dof_full_ids, g2_entity_ownership, cell_owner_domain,
        cell_owner_refs, partition_count, halo_status,
        halo_owner_refs)
    NG12_R.NativeG1G2Q1FieldStateV1(args...,
        NG12_G.canonical_hash(NG12_R._ng12_q1_field_state_body(args...)))
end

function ng12_rehashed_level(level;
        analytic_source_integral=level.analytic_source_integral,
        analytic_outward_conormal_integral=
            level.analytic_outward_conormal_integral,
        assembled_source_integral=level.assembled_source_integral,
        field_state=level.field_state)
    source_integral_error = abs(assembled_source_integral -
        analytic_source_integral)
    analytic_identity_defect = analytic_source_integral +
        analytic_outward_conormal_integral
    args = (level.level, level.cell_counts, level.physical_domain,
        level.cells, level.free_dofs, level.dirichlet_dofs,
        level.matrix_shape, level.matrix_nnz, level.matrix_hash,
        level.rhs_hash, level.solution_hash, level.residual_abs,
        level.residual_rel, level.l2_error, level.h1_seminorm_error,
        level.boundary_linf, assembled_source_integral,
        analytic_source_integral, source_integral_error,
        analytic_outward_conormal_integral, analytic_identity_defect,
        level.discrete_trace_conormal_integral,
        abs(level.discrete_trace_conormal_integral -
            analytic_outward_conormal_integral),
        level.dof_partition_hash,
        level.discrete_interior_reaction_linf,
        level.discrete_interior_reaction_sum,
        level.discrete_interior_residual_match_linf,
        level.discrete_boundary_reaction_integral,
        assembled_source_integral +
            level.discrete_boundary_reaction_integral,
        field_state, level.source_sign, level.status)
    NG12_R.NativeG1G2GridapLevelResultV1(args...,
        NG12_G.canonical_hash(NG12_R._ng12_level_body(args...)))
end

function ng12_admission_with_package(admission, package)
    NG12_G.VNextT1AdmissionResultV2(admission.status, admission.resolution,
        admission.accepted, admission.claim_ceiling, package,
        admission.errors, admission.gaps, admission.trace)
end

const NG12_NATIVE_PARENT_CANDIDATE_DIR =
    "tmp/up1_04b_true_consumer/guarded_candidate_local-authored-up4-g123-20261002-g3-reenable-325-r1"
const NG12_NATIVE_EDITED_CANDIDATE_DIR =
    "tmp/up2_03_native_mesh_child_20261004/guarded_candidate_local-authored-up4-g123-20261004-native-mesh-334-r1"
const NG12_NATIVE_TRANSFER_CHILD_CANDIDATE_DIR =
    "tmp/up2_copy_hotspot_impl/up2_03_native_transfer_tests/guarded_candidate_local-authored-up4-g123-20261004-native-transfer-468-r1"

function ng12_current_source_t1(candidate_directory::AbstractString)
    G = NG12_G
    Base.invokelatest(G.load_genome_v5_components!)
    Base.invokelatest(G.load_vnext_t2_components_v2!)
    built = Base.invokelatest(G._vnext_current_source_candidate_records_v1,
        NG12_ROOT, candidate_directory)
    records = Base.invokelatest(G._vnext_current_source_records_v1, built)
    t0 = Base.invokelatest(G.vnext_declaration_transport_local_v1,
        built.candidate_ref, records.declarations, records.children,
        records.feedback; frozen_context=NG12_ROOT)
    independent = Base.invokelatest(
        G._vnext_current_source_independent_g3_inputs_v1, built, records,
        t0.transport)
    current = Base.invokelatest(G._vnext_current_source_continue_v1,
        built.candidate_ref, t0, NG12_ROOT, independent.expected,
        independent.realization_state, independent.control_payload,
        independent.control_state, independent.binding_key;
        initial_links=independent.initial_links,
        g3_factory_invocation=built.g3_factory_invocation)
    (built=built, records=records, t0=t0, independent=independent,
        current=current, admission=current.t1)
end

function ng12_rehashed_protocol_with_cells(protocol, cell_counts)
    body = NG12_R._ng12_protocol_body(cell_counts,
        protocol.quadrature_degree, protocol.solver,
        protocol.residual_abs_tol, protocol.residual_rel_tol,
        protocol.boundary_abs_tol, protocol.source_integral_abs_tol,
        protocol.analytic_identity_abs_tol,
        protocol.reaction_balance_abs_tol,
        protocol.l2_order_interval, protocol.h1_order_interval,
        protocol.finest_l2_max, protocol.finest_h1_seminorm_max,
        protocol.budget_basis)
    NG12_R.NativeG1G2NumericalProtocolV1(cell_counts,
        protocol.quadrature_degree, protocol.solver,
        protocol.residual_abs_tol, protocol.residual_rel_tol,
        protocol.boundary_abs_tol, protocol.source_integral_abs_tol,
        protocol.analytic_identity_abs_tol,
        protocol.reaction_balance_abs_tol,
        protocol.l2_order_interval, protocol.h1_order_interval,
        protocol.finest_l2_max, protocol.finest_h1_seminorm_max,
        protocol.budget_basis, NG12_G.canonical_hash(body))
end

function ng12_primary_current_source_source_phase(context::Base.RefValue{Any})
        ng12_stage("primary.current_source_parent.before";
            detail="candidate_directory=" * NG12_NATIVE_PARENT_CANDIDATE_DIR)
        parent = ng12_current_source_t1(NG12_NATIVE_PARENT_CANDIDATE_DIR)
        ng12_stage("primary.current_source_parent.after";
            detail="t0_status=" * string(parent.t0.status) *
                ",t1_status=" * string(parent.admission.status))
        ng12_stage("primary.current_source_edited.before";
            detail="candidate_directory=" * NG12_NATIVE_EDITED_CANDIDATE_DIR)
        edited = ng12_current_source_t1(NG12_NATIVE_EDITED_CANDIDATE_DIR)
        ng12_stage("primary.current_source_edited.after";
            detail="t0_status=" * string(edited.t0.status) *
                ",t1_status=" * string(edited.admission.status))
        @test parent.t0.status === :valid
        @test edited.t0.status === :valid
        @test parent.current.status === :prepared_not_executed
        @test edited.current.status === :prepared_not_executed
        @test parent.admission.status === :prepared_not_executed
        @test edited.admission.status === :prepared_not_executed
        @test edited.admission.claim_ceiling === :contract_only
        @test parent.admission.package isa NG12_G.CandidateStatePackageV5NextV2
        @test edited.admission.package isa NG12_G.CandidateStatePackageV5NextV2
        @test parent.built.candidate_ref != edited.built.candidate_ref
        @test parent.admission.package.package_hash !=
            edited.admission.package.package_hash
        @test parent.built.g2.declaration.source.mesh.cells == (2, 3, 4)
        @test edited.built.g2.declaration.source.mesh.cells == (3, 3, 4)
        parent_projection = NG12_G.g2_v5_source_projection_v1(parent.records.g2)
        edited_projection = NG12_G.g2_v5_source_projection_v1(edited.records.g2)
        legal_mesh_edit = NG12_G.g2_edit_mesh_cells(
            parent_projection.genome, (3, 3, 4))
        parent_plan = parent_projection.genome.plan
        edited_plan = edited_projection.genome.plan
        edited_source_payload = edited_projection.source_declaration.source_payload
        edited_regions = edited_projection.genome.region_interface.regions
        @test legal_mesh_edit.plan.mesh.cells_per_region == (3, 3, 4)
        @test edited_plan.mesh.cells_per_region ==
            legal_mesh_edit.plan.mesh.cells_per_region
        @test edited_plan.mesh.mesh_ref.id == edited_source_payload.mesh.mesh_ref.id
        @test edited_plan.mesh.mesh_ref.version == "v2"
        @test edited_plan.mesh.region_ids ==
            Tuple(region.region_id for region in edited_regions)
        @test edited_plan.mesh.basis == parent_plan.mesh.basis
        @test edited_plan.mesh.quadrature == parent_plan.mesh.quadrature
        @test edited_plan.mesh.execution_status == parent_plan.mesh.execution_status
        @test edited_plan.chart.frame_ref == parent_plan.chart.frame_ref
        @test edited_plan.chart.axes == parent_plan.chart.axes
        @test edited_plan.chart.map_kind == parent_plan.chart.map_kind
        @test edited_plan.chart.chart_ref.id ==
            edited_source_payload.chart_map.chart_ref.id
        @test edited_plan.chart.chart_ref.version == "v2"
        @test all(region.chart_ref == edited_plan.chart.chart_ref for
            region in edited_regions)
        @test edited_plan.chart.chart_ref != parent_plan.chart.chart_ref
        @test edited_plan.embedding.ambient_dimension ==
            parent_plan.embedding.ambient_dimension
        @test edited_plan.embedding.embedding_kind ==
            parent_plan.embedding.embedding_kind
        @test edited_plan.embedding.chart_ref == edited_plan.chart.chart_ref
        @test edited_plan.embedding.embedding_ref ==
            first(edited_source_payload.region_interface.regions).embedding_ref
        @test all(region.embedding_ref == edited_plan.embedding.embedding_ref
            for region in edited_source_payload.region_interface.regions)
        @test edited_plan.embedding.embedding_ref !=
            parent_plan.embedding.embedding_ref
        @test edited_plan.field_space.value_shape ==
            parent_plan.field_space.value_shape
        @test edited_plan.field_space.continuity ==
            parent_plan.field_space.continuity
        @test edited_plan.field_space.state_unit ==
            parent_plan.field_space.state_unit
        @test edited_plan.field_space.field_space_ref ==
            first(edited_source_payload.region_interface.regions).field_space_ref
        @test all(region.field_space_ref ==
            edited_plan.field_space.field_space_ref for
            region in edited_source_payload.region_interface.regions)
        @test edited_plan.field_space.field_space_ref !=
            parent_plan.field_space.field_space_ref
        @test edited_plan.exterior.boundary_region_ids ==
            parent_plan.exterior.boundary_region_ids
        @test edited_plan.exterior.boundary_faces ==
            parent_plan.exterior.boundary_faces
        @test edited_plan.exterior.boundary_patches ==
            parent_plan.exterior.boundary_patches
        @test edited_plan.exterior.boundary_condition ==
            parent_plan.exterior.boundary_condition
        @test edited_plan.exterior.provider_match ==
            parent_plan.exterior.provider_match
        @test edited_plan.exterior.exterior_ref.id ==
            "fusionconceptai://GenomeV5/G2/exterior/" *
            edited_projection.source_payload_hash.value
        @test edited_plan.exterior.exterior_ref.version == "v2"
        @test edited_plan.exterior.exterior_ref != parent_plan.exterior.exterior_ref
        @test edited_plan.plan_ref.id ==
            "fusionconceptai://GenomeV5/G2/field-space-plan/" *
            edited_projection.source_payload_hash.value
        @test edited_plan.plan_ref.version == "v2"
        @test parent.built.entries.g2_source_jl.sha256 !=
            edited.built.entries.g2_source_jl.sha256
        @test parent.built.entries.native_mms_source_expressions_json.sha256 !=
            edited.built.entries.native_mms_source_expressions_json.sha256
        @test Tuple(edited.built.expression.g2_mesh_cells) == (3, 3, 4)

        context[] = merge(context[], (parent=parent, edited=edited, parent_projection=parent_projection))
end

function ng12_primary_current_source_preparation_phase(context::Base.RefValue{Any})
    state = context[]
        edited = state.edited
        ng12_stage("primary.first_program_bundle.before")
        profile_programs = ng12_profile_and_programs()
        ng12_stage("primary.first_program_bundle.after")
        ng12_stage("primary.first_compile.before";
            detail="candidate=edited mesh=3x3x4")
        compiled = NG12_R.compile_native_g1g2_diffusion_v1(
            edited.admission, edited.built.g1.declaration,
            edited.built.g2.declaration, profile_programs.programs,
            profile_programs.profile)
        ng12_stage("primary.first_compile.after";
            detail="status=" * string(compiled.status) *
                ",error_count=" * string(length(compiled.errors)))
        @test compiled.status === :compiled_numerical_preparation
        @test compiled.claim_ceiling === :contract_only
        @test isempty(compiled.errors)
        @test compiled.compilation.form.candidate_ref ==
            edited.admission.package.candidate_ref
        @test compiled.compilation.form.t1_package === edited.admission.package
        @test compiled.compilation.form.g2_declaration.source.mesh.cells ==
            (3, 3, 4)

        protocol = NG12_R.native_g1g2_numerical_protocol_v1((3, 3, 4))
        @test protocol.cell_counts == ((3, 3, 4), (6, 6, 8), (12, 12, 16))
        @test protocol.quadrature_degree == 8
        @test protocol.solver === :gridap_sparse_lu
        @test protocol.residual_abs_tol == 1.0e-9
        @test protocol.residual_rel_tol == 1.0e-11
        @test protocol.boundary_abs_tol == 1.0e-10
        @test protocol.source_integral_abs_tol == 1.0e-10
        @test protocol.analytic_identity_abs_tol == 1.0e-12
        @test protocol.reaction_balance_abs_tol == 1.0e-9
        @test protocol.l2_order_interval == (1.4, 2.6)
        @test protocol.h1_order_interval == (0.6, 1.4)
        @test protocol.finest_l2_max == 5.0e-3
        @test protocol.finest_h1_seminorm_max == 1.0e-2
        @test protocol.budget_basis.base_cell_counts == (3, 3, 4)
        @test protocol.budget_basis.three_level_cell_counts ==
            protocol.cell_counts
        @test protocol.budget_basis.poincare_finest_l2_bound_m32 <=
            protocol.finest_l2_max
        @test protocol.budget_basis.cea_finest_h1_bound_m12 <=
            protocol.finest_h1_seminorm_max
        @test_throws ArgumentError NG12_R.prepare_gridap_native_g1g2_diffusion_v1(
            compiled, NG12_R.native_g1g2_numerical_protocol_v1())
        foreign_protocol =
            NG12_R.native_g1g2_numerical_protocol_v1((3, 3, 5))
        @test_throws ArgumentError NG12_R.prepare_gridap_native_g1g2_diffusion_v1(
            compiled, foreign_protocol)
        bad_hierarchy = ng12_rehashed_protocol_with_cells(protocol,
            ((3, 3, 4), (6, 6, 8), (12, 12, 15)))
        @test !NG12_R._ng12_protocol_integrity(bad_hierarchy)
        @test_throws ArgumentError NG12_R.prepare_gridap_native_g1g2_diffusion_v1(
            compiled, bad_hierarchy)

        plan = NG12_R.prepare_gridap_native_g1g2_diffusion_v1(
            compiled, protocol)
        @test NG12_R.validate_native_g1g2_gridap_plan_v1(plan)
        @test plan.protocol.cell_counts ==
            ((3, 3, 4), (6, 6, 8), (12, 12, 16))
        @test plan.subject.materialized_payload.formal_t2_receipt_assignment ===
            false

        context[] = merge(context[], (profile_programs=profile_programs, plan=plan))
end

function ng12_primary_current_source_first_solve_phase(context::Base.RefValue{Any})
    state = context[]
        parent = state.parent
        edited = state.edited
        profile_programs = state.profile_programs
        plan = state.plan
        # One real source-bound solve: producer state only, not a transfer.
        ng12_stage("primary.first_solve.before";
            detail="candidate=edited level=1 cells=3x3x4")
        child_level = NG12_R.run_native_g1g2_gridap_level_v1(plan, 1)
        ng12_stage("primary.first_solve.after";
            detail="status=" * string(child_level.status) *
                ",cells=" * string(child_level.cells))
        field_state = child_level.field_state
        @test field_state isa NG12_R.NativeG1G2Q1FieldStateV1
        @test NG12_R._ng12_q1_field_state_valid(field_state)
        @test NG12_R._ng12_level_integrity(child_level)
        @test NG12_R._ng12_level_matches_plan(plan, child_level, 1)
        @test field_state.candidate_ref == edited.built.candidate_ref
        @test field_state.package_hash == edited.admission.package.package_hash
        @test field_state.semantic_identity == edited.admission.package.semantic_identity
        @test field_state.t0_bundle_hash == edited.admission.package.bundle_hash
        @test field_state.plan_hash == plan.plan_hash
        @test field_state.g1_declaration_hash == edited.built.g1.declaration.declaration_hash
        @test field_state.g2_declaration_hash == edited.built.g2.declaration.declaration_hash
        @test field_state.g2_source_ref == edited.built.g2.declaration.source.source_ref
        @test field_state.g2_source_hash == edited.built.g2.declaration.source.source_hash
        @test field_state.g2_mesh_ref == edited.built.g2.declaration.source.mesh.mesh_ref
        @test field_state.g2_chart_ref == edited.built.g2.declaration.source.chart_map.chart_ref
        @test field_state.source_sign === :declared
        @test field_state.cell_counts == edited.built.g2.declaration.source.mesh.cells
        @test field_state.physical_domain == child_level.physical_domain
        @test field_state.component_field_ids == (edited.built.g1.declaration.u.field_id,)
        @test field_state.component_units == (edited.built.g1.declaration.u.physical_type.units,)
        @test field_state.component_orientations == (:scalar_invariant,)
        @test length(field_state.component_dof_values) == 1
        full_values = field_state.component_dof_values[1]
        @test length(full_values) == length(field_state.dof_coordinates)
        @test length(full_values) == child_level.free_dofs + child_level.dirichlet_dofs
        @test length(field_state.dof_coordinates) == prod(child_level.cell_counts .+ 1)
        @test all(isfinite, full_values)
        @test all(p -> all(isfinite, p), field_state.dof_coordinates)
        @test maximum(full_values) > minimum(full_values)
        @test NG12_G.canonical_hash(Float64[full_values[i] for i in field_state.free_to_full]) == child_level.solution_hash
        @test length(field_state.cell_dof_ids) == child_level.cells
        @test all(length(ids) == 8 && length(unique(ids)) == 8 for ids in field_state.cell_dof_ids)
        @test all(all(1 <= id <= length(full_values) for id in ids) for ids in field_state.cell_dof_ids)
        @test all(Tuple(field_state.dof_coordinates[id] for id in ids) == field_state.cell_dof_coordinates[cell]
            for (cell, ids) in enumerate(field_state.cell_dof_ids))
        @test length(field_state.free_to_full) == child_level.free_dofs
        @test length(field_state.boundary_to_full) == child_level.dirichlet_dofs
        @test sort(vcat(collect(field_state.free_to_full), collect(field_state.boundary_to_full))) == collect(1:length(full_values))
        @test all(id -> any(isapprox(field_state.dof_coordinates[id][axis],
            field_state.physical_domain[2axis-2+side]; atol=1e-12, rtol=0.0)
            for axis in 1:3 for side in 1:2), field_state.boundary_to_full)
        @test all(iszero(full_values[id]) for id in field_state.boundary_to_full)
        @test Set(face.face for face in field_state.face_owners) == Set((:x_min, :x_max, :y_min, :y_max, :z_min, :z_max))
        @test Set(face.face for face in field_state.face_dof_full_ids) == Set((:x_min, :x_max, :y_min, :y_max, :z_min, :z_max))
        @test all(all(id in field_state.boundary_to_full for id in face.dof_full_ids) &&
            all(isapprox(field_state.dof_coordinates[id][face.face in (:x_min,:x_max) ? 1 : face.face in (:y_min,:y_max) ? 2 : 3],
                face.physical_plane_coordinate; atol=1e-12, rtol=0.0) for id in face.dof_full_ids)
            for face in field_state.face_dof_full_ids)
        @test field_state.g2_entity_ownership.status === :typed_absent
        @test field_state.g2_entity_ownership.reason === :g2_mesh_does_not_resolve_all_source_regions_and_owners
        @test all(owner.status in (:mapped, :typed_absent) for owner in field_state.g2_entity_ownership.cell_owners)
        @test any(owner.status === :typed_absent for owner in field_state.g2_entity_ownership.cell_owners)
        @test any(interface.status === :typed_absent for interface in field_state.g2_entity_ownership.interface_maps)
        @test all(begin
            source_face=only(filter(face -> face.face === projected.face, edited.built.g2.declaration.source.faces))
            projected.face_id == source_face.face_id &&
            projected.owner_region_id == source_face.owner_region_id &&
            projected.reference_normal == source_face.reference_normal &&
            projected.kind === source_face.value.kind &&
            projected.value == Float64(source_face.value.value) && projected.unit == source_face.value.unit
        end for projected in field_state.face_owners)
        @test all(face.kind === :dirichlet && iszero(face.value) for face in field_state.face_owners)
        @test field_state.cell_owner_domain === :process_partition
        @test field_state.cell_owner_refs == ntuple(_ -> "serial-process:0", child_level.cells)
        @test field_state.partition_count == 1
        @test field_state.halo_status === :single_rank_empty
        @test isempty(field_state.halo_owner_refs)

        # The real 3x3x4 G2 partition cuts the x=1.5 source interface.
        edited_source = edited.built.g2.declaration.source
        source_region_ids = Tuple(region.region_id for region in
            edited_source.region_interface.regions)
        source_interface = only(edited_source.region_interface.interfaces)
        cell_owners = field_state.g2_entity_ownership.cell_owners
        @test field_state.cell_counts == (3, 3, 4)
        @test length(cell_owners) == 36
        @test count(owner -> owner.status === :mapped &&
            owner.owner_region_id === source_region_ids[1], cell_owners) == 12
        @test count(owner -> owner.status === :mapped &&
            owner.owner_region_id === source_region_ids[2], cell_owners) == 12
        @test count(owner -> owner.status === :typed_absent &&
            owner.owner_region_id === nothing, cell_owners) == 12
        @test Set(owner.owner_region_id for owner in cell_owners
            if owner.status === :mapped) == Set(source_region_ids)
        @test length(field_state.g2_entity_ownership.interface_maps) == 1
        interface_map = only(field_state.g2_entity_ownership.interface_maps)
        @test interface_map.interface_ref == source_interface.interface_ref
        @test interface_map.expected_face_count == 12
        @test isempty(interface_map.mapped_faces)
        @test interface_map.status === :typed_absent

        # A real source-bound parent with a positive diagonal affine chart maps.
        parent_programs = ng12_profile_and_programs()
        parent_compiled = NG12_R.compile_native_g1g2_diffusion_v1(
            parent.admission, parent.built.g1.declaration,
            parent.built.g2.declaration, parent_programs.programs,
            parent_programs.profile)
        @test parent_compiled.status === :compiled_numerical_preparation
        @test isempty(parent_compiled.errors)
        parent_protocol = NG12_R.native_g1g2_numerical_protocol_v1(
            parent.built.g2.declaration.source.mesh.cells)
        parent_plan = NG12_R.prepare_gridap_native_g1g2_diffusion_v1(
            parent_compiled, parent_protocol)
        parent_mapping = NG12_R._ng12_q1_plan_mapping_v1(parent_plan, 1)
        @test parent_mapping !== nothing
        parent_chart = parent.built.g2.declaration.source.chart_map
        @test all(parent_chart.jacobian_rows[i][i] > 0 for i in 1:3)
        @test all(iszero(parent_chart.jacobian_rows[i][j])
            for i in 1:3 for j in 1:3 if i != j)
        @test parent_chart.jacobian_rows != ((1//1,0//1,0//1),
            (0//1,1//1,0//1),(0//1,0//1,1//1))
        @test NG12_R._ng12_cartesian_chart_supported_v1(parent_chart)
        @test parent_mapping.g2_entity_ownership.status === :mapped
        @test all(owner.status === :mapped for owner in
            parent_mapping.g2_entity_ownership.cell_owners)
        @test Set(owner.owner_region_id for owner in
            parent_mapping.g2_entity_ownership.cell_owners) ==
            Set(region.region_id for region in
                parent.built.g2.declaration.source.region_interface.regions)
        @test only(parent_mapping.g2_entity_ownership.interface_maps).status === :mapped
        @test length(only(parent_mapping.g2_entity_ownership.interface_maps).mapped_faces) == 12

        context[] = merge(context[], (child_level=child_level, field_state=field_state, parent_plan=parent_plan, edited_source=edited_source))
end

function ng12_primary_current_source_transfer_phase(context::Base.RefValue{Any})
    state = context[]
        parent = state.parent
        edited = state.edited
        parent_projection = state.parent_projection
        parent_plan = state.parent_plan
        plan = state.plan
        # Separate, current-source candidate produced by the actual parent
        # g2_edit_mesh_cells((4,6,8)) result. Exercise the transfer through the
        # child FE matrix/RHS and its existing level/state gates.
        transfer_child = ng12_current_source_t1(
            NG12_NATIVE_TRANSFER_CHILD_CANDIDATE_DIR)
        @test transfer_child.t0.status === :valid
        @test transfer_child.admission.status === :prepared_not_executed
        transfer_child_projection = NG12_G.g2_v5_source_projection_v1(
            transfer_child.records.g2)
        @test transfer_child_projection.genome.plan.mesh.cells_per_region == (4, 6, 8)
        transfer_child_edit = NG12_G.g2_edit_mesh_cells(
            parent_projection.genome, (4, 6, 8))
        @test transfer_child_edit.plan.mesh.cells_per_region == (4, 6, 8)
        @test NG12_R._ng12_g2_edit_semantics_match_v1(
            transfer_child_edit, transfer_child_projection.genome)
        transfer_child_programs = ng12_profile_and_programs()
        transfer_child_compiled = NG12_R.compile_native_g1g2_diffusion_v1(
            transfer_child.admission, transfer_child.built.g1.declaration,
            transfer_child.built.g2.declaration,
            transfer_child_programs.programs, transfer_child_programs.profile)
        @test transfer_child_compiled.status === :compiled_numerical_preparation
        @test isempty(transfer_child_compiled.errors)
        transfer_child_protocol = NG12_R.native_g1g2_numerical_protocol_v1(
            (4, 6, 8))
        transfer_child_plan = NG12_R.prepare_gridap_native_g1g2_diffusion_v1(
            transfer_child_compiled, transfer_child_protocol)
        @test NG12_R.validate_native_g1g2_gridap_plan_v1(transfer_child_plan)
        @test transfer_child_plan.protocol.cell_counts ==
            ((4, 6, 8), (8, 12, 16), (16, 24, 32))
        parent_level = NG12_R.run_native_g1g2_gridap_level_v1(parent_plan, 1)
        @test parent_level.status === :pass
        @test NG12_R._ng12_level_integrity(parent_level)
        child_transfer = NG12_R.transfer_gridap_field_payload_v1(
            parent_plan, parent_level, parent.records.g2,
            transfer_child_plan, transfer_child.records.g2)
        @test child_transfer.status === :ready
        @test child_transfer.accepted === false
        @test child_transfer.formal_up2_credit === false
        @test child_transfer.claim_ceiling === :screen_only
        @test child_transfer.relation.parent_candidate_ref == parent.built.candidate_ref
        @test child_transfer.relation.child_candidate_ref ==
            transfer_child.built.candidate_ref
        @test child_transfer.relation.parent_candidate_ref !=
            child_transfer.relation.child_candidate_ref
        @test child_transfer.relation.parent_t0_bundle_hash !=
            child_transfer.relation.child_t0_bundle_hash
        @test child_transfer.relation.parent_plan_hash == parent_plan.plan_hash
        @test child_transfer.relation.child_plan_hash == transfer_child_plan.plan_hash
        @test child_transfer.relation.parent_mesh_cells == (2, 3, 4)
        @test child_transfer.relation.child_mesh_cells == (4, 6, 8)
        @test child_transfer.relation.edit_result_hash ==
            NG12_G.canonical_hash(NG12_G.semantic_view(transfer_child_edit))
        @test child_transfer.local_gate && child_transfer.global_gate
        @test maximum(abs, child_transfer.cell_integral_defects; init=0.0) <=
            1.0e-12 * max(1.0, abs(child_transfer.source_integral))
        @test abs(child_transfer.conservation_defect) <=
            1.0e-12 * max(1.0, abs(child_transfer.source_integral))
        @test child_transfer.boundary_linf <= 1.0e-12

        child_execution = NG12_R.run_native_g1g2_gridap_level_v1(
            transfer_child_plan, 1; transfer_outcome=child_transfer)
        child_level = child_execution.level
        child_consumption = child_execution.transfer_consumption
        @test child_level.status === :pass
        @test NG12_R._ng12_level_integrity(child_level)
        @test NG12_R._ng12_level_matches_plan(transfer_child_plan, child_level, 1)
        @test child_consumption.status === :measured
        @test child_consumption.pass === false
        @test child_consumption.claim_ceiling === :screen_only
        @test child_consumption.consumer === :native_child_q1_residual_correction_seed
        @test child_consumption.seed_used === true
        @test child_consumption.residual_abs > 0.0
        @test child_consumption.transfer_receipt_hash == child_transfer.receipt_hash
        @test child_consumption.transfer_projection_hash ==
            child_transfer.transfer_projection_hash
        @test child_consumption.matrix_hash == child_level.matrix_hash
        @test child_consumption.rhs_hash == child_level.rhs_hash
        @test child_consumption.boundary_preserved
        @test child_consumption.boundary_linf <= transfer_child_protocol.boundary_abs_tol
        @test child_consumption.corrected_residual_abs <=
            transfer_child_protocol.residual_abs_tol ||
            child_consumption.corrected_residual_rel <=
                transfer_child_protocol.residual_rel_tol
        final_state = child_level.field_state
        @test final_state.candidate_ref == transfer_child.built.candidate_ref
        @test final_state.t0_bundle_hash == transfer_child.admission.package.bundle_hash
        @test final_state.plan_hash == transfer_child_plan.plan_hash
        @test final_state.cell_counts == (4, 6, 8)
        @test NG12_R._ng12_q1_field_state_valid(final_state)
        payload_axes = child_transfer.projection.payload.coordinates
        payload_index = Dict{NTuple{3,Float64},Int}()
        for i in eachindex(payload_axes[1]), j in eachindex(payload_axes[2]),
                k in eachindex(payload_axes[3])
            payload_index[(payload_axes[1][i],payload_axes[2][j],payload_axes[3][k])] =
                NG12_R._gridap_node_index(i,j,k,length(payload_axes[2]),
                    length(payload_axes[3]))
        end
        applied_correction_linf = maximum(abs(
            final_state.component_dof_values[1][id] -
            child_transfer.projection.payload.values[payload_index[
                Tuple(Float64.(final_state.dof_coordinates[id]))]])
            for id in final_state.free_to_full; init=0.0)
        @test applied_correction_linf > 0.0
        @test isapprox(applied_correction_linf,
            child_consumption.correction_linf; atol=1.0e-9, rtol=1.0e-7)

        context[] = merge(context[], (parent_level=parent_level, transfer_child=transfer_child, transfer_child_plan=transfer_child_plan, child_transfer=child_transfer, transfer_child_level=child_level, child_consumption=child_consumption, final_state=final_state, payload_axes=payload_axes, payload_index=payload_index))
end

function ng12_primary_current_source_adversarial_phase(context::Base.RefValue{Any})
    state = context[]
        parent = state.parent
        edited = state.edited
        parent_projection = state.parent_projection
        profile_programs = state.profile_programs
        plan = state.plan
        child_level = state.child_level
        field_state = state.field_state
        parent_plan = state.parent_plan
        edited_source = state.edited_source
        parent_level = state.parent_level
        transfer_child = state.transfer_child
        transfer_child_plan = state.transfer_child_plan
        child_transfer = state.child_transfer
        child_consumption = state.child_consumption
        final_state = state.final_state
        payload_axes = state.payload_axes
        payload_index = state.payload_index
        # The old 3x3x4 cut-cell remains a typed negative for exact nested 2x.
        @test_throws ArgumentError NG12_R.transfer_gridap_field_payload_v1(
            parent_plan, parent_level, parent.records.g2, plan, edited.records.g2)
        @test_throws ArgumentError NG12_R.transfer_gridap_field_payload_v1(
            parent_plan, parent_level, parent.records.g2,
            transfer_child_plan, parent.records.g2)
        @test_throws ArgumentError NG12_R.run_native_g1g2_gridap_level_v1(
            transfer_child_plan, 1;
            transfer_outcome=merge(child_transfer, (receipt_hash="0"^64,)))

        function ng12_rehash_child_transfer(transfer; relation=transfer.relation,
                projection=transfer.projection)
            body = (domain=transfer.domain, relation=relation,
                transfer_projection_hash=projection.projection_hash,
                source_grid_hash=projection.source_grid_hash,
                target_grid_hash=projection.target_grid_hash,
                source_integral=projection.source_integral,
                target_integral=projection.target_integral,
                conservation_defect=projection.conservation_defect,
                cell_integral_defects=projection.cell_integral_defects,
                boundary_payload_indices=transfer.boundary_payload_indices,
                boundary_linf=transfer.boundary_linf,
                local_gate=transfer.local_gate, global_gate=transfer.global_gate,
                status=transfer.status, accepted=transfer.accepted,
                formal_up2_credit=transfer.formal_up2_credit,
                claim_ceiling=transfer.claim_ceiling)
            merge(transfer, (relation=relation, projection=projection,
                transfer_projection_hash=projection.projection_hash,
                source_grid_hash=projection.source_grid_hash,
                target_grid_hash=projection.target_grid_hash,
                source_integral=projection.source_integral,
                target_integral=projection.target_integral,
                conservation_defect=projection.conservation_defect,
                cell_integral_defects=projection.cell_integral_defects,
                receipt_hash=NG12_G.canonical_hash(body)))
        end
        foreign_relation = merge(child_transfer.relation,
            (child_candidate_ref=parent.built.candidate_ref,))
        @test_throws ArgumentError NG12_R.run_native_g1g2_gridap_level_v1(
            transfer_child_plan, 1; transfer_outcome=
                ng12_rehash_child_transfer(child_transfer; relation=foreign_relation))
        transferred_values = collect(child_transfer.projection.payload.values)
        first_free_id = first(final_state.free_to_full)
        free_coord = Tuple(Float64.(final_state.dof_coordinates[first_free_id]))
        transferred_values[payload_index[free_coord]] += 0.125
        forged_payload = NG12_R.FieldResidualPayloadV4(
            child_transfer.projection.payload.state_ref,
            NG12_R.FieldGridSpecV4(payload_axes), Tuple(transferred_values),
            child_transfer.projection.payload.physical_type)
        old_projection = child_transfer.projection
        forged_projection_body = NG12_R._gridap_projection_body(
            NG12_R._ng12_q1_physical_payload_v1(
                parent_plan,parent_level.field_state).payload.content_hash, forged_payload.content_hash,
            old_projection.source_grid_hash, old_projection.target_grid_hash,
            old_projection.source_domain, old_projection.target_domain,
            old_projection.source_integral, old_projection.target_integral,
            old_projection.conservation_defect, old_projection.cell_integral_defects,
            old_projection.state_delta_linf, old_projection.support,
            old_projection.quadrature)
        forged_projection = merge(old_projection, (payload=forged_payload,
            projection_hash=NG12_G.canonical_hash(forged_projection_body)))
        coherent_forgery = ng12_rehash_child_transfer(child_transfer;
            projection=forged_projection)
        @test_throws ArgumentError NG12_R.run_native_g1g2_gridap_level_v1(
            transfer_child_plan, 1; transfer_outcome=coherent_forgery)
        println("NG12_NATIVE_2X_CHILD_TRANSFER status=ready parent_cells=2x3x4 child_cells=4x6x8 local_gate=true global_gate=true boundary_linf=", child_transfer.boundary_linf, " correction_linf=", child_consumption.correction_linf, " corrected_residual_abs=", child_consumption.corrected_residual_abs, " corrected_residual_rel=", child_consumption.corrected_residual_rel, " claim_ceiling=screen_only formal_up2_credit=false")

        # Shear reaches the existing compile failure and geometry-mapper guard.
        edited_chart = edited_source.chart_map
        shear_rows = ((edited_chart.jacobian_rows[1][1], 1//10, 0//1),
            edited_chart.jacobian_rows[2], edited_chart.jacobian_rows[3])
        shear_chart = NG12_G.G2MBChartMapV1(edited_chart.chart_ref,
            edited_chart.domain_lower, edited_chart.domain_upper, shear_rows,
            edited_chart.offset; axes=edited_chart.axes)
        shear_source = NG12_G.g2mb_source_v1(edited_source.source_ref,
            edited_source.source_version, edited_source.candidate_ref,
            shear_chart, edited_source.mesh, edited_source.faces,
            edited_source.profile, edited_source.units,
            edited_source.authority; field_space=edited_source.field_space,
            q1_interpretation=edited_source.q1_interpretation,
            boundary_coverage=nothing,
            region_interface=edited_source.region_interface,
            region_exterior_owners=edited_source.region_exterior_owners)
        shear_declaration = NG12_G.g2mb_declaration_v1(
            edited.built.g2.declaration.contract_ref, shear_source)
        @test !NG12_R._ng12_cartesian_chart_supported_v1(shear_chart)
        shear_errors = NG12_R.native_g1g2_physics_errors_v1(
            edited.built.g1.declaration, shear_declaration,
            profile_programs.programs, profile_programs.profile)
        @test :unsupported_non_diagonal_or_reversing_chart in shear_errors
        shear_ownership = NG12_R._ng12_g2_entity_ownership_v1(shear_source,
            field_state.cell_counts, field_state.dof_coordinates,
            field_state.cell_dof_ids)
        @test shear_ownership.status === :typed_absent
        @test shear_ownership.reason === :native_cartesian_affine_chart_unsupported
        shear_state = ng12_rehashed_q1_field_state(field_state;
            g2_entity_ownership=shear_ownership)
        shear_level = ng12_rehashed_level(child_level; field_state=shear_state)
        @test NG12_R._ng12_q1_field_state_valid(shear_state)
        @test NG12_R._ng12_level_integrity(shear_level)
        @test !NG12_R._ng12_level_matches_plan(plan, shear_level, 1)
end

function ng12_primary_current_source_tests()
    @testset "current-source edited G2 mesh compiles against derived native protocol" begin
        current_source_context = Ref{Any}(NamedTuple())
        ng12_stage("primary.current_source.phase.source.before")
        Base.invokelatest(ng12_primary_current_source_source_phase, current_source_context)
        ng12_stage("primary.current_source.phase.preparation.before")
        Base.invokelatest(ng12_primary_current_source_preparation_phase, current_source_context)
        ng12_stage("primary.current_source.phase.first_solve.before")
        Base.invokelatest(ng12_primary_current_source_first_solve_phase, current_source_context)
        ng12_stage("primary.current_source.phase.transfer.before")
        Base.invokelatest(ng12_primary_current_source_transfer_phase, current_source_context)
        ng12_stage("primary.current_source.phase.adversarial.before")
        Base.invokelatest(ng12_primary_current_source_adversarial_phase, current_source_context)
    end
end

function ng12_authored_ast_case_v1(kind::Symbol)
    schema = "fusionconceptai:genome-v5:g1-source-expression-ast-v1"
    u = Dict("schema" => schema, "role" => "u", "root" => 1,
        "nodes" => [Dict("kind" => "constant", "role" => "dimensionless",
            "value" => 0.0)])
    if kind === :constant
        f = Dict("schema" => schema, "role" => "f", "root" => 1,
            "nodes" => [Dict("kind" => "constant", "role" => "f",
                "value" => 1.0)])
    elseif kind === :affine
        f = Dict("schema" => schema, "role" => "f", "root" => 7,
            "nodes" => [Dict("kind" => "input", "port" => 1),
                Dict("kind" => "constant", "role" => "chart_x_axis",
                    "value" => [1.0, 0.0, 0.0]),
                Dict("kind" => "apply", "operator" => "DOT", "inputs" => [1, 2]),
                Dict("kind" => "constant", "role" => "f", "value" => 1.0),
                Dict("kind" => "apply", "operator" => "SCALAR_MUL", "inputs" => [3, 4]),
                Dict("kind" => "constant", "role" => "f", "value" => 1.0),
                Dict("kind" => "apply", "operator" => "ADD", "inputs" => [5, 6])])
    elseif kind === :quadratic
        f = Dict("schema" => schema, "role" => "f", "root" => 8,
            "nodes" => [Dict("kind" => "input", "port" => 1),
                Dict("kind" => "constant", "role" => "chart_x_axis",
                    "value" => [1.0, 0.0, 0.0]),
                Dict("kind" => "apply", "operator" => "DOT", "inputs" => [1, 2]),
                Dict("kind" => "apply", "operator" => "SCALAR_MUL", "inputs" => [3, 3]),
                Dict("kind" => "constant", "role" => "f", "value" => 1.0),
                Dict("kind" => "apply", "operator" => "SCALAR_MUL", "inputs" => [4, 5]),
                Dict("kind" => "constant", "role" => "f", "value" => 1.0),
                Dict("kind" => "apply", "operator" => "ADD", "inputs" => [6, 7])])
    else
        throw(ArgumentError("unsupported authored AST test case"))
    end
    (u=u, f=f)
end

function ng12_authored_ast_source_case_compiles_v1(kind::Symbol)
    fixture_dir = joinpath(NG12_ROOT, NG12_CURRENT_SOURCE_AUTHORED_AST_DIR)
    expression_path = joinpath(fixture_dir, "native_mms_source_expressions.json")
    manifest_path = joinpath(fixture_dir, "manifest.json")
    original_expression = read(expression_path)
    original_manifest = read(manifest_path)
    try
        record = JSON3.read(String(original_expression), Dict{String,Any})
        ast = ng12_authored_ast_case_v1(kind)
        record["authored_u_ast"] = ast.u
        record["authored_f_ast"] = ast.f
        write(expression_path, codeunits(JSON3.write(record) * "\n"))
        manifest = JSON3.read(String(original_manifest), Dict{String,Any})
        pin = only(row for row in manifest["files"]
            if row["path"] == "native_mms_source_expressions.json")
        bytes = read(expression_path)
        pin["bytes"] = length(bytes)
        pin["sha256"] = bytes2hex(SHA.sha256(bytes))
        write(manifest_path, codeunits(JSON3.write(manifest) * "\n"))

        chain = ng12_current_source_native_chain(
            NG12_CURRENT_SOURCE_AUTHORED_AST_DIR)
        @test chain.admission.status === :prepared_not_executed
        @test all(face.value.kind === :dirichlet && face.value.value == 0
            for face in chain.g2.source.faces)
        compiled = NG12_R.compile_native_g1g2_diffusion_v1(
            chain.admission, chain.g1, chain.g2, chain.programs,
            chain.profile)
        @test compiled.status === :compiled_numerical_preparation
        @test isempty(compiled.errors)
        @test compiled.compilation.form.authored_source_capability !== nothing
        profile = NG12_R.native_g1g2_numerical_protocol_v1((2, 3, 4))
        plan = NG12_R.prepare_gridap_native_g1g2_diffusion_v1(
            compiled, profile)
        level = NG12_R.run_native_g1g2_gridap_level_v1(plan, 1)
        lo = chain.programs.parameters.physical_lower
        hi = chain.programs.parameters.physical_upper
        points = ((Float64(lo[1]), Float64(lo[2]), Float64(lo[3])),
            ((Float64(lo[1]) + Float64(hi[1])) / 2,
                (Float64(lo[2]) + Float64(hi[2])) / 2,
                (Float64(lo[3]) + Float64(hi[3])) / 2),
            (Float64(hi[1]), Float64(hi[2]), Float64(hi[3])))
        source_values = Tuple(NG12_R.native_g1g2_source_value_v1(
            compiled.compilation.form, point) for point in points)
        expected_values = kind === :constant ? (1.0, 1.0, 1.0) :
            (1.0, 1.5, 2.0)
        @test all(isapprox(value, expected; atol=1e-14, rtol=0.0)
            for (value, expected) in zip(source_values, expected_values))
        expected_integral = kind === :constant ? 24.0 : 36.0
        @test isapprox(level.assembled_source_integral, expected_integral;
            atol=1e-11, rtol=0.0)
        @test level.residual_abs <= 1e-9
        @test level.residual_rel <= 1e-11
        @test level.field_state isa NG12_R.NativeG1G2Q1FieldStateV1
        @test NG12_R._ng12_q1_field_state_valid(level.field_state)
        @test all(isfinite, level.field_state.component_dof_values[1])
        @test level.boundary_linf == 0.0
        @test level.status === :not_applicable_reference
        result = (kind=kind, rhs_hash=level.rhs_hash,
            rhs_integral=level.assembled_source_integral,
            residual_abs=level.residual_abs, residual_rel=level.residual_rel,
            field_state_hash=level.field_state.state_hash,
            reference_status=level.status, source_values=source_values)
        println("NG12_AUTHORED_G1_AST_VARIANT kind=", kind,
            " rhs_integral=", level.assembled_source_integral,
            " residual_abs=", level.residual_abs,
            " residual_rel=", level.residual_rel,
            " reference=MMS_NA downstream_state=ready")
        return result
    finally
        write(expression_path, original_expression)
        write(manifest_path, original_manifest)
    end
end

Base.@noinline Base.@nospecializeinfer function ng12_primary_authored_ast_native_source_tests(base_fixture)
    Base.@nospecialize base_fixture
    ng12_stage("primary.authored_ast_native_source.begin")
    execution = Ref{Any}(nothing)
    source_variant_results = Ref{Any}(nothing)
    @testset "candidate AST variants rebuild through the same current-source entry" begin
        for role in (:u, :f)
            @test_throws ArgumentError NG12_R._g1_authored_source_expression_root_v1(
                "{", role)
            unsupported_schema = NG12_G.canonical_json((schema="unsupported",
                role=String(role), nodes=(), root=1))
            @test_throws ArgumentError NG12_R._g1_authored_source_expression_root_v1(
                unsupported_schema, role)
        end
        @test NG12_R._g1_authored_source_expression_root_v1(
            "legacy-unknown-expression", :u) === nothing
        @test NG12_R._g1_authored_source_expression_root_v1(
            "legacy-source-expression", :f) === nothing
        constant = ng12_authored_ast_source_case_compiles_v1(:constant)
        affine = ng12_authored_ast_source_case_compiles_v1(:affine)
        @test constant.rhs_hash != affine.rhs_hash
        @test constant.field_state_hash != affine.field_state_hash
        source_variant_results[] = (constant=constant, affine=affine)
    end
    @testset "current-source legal authored G1 AST reaches native Gridap level" begin
        chain = ng12_current_source_native_chain(
            NG12_CURRENT_SOURCE_AUTHORED_AST_DIR)
        @test chain.admission.status === :prepared_not_executed
        @test chain.admission.claim_ceiling === :contract_only
        @test chain.g2.source.mesh.cells == (2, 3, 4)
        @test chain.g2.source.units.field_value == NG12_G.UnitSignature()
        @test all(face.value.kind === :dirichlet && face.value.value == 0
            for face in chain.g2.source.faces)
        @test chain.g1.u.source_expression !=
            base_fixture.chain.g1.u.source_expression
        @test chain.g1.f.source_expression !=
            base_fixture.chain.g1.f.source_expression
        @test chain.g1.source_hash ==
            NG12_G.g1_diffusion_source_hash_v1(chain.g1.source_payload)
        g1_manifest = only(d for d in chain.admission.package.declarations
            if d.layer === :G1)
        @test NG12_G.copy_bytes(g1_manifest.declaration_bytes) ==
            Vector{UInt8}(codeunits(NG12_G.canonical_json(chain.g1)))
        @test isempty(NG12_R.native_g1g2_t1_binding_errors_v1(
            chain.admission, chain.g1, chain.g2))

        compiled = NG12_R.compile_native_g1g2_diffusion_v1(
            chain.admission, chain.g1, chain.g2, chain.programs,
            chain.profile)
        @test compiled.status === :compiled_numerical_preparation
        @test isempty(compiled.errors)
        form = compiled.compilation.form
        @test form.authored_source_capability !== nothing
        profile = NG12_R.native_g1g2_numerical_protocol_v1((2, 3, 4))
        plan = NG12_R.prepare_gridap_native_g1g2_diffusion_v1(compiled,
            profile)
        level = NG12_R.run_native_g1g2_gridap_level_v1(plan, 1)
        baseline_level = NG12_R.run_native_g1g2_gridap_level_v1(
            base_fixture.plan, 1)

        lo = chain.programs.parameters.physical_lower
        hi = chain.programs.parameters.physical_upper
        points = ((Float64(lo[1]), Float64(lo[2]), Float64(lo[3])),
            ((Float64(lo[1]) + Float64(hi[1])) / 2,
                (Float64(lo[2]) + Float64(hi[2])) / 2,
                (Float64(lo[3]) + Float64(hi[3])) / 2),
            (Float64(hi[1]), Float64(hi[2]), Float64(hi[3])))
        source_values = Tuple(NG12_R.native_g1g2_source_value_v1(form, p)
            for p in points)
        @test all(isapprox(a, b; atol=1e-14, rtol=0.0)
            for (a, b) in zip(source_values, (1.0, 1.25, 2.0)))
        @test length(unique(source_values)) == 3
        @test level.rhs_hash != baseline_level.rhs_hash
        @test level.rhs_hash != source_variant_results[].constant.rhs_hash
        @test level.rhs_hash != source_variant_results[].affine.rhs_hash
        @test level.field_state.state_hash !=
            source_variant_results[].constant.field_state_hash
        @test level.field_state.state_hash !=
            source_variant_results[].affine.field_state_hash
        @test isapprox(level.assembled_source_integral, 32.0;
            atol=1e-11, rtol=0.0)
        @test level.residual_abs <= 1e-9
        @test level.residual_rel <= 1e-11
        @test level.discrete_interior_residual_match_linf <= 1e-9
        @test level.discrete_interior_reaction_linf <= 1e-9
        @test level.field_state isa NG12_R.NativeG1G2Q1FieldStateV1
        @test NG12_R._ng12_q1_field_state_valid(level.field_state)
        @test all(isfinite, level.field_state.component_dof_values[1])
        @test level.boundary_linf == 0.0
        # The source has no compatible authored exact-u/gradient oracle here.
        # The native consumer must report that its MMS reference is NA.
        @test level.status === :not_applicable_reference
        execution[] = (candidate_ref=chain.candidate,
            t1_package_hash=chain.admission.package.package_hash,
            g1_declaration_hash=chain.g1.declaration_hash,
            compilation_hash=compiled.compilation.compilation_hash,
            level_hash=level.level_hash, rhs_hash=level.rhs_hash,
            rhs_integral=level.assembled_source_integral,
            residual_abs=level.residual_abs,
            residual_rel=level.residual_rel,
            source_values=source_values,
            field_state_hash=level.field_state.state_hash,
            reference_status=level.status,
            source_variant_results=(constant=source_variant_results[].constant,
                affine=source_variant_results[].affine,
                quadratic=(rhs_hash=level.rhs_hash,
                    rhs_integral=level.assembled_source_integral,
                    residual_abs=level.residual_abs,
                    residual_rel=level.residual_rel,
                    field_state_hash=level.field_state.state_hash,
                    reference_status=level.status,
                    source_values=source_values)))
        println("NG12_AUTHORED_G1_AST status=ready cells=2x3x4 source_values=1,1.25,2 assembled_rhs_integral=32 raw_residual=", level.residual_abs, " reference=MMS_NA downstream_state=ready")
    end
    ng12_stage("primary.authored_ast_native_source.complete")
    execution[]
end

function ng12_authored_ast_only(artifact_path::AbstractString)
    ispath(artifact_path) && error("authored AST artifact already exists")
    fixture = ng12_compiled_fixture()
    result = Base.invokelatest(
        ng12_primary_authored_ast_native_source_tests, fixture)
    result === nothing && error("authored AST test did not emit execution evidence")
    mkpath(dirname(artifact_path))
    open(artifact_path, "w") do io
        Serialization.serialize(io, merge((
            schema="native-g1g2-authored-ast-level-artifact-v1",
            status="not_applicable_reference", claim_ceiling=:screen_only),
            result))
    end
    println("NG12_RESULT mode=authored_ast status=pass level_hash=",
        result.level_hash.value, " rhs_hash=", result.rhs_hash.value,
        " reference=MMS_NA resolution=terminal_deferred")
end

Base.@noinline Base.@nospecializeinfer function ng12_primary_t1_carrier_tests(fixture, chain, compilation, form)
    Base.@nospecialize fixture chain compilation form
    ng12_stage("primary.t1_carrier.body_entry")
    @testset "native source and formal T1 carrier" begin
        @test chain.admission.status === :prepared_not_executed
        @test chain.admission.resolution === :terminal_deferred
        @test !chain.admission.accepted
        @test chain.admission.claim_ceiling === :contract_only
        @test isempty(chain.admission.errors)
        @test chain.admission.package isa NG12_G.CandidateStatePackageV5NextV2
        @test chain.admission.package.candidate_ref == NG12_CANDIDATE
        @test chain.recheck_v2.status === :local_checked_present
        @test chain.recheck_v2.resolution === :resolved
        @test !chain.recheck_v2.accepted
        @test isempty(chain.recheck_v2.errors)
        @test chain.admission.package.wire.sha256 ==
            NG12_G._vnext_ar_v2_carrier(chain.transport).sha256
        @test NG12_G.copy_bytes(chain.admission.package.wire) ==
            NG12_G.copy_bytes(NG12_G._vnext_ar_v2_carrier(chain.transport))
        @test all(chain.admission.package.declarations[i].source_bytes.sha256 ==
            chain.transport.declarations[i].source_bytes.sha256 for i in 1:3)
        @test all(NG12_G.copy_bytes(
            chain.admission.package.declarations[i].source_bytes) ==
            chain.transport.declarations[i].source_bytes.bytes for i in 1:3)
        @test chain.witness_build.source_ready
        @test chain.witness_build.status === :source_ready
        witness_validation = NG12_G.validate_vnext_t2_concrete_source_witness_v3(
            chain.witness, chain.transport, chain.recheck_v2, chain.parent,
            chain.expected, chain.bridge, chain.realization,
            chain.control_payload, chain.control_state, chain.binding_key;
            frozen_context=NG12_ROOT,
            g3_factory_invocation=chain.g3_factory_invocation)
        @test witness_validation.source_ready
        @test chain.witness.candidate_ref == chain.admission.package.candidate_ref
        @test fixture.compile_result.status === :compiled_numerical_preparation
        @test fixture.compile_result.resolution === :terminal_deferred
        @test !fixture.compile_result.accepted
        @test fixture.compile_result.claim_ceiling === :contract_only
        @test isempty(fixture.compile_result.errors)
        @test fixture.compile_result.gaps == (
            :native_g1g2_numerical_execution_pending,
            :up1_aggregate_gate_pending,
            :g3_material_conversion_missing,
            :g3_two_region_interface_missing)
        @test NG12_R.validate_native_g1g2_diffusion_compilation_v1(compilation)

        expected_unknown = NG12_G.canonical_json(
            NG12_R._ng12_unknown_expression_body(chain.programs.unknown_program,
                chain.programs.reference_program, chain.programs.parameters,
                chain.profile.profile_hash))
        expected_source = NG12_G.canonical_json(
            NG12_R._ng12_source_expression_body(chain.programs.source_program,
                chain.programs.parameters, chain.profile.profile_hash))
        @test chain.g1.u.source_expression == expected_unknown
        @test chain.g1.f.source_expression == expected_source
        @test chain.g1.source_payload.u.source_expression == expected_unknown
        @test chain.g1.source_payload.f.source_expression == expected_source
        @test chain.g1.source_hash ==
            NG12_G.g1_diffusion_source_hash_v1(chain.g1.source_payload)
        g1_manifest = only(d for d in chain.admission.package.declarations
            if d.layer === :G1)
        g2_manifest = only(d for d in chain.admission.package.declarations
            if d.layer === :G2)
        @test NG12_G.copy_bytes(g1_manifest.declaration_bytes) ==
            Vector{UInt8}(codeunits(NG12_G.canonical_json(chain.g1)))
        @test NG12_G.copy_bytes(g2_manifest.declaration_bytes) ==
            Vector{UInt8}(codeunits(NG12_G.canonical_json(chain.g2)))
        @test isempty(NG12_R.native_g1g2_t1_binding_errors_v1(
            chain.admission, chain.g1, chain.g2))
        @test isempty(NG12_R.native_g1g2_physics_errors_v1(
            chain.g1, chain.g2, chain.programs, chain.profile))

        residual = chain.programs.residual_program
        operator_ids = Tuple(node isa NG12_G.ASTApplyV1 ?
            node.operator_ref.qualified.id : "" for node in residual.nodes)
        @test operator_ids[4:8] == ("GRAD",
            NG12_R.NATIVE_G1G2_K_APPLY_OPERATOR_V1,
            "DIV_OP", "NEG", "SUB")
        @test Tuple(residual.nodes[i].inputs for i in 4:8) ==
            ((1,), (2, 4), (5,), (6,), (7, 3))
        @test NG12_R.native_g1g2_translate_unit_v1(chain.profile,
            ng12_native_length(1)) == NG12_R._ng12_si_length_unit(1)
        @test NG12_R.native_g1g2_translate_unit_v1(chain.profile,
            NG12_G.UnitSignature()) == NG12_G.UnitSignature()
        @test ng12_expect_code(() -> NG12_R.native_g1g2_translate_unit_v1(
            chain.profile, ng12_native_unit((0, 0, 0, 0, 0, 0, 1))),
            "undocumented non-length axis")
        @test ng12_expect_code(() ->
            NG12_R.native_g1g2_unit_compatibility_profile_v1(
                length_scale_metres=2 // 1), "one-metre")
        @test ng12_expect_code(() ->
            NG12_R.native_g1g2_unit_compatibility_profile_v1(
                source_basis="RuntimeV4/SI-kg-m-s-A-K-mol-cd-v1"),
            "native length-first basis")
        @test form.t1_package === chain.admission.package
    end
end

Base.@noinline Base.@nospecializeinfer function ng12_primary_compile_boundary_tests(fixture, chain, form,
        altered_mesh_chain_out, tensor_execution_out)
    Base.@nospecialize fixture chain form altered_mesh_chain_out tensor_execution_out
    ng12_stage("primary.compile_boundary.body_entry")
    @testset "compile boundary negatives" begin
        bad_source = ng12_g1_declaration(chain.candidate, chain.programs;
            source_expression="f_candidate(x)=1")
        @test :g1_source_payload_mismatch in
            NG12_R.native_g1g2_physics_errors_v1(bad_source, chain.g2,
                chain.programs, chain.profile)

        short_k = ng12_g1_declaration(chain.candidate, chain.programs;
            domain_min=(0, 0, 0), domain_max=(1, 1, 1))
        @test :k_domain_does_not_cover_physical_chart in
            NG12_R.native_g1g2_physics_errors_v1(short_k, chain.g2,
                chain.programs, chain.profile)

        mixed = ng12_g2_declaration(all_zero_dirichlet=false)
        @test :boundary_not_all_zero_dirichlet in
            NG12_R.native_g1g2_physics_errors_v1(chain.g1, mixed,
                chain.programs, chain.profile)

        wrong_units = ng12_g2_declaration(
            field_unit=ng12_native_unit((0, 0, 0, 0, 0, 0, 1)),
            flux_unit=ng12_native_unit((0, 0, 0, 0, 0, 1, 0)))
        wrong_unit_errors = NG12_R.native_g1g2_physics_errors_v1(chain.g1,
            wrong_units, chain.programs, chain.profile)
        @test :g1_g2_field_unit_mismatch in wrong_unit_errors
        @test :g1_g2_flux_unit_mismatch in wrong_unit_errors
        @test :unit_basis_translation_rejected in wrong_unit_errors

        shear = ng12_g2_declaration(
            chart_rows=((2, 1 // 10, 0), (0, 3, 0), (0, 0, 4)))
        @test :unsupported_non_diagonal_or_reversing_chart in
            NG12_R.native_g1g2_physics_errors_v1(chain.g1, shear,
                chain.programs, chain.profile)

        legacy_g1 = ng12_g1_declaration(chain.candidate, chain.programs;
            domain_min=(0, 0, 0), domain_max=(1, 1, 1),
            unknown_source_expression="legacy-unknown-expression",
            source_expression="legacy-source-expression")
        legacy_g2 = ng12_g2_declaration(all_zero_dirichlet=false,
            field_unit=ng12_native_unit((0, 0, 0, 0, 0, 0, 1)),
            flux_unit=ng12_native_unit((0, 0, 0, 0, 0, 1, 0)))
        old_errors = NG12_R.native_g1g2_physics_errors_v1(
            legacy_g1, legacy_g2, chain.programs, chain.profile)
        @test :g1_unknown_reference_payload_mismatch in old_errors
        @test :g1_source_payload_mismatch in old_errors
        @test :k_domain_does_not_cover_physical_chart in old_errors
        @test :boundary_not_all_zero_dirichlet in old_errors
        @test :g1_g2_field_unit_mismatch in old_errors

        foreign = ng12_current_source_native_chain(
            NG12_CURRENT_SOURCE_MMS_FOREIGN_CANDIDATE_DIR)
        foreign_compile = NG12_R.compile_native_g1g2_diffusion_v1(
            foreign.admission, chain.g1, chain.g2, chain.programs,
            chain.profile)
        @test foreign_compile.status === :fail_closed
        @test foreign_compile.compilation === nothing
        @test :t1_candidate_g1_mismatch in foreign_compile.errors
        @test :t1_g1_declaration_carrier_mismatch in foreign_compile.errors
        @test NG12_G.canonical_json(foreign.g2) ==
            NG12_G.canonical_json(chain.g2)

        expected_alternative_programs = ng12_alternative_source_program_bundle(
            chain.profile, chain.programs)
        alternative_chain = ng12_current_source_native_chain(
            NG12_CURRENT_SOURCE_MMS_ALTERNATIVE_DIR)
        @test alternative_chain.admission.status === :prepared_not_executed
        @test alternative_chain.candidate != chain.candidate
        alternative_programs = alternative_chain.programs
        @test NG12_G.canonical_json(alternative_programs) ==
            NG12_G.canonical_json(expected_alternative_programs)
        @test alternative_chain.g1.f.source_expression ==
            alternative_programs.source_expression
        alternative_errors = NG12_R.native_g1g2_physics_errors_v1(
            alternative_chain.g1, alternative_chain.g2, alternative_programs,
            alternative_chain.profile)
        @test :program_semantic_projection_mismatch in alternative_errors
        alternative_compile = NG12_R.compile_native_g1g2_diffusion_v1(
            alternative_chain.admission, alternative_chain.g1,
            alternative_chain.g2, alternative_programs,
            alternative_chain.profile)
        @test alternative_compile.status === :fail_closed
        @test alternative_compile.compilation === nothing

        altered_mesh_chain = ng12_current_source_native_chain(
            NG12_CURRENT_SOURCE_MMS_MESH_VARIANT_DIR)
        altered_mesh_chain_out[] = altered_mesh_chain
        mismatched_g2_compile = NG12_R.compile_native_g1g2_diffusion_v1(
            chain.admission, chain.g1, altered_mesh_chain.g2,
            chain.programs, chain.profile)
        @test mismatched_g2_compile.status === :fail_closed
        @test :t1_g2_declaration_carrier_mismatch in
            mismatched_g2_compile.errors
        altered_mesh_compile = NG12_R.compile_native_g1g2_diffusion_v1(
            altered_mesh_chain.admission, altered_mesh_chain.g1,
            altered_mesh_chain.g2, altered_mesh_chain.programs,
            altered_mesh_chain.profile)
        @test altered_mesh_compile.status === :compiled_numerical_preparation
        @test ng12_expect_code(() ->
            NG12_R.prepare_gridap_native_g1g2_diffusion_v1(
                altered_mesh_compile, fixture.protocol),
            "error budget does not apply")

        altered_k_programs = NG12_R.native_g1g2_program_bundle_v1(
            chain.profile; physical_lower=NG12_PHYSICAL_LOWER,
            physical_upper=NG12_PHYSICAL_UPPER,
            k_base_matrix=NG12_TENSOR_K_BASE,
            k_slope_matrices=NG12_TENSOR_K_SLOPES)
        altered_k_chain = ng12_current_source_native_chain(
            NG12_CURRENT_SOURCE_MMS_K_VARIANT_DIR)
        @test altered_k_chain.programs.bundle_hash == altered_k_programs.bundle_hash
        altered_k_compile = NG12_R.compile_native_g1g2_diffusion_v1(
            altered_k_chain.admission, altered_k_chain.g1,
            altered_k_chain.g2, altered_k_programs, chain.profile)
        @test altered_k_compile.status === :compiled_numerical_preparation
        @test isempty(altered_k_compile.errors)
        tensor_expression = altered_k_chain.g1.K.expression
        @test tensor_expression isa NG12_G.G1DiffusionSymmetricAffineTensorKFieldV2
        @test tensor_expression.base_matrix ==
            altered_k_programs.parameters.k_base_matrix
        @test tensor_expression.slope_matrices ==
            altered_k_programs.parameters.k_slope_matrices
        tampered_tensor_base = ((3 // 1, 1 // 9, 0 // 1),
            (1 // 9, 3 // 1, 0 // 1), (0 // 1, 0 // 1, 4 // 1))
        tampered_tensor_programs = NG12_R.native_g1g2_program_bundle_v1(
            chain.profile; physical_lower=NG12_PHYSICAL_LOWER,
            physical_upper=NG12_PHYSICAL_UPPER,
            k_base_matrix=tampered_tensor_base,
            k_slope_matrices=NG12_TENSOR_K_SLOPES)
        tampered_tensor_compile = NG12_R.compile_native_g1g2_diffusion_v1(
            altered_k_chain.admission, altered_k_chain.g1,
            altered_k_chain.g2, tampered_tensor_programs, chain.profile)
        @test tampered_tensor_compile.status === :fail_closed
        @test :k_base_matrix_mismatch in tampered_tensor_compile.errors
        @test ng12_expect_code(() ->
            NG12_R.prepare_gridap_native_g1g2_diffusion_v1(
                altered_k_compile, fixture.protocol),
            "error budget does not apply")
        tensor_coefficients = (physical_lower=tensor_expression.domain_min,
            physical_upper=tensor_expression.domain_max,
            base_matrix=tensor_expression.base_matrix,
            slope_matrices=tensor_expression.slope_matrices)
        tensor_protocol = NG12_R.native_g1g2_numerical_protocol_v1(
            altered_k_chain.g2.source.mesh.cells;
            tensor_coefficients=tensor_coefficients)
        tensor_plan = NG12_R.prepare_gridap_native_g1g2_diffusion_v1(
            altered_k_compile, tensor_protocol)
        @test NG12_R.validate_native_g1g2_gridap_plan_v1(tensor_plan)
        tensor_form = altered_k_compile.compilation.form
        tensor_points = ((3 / 4, 7 / 6, 5 / 4),
            (3 / 2, 11 / 6, 9 / 4), (9 / 4, 17 / 6, 15 / 4),
            (5 / 8, 19 / 12, 33 / 16))
        for point in tensor_points
            actual_k = NG12_R.native_g1g2_k_tensor_v1(tensor_form, point)
            oracle_k = ng12_tensor_oracle_k(point)
            @test all(isapprox(actual_k[i][j], oracle_k[i][j];
                atol=2e-15, rtol=2e-15) for i in 1:3 for j in 1:3)
            @test isapprox(NG12_R.native_g1g2_source_value_v1(
                tensor_form, point), ng12_tensor_oracle_source(point);
                atol=2e-14, rtol=2e-14)
        end
        for axis in 1:3, side in 0:1
            boundary_point = ntuple(i -> i == axis ?
                Float64(side == 0 ? NG12_PHYSICAL_LOWER[i] :
                    NG12_PHYSICAL_UPPER[i]) :
                (Float64(NG12_PHYSICAL_LOWER[i]) +
                    Float64(NG12_PHYSICAL_UPPER[i])) / 2, 3)
            @test NG12_R.native_g1g2_reference_value_v1(
                tensor_form, boundary_point) == 0.0
            boundary_k = NG12_R.native_g1g2_k_tensor_v1(
                tensor_form, boundary_point)
            oracle_boundary_k = ng12_tensor_oracle_k(boundary_point)
            @test all(isapprox(boundary_k[i][j], oracle_boundary_k[i][j];
                atol=2e-15, rtol=2e-15) for i in 1:3 for j in 1:3)
        end
        tensor_balance = NG12_R.native_g1g2_continuous_balance_v1(tensor_form)
        oracle_tensor_balance = ng12_tensor_oracle_balance()
        @test isapprox(tensor_balance.source_integral,
            oracle_tensor_balance.source_integral; atol=2e-13, rtol=2e-13)
        @test isapprox(tensor_balance.outward_conormal_integral,
            oracle_tensor_balance.outward_conormal_integral;
            atol=2e-13, rtol=2e-13)
        @test abs(oracle_tensor_balance.defect) <= 2e-13
        @test abs(ng12_tensor_oracle_source(tensor_points[1]) -
            ng12_tensor_oracle_source_diagonal_only(tensor_points[1])) > 1e-6
        tensor_bundle = NG12_R.execute_native_g1g2_gridap_once!(
            Dict{Any,Any}(), tensor_plan)
        @test NG12_R.validate_native_g1g2_execution_bundle_v1(
            tensor_plan, tensor_bundle)
        @test tensor_bundle.invocation_counts == (compiler_calls=1,
            provider_calls=1, mesh_calls=3, assembly_calls=6,
            solver_calls=3, formal_t2_consumer_receipts=0)
        tensor_execution_out[] = (candidate_ref=altered_k_chain.candidate,
            source_witness_hash=NG12_G.canonical_hash(altered_k_chain.witness),
            g1_declaration_hash=altered_k_chain.g1.declaration_hash,
            g2_declaration_hash=altered_k_chain.g2.declaration_hash,
            program_bundle_hash=altered_k_programs.bundle_hash,
            compile_result_hash=altered_k_compile.result_hash,
            protocol_hash=tensor_protocol.protocol_hash,
            plan=tensor_plan, bundle=tensor_bundle)

        forged_form_body = NG12_R._ng12_form_body(NG12_FOREIGN_CANDIDATE,
            form.t1_package_hash,
            form.t1_semantic_identity, form.t0_bundle_hash,
            form.g1_declaration, form.g2_declaration, form.programs,
            form.authored_source_capability, form.unit_profile, form.weak_form_sign,
            form.coordinate_semantics, form.boundary_semantics)
        forged_form = NG12_R.NativeG1G2VariableDiffusionFormV1(
            NG12_FOREIGN_CANDIDATE, form.t1_package, form.t1_package_hash,
            form.t1_semantic_identity, form.t0_bundle_hash,
            form.g1_declaration, form.g2_declaration, form.programs,
            form.authored_source_capability, form.unit_profile, form.weak_form_sign,
            form.coordinate_semantics, form.boundary_semantics,
            NG12_G.canonical_hash(forged_form_body))
        @test !NG12_R._ng12_form_integrity(forged_form)
    end
end

function ng12_replay_tensor_execution(fixture)
    chain = ng12_current_source_native_chain(
        NG12_CURRENT_SOURCE_MMS_K_VARIANT_DIR)
    programs = NG12_R.native_g1g2_program_bundle_v1(
        fixture.chain.profile; physical_lower=NG12_PHYSICAL_LOWER,
        physical_upper=NG12_PHYSICAL_UPPER,
        k_base_matrix=NG12_TENSOR_K_BASE,
        k_slope_matrices=NG12_TENSOR_K_SLOPES)
    compilation = NG12_R.compile_native_g1g2_diffusion_v1(
        chain.admission, chain.g1, chain.g2, programs, fixture.chain.profile)
    expression = chain.g1.K.expression
    coefficients = (physical_lower=expression.domain_min,
        physical_upper=expression.domain_max,
        base_matrix=expression.base_matrix,
        slope_matrices=expression.slope_matrices)
    protocol = NG12_R.native_g1g2_numerical_protocol_v1(
        chain.g2.source.mesh.cells; tensor_coefficients=coefficients)
    plan = NG12_R.prepare_gridap_native_g1g2_diffusion_v1(
        compilation, protocol)
    bundle = NG12_R.execute_native_g1g2_gridap_once!(Dict{Any,Any}(), plan)
    (chain=chain, programs=programs, compilation=compilation,
        protocol=protocol, plan=plan, bundle=bundle)
end

function ng12_primary_analytic_oracle_tests(form)
    @testset "independent analytic oracle" begin
        points = ((3 / 4, 7 / 6, 5 / 4),
            (3 / 2, 11 / 6, 9 / 4),
            (9 / 4, 17 / 6, 15 / 4))
        for point in points
            @test isapprox(NG12_R.native_g1g2_reference_value_v1(form, point),
                ng12_oracle_reference(point); atol=2e-15, rtol=2e-15)
            @test all(isapprox.(
                NG12_R.native_g1g2_reference_gradient_v1(form, point),
                ng12_oracle_gradient(point); atol=2e-15, rtol=2e-15))
            @test all(isapprox.(NG12_R.native_g1g2_k_diagonal_v1(form, point),
                ng12_oracle_k(point); atol=2e-15, rtol=2e-15))
            @test isapprox(NG12_R.native_g1g2_source_value_v1(form, point),
                ng12_oracle_source(point); atol=2e-15, rtol=2e-15)
        end
        derivative_point = points[1]
        @test abs(ng12_oracle_source(derivative_point) -
            ng12_oracle_source_without_grad_k(derivative_point)) > 1e-6
        balance = NG12_R.native_g1g2_continuous_balance_v1(form)
        independent_balance = ng12_oracle_continuous_balance()
        @test isapprox(balance.source_integral,
            independent_balance.source_integral; atol=2e-15, rtol=2e-15)
        @test isapprox(balance.outward_conormal_integral,
            independent_balance.outward_conormal_integral;
            atol=2e-15, rtol=2e-15)
        @test independent_balance.defect == 0.0
        for axis in 1:3, side in 0:1
            point = ntuple(i -> i == axis ?
                Float64(side == 0 ? NG12_PHYSICAL_LOWER[i] :
                    NG12_PHYSICAL_UPPER[i]) :
                (Float64(NG12_PHYSICAL_LOWER[i]) +
                    Float64(NG12_PHYSICAL_UPPER[i])) / 2, 3)
            @test ng12_oracle_reference(point) == 0.0
        end
    end
end

Base.@noinline Base.@nospecializeinfer function ng12_primary_provider_plan_tests(fixture, chain, plan)
    Base.@nospecialize fixture chain plan
    ng12_stage("primary.provider_plan.body_entry")
    @testset "provider plan and immutable protocol" begin
        @test NG12_R.validate_native_g1g2_gridap_plan_v1(plan)
        plan_admission = NG12_R.native_g1g2_gridap_plan_admission_v1(plan)
        @test plan_admission isa NG12_R.NativeG1G2GridapPlanAdmissionV1
        @test NG12_R.validate_native_g1g2_gridap_plan_admission_v1(
            plan, plan_admission)
        original_context_hash = plan_admission.context_hash
        plan_admission.context_hash = NG12_G.Digest256(repeat("0", 64))
        @test !NG12_R.validate_native_g1g2_gridap_plan_admission_v1(
            plan, plan_admission)
        plan_admission.context_hash = original_context_hash
        @test NG12_R.validate_native_g1g2_gridap_plan_admission_v1(
            plan, plan_admission)
        @test !NG12_R.validate_native_g1g2_gridap_plan_admission_v1(
            plan, deepcopy(plan_admission))
        cross_plan = NG12_R.NativeG1G2GridapPlanV1(plan.compilation,
            NG12_G.Digest256(repeat("0", 64)), plan.protocol,
            plan.dependency_identity, plan.provider, plan.subject,
            plan.solver_input, plan.adapter_source_hash, plan.plan_hash)
        @test !NG12_R.validate_native_g1g2_gridap_plan_admission_v1(
            cross_plan, plan_admission)
        @test !NG12_R.validate_native_g1g2_gridap_plan_v1(cross_plan)
        @test ng12_expect_code(() ->
            NG12_R._ng12_register_executor_plan_admission_v1(cross_plan),
            "Gridap plan has no current admission")
        alternate_snapshot = mktempdir()
        write(joinpath(alternate_snapshot, "manifest.toml"),
            "# alternate snapshot manifest\n")
        alternate_receipt = joinpath(alternate_snapshot, "receipt.json")
        write(alternate_receipt, "{}")
        alternate_receipt_sha = bytes2hex(SHA.sha256(read(alternate_receipt)))
        accepted_under_wrong_snapshot = withenv(
                "UP1_FROZEN_SNAPSHOT_ROOT" => alternate_snapshot,
                "UP1_FROZEN_RECEIPT_PATH" => alternate_receipt,
                "UP1_FROZEN_RECEIPT_SHA256" => alternate_receipt_sha) do
            NG12_R.validate_native_g1g2_gridap_plan_admission_v1(
                plan, plan_admission)
        end
        @test !accepted_under_wrong_snapshot
        @test plan.subject.materialized_payload.compile_result_hash ==
            fixture.compile_result.result_hash
        @test plan.provider.executor ===
            NG12_R._native_g1g2_gridap_provider_executor_v1
        @test !isdefined(NG12_R, :_NG12_ACTIVE_PROVIDER_PLAN)
        @test plan.protocol.cell_counts == ((2, 3, 4), (4, 6, 8),
            (8, 12, 16))
        @test plan.protocol.quadrature_degree == 8
        @test plan.protocol.residual_abs_tol == 1e-9
        @test plan.protocol.residual_rel_tol == 1e-11
        @test plan.protocol.boundary_abs_tol == 1e-10
        @test plan.protocol.source_integral_abs_tol == 1e-10
        @test plan.protocol.analytic_identity_abs_tol == 1e-12
        @test plan.protocol.reaction_balance_abs_tol == 1e-9
        @test plan.protocol.l2_order_interval == (1.4, 2.6)
        @test plan.protocol.h1_order_interval == (0.6, 1.4)
        @test plan.protocol.finest_l2_max == 5e-3
        @test plan.protocol.finest_h1_seminorm_max == 1e-2
        budget = plan.protocol.budget_basis
        @test budget == NG12_R.native_g1g2_error_budget_basis_v1()
        @test budget.physical_lower_metres == NG12_PHYSICAL_LOWER
        @test budget.physical_upper_metres == NG12_PHYSICAL_UPPER
        @test budget.physical_lengths_metres == NG12_PHYSICAL_LENGTHS
        @test budget.k_base == NG12_K_BASE
        @test budget.k_slope == NG12_K_SLOPE
        @test budget.poincare_finest_l2_bound_m32 <
            plan.protocol.finest_l2_max
        @test budget.cea_finest_h1_bound_m12 <
            plan.protocol.finest_h1_seminorm_max
        @test budget.gridap_quadrature_degree ==
            plan.protocol.quadrature_degree
        @test plan.protocol.cell_counts[1] == chain.g2.source.mesh.cells
        @test plan.provider.domain.declared_g2_quadrature_role ===
            :identity_bound_geometry_metadata_not_execution_rule
        @test plan.subject.materialized_payload.formal_t2_receipt_assignment ===
            false
        staged = NG12_R.stage_gridap_native_g1g2_diffusion_v1(
            fixture.compile_result, plan.protocol)
        @test staged isa NG12_R.NativeG1G2GridapStagedPlanV1
        @test staged.plan.plan_hash == plan.plan_hash
        @test staged.validation_state === :plan_validation_deferred
        @test staged.numerical_execution === :not_executed
        @test !staged.accepted
        @test !hasproperty(staged, :plan_admission)
        executor_admission_key =
            NG12_R._ng12_register_executor_plan_admission_v1(plan)
        try
            @test NG12_R._ng12_admitted_executor_plan_v1(
                plan.solver_input) === plan
            input = plan.solver_input
            wrong_input = NG12_R.SolverInputV4(
                input.physical_subject_hash, input.scenario_hash,
                input.provider_manifest_hash,
                NG12_G.Digest256(repeat("1", 64)), input.payload)
            @test NG12_R._ng12_admitted_executor_plan_v1(wrong_input) === nothing
            alternate_executor_snapshot = mktempdir()
            write(joinpath(alternate_executor_snapshot, "manifest.toml"),
                "# changed executor snapshot\n")
            alternate_executor_receipt = joinpath(
                alternate_executor_snapshot, "receipt.json")
            write(alternate_executor_receipt, "{}")
            alternate_executor_receipt_sha = bytes2hex(
                SHA.sha256(read(alternate_executor_receipt)))
            @test_throws ArgumentError withenv(
                    "UP1_FROZEN_SNAPSHOT_ROOT" => alternate_executor_snapshot,
                    "UP1_FROZEN_RECEIPT_PATH" => alternate_executor_receipt,
                    "UP1_FROZEN_RECEIPT_SHA256" =>
                        alternate_executor_receipt_sha) do
                NG12_R._ng12_admitted_executor_plan_v1(input)
            end
        finally
            NG12_R._ng12_unregister_executor_plan_admission_v1!(
                executor_admission_key, plan)
        end
    end
end

Base.@noinline Base.@nospecializeinfer function ng12_primary_handoff_tests(fixture, chain, compilation, plan,
        bundle, reversed, altered_mesh_chain)
    Base.@nospecialize fixture chain compilation plan bundle reversed altered_mesh_chain
    ng12_stage("primary.handoff.body_entry")
    @testset "executed local T1 to Gridap handoff" begin
        handoff = NG12_R.finalize_native_g1g2_t1_handoff_v1(
            chain.admission, compilation, plan, bundle)
        @test handoff isa NG12_R.NativeG1G2T1RuntimeHandoffV1
        @test handoff.status === :executed_local
        @test handoff.resolution === :terminal_deferred
        @test handoff.candidate_ref == chain.candidate
        @test handoff.package_hash == chain.admission.package.package_hash
        @test handoff.semantic_identity ==
            chain.admission.package.semantic_identity
        @test handoff.wire_hash == chain.admission.package.wire.sha256
        @test handoff.t0_bundle_hash == chain.admission.package.bundle_hash
        @test handoff.scenario_hash == plan.solver_input.scenario_hash
        @test handoff.bundle_hash == bundle.bundle_hash
        @test handoff.report_hash == bundle.report.report_hash
        @test !handoff.accepted
        @test handoff.claim_ceiling === NG12_G.screen_only
        @test handoff.physical_status === :unknown
        @test isempty(handoff.errors)
        @test NG12_R.validate_native_g1g2_t1_runtime_handoff_v1(
            chain.admission, compilation, plan, bundle, handoff)
        altered_handoff = NG12_R.NativeG1G2T1RuntimeHandoffV1(
            handoff.status, handoff.resolution, handoff.candidate_ref,
            handoff.package_hash, handoff.semantic_identity, handoff.wire_hash,
            handoff.t0_bundle_hash, handoff.scenario_hash, handoff.bundle_hash,
            NG12_G.digest256_text("tampered-report"), handoff.accepted,
            handoff.claim_ceiling, handoff.physical_status, handoff.errors,
            handoff.gaps, handoff.result_hash)
        @test !NG12_R.validate_native_g1g2_t1_runtime_handoff_v1(
            chain.admission, compilation, plan, bundle, altered_handoff)

        # T1 admission remains a prepared local package.  Runtime execution
        # yields a separate handoff and does not rewrite its claim ceiling.
        @test chain.admission.status === :prepared_not_executed
        @test chain.admission.resolution === :terminal_deferred
        @test !chain.admission.accepted
        @test chain.admission.claim_ceiling === :contract_only

        foreign_chain = ng12_current_source_native_chain(
            NG12_CURRENT_SOURCE_MMS_FOREIGN_CANDIDATE_DIR)
        @test_throws ArgumentError NG12_R.finalize_native_g1g2_t1_handoff_v1(
            foreign_chain.admission, compilation, plan, bundle)

        same_candidate_other_package = altered_mesh_chain
        @test same_candidate_other_package.candidate == chain.candidate
        @test same_candidate_other_package.admission.package.package_hash !=
            chain.admission.package.package_hash
        @test_throws ArgumentError NG12_R.finalize_native_g1g2_t1_handoff_v1(
            same_candidate_other_package.admission, compilation, plan, bundle)

        package = chain.admission.package
        wire_bytes = NG12_G.copy_bytes(package.wire)
        push!(wire_bytes, 0x00)
        tampered_wire = NG12_G.VNextT1CanonicalBytesV2(wire_bytes)
        tampered_package = NG12_G.CandidateStatePackageV5NextV2(
            package.schema_id, package.schema_version,
            package.canonicalization_version, package.profile_version,
            package.candidate_ref, package.bundle_hash, package.declarations,
            package.children, package.feedback, package.axes,
            package.parent_commitments, package.g3_authority, tampered_wire,
            package.semantic_identity, package.package_hash, package.status,
            package.resolution, package.accepted, package.claim_ceiling)
        tampered_admission = ng12_admission_with_package(chain.admission,
            tampered_package)
        @test_throws ArgumentError NG12_R.finalize_native_g1g2_t1_handoff_v1(
            tampered_admission, compilation, plan, bundle)

        alternate_scenario_compile = NG12_R.compile_native_g1g2_diffusion_v1(
            chain.admission, chain.g1, chain.g2, chain.programs, chain.profile;
            scenario=(scenario_id="native-g1g2-foreign-scenario-v1",
                execution_scope=:numerical_preparation))
        alternate_scenario_plan =
            NG12_R.prepare_gridap_native_g1g2_diffusion_v1(
                alternate_scenario_compile, fixture.protocol)
        @test_throws ArgumentError NG12_R.finalize_native_g1g2_t1_handoff_v1(
            chain.admission, alternate_scenario_compile.compilation,
            alternate_scenario_plan, bundle)

        @test reversed.status === :numerical_fail
        @test reversed.source_sign === :reversed_test_control
        @test_throws MethodError NG12_R.finalize_native_g1g2_t1_handoff_v1(
            chain.admission, compilation, plan, reversed)
    end
end

Base.@noinline Base.@nospecializeinfer function ng12_primary_execution_receipt_tests(fixture, chain, compilation,
        plan, bundle, store, cached, reversed)
    Base.@nospecialize fixture chain compilation plan bundle store cached reversed
    ng12_stage("primary.execution_receipts.body_entry")
    @testset "actual Gridap solve and adversarial receipts" begin
        @test length(store) == 1
        @test cached.bundle_hash == bundle.bundle_hash
        @test NG12_R.validate_native_g1g2_execution_bundle_v1(plan, bundle)
        report = bundle.report
        @test NG12_R.validate_native_g1g2_gridap_report_v1(plan, report)
        source_state = report.levels[1].field_state
        @test NG12_R._ng12_q1_field_state_valid(source_state)

        changed = collect(source_state.component_dof_values[1])
        changed[first(source_state.free_to_full)] += 0.125
        forged = ng12_rehashed_q1_field_state(source_state; component_dof_values=(Tuple(changed),))
        @test NG12_R._ng12_q1_field_state_valid(forged)
        @test !NG12_R.validate_native_g1g2_gridap_report_v1(plan,
            ng12_rehashed_report(report; levels=(ng12_rehashed_level(report.levels[1]; field_state=forged), report.levels[2], report.levels[3])))

        changed = collect(source_state.component_dof_values[1])
        changed[first(source_state.boundary_to_full)] = 0.125
        forged = ng12_rehashed_q1_field_state(source_state; component_dof_values=(Tuple(changed),))
        @test !NG12_R._ng12_q1_field_state_valid(forged)
        @test !NG12_R.validate_native_g1g2_gridap_report_v1(plan,
            ng12_rehashed_report(report; levels=(ng12_rehashed_level(report.levels[1]; field_state=forged), report.levels[2], report.levels[3])))

        changed_coords = collect(source_state.dof_coordinates)
        i = first(source_state.free_to_full); p = changed_coords[i]
        changed_coords[i] = (p[1]+1e-6, p[2], p[3])
        forged_entity = NG12_R._ng12_g2_entity_ownership_v1(
            plan.compilation.form.g2_declaration.source, source_state.cell_counts,
            Tuple(changed_coords), source_state.cell_dof_ids)
        forged = ng12_rehashed_q1_field_state(source_state;
            dof_coordinates=Tuple(changed_coords), g2_entity_ownership=forged_entity)
        @test NG12_R._ng12_q1_field_state_valid(forged)
        @test !NG12_R.validate_native_g1g2_gridap_report_v1(plan,
            ng12_rehashed_report(report; levels=(ng12_rehashed_level(report.levels[1]; field_state=forged), report.levels[2], report.levels[3])))

        changed_cells = collect(source_state.cell_dof_ids)
        ids = collect(changed_cells[1]); ids[1],ids[2]=ids[2],ids[1]; changed_cells[1]=Tuple(ids)
        forged_entity = NG12_R._ng12_g2_entity_ownership_v1(
            plan.compilation.form.g2_declaration.source, source_state.cell_counts,
            source_state.dof_coordinates, Tuple(changed_cells))
        forged = ng12_rehashed_q1_field_state(source_state;
            cell_dof_ids=Tuple(changed_cells), g2_entity_ownership=forged_entity)
        @test NG12_R._ng12_q1_field_state_valid(forged)
        @test !NG12_R.validate_native_g1g2_gridap_report_v1(plan,
            ng12_rehashed_report(report; levels=(ng12_rehashed_level(report.levels[1]; field_state=forged), report.levels[2], report.levels[3])))

        changed_free = collect(source_state.free_to_full)
        changed_free[1],changed_free[2]=changed_free[2],changed_free[1]
        forged = ng12_rehashed_q1_field_state(source_state; free_to_full=Tuple(changed_free))
        @test NG12_R._ng12_q1_field_state_valid(forged)
        @test !NG12_R.validate_native_g1g2_gridap_report_v1(plan,
            ng12_rehashed_report(report; levels=(ng12_rehashed_level(report.levels[1]; field_state=forged), report.levels[2], report.levels[3])))

        forged = ng12_rehashed_q1_field_state(source_state;
            g2_source_hash=NG12_G.digest256_text("forged-g2-source-binding"))
        @test NG12_R._ng12_q1_field_state_valid(forged)
        @test !NG12_R.validate_native_g1g2_gridap_report_v1(plan,
            ng12_rehashed_report(report; levels=(ng12_rehashed_level(report.levels[1]; field_state=forged), report.levels[2], report.levels[3])))

        changed_faces = collect(source_state.face_dof_full_ids)
        f = changed_faces[1]
        reversed_ids = Tuple(reverse(collect(f.dof_full_ids)))
        changed_faces[1] = merge(f, (dof_full_ids=reversed_ids,))
        forged = ng12_rehashed_q1_field_state(source_state; face_dof_full_ids=Tuple(changed_faces))
        @test NG12_R._ng12_q1_field_state_valid(forged)
        @test !NG12_R.validate_native_g1g2_gridap_report_v1(plan,
            ng12_rehashed_report(report; levels=(ng12_rehashed_level(report.levels[1]; field_state=forged), report.levels[2], report.levels[3])))

        forged_ownership = merge(source_state.g2_entity_ownership, (reason=:forged_region_map,))
        forged = ng12_rehashed_q1_field_state(source_state; g2_entity_ownership=forged_ownership)
        @test NG12_R._ng12_q1_field_state_valid(forged)
        @test !NG12_R.validate_native_g1g2_gridap_report_v1(plan,
            ng12_rehashed_report(report; levels=(ng12_rehashed_level(report.levels[1]; field_state=forged), report.levels[2], report.levels[3])))

        @test !NG12_R.validate_native_g1g2_gridap_report_v1(plan,
            ng12_rehashed_report(report; levels=(ng12_rehashed_level(report.levels[1];
                field_state=ng12_rehashed_q1_field_state(source_state; candidate_ref=NG12_FOREIGN_CANDIDATE)),
                report.levels[2], report.levels[3])))
        @test !NG12_R._ng12_q1_field_state_valid(ng12_rehashed_q1_field_state(source_state; component_dof_values=()))
        @test !NG12_R._ng12_q1_field_state_valid(ng12_rehashed_q1_field_state(source_state; component_orientations=(:vector_covariant,)))

        @test report.status === :pass
        @test report.gaps == (
            :up1_aggregate_gate_pending,
            :g3_material_conversion_missing,
            :g3_two_region_interface_missing,
            :strong_trace_flux_is_nonconservative_diagnostic,
            :independent_physical_validation_missing)
        @test report.resolution === :terminal_deferred
        @test !report.accepted
        @test report.claim_ceiling == NG12_G.screen_only
        @test report.physical_status === :unknown
        @test isempty(report.errors)
        @test all(level.status === :pass for level in report.levels)
        @test all(level.source_sign === :declared for level in report.levels)
        @test all(level.residual_abs <= plan.protocol.residual_abs_tol ||
            level.residual_rel <= plan.protocol.residual_rel_tol
            for level in report.levels)
        @test all(level.boundary_linf <= plan.protocol.boundary_abs_tol
            for level in report.levels)
        @test all(level.source_integral_error <=
            plan.protocol.source_integral_abs_tol for level in report.levels)
        @test all(abs(level.analytic_identity_defect) <=
            plan.protocol.analytic_identity_abs_tol
            for level in report.levels)
        @test all(level.discrete_interior_reaction_linf <=
            plan.protocol.residual_abs_tol for level in report.levels)
        @test all(level.discrete_interior_residual_match_linf <=
            plan.protocol.residual_abs_tol for level in report.levels)
        @test all(level.free_dofs + level.dirichlet_dofs ==
            prod(level.cell_counts .+ 1) for level in report.levels)
        @test all(abs(level.discrete_boundary_reaction_balance_defect) <=
            plan.protocol.reaction_balance_abs_tol for level in report.levels)
        @test all(isapprox(level.discrete_boundary_reaction_balance_defect,
            -level.discrete_interior_reaction_sum;
            atol=plan.protocol.reaction_balance_abs_tol, rtol=0.0)
            for level in report.levels)
        @test all(report.levels[i].discrete_trace_conormal_error >
            report.levels[i + 1].discrete_trace_conormal_error for i in 1:2)
        @test all(plan.protocol.l2_order_interval[1] <= order <=
            plan.protocol.l2_order_interval[2] for order in report.l2_orders)
        @test all(plan.protocol.h1_order_interval[1] <= order <=
            plan.protocol.h1_order_interval[2] for order in report.h1_orders)
        @test report.levels[3].l2_error <= plan.protocol.finest_l2_max
        @test report.levels[3].h1_seminorm_error <=
            plan.protocol.finest_h1_seminorm_max
        @test length(unique(level.matrix_hash for level in report.levels)) == 3
        @test length(unique(level.rhs_hash for level in report.levels)) == 3
        @test length(unique(level.solution_hash for level in report.levels)) == 3
        independent_balance = ng12_oracle_continuous_balance()
        @test all(isapprox(level.analytic_source_integral,
            independent_balance.source_integral; atol=2e-15, rtol=2e-15)
            for level in report.levels)
        @test bundle.invocation_counts == (compiler_calls=1,
            provider_calls=1, mesh_calls=3, assembly_calls=6,
            solver_calls=3, formal_t2_consumer_receipts=0)
        @test !bundle.formal_t2_consumer_receipts_reclassified
        @test fixture.preparation_counts == (
            t0_source_record_factory_calls=3,
            v3_source_witness_calls=1, t1_admission_calls=1,
            compiler_calls=1)
        metrics = Dict(metric.name => metric for metric in bundle.evidence.metrics)
        @test metrics[:finest_l2_error].unit ==
            NG12_R._ng12_si_length_unit(3 // 2)
        @test metrics[:finest_h1_seminorm_error].unit ==
            NG12_R._ng12_si_length_unit(1 // 2)
        @test metrics[:max_algebraic_residual].unit ==
            NG12_R._ng12_si_length_unit(1)
        @test metrics[:max_source_integral_error].unit ==
            NG12_R._ng12_si_length_unit(1)
        @test metrics[:max_interior_reaction_linf].unit ==
            NG12_R._ng12_si_length_unit(1)
        @test metrics[:max_interior_residual_match_linf].unit ==
            NG12_R._ng12_si_length_unit(1)
        @test metrics[:max_discrete_boundary_reaction_balance_defect].unit ==
            NG12_R._ng12_si_length_unit(1)
        @test metrics[:solver_calls].unit == NG12_G.UnitSignature()

        @test reversed.status === :numerical_fail
        @test reversed.source_sign === :reversed_test_control
        @test reversed.analytic_source_integral < 0
        @test reversed.matrix_hash == report.levels[2].matrix_hash
        @test reversed.rhs_hash != report.levels[2].rhs_hash
        @test reversed.solution_hash != report.levels[2].solution_hash
        @test isapprox(reversed.assembled_source_integral,
            -report.levels[2].assembled_source_integral;
            atol=plan.protocol.source_integral_abs_tol, rtol=0.0)
        @test reversed.l2_error > report.levels[2].l2_error
        @test reversed.discrete_interior_reaction_linf <=
            plan.protocol.residual_abs_tol
        @test reversed.discrete_interior_residual_match_linf <=
            plan.protocol.residual_abs_tol
        @test abs(reversed.discrete_boundary_reaction_balance_defect) <=
            plan.protocol.reaction_balance_abs_tol
        @test isapprox(reversed.discrete_boundary_reaction_balance_defect,
            -reversed.discrete_interior_reaction_sum;
            atol=plan.protocol.reaction_balance_abs_tol, rtol=0.0)

        forged_level = ng12_rehashed_level(report.levels[1];
            analytic_source_integral=
                report.levels[1].analytic_source_integral + 1.0)
        @test NG12_R._ng12_level_integrity(forged_level)
        forged_levels = (forged_level, report.levels[2], report.levels[3])
        forged_report = ng12_rehashed_report(report; levels=forged_levels)
        @test !NG12_R.validate_native_g1g2_gridap_report_v1(plan,
            forged_report)

        forged_gaps = ng12_rehashed_report(report; gaps=(:forged_gap,))
        @test !NG12_R.validate_native_g1g2_gridap_report_v1(plan, forged_gaps)
        forged_pending_gap = ng12_rehashed_report(report;
            gaps=(:native_g1g2_numerical_execution_pending, report.gaps...))
        @test !NG12_R.validate_native_g1g2_gridap_report_v1(plan,
            forged_pending_gap)
        foreign_report = ng12_rehashed_report(report;
            candidate_ref=NG12_FOREIGN_CANDIDATE)
        @test !NG12_R.validate_native_g1g2_gridap_report_v1(plan,
            foreign_report)

        expected_evidence = bundle.evidence
        forged_evidence = NG12_R.RuntimeEvidenceV4(
            expected_evidence.physical_subject_hash,
            expected_evidence.scenario_hash,
            expected_evidence.solver_input_hash,
            expected_evidence.provider_manifest_hash,
            merge(expected_evidence.binding_provenance,
                (report_hash=NG12_G.digest256_text("foreign-report"),)),
            expected_evidence.status_vector, expected_evidence.metrics;
            claim_ceiling=expected_evidence.claim_ceiling,
            independence_group=expected_evidence.independence_group,
            provider_manifest=plan.provider,
            backend_revision=expected_evidence.backend_revision,
            numerical_configuration_hash=
                expected_evidence.numerical_configuration_hash,
            artifact_refs=expected_evidence.artifact_refs,
            uncertainty_or_null=expected_evidence.uncertainty_or_null)
        forged_bundle_body = NG12_R._ng12_execution_bundle_body(
            bundle.plan_hash, bundle.solver_input_hash, bundle.report,
            forged_evidence, bundle.invocation_counts,
            bundle.formal_t2_consumer_receipts_reclassified)
        forged_bundle = NG12_R.NativeG1G2ExecutionBundleV1(
            bundle.plan_hash, bundle.solver_input_hash, bundle.report,
            forged_evidence, bundle.invocation_counts,
            bundle.formal_t2_consumer_receipts_reclassified,
            NG12_G.canonical_hash(forged_bundle_body))
        @test !NG12_R.validate_native_g1g2_execution_bundle_v1(plan,
            forged_bundle)
        @test_throws ArgumentError NG12_R.finalize_native_g1g2_t1_handoff_v1(
            chain.admission, compilation, plan, forged_bundle)

        forged_report_evidence = NG12_R._ng12_expected_runtime_evidence_v1(
            plan, forged_gaps)
        forged_report_bundle_body = NG12_R._ng12_execution_bundle_body(
            bundle.plan_hash, bundle.solver_input_hash, forged_gaps,
            forged_report_evidence, bundle.invocation_counts,
            bundle.formal_t2_consumer_receipts_reclassified)
        forged_report_bundle = NG12_R.NativeG1G2ExecutionBundleV1(
            bundle.plan_hash, bundle.solver_input_hash, forged_gaps,
            forged_report_evidence, bundle.invocation_counts,
            bundle.formal_t2_consumer_receipts_reclassified,
            NG12_G.canonical_hash(forged_report_bundle_body))
        @test !NG12_R.validate_native_g1g2_execution_bundle_v1(plan,
            forged_report_bundle)
        @test_throws ArgumentError NG12_R.finalize_native_g1g2_t1_handoff_v1(
            chain.admission, compilation, plan, forged_report_bundle)

        pending = NG12_R.native_g1g2_downstream_input_link_v1(plan, bundle)
        @test pending.status === :pending_qualified_t2
        @test pending.resolution === :terminal_deferred
        @test !pending.accepted
        @test !pending.same_candidate_validated
        @test !pending.formal_t2_consumer_receipts_reclassified
        @test pending.t2_ledger_hash === nothing
        @test pending.t2_input_hash === nothing
        @test pending.numerical_invocation_counts.formal_t2_consumer_receipts == 0
        @test ng12_expect_code(() ->
            NG12_R.native_g1g2_downstream_input_link_v1(
                plan, bundle, nothing, nothing),
            "actual qualified T2 receipt ledger is invalid")

        bytes = ng12_serialize_bytes(bundle)
        reloaded = Serialization.deserialize(IOBuffer(bytes))
        @test reloaded isa NG12_R.NativeG1G2ExecutionBundleV1
        @test NG12_R.validate_native_g1g2_execution_bundle_v1(plan, reloaded)
        @test reloaded.bundle_hash == bundle.bundle_hash
    end
end

function ng12_primary(artifact_path::AbstractString)
    ng12_stage("primary.current_source_entry";
        detail="testset=current-source-edited-G2-mesh")
    Base.invokelatest(ng12_primary_current_source_tests)

    ng12_stage("primary.fixture.begin")
    fixture = ng12_compiled_fixture()
    chain = fixture.chain
    compilation = fixture.compile_result.compilation
    form = compilation.form
    plan = fixture.plan
    ng12_stage("primary.fixture.complete";
        detail="package=" * chain.admission.package.package_hash.value)

    Base.invokelatest(ng12_primary_authored_ast_native_source_tests, fixture)

    Base.invokelatest(ng12_primary_t1_carrier_tests, fixture, chain, compilation, form)
    ng12_stage("primary.source_t1.complete")

    altered_mesh_chain_out = Ref{Any}(nothing)
    tensor_execution_out = Ref{Any}(nothing)
    Base.invokelatest(ng12_primary_compile_boundary_tests, fixture, chain,
        form, altered_mesh_chain_out, tensor_execution_out)
    altered_mesh_chain = altered_mesh_chain_out[]
    tensor_execution = tensor_execution_out[]
    ng12_stage("primary.negatives.complete")

    Base.invokelatest(ng12_primary_analytic_oracle_tests, form)
    ng12_stage("primary.oracle.complete")

    Base.invokelatest(ng12_primary_provider_plan_tests, fixture, chain, plan)
    ng12_stage("primary.plan.complete")

    ng12_stage("primary.solve.begin")
    store = Dict{Any,Any}()
    bundle = NG12_R.execute_native_g1g2_gridap_once!(store, plan)
    cached = NG12_R.execute_native_g1g2_gridap_once!(store, plan)
    corrupt_store = Dict{Any,Any}(
        plan.solver_input.solver_input_hash => :tampered_cache_entry)
    @test ng12_expect_code(() ->
        NG12_R.execute_native_g1g2_gridap_once!(corrupt_store, plan),
        "cached native G1/G2 execution bundle type mismatch")
    ng12_stage("primary.solve.complete";
        detail="report=" * bundle.report.report_hash.value)
    checkpoint_path = artifact_path * ".preassert.bin"
    ispath(checkpoint_path) && error("pre-assert checkpoint already exists")
    mkpath(dirname(checkpoint_path))
    open(checkpoint_path, "w") do io
        Serialization.serialize(io,
            (schema="native-g1g2-preassert-checkpoint-v1",
                plan_hash=plan.plan_hash, bundle=bundle,
                preparation_counts=fixture.preparation_counts,
                numerical_counts=bundle.invocation_counts))
    end
    checkpoint_sha = bytes2hex(SHA.sha256(read(checkpoint_path)))
    ng12_stage("primary.preassert_checkpoint.complete";
        detail="sha256=" * checkpoint_sha)
    ng12_stage("primary.wrong_sign.begin")
    reversed = NG12_R.run_native_g1g2_wrong_sign_control_v1(plan; level=2)
    ng12_stage("primary.wrong_sign.complete";
        detail="level=" * reversed.level_hash.value)
    wrong_sign_checkpoint_path = artifact_path *
        ".wrong-sign-preassert.bin"
    ispath(wrong_sign_checkpoint_path) &&
        error("wrong-sign pre-assert checkpoint already exists")
    open(wrong_sign_checkpoint_path, "w") do io
        Serialization.serialize(io,
            (schema="native-g1g2-wrong-sign-preassert-checkpoint-v1",
                plan_hash=plan.plan_hash, wrong_sign_level=reversed))
    end
    wrong_sign_checkpoint_sha = bytes2hex(
        SHA.sha256(read(wrong_sign_checkpoint_path)))
    ng12_stage("primary.wrong_sign_checkpoint.complete";
        detail="sha256=" * wrong_sign_checkpoint_sha)

    Base.invokelatest(ng12_primary_handoff_tests, fixture, chain,
        compilation, plan, bundle, reversed, altered_mesh_chain)

    ng12_stage("primary.execution_receipts.before")
    Base.invokelatest(ng12_primary_execution_receipt_tests, fixture, chain,
        compilation, plan, bundle, store, cached, reversed)
    ng12_stage("primary.assertions.complete")

    artifact = (schema="native-g1g2-gridap-primary-artifact-v1",
        candidate_ref=chain.candidate,
        source_witness_hash=NG12_G.canonical_hash(chain.witness),
        t1_package_hash=chain.admission.package.package_hash,
        t1_semantic_identity=chain.admission.package.semantic_identity,
        g1_declaration_hash=chain.g1.declaration_hash,
        g2_declaration_hash=chain.g2.declaration_hash,
        program_bundle_hash=chain.programs.bundle_hash,
        compile_result_hash=fixture.compile_result.result_hash,
        protocol_hash=fixture.protocol.protocol_hash,
        plan_hash=plan.plan_hash, bundle=bundle,
        preparation_counts=fixture.preparation_counts,
        numerical_counts=bundle.invocation_counts,
        preassert_checkpoint_sha256=checkpoint_sha,
        wrong_sign_checkpoint_sha256=wrong_sign_checkpoint_sha,
        pending_link=NG12_R.native_g1g2_downstream_input_link_v1(plan, bundle),
        tensor_execution=tensor_execution,
        oracle_balance=ng12_oracle_continuous_balance(),
        compiler_source_hash=
            NG12_R.native_g1g2_diffusion_compiler_source_hash_v1(),
        adapter_source_hash=
            NG12_R.native_g1g2_gridap_adapter_source_hash_v1())
    ispath(artifact_path) && error("artifact path already exists")
    mkpath(dirname(artifact_path))
    open(artifact_path, "w") do io
        Serialization.serialize(io, artifact)
    end
    artifact_sha = bytes2hex(SHA.sha256(read(artifact_path)))
    ng12_stage("primary.artifact.complete"; detail="sha256=" * artifact_sha)
    println("NG12_RESULT mode=primary status=pass report_hash=",
        bundle.report.report_hash.value, " artifact_sha256=", artifact_sha,
        " t0_source_record_factory_calls=3 v3_source_witness_calls=1",
        " t1_admission_calls=1 compiler_calls=1 provider_calls=1",
        " mesh_calls=3 assembly_calls=6 solver_calls=3",
        " formal_t2_consumer_receipts=0 resolution=terminal_deferred")
end

function ng12_replay(artifact_path::AbstractString)
    # Rebuild every source/T0/T1/compile/provider expectation before reading
    # the serialized result under test.
    ng12_stage("replay.fixture.begin")
    fixture = ng12_compiled_fixture()
    plan = fixture.plan
    ng12_stage("replay.fixture.complete";
        detail="plan=" * plan.plan_hash.value)
    ng12_stage("replay.solve.begin")
    fresh = NG12_R.execute_native_g1g2_gridap_once!(Dict{Any,Any}(), plan)
    ng12_stage("replay.solve.complete";
        detail="report=" * fresh.report.report_hash.value)
    tensor_fresh = ng12_replay_tensor_execution(fixture)
    ng12_stage("replay.tensor_solve.complete";
        detail="report=" * tensor_fresh.bundle.report.report_hash.value)
    replay_checkpoint_path = artifact_path * ".replay-preassert.bin"
    ispath(replay_checkpoint_path) &&
        error("replay pre-assert checkpoint already exists")
    open(replay_checkpoint_path, "w") do io
        Serialization.serialize(io,
            (schema="native-g1g2-replay-preassert-checkpoint-v1",
                plan_hash=plan.plan_hash, bundle=fresh,
                preparation_counts=fixture.preparation_counts,
                numerical_counts=fresh.invocation_counts))
    end
    ng12_stage("replay.preassert_checkpoint.complete";
        detail="sha256=" *
            bytes2hex(SHA.sha256(read(replay_checkpoint_path))))

    isfile(artifact_path) || error("primary artifact is missing")
    artifact_bytes = read(artifact_path)
    artifact = Serialization.deserialize(IOBuffer(artifact_bytes))
    ng12_stage("replay.artifact.loaded";
        detail="sha256=" * bytes2hex(SHA.sha256(artifact_bytes)))

    @testset "fresh-process source and assembly replay" begin
        @test artifact.schema == "native-g1g2-gridap-primary-artifact-v1"
        @test artifact.candidate_ref == fixture.chain.candidate
        @test artifact.source_witness_hash ==
            NG12_G.canonical_hash(fixture.chain.witness)
        @test artifact.t1_package_hash ==
            fixture.chain.admission.package.package_hash
        @test artifact.t1_semantic_identity ==
            fixture.chain.admission.package.semantic_identity
        @test artifact.g1_declaration_hash == fixture.chain.g1.declaration_hash
        @test artifact.g2_declaration_hash == fixture.chain.g2.declaration_hash
        @test artifact.program_bundle_hash == fixture.chain.programs.bundle_hash
        @test artifact.compile_result_hash == fixture.compile_result.result_hash
        @test artifact.protocol_hash == fixture.protocol.protocol_hash
        @test artifact.plan_hash == plan.plan_hash
        @test artifact.preparation_counts == fixture.preparation_counts
        @test artifact.numerical_counts == fresh.invocation_counts
        @test artifact.preassert_checkpoint_sha256 ==
            bytes2hex(SHA.sha256(read(artifact_path * ".preassert.bin")))
        @test artifact.wrong_sign_checkpoint_sha256 == bytes2hex(
            SHA.sha256(read(artifact_path * ".wrong-sign-preassert.bin")))
        @test artifact.compiler_source_hash ==
            NG12_R.native_g1g2_diffusion_compiler_source_hash_v1()
        @test artifact.adapter_source_hash ==
            NG12_R.native_g1g2_gridap_adapter_source_hash_v1()
        @test NG12_R.validate_native_g1g2_execution_bundle_v1(plan,
            artifact.bundle)
        @test NG12_R.validate_native_g1g2_execution_bundle_v1(plan, fresh)
        @test fresh.bundle_hash == artifact.bundle.bundle_hash
        @test fresh.report.report_hash == artifact.bundle.report.report_hash
        @test Tuple(level.matrix_hash for level in fresh.report.levels) ==
            Tuple(level.matrix_hash for level in artifact.bundle.report.levels)
        @test Tuple(level.rhs_hash for level in fresh.report.levels) ==
            Tuple(level.rhs_hash for level in artifact.bundle.report.levels)
        @test Tuple(level.solution_hash for level in fresh.report.levels) ==
            Tuple(level.solution_hash for level in artifact.bundle.report.levels)
        @test Tuple(level.l2_error for level in fresh.report.levels) ==
            Tuple(level.l2_error for level in artifact.bundle.report.levels)
        @test Tuple(level.h1_seminorm_error for level in fresh.report.levels) ==
            Tuple(level.h1_seminorm_error for level in
                artifact.bundle.report.levels)
        tensor_saved = artifact.tensor_execution
        @test tensor_fresh.chain.candidate == tensor_saved.candidate_ref
        @test NG12_G.canonical_hash(tensor_fresh.chain.witness) ==
            tensor_saved.source_witness_hash
        @test tensor_fresh.chain.g1.declaration_hash ==
            tensor_saved.g1_declaration_hash
        @test tensor_fresh.chain.g2.declaration_hash ==
            tensor_saved.g2_declaration_hash
        @test tensor_fresh.programs.bundle_hash ==
            tensor_saved.program_bundle_hash
        @test tensor_fresh.compilation.result_hash ==
            tensor_saved.compile_result_hash
        @test tensor_fresh.protocol.protocol_hash == tensor_saved.protocol_hash
        @test NG12_R.validate_native_g1g2_gridap_plan_v1(tensor_fresh.plan)
        @test NG12_R.validate_native_g1g2_execution_bundle_v1(
            tensor_fresh.plan, tensor_saved.bundle)
        @test NG12_R.validate_native_g1g2_execution_bundle_v1(
            tensor_fresh.plan, tensor_fresh.bundle)
        @test tensor_fresh.plan.plan_hash == tensor_saved.plan.plan_hash
        @test tensor_fresh.bundle.bundle_hash == tensor_saved.bundle.bundle_hash
        @test tensor_fresh.bundle.report.report_hash ==
            tensor_saved.bundle.report.report_hash
        @test Tuple((level.matrix_hash, level.rhs_hash,
            level.solution_hash, level.residual_abs, level.residual_rel,
            level.l2_error, level.h1_seminorm_error, level.boundary_linf,
            level.source_integral_error, level.analytic_identity_defect)
            for level in tensor_fresh.bundle.report.levels) ==
            Tuple((level.matrix_hash, level.rhs_hash,
                level.solution_hash, level.residual_abs, level.residual_rel,
                level.l2_error, level.h1_seminorm_error, level.boundary_linf,
                level.source_integral_error, level.analytic_identity_defect)
                for level in tensor_saved.bundle.report.levels)
        @test artifact.oracle_balance == ng12_oracle_continuous_balance()
        replay_link = NG12_R.native_g1g2_downstream_input_link_v1(plan, fresh)
        @test artifact.pending_link.link_hash == replay_link.link_hash
        @test artifact.pending_link.status === replay_link.status
        @test fresh.invocation_counts.formal_t2_consumer_receipts == 0
    end
    ng12_stage("replay.assertions.complete")
    println("NG12_RESULT mode=replay status=pass report_hash=",
        fresh.report.report_hash.value,
        " fresh_provider_calls=1 fresh_mesh_calls=3 fresh_assembly_calls=6",
        " fresh_solver_calls=3 formal_t2_consumer_receipts=0",
        " resolution=terminal_deferred")
end

length(ARGS) == 2 || error(
    "usage: focused_tests.jl <primary|replay|authored_ast> <artifact-path>")
mode, artifact_path = ARGS
ng12_stage("dispatch.before"; detail="mode=" * mode)
mode == "primary" ? ng12_primary(artifact_path) :
    mode == "replay" ? ng12_replay(artifact_path) :
    mode == "authored_ast" ? ng12_authored_ast_only(artifact_path) :
    error("unsupported mode: " * mode)
