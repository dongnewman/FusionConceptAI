"""Candidate-owned UP2 bound-input identity scaffold.

This additive envelope binds an actual CandidateStatePackageV5 to the three
public outer refs, component hashes and four version axes.  It does not invent
N05/N06 physical declarations and it never changes the package's original
candidate_hash.  A future N05/N06 implementation must subtype the abstract
contracts below and provide its own typed, content-hashed extension before it
can be admitted by a later version of this envelope.
"""

const _UP2E0_SCHEMA_SOURCE_V1 = """
schema_id=GenomeV5/UP2/UP2CandidatePhysicalBindingV1
version=v1
fields=candidate_ref:QualifiedRefV1,package_hash:Digest256,
g1_ref:GenomeContractRef,g2_ref:GenomeContractRef,g3_ref:GenomeContractRef,
g1_component_hash:Digest256,g2_component_hash:Digest256,g3_component_hash:Digest256,
version_axes:NamedTuple[g1,g2,g3],schema_hash:Digest256,
canonicalization_hash:Digest256,profile_hash:Digest256,binding_hash:Digest256,
bound_input_hash:Digest256,n05:typed-or-absent,n06:typed-or-absent,
gaps:Tuple[String],resolution:terminal_deferred
constraints=actual CandidateStatePackageV5 factory; exact public ref fields and
component hashes and axes; package_hash remains the original package hash;
binding_hash participates in bound_input_hash; absent N05/N06 are deferred;
malformed candidate/ref/hash/axis is fail_closed; no compiler/provider/solver
"""

const _UP2E0_CANONICALIZATION_SOURCE_V1 = """
canonicalization_id=GenomeV5/UP2/bound-input/canonicalization/v1
encoding=UTF-8; line_endings=LF; strings=ordinal UTF-8 bytes; tuples=declared order
refs=uri,version,schema_hash,canonicalization_hash,compatibility_profile
identity=package_hash,candidate_ref,three_public_refs,three_component_hashes,
four_version_axes,schema_hash,canonicalization_hash,profile_hash,binding_hash,
typed_declaration_presence,gaps
digest=SHA-256 of canonical semantic value
"""

const _UP2E0_PROFILE_SOURCE_V1 = """
profile_id=GenomeV5/UP2/bound-input/applicability/v1
scope=candidate-bound contract-only precompiler input
authority=actual CandidateStatePackageV5 only
missing_n05_n06=terminal_deferred
malformed_ref_hash_axis=fail_closed
execution=compile/provider/solver not invoked
physical=declaration and envelope do not imply provider, mesh, engineering or physical evidence
"""

up2e0_schema_hash() = digest256_text(_UP2E0_SCHEMA_SOURCE_V1)
up2e0_canonicalization_hash() = digest256_text(_UP2E0_CANONICALIZATION_SOURCE_V1)
up2e0_profile_hash() = digest256_text(_UP2E0_PROFILE_SOURCE_V1)

const UP2E0_N05_AUTHORITY_GAP_V1 = "N05_terminal_deferred:no_authoritative_typed_flux_binding"
const UP2E0_N06_AUTHORITY_GAP_V1 = "N06_terminal_deferred:no_authoritative_typed_source_field_return_heat_ledger_binding"
const UP2E0_REQUIRED_AUTHORITY_GAPS_V1 =
    (UP2E0_N05_AUTHORITY_GAP_V1, UP2E0_N06_AUTHORITY_GAP_V1)

abstract type UP2E0N05DeclarationContractV1 end
abstract type UP2E0N06DeclarationContractV1 end

_up2e0_ref(x) = x isa GenomeContractRef ? x : throw(ArgumentError("UP2E0 source must be GenomeContractRef"))
_up2e0_digest(x, field) = x isa Digest256 ? x : throw(ArgumentError("$field must be Digest256"))

function _up2e0_component_ref(package, role::Symbol)
    value = role === :G1 ? package.g1.contract_ref :
            role === :G2 ? package.g2.contract_ref :
            role === :G3 ? package.g3.contract_binding.contract_ref : nothing
    value isa GenomeContractRef || throw(ArgumentError("$role outer public ref is missing"))
    value
end

function _up2e0_component_hash(package, role::Symbol)
    component = role === :G1 ? package.g1 : role === :G2 ? package.g2 :
                role === :G3 ? package.g3 : nothing
    value = component === nothing ? nothing : getproperty(component, :candidate_hash)
    value isa Digest256 || throw(ArgumentError("$role component hash is missing"))
    value
end

function _up2e0_axes(package, role::Symbol)
    component = role === :G1 ? package.g1 : role === :G2 ? package.g2 :
                role === :G3 ? package.g3 : nothing
    axes = if component === nothing
        nothing
    elseif role === :G3
        component.contract_binding.version_axes
    else
        component.version_axes
    end
    axes === nothing && throw(ArgumentError("$role version axes are missing"))
    semantic_view(axes)
end

function _up2e0_child_refs(g3)
    (realization=semantic_view(g3.realization.contract_binding.contract_ref),
     control=semantic_view(g3.control.contract_binding.contract_ref),
     binding=semantic_view(g3.binding.contract_binding.contract_ref))
end

function _up2e0_package_hash(package)
    canonical_hash((package_version="v5", candidate_ref=package.candidate_ref,
        component_identity=package.component_identity,
        version_axes=package.version_axes,
        migration_receipt=package.migration_receipt))
end

function _up2e0_binding_hash(candidate_ref, package_hash, g1_ref, g2_ref, g3_ref,
                             g1_component_hash, g2_component_hash, g3_component_hash,
                             version_axes, schema_hash, canonicalization_hash, profile_hash,
                             n05, n06, gaps, resolution)
    canonical_hash((candidate_ref=candidate_ref, package_hash=package_hash,
        g1_ref=g1_ref, g2_ref=g2_ref, g3_ref=g3_ref,
        g1_component_hash=g1_component_hash, g2_component_hash=g2_component_hash,
        g3_component_hash=g3_component_hash, version_axes=version_axes,
        schema_hash=schema_hash, canonicalization_hash=canonicalization_hash,
        profile_hash=profile_hash, n05_present=n05 !== nothing,
        n06_present=n06 !== nothing, gaps=gaps, resolution=resolution))
end

function _up2e0_bound_input_hash(candidate_ref, package_hash, g1_ref, g2_ref, g3_ref,
                                 g1_component_hash, g2_component_hash, g3_component_hash,
                                 version_axes, schema_hash, canonicalization_hash, profile_hash,
                                 binding_hash, n05, n06, gaps, resolution)
    canonical_hash((bound_input_version="v1", candidate_ref=candidate_ref,
        package_hash=package_hash, g1_ref=g1_ref, g2_ref=g2_ref, g3_ref=g3_ref,
        g1_component_hash=g1_component_hash, g2_component_hash=g2_component_hash,
        g3_component_hash=g3_component_hash, version_axes=version_axes,
        schema_hash=schema_hash, canonicalization_hash=canonicalization_hash,
        profile_hash=profile_hash, binding_hash=binding_hash,
        n05_present=n05 !== nothing, n06_present=n06 !== nothing, gaps=gaps,
        resolution=resolution))
end

function _up2e0_identity_errors(package::CandidateStatePackageV5,
                                expected_candidate_ref::QualifiedRefV1,
                                expected_package_hash::Digest256,
                                expected_axes::NamedTuple)
    errors = String[]
    package.candidate_ref == expected_candidate_ref || push!(errors, "candidate_ref_mismatch")
    package.candidate_hash == expected_package_hash || push!(errors, "package_hash_mismatch")
    package.version_axes == expected_axes || push!(errors, "version_axes_mismatch")
    package.candidate_ref.version == "v5" || push!(errors, "candidate_ref_version_not_v5")
    package.structural_status == :valid || push!(errors, "package_structural_status_not_valid")
    package.claim_ceiling == none || push!(errors, "package_claim_ceiling_not_none")
    package.migration_receipt.candidate_ref == package.candidate_ref ||
        push!(errors, "migration_receipt_candidate_mismatch")
    package.candidate_hash == _up2e0_package_hash(package) ||
        push!(errors, "package_hash_not_reproducible")

    refs = (_up2e0_component_ref(package, :G1), _up2e0_component_ref(package, :G2),
            _up2e0_component_ref(package, :G3))
    roles = (:G1, :G2, :G3)
    for (role, ref) in zip(roles, refs)
        ref.version == "v5" || push!(errors, "$(role)_ref_version_not_v5")
        isempty(ref.uri) && push!(errors, "$(role)_ref_uri_empty")
        isempty(ref.compatibility_profile) && push!(errors, "$(role)_ref_profile_empty")
        ref.schema_hash == Digest256(repeat("0", 64)) && push!(errors, "$(role)_schema_hash_placeholder")
        ref.canonicalization_hash == Digest256(repeat("0", 64)) &&
            push!(errors, "$(role)_canonicalization_hash_placeholder")
    end

    hashes = (_up2e0_component_hash(package, :G1), _up2e0_component_hash(package, :G2),
              _up2e0_component_hash(package, :G3))
    identity = package.component_identity
    required = (:candidate_ref, :g1_ref, :g2_ref, :g3_ref, :g1_genome_hash,
                :g2_genome_hash, :g3_genome_hash, :g3_child_refs)
    all(hasproperty(identity, x) for x in required) || push!(errors, "component_identity_fields_missing")
    if isempty(errors) || all(hasproperty(identity, x) for x in required)
        identity.candidate_ref == package.candidate_ref || push!(errors, "identity_candidate_ref_mismatch")
        identity.g1_ref == semantic_view(refs[1]) || push!(errors, "identity_g1_ref_mismatch")
        identity.g2_ref == semantic_view(refs[2]) || push!(errors, "identity_g2_ref_mismatch")
        identity.g3_ref == semantic_view(refs[3]) || push!(errors, "identity_g3_ref_mismatch")
        identity.g1_genome_hash == hashes[1] || push!(errors, "identity_g1_hash_mismatch")
        identity.g2_genome_hash == hashes[2] || push!(errors, "identity_g2_hash_mismatch")
        identity.g3_genome_hash == hashes[3] || push!(errors, "identity_g3_hash_mismatch")
        identity.g3_child_refs == _up2e0_child_refs(package.g3) ||
            push!(errors, "identity_g3_child_refs_mismatch")
    end
    package.g2_binding.candidate_ref == package.candidate_ref || push!(errors, "g2_binding_candidate_mismatch")
    package.g2_binding.genome_hash == hashes[2] || push!(errors, "g2_binding_hash_mismatch")
    package.version_axes.g1 == _up2e0_axes(package, :G1) || push!(errors, "G1_axes_not_source_backed")
    package.version_axes.g2 == _up2e0_axes(package, :G2) || push!(errors, "G2_axes_not_source_backed")
    package.version_axes.g3 == _up2e0_axes(package, :G3) || push!(errors, "G3_axes_not_source_backed")
    unique!(errors)
    errors
end

function _up2e0_check_package_with_inspector(package::CandidateStatePackageV5,
                                             expected_candidate_ref::QualifiedRefV1,
                                             expected_package_hash::Digest256,
                                             expected_axes::NamedTuple,
                                             inspector::F) where {F<:Function}
    errors = try
        inspector(package, expected_candidate_ref, expected_package_hash, expected_axes)
    catch error
        return up2e0_classify_exception(error)
    end
    (status=isempty(errors) ? :valid : :fail_closed, errors=Tuple(errors),
     compile_calls=0, provider_calls=0, solver_calls=0)
end

"""Check expected source identity against the actual package without executing anything."""
function up2e0_check_package(package::CandidateStatePackageV5,
                             expected_candidate_ref::QualifiedRefV1=package.candidate_ref,
                             expected_package_hash::Digest256=package.candidate_hash,
                             expected_axes::NamedTuple=package.version_axes)
    _up2e0_check_package_with_inspector(package, expected_candidate_ref,
        expected_package_hash, expected_axes, _up2e0_identity_errors)
end

"""Keep unexpected internal/source exceptions distinct from known contradictions."""
function up2e0_classify_exception(error::Exception)
    (status=:program_exception,
     errors=("package_source_exception:" * sprint(showerror, error),),
     compile_calls=0, provider_calls=0, solver_calls=0)
end

"""Typed expected identity used only for fail-closed negative controls."""
struct UP2E0ExpectedPackageIdentityV1
    candidate_ref::QualifiedRefV1
    package_hash::Digest256
    g1_ref::GenomeContractRef
    g2_ref::GenomeContractRef
    g3_ref::GenomeContractRef
    g1_component_hash::Digest256
    g2_component_hash::Digest256
    g3_component_hash::Digest256
    version_axes::NamedTuple
end

function up2e0_expected_identity(package::CandidateStatePackageV5)
    UP2E0ExpectedPackageIdentityV1(package.candidate_ref, package.candidate_hash,
        _up2e0_component_ref(package, :G1), _up2e0_component_ref(package, :G2),
        _up2e0_component_ref(package, :G3), _up2e0_component_hash(package, :G1),
        _up2e0_component_hash(package, :G2), _up2e0_component_hash(package, :G3),
        package.version_axes)
end

function up2e0_check_package(package::CandidateStatePackageV5,
                             expected::UP2E0ExpectedPackageIdentityV1)
    _up2e0_check_expected_with_checker(package, expected, _up2e0_identity_checker)
end

function _up2e0_identity_checker(package::CandidateStatePackageV5,
                                 expected_candidate_ref::QualifiedRefV1,
                                 expected_package_hash::Digest256,
                                 expected_axes::NamedTuple)
    _up2e0_check_package_with_inspector(package, expected_candidate_ref, expected_package_hash,
        expected_axes, _up2e0_identity_errors)
end

function _up2e0_check_expected_with_checker(package::CandidateStatePackageV5,
                                            expected::UP2E0ExpectedPackageIdentityV1,
                                            checker::F) where {F<:Function}
    base = checker(package, expected.candidate_ref, expected.package_hash, expected.version_axes)
    base.status == :program_exception && return base
    errors = String[base.errors...]
    _up2e0_component_ref(package, :G1) == expected.g1_ref || push!(errors, "G1_ref_mismatch")
    _up2e0_component_ref(package, :G2) == expected.g2_ref || push!(errors, "G2_ref_mismatch")
    _up2e0_component_ref(package, :G3) == expected.g3_ref || push!(errors, "G3_ref_mismatch")
    _up2e0_component_hash(package, :G1) == expected.g1_component_hash ||
        push!(errors, "G1_component_hash_mismatch")
    _up2e0_component_hash(package, :G2) == expected.g2_component_hash ||
        push!(errors, "G2_component_hash_mismatch")
    _up2e0_component_hash(package, :G3) == expected.g3_component_hash ||
        push!(errors, "G3_component_hash_mismatch")
    errors = unique(errors)
    (status=isempty(errors) ? :valid : :fail_closed, errors=Tuple(errors),
     compile_calls=0, provider_calls=0, solver_calls=0)
end

struct UP2CandidatePhysicalBindingV1
    candidate_ref::QualifiedRefV1
    package_hash::Digest256
    g1_ref::GenomeContractRef
    g2_ref::GenomeContractRef
    g3_ref::GenomeContractRef
    g1_component_hash::Digest256
    g2_component_hash::Digest256
    g3_component_hash::Digest256
    version_axes::NamedTuple
    schema_hash::Digest256
    canonicalization_hash::Digest256
    profile_hash::Digest256
    binding_hash::Digest256
    bound_input_hash::Digest256
    n05::Union{Nothing,UP2E0N05DeclarationContractV1}
    n06::Union{Nothing,UP2E0N06DeclarationContractV1}
    gaps::Tuple{Vararg{String}}
    resolution::Symbol
    function UP2CandidatePhysicalBindingV1(candidate_ref::QualifiedRefV1,
            package_hash::Digest256, g1_ref::GenomeContractRef, g2_ref::GenomeContractRef,
            g3_ref::GenomeContractRef, g1_component_hash::Digest256,
            g2_component_hash::Digest256, g3_component_hash::Digest256,
            version_axes::NamedTuple, schema_hash::Digest256,
            canonicalization_hash::Digest256, profile_hash::Digest256,
            n05::Union{Nothing,UP2E0N05DeclarationContractV1},
            n06::Union{Nothing,UP2E0N06DeclarationContractV1}, gaps::Tuple{Vararg{String}})
        candidate_ref.version == "v5" || throw(ArgumentError("UP2E0 candidate ref must use v5"))
        resolution = :terminal_deferred
        body = (candidate_ref=candidate_ref, package_hash=package_hash,
            g1_ref=g1_ref, g2_ref=g2_ref, g3_ref=g3_ref,
            g1_component_hash=g1_component_hash, g2_component_hash=g2_component_hash,
            g3_component_hash=g3_component_hash, version_axes=version_axes,
            schema_hash=schema_hash, canonicalization_hash=canonicalization_hash,
            profile_hash=profile_hash, n05_present=n05 !== nothing,
            n06_present=n06 !== nothing, gaps=gaps, resolution=resolution)
        binding_hash = _up2e0_binding_hash(candidate_ref, package_hash, g1_ref, g2_ref, g3_ref,
            g1_component_hash, g2_component_hash, g3_component_hash, version_axes,
            schema_hash, canonicalization_hash, profile_hash, n05, n06, gaps, resolution)
        bound_input_hash = _up2e0_bound_input_hash(candidate_ref, package_hash, g1_ref, g2_ref, g3_ref,
            g1_component_hash, g2_component_hash, g3_component_hash, version_axes,
            schema_hash, canonicalization_hash, profile_hash, binding_hash, n05, n06, gaps, resolution)
        new(candidate_ref, package_hash, g1_ref, g2_ref, g3_ref,
            g1_component_hash, g2_component_hash, g3_component_hash, version_axes,
            schema_hash, canonicalization_hash, profile_hash, binding_hash,
            bound_input_hash, n05, n06, gaps, resolution)
    end
end

semantic_view(x::UP2CandidatePhysicalBindingV1) =
    (candidate_ref=x.candidate_ref, package_hash=x.package_hash,
     g1_ref=x.g1_ref, g2_ref=x.g2_ref, g3_ref=x.g3_ref,
     g1_component_hash=x.g1_component_hash, g2_component_hash=x.g2_component_hash,
     g3_component_hash=x.g3_component_hash, version_axes=x.version_axes,
     schema_hash=x.schema_hash, canonicalization_hash=x.canonicalization_hash,
     profile_hash=x.profile_hash, binding_hash=x.binding_hash,
     bound_input_hash=x.bound_input_hash, n05=x.n05, n06=x.n06,
     gaps=x.gaps, resolution=x.resolution)

function up2_candidate_physical_binding_from_a(package::CandidateStatePackageV5;
                                               n05::Union{Nothing,UP2E0N05DeclarationContractV1}=nothing,
                                               n06::Union{Nothing,UP2E0N06DeclarationContractV1}=nothing)
    n05 === nothing || n05 isa UP2E0N05DeclarationContractV1 ||
        throw(ArgumentError("N05 declaration must use the typed UP2E0 abstract contract"))
    n06 === nothing || n06 isa UP2E0N06DeclarationContractV1 ||
        throw(ArgumentError("N06 declaration must use the typed UP2E0 abstract contract"))
    n05 === nothing && n06 === nothing ||
        throw(ArgumentError("N05/N06 extensions require a later typed, content-hashed implementation"))
    check = up2e0_check_package(package)
    check.status == :valid || begin
        check.status == :program_exception &&
            throw(ErrorException("UP2E0 program_exception: " * join(check.errors, ",")))
        throw(ArgumentError("UP2E0 source package fail_closed: " * join(check.errors, ",")))
    end
    refs = (_up2e0_component_ref(package, :G1), _up2e0_component_ref(package, :G2),
            _up2e0_component_ref(package, :G3))
    hashes = (_up2e0_component_hash(package, :G1), _up2e0_component_hash(package, :G2),
              _up2e0_component_hash(package, :G3))
    gaps = UP2E0_REQUIRED_AUTHORITY_GAPS_V1
    UP2CandidatePhysicalBindingV1(package.candidate_ref, package.candidate_hash,
        refs[1], refs[2], refs[3], hashes[1], hashes[2], hashes[3],
        package.version_axes, up2e0_schema_hash(), up2e0_canonicalization_hash(),
        up2e0_profile_hash(), n05, n06, gaps)
end

function up2e0_validate_binding(binding::UP2CandidatePhysicalBindingV1)
    errors = String[]
    binding.candidate_ref.version == "v5" || push!(errors, "candidate_ref_version_not_v5")
    binding.resolution == :terminal_deferred || push!(errors, "resolution_not_terminal_deferred")
    Tuple(binding.gaps) == UP2E0_REQUIRED_AUTHORITY_GAPS_V1 ||
        push!(errors, "physical_authority_gaps_not_exact")
    binding.n05 === nothing || push!(errors, "N05_extension_not_admitted")
    binding.n06 === nothing || push!(errors, "N06_extension_not_admitted")
    binding.schema_hash == up2e0_schema_hash() || push!(errors, "schema_hash_not_authoritative")
    binding.canonicalization_hash == up2e0_canonicalization_hash() ||
        push!(errors, "canonicalization_hash_not_authoritative")
    binding.profile_hash == up2e0_profile_hash() || push!(errors, "profile_hash_not_authoritative")
    for (role, ref) in ((:G1, binding.g1_ref), (:G2, binding.g2_ref), (:G3, binding.g3_ref))
        ref.version == "v5" || push!(errors, "$(role)_ref_version_not_v5")
        if isempty(ref.uri) || isempty(ref.compatibility_profile)
            push!(errors, "$(role)_ref_fields_missing")
        end
    end
    all(hasproperty(binding.version_axes, x) for x in (:g1, :g2, :g3)) ||
        push!(errors, "version_axes_shape_invalid")
    binding.binding_hash == _up2e0_binding_hash(binding.candidate_ref, binding.package_hash,
        binding.g1_ref, binding.g2_ref, binding.g3_ref, binding.g1_component_hash,
        binding.g2_component_hash, binding.g3_component_hash, binding.version_axes,
        binding.schema_hash, binding.canonicalization_hash, binding.profile_hash,
        binding.n05, binding.n06, binding.gaps, binding.resolution) ||
        push!(errors, "binding_hash_mismatch")
    binding.bound_input_hash == _up2e0_bound_input_hash(binding.candidate_ref, binding.package_hash,
        binding.g1_ref, binding.g2_ref, binding.g3_ref, binding.g1_component_hash,
        binding.g2_component_hash, binding.g3_component_hash, binding.version_axes,
        binding.schema_hash, binding.canonicalization_hash, binding.profile_hash,
        binding.binding_hash, binding.n05, binding.n06, binding.gaps, binding.resolution) ||
        push!(errors, "bound_input_hash_mismatch")
    isempty(errors) ? (status=:valid, errors=(), compile_calls=0, provider_calls=0, solver_calls=0) :
        (status=:fail_closed, errors=Tuple(unique(errors)), compile_calls=0, provider_calls=0, solver_calls=0)
end

"""Validate an already-held envelope against the actual package source."""
function _up2e0_validate_binding_with_checker(binding::UP2CandidatePhysicalBindingV1,
                                               package::CandidateStatePackageV5,
                                               checker::F) where {F<:Function}
    internal = up2e0_validate_binding(binding)
    errors = String[internal.errors...]
    source = checker(package)
    source.status == :program_exception &&
        return (status=:program_exception, errors=Tuple(unique(vcat(errors, collect(source.errors)))),
            compile_calls=0, provider_calls=0, solver_calls=0)
    source.status == :valid || append!(errors, source.errors)
    binding.candidate_ref == package.candidate_ref || push!(errors, "source_candidate_ref_mismatch")
    binding.package_hash == package.candidate_hash || push!(errors, "source_package_hash_mismatch")
    binding.g1_ref == _up2e0_component_ref(package, :G1) || push!(errors, "source_G1_ref_mismatch")
    binding.g2_ref == _up2e0_component_ref(package, :G2) || push!(errors, "source_G2_ref_mismatch")
    binding.g3_ref == _up2e0_component_ref(package, :G3) || push!(errors, "source_G3_ref_mismatch")
    binding.g1_component_hash == _up2e0_component_hash(package, :G1) ||
        push!(errors, "source_G1_component_hash_mismatch")
    binding.g2_component_hash == _up2e0_component_hash(package, :G2) ||
        push!(errors, "source_G2_component_hash_mismatch")
    binding.g3_component_hash == _up2e0_component_hash(package, :G3) ||
        push!(errors, "source_G3_component_hash_mismatch")
    binding.version_axes == package.version_axes || push!(errors, "source_version_axes_mismatch")
    errors = unique(errors)
    isempty(errors) ? (status=:valid, errors=(), compile_calls=0, provider_calls=0, solver_calls=0) :
        (status=:fail_closed, errors=Tuple(errors), compile_calls=0, provider_calls=0, solver_calls=0)
end

function up2e0_validate_binding(binding::UP2CandidatePhysicalBindingV1,
                                 package::CandidateStatePackageV5)
    _up2e0_validate_binding_with_checker(binding, package, up2e0_check_package)
end
