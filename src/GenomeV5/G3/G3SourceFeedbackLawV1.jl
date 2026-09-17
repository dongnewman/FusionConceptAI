"""UP2-01-G3-SOURCE-FEEDBACK-V1 candidate-owned source/feedback law.

This is an additive preparation slice.  It describes a typed source -> field ->
return/heat -> ledger relation and typed targets for later G1/G2 rebinding.
It deliberately has no compiler, provider, mesh, solver, or physical execution
entry point.  Missing external authority is terminal_deferred.
"""

const G3_SF_V1_SCHEMA_ID = "GenomeV5/G3/G3SourceFeedbackLawV1"
const G3_SF_V1_VERSION = "v1"
const G3_SF_V1_CLAIM_CEILING = :contract_only
const G3_SF_V1_ALLOWED_DIRECTIONS = (:in, :out, :bidirectional)
const G3_SF_V1_AUTHORITY_STATUSES = (:actual, :missing, :historical_absent, :stale, :contradictory)
const G3_SF_V1_ATTESTATIONS = (:unattested, :trusted_receipt)
const G3_SF_V1_FEEDBACK_LAYERS = (:G1, :G2)

const _G3_SF_V1_SCHEMA_SOURCE = """
schema_id=GenomeV5/G3/G3SourceFeedbackLawV1
version=v1
fields=candidate_ref,source_id,owner_scope,endpoints,law,ledger_entries,ledger_closure,feedback_targets,upstream_authority,declaration_hash
endpoint=id,role,unit,direction,sign,owner_scope
law=typed conservative_split(field_fraction,return_fraction,heat_fraction); typed heat_relation; typed ledger_relation
ledger=declared coefficient*source_power entries; source=field+return+heat; ledger residual=0; all entries share explicit unit and owner scope
feedback=target_layer,target_path,quantity,unit,direction,sign,source_id,authority_ref,authority_hash,authority_status
authority=actual requires same-candidate G1/G2 ref and hash; absent authority is terminal_deferred
contradiction=typed fail_closed; unexpected exception=program_exception
execution=provider_calls=0,compiler_calls=0,mesh_calls=0,solver_calls=0,physical_evidence=false
"""
const _G3_SF_V1_CANONICAL_SOURCE = """
encoding=UTF-8;line_endings=LF;tuple_order=declared;symbols=ordinal names;rationals=normalized
identity=all candidate-owned endpoints/law/ledger/feedback/authority content; edits rebuild declaration_hash
"""
const _G3_SF_V1_PROFILE_SOURCE = """
scope=contract-only typed G3 source/return/heat/ledger and feedback target declaration
requires=unit equality, direction/sign consistency, owner scope, exact energy and ledger closure, authority status
missing_authority=terminal_deferred; contradiction=fail_closed; unexpected_exception=program_exception
"""

g3_sf_schema_hash_v1() = digest256_text(_G3_SF_V1_SCHEMA_SOURCE)
g3_sf_canonicalization_hash_v1() = digest256_text(_G3_SF_V1_CANONICAL_SOURCE)
g3_sf_profile_hash_v1() = digest256_text(_G3_SF_V1_PROFILE_SOURCE)

_g3sf_text(x, field) = begin
    text = String(x)
    !isempty(text) && isvalid(text) || throw(ArgumentError("$field must be non-empty UTF-8"))
    text
end
_g3sf_unit(x, field) = x isa UnitSignature ? x : throw(ArgumentError("$field must be UnitSignature"))
_g3sf_ref(x, field) = x isa QualifiedRefV1 ? x : throw(ArgumentError("$field must be QualifiedRefV1"))
_g3sf_digest(x, field) = x isa Digest256 ? x : throw(ArgumentError("$field must be Digest256"))
_g3sf_rat(x, field) = begin
    x isa Bool && throw(ArgumentError("$field must be exact Rational"))
    x isa Rational || x isa Integer || throw(ArgumentError("$field must be exact Rational or integer"))
    Rational{Int64}(x)
end
_g3sf_direction(x, field) = begin
    s = x isa Symbol ? x : Symbol(x)
    s in G3_SF_V1_ALLOWED_DIRECTIONS || throw(ArgumentError("$field has invalid direction"))
    s
end
_g3sf_sign(x, field) = begin
    x isa Bool && throw(ArgumentError("$field must be +1 or -1"))
    x isa Integer || throw(ArgumentError("$field must be +1 or -1"))
    x in (-1, 1) || throw(ArgumentError("$field must be +1 or -1"))
    Int8(x)
end
_g3sf_tuple(x, field) = begin
    x isa Tuple || throw(ArgumentError("$field must be an immutable tuple"))
    x
end

struct G3SFAuthorityV1
    layer::Symbol
    candidate_ref::QualifiedRefV1
    contract_ref::Union{Nothing,GenomeContractRef}
    contract_hash::Union{Nothing,Digest256}
    source_ref::Union{Nothing,QualifiedRefV1}
    source_bytes::Union{Nothing,Int}
    source_sha256::Union{Nothing,Digest256}
    status::Symbol
    attestation::Symbol
    function G3SFAuthorityV1(layer::Any, candidate_ref::Any, contract_ref::Any,
            contract_hash::Any, status::Any; attestation=:unattested,
            source_ref=nothing, source_bytes=nothing, source_sha256=nothing)
        l = layer isa Symbol ? layer : Symbol(layer)
        l in G3_SF_V1_FEEDBACK_LAYERS || throw(ArgumentError("authority layer must be G1 or G2"))
        c = _g3sf_ref(candidate_ref, "authority candidate_ref")
        c.version == "v5" || throw(ArgumentError("authority candidate_ref must use v5"))
        s = status isa Symbol ? status : Symbol(status)
        s in G3_SF_V1_AUTHORITY_STATUSES || throw(ArgumentError("unknown authority status"))
        a = attestation isa Symbol ? attestation : Symbol(attestation)
        a in G3_SF_V1_ATTESTATIONS || throw(ArgumentError("unknown authority attestation"))
        if s === :actual
            contract_ref isa GenomeContractRef || throw(ArgumentError("actual authority requires contract_ref"))
            contract_hash isa Digest256 || throw(ArgumentError("actual authority requires contract_hash"))
            contract_ref.version == "v5" || throw(ArgumentError("actual authority contract must use v5"))
        else
            contract_ref === nothing || contract_ref isa GenomeContractRef ||
                throw(ArgumentError("authority contract_ref must be nothing or GenomeContractRef"))
            contract_hash === nothing || contract_hash isa Digest256 ||
                throw(ArgumentError("authority contract_hash must be nothing or Digest256"))
        end
        (contract_ref === nothing) == (contract_hash === nothing) ||
            throw(ArgumentError("authority contract_ref and contract_hash must be paired"))
        source_ref === nothing || source_ref isa QualifiedRefV1 ||
            throw(ArgumentError("authority source_ref must be nothing or QualifiedRefV1"))
        source_bytes === nothing || (source_bytes isa Integer && !(source_bytes isa Bool) && source_bytes >= 0) ||
            throw(ArgumentError("authority source_bytes must be nothing or a non-negative integer"))
        source_sha256 === nothing || source_sha256 isa Digest256 ||
            throw(ArgumentError("authority source_sha256 must be nothing or Digest256"))
        source_material = (source_ref === nothing, source_bytes === nothing, source_sha256 === nothing)
        all(source_material) || all(!x for x in source_material) ||
            throw(ArgumentError("authority source identity, bytes, and hash must be paired"))
        new(l, c, contract_ref, contract_hash, source_ref,
            source_bytes === nothing ? nothing : Int(source_bytes), source_sha256, s, a)
    end
end

function g3_sf_authority_content_hash_v1(layer::Any, candidate_ref::Any,
        contract_ref::Any, source_ref::Any, source_bytes::Any, source_sha256::Any)
    l = layer isa Symbol ? layer : Symbol(layer)
    l in G3_SF_V1_FEEDBACK_LAYERS || throw(ArgumentError("authority layer must be G1 or G2"))
    c = _g3sf_ref(candidate_ref, "authority candidate_ref")
    contract = contract_ref isa GenomeContractRef ? contract_ref :
        throw(ArgumentError("authority contract_ref must be GenomeContractRef"))
    source = source_ref isa QualifiedRefV1 ? source_ref :
        throw(ArgumentError("authority source_ref must be QualifiedRefV1"))
    bytes = source_bytes isa Integer && !(source_bytes isa Bool) && source_bytes >= 0 ? Int(source_bytes) :
        throw(ArgumentError("authority source_bytes must be non-negative integer"))
    digest = _g3sf_digest(source_sha256, "authority source_sha256")
    canonical_hash((domain="G3SF-authority-content-v1", layer=l, candidate_ref=c,
        contract_ref=contract, source_ref=source, source_bytes=bytes, source_sha256=digest))
end

struct G3SFConservativeSplitV1
    field_fraction::Rational{Int64}
    return_fraction::Rational{Int64}
    heat_fraction::Rational{Int64}
    function G3SFConservativeSplitV1(field_fraction::Any, return_fraction::Any, heat_fraction::Any)
        f = _g3sf_rat(field_fraction, "field_fraction")
        r = _g3sf_rat(return_fraction, "return_fraction")
        h = _g3sf_rat(heat_fraction, "heat_fraction")
        0 <= f <= 1 && 0 <= r <= 1 && 0 <= h <= 1 ||
            throw(ArgumentError("conservative split fractions must be in [0,1]"))
        f + r + h == 1 || throw(ArgumentError("conservative split fractions must sum to one"))
        new(f, r, h)
    end
end

struct G3SFHeatRelationV1
    source_role::Symbol
    heat_role::Symbol
    fraction::Rational{Int64}
    function G3SFHeatRelationV1(source_role::Any, heat_role::Any, fraction::Any)
        s = source_role isa Symbol ? source_role : Symbol(source_role)
        h = heat_role isa Symbol ? heat_role : Symbol(heat_role)
        s === :source && h === :heat || throw(ArgumentError("heat relation roles must be source and heat"))
        f = _g3sf_rat(fraction, "heat relation fraction")
        0 <= f <= 1 || throw(ArgumentError("heat relation fraction must be in [0,1]"))
        new(s, h, f)
    end
end

struct G3SFLedgerRelationV1
    entry_roles::Tuple{Vararg{Symbol}}
    expected_residual::Rational{Int64}
    function G3SFLedgerRelationV1(entry_roles::Any, expected_residual::Any)
        roles = _g3sf_tuple(entry_roles, "ledger relation entry_roles")
        all(x -> x isa Symbol && x in (:source, :field, :return, :heat), roles) ||
            throw(ArgumentError("ledger relation roles are invalid"))
        Tuple(sort!(collect(roles))) == (:field, :heat, :return, :source) ||
            throw(ArgumentError("ledger relation must contain source, field, return and heat exactly once"))
        residual = _g3sf_rat(expected_residual, "ledger relation expected_residual")
        residual == 0 || throw(ArgumentError("ledger relation expected residual must be zero"))
        new(Tuple(roles), residual)
    end
end

semantic_view(x::G3SFConservativeSplitV1) =
    (field_fraction=x.field_fraction, return_fraction=x.return_fraction, heat_fraction=x.heat_fraction)
semantic_view(x::G3SFHeatRelationV1) =
    (source_role=x.source_role, heat_role=x.heat_role, fraction=x.fraction)
semantic_view(x::G3SFLedgerRelationV1) =
    (entry_roles=x.entry_roles, expected_residual=x.expected_residual)

struct G3SFEndpointV1
    endpoint_id::String
    role::Symbol
    unit::UnitSignature
    direction::Symbol
    sign::Int8
    owner_scope::String
    function G3SFEndpointV1(endpoint_id::Any, role::Any, unit::Any,
            direction::Any, sign::Any, owner_scope::Any)
        r = role isa Symbol ? role : Symbol(role)
        r in (:source, :field, :return, :heat, :ledger) || throw(ArgumentError("unknown endpoint role"))
        new(_g3sf_text(endpoint_id, "endpoint_id"), r, _g3sf_unit(unit, "endpoint unit"),
            _g3sf_direction(direction, "endpoint direction"), _g3sf_sign(sign, "endpoint sign"),
            _g3sf_text(owner_scope, "endpoint owner_scope"))
    end
end

struct G3SFLawV1
    law_id::String
    source_endpoint_id::String
    field_endpoint_id::String
    return_endpoint_id::String
    heat_endpoint_id::String
    conservative_split::G3SFConservativeSplitV1
    heat_relation::G3SFHeatRelationV1
    ledger_relation::G3SFLedgerRelationV1
    owner_scope::String
    function G3SFLawV1(law_id::Any, source_endpoint_id::Any, field_endpoint_id::Any,
            return_endpoint_id::Any, heat_endpoint_id::Any, efficiency::Any,
            heat_fraction::Any, conservative_split::Any, heat_relation::Any,
            ledger_relation::Any, owner_scope::Any)
        split = conservative_split isa G3SFConservativeSplitV1 ? conservative_split :
            throw(ArgumentError("law requires typed conservative split"))
        heat = heat_relation isa G3SFHeatRelationV1 ? heat_relation :
            throw(ArgumentError("law requires typed heat relation"))
        ledger = ledger_relation isa G3SFLedgerRelationV1 ? ledger_relation :
            throw(ArgumentError("law requires typed ledger relation"))
        split.field_fraction == _g3sf_rat(efficiency, "efficiency") ||
            throw(ArgumentError("conservative split field fraction disagrees with efficiency"))
        split.heat_fraction == _g3sf_rat(heat_fraction, "heat_fraction") ||
            throw(ArgumentError("conservative split heat fraction disagrees with heat_fraction"))
        heat.fraction == split.heat_fraction || throw(ArgumentError("heat relation fraction disagrees with split"))
        new(_g3sf_text(law_id, "law_id"), _g3sf_text(source_endpoint_id, "source_endpoint_id"),
            _g3sf_text(field_endpoint_id, "field_endpoint_id"), _g3sf_text(return_endpoint_id, "return_endpoint_id"),
            _g3sf_text(heat_endpoint_id, "heat_endpoint_id"), split, heat, ledger,
            _g3sf_text(owner_scope, "law owner_scope"))
    end
end

struct G3SFLedgerEntryV1
    entry_id::String
    endpoint_id::String
    unit::UnitSignature
    direction::Symbol
    sign::Int8
    effect::Symbol
    coefficient::Rational{Int64}
    owner_scope::String
    function G3SFLedgerEntryV1(entry_id::Any, endpoint_id::Any, unit::Any,
            direction::Any, sign::Any, effect::Any, coefficient::Any, owner_scope::Any)
        e = effect isa Symbol ? effect : Symbol(effect)
        e in (:source, :field, :return, :heat) || throw(ArgumentError("unknown ledger effect"))
        new(_g3sf_text(entry_id, "entry_id"), _g3sf_text(endpoint_id, "entry endpoint_id"),
            _g3sf_unit(unit, "ledger unit"), _g3sf_direction(direction, "ledger direction"),
            _g3sf_sign(sign, "ledger sign"), e, _g3sf_rat(coefficient, "ledger coefficient"),
            _g3sf_text(owner_scope, "ledger owner_scope"))
    end
end

struct G3SFLedgerClosureV1
    closure_id::String
    entry_ids::Tuple{Vararg{String}}
    expected_residual::Rational{Int64}
    unit::UnitSignature
    owner_scope::String
    function G3SFLedgerClosureV1(closure_id::Any, entry_ids::Any,
            expected_residual::Any, unit::Any, owner_scope::Any)
        ids = _g3sf_tuple(entry_ids, "closure entry_ids")
        !isempty(ids) && all(x -> x isa AbstractString && !isempty(String(x)), ids) ||
            throw(ArgumentError("closure entry_ids must be non-empty strings"))
        new(_g3sf_text(closure_id, "closure_id"), Tuple(String.(ids)),
            _g3sf_rat(expected_residual, "expected_residual"), _g3sf_unit(unit, "closure unit"),
            _g3sf_text(owner_scope, "closure owner_scope"))
    end
end

struct G3SFFeedbackTargetV1
    target_id::String
    target_layer::Symbol
    target_path::String
    quantity::Symbol
    unit::UnitSignature
    direction::Symbol
    sign::Int8
    source_id::String
    owner_scope::String
    authority::G3SFAuthorityV1
    function G3SFFeedbackTargetV1(target_id::Any, target_layer::Any, target_path::Any,
            quantity::Any, unit::Any, direction::Any, sign::Any, source_id::Any,
            owner_scope::Any, authority::Any)
        l = target_layer isa Symbol ? target_layer : Symbol(target_layer)
        l in G3_SF_V1_FEEDBACK_LAYERS || throw(ArgumentError("feedback target_layer must be G1 or G2"))
        q = quantity isa Symbol ? quantity : Symbol(quantity)
        q in (:residual, :loss, :thermal_load, :deformation) || throw(ArgumentError("unknown feedback quantity"))
        authority isa G3SFAuthorityV1 || throw(ArgumentError("feedback authority must be typed"))
        authority.layer == l || throw(ArgumentError("feedback authority layer mismatch"))
        new(_g3sf_text(target_id, "target_id"), l, _g3sf_text(target_path, "target_path"), q,
            _g3sf_unit(unit, "feedback unit"), _g3sf_direction(direction, "feedback direction"),
            _g3sf_sign(sign, "feedback sign"), _g3sf_text(source_id, "feedback source_id"),
            _g3sf_text(owner_scope, "feedback owner_scope"), authority)
    end
end

struct G3SFDeclarationV1
    candidate_ref::QualifiedRefV1
    source_id::String
    owner_scope::String
    endpoints::Tuple{Vararg{G3SFEndpointV1}}
    law::G3SFLawV1
    ledger_entries::Tuple{Vararg{G3SFLedgerEntryV1}}
    ledger_closure::G3SFLedgerClosureV1
    feedback_targets::Tuple{Vararg{G3SFFeedbackTargetV1}}
    upstream_authority::Tuple{Vararg{G3SFAuthorityV1}}
    declaration_hash::Digest256
end

semantic_view(x::G3SFAuthorityV1) = (layer=x.layer, candidate_ref=x.candidate_ref,
    contract_ref=x.contract_ref, contract_hash=x.contract_hash, source_ref=x.source_ref,
    source_bytes=x.source_bytes, source_sha256=x.source_sha256, status=x.status, attestation=x.attestation)
semantic_view(x::G3SFEndpointV1) = (endpoint_id=x.endpoint_id, role=x.role, unit=x.unit,
    direction=x.direction, sign=x.sign, owner_scope=x.owner_scope)
semantic_view(x::G3SFLawV1) = (law_id=x.law_id, source_endpoint_id=x.source_endpoint_id,
    field_endpoint_id=x.field_endpoint_id, return_endpoint_id=x.return_endpoint_id,
    heat_endpoint_id=x.heat_endpoint_id, conservative_split=x.conservative_split,
    heat_relation=x.heat_relation, ledger_relation=x.ledger_relation, owner_scope=x.owner_scope)
semantic_view(x::G3SFLedgerEntryV1) = (entry_id=x.entry_id, endpoint_id=x.endpoint_id,
    unit=x.unit, direction=x.direction, sign=x.sign, effect=x.effect, coefficient=x.coefficient,
    owner_scope=x.owner_scope)
semantic_view(x::G3SFLedgerClosureV1) = (closure_id=x.closure_id, entry_ids=x.entry_ids,
    expected_residual=x.expected_residual, unit=x.unit, owner_scope=x.owner_scope)
semantic_view(x::G3SFFeedbackTargetV1) = (target_id=x.target_id, target_layer=x.target_layer,
    target_path=x.target_path, quantity=x.quantity, unit=x.unit, direction=x.direction, sign=x.sign,
    source_id=x.source_id, owner_scope=x.owner_scope, authority=x.authority)

function _g3sf_body(x::G3SFDeclarationV1)
    (schema_id=G3_SF_V1_SCHEMA_ID, version=G3_SF_V1_VERSION,
     candidate_ref=x.candidate_ref, source_id=x.source_id, owner_scope=x.owner_scope,
     endpoints=x.endpoints, law=x.law, ledger_entries=x.ledger_entries,
     ledger_closure=x.ledger_closure, feedback_targets=x.feedback_targets,
     upstream_authority=x.upstream_authority)
end
semantic_view(x::G3SFDeclarationV1) = merge(_g3sf_body(x), (declaration_hash=x.declaration_hash,))
canonical_json(x::Union{G3SFAuthorityV1,G3SFEndpointV1,G3SFLawV1,G3SFLedgerEntryV1,
                        G3SFLedgerClosureV1,G3SFFeedbackTargetV1,G3SFDeclarationV1}) =
    canonical_json(semantic_view(x))

function g3_sf_declaration_v1(candidate_ref::Any, source_id::Any, owner_scope::Any,
        endpoints::Any, law::Any, ledger_entries::Any, ledger_closure::Any,
        feedback_targets::Any, upstream_authority::Any)
    c = _g3sf_ref(candidate_ref, "candidate_ref")
    c.version == "v5" || throw(ArgumentError("candidate_ref must use v5"))
    eps = _g3sf_tuple(endpoints, "endpoints")
    all(x -> x isa G3SFEndpointV1, eps) || throw(ArgumentError("endpoints must be typed"))
    entries = _g3sf_tuple(ledger_entries, "ledger_entries")
    all(x -> x isa G3SFLedgerEntryV1, entries) || throw(ArgumentError("ledger_entries must be typed"))
    targets = _g3sf_tuple(feedback_targets, "feedback_targets")
    all(x -> x isa G3SFFeedbackTargetV1, targets) || throw(ArgumentError("feedback_targets must be typed"))
    authorities = _g3sf_tuple(upstream_authority, "upstream_authority")
    all(x -> x isa G3SFAuthorityV1, authorities) || throw(ArgumentError("upstream_authority must be typed"))
    law isa G3SFLawV1 || throw(ArgumentError("law must be G3SFLawV1"))
    ledger_closure isa G3SFLedgerClosureV1 || throw(ArgumentError("ledger_closure must be typed"))
    draft = G3SFDeclarationV1(c, _g3sf_text(source_id, "source_id"), _g3sf_text(owner_scope, "owner_scope"),
        Tuple(eps), law, Tuple(entries), ledger_closure, Tuple(targets), Tuple(authorities),
        Digest256(repeat("0", 64)))
    G3SFDeclarationV1(draft.candidate_ref, draft.source_id, draft.owner_scope, draft.endpoints,
        draft.law, draft.ledger_entries, draft.ledger_closure, draft.feedback_targets,
        draft.upstream_authority, canonical_hash(_g3sf_body(draft)))
end

g3_sf_declaration_hash_v1(x::G3SFDeclarationV1) = x.declaration_hash

function g3_sf_evaluate_v1(x::G3SFDeclarationV1, source_power::Any)
    p = _g3sf_rat(source_power, "source_power")
    status, errors = g3_sf_validate_v1(x)
    status == :valid || throw(ArgumentError("cannot evaluate invalid G3 source/feedback declaration: $(join(errors, ","))"))
    entries = Dict(e.effect => e.coefficient * p for e in x.ledger_entries)
    source = entries[:source]
    field = -entries[:field]
    returned = -entries[:return]
    heat = -entries[:heat]
    ledger = (source=source, field=-field, return_power=-returned, heat=-heat)
    (source_power=source, field_power=field, return_power=returned, heat_power=heat,
     ledger=ledger, energy_residual=source - field - returned - heat,
     ledger_residual=sum(values(ledger)))
end

function g3_sf_validate_v1(x::G3SFDeclarationV1)
    errors = String[]
    x.declaration_hash == canonical_hash(_g3sf_body(x)) || push!(errors, "declaration_hash_mismatch")
    ids = Tuple(e.endpoint_id for e in x.endpoints)
    length(unique(ids)) == length(ids) || push!(errors, "duplicate_endpoint_id")
    endpoint_map = Dict(e.endpoint_id => e for e in x.endpoints)
    endpoint_roles = Tuple(e.role for e in x.endpoints)
    for role in (:source, :field, :return, :heat, :ledger)
        count(==(role), endpoint_roles) == 1 ||
            push!(errors, "endpoint_role_count_mismatch:" * String(role))
    end
    required = ((:source, x.law.source_endpoint_id), (:field, x.law.field_endpoint_id),
                (:return, x.law.return_endpoint_id), (:heat, x.law.heat_endpoint_id))
    for (role, id) in required
        haskey(endpoint_map, id) || push!(errors, "law_endpoint_missing:" * String(role))
        haskey(endpoint_map, id) && endpoint_map[id].role == role ||
            (haskey(endpoint_map, id) && push!(errors, "law_endpoint_role_mismatch:" * String(role)))
    end
    x.law.owner_scope == x.owner_scope || push!(errors, "law_owner_scope_mismatch")
    for e in x.endpoints
        e.owner_scope == x.owner_scope || push!(errors, "endpoint_owner_scope_mismatch:" * e.endpoint_id)
    end
    if all(haskey(endpoint_map, id) for (_, id) in required)
        src = endpoint_map[x.law.source_endpoint_id]
        field = endpoint_map[x.law.field_endpoint_id]
        ret = endpoint_map[x.law.return_endpoint_id]
        heat = endpoint_map[x.law.heat_endpoint_id]
        all(e.unit == src.unit for e in (field, ret, heat)) || push!(errors, "source_output_unit_mismatch")
        src.direction in (:out, :bidirectional) || push!(errors, "source_direction_invalid")
        all(e.direction === :out for e in (field, ret, heat)) || push!(errors, "output_direction_invalid")
        all(e.sign == -1 for e in (field, ret, heat)) || push!(errors, "output_sign_invalid")
        src.sign == 1 || push!(errors, "source_sign_invalid")
    end
    entry_ids = Tuple(e.entry_id for e in x.ledger_entries)
    length(unique(entry_ids)) == length(entry_ids) || push!(errors, "duplicate_ledger_entry_id")
    effects = Tuple(e.effect for e in x.ledger_entries)
    length(unique(effects)) == length(effects) || push!(errors, "duplicate_ledger_effect")
    Set(effects) == Set((:source, :field, :return, :heat)) || push!(errors, "ledger_effect_set_mismatch")
    length(unique(x.ledger_closure.entry_ids)) == length(x.ledger_closure.entry_ids) ||
        push!(errors, "duplicate_ledger_closure_entry_id")
    closure_ids = Set(x.ledger_closure.entry_ids)
    closure_ids == Set(entry_ids) || push!(errors, "ledger_closure_entry_set_mismatch")
    x.ledger_closure.expected_residual == 0 || push!(errors, "ledger_expected_residual_not_zero")
    if haskey(endpoint_map, x.law.source_endpoint_id)
        x.ledger_closure.unit == endpoint_map[x.law.source_endpoint_id].unit ||
            push!(errors, "ledger_closure_unit_mismatch")
    end
    x.ledger_closure.owner_scope == x.owner_scope || push!(errors, "ledger_closure_owner_scope_mismatch")
    for e in x.ledger_entries
        haskey(endpoint_map, e.endpoint_id) || push!(errors, "ledger_endpoint_missing:" * e.entry_id)
        if haskey(endpoint_map, e.endpoint_id)
            endpoint = endpoint_map[e.endpoint_id]
            e.unit == endpoint.unit || push!(errors, "ledger_unit_mismatch:" * e.entry_id)
            e.effect == endpoint.role || push!(errors, "ledger_effect_role_mismatch:" * e.entry_id)
            e.direction == endpoint.direction || push!(errors, "ledger_direction_mismatch:" * e.entry_id)
            e.sign == endpoint.sign || push!(errors, "ledger_sign_mismatch:" * e.entry_id)
            expected_coefficient = e.effect === :source ? 1 // 1 :
                e.effect === :field ? -x.law.conservative_split.field_fraction :
                e.effect === :return ? -x.law.conservative_split.return_fraction :
                -x.law.conservative_split.heat_fraction
            e.coefficient == expected_coefficient || push!(errors, "ledger_coefficient_mismatch:" * e.entry_id)
        end
        e.owner_scope == x.owner_scope || push!(errors, "ledger_owner_scope_mismatch:" * e.entry_id)
    end
    authority_layers = Tuple(a.layer for a in x.upstream_authority)
    length(unique(authority_layers)) == length(authority_layers) ||
        push!(errors, "duplicate_upstream_authority_layer")
    for layer in G3_SF_V1_FEEDBACK_LAYERS
        count(==(layer), authority_layers) == 1 ||
            push!(errors, count(==(layer), authority_layers) == 0 ?
                "missing_upstream_authority_layer:" * String(layer) :
                "ambiguous_upstream_authority_layer:" * String(layer))
    end
    all(a.candidate_ref == x.candidate_ref for a in x.upstream_authority) ||
        push!(errors, "upstream_candidate_binding_mismatch")
    Set(a.layer for a in x.upstream_authority) == Set(G3_SF_V1_FEEDBACK_LAYERS) ||
        push!(errors, "upstream_authority_layer_set_mismatch")
    for authority in x.upstream_authority
        prefix = "fusionconceptai://GenomeV5/" * String(authority.layer) * "/"
        has_material = authority.contract_ref !== nothing || authority.contract_hash !== nothing ||
            authority.source_ref !== nothing || authority.source_bytes !== nothing || authority.source_sha256 !== nothing
        if authority.status !== :actual && has_material
            push!(errors, "authority_status_body_mismatch:" * String(authority.layer))
        end
        if authority.contract_ref !== nothing
            startswith(authority.contract_ref.uri, prefix) ||
                push!(errors, "authority_contract_namespace_mismatch:" * String(authority.layer))
        end
        if authority.source_ref !== nothing
            startswith(authority.source_ref.id, prefix) ||
                push!(errors, "authority_source_namespace_mismatch:" * String(authority.layer))
            authority.source_ref.version == "v1" ||
                push!(errors, "authority_source_version_mismatch:" * String(authority.layer))
        end
        if authority.status === :actual
            authority.contract_ref !== nothing && authority.contract_hash !== nothing &&
                authority.source_ref !== nothing && authority.source_bytes !== nothing &&
                authority.source_sha256 !== nothing ||
                push!(errors, "actual_authority_source_material_missing:" * String(authority.layer))
            if authority.contract_ref !== nothing && authority.contract_hash !== nothing &&
                    authority.source_ref !== nothing && authority.source_bytes !== nothing &&
                    authority.source_sha256 !== nothing
                expected_hash = g3_sf_authority_content_hash_v1(authority.layer, authority.candidate_ref,
                    authority.contract_ref, authority.source_ref, authority.source_bytes,
                    authority.source_sha256)
                authority.contract_hash == expected_hash ||
                    push!(errors, "authority_contract_hash_source_binding_mismatch:" * String(authority.layer))
            end
        end
        authority.status === :contradictory &&
            push!(errors, "authority_contradiction:" * String(authority.layer))
        authority.status === :actual && authority.attestation !== :trusted_receipt &&
            push!(errors, "unattested_authority:" * String(authority.layer))
    end
    target_ids = Tuple(target.target_id for target in x.feedback_targets)
    length(unique(target_ids)) == length(target_ids) || push!(errors, "duplicate_feedback_target_id")
    target_keys = Tuple((target.target_layer, target.target_path, target.quantity, target.unit,
        target.direction, target.sign, target.source_id, target.owner_scope) for target in x.feedback_targets)
    length(unique(target_keys)) == length(target_keys) ||
        push!(errors, "duplicate_or_ambiguous_feedback_target")
    authority_by_layer = Dict(a.layer => a for a in x.upstream_authority)
    for target in x.feedback_targets
        target.source_id == x.source_id || push!(errors, "feedback_source_id_mismatch:" * target.target_id)
        target.owner_scope == x.owner_scope || push!(errors, "feedback_owner_scope_mismatch:" * target.target_id)
        target.authority.candidate_ref == x.candidate_ref || push!(errors, "feedback_candidate_binding_mismatch:" * target.target_id)
        if haskey(authority_by_layer, target.target_layer)
            canonical_json(semantic_view(target.authority)) ==
                canonical_json(semantic_view(authority_by_layer[target.target_layer])) ||
                push!(errors, "feedback_authority_mismatch:" * target.target_id)
        end
        target.authority.status === :contradictory &&
            push!(errors, "feedback_authority_contradiction:" * target.target_id)
    end
    unique!(errors)
    isempty(errors) ? (:valid, Tuple(errors)) : (:fail_closed, Tuple(errors))
end

struct G3SFAdmissionV1
    status::Symbol
    accepted::Bool
    resolution::Symbol
    claim_ceiling::Symbol
    errors::Tuple{Vararg{String}}
    gaps::Tuple{Vararg{String}}
    declaration_hash::Digest256
    source_id::String
    compiler_calls::Int
    provider_calls::Int
    mesh_calls::Int
    solver_calls::Int
    physical_evidence::Bool
end

semantic_view(x::G3SFAdmissionV1) = (status=x.status, accepted=x.accepted,
    resolution=x.resolution, claim_ceiling=x.claim_ceiling, errors=x.errors, gaps=x.gaps,
    declaration_hash=x.declaration_hash, source_id=x.source_id, compiler_calls=x.compiler_calls,
    provider_calls=x.provider_calls, mesh_calls=x.mesh_calls, solver_calls=x.solver_calls,
    physical_evidence=x.physical_evidence)
canonical_json(x::G3SFAdmissionV1) = canonical_json(semantic_view(x))

function _g3sf_admit_core_v1(x::G3SFDeclarationV1; inject_internal_fault::Bool=false)
    inject_internal_fault && error("controlled internal validation fault seam")
    status, errors = g3_sf_validate_v1(x)
    status == :valid || return G3SFAdmissionV1(:fail_closed, false, :fail_closed,
        G3_SF_V1_CLAIM_CEILING, errors, (), x.declaration_hash, x.source_id, 0, 0, 0, 0, false)
    gaps = String[]
    for authority in x.upstream_authority
        authority.status === :actual ?
            push!(gaps, "same_candidate_authority_gate:VNEXT:" * String(authority.layer)) :
            push!(gaps, "external_authority_gap:" * String(authority.layer))
    end
    for target in x.feedback_targets
        target.authority.status === :actual ?
            push!(gaps, "feedback_same_candidate_gate:VNEXT:" * target.target_id) :
            push!(gaps, "feedback_authority_gap:" * target.target_id)
    end
    unique!(gaps)
    resolution = isempty(gaps) ? :resolved : :terminal_deferred
    G3SFAdmissionV1(:proposal, false, resolution, G3_SF_V1_CLAIM_CEILING, (), Tuple(gaps),
        x.declaration_hash, x.source_id, 0, 0, 0, 0, false)
end

function g3_sf_admit_v1(x::Any)
    x isa G3SFDeclarationV1 || return G3SFAdmissionV1(:fail_closed, false, :fail_closed,
        G3_SF_V1_CLAIM_CEILING, ("declaration_type",), (), digest256_text("invalid-declaration"),
        "unknown", 0, 0, 0, 0, false)
    try
        _g3sf_admit_core_v1(x)
    catch err
        G3SFAdmissionV1(:program_exception, false, :program_exception, G3_SF_V1_CLAIM_CEILING,
            (string(typeof(err)),), (), x.declaration_hash, x.source_id, 0, 0, 0, 0, false)
    end
end

# This unexported seam is reserved for focused internal fault classification tests.
function _g3sf_admit_fault_seam_v1(x::Any)
    x isa G3SFDeclarationV1 || return G3SFAdmissionV1(:fail_closed, false, :fail_closed,
        G3_SF_V1_CLAIM_CEILING, ("declaration_type",), (), digest256_text("invalid-declaration"),
        "unknown", 0, 0, 0, 0, false)
    try
        _g3sf_admit_core_v1(x; inject_internal_fault=true)
    catch err
        G3SFAdmissionV1(:program_exception, false, :program_exception, G3_SF_V1_CLAIM_CEILING,
            (string(typeof(err)),), (), x.declaration_hash, x.source_id, 0, 0, 0, 0, false)
    end
end

function g3_sf_edit_efficiency_v1(x::G3SFDeclarationV1, efficiency::Any)
    η = _g3sf_rat(efficiency, "efficiency")
    split = G3SFConservativeSplitV1(η, 1 - η - x.law.conservative_split.heat_fraction,
        x.law.conservative_split.heat_fraction)
    heat = G3SFHeatRelationV1(:source, :heat, split.heat_fraction)
    law = G3SFLawV1(x.law.law_id, x.law.source_endpoint_id, x.law.field_endpoint_id,
        x.law.return_endpoint_id, x.law.heat_endpoint_id, split.field_fraction,
        split.heat_fraction, split, heat, x.law.ledger_relation, x.law.owner_scope)
    entries = Tuple(begin
        coefficient = e.effect === :source ? 1 // 1 : e.effect === :field ? -split.field_fraction :
            e.effect === :return ? -split.return_fraction : -split.heat_fraction
        G3SFLedgerEntryV1(e.entry_id, e.endpoint_id, e.unit, e.direction, e.sign, e.effect,
            coefficient, e.owner_scope)
    end for e in x.ledger_entries)
    g3_sf_declaration_v1(x.candidate_ref, x.source_id, x.owner_scope, x.endpoints, law,
        entries, x.ledger_closure, x.feedback_targets, x.upstream_authority)
end

g3_sf_authority_gap_v1(x::G3SFDeclarationV1) =
    Tuple("external_authority_gap:" * String(a.layer) for a in x.upstream_authority if a.status !== :actual)
