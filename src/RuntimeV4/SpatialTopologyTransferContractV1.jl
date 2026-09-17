"""Additive UP2 contract-only spatial topology/conservation transfer boundary.

This file is intentionally standalone.  It describes source/target space
identity, ownership, typed account transfer witnesses, closure defects, and
diagnostic declarations.  It does not construct a mesh, call a provider,
assemble a solver, perform a physical event, or claim numerical evidence.
"""

using SHA

const _STTC_SCHEMA_V1 = "FusionConceptAI/RuntimeV4/SpatialTopologyTransferContractV1"
const _STTC_REVISION_V1 = "spatial-topology-transfer-v1"
const _STTC_CLAIM_CEILING_V1 = :contract_only
const _STTC_EVIDENCE_SCOPE_V1 = :screen_only
const _STTC_READY_V1 = :ready
const _STTC_FAIL_CLOSED_V1 = :fail_closed
const _STTC_RETURN_REF_V1 = "return:source-to-target-v1"
const _STTC_EXTERNAL_OWNER_V1 = "external"
const _STTC_DEFECT_SCOPES_V1 = (:local, :region, :interface, :exterior, :global, :external)
const _STTC_DIAGNOSTIC_NAMES_V1 = (:divB, :positivity, :gauge, :nullspace)
const _STTC_WILDCARD_REFS_V1 = ("*", "any", "wildcard", "null", "none")

_sttc_text(value, field::AbstractString) = begin
    value isa AbstractString || throw(ArgumentError("$field must be a string"))
    text = strip(String(value))
    isempty(text) && throw(ArgumentError("$field cannot be empty"))
    text
end

_sttc_tuple_text(values, field::AbstractString; allow_empty::Bool=false) = begin
    values isa Tuple || throw(ArgumentError("$field must be a tuple"))
    result = Tuple(_sttc_text(value, field) for value in values)
    !allow_empty && isempty(result) && throw(ArgumentError("$field cannot be empty"))
    length(unique(result)) == length(result) || throw(ArgumentError("$field contains duplicates"))
    result
end

_sttc_ref_ok(value::AbstractString) = begin
    text = strip(String(value))
    lowered = lowercase(text)
    !isempty(text) && !occursin("*", text) && lowered ∉ _STTC_WILDCARD_REFS_V1
end

_sttc_require_ref!(failures, value::AbstractString, code::Symbol, path::String, detail::String) =
    _sttc_ref_ok(value) || _sttc_fail!(failures, code, path, detail)

struct SpatialTransferUnitV1
    name::String
    exponents::NTuple{7,Int}
    scale_to_si::Float64
end

struct SpatialTopologyIdentityV1
    candidate_ref::String
    space_ref::String
    topology_ref::String
    mesh_ref::String
    basis_ref::String
    quadrature_ref::String
    dof_ref::String
    order_ref::String
    side::Symbol
end

struct SpatialRegionIdentityV1
    region_ref::String
    owner_ref::String
    side::Symbol
    exterior::Bool
end

struct SpatialInterfaceIdentityV1
    interface_ref::String
    minus_region_ref::String
    plus_region_ref::String
    owner_ref::String
    orientation::Symbol
end

struct SpatialTypedAccountV1
    account_ref::String
    account_kind::Symbol
    owner_ref::String
    region_ref::String
    unit::SpatialTransferUnitV1
    orientation::Symbol
end

struct SpatialAccountEffectV1
    transfer_ref::String
    account_ref::String
    signed_value::Float64
    unit::SpatialTransferUnitV1
    orientation::Symbol
end

struct SpatialTransferWitnessV1
    source_topology_ref::String
    target_topology_ref::String
    effects::Tuple{Vararg{SpatialAccountEffectV1}}
end

struct SpatialDefectV1
    scope::Symbol
    defect_ref::String
    value::Float64
    tolerance::Float64
end

struct SpatialDiagnosticV1
    name::Symbol
    value::Float64
    tolerance::Float64
end

struct SpatialTransferFailureV1
    code::Symbol
    path::String
    detail::String
end

struct SpatialTransferValidationV1
    valid::Bool
    status::Symbol
    failures::Tuple{Vararg{SpatialTransferFailureV1}}
    claim_ceiling::Symbol
    evidence_scope::Symbol
    provider_calls::Int
    mesh_calls::Int
    solver_calls::Int
end

struct SpatialTopologyTransferV1
    schema::String
    revision::String
    candidate_ref::String
    space_ref::String
    source::SpatialTopologyIdentityV1
    target::SpatialTopologyIdentityV1
    regions::Tuple{Vararg{SpatialRegionIdentityV1}}
    interfaces::Tuple{Vararg{SpatialInterfaceIdentityV1}}
    accounts::Tuple{Vararg{SpatialTypedAccountV1}}
    witness::SpatialTransferWitnessV1
    defects::Tuple{Vararg{SpatialDefectV1}}
    diagnostics::Tuple{Vararg{SpatialDiagnosticV1}}
    constraint_refs::Tuple{Vararg{String}}
    physical_event_refs::Tuple{Vararg{String}}
    external_closure_ref::String
    return_ref::String
    canonical_order::Tuple{Vararg{String}}
    claim_ceiling::Symbol
    evidence_scope::Symbol
end

function _sttc_unit(name::AbstractString="1", exponents=(0,0,0,0,0,0,0); scale::Real=1.0)
    raw = Tuple(exponents)
    length(raw) == 7 || throw(ArgumentError("unit requires seven exponents"))
    all(x -> x isa Integer, raw) || throw(ArgumentError("unit exponents must be integers"))
    SpatialTransferUnitV1(_sttc_text(name, "unit name"), ntuple(i -> Int(raw[i]), 7), Float64(scale))
end

function _sttc_identity(candidate::String, space::String, topology::String, side::Symbol)
    SpatialTopologyIdentityV1(candidate, space, topology,
        "mesh:contract-fixture-v1", "basis:contract-fixture-v1",
        "quadrature:contract-fixture-v1", "dof:contract-fixture-v1",
        "order:contract-fixture-v1", side)
end

function _sttc_default_regions()
    (SpatialRegionIdentityV1("region:source-v1", "owner:source-v1", :source, false),
     SpatialRegionIdentityV1("region:target-v1", "owner:target-v1", :target, false))
end

function _sttc_default_interfaces()
    (SpatialInterfaceIdentityV1("interface:source-target-v1", "region:source-v1",
        "region:target-v1", "owner:interface-v1", :minus_to_plus),)
end

function _sttc_default_accounts(unit::SpatialTransferUnitV1)
    (SpatialTypedAccountV1("account:source-v1", :region, "owner:source-v1",
        "region:source-v1", unit, :minus),
     SpatialTypedAccountV1("account:target-v1", :region, "owner:target-v1",
        "region:target-v1", unit, :plus))
end

function _sttc_default_effects(unit::SpatialTransferUnitV1)
    (SpatialAccountEffectV1("transfer:identity-v1", "account:source-v1", -1.0, unit, :minus),
     SpatialAccountEffectV1("transfer:identity-v1", "account:target-v1", 1.0, unit, :plus))
end

function _sttc_default_defects()
    Tuple(SpatialDefectV1(scope, "defect:" * String(scope) * "-v1", 0.0, 0.0)
          for scope in _STTC_DEFECT_SCOPES_V1)
end

function _sttc_default_diagnostics()
    Tuple(SpatialDiagnosticV1(name, 0.0, 0.0) for name in _STTC_DIAGNOSTIC_NAMES_V1)
end

function _sttc_sorted(values, key)
    Tuple(sort(collect(values), by=key))
end

# Effects may legally reuse a transfer/account/orientation key for split
# contributions.  The canonical order therefore includes every semantic
# effect field, including signed value and the complete unit identity.  Text
# representations keep the order total and stable even for malformed values;
# validation remains responsible for rejecting those values fail-closed.
_sttc_effect_sort_key(effect::SpatialAccountEffectV1) =
    (effect.transfer_ref, effect.account_ref, String(effect.orientation),
     repr(effect.signed_value), effect.unit.name, effect.unit.exponents,
     repr(effect.unit.scale_to_si))

function _sttc_order(source::SpatialTopologyIdentityV1, target::SpatialTopologyIdentityV1,
                     regions, interfaces, accounts, effects)
    Tuple(vcat(["source:" * source.topology_ref, "target:" * target.topology_ref],
        ["region:" * x.region_ref for x in regions],
        ["interface:" * x.interface_ref for x in interfaces],
        ["account:" * x.account_ref for x in accounts],
        ["effect:" * x.transfer_ref * ":" * x.account_ref for x in effects]))
end

function spatial_topology_transfer_v1(; schema::AbstractString=_STTC_SCHEMA_V1,
        revision::AbstractString=_STTC_REVISION_V1,
        candidate_ref::AbstractString="candidate:contract-fixture-v1",
        space_ref::AbstractString="space:contract-fixture-v1",
        source::SpatialTopologyIdentityV1=_sttc_identity(String(candidate_ref), String(space_ref), "topology:source-v1", :source),
        target::SpatialTopologyIdentityV1=_sttc_identity(String(candidate_ref), String(space_ref), "topology:target-v1", :target),
        regions=_sttc_default_regions(), interfaces=_sttc_default_interfaces(),
        accounts=_sttc_default_accounts(_sttc_unit()),
        effects=_sttc_default_effects(_sttc_unit()),
        defects=_sttc_default_defects(), diagnostics=_sttc_default_diagnostics(),
        constraint_refs=("constraint:transfer-conservation-v1",),
        physical_event_refs=(), external_closure_ref::AbstractString="",
        return_ref::AbstractString=_STTC_RETURN_REF_V1,
        claim_ceiling::Symbol=_STTC_CLAIM_CEILING_V1,
        evidence_scope::Symbol=_STTC_EVIDENCE_SCOPE_V1)
    source_effect_unit = isempty(accounts) ? _sttc_unit() : first(accounts).unit
    sorted_regions = _sttc_sorted(regions, x -> x.region_ref)
    sorted_interfaces = _sttc_sorted(interfaces, x -> x.interface_ref)
    sorted_accounts = _sttc_sorted(accounts, x -> x.account_ref)
    sorted_effects = _sttc_sorted(effects, _sttc_effect_sort_key)
    witness = SpatialTransferWitnessV1(source.topology_ref, target.topology_ref, sorted_effects)
    SpatialTopologyTransferV1(String(schema), String(revision), String(candidate_ref), String(space_ref),
        source, target, sorted_regions, sorted_interfaces, sorted_accounts, witness,
        Tuple(defects), Tuple(diagnostics), _sttc_tuple_text(Tuple(constraint_refs), "constraint_refs"),
        _sttc_tuple_text(Tuple(physical_event_refs), "physical_event_refs"; allow_empty=true),
        String(external_closure_ref), String(return_ref),
        _sttc_order(source, target, sorted_regions, sorted_interfaces, sorted_accounts, sorted_effects),
        claim_ceiling, evidence_scope)
end

_sttc_failure(code::Symbol, path, detail) = SpatialTransferFailureV1(code, String(path), String(detail))
_sttc_unit_equal(a::SpatialTransferUnitV1, b::SpatialTransferUnitV1) =
    a.name == b.name && a.exponents == b.exponents && isequal(a.scale_to_si, b.scale_to_si)
_sttc_units_compatible(a::SpatialTransferUnitV1, b::SpatialTransferUnitV1) =
    a.exponents == b.exponents && isfinite(a.scale_to_si) && a.scale_to_si > 0.0 &&
    isfinite(b.scale_to_si) && b.scale_to_si > 0.0
_sttc_fail!(failures, code, path, detail) = push!(failures, _sttc_failure(code, path, detail))

function _sttc_valid_unit(unit::SpatialTransferUnitV1, path::String, failures)
    isempty(strip(unit.name)) && _sttc_fail!(failures, :unit_mismatch, path, "unit name is empty")
    length(unit.exponents) == 7 || _sttc_fail!(failures, :unit_mismatch, path, "unit rank is not seven")
    isfinite(unit.scale_to_si) && unit.scale_to_si > 0.0 ||
        _sttc_fail!(failures, :unit_mismatch, path, "unit scale is not finite and positive")
end

function _sttc_valid_identity(identity::SpatialTopologyIdentityV1, expected_side::Symbol,
                              path::String, failures)
    for field in (:candidate_ref, :space_ref, :topology_ref, :mesh_ref, :basis_ref,
                  :quadrature_ref, :dof_ref, :order_ref)
        _sttc_require_ref!(failures, getfield(identity, field), :topology_identity_mismatch,
            path * "." * String(field), "identity reference is empty or wildcard")
    end
    identity.side === expected_side ||
        _sttc_fail!(failures, :topology_identity_mismatch, path * ".side", "source/target side mismatch")
end

function _sttc_expected_order(x::SpatialTopologyTransferV1)
    _sttc_order(x.source, x.target, x.regions, x.interfaces, x.accounts, x.witness.effects)
end

function validate_spatial_topology_transfer(x::SpatialTopologyTransferV1)
    failures = SpatialTransferFailureV1[]
    x.schema == _STTC_SCHEMA_V1 || _sttc_fail!(failures, :schema_mismatch, "schema", "schema is not exact V1")
    x.revision == _STTC_REVISION_V1 || _sttc_fail!(failures, :revision_mismatch, "revision", "revision is not exact V1")
    x.claim_ceiling === _STTC_CLAIM_CEILING_V1 ||
        _sttc_fail!(failures, :claim_ceiling_mismatch, "claim_ceiling", "physical or measured claim is forbidden")
    x.evidence_scope === _STTC_EVIDENCE_SCOPE_V1 ||
        _sttc_fail!(failures, :evidence_scope_mismatch, "evidence_scope", "only screen_only is allowed")
    _sttc_require_ref!(failures, x.candidate_ref, :candidate_mismatch, "candidate_ref",
        "candidate is empty or wildcard")
    _sttc_require_ref!(failures, x.space_ref, :space_mismatch, "space_ref",
        "space is empty or wildcard")
    _sttc_valid_identity(x.source, :source, "source", failures)
    _sttc_valid_identity(x.target, :target, "target", failures)
    x.source.candidate_ref == x.candidate_ref && x.target.candidate_ref == x.candidate_ref ||
        _sttc_fail!(failures, :candidate_mismatch, "topology", "candidate identity is not bound")
    x.source.space_ref == x.space_ref && x.target.space_ref == x.space_ref ||
        _sttc_fail!(failures, :space_mismatch, "topology", "space identity is not bound")
    for field in (:mesh_ref, :basis_ref, :quadrature_ref, :dof_ref, :order_ref)
        getfield(x.source, field) == getfield(x.target, field) ||
            _sttc_fail!(failures, :topology_identity_mismatch, "topology." * String(field), "source/target discretization identity differs")
    end
    x.witness.source_topology_ref == x.source.topology_ref &&
        x.witness.target_topology_ref == x.target.topology_ref ||
        _sttc_fail!(failures, :witness_mismatch, "witness.topology", "witness is not bound to source/target")

    region_refs = Set{String}()
    region_owners = Dict{String,String}()
    for region in x.regions
        _sttc_require_ref!(failures, region.region_ref, :region_mismatch, "regions.region_ref",
            "region ref is empty or wildcard")
        _sttc_require_ref!(failures, region.owner_ref, :owner_mismatch, "regions.owner_ref",
            "region owner is empty or wildcard")
        region.side in (:source, :target) || _sttc_fail!(failures, :region_mismatch, "regions", "invalid region side")
        region.region_ref in region_refs && _sttc_fail!(failures, :region_mismatch, "regions", "duplicate region ref")
        push!(region_refs, region.region_ref)
        region_owners[region.region_ref] = region.owner_ref
    end

    interface_refs = Set{String}()
    interface_owners = Dict{String,String}()
    for interface in x.interfaces
        _sttc_require_ref!(failures, interface.interface_ref, :interface_mismatch,
            "interfaces.interface_ref", "interface ref is empty or wildcard")
        _sttc_require_ref!(failures, interface.minus_region_ref, :interface_mismatch,
            "interfaces.minus_region_ref", "interface minus region ref is empty or wildcard")
        _sttc_require_ref!(failures, interface.plus_region_ref, :interface_mismatch,
            "interfaces.plus_region_ref", "interface plus region ref is empty or wildcard")
        _sttc_require_ref!(failures, interface.owner_ref, :owner_mismatch,
            "interfaces.owner_ref", "interface owner is empty or wildcard")
        interface.interface_ref in interface_refs && _sttc_fail!(failures, :interface_mismatch, "interfaces", "duplicate interface ref")
        push!(interface_refs, interface.interface_ref)
        interface_owners[interface.interface_ref] = interface.owner_ref
        interface.minus_region_ref in region_refs && interface.plus_region_ref in region_refs ||
            _sttc_fail!(failures, :interface_mismatch, "interfaces", "interface endpoint is dangling")
        interface.minus_region_ref != interface.plus_region_ref ||
            _sttc_fail!(failures, :interface_mismatch, "interfaces", "interface endpoints must differ")
        interface.orientation in (:minus_to_plus, :plus_to_minus) ||
            _sttc_fail!(failures, :orientation_mismatch, "interfaces", "invalid interface orientation")
    end

    account_refs = Set{String}()
    account_map = Dict{String,SpatialTypedAccountV1}()
    for account in x.accounts
        _sttc_require_ref!(failures, account.account_ref, :account_mismatch,
            "accounts.account_ref", "account ref is empty or wildcard")
        _sttc_require_ref!(failures, account.owner_ref, :owner_mismatch,
            "accounts.owner_ref", "account owner is empty or wildcard")
        _sttc_require_ref!(failures, account.region_ref, :account_mismatch,
            "accounts.region_ref", "account region/interface ref is empty or wildcard")
        account.account_ref in account_refs && _sttc_fail!(failures, :account_mismatch, "accounts", "duplicate account ref")
        push!(account_refs, account.account_ref)
        account.account_kind in (:local, :region, :interface, :exterior, :external) ||
            _sttc_fail!(failures, :account_mismatch, "accounts", "invalid account kind")
        _sttc_valid_unit(account.unit, "accounts." * account.account_ref * ".unit", failures)
        account.orientation in (:minus, :plus) ||
            _sttc_fail!(failures, :orientation_mismatch, "accounts." * account.account_ref, "invalid account orientation")
        if account.account_kind in (:local, :region, :exterior)
            account.region_ref in region_refs || _sttc_fail!(failures, :account_mismatch, "accounts", "region account is dangling")
            if haskey(region_owners, account.region_ref) && account.owner_ref != region_owners[account.region_ref]
                _sttc_fail!(failures, :owner_mismatch, "accounts." * account.account_ref, "account owner differs from region owner")
            end
            account.account_kind === :exterior && !any(r -> r.region_ref == account.region_ref && r.exterior, x.regions) &&
                _sttc_fail!(failures, :account_mismatch, "accounts." * account.account_ref, "exterior account is not exterior-owned")
        elseif account.account_kind === :interface
            account.region_ref in interface_refs || _sttc_fail!(failures, :account_mismatch, "accounts", "interface account is dangling")
            if haskey(interface_owners, account.region_ref) && account.owner_ref != interface_owners[account.region_ref]
                _sttc_fail!(failures, :owner_mismatch, "accounts." * account.account_ref,
                    "interface account owner differs from interface owner")
            end
        elseif account.region_ref != "external"
            _sttc_fail!(failures, :external_closure_mismatch, "accounts." * account.account_ref, "external account region must be external")
        elseif account.owner_ref != _STTC_EXTERNAL_OWNER_V1
            _sttc_fail!(failures, :owner_mismatch, "accounts." * account.account_ref,
                "external account owner is not the frozen external owner")
        end
        account_map[account.account_ref] = account
    end

    transfer_values = Dict{String,Float64}()
    transfer_units = Dict{String,SpatialTransferUnitV1}()
    transfer_has_minus = Set{String}()
    transfer_has_plus = Set{String}()
    transfer_has_external = Set{String}()
    for effect in x.witness.effects
        _sttc_valid_unit(effect.unit, "witness.effects." * effect.account_ref * ".unit", failures)
        _sttc_require_ref!(failures, effect.transfer_ref, :witness_mismatch,
            "witness.effects.transfer_ref", "transfer ref is empty or wildcard")
        _sttc_require_ref!(failures, effect.account_ref, :witness_mismatch,
            "witness.effects.account_ref", "effect account ref is empty or wildcard")
        effect.account_ref in account_refs || _sttc_fail!(failures, :witness_mismatch, "witness.effects", "effect account is dangling")
        isfinite(effect.signed_value) && effect.signed_value != 0.0 ||
            _sttc_fail!(failures, :nonfinite, "witness.effects", "effect value must be finite and nonzero")
        effect.orientation in (:minus, :plus) || _sttc_fail!(failures, :orientation_mismatch, "witness.effects", "invalid effect orientation")
        if effect.orientation === :minus
            effect.signed_value < 0.0 || _sttc_fail!(failures, :orientation_mismatch, "witness.effects", "minus effect must be negative")
            push!(transfer_has_minus, effect.transfer_ref)
        else
            effect.signed_value > 0.0 || _sttc_fail!(failures, :orientation_mismatch, "witness.effects", "plus effect must be positive")
            push!(transfer_has_plus, effect.transfer_ref)
        end
        if haskey(account_map, effect.account_ref)
            account = account_map[effect.account_ref]
            _sttc_units_compatible(effect.unit, account.unit) ||
                _sttc_fail!(failures, :unit_mismatch, "witness.effects", "effect/account dimensions or scales are incompatible")
            effect.orientation === account.orientation || _sttc_fail!(failures, :orientation_mismatch, "witness.effects", "effect/account orientation differs")
            account.account_kind === :external && push!(transfer_has_external, effect.transfer_ref)
            if _sttc_units_compatible(effect.unit, account.unit)
                if haskey(transfer_units, effect.transfer_ref)
                    _sttc_units_compatible(account.unit, transfer_units[effect.transfer_ref]) ||
                        _sttc_fail!(failures, :unit_mismatch, "witness." * effect.transfer_ref,
                            "transfer accounts require compatible canonical dimensions")
                    canonical_unit = transfer_units[effect.transfer_ref]
                    if _sttc_units_compatible(account.unit, canonical_unit)
                        normalized_value = effect.signed_value * effect.unit.scale_to_si /
                            canonical_unit.scale_to_si
                        transfer_values[effect.transfer_ref] =
                            get(transfer_values, effect.transfer_ref, 0.0) + normalized_value
                    end
                else
                    transfer_units[effect.transfer_ref] = account.unit
                    normalized_value = effect.signed_value * effect.unit.scale_to_si /
                        account.unit.scale_to_si
                    transfer_values[effect.transfer_ref] =
                        get(transfer_values, effect.transfer_ref, 0.0) + normalized_value
                end
            end
        else
            transfer_values[effect.transfer_ref] = get(transfer_values, effect.transfer_ref, 0.0) + effect.signed_value
        end
    end
    for transfer_ref in keys(transfer_values)
        transfer_ref in transfer_has_minus && transfer_ref in transfer_has_plus ||
            _sttc_fail!(failures, :return_mismatch, "witness." * transfer_ref, "transfer requires opposite signed orientations")
        abs(transfer_values[transfer_ref]) <= 1.0e-12 ||
            _sttc_fail!(failures, :conservation_defect, "witness." * transfer_ref, "transfer does not close")
    end
    has_external = !isempty(transfer_has_external)
    if has_external
        _sttc_ref_ok(x.external_closure_ref) ||
            _sttc_fail!(failures, :external_closure_mismatch, "external_closure_ref", "external effect lacks a non-wildcard closure ref")
        startswith(x.external_closure_ref, "external:") ||
            _sttc_fail!(failures, :external_closure_mismatch, "external_closure_ref", "external closure ref is not typed")
    elseif !isempty(strip(x.external_closure_ref))
        _sttc_fail!(failures, :external_closure_mismatch, "external_closure_ref", "closure ref has no external effect")
    end

    defect_scopes = Symbol[d.scope for d in x.defects]
    Set(defect_scopes) == Set(_STTC_DEFECT_SCOPES_V1) && length(defect_scopes) == length(_STTC_DEFECT_SCOPES_V1) ||
        _sttc_fail!(failures, :defect_scope_mismatch, "defects", "all six defect scopes are required exactly once")
    for defect in x.defects
        defect.scope in _STTC_DEFECT_SCOPES_V1 || _sttc_fail!(failures, :defect_scope_mismatch, "defects", "unknown defect scope")
        _sttc_require_ref!(failures, defect.defect_ref, :defect_scope_mismatch,
            "defects.defect_ref", "defect ref is empty or wildcard")
        isfinite(defect.value) && isfinite(defect.tolerance) && defect.tolerance >= 0.0 ||
            _sttc_fail!(failures, :nonfinite, "defects", "defect value/tolerance is not finite")
        isfinite(defect.value) && isfinite(defect.tolerance) && abs(defect.value) <= defect.tolerance ||
            _sttc_fail!(failures, :conservation_defect, "defects", "defect exceeds tolerance")
    end
    diagnostic_names = Symbol[d.name for d in x.diagnostics]
    Set(diagnostic_names) == Set(_STTC_DIAGNOSTIC_NAMES_V1) && length(diagnostic_names) == length(_STTC_DIAGNOSTIC_NAMES_V1) ||
        _sttc_fail!(failures, :diagnostic_mismatch, "diagnostics", "divB/positivity/gauge/nullspace diagnostics are required")
    for diagnostic in x.diagnostics
        diagnostic.name in _STTC_DIAGNOSTIC_NAMES_V1 || _sttc_fail!(failures, :diagnostic_mismatch, "diagnostics", "unknown diagnostic")
        isfinite(diagnostic.value) && isfinite(diagnostic.tolerance) && diagnostic.tolerance >= 0.0 ||
            _sttc_fail!(failures, :nonfinite, "diagnostics", "diagnostic value/tolerance is not finite")
        isfinite(diagnostic.value) && isfinite(diagnostic.tolerance) && abs(diagnostic.value) <= diagnostic.tolerance ||
            _sttc_fail!(failures, :diagnostic_mismatch, "diagnostics", "diagnostic exceeds tolerance")
    end

    isempty(x.constraint_refs) && _sttc_fail!(failures, :constraint_mismatch, "constraint_refs", "at least one typed constraint is required")
    length(unique(x.constraint_refs)) == length(x.constraint_refs) || _sttc_fail!(failures, :constraint_mismatch, "constraint_refs", "constraint refs duplicate")
    all(_sttc_ref_ok(ref) for ref in x.constraint_refs) ||
        _sttc_fail!(failures, :constraint_mismatch, "constraint_refs", "constraint ref is empty or wildcard")
    all(startswith(ref, "constraint:") for ref in x.constraint_refs) || _sttc_fail!(failures, :constraint_mismatch, "constraint_refs", "constraint ref is not typed")
    isempty(x.physical_event_refs) || _sttc_fail!(failures, :physical_event_misuse, "physical_event_refs", "physical event execution is outside this contract")
    _sttc_ref_ok(x.return_ref) && x.return_ref == _STTC_RETURN_REF_V1 ||
        _sttc_fail!(failures, :return_mismatch, "return_ref", "return identity is not exact")
    x.canonical_order == _sttc_expected_order(x) || _sttc_fail!(failures, :canonical_order_mismatch, "canonical_order", "order is not the deterministic contract order")

    SpatialTransferValidationV1(isempty(failures), isempty(failures) ? _STTC_READY_V1 : _STTC_FAIL_CLOSED_V1,
        Tuple(failures), _STTC_CLAIM_CEILING_V1, _STTC_EVIDENCE_SCOPE_V1, 0, 0, 0)
end

_sttc_quote(value) = "\"" * replace(String(value), "\\" => "\\\\", "\"" => "\\\"") * "\""
_sttc_unit_wire(x::SpatialTransferUnitV1) = "{" *
    "name:" * _sttc_quote(x.name) * ",exponents:" * repr(x.exponents) * ",scale:" * repr(x.scale_to_si) * "}"
_sttc_identity_wire(x::SpatialTopologyIdentityV1) = "{" *
    "candidate:" * _sttc_quote(x.candidate_ref) * ",space:" * _sttc_quote(x.space_ref) *
    ",topology:" * _sttc_quote(x.topology_ref) * ",mesh:" * _sttc_quote(x.mesh_ref) *
    ",basis:" * _sttc_quote(x.basis_ref) * ",quadrature:" * _sttc_quote(x.quadrature_ref) *
    ",dof:" * _sttc_quote(x.dof_ref) * ",order:" * _sttc_quote(x.order_ref) *
    ",side:" * _sttc_quote(x.side) * "}"
_sttc_region_wire(x::SpatialRegionIdentityV1) =
    "{" * _sttc_quote(x.region_ref) * ":" * _sttc_quote(x.owner_ref) * ":" * _sttc_quote(x.side) * ":" * string(x.exterior) * "}"
_sttc_interface_wire(x::SpatialInterfaceIdentityV1) =
    "{" * _sttc_quote(x.interface_ref) * ":" * _sttc_quote(x.minus_region_ref) * ":" * _sttc_quote(x.plus_region_ref) * ":" * _sttc_quote(x.owner_ref) * ":" * _sttc_quote(x.orientation) * "}"
_sttc_account_wire(x::SpatialTypedAccountV1) =
    "{" * _sttc_quote(x.account_ref) * ":" * _sttc_quote(x.account_kind) * ":" * _sttc_quote(x.owner_ref) * ":" * _sttc_quote(x.region_ref) * ":" * _sttc_unit_wire(x.unit) * ":" * _sttc_quote(x.orientation) * "}"
_sttc_effect_wire(x::SpatialAccountEffectV1) =
    "{" * _sttc_quote(x.transfer_ref) * ":" * _sttc_quote(x.account_ref) * ":" * repr(x.signed_value) * ":" * _sttc_unit_wire(x.unit) * ":" * _sttc_quote(x.orientation) * "}"

function spatial_topology_transfer_canonical_json(x::SpatialTopologyTransferV1)
    join(("schema=" * _sttc_quote(x.schema), "revision=" * _sttc_quote(x.revision),
        "candidate=" * _sttc_quote(x.candidate_ref), "space=" * _sttc_quote(x.space_ref),
        "source=" * _sttc_identity_wire(x.source), "target=" * _sttc_identity_wire(x.target),
        "regions=[" * join((_sttc_region_wire(v) for v in x.regions), ",") * "]",
        "interfaces=[" * join((_sttc_interface_wire(v) for v in x.interfaces), ",") * "]",
        "accounts=[" * join((_sttc_account_wire(v) for v in x.accounts), ",") * "]",
        "effects=[" * join((_sttc_effect_wire(v) for v in x.witness.effects), ",") * "]",
        "defects=" * repr(x.defects), "diagnostics=" * repr(x.diagnostics),
        "constraints=" * repr(x.constraint_refs), "external=" * _sttc_quote(x.external_closure_ref),
        "return=" * _sttc_quote(x.return_ref), "order=" * repr(x.canonical_order)), "|")
end

spatial_topology_transfer_canonical_hash(x::SpatialTopologyTransferV1) =
    bytes2hex(sha256(codeunits(spatial_topology_transfer_canonical_json(x))))
