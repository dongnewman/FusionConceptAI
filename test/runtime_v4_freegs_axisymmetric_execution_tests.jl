using Test
using FusionConceptAI

include(joinpath(@__DIR__, "..", "examples",
    "runtime_v4_freegs_axisymmetric_execution.jl"))
const F = FreeGSAxisymmetricRuntime

@testset "typed G2 axisymmetric declaration and subject binding" begin
    @test F.validate_forward_chain_context(freegs_context) == freegs_context.context_hash
    @test canonical_hash(freegs_axisymmetric_declaration) ==
        freegs_axisymmetric_declaration.declaration_hash
    @test freegs_candidate.field_geometry_genome_ref.fields ==
        (freegs_axisymmetric_declaration,)
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

@testset "strict typed FreeGS input and negative boundaries" begin
    input = F.freegs_axisymmetric_solver_input(freegs_context)
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
end

@testset "real pinned FreeGS integration is screen-only" begin
    artifacts = F.execute_freegs_axisymmetric_screen(freegs_context)
    receipt = artifacts.receipt
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
end
