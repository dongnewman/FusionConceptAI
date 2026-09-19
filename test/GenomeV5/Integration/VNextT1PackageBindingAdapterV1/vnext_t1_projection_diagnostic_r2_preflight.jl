using SHA
using FusionConceptAI

"""Independent R2 diagnostic preflight; no focused package test is included."""
const _R2_ROOT = normpath(joinpath(@__DIR__, "..", "..", "..", ".."))
const _R2_REPO = realpath(_R2_ROOT)
const A = FusionConceptAI

# Load only production declarations needed to construct one typed local input.
A.load_genome_v5_components!()
for relative in (
        joinpath("GenomeV5", "G1", "DiffusionDeclarationV1.jl"),
        joinpath("GenomeV5", "G1", "G1SourceAuthorityFactoryV1.jl"),
        joinpath("GenomeV5", "G2", "MetricBoundaryDeclarationV1.jl"),
        joinpath("GenomeV5", "G2", "G2SourceAuthorityFactoryV1.jl"),
        joinpath("GenomeV5", "G3", "G3SourceFeedbackLawV1.jl"),
        joinpath("GenomeV5", "G3", "G3SourceAuthorityFactoryV1.jl"),
        joinpath("GenomeV5", "Integration", "VNextDeclarationTransportLocalV1.jl"),
        joinpath("GenomeV5", "Integration", "VNextDeclarationAuthorityRecheckLocalV1.jl"),
        joinpath("Contracts", "CandidateStatePackageV5Next.jl"),
        joinpath("GenomeV5", "Integration", "VNextGenomeV5Integration.jl"))
    Base.include(A, joinpath(_R2_ROOT, "src", relative))
end
Base.include(Main, joinpath(_R2_ROOT, "test", "GenomeV5", "Integration",
    "vnext_t1_projection_diagnostic_v1.jl"))

const _R2_CANDIDATE = A.QualifiedRefV1("local://candidate/up1-04a", "v5")
const _R2_FAILURE_MESSAGE = "R2 diagnostic preflight failed"

function _r2_require(condition)
    condition || throw(ArgumentError(_R2_FAILURE_MESSAGE))
    nothing
end

_r2_sha(bytes) = A.Digest256(bytes2hex(SHA.sha256(copy(Vector{UInt8}(bytes)))))
_r2_bytes(text) = begin
    bytes = Vector{UInt8}(codeunits(text))
    A.VNextT0LocalBytesV1(bytes, _r2_sha(bytes))
end
_r2_local_axes() = ntuple(i -> A.QualifiedRefV1(
    A.VNEXT_T0_LOCAL_AXIS_IDS_V1[i], "v1"), 4)
function _r2_locator(source_ref, source_bytes, path)
    A.VNextT0LocalSourceLocatorV1(_R2_REPO, path, source_ref.id, source_ref,
        length(source_bytes.bytes), source_bytes.sha256, "diagnostic-fixture",
        :present, :present, :clean, nothing, :isolated_test_fixture)
end
function _r2_factory_axes(api)
    api === :G1 && return (
        A.QualifiedRefV1("fusion.g1.payload-schema", "v2"),
        A.QualifiedRefV1("fusion.g1.canonicalization", "v2"),
        A.QualifiedRefV1("fusion.g1.applicability", "v2"),
        A.QualifiedRefV1("fusion.g1.receipt", "v2"))
    api === :G2 && return (
        A.QualifiedRefV1("fusion.g2.payload-schema", "v5"),
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
function _r2_factory_id(api)
    api === :G1 && return A.VNEXT_T1_G1_FACTORY_ID_V1
    api === :G2 && return A.VNEXT_T1_G2_FACTORY_ID_V1
    api === :G3 && return A.VNEXT_T1_G3_FACTORY_ID_V1
    A.VNEXT_T1_G3_FEEDBACK_FACTORY_ID_V1
end
function _r2_contract(api)
    api === :G1 && return A._g1sf_expected_contract()
    api === :G2 && return A._g2sf_expected_contract()
    api === :G3 && return A.g3_contract_ref(:realization)
    A.vnext_t0_local_g3_feedback_contract_v1()
end
function _r2_factory_result(api, layer, candidate, source_ref, declaration_ref,
        source_bytes, declaration_bytes, locator, axes)
    factory_id = _r2_factory_id(api)
    upstream = _r2_bytes("diagnostic-upstream-" * String(api))
    contract = _r2_contract(api)
    content_identity = A.canonical_hash((factory_id=factory_id,
        factory_version="v1", factory_api=api, candidate_ref=candidate,
        layer=layer, source_ref=source_ref, source_bytes=source_bytes,
        source_size=length(source_bytes.bytes), locator=locator,
        locator_provenance=:isolated_test_fixture,
        declaration_ref=declaration_ref, declaration_bytes=declaration_bytes,
        declaration_hash=declaration_bytes.sha256, status=:present,
        contract_ref=contract, axes=axes,
        upstream_receipt_bytes=upstream, upstream_receipt_hash=upstream.sha256))
    A.VNextT0LocalFactoryResultV1(factory_id, "v1", api, candidate, layer,
        source_ref, source_bytes, length(source_bytes.bytes), locator,
        :isolated_test_fixture, declaration_ref, declaration_bytes,
        declaration_bytes.sha256, :present, contract, content_identity, axes,
        upstream, upstream.sha256)
end
function _r2_declaration(layer, candidate=_R2_CANDIDATE)
    api = layer === :G1 ? :G1 : layer === :G2 ? :G2 : :G3
    source_ref = A.QualifiedRefV1("diagnostic://" * lowercase(String(layer)) * "/source", "v1")
    declaration_ref = A.QualifiedRefV1("diagnostic://" * lowercase(String(layer)) * "/declaration", "v1")
    source_bytes = _r2_bytes("diagnostic-source-" * String(layer))
    body = (candidate_ref=candidate, source_ref=source_ref, layer=layer,
        diagnostic_payload=true)
    semantic_body = _r2_bytes(A.canonical_json(body))
    semantic = A.VNextT0LocalSemanticBodyV1(body, semantic_body, ())
    declaration_bytes = _r2_bytes(A.canonical_json(body))
    locator = _r2_locator(source_ref, source_bytes,
        "test/GenomeV5/Integration/diagnostic-" * lowercase(String(layer)) * ".jl")
    factory_axes = _r2_factory_axes(api)
    factory_result = _r2_factory_result(api, layer, candidate, source_ref,
        declaration_ref, source_bytes, declaration_bytes, locator, factory_axes)
    axes = _r2_local_axes()
    factory = A.VNextT0LocalFactoryReceiptV1(candidate, layer, source_ref,
        declaration_ref, axes, :present, factory_result)
    declaration = A.VNextT0LocalDeclarationReceiptV1(candidate, layer,
        source_ref, declaration_ref, axes, :present, factory_result)
    A.VNextT0LocalPresentDeclarationV1(layer, candidate, source_ref,
        declaration_ref, A.canonical_hash((kind=:source, ref=source_ref,
            bytes_sha256=source_bytes.sha256)),
        A.canonical_hash((kind=:declaration, ref=declaration_ref,
            bytes_sha256=declaration_bytes.sha256)), axes, source_bytes,
        declaration_bytes, semantic, locator, factory, declaration)
end
function _r2_absent_child(kind, candidate=_R2_CANDIDATE)
    bytes = _r2_bytes("diagnostic-child-receipt-" * String(kind))
    A.VNextT0LocalChildAbsentV1(kind, candidate, :G3, String(kind),
        :terminal_deferred, "diagnostic preflight absence", false, :G3,
        bytes, bytes.sha256, "src/GenomeV5/G3/G3SourceFeedbackLawV1.jl")
end
function _r2_feedback(id, target_layer, declaration, candidate=_R2_CANDIDATE)
    target_ref = declaration.declaration_ref
    authority = (candidate_ref=candidate, source_ref=declaration.source_ref)
    target = (target_id=id, target_layer=target_layer, authority=authority)
    body = (candidate_ref=candidate, source_ref=declaration.source_ref,
        declaration_ref=declaration.declaration_ref, target_ref=target_ref,
        feedback_targets=(target,))
    A.VNextT0LocalFeedbackV1(id, target_layer, candidate, target_ref, body,
        A.canonical_hash(body))
end
function _r2_input()
    candidate = _R2_CANDIDATE
    declarations = (_r2_declaration(:G1, candidate),
        _r2_declaration(:G2, candidate), _r2_declaration(:G3, candidate))
    children = (_r2_absent_child(:realization, candidate),
        _r2_absent_child(:control, candidate), _r2_absent_child(:binding, candidate))
    feedback = (_r2_feedback("g1-residual", :G1, declarations[1], candidate),
        _r2_feedback("g2-thermal", :G2, declarations[2], candidate))
    provisional = A.VNextT0LocalTransportV1(candidate, declarations, children,
        feedback, A.Digest256(repeat("0", 64)), :valid, (),
        (:g3_child_terminal_deferred,))
    bundle_hash = A.vnext_t0_local_bundle_hash_recompute_v1(provisional)
    transport = A.VNextT0LocalTransportV1(candidate, declarations, children,
        feedback, bundle_hash, :valid, (), (:g3_child_terminal_deferred,))
    output = A.VNextAuthorityRecheckLocalCheckedPresentV1(candidate,
        declarations[1], declarations[2], declarations[3], feedback, children,
        bundle_hash)
    prior_bytes = Tuple(Vector{UInt8}(codeunits(A.canonical_json(transport))))
    recheck = A.VNextAuthorityRecheckLocalResultV1(:local_checked_present,
        :resolved, false, :contract_only, (), (), output, prior_bytes, bundle_hash)
    A.VNextT1AdmissionInputV1(candidate, recheck, transport, nothing)
end

valid_input = _r2_input()
package_identity = A.canonical_hash((kind=:candidate_identity,
    candidate_ref=valid_input.candidate_ref))
forged = A.VNextT1NoLegacyReceiptV1(
    A.QualifiedRefV1("legacy://GenomeV5/T1/migration", "v1"),
    valid_input.candidate_ref, (), :no_legacy_mapping, package_identity)
input = A.VNextT1AdmissionInputV1(valid_input.candidate_ref,
    valid_input.t0_recheck, valid_input.transport, forged)
admission = A.vnext_t1_admit_skeleton_v1(input)
diagnostic = Main.vnext_t1_projection_diagnostic_v1(input)
expected_stage = :no_legacy
expected_exception_type = :ArgumentError
expected_digest = A.canonical_hash((status=:internal_failure,
    stage=expected_stage, exception_type=expected_exception_type))
_r2_require(admission.status === :fail_closed)
_r2_require(admission.errors == (:t1_projection_invalid,))
_r2_require(diagnostic.status === :internal_failure)
_r2_require(diagnostic.stage === expected_stage)
_r2_require(diagnostic.exception_type === expected_exception_type)
_r2_require(diagnostic.message_digest == expected_digest)
println("R2_DIAGNOSTIC status=$(diagnostic.status) admission_errors=$(admission.errors) stage=$(diagnostic.stage) exception_type=$(diagnostic.exception_type) message_digest=$(diagnostic.message_digest.value)")
