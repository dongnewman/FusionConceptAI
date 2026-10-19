using SHA
using FusionConceptAI

"""Independent R3 observe-first diagnostic for the real T1 adapter.

This probe constructs a package through the existing T1 producer, passes its
real wire bytes through the package adapter and then through candidate-binding
V2.  The first emitted line contains only observed fields; all expectation
classification happens after that observation.  No placeholder byte or digest
is used as a valid input.
"""
const _R3_ROOT = normpath(joinpath(@__DIR__, "..", "..", "..", ".."))
const _R3_REPO = realpath(_R3_ROOT)
const A = FusionConceptAI
A.load_genome_v5_components!()
Base.include(Main, joinpath(_R3_ROOT, "test", "GenomeV5", "Integration",
    "vnext_declaration_transport_local_v1_tests.jl"))
Base.include(A, joinpath(_R3_ROOT, "src", "GenomeV5", "Integration",
    "VNextDeclarationAuthorityRecheckLocalV1.jl"))
Base.include(A, joinpath(_R3_ROOT, "src", "Contracts",
    "CandidateStatePackageV5Next.jl"))
Base.include(A, joinpath(_R3_ROOT, "src", "GenomeV5", "Integration",
    "VNextGenomeV5Integration.jl"))
Base.include(Main, joinpath(_R3_ROOT, "test", "GenomeV5", "Integration",
    "vnext_t1_projection_diagnostic_v1.jl"))
Base.include(A, joinpath(_R3_ROOT, "src", "Contracts",
    "VNextT1CanonicalBytesV2.jl"))
Base.include(A, joinpath(_R3_ROOT, "src", "Contracts",
    "VNextT1CandidateBindingV2.jl"))
Base.include(A, joinpath(_R3_ROOT, "src", "Contracts",
    "VNextT1PackageBindingAdapterV1.jl"))

const _R3_CANDIDATE = A.QualifiedRefV1("local://candidate/up1-04a", "v5")
_r3_sha(bytes) = A.Digest256(bytes2hex(SHA.sha256(copy(Vector{UInt8}(bytes)))))
_r3_bytes(text) = begin
    bytes = Vector{UInt8}(codeunits(text))
    A.VNextT0LocalBytesV1(bytes, _r3_sha(bytes))
end
_r3_local_axes() = ntuple(i -> A.QualifiedRefV1(
    A.VNEXT_T0_LOCAL_AXIS_IDS_V1[i], "v1"), 4)
function _r3_locator(source_ref, source_bytes, path)
    A.VNextT0LocalSourceLocatorV1(_R3_REPO, path, source_ref.id, source_ref,
        length(source_bytes.bytes), source_bytes.sha256, "diagnostic-fixture",
        :present, :present, :clean, nothing, :isolated_test_fixture)
end
function _r3_factory_axes(api)
    api === :G1 && return (A.QualifiedRefV1("fusion.g1.payload-schema", "v2"),
        A.QualifiedRefV1("fusion.g1.canonicalization", "v2"),
        A.QualifiedRefV1("fusion.g1.applicability", "v2"),
        A.QualifiedRefV1("fusion.g1.receipt", "v2"))
    api === :G2 && return (A.QualifiedRefV1("fusion.g2.payload-schema", "v5"),
        A.QualifiedRefV1("fusion.g2.canonicalization", "v5"),
        A.QualifiedRefV1("fusion.g2.applicability", "v5"),
        A.QualifiedRefV1("fusion.g2.receipt", "v5"))
    api === :G3 && begin
        axes = A.g3_version_axes(:realization)
        return (axes.payload_schema_version, axes.canonicalization_profile_version,
            axes.applicability_profile_version, axes.evidence_receipt_version)
    end
    A.VNEXT_T0_G3_FEEDBACK_AXES_V1
end
function _r3_factory_id(api)
    api === :G1 && return A.VNEXT_T1_G1_FACTORY_ID_V1
    api === :G2 && return A.VNEXT_T1_G2_FACTORY_ID_V1
    api === :G3 && return A.VNEXT_T1_G3_FACTORY_ID_V1
    A.VNEXT_T1_G3_FEEDBACK_FACTORY_ID_V1
end
function _r3_contract(api)
    api === :G1 && return A._g1sf_expected_contract()
    api === :G2 && return A._g2sf_expected_contract()
    api === :G3 && return A.g3_contract_ref(:realization)
    A.vnext_t0_local_g3_feedback_contract_v1()
end
function _r3_factory_result(api, layer, candidate, source_ref, declaration_ref,
        source_bytes, declaration_bytes, locator, axes)
    factory_id = _r3_factory_id(api)
    upstream = _r3_bytes("diagnostic-upstream-" * String(api))
    contract = _r3_contract(api)
    content_identity = A.canonical_hash((factory_id=factory_id, factory_version="v1",
        factory_api=api, candidate_ref=candidate, layer=layer,
        source_ref=source_ref, source_bytes=source_bytes,
        source_size=length(source_bytes.bytes), locator=locator,
        locator_provenance=:isolated_test_fixture, declaration_ref=declaration_ref,
        declaration_bytes=declaration_bytes, declaration_hash=declaration_bytes.sha256,
        status=:present, contract_ref=contract, axes=axes,
        upstream_receipt_bytes=upstream, upstream_receipt_hash=upstream.sha256))
    A.VNextT0LocalFactoryResultV1(factory_id, "v1", api, candidate, layer,
        source_ref, source_bytes, length(source_bytes.bytes), locator,
        :isolated_test_fixture, declaration_ref, declaration_bytes,
        declaration_bytes.sha256, :present, contract, content_identity, axes,
        upstream, upstream.sha256)
end
function _r3_declaration(layer, candidate=_R3_CANDIDATE)
    api = layer === :G1 ? :G1 : layer === :G2 ? :G2 : :G3
    source_ref = A.QualifiedRefV1("diagnostic://" * lowercase(String(layer)) * "/source", "v1")
    declaration_ref = A.QualifiedRefV1("diagnostic://" * lowercase(String(layer)) * "/declaration", "v1")
    source_bytes = _r3_bytes("diagnostic-source-" * String(layer))
    body = (candidate_ref=candidate, source_ref=source_ref, layer=layer,
        diagnostic_payload=true)
    semantic_body = _r3_bytes(A.canonical_json(body))
    semantic = A.VNextT0LocalSemanticBodyV1(body, semantic_body, ())
    declaration_bytes = _r3_bytes(A.canonical_json(body))
    locator = _r3_locator(source_ref, source_bytes,
        "test/GenomeV5/Integration/diagnostic-" * lowercase(String(layer)) * ".jl")
    factory_result = _r3_factory_result(api, layer, candidate, source_ref,
        declaration_ref, source_bytes, declaration_bytes, locator, _r3_factory_axes(api))
    axes = _r3_local_axes()
    factory = A.VNextT0LocalFactoryReceiptV1(candidate, layer, source_ref,
        declaration_ref, axes, :present, factory_result)
    declaration = A.VNextT0LocalDeclarationReceiptV1(candidate, layer,
        source_ref, declaration_ref, axes, :present, factory_result)
    A.VNextT0LocalPresentDeclarationV1(layer, candidate, source_ref,
        declaration_ref, A.canonical_hash((kind=:source, ref=source_ref,
            bytes_sha256=source_bytes.sha256)), A.canonical_hash((kind=:declaration,
            ref=declaration_ref, bytes_sha256=declaration_bytes.sha256)), axes,
        source_bytes, declaration_bytes, semantic, locator, factory, declaration)
end
function _r3_absent_child(kind, candidate=_R3_CANDIDATE)
    bytes = _r3_bytes("diagnostic-child-receipt-" * String(kind))
    A.VNextT0LocalChildAbsentV1(kind, candidate, :G3, String(kind),
        :terminal_deferred, "diagnostic preflight absence", false, :G3,
        bytes, bytes.sha256, "src/GenomeV5/G3/G3SourceFeedbackLawV1.jl")
end
function _r3_feedback(id, target_layer, declaration, candidate=_R3_CANDIDATE)
    target_ref = declaration.declaration_ref
    authority = (candidate_ref=candidate, source_ref=declaration.source_ref)
    target = (target_id=id, target_layer=target_layer, authority=authority)
    body = (candidate_ref=candidate, source_ref=declaration.source_ref,
        declaration_ref=declaration.declaration_ref, target_ref=target_ref,
        feedback_targets=(target,))
    A.VNextT0LocalFeedbackV1(id, target_layer, candidate, target_ref, body,
        A.canonical_hash(body))
end
function _r3_input()
    candidate = Main._T0L_CANDIDATE
    g1, g2, g3 = Main._t0l_g1(), Main._t0l_g2(), Main._t0l_g3()
    declarations = (Main._t0l_present(:G1, g1),
        Main._t0l_present(:G2, g2), Main._t0l_present(:G3, g3))
    children = (Main._t0l_child(:realization), Main._t0l_child(:control),
        Main._t0l_child(:binding))
    feedback = ntuple(i -> begin
        id = i == 1 ? "g1-residual" : "g2-thermal"
        target = i == 1 ? declarations[1].declaration_ref :
            declarations[2].declaration_ref
        layer = i == 1 ? :G1 : :G2
        raw_target = only(filter(x -> x.target_id == id, g3.feedback_targets))
        body = (candidate_ref=candidate,
            source_ref=(i == 1 ? declarations[1].source_ref :
                declarations[2].source_ref),
            declaration_ref=(i == 1 ? declarations[1].declaration_ref :
                declarations[2].declaration_ref), target_ref=target,
            feedback_targets=(raw_target,))
        A.VNextT0LocalFeedbackV1(id, layer, candidate, target, body,
            A.canonical_hash(body))
    end, 2)
    transport_admission = A.vnext_declaration_transport_local_v1(
        candidate, declarations, children, feedback)
    transport_admission.status === :valid ||
        error("R3 source-backed transport failed: $(transport_admission.errors)")
    recheck = A.vnext_declaration_authority_recheck_local_v1(
        A.VNextAuthorityRecheckLocalInputV1(candidate,
            transport_admission.transport, declarations))
    A.VNextT1AdmissionInputV1(candidate, recheck,
        transport_admission.transport, nothing)
end

function _r3_repackage(package; candidate_ref=package.candidate_ref,
        declarations=package.declarations, package_hash=package.package_hash,
        semantic_identity=package.semantic_identity)
    A.CandidateStatePackageV5Next(candidate_ref, declarations, package.children,
        package.axes, package.feedback, package.source_hashes,
        package.declaration_hashes, package.layer_contracts,
        package.schema_hashes, package.canonicalization_hashes,
        package.profile_hashes, package.component_identity,
        package.component_count_receipt, semantic_identity,
        package.no_legacy_receipt, package.t0_gate, package.status,
        package.resolution, package.accepted, package.claim_ceiling,
        package.package_schema_version, package.package_schema_hash,
        package.package_canonicalization_version,
        package.package_canonicalization_hash, package.package_profile_version,
        package.package_profile_hash, package_hash)
end

function _r3_empty_declaration(declaration)
    empty_bytes = A.VNextT1CanonicalBytesV1(UInt8[])
    A.VNextT1DeclarationRecordV1(declaration.layer,
        declaration.candidate_ref, declaration.source_ref,
        declaration.declaration_ref, A.Digest256(repeat("0", 64)),
        declaration.declaration_identity_hash, declaration.axes, empty_bytes,
        declaration.declaration_bytes, declaration.semantic_body_bytes,
        declaration.source_locator, declaration.factory_receipt,
        declaration.declaration_receipt, declaration.contract_identity)
end

function _r3_upstream_missing_declaration(package)
    candidate = package.candidate_ref
    transport = _r3_input().transport
    missing = A.VNextT0LocalAbsentDeclarationV1(:G1, candidate,
        :missing_declaration, :terminal_deferred)
    missing_transport = A.VNextT0LocalTransportV1(candidate,
        (missing, transport.declarations[2], transport.declarations[3]),
        transport.children, transport.feedback, transport.bundle_hash,
        transport.status, transport.errors, transport.gaps)
    input_hash = A.canonical_hash((stage=:package_constructor,
        candidate_ref=candidate, declarations=missing_transport.declarations,
        bundle_hash=missing_transport.bundle_hash))
    try
        A._vnext_t1_declaration_tuple(missing_transport, candidate)
        return (label=:missing_declaration, status=:unexpected_success,
            reason=:unexpected_success, stage=:package_constructor,
            exception_type=nothing, exception_message_hash=nothing,
            backtrace_hash=nothing, input_hash=input_hash,
            adapter_receipt=false)
    catch exception
        frames = Tuple(string(frame) for frame in stacktrace(catch_backtrace()))
        message = sprint(showerror, exception)
        reason = nameof(typeof(exception)) === :ArgumentError &&
            occursin("all three present declarations", message) ?
            :upstream_missing_declaration : :upstream_constructor_exception
        return (label=:missing_declaration, status=:fail_closed,
            reason=reason, stage=:package_constructor,
            exception_type=nameof(typeof(exception)),
            exception_message_hash=A.canonical_hash(message),
            backtrace_hash=A.canonical_hash(frames), input_hash=input_hash,
            adapter_receipt=false)
    end
end

function _r3_emit_observation(label, observed)
    diagnostic = observed.diagnostic
    result = observed.result
    exception_type = diagnostic.exception_type === nothing ? :none :
        diagnostic.exception_type
    backtrace_hash = diagnostic.backtrace_hash === nothing ? :none :
        diagnostic.backtrace_hash.value
    println("R3_DIAGNOSTIC case=$(label) status=$(result.status) " *
        "result_reason=$(result.reason) diagnostic_reason=$(diagnostic.reason) " *
        "stage=$(diagnostic.stage) exception_type=$(exception_type) " *
        "backtrace_hash=$(backtrace_hash) input_hash=$(diagnostic.input_hash.value) " *
        "wire_hash=$(result.wire_hash === nothing ? :none : result.wire_hash.value)")
end

function _r3_emit_upstream(observed)
    exception_type = observed.exception_type === nothing ? :none :
        observed.exception_type
    println("R3_DIAGNOSTIC case=$(observed.label) status=$(observed.status) " *
        "result_reason=$(observed.reason) diagnostic_reason=$(observed.reason) " *
        "stage=$(observed.stage) exception_type=$(exception_type) " *
        "backtrace_hash=$(observed.backtrace_hash === nothing ? :none : observed.backtrace_hash.value) " *
        "input_hash=$(observed.input_hash.value) adapter_receipt=$(observed.adapter_receipt)")
end

function _r3_capture_upstream_admission_failure(input)
    stage = :snapshot
    input_hash = A.canonical_hash((candidate_ref=input.candidate_ref,
        t0_recheck=(status=input.t0_recheck.status,
            resolution=input.t0_recheck.resolution,
            accepted=input.t0_recheck.accepted,
            claim_ceiling=input.t0_recheck.claim_ceiling,
            prior_bundle_sha256=input.t0_recheck.prior_bundle_sha256),
        transport=(candidate_ref=input.transport.candidate_ref,
            bundle_hash=input.transport.bundle_hash,
            status=input.transport.status,
            errors=input.transport.errors, gaps=input.transport.gaps),
        stage=:package_constructor))
    try
        A._vnext_t1_snapshot(input)
        stage = :declarations
        A._vnext_t1_declaration_tuple(input.transport, input.candidate_ref)
        return (status=:unexpected_success, stage=:declarations,
            exception_type=nothing, exception_message_hash=nothing,
            backtrace_hash=nothing, input_hash=input_hash)
    catch exception
        message = sprint(showerror, exception)
        frames = Tuple(string(frame) for frame in stacktrace(catch_backtrace()))
        return (status=:internal_failure, stage=stage,
            exception_type=nameof(typeof(exception)),
            exception_message_hash=A.canonical_hash(message),
            backtrace_hash=A.canonical_hash(frames), input_hash=input_hash)
    end
end

function _r3_capture_declaration_failure(input)
    for declaration_index in 1:3
        declaration = input.transport.declarations[declaration_index]
        input_hash = A.canonical_hash((stage=:declaration_record,
            declaration_index=declaration_index,
            candidate_ref=input.candidate_ref,
            layer=declaration.layer,
            declaration_candidate_ref=declaration.candidate_ref,
            source_ref=declaration.source_ref,
            declaration_ref=declaration.declaration_ref,
            source_sha256=declaration.source_bytes.sha256,
            declaration_sha256=declaration.declaration_bytes.sha256,
            semantic_body_sha256=declaration.semantic_body.bytes.sha256))
        try
            A._vnext_t1_declaration_record(declaration, input.candidate_ref)
        catch exception
            message = sprint(showerror, exception)
            frames = Tuple(string(frame) for frame in stacktrace(catch_backtrace()))
            return (status=:internal_failure, stage=:declarations,
                declaration_index=declaration_index,
                exception_type=nameof(typeof(exception)),
                exception_message_hash=A.canonical_hash(message),
                backtrace_hash=A.canonical_hash(frames), input_hash=input_hash)
        end
    end
    nothing
end

_r3_nonzero_digest(digest) = digest !== nothing &&
    digest.value != repeat("0", 64)

valid_input = _r3_input()
admission = A.vnext_t1_admit_skeleton_v1(valid_input)
if admission.package === nothing
    declaration_diagnostic = _r3_capture_declaration_failure(valid_input)
    declaration_diagnostic !== nothing &&
        (declaration_diagnostic.declaration_index in 1:3 ||
            error("R3_DECLARATION_DIAGNOSTIC_INDEX_INVALID"))
    declaration_diagnostic !== nothing &&
        (_r3_nonzero_digest(declaration_diagnostic.exception_message_hash) &&
            _r3_nonzero_digest(declaration_diagnostic.backtrace_hash) &&
            _r3_nonzero_digest(declaration_diagnostic.input_hash) ||
            error("R3_DECLARATION_DIAGNOSTIC_HASH_INVALID"))
    diagnostic = declaration_diagnostic === nothing ?
        _r3_capture_upstream_admission_failure(valid_input) : declaration_diagnostic
    declaration_index = hasproperty(diagnostic, :declaration_index) ?
        diagnostic.declaration_index : :none
    println("R3_UPSTREAM_DIAGNOSTIC status=$(diagnostic.status) " *
        "stage=$(diagnostic.stage) exception_type=$(diagnostic.exception_type) " *
        "declaration_index=$(declaration_index) " *
        "exception_message_hash=$(diagnostic.exception_message_hash === nothing ? :none : diagnostic.exception_message_hash.value) " *
        "backtrace_hash=$(diagnostic.backtrace_hash === nothing ? :none : diagnostic.backtrace_hash.value) " *
        "input_hash=$(diagnostic.input_hash.value)")
    error("R3_PACKAGE_CONSTRUCTION_FAILED status=$(admission.status) errors=$(admission.errors) gaps=$(admission.gaps)")
end
package = admission.package
wire = A.VNextT1CanonicalBytesV2(UInt8[0x11, 0x22, 0x33, 0x44])

function _r3_receipt_negative(receipt, candidate, label, receipt_bytes)
    input_hash = A.canonical_hash((stage=:receipt_envelope, label=label,
        candidate_ref=candidate, factory_result_hash=receipt.factory_result_hash,
        receipt_bytes_sha256=receipt_bytes.sha256))
    try
        A._vnext_t1_validate_receipt_envelope(receipt_bytes,
            receipt.factory_result)
        return (status=:unexpected_accept, stage=:receipt_envelope,
            reason=:receipt_envelope_mismatch_not_detected,
            exception_type=nothing, exception_message_hash=nothing,
            backtrace_hash=nothing, input_hash=input_hash)
    catch exception
        message = sprint(showerror, exception)
        frames = Tuple(string(frame) for frame in stacktrace(catch_backtrace()))
        return (status=:fail_closed, stage=:receipt_envelope,
            reason=:receipt_envelope_mismatch,
            exception_type=nameof(typeof(exception)),
            exception_message_hash=A.canonical_hash(message),
            backtrace_hash=A.canonical_hash(frames), input_hash=input_hash)
    end
end

function _r3_emit_receipt_negative(label, diagnostic)
    println("R3_DIAGNOSTIC case=$(label) status=$(diagnostic.status) " *
        "reason=$(diagnostic.reason) stage=$(diagnostic.stage) " *
        "exception_type=$(diagnostic.exception_type === nothing ? :none : diagnostic.exception_type) " *
        "exception_message_hash=$(diagnostic.exception_message_hash === nothing ? :none : diagnostic.exception_message_hash.value) " *
        "backtrace_hash=$(diagnostic.backtrace_hash === nothing ? :none : diagnostic.backtrace_hash.value) " *
        "input_hash=$(diagnostic.input_hash.value)")
end

function _r3_declaration_bytes_negative(label, action, input_hash)
    try
        action()
        return (status=:unexpected_accept, stage=:declaration_bytes,
            reason=:declaration_bytes_mismatch_not_detected,
            exception_type=nothing, exception_message_hash=nothing,
            backtrace_hash=nothing, input_hash=input_hash)
    catch exception
        message = sprint(showerror, exception)
        frames = Tuple(string(frame) for frame in stacktrace(catch_backtrace()))
        return (status=:fail_closed, stage=:declaration_bytes,
            reason=label === :mutated_declaration_bytes ?
                :factory_result_declaration_bytes_mismatch :
                :factory_result_declaration_hash_mismatch,
            exception_type=nameof(typeof(exception)),
            exception_message_hash=A.canonical_hash(message),
            backtrace_hash=A.canonical_hash(frames), input_hash=input_hash)
    end
end

function _r3_factory_result_with_declaration_bytes(result, declaration_bytes)
    declaration_hash = declaration_bytes.sha256
    content_identity = A.canonical_hash((factory_id=result.factory_id,
        factory_version=result.factory_version, factory_api=result.factory_api,
        candidate_ref=result.candidate_ref, layer=result.layer,
        source_ref=result.source_ref, source_bytes=result.source_bytes,
        source_size=result.source_size, locator=result.locator,
        locator_provenance=result.locator_provenance,
        declaration_ref=result.declaration_ref,
        declaration_bytes=declaration_bytes,
        declaration_hash=declaration_hash, status=result.status,
        contract_ref=result.contract_ref, axes=result.axes,
        upstream_receipt_bytes=result.upstream_receipt_bytes,
        upstream_receipt_hash=result.upstream_receipt_hash))
    A.VNextT0LocalFactoryResultV1(result.factory_id, result.factory_version,
        result.factory_api, result.candidate_ref, result.layer,
        result.source_ref, result.source_bytes, result.source_size,
        result.locator, result.locator_provenance, result.declaration_ref,
        declaration_bytes, declaration_hash, result.status, result.contract_ref,
        content_identity, result.axes, result.upstream_receipt_bytes,
        result.upstream_receipt_hash)
end

function _r3_emit_declaration_bytes_negative(label, diagnostic)
    println("R3_DIAGNOSTIC case=$(label) status=$(diagnostic.status) " *
        "reason=$(diagnostic.reason) stage=$(diagnostic.stage) " *
        "exception_type=$(diagnostic.exception_type === nothing ? :none : diagnostic.exception_type) " *
        "exception_message_hash=$(diagnostic.exception_message_hash === nothing ? :none : diagnostic.exception_message_hash.value) " *
        "backtrace_hash=$(diagnostic.backtrace_hash === nothing ? :none : diagnostic.backtrace_hash.value) " *
        "input_hash=$(diagnostic.input_hash.value)")
end

receipt_for_negative = package.declarations[1].factory_receipt
receipt_bytes_mutated = copy(receipt_for_negative.bytes.bytes)
receipt_bytes_mutated[1] = xor(receipt_bytes_mutated[1], UInt8(0x01))
tampered_receipt_bytes = A.VNextT0LocalBytesV1(receipt_bytes_mutated,
    _r3_sha(receipt_bytes_mutated))
tampered_receipt_hash = A.VNextT0LocalBytesV1(
    copy(receipt_for_negative.bytes.bytes), A.Digest256(repeat("f", 64)))
tampered_receipt_bytes_diagnostic = _r3_receipt_negative(
    receipt_for_negative, package.candidate_ref, :tampered_receipt_bytes,
    tampered_receipt_bytes)
tampered_receipt_hash_diagnostic = _r3_receipt_negative(
    receipt_for_negative, package.candidate_ref, :tampered_receipt_hash,
    tampered_receipt_hash)
_r3_emit_receipt_negative(:tampered_receipt_bytes,
    tampered_receipt_bytes_diagnostic)
_r3_emit_receipt_negative(:tampered_receipt_hash,
    tampered_receipt_hash_diagnostic)

declaration_for_negative = package.declarations[3]
factory_result_for_negative = declaration_for_negative.factory_receipt.factory_result
declaration_bytes_mutated = copy(declaration_for_negative.declaration_bytes.bytes)
declaration_bytes_mutated[1] = xor(declaration_bytes_mutated[1], UInt8(0x01))
mutated_declaration_bytes = A.VNextT0LocalBytesV1(
    declaration_bytes_mutated, _r3_sha(declaration_bytes_mutated))
mutated_declaration_result = _r3_factory_result_with_declaration_bytes(
    factory_result_for_negative, mutated_declaration_bytes)
mutated_declaration_input_hash = A.canonical_hash((
    stage=:declaration_bytes, label=:mutated_declaration_bytes,
    candidate_ref=package.candidate_ref,
    declaration_ref=declaration_for_negative.declaration_ref,
    declaration_sha256=mutated_declaration_bytes.sha256))
mutated_declaration_diagnostic = _r3_declaration_bytes_negative(
    :mutated_declaration_bytes,
    () -> A._vnext_t1_validate_factory_result(mutated_declaration_result,
        declaration_for_negative, package.candidate_ref,
        declaration_for_negative.axes), mutated_declaration_input_hash)
hash_only_declaration_input_hash = A.canonical_hash((
    stage=:declaration_bytes, label=:hash_only_declaration,
    candidate_ref=package.candidate_ref,
    declaration_ref=declaration_for_negative.declaration_ref,
    declaration_sha256=declaration_for_negative.declaration_bytes.sha256,
    tampered_hash=repeat("f", 64)))
hash_only_declaration_diagnostic = _r3_declaration_bytes_negative(
    :hash_only_declaration,
    () -> A.VNextT0LocalFactoryResultV1(factory_result_for_negative.factory_id,
        factory_result_for_negative.factory_version,
        factory_result_for_negative.factory_api,
        factory_result_for_negative.candidate_ref,
        factory_result_for_negative.layer,
        factory_result_for_negative.source_ref,
        factory_result_for_negative.source_bytes,
        factory_result_for_negative.source_size,
        factory_result_for_negative.locator,
        factory_result_for_negative.locator_provenance,
        factory_result_for_negative.declaration_ref,
        factory_result_for_negative.declaration_bytes,
        A.Digest256(repeat("f", 64)), factory_result_for_negative.status,
        factory_result_for_negative.contract_ref,
        factory_result_for_negative.content_identity,
        factory_result_for_negative.axes,
        factory_result_for_negative.upstream_receipt_bytes,
        factory_result_for_negative.upstream_receipt_hash),
    hash_only_declaration_input_hash)
_r3_emit_declaration_bytes_negative(:mutated_declaration_bytes,
    mutated_declaration_diagnostic)
_r3_emit_declaration_bytes_negative(:hash_only_declaration,
    hash_only_declaration_diagnostic)

positive_diagnostic = A._vnext_t1_package_binding_adapter_diagnose_v1(
    package; wire=wire)
positive_observation = A.vnext_t1_package_binding_adapter_observe_v1(
    package; wire=wire)
positive = positive_observation.result
binding = A.vnext_t1_candidate_binding_v2(positive.input, (positive.input,))
wire_roundtrip = A.VNextT1CanonicalBytesV2(A.copy_bytes(wire))

wrong_hash_package = _r3_repackage(package;
    package_hash=A.Digest256(repeat("f", 64)))
wrong_hash_observation = A.vnext_t1_package_binding_adapter_observe_v1(
    wrong_hash_package; wire=wire)
wrong_hash_diagnostic = wrong_hash_observation.diagnostic
wrong_hash_result = wrong_hash_observation.result

foreign_candidate = A.QualifiedRefV1("local://candidate/foreign", "v5")
foreign_package = _r3_repackage(package; candidate_ref=foreign_candidate)
foreign_observation = A.vnext_t1_package_binding_adapter_observe_v1(
    foreign_package; wire=wire)
foreign_diagnostic = foreign_observation.diagnostic
foreign_result = foreign_observation.result

zero_declaration = _r3_empty_declaration(package.declarations[1])
zero_package = _r3_repackage(package;
    declarations=(zero_declaration, package.declarations[2], package.declarations[3]))
zero_observation = A.vnext_t1_package_binding_adapter_observe_v1(
    zero_package; wire=wire)
zero_diagnostic = zero_observation.diagnostic
zero_result = zero_observation.result

zero_hash = A.Digest256(repeat("0", 64))
zero_hash_package = _r3_repackage(package; package_hash=zero_hash,
    semantic_identity=zero_hash)
zero_hash_observation = A.vnext_t1_package_binding_adapter_observe_v1(
    zero_hash_package; wire=wire)
zero_hash_diagnostic = zero_hash_observation.diagnostic
zero_hash_result = zero_hash_observation.result

wrong_wire = A.VNextT1CanonicalBytesV2("r3-wire",
    A.Digest256(repeat("f", 64)), A.VNEXT_T1_CANONICAL_BYTES_V2_ENCODING)
wrong_wire_observation = A.vnext_t1_package_binding_adapter_observe_v1(
    package; wire=wrong_wire)
wrong_wire_diagnostic = wrong_wire_observation.diagnostic
wrong_wire_result = wrong_wire_observation.result

missing_declaration = _r3_upstream_missing_declaration(package)

# Observe first: emit every actual adapter/upstream diagnostic before any
# expectation check. Exception text is retained only as a digest; each
# diagnostic object retains type, backtrace frames and input hash.
_r3_emit_observation("positive", positive_observation)
_r3_emit_observation("wrong_package_hash", wrong_hash_observation)
_r3_emit_observation("foreign_candidate", foreign_observation)
_r3_emit_observation("zero_bytes", zero_observation)
_r3_emit_observation("zero_hash", zero_hash_observation)
_r3_emit_observation("wrong_wire_hash", wrong_wire_observation)
_r3_emit_upstream(missing_declaration)

classification = positive.status === :prepared_not_executed &&
    positive.reason === :mapped_prepared_not_executed &&
    positive.input !== nothing && positive.input.wire.sha256 == wire_roundtrip.sha256 &&
    positive_diagnostic.reason === nothing &&
    _r3_nonzero_digest(positive_diagnostic.input_hash) &&
    binding.status === :bound &&
    tampered_receipt_bytes_diagnostic.status === :fail_closed &&
    tampered_receipt_bytes_diagnostic.reason === :receipt_envelope_mismatch &&
    _r3_nonzero_digest(tampered_receipt_bytes_diagnostic.exception_message_hash) &&
    _r3_nonzero_digest(tampered_receipt_bytes_diagnostic.backtrace_hash) &&
    _r3_nonzero_digest(tampered_receipt_bytes_diagnostic.input_hash) &&
    tampered_receipt_hash_diagnostic.status === :fail_closed &&
    tampered_receipt_hash_diagnostic.reason === :receipt_envelope_mismatch &&
    _r3_nonzero_digest(tampered_receipt_hash_diagnostic.exception_message_hash) &&
    _r3_nonzero_digest(tampered_receipt_hash_diagnostic.backtrace_hash) &&
    _r3_nonzero_digest(tampered_receipt_hash_diagnostic.input_hash) &&
    mutated_declaration_diagnostic.status === :fail_closed &&
    mutated_declaration_diagnostic.reason ===
        :factory_result_declaration_bytes_mismatch &&
    _r3_nonzero_digest(mutated_declaration_diagnostic.exception_message_hash) &&
    _r3_nonzero_digest(mutated_declaration_diagnostic.backtrace_hash) &&
    _r3_nonzero_digest(mutated_declaration_diagnostic.input_hash) &&
    hash_only_declaration_diagnostic.status === :fail_closed &&
    hash_only_declaration_diagnostic.reason ===
        :factory_result_declaration_hash_mismatch &&
    _r3_nonzero_digest(hash_only_declaration_diagnostic.exception_message_hash) &&
    _r3_nonzero_digest(hash_only_declaration_diagnostic.backtrace_hash) &&
    _r3_nonzero_digest(hash_only_declaration_diagnostic.input_hash) &&
    wrong_hash_result.status === :fail_closed &&
    wrong_hash_diagnostic.reason === :package_hash_mismatch &&
    _r3_nonzero_digest(wrong_hash_diagnostic.input_hash) &&
    foreign_result.status === :fail_closed &&
    foreign_diagnostic.reason === :candidate_ref_conflict &&
    _r3_nonzero_digest(foreign_diagnostic.input_hash) &&
    zero_result.status === :fail_closed &&
    zero_diagnostic.reason === :zero_bytes_placeholder &&
    _r3_nonzero_digest(zero_diagnostic.input_hash) &&
    zero_hash_result.status === :fail_closed &&
    zero_hash_diagnostic.reason === :zero_hash_placeholder &&
    _r3_nonzero_digest(zero_hash_diagnostic.input_hash) &&
    wrong_wire_result.status === :fail_closed &&
    wrong_wire_diagnostic.reason === :wire_hash_mismatch &&
    _r3_nonzero_digest(wrong_wire_diagnostic.input_hash) &&
    missing_declaration.status === :fail_closed &&
    missing_declaration.reason === :upstream_missing_declaration &&
    missing_declaration.stage === :package_constructor &&
    _r3_nonzero_digest(missing_declaration.input_hash) &&
    missing_declaration.backtrace_hash !== nothing ?
    :diagnostic_observed_expected : :diagnostic_observed_unexpected
classification === :diagnostic_observed_expected ||
    error("R3_EXPECTATION_FAILED classification=$(classification)")
