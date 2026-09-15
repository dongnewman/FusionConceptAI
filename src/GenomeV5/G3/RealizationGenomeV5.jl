"""Candidate-owned G3 realization/resource contract.

The types in this file are an additive V5 slice.  They deliberately do not
modify the legacy realization/control genome or the default operator registry.
Schema, canonicalization and applicability-profile digests are derived from the
versioned field/rule source strings below; callers cannot replace them with a
stale or guessed digest.
"""

const _G3_V5_ALLOWED_DIRECTIONS = (:in, :out, :bidirectional)
const _G3_V5_RESOURCE_KINDS = (:effort, :flow, :load, :return, :heat_sink, :material)
const _G3_V5_LEDGER_DOMAINS = (:energy, :material, :thermal, :mechanical)
const _G3_V5_ENTRY_EFFECTS = (:source, :load, :return, :heat_rejection, :material_in,
                              :material_out, :loss, :deformation)
const _G3_V5_PROVIDER_MATCHES = (:unique_match, :no_match, :ambiguous,
                                 :out_of_domain, :invalid_signature)

function _g3_text(value, field::AbstractString)
    value isa AbstractString && !isempty(String(value)) && isvalid(String(value)) ||
        throw(ArgumentError("$field must be a non-empty valid UTF-8 string"))
    String(value)
end

function _g3_tuple(value, field::AbstractString)
    value isa Tuple || throw(ArgumentError("$field must be an immutable tuple"))
    value
end

function _g3_symbol(value, allowed, field::AbstractString)
    symbol = value isa Symbol ? value : Symbol(value)
    symbol in allowed || throw(ArgumentError("$field is invalid: $symbol"))
    symbol
end

function _g3_rational(value, field::AbstractString; positive=false, nonnegative=false)
    value isa Bool && throw(ArgumentError("$field must be exact Rational"))
    value isa Rational || value isa Integer || throw(ArgumentError("$field must be exact Rational or integer"))
    result = try Rational{Int64}(value) catch
        throw(ArgumentError("$field is outside Int64 rational range"))
    end
    positive && (result <= (0 // 1)) && throw(ArgumentError("$field must be positive"))
    nonnegative && (result < (0 // 1)) && throw(ArgumentError("$field must be non-negative"))
    result
end

const _G3_REALIZATION_SCHEMA_SOURCE_V5 = """
schema_id=GenomeV5/G3/RealizationGenomeV5
version=v5
fields=contract_binding:G3ContractBindingV2,network:G3ResourceNetworkV2,
material_domains:Tuple[G3MaterialDomainV2],manufacturing_domains:Tuple[G3ManufacturingDomainV2],
provider_match:enum(unique_match|no_match|ambiguous|out_of_domain|invalid_signature)
resource_port=port_id:String,kind:enum(effort|flow|load|return|heat_sink|material),
direction:enum(in|out|bidirectional),unit:UnitSignature,account_id:String
component=component_id:String,kind:Symbol,resource_port_ids:Tuple[String],capacity:positive Rational{Int64},
capacity_unit:UnitSignature,material_id:String,manufacturing_process_id:String,passive:Bool,
initial_states:Tuple[G3InitialStateV2],events:Tuple[G3EventV2]
initial_state=state_id:String,unit:UnitSignature,value:Rational{Int64}
event=event_id:String,trigger:enum(initial|scheduled|fault|threshold),time:nonnegative Rational{Int64},
action:enum(enable|disable|hold|trip|recover)
material_domain=material_id:String,property:enum(conductivity|resistivity|density|strength),
lower:Rational{Int64},upper:Rational{Int64},unit:UnitSignature,lower<upper
manufacturing_domain=process_id:String,parameter:enum(thickness|current_density|temperature|tolerance),
lower:Rational{Int64},upper:Rational{Int64},unit:UnitSignature,lower<upper
ledger_account=account_id:String,domain:enum(energy|material|thermal|mechanical),unit:UnitSignature,owner:String
ledger_entry=entry_id:String,account_id:String,port_id:String,component_id:String,
coefficient:nonzero Rational{Int64},unit:UnitSignature,effect:enum(source|load|return|heat_rejection|material_in|material_out|loss|deformation)
ledger_closure=closure_id:String,domain:ledger_domain,account_ids:nonempty_unique Tuple[String],expected_balance:Rational{Int64}
constraints=unique ids; every port/account/entry/component reference resolves; effort+flow+load+return+heat_sink required;
port units match kind; every resource port has a consumable entry and its account appears in a closure;
entries match account/port/component and account units; closure entries balance expected_balance;
non-effort source/load/return/heat entries cannot exceed the owning component capacity;
passive components cannot own source entries; no legacy v1 contract references
realization_hashes=plan_hash:Digest256,candidate_hash:Digest256
"""
const _G3_CONTROL_SCHEMA_SOURCE_V5 = """
schema_id=GenomeV5/G3/ControlGenomeV5
version=v5
fields=contract_binding:G3ContractBindingV2,signal_ports:Tuple[G3SignalPortV2],
controllers:Tuple[G3ControllerV2],faults:Tuple[G3FaultPathV2],plan:G3ControlPlanV2,
provider_match:enum(unique_match|no_match|ambiguous|out_of_domain|invalid_signature)
signal_port=port_id:String,signal_kind:Symbol,direction:enum(in|out|bidirectional),unit:UnitSignature,account_id:String
controller=controller_id:String,sensor_port_ids:Tuple[String],actuator_port_ids:Tuple[String],
actuator_resource_port_ids:Tuple[String],fault_ids:Tuple[String],initial_states:Tuple[G3InitialStateV2],events:Tuple[G3EventV2]
initial_state=state_id:String,unit:UnitSignature,value:Rational{Int64}
event=event_id:String,trigger:enum(initial|scheduled|fault|threshold),time:nonnegative Rational{Int64},
action:enum(enable|disable|hold|trip|recover)
fault_path=fault_id:String,target_id:String,mode:enum(open_circuit|short_circuit|sensor_dropout|actuator_stuck|overtemperature),
safe_action:enum(trip|hold|disable|recover),detection_signal_id:String,deadline:positive Rational{Int64}
constraints=unique ids; controller/fault/sensor/actuator/resource references resolve; signal/resource port units are typed;
actuator resource links require out or bidirectional resource direction;
fault detection and safe actions remain explicit; control plan controller_ids, signal_port_ids and fault_ids are
each non-empty and unique; no legacy v1 contract references
control_hashes=plan_hash:Digest256,candidate_hash:Digest256
"""
const _G3_BINDING_SCHEMA_SOURCE_V5 = """
schema_id=GenomeV5/G3/CoupledRealizationControlBindingV2
version=v2
fields=contract_binding:G3ContractBindingV2,realization_binding:G3ContractBindingV2,
control_binding:G3ContractBindingV2,links:Tuple[G3ControlResourceLinkV2],feedback:Tuple[G3FeedbackChannelV2]
contract_binding_record=contract_ref:GenomeContractRef,candidate_ref:QualifiedRefV1,version_axes:G3VersionAxesV2,binding_hash:Digest256
control_resource_link=link_id:String,controller_id:String,sensor_port_id:String,
actuator_port_id:String,resource_port_id:String,fault_id:String
feedback=feedback_id:String,target_layer:enum(G1|G2),target_contract_ref:GenomeContractRef,
channel:enum(residual|loss|heat|shape),unit:UnitSignature,kind:enum(implementation_error|loss|thermal_load|deformation),source_id:String
constraints=all three child refs resolve to their exact authoritative layer contracts;
all child candidate refs equal bundle candidate; links resolve controller/sensor/actuator/resource/fault;
feedback target refs are explicit and typed; at least one control-resource link closes the loop;
binding_hash=Digest256
"""
const _G3_BUNDLE_SCHEMA_SOURCE_V5 = """
schema_id=GenomeV5/G3/RealizationControlGenomeV5
version=v5
fields=contract_binding:G3ContractBindingV2,realization:RealizationGenomeV5,control:ControlGenomeV5,
binding:CoupledRealizationControlBindingV2,admission:G3AdmissionResultV2,candidate_hash:Digest256
admission=structural_status:Symbol,provider_match:Symbol,resolution:Symbol,errors:Tuple[String],gaps:Tuple[String],
realization_plan_hash:Digest256,control_plan_hash:Digest256,binding_hash:Digest256,candidate_hash:Digest256
children=realization_contract_ref:GenomeContractRef,control_contract_ref:GenomeContractRef,binding_contract_ref:GenomeContractRef
version_axes=payload_schema,canonicalization_profile,applicability_profile,evidence_receipt
constraints=external bundle and all three child refs equal authoritative URI/version/schema/canonical/profile values;
all four version axes are exact for their layer; every child candidate binding equals bundle candidate;
resource/control/binding hashes and admission are candidate-bound; provider gaps are terminal_deferred;
no provider, engineering or physical result may be inferred from structural admission
"""
const _G3_CANONICALIZATION_SOURCE_V5 = """
canonicalization_id=GenomeV5/G3/canonicalization/v5
encoding=UTF-8; line_endings=LF; Unicode=valid scalar values; strings=preserve case and ordinal bytes
objects=field-name order ascending by ordinal codepoint; tuples=preserve declared order; sets=never implicit
integers=base10; rationals=normalized numerator/positive denominator; symbols=serialized by name
unit_signature=ordered seven-base-dimension exponents; digest=SHA-256 of canonical UTF-8 bytes
identity=include contract refs, four axes, candidate ref, typed ports, constraints, provider status and edits
"""
const _G3_PROFILE_SOURCE_V5 = """
profile_id=GenomeV5/G3/applicability/v5
capability_domains=resource_network,control_fault,ledger_closure,candidate_binding,typed_feedback
allowed_resource_kinds=effort,flow,load,return,heat_sink,material
required_resource_kinds=effort,flow,load,return,heat_sink
allowed_ledger_domains=energy,material,thermal,mechanical
required_checks=unit_compatibility,reference_resolution,owner_uniqueness,closure_balance,
source_return_heat_sink_presence,control_loop_closure,fault_path_resolution,candidate_identity
provider_policy=unique_match only resolves; no_match|ambiguous|out_of_domain|invalid_signature terminal_deferred
physical_policy=structural contracts never imply engineering or physical execution
"""

_g3_schema_hash(source::AbstractString) = digest256_text(source)
_g3_canonicalization_hash() = digest256_text(_G3_CANONICALIZATION_SOURCE_V5)
_g3_profile_hash() = digest256_text(_G3_PROFILE_SOURCE_V5)

function _g3_authoritative_axes(layer::Symbol)
    prefix = "fusionconceptai://GenomeV5/G3/" * String(layer)
    payload_version = layer === :binding ? "v2" : "v5"
    G3VersionAxesV2(QualifiedRefV1(prefix * "/payload-schema", payload_version),
        QualifiedRefV1(prefix * "/canonicalization-profile", "v5"),
        QualifiedRefV1(prefix * "/applicability-profile", "v5"),
        QualifiedRefV1(prefix * "/evidence-receipt", "v2"))
end

g3_version_axes(layer::Symbol) = _g3_authoritative_axes(layer)

function _g3_layer_contract_ref(layer::Symbol)
    source = layer === :realization ? _G3_REALIZATION_SCHEMA_SOURCE_V5 :
        layer === :control ? _G3_CONTROL_SCHEMA_SOURCE_V5 :
        layer === :binding ? _G3_BINDING_SCHEMA_SOURCE_V5 :
        layer === :bundle ? _G3_BUNDLE_SCHEMA_SOURCE_V5 :
        throw(ArgumentError("unknown G3 contract layer"))
    contract_version = layer === :binding ? "v2" : "v5"
    GenomeContractRef("fusionconceptai://GenomeV5/G3/" * String(layer), contract_version,
        _g3_schema_hash(source), _g3_canonicalization_hash(),
        "g3-v5-" * String(layer) * "-candidate-owned-profile-" * string(_g3_profile_hash()))
end

g3_contract_ref(layer::Symbol) = _g3_layer_contract_ref(layer)

function _g3_require_candidate(candidate_ref::QualifiedRefV1)
    candidate_ref.version == "v5" || throw(ArgumentError("G3 candidate binding requires version v5"))
    startswith(candidate_ref.id, "fusionconceptai://candidate/") ||
        throw(ArgumentError("G3 candidate binding requires a candidate-owned URI"))
    candidate_ref
end

struct G3VersionAxesV2
    payload_schema_version::QualifiedRefV1
    canonicalization_profile_version::QualifiedRefV1
    applicability_profile_version::QualifiedRefV1
    evidence_receipt_version::QualifiedRefV1
    function G3VersionAxesV2(payload_schema_version::Any,
            canonicalization_profile_version::Any,
            applicability_profile_version::Any,
            evidence_receipt_version::Any)
        refs = (payload_schema_version, canonicalization_profile_version,
            applicability_profile_version, evidence_receipt_version)
        all(x -> x isa QualifiedRefV1, refs) ||
            throw(ArgumentError("G3 version axes require QualifiedRefV1"))
        all(x -> x.version != "v1", refs) ||
            throw(ArgumentError("G3 version axes cannot reinterpret legacy v1"))
        new(refs...)
    end
end

semantic_view(x::G3VersionAxesV2) =
    (payload_schema_version=x.payload_schema_version,
     canonicalization_profile_version=x.canonicalization_profile_version,
      applicability_profile_version=x.applicability_profile_version,
      evidence_receipt_version=x.evidence_receipt_version)

function _g3_contract_layer(ref::GenomeContractRef)::Symbol
    prefix = "fusionconceptai://GenomeV5/G3/"
    startswith(ref.uri, prefix) || throw(ArgumentError("G3 contract URI is outside the authoritative V5 domain"))
    suffix = ref.uri[length(prefix) + 1:end]
    suffix in ("realization", "control", "binding", "bundle") ||
        throw(ArgumentError("G3 contract URI has an unknown layer: $suffix"))
    Symbol(suffix)
end

function _g3_validate_authoritative_ref(ref::GenomeContractRef, layer::Symbol)
    expected = g3_contract_ref(layer)
    ref == expected || throw(ArgumentError(
        "G3 $layer contract ref does not match its versioned schema/canonical/profile identity"))
    ref
end

function _g3_validate_authoritative_axes(axes::G3VersionAxesV2, layer::Symbol)
    canonical_hash(axes) == canonical_hash(g3_version_axes(layer)) || throw(ArgumentError(
        "G3 $layer version axes do not match the authoritative four-axis identity"))
    axes
end

struct G3ContractBindingV2
    contract_ref::GenomeContractRef
    candidate_ref::QualifiedRefV1
    version_axes::G3VersionAxesV2
    binding_hash::Digest256
    function G3ContractBindingV2(contract_ref::Any, candidate_ref::Any,
            version_axes::Any)
        contract_ref isa GenomeContractRef ||
            throw(ArgumentError("G3 contract binding requires GenomeContractRef"))
        layer = _g3_contract_layer(contract_ref)
        _g3_validate_authoritative_ref(contract_ref, layer)
        candidate_ref isa QualifiedRefV1 ||
            throw(ArgumentError("G3 candidate binding requires QualifiedRefV1"))
        _g3_require_candidate(candidate_ref)
        version_axes isa G3VersionAxesV2 ||
            throw(ArgumentError("G3 contract binding requires four version axes"))
        _g3_validate_authoritative_axes(version_axes, layer)
        body = (contract_ref=contract_ref, candidate_ref=candidate_ref,
            version_axes=version_axes)
        new(contract_ref, candidate_ref, version_axes, canonical_hash(body))
    end
end

semantic_view(x::G3ContractBindingV2) =
    (contract_ref=x.contract_ref, candidate_ref=x.candidate_ref,
     version_axes=x.version_axes, binding_hash=x.binding_hash)

struct G3ResourcePortV2
    port_id::String
    kind::Symbol
    direction::Symbol
    unit::UnitSignature
    account_id::String
    function G3ResourcePortV2(port_id::Any, kind::Any, direction::Any,
            unit::Any, account_id::Any)
        id = _g3_text(port_id, "resource port_id")
        k = _g3_symbol(kind, _G3_V5_RESOURCE_KINDS, "resource port kind")
        d = _g3_symbol(direction, _G3_V5_ALLOWED_DIRECTIONS, "resource port direction")
        unit isa UnitSignature || throw(ArgumentError("resource port unit must be UnitSignature"))
        account = _g3_text(account_id, "resource port account_id")
        new(id, k, d, unit, account)
    end
end

struct G3SignalPortV2
    port_id::String
    signal_kind::Symbol
    direction::Symbol
    unit::UnitSignature
    account_id::String
    function G3SignalPortV2(port_id::Any, signal_kind::Any, direction::Any,
            unit::Any, account_id::Any)
        id = _g3_text(port_id, "signal port_id")
        kind = _g3_text(signal_kind isa Symbol ? String(signal_kind) : signal_kind, "signal kind")
        d = _g3_symbol(direction, _G3_V5_ALLOWED_DIRECTIONS, "signal port direction")
        unit isa UnitSignature || throw(ArgumentError("signal port unit must be UnitSignature"))
        account = _g3_text(account_id, "signal port account_id")
        new(id, Symbol(kind), d, unit, account)
    end
end

semantic_view(x::G3ResourcePortV2) =
    (port_id=x.port_id, kind=x.kind, direction=x.direction, unit=x.unit,
     account_id=x.account_id)
semantic_view(x::G3SignalPortV2) =
    (port_id=x.port_id, signal_kind=x.signal_kind, direction=x.direction,
     unit=x.unit, account_id=x.account_id)

struct G3InitialStateV2
    state_id::String
    unit::UnitSignature
    value::Rational{Int64}
    function G3InitialStateV2(state_id::Any, unit::Any, value::Any)
        id = _g3_text(state_id, "initial state_id")
        unit isa UnitSignature || throw(ArgumentError("initial state unit must be UnitSignature"))
        new(id, unit, _g3_rational(value, "initial state value"))
    end
end

struct G3EventV2
    event_id::String
    trigger::Symbol
    time::Rational{Int64}
    action::Symbol
    function G3EventV2(event_id::Any, trigger::Any, time::Any, action::Any)
        id = _g3_text(event_id, "event_id")
        t = _g3_symbol(trigger, (:initial, :scheduled, :fault, :threshold), "event trigger")
        a = _g3_symbol(action, (:enable, :disable, :hold, :trip, :recover), "event action")
        new(id, t, _g3_rational(time, "event time"; nonnegative=true), a)
    end
end

semantic_view(x::G3InitialStateV2) = (state_id=x.state_id, unit=x.unit, value=x.value)
semantic_view(x::G3EventV2) =
    (event_id=x.event_id, trigger=x.trigger, time=x.time, action=x.action)

struct G3MaterialDomainV2
    material_id::String
    property::Symbol
    lower::Rational{Int64}
    upper::Rational{Int64}
    unit::UnitSignature
    function G3MaterialDomainV2(material_id::Any, property::Any, lower::Any,
            upper::Any, unit::Any)
        id = _g3_text(material_id, "material_id")
        p = _g3_symbol(property, (:conductivity, :resistivity, :density, :strength),
            "material property")
        lo = _g3_rational(lower, "material lower")
        hi = _g3_rational(upper, "material upper")
        lo < hi || throw(ArgumentError("material domain must have lower < upper"))
        unit isa UnitSignature || throw(ArgumentError("material domain unit must be UnitSignature"))
        new(id, p, lo, hi, unit)
    end
end

struct G3ManufacturingDomainV2
    process_id::String
    parameter::Symbol
    lower::Rational{Int64}
    upper::Rational{Int64}
    unit::UnitSignature
    function G3ManufacturingDomainV2(process_id::Any, parameter::Any, lower::Any,
            upper::Any, unit::Any)
        id = _g3_text(process_id, "manufacturing process_id")
        p = _g3_symbol(parameter, (:thickness, :current_density, :temperature,
            :tolerance), "manufacturing parameter")
        lo = _g3_rational(lower, "manufacturing lower")
        hi = _g3_rational(upper, "manufacturing upper")
        lo < hi || throw(ArgumentError("manufacturing domain must have lower < upper"))
        unit isa UnitSignature || throw(ArgumentError("manufacturing domain unit must be UnitSignature"))
        new(id, p, lo, hi, unit)
    end
end

semantic_view(x::G3MaterialDomainV2) =
    (material_id=x.material_id, property=x.property, lower=x.lower, upper=x.upper, unit=x.unit)
semantic_view(x::G3ManufacturingDomainV2) =
    (process_id=x.process_id, parameter=x.parameter, lower=x.lower, upper=x.upper, unit=x.unit)

struct G3RealizationComponentV2
    component_id::String
    kind::Symbol
    resource_port_ids::Tuple{Vararg{String}}
    capacity::Rational{Int64}
    capacity_unit::UnitSignature
    material_id::String
    manufacturing_process_id::String
    passive::Bool
    initial_states::Tuple{Vararg{G3InitialStateV2}}
    events::Tuple{Vararg{G3EventV2}}
    function G3RealizationComponentV2(component_id::Any, kind::Any,
            resource_port_ids::Any, capacity::Any, capacity_unit::Any,
            material_id::Any, manufacturing_process_id::Any, passive::Any,
            initial_states::Any=(), events::Any=())
        id = _g3_text(component_id, "component_id")
        k = Symbol(_g3_text(kind isa Symbol ? String(kind) : kind, "component kind"))
        ports = _g3_tuple(resource_port_ids, "component resource_port_ids")
        all(x -> x isa AbstractString && !isempty(String(x)), ports) ||
            throw(ArgumentError("component resource port ids are invalid"))
        unit = capacity_unit isa UnitSignature ? capacity_unit :
            throw(ArgumentError("component capacity unit must be UnitSignature"))
        passive isa Bool || throw(ArgumentError("component passive must be Bool"))
        states = _g3_tuple(initial_states, "component initial_states")
        events_tuple = _g3_tuple(events, "component events")
        all(x -> x isa G3InitialStateV2, states) ||
            throw(ArgumentError("component initial states are not typed"))
        all(x -> x isa G3EventV2, events_tuple) ||
            throw(ArgumentError("component events are not typed"))
        new(id, k, Tuple(String.(ports)), _g3_rational(capacity, "component capacity"; positive=true),
            unit, _g3_text(material_id, "component material_id"),
            _g3_text(manufacturing_process_id, "component manufacturing_process_id"),
            passive, Tuple(states), Tuple(events_tuple))
    end
end

struct G3LedgerAccountV2
    account_id::String
    domain::Symbol
    unit::UnitSignature
    owner::String
    function G3LedgerAccountV2(account_id::Any, domain::Any, unit::Any, owner::Any)
        id = _g3_text(account_id, "ledger account_id")
        d = _g3_symbol(domain, _G3_V5_LEDGER_DOMAINS, "ledger domain")
        unit isa UnitSignature || throw(ArgumentError("ledger account unit must be UnitSignature"))
        new(id, d, unit, _g3_text(owner, "ledger owner"))
    end
end

struct G3LedgerEntryV2
    entry_id::String
    account_id::String
    port_id::String
    component_id::String
    coefficient::Rational{Int64}
    unit::UnitSignature
    effect::Symbol
    function G3LedgerEntryV2(entry_id::Any, account_id::Any, port_id::Any,
            component_id::Any, coefficient::Any, unit::Any, effect::Any)
        unit isa UnitSignature || throw(ArgumentError("ledger entry unit must be UnitSignature"))
        e = _g3_symbol(effect, _G3_V5_ENTRY_EFFECTS, "ledger entry effect")
        coefficient_value = _g3_rational(coefficient, "ledger coefficient")
        coefficient_value != (0 // 1) || throw(ArgumentError("ledger coefficient cannot be zero"))
        new(_g3_text(entry_id, "ledger entry_id"), _g3_text(account_id, "ledger account_id"),
            _g3_text(port_id, "ledger port_id"), _g3_text(component_id, "ledger component_id"),
            coefficient_value, unit, e)
    end
end

struct G3LedgerClosureV2
    closure_id::String
    domain::Symbol
    account_ids::Tuple{Vararg{String}}
    expected_balance::Rational{Int64}
    function G3LedgerClosureV2(closure_id::Any, domain::Any, account_ids::Any,
            expected_balance::Any=0 // 1)
        ids = _g3_tuple(account_ids, "closure account_ids")
        !isempty(ids) && all(x -> x isa AbstractString && !isempty(String(x)), ids) ||
            throw(ArgumentError("closure account_ids must be non-empty"))
        length(unique(String.(ids))) == length(ids) ||
            throw(ArgumentError("closure account_ids must be unique"))
        new(_g3_text(closure_id, "closure_id"),
            _g3_symbol(domain, _G3_V5_LEDGER_DOMAINS, "closure domain"),
            Tuple(String.(ids)), _g3_rational(expected_balance, "closure expected_balance"))
    end
end

semantic_view(x::G3RealizationComponentV2) =
    (component_id=x.component_id, kind=x.kind, resource_port_ids=x.resource_port_ids,
     capacity=x.capacity, capacity_unit=x.capacity_unit, material_id=x.material_id,
     manufacturing_process_id=x.manufacturing_process_id, passive=x.passive,
     initial_states=x.initial_states, events=x.events)
semantic_view(x::G3LedgerAccountV2) =
    (account_id=x.account_id, domain=x.domain, unit=x.unit, owner=x.owner)
semantic_view(x::G3LedgerEntryV2) =
    (entry_id=x.entry_id, account_id=x.account_id, port_id=x.port_id,
     component_id=x.component_id, coefficient=x.coefficient, unit=x.unit, effect=x.effect)
semantic_view(x::G3LedgerClosureV2) =
    (closure_id=x.closure_id, domain=x.domain, account_ids=x.account_ids,
     expected_balance=x.expected_balance)

struct G3ResourceNetworkV2
    components::Tuple{Vararg{G3RealizationComponentV2}}
    resource_ports::Tuple{Vararg{G3ResourcePortV2}}
    accounts::Tuple{Vararg{G3LedgerAccountV2}}
    entries::Tuple{Vararg{G3LedgerEntryV2}}
    closures::Tuple{Vararg{G3LedgerClosureV2}}
    function G3ResourceNetworkV2(components::Any, resource_ports::Any, accounts::Any,
            entries::Any, closures::Any)
        cs = _g3_tuple(components, "components"); ps = _g3_tuple(resource_ports, "resource_ports")
        ac = _g3_tuple(accounts, "accounts"); es = _g3_tuple(entries, "entries"); cl = _g3_tuple(closures, "closures")
        all(x -> x isa G3RealizationComponentV2, cs) || throw(ArgumentError("invalid realization component"))
        all(x -> x isa G3ResourcePortV2, ps) || throw(ArgumentError("invalid resource port"))
        all(x -> x isa G3LedgerAccountV2, ac) || throw(ArgumentError("invalid ledger account"))
        all(x -> x isa G3LedgerEntryV2, es) || throw(ArgumentError("invalid ledger entry"))
        all(x -> x isa G3LedgerClosureV2, cl) || throw(ArgumentError("invalid ledger closure"))
        for (xs, label) in ((cs, "component"), (ps, "resource port"),
                            (ac, "ledger account"), (es, "ledger entry"), (cl, "ledger closure"))
            ids = Tuple(label == "component" ? x.component_id : label == "resource port" ? x.port_id :
                label == "ledger account" ? x.account_id : label == "ledger entry" ? x.entry_id : x.closure_id for x in xs)
            length(unique(ids)) == length(ids) || throw(ArgumentError("duplicate $label id"))
        end
        new(Tuple(cs), Tuple(ps), Tuple(ac), Tuple(es), Tuple(cl))
    end
end

semantic_view(x::G3ResourceNetworkV2) =
    (components=x.components, resource_ports=x.resource_ports, accounts=x.accounts,
     entries=x.entries, closures=x.closures)

function _g3_expected_unit(kind::Symbol)
    kind === :effort && return UnitSignature((1, 2, -3, -1, 0, 0, 0))
    kind in (:flow, :return) && return UnitSignature((0, 0, 0, 1, 0, 0, 0))
    kind in (:load, :heat_sink) && return UnitSignature((1, 2, -3, 0, 0, 0, 0))
    kind === :material && return UnitSignature((0, 0, 0, 0, 0, 1, 0))
    throw(ArgumentError("no expected unit for resource kind $kind"))
end

function g3_validate_resource_network(network::G3ResourceNetworkV2)
    errors = String[]
    component_map = Dict(x.component_id => x for x in network.components)
    port_map = Dict(x.port_id => x for x in network.resource_ports)
    account_map = Dict(x.account_id => x for x in network.accounts)
    entries_by_port = Dict{String,Vector{G3LedgerEntryV2}}()
    for entry in network.entries
        push!(get!(entries_by_port, entry.port_id, G3LedgerEntryV2[]), entry)
    end
    closure_accounts = Set(String(id) for c in network.closures for id in c.account_ids)
    for port in network.resource_ports
        haskey(account_map, port.account_id) || push!(errors, "port_account_missing:" * port.port_id)
        port.unit == _g3_expected_unit(port.kind) || push!(errors, "resource_unit_mismatch:" * port.port_id)
        entries = get(entries_by_port, port.port_id, G3LedgerEntryV2[])
        isempty(entries) && push!(errors, "missing_consumable_entry:" * port.port_id)
        port.account_id in closure_accounts || push!(errors, "missing_consumable_closure:" * port.port_id)
    end
    for component in network.components
        all(haskey(port_map, id) for id in component.resource_port_ids) ||
            push!(errors, "component_port_missing:" * component.component_id)
    end
    for entry in network.entries
        haskey(account_map, entry.account_id) || push!(errors, "entry_account_missing:" * entry.entry_id)
        haskey(port_map, entry.port_id) || push!(errors, "entry_port_missing:" * entry.entry_id)
        haskey(component_map, entry.component_id) || push!(errors, "entry_component_missing:" * entry.entry_id)
        if haskey(port_map, entry.port_id) && haskey(account_map, entry.account_id)
            port_map[entry.port_id].account_id == entry.account_id ||
                push!(errors, "entry_port_account_mismatch:" * entry.entry_id)
            entry.unit == account_map[entry.account_id].unit ||
                push!(errors, "entry_account_unit_mismatch:" * entry.entry_id)
        end
        if haskey(port_map, entry.port_id) && haskey(component_map, entry.component_id)
            port = port_map[entry.port_id]
            component = component_map[entry.component_id]
            if port.kind !== :effort && entry.effect in (:source, :load, :return, :heat_rejection)
                entry.unit == component.capacity_unit ||
                    push!(errors, "component_capacity_unit_mismatch:" * entry.entry_id)
                entry.unit == component.capacity_unit && abs(entry.coefficient) > component.capacity &&
                    push!(errors, "component_capacity_exceeded:" * entry.entry_id)
            end
        end
        if haskey(component_map, entry.component_id) && component_map[entry.component_id].passive && entry.effect === :source
            push!(errors, "passive_component_cannot_source:" * entry.entry_id)
        end
    end
    required = (:effort, :flow, :load, :return, :heat_sink)
    for kind in required
        any(p -> p.kind === kind, network.resource_ports) || push!(errors, "missing_required_resource_port:$kind")
    end
    for closure in network.closures
        all(haskey(account_map, id) for id in closure.account_ids) ||
            push!(errors, "closure_account_missing:" * closure.closure_id)
        relevant = Tuple(e for e in network.entries if e.account_id in closure.account_ids)
        isempty(relevant) && push!(errors, "closure_has_no_entries:" * closure.closure_id)
        if !isempty(relevant)
            known_relevant = Tuple(e for e in relevant if haskey(account_map, e.account_id))
            length(known_relevant) == length(relevant) ||
                push!(errors, "closure_entry_account_missing:" * closure.closure_id)
            all(account_map[e.account_id].domain === closure.domain for e in known_relevant) ||
                push!(errors, "closure_domain_mismatch:" * closure.closure_id)
            sum((e.coefficient for e in relevant); init=0 // 1) == closure.expected_balance ||
                push!(errors, "ledger_balance_mismatch:" * closure.closure_id)
        end
    end
    unique!(errors)
end

struct RealizationGenomeV5
    contract_binding::G3ContractBindingV2
    network::G3ResourceNetworkV2
    material_domains::Tuple{Vararg{G3MaterialDomainV2}}
    manufacturing_domains::Tuple{Vararg{G3ManufacturingDomainV2}}
    provider_match::Symbol
    plan_hash::Digest256
    candidate_hash::Digest256
    function RealizationGenomeV5(contract_binding::Any, network::Any,
            material_domains::Any, manufacturing_domains::Any;
            provider_match=:no_match)
        contract_binding isa G3ContractBindingV2 || throw(ArgumentError("realization requires G3ContractBindingV2"))
        network isa G3ResourceNetworkV2 || throw(ArgumentError("realization requires G3ResourceNetworkV2"))
        materials = _g3_tuple(material_domains, "material_domains")
        manufacturing = _g3_tuple(manufacturing_domains, "manufacturing_domains")
        all(x -> x isa G3MaterialDomainV2, materials) || throw(ArgumentError("invalid material domain"))
        all(x -> x isa G3ManufacturingDomainV2, manufacturing) || throw(ArgumentError("invalid manufacturing domain"))
        match = _g3_symbol(provider_match, _G3_V5_PROVIDER_MATCHES, "realization provider_match")
        body = (network=network, material_domains=Tuple(materials), manufacturing_domains=Tuple(manufacturing))
        plan_hash = canonical_hash(body)
        candidate_hash = canonical_hash((contract_binding=contract_binding, body=body, provider_match=match))
        new(contract_binding, network, Tuple(materials), Tuple(manufacturing), match, plan_hash, candidate_hash)
    end
end

semantic_view(x::RealizationGenomeV5) =
    (contract_binding=x.contract_binding, network=x.network, material_domains=x.material_domains,
     manufacturing_domains=x.manufacturing_domains, provider_match=x.provider_match,
     plan_hash=x.plan_hash, candidate_hash=x.candidate_hash)

function g3_edit_component_capacity(genome::RealizationGenomeV5, component_id::AbstractString,
        capacity::Union{Integer,Rational})
    id = String(component_id); found = false
    rebuilt = G3RealizationComponentV2[]
    for component in genome.network.components
        if component.component_id == id
            found = true
            push!(rebuilt, G3RealizationComponentV2(component.component_id, component.kind,
                component.resource_port_ids, capacity, component.capacity_unit,
                component.material_id, component.manufacturing_process_id, component.passive,
                component.initial_states, component.events))
        else
            push!(rebuilt, component)
        end
    end
    found || throw(ArgumentError("unknown realization component"))
    network = G3ResourceNetworkV2(Tuple(rebuilt), genome.network.resource_ports,
        genome.network.accounts, genome.network.entries, genome.network.closures)
    RealizationGenomeV5(genome.contract_binding, network, genome.material_domains,
        genome.manufacturing_domains; provider_match=genome.provider_match)
end
