"""AD49-F0 additive G2 source-stage authority factory.

This adapter consumes a tracked, clean independent locator, the exact AD45
temporary common handle, a public five-field GenomeContractRef, typed G2 source
payload and the real metric-boundary declaration constructor.  It preserves
GenomeContractRef throughout the G2 source/declaration path and never creates
a QualifiedRef mapping or final package identity.
"""

if !isdefined(@__MODULE__, :NativeGitReadCompatibilityV1)
    Base.include(@__MODULE__, joinpath(@__DIR__, "..", "Integration", "NativeGitReadCompatibilityV1.jl"))
end

const G2_SOURCE_AUTHORITY_FACTORY_VERSION_V1 = "v1"
const G2_SOURCE_AUTHORITY_FACTORY_REF_V1 = QualifiedRefV1(
    "fusionconceptai://GenomeV5/G2/source-authority-factory", "v1")
const G2_SOURCE_AUTHORITY_FACTORY_SOURCE_PATH_V1 =
    "src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl"
const G2_AD45_COMMON_BINDING_HANDLE_ID_V1 =
    "fusionconceptai://candidate-binding/AD45-FRESH-CANDIDATE-BINDING-ENVELOPE/3da169fa-2376-4b36-b794-ac5a32161aa7"
const G2_AD45_COMMON_BINDING_HANDLE_VERSION_V1 = "v5"
const G2_AD45_ENVELOPE_RELATIVE_PATH_V1 =
    "docs/implementation/AD-45/FRESH-CANDIDATE-BINDING-ENVELOPE/fresh_candidate_binding_envelope_v1.json"
const G2_AD45_ENVELOPE_SHA256_V1 =
    Digest256("17901aa6e1be326b95e56fbbbd5148bd02b7c3ea43bd0c451336cd297e2950dc")
const G2_FACTORY_MODULE_DIR_V1 = @__DIR__

abstract type AbstractG2SourceFactoryIdentityV1 end
abstract type AbstractG2SourceDeclarationV1 end
abstract type AbstractG2SourceConstructionReceiptV1 end

struct G2IndependentSourceLocatorV1
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
    function G2IndependentSourceLocatorV1(repository_root::Any, observed_head::Any,
            source_path::Any, source_bytes::Any, source_sha256::Any,
            head_path_status::Any, working_tree_path_status::Any,
            working_tree_status::Any, head_blob_sha256::Any=nothing,
            provenance::Any=:repository_head)
        root = String(repository_root); head = String(observed_head); path = String(source_path)
        !isempty(root) && !isempty(head) && !isempty(path) ||
            throw(ArgumentError("G2 locator text fields are required"))
        isabspath(path) && throw(ArgumentError("G2 source_path must be relative"))
        occursin("..", replace(path, '\\' => '/')) &&
            throw(ArgumentError("G2 source_path must not escape repository"))
        source_bytes isa Integer && !(source_bytes isa Bool) && source_bytes >= 0 ||
            throw(ArgumentError("G2 source_bytes must be a non-negative integer"))
        source_sha256 isa Digest256 || throw(ArgumentError("G2 source_sha256 must be Digest256"))
        all(x -> x isa Symbol, (head_path_status, working_tree_path_status, working_tree_status)) ||
            throw(ArgumentError("G2 locator statuses must be Symbols"))
        head_blob_sha256 === nothing || head_blob_sha256 isa Digest256 ||
            throw(ArgumentError("G2 head_blob_sha256 must be Digest256 or nothing"))
        provenance isa Symbol && provenance in (:repository_head, :isolated_test_fixture,
            :up1_frozen_snapshot, :current_source) ||
            throw(ArgumentError("G2 locator provenance must be explicit"))
        new(root, head, replace(path, '\\' => '/'), Int(source_bytes), source_sha256,
            head_path_status, working_tree_path_status, working_tree_status, head_blob_sha256, provenance)
    end
end

struct G2SourceDeclarationConstructorV1
    constructor::Function
    function G2SourceDeclarationConstructorV1(constructor::Any)
        constructor isa Function || throw(ArgumentError("G2 declaration constructor must be callable"))
        new(constructor)
    end
end

struct PresentG2SourceFactoryIdentityV1 <: AbstractG2SourceFactoryIdentityV1
    factory_ref::QualifiedRefV1
    factory_version::String
    locator::G2IndependentSourceLocatorV1
    common_binding_handle::QualifiedRefV1
    contract_ref::GenomeContractRef
    version_axes::G2VersionAxesV2
    source_payload_hash::Digest256
    source_content_hash::Digest256
    declaration_hash::Digest256
    registry_not_used::Bool
    candidate_identity_created::Bool
    final_candidate_or_package_hash_created::Bool
    factory_identity_hash::Digest256
end
struct AbsentG2SourceFactoryIdentityV1 <: AbstractG2SourceFactoryIdentityV1
    reason::Symbol
    terminal_deferred::Bool
    candidate_identity_created::Bool
    final_candidate_or_package_hash_created::Bool
end
struct FailedG2SourceFactoryIdentityV1 <: AbstractG2SourceFactoryIdentityV1
    reason::Symbol
    fail_closed::Bool
    candidate_identity_created::Bool
    final_candidate_or_package_hash_created::Bool
end

struct G2SourceContractBindingV1
    common_binding_handle::QualifiedRefV1
    common_binding_envelope_sha256::Digest256
    contract_ref::GenomeContractRef
    version_axes::G2VersionAxesV2
    binding_role::Symbol
    candidate_identity_created::Bool
    binding_hash::Digest256
end

struct PresentG2SourceDeclarationV1 <: AbstractG2SourceDeclarationV1
    public_contract_ref::GenomeContractRef
    common_binding_handle::QualifiedRefV1
    version_axes::G2VersionAxesV2
    locator::G2IndependentSourceLocatorV1
    source_payload::G2MBSourceV1
    declaration::G2MBDeclarationV1
    binding::G2SourceContractBindingV1
    source_content_hash::Digest256
    local_declaration_hash::Digest256
    declaration_hash::Digest256
    synthetic_test_only::Bool
    candidate_identity_created::Bool
    final_candidate_or_package_hash_created::Bool
end
struct AbsentG2SourceDeclarationV1 <: AbstractG2SourceDeclarationV1
    reason::Symbol
    terminal_deferred::Bool
    candidate_identity_created::Bool
    final_candidate_or_package_hash_created::Bool
end
struct FailedG2SourceDeclarationV1 <: AbstractG2SourceDeclarationV1
    reason::Symbol
    fail_closed::Bool
    candidate_identity_created::Bool
    final_candidate_or_package_hash_created::Bool
end

struct PresentG2SourceConstructionReceiptV1 <: AbstractG2SourceConstructionReceiptV1
    status::Symbol
    factory_ref::QualifiedRefV1
    locator_digest::Digest256
    source_payload_hash::Digest256
    source_content_hash::Digest256
    local_declaration_hash::Digest256
    declaration_hash::Digest256
    common_binding_handle::QualifiedRefV1
    contract_ref::GenomeContractRef
    version_axes::G2VersionAxesV2
    output_source_declaration::PresentG2SourceDeclarationV1
    registry_not_used::Bool
    trusted::Bool
    candidate_identity_created::Bool
    final_hash_created::Bool
    replayable::Bool
    receipt_hash::Digest256
end
struct AbsentG2SourceConstructionReceiptV1 <: AbstractG2SourceConstructionReceiptV1
    status::Symbol
    reason::Symbol
    terminal_deferred::Bool
    trusted::Bool
    candidate_identity_created::Bool
    final_hash_created::Bool
end
struct FailedG2SourceConstructionReceiptV1 <: AbstractG2SourceConstructionReceiptV1
    status::Symbol
    reason::Symbol
    fail_closed::Bool
    trusted::Bool
    candidate_identity_created::Bool
    final_hash_created::Bool
end

struct G2SourceFactoryConstructionResultV1
    identity::AbstractG2SourceFactoryIdentityV1
    source_declaration::AbstractG2SourceDeclarationV1
    receipt::AbstractG2SourceConstructionReceiptV1
end

semantic_view(x::G2IndependentSourceLocatorV1) =
    (repository_root=x.repository_root, observed_head=x.observed_head, source_path=x.source_path,
     source_bytes=x.source_bytes, source_sha256=x.source_sha256,
     head_path_status=x.head_path_status, working_tree_path_status=x.working_tree_path_status,
     working_tree_status=x.working_tree_status, head_blob_sha256=x.head_blob_sha256,
     provenance=x.provenance)
semantic_view(x::G2SourceDeclarationConstructorV1) = (constructor=string(x.constructor),)
semantic_view(x::G2SourceContractBindingV1) =
    (common_binding_handle=x.common_binding_handle, common_binding_envelope_sha256=x.common_binding_envelope_sha256,
     contract_ref=x.contract_ref,
     version_axes=x.version_axes, binding_role=x.binding_role,
     candidate_identity_created=x.candidate_identity_created)
semantic_view(x::PresentG2SourceFactoryIdentityV1) =
    (factory_ref=x.factory_ref, factory_version=x.factory_version, locator=x.locator,
     common_binding_handle=x.common_binding_handle, contract_ref=x.contract_ref,
     version_axes=x.version_axes, source_payload_hash=x.source_payload_hash,
     source_content_hash=x.source_content_hash, declaration_hash=x.declaration_hash,
     registry_not_used=x.registry_not_used, candidate_identity_created=x.candidate_identity_created,
     final_candidate_or_package_hash_created=x.final_candidate_or_package_hash_created)
semantic_view(x::AbsentG2SourceFactoryIdentityV1) =
    (reason=x.reason, terminal_deferred=x.terminal_deferred, candidate_identity_created=x.candidate_identity_created,
     final_candidate_or_package_hash_created=x.final_candidate_or_package_hash_created)
semantic_view(x::FailedG2SourceFactoryIdentityV1) =
    (reason=x.reason, fail_closed=x.fail_closed, candidate_identity_created=x.candidate_identity_created,
     final_candidate_or_package_hash_created=x.final_candidate_or_package_hash_created)
semantic_view(x::PresentG2SourceDeclarationV1) =
    (public_contract_ref=x.public_contract_ref, common_binding_handle=x.common_binding_handle,
     version_axes=x.version_axes, locator=x.locator, source_payload=x.source_payload,
     declaration=x.declaration, binding=x.binding, source_content_hash=x.source_content_hash,
     local_declaration_hash=x.local_declaration_hash, synthetic_test_only=x.synthetic_test_only,
     candidate_identity_created=x.candidate_identity_created,
     final_candidate_or_package_hash_created=x.final_candidate_or_package_hash_created)
semantic_view(x::AbsentG2SourceDeclarationV1) =
    (reason=x.reason, terminal_deferred=x.terminal_deferred, candidate_identity_created=x.candidate_identity_created,
     final_candidate_or_package_hash_created=x.final_candidate_or_package_hash_created)
semantic_view(x::FailedG2SourceDeclarationV1) =
    (reason=x.reason, fail_closed=x.fail_closed, candidate_identity_created=x.candidate_identity_created,
     final_candidate_or_package_hash_created=x.final_candidate_or_package_hash_created)
semantic_view(x::PresentG2SourceConstructionReceiptV1) =
    (status=x.status, factory_ref=x.factory_ref, locator_digest=x.locator_digest,
     source_payload_hash=x.source_payload_hash, source_content_hash=x.source_content_hash,
     local_declaration_hash=x.local_declaration_hash, declaration_hash=x.declaration_hash,
     common_binding_handle=x.common_binding_handle, contract_ref=x.contract_ref,
     version_axes=x.version_axes, output_source_declaration=x.output_source_declaration,
     registry_not_used=x.registry_not_used, trusted=x.trusted,
     candidate_identity_created=x.candidate_identity_created, final_hash_created=x.final_hash_created,
     replayable=x.replayable)
semantic_view(x::AbsentG2SourceConstructionReceiptV1) =
    (status=x.status, reason=x.reason, terminal_deferred=x.terminal_deferred, trusted=x.trusted,
     candidate_identity_created=x.candidate_identity_created, final_hash_created=x.final_hash_created)
semantic_view(x::FailedG2SourceConstructionReceiptV1) =
    (status=x.status, reason=x.reason, fail_closed=x.fail_closed, trusted=x.trusted,
     candidate_identity_created=x.candidate_identity_created, final_hash_created=x.final_hash_created)
semantic_view(x::G2SourceFactoryConstructionResultV1) =
    (identity=x.identity, source_declaration=x.source_declaration, receipt=x.receipt)

for T in (:G2IndependentSourceLocatorV1, :G2SourceDeclarationConstructorV1,
          :G2SourceContractBindingV1,
          :PresentG2SourceFactoryIdentityV1, :AbsentG2SourceFactoryIdentityV1,
          :FailedG2SourceFactoryIdentityV1, :PresentG2SourceDeclarationV1,
          :AbsentG2SourceDeclarationV1, :FailedG2SourceDeclarationV1,
          :PresentG2SourceConstructionReceiptV1, :AbsentG2SourceConstructionReceiptV1,
          :FailedG2SourceConstructionReceiptV1, :G2SourceFactoryConstructionResultV1)
    @eval canonical_json(x::$T) = canonical_json(semantic_view(x))
end

function _g2sf_git(root, args...)
    try
        output = NativeGitReadCompatibilityV1.git_text(root, args...)
        output isa AbstractString || return nothing
        chomp(String(output))
    catch err
        err isa ManagedExternalProcessV1.ManagedProcessError && rethrow()
        nothing
    end
end
function _g2sf_git_bytes(root, args...)
    try
        output = NativeGitReadCompatibilityV1.git_bytes(root, args...)
        output isa Vector{UInt8} || return nothing
        output
    catch err
        err isa ManagedExternalProcessV1.ManagedProcessError && rethrow()
        nothing
    end
end
function _g2sf_validate_git(locator::G2IndependentSourceLocatorV1)
    root = try realpath(locator.repository_root) catch; return :repository_root_invalid end
    git_top = _g2sf_git(locator.repository_root, "rev-parse", "--show-toplevel")
    git_top isa String && !isempty(strip(git_top)) || return :repository_root_not_git
    try realpath(git_top) == root || return :repository_root_mismatch
    catch; return :repository_root_mismatch end
    head = _g2sf_git(locator.repository_root, "rev-parse", "HEAD")
    head isa String && occursin(r"^[0-9a-f]{40}$", head) || return :head_probe_failed
    head == locator.observed_head || return :locator_head_mismatch
    tree = _g2sf_git(locator.repository_root, "ls-tree", "-r", "--name-only", "HEAD", "--", locator.source_path)
    tracked = _g2sf_git(locator.repository_root, "ls-files", "--stage", "--", locator.source_path)
    verbose = _g2sf_git(locator.repository_root, "ls-files", "-v", "--", locator.source_path)
    tree isa String && tracked isa String && verbose isa String || return :source_read_or_git_probe_failed
    tree_lines = isempty(tree) ? String[] : split(tree, '\n'; keepempty=false)
    tracked_lines = isempty(tracked) ? String[] : split(tracked, '\n'; keepempty=false)
    verbose_lines = isempty(verbose) ? String[] : split(verbose, '\n'; keepempty=false)
    actual_head_path = isempty(tree_lines) ? :absent_untracked : :present
    actual_head_path == locator.head_path_status || return :head_path_status_mismatch
    porcelain = _g2sf_git(locator.repository_root, "status", "--porcelain=v1", "--untracked-files=all", "--", locator.source_path)
    porcelain isa String || return :source_read_or_git_probe_failed
    actual_status = isempty(porcelain) ? :clean : startswith(porcelain, "??") ? :untracked : :dirty
    actual_work_path = actual_status === :clean ? :present : :absent_untracked
    actual_work_path == locator.working_tree_path_status || return :working_tree_path_status_mismatch
    actual_status == locator.working_tree_status || return :working_tree_status_mismatch
    if actual_head_path === :absent_untracked
        isempty(tracked_lines) || return :tracked_path_mismatch
        isempty(verbose_lines) || return :index_flags_malformed
        locator.head_blob_sha256 === nothing || return :head_blob_sha256_mismatch
        actual_status === :untracked || return :source_authority_missing
        return :source_authority_missing
    end
    length(tree_lines) == 1 && tree_lines[1] == locator.source_path || return :head_path_missing
    locator.head_path_status == :present || return :head_path_status_mismatch
    length(tracked_lines) == 1 || return :tracked_path_missing
    tracked_match = match(r"^([0-9]{6}) ([0-9a-f]{40}) ([0-3])\t(.+)$", tracked_lines[1])
    tracked_match === nothing && return :tracked_entry_malformed
    tracked_match.captures[3] == "0" || return :tracked_entry_unmerged
    tracked_match.captures[4] == locator.source_path || return :tracked_path_mismatch
    length(verbose_lines) == 1 || return :tracked_path_missing
    flag = first(verbose_lines[1])
    flag == 'h' && return :index_assume_unchanged
    flag == 's' && return :index_skip_worktree
    (flag == 'H' || flag == 'S') || return :index_flags_malformed
    debug_index = _g2sf_git(locator.repository_root, "ls-files", "--debug", "--", locator.source_path)
    debug_index isa String || return :index_flags_probe_failed
    debug_match = match(r"flags:\s*([0-9a-fA-F]+)", debug_index)
    debug_match === nothing && return :index_flags_malformed
    index_flags = try parse(UInt32, debug_match.captures[1]; base=16) catch; return :index_flags_malformed end
    index_flags & UInt32(0x8000) != 0 && return :index_assume_unchanged
    index_flags & UInt32(0x4000) != 0 && return :index_skip_worktree
    index_flags == 0 || return :index_flags_malformed
    blob = _g2sf_git(locator.repository_root, "rev-parse", "HEAD:" * locator.source_path)
    blob isa String && occursin(r"^[0-9a-f]{40}$", blob) || return :head_blob_probe_failed
    head_bytes = _g2sf_git_bytes(locator.repository_root, "show", "HEAD:" * locator.source_path)
    cat_bytes = _g2sf_git_bytes(locator.repository_root, "cat-file", "blob", blob)
    head_bytes isa Vector{UInt8} && cat_bytes isa Vector{UInt8} || return :head_blob_read_failed
    head_bytes == cat_bytes || return :head_blob_bytes_mismatch
    working_path = joinpath(locator.repository_root, split(locator.source_path, '/')...)
    isfile(working_path) || return :source_file_missing
    try read(working_path) catch; return :source_read_failed end
    length(head_bytes) == locator.source_bytes || return :head_blob_bytes_mismatch
    head_sha = Digest256(bytes2hex(SHA.sha256(head_bytes)))
    head_sha == locator.source_sha256 == locator.head_blob_sha256 || return :head_blob_sha256_mismatch
    filtered_blob = _g2sf_git(locator.repository_root, "hash-object", "--path", locator.source_path, working_path)
    filtered_blob isa String && filtered_blob == blob || return :working_tree_filtered_blob_mismatch
    isempty(porcelain) && actual_status === :clean || return :working_tree_dirty
    nothing
end
function _g2sf_repository_anchor(module_dir=G2_FACTORY_MODULE_DIR_V1)
    module_anchor = try realpath(normpath(joinpath(module_dir, "..", "..", ".."))) catch; return nothing end
    top = _g2sf_git(module_anchor, "rev-parse", "--show-toplevel")
    top isa String || return nothing
    try realpath(top) == module_anchor ? module_anchor : nothing catch; nothing end
end
function _g2sf_validate_locator(locator::G2IndependentSourceLocatorV1, frozen_context=nothing)
    if frozen_context isa AbstractString
        locator.source_path == G2_SOURCE_AUTHORITY_FACTORY_SOURCE_PATH_V1 ||
            return :source_path_mismatch
        locator.provenance === :current_source || return :locator_provenance_mismatch
        return NativeGitReadCompatibilityV1.current_source_validation(frozen_context, locator; family=:g2)
    end
    locator.source_path == G2_SOURCE_AUTHORITY_FACTORY_SOURCE_PATH_V1 || return :source_path_mismatch
    locator.provenance === :up1_frozen_snapshot &&
        !(frozen_context isa NativeGitReadCompatibilityV1.UP1FrozenSourceContextV1) &&
        return :up1_frozen_context_missing
    if frozen_context !== nothing
        return NativeGitReadCompatibilityV1.frozen_source_validation(frozen_context, locator; family=:g2)
    end
    NativeGitReadCompatibilityV1._guard_legacy_git_access("_g2sf_validate_locator")
    path = joinpath(locator.repository_root, split(locator.source_path, '/')...)
    isfile(path) || return :source_file_missing
    try read(path) catch; return :source_read_failed end
    if locator.provenance === :repository_head
        anchor = _g2sf_repository_anchor()
        anchor === nothing && return :repository_anchor_unavailable
        try realpath(locator.repository_root) == anchor || return :repository_anchor_mismatch catch; return :repository_anchor_mismatch end
    else
        try realpath(locator.repository_root) == locator.repository_root || return :fixture_root_not_canonical catch; return :fixture_root_invalid end
    end
    head = _g2sf_git(locator.repository_root, "rev-parse", "HEAD")
    head isa String && head == locator.observed_head || return :locator_head_mismatch
    _g2sf_validate_git(locator)
end
function _g2sf_validate_handle(root, handle, frozen_context=nothing)
    handle isa QualifiedRefV1 || return :common_handle_type_mismatch
    handle.version == G2_AD45_COMMON_BINDING_HANDLE_VERSION_V1 || return :common_handle_version_mismatch
    handle.id == G2_AD45_COMMON_BINDING_HANDLE_ID_V1 || return :foreign_common_handle
    if frozen_context isa AbstractString
        envelope = NativeGitReadCompatibilityV1.current_source(frozen_context,
            G2_AD45_ENVELOPE_RELATIVE_PATH_V1)
        return Digest256(envelope.sha256) == G2_AD45_ENVELOPE_SHA256_V1 ? nothing : :ad45_envelope_hash_mismatch
    elseif frozen_context !== nothing
        envelope = NativeGitReadCompatibilityV1.frozen_source(frozen_context,
            G2_AD45_ENVELOPE_RELATIVE_PATH_V1)
        envelope === nothing && return :ad45_envelope_missing
        envelope.role == "binding_envelope" || throw(ArgumentError("frozen AD45 envelope role mismatch"))
        return Digest256(bytes2hex(SHA.sha256(envelope.bytes))) == G2_AD45_ENVELOPE_SHA256_V1 ?
            nothing : :ad45_envelope_hash_mismatch
    end
    NativeGitReadCompatibilityV1._guard_legacy_git_access("_g2sf_validate_handle")
    path = joinpath(root, split(G2_AD45_ENVELOPE_RELATIVE_PATH_V1, '/')...)
    isfile(path) || return :ad45_envelope_missing
    try
        Digest256(bytes2hex(SHA.sha256(read(path)))) == G2_AD45_ENVELOPE_SHA256_V1 ? nothing : :ad45_envelope_hash_mismatch
    catch
        :ad45_envelope_read_failed
    end
end
function _g2sf_expected_contract(region_interface_present::Bool=false)
    profile = G2MBProfileV1("fusion.g2.metric-boundary.profile")
    GenomeContractRef("fusionconceptai://GenomeV5/G2/metric-boundary/public-contract/v1", "v5",
        g2mb_schema_hash_v1(region_interface_present), g2mb_canonicalization_hash_v1(), g2mb_profile_token_v1(profile))
end
_g2sf_expected_contract(source::G2MBSourceV1) =
    _g2sf_expected_contract(source.region_interface !== nothing)
function _g2sf_axes_ok(axes)
    axes isa G2VersionAxesV2 || return false
    refs = (axes.payload_schema_version, axes.canonicalization_profile_version,
        axes.applicability_profile_version, axes.evidence_receipt_version)
    all(x -> x isa QualifiedRefV1 && x.version == "v5", refs) &&
        Tuple(x.id for x in refs) == ("fusion.g2.payload-schema", "fusion.g2.canonicalization",
            "fusion.g2.applicability", "fusion.g2.receipt")
end
_g2sf_absent(reason) = (AbsentG2SourceFactoryIdentityV1(reason, true, false, false),
    AbsentG2SourceDeclarationV1(reason, true, false, false),
    AbsentG2SourceConstructionReceiptV1(:typed_absent, reason, true, false, false, false))
_g2sf_failed(reason) = (FailedG2SourceFactoryIdentityV1(reason, true, false, false),
    FailedG2SourceDeclarationV1(reason, true, false, false),
    FailedG2SourceConstructionReceiptV1(:fail_closed, reason, true, false, false, false))

"""Build a source-stage G2 declaration using the real declaration constructor."""
function _g2_source_authority_factory_core_v1(locator::Any, common_binding_handle::Any,
        contract_ref::Any, source_payload::Any, version_axes::Any,
        declaration_constructor::Any, frozen_context::Union{Nothing,NativeGitReadCompatibilityV1.FrozenSourceContextV1,NativeGitReadCompatibilityV1.UP1FrozenSourceContextV1,AbstractString};
        allow_legacy::Bool=false)
    for (value, reason) in ((locator, :locator_missing), (common_binding_handle, :common_handle_missing),
            (contract_ref, :contract_ref_missing), (source_payload, :source_payload_missing),
            (version_axes, :version_axes_missing), (declaration_constructor, :declaration_constructor_missing))
        value === nothing && begin; b = _g2sf_absent(reason); return G2SourceFactoryConstructionResultV1(b...); end
    end
    locator isa G2IndependentSourceLocatorV1 || begin; b=_g2sf_failed(:locator_type_mismatch); return G2SourceFactoryConstructionResultV1(b...); end
    common_binding_handle isa QualifiedRefV1 || begin; b=_g2sf_failed(:common_handle_type_mismatch); return G2SourceFactoryConstructionResultV1(b...); end
    contract_ref isa GenomeContractRef || begin; b=_g2sf_failed(:contract_ref_type_mismatch); return G2SourceFactoryConstructionResultV1(b...); end
    source_payload isa G2MBSourceV1 || begin; b=_g2sf_failed(:source_payload_type_mismatch); return G2SourceFactoryConstructionResultV1(b...); end
    version_axes isa G2VersionAxesV2 || begin; b=_g2sf_failed(:version_axes_type_mismatch); return G2SourceFactoryConstructionResultV1(b...); end
    declaration_constructor isa G2SourceDeclarationConstructorV1 || begin; b=_g2sf_failed(:declaration_constructor_type_mismatch); return G2SourceFactoryConstructionResultV1(b...); end
    contract_ref == _g2sf_expected_contract(source_payload isa G2MBSourceV1 && source_payload.region_interface !== nothing) || begin; b=_g2sf_failed(:public_contract_mismatch); return G2SourceFactoryConstructionResultV1(b...); end
    _g2sf_axes_ok(version_axes) || begin; b=_g2sf_failed(:version_axes_mismatch); return G2SourceFactoryConstructionResultV1(b...); end
    frozen_context === nothing && !allow_legacy && begin; b=_g2sf_failed(:frozen_source_context_missing); return G2SourceFactoryConstructionResultV1(b...); end
    handle_error = _g2sf_validate_handle(locator.repository_root, common_binding_handle, frozen_context)
    handle_error === nothing || begin; b=_g2sf_failed(handle_error); return G2SourceFactoryConstructionResultV1(b...); end
    locator_error = _g2sf_validate_locator(locator, frozen_context)
    if locator_error !== nothing
        b = locator_error === :source_authority_missing || locator_error === :source_file_missing ? _g2sf_absent(locator_error) : _g2sf_failed(locator_error)
        return G2SourceFactoryConstructionResultV1(b...)
    end
    (declaration_constructor.constructor === g2mb_declaration_v1 || declaration_constructor.constructor === G2MBDeclarationV1) || begin; b=_g2sf_failed(:not_real_declaration_constructor); return G2SourceFactoryConstructionResultV1(b...); end
    source_payload.candidate_ref == contract_ref || begin; b=_g2sf_failed(:source_contract_ref_mismatch); return G2SourceFactoryConstructionResultV1(b...); end
    payload_hash = source_payload.source_hash
    declaration = try declaration_constructor.constructor(contract_ref, source_payload) catch; nothing end
    declaration isa G2MBDeclarationV1 || begin; b=_g2sf_failed(:constructor_rejected_input); return G2SourceFactoryConstructionResultV1(b...); end
    declaration_hash = g2mb_declaration_hash_v1(declaration)
    binding_body = (common_binding_handle=common_binding_handle,
        common_binding_envelope_sha256=G2_AD45_ENVELOPE_SHA256_V1, contract_ref=contract_ref,
        version_axes=version_axes, binding_role=:temporary_common_candidate_binding_handle_only,
        candidate_identity_created=false)
    binding = G2SourceContractBindingV1(common_binding_handle, G2_AD45_ENVELOPE_SHA256_V1, contract_ref, version_axes,
        :temporary_common_candidate_binding_handle_only, false, canonical_hash(binding_body))
    synthetic_test_only = locator.provenance === :isolated_test_fixture
    source_content_body = (factory_ref=G2_SOURCE_AUTHORITY_FACTORY_REF_V1,
        locator=locator, common_binding_handle=common_binding_handle, contract_ref=contract_ref,
        version_axes=version_axes, source_payload=source_payload, source_payload_hash=payload_hash,
        binding=binding, binding_hash=binding.binding_hash, declaration_hash=declaration_hash,
        synthetic_test_only=synthetic_test_only)
    if frozen_context isa NativeGitReadCompatibilityV1.FrozenSourceContextV1 ||
            frozen_context isa NativeGitReadCompatibilityV1.UP1FrozenSourceContextV1
        auth = NativeGitReadCompatibilityV1.frozen_source_identity(frozen_context)
        source_entry = NativeGitReadCompatibilityV1.frozen_source(frozen_context, locator.source_path)
        source_entry === nothing && throw(ArgumentError("verified frozen source input disappeared"))
        source_content_body = merge(source_content_body, (frozen_source_authority=merge(auth, (
            source_logical_path=source_entry.logical_path,
            source_manifest_key=source_entry.manifest_key,
            ad45_envelope_manifest_key=NativeGitReadCompatibilityV1.frozen_source_manifest_key(
                frozen_context, G2_AD45_ENVELOPE_RELATIVE_PATH_V1))),))
    end
    source_content_hash = canonical_hash(source_content_body)
    body = (public_contract_ref=contract_ref, common_binding_handle=common_binding_handle,
        version_axes=version_axes, locator=locator, source_payload=source_payload,
        declaration=declaration, binding=binding, source_content_hash=source_content_hash,
        local_declaration_hash=declaration_hash, synthetic_test_only=synthetic_test_only,
        candidate_identity_created=false, final_candidate_or_package_hash_created=false)
    source_decl = PresentG2SourceDeclarationV1(contract_ref, common_binding_handle, version_axes,
        locator, source_payload, declaration, binding, source_content_hash, declaration_hash,
        canonical_hash(body), synthetic_test_only, false, false)
    locator_digest = canonical_hash(locator)
    ibody = (factory_ref=G2_SOURCE_AUTHORITY_FACTORY_REF_V1, factory_version="v1", locator=locator,
        common_binding_handle=common_binding_handle, contract_ref=contract_ref, version_axes=version_axes,
        source_payload_hash=payload_hash, source_content_hash=source_content_hash,
        declaration_hash=declaration_hash, registry_not_used=true, candidate_identity_created=false,
        final_candidate_or_package_hash_created=false)
    identity = PresentG2SourceFactoryIdentityV1(G2_SOURCE_AUTHORITY_FACTORY_REF_V1, "v1", locator,
        common_binding_handle, contract_ref, version_axes, payload_hash, source_content_hash,
        declaration_hash, true, false, false, canonical_hash(ibody))
    rbody = (status=:present, factory_ref=G2_SOURCE_AUTHORITY_FACTORY_REF_V1, locator_digest=locator_digest,
        source_payload_hash=payload_hash, source_content_hash=source_content_hash,
        local_declaration_hash=declaration_hash, declaration_hash=source_decl.declaration_hash,
        common_binding_handle=common_binding_handle, contract_ref=contract_ref, version_axes=version_axes,
        output_source_declaration=source_decl, registry_not_used=true, trusted=false,
        candidate_identity_created=false, final_hash_created=false, replayable=true)
    receipt = PresentG2SourceConstructionReceiptV1(rbody..., canonical_hash(rbody))
    G2SourceFactoryConstructionResultV1(identity, source_decl, receipt)
end

g2_source_authority_factory_v1(locator, common_binding_handle, contract_ref, source_payload,
    version_axes, declaration_constructor, frozen_context::NativeGitReadCompatibilityV1.FrozenSourceContextV1) =
        _g2_source_authority_factory_core_v1(locator, common_binding_handle, contract_ref,
            source_payload, version_axes, declaration_constructor, frozen_context)

g2_source_authority_factory_v1(locator, common_binding_handle, contract_ref, source_payload,
    version_axes, declaration_constructor, frozen_context::NativeGitReadCompatibilityV1.UP1FrozenSourceContextV1) =
        _g2_source_authority_factory_core_v1(locator, common_binding_handle, contract_ref,
            source_payload, version_axes, declaration_constructor, frozen_context)

g2_source_authority_factory_v1(locator, common_binding_handle, contract_ref, source_payload,
    version_axes, declaration_constructor) =
        _g2_source_authority_factory_core_v1(locator, common_binding_handle, contract_ref,
            source_payload, version_axes, declaration_constructor, nothing)

g2_source_authority_factory_v1(locator, common_binding_handle, contract_ref, source_payload,
    version_axes, declaration_constructor, ::Nothing) =
        _g2_source_authority_factory_core_v1(locator, common_binding_handle, contract_ref,
            source_payload, version_axes, declaration_constructor, nothing)

function g2_source_authority_factory_legacy_v1(locator, common_binding_handle, contract_ref,
        source_payload, version_axes, declaration_constructor)
    NativeGitReadCompatibilityV1._guard_legacy_git_access("g2_source_authority_factory_legacy_v1")
    _g2_source_authority_factory_core_v1(locator, common_binding_handle, contract_ref,
        source_payload, version_axes, declaration_constructor, nothing; allow_legacy=true)
end

g2_source_authority_factory_v1(locator, handle, contract_ref, payload, axes, constructor,
    context::AbstractString) =
        _g2_source_authority_factory_core_v1(locator, handle, contract_ref, payload, axes, constructor, context)

g2_source_factory_result_status(x::G2SourceFactoryConstructionResultV1) =
    x.identity isa PresentG2SourceFactoryIdentityV1 ? :present :
    x.identity isa AbsentG2SourceFactoryIdentityV1 ? :typed_absent : :fail_closed
g2_source_factory_receipt(x::G2SourceFactoryConstructionResultV1) = x.receipt
g2_source_factory_declaration(x::G2SourceFactoryConstructionResultV1) = x.source_declaration
