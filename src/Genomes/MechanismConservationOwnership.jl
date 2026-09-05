"""Sealed occurrence identity used to assign every graph ledger effect."""

@enum ConservationOccurrenceKindV1 occurrence_internal_effect occurrence_source_effect occurrence_sink_effect occurrence_boundary_effect occurrence_interface_minus occurrence_interface_plus

struct ConservationLedgerOccurrenceRefV1
    operator_site_ref::OperatorSiteRefV1
    port_side::Symbol
    port_index::Int
    direction::Symbol
    occurrence_kind::ConservationOccurrenceKindV1
    ledger_identity::ConservationLedgerIdentityV1
    function ConservationLedgerOccurrenceRefV1(operator_site_ref::Any, port_side::Any,
                                               port_index::Any, direction::Any, occurrence_kind::Any,
                                               ledger_identity::Any)
        typeof(operator_site_ref) === OperatorSiteRefV1 ||
            throw(ArgumentError("occurrence operator_site_ref must be exactly OperatorSiteRefV1"))
        typeof(port_side) === Symbol || throw(ArgumentError("occurrence port side must be Symbol"))
        typeof(direction) === Symbol || throw(ArgumentError("occurrence direction must be Symbol"))
        typeof(port_index) in _P0_SAFE_INTEGER_TYPES || throw(ArgumentError("occurrence port_index must be fixed-width integer"))
        port_index isa Bool && throw(ArgumentError("occurrence port_index must not be Bool"))
        typemin(Int) <= port_index <= typemax(Int) && port_index >= 1 || throw(ArgumentError("occurrence port_index is out of range"))
        port_side in (:input, :output) || throw(ArgumentError("occurrence port side must be input or output"))
        direction in (:inflow, :outflow, :minus, :plus) || throw(ArgumentError("occurrence direction is invalid"))
        typeof(occurrence_kind) === ConservationOccurrenceKindV1 ||
            throw(ArgumentError("occurrence kind must be exactly ConservationOccurrenceKindV1"))
        typeof(ledger_identity) === ConservationLedgerIdentityV1 ||
            throw(ArgumentError("occurrence ledger_identity must be exactly ConservationLedgerIdentityV1"))
        if occurrence_kind === occurrence_source_effect
            port_side === :output && direction === :plus || throw(ArgumentError("source occurrence must be output/plus"))
        elseif occurrence_kind === occurrence_sink_effect
            port_side === :output && direction === :minus || throw(ArgumentError("sink occurrence must be output/minus"))
        elseif occurrence_kind === occurrence_interface_minus
            port_side === :output && direction === :minus || throw(ArgumentError("interface-minus occurrence must be output/minus"))
        elseif occurrence_kind === occurrence_interface_plus
            port_side === :output && direction === :plus || throw(ArgumentError("interface-plus occurrence must be output/plus"))
        elseif occurrence_kind in (occurrence_boundary_effect, occurrence_internal_effect)
            direction in (:inflow, :outflow, :minus, :plus) || throw(ArgumentError("boundary/internal occurrence direction is invalid"))
        else
            throw(ArgumentError("occurrence kind is not sealed"))
        end
        new(operator_site_ref, port_side, Int(port_index), direction, occurrence_kind, ledger_identity)
    end
end

"""Coefficient-free identity for ownership closure and duplicate detection."""
function _g1_occurrence_key(x::ConservationLedgerOccurrenceRefV1)
    identity = getfield(x, :ledger_identity)
    ref = getfield(x, :operator_site_ref)
    (getfield(ref, :value), getfield(x, :port_side), getfield(x, :port_index),
        getfield(x, :direction), getfield(x, :occurrence_kind),
        invoke(_ledger_identity_full_key, Tuple{ConservationLedgerIdentityV1}, identity))
end
