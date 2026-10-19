"""Closed, realization-only source editability precursor for G3 V1.

This file is intentionally additive.  It does not import or modify the G3 V5
genomes, T0 transport, package, registry, provider, mesh, or solver paths.
The constructors and the replacement operation are contract admission only;
physical resolution remains an independent status and cannot be promoted by a
local hash or test receipt.
"""

const G3_REALIZATION_CHILD_EDIT_SCHEMA_ID_V1 =
    "GenomeV5/G3/G3RealizationChildEditabilityV1"
const G3_REALIZATION_CHILD_EDIT_VERSION_V1 = "v1"
const G3_REALIZATION_CHILD_EDIT_CONTRACT_URI_V1 =
    "fusionconceptai://GenomeV5/G3/realization-child-editability"
const G3_REALIZATION_CHILD_EDIT_PROFILE_V1 = "closed-source-edit-v1"
const G3_REALIZATION_CHILD_EDIT_SOURCE_URI_V1 =
    "fusionconceptai://GenomeV5/G3/realization-source-record"
const G3_REALIZATION_CHILD_EDIT_SOURCE_VERSION_V1 = "v1"
const G3_REALIZATION_CHILD_EDIT_KIND_V1 = :realization
const G3_REALIZATION_CHILD_EDIT_ZERO_DIGEST_V1 = Digest256(repeat("0", 64))
const G3_REALIZATION_CHILD_EDIT_PORT_ROLES_V1 = (:source, :field, :return, :heat)
const G3_REALIZATION_CHILD_EDIT_DIRECTIONS_V1 = (:in, :out, :bidirectional)
const G3_REALIZATION_CHILD_EDIT_SLOT_KINDS_V1 =
    (:schema, :canonicalization, :profile, :evidence_receipt)
const G3_REALIZATION_CHILD_EDIT_SLOT_STATUSES_V1 = (:present, :typed_absent)
const G3_REALIZATION_CHILD_EDIT_CONTRACT_STATUSES_V1 =
    (:declared_consistent, :terminal_deferred, :fail_closed, :program_exception)
const G3_AUTHORED_SI_BASIS_V1 = (:kg, :m, :s, :A, :K, :mol, :cd)

const _G3_REALIZATION_CHILD_EDIT_SCHEMA_SOURCE_V1 = """
schema_id=GenomeV5/G3/G3RealizationChildEditabilityV1
version=v1
scope=realization-only candidate-owned closed source body
body=source_id,owner_scope,ports,components,material_domains,manufacturing_domains,ledger_accounts,ledger_entries,ledger_closures,source_power,field_power,return_power,heat_power,capacity,capacity_unit,closure_residual
payload=typed parent G3 declaration ref/hash, additive child contract ref/identity hash, source uri/version, body, closed source record, source_content_hash
record=source uri/version, exactly schema/canonicalization/profile/evidence_receipt provenance slots, source_record_hash
operation=replace_source_payload(operation_id,key,expected_prior_state_hash,expected_prior_source_content_hash,replacement_payload,source_record_ref,operation_hash)
"""
const _G3_REALIZATION_CHILD_EDIT_CANONICAL_SOURCE_V1 = """
encoding=UTF-8;line_endings=LF;tuple_order=declared;symbols=ordinal;rationals=normalized
hashes=contract_identity,source_record,source_content,initial_state,current_state,operation
source_record_hash excludes source_record_hash, source_content_hash and operation_hash
source_content_hash excludes itself; operation_hash excludes resulting state_hash
initial_state_hash is created once and remains frozen across the ordered operation history
"""
const _G3_REALIZATION_CHILD_EDIT_PROFILE_SOURCE_V1 = """
admission=closed typed construction, exact identity, source-law closure and provenance classification
missing_provenance=typed_absent; local status=terminal_deferred; absent has no source hash
conflict=fail_closed; unexpected=program_exception
physical_resolution=independent unknown or terminal_deferred; local edit cannot promote physical
"""

g3_realization_child_edit_schema_hash_v1() = digest256_text(_G3_REALIZATION_CHILD_EDIT_SCHEMA_SOURCE_V1)
g3_realization_child_edit_canonicalization_hash_v1() = digest256_text(_G3_REALIZATION_CHILD_EDIT_CANONICAL_SOURCE_V1)
g3_realization_child_edit_profile_hash_v1() = digest256_text(_G3_REALIZATION_CHILD_EDIT_PROFILE_SOURCE_V1)

function _g3rce_text(value, field::AbstractString)
    value isa AbstractString || throw(ArgumentError("$field must be String"))
    text = String(value)
    !isempty(text) && isvalid(text) || throw(ArgumentError("$field must be non-empty UTF-8"))
    text
end
_g3rce_ref(value, field) = value isa QualifiedRefV1 ? value : throw(ArgumentError("$field must be QualifiedRefV1"))
_g3rce_digest(value, field) = value isa Digest256 ? value : throw(ArgumentError("$field must be Digest256"))
_g3rce_unit(value, field) = value isa UnitSignature ? value : throw(ArgumentError("$field must be UnitSignature"))
_g3rce_tuple(value, field) = value isa Tuple ? value : throw(ArgumentError("$field must be an immutable Tuple"))
_g3rce_structural_conflict(reason) =
    reason isa AbstractString && startswith(String(reason), "structural conflict:")

function _g3rce_symbol(value, allowed, field)
    symbol = value isa Symbol ? value : Symbol(value)
    symbol in allowed || throw(ArgumentError("$field is invalid: $symbol"))
    symbol
end

function _g3rce_rat(value, field; nonnegative=false, positive=false)
    value isa Bool && throw(ArgumentError("$field must be exact Rational"))
    value isa Rational || value isa Integer || throw(ArgumentError("$field must be exact Rational or integer"))
    result = try Rational{Int64}(value) catch
        throw(ArgumentError("$field is outside Int64 rational range"))
    end
    nonnegative && result < 0 && throw(ArgumentError("$field must be non-negative"))
    positive && result <= 0 && throw(ArgumentError("$field must be positive"))
    result
end

"""Candidate-authored V-I-P identity; not a measurement or provider receipt."""
struct G3AuthoredPowerLawV1
    law_id::String
    effort_port_id::String
    current_port_id::String
    power_endpoint_id::String
    voltage::Rational{Int64}
    current::Rational{Int64}
    power::Rational{Int64}
    voltage_unit::UnitSignature
    current_unit::UnitSignature
    power_unit::UnitSignature
    claim_scope::Symbol
    function G3AuthoredPowerLawV1(law_id, effort_port_id, current_port_id,
            power_endpoint_id, voltage, current, power, voltage_unit,
            current_unit, power_unit, claim_scope=:candidate_design_only)
        v = _g3rce_rat(voltage, "authored voltage"; positive=true)
        i = _g3rce_rat(current, "authored current"; nonnegative=true)
        p = _g3rce_rat(power, "authored power"; nonnegative=true)
        voltage_unit isa UnitSignature && current_unit isa UnitSignature &&
            power_unit isa UnitSignature || throw(ArgumentError("authored V-I-P units must be UnitSignature"))
        voltage_unit == UnitSignature((1, 2, -3, -1, 0, 0, 0)) ||
            throw(ArgumentError("voltage unit must use declared kg,m,s,A,K,mol,cd basis"))
        current_unit == UnitSignature((0, 0, 0, 1, 0, 0, 0)) ||
            throw(ArgumentError("current unit must use declared kg,m,s,A,K,mol,cd basis"))
        power_unit == UnitSignature((1, 2, -3, 0, 0, 0, 0)) ||
            throw(ArgumentError("power unit must use declared kg,m,s,A,K,mol,cd basis"))
        v * i == p || throw(ArgumentError("authored voltage-current product differs from power"))
        claim_scope === :candidate_design_only ||
            throw(ArgumentError("authored V-I-P law is candidate_design_only"))
        new(_g3rce_text(law_id, "law_id"),
            _g3rce_text(effort_port_id, "effort_port_id"),
            _g3rce_text(current_port_id, "current_port_id"),
            _g3rce_text(power_endpoint_id, "power_endpoint_id"),
            v, i, p, voltage_unit, current_unit, power_unit, claim_scope)
    end
end

function _g3rce_candidate(value, field="candidate_ref")
    ref = _g3rce_ref(value, field)
    ref.version == "v5" || throw(ArgumentError("$field must use candidate version v5"))
    ref
end

function _g3rce_parent(value)
    ref = _g3rce_ref(value, "parent_g3_declaration_ref")
    ref.version == "v1" || throw(ArgumentError("parent G3 declaration ref must use version v1"))
    ref
end

struct G3RealizationChildKeyV1
    candidate_ref::QualifiedRefV1
    parent_g3_declaration_hash::Digest256
    child_kind::Symbol
    child_id::String
    function G3RealizationChildKeyV1(candidate_ref::Any, parent_hash::Any,
            child_kind::Any, child_id::Any)
        c = _g3rce_candidate(candidate_ref)
        h = _g3rce_digest(parent_hash, "parent_g3_declaration_hash")
        k = _g3rce_symbol(child_kind, (G3_REALIZATION_CHILD_EDIT_KIND_V1,), "child_kind")
        i = _g3rce_text(child_id, "child_id")
        new(c, h, k, i)
    end
end

struct G3RealizationSourcePortV1
    port_id::String
    role::Symbol
    unit::UnitSignature
    direction::Symbol
    sign::Int8
    owner_scope::String
    function G3RealizationSourcePortV1(port_id::Any, role::Any, unit::Any,
            direction::Any, sign::Any, owner_scope::Any="")
        p = _g3rce_text(port_id, "port_id")
        r = _g3rce_symbol(role, G3_REALIZATION_CHILD_EDIT_PORT_ROLES_V1, "role")
        u = _g3rce_unit(unit, "unit")
        d = _g3rce_symbol(direction, G3_REALIZATION_CHILD_EDIT_DIRECTIONS_V1, "direction")
        sign isa Bool || sign isa Integer || throw(ArgumentError("sign must be +1 or -1"))
        sign in (-1, 1) || throw(ArgumentError("sign must be +1 or -1"))
        owner = isempty(String(owner_scope)) ? "unbound" : _g3rce_text(owner_scope, "owner_scope")
        new(p, r, u, d, Int8(sign), owner)
    end
end

const G3_REALIZATION_CHILD_EDIT_COMPONENT_KINDS_V1 = (:source_component, :passive_component, :return_component, :heat_component)
const G3_REALIZATION_CHILD_EDIT_MATERIAL_PROPERTIES_V1 = (:conductivity, :resistivity, :density, :strength)
const G3_REALIZATION_CHILD_EDIT_MANUFACTURING_PARAMETERS_V1 = (:thickness, :current_density, :temperature, :tolerance)
const G3_REALIZATION_CHILD_EDIT_LEDGER_DOMAINS_V1 = (:energy, :material, :thermal, :mechanical)
const G3_REALIZATION_CHILD_EDIT_LEDGER_EFFECTS_V1 = (:source, :load, :return, :heat_rejection, :material_in, :material_out, :loss, :deformation)

struct G3RealizationComponentV1
    component_id::String
    kind::Symbol
    port_ids::Tuple
    capacity::Rational{Int64}
    capacity_unit::UnitSignature
    material_id::String
    manufacturing_process_id::String
    function G3RealizationComponentV1(component_id::Any, kind::Any, port_ids::Any,
            capacity::Any, capacity_unit::Any, material_id::Any, manufacturing_process_id::Any)
        id = _g3rce_text(component_id, "component_id")
        k = _g3rce_symbol(kind, G3_REALIZATION_CHILD_EDIT_COMPONENT_KINDS_V1, "component kind")
        ids = _g3rce_tuple(port_ids, "component port_ids")
        all(x -> x isa AbstractString && !isempty(String(x)), ids) || throw(ArgumentError("component port_ids must be non-empty strings"))
        length(unique(String.(ids))) == length(ids) || throw(ArgumentError("component port_ids must be unique"))
        cap = _g3rce_rat(capacity, "component capacity"; positive=true)
        u = _g3rce_unit(capacity_unit, "component capacity_unit")
        new(id, k, Tuple(String(x) for x in ids), cap, u,
            _g3rce_text(material_id, "component material_id"),
            _g3rce_text(manufacturing_process_id, "component manufacturing_process_id"))
    end
end

struct G3RealizationMaterialDomainV1
    material_id::String
    property::Symbol
    lower::Rational{Int64}
    upper::Rational{Int64}
    unit::UnitSignature
    function G3RealizationMaterialDomainV1(material_id::Any, property::Any, lower::Any, upper::Any, unit::Any)
        lo = _g3rce_rat(lower, "material lower")
        hi = _g3rce_rat(upper, "material upper")
        lo < hi || throw(ArgumentError("material domain requires lower < upper"))
        new(_g3rce_text(material_id, "material_id"),
            _g3rce_symbol(property, G3_REALIZATION_CHILD_EDIT_MATERIAL_PROPERTIES_V1, "material property"),
            lo, hi, _g3rce_unit(unit, "material unit"))
    end
end

struct G3RealizationManufacturingDomainV1
    process_id::String
    parameter::Symbol
    lower::Rational{Int64}
    upper::Rational{Int64}
    unit::UnitSignature
    function G3RealizationManufacturingDomainV1(process_id::Any, parameter::Any, lower::Any, upper::Any, unit::Any)
        lo = _g3rce_rat(lower, "manufacturing lower")
        hi = _g3rce_rat(upper, "manufacturing upper")
        lo < hi || throw(ArgumentError("manufacturing domain requires lower < upper"))
        new(_g3rce_text(process_id, "process_id"),
            _g3rce_symbol(parameter, G3_REALIZATION_CHILD_EDIT_MANUFACTURING_PARAMETERS_V1, "manufacturing parameter"),
            lo, hi, _g3rce_unit(unit, "manufacturing unit"))
    end
end

struct G3RealizationLedgerAccountV1
    account_id::String
    domain::Symbol
    unit::UnitSignature
    owner_scope::String
    function G3RealizationLedgerAccountV1(account_id::Any, domain::Any, unit::Any, owner_scope::Any)
        new(_g3rce_text(account_id, "account_id"),
            _g3rce_symbol(domain, G3_REALIZATION_CHILD_EDIT_LEDGER_DOMAINS_V1, "ledger domain"),
            _g3rce_unit(unit, "ledger unit"), _g3rce_text(owner_scope, "ledger owner_scope"))
    end
end

struct G3RealizationLedgerEntryV1
    entry_id::String
    account_id::String
    port_id::String
    component_id::String
    coefficient::Rational{Int64}
    unit::UnitSignature
    effect::Symbol
    function G3RealizationLedgerEntryV1(entry_id::Any, account_id::Any, port_id::Any,
            component_id::Any, coefficient::Any, unit::Any, effect::Any)
        coeff = _g3rce_rat(coefficient, "ledger coefficient")
        coeff != 0 || throw(ArgumentError("ledger coefficient must be non-zero"))
        new(_g3rce_text(entry_id, "entry_id"), _g3rce_text(account_id, "account_id"),
            _g3rce_text(port_id, "port_id"), _g3rce_text(component_id, "component_id"),
            coeff, _g3rce_unit(unit, "ledger entry unit"),
            _g3rce_symbol(effect, G3_REALIZATION_CHILD_EDIT_LEDGER_EFFECTS_V1, "ledger effect"))
    end
end

struct G3RealizationLedgerClosureV1
    closure_id::String
    domain::Symbol
    account_ids::Tuple
    expected_balance::Rational{Int64}
    function G3RealizationLedgerClosureV1(closure_id::Any, domain::Any, account_ids::Any, expected_balance::Any)
        ids = _g3rce_tuple(account_ids, "closure account_ids")
        !isempty(ids) && all(x -> x isa AbstractString && !isempty(String(x)), ids) ||
            throw(ArgumentError("closure account_ids must be non-empty strings"))
        length(unique(String.(ids))) == length(ids) || throw(ArgumentError("closure account_ids must be unique"))
        new(_g3rce_text(closure_id, "closure_id"),
            _g3rce_symbol(domain, G3_REALIZATION_CHILD_EDIT_LEDGER_DOMAINS_V1, "closure domain"),
            Tuple(String(x) for x in ids), _g3rce_rat(expected_balance, "expected_balance"))
    end
end

struct G3RealizationSourceBodyV1
    source_id::String
    owner_scope::String
    ports::Tuple
    source_power::Rational{Int64}
    field_power::Rational{Int64}
    return_power::Rational{Int64}
    heat_power::Rational{Int64}
    capacity::Rational{Int64}
    capacity_unit::UnitSignature
    closure_residual::Rational{Int64}
    components::Tuple
    material_domains::Tuple
    manufacturing_domains::Tuple
    ledger_accounts::Tuple
    ledger_entries::Tuple
    ledger_closures::Tuple
    function G3RealizationSourceBodyV1(source_id::Any, owner_scope::Any, ports::Any,
            source_power::Any, field_power::Any, return_power::Any, heat_power::Any,
            capacity::Any, capacity_unit::Any, closure_residual::Any,
            components::Any=(), material_domains::Any=(), manufacturing_domains::Any=(),
            ledger_accounts::Any=(), ledger_entries::Any=(), ledger_closures::Any=())
        sid = _g3rce_text(source_id, "source_id")
        owner = _g3rce_text(owner_scope, "owner_scope")
        ps = _g3rce_tuple(ports, "ports")
        all(p -> p isa G3RealizationSourcePortV1, ps) ||
            throw(ArgumentError("ports must contain only G3RealizationSourcePortV1"))
        length(ps) == length(G3_REALIZATION_CHILD_EDIT_PORT_ROLES_V1) ||
            throw(ArgumentError("body must contain exactly four source ports"))
        roles = Tuple(p.role for p in ps)
        length(unique(roles)) == length(roles) &&
            Set(roles) == Set(G3_REALIZATION_CHILD_EDIT_PORT_ROLES_V1) ||
            throw(ArgumentError("body ports must contain each source role exactly once"))
        length(unique(p.port_id for p in ps)) == length(ps) ||
            throw(ArgumentError("body port_id values must be unique"))
        all(p -> p.sign == 1 && p.owner_scope == owner, ps) || throw(ArgumentError("source ports must be owned by body owner_scope with sign +1"))
        all((p.role === :source && p.direction in (:out, :bidirectional)) ||
            (p.role !== :source && p.direction in (:in, :bidirectional)) for p in ps) ||
            throw(ArgumentError("port direction is incompatible with its role"))
        su = first(p.unit for p in ps if p.role === :source)
        all(p -> p.unit == su, ps) || throw(ArgumentError("source port units must match"))
        source = _g3rce_rat(source_power, "source_power"; nonnegative=true)
        field = _g3rce_rat(field_power, "field_power"; nonnegative=true)
        returned = _g3rce_rat(return_power, "return_power"; nonnegative=true)
        heat = _g3rce_rat(heat_power, "heat_power"; nonnegative=true)
        cap = _g3rce_rat(capacity, "capacity"; positive=true)
        cap_unit = _g3rce_unit(capacity_unit, "capacity_unit")
        residual = _g3rce_rat(closure_residual, "closure_residual")
        source == field + returned + heat || throw(ArgumentError("source balance is not closed"))
        residual == 0 || throw(ArgumentError("closure_residual must be zero"))
        source <= cap || throw(ArgumentError("source_power exceeds capacity"))
        comps = _g3rce_tuple(components, "components")
        mats = _g3rce_tuple(material_domains, "material_domains")
        procs = _g3rce_tuple(manufacturing_domains, "manufacturing_domains")
        accounts = _g3rce_tuple(ledger_accounts, "ledger_accounts")
        entries = _g3rce_tuple(ledger_entries, "ledger_entries")
        closures = _g3rce_tuple(ledger_closures, "ledger_closures")
        all(!isempty, (comps, mats, procs, accounts, entries, closures)) ||
            throw(ArgumentError("components, material/manufacturing domains and ledger records cannot be empty"))
        all(x -> x isa G3RealizationComponentV1, comps) || throw(ArgumentError("components have wrong type"))
        all(x -> x isa G3RealizationMaterialDomainV1, mats) || throw(ArgumentError("material_domains have wrong type"))
        all(x -> x isa G3RealizationManufacturingDomainV1, procs) || throw(ArgumentError("manufacturing_domains have wrong type"))
        all(x -> x isa G3RealizationLedgerAccountV1, accounts) || throw(ArgumentError("ledger_accounts have wrong type"))
        all(x -> x isa G3RealizationLedgerEntryV1, entries) || throw(ArgumentError("ledger_entries have wrong type"))
        all(x -> x isa G3RealizationLedgerClosureV1, closures) || throw(ArgumentError("ledger_closures have wrong type"))
        length(unique(String[c.component_id for c in comps])) == length(comps) || throw(ArgumentError("component ids must be unique"))
        length(unique(String[m.material_id for m in mats])) == length(mats) || throw(ArgumentError("material ids must be unique"))
        length(unique(String[p.process_id for p in procs])) == length(procs) || throw(ArgumentError("manufacturing process ids must be unique"))
        length(unique(String[a.account_id for a in accounts])) == length(accounts) || throw(ArgumentError("ledger account ids must be unique"))
        length(unique(String[e.entry_id for e in entries])) == length(entries) || throw(ArgumentError("ledger entry ids must be unique"))
        length(unique(String[c.closure_id for c in closures])) == length(closures) || throw(ArgumentError("ledger closure ids must be unique"))
        port_ids = Set(p.port_id for p in ps)
        material_ids = Set(m.material_id for m in mats)
        process_ids = Set(p.process_id for p in procs)
        component_ids = Set(c.component_id for c in comps)
        account_ids = Set(a.account_id for a in accounts)
        all(c -> all(id -> id in port_ids, c.port_ids) && c.material_id in material_ids && c.manufacturing_process_id in process_ids, comps) ||
            throw(ArgumentError("component references do not resolve"))
        all(c -> c.capacity <= cap && c.capacity_unit == cap_unit, comps) ||
            throw(ArgumentError("component capacity exceeds body capacity or has wrong unit"))
        all(p -> any(p.port_id in c.port_ids for c in comps), ps) ||
            throw(ArgumentError("every source port must belong to a component"))
        all(a -> a.owner_scope == owner, accounts) || throw(ArgumentError("ledger account owner scope mismatch"))
        port_map = Dict(p.port_id => p for p in ps)
        account_map = Dict(a.account_id => a for a in accounts)
        component_map = Dict(c.component_id => c for c in comps)
        all(e -> e.account_id in account_ids && e.component_id in component_ids && e.port_id in port_ids &&
            e.port_id in component_map[e.component_id].port_ids &&
            e.unit == account_map[e.account_id].unit == port_map[e.port_id].unit, entries) ||
            throw(ArgumentError("ledger entry references or units do not resolve"))
        all(c -> all(id -> id in account_ids, c.account_ids), closures) || throw(ArgumentError("closure account references do not resolve"))
        all(c -> all(account_map[id].domain === c.domain for id in c.account_ids), closures) || throw(ArgumentError("closure/account domains do not match"))
        all(c -> (sum(e.coefficient for e in entries if e.account_id in c.account_ids) == c.expected_balance), closures) ||
            throw(ArgumentError("ledger closure balance mismatch"))
        all(p -> count(e -> e.port_id == p.port_id, entries) == 1, ps) || throw(ArgumentError("every source port requires exactly one ledger entry"))
        expected = Dict(:source => (source, :source), :field => (-field, :load),
            :return => (-returned, :return), :heat => (-heat, :heat_rejection))
        all(e -> begin
            role = port_map[e.port_id].role
            e.coefficient == expected[role][1] && e.effect === expected[role][2]
        end, entries) || throw(ArgumentError("ledger entry coefficient/effect does not match source body"))
        new(sid, owner, ps, source, field, returned, heat, cap, cap_unit, residual,
            comps, mats, procs, accounts, entries, closures)
    end
end

struct G3RealizationSourceProvenanceV1
    kind::Symbol
    source_ref::Union{Nothing,QualifiedRefV1}
    candidate_ref::QualifiedRefV1
    source_hash::Union{Nothing,Digest256}
    status::Symbol
    reason::Union{Nothing,String}
    absence_content_hash::Union{Nothing,Digest256}
    function G3RealizationSourceProvenanceV1(kind::Any, source_ref::Any,
            candidate_ref::Any, source_hash::Any, status::Any, reason::Any,
            absence_content_hash::Any)
        k = _g3rce_symbol(kind, G3_REALIZATION_CHILD_EDIT_SLOT_KINDS_V1, "provenance kind")
        c = _g3rce_candidate(candidate_ref)
        s = _g3rce_symbol(status, G3_REALIZATION_CHILD_EDIT_SLOT_STATUSES_V1, "provenance status")
        if s === :present
            source_ref isa QualifiedRefV1 || throw(ArgumentError("present provenance requires source_ref"))
            source_hash isa Digest256 || throw(ArgumentError("present provenance requires source_hash"))
            reason === nothing || throw(ArgumentError("present provenance cannot carry reason"))
            absence_content_hash === nothing || throw(ArgumentError("present provenance cannot carry absence hash"))
        else
            source_ref === nothing || throw(ArgumentError("typed absent provenance cannot carry source_ref"))
            source_hash === nothing || throw(ArgumentError("typed absent provenance cannot carry source_hash"))
            reason isa AbstractString && !isempty(String(reason)) ||
                throw(ArgumentError("typed absent provenance requires reason"))
            absence_content_hash isa Digest256 || throw(ArgumentError("typed absent provenance requires absence hash"))
        end
        new(k, source_ref, c, source_hash, s, reason === nothing ? nothing : String(reason), absence_content_hash)
    end
end

function g3_realization_source_provenance_v1(kind, candidate_ref, source_ref, source_hash)
    G3RealizationSourceProvenanceV1(kind, source_ref, candidate_ref, source_hash, :present, nothing, nothing)
end

function g3_realization_typed_absent_provenance_v1(kind, candidate_ref, reason)
    c = _g3rce_candidate(candidate_ref)
    k = _g3rce_symbol(kind, G3_REALIZATION_CHILD_EDIT_SLOT_KINDS_V1, "provenance kind")
    r = _g3rce_text(reason, "absence reason")
    absence_hash = canonical_hash((domain="g3-realization-provenance-absence-v1",
        kind=k, candidate_ref=c, reason=r))
    G3RealizationSourceProvenanceV1(k, nothing, c, nothing, :typed_absent, r, absence_hash)
end

struct G3RealizationSourceRecordV1
    source_uri::String
    source_version::String
    schema::G3RealizationSourceProvenanceV1
    canonicalization::G3RealizationSourceProvenanceV1
    profile::G3RealizationSourceProvenanceV1
    evidence_receipt::G3RealizationSourceProvenanceV1
    source_record_hash::Digest256
    function G3RealizationSourceRecordV1(source_uri::Any, source_version::Any,
            schema::Any, canonicalization::Any, profile::Any, evidence_receipt::Any,
            source_record_hash::Any)
        u = _g3rce_text(source_uri, "source_uri")
        v = _g3rce_text(source_version, "source_version")
        slots = (schema, canonicalization, profile, evidence_receipt)
        all(s -> s isa G3RealizationSourceProvenanceV1, slots) ||
            throw(ArgumentError("source record slots have wrong type"))
        all(s -> s.kind in G3_REALIZATION_CHILD_EDIT_SLOT_KINDS_V1, slots) ||
            throw(ArgumentError("source record has unknown provenance slot"))
        Tuple(s.kind for s in slots) == G3_REALIZATION_CHILD_EDIT_SLOT_KINDS_V1 ||
            throw(ArgumentError("source record slots must be schema/canonicalization/profile/evidence_receipt"))
        h = _g3rce_digest(source_record_hash, "source_record_hash")
        new(u, v, schema, canonicalization, profile, evidence_receipt, h)
    end
end

function _g3rce_source_record_body(record::G3RealizationSourceRecordV1)
    (source_uri=record.source_uri, source_version=record.source_version,
        schema=record.schema, canonicalization=record.canonicalization,
        profile=record.profile, evidence_receipt=record.evidence_receipt)
end

function g3_realization_source_record_v1(candidate_ref::Any;
        source_uri=G3_REALIZATION_CHILD_EDIT_SOURCE_URI_V1,
        source_version=G3_REALIZATION_CHILD_EDIT_SOURCE_VERSION_V1,
        schema_ref=nothing, schema_hash=nothing, canonicalization_ref=nothing,
        canonicalization_hash=nothing, profile_ref=nothing, profile_hash=nothing,
        evidence_receipt_ref=nothing, evidence_receipt_hash=nothing,
        absence_reasons=())
    c = _g3rce_candidate(candidate_ref)
    reasons = _g3rce_tuple(absence_reasons, "absence_reasons")
    reason_for(kind) = begin
        matches = [x for x in reasons if x isa Pair && Symbol(first(x)) === kind]
        if isempty(matches)
            nothing
        elseif length(matches) == 1
            last(only(matches))
        else
            "structural conflict: multiple absence reasons for $kind"
        end
    end
    slot(kind, ref, hash) = begin
        if ref === nothing && hash === nothing
            reason = reason_for(kind)
            reason === nothing && (reason = "missing $kind provenance")
            g3_realization_typed_absent_provenance_v1(kind, c, reason)
        elseif ref isa QualifiedRefV1 && hash isa Digest256
            g3_realization_source_provenance_v1(kind, c, ref, hash)
        else
            throw(ArgumentError("$kind provenance ref and hash must be both present or both absent"))
        end
    end
    record = G3RealizationSourceRecordV1(source_uri, source_version,
        slot(:schema, schema_ref, schema_hash),
        slot(:canonicalization, canonicalization_ref, canonicalization_hash),
        slot(:profile, profile_ref, profile_hash),
        slot(:evidence_receipt, evidence_receipt_ref, evidence_receipt_hash),
        G3_REALIZATION_CHILD_EDIT_ZERO_DIGEST_V1)
    G3RealizationSourceRecordV1(record.source_uri, record.source_version,
        record.schema, record.canonicalization, record.profile, record.evidence_receipt,
        canonical_hash(_g3rce_source_record_body(record)))
end

struct G3RealizationSourceRecordRefV1
    record_uri::String
    record_version::String
    record_hash::Digest256
    function G3RealizationSourceRecordRefV1(record_uri::Any, record_version::Any, record_hash::Any)
        new(_g3rce_text(record_uri, "record_uri"), _g3rce_text(record_version, "record_version"),
            _g3rce_digest(record_hash, "record_hash"))
    end
end

struct G3RealizationSourcePayloadV1
    key::G3RealizationChildKeyV1
    parent_g3_declaration_ref::QualifiedRefV1
    parent_g3_declaration_hash::Digest256
    child_contract_ref::GenomeContractRef
    child_contract_identity_hash::Digest256
    source_uri::String
    source_version::String
    body::G3RealizationSourceBodyV1
    source_record::G3RealizationSourceRecordV1
    source_content_hash::Digest256
    function G3RealizationSourcePayloadV1(key::Any, parent_ref::Any, parent_hash::Any,
            contract_ref::Any, contract_identity_hash::Any, source_uri::Any,
            source_version::Any, body::Any, source_record::Any, source_content_hash::Any)
        k = key isa G3RealizationChildKeyV1 ? key : throw(ArgumentError("key must be G3RealizationChildKeyV1"))
        p = _g3rce_parent(parent_ref)
        ph = _g3rce_digest(parent_hash, "parent_g3_declaration_hash")
        ph == k.parent_g3_declaration_hash || throw(ArgumentError("parent hash/key mismatch"))
        contract_ref isa GenomeContractRef || throw(ArgumentError("child_contract_ref must be GenomeContractRef"))
        contract_identity_hash isa Digest256 || throw(ArgumentError("child contract identity hash must be Digest256"))
        _g3rce_text(source_uri, "source_uri")
        _g3rce_text(source_version, "source_version")
        body isa G3RealizationSourceBodyV1 || throw(ArgumentError("body has wrong type"))
    source_record isa G3RealizationSourceRecordV1 || throw(ArgumentError("source_record has wrong type"))
        body.source_id == k.child_id || throw(ArgumentError("child key id/body source id mismatch"))
        source_content_hash isa Digest256 || throw(ArgumentError("source_content_hash must be Digest256"))
        new(k, p, ph, contract_ref, contract_identity_hash, String(source_uri), String(source_version),
        body, source_record, source_content_hash)
    end
end

function _g3rce_contract_ref_v1()
    GenomeContractRef(G3_REALIZATION_CHILD_EDIT_CONTRACT_URI_V1,
        G3_REALIZATION_CHILD_EDIT_VERSION_V1,
        g3_realization_child_edit_schema_hash_v1(),
        g3_realization_child_edit_canonicalization_hash_v1(),
        G3_REALIZATION_CHILD_EDIT_PROFILE_V1)
end

function _g3rce_payload_body(payload::G3RealizationSourcePayloadV1)
    (key=payload.key, parent_g3_declaration_ref=payload.parent_g3_declaration_ref,
        parent_g3_declaration_hash=payload.parent_g3_declaration_hash,
        child_contract_ref=payload.child_contract_ref,
        child_contract_identity_hash=payload.child_contract_identity_hash,
        source_uri=payload.source_uri, source_version=payload.source_version,
        body=payload.body, source_record_hash=payload.source_record.source_record_hash)
end

function g3_realization_source_payload_v1(key::G3RealizationChildKeyV1,
        parent_ref::QualifiedRefV1, body::G3RealizationSourceBodyV1,
        source_record::G3RealizationSourceRecordV1;
        source_uri=source_record.source_uri, source_version=source_record.source_version,
        child_contract_ref=_g3rce_contract_ref_v1())
    contract = child_contract_ref isa GenomeContractRef ? child_contract_ref :
        throw(ArgumentError("child_contract_ref must be GenomeContractRef"))
    contract == _g3rce_contract_ref_v1() || throw(ArgumentError("child contract URI/version/ref is not exact"))
    source_uri == source_record.source_uri && source_version == source_record.source_version ||
        throw(ArgumentError("source URI/version must equal source record URI/version"))
    all(s -> s.status === :present, (source_record.schema, source_record.canonicalization,
        source_record.profile, source_record.evidence_receipt)) ||
        throw(ArgumentError("source provenance is incomplete; construct typed absent state"))
    identity_hash = canonical_hash(semantic_view(contract))
    draft = G3RealizationSourcePayloadV1(key, parent_ref, key.parent_g3_declaration_hash,
        contract, identity_hash, source_uri, source_version, body, source_record,
        G3_REALIZATION_CHILD_EDIT_ZERO_DIGEST_V1)
    G3RealizationSourcePayloadV1(draft.key, draft.parent_g3_declaration_ref,
        draft.parent_g3_declaration_hash, draft.child_contract_ref,
        draft.child_contract_identity_hash, draft.source_uri, draft.source_version,
        draft.body, draft.source_record, canonical_hash(_g3rce_payload_body(draft)))
end

function _g3rce_payload_valid(payload::G3RealizationSourcePayloadV1)
    errors = String[]
    payload.parent_g3_declaration_hash == payload.key.parent_g3_declaration_hash || push!(errors, "parent_hash_key_mismatch")
    payload.parent_g3_declaration_ref.version == "v1" || push!(errors, "parent_ref_version_mismatch")
    payload.child_contract_ref == _g3rce_contract_ref_v1() || push!(errors, "child_contract_ref_not_exact")
    payload.child_contract_identity_hash == canonical_hash(semantic_view(payload.child_contract_ref)) || push!(errors, "child_contract_identity_hash_mismatch")
    payload.body.source_id == payload.key.child_id || push!(errors, "child_id_body_mismatch")
    payload.source_uri == payload.source_record.source_uri || push!(errors, "source_uri_record_mismatch")
    payload.source_version == payload.source_record.source_version || push!(errors, "source_version_record_mismatch")
    payload.source_record.source_record_hash == canonical_hash(_g3rce_source_record_body(payload.source_record)) || push!(errors, "source_record_hash_mismatch")
    payload.source_content_hash == canonical_hash(_g3rce_payload_body(payload)) || push!(errors, "source_content_hash_mismatch")
    all(s -> s.candidate_ref == payload.key.candidate_ref,
        (payload.source_record.schema, payload.source_record.canonicalization,
            payload.source_record.profile, payload.source_record.evidence_receipt)) ||
        push!(errors, "provenance_candidate_mismatch")
    Tuple(s.status for s in (payload.source_record.schema, payload.source_record.canonicalization,
        payload.source_record.profile, payload.source_record.evidence_receipt)) ==
        (:present, :present, :present, :present) || push!(errors, "source_provenance_missing")
    Tuple(errors)
end

struct G3RealizationSourceStateV1
    key::G3RealizationChildKeyV1
    payload::Union{Nothing,G3RealizationSourcePayloadV1}
    source_content_hash::Union{Nothing,Digest256}
    initial_source_content_hash::Union{Nothing,Digest256}
    state_status::Symbol
    absence_reason::Union{Nothing,String}
    absence_content_hash::Union{Nothing,Digest256}
    missing_slots::Tuple
    initial_state_hash::Digest256
    state_hash::Digest256
    operation_hash::Digest256
    contract_admission::Symbol
    physical_resolution::Symbol
    operation_history::Tuple
    function G3RealizationSourceStateV1(key::Any, payload::Any, source_content_hash::Any,
            initial_source_content_hash::Any, state_status::Any, absence_reason::Any, absence_content_hash::Any,
            missing_slots::Any, initial_state_hash::Any, state_hash::Any, operation_hash::Any,
            contract_admission::Any, physical_resolution::Any, operation_history::Any)
        k = key isa G3RealizationChildKeyV1 ? key : throw(ArgumentError("state key has wrong type"))
        status = _g3rce_symbol(state_status, (:present, :typed_absent), "state_status")
        admission = _g3rce_symbol(contract_admission, (:declared_consistent, :terminal_deferred, :fail_closed), "contract_admission")
        physical = _g3rce_symbol(physical_resolution, (:unknown, :terminal_deferred), "physical_resolution")
        history = _g3rce_tuple(operation_history, "operation_history")
        missing = _g3rce_tuple(missing_slots, "missing_slots")
        all(x -> x isa Symbol && x in G3_REALIZATION_CHILD_EDIT_SLOT_KINDS_V1, missing) ||
            throw(ArgumentError("missing_slots has invalid slot"))
        length(unique(missing)) == length(missing) || throw(ArgumentError("missing_slots must be unique"))
        status === :present && isempty(missing) ||
            status === :typed_absent && (admission === :fail_closed || !isempty(missing)) ||
            throw(ArgumentError("missing_slots must match state status"))
        all(x -> x isa AbstractString && !isempty(String(x)), history) || throw(ArgumentError("operation_history has invalid id"))
        length(unique(String.(history))) == length(history) || throw(ArgumentError("operation_history operation ids must be unique"))
        if status === :present
            payload isa G3RealizationSourcePayloadV1 || throw(ArgumentError("present state requires payload"))
            source_content_hash isa Digest256 || throw(ArgumentError("present state requires source_content_hash"))
            absence_reason === nothing && absence_content_hash === nothing || throw(ArgumentError("present state cannot carry absence"))
            admission === :declared_consistent || throw(ArgumentError("present state requires declared_consistent admission"))
        else
            payload === nothing && source_content_hash === nothing || throw(ArgumentError("typed absent state cannot carry payload/source hash"))
            absence_reason isa AbstractString && !isempty(String(absence_reason)) || throw(ArgumentError("typed absent state requires reason"))
            absence_content_hash isa Digest256 || throw(ArgumentError("typed absent state requires absence hash"))
            admission in (:terminal_deferred, :fail_closed) || throw(ArgumentError("typed absent state requires deferred or fail_closed admission"))
        end
        ih = _g3rce_digest(initial_state_hash, "initial_state_hash")
        oh = _g3rce_digest(operation_hash, "operation_hash")
        sh = _g3rce_digest(state_hash, "state_hash")
        normalized_reason = absence_reason === nothing ? nothing : String(absence_reason)
        initial_source = status === :present ? _g3rce_digest(initial_source_content_hash, "initial_source_content_hash") :
            (initial_source_content_hash === nothing ? nothing : throw(ArgumentError("typed absent state cannot carry initial source hash")))
        expected_initial = _g3rce_initial_hash(k, status, initial_source, absence_content_hash, missing)
        ih == expected_initial || throw(ArgumentError("initial_state_hash does not match frozen identity"))
        expected_state = _g3rce_state_hash(k, status, source_content_hash, absence_content_hash, oh, history, missing)
        sh == expected_state || throw(ArgumentError("state_hash does not match state identity"))
        status === :present && payload.source_content_hash == source_content_hash || status === :typed_absent ||
            throw(ArgumentError("state source hash/payload mismatch"))
        new(k, payload, source_content_hash, initial_source, status, normalized_reason,
            absence_content_hash, missing, ih, sh, oh, admission, physical, Tuple(String(x) for x in history))
    end
end

function _g3rce_initial_hash(key, status, source_hash, absence_hash, missing_slots=())
    canonical_hash((domain="g3-realization-initial-state-v1", key=key, state_status=status,
        source_content_hash=source_hash, absence_content_hash=absence_hash,
        missing_slots=missing_slots, operation_history=(),
        operation_hash=G3_REALIZATION_CHILD_EDIT_ZERO_DIGEST_V1))
end
function _g3rce_state_hash(key, status, source_hash, absence_hash, operation_hash,
        operation_history=(), missing_slots=())
    canonical_hash((domain="g3-realization-state-v1", key=key, state_status=status,
        source_content_hash=source_hash, absence_content_hash=absence_hash,
        missing_slots=missing_slots, operation_history=operation_history, operation_hash=operation_hash))
end

function g3_realization_initial_state_v1(key::G3RealizationChildKeyV1,
        payload::G3RealizationSourcePayloadV1)
    key == payload.key || throw(ArgumentError("state key/payload key mismatch"))
    isempty(_g3rce_payload_valid(payload)) || throw(ArgumentError("payload is not locally admissible"))
    initial = _g3rce_initial_hash(key, :present, payload.source_content_hash, nothing, ())
    state = _g3rce_state_hash(key, :present, payload.source_content_hash, nothing,
        G3_REALIZATION_CHILD_EDIT_ZERO_DIGEST_V1, (), ())
    G3RealizationSourceStateV1(key, payload, payload.source_content_hash, payload.source_content_hash, :present, nothing,
        nothing, (), initial, state, G3_REALIZATION_CHILD_EDIT_ZERO_DIGEST_V1,
        :declared_consistent, :unknown, ())
end

function g3_realization_typed_absent_state_v1(key::G3RealizationChildKeyV1, reason::Any;
        missing_slots=(), admission=:terminal_deferred)
    r = _g3rce_text(reason, "absence reason")
    missing = _g3rce_tuple(missing_slots, "missing_slots")
    all(x -> x isa Symbol && x in G3_REALIZATION_CHILD_EDIT_SLOT_KINDS_V1, missing) ||
        throw(ArgumentError("missing_slots has invalid slot"))
    length(unique(missing)) == length(missing) || throw(ArgumentError("missing_slots must be unique"))
    absence_hash = canonical_hash((domain="g3-realization-state-absence-v1", key=key,
        reason=r, missing_slots=missing))
    initial = _g3rce_initial_hash(key, :typed_absent, nothing, absence_hash, missing)
    state = _g3rce_state_hash(key, :typed_absent, nothing, absence_hash,
        G3_REALIZATION_CHILD_EDIT_ZERO_DIGEST_V1, (), missing)
    a = _g3rce_symbol(admission, (:terminal_deferred, :fail_closed), "absence admission")
    G3RealizationSourceStateV1(key, nothing, nothing, nothing, :typed_absent, r, absence_hash,
        missing, initial, state, G3_REALIZATION_CHILD_EDIT_ZERO_DIGEST_V1,
        a, :unknown, ())
end

function g3_realization_admit_v1(key::G3RealizationChildKeyV1,
        payload::G3RealizationSourcePayloadV1)
    errors = _g3rce_payload_valid(payload)
    isempty(errors) && return g3_realization_initial_state_v1(key, payload)
    missing = Tuple(s.kind for s in (payload.source_record.schema, payload.source_record.canonicalization,
        payload.source_record.profile, payload.source_record.evidence_receipt) if s.status === :typed_absent)
    missing_only = !isempty(missing) && all(e -> e == "source_provenance_missing", errors)
    g3_realization_typed_absent_state_v1(key, "source admission: " * join(errors, ",");
        missing_slots=missing, admission=missing_only ? :terminal_deferred : :fail_closed)
end

function g3_realization_admit_source_v1(key::G3RealizationChildKeyV1,
        parent_ref::QualifiedRefV1, body::G3RealizationSourceBodyV1,
        source_record::G3RealizationSourceRecordV1)
    _g3rce_parent(parent_ref)
    slots = (source_record.schema, source_record.canonicalization,
        source_record.profile, source_record.evidence_receipt)
    missing = Tuple(s.kind for s in slots if s.status === :typed_absent)
    conflicts = any(s -> s.status === :typed_absent && _g3rce_structural_conflict(s.reason), slots)
    !isempty(missing) && return g3_realization_typed_absent_state_v1(key,
        conflicts ? "source admission structural conflict" : "source provenance unavailable";
        missing_slots=missing, admission=conflicts ? :fail_closed : :terminal_deferred)
    try
        g3_realization_initial_state_v1(key,
            g3_realization_source_payload_v1(key, parent_ref, body, source_record))
    catch err
        g3_realization_typed_absent_state_v1(key, "source admission conflict: " * string(typeof(err));
            missing_slots=(), admission=:fail_closed)
    end
end

struct G3RealizationReplaceSourcePayloadV1
    operation_id::String
    key::G3RealizationChildKeyV1
    expected_prior_state_hash::Digest256
    expected_prior_source_content_hash::Union{Nothing,Digest256}
    replacement_payload::G3RealizationSourcePayloadV1
    source_record_ref::G3RealizationSourceRecordRefV1
    operation_hash::Digest256
end

function _g3rce_operation_body(operation::G3RealizationReplaceSourcePayloadV1)
    (domain="g3-realization-replace-source-payload-v1", operation_id=operation.operation_id,
        key=operation.key, expected_prior_state_hash=operation.expected_prior_state_hash,
        expected_prior_source_content_hash=operation.expected_prior_source_content_hash,
        replacement_payload=operation.replacement_payload,
        source_record_ref=operation.source_record_ref)
end

function g3_realization_replace_operation_v1(operation_id::Any,
        key::G3RealizationChildKeyV1, expected_prior_state_hash::Digest256,
        expected_prior_source_content_hash, replacement_payload::G3RealizationSourcePayloadV1,
        source_record_ref::G3RealizationSourceRecordRefV1)
    opid = _g3rce_text(operation_id, "operation_id")
    expected_prior_source_content_hash === nothing || expected_prior_source_content_hash isa Digest256 ||
        throw(ArgumentError("expected prior source hash must be Digest256 or nothing"))
    draft = G3RealizationReplaceSourcePayloadV1(opid, key, expected_prior_state_hash,
        expected_prior_source_content_hash, replacement_payload, source_record_ref,
        G3_REALIZATION_CHILD_EDIT_ZERO_DIGEST_V1)
    G3RealizationReplaceSourcePayloadV1(draft.operation_id, draft.key,
        draft.expected_prior_state_hash, draft.expected_prior_source_content_hash,
        draft.replacement_payload, draft.source_record_ref,
        canonical_hash(_g3rce_operation_body(draft)))
end

struct G3RealizationOperationReceiptV1
    operation_id::String
    operation_hash::Digest256
    source_record_hash::Digest256
    source_content_hash::Digest256
    initial_state_hash::Digest256
    state_hash::Digest256
    contract_admission::Symbol
    physical_resolution::Symbol
    function G3RealizationOperationReceiptV1(operation_id::Any, operation_hash::Any,
            source_record_hash::Any, source_content_hash::Any, initial_state_hash::Any,
            state_hash::Any, contract_admission::Any, physical_resolution::Any)
        admission = _g3rce_symbol(contract_admission, (:declared_consistent,), "receipt contract_admission")
        physical = _g3rce_symbol(physical_resolution, (:unknown, :terminal_deferred), "receipt physical_resolution")
        new(_g3rce_text(operation_id, "receipt operation_id"),
            _g3rce_digest(operation_hash, "receipt operation_hash"),
            _g3rce_digest(source_record_hash, "receipt source_record_hash"),
            _g3rce_digest(source_content_hash, "receipt source_content_hash"),
            _g3rce_digest(initial_state_hash, "receipt initial_state_hash"),
            _g3rce_digest(state_hash, "receipt state_hash"), admission, physical)
    end
end

struct G3RealizationReplaceResultV1
    status::Symbol
    state::G3RealizationSourceStateV1
    receipt::Union{Nothing,G3RealizationOperationReceiptV1}
    errors::Tuple
    function G3RealizationReplaceResultV1(status::Any, state::Any, receipt::Any, errors::Any)
        s = _g3rce_symbol(status, (:applied, :fail_closed, :terminal_deferred), "result status")
        state isa G3RealizationSourceStateV1 || throw(ArgumentError("result state has wrong type"))
        receipt === nothing || receipt isa G3RealizationOperationReceiptV1 ||
            throw(ArgumentError("result receipt has wrong type"))
        es = _g3rce_tuple(errors, "result errors")
        all(x -> x isa AbstractString, es) || throw(ArgumentError("result errors must be strings"))
        s === :applied && receipt === nothing && throw(ArgumentError("applied result requires receipt"))
        s !== :applied && receipt !== nothing && throw(ArgumentError("non-applied result cannot carry receipt"))
        new(s, state, receipt, Tuple(String(x) for x in es))
    end
    function G3RealizationReplaceResultV1(status::Any, state::Any, receipt::Any,
            errors::Any, ::Val{:internal_program_exception})
        status === :program_exception || throw(ArgumentError("internal constructor only admits program_exception"))
        state isa G3RealizationSourceStateV1 || throw(ArgumentError("result state has wrong type"))
        receipt === nothing || throw(ArgumentError("program_exception cannot carry receipt"))
        es = _g3rce_tuple(errors, "result errors")
        new(:program_exception, state, nothing, Tuple(String(x) for x in es))
    end
end

function _g3rce_fail(state, status, errors)
    G3RealizationReplaceResultV1(status, state, nothing, Tuple(String(e) for e in errors))
end

function replace_source_payload(state::G3RealizationSourceStateV1,
        operation::G3RealizationReplaceSourcePayloadV1)
    try
        operation.key == state.key || return _g3rce_fail(state, :fail_closed, ("child_key_mismatch",))
        operation.operation_hash == canonical_hash(_g3rce_operation_body(operation)) ||
            return _g3rce_fail(state, :fail_closed, ("operation_hash_mismatch",))
        operation.operation_id in state.operation_history &&
            return _g3rce_fail(state, :fail_closed, ("duplicate_operation_id",))
        operation.expected_prior_state_hash == state.state_hash ||
            return _g3rce_fail(state, :fail_closed, ("stale_state_hash",))
        operation.expected_prior_source_content_hash == state.source_content_hash ||
            return _g3rce_fail(state, :fail_closed, ("stale_source_content_hash",))
        operation.replacement_payload.key == state.key ||
            return _g3rce_fail(state, :fail_closed, ("replacement_key_mismatch",))
        isempty(_g3rce_payload_valid(operation.replacement_payload)) ||
            return _g3rce_fail(state, :fail_closed, ("replacement_payload_invalid",))
        record = operation.replacement_payload.source_record
        operation.source_record_ref.record_uri == record.source_uri &&
            operation.source_record_ref.record_version == record.source_version &&
            operation.source_record_ref.record_hash == record.source_record_hash ||
            return _g3rce_fail(state, :fail_closed, ("source_record_ref_mismatch",))
        new_initial = state.initial_state_hash
        history = (state.operation_history..., operation.operation_id)
        new_state_hash = _g3rce_state_hash(state.key, :present,
            operation.replacement_payload.source_content_hash, nothing, operation.operation_hash,
            history, ())
        new_state = G3RealizationSourceStateV1(state.key, operation.replacement_payload,
            operation.replacement_payload.source_content_hash, state.initial_source_content_hash,
            :present, nothing, nothing, (),
            new_initial, new_state_hash, operation.operation_hash,
            :declared_consistent, :unknown, history)
        receipt = G3RealizationOperationReceiptV1(operation.operation_id, operation.operation_hash,
            record.source_record_hash, operation.replacement_payload.source_content_hash,
            new_initial, new_state_hash, :declared_consistent, :unknown)
        G3RealizationReplaceResultV1(:applied, new_state, receipt, ())
    catch err
        G3RealizationReplaceResultV1(:program_exception, state, nothing,
            (string(typeof(err)),), Val(:internal_program_exception))
    end
end

const g3_realization_replace_source_payload_v1 = replace_source_payload

semantic_view(x::G3RealizationChildKeyV1) =
    (candidate_ref=x.candidate_ref, parent_g3_declaration_hash=x.parent_g3_declaration_hash,
        child_kind=x.child_kind, child_id=x.child_id)
semantic_view(x::G3RealizationSourcePortV1) =
    (port_id=x.port_id, role=x.role, unit=x.unit, direction=x.direction, sign=x.sign, owner_scope=x.owner_scope)
semantic_view(x::G3RealizationComponentV1) =
    (component_id=x.component_id, kind=x.kind, port_ids=x.port_ids, capacity=x.capacity,
        capacity_unit=x.capacity_unit, material_id=x.material_id,
        manufacturing_process_id=x.manufacturing_process_id)
semantic_view(x::G3RealizationMaterialDomainV1) =
    (material_id=x.material_id, property=x.property, lower=x.lower, upper=x.upper, unit=x.unit)
semantic_view(x::G3RealizationManufacturingDomainV1) =
    (process_id=x.process_id, parameter=x.parameter, lower=x.lower, upper=x.upper, unit=x.unit)
semantic_view(x::G3RealizationLedgerAccountV1) =
    (account_id=x.account_id, domain=x.domain, unit=x.unit, owner_scope=x.owner_scope)
semantic_view(x::G3RealizationLedgerEntryV1) =
    (entry_id=x.entry_id, account_id=x.account_id, port_id=x.port_id,
        component_id=x.component_id, coefficient=x.coefficient, unit=x.unit, effect=x.effect)
semantic_view(x::G3RealizationLedgerClosureV1) =
    (closure_id=x.closure_id, domain=x.domain, account_ids=x.account_ids,
        expected_balance=x.expected_balance)
semantic_view(x::G3AuthoredPowerLawV1) =
    (law_id=x.law_id, effort_port_id=x.effort_port_id,
        current_port_id=x.current_port_id, power_endpoint_id=x.power_endpoint_id,
        voltage=x.voltage, current=x.current, power=x.power,
        voltage_unit=x.voltage_unit, current_unit=x.current_unit,
        power_unit=x.power_unit, claim_scope=x.claim_scope)
semantic_view(x::G3RealizationSourceBodyV1) =
    (source_id=x.source_id, owner_scope=x.owner_scope, ports=x.ports,
        source_power=x.source_power, field_power=x.field_power, return_power=x.return_power,
        heat_power=x.heat_power, capacity=x.capacity, capacity_unit=x.capacity_unit,
        closure_residual=x.closure_residual, components=x.components,
        material_domains=x.material_domains, manufacturing_domains=x.manufacturing_domains,
        ledger_accounts=x.ledger_accounts, ledger_entries=x.ledger_entries,
        ledger_closures=x.ledger_closures)
semantic_view(x::G3RealizationSourceProvenanceV1) =
    (kind=x.kind, source_ref=x.source_ref, candidate_ref=x.candidate_ref,
        source_hash=x.source_hash, status=x.status, reason=x.reason,
        absence_content_hash=x.absence_content_hash)
semantic_view(x::G3RealizationSourceRecordV1) =
    (source_uri=x.source_uri, source_version=x.source_version, schema=x.schema,
        canonicalization=x.canonicalization, profile=x.profile,
        evidence_receipt=x.evidence_receipt, source_record_hash=x.source_record_hash)
semantic_view(x::G3RealizationSourceRecordRefV1) =
    (record_uri=x.record_uri, record_version=x.record_version, record_hash=x.record_hash)
semantic_view(x::G3RealizationSourcePayloadV1) =
    (key=x.key, parent_g3_declaration_ref=x.parent_g3_declaration_ref,
        parent_g3_declaration_hash=x.parent_g3_declaration_hash,
        child_contract_ref=x.child_contract_ref,
        child_contract_identity_hash=x.child_contract_identity_hash,
        source_uri=x.source_uri, source_version=x.source_version, body=x.body,
        source_record=x.source_record, source_content_hash=x.source_content_hash)
semantic_view(x::G3RealizationSourceStateV1) =
    (key=x.key, payload=x.payload, source_content_hash=x.source_content_hash,
        initial_source_content_hash=x.initial_source_content_hash,
        state_status=x.state_status, absence_reason=x.absence_reason,
        absence_content_hash=x.absence_content_hash, missing_slots=x.missing_slots,
        initial_state_hash=x.initial_state_hash,
        state_hash=x.state_hash, operation_hash=x.operation_hash,
        contract_admission=x.contract_admission, physical_resolution=x.physical_resolution,
        operation_history=x.operation_history)
semantic_view(x::G3RealizationReplaceSourcePayloadV1) =
    (operation_id=x.operation_id, key=x.key, expected_prior_state_hash=x.expected_prior_state_hash,
        expected_prior_source_content_hash=x.expected_prior_source_content_hash,
        replacement_payload=x.replacement_payload, source_record_ref=x.source_record_ref,
        operation_hash=x.operation_hash)
semantic_view(x::G3RealizationOperationReceiptV1) =
    (operation_id=x.operation_id, operation_hash=x.operation_hash,
        source_record_hash=x.source_record_hash, source_content_hash=x.source_content_hash,
        initial_state_hash=x.initial_state_hash, state_hash=x.state_hash,
        contract_admission=x.contract_admission, physical_resolution=x.physical_resolution)
semantic_view(x::G3RealizationReplaceResultV1) =
    (status=x.status, state=x.state, receipt=x.receipt, errors=x.errors)

Base.:(==)(a::G3RealizationChildKeyV1, b::G3RealizationChildKeyV1) =
    a.candidate_ref == b.candidate_ref &&
    a.parent_g3_declaration_hash == b.parent_g3_declaration_hash &&
    a.child_kind === b.child_kind && a.child_id == b.child_id
Base.:(==)(a::G3RealizationSourceRecordRefV1, b::G3RealizationSourceRecordRefV1) =
    a.record_uri == b.record_uri && a.record_version == b.record_version &&
    a.record_hash == b.record_hash
