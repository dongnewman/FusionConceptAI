"""Typed conservation-ledger identity shared by the MIMO and genome layers."""

struct ConservationLedgerIdentityV1
    account_kind_ref::QualifiedRefV1
    ontology_hash::Digest256
    unit::UnitSignature
    function ConservationLedgerIdentityV1(account_kind_ref::Any, ontology_hash::Any, unit::Any)
        typeof(account_kind_ref) === QualifiedRefV1 ||
            throw(ArgumentError("account_kind_ref must be exactly QualifiedRefV1"))
        typeof(ontology_hash) === Digest256 ||
            throw(ArgumentError("ontology_hash must be exactly Digest256"))
        typeof(unit) === UnitSignature ||
            throw(ArgumentError("unit must be exactly UnitSignature"))
        new(account_kind_ref, ontology_hash, unit)
    end
end

const ConservationLedgerKeyV1 = Tuple{String,String,String,NTuple{7,Rational{Int64}}}

"""The closed identity key; all four components are identity-bearing."""
function _ledger_identity_full_key(x::ConservationLedgerIdentityV1)::ConservationLedgerKeyV1
    account_kind_ref = getfield(x, :account_kind_ref)
    ontology_hash = getfield(x, :ontology_hash)
    unit = getfield(x, :unit)
    (getfield(account_kind_ref, :id), getfield(account_kind_ref, :version),
        getfield(ontology_hash, :value), getfield(unit, :exponents))
end

function _ledger_identity_hash(x::ConservationLedgerIdentityV1)::Digest256
    _ccbw_hash_bytes(_ledger_identity_canonical_bytes(x))
end

function _ledger_identity_wire(x::ConservationLedgerIdentityV1)
    account_kind_ref = getfield(x, :account_kind_ref)
    ontology_hash = getfield(x, :ontology_hash)
    unit = getfield(x, :unit)
    io = _ccbw_new()
    _ccbw_ascii!(io, "{\"account_kind_ref\":{\"id\":")
    _ccbw_quote!(io, getfield(account_kind_ref, :id))
    _ccbw_ascii!(io, ",\"version\":")
    _ccbw_quote!(io, getfield(account_kind_ref, :version))
    _ccbw_ascii!(io, "},\"ontology_hash\":{\"value\":")
    _ccbw_quote!(io, getfield(ontology_hash, :value))
    _ccbw_ascii!(io, "},\"unit\":{\"exponents\":[")
    exponents = getfield(unit, :exponents)
    for index in 1:7
        exponent = getfield(exponents, index)
        index > 1 && _ccbw_byte!(io, UInt8(','))
        _ccbw_ascii!(io, "{\"denominator\":")
        _ccbw_integer!(io, getfield(exponent, :den))
        _ccbw_ascii!(io, ",\"numerator\":")
        _ccbw_integer!(io, getfield(exponent, :num))
        _ccbw_byte!(io, UInt8('}'))
    end
    _ccbw_ascii!(io, "]}}")
    _ccbw_finish(io)
end

function _ledger_identity_canonical_bytes(x::ConservationLedgerIdentityV1)::String
    "{\"canonicalization_version\":\"1\",\"domain\":\"fusionconceptai:v4:conservation-ledger-identity:v1\",\"identity\":" *
        _ledger_identity_wire(x) * "}"
end

semantic_view(x::ConservationLedgerIdentityV1) =
    (account_kind_ref=getfield(x, :account_kind_ref), ontology_hash=getfield(x, :ontology_hash), unit=getfield(x, :unit))
