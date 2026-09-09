using Test
push!(LOAD_PATH, dirname(@__DIR__))
using FusionConceptAI
using Gridap

include(joinpath(@__DIR__, "..", "examples",
    "runtime_v4_gridap_native_comparison_fixture.jl"))

const GNC = FusionRuntimeV4
const GNC_REPORT = gridap_c_report

function _gnc_validate(r)
    GNC.validate_gridap_native_comparison(r, gridap_c_gridap_bundles,
        gridap_c_native_witnesses, gridap_c_native_convergence,
        gridap_c_gridap_convergence; compiled=composition_compiled,
        genome_registry=tdae_registry, scenario=d3_g2_scenario)
end

function _gnc_forge_case(c::GNC.GridapNativeTransferCaseV4;
        coordinate_linf=c.coordinate_linf,
        transfer_linf=c.transfer_linf,
        status=c.status,
        case_hash=c.case_hash)
    GNC.GridapNativeTransferCaseV4(GNC._GNC_TOKEN, c.nodes_per_axis,
        c.domain_identity, c.g2_identity, c.payload_identity,
        c.protocol_identity, c.provider_identity, c.assembly_identity,
        c.native_coordinates_hash, c.gridap_coordinates_hash,
        c.native_indices, c.gridap_indices, c.quadrature_weights_hash,
        c.mapping_hash, coordinate_linf, c.interpolation_linf,
        transfer_linf, c.transfer_l2, c.transfer_relative_l2,
        c.native_solution_linf, c.gridap_solution_l2,
        c.gridap_solution_h1, c.source_interpolation_l2,
        c.boundary_interpolation_linf, c.native_residual_inf,
        c.gridap_residual_inf, status, case_hash)
end

function _gnc_forge_report(r::GNC.FieldNumericalComparisonV4;
        status=r.status, cases=r.transfer_cases,
        receipt=r.receipt, claim_ceiling=r.claim_ceiling,
        report_hash=r.report_hash)
    GNC.FieldNumericalComparisonV4(GNC._GNC_TOKEN, status, cases, receipt,
        r.native_linf_errors, r.native_linf_orders, r.gridap_l2_errors,
        r.gridap_h1_errors, r.gridap_l2_orders, r.gridap_h1_orders,
        r.transfer_linf_errors, r.transfer_l2_errors,
        r.transfer_relative_l2_errors, r.transfer_linf_orders,
        r.transfer_l2_orders, r.acceptance_bands, r.rejection_reasons,
        r.evidence_class, claim_ceiling,
        r.credible_physical_candidate_count, r.p5_ready,
        r.unsupported_emitted, report_hash)
end

@testset "Batch C sealed provider replay and exact identity" begin
    r = GNC_REPORT
    @test !GNC.validate_gridap_native_comparison(r)
    @test _gnc_validate(r)
    @test GNC.validate_field_numerical_comparison(r,
        gridap_c_gridap_bundles, gridap_c_native_witnesses,
        gridap_c_native_convergence, gridap_c_gridap_convergence;
        compiled=composition_compiled, genome_registry=tdae_registry,
        scenario=d3_g2_scenario)
    @test r.status === :pass
    @test isempty(r.rejection_reasons)
    @test Tuple(c.nodes_per_axis for c in r.transfer_cases) == (5, 9, 17)
    @test all(GNC._gnc_case_integrity, r.transfer_cases)
    @test all(GNC.validate_native_field_replay_witness,
        gridap_c_native_witnesses)
    @test all(w -> w.primary_store !== w.replay_store,
        gridap_c_native_witnesses)
    @test all(b -> GNC.validate_gridap_field_evidence(b),
        gridap_c_gridap_bundles)
    @test r.receipt.native_convergence_hash ==
        gridap_c_native_convergence.receipt_hash
    @test r.receipt.gridap_convergence_hash ==
        gridap_c_gridap_convergence.receipt_hash
    @test r.receipt.native_witness_hashes ==
        Tuple(w.witness_hash for w in gridap_c_native_witnesses)
    @test r.receipt.gridap_bundle_hashes ==
        Tuple(b.bundle_hash for b in gridap_c_gridap_bundles)
    @test r.receipt.transfer_case_hashes ==
        Tuple(c.case_hash for c in r.transfer_cases)
    @test r.receipt.native_independence_group !=
        r.receipt.gridap_independence_group
    @test all(c -> c.domain_identity.bounds_hash ==
        composition_compiled.minimality_scope.bounds_hash, r.transfer_cases)
    @test all(c -> c.domain_identity.registry_hash ==
        canonical_hash(tdae_registry), r.transfer_cases)
    @test all(c -> c.domain_identity.constraint_edge_hash ==
        canonical_hash(composition_constraint), r.transfer_cases)
    @test all(c -> c.assembly_identity.matrix_identity ===
        :independent_discretizations, r.transfer_cases)
    @test all(c -> c.assembly_identity.rhs_identity ===
        :independent_discretizations, r.transfer_cases)
end

@testset "Batch C keeps error families and authority separate" begin
    r = GNC_REPORT
    @test r.native_linf_errors == gridap_c_native_convergence.errors
    @test r.native_linf_orders == gridap_c_native_convergence.orders
    @test r.gridap_l2_errors == Tuple(c.solution_l2
        for c in gridap_c_gridap_convergence.cases)
    @test r.gridap_h1_errors == Tuple(c.solution_h1_seminorm
        for c in gridap_c_gridap_convergence.cases)
    @test r.transfer_linf_errors == Tuple(c.transfer_linf
        for c in r.transfer_cases)
    @test r.transfer_l2_errors == Tuple(c.transfer_l2
        for c in r.transfer_cases)
    @test r.transfer_relative_l2_errors ==
        Tuple(c.transfer_relative_l2 for c in r.transfer_cases)
    @test all(c -> c.coordinate_linf <=
        r.acceptance_bands.coordinate_linf, r.transfer_cases)
    @test all(c -> c.interpolation_linf == 0.0, r.transfer_cases)
    @test all(>(0.0), r.transfer_linf_errors)
    @test all(>(0.0), r.transfer_l2_errors)
    @test all(r.transfer_linf_errors[i] > r.transfer_linf_errors[i + 1]
        for i in 1:2)
    @test all(r.transfer_l2_errors[i] > r.transfer_l2_errors[i + 1]
        for i in 1:2)
    @test r.evidence_class === :manufactured_control
    @test r.claim_ceiling === screen_only
    @test r.credible_physical_candidate_count == 0
    @test !r.p5_ready && !r.unsupported_emitted
    @testset "manifest" begin
        m = GNC.gridap_native_comparison_manifest()
        @test m.compares_independent_discretizations
        @test !m.physical_validation
        @test !m.engineering_validation
        @test !m.terminal_authority
    end
end

@testset "Batch C coordinate operator is explicit and permutation-safe" begin
    native = ((0.0, 0.0, 0.0), (1.0, 0.0, 0.0),
        (2.0, 0.0, 0.0))
    gridap = (native[3], native[1], native[2])
    mapping, coordinate_linf = GNC._gnc_coordinate_transfer(native, gridap)
    @test mapping == (2, 3, 1)
    @test coordinate_linf == 0.0
    @test_throws ArgumentError GNC._gnc_coordinate_transfer(native,
        (native[1], native[1], native[3]))
    @test_throws ArgumentError GNC._gnc_coordinate_transfer(native,
        (native[1], native[2]))
    @test_throws ArgumentError GNC._gnc_coordinate_transfer(native,
        (native[1], native[2], (3.0, 0.0, 0.0)))
    @test all(c -> length(unique(c.gridap_indices)) ==
        c.nodes_per_axis^3, GNC_REPORT.transfer_cases)
    @test all(c -> c.mapping_hash == canonical_hash((
        native_coordinates_hash=c.native_coordinates_hash,
        gridap_coordinates_hash=c.gridap_coordinates_hash,
        native_indices=c.native_indices, gridap_indices=c.gridap_indices,
        quadrature_weights_hash=c.quadrature_weights_hash,
        method=:exact_coordinate_bijection_then_tensor_trapezoid_l2)),
        GNC_REPORT.transfer_cases)
end

@testset "Batch C adversarial bindings and acceptance fail closed" begin
    first_compilation = first(gridap_c_gridap_bundles).compilation
    original_b2_case = first(gridap_c_gridap_convergence.cases)
    foreign_hash = digest256_text("foreign-batch-c-binding")
    foreign_b2_case = GNC.GridapFieldConvergenceCaseV4(GNC._GRIDAP_B2_TOKEN,
        foreign_hash, original_b2_case.plan_hash,
        original_b2_case.g2_u_result_hash,
        original_b2_case.g2_f_result_hash,
        original_b2_case.nodes_per_axis, original_b2_case.cells,
        original_b2_case.dofs, original_b2_case.runtime_seconds,
        original_b2_case.memory_bytes, original_b2_case.solution_l2,
        original_b2_case.solution_h1_seminorm,
        original_b2_case.source_cell_center_rms,
        original_b2_case.boundary_face_center_linf,
        original_b2_case.residual, original_b2_case.status,
        original_b2_case.case_hash)
    @test_throws ArgumentError GNC._gnc_build_case(
        first(gridap_c_gridap_bundles),
        first(gridap_c_native_witnesses), 1,
        gridap_c_native_convergence, foreign_b2_case,
        composition_compiled, tdae_registry, d3_g2_scenario;
        fresh_replay=false)

    @test_throws ArgumentError GNC._gnc_common_identity(first_compilation,
        composition_compiled, tdae_registry,
        (name="foreign", load_case="foreign"))

    foreign_ref = GenomeContractRef("urn:fusion:runtime:foreign-field", "v4",
        digest256_text("foreign-field-schema"),
        digest256_text("foreign-field-canonicalization"), "runtime")
    foreign_registry = GenomeContractRegistryV4(tdae_registry.mechanism,
        foreign_ref, tdae_registry.realization_control)
    @test_throws ArgumentError GNC._gnc_common_identity(first_compilation,
        composition_compiled, foreign_registry, d3_g2_scenario)

    @test_throws ArgumentError GNC.make_native_field_replay_witness(
        first(gridap_c_native_witnesses).plan,
        first(gridap_c_native_witnesses).primary_store,
        first(gridap_c_native_witnesses).primary_store,
        first(gridap_c_native_witnesses).solver_input_hash)

    c = first(GNC_REPORT.transfer_cases)
    @test !GNC._gnc_case_integrity(_gnc_forge_case(c;
        coordinate_linf=1.0, case_hash=c.case_hash))
    @test !GNC._gnc_validate_internal(
        _gnc_forge_report(GNC_REPORT; status=:numerical_fail))
    @test !GNC._gnc_validate_internal(
        _gnc_forge_report(GNC_REPORT; claim_ceiling=validation_vvuq))

    bad = _gnc_forge_case(c;
        transfer_linf=GNC._GNC_TRANSFER_BANDS.linf_upper[1] + 1.0)
    reasons = GNC._gnc_acceptance((bad,
        GNC_REPORT.transfer_cases[2], GNC_REPORT.transfer_cases[3]))[1]
    @test "transfer_linf_band" in reasons

    source = read(joinpath(@__DIR__, "..", "src", "RuntimeV4",
        "GridapNativeComparison.jl"), String)
    @test !occursin("assemble_field_residual_kernel", source)
    @test !occursin("solve_field_residual_kernel", source)
    @test !occursin("Base.getproperty", source)
    @test_throws ArgumentError GNC.GridapNativeTransferCaseV4()
    @test_throws ArgumentError GNC.FieldNumericalComparisonV4()
end

println("BATCH_C_FOCUSED_EXIT_CODE=0")
