using Test
using FusionConceptAI

include(joinpath(@__DIR__, "..", "examples",
    "runtime_v4_trusted_freegs_axisymmetric_provider.jl"))

const TF = TrustedFreeGSRuntime
const TFH = digest256_text("trusted-freegs-adversarial")

@testset "fixed FreeGS catalog and exact typed capability" begin
    @test Tuple(item.provider_id for item in
        trusted_freegs_empty_registry.descriptors) ==
        (TF._TPR_BUILTIN_PROVIDER, TF._TPR_FREEGS_PROVIDER)
    descriptor = TF._tpr_find_descriptor(trusted_freegs_empty_registry,
        TF._TPR_FREEGS_PROVIDER)
    @test descriptor.source_relative_path == TF._TPR_FREEGS_SOURCE
    @test descriptor.entrypoint === :_trusted_freegs_axisymmetric_executor
    @test descriptor.attested_source_paths == TF._TPR_FREEGS_ATTESTED_SOURCES
    @test descriptor.attested_source_hashes == Tuple(
        TF._tpr_file_hash(TF._tpr_inside_root(trusted_freegs_repository_root, path))
        for path in descriptor.attested_source_paths)
    @test descriptor.runtime_hash == TF._tpr_runtime_hash(
        TF._trusted_freegs_axisymmetric_executor,
        trusted_freegs_repository_root)
    @test descriptor.executor === TF._trusted_freegs_axisymmetric_executor
    @test TF.validate_repository_provider_descriptor(descriptor,
        trusted_freegs_repository_root) == descriptor.descriptor_hash
    forged_hashes = Base.setindex(descriptor.attested_source_hashes, TFH, 2)
    forged_descriptor = TF.RepositoryProviderDescriptorV4(TF._TPR_TOKEN,
        descriptor.provider_id, descriptor.source_relative_path,
        descriptor.entrypoint, descriptor.allowed_capability_kinds,
        descriptor.allowed_model_classes, descriptor.source_hash,
        descriptor.attested_source_paths, forged_hashes,
        descriptor.runtime_hash, descriptor.executor, descriptor.descriptor_hash)
    @test_throws ArgumentError TF.validate_repository_provider_descriptor(
        forged_descriptor, trusted_freegs_repository_root)

    @test canonical_hash(trusted_freegs_capability) ==
        TF.validate_trusted_freegs_axisymmetric_capability(
            trusted_freegs_capability, freegs_context)
    @test all(canonical_hash(item) != canonical_hash(trusted_freegs_capability)
        for item in freegs_context.obligations)
    @test trusted_freegs_capability.kind === :axisymmetric_equilibrium_screen
    @test trusted_freegs_capability.evidence_level == screen_only
    @test trusted_freegs_capability.applicability_bounds ==
        freegs_context.compiled.minimality_scope.bounds_hash

    domain = trusted_freegs_manifest.domain
    @test domain.binding_hash == freegs_subject_binding.binding_hash
    @test domain.declaration_hash == canonical_hash(freegs_axisymmetric_declaration)
    @test domain.field_geometry_graph_hash ==
        freegs_subject_binding.field_geometry_graph_hash
end

@testset "trusted FreeGS canonical request rejects substitution" begin
    @test TF.validate_trusted_freegs_axisymmetric_input(trusted_freegs_input,
        freegs_context, trusted_freegs_capability) == trusted_freegs_input.input_hash
    @test trusted_freegs_input.context_hash == freegs_context.context_hash
    @test trusted_freegs_input.binding_hash == freegs_subject_binding.binding_hash
    @test trusted_freegs_input.solver_input_hash ==
        trusted_freegs_receipt.output.freegs_receipt.input_hash
    @test trusted_freegs_request.status === :ready_for_dispatch
    @test TF.validate_trusted_provider_dispatch_request(trusted_freegs_request,
        trusted_freegs_registry, freegs_context, trusted_freegs_capability,
        trusted_freegs_input)

    wrong_capability = TF.CapabilitySignatureV4(
        trusted_freegs_capability.schema, trusted_freegs_capability.revision,
        trusted_freegs_capability.kind, trusted_freegs_capability.operator,
        ("foreign-declaration",), trusted_freegs_capability.source_space,
        trusted_freegs_capability.target_space, trusted_freegs_capability.dimension,
        trusted_freegs_capability.coordinates,
        trusted_freegs_capability.boundary_relation,
        trusted_freegs_capability.interface_relation,
        trusted_freegs_capability.time_semantics,
        trusted_freegs_capability.required_output,
        trusted_freegs_capability.evidence_level,
        trusted_freegs_capability.applicability_bounds;
        input_schema_hash=trusted_freegs_capability.input_schema_hash,
        coordinate_system=trusted_freegs_capability.coordinate_system)
    @test_throws ArgumentError TF.validate_trusted_freegs_axisymmetric_capability(
        wrong_capability, freegs_context)
    @test_throws ArgumentError TF.make_repository_owned_provider_manifest(
        trusted_freegs_empty_registry, freegs_context,
        TF._TPR_FREEGS_PROVIDER, wrong_capability;
        model_class=TF._TPR_FREEGS_MODEL_CLASS)

    forged_input = TF.TrustedFreeGSAxisymmetricInputV4(TF._TRUSTED_FREEGS_TOKEN,
        trusted_freegs_input.context_hash,
        trusted_freegs_input.physical_subject_hash,
        trusted_freegs_input.scenario_hash, TFH,
        trusted_freegs_input.declaration_hash,
        trusted_freegs_input.capability_hash,
        trusted_freegs_input.solver_input_hash,
        trusted_freegs_input.input_hash)
    @test_throws ArgumentError TF.validate_trusted_freegs_axisymmetric_input(
        forged_input, freegs_context, trusted_freegs_capability)
    @test_throws ArgumentError TF.build_trusted_provider_dispatch_request(
        trusted_freegs_registry, freegs_context, trusted_freegs_capability,
        forged_input)
end

@testset "trusted wrapper binds the existing FreeGS receipt and output" begin
    receipt = trusted_freegs_receipt
    output = receipt.output
    freegs_receipt = output.freegs_receipt
    @test receipt.status === :physical_model_screen
    @test receipt.exit_code == 0
    @test freegs_receipt.status === :physical_model_screen
    @test freegs_receipt.freegs_version == "0.8.2"
    @test output.freegs_receipt_hash == freegs_receipt.receipt_hash
    @test output.freegs_output_hash == freegs_receipt.output_hash ==
        TF._freegs_sha256_text(output.output_json)
    @test TF.validate_freegs_axisymmetric_receipt(freegs_context,
        freegs_receipt) == freegs_receipt.receipt_hash
    @test TF.validate_trusted_freegs_axisymmetric_output(output,
        freegs_context, trusted_freegs_input, trusted_freegs_capability) ==
        canonical_hash(output)
    @test TF.validate_trusted_provider_execution_receipt(receipt,
        trusted_freegs_request, trusted_freegs_registry, freegs_context)
    @test receipt.output_hash == canonical_hash(output)
    @test freegs_receipt.claim_ceiling == screen_only
    @test !freegs_receipt.physical_validation
    @test !freegs_receipt.engineering_validation
    @test !freegs_receipt.p5_ready
    @test !freegs_receipt.terminal_authority

    forged_output = TF.TrustedFreeGSAxisymmetricOutputV4(
        output.freegs_receipt, output.freegs_receipt_hash, TFH,
        output.output_json)
    @test_throws ArgumentError TF.validate_trusted_freegs_axisymmetric_output(
        forged_output, freegs_context, trusted_freegs_input,
        trusted_freegs_capability)
end

println("TRUSTED_FREEGS_AXISYMMETRIC_PROVIDER_FOCUSED_EXIT_CODE=0")
