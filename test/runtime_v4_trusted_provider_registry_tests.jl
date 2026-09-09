using Test
using FusionConceptAI

include(joinpath(@__DIR__, "..", "examples",
    "runtime_v4_trusted_provider_registry.jl"))

const R = TrustedProviderRegistryRuntime
const TH = digest256_text("trusted-provider-registry-adversarial")
const _CALLER_STUB = input -> (execution_kind=:caller_stub,
    input_hash=canonical_hash(input))

function _manifest(context::R.ForwardChainContextV4,
        capability::R.CapabilitySignatureV4;
        executor=only(R.empty_trusted_registry.descriptors).executor,
        code_hash=only(R.empty_trusted_registry.descriptors).source_hash,
        domain=nothing, backend=R._TPR_BUILTIN_PROVIDER,
        backend_revision=R._TPR_REVISION,
        independence_group="trusted-repository:$(R._TPR_BUILTIN_PROVIDER)")
    descriptor = only(R.empty_trusted_registry.descriptors)
    resolved_domain = domain === nothing ?
        R._tpr_domain(context, descriptor, capability, "test_only") : domain
    R.ProviderManifestV4(capability.schema, capability.revision, capability.kind,
        capability, resolved_domain, backend, backend_revision, code_hash,
        independence_group, screen_only;
        input_schema_hash=capability.input_schema_hash, executor=executor)
end

function _foreign_subject_context()
    subject = R.ExecutablePhysicalSubjectV4(R.trusted_compiled.prefix_hash,
        R.candidate.canonical_hashes.genome_bundle_hash,
        R.trusted_compiled.minimality_scope.mission_hash,
        R.trusted_compiled.minimality_scope.bounds_hash,
        ((binding_kind="foreign-trust-fixture",
          candidate_ref=R.candidate.identity_ref),), R.trusted_scenarios,
        (materialization="foreign-software-fixture", revision="v1"),
        R.derive_capability_obligations(R.trusted_compiled))
    R.make_forward_chain_context(R.candidate, R.trusted_compiled, R.registry,
        R.trusted_mission, R.trusted_bounds, R.trusted_comparison_scope,
        R.trusted_scenario_scope, subject, first(R.trusted_scenarios))
end

@testset "trusted repository bootstrap and exact registration" begin
    @test R.validate_trusted_provider_registry(R.empty_trusted_registry) ==
        R.empty_trusted_registry.registry_hash
    @test R.validate_trusted_provider_registry(R.trusted_registry) ==
        R.trusted_registry.registry_hash
    @test length(R.empty_trusted_registry.registrations) == 0
    @test length(R.trusted_registry.registrations) == 1
    descriptor = only(R.trusted_registry.descriptors)
    registration = only(R.trusted_registry.registrations)
    @test R.validate_repository_provider_descriptor(descriptor,
        R.trusted_repository_root) == descriptor.descriptor_hash
    @test R.validate_trusted_provider_registration(registration, descriptor,
        R.trusted_repository_root) == registration.registration_hash
    @test registration.manifest.executor === descriptor.executor
    @test registration.manifest.code_hash == descriptor.source_hash
    @test descriptor.runtime_hash == R._tpr_runtime_hash(descriptor.executor,
        R.trusted_repository_root)
    @test registration.context_hash == R.trusted_context.context_hash
    @test registration.subject_hash == R.trusted_context.subject.physical_subject_hash
    @test registration.scenario_hash == R.trusted_context.scenario_hash
    @test_throws ArgumentError R.register_trusted_provider(R.trusted_registry,
        R.trusted_context, R._TPR_BUILTIN_PROVIDER, R.trusted_capability,
        R.repository_provider_manifest)
end

@testset "caller manifest, executor, code hash, and prebinding fail closed" begin
    descriptor = only(R.empty_trusted_registry.descriptors)
    foreign_context = _foreign_subject_context()
    foreign_capability = first(foreign_context.obligations)

    # First-bind a distinct manifest hash to a caller stub.  Registration rejects
    # it, and the package-level executor map can at worst make the later trusted
    # factory fail; it never substitutes the stub into the trusted registry.
    prebound_stub = _manifest(foreign_context, foreign_capability;
        executor=_CALLER_STUB)
    @test_throws ArgumentError R.register_trusted_provider(
        R.empty_trusted_registry, foreign_context, R._TPR_BUILTIN_PROVIDER,
        foreign_capability, prebound_stub)
    @test_throws ArgumentError R.make_repository_owned_provider_manifest(
        R.empty_trusted_registry, foreign_context, R._TPR_BUILTIN_PROVIDER,
        foreign_capability; model_class="test_only")
    @test isempty(R.empty_trusted_registry.registrations)

    wrong_code = _manifest(R.trusted_context, R.trusted_capability;
        code_hash=TH, independence_group="wrong-code-test")
    @test_throws ArgumentError R.register_trusted_provider(
        R.empty_trusted_registry, R.trusted_context, R._TPR_BUILTIN_PROVIDER,
        R.trusted_capability, wrong_code)

    wrong_domain = R._tpr_domain(R.trusted_context, descriptor,
        R.trusted_capability, "test_only")
    wrong_domain = merge(wrong_domain, (scenario_hash=TH,))
    wrong_context_manifest = _manifest(R.trusted_context,
        R.trusted_capability; domain=wrong_domain,
        independence_group="wrong-domain-test")
    @test_throws ArgumentError R.register_trusted_provider(
        R.empty_trusted_registry, R.trusted_context, R._TPR_BUILTIN_PROVIDER,
        R.trusted_capability, wrong_context_manifest)

    @test_throws ArgumentError R.make_repository_owned_provider_manifest(
        R.empty_trusted_registry, R.trusted_context, R._TPR_BUILTIN_PROVIDER,
        R.trusted_capability; model_class="physical_experiment")
end


@testset "descriptor, registry, root, source, and runtime forgeries" begin
    descriptor = only(R.empty_trusted_registry.descriptors)
    forged_source = R.RepositoryProviderDescriptorV4(R._TPR_TOKEN,
        descriptor.provider_id, descriptor.source_relative_path,
        descriptor.entrypoint, descriptor.allowed_capability_kinds,
        descriptor.allowed_model_classes, TH, descriptor.runtime_hash,
        descriptor.executor, descriptor.descriptor_hash)
    @test_throws ArgumentError R.validate_repository_provider_descriptor(
        forged_source, R.trusted_repository_root)

    forged_runtime = R.RepositoryProviderDescriptorV4(R._TPR_TOKEN,
        descriptor.provider_id, descriptor.source_relative_path,
        descriptor.entrypoint, descriptor.allowed_capability_kinds,
        descriptor.allowed_model_classes, descriptor.source_hash, TH,
        descriptor.executor, descriptor.descriptor_hash)
    @test_throws ArgumentError R.validate_repository_provider_descriptor(
        forged_runtime, R.trusted_repository_root)

    forged_executor = R.RepositoryProviderDescriptorV4(R._TPR_TOKEN,
        descriptor.provider_id, descriptor.source_relative_path,
        descriptor.entrypoint, descriptor.allowed_capability_kinds,
        descriptor.allowed_model_classes, descriptor.source_hash,
        descriptor.runtime_hash, _CALLER_STUB, descriptor.descriptor_hash)
    @test_throws ArgumentError R.validate_repository_provider_descriptor(
        forged_executor, R.trusted_repository_root)

    registry = R.empty_trusted_registry
    forged_registry = R.TrustedProviderRegistryV4(R._TPR_TOKEN,
        registry.repository_root, registry.repository_identity_hash,
        registry.descriptors, registry.registrations, TH)
    @test_throws ArgumentError R.validate_trusted_provider_registry(forged_registry)

    @test_throws ArgumentError R.bootstrap_trusted_provider_registry(
        Val(:trusted_repository_bootstrap), dirname(R.trusted_repository_root))
    mktempdir() do temporary_root
        mkpath(joinpath(temporary_root, "src", "RuntimeV4"))
        cp(joinpath(R.trusted_repository_root, "Project.toml"),
            joinpath(temporary_root, "Project.toml"))
        cp(joinpath(R.trusted_repository_root, "src", "FusionConceptAI.jl"),
            joinpath(temporary_root, "src", "FusionConceptAI.jl"))
        cp(joinpath(R.trusted_repository_root, R._TPR_BUILTIN_SOURCE),
            joinpath(temporary_root, R._TPR_BUILTIN_SOURCE))
        @test_throws ArgumentError R.bootstrap_trusted_provider_registry(
            Val(:trusted_repository_bootstrap), temporary_root)
    end
end

@testset "dispatch readiness comes only from the validated registry" begin
    missing = R.build_trusted_provider_dispatch_request(
        R.empty_trusted_registry, R.trusted_context, R.trusted_capability,
        R.trusted_input)
    @test missing.status === :recoverable_gap
    @test missing.registration === nothing
    @test missing.recoverable_gaps == ("trusted_provider_registration_missing",)

    @test R.trusted_request.status === :ready_for_dispatch
    @test R.trusted_request.registration !== nothing
    @test isempty(R.trusted_request.recoverable_gaps)
    @test R.validate_trusted_provider_dispatch_request(R.trusted_request,
        R.trusted_registry, R.trusted_context, R.trusted_capability,
        R.trusted_input)
    @test !R.validate_trusted_provider_dispatch_request(R.trusted_request)
    @test !hasproperty(R.trusted_request, :manifest)
    @test !hasproperty(R.trusted_request, :evidence)
    @test_throws ArgumentError canonical_hash(R.trusted_request)

    request = R.trusted_request
    forged_ready = R.TrustedProviderDispatchRequestV4(R._TPR_TOKEN,
        R.empty_trusted_registry.registry_hash, request.context,
        request.context_hash, request.subject_hash, request.scenario_hash,
        request.capability, request.input, request.input_hash,
        request.registration, :ready_for_dispatch, (), request.request_hash)
    @test !R.validate_trusted_provider_dispatch_request(forged_ready,
        R.empty_trusted_registry, R.trusted_context, R.trusted_capability,
        R.trusted_input)

    foreign_context = _foreign_subject_context()
    foreign_request = R.build_trusted_provider_dispatch_request(
        R.trusted_registry, foreign_context, R.trusted_capability,
        R.trusted_input)
    @test foreign_request.status === :recoverable_gap
    @test foreign_request.registration === nothing
    @test_throws ArgumentError R.build_trusted_provider_dispatch_request(
        R.trusted_registry, R.trusted_context, R.trusted_capability,
        Dict("mutable" => true))
end

@testset "operational receipt binds every dispatch identity" begin
    receipt = R.trusted_receipt
    @test receipt.status === :completed
    @test receipt.exit_code == 0
    @test receipt.registry_hash == R.trusted_registry.registry_hash
    @test receipt.request_hash == R.trusted_request.request_hash
    @test receipt.registration_hash ==
        only(R.trusted_registry.registrations).registration_hash
    @test receipt.provider_manifest_hash == R.repository_provider_manifest.manifest_hash
    @test receipt.input_hash == canonical_hash(R.trusted_input)
    @test receipt.output_hash == canonical_hash(receipt.output)
    @test R.validate_trusted_provider_execution_receipt(receipt,
        R.trusted_request, R.trusted_registry, R.trusted_context)
    @test !R.validate_trusted_provider_execution_receipt(receipt)

    forged_output = R.TrustedProviderExecutionReceiptV4(R._TPR_TOKEN,
        receipt.registry_hash, receipt.request_hash, receipt.registration_hash,
        receipt.provider_manifest_hash, receipt.input_hash, (forged=true,),
        receipt.output_hash, receipt.exit_code, receipt.status,
        receipt.message, receipt.receipt_hash)
    @test !R.validate_trusted_provider_execution_receipt(forged_output,
        R.trusted_request, R.trusted_registry, R.trusted_context)

    forged_exit = R.TrustedProviderExecutionReceiptV4(R._TPR_TOKEN,
        receipt.registry_hash, receipt.request_hash, receipt.registration_hash,
        receipt.provider_manifest_hash, receipt.input_hash, receipt.output,
        receipt.output_hash, 9, :completed, receipt.message,
        receipt.receipt_hash)
    @test !R.validate_trusted_provider_execution_receipt(forged_exit,
        R.trusted_request, R.trusted_registry, R.trusted_context)

    forged_status = R.TrustedProviderExecutionReceiptV4(R._TPR_TOKEN,
        receipt.registry_hash, receipt.request_hash, receipt.registration_hash,
        receipt.provider_manifest_hash, receipt.input_hash, receipt.output,
        receipt.output_hash, 0, :pass, receipt.message,
        receipt.receipt_hash)
    @test !R.validate_trusted_provider_execution_receipt(forged_status,
        R.trusted_request, R.trusted_registry, R.trusted_context)

    forged_request = R.TrustedProviderExecutionReceiptV4(R._TPR_TOKEN,
        receipt.registry_hash, TH, receipt.registration_hash,
        receipt.provider_manifest_hash, receipt.input_hash, receipt.output,
        receipt.output_hash, receipt.exit_code, receipt.status,
        receipt.message, receipt.receipt_hash)
    @test !R.validate_trusted_provider_execution_receipt(forged_request,
        R.trusted_request, R.trusted_registry, R.trusted_context)

    manifest = R.trusted_provider_registry_manifest()
    @test !manifest.accepts_caller_provider_descriptors
    @test !manifest.accepts_caller_executors && !manifest.emits_evidence
    @test manifest.physical_validation_credit == 0
    @test !manifest.closure_authority && !manifest.promotion_authority
    @test !manifest.terminal_authority
    @test manifest.credible_physical_candidate_count == 0 && !manifest.p5_ready
    @test !hasproperty(receipt, :evidence)
    @test !hasproperty(receipt, :accepted)
end

println("TRUSTED_PROVIDER_REGISTRY_FOCUSED_EXIT_CODE=0")
