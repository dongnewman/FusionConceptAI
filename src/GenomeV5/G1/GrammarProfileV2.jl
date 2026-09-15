"""Candidate-owned G1 V2 grammar and operator contracts.

This file is intentionally an additive extension.  It does not register anything
in `default_operator_registry()` and it does not provide a conversion from a V1
payload.  A profile is a closed value: a caller must explicitly supply every
operator, effect, derivative and provider capability used by a candidate.
"""

const _G1V5_ROLES = (:governing, :additive, :constraint)
const _G1V5_EFFECTS = (:none, :redistribution, :interface_flux, :net_creation, :net_destruction)
const _G1V5_MATCHES = (:unique_match, :no_match, :ambiguous, :out_of_domain, :invalid_signature)
const _G1V5_COMPATIBILITY_PROFILE = "candidate-owned-g1-v2"

# These strings are version-controlled contract material, rather than labels.  Their
# exact bytes are hashed and are therefore part of every external G1 reference.
const _G1V5_SCHEMA_CANONICAL = "MechanismGenomePayloadV2|contract_ref(uri,version,schema_hash,canonicalization_hash,grammar_profile_hash,applicability_profile_hash,compatibility_profile,version_axes,candidate_binding)|state(state_id,physical_type,derivative_order)|equation(equation_id,role,operator_ref,input_state_refs,output_state_refs,input_units,output_units,input_ranks,output_ranks,temporal_kind,derivative_order,effects,occurrences,closure_ref,typed_expression)|profile(operators,closures,max_states,max_equations,max_ast_nodes)|constraints(nonempty_ids,unique_ids,typed_units,exact_rational_occurrences,unique_occurrence_key,closure_balance,role_complete,provider_fail_closed)"
const _G1V5_CANONICALIZATION_RULES = "UTF-8|LF|named_tuple_keys_lexicographic|tuple_order_preserved|symbols_as_utf8|rational_as_num/den|digest=SHA256|no_mutable_containers|hash_before_execution"
const _G1V5_APPLICABILITY_RULES = "operator_candidate_owned_only|operator_role_exact|arity_units_ranks_temporal_derivative_effects_exact|provider_unique_match_required_for_execution|no_match_ambiguous_out_of_domain_invalid_signature=terminal_deferred"

g1_schema_hash() = digest256_text(_G1V5_SCHEMA_CANONICAL)
g1_canonicalization_hash() = digest256_text(_G1V5_CANONICALIZATION_RULES)

function _g1v5_tuple(value, field::AbstractString)
    value isa Tuple || throw(ArgumentError("$field must be an immutable tuple"))
    value
end

function _g1v5_text(value, field::AbstractString)
    value isa AbstractString && !isempty(String(value)) && isvalid(String(value)) ||
        throw(ArgumentError("$field must be a non-empty valid UTF-8 string"))
    String(value)
end

struct G1VersionAxesV2
    payload_schema_version::QualifiedRefV1
    canonicalization_profile_version::QualifiedRefV1
    applicability_profile_version::QualifiedRefV1
    evidence_receipt_version::QualifiedRefV1
    function G1VersionAxesV2(payload_schema_version::Any, canonicalization_profile_version::Any,
                             applicability_profile_version::Any, evidence_receipt_version::Any)
        refs = (payload_schema_version, canonicalization_profile_version,
                applicability_profile_version, evidence_receipt_version)
        all(x -> x isa QualifiedRefV1, refs) || throw(ArgumentError("G1 version axes require QualifiedRefV1"))
        all(x -> x.version != "v1", refs) || throw(ArgumentError("G1 V1 version axis cannot be reinterpreted as V2/V5"))
        new(refs...)
    end
end

"""Internal G1 binding/proposal metadata; materialize to public GenomeContractRef only when complete."""
struct G1GenomeContractRefV2
    uri::String
    version::String
    schema_hash::Union{Nothing,Digest256}
    canonicalization_hash::Union{Nothing,Digest256}
    compatibility_profile::String
    version_axes::G1VersionAxesV2
    candidate_binding::String
    schema_hash_status::Symbol
    canonicalization_hash_status::Symbol
    schema_hash_pending_reason::Union{Nothing,String}
    canonicalization_hash_pending_reason::Union{Nothing,String}
    grammar_profile_hash::Union{Nothing,Digest256}
    applicability_profile_hash::Union{Nothing,Digest256}
    grammar_profile_hash_status::Symbol
    applicability_profile_hash_status::Symbol
    grammar_profile_hash_pending_reason::Union{Nothing,String}
    applicability_profile_hash_pending_reason::Union{Nothing,String}
    function G1GenomeContractRefV2(uri::Any, version::Any, schema_hash::Any,
                                   canonicalization_hash::Any, compatibility_profile::Any,
                                   version_axes::Any, candidate_binding::Any;
                                   schema_hash_pending_reason=nothing,
                                   canonicalization_hash_pending_reason=nothing,
                                   grammar_profile_hash=nothing,
                                   applicability_profile_hash=nothing,
                                   grammar_profile_hash_pending_reason=nothing,
                                   applicability_profile_hash_pending_reason=nothing)
        u = _g1v5_text(uri, "contract uri")
        occursin("://", u) || throw(ArgumentError("G1 external contract URI must be absolute or explicitly pending"))
        v = _g1v5_text(version, "contract version")
        v == "v5" || throw(ArgumentError("G1 external contract version must be the v5 contract token"))
        occursin("wire-domain:v2", u) || occursin("wire-domain:v2", v) ?
            throw(ArgumentError("legacy wire-domain:v2 cannot enter G1 V5 external ref")) : nothing
        sh = schema_hash === nothing ? nothing : schema_hash isa Digest256 ? schema_hash : Digest256(schema_hash)
        ch = canonicalization_hash === nothing ? nothing : canonicalization_hash isa Digest256 ? canonicalization_hash : Digest256(canonicalization_hash)
        profile = _g1v5_text(compatibility_profile, "compatibility_profile")
        axes = version_axes isa G1VersionAxesV2 ? version_axes : throw(ArgumentError("external ref must bind all four G1 version axes"))
        binding = _g1v5_text(candidate_binding, "candidate_binding")
        sh === nothing && (schema_hash_pending_reason isa AbstractString && !isempty(String(schema_hash_pending_reason)) || throw(ArgumentError("pending schema_hash requires pending reason")))
        ch === nothing && (canonicalization_hash_pending_reason isa AbstractString && !isempty(String(canonicalization_hash_pending_reason)) || throw(ArgumentError("pending canonicalization_hash requires pending reason")))
        shr = sh === nothing ? _g1v5_text(schema_hash_pending_reason, "schema_hash_pending_reason") : nothing
        chr = ch === nothing ? _g1v5_text(canonicalization_hash_pending_reason, "canonicalization_hash_pending_reason") : nothing
        gh = grammar_profile_hash === nothing ? nothing : grammar_profile_hash isa Digest256 ? grammar_profile_hash : Digest256(grammar_profile_hash)
        ah = applicability_profile_hash === nothing ? nothing : applicability_profile_hash isa Digest256 ? applicability_profile_hash : Digest256(applicability_profile_hash)
        gh === nothing && (grammar_profile_hash_pending_reason isa AbstractString && !isempty(String(grammar_profile_hash_pending_reason)) || throw(ArgumentError("pending grammar_profile_hash requires pending reason")))
        ah === nothing && (applicability_profile_hash_pending_reason isa AbstractString && !isempty(String(applicability_profile_hash_pending_reason)) || throw(ArgumentError("pending applicability_profile_hash requires pending reason")))
        ghr = gh === nothing ? _g1v5_text(grammar_profile_hash_pending_reason, "grammar_profile_hash_pending_reason") : nothing
        ahr = ah === nothing ? _g1v5_text(applicability_profile_hash_pending_reason, "applicability_profile_hash_pending_reason") : nothing
        new(u, v, sh, ch, profile, axes, binding, sh === nothing ? :pending : :available,
            ch === nothing ? :pending : :available, shr, chr, gh, ah,
            gh === nothing ? :pending : :available, ah === nothing ? :pending : :available, ghr, ahr)
    end
end

const GenomeContractRefV2 = G1GenomeContractRefV2

struct G1OperatorSpecV2
    ref::QualifiedRefV1
    input_arity::Int
    output_arity::Int
    roles::Tuple{Vararg{Symbol}}
    input_units::Tuple{Vararg{UnitSignature}}
    output_units::Tuple{Vararg{UnitSignature}}
    input_ranks::Tuple{Vararg{Int}}
    output_ranks::Tuple{Vararg{Int}}
    temporal_kinds::Tuple{Vararg{TimeKindV1}}
    max_derivative_order::Int
    effects::Tuple{Vararg{Symbol}}
    provider_match::Symbol
    candidate_owned::Bool
    function G1OperatorSpecV2(ref::Any, input_arity::Any, output_arity::Any,
                              roles::Any, input_units::Any, output_units::Any,
                              temporal_kinds::Any, max_derivative_order::Any,
                              effects::Any; input_ranks=nothing, output_ranks=nothing,
                              provider_match=:unique_match, candidate_owned=true)
        ref isa QualifiedRefV1 || throw(ArgumentError("operator ref must be QualifiedRefV1"))
        ref.version != "v1" || throw(ArgumentError("legacy v1 operator cannot enter G1 V2 profile"))
        ia = input_arity isa Integer && !(input_arity isa Bool) ? Int(input_arity) : throw(ArgumentError("input_arity must be an integer"))
        oa = output_arity isa Integer && !(output_arity isa Bool) ? Int(output_arity) : throw(ArgumentError("output_arity must be an integer"))
        ia >= 0 && oa > 0 || throw(ArgumentError("operator arities are invalid"))
        rs = _g1v5_tuple(roles, "roles")
        !isempty(rs) && all(x -> x isa Symbol && x in _G1V5_ROLES, rs) || throw(ArgumentError("operator role is invalid"))
        length(unique(rs)) == length(rs) || throw(ArgumentError("operator roles must be unique"))
        iu = _g1v5_tuple(input_units, "input_units")
        ou = _g1v5_tuple(output_units, "output_units")
        length(iu) == ia && length(ou) == oa || throw(ArgumentError("operator unit arity does not match"))
        all(x -> x isa UnitSignature, iu) && all(x -> x isa UnitSignature, ou) || throw(ArgumentError("operator units must be UnitSignature"))
        ir = input_ranks === nothing ? ntuple(_ -> 0, ia) : _g1v5_tuple(input_ranks, "input_ranks")
        or = output_ranks === nothing ? ntuple(_ -> 0, oa) : _g1v5_tuple(output_ranks, "output_ranks")
        length(ir) == ia && length(or) == oa && all(x -> x isa Integer && !(x isa Bool) && x >= 0, ir) && all(x -> x isa Integer && !(x isa Bool) && x >= 0, or) || throw(ArgumentError("operator tensor ranks are invalid"))
        tk = _g1v5_tuple(temporal_kinds, "temporal_kinds")
        !isempty(tk) && all(x -> x isa TimeKindV1, tk) || throw(ArgumentError("operator temporal kind is invalid"))
        d = max_derivative_order isa Integer && !(max_derivative_order isa Bool) ? Int(max_derivative_order) : throw(ArgumentError("max_derivative_order must be an integer"))
        0 <= d <= 255 || throw(ArgumentError("max_derivative_order is outside the G1 V2 bound"))
        es = _g1v5_tuple(effects, "effects")
        all(x -> x isa Symbol && x in _G1V5_EFFECTS, es) || throw(ArgumentError("operator effect is invalid"))
        match = provider_match isa Symbol ? provider_match : Symbol(provider_match)
        match in _G1V5_MATCHES || throw(ArgumentError("provider_match is invalid"))
        candidate_owned === true || throw(ArgumentError("G1 V2 operators must be candidate-owned"))
        new(ref, ia, oa, Tuple(rs), Tuple(iu), Tuple(ou), Tuple(Int.(ir)), Tuple(Int.(or)), Tuple(tk), d, Tuple(es), match, true)
    end
end

struct G1LedgerOccurrenceV2
    equation_id::String
    port_side::Symbol
    port_index::Int
    coefficient::Rational{Int64}
    ledger_id::String
    unit::UnitSignature
    effect::Symbol
    function G1LedgerOccurrenceV2(equation_id::Any, port_side::Any, port_index::Any,
                                 coefficient::Any, ledger_id::Any, unit::Any, effect::Any)
        eq = _g1v5_text(equation_id, "equation_id")
        side = port_side isa Symbol ? port_side : Symbol(port_side)
        side in (:input, :output) || throw(ArgumentError("occurrence port_side must be input or output"))
        idx = port_index isa Integer && !(port_index isa Bool) ? Int(port_index) : throw(ArgumentError("occurrence port_index must be an integer"))
        idx > 0 || throw(ArgumentError("occurrence port_index must be positive"))
        coefficient isa Rational || throw(ArgumentError("occurrence coefficient must be exact Rational"))
        coeff = try Rational{Int64}(coefficient) catch; throw(ArgumentError("occurrence coefficient is out of range")) end
        coeff != 0 || throw(ArgumentError("occurrence coefficient cannot be zero"))
        led = _g1v5_text(ledger_id, "ledger_id")
        unit isa UnitSignature || throw(ArgumentError("occurrence unit must be UnitSignature"))
        eff = effect isa Symbol ? effect : Symbol(effect)
        eff in _G1V5_EFFECTS || throw(ArgumentError("occurrence effect is invalid"))
        new(eq, side, idx, coeff, led, unit, eff)
    end
end

struct G1ClosureRuleV2
    closure_id::String
    ledger_id::String
    unit::UnitSignature
    equation_ids::Tuple{Vararg{String}}
    expected_balance::Rational{Int64}
    function G1ClosureRuleV2(closure_id::Any, ledger_id::Any, unit::Any,
                             equation_ids::Any, expected_balance::Any=0 // 1)
        cid = _g1v5_text(closure_id, "closure_id")
        lid = _g1v5_text(ledger_id, "ledger_id")
        unit isa UnitSignature || throw(ArgumentError("closure unit must be UnitSignature"))
        ids = _g1v5_tuple(equation_ids, "equation_ids")
        all(x -> x isa AbstractString && !isempty(String(x)), ids) || throw(ArgumentError("closure equation ids are invalid"))
        length(unique(String.(ids))) == length(ids) || throw(ArgumentError("closure equation ids must be unique"))
        balance = expected_balance isa Rational ? (try Rational{Int64}(expected_balance) catch; throw(ArgumentError("closure balance is out of range")) end) :
            throw(ArgumentError("closure balance must be exact Rational"))
        new(cid, lid, unit, Tuple(String.(ids)), balance)
    end
end

struct GrammarProfileV2
    profile_ref::QualifiedRefV1
    canonicalization_profile::QualifiedRefV1
    applicability_profile::QualifiedRefV1
    operators::Tuple{Vararg{G1OperatorSpecV2}}
    closures::Tuple{Vararg{G1ClosureRuleV2}}
    max_states::Int
    max_equations::Int
    max_ast_nodes::Int
    candidate_owned::Bool
    function GrammarProfileV2(profile_ref::Any, canonicalization_profile::Any,
                              applicability_profile::Any, operators::Any, closures::Any;
                              max_states=8, max_equations=64, max_ast_nodes=256,
                              candidate_owned=true)
        profile_ref isa QualifiedRefV1 && canonicalization_profile isa QualifiedRefV1 && applicability_profile isa QualifiedRefV1 ||
            throw(ArgumentError("G1 V2 profile refs must be QualifiedRefV1"))
        ops = _g1v5_tuple(operators, "operators")
        cls = _g1v5_tuple(closures, "closures")
        all(x -> typeof(x) === G1OperatorSpecV2, ops) || throw(ArgumentError("profile operators are not G1OperatorSpecV2"))
        all(x -> typeof(x) === G1ClosureRuleV2, cls) || throw(ArgumentError("profile closures are not G1ClosureRuleV2"))
        refs = Tuple((x.ref.id, x.ref.version) for x in ops)
        length(unique(refs)) == length(refs) || throw(ArgumentError("profile contains duplicate operator refs"))
        max_states isa Integer && max_states > 0 || throw(ArgumentError("max_states must be positive"))
        max_equations isa Integer && max_equations > 0 || throw(ArgumentError("max_equations must be positive"))
        max_ast_nodes isa Integer && max_ast_nodes > 0 || throw(ArgumentError("max_ast_nodes must be positive"))
        candidate_owned === true || throw(ArgumentError("G1 V2 profile must be candidate-owned"))
        new(profile_ref, canonicalization_profile, applicability_profile, Tuple(ops), Tuple(cls),
            Int(max_states), Int(max_equations), Int(max_ast_nodes), true)
    end
end

semantic_view(x::G1OperatorSpecV2) =
    (ref=x.ref, input_arity=x.input_arity, output_arity=x.output_arity, roles=x.roles,
     input_units=x.input_units, output_units=x.output_units, temporal_kinds=x.temporal_kinds,
     input_ranks=x.input_ranks, output_ranks=x.output_ranks,
     max_derivative_order=x.max_derivative_order, effects=x.effects,
     provider_match=x.provider_match, candidate_owned=x.candidate_owned)
semantic_view(x::G1VersionAxesV2) =
    (payload_schema_version=x.payload_schema_version,
     canonicalization_profile_version=x.canonicalization_profile_version,
     applicability_profile_version=x.applicability_profile_version,
     evidence_receipt_version=x.evidence_receipt_version)
Base.:(==)(a::G1VersionAxesV2, b::G1VersionAxesV2) =
    a.payload_schema_version == b.payload_schema_version &&
    a.canonicalization_profile_version == b.canonicalization_profile_version &&
    a.applicability_profile_version == b.applicability_profile_version &&
    a.evidence_receipt_version == b.evidence_receipt_version
semantic_view(x::G1GenomeContractRefV2) =
    (uri=x.uri, version=x.version, schema_hash=x.schema_hash,
     canonicalization_hash=x.canonicalization_hash,
     compatibility_profile=x.compatibility_profile, version_axes=x.version_axes,
     candidate_binding=x.candidate_binding,
     schema_hash_status=x.schema_hash_status,
     canonicalization_hash_status=x.canonicalization_hash_status,
     schema_hash_pending_reason=x.schema_hash_pending_reason,
     canonicalization_hash_pending_reason=x.canonicalization_hash_pending_reason,
     grammar_profile_hash=x.grammar_profile_hash,
     applicability_profile_hash=x.applicability_profile_hash,
     grammar_profile_hash_status=x.grammar_profile_hash_status,
     applicability_profile_hash_status=x.applicability_profile_hash_status,
     grammar_profile_hash_pending_reason=x.grammar_profile_hash_pending_reason,
     applicability_profile_hash_pending_reason=x.applicability_profile_hash_pending_reason)
semantic_view(x::G1LedgerOccurrenceV2) =
    (equation_id=x.equation_id, port_side=x.port_side, port_index=x.port_index,
     coefficient=x.coefficient, ledger_id=x.ledger_id, unit=x.unit, effect=x.effect)
semantic_view(x::G1ClosureRuleV2) =
    (closure_id=x.closure_id, ledger_id=x.ledger_id, unit=x.unit,
     equation_ids=x.equation_ids, expected_balance=x.expected_balance)
semantic_view(x::GrammarProfileV2) =
    (profile_ref=x.profile_ref, canonicalization_profile=x.canonicalization_profile,
     applicability_profile=x.applicability_profile, operators=x.operators, closures=x.closures,
     max_states=x.max_states, max_equations=x.max_equations, max_ast_nodes=x.max_ast_nodes,
     candidate_owned=x.candidate_owned)

canonical_json(x::G1OperatorSpecV2) = canonical_json(semantic_view(x))
canonical_json(x::G1VersionAxesV2) = canonical_json(semantic_view(x))
canonical_json(x::G1GenomeContractRefV2) = canonical_json(semantic_view(x))
canonical_json(x::G1LedgerOccurrenceV2) = canonical_json(semantic_view(x))
canonical_json(x::G1ClosureRuleV2) = canonical_json(semantic_view(x))
canonical_json(x::GrammarProfileV2) = canonical_json(semantic_view(x))
g1_profile_hash(x::GrammarProfileV2) = canonical_hash(x)
g1_grammar_profile_hash(x::GrammarProfileV2) = g1_profile_hash(x)
g1_compatibility_profile_token(::GrammarProfileV2) = _G1V5_COMPATIBILITY_PROFILE
g1_applicability_profile_hash(x::GrammarProfileV2) = canonical_hash((
    profile_ref=x.applicability_profile,
    operator_rules=Tuple((ref=o.ref, roles=o.roles, input_arity=o.input_arity, output_arity=o.output_arity,
                          input_units=o.input_units, output_units=o.output_units, input_ranks=o.input_ranks,
                          output_ranks=o.output_ranks, temporal_kinds=o.temporal_kinds,
                          max_derivative_order=o.max_derivative_order, effects=o.effects,
                          provider_match=o.provider_match, candidate_owned=o.candidate_owned) for o in x.operators),
    rules=_G1V5_APPLICABILITY_RULES))

"""Materialize the public contract only after all G1 binding evidence is available."""
function g1_materialize_contract_ref(binding::G1GenomeContractRefV2, profile::GrammarProfileV2)::GenomeContractRef
    binding.version == "v5" || throw(ArgumentError("G1 materialization requires contract version v5"))
    binding.compatibility_profile == g1_compatibility_profile_token(profile) ||
        throw(ArgumentError("G1 compatibility profile does not match candidate-owned profile"))
    binding.schema_hash === nothing && throw(ArgumentError("G1 schema hash is pending; public ref cannot materialize"))
    binding.canonicalization_hash === nothing && throw(ArgumentError("G1 canonicalization hash is pending; public ref cannot materialize"))
    binding.grammar_profile_hash === nothing && throw(ArgumentError("G1 grammar profile hash is pending; public ref cannot materialize"))
    binding.applicability_profile_hash === nothing && throw(ArgumentError("G1 applicability profile hash is pending; public ref cannot materialize"))
    binding.schema_hash == g1_schema_hash() || throw(ArgumentError("G1 schema hash does not match authoritative content"))
    binding.canonicalization_hash == g1_canonicalization_hash() || throw(ArgumentError("G1 canonicalization hash does not match authoritative content"))
    binding.grammar_profile_hash == g1_grammar_profile_hash(profile) || throw(ArgumentError("G1 grammar profile hash does not match authoritative content"))
    binding.applicability_profile_hash == g1_applicability_profile_hash(profile) || throw(ArgumentError("G1 applicability profile hash does not match authoritative content"))
    axes = binding.version_axes
    all(x -> x.version != "v1", (axes.payload_schema_version, axes.canonicalization_profile_version,
        axes.applicability_profile_version, axes.evidence_receipt_version)) ||
        throw(ArgumentError("legacy G1 version axis cannot materialize"))
    axes.payload_schema_version.version == "v2" || throw(ArgumentError("G1 payload schema axis must be v2"))
    axes.canonicalization_profile_version.version == profile.canonicalization_profile.version ||
        throw(ArgumentError("G1 canonicalization axis does not match profile version"))
    axes.applicability_profile_version.version == profile.applicability_profile.version ||
        throw(ArgumentError("G1 applicability axis does not match profile version"))
    axes.evidence_receipt_version.version == "v2" || throw(ArgumentError("G1 evidence receipt axis must be v2"))
    isempty(binding.candidate_binding) && throw(ArgumentError("G1 candidate binding cannot be empty"))
    GenomeContractRef(binding.uri, binding.version, binding.schema_hash,
        binding.canonicalization_hash, binding.compatibility_profile)
end
