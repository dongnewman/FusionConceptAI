"""Additive v5 candidate package and explicit legacy migration receipts.

This file deliberately does not include any GenomeV5 component implementation.  The
shared package can therefore be loaded by ``using FusionConceptAI`` while each layer
keeps ownership of its own concrete genome type.  Integration records the projected
identity of those objects; the objects themselves remain available on the package for
the next stage.
"""

struct GenomeV5MigrationRecord
    legacy_ref::String
    new_ref::Union{Nothing,GenomeContractRef}
    lossless::Bool
    disposition::Symbol
    reason::String
    before_hash::Union{Nothing,Digest256}
    after_hash::Union{Nothing,Digest256}
    before_axes::Any
    after_axes::Any
    field_mapping::Tuple{Vararg{String}}
    mapping_algorithm::String
    provenance::String
    function GenomeV5MigrationRecord(legacy_ref::AbstractString,
                                     new_ref::Union{Nothing,GenomeContractRef},
                                     lossless::Bool, disposition::Symbol,
                                     reason::AbstractString,
                                     before_hash::Union{Nothing,Digest256},
                                     after_hash::Union{Nothing,Digest256},
                                     before_axes, after_axes,
                                     field_mapping::Tuple{Vararg{String}}, mapping_algorithm::AbstractString,
                                     provenance::AbstractString)
        !isempty(String(legacy_ref)) || throw(ArgumentError("legacy_ref cannot be empty"))
        disposition in (:migrated, :terminal_deferred, :not_migrated) ||
            throw(ArgumentError("unsupported migration disposition"))
        (!lossless && disposition != :migrated) ||
            throw(ArgumentError("UP1-04A does not authorize lossless or migrated records"))
        !isempty(String(reason)) || throw(ArgumentError("migration reason cannot be empty"))
        !isempty(String(mapping_algorithm)) || throw(ArgumentError("migration algorithm cannot be empty"))
        !isempty(String(provenance)) || throw(ArgumentError("migration provenance cannot be empty"))
        !lossless && disposition != :migrated ||
            throw(ArgumentError("only deferred/non-migrated records are constructible in UP1-04A"))
        new(invoke(String, Tuple{AbstractString}, legacy_ref), new_ref, lossless,
            disposition, invoke(String, Tuple{AbstractString}, reason), before_hash, after_hash,
            before_axes, after_axes, field_mapping, invoke(String, Tuple{AbstractString}, mapping_algorithm),
            invoke(String, Tuple{AbstractString}, provenance))
    end
end

function GenomeV5MigrationRecord(legacy_ref::AbstractString,
                                 new_ref::Union{Nothing,GenomeContractRef},
                                 lossless::Bool, disposition::Symbol,
                                 reason::AbstractString;
                                 before_hash=nothing, after_hash=nothing,
                                 before_axes=nothing, after_axes=nothing,
                                 field_mapping=(), mapping_algorithm="none",
                                 provenance="UP1-04A explicit mapping input")
    before = before_hash === nothing ? nothing : before_hash isa Digest256 ? before_hash : Digest256(String(before_hash))
    after = after_hash === nothing ? nothing : after_hash isa Digest256 ? after_hash : Digest256(String(after_hash))
    fields = Tuple(String(x) for x in field_mapping)
    GenomeV5MigrationRecord(legacy_ref, new_ref, lossless, disposition, reason,
                            before, after, before_axes, after_axes, fields, mapping_algorithm, provenance)
end

semantic_view(x::GenomeV5MigrationRecord) = (
    legacy_ref=x.legacy_ref, new_ref=x.new_ref, lossless=x.lossless,
    disposition=x.disposition, reason=x.reason, before_hash=x.before_hash,
    after_hash=x.after_hash, before_axes=x.before_axes, after_axes=x.after_axes,
    field_mapping=x.field_mapping, mapping_algorithm=x.mapping_algorithm,
    provenance=x.provenance)

struct GenomeV5MigrationReceipt
    receipt_id::QualifiedRefV1
    candidate_ref::QualifiedRefV1
    records::Tuple{Vararg{GenomeV5MigrationRecord}}
    status::Symbol
    candidate_identity_before::Union{Nothing,String}
    candidate_identity_after::String
    scope::String
    function GenomeV5MigrationReceipt(receipt_id::QualifiedRefV1,
                                      candidate_ref::QualifiedRefV1,
                                      records::Tuple{Vararg{GenomeV5MigrationRecord}},
                                      status::Symbol,
                                      candidate_identity_before,
                                      candidate_identity_after::AbstractString,
                                      scope::AbstractString)
        status in (:terminal_deferred, :pending) ||
            throw(ArgumentError("unsupported migration receipt status"))
        status == :terminal_deferred && isempty(records) &&
            throw(ArgumentError("terminal_deferred migration receipt requires a source record"))
        after = String(candidate_identity_after)
        !isempty(after) || throw(ArgumentError("candidate_identity_after cannot be empty"))
        !isempty(String(scope)) || throw(ArgumentError("migration scope cannot be empty"))
        before = candidate_identity_before === nothing ? nothing : String(candidate_identity_before)
        new(receipt_id, candidate_ref, records, status, before, after, String(scope))
    end
end

"""Candidate-specific wrapper for a reusable G2 plan.

The plan body may be reused, but this typed binding is rebuilt for every
candidate and carries the actual G2 component hash consumed by the package.
"""
struct G2CandidateBindingV5
    candidate_ref::QualifiedRefV1
    genome_hash::Digest256
    function G2CandidateBindingV5(candidate_ref::QualifiedRefV1, genome_hash::Digest256)
        candidate_ref.version == "v5" ||
            throw(ArgumentError("G2 candidate binding requires a v5 candidate ref"))
        new(candidate_ref, genome_hash)
    end
end

semantic_view(x::G2CandidateBindingV5) =
    (candidate_ref=x.candidate_ref, genome_hash=x.genome_hash)

function v5_fresh_migration_receipt(candidate_ref::QualifiedRefV1;
                                    receipt_id=QualifiedRefV1(
                                        "fusionconceptai://migration/UP1-04A", "v1"))
    GenomeV5MigrationReceipt(receipt_id, candidate_ref, (), :pending, nothing,
                             candidate_ref.id, "no_legacy_mapping_requested")
end

semantic_view(x::GenomeV5MigrationReceipt) = (
    receipt_id=x.receipt_id, candidate_ref=x.candidate_ref, records=x.records,
    status=x.status, candidate_identity_before=x.candidate_identity_before,
    candidate_identity_after=x.candidate_identity_after, scope=x.scope)

"""Build a receipt which preserves an old reference without guessing a v5 mapping."""
function v5_deferred_migration_receipt(candidate_ref::QualifiedRefV1;
                                        legacy_refs=(),
                                        receipt_id=QualifiedRefV1(
                                            "fusionconceptai://migration/UP1-04A", "v1"),
                                        reason="no lossless field-semantic mapping was supplied")
    all(ref isa GenomeContractRef for ref in legacy_refs) ||
        throw(ArgumentError("legacy_refs must be actual GenomeContractRef values; placeholders are rejected"))
    !isempty(legacy_refs) ||
        throw(ArgumentError("legacy_refs must contain an actual V4 source ref"))
    for ref in legacy_refs
        any(startswith(ref.uri, prefix) for prefix in ("placeholder://", "pending://", "synthetic://")) &&
            throw(ArgumentError("legacy source ref URI is a placeholder or synthetic value"))
        startswith(ref.version, "v4") ||
            throw(ArgumentError("legacy migration source ref must carry a v4 version token"))
        zero = Digest256(repeat("0", 64))
        (ref.schema_hash == zero || ref.canonicalization_hash == zero) &&
            throw(ArgumentError("legacy source ref has a placeholder digest"))
    end
    records = Tuple(GenomeV5MigrationRecord(ref.uri, nothing, false,
                                             :terminal_deferred, reason;
                                             before_hash=canonical_hash(ref),
                                             before_axes=nothing,
                                             mapping_algorithm="none_available",
                                             provenance="unverified typed V4 source ref; no source receipt or lossless V4-to-V5 algorithm")
                    for ref in legacy_refs)
    GenomeV5MigrationReceipt(receipt_id, candidate_ref, records, :terminal_deferred,
                             isempty(records) ? nothing : join((r.legacy_ref for r in records), ","),
                             candidate_ref.id, "explicit_v4_to_v5_mapping")
end

struct CandidateStatePackageV5{G1T,G2T,G3T}
    candidate_ref::QualifiedRefV1
    g1::G1T
    g2::G2T
    g2_binding::G2CandidateBindingV5
    g3::G3T
    version_axes::NamedTuple
    migration_receipt::GenomeV5MigrationReceipt
    component_identity::NamedTuple
    structural_status::Symbol
    resolution::ResolutionStatus
    errors::Tuple{Vararg{String}}
    gaps::Tuple{Vararg{String}}
    candidate_hash::Digest256
    claim_ceiling::ClaimCeiling
    function CandidateStatePackageV5(candidate_ref::QualifiedRefV1, g1, g2,
                                      g2_binding::G2CandidateBindingV5, g3,
                                      version_axes::NamedTuple,
                                      migration_receipt::GenomeV5MigrationReceipt,
                                      component_identity::NamedTuple,
                                      structural_status::Symbol,
                                      resolution::ResolutionStatus,
                                      errors::Tuple{Vararg{String}},
                                      gaps::Tuple{Vararg{String}},
                                      claim_ceiling::ClaimCeiling)
        candidate_ref.version == "v5" ||
            throw(ArgumentError("CandidateStatePackageV5 requires candidate ref version v5"))
        structural_status in (:valid, :fail_closed) ||
            throw(ArgumentError("invalid v5 structural status"))
        resolution == terminal_deferred ||
            throw(ArgumentError("UP1-04A package cannot claim resolution=resolved"))
        claim_ceiling == none ||
            throw(ArgumentError("UP1-04A package claim_ceiling must remain none"))
        structural_status == :fail_closed && isempty(errors) &&
            throw(ArgumentError("fail_closed package requires structural errors"))
        structural_status == :valid && !isempty(errors) &&
            throw(ArgumentError("valid package cannot contain structural errors"))
        if structural_status == :valid && isdefined(@__MODULE__, :_v5_valid_package_gap_contract)
            checker = getfield(@__MODULE__, :_v5_valid_package_gap_contract)
            checker(g1, g2, g3, migration_receipt, gaps) ||
                throw(ArgumentError("valid package gaps must be derived from child admissions and authority"))
        end
        if isdefined(@__MODULE__, :_v5_component_type_valid)
            checker = getfield(@__MODULE__, :_v5_component_type_valid)
            checker(g1, :G1) || structural_status == :fail_closed ||
                throw(ArgumentError("G1 must be MechanismGenomeV5"))
            checker(g2, :G2) || structural_status == :fail_closed ||
                throw(ArgumentError("G2 must be FieldGeometryGenomeV5"))
            checker(g3, :G3) || structural_status == :fail_closed ||
                throw(ArgumentError("G3 must be RealizationControlGenomeV5"))
        end
        if isdefined(@__MODULE__, :_v5_package_identity_valid)
            verifier = getfield(@__MODULE__, :_v5_package_identity_valid)
            verifier(candidate_ref, g1, g2, g2_binding, g3, version_axes, component_identity,
                     migration_receipt;
                     require_candidate=(structural_status == :valid)) ||
                throw(ArgumentError("component identity does not match package objects"))
        end
        migration_receipt.candidate_ref == candidate_ref ||
            throw(ArgumentError("migration receipt candidate ref mismatch"))
            candidate_hash = canonical_hash((package_version="v5",
                                         candidate_ref=candidate_ref,
                                         component_identity=component_identity,
                                         version_axes=version_axes,
                                         migration_receipt=migration_receipt))
        new{typeof(g1),typeof(g2),typeof(g3)}(candidate_ref, g1, g2, g2_binding, g3, version_axes, migration_receipt,
            component_identity, structural_status, resolution, errors, gaps,
            candidate_hash, claim_ceiling)
    end
end

semantic_view(x::CandidateStatePackageV5) = (
    candidate_ref=x.candidate_ref, g2_binding=x.g2_binding,
    component_identity=x.component_identity,
    version_axes=x.version_axes, migration_receipt=x.migration_receipt,
    structural_status=x.structural_status, resolution=x.resolution,
    errors=x.errors, gaps=x.gaps,
    candidate_hash=x.candidate_hash, claim_ceiling=x.claim_ceiling)
