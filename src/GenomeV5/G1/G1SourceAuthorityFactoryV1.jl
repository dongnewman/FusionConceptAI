"""AD49-F0 additive G1 source-stage authority factory.

The factory binds an independently observed, tracked source closure to the
AD45 temporary common handle and the public G1 GenomeContractRef.  The handle
is deliberately retained as a binding handle; it never becomes a candidate
identity.  This file does not alter the V1 diffusion declaration schema or
any registry and does not create a final candidate/package identity.
"""

const G1_SOURCE_AUTHORITY_FACTORY_VERSION_V1 = "v1"
const G1_SOURCE_AUTHORITY_FACTORY_REF_V1 = QualifiedRefV1(
    "fusionconceptai://GenomeV5/G1/source-authority-factory", "v1")
const G1_SOURCE_AUTHORITY_FACTORY_SOURCE_PATH_V1 =
    "src/GenomeV5/G1/DiffusionDeclarationV1.jl"
const G1_SOURCE_AUTHORITY_FACTORY_SOURCE_VERSION_V1 = "v1"
const G1_AD45_COMMON_BINDING_HANDLE_ID_V1 =
    "fusionconceptai://candidate-binding/AD45-FRESH-CANDIDATE-BINDING-ENVELOPE/3da169fa-2376-4b36-b794-ac5a32161aa7"
const G1_AD45_COMMON_BINDING_HANDLE_VERSION_V1 = "v5"
const G1_AD45_ENVELOPE_RELATIVE_PATH_V1 =
    "docs/implementation/AD-45/FRESH-CANDIDATE-BINDING-ENVELOPE/fresh_candidate_binding_envelope_v1.json"
const G1_AD45_ENVELOPE_SHA256_V1 =
    Digest256("17901aa6e1be326b95e56fbbbd5148bd02b7c3ea43bd0c451336cd297e2950dc")
const G1_FACTORY_MODULE_DIR_V1 = @__DIR__

abstract type AbstractG1SourceFactoryIdentityV1 end
abstract type AbstractG1SourceDeclarationV1 end
abstract type AbstractG1SourceConstructionReceiptV1 end

struct G1IndependentSourceLocatorV1
    repository_root::String
    observed_head::String
    source_path::String
    source_bytes::Int
    source_sha256::Digest256
    head_path_status::Symbol
    working_tree_path_status::Symbol
    working_tree_status::Symbol
    head_blob_sha256::Union{Nothing,Digest256}
    provenance::Symbol
    function G1IndependentSourceLocatorV1(repository_root::Any, observed_head::Any,
            source_path::Any, source_bytes::Any, source_sha256::Any,
            head_path_status::Any, working_tree_path_status::Any,
            working_tree_status::Any, head_blob_sha256::Any=nothing,
            provenance::Any=:repository_head)
        root = String(repository_root); head = String(observed_head); path = String(source_path)
        !isempty(root) && !isempty(head) && !isempty(path) ||
            throw(ArgumentError("G1 locator text fields are required"))
        isabspath(path) && throw(ArgumentError("G1 source_path must be relative"))
        occursin("..", replace(path, '\\' => '/')) &&
            throw(ArgumentError("G1 source_path must not escape repository"))
        source_bytes isa Integer && !(source_bytes isa Bool) && source_bytes >= 0 ||
            throw(ArgumentError("G1 source_bytes must be a non-negative integer"))
        source_sha256 isa Digest256 || throw(ArgumentError("G1 source_sha256 must be Digest256"))
        statuses = (head_path_status, working_tree_path_status, working_tree_status)
        all(x -> x isa Symbol, statuses) || throw(ArgumentError("G1 locator statuses must be Symbols"))
        head_blob_sha256 === nothing || head_blob_sha256 isa Digest256 ||
            throw(ArgumentError("G1 head_blob_sha256 must be Digest256 or nothing"))
        provenance isa Symbol && provenance in (:repository_head, :isolated_test_fixture) ||
            throw(ArgumentError("G1 locator provenance must be explicit"))
        new(root, head, replace(path, '\\' => '/'), Int(source_bytes), source_sha256,
            head_path_status, working_tree_path_status, working_tree_status, head_blob_sha256, provenance)
    end
end

"""Arguments for the real G1 diffusion declaration constructor."""
struct G1SourceDeclarationConstructorV1
    constructor::Function
    candidate_ref::QualifiedRefV1
    operators::G1DiffusionOperatorChainV1
    closure_ref::QualifiedRefV1
    applicability_ref::QualifiedRefV1
    applicability_domain::String
    negative_controls::Tuple{Vararg{Symbol}}
    function G1SourceDeclarationConstructorV1(constructor::Any, candidate_ref::Any,
            operators::Any, closure_ref::Any, applicability_ref::Any,
            applicability_domain::Any, negative_controls::Any)
        constructor isa Function || throw(ArgumentError("G1 declaration constructor must be callable"))
        candidate_ref isa QualifiedRefV1 && candidate_ref.version == "v5" ||
            throw(ArgumentError("G1 declaration constructor candidate_ref must be v5 QualifiedRefV1"))
        operators isa G1DiffusionOperatorChainV1 ||
            throw(ArgumentError("G1 declaration constructor operators must be typed"))
        closure_ref isa QualifiedRefV1 && applicability_ref isa QualifiedRefV1 ||
            throw(ArgumentError("G1 declaration refs must be QualifiedRefV1"))
        domain = String(applicability_domain); !isempty(domain) ||
            throw(ArgumentError("G1 applicability_domain is required"))
        controls = Tuple(Symbol.(Tuple(negative_controls)))
        new(constructor, candidate_ref, operators, closure_ref, applicability_ref, domain, controls)
    end
end

struct PresentG1SourceFactoryIdentityV1 <: AbstractG1SourceFactoryIdentityV1
    factory_ref::QualifiedRefV1
    factory_version::String
    locator::G1IndependentSourceLocatorV1
    common_binding_handle::QualifiedRefV1
    contract_ref::GenomeContractRef
    version_axes::G1VersionAxesV2
    source_payload_hash::Digest256
    source_content_hash::Digest256
    declaration_hash::Digest256
    registry_not_used::Bool
    candidate_identity_created::Bool
    final_candidate_or_package_hash_created::Bool
    factory_identity_hash::Digest256
end
struct AbsentG1SourceFactoryIdentityV1 <: AbstractG1SourceFactoryIdentityV1
    reason::Symbol
    terminal_deferred::Bool
    candidate_identity_created::Bool
    final_candidate_or_package_hash_created::Bool
end
struct FailedG1SourceFactoryIdentityV1 <: AbstractG1SourceFactoryIdentityV1
    reason::Symbol
    fail_closed::Bool
    candidate_identity_created::Bool
    final_candidate_or_package_hash_created::Bool
end

struct G1SourceContractBindingV1
    common_binding_handle::QualifiedRefV1
    common_binding_envelope_sha256::Digest256
    contract_ref::GenomeContractRef
    version_axes::G1VersionAxesV2
    binding_role::Symbol
    candidate_identity_created::Bool
    binding_hash::Digest256
end

struct PresentG1SourceDeclarationV1 <: AbstractG1SourceDeclarationV1
    public_contract_ref::GenomeContractRef
    common_binding_handle::QualifiedRefV1
    version_axes::G1VersionAxesV2
    locator::G1IndependentSourceLocatorV1
    source_payload::G1DiffusionSourcePayloadV1
    declaration::G1DiffusionDeclarationV1
    binding::G1SourceContractBindingV1
    source_content_hash::Digest256
    local_declaration_hash::Digest256
    declaration_hash::Digest256
    synthetic_test_only::Bool
    candidate_identity_created::Bool
    final_candidate_or_package_hash_created::Bool
end
struct AbsentG1SourceDeclarationV1 <: AbstractG1SourceDeclarationV1
    reason::Symbol
    terminal_deferred::Bool
    candidate_identity_created::Bool
    final_candidate_or_package_hash_created::Bool
end
struct FailedG1SourceDeclarationV1 <: AbstractG1SourceDeclarationV1
    reason::Symbol
    fail_closed::Bool
    candidate_identity_created::Bool
    final_candidate_or_package_hash_created::Bool
end

struct PresentG1SourceConstructionReceiptV1 <: AbstractG1SourceConstructionReceiptV1
    status::Symbol
    factory_ref::QualifiedRefV1
    locator_digest::Digest256
    source_payload_hash::Digest256
    source_content_hash::Digest256
    local_declaration_hash::Digest256
    declaration_hash::Digest256
    common_binding_handle::QualifiedRefV1
    contract_ref::GenomeContractRef
    version_axes::G1VersionAxesV2
    output_source_declaration::PresentG1SourceDeclarationV1
    registry_not_used::Bool
    trusted::Bool
    candidate_identity_created::Bool
    final_hash_created::Bool
    replayable::Bool
    receipt_hash::Digest256
end
struct AbsentG1SourceConstructionReceiptV1 <: AbstractG1SourceConstructionReceiptV1
    status::Symbol
    reason::Symbol
    terminal_deferred::Bool
    trusted::Bool
    candidate_identity_created::Bool
    final_hash_created::Bool
end
struct FailedG1SourceConstructionReceiptV1 <: AbstractG1SourceConstructionReceiptV1
    status::Symbol
    reason::Symbol
    fail_closed::Bool
    trusted::Bool
    candidate_identity_created::Bool
    final_hash_created::Bool
end

struct G1SourceFactoryConstructionResultV1
    identity::AbstractG1SourceFactoryIdentityV1
    source_declaration::AbstractG1SourceDeclarationV1
    receipt::AbstractG1SourceConstructionReceiptV1
end

semantic_view(x::G1IndependentSourceLocatorV1) =
    (repository_root=x.repository_root, observed_head=x.observed_head, source_path=x.source_path,
     source_bytes=x.source_bytes, source_sha256=x.source_sha256,
     head_path_status=x.head_path_status, working_tree_path_status=x.working_tree_path_status,
     working_tree_status=x.working_tree_status, head_blob_sha256=x.head_blob_sha256,
     provenance=x.provenance)
semantic_view(x::G1SourceDeclarationConstructorV1) =
    (constructor=string(x.constructor), candidate_ref=x.candidate_ref, operators=x.operators,
     closure_ref=x.closure_ref, applicability_ref=x.applicability_ref,
     applicability_domain=x.applicability_domain, negative_controls=x.negative_controls)
semantic_view(x::G1SourceContractBindingV1) =
    (common_binding_handle=x.common_binding_handle, common_binding_envelope_sha256=x.common_binding_envelope_sha256,
     contract_ref=x.contract_ref,
     version_axes=x.version_axes, binding_role=x.binding_role,
     candidate_identity_created=x.candidate_identity_created)
semantic_view(x::PresentG1SourceFactoryIdentityV1) =
    (factory_ref=x.factory_ref, factory_version=x.factory_version, locator=x.locator,
     common_binding_handle=x.common_binding_handle, contract_ref=x.contract_ref,
     version_axes=x.version_axes, source_payload_hash=x.source_payload_hash,
     source_content_hash=x.source_content_hash, declaration_hash=x.declaration_hash,
     registry_not_used=x.registry_not_used, candidate_identity_created=x.candidate_identity_created,
     final_candidate_or_package_hash_created=x.final_candidate_or_package_hash_created)
semantic_view(x::AbsentG1SourceFactoryIdentityV1) =
    (reason=x.reason, terminal_deferred=x.terminal_deferred,
     candidate_identity_created=x.candidate_identity_created,
     final_candidate_or_package_hash_created=x.final_candidate_or_package_hash_created)
semantic_view(x::FailedG1SourceFactoryIdentityV1) =
    (reason=x.reason, fail_closed=x.fail_closed, candidate_identity_created=x.candidate_identity_created,
     final_candidate_or_package_hash_created=x.final_candidate_or_package_hash_created)
semantic_view(x::PresentG1SourceDeclarationV1) =
    (public_contract_ref=x.public_contract_ref, common_binding_handle=x.common_binding_handle,
     version_axes=x.version_axes, locator=x.locator, source_payload=x.source_payload,
     declaration=x.declaration, binding=x.binding, source_content_hash=x.source_content_hash,
     local_declaration_hash=x.local_declaration_hash, synthetic_test_only=x.synthetic_test_only,
     candidate_identity_created=x.candidate_identity_created,
     final_candidate_or_package_hash_created=x.final_candidate_or_package_hash_created)
semantic_view(x::AbsentG1SourceDeclarationV1) =
    (reason=x.reason, terminal_deferred=x.terminal_deferred,
     candidate_identity_created=x.candidate_identity_created,
     final_candidate_or_package_hash_created=x.final_candidate_or_package_hash_created)
semantic_view(x::FailedG1SourceDeclarationV1) =
    (reason=x.reason, fail_closed=x.fail_closed, candidate_identity_created=x.candidate_identity_created,
     final_candidate_or_package_hash_created=x.final_candidate_or_package_hash_created)
semantic_view(x::PresentG1SourceConstructionReceiptV1) =
    (status=x.status, factory_ref=x.factory_ref, locator_digest=x.locator_digest,
     source_payload_hash=x.source_payload_hash, source_content_hash=x.source_content_hash,
     local_declaration_hash=x.local_declaration_hash, declaration_hash=x.declaration_hash,
     common_binding_handle=x.common_binding_handle, contract_ref=x.contract_ref,
     version_axes=x.version_axes, output_source_declaration=x.output_source_declaration,
     registry_not_used=x.registry_not_used, trusted=x.trusted,
     candidate_identity_created=x.candidate_identity_created, final_hash_created=x.final_hash_created,
     replayable=x.replayable)
semantic_view(x::AbsentG1SourceConstructionReceiptV1) =
    (status=x.status, reason=x.reason, terminal_deferred=x.terminal_deferred, trusted=x.trusted,
     candidate_identity_created=x.candidate_identity_created, final_hash_created=x.final_hash_created)
semantic_view(x::FailedG1SourceConstructionReceiptV1) =
    (status=x.status, reason=x.reason, fail_closed=x.fail_closed, trusted=x.trusted,
     candidate_identity_created=x.candidate_identity_created, final_hash_created=x.final_hash_created)
semantic_view(x::G1SourceFactoryConstructionResultV1) =
    (identity=x.identity, source_declaration=x.source_declaration, receipt=x.receipt)

for T in (:G1IndependentSourceLocatorV1, :G1SourceDeclarationConstructorV1,
          :G1SourceContractBindingV1, :PresentG1SourceFactoryIdentityV1,
          :AbsentG1SourceFactoryIdentityV1, :FailedG1SourceFactoryIdentityV1,
          :PresentG1SourceDeclarationV1, :AbsentG1SourceDeclarationV1,
          :FailedG1SourceDeclarationV1, :PresentG1SourceConstructionReceiptV1,
          :AbsentG1SourceConstructionReceiptV1, :FailedG1SourceConstructionReceiptV1,
          :G1SourceFactoryConstructionResultV1)
    @eval canonical_json(x::$T) = canonical_json(semantic_view(x))
end

function _g1sf_git(root, args...)
    try
        cmd = Cmd(String["git", "-C", root, String.(args)...])
        String(readchomp(cmd))
    catch
        nothing
    end
end
function _g1sf_git_bytes(root, args...)
    try
        read(Cmd(String["git", "-C", root, String.(args)...]))
    catch
        nothing
    end
end
function _g1sf_repository_anchor(module_dir=G1_FACTORY_MODULE_DIR_V1)
    module_anchor = try realpath(normpath(joinpath(module_dir, "..", "..", ".."))) catch; return nothing end
    top = _g1sf_git(module_anchor, "rev-parse", "--show-toplevel")
    top isa String || return nothing
    try realpath(top) == module_anchor ? module_anchor : nothing catch; nothing end
end
function _g1sf_validate_locator(locator::G1IndependentSourceLocatorV1)
    locator.source_path == G1_SOURCE_AUTHORITY_FACTORY_SOURCE_PATH_V1 || return :source_path_mismatch
    path = joinpath(locator.repository_root, split(locator.source_path, '/')...)
    isfile(path) || return :source_file_missing
    bytes = try read(path) catch; return :source_read_failed end
    length(bytes) == locator.source_bytes || return :source_bytes_mismatch
    Digest256(bytes2hex(SHA.sha256(bytes))) == locator.source_sha256 || return :source_hash_mismatch
    if locator.provenance === :repository_head
        anchor = _g1sf_repository_anchor()
        anchor === nothing && return :repository_anchor_unavailable
        try realpath(locator.repository_root) == anchor || return :repository_anchor_mismatch catch; return :repository_anchor_mismatch end
    else
        try realpath(locator.repository_root) == locator.repository_root || return :fixture_root_not_canonical catch; return :fixture_root_invalid end
    end
    head = _g1sf_git(locator.repository_root, "rev-parse", "HEAD")
    head isa String && head == locator.observed_head || return :locator_head_mismatch
    tracked = _g1sf_git(locator.repository_root, "ls-files", "--stage", "--", locator.source_path)
    tree = _g1sf_git(locator.repository_root, "ls-tree", "-r", "--name-only", "HEAD", "--", locator.source_path)
    tree isa String || return :source_read_or_git_probe_failed
    actual_head_path = isempty(strip(tree)) ? :absent_untracked : :present
    actual_head_path == locator.head_path_status || return :head_path_status_mismatch
    if actual_head_path === :present
        blob = _g1sf_git(locator.repository_root, "rev-parse", "HEAD:" * locator.source_path)
        blob isa String && length(blob) == 40 || return :head_blob_probe_failed
        head_bytes = _g1sf_git_bytes(locator.repository_root, "show", "HEAD:" * locator.source_path)
        cat_bytes = _g1sf_git_bytes(locator.repository_root, "cat-file", "blob", blob)
        head_bytes isa Vector{UInt8} && cat_bytes isa Vector{UInt8} || return :head_blob_read_failed
        head_bytes == cat_bytes || return :head_blob_bytes_mismatch
        bytes == head_bytes || return :working_tree_head_bytes_mismatch
        length(head_bytes) == locator.source_bytes || return :head_blob_bytes_mismatch
        head_sha = Digest256(bytes2hex(SHA.sha256(head_bytes)))
        head_sha == locator.source_sha256 == locator.head_blob_sha256 || return :head_blob_sha256_mismatch
    else
        locator.head_blob_sha256 === nothing || return :head_blob_sha256_mismatch
    end
    porcelain = _g1sf_git(locator.repository_root, "status", "--porcelain=v1", "--untracked-files=all", "--", locator.source_path)
    porcelain isa String || return :source_read_or_git_probe_failed
    actual_status = isempty(porcelain) ? :clean : startswith(porcelain, "??") ? :untracked : :dirty
    actual_work_path = actual_status === :clean ? :present : :absent_untracked
    actual_work_path == locator.working_tree_path_status || return :working_tree_path_status_mismatch
    actual_status == locator.working_tree_status || return :working_tree_status_mismatch
    # A source-stage authority requires the exact committed, clean closure.
    (actual_head_path === :present && actual_status === :clean && tracked isa String && !isempty(strip(tracked))) ?
        nothing : :source_authority_missing
end

function _g1sf_validate_handle(root, handle)
    handle isa QualifiedRefV1 || return :common_handle_type_mismatch
    handle.version == G1_AD45_COMMON_BINDING_HANDLE_VERSION_V1 || return :common_handle_version_mismatch
    handle.id == G1_AD45_COMMON_BINDING_HANDLE_ID_V1 || return :foreign_common_handle
    path = joinpath(root, split(G1_AD45_ENVELOPE_RELATIVE_PATH_V1, '/')...)
    isfile(path) || return :ad45_envelope_missing
    try
        Digest256(bytes2hex(SHA.sha256(read(path)))) == G1_AD45_ENVELOPE_SHA256_V1 ? nothing : :ad45_envelope_hash_mismatch
    catch
        :ad45_envelope_read_failed
    end
end

function _g1sf_expected_contract()
    GenomeContractRef("fusionconceptai://GenomeV5/G1/diffusion/public-contract/v1", "v5",
        g1_diffusion_schema_hash_v1(), g1_diffusion_canonicalization_hash_v1(),
        "g1-diffusion-v1-profile:" * g1_diffusion_profile_hash_v1().value)
end
function _g1sf_axes_ok(axes)
    axes isa G1VersionAxesV2 || return false
    refs = (axes.payload_schema_version, axes.canonicalization_profile_version,
        axes.applicability_profile_version, axes.evidence_receipt_version)
    all(x -> x isa QualifiedRefV1 && x.version == "v2", refs) &&
        Tuple(x.id for x in refs) == ("fusion.g1.payload-schema", "fusion.g1.canonicalization",
            "fusion.g1.applicability", "fusion.g1.receipt")
end
_g1sf_locator_digest(x) = canonical_hash(x)

function _g1sf_absent(reason)
    (AbsentG1SourceFactoryIdentityV1(reason, true, false, false),
     AbsentG1SourceDeclarationV1(reason, true, false, false),
     AbsentG1SourceConstructionReceiptV1(:typed_absent, reason, true, false, false, false))
end
function _g1sf_failed(reason)
    (FailedG1SourceFactoryIdentityV1(reason, true, false, false),
     FailedG1SourceDeclarationV1(reason, true, false, false),
     FailedG1SourceConstructionReceiptV1(:fail_closed, reason, true, false, false, false))
end

"""Build a source-stage G1 declaration from a real V1 declaration constructor."""
function g1_source_authority_factory_v1(locator::Any, common_binding_handle::Any,
        contract_ref::Any, source_payload::Any, version_axes::Any,
        declaration_constructor::Any)
    locator === nothing && return G1SourceFactoryConstructionResultV1(_g1sf_absent(:locator_missing)[1], _g1sf_absent(:locator_missing)[2], _g1sf_absent(:locator_missing)[3])
    common_binding_handle === nothing && return G1SourceFactoryConstructionResultV1(_g1sf_absent(:common_handle_missing)[1], _g1sf_absent(:common_handle_missing)[2], _g1sf_absent(:common_handle_missing)[3])
    contract_ref === nothing && return G1SourceFactoryConstructionResultV1(_g1sf_absent(:contract_ref_missing)[1], _g1sf_absent(:contract_ref_missing)[2], _g1sf_absent(:contract_ref_missing)[3])
    source_payload === nothing && return G1SourceFactoryConstructionResultV1(_g1sf_absent(:source_payload_missing)[1], _g1sf_absent(:source_payload_missing)[2], _g1sf_absent(:source_payload_missing)[3])
    version_axes === nothing && return G1SourceFactoryConstructionResultV1(_g1sf_absent(:version_axes_missing)[1], _g1sf_absent(:version_axes_missing)[2], _g1sf_absent(:version_axes_missing)[3])
    declaration_constructor === nothing && return G1SourceFactoryConstructionResultV1(_g1sf_absent(:declaration_constructor_missing)[1], _g1sf_absent(:declaration_constructor_missing)[2], _g1sf_absent(:declaration_constructor_missing)[3])
    locator isa G1IndependentSourceLocatorV1 || return G1SourceFactoryConstructionResultV1(_g1sf_failed(:locator_type_mismatch)[1], _g1sf_failed(:locator_type_mismatch)[2], _g1sf_failed(:locator_type_mismatch)[3])
    contract_ref isa GenomeContractRef || return G1SourceFactoryConstructionResultV1(_g1sf_failed(:contract_ref_type_mismatch)[1], _g1sf_failed(:contract_ref_type_mismatch)[2], _g1sf_failed(:contract_ref_type_mismatch)[3])
    source_payload isa G1DiffusionSourcePayloadV1 || return G1SourceFactoryConstructionResultV1(_g1sf_failed(:source_payload_type_mismatch)[1], _g1sf_failed(:source_payload_type_mismatch)[2], _g1sf_failed(:source_payload_type_mismatch)[3])
    version_axes isa G1VersionAxesV2 || return G1SourceFactoryConstructionResultV1(_g1sf_failed(:version_axes_type_mismatch)[1], _g1sf_failed(:version_axes_type_mismatch)[2], _g1sf_failed(:version_axes_type_mismatch)[3])
    declaration_constructor isa G1SourceDeclarationConstructorV1 || return G1SourceFactoryConstructionResultV1(_g1sf_failed(:declaration_constructor_type_mismatch)[1], _g1sf_failed(:declaration_constructor_type_mismatch)[2], _g1sf_failed(:declaration_constructor_type_mismatch)[3])
    contract_ref == _g1sf_expected_contract() || return G1SourceFactoryConstructionResultV1(_g1sf_failed(:public_contract_mismatch)[1], _g1sf_failed(:public_contract_mismatch)[2], _g1sf_failed(:public_contract_mismatch)[3])
    _g1sf_axes_ok(version_axes) || return G1SourceFactoryConstructionResultV1(_g1sf_failed(:version_axes_mismatch)[1], _g1sf_failed(:version_axes_mismatch)[2], _g1sf_failed(:version_axes_mismatch)[3])
    handle_error = _g1sf_validate_handle(locator.repository_root, common_binding_handle)
    handle_error === nothing || return G1SourceFactoryConstructionResultV1(_g1sf_failed(handle_error)[1], _g1sf_failed(handle_error)[2], _g1sf_failed(handle_error)[3])
    locator_error = _g1sf_validate_locator(locator)
    if locator_error !== nothing
        branch = locator_error === :source_authority_missing || locator_error === :source_file_missing ? _g1sf_absent(locator_error) : _g1sf_failed(locator_error)
        return G1SourceFactoryConstructionResultV1(branch[1], branch[2], branch[3])
    end
    ctor = declaration_constructor
    (ctor.constructor === g1_diffusion_declaration_v1 || ctor.constructor === G1DiffusionDeclarationV1) ||
        return G1SourceFactoryConstructionResultV1(_g1sf_failed(:not_real_declaration_constructor)[1], _g1sf_failed(:not_real_declaration_constructor)[2], _g1sf_failed(:not_real_declaration_constructor)[3])
    payload_hash = g1_diffusion_source_hash_v1(source_payload)
    declaration = try
        ctor.constructor(ctor.candidate_ref, source_payload.source_ref, source_payload.source_version,
            payload_hash, source_payload.u, source_payload.K, source_payload.f, ctor.operators,
            ctor.closure_ref, ctor.applicability_ref, ctor.applicability_domain,
            ctor.negative_controls; ownership=:candidate_owned, source_payload=source_payload)
    catch
        return G1SourceFactoryConstructionResultV1(_g1sf_failed(:constructor_rejected_input)[1], _g1sf_failed(:constructor_rejected_input)[2], _g1sf_failed(:constructor_rejected_input)[3])
    end
    declaration isa G1DiffusionDeclarationV1 || return G1SourceFactoryConstructionResultV1(_g1sf_failed(:constructor_result_type_mismatch)[1], _g1sf_failed(:constructor_result_type_mismatch)[2], _g1sf_failed(:constructor_result_type_mismatch)[3])
    declaration.source_payload === source_payload || canonical_hash(declaration.source_payload) == payload_hash || return G1SourceFactoryConstructionResultV1(_g1sf_failed(:declaration_payload_mismatch)[1], _g1sf_failed(:declaration_payload_mismatch)[2], _g1sf_failed(:declaration_payload_mismatch)[3])
    declaration_hash = g1_diffusion_declaration_hash_v1(declaration)
    binding_body = (common_binding_handle=common_binding_handle,
        common_binding_envelope_sha256=G1_AD45_ENVELOPE_SHA256_V1, contract_ref=contract_ref,
        version_axes=version_axes, binding_role=:temporary_common_candidate_binding_handle_only,
        candidate_identity_created=false)
    binding = G1SourceContractBindingV1(common_binding_handle, G1_AD45_ENVELOPE_SHA256_V1, contract_ref, version_axes,
        :temporary_common_candidate_binding_handle_only, false, canonical_hash(binding_body))
    synthetic_test_only = locator.provenance === :isolated_test_fixture
    source_content_hash = canonical_hash((factory_ref=G1_SOURCE_AUTHORITY_FACTORY_REF_V1,
        locator=locator, common_binding_handle=common_binding_handle, contract_ref=contract_ref,
        version_axes=version_axes, source_payload=source_payload, source_payload_hash=payload_hash,
        binding=binding, binding_hash=binding.binding_hash, declaration_hash=declaration_hash,
        synthetic_test_only=synthetic_test_only))
    body = (public_contract_ref=contract_ref, common_binding_handle=common_binding_handle,
        version_axes=version_axes, locator=locator, source_payload=source_payload,
        declaration=declaration, binding=binding, source_content_hash=source_content_hash,
        local_declaration_hash=declaration_hash, synthetic_test_only=synthetic_test_only,
        candidate_identity_created=false, final_candidate_or_package_hash_created=false)
    source_decl = PresentG1SourceDeclarationV1(contract_ref, common_binding_handle, version_axes,
        locator, source_payload, declaration, binding, source_content_hash, declaration_hash,
        canonical_hash(body), synthetic_test_only, false, false)
    locator_digest = _g1sf_locator_digest(locator)
    ibody = (factory_ref=G1_SOURCE_AUTHORITY_FACTORY_REF_V1, factory_version="v1",
        locator=locator, common_binding_handle=common_binding_handle, contract_ref=contract_ref,
        version_axes=version_axes, source_payload_hash=payload_hash,
        source_content_hash=source_content_hash, declaration_hash=declaration_hash,
        registry_not_used=true, candidate_identity_created=false,
        final_candidate_or_package_hash_created=false)
    identity = PresentG1SourceFactoryIdentityV1(G1_SOURCE_AUTHORITY_FACTORY_REF_V1, "v1",
        locator, common_binding_handle, contract_ref, version_axes, payload_hash,
        source_content_hash, declaration_hash, true, false, false, canonical_hash(ibody))
    rbody = (status=:present, factory_ref=G1_SOURCE_AUTHORITY_FACTORY_REF_V1,
        locator_digest=locator_digest, source_payload_hash=payload_hash,
        source_content_hash=source_content_hash, local_declaration_hash=declaration_hash,
        declaration_hash=source_decl.declaration_hash, common_binding_handle=common_binding_handle,
        contract_ref=contract_ref, version_axes=version_axes, output_source_declaration=source_decl,
        registry_not_used=true, trusted=false, candidate_identity_created=false,
        final_hash_created=false, replayable=true)
    receipt = PresentG1SourceConstructionReceiptV1(rbody..., canonical_hash(rbody))
    G1SourceFactoryConstructionResultV1(identity, source_decl, receipt)
end

g1_source_factory_result_status(x::G1SourceFactoryConstructionResultV1) =
    x.identity isa PresentG1SourceFactoryIdentityV1 ? :present :
    x.identity isa AbsentG1SourceFactoryIdentityV1 ? :typed_absent : :fail_closed
g1_source_factory_receipt(x::G1SourceFactoryConstructionResultV1) = x.receipt
g1_source_factory_declaration(x::G1SourceFactoryConstructionResultV1) = x.source_declaration
