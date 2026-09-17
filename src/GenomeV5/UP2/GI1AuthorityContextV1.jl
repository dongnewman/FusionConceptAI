"""Additive G-I1A authority context.

This context is a typed, candidate-bound join of an actual A package, the
source-validated E0 binding, E1/N05 authority when it is present, and a typed
E2/N06 absence when the current A package has no authoritative dimensioned
G1-to-G3 mapping.  It is an identity and admission envelope only: physical
resolution remains deferred and no compiler, provider, solver, mesh, or
engineering operation is invoked.
"""

const _GI1_SCHEMA_SOURCE_V1 = """
schema_id=GenomeV5/UP2/GI1AuthorityContextV1
version=v1
fields=candidate_ref,package_hash,package_structural_status,package_resolution,package_claim_ceiling,
g1_ref,g2_ref,g3_ref,g1_component_hash,g2_component_hash,g3_component_hash,version_axes,
e0_binding,e1_slot,e2_slot,contract_admission,physical_resolution,gaps,errors,
compile_calls,provider_calls,solver_calls,context_hash
constraints=actual CandidateStatePackageV5 and UP2E0 binding; exact five-field refs,
component hashes and four axes; E1 present requires up2n05_validate; E2 absent
is derived from n06_mapping_admission(package,e0); absence is typed and content-hashed;
foreign/stale/self-inconsistent identity is fail_closed; missing authority is terminal_deferred
"""
const _GI1_CANONICAL_SOURCE_V1 = """
canonicalization_id=GenomeV5/UP2/gi1-authority-context/canonicalization/v1
encoding=UTF-8; line_endings=LF; fixed_order=context fields; refs=all five fields;
slots=typed presence/absence with independent content hash; identity=all semantic values
and E0/N05/N06 provenance; digest=SHA-256 of canonical semantic value
"""
const _GI1_PROFILE_SOURCE_V1 = """
profile_id=GenomeV5/UP2/gi1-authority-context/applicability/v1
scope=contract-only authority context; contract_admission is declared_consistent,
fail_closed, terminal_deferred or program_exception;
physical_resolution=terminal_deferred; compile/provider/solver=0; no B00/B04 or physical credit
"""

gi1_schema_hash() = digest256_text(_GI1_SCHEMA_SOURCE_V1)
gi1_canonicalization_hash() = digest256_text(_GI1_CANONICAL_SOURCE_V1)
gi1_profile_hash() = digest256_text(_GI1_PROFILE_SOURCE_V1)

abstract type GI1AuthoritySlotV1 end

struct GI1ProgramException <: Exception
    message::String
end

Base.showerror(io::IO, err::GI1ProgramException) = print(io, err.message)

gi1_admission_taxonomy(status::Symbol) =
    status in (:declared_consistent, :fail_closed, :terminal_deferred, :program_exception) ?
        status : throw(ArgumentError("GI1 admission taxonomy status is invalid"))

function _gi1_require_valid(result, label::AbstractString)
    result.status === :valid && return result
    if result.status === :program_exception
        details = hasproperty(result, :errors) ? join(String.(result.errors), ",") : "program_exception"
        throw(GI1ProgramException("$(label) program_exception: $(details)"))
    end
    details = hasproperty(result, :errors) ? join(String.(result.errors), ",") : String(result.status)
    throw(ArgumentError("$(label) fail_closed: $(details)"))
end

function _gi1_overall_admission(e1::GI1AuthoritySlotV1,
                                e2::GI1AuthoritySlotV1,
                                e1_admission::Symbol, e2_admission::Symbol,
                                gaps, errors=())
    if e1_admission === :program_exception || e2_admission === :program_exception
        return :program_exception
    elseif e1_admission === :fail_closed || e2_admission === :fail_closed
        return :fail_closed
    end
    e1 isa GI1N05PresentAuthoritySlotV1 && e1.content_hash != _gi1_slot_hash(e1) &&
        return :fail_closed
    if e2 isa GI1N06PresentAuthoritySlotV1
        e2.content_hash == _gi1_slot_hash(e2) || return :fail_closed
        e2.mapping.mapping_hash == _n06_mapping_hash(e2.mapping) || return :fail_closed
    end
    e1_admission in (:declared_consistent, :terminal_deferred) ||
        throw(ArgumentError("GI1 E1 admission taxonomy is invalid"))
    e2_admission in (:declared_consistent, :terminal_deferred) ||
        throw(ArgumentError("GI1 E2 admission taxonomy is invalid"))
    e1 isa GI1N05PresentAuthoritySlotV1 &&
        e2 isa GI1N06PresentAuthoritySlotV1 &&
        e1_admission === :declared_consistent &&
        e2_admission === :declared_consistent &&
        isempty(gaps) && isempty(errors) ? :declared_consistent : :terminal_deferred
end

struct GI1AbsentAuthoritySlotV1 <: GI1AuthoritySlotV1
    slot::Symbol
    reason::Symbol
    gaps::Tuple{Vararg{String}}
    projection_hash::Digest256
    schema_hash::Digest256
    canonicalization_hash::Digest256
    profile_hash::Digest256
    compatibility_profile_hash::Digest256
    provenance::NamedTuple
    content_hash::Digest256
end

struct GI1N05PresentAuthoritySlotV1 <: GI1AuthoritySlotV1
    slot::Symbol
    authority::UP2N05AuthorityV1
    package_hash::Digest256
    e0_bound_input_hash::Digest256
    schema_hash::Digest256
    canonicalization_hash::Digest256
    profile_hash::Digest256
    compatibility_profile_hash::Digest256
    provenance::NamedTuple
    content_hash::Digest256
end

struct GI1N06PresentAuthoritySlotV1 <: GI1AuthoritySlotV1
    slot::Symbol
    mapping::N06SourceFieldLedgerMappingV1
    package_hash::Digest256
    e0_bound_input_hash::Digest256
    schema_hash::Digest256
    canonicalization_hash::Digest256
    profile_hash::Digest256
    compatibility_profile_hash::Digest256
    provenance::NamedTuple
    content_hash::Digest256
end

function _gi1_absent_body(x::GI1AbsentAuthoritySlotV1)
    (slot=x.slot, reason=x.reason, gaps=x.gaps, projection_hash=x.projection_hash,
     schema_hash=x.schema_hash, canonicalization_hash=x.canonicalization_hash,
     profile_hash=x.profile_hash, compatibility_profile_hash=x.compatibility_profile_hash,
     provenance=x.provenance)
end

function _gi1_present_body(x::GI1N05PresentAuthoritySlotV1)
    (slot=x.slot, authority=x.authority, package_hash=x.package_hash,
     e0_bound_input_hash=x.e0_bound_input_hash, schema_hash=x.schema_hash,
     canonicalization_hash=x.canonicalization_hash, profile_hash=x.profile_hash,
     compatibility_profile_hash=x.compatibility_profile_hash,
     provenance=x.provenance)
end

function _gi1_n06_present_body(x::GI1N06PresentAuthoritySlotV1)
    (slot=x.slot, mapping=x.mapping, package_hash=x.package_hash,
     e0_bound_input_hash=x.e0_bound_input_hash, schema_hash=x.schema_hash,
     canonicalization_hash=x.canonicalization_hash, profile_hash=x.profile_hash,
     compatibility_profile_hash=x.compatibility_profile_hash,
     provenance=x.provenance)
end

_gi1_slot_hash(x::GI1AbsentAuthoritySlotV1) = canonical_hash(_gi1_absent_body(x))
_gi1_slot_hash(x::GI1N05PresentAuthoritySlotV1) = canonical_hash(_gi1_present_body(x))
_gi1_slot_hash(x::GI1N06PresentAuthoritySlotV1) = canonical_hash(_gi1_n06_present_body(x))
semantic_view(x::GI1AbsentAuthoritySlotV1) = merge(_gi1_absent_body(x), (content_hash=x.content_hash,))
semantic_view(x::GI1N05PresentAuthoritySlotV1) = merge(_gi1_present_body(x), (content_hash=x.content_hash,))
semantic_view(x::GI1N06PresentAuthoritySlotV1) = merge(_gi1_n06_present_body(x), (content_hash=x.content_hash,))

function _gi1_validate_provenance(p, candidate_ref, package_hash, e0_hash)
    hasproperty(p, :source) && p.source === :actual_A_E0 ||
        throw(ArgumentError("GI1 slot provenance source is not actual A/E0"))
    hasproperty(p, :candidate_ref) && p.candidate_ref == candidate_ref ||
        throw(ArgumentError("GI1 slot provenance candidate mismatch"))
    hasproperty(p, :package_hash) && p.package_hash == package_hash ||
        throw(ArgumentError("GI1 slot provenance package mismatch"))
    hasproperty(p, :e0_bound_input_hash) && p.e0_bound_input_hash == e0_hash ||
        throw(ArgumentError("GI1 slot provenance E0 mismatch"))
    true
end

function _gi1_make_absent(slot::Symbol, reason::Symbol, gaps, projection_hash,
                          schema_hash, canonicalization_hash, profile_hash,
                          provenance::NamedTuple)
    projection_hash isa Digest256 || throw(ArgumentError("GI1 absent projection hash must be Digest256"))
    gs = Tuple(String(g) for g in gaps)
    isempty(gs) && throw(ArgumentError("GI1 absent slot requires an authority gap"))
    body = (slot=slot, reason=reason, gaps=gs, projection_hash=projection_hash,
        schema_hash=schema_hash, canonicalization_hash=canonicalization_hash,
        profile_hash=profile_hash, compatibility_profile_hash=profile_hash,
        provenance=provenance)
    GI1AbsentAuthoritySlotV1(slot, reason, gs, projection_hash, schema_hash,
        canonicalization_hash, profile_hash, profile_hash, provenance, canonical_hash(body))
end

function _gi1_make_n05_present(authority::UP2N05AuthorityV1,
                               package::CandidateStatePackageV5,
                               e0::UP2CandidatePhysicalBindingV1)
    authority.resolution === :contract_ready ||
        throw(ArgumentError("GI1 E1 authority is not contract_ready"))
    authority.candidate_ref == package.candidate_ref ||
        throw(ArgumentError("GI1 E1 candidate mismatch"))
    authority.package_hash == package.candidate_hash ||
        throw(ArgumentError("GI1 E1 package mismatch"))
    authority.g1_ref == package.g1.contract_ref &&
        authority.g2_ref == package.g2.contract_ref &&
        authority.g3_ref == package.g3.contract_binding.contract_ref ||
        throw(ArgumentError("GI1 E1 component ref mismatch"))
    p = (source=:actual_A_E0, candidate_ref=package.candidate_ref,
         package_hash=package.candidate_hash, e0_bound_input_hash=e0.bound_input_hash)
    _gi1_validate_provenance(p, package.candidate_ref, package.candidate_hash,
        e0.bound_input_hash)
    body = (slot=:E1, authority=authority, package_hash=package.candidate_hash,
        e0_bound_input_hash=e0.bound_input_hash, schema_hash=authority.schema_hash,
        canonicalization_hash=authority.canonicalization_hash,
        profile_hash=authority.profile_hash,
        compatibility_profile_hash=authority.profile_hash, provenance=p)
    GI1N05PresentAuthoritySlotV1(:E1, authority, package.candidate_hash,
        e0.bound_input_hash, authority.schema_hash, authority.canonicalization_hash,
        authority.profile_hash, authority.profile_hash, p, canonical_hash(body))
end

function _gi1_make_n06_present(mapping::N06SourceFieldLedgerMappingV1,
                               package::CandidateStatePackageV5,
                               e0::UP2CandidatePhysicalBindingV1)
    p = (source=:actual_A_E0, candidate_ref=package.candidate_ref,
         package_hash=package.candidate_hash, e0_bound_input_hash=e0.bound_input_hash)
    _gi1_validate_provenance(p, package.candidate_ref, package.candidate_hash,
        e0.bound_input_hash)
    body = (slot=:E2, mapping=mapping, package_hash=package.candidate_hash,
        e0_bound_input_hash=e0.bound_input_hash, schema_hash=n06_schema_hash(),
        canonicalization_hash=n06_canonicalization_hash(), profile_hash=n06_profile_hash(),
        compatibility_profile_hash=n06_profile_hash(), provenance=p)
    GI1N06PresentAuthoritySlotV1(:E2, mapping, package.candidate_hash,
        e0.bound_input_hash, n06_schema_hash(), n06_canonicalization_hash(),
        n06_profile_hash(), n06_profile_hash(), p, canonical_hash(body))
end

function _gi1_check_slot(slot::GI1AuthoritySlotV1, expected_slot::Symbol, package, e0)
    slot.content_hash == _gi1_slot_hash(slot) ||
        throw(ArgumentError("GI1 slot content hash mismatch"))
    if slot isa GI1N05PresentAuthoritySlotV1
        slot.slot === :E1 && expected_slot === :E1 ||
            throw(ArgumentError("GI1 E1 slot position mismatch"))
        slot.package_hash == package.candidate_hash || throw(ArgumentError("GI1 E1 package hash mismatch"))
        slot.e0_bound_input_hash == e0.bound_input_hash || throw(ArgumentError("GI1 E1 E0 hash mismatch"))
        slot.authority.candidate_ref == package.candidate_ref || throw(ArgumentError("GI1 E1 source candidate mismatch"))
        slot.authority.resolution === :contract_ready || throw(ArgumentError("GI1 E1 source is not contract_ready"))
        slot.compatibility_profile_hash == slot.authority.profile_hash ||
            throw(ArgumentError("GI1 E1 compatibility profile hash mismatch"))
    elseif slot isa GI1N06PresentAuthoritySlotV1
        slot.slot === :E2 && expected_slot === :E2 ||
            throw(ArgumentError("GI1 E2 slot position mismatch"))
        slot.package_hash == package.candidate_hash || throw(ArgumentError("GI1 E2 package hash mismatch"))
        slot.e0_bound_input_hash == e0.bound_input_hash || throw(ArgumentError("GI1 E2 E0 hash mismatch"))
        slot.mapping.candidate_ref == package.candidate_ref ||
            throw(ArgumentError("GI1 E2 source candidate mismatch"))
        slot.mapping.package_hash == package.candidate_hash ||
            throw(ArgumentError("GI1 E2 source package mismatch"))
        slot.mapping.e0_bound_input_hash == e0.bound_input_hash ||
            throw(ArgumentError("GI1 E2 source E0 hash mismatch"))
        slot.mapping.schema_hash == n06_schema_hash() &&
            slot.mapping.canonicalization_hash == n06_canonicalization_hash() &&
            slot.mapping.profile_hash == n06_profile_hash() ||
            throw(ArgumentError("GI1 E2 source contract hash mismatch"))
        slot.mapping.mapping_hash == _n06_mapping_hash(slot.mapping) ||
            throw(ArgumentError("GI1 E2 source mapping hash mismatch"))
        slot.compatibility_profile_hash == slot.profile_hash ||
            throw(ArgumentError("GI1 E2 compatibility profile hash mismatch"))
    else
        slot.slot === expected_slot || throw(ArgumentError("GI1 absent slot position mismatch"))
        isempty(slot.gaps) && throw(ArgumentError("GI1 absent slot has no gap"))
        slot.compatibility_profile_hash == slot.profile_hash ||
            throw(ArgumentError("GI1 absent compatibility profile hash mismatch"))
    end
    true
end

struct GI1AuthorityContextV1
    context_version::String
    schema_hash::Digest256
    canonicalization_hash::Digest256
    compatibility_profile_hash::Digest256
    candidate_ref::QualifiedRefV1
    package_hash::Digest256
    package_structural_status::Symbol
    package_resolution::ResolutionStatus
    package_claim_ceiling::ClaimCeiling
    g1_ref::GenomeContractRef
    g2_ref::GenomeContractRef
    g3_ref::GenomeContractRef
    g1_component_hash::Digest256
    g2_component_hash::Digest256
    g3_component_hash::Digest256
    version_axes::NamedTuple
    e0_binding::UP2CandidatePhysicalBindingV1
    e1::GI1AuthoritySlotV1
    e2::GI1AuthoritySlotV1
    contract_admission::Symbol
    physical_resolution::ResolutionStatus
    gaps::Tuple{Vararg{String}}
    errors::Tuple{Vararg{String}}
    compile_calls::Int
    provider_calls::Int
    solver_calls::Int
    context_hash::Digest256
    function GI1AuthorityContextV1(context_version::AbstractString,
                                   schema_hash::Digest256,
                                   canonicalization_hash::Digest256,
                                   compatibility_profile_hash::Digest256,
                                   candidate_ref::QualifiedRefV1,
                                   package_hash::Digest256,
                                   package_structural_status::Symbol,
                                   package_resolution::ResolutionStatus,
                                   package_claim_ceiling::ClaimCeiling,
                                   g1_ref::GenomeContractRef, g2_ref::GenomeContractRef,
                                   g3_ref::GenomeContractRef,
                                   g1_component_hash::Digest256, g2_component_hash::Digest256,
                                   g3_component_hash::Digest256, version_axes::NamedTuple,
                                   e0_binding::UP2CandidatePhysicalBindingV1,
                                   e1::GI1AuthoritySlotV1, e2::GI1AuthoritySlotV1,
                                   contract_admission::Symbol,
                                   physical_resolution::ResolutionStatus,
                                   gaps::Tuple{Vararg{String}}, errors::Tuple{Vararg{String}},
                                   compile_calls::Integer, provider_calls::Integer,
                                   solver_calls::Integer, context_hash::Digest256)
        String(context_version) == "v1" || throw(ArgumentError("GI1 context version must be v1"))
        schema_hash == gi1_schema_hash() || throw(ArgumentError("GI1 schema hash is not authoritative"))
        canonicalization_hash == gi1_canonicalization_hash() ||
            throw(ArgumentError("GI1 canonicalization hash is not authoritative"))
        compatibility_profile_hash == gi1_profile_hash() ||
            throw(ArgumentError("GI1 compatibility profile hash is not authoritative"))
        candidate_ref.version == "v5" || throw(ArgumentError("GI1 candidate ref must use v5"))
        package_structural_status in (:valid, :fail_closed) ||
            throw(ArgumentError("GI1 package structural status invalid"))
        package_resolution == terminal_deferred ||
            throw(ArgumentError("GI1 package resolution must remain terminal_deferred"))
        package_claim_ceiling == none || throw(ArgumentError("GI1 claim ceiling must remain none"))
        gi1_admission_taxonomy(contract_admission)
        physical_resolution == terminal_deferred ||
            throw(ArgumentError("GI1 physical resolution must remain deferred"))
        compile_calls == 0 && provider_calls == 0 && solver_calls == 0 ||
            throw(ArgumentError("GI1 downstream counters must be zero"))
        _gi1_check_slot(e1, :E1, (candidate_ref=candidate_ref, candidate_hash=package_hash), e0_binding)
        _gi1_check_slot(e2, :E2, (candidate_ref=candidate_ref, candidate_hash=package_hash), e0_binding)
        if package_structural_status === :valid
            isempty(errors) ||
                throw(ArgumentError("GI1 valid context cannot contain structural errors"))
        elseif package_structural_status === :fail_closed
            !isempty(errors) ||
                throw(ArgumentError("GI1 fail_closed context requires structural errors"))
        else
            throw(ArgumentError("GI1 package structural status branch is invalid"))
        end
        new(String(context_version), schema_hash, canonicalization_hash,
            compatibility_profile_hash, candidate_ref, package_hash, package_structural_status, package_resolution,
            package_claim_ceiling, g1_ref, g2_ref, g3_ref, g1_component_hash,
            g2_component_hash, g3_component_hash, version_axes, e0_binding, e1, e2,
            contract_admission, physical_resolution, gaps, errors, Int(compile_calls),
            Int(provider_calls), Int(solver_calls), context_hash)
    end
end

function _gi1_context_body(x::GI1AuthorityContextV1)
    (context_version=x.context_version, schema_hash=x.schema_hash,
     canonicalization_hash=x.canonicalization_hash,
     compatibility_profile_hash=x.compatibility_profile_hash,
     candidate_ref=x.candidate_ref, package_hash=x.package_hash,
     package_structural_status=x.package_structural_status,
     package_resolution=x.package_resolution, package_claim_ceiling=x.package_claim_ceiling,
     g1_ref=x.g1_ref, g2_ref=x.g2_ref, g3_ref=x.g3_ref,
     g1_component_hash=x.g1_component_hash, g2_component_hash=x.g2_component_hash,
     g3_component_hash=x.g3_component_hash, version_axes=x.version_axes,
     e0_binding=x.e0_binding, e1=x.e1, e2=x.e2,
     contract_admission=x.contract_admission, physical_resolution=x.physical_resolution,
     gaps=x.gaps, errors=x.errors, compile_calls=x.compile_calls,
     provider_calls=x.provider_calls, solver_calls=x.solver_calls)
end
semantic_view(x::GI1AuthorityContextV1) = merge(_gi1_context_body(x), (context_hash=x.context_hash,))

function _gi1_validate_context_identity(x::GI1AuthorityContextV1)
    x.context_version == "v1" || throw(ArgumentError("GI1 context version mismatch"))
    x.schema_hash == gi1_schema_hash() || throw(ArgumentError("GI1 context schema hash mismatch"))
    x.canonicalization_hash == gi1_canonicalization_hash() ||
        throw(ArgumentError("GI1 context canonicalization hash mismatch"))
    x.compatibility_profile_hash == gi1_profile_hash() ||
        throw(ArgumentError("GI1 context compatibility profile hash mismatch"))
    x.context_hash == canonical_hash(_gi1_context_body(x)) ||
        throw(ArgumentError("GI1 context identity hash mismatch"))
    x.e0_binding.candidate_ref == x.candidate_ref || throw(ArgumentError("GI1 E0 candidate mismatch"))
    x.e0_binding.package_hash == x.package_hash || throw(ArgumentError("GI1 E0 package hash mismatch"))
    x.e0_binding.g1_ref == x.g1_ref && x.e0_binding.g2_ref == x.g2_ref &&
        x.e0_binding.g3_ref == x.g3_ref || throw(ArgumentError("GI1 E0 outer ref mismatch"))
    x.e0_binding.g1_component_hash == x.g1_component_hash &&
        x.e0_binding.g2_component_hash == x.g2_component_hash &&
        x.e0_binding.g3_component_hash == x.g3_component_hash ||
        throw(ArgumentError("GI1 E0 component hash mismatch"))
    x.e0_binding.version_axes == x.version_axes || throw(ArgumentError("GI1 E0 axes mismatch"))
    true
end

function _gi1_e1_absent(package, e0)
    gaps = UP2N05_MISSING_AUTHORITY_GAPS_V1
    p = (source=:actual_A_E0, candidate_ref=package.candidate_ref,
         package_hash=package.candidate_hash, e0_bound_input_hash=e0.bound_input_hash)
    _gi1_make_absent(:E1, :missing_authority, gaps,
        canonical_hash((slot=:E1, candidate_ref=package.candidate_ref,
                        package_hash=package.candidate_hash, e0=e0.bound_input_hash)),
        UP2N05_SCHEMA_HASH_V1, UP2N05_CANONICAL_HASH_V1, UP2N05_PROFILE_HASH_V1, p)
end

function _gi1_e2_absent(package, e0)
    admission = try
        n06_mapping_admission(package, e0)
    catch err
        throw(GI1ProgramException("GI1 N06 authority program_exception: " * sprint(showerror, err)))
    end
    admission.status === :program_exception &&
        throw(GI1ProgramException("GI1 N06 authority program_exception: " *
            join(String.(admission.errors), ",")))
    admission.status === :terminal_deferred ||
        throw(ArgumentError("GI1 N06 absence expected terminal_deferred, got $(admission.status)"))
    gaps = Tuple(String(x) for x in admission.errors)
    isempty(gaps) && throw(ArgumentError("GI1 N06 deferred admission has no authority gaps"))
    p = (source=:actual_A_E0, candidate_ref=package.candidate_ref,
         package_hash=package.candidate_hash, e0_bound_input_hash=e0.bound_input_hash,
         projection_hash=admission.projection.projection_hash)
    _gi1_make_absent(:E2, :missing_authority, gaps, admission.projection.projection_hash,
        n06_schema_hash(), n06_canonicalization_hash(), n06_profile_hash(), p)
end

function _gi1_e2_slot(package, e0, n06::Union{Nothing,N06SourceFieldLedgerMappingV1})
    n06 === nothing && begin
        absent = _gi1_e2_absent(package, e0)
        return (absent, :terminal_deferred, absent.gaps)
    end
    admission = try
        n06_mapping_admission(package, e0, n06)
    catch err
        throw(GI1ProgramException("GI1 N06 authority program_exception: " * sprint(showerror, err)))
    end
    admission.status === :program_exception &&
        throw(GI1ProgramException("GI1 N06 authority program_exception: " *
            join(String.(admission.errors), ",")))
    admission.status === :valid &&
        return (_gi1_make_n06_present(n06, package, e0), :declared_consistent, ())
    admission.status === :terminal_deferred &&
        return (_gi1_make_n06_present(n06, package, e0), :terminal_deferred,
            Tuple(String(x) for x in admission.errors))
    throw(ArgumentError("GI1 N06 source admission is $(admission.status)"))
end

function gi1_authority_context_from_a(package::CandidateStatePackageV5,
                                      e0::UP2CandidatePhysicalBindingV1;
                                      n05::Union{Nothing,UP2N05AuthorityV1}=nothing,
                                      n06::Union{Nothing,N06SourceFieldLedgerMappingV1}=nothing)
    e0_check = try
        up2e0_validate_binding(e0, package)
    catch err
        throw(GI1ProgramException("GI1 E0 program_exception: " * sprint(showerror, err)))
    end
    _gi1_require_valid(e0_check, "GI1 E0 source")
    package_check = try
        up2e0_check_package(package)
    catch err
        throw(GI1ProgramException("GI1 package program_exception: " * sprint(showerror, err)))
    end
    _gi1_require_valid(package_check, "GI1 package source")
    n05 === nothing || begin
        n05_check = try
            up2n05_validate(n05, package, e0)
        catch err
            throw(GI1ProgramException("GI1 E1 program_exception: " * sprint(showerror, err)))
        end
        _gi1_require_valid(n05_check, "GI1 E1 source")
    end
    e1 = n05 === nothing ? _gi1_e1_absent(package, e0) : _gi1_make_n05_present(n05, package, e0)
    e2, e2_admission, e2_gaps = _gi1_e2_slot(package, e0, n06)
    refs = (package.g1.contract_ref, package.g2.contract_ref,
            package.g3.contract_binding.contract_ref)
    hashes = (package.g1.candidate_hash, package.g2.candidate_hash, package.g3.candidate_hash)
    e1_gaps = n05 === nothing ? () : Tuple(String(x) for x in n05.gaps)
    gaps = unique(Tuple(vcat(collect(e0.gaps), collect(e1_gaps), collect(e2_gaps))))
    e1_admission = n05 === nothing ? :terminal_deferred : :declared_consistent
    admission = _gi1_overall_admission(e1, e2, e1_admission, e2_admission, gaps, ())
    body = (context_version="v1", schema_hash=gi1_schema_hash(),
        canonicalization_hash=gi1_canonicalization_hash(),
        compatibility_profile_hash=gi1_profile_hash(),
        candidate_ref=package.candidate_ref, package_hash=package.candidate_hash,
        package_structural_status=package.structural_status, package_resolution=package.resolution,
        package_claim_ceiling=package.claim_ceiling, g1_ref=refs[1], g2_ref=refs[2], g3_ref=refs[3],
        g1_component_hash=hashes[1], g2_component_hash=hashes[2], g3_component_hash=hashes[3],
        version_axes=package.version_axes, e0_binding=e0, e1=e1, e2=e2,
        contract_admission=admission, physical_resolution=terminal_deferred,
        gaps=Tuple(String(x) for x in gaps), errors=(), compile_calls=0,
        provider_calls=0, solver_calls=0)
    context_hash = canonical_hash(body)
    context = GI1AuthorityContextV1("v1", gi1_schema_hash(), gi1_canonicalization_hash(),
        gi1_profile_hash(), package.candidate_ref, package.candidate_hash,
        package.structural_status, package.resolution, package.claim_ceiling,
        refs[1], refs[2], refs[3], hashes[1], hashes[2], hashes[3], package.version_axes,
        e0, e1, e2, admission, terminal_deferred, Tuple(String(x) for x in gaps), (), 0, 0, 0,
        context_hash)
    _gi1_validate_context_identity(context)
    context
end

function gi1_validate_authority_context_schema(context::GI1AuthorityContextV1)
    try
        _gi1_validate_context_identity(context)
        context.physical_resolution == terminal_deferred || throw(ArgumentError("GI1 physical resolution is not deferred"))
        context.compile_calls == 0 && context.provider_calls == 0 && context.solver_calls == 0 ||
            throw(ArgumentError("GI1 downstream invocation counter is nonzero"))
        (status=:valid, errors=(), contract_admission=context.contract_admission,
         physical_resolution=context.physical_resolution, compile_calls=0,
         provider_calls=0, solver_calls=0)
    catch err
        err isa ArgumentError || return (status=:program_exception,
            errors=(sprint(showerror, err),), compile_calls=0, provider_calls=0, solver_calls=0)
        (status=:fail_closed, errors=(sprint(showerror, err),), compile_calls=0,
         provider_calls=0, solver_calls=0)
    end
end

"""Trusted source-bound validator; it rebuilds context from actual A/E0 inputs."""
function gi1_validate_authority_context(context::GI1AuthorityContextV1,
                                        package::CandidateStatePackageV5,
                                        e0::UP2CandidatePhysicalBindingV1;
                                        n05::Union{Nothing,UP2N05AuthorityV1}=nothing,
                                        n06::Union{Nothing,N06SourceFieldLedgerMappingV1}=nothing)
    try
        expected = gi1_authority_context_from_a(package, e0; n05=n05, n06=n06)
        context.context_hash == expected.context_hash ||
            throw(ArgumentError("GI1 trusted context hash mismatch"))
        semantic_view(context.e1) == semantic_view(expected.e1) ||
            throw(ArgumentError("GI1 trusted E1 slot mismatch"))
        semantic_view(context.e2) == semantic_view(expected.e2) ||
            throw(ArgumentError("GI1 trusted E2 slot mismatch"))
        _gi1_validate_context_identity(context)
        (status=:valid, errors=(), contract_admission=context.contract_admission,
         physical_resolution=context.physical_resolution, compile_calls=0,
         provider_calls=0, solver_calls=0, source_bound=true)
    catch err
        err isa ArgumentError && return (status=:fail_closed,
            errors=(sprint(showerror, err),), compile_calls=0, provider_calls=0,
            solver_calls=0, source_bound=true)
        (status=:program_exception, errors=(sprint(showerror, err),),
         compile_calls=0, provider_calls=0, solver_calls=0, source_bound=true)
    end
end
