"""Repository-local G3 source-authority factory boundary.

This is an additive, fail-closed source-stage binding factory.  It consumes an
independently observed source locator and an explicitly supplied AD45 common v5
handle, then creates a local, candidate-bound
G3 source content/declaration identity.  It does not create a final package
identity, CandidateIdentityV1, trusted attestation, registry entry, or physical
result.
"""

const G3_SOURCE_AUTHORITY_FACTORY_VERSION_V1 = "v1"
const G3_SOURCE_AUTHORITY_FACTORY_REF_V1 =
    QualifiedRefV1("fusionconceptai://GenomeV5/G3/source-authority-factory", "v1")
const G3_SOURCE_AUTHORITY_FACTORY_SCOPES_V1 = (:realization, :control, :binding, :bundle)
const G3_SOURCE_AUTHORITY_FACTORY_STATUS_V1 = (:present, :typed_absent, :fail_closed)
const G3_SOURCE_AUTHORITY_FACTORY_SOURCE_VERSION_V1 = "v1"
const G3_AD45_COMMON_BINDING_HANDLE_ID_V1 =
    "fusionconceptai://candidate-binding/AD45-FRESH-CANDIDATE-BINDING-ENVELOPE/3da169fa-2376-4b36-b794-ac5a32161aa7"
const G3_AD45_COMMON_BINDING_HANDLE_VERSION_V1 = "v5"
const G3_AD45_ENVELOPE_RELATIVE_PATH_V1 =
    "docs/implementation/AD-45/FRESH-CANDIDATE-BINDING-ENVELOPE/fresh_candidate_binding_envelope_v1.json"
const G3_AD45_ENVELOPE_SHA256_V1 =
    Digest256("17901aa6e1be326b95e56fbbbd5148bd02b7c3ea43bd0c451336cd297e2950dc")

abstract type AbstractG3FactoryIdentityV1 end
abstract type AbstractG3FactoryConstructionReceiptV1 end

"""Independent source observation supplied by AD48-S1 or an equivalent adapter."""
struct G3IndependentSourceLocatorV1
    scope::Symbol
    repository_root::String
    observed_head::String
    source_path::String
    source_bytes::Int
    source_sha256::Digest256
    head_path_status::Symbol
    working_tree_path_status::Symbol
    working_tree_status::Symbol
    head_blob_sha256::Union{Nothing,Digest256}
    function G3IndependentSourceLocatorV1(scope::Any, repository_root::Any,
            observed_head::Any, source_path::Any, source_bytes::Any,
            source_sha256::Any, head_path_status::Any,
            working_tree_path_status::Any, working_tree_status::Any)
        G3IndependentSourceLocatorV1(scope, repository_root, observed_head,
            source_path, source_bytes, source_sha256, head_path_status,
            working_tree_path_status, working_tree_status, nothing)
    end
    function G3IndependentSourceLocatorV1(scope::Any, repository_root::Any,
            observed_head::Any, source_path::Any, source_bytes::Any,
            source_sha256::Any, head_path_status::Any,
            working_tree_path_status::Any, working_tree_status::Any,
            head_blob_sha256::Any)
        s = _g3s_scope(scope)
        root = _g3s_text(repository_root, "repository_root")
        head = _g3s_text(observed_head, "observed_head")
        path = _g3s_relative_path(source_path)
        bytes = source_bytes isa Integer && !(source_bytes isa Bool) ? Int(source_bytes) :
            throw(ArgumentError("source_bytes must be an integer"))
        bytes >= 0 || throw(ArgumentError("source_bytes must be non-negative"))
        digest = source_sha256 isa Digest256 ? source_sha256 :
            throw(ArgumentError("source_sha256 must be Digest256"))
        head_digest = head_blob_sha256 === nothing ? nothing :
            (head_blob_sha256 isa Digest256 ? head_blob_sha256 :
             throw(ArgumentError("head_blob_sha256 must be Digest256 or nothing")))
        new(s, root, head, path, bytes, digest,
            _g3s_status(head_path_status, "head_path_status"),
            _g3s_status(working_tree_path_status, "working_tree_path_status"),
            _g3s_status(working_tree_status, "working_tree_status"), head_digest)
    end
end

struct PresentG3FactoryIdentityV1 <: AbstractG3FactoryIdentityV1
    scope::Symbol
    factory_ref::QualifiedRefV1
    factory_version::String
    function_name::String
    constructor_type::String
    argument_schema::Tuple
    locator::G3IndependentSourceLocatorV1
    common_binding_handle::QualifiedRefV1
    contract_ref::GenomeContractRef
    version_axes::G3VersionAxesV2
    source_bytes::Int
    source_sha256::Digest256
    registry_not_used::Bool
    candidate_identity_created::Bool
    g3_source_declaration_hash_created::Bool
    final_candidate_or_package_declaration_hash_created::Bool
    source_declaration_ref::QualifiedRefV1
    source_declaration_hash::Digest256
    factory_identity_digest::Digest256
end

struct AbsentG3FactoryIdentityV1 <: AbstractG3FactoryIdentityV1
    scope::Symbol
    reason::Symbol
    terminal_deferred::Bool
    candidate_identity_created::Bool
    g3_source_declaration_hash_created::Bool
    final_candidate_or_package_declaration_hash_created::Bool
end

struct FailedG3FactoryIdentityV1 <: AbstractG3FactoryIdentityV1
    scope::Symbol
    reason::Symbol
    fail_closed::Bool
    candidate_identity_created::Bool
    g3_source_declaration_hash_created::Bool
    final_candidate_or_package_declaration_hash_created::Bool
end

"""Source-stage binding for the AD45 temporary common handle.

This is deliberately distinct from `G3ContractBindingV2`: AD45 supplies a
temporary common join handle, not a final candidate-owned URI.  AD46 may later
materialize a real candidate binding after a CandidateIdentity exists.
"""
struct G3SourceContractBindingV1
    scope::Symbol
    common_binding_handle::QualifiedRefV1
    contract_ref::GenomeContractRef
    version_axes::G3VersionAxesV2
    binding_role::Symbol
    candidate_identity_created::Bool
    binding_digest::Digest256
end

struct G3CandidateBoundSourceContentV1
    scope::Symbol
    locator::G3IndependentSourceLocatorV1
    locator_digest::Digest256
    source_path::String
    source_bytes::Int
    source_sha256::Digest256
    source_content_digest::Digest256
    common_binding_handle::QualifiedRefV1
    common_binding_envelope_path::String
    common_binding_envelope_sha256::Digest256
    contract_ref::GenomeContractRef
    version_axes::G3VersionAxesV2
    binding::G3SourceContractBindingV1
    binding_digest::Digest256
    source_role::Symbol
    source_schema_ref::QualifiedRefV1
    source_version::String
end

abstract type AbstractG3CandidateBoundSourceDeclarationV1 end

struct G3CandidateBoundSourceDeclarationV1 <: AbstractG3CandidateBoundSourceDeclarationV1
    scope::Symbol
    declaration_ref::QualifiedRefV1
    content::G3CandidateBoundSourceContentV1
    source_declaration_hash::Digest256
    g3_source_declaration_hash_created::Bool
    final_candidate_or_package_declaration_hash_created::Bool
end

struct PresentG3FactoryConstructionReceiptV1 <: AbstractG3FactoryConstructionReceiptV1
    scope::Symbol
    status::Symbol
    locator_digest::Digest256
    source_module_path::String
    source_bytes::Int
    source_sha256::Digest256
    factory_ref::QualifiedRefV1
    factory_version::String
    function_name::String
    constructor_type::String
    argument_schema::Tuple
    locator_ref::Digest256
    common_binding_handle::QualifiedRefV1
    contract_ref::GenomeContractRef
    version_axes::G3VersionAxesV2
    constructed_binding_hash::Digest256
    source_content_digest::Digest256
    source_declaration_ref::QualifiedRefV1
    source_declaration_hash::Digest256
    output_source_declaration::G3CandidateBoundSourceDeclarationV1
    registry_not_used::Bool
    candidate_identity_created::Bool
    g3_source_declaration_hash_created::Bool
    final_candidate_or_package_declaration_hash_created::Bool
    trusted_attestation_created::Bool
    semantic_digest::Digest256
    construction_digest::Digest256
end

struct AbsentG3FactoryConstructionReceiptV1 <: AbstractG3FactoryConstructionReceiptV1
    scope::Symbol
    status::Symbol
    reason::Symbol
    terminal_deferred::Bool
    candidate_identity_created::Bool
    g3_source_declaration_hash_created::Bool
    final_candidate_or_package_declaration_hash_created::Bool
    trusted_attestation_created::Bool
end

struct FailedG3FactoryConstructionReceiptV1 <: AbstractG3FactoryConstructionReceiptV1
    scope::Symbol
    status::Symbol
    reason::Symbol
    fail_closed::Bool
    candidate_identity_created::Bool
    g3_source_declaration_hash_created::Bool
    final_candidate_or_package_declaration_hash_created::Bool
    trusted_attestation_created::Bool
end

struct G3FactoryConstructionResultV1
    identity::AbstractG3FactoryIdentityV1
    binding::Union{Nothing,G3SourceContractBindingV1}
    source_declaration::Union{Nothing,G3CandidateBoundSourceDeclarationV1}
    receipt::AbstractG3FactoryConstructionReceiptV1
end

function G3FactoryConstructionResultV1(identity::AbstractG3FactoryIdentityV1,
        receipt::AbstractG3FactoryConstructionReceiptV1)
    G3FactoryConstructionResultV1(identity, nothing, nothing, receipt)
end

semantic_view(x::G3IndependentSourceLocatorV1) =
    (scope=x.scope, repository_root=x.repository_root, observed_head=x.observed_head,
     source_path=x.source_path, source_bytes=x.source_bytes, source_sha256=x.source_sha256,
     head_path_status=x.head_path_status, working_tree_path_status=x.working_tree_path_status,
     working_tree_status=x.working_tree_status, head_blob_sha256=x.head_blob_sha256)
semantic_view(x::PresentG3FactoryIdentityV1) =
    (scope=x.scope, factory_ref=x.factory_ref, factory_version=x.factory_version,
     function_name=x.function_name, constructor_type=x.constructor_type,
     argument_schema=x.argument_schema, locator=x.locator,
     common_binding_handle=x.common_binding_handle, contract_ref=x.contract_ref,
     version_axes=x.version_axes, source_bytes=x.source_bytes,
     source_sha256=x.source_sha256, registry_not_used=x.registry_not_used,
     candidate_identity_created=x.candidate_identity_created,
     g3_source_declaration_hash_created=x.g3_source_declaration_hash_created,
     final_candidate_or_package_declaration_hash_created=x.final_candidate_or_package_declaration_hash_created,
     source_declaration_ref=x.source_declaration_ref,
     source_declaration_hash=x.source_declaration_hash,
     factory_identity_digest=x.factory_identity_digest)
semantic_view(x::AbsentG3FactoryIdentityV1) =
     (scope=x.scope, reason=x.reason, terminal_deferred=x.terminal_deferred,
     candidate_identity_created=x.candidate_identity_created,
     g3_source_declaration_hash_created=x.g3_source_declaration_hash_created,
     final_candidate_or_package_declaration_hash_created=x.final_candidate_or_package_declaration_hash_created)
semantic_view(x::FailedG3FactoryIdentityV1) =
     (scope=x.scope, reason=x.reason, fail_closed=x.fail_closed,
     candidate_identity_created=x.candidate_identity_created,
     g3_source_declaration_hash_created=x.g3_source_declaration_hash_created,
     final_candidate_or_package_declaration_hash_created=x.final_candidate_or_package_declaration_hash_created)
semantic_view(x::G3SourceContractBindingV1) =
    (scope=x.scope, common_binding_handle=x.common_binding_handle,
     contract_ref=x.contract_ref, version_axes=x.version_axes,
     binding_role=x.binding_role,
     candidate_identity_created=x.candidate_identity_created)
semantic_view(x::G3CandidateBoundSourceContentV1) =
    (scope=x.scope, locator=x.locator, locator_digest=x.locator_digest,
     source_path=x.source_path, source_bytes=x.source_bytes, source_sha256=x.source_sha256,
     common_binding_handle=x.common_binding_handle,
     common_binding_envelope_path=x.common_binding_envelope_path,
     common_binding_envelope_sha256=x.common_binding_envelope_sha256,
     contract_ref=x.contract_ref,
     version_axes=x.version_axes, binding=x.binding, binding_digest=x.binding_digest,
     source_role=x.source_role, source_schema_ref=x.source_schema_ref,
     source_version=x.source_version)
semantic_view(x::G3CandidateBoundSourceDeclarationV1) =
    (scope=x.scope, declaration_ref=x.declaration_ref, content=x.content,
     g3_source_declaration_hash_created=x.g3_source_declaration_hash_created,
     final_candidate_or_package_declaration_hash_created=x.final_candidate_or_package_declaration_hash_created)
semantic_view(x::PresentG3FactoryConstructionReceiptV1) =
    (scope=x.scope, status=x.status, locator_digest=x.locator_digest,
     source_module_path=x.source_module_path, source_bytes=x.source_bytes,
     source_sha256=x.source_sha256, factory_ref=x.factory_ref,
     factory_version=x.factory_version, function_name=x.function_name,
     constructor_type=x.constructor_type, argument_schema=x.argument_schema,
     locator_ref=x.locator_ref, common_binding_handle=x.common_binding_handle,
     contract_ref=x.contract_ref, version_axes=x.version_axes,
     constructed_binding_hash=x.constructed_binding_hash,
     source_content_digest=x.source_content_digest,
     source_declaration_ref=x.source_declaration_ref,
     source_declaration_hash=x.source_declaration_hash,
     output_source_declaration=x.output_source_declaration,
     registry_not_used=x.registry_not_used,
     candidate_identity_created=x.candidate_identity_created,
     g3_source_declaration_hash_created=x.g3_source_declaration_hash_created,
     final_candidate_or_package_declaration_hash_created=x.final_candidate_or_package_declaration_hash_created,
     trusted_attestation_created=x.trusted_attestation_created,
     semantic_digest=x.semantic_digest, construction_digest=x.construction_digest)
semantic_view(x::AbsentG3FactoryConstructionReceiptV1) =
    (scope=x.scope, status=x.status, reason=x.reason,
     terminal_deferred=x.terminal_deferred,
     candidate_identity_created=x.candidate_identity_created,
     g3_source_declaration_hash_created=x.g3_source_declaration_hash_created,
     final_candidate_or_package_declaration_hash_created=x.final_candidate_or_package_declaration_hash_created,
     trusted_attestation_created=x.trusted_attestation_created)
semantic_view(x::FailedG3FactoryConstructionReceiptV1) =
     (scope=x.scope, status=x.status, reason=x.reason, fail_closed=x.fail_closed,
     candidate_identity_created=x.candidate_identity_created,
     g3_source_declaration_hash_created=x.g3_source_declaration_hash_created,
     final_candidate_or_package_declaration_hash_created=x.final_candidate_or_package_declaration_hash_created,
     trusted_attestation_created=x.trusted_attestation_created)
semantic_view(x::G3FactoryConstructionResultV1) =
    (identity=x.identity, binding=x.binding, source_declaration=x.source_declaration,
     receipt=x.receipt)

_g3s_text(x, field) = x isa AbstractString && !isempty(String(x)) && isvalid(String(x)) ?
    String(x) : throw(ArgumentError("$field must be non-empty UTF-8"))

function _g3s_scope(x)
    s = x isa Symbol ? x : x isa AbstractString ? Symbol(x) :
        throw(ArgumentError("scope must be Symbol or String"))
    s in G3_SOURCE_AUTHORITY_FACTORY_SCOPES_V1 ||
        throw(ArgumentError("unknown G3 source-authority scope: $s"))
    s
end

function _g3s_status(x, field)
    s = x isa Symbol ? x : x isa AbstractString ? Symbol(x) :
        throw(ArgumentError("$field must be Symbol or String"))
    s in (:present, :absent_untracked, :untracked, :tracked, :dirty, :clean, :missing) ||
        throw(ArgumentError("invalid $field: $s"))
    s
end

function _g3s_relative_path(x)
    path = _g3s_text(x, "source_path")
    isabspath(path) && throw(ArgumentError("source_path must be repository-relative"))
    parts = split(replace(path, '\\' => '/'), '/')
    any(p -> isempty(p) || p == "." || p == "..", parts) &&
        throw(ArgumentError("source_path must be a normalized relative path"))
    replace(path, '\\' => '/')
end

function _g3s_expected_source(scope::Symbol)
    Dict(
        :realization => "src/GenomeV5/G3/RealizationGenomeV5.jl",
        :control => "src/GenomeV5/G3/ControlGenomeV5.jl",
        :binding => "src/GenomeV5/G3/CoupledRealizationControlBindingV2.jl",
        :bundle => "src/GenomeV5/G3/RealizationControlGenomeV5.jl",
    )[scope]
end

function _g3s_source_role(scope::Symbol)
    Dict(:realization => :realization_source, :control => :control_source,
        :binding => :binding_source, :bundle => :bundle_source)[scope]
end

function _g3s_source_schema_ref(scope::Symbol)
    QualifiedRefV1("fusionconceptai://GenomeV5/G3/" * String(scope) * "/source-schema", "v1")
end

function _g3s_declaration_ref(x, scope::Symbol)
    x isa QualifiedRefV1 || return :source_declaration_ref_type_mismatch
    x.version == G3_SOURCE_AUTHORITY_FACTORY_SOURCE_VERSION_V1 ||
        return :source_declaration_ref_version_mismatch
    expected_prefix = "fusionconceptai://GenomeV5/G3/" * String(scope) * "/source-declaration/"
    startswith(x.id, expected_prefix) || return :source_declaration_ref_scope_mismatch
    nothing
end

_g3s_ref_equal(a::QualifiedRefV1, b::QualifiedRefV1) = a.id == b.id && a.version == b.version

function _g3s_validate_common_binding_handle(repository_root::String,
        handle::QualifiedRefV1)
    handle.version == G3_AD45_COMMON_BINDING_HANDLE_VERSION_V1 ||
        return :common_handle_version_mismatch
    handle.id == G3_AD45_COMMON_BINDING_HANDLE_ID_V1 ||
        return :foreign_common_handle
    try
        path = joinpath(repository_root, split(G3_AD45_ENVELOPE_RELATIVE_PATH_V1, '/')...)
        isfile(path) || return :ad45_envelope_missing
        bytes = read(path)
        Digest256(bytes2hex(SHA.sha256(bytes))) == G3_AD45_ENVELOPE_SHA256_V1 ||
            return :ad45_envelope_hash_mismatch
        nothing
    catch
        :ad45_envelope_read_failed
    end
end

function _g3s_absent(scope::Symbol, reason::Symbol)
    AbsentG3FactoryIdentityV1(scope, reason, true, false, false, false),
    AbsentG3FactoryConstructionReceiptV1(scope, :typed_absent, reason, true, false, false, false, false)
end

function _g3s_failed(scope::Symbol, reason::Symbol)
    FailedG3FactoryIdentityV1(scope, reason, true, false, false, false),
    FailedG3FactoryConstructionReceiptV1(scope, :fail_closed, reason, true, false, false, false, false)
end

function _g3s_locator_digest(locator::G3IndependentSourceLocatorV1)
    canonical_hash((scope=locator.scope, repository_root=locator.repository_root,
        observed_head=locator.observed_head, source_path=locator.source_path,
        source_bytes=locator.source_bytes, source_sha256=locator.source_sha256,
        head_path_status=locator.head_path_status,
        working_tree_path_status=locator.working_tree_path_status,
        working_tree_status=locator.working_tree_status,
        head_blob_sha256=locator.head_blob_sha256))
end

function _g3s_git_read(root::String, args...)
    try
        parts = String["git", "-C", root]
        append!(parts, String.(args))
        String(readchomp(Cmd(parts)))
    catch
        nothing
    end
end

function _g3s_git_bytes(root::String, args...)
    try
        parts = String["git", "-C", root]
        append!(parts, String.(args))
        read(Cmd(parts))
    catch
        nothing
    end
end

function _g3s_validate_git(locator::G3IndependentSourceLocatorV1)
    root = try realpath(locator.repository_root) catch; return :repository_root_invalid end
    git_top = _g3s_git_read(locator.repository_root, "rev-parse", "--show-toplevel")
    git_top isa String && !isempty(strip(git_top)) || return :repository_root_not_git
    try realpath(git_top) == root || return :repository_root_mismatch
    catch
        return :repository_root_mismatch
    end

    head = _g3s_git_read(locator.repository_root, "rev-parse", "HEAD")
    head isa String && occursin(r"^[0-9a-f]{40}$", head) || return :head_probe_failed
    head == locator.observed_head || return :locator_head_mismatch

    tree_path = _g3s_git_read(locator.repository_root, "ls-tree", "-r", "--name-only",
        "HEAD", "--", locator.source_path)
    tree_path isa String || return :head_tree_probe_failed
    tree_lines = isempty(tree_path) ? String[] : split(tree_path, '\n'; keepempty=false)

    # The index entry must be a single, stage-zero tracked path.  In
    # particular, do not infer tracking from a clean porcelain result.
    tracked = _g3s_git_read(locator.repository_root, "ls-files", "--stage", "--",
        locator.source_path)
    tracked isa String || return :tracked_path_probe_failed
    tracked_lines = isempty(tracked) ? String[] : split(tracked, '\n'; keepempty=false)

    # ls-files -v exposes index flags hidden by porcelain.  Lower-case h/s
    # denote assume-unchanged/skip-worktree and must never be authoritative.
    verbose = _g3s_git_read(locator.repository_root, "ls-files", "-v", "--",
        locator.source_path)
    verbose isa String || return :index_flags_probe_failed
    verbose_lines = isempty(verbose) ? String[] : split(verbose, '\n'; keepempty=false)

    porcelain = _g3s_git_read(locator.repository_root, "status", "--porcelain=v1",
        "--untracked-files=all", "--", locator.source_path)
    porcelain isa String || return :source_status_probe_failed
    actual_status = isempty(porcelain) ? :clean : startswith(porcelain, "??") ? :untracked : :dirty
    actual_work_path = actual_status === :clean ? :present : :absent_untracked
    actual_work_path == locator.working_tree_path_status ||
        return :working_tree_path_status_mismatch
    actual_status == locator.working_tree_status || return :working_tree_status_mismatch

    # An absent HEAD path is a typed, terminal absence.  Validate the absence
    # evidence and never let the working-tree snapshot become Present.
    if isempty(tree_lines)
        isempty(tracked_lines) || return :tracked_path_mismatch
        isempty(verbose_lines) || return :index_flags_malformed
        locator.head_path_status == :absent_untracked || return :head_path_status_mismatch
        locator.head_blob_sha256 === nothing || return :head_blob_sha256_mismatch
        actual_status === :untracked || return :source_authority_missing
        return :source_authority_missing
    end

    length(tree_lines) == 1 && tree_lines[1] == locator.source_path ||
        return :head_path_missing
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
    debug_index = _g3s_git_read(locator.repository_root, "ls-files", "--debug", "--",
        locator.source_path)
    debug_index isa String || return :index_flags_probe_failed
    debug_match = match(r"flags:\s*([0-9a-fA-F]+)", debug_index)
    debug_match === nothing && return :index_flags_malformed
    index_flags = try parse(UInt32, debug_match.captures[1]; base=16) catch; return :index_flags_malformed end
    index_flags & UInt32(0x8000) != 0 && return :index_assume_unchanged
    index_flags & UInt32(0x4000) != 0 && return :index_skip_worktree
    index_flags == 0 || return :index_flags_malformed

    blob = _g3s_git_read(locator.repository_root, "rev-parse", "HEAD:" * locator.source_path)
    blob isa String && occursin(r"^[0-9a-f]{40}$", blob) || return :head_blob_probe_failed
    head_bytes = _g3s_git_bytes(locator.repository_root, "show", "HEAD:" * locator.source_path)
    cat_bytes = _g3s_git_bytes(locator.repository_root, "cat-file", "blob", blob)
    head_bytes isa Vector{UInt8} && cat_bytes isa Vector{UInt8} || return :head_blob_read_failed
    head_bytes == cat_bytes || return :head_blob_bytes_mismatch
    working_path = joinpath(locator.repository_root, split(locator.source_path, '/')...)
    isfile(working_path) || return :source_file_missing
    try read(working_path) catch; return :source_read_failed end
    length(head_bytes) == locator.source_bytes || return :head_blob_bytes_mismatch
    head_sha = Digest256(bytes2hex(SHA.sha256(head_bytes)))
    head_sha == locator.source_sha256 == locator.head_blob_sha256 || return :head_blob_sha256_mismatch
    filtered_blob = _g3s_git_read(locator.repository_root, "hash-object", "--path",
        locator.source_path, working_path)
    filtered_blob isa String && filtered_blob == blob ||
        return :working_tree_filtered_blob_mismatch

    isempty(porcelain) || return :working_tree_dirty
    actual_status === :clean || return :working_tree_dirty
    nothing
end

function _g3s_validate_locator(scope::Symbol, locator::G3IndependentSourceLocatorV1)
    locator.scope == scope || return :scope_mismatch
    locator.source_path == _g3s_expected_source(scope) || return :source_path_mismatch
    try
        path = joinpath(locator.repository_root, split(locator.source_path, '/')...)
        isfile(path) || return :source_file_missing
        try read(path) catch; return :source_read_failed end
        git_error = _g3s_validate_git(locator)
        git_error === nothing || return git_error
        nothing
    catch
        :source_read_failed
    end
end

function _g3s_binding(scope::Symbol, handle::QualifiedRefV1,
        contract_ref::GenomeContractRef, axes::G3VersionAxesV2)
    role = :temporary_common_candidate_binding_handle_only
    body = (scope=scope, common_binding_handle=handle, contract_ref=contract_ref,
        version_axes=axes, binding_role=role, candidate_identity_created=false)
    G3SourceContractBindingV1(scope, handle, contract_ref, axes, role, false,
        canonical_hash(body))
end

function _g3s_content_body(scope::Symbol, locator::G3IndependentSourceLocatorV1,
        locator_digest::Digest256, handle::QualifiedRefV1, contract_ref::GenomeContractRef,
        axes::G3VersionAxesV2, binding::G3SourceContractBindingV1,
        binding_digest::Digest256, source_role::Symbol,
        source_schema_ref::QualifiedRefV1, source_version::String)
    (scope=scope, locator=locator, locator_digest=locator_digest,
     source_path=locator.source_path, source_bytes=locator.source_bytes,
     source_sha256=locator.source_sha256, common_binding_handle=handle,
     common_binding_envelope_path=G3_AD45_ENVELOPE_RELATIVE_PATH_V1,
     common_binding_envelope_sha256=G3_AD45_ENVELOPE_SHA256_V1,
     contract_ref=contract_ref, version_axes=axes, binding=binding,
     binding_digest=binding_digest, source_role=source_role,
     source_schema_ref=source_schema_ref, source_version=source_version)
end

function _g3s_make_content(scope::Symbol, locator::G3IndependentSourceLocatorV1,
        handle::QualifiedRefV1, contract_ref::GenomeContractRef,
        axes::G3VersionAxesV2, binding::G3SourceContractBindingV1)
    locator_digest = _g3s_locator_digest(locator)
    source_role = _g3s_source_role(scope)
    source_schema_ref = _g3s_source_schema_ref(scope)
    binding_digest = binding.binding_digest
    body = _g3s_content_body(scope, locator, locator_digest, handle, contract_ref,
        axes, binding, binding_digest, source_role, source_schema_ref,
        G3_SOURCE_AUTHORITY_FACTORY_SOURCE_VERSION_V1)
    digest = canonical_hash(body)
    G3CandidateBoundSourceContentV1(scope, locator, locator_digest,
        locator.source_path, locator.source_bytes, locator.source_sha256, digest,
        handle, G3_AD45_ENVELOPE_RELATIVE_PATH_V1, G3_AD45_ENVELOPE_SHA256_V1,
        contract_ref, axes, binding, binding_digest, source_role,
        source_schema_ref, G3_SOURCE_AUTHORITY_FACTORY_SOURCE_VERSION_V1)
end

function _g3s_make_declaration(scope::Symbol, declaration_ref::QualifiedRefV1,
        content::G3CandidateBoundSourceContentV1)
    body = (scope=scope, declaration_ref=declaration_ref, content=content,
        g3_source_declaration_hash_created=true,
        final_candidate_or_package_declaration_hash_created=false)
    hash = canonical_hash(body)
    G3CandidateBoundSourceDeclarationV1(scope, declaration_ref, content, hash, true, false)
end

"""Construct a deterministic local factory result for one G3 scope.

`nothing` or a missing typed input is `Absent...`; a typed mismatch, stale
locator, or foreign contract is `Failed...`.  The operation has no global
state and therefore has no partial publication path.
"""
function g3_source_authority_factory_v1(scope::Any, locator::Any,
        common_binding_handle::Any, contract_ref::Any, version_axes::Any,
        source_declaration_ref::Any=nothing)
    parsed_scope = try _g3s_scope(scope) catch; return G3FactoryConstructionResultV1(
        _g3s_failed(:invalid, :invalid_scope)...); end
    locator === nothing && return G3FactoryConstructionResultV1(_g3s_absent(parsed_scope, :locator_missing)...)
    common_binding_handle === nothing && return G3FactoryConstructionResultV1(_g3s_absent(parsed_scope, :common_handle_missing)...)
    contract_ref === nothing && return G3FactoryConstructionResultV1(_g3s_absent(parsed_scope, :contract_ref_missing)...)
    version_axes === nothing && return G3FactoryConstructionResultV1(_g3s_absent(parsed_scope, :version_axes_missing)...)
    source_declaration_ref === nothing && return G3FactoryConstructionResultV1(_g3s_absent(parsed_scope, :source_declaration_ref_missing)...)
    locator isa G3IndependentSourceLocatorV1 || return G3FactoryConstructionResultV1(_g3s_failed(parsed_scope, :locator_type_mismatch)...)
    common_binding_handle isa QualifiedRefV1 || return G3FactoryConstructionResultV1(_g3s_failed(parsed_scope, :common_handle_type_mismatch)...)
    contract_ref isa GenomeContractRef || return G3FactoryConstructionResultV1(_g3s_failed(parsed_scope, :contract_ref_type_mismatch)...)
    version_axes isa G3VersionAxesV2 || return G3FactoryConstructionResultV1(_g3s_failed(parsed_scope, :version_axes_type_mismatch)...)
    declaration_ref_error = _g3s_declaration_ref(source_declaration_ref, parsed_scope)
    declaration_ref_error === nothing || return G3FactoryConstructionResultV1(_g3s_failed(parsed_scope, declaration_ref_error)...)
    handle_error = _g3s_validate_common_binding_handle(locator.repository_root,
        common_binding_handle)
    handle_error === nothing || return G3FactoryConstructionResultV1(_g3s_failed(parsed_scope, handle_error)...)
    locator_error = _g3s_validate_locator(parsed_scope, locator)
    if locator_error !== nothing
        classified = locator_error in (:source_file_missing, :source_authority_missing) ?
            _g3s_absent(parsed_scope, locator_error) : _g3s_failed(parsed_scope, locator_error)
        return G3FactoryConstructionResultV1(classified...)
    end
    contract_ref == g3_contract_ref(parsed_scope) || return G3FactoryConstructionResultV1(_g3s_failed(parsed_scope, :contract_ref_mismatch)...)
    canonical_hash(version_axes) == canonical_hash(g3_version_axes(parsed_scope)) ||
        return G3FactoryConstructionResultV1(_g3s_failed(parsed_scope, :version_axes_mismatch)...)
    binding = try
        _g3s_binding(parsed_scope, common_binding_handle, contract_ref, version_axes)
    catch
        return G3FactoryConstructionResultV1(_g3s_failed(parsed_scope, :constructor_rejected_input)...)
    end
    function_name = "g3_source_authority_factory_v1_" * String(parsed_scope)
    argument_schema = (:scope, :independent_source_locator_v1, :common_binding_handle_v5,
        :g3_contract_ref, :g3_version_axes_v2, :source_declaration_ref_v1)
    locator_digest = _g3s_locator_digest(locator)
    content = _g3s_make_content(parsed_scope, locator, common_binding_handle,
        contract_ref, version_axes, binding)
    declaration = _g3s_make_declaration(parsed_scope, source_declaration_ref, content)
    semantic_digest = canonical_hash((scope=parsed_scope, factory_ref=G3_SOURCE_AUTHORITY_FACTORY_REF_V1,
        factory_version=G3_SOURCE_AUTHORITY_FACTORY_VERSION_V1, function_name=function_name,
        constructor_type="G3SourceContractBindingV1+G3CandidateBoundSourceDeclarationV1",
        argument_schema=argument_schema,
        locator_digest=locator_digest, source_path=locator.source_path,
        source_bytes=locator.source_bytes, source_sha256=locator.source_sha256,
        common_binding_handle=common_binding_handle, contract_ref=contract_ref,
        version_axes=version_axes, constructed_binding_hash=binding.binding_digest,
        source_content_digest=content.source_content_digest,
        source_declaration_ref=declaration.declaration_ref,
        source_declaration_hash=declaration.source_declaration_hash))
    identity = PresentG3FactoryIdentityV1(parsed_scope, G3_SOURCE_AUTHORITY_FACTORY_REF_V1,
        G3_SOURCE_AUTHORITY_FACTORY_VERSION_V1, function_name,
        "G3SourceContractBindingV1+G3CandidateBoundSourceDeclarationV1",
        argument_schema, locator, common_binding_handle, contract_ref, version_axes,
        locator.source_bytes, locator.source_sha256, true, false, true, false,
        declaration.declaration_ref, declaration.source_declaration_hash, semantic_digest)
    receipt_body = (scope=parsed_scope, status=:present, locator_digest=locator_digest,
        source_module_path=locator.source_path, source_bytes=locator.source_bytes,
        source_sha256=locator.source_sha256, factory_ref=G3_SOURCE_AUTHORITY_FACTORY_REF_V1,
        factory_version=G3_SOURCE_AUTHORITY_FACTORY_VERSION_V1, function_name=function_name,
        constructor_type="G3SourceContractBindingV1+G3CandidateBoundSourceDeclarationV1",
        argument_schema=argument_schema,
        locator_ref=locator_digest, common_binding_handle=common_binding_handle,
        contract_ref=contract_ref, version_axes=version_axes,
        constructed_binding_hash=binding.binding_digest,
        source_content_digest=content.source_content_digest,
        source_declaration_ref=declaration.declaration_ref,
        source_declaration_hash=declaration.source_declaration_hash,
        output_source_declaration=declaration, registry_not_used=true,
        candidate_identity_created=false, g3_source_declaration_hash_created=true,
        final_candidate_or_package_declaration_hash_created=false,
        trusted_attestation_created=false, semantic_digest=semantic_digest)
    receipt = PresentG3FactoryConstructionReceiptV1(receipt_body..., canonical_hash(receipt_body))
    G3FactoryConstructionResultV1(identity, binding, declaration, receipt)
end

g3_realization_source_authority_factory_v1(locator, handle, contract_ref, axes, declaration_ref) =
    g3_source_authority_factory_v1(:realization, locator, handle, contract_ref, axes, declaration_ref)
g3_control_source_authority_factory_v1(locator, handle, contract_ref, axes, declaration_ref) =
    g3_source_authority_factory_v1(:control, locator, handle, contract_ref, axes, declaration_ref)
g3_binding_source_authority_factory_v1(locator, handle, contract_ref, axes, declaration_ref) =
    g3_source_authority_factory_v1(:binding, locator, handle, contract_ref, axes, declaration_ref)
g3_bundle_source_authority_factory_v1(locator, handle, contract_ref, axes, declaration_ref) =
    g3_source_authority_factory_v1(:bundle, locator, handle, contract_ref, axes, declaration_ref)

g3_factory_identity_v1(result::G3FactoryConstructionResultV1) = result.identity
g3_factory_construction_receipt_v1(result::G3FactoryConstructionResultV1) = result.receipt
g3_factory_result_status(result::G3FactoryConstructionResultV1) =
    result.identity isa PresentG3FactoryIdentityV1 ? :present :
    result.identity isa AbsentG3FactoryIdentityV1 ? :typed_absent : :fail_closed
