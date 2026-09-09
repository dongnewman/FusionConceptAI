using Test
using FusionConceptAI

include(joinpath(@__DIR__, "..", "examples",
    "runtime_v4_trusted_engineering_control_fault_provider.jl"))

const P = TECFE
const ECF_FORGERY_HASH = digest256_text("trusted-ecf-provider-forgery")

function _ecf_sealed_replace(type, token, value; replacements...)
    names = fieldnames(type)
    fields = ntuple(i -> names[i] in keys(replacements) ?
        replacements[names[i]] : getfield(value, names[i]),
        fieldcount(type))
    type(token, fields...)
end

function _ecf_rehashed_input(value; replacements...)
    provisional = _ecf_sealed_replace(P.TrustedEngineeringControlFaultInputV4,
        P._TECFE_TOKEN, value; replacements..., input_hash=ECF_FORGERY_HASH)
    _ecf_sealed_replace(P.TrustedEngineeringControlFaultInputV4,
        P._TECFE_TOKEN, provisional;
        input_hash=canonical_hash(P._tecfe_input_body(provisional)))
end

function _ecf_rehashed_request(value; replacements...)
    provisional = _ecf_sealed_replace(
        P.TrustedEngineeringControlFaultDispatchRequestV4,
        P._TECFE_TOKEN, value; replacements..., request_hash=ECF_FORGERY_HASH)
    _ecf_sealed_replace(P.TrustedEngineeringControlFaultDispatchRequestV4,
        P._TECFE_TOKEN, provisional;
        request_hash=canonical_hash(P._tecfe_request_body(provisional)))
end

function _ecf_rehashed_result(value; replacements...)
    provisional = _ecf_sealed_replace(P.TrustedEngineeringControlFaultResultV4,
        P._TECFE_TOKEN, value; replacements..., result_hash=ECF_FORGERY_HASH)
    _ecf_sealed_replace(P.TrustedEngineeringControlFaultResultV4,
        P._TECFE_TOKEN, provisional;
        result_hash=canonical_hash(P._tecfe_result_body(provisional)))
end

function _ecf_rehashed_receipt(value; replacements...)
    provisional = _ecf_sealed_replace(
        P.TrustedEngineeringControlFaultOperationalReceiptV4,
        P._TECFE_TOKEN, value; replacements..., receipt_hash=ECF_FORGERY_HASH)
    _ecf_sealed_replace(P.TrustedEngineeringControlFaultOperationalReceiptV4,
        P._TECFE_TOKEN, provisional;
        receipt_hash=canonical_hash(P._tecfe_receipt_body(provisional)))
end

function _ecf_probability_context(probability::Rational{Int64})
    timing = P.make_engineering_control_fault_timing(
        NonnegativeQuantityV1(2 // 1000, ecfgo_seconds), probability,
        NonnegativeQuantityV1(1 // 1, ecfgo_seconds),
        NonnegativeQuantityV1(1 // 10, ecfgo_seconds),
        NonnegativeQuantityV1(2 // 1, ecfgo_seconds),
        NonnegativeQuantityV1(5 // 2, ecfgo_seconds), P.observation_dropout)
    declaration = P.declare_engineering_control_fault_graph(
        "ecfgo-manufactured-declaration", ecfgo_specs, ecfgo_limit, timing)
    g3 = RealizationControlGenomeV4(3, 4, _fixture_refs[3],
        _fixture_graph(), ecfgo_control_graph_value; control=(declaration,))
    candidate_value = CandidateStatePackageV4("ecfgo-manufactured-candidate",
        _fixture_mission, _fixture_mechanism, _fixture_field, g3, registry)
    compiled = P.compile_candidate(candidate_value, registry;
        mission_payload=ecfgo_mission, bounds_payload=ecfgo_bounds_payload,
        comparison_scope=ecfgo_comparison_scope,
        scenario_scope=ecfgo_scenario_scope)
    subject_binding = P.make_engineering_control_fault_subject_binding(compiled,
        registry, ecfgo_mission, ecfgo_bounds_payload,
        ecfgo_comparison_scope, ecfgo_scenario_scope, first(ecfgo_scenarios),
        declaration)
    subject = P.ExecutablePhysicalSubjectV4(compiled.prefix_hash,
        candidate_value.canonical_hashes.genome_bundle_hash,
        compiled.minimality_scope.mission_hash,
        compiled.minimality_scope.bounds_hash, (subject_binding,),
        ecfgo_scenarios, (model="typed-control-chain", revision="v1"),
        P.derive_capability_obligations(compiled))
    P.make_forward_chain_context(candidate_value, compiled, registry,
        ecfgo_mission, ecfgo_bounds_payload, ecfgo_comparison_scope,
        ecfgo_scenario_scope, subject, first(ecfgo_scenarios))
end

function _ecf_probability_execution(probability::Rational{Int64})
    context = _ecf_probability_context(probability)
    trusted_registry = P.register_trusted_engineering_control_fault_provider(
        tecfe_base_registry, context)
    request = P.build_trusted_engineering_control_fault_dispatch_request(
        trusted_registry, context)
    receipt = P.execute_trusted_engineering_control_fault_provider(
        trusted_registry, context, request)
    (context=context, registry=trusted_registry, request=request,
        receipt=receipt, result=receipt.result)
end

@testset "fixed repository engineering provider registration" begin
    @test P.validate_trusted_provider_registry(tecfe_base_registry) ==
        tecfe_base_registry.registry_hash
    @test length(tecfe_base_registry.descriptors) == 2
    @test isempty(tecfe_base_registry.registrations)
    descriptor = P._tpr_find_descriptor(tecfe_base_registry,
        P._TPR_ENGINEERING_CONTROL_FAULT_PROVIDER)
    registration = tecfe_registry.registration
    compilation = P.resolve_engineering_control_fault_graph_obligation(ecfgo_context)

    @test descriptor.source_relative_path ==
        P._TPR_ENGINEERING_CONTROL_FAULT_SOURCE
    @test descriptor.entrypoint === :_trusted_engineering_control_fault_executor
    @test descriptor.executor === P._trusted_engineering_control_fault_executor
    @test descriptor.attested_source_paths ==
        P._TPR_ENGINEERING_CONTROL_FAULT_ATTESTED_SOURCES
    @test descriptor.runtime_hash == P._tpr_runtime_hash(descriptor.executor,
        tecfe_base_registry.repository_root)
    @test P.validate_repository_provider_descriptor(descriptor,
        tecfe_base_registry.repository_root) == descriptor.descriptor_hash
    @test P.validate_trusted_engineering_control_fault_registry(tecfe_registry) ==
        tecfe_registry.registry_hash
    @test P.validate_trusted_engineering_control_fault_registration(registration,
        tecfe_base_registry) == registration.registration_hash
    @test registration.context_hash == ecfgo_context.context_hash
    @test registration.physical_subject_hash ==
        ecfgo_context.subject.physical_subject_hash
    @test registration.scenario_hash == ecfgo_context.scenario_hash
    @test registration.declaration_hash == canonical_hash(compilation.declaration)
    @test registration.subject_binding_hash ==
        canonical_hash(compilation.subject_binding)
    @test registration.compilation_hash == canonical_hash(compilation)
    @test registration.capability_hash == canonical_hash(registration.capability)
    @test registration.input_hash == canonical_hash(registration.input)
    @test registration.manifest.executor === descriptor.executor
    @test registration.manifest.code_hash == descriptor.source_hash
    @test registration.manifest_hash == registration.manifest.manifest_hash

    @test_throws MethodError P.register_trusted_engineering_control_fault_provider(
        tecfe_base_registry, ecfgo_context, descriptor)
    @test_throws ArgumentError P.TrustedEngineeringControlFaultRegistrationV4()
    @test_throws ArgumentError P.TrustedEngineeringControlFaultInputV4()
end

@testset "generic and caller-supplied provider paths stay closed" begin
    registration = tecfe_registry.registration
    descriptor = P._tpr_find_descriptor(tecfe_base_registry,
        P._TPR_ENGINEERING_CONTROL_FAULT_PROVIDER)
    @test_throws ArgumentError P.register_trusted_engineering_control_fault_provider(
        tecfe_base_registry, ecfgo_generic_context)
    @test_throws ArgumentError P.make_repository_owned_provider_manifest(
        tecfe_base_registry, ecfgo_context, descriptor.provider_id,
        registration.capability;
        model_class=P._TPR_ENGINEERING_CONTROL_FAULT_MODEL_CLASS)
    @test_throws ArgumentError P.register_trusted_provider(tecfe_base_registry,
        ecfgo_context, descriptor.provider_id, registration.capability,
        registration.manifest)
    @test_throws MethodError P.register_trusted_engineering_control_fault_provider(
        tecfe_base_registry, ecfgo_context, registration.capability,
        registration.input, registration.manifest, identity)
end

@testset "deterministic bounded manufactured execution" begin
    input = tecfe_registry.registration.input
    result = tecfe_receipt.result
    repeated = P._trusted_engineering_control_fault_executor(ecfgo_context, input)
    times = Tuple(step.time for step in result.trace)
    actuators = Tuple(step.actuator_command for step in result.trace)
    compilation = P.resolve_engineering_control_fault_graph_obligation(ecfgo_context)
    interval = compilation.declaration.actuator_limit.interval.interval

    @test P.validate_trusted_engineering_control_fault_input(input,
        ecfgo_context) == input
    @test P.validate_trusted_engineering_control_fault_result(result,
        ecfgo_context, input) == result
    @test canonical_hash(repeated) == canonical_hash(result)
    @test semantic_view(repeated) == semantic_view(result)
    @test result.trace_hash == canonical_hash(result.trace)
    @test result.trace_hash == Digest256(
        "4f501d75f8e1c4d1257ae78060bb2b9257945407527bfaa84d2139620d33d755")
    @test result.sample_count == length(input.sample_times) == length(result.trace)
    @test times == Tuple(item.value for item in input.sample_times)
    @test issorted(times) && length(unique(times)) == length(times)
    @test first(times) == 0 // 1 && last(times) == input.horizon.value
    @test result.transport_release_count == count(step -> step.released_command,
        result.trace) == 5
    @test all(step -> step.dropout_draw == P._tecfe_dropout_draw(ecfgo_context,
        canonical_hash(input), step.time, step.step_index), result.trace)
    @test all(step -> step.scheduled_dropout_active ==
        P._tecfe_dropout_decision(step.dropout_draw,
            compilation.declaration.timing.dropout_probability,
            step.dropout_window_active), result.trace)
    @test result.scheduled_dropout_sample_count ==
        count(step -> step.scheduled_dropout_active, result.trace) == 0
    @test result.declared_fault_sample_count ==
        count(step -> step.declared_fault_active, result.trace) == 2
    @test result.actuator_bound_violation_count == 0
    @test all(value -> interval.lower <= value <= interval.upper, actuators)
    @test result.maximum_absolute_actuator == maximum(abs, actuators)
    @test result.final_state == 1786562681 // 2000000000
    @test result.status === :operational_screen_completed
    @test result.claim_ceiling === screen_only
    @test result.credible_device_count == 0
    @test !result.emits_evidence && !result.engineering_evidence
    @test !result.physical_evidence && !result.validation_evidence
    @test !result.promotion_authority && !result.p5_authority
    @test !result.terminal_authority
end


@testset "counter-based deterministic dropout probability semantics" begin
    zero = _ecf_probability_execution(0 // 1)
    one = _ecf_probability_execution(1 // 1)
    fractional = _ecf_probability_execution(1 // 2)
    replay = P.execute_trusted_engineering_control_fault_provider(
        fractional.registry, fractional.context, fractional.request)

    for execution in (zero, one, fractional)
        timing = P.resolve_engineering_control_fault_graph_obligation(
            execution.context).declaration.timing
        input_hash = execution.registry.registration.input_hash
        @test all(step -> step.dropout_draw == P._tecfe_dropout_draw(
            execution.context, input_hash, step.time, step.step_index),
            execution.result.trace)
        @test all(step -> step.scheduled_dropout_active ==
            P._tecfe_dropout_decision(step.dropout_draw,
                timing.dropout_probability, step.dropout_window_active),
            execution.result.trace)
        @test all(step -> 0 // 1 <= step.dropout_draw < 1 // 1,
            execution.result.trace)
        @test all(step -> !step.dropout_window_active ||
            step.time >= timing.dropout_onset.value,
            execution.result.trace)
    end

    zero_window = filter(step -> step.dropout_window_active, zero.result.trace)
    one_window = filter(step -> step.dropout_window_active, one.result.trace)
    fractional_window = filter(step -> step.dropout_window_active,
        fractional.result.trace)
    @test !isempty(zero_window) && length(zero_window) == length(one_window) ==
        length(fractional_window)
    @test all(step -> !step.scheduled_dropout_active, zero_window)
    @test zero.result.scheduled_dropout_sample_count == 0
    @test all(step -> step.scheduled_dropout_active, one_window)
    @test one.result.scheduled_dropout_sample_count == length(one_window)
    @test fractional.result.scheduled_dropout_sample_count ==
        count(step -> step.dropout_draw < 1 // 2, fractional_window)
    @test canonical_hash(replay) == canonical_hash(fractional.receipt)
    @test semantic_view(replay) == semantic_view(fractional.receipt)
    @test !P._tecfe_dropout_decision(1 // 4, 0 // 1, true)
    @test !P._tecfe_dropout_decision(1 // 4, 1 // 4, true)
    @test P._tecfe_dropout_decision(1 // 4, 1 // 2, true)
    @test P._tecfe_dropout_decision(1 // 4, 1 // 1, true)
    @test !P._tecfe_dropout_decision(1 // 4, 1 // 1, false)
end

@testset "context, input, request, and result mismatch fail closed" begin
    input = tecfe_registry.registration.input
    result = tecfe_receipt.result
    request = tecfe_request

    @test_throws ArgumentError P.build_trusted_engineering_control_fault_dispatch_request(
        tecfe_registry, ecfgo_generic_context)
    @test_throws ArgumentError P.execute_trusted_engineering_control_fault_provider(
        tecfe_registry, ecfgo_generic_context, request)

    forged_input = _ecf_rehashed_input(input; initial_state=1 // 10)
    @test canonical_hash(forged_input) == forged_input.input_hash
    @test_throws ArgumentError P.validate_trusted_engineering_control_fault_input(
        forged_input, ecfgo_context)

    forged_request = _ecf_rehashed_request(request;
        scenario_hash=ECF_FORGERY_HASH)
    @test canonical_hash(forged_request) == forged_request.request_hash
    @test_throws ArgumentError P.validate_trusted_engineering_control_fault_dispatch_request(
        forged_request, tecfe_registry, ecfgo_context)
    @test_throws ArgumentError P.execute_trusted_engineering_control_fault_provider(
        tecfe_registry, ecfgo_context, forged_request)

    forged_result = _ecf_rehashed_result(result;
        final_state=result.final_state + 1 // 1000)
    @test canonical_hash(forged_result) == forged_result.result_hash
    @test_throws ArgumentError P.validate_trusted_engineering_control_fault_result(
        forged_result, ecfgo_context, input)
end

@testset "descriptor, registration, registry, and receipt forgeries fail closed" begin
    descriptor = P._tpr_find_descriptor(tecfe_base_registry,
        P._TPR_ENGINEERING_CONTROL_FAULT_PROVIDER)
    forged_source = P.RepositoryProviderDescriptorV4(P._TPR_TOKEN,
        descriptor.provider_id, descriptor.source_relative_path,
        descriptor.entrypoint, descriptor.allowed_capability_kinds,
        descriptor.allowed_model_classes, ECF_FORGERY_HASH,
        descriptor.attested_source_paths, descriptor.attested_source_hashes,
        descriptor.runtime_hash, descriptor.executor, descriptor.descriptor_hash)
    @test_throws ArgumentError P.validate_repository_provider_descriptor(
        forged_source, tecfe_base_registry.repository_root)

    forged_runtime = P.RepositoryProviderDescriptorV4(P._TPR_TOKEN,
        descriptor.provider_id, descriptor.source_relative_path,
        descriptor.entrypoint, descriptor.allowed_capability_kinds,
        descriptor.allowed_model_classes, descriptor.source_hash,
        descriptor.attested_source_paths, descriptor.attested_source_hashes,
        ECF_FORGERY_HASH, descriptor.executor, descriptor.descriptor_hash)
    @test_throws ArgumentError P.validate_repository_provider_descriptor(
        forged_runtime, tecfe_base_registry.repository_root)

    registration = tecfe_registry.registration
    forged_registration = _ecf_sealed_replace(
        P.TrustedEngineeringControlFaultRegistrationV4, P._TECFE_TOKEN,
        registration; source_hash=ECF_FORGERY_HASH)
    @test_throws ArgumentError P.validate_trusted_engineering_control_fault_registration(
        forged_registration, tecfe_base_registry)

    forged_registry = P.TrustedEngineeringControlFaultRegistryV4(P._TECFE_TOKEN,
        tecfe_registry.base_registry, tecfe_registry.registration,
        ECF_FORGERY_HASH)
    @test_throws ArgumentError P.validate_trusted_engineering_control_fault_registry(
        forged_registry)

    forged_receipt = _ecf_rehashed_receipt(tecfe_receipt;
        context_hash=ECF_FORGERY_HASH)
    @test canonical_hash(forged_receipt) == forged_receipt.receipt_hash
    @test_throws ArgumentError P.validate_trusted_engineering_control_fault_operational_receipt(
        forged_receipt, tecfe_request, tecfe_registry, ecfgo_context)
end

@testset "operational receipt has no evidence or authority" begin
    receipt = tecfe_receipt
    @test P.validate_trusted_engineering_control_fault_dispatch_request(
        tecfe_request, tecfe_registry, ecfgo_context) == tecfe_request
    @test P.validate_trusted_engineering_control_fault_operational_receipt(
        receipt, tecfe_request, tecfe_registry, ecfgo_context) == receipt
    @test receipt.registry_hash == tecfe_registry.registry_hash
    @test receipt.registration_hash == tecfe_registry.registration.registration_hash
    @test receipt.request_hash == tecfe_request.request_hash
    @test receipt.input_hash == tecfe_registry.registration.input_hash
    @test receipt.result_hash == canonical_hash(receipt.result)
    @test receipt.exit_code == 0
    @test receipt.status === :operational_screen
    @test receipt.claim_ceiling === screen_only
    @test receipt.credible_device_count == 0
    @test !receipt.emits_evidence && !receipt.engineering_evidence
    @test !receipt.physical_evidence && !receipt.validation_evidence
    @test !receipt.promotion_authority && !receipt.p5_authority
    @test !receipt.terminal_authority

    manifest = P.trusted_engineering_control_fault_provider_manifest()
    @test !manifest.accepts_caller_descriptor
    @test !manifest.accepts_caller_manifest
    @test !manifest.accepts_caller_executor
    @test manifest.registration_binds_capability_and_input
    @test manifest.pre_and_post_dispatch_revalidation
    @test manifest.result_is_recomputed_from_exact_rational_trace
    @test manifest.dropout_sampling ===
        :canonical_sha256_counter_first_60_bits
    @test manifest.dropout_draw_denominator == Int64(1) << 60
    @test manifest.dropout_decision ===
        :window_active_and_draw_strictly_below_probability
    @test !manifest.statistical_validation
    @test manifest.operational_status === :operational_screen
    @test manifest.claim_ceiling === screen_only
    @test manifest.credible_device_count == 0
    @test !manifest.emits_evidence && !manifest.engineering_evidence
    @test !manifest.physical_evidence && !manifest.validation_evidence
    @test !manifest.promotion_authority && !manifest.p5_authority
    @test !manifest.terminal_authority
end

println("TRUSTED_ENGINEERING_CONTROL_FAULT_PROVIDER_FOCUSED_EXIT_CODE=0")
