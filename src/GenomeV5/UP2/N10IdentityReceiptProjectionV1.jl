"""Contract-only N10 identity and receipt projection.

Every declaration is read from an actual CandidateStatePackageV5.  The
projection keeps the typed source value and the independent value used by the
cross-field invariant.  It never calls a compiler, provider, solver, or mesh
routine.  Fresh receipts are covered only for candidate_identity_after
mismatch; legacy V4 receipt provenance remains an explicit deferred gap.
"""

const _N10_SCHEMA_SOURCE_V1 = """
schema_id=GenomeV5/UP2/N10IdentityReceiptProjectionV1
version=v1
fields=N10IdentityFieldV1(id:String,field_path:String,source_locator:String,source_type:Symbol,
source_ref:GenomeContractRef|QualifiedRefV1,component_hash:Digest256,schema_hash:Digest256,
canonicalization_hash:Digest256,original_value:typed,authoritative_value:typed)
rows=N10-01:g1_ref.schema_hash,N10-02:g2_ref.canonicalization_hash,
N10-03:g3.binding.contract_binding.contract_ref,N10-04:package.candidate_hash,
N10-05:migration_receipt.candidate_identity_after
constraints=actual CandidateStatePackageV5 factory only; package/candidate/component/child
identity exact; N10-03 compares typed child GenomeContractRef to five-field identity;
N10-05 is fresh receipt identity mismatch only; missing V4 provenance terminal_deferred;
structural mismatches invalid_type+fail_closed; compile/provider/solver calls zero
"""

const _N10_CANONICALIZATION_SOURCE_V1 = """
canonicalization_id=GenomeV5/UP2/N10/canonicalization/v1
encoding=UTF-8; line_endings=LF; strings=ordinal bytes; tuples=declared order
typed_values=Digest256,GenomeContractRef,String; identity=URI/version/schema/canonical/profile
digest=SHA-256 of canonical semantic value
"""

n10_schema_hash() = digest256_text(_N10_SCHEMA_SOURCE_V1)
n10_canonicalization_hash() = digest256_text(_N10_CANONICALIZATION_SOURCE_V1)

abstract type N10TypedValueV1 end
struct N10DigestValueV1 <: N10TypedValueV1; value::Digest256; end
struct N10RefValueV1 <: N10TypedValueV1; value::GenomeContractRef; end
struct N10IdentityValueV1 <: N10TypedValueV1; value::NamedTuple; end
struct N10TextValueV1 <: N10TypedValueV1; value::String; end

semantic_view(x::N10DigestValueV1) = (kind=:digest256, value=x.value)
semantic_view(x::N10RefValueV1) = (kind=:genome_contract_ref, value=x.value)
semantic_view(x::N10IdentityValueV1) = (kind=:five_field_identity, value=x.value)
semantic_view(x::N10TextValueV1) = (kind=:text, value=x.value)

_n10_has(x, name::Symbol) = x !== nothing && hasproperty(x, name)
_n10_get(x, name::Symbol, default=nothing) = _n10_has(x, name) ? getproperty(x, name) : default
_n10_digest(x, field) = x isa Digest256 ? x : throw(ArgumentError("$field must be Digest256"))
_n10_ref(x, field) = x isa GenomeContractRef ? x : throw(ArgumentError("$field must be GenomeContractRef"))
_n10_text(x, field) = x isa AbstractString && !isempty(String(x)) ? String(x) : throw(ArgumentError("$field must be non-empty"))

function _n10_ref_identity(ref::GenomeContractRef)
    (uri=ref.uri, version=ref.version, schema_hash=ref.schema_hash,
     canonicalization_hash=ref.canonicalization_hash,
     compatibility_profile=ref.compatibility_profile)
end

function _n10_contract_ref(x, field)
    ref = _n10_get(x, :contract_ref)
    ref isa GenomeContractRef && return ref
    binding = _n10_get(x, :contract_binding)
    ref = _n10_get(binding, :contract_ref)
    ref isa GenomeContractRef && return ref
    throw(ArgumentError("$field has no public GenomeContractRef"))
end

function _n10_expected_identity_hash(package::CandidateStatePackageV5)
    canonical_hash((candidate_ref=package.candidate_ref,
        identity=package.component_identity, axes=package.version_axes)).value
end

function _n10_expected_package_hash(package::CandidateStatePackageV5)
    canonical_hash((package_version="v5", candidate_ref=package.candidate_ref,
        component_identity=package.component_identity,
        version_axes=package.version_axes,
        migration_receipt=package.migration_receipt))
end

struct N10IdentityFieldV1
    id::String
    field_path::String
    source_locator::String
    source_type::Symbol
    source_ref::Any
    component_hash::Digest256
    schema_hash::Digest256
    canonicalization_hash::Digest256
    original_value::N10TypedValueV1
    authoritative_value::N10TypedValueV1
    function N10IdentityFieldV1(id, field_path, source_locator, source_type,
                                source_ref, component_hash, original_value,
                                authoritative_value)
        iid = _n10_text(id, "N10 id")
        path = _n10_text(field_path, "N10 field path")
        locator = _n10_text(source_locator, "N10 source locator")
        (source_ref isa GenomeContractRef || source_ref isa QualifiedRefV1) ||
            throw(ArgumentError("N10 source ref/owner must be typed"))
        source_ref isa QualifiedRefV1 && source_ref.version == "v5" ||
            source_ref isa GenomeContractRef || throw(ArgumentError("N10 source owner must be v5"))
        hash = _n10_digest(component_hash, "N10 component hash")
        original_value isa N10TypedValueV1 || throw(ArgumentError("N10 original value must be typed"))
        authoritative_value isa N10TypedValueV1 || throw(ArgumentError("N10 authoritative value must be typed"))
        schema = source_ref isa GenomeContractRef ? source_ref.schema_hash : n10_schema_hash()
        canonical = source_ref isa GenomeContractRef ? source_ref.canonicalization_hash : n10_canonicalization_hash()
        new(iid, path, locator, Symbol(source_type), source_ref, hash, schema,
            canonical, original_value, authoritative_value)
    end
end

semantic_view(x::N10IdentityFieldV1) =
    (id=x.id, field_path=x.field_path, source_locator=x.source_locator,
     source_type=x.source_type, source_ref=x.source_ref,
     component_hash=x.component_hash, schema_hash=x.schema_hash,
     canonicalization_hash=x.canonicalization_hash,
     original_value=x.original_value, authoritative_value=x.authoritative_value)

struct N10IdentityProjectionV1
    candidate_ref::QualifiedRefV1
    package_hash::Digest256
    component_identity::NamedTuple
    version_axes::NamedTuple
    migration_receipt::GenomeV5MigrationReceipt
    g3_child_refs::NamedTuple
    fields::Tuple{Vararg{N10IdentityFieldV1}}
    gaps::Tuple{Vararg{String}}
    projection_hash::Digest256
    function N10IdentityProjectionV1(candidate_ref, package_hash, component_identity,
                                     version_axes, migration_receipt, g3_child_refs, fields, gaps)
        candidate_ref isa QualifiedRefV1 && candidate_ref.version == "v5" ||
            throw(ArgumentError("N10 projection requires a v5 candidate ref"))
        package_hash isa Digest256 || throw(ArgumentError("N10 projection requires package hash"))
        component_identity isa NamedTuple || throw(ArgumentError("N10 identity must be NamedTuple"))
        version_axes isa NamedTuple || throw(ArgumentError("N10 axes must be NamedTuple"))
        migration_receipt isa GenomeV5MigrationReceipt ||
            throw(ArgumentError("N10 projection requires migration receipt"))
        g3_child_refs isa NamedTuple || throw(ArgumentError("N10 G3 child refs must be NamedTuple"))
        fields isa Tuple && length(fields) == 5 && all(x -> x isa N10IdentityFieldV1, fields) ||
            throw(ArgumentError("N10 projection requires exactly five typed fields"))
        length(unique(x.id for x in fields)) == 5 || throw(ArgumentError("N10 IDs must be unique"))
        length(unique(x.field_path for x in fields)) == 5 || throw(ArgumentError("N10 paths must be unique"))
        gs = Tuple(_n10_text(g, "N10 gap") for g in gaps)
        body = (candidate_ref=candidate_ref, package_hash=package_hash,
            component_identity=component_identity, version_axes=version_axes,
            migration_receipt=migration_receipt, g3_child_refs=g3_child_refs,
            fields=Tuple(fields), gaps=gs)
        new(candidate_ref, package_hash, component_identity, version_axes,
            migration_receipt, g3_child_refs, Tuple(fields), gs, canonical_hash(body))
    end
end

semantic_view(x::N10IdentityProjectionV1) =
    (candidate_ref=x.candidate_ref, package_hash=x.package_hash,
     component_identity=x.component_identity, version_axes=x.version_axes,
     migration_receipt=x.migration_receipt, g3_child_refs=x.g3_child_refs,
     fields=x.fields, gaps=x.gaps,
     projection_hash=x.projection_hash)

_n10_expected_identity_hash(p::N10IdentityProjectionV1) =
    canonical_hash((candidate_ref=p.candidate_ref, identity=p.component_identity,
        axes=p.version_axes)).value

_n10_expected_package_hash(p::N10IdentityProjectionV1) =
    canonical_hash((package_version="v5", candidate_ref=p.candidate_ref,
        component_identity=p.component_identity, version_axes=p.version_axes,
        migration_receipt=p.migration_receipt))

struct N10MutationSpecV1
    id::String
    field_path::String
    source_locator::String
    source_type::Symbol
    mutation_kind::Symbol
    expected_error::Symbol
    expected_resolution::Symbol
    expected_compile_calls::Int
    expected_provider_calls::Int
    expected_solver_calls::Int
    function N10MutationSpecV1(id, field_path, source_locator, source_type,
                               mutation_kind, expected_error, expected_resolution,
                               expected_compile_calls, expected_provider_calls,
                               expected_solver_calls)
        ec, ep, es = Int(expected_compile_calls), Int(expected_provider_calls), Int(expected_solver_calls)
        ec == 0 && ep == 0 && es == 0 || throw(ArgumentError("N10 requires zero execution calls"))
        Symbol(expected_resolution) == :fail_closed || throw(ArgumentError("N10 resolution must be fail_closed"))
        Symbol(expected_error) in (:invalid_type, :invalid_closure, :invalid_boundary) ||
            throw(ArgumentError("N10 expected error is not registered"))
        new(_n10_text(id, "N10 mutation id"), _n10_text(field_path, "N10 mutation path"),
            _n10_text(source_locator, "N10 mutation locator"), Symbol(source_type),
            Symbol(mutation_kind), Symbol(expected_error), Symbol(expected_resolution), ec, ep, es)
    end
end

struct N10InvocationCounterV1
    compile_calls::Int
    provider_calls::Int
    solver_calls::Int
end
N10InvocationCounterV1() = N10InvocationCounterV1(0, 0, 0)

struct N10ValidationResultV1
    mutation_id::String
    baseline_package_hash::Digest256
    input_hash::Digest256
    mutated_input_hash::Digest256
    candidate_ref::QualifiedRefV1
    source_ref::Any
    component_hash::Digest256
    schema_hash::Digest256
    canonicalization_hash::Digest256
    original_value::N10TypedValueV1
    mutated_value::N10TypedValueV1
    status::Symbol
    resolution::Symbol
    error_code::Symbol
    error_path::String
    detail::String
    authority_gap::String
    mutation_hash::Digest256
    compile_calls::Int
    provider_calls::Int
    solver_calls::Int
    result_hash::Digest256
end

semantic_view(x::N10ValidationResultV1) =
    (mutation_id=x.mutation_id, baseline_package_hash=x.baseline_package_hash,
     input_hash=x.input_hash, mutated_input_hash=x.mutated_input_hash,
     candidate_ref=x.candidate_ref, source_ref=x.source_ref,
     component_hash=x.component_hash, schema_hash=x.schema_hash,
     canonicalization_hash=x.canonicalization_hash,
     original_value=x.original_value, mutated_value=x.mutated_value,
     status=x.status, resolution=x.resolution, error_code=x.error_code,
     error_path=x.error_path, detail=x.detail, authority_gap=x.authority_gap,
     mutation_hash=x.mutation_hash, compile_calls=x.compile_calls,
     provider_calls=x.provider_calls, solver_calls=x.solver_calls,
     result_hash=x.result_hash)

function _n10_check_package(package::CandidateStatePackageV5)
    package.structural_status == :valid || throw(ArgumentError("N10 requires valid actual A package"))
    package.candidate_ref.version == "v5" || throw(ArgumentError("N10 candidate ref must be v5"))
    package.resolution == terminal_deferred || throw(ArgumentError("N10 preserves A deferred resolution"))
    package.claim_ceiling == none || throw(ArgumentError("N10 claim ceiling must remain none"))
    package.g1 isa MechanismGenomeV5 && package.g2 isa FieldGeometryGenomeV5 &&
        package.g3 isa RealizationControlGenomeV5 || throw(ArgumentError("N10 requires concrete A components"))
    package.g2_binding.candidate_ref == package.candidate_ref ||
        throw(ArgumentError("N10 G2 candidate binding mismatch"))
    package.g2_binding.genome_hash == package.g2.candidate_hash ||
        throw(ArgumentError("N10 G2 component hash mismatch"))
    g1 = _n10_contract_ref(package.g1, "N10 G1")
    g2 = _n10_contract_ref(package.g2, "N10 G2")
    g3 = _n10_contract_ref(package.g3, "N10 G3")
    child = package.g3.binding.contract_binding.contract_ref
    child isa GenomeContractRef || throw(ArgumentError("N10 G3 binding child ref missing"))
    all(x -> x.version == "v5", (g1, g2, g3)) || throw(ArgumentError("N10 outer refs must be v5"))
    child.version == "v2" && endswith(child.uri, "/binding") ||
        throw(ArgumentError("N10 binding child ref is not the typed v2 binding ref"))
    identity = package.component_identity
    identity.g1_ref == _n10_ref_identity(g1) || throw(ArgumentError("N10 G1 identity mismatch"))
    identity.g2_ref == _n10_ref_identity(g2) || throw(ArgumentError("N10 G2 identity mismatch"))
    identity.g3_ref == _n10_ref_identity(g3) || throw(ArgumentError("N10 G3 identity mismatch"))
    identity.g3_child_refs.binding == _n10_ref_identity(child) ||
        throw(ArgumentError("N10 G3 child identity mismatch"))
    identity.g1_genome_hash == package.g1.candidate_hash || throw(ArgumentError("N10 G1 hash mismatch"))
    identity.g2_genome_hash == package.g2.candidate_hash || throw(ArgumentError("N10 G2 hash mismatch"))
    identity.g3_genome_hash == package.g3.candidate_hash || throw(ArgumentError("N10 G3 hash mismatch"))
    identity.candidate_ref == package.candidate_ref || throw(ArgumentError("N10 identity candidate mismatch"))
    expected_g2_uri = replace(package.candidate_ref.id,
        "fusionconceptai://candidate/" => "fusionconceptai://GenomeV5/G2/")
    g2.uri == expected_g2_uri || throw(ArgumentError("N10 G2 ref is foreign to package candidate"))
    package.migration_receipt.candidate_ref == package.candidate_ref ||
        throw(ArgumentError("N10 receipt candidate mismatch"))
    package.candidate_hash == _n10_expected_package_hash(package) ||
        throw(ArgumentError("N10 package candidate hash does not recompute"))
    package.migration_receipt.candidate_identity_after == _n10_expected_identity_hash(package) ||
        throw(ArgumentError("N10 receipt identity-after does not recompute"))
    (g1, g2, g3, child)
end

"""Build the five declarations from the actual A package and no other input."""
function n10_identity_projection_from_a(package::CandidateStatePackageV5)
    g1, g2, g3, child = _n10_check_package(package)
    identity = package.component_identity
    package_hash = package.candidate_hash
    fields = (
        N10IdentityFieldV1("N10-01", "/candidate/component_identity/g1_ref/schema_hash",
            "CandidateStatePackageV5.component_identity.g1_ref.schema_hash::Digest256", :Digest256,
            g1, package.g1.candidate_hash, N10DigestValueV1(identity.g1_ref.schema_hash),
            N10DigestValueV1(g1.schema_hash)),
        N10IdentityFieldV1("N10-02", "/candidate/component_identity/g2_ref/canonicalization_hash",
            "CandidateStatePackageV5.component_identity.g2_ref.canonicalization_hash::Digest256", :Digest256,
            g2, package.g2.candidate_hash, N10DigestValueV1(identity.g2_ref.canonicalization_hash),
            N10DigestValueV1(g2.canonicalization_hash)),
        N10IdentityFieldV1("N10-03", "/g3/binding/contract_binding/contract_ref",
            "CandidateStatePackageV5.g3.binding.contract_binding.contract_ref::GenomeContractRef", :GenomeContractRef,
            child, package.g3.candidate_hash, N10RefValueV1(child),
            N10IdentityValueV1(identity.g3_child_refs.binding)),
        N10IdentityFieldV1("N10-04", "/candidate/candidate_hash",
            "CandidateStatePackageV5.candidate_hash::Digest256", :Digest256,
            package.candidate_ref, package_hash, N10DigestValueV1(package_hash),
            N10DigestValueV1(_n10_expected_package_hash(package))),
        N10IdentityFieldV1("N10-05", "/migration_receipt/candidate_identity_after",
            "GenomeV5MigrationReceipt.candidate_identity_after::String", :String,
            package.candidate_ref, package_hash, N10TextValueV1(package.migration_receipt.candidate_identity_after),
            N10TextValueV1(_n10_expected_identity_hash(package)))
    )
    N10IdentityProjectionV1(package.candidate_ref, package_hash, identity,
        package.version_axes, package.migration_receipt,
        (realization=package.g3.realization.contract_binding.contract_ref,
         control=package.g3.control.contract_binding.contract_ref, binding=child), fields,
        ("legacy_v4_receipt_provenance_absent_terminal_deferred",))
end

function _n10_field(p::N10IdentityProjectionV1, id::AbstractString)
    first(x for x in p.fields if x.id == String(id))
end

function _n10_changed_digest(original::Digest256, other::Digest256)
    original == other && throw(ArgumentError("N10 digest mutation did not change value"))
    other
end

function _n10_mutated(p::N10IdentityProjectionV1, spec::N10MutationSpecV1)
    f = _n10_field(p, spec.id)
    if spec.id == "N10-01"
        other = p.component_identity.g2_ref.schema_hash
        return _n10_rebuild(p, spec.id, N10DigestValueV1(_n10_changed_digest(f.original_value.value, other)))
    elseif spec.id == "N10-02"
        other = p.component_identity.g1_ref.canonicalization_hash
        return _n10_rebuild(p, spec.id, N10DigestValueV1(_n10_changed_digest(f.original_value.value, other)))
    elseif spec.id == "N10-03"
        # An actual sibling child ref is a typed, candidate-bound value, but it
        # is the wrong G3 child layer for this declaration.
        return _n10_rebuild(p, spec.id, N10RefValueV1(p.g3_child_refs.control))
    elseif spec.id == "N10-04"
        attempted = canonical_hash((baseline=p.package_hash, mutation="N10-04-candidate-hash-attempt"))
        return _n10_rebuild(p, spec.id, N10DigestValueV1(_n10_changed_digest(f.original_value.value, attempted)))
    elseif spec.id == "N10-05"
        attempted = canonical_hash((baseline=f.original_value.value, mutation="N10-05-fresh-receipt-attempt")).value
        attempted == f.original_value.value && throw(ArgumentError("N10 receipt mutation did not change value"))
        return _n10_rebuild(p, spec.id, N10TextValueV1(attempted))
    end
    throw(ArgumentError("unknown N10 mutation $(spec.id)"))
end

function _n10_rebuild(p::N10IdentityProjectionV1, id::AbstractString, value::N10TypedValueV1)
    fields = Tuple(x.id == String(id) ? N10IdentityFieldV1(x.id, x.field_path,
        x.source_locator, x.source_type, x.source_ref, x.component_hash,
        x.original_value, x.authoritative_value) : x for x in p.fields)
    # Store the attempted typed value in the field while preserving the source
    # declaration and authoritative comparison value.
    fields = Tuple(x.id == String(id) ? N10IdentityFieldV1(x.id, x.field_path,
        x.source_locator, x.source_type, x.source_ref, x.component_hash,
        value, x.authoritative_value) : x for x in fields)
    N10IdentityProjectionV1(p.candidate_ref, p.package_hash, p.component_identity,
        p.version_axes, p.migration_receipt, p.g3_child_refs, fields, p.gaps)
end

function _n10_classify(p::N10IdentityProjectionV1, q::N10IdentityProjectionV1, spec::N10MutationSpecV1)
    f = _n10_field(q, spec.id)
    if spec.id == "N10-01"
        f.original_value isa N10DigestValueV1 && f.original_value.value == f.authoritative_value.value &&
            return (:valid, :none, "")
        return (:fail_closed, :invalid_type, "g1_identity_schema_hash_mismatch")
    elseif spec.id == "N10-02"
        f.original_value isa N10DigestValueV1 && f.original_value.value == f.authoritative_value.value &&
            return (:valid, :none, "")
        return (:fail_closed, :invalid_type, "g2_identity_canonicalization_hash_mismatch")
    elseif spec.id == "N10-03"
        f.original_value isa N10RefValueV1 || return (:fail_closed, :invalid_type, "g3_child_ref_type_mismatch")
        expected = f.authoritative_value.value
        _n10_ref_identity(f.original_value.value) == expected && return (:valid, :none, "")
        return (:fail_closed, :invalid_type, "g3_binding_child_identity_mismatch")
    elseif spec.id == "N10-04"
        f.original_value isa N10DigestValueV1 || return (:fail_closed, :invalid_type, "candidate_hash_type_mismatch")
        f.original_value.value == _n10_expected_package_hash(p) && return (:valid, :none, "")
        return (:fail_closed, :invalid_type, "candidate_hash_recompute_mismatch")
    elseif spec.id == "N10-05"
        f.original_value isa N10TextValueV1 || return (:fail_closed, :invalid_type, "receipt_identity_after_type_mismatch")
        f.original_value.value == _n10_expected_identity_hash(p) && return (:valid, :none, "")
        return (:fail_closed, :invalid_type, "fresh_receipt_candidate_identity_after_mismatch")
    end
    throw(ArgumentError("unknown N10 classifier id $(spec.id)"))
end

function _n10_counter(counter)
    counter === nothing && return N10InvocationCounterV1()
    all(_n10_has(counter, x) for x in (:compile_calls, :provider_calls, :solver_calls)) ||
        throw(ArgumentError("N10 counter fields missing"))
    c = N10InvocationCounterV1(Int(counter.compile_calls), Int(counter.provider_calls), Int(counter.solver_calls))
    c.compile_calls == 0 && c.provider_calls == 0 && c.solver_calls == 0 ||
        throw(ArgumentError("N10 fail-closed path observed execution calls"))
    c
end

"""Classify a changed typed field without consulting expected_error metadata."""
function n10_validate_mutation(p::N10IdentityProjectionV1, spec::N10MutationSpecV1;
                               counter=N10InvocationCounterV1())
    field = _n10_field(p, spec.id)
    field.field_path == spec.field_path && field.source_locator == spec.source_locator &&
        field.source_type == spec.source_type || throw(ArgumentError("N10 metadata does not bind source field"))
    c = _n10_counter(counter)
    q = _n10_mutated(p, spec)
    status, code, detail = _n10_classify(p, q, spec)
    status == :fail_closed || throw(ArgumentError("N10 mutation did not produce a structural mismatch"))
    mutated = _n10_field(q, spec.id)
    mutation_hash = canonical_hash((mutation_id=spec.id, baseline=p.package_hash,
        original_value=field.original_value, mutated_value=mutated.original_value,
        schema_hash=n10_schema_hash(), canonicalization_hash=n10_canonicalization_hash()))
    result_hash = canonical_hash((mutation_id=spec.id, baseline_package_hash=p.package_hash,
        input_hash=p.projection_hash, mutated_input_hash=q.projection_hash,
        source_ref=field.source_ref, component_hash=field.component_hash,
        schema_hash=field.schema_hash, canonicalization_hash=field.canonicalization_hash,
        original_value=field.original_value, mutated_value=mutated.original_value,
        status=status, resolution=:fail_closed, error_code=code, error_path=field.field_path,
        detail=detail, authority_gap="", mutation_hash=mutation_hash,
        compile_calls=c.compile_calls, provider_calls=c.provider_calls, solver_calls=c.solver_calls,
        scope=:schema_validation_only))
    N10ValidationResultV1(spec.id, p.package_hash, p.projection_hash, q.projection_hash,
        p.candidate_ref, field.source_ref, field.component_hash, field.schema_hash,
        field.canonicalization_hash, field.original_value, mutated.original_value,
        status, :fail_closed, code, field.field_path, detail, "", mutation_hash,
        c.compile_calls, c.provider_calls, c.solver_calls, result_hash)
end
