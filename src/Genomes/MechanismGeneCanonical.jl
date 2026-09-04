"""Closed wire identities for the G1 mechanism primitives.

These encoders deliberately do not call `semantic_view`, `_canonical`,
`canonical_json`, or any open nested encoder.  The public methods below are
defined per concrete primitive so the domain and wire kind cannot be supplied
by a caller.
"""

const _G1_PRIMITIVE_DOMAIN = "fusionconceptai:v4:g1-primitive:v1"
const _G1_PRIMITIVE_VERSION = "1"

function _g1_quote(value::String)
    isvalid(value) || throw(ArgumentError("G1 primitive text must be valid UTF-8"))
    io = IOBuffer()
    print(io, '"')
    for character in value
        if character == '"'
            print(io, "\\\"")
        elseif character == '\\'
            print(io, "\\\\")
        elseif character == '\b'
            print(io, "\\b")
        elseif character == '\f'
            print(io, "\\f")
        elseif character == '\n'
            print(io, "\\n")
        elseif character == '\r'
            print(io, "\\r")
        elseif character == '\t'
            print(io, "\\t")
        elseif UInt32(character) < 0x20
            print(io, "\\u", lpad(string(UInt32(character), base=16), 4, '0'))
        else
            print(io, character)
        end
    end
    print(io, '"')
    String(take!(io))
end

_g1_rational(value::Rational{Int64}) =
    "{\"denominator\":" * string(denominator(value)) * ",\"numerator\":" * string(numerator(value)) * "}"

function _g1_unit(value::UnitSignature)
    encoded = String[]
    for exponent in value.exponents
        push!(encoded, invoke(_g1_rational, Tuple{Rational{Int64}}, exponent))
    end
    "{\"exponents\":[" * join(encoded, ",") * "]}"
end

function _g1_wrap(kind::String, payload::String)
    "{\"canonicalization_version\":" * invoke(_g1_quote, Tuple{String}, _G1_PRIMITIVE_VERSION) *
    ",\"domain\":" * invoke(_g1_quote, Tuple{String}, _G1_PRIMITIVE_DOMAIN) *
    ",\"kind\":" * invoke(_g1_quote, Tuple{String}, kind) * ",\"payload\":" * payload * "}"
end

function _g1_ref_wire(kind::String, value::String)
    payload = "{\"value\":" * invoke(_g1_quote, Tuple{String}, value) * "}"
    invoke(_g1_wrap, Tuple{String,String}, kind, payload)
end

function _g1_interval_wire(value::ExactFiniteIntervalV1)
    payload = "{\"allow_equal\":" * (value.allow_equal ? "true" : "false") *
        ",\"lower\":" * invoke(_g1_rational, Tuple{Rational{Int64}}, value.lower) *
        ",\"upper\":" * invoke(_g1_rational, Tuple{Rational{Int64}}, value.upper) * "}"
    invoke(_g1_wrap, Tuple{String,String}, "exact_finite_interval", payload)
end

function _g1_quantity_interval_wire(value::QuantityIntervalV1)
    payload = "{\"interval\":" * _g1_interval_payload(value.interval) *
        ",\"unit\":" * invoke(_g1_unit, Tuple{UnitSignature}, value.unit) * "}"
    invoke(_g1_wrap, Tuple{String,String}, "quantity_interval", payload)
end

_g1_interval_payload(value::ExactFiniteIntervalV1) =
    "{\"allow_equal\":" * (value.allow_equal ? "true" : "false") *
    ",\"lower\":" * invoke(_g1_rational, Tuple{Rational{Int64}}, value.lower) *
    ",\"upper\":" * invoke(_g1_rational, Tuple{Rational{Int64}}, value.upper) * "}"

function _g1_nonnegative_wire(value::NonnegativeQuantityV1)
    payload = "{\"unit\":" * invoke(_g1_unit, Tuple{UnitSignature}, value.unit) *
        ",\"value\":" * invoke(_g1_rational, Tuple{Rational{Int64}}, value.value) * "}"
    invoke(_g1_wrap, Tuple{String,String}, "nonnegative_quantity", payload)
end

function _g1_matrix_wire(value::ExactRationalMatrixV1)
    row_text = String[]
    for row in value.rows
        entries = String[]
        for entry in row
            entry isa Rational{Int64} || throw(ArgumentError("G1 matrix contains an unsafe rational"))
            push!(entries, invoke(_g1_rational, Tuple{Rational{Int64}}, entry))
        end
        push!(row_text, "[" * join(entries, ",") * "]")
    end
    payload = "{\"rows\":[" * join(row_text, ",") * "]}"
    invoke(_g1_wrap, Tuple{String,String}, "exact_rational_matrix", payload)
end

function _g1_qualified_ref(value::QualifiedRefV1)
    "{\"id\":" * invoke(_g1_quote, Tuple{String}, value.id) *
        ",\"version\":" * invoke(_g1_quote, Tuple{String}, value.version) * "}"
end

function _g1_parity_wire(value::ParityActionV1)
    sign = value.sign == even ? "even" : value.sign == odd ? "odd" :
        throw(ArgumentError("invalid parity sign"))
    payload = "{\"generator_ref\":" * invoke(_g1_qualified_ref, Tuple{QualifiedRefV1}, value.generator_ref) *
        ",\"sign\":" * invoke(_g1_quote, Tuple{String}, sign) * "}"
    invoke(_g1_wrap, Tuple{String,String}, "parity_action", payload)
end

function _g1_enum_wire(kind::String, value::Int, labels::Tuple{Vararg{String}})
    0 <= value < length(labels) || throw(ArgumentError("invalid G1 enum value"))
    payload = "{\"value\":" * invoke(_g1_quote, Tuple{String}, labels[value + 1]) * "}"
    invoke(_g1_wrap, Tuple{String,String}, kind, payload)
end

function _g1_state_wire(value::StateEpistemicV1)
    labels = ("derived", "measured", "declared_known", "hypothesized", "learned", "empirical_prior", "unknown_placeholder", "not_applicable")
    invoke(_g1_enum_wire, Tuple{String,Int,Tuple{Vararg{String}}}, "state_epistemic", Int(value), labels)
end
function _g1_parity_sign_wire(value::ParitySignV1)
    labels = ("even", "odd")
    invoke(_g1_enum_wire, Tuple{String,Int,Tuple{Vararg{String}}}, "parity_sign", Int(value), labels)
end
function _g1_scope_wrap(payload::String)
    io = _ccbw_new()
    _ccbw_ascii!(io, "{\"canonicalization_version\":\"1\",\"domain\":\"fusionconceptai:v4:g1-primitive:v1\",\"kind\":\"conservation_scope\",\"payload\":")
    _ccbw_ascii!(io, payload)
    _ccbw_byte!(io, UInt8('}'))
    _ccbw_finish(io)
end

function _g1_scope_wire(value::GlobalConservationScopeV1)
    invoke(_g1_scope_wrap, Tuple{String}, "{\"kind\":\"global\"}")
end

function _g1_scope_wire(value::DomainConservationScopeV1)
    refs = getfield(value, :state_refs)
    body = _ccbw_new()
    _ccbw_ascii!(body, "{\"kind\":\"domain\",\"state_refs\":[")
    for index in 1:length(refs)
        index > 1 && _ccbw_byte!(body, UInt8(','))
        ref = getfield(refs, index)
        _ccbw_ascii!(body, "{\"value\":")
        _ccbw_quote!(body, getfield(ref, :value))
        _ccbw_byte!(body, UInt8('}'))
    end
    _ccbw_ascii!(body, "]}")
    invoke(_g1_scope_wrap, Tuple{String}, _ccbw_finish(body))
end

function _g1_scope_wire(value::InterfaceConservationScopeV1)
    ref = getfield(value, :operator_site_ref)
    io = _ccbw_new()
    _ccbw_ascii!(io, "{\"kind\":\"interface\",\"operator_site_ref\":{\"value\":")
    _ccbw_quote!(io, getfield(ref, :value))
    _ccbw_ascii!(io, "}}")
    invoke(_g1_scope_wrap, Tuple{String}, _ccbw_finish(io))
end
function _g1_entropy_wire(value::EntropyDirectionV1)
    labels = ("not_applicable", "nondecreasing", "nonincreasing", "conserved")
    invoke(_g1_enum_wire, Tuple{String,Int,Tuple{Vararg{String}}}, "entropy_direction", Int(value), labels)
end
function _g1_transform_wire(value::ParameterTransformKindV1)
    labels = ("linear", "log", "signed_log")
    invoke(_g1_enum_wire, Tuple{String,Int,Tuple{Vararg{String}}}, "parameter_transform", Int(value), labels)
end
function _g1_group_wire(value::SymmetryGroupKindV1)
    labels = ("discrete", "continuous")
    invoke(_g1_enum_wire, Tuple{String,Int,Tuple{Vararg{String}}}, "symmetry_group", Int(value), labels)
end
function _g1_behavior_wire(value::SymmetryBehaviorV1)
    labels = ("invariant", "equivariant")
    invoke(_g1_enum_wire, Tuple{String,Int,Tuple{Vararg{String}}}, "symmetry_behavior", Int(value), labels)
end
function _g1_conservation_wire(value::ConservationEffectKindV1)
    labels = ("redistribution", "interface_flux", "net_creation", "net_destruction")
    invoke(_g1_enum_wire, Tuple{String,Int,Tuple{Vararg{String}}}, "conservation_effect", Int(value), labels)
end

canonical_json(value::StateGeneRefV1) = invoke(_g1_ref_wire, Tuple{String,String}, "state_gene_ref", value.value)
canonical_json(value::InvariantRefV1) = invoke(_g1_ref_wire, Tuple{String,String}, "invariant_ref", value.value)
canonical_json(value::ParameterRefV1) = invoke(_g1_ref_wire, Tuple{String,String}, "parameter_ref", value.value)
canonical_json(value::SymmetryRefV1) = invoke(_g1_ref_wire, Tuple{String,String}, "symmetry_ref", value.value)
canonical_json(value::ObservableRefV1) = invoke(_g1_ref_wire, Tuple{String,String}, "observable_ref", value.value)
canonical_json(value::OperatorSiteRefV1) = invoke(_g1_ref_wire, Tuple{String,String}, "operator_site_ref", value.value)
canonical_json(value::ConstraintRefV1) = invoke(_g1_ref_wire, Tuple{String,String}, "constraint_ref", value.value)
canonical_json(value::HoleRefV1) = invoke(_g1_ref_wire, Tuple{String,String}, "hole_ref", value.value)
canonical_json(value::ExactFiniteIntervalV1) = _g1_interval_wire(value)
canonical_json(value::QuantityIntervalV1) = _g1_quantity_interval_wire(value)
canonical_json(value::NonnegativeQuantityV1) = _g1_nonnegative_wire(value)
canonical_json(value::ExactRationalMatrixV1) = _g1_matrix_wire(value)
canonical_json(value::ParityActionV1) = _g1_parity_wire(value)
canonical_json(value::StateEpistemicV1) = _g1_state_wire(value)
canonical_json(value::ParitySignV1) = _g1_parity_sign_wire(value)
canonical_json(value::GlobalConservationScopeV1) = _g1_scope_wire(value)
canonical_json(value::DomainConservationScopeV1) = _g1_scope_wire(value)
canonical_json(value::InterfaceConservationScopeV1) = _g1_scope_wire(value)
canonical_json(value::EntropyDirectionV1) = _g1_entropy_wire(value)
canonical_json(value::ParameterTransformKindV1) = _g1_transform_wire(value)
canonical_json(value::SymmetryGroupKindV1) = _g1_group_wire(value)
canonical_json(value::SymmetryBehaviorV1) = _g1_behavior_wire(value)
canonical_json(value::ConservationEffectKindV1) = _g1_conservation_wire(value)

_g1_hash_bytes(value::String) = Digest256(bytes2hex(SHA.sha256(Vector{UInt8}(codeunits(value)))))

canonical_hash(value::StateGeneRefV1) = invoke(_g1_hash_bytes, Tuple{String}, canonical_json(value))
canonical_hash(value::InvariantRefV1) = invoke(_g1_hash_bytes, Tuple{String}, canonical_json(value))
canonical_hash(value::ParameterRefV1) = invoke(_g1_hash_bytes, Tuple{String}, canonical_json(value))
canonical_hash(value::SymmetryRefV1) = invoke(_g1_hash_bytes, Tuple{String}, canonical_json(value))
canonical_hash(value::ObservableRefV1) = invoke(_g1_hash_bytes, Tuple{String}, canonical_json(value))
canonical_hash(value::OperatorSiteRefV1) = invoke(_g1_hash_bytes, Tuple{String}, canonical_json(value))
canonical_hash(value::ConstraintRefV1) = invoke(_g1_hash_bytes, Tuple{String}, canonical_json(value))
canonical_hash(value::HoleRefV1) = invoke(_g1_hash_bytes, Tuple{String}, canonical_json(value))
canonical_hash(value::ExactFiniteIntervalV1) = invoke(_g1_hash_bytes, Tuple{String}, _g1_interval_wire(value))
canonical_hash(value::QuantityIntervalV1) = invoke(_g1_hash_bytes, Tuple{String}, _g1_quantity_interval_wire(value))
canonical_hash(value::NonnegativeQuantityV1) = invoke(_g1_hash_bytes, Tuple{String}, _g1_nonnegative_wire(value))
canonical_hash(value::ExactRationalMatrixV1) = invoke(_g1_hash_bytes, Tuple{String}, _g1_matrix_wire(value))
canonical_hash(value::ParityActionV1) = invoke(_g1_hash_bytes, Tuple{String}, _g1_parity_wire(value))
canonical_hash(value::StateEpistemicV1) = invoke(_g1_hash_bytes, Tuple{String}, _g1_state_wire(value))
canonical_hash(value::ParitySignV1) = invoke(_g1_hash_bytes, Tuple{String}, _g1_parity_sign_wire(value))
canonical_hash(value::GlobalConservationScopeV1) = invoke(_g1_hash_bytes, Tuple{String}, _g1_scope_wire(value))
canonical_hash(value::DomainConservationScopeV1) = invoke(_g1_hash_bytes, Tuple{String}, _g1_scope_wire(value))
canonical_hash(value::InterfaceConservationScopeV1) = invoke(_g1_hash_bytes, Tuple{String}, _g1_scope_wire(value))
canonical_hash(value::EntropyDirectionV1) = invoke(_g1_hash_bytes, Tuple{String}, _g1_entropy_wire(value))
canonical_hash(value::ParameterTransformKindV1) = invoke(_g1_hash_bytes, Tuple{String}, _g1_transform_wire(value))
canonical_hash(value::SymmetryGroupKindV1) = invoke(_g1_hash_bytes, Tuple{String}, _g1_group_wire(value))
canonical_hash(value::SymmetryBehaviorV1) = invoke(_g1_hash_bytes, Tuple{String}, _g1_behavior_wire(value))
canonical_hash(value::ConservationEffectKindV1) = invoke(_g1_hash_bytes, Tuple{String}, _g1_conservation_wire(value))
