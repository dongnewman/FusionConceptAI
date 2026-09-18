"""UP4-02A engineering-feedback bridge, contract-only V1.

This file is deliberately additive.  It binds one candidate-owned engineering
feedback declaration to the frozen identity tuple and checks typed resource,
ledger, unit, direction, ownership, capacity, and feedback edges.  It does not
call a provider, solver, checker, hardware, or external service.  A successful
structural validation is still `accepted=false`, `claim_ceiling=:contract_only`,
and carries no engineering, physical, or R01--R10 credit.
"""

import FusionConceptAI: Digest256, digest256_text, canonical_hash, semantic_view

const UP4_02A_SCHEMA = "fusionconceptai:up4-02a-engineering-feedback-bridge-v1"
const UP4_02A_REVISION = "UP4-02A-ENGINEERING-FEEDBACK-BRIDGE-V1"
const UP4_02A_CLAIM_CEILING = :contract_only
const UP4_02A_FAILURE_CODES = (
    :candidate_hash_mismatch, :g3_hash_mismatch, :missing_return,
    :missing_heat_sink, :ledger_imbalance, :unit_mismatch, :passive_source,
    :capacity_exceeded, :missing_support_boundary, :unknown_material,
    :provider_dropout, :ambiguous_provider, :static_flux_to_emf,
    :feedback_edge_removed, :scenario_reuse_mismatch,
    :missing_source, :direction_mismatch, :owner_mismatch,
    :feedback_control_resource_link_mismatch, :realization_plan_hash_mismatch,
    :control_plan_hash_mismatch, :provider_capability_gap, :solver_capability_gap,
    :checker_capability_gap, :missing_link, :duplicate_ledger, :empty_entry,
    :forged_residual)
const _UP4_02A_REF_KINDS = (
    :candidate, :genome, :axis, :parent, :mission, :scenario,
    :physical_subject, :source, :coil, :driver, :return, :heat_sink,
    :material, :manufacturing, :cooling, :support, :control_fault,
    :control, :provider, :solver, :checker, :feedback_target)
const _UP4_02A_REF_STATUSES = (:present, :typed_absent, :unknown)
const _UP4_02A_DIRECTIONS = (:in, :out, :bidirectional, :passive)
const _UP4_02A_UNITS = (:W, :J, :kg, :K, :Pa, :m, :A, :V, :T, :kg_m3, :unitless,
    :unspecified)
const _UP4_02A_LEDGER_KINDS = (:energy, :material, :thermal, :mechanical)
const _UP4_02A_RESOURCE_RULES = (
    (kind=:source, directions=(:in, :bidirectional), units=(:W,), domain=:energy),
    (kind=:coil, directions=(:out, :bidirectional), units=(:W,), domain=:mechanical),
    (kind=:driver, directions=(:out, :bidirectional), units=(:W,), domain=:mechanical),
    (kind=:return, directions=(:out, :bidirectional), units=(:W,), domain=:energy),
    (kind=:heat_sink, directions=(:out, :bidirectional), units=(:W,), domain=:energy),
    (kind=:material, directions=(:in, :out, :bidirectional), units=(:kg,), domain=:material),
    (kind=:manufacturing, directions=(:out, :bidirectional), units=(:kg,), domain=:material),
    (kind=:cooling, directions=(:in, :out, :bidirectional), units=(:W,), domain=:thermal),
    (kind=:support, directions=(:in, :out, :bidirectional), units=(:W,), domain=:mechanical),
    (kind=:control_fault, directions=(:in, :out, :bidirectional), units=(:W,), domain=:feedback),
    (kind=:control, directions=(:in, :out, :bidirectional), units=(:W,), domain=:feedback),
    (kind=:provider, directions=(:in, :out, :bidirectional), units=(:unitless,), domain=:capability),
    (kind=:solver, directions=(:in, :out, :bidirectional), units=(:unitless,), domain=:capability),
    (kind=:checker, directions=(:in, :out, :bidirectional), units=(:unitless,), domain=:capability))

struct EngineeringFeedbackBridgeInputError <: Exception
    code::Symbol
    detail::String
end
Base.showerror(io::IO, e::EngineeringFeedbackBridgeInputError) =
    print(io, "UP4-02A input [", e.code, "]: ", e.detail)
_up4_02a_error(msg) = EngineeringFeedbackBridgeInputError(:malformed_input, String(msg))
_up4_02a_text(x, label) = begin
    x isa AbstractString || throw(_up4_02a_error("$label must be a string"))
    s = String(x)
    isempty(strip(s)) || !isvalid(s) ? throw(_up4_02a_error("$label must be non-empty UTF-8")) : s
end
_up4_02a_digest(x, label) = x isa Digest256 ? x : throw(_up4_02a_error("$label must be Digest256"))
_up4_02a_symbol(x, allowed, label) = x isa Symbol && x in allowed ? x :
    throw(_up4_02a_error("invalid $label"))
_up4_02a_tuple(x, label) = x isa Tuple ? x : throw(_up4_02a_error("$label must be an immutable tuple"))
_up4_02a_rat(x, label) = begin
    x isa Bool && throw(_up4_02a_error("$label must be rational"))
    x isa Rational || x isa Integer || throw(_up4_02a_error("$label must be rational"))
    Rational{Int64}(x)
end

"""Content-addressed typed reference.  `typed_absent` is explicit."""
struct EngineeringFeedbackTypedRefV1
    ref::String
    kind::Symbol
    version::String
    candidate_hash::Digest256
    scenario_hash::Digest256
    content_hash::Digest256
    unit::Symbol
    direction::Symbol
    owner_scope::String
    capacity::Rational{Int64}
    status::Symbol
    reason::String
    ref_hash::Digest256
    function EngineeringFeedbackTypedRefV1(ref, kind, version, candidate_hash,
            scenario_hash, content_hash, unit, direction, owner_scope, capacity,
            status, reason, ref_hash)
        k = _up4_02a_symbol(kind, _UP4_02A_REF_KINDS, "ref kind")
        u = _up4_02a_symbol(unit, _UP4_02A_UNITS, "ref unit")
        d = _up4_02a_symbol(direction, _UP4_02A_DIRECTIONS, "ref direction")
        st = _up4_02a_symbol(status, _UP4_02A_REF_STATUSES, "ref status")
        why = String(reason)
        (st === :present && isempty(strip(why))) || (st !== :present && !isempty(strip(why))) ||
            throw(_up4_02a_error("present/absent ref reason mismatch"))
        new(_up4_02a_text(ref, "ref"), k, _up4_02a_text(version, "version"),
            _up4_02a_digest(candidate_hash, "candidate hash"),
            _up4_02a_digest(scenario_hash, "scenario hash"),
            _up4_02a_digest(content_hash, "content hash"), u, d,
            _up4_02a_text(owner_scope, "owner_scope"), _up4_02a_rat(capacity, "capacity"),
            st, why, _up4_02a_digest(ref_hash, "ref hash"))
    end
end

"""Hash of the identity projection, excluding the typed pointer/hash fields."""
function _up4_02a_identity_projection(x::EngineeringFeedbackTypedRefV1)
    (revision=UP4_02A_REVISION, ref=x.ref, kind=x.kind, version=x.version,
        unit=x.unit, direction=x.direction, owner_scope=x.owner_scope,
        capacity=x.capacity, status=x.status, reason=x.reason)
end
_up4_02a_identity_projection_hash(x::EngineeringFeedbackTypedRefV1) =
    canonical_hash(_up4_02a_identity_projection(x))

function _up4_02a_ref_body(x::EngineeringFeedbackTypedRefV1)
    (revision=UP4_02A_REVISION, ref=x.ref, kind=x.kind, version=x.version,
        candidate_hash=x.candidate_hash, scenario_hash=x.scenario_hash,
        content_hash=x.content_hash, unit=x.unit, direction=x.direction,
        owner_scope=x.owner_scope, capacity=x.capacity, status=x.status, reason=x.reason)
end
semantic_view(x::EngineeringFeedbackTypedRefV1) = merge(_up4_02a_ref_body(x), (ref_hash=x.ref_hash,))
canonical_hash(x::EngineeringFeedbackTypedRefV1) = begin
    expected = canonical_hash(_up4_02a_ref_body(x))
    expected == x.ref_hash || throw(ArgumentError("engineering feedback ref hash mismatch"))
    expected
end

struct EngineeringFeedbackVersionAxesV1
    contract_axis::EngineeringFeedbackTypedRefV1
    schema_axis::EngineeringFeedbackTypedRefV1
    canonicalization_axis::EngineeringFeedbackTypedRefV1
    compatibility_axis::EngineeringFeedbackTypedRefV1
    axes_hash::Digest256
    function EngineeringFeedbackVersionAxesV1(a, b, c, d, h)
        xs = (a, b, c, d)
        all(x -> x isa EngineeringFeedbackTypedRefV1 && x.kind === :axis, xs) ||
            throw(_up4_02a_error("four version axes must be typed axis refs"))
        length(unique(x.ref_hash for x in xs)) == 4 || throw(_up4_02a_error("four axes must be distinct"))
        new(xs..., _up4_02a_digest(h, "axes hash"))
    end
end
function _up4_02a_axes_body(x::EngineeringFeedbackVersionAxesV1)
    (revision=UP4_02A_REVISION, contract_axis=x.contract_axis, schema_axis=x.schema_axis,
        canonicalization_axis=x.canonicalization_axis, compatibility_axis=x.compatibility_axis)
end
semantic_view(x::EngineeringFeedbackVersionAxesV1) = merge(_up4_02a_axes_body(x), (axes_hash=x.axes_hash,))
canonical_hash(x::EngineeringFeedbackVersionAxesV1) = begin
    foreach(canonical_hash, (x.contract_axis, x.schema_axis, x.canonicalization_axis, x.compatibility_axis))
    expected = canonical_hash(_up4_02a_axes_body(x))
    expected == x.axes_hash || throw(ArgumentError("engineering feedback axes hash mismatch"))
    expected
end

"""Exact candidate/G1/G2/G3/parent/mission/scenario/subject/axis join."""
struct EngineeringFeedbackBindingV1
    candidate::EngineeringFeedbackTypedRefV1
    g1::EngineeringFeedbackTypedRefV1
    g2::EngineeringFeedbackTypedRefV1
    g3::EngineeringFeedbackTypedRefV1
    parent::EngineeringFeedbackTypedRefV1
    mission::EngineeringFeedbackTypedRefV1
    scenario::EngineeringFeedbackTypedRefV1
    physical_subject::EngineeringFeedbackTypedRefV1
    axes::EngineeringFeedbackVersionAxesV1
    design_hash::Digest256
    realization_plan_hash::Digest256
    control_plan_hash::Digest256
    binding_hash::Digest256
    function EngineeringFeedbackBindingV1(candidate, g1, g2, g3, parent, mission,
            scenario, physical_subject, axes, design_hash, realization_plan_hash,
            control_plan_hash, binding_hash)
        xs = (candidate, g1, g2, g3, parent, mission, scenario, physical_subject)
        all(x -> x isa EngineeringFeedbackTypedRefV1, xs) || throw(_up4_02a_error("binding refs must be typed"))
        Tuple(x.kind for x in xs) == (:candidate, :genome, :genome, :genome, :parent,
            :mission, :scenario, :physical_subject) || throw(_up4_02a_error("binding ref kinds mismatch"))
        axes isa EngineeringFeedbackVersionAxesV1 || throw(_up4_02a_error("binding axes are untyped"))
        new(xs..., axes, _up4_02a_digest(design_hash, "design hash"),
            _up4_02a_digest(realization_plan_hash, "realization plan hash"),
            _up4_02a_digest(control_plan_hash, "control plan hash"),
            _up4_02a_digest(binding_hash, "binding hash"))
    end
end
function _up4_02a_binding_body(x::EngineeringFeedbackBindingV1)
    (revision=UP4_02A_REVISION, candidate=x.candidate, g1=x.g1, g2=x.g2, g3=x.g3,
        parent=x.parent, mission=x.mission, scenario=x.scenario,
        physical_subject=x.physical_subject, axes=x.axes, design_hash=x.design_hash,
        realization_plan_hash=x.realization_plan_hash, control_plan_hash=x.control_plan_hash)
end
semantic_view(x::EngineeringFeedbackBindingV1) = merge(_up4_02a_binding_body(x), (binding_hash=x.binding_hash,))
canonical_hash(x::EngineeringFeedbackBindingV1) = begin
    foreach(canonical_hash, (x.candidate, x.g1, x.g2, x.g3, x.parent, x.mission,
        x.scenario, x.physical_subject)); canonical_hash(x.axes)
    expected = canonical_hash(_up4_02a_binding_body(x))
    expected == x.binding_hash || throw(ArgumentError("engineering feedback binding hash mismatch"))
    expected
end

struct EngineeringFeedbackLedgerEntryV1
    entry_id::String
    role::Symbol
    amount::Rational{Int64}
    sign::Int8
    unit::Symbol
    direction::Symbol
    owner_scope::String
    resource_hash::Digest256
    function EngineeringFeedbackLedgerEntryV1(entry_id, role, amount, sign, unit,
            direction, owner_scope, resource_hash)
        r = _up4_02a_symbol(role, (:source, :field, :return, :heat_sink, :input, :output), "ledger role")
        a = _up4_02a_rat(amount, "amount")
        a >= 0 || throw(_up4_02a_error("ledger amount must be non-negative"))
        s = sign isa Integer && !(sign isa Bool) ? Int(sign) : throw(_up4_02a_error("ledger sign must be integer"))
        s in (-1, 1) || throw(_up4_02a_error("ledger sign must be -1 or +1"))
        new(_up4_02a_text(entry_id, "entry_id"), r, a, Int8(s),
            _up4_02a_symbol(unit, _UP4_02A_UNITS, "ledger unit"),
            _up4_02a_symbol(direction, _UP4_02A_DIRECTIONS, "ledger direction"),
            _up4_02a_text(owner_scope, "ledger owner"),
            _up4_02a_digest(resource_hash, "ledger resource hash"))
    end
end
semantic_view(x::EngineeringFeedbackLedgerEntryV1) = (entry_id=x.entry_id, role=x.role,
    amount=x.amount, sign=x.sign, unit=x.unit, direction=x.direction,
    owner_scope=x.owner_scope, resource_hash=x.resource_hash)

struct EngineeringFeedbackLedgerClosureV1
    ledger_kind::Symbol
    entries::Tuple{Vararg{EngineeringFeedbackLedgerEntryV1}}
    expected_residual::Rational{Int64}
    actual_residual::Rational{Int64}
    unit::Symbol
    owner_scope::String
    closure_hash::Digest256
    function EngineeringFeedbackLedgerClosureV1(kind, entries, expected_residual,
            actual_residual, unit, owner_scope, closure_hash)
        k = _up4_02a_symbol(kind, _UP4_02A_LEDGER_KINDS, "ledger kind")
        es = _up4_02a_tuple(entries, "ledger entries")
        all(x -> x isa EngineeringFeedbackLedgerEntryV1, es) || throw(_up4_02a_error("ledger entries must be typed"))
        new(k, es, _up4_02a_rat(expected_residual, "expected residual"),
            _up4_02a_rat(actual_residual, "actual residual"),
            _up4_02a_symbol(unit, _UP4_02A_UNITS, "closure unit"),
            _up4_02a_text(owner_scope, "closure owner"), _up4_02a_digest(closure_hash, "closure hash"))
    end
end
function _up4_02a_ledger_body(x::EngineeringFeedbackLedgerClosureV1)
    (revision=UP4_02A_REVISION, ledger_kind=x.ledger_kind, entries=x.entries,
        expected_residual=x.expected_residual, actual_residual=x.actual_residual,
        unit=x.unit, owner_scope=x.owner_scope)
end
semantic_view(x::EngineeringFeedbackLedgerClosureV1) = merge(_up4_02a_ledger_body(x), (closure_hash=x.closure_hash,))
canonical_hash(x::EngineeringFeedbackLedgerClosureV1) = begin
    foreach(canonical_hash, x.entries)
    expected = canonical_hash(_up4_02a_ledger_body(x))
    expected == x.closure_hash || throw(ArgumentError("ledger closure hash mismatch"))
    expected
end

struct EngineeringFeedbackFeedbackTargetV1
    target_id::String
    target_layer::Symbol
    target_path::String
    quantity::Symbol
    unit::Symbol
    direction::Symbol
    owner_scope::String
    control_resource::EngineeringFeedbackTypedRefV1
    candidate_hash::Digest256
    g1_hash::Digest256
    g2_hash::Digest256
    g3_hash::Digest256
    status::Symbol
    target_hash::Digest256
    function EngineeringFeedbackFeedbackTargetV1(target_id, target_layer, target_path,
            quantity, unit, direction, owner_scope, control_resource, candidate_hash,
            g1_hash, g2_hash, g3_hash, status, target_hash)
        l = _up4_02a_symbol(target_layer, (:G1, :G2, :G3), "feedback layer")
        q = _up4_02a_symbol(quantity, (:residual, :loss, :thermal_load, :deformation, :control_fault), "feedback quantity")
        cr = control_resource isa EngineeringFeedbackTypedRefV1 ? control_resource : throw(_up4_02a_error("control resource must be typed"))
        st = _up4_02a_symbol(status, _UP4_02A_REF_STATUSES, "feedback status")
        new(_up4_02a_text(target_id, "target id"), l, _up4_02a_text(target_path, "target path"), q,
            _up4_02a_symbol(unit, _UP4_02A_UNITS, "feedback unit"),
            _up4_02a_symbol(direction, _UP4_02A_DIRECTIONS, "feedback direction"),
            _up4_02a_text(owner_scope, "feedback owner"), cr,
            _up4_02a_digest(candidate_hash, "feedback candidate hash"),
            _up4_02a_digest(g1_hash, "feedback G1 hash"),
            _up4_02a_digest(g2_hash, "feedback G2 hash"),
            _up4_02a_digest(g3_hash, "feedback G3 hash"), st,
            _up4_02a_digest(target_hash, "target hash"))
    end
end
function _up4_02a_target_body(x::EngineeringFeedbackFeedbackTargetV1)
    (revision=UP4_02A_REVISION, target_id=x.target_id, target_layer=x.target_layer,
        target_path=x.target_path, quantity=x.quantity, unit=x.unit,
        direction=x.direction, owner_scope=x.owner_scope, control_resource=x.control_resource,
        candidate_hash=x.candidate_hash, g1_hash=x.g1_hash, g2_hash=x.g2_hash,
        g3_hash=x.g3_hash, status=x.status)
end
semantic_view(x::EngineeringFeedbackFeedbackTargetV1) = merge(_up4_02a_target_body(x), (target_hash=x.target_hash,))
canonical_hash(x::EngineeringFeedbackFeedbackTargetV1) = begin
    canonical_hash(x.control_resource)
    expected = canonical_hash(_up4_02a_target_body(x))
    expected == x.target_hash || throw(ArgumentError("feedback target hash mismatch"))
    expected
end

"""All consumed resource and capability refs; no defaults are inferred."""
struct EngineeringFeedbackResourceBundleV1
    source::EngineeringFeedbackTypedRefV1
    coil::EngineeringFeedbackTypedRefV1
    driver::EngineeringFeedbackTypedRefV1
    return_ref::EngineeringFeedbackTypedRefV1
    heat_sink::EngineeringFeedbackTypedRefV1
    material::EngineeringFeedbackTypedRefV1
    manufacturing::EngineeringFeedbackTypedRefV1
    cooling::EngineeringFeedbackTypedRefV1
    support::EngineeringFeedbackTypedRefV1
    control_fault::EngineeringFeedbackTypedRefV1
    control::EngineeringFeedbackTypedRefV1
    provider::EngineeringFeedbackTypedRefV1
    solver::EngineeringFeedbackTypedRefV1
    checker::EngineeringFeedbackTypedRefV1
    realization_plan_hash::Digest256
    control_plan_hash::Digest256
    bundle_hash::Digest256
    function EngineeringFeedbackResourceBundleV1(source, coil, driver, return_ref,
            heat_sink, material, manufacturing, cooling, support, control_fault,
            control, provider, solver, checker, realization_plan_hash,
            control_plan_hash, bundle_hash)
        refs = (source, coil, driver, return_ref, heat_sink, material, manufacturing,
            cooling, support, control_fault, control, provider, solver, checker)
        all(x -> x isa EngineeringFeedbackTypedRefV1, refs) ||
            throw(_up4_02a_error("resource slots must be typed"))
        Tuple(x.kind for x in refs) == (:source, :coil, :driver, :return, :heat_sink,
            :material, :manufacturing, :cooling, :support, :control_fault, :control,
            :provider, :solver, :checker) ||
            throw(_up4_02a_error("resource slot kind mismatch"))
        new(refs..., _up4_02a_digest(realization_plan_hash, "realization plan hash"),
            _up4_02a_digest(control_plan_hash, "control plan hash"),
            _up4_02a_digest(bundle_hash, "bundle hash"))
    end
end
function _up4_02a_resource_body(x::EngineeringFeedbackResourceBundleV1)
    (revision=UP4_02A_REVISION, source=x.source, coil=x.coil, driver=x.driver,
        return_ref=x.return_ref, heat_sink=x.heat_sink, material=x.material,
        manufacturing=x.manufacturing, cooling=x.cooling, support=x.support,
        control_fault=x.control_fault, control=x.control, provider=x.provider,
        solver=x.solver, checker=x.checker, realization_plan_hash=x.realization_plan_hash,
        control_plan_hash=x.control_plan_hash)
end
semantic_view(x::EngineeringFeedbackResourceBundleV1) = merge(_up4_02a_resource_body(x), (bundle_hash=x.bundle_hash,))
canonical_hash(x::EngineeringFeedbackResourceBundleV1) = begin
    foreach(canonical_hash, (x.source, x.coil, x.driver, x.return_ref, x.heat_sink,
        x.material, x.manufacturing, x.cooling, x.support, x.control_fault, x.control,
        x.provider, x.solver, x.checker))
    expected = canonical_hash(_up4_02a_resource_body(x))
    expected == x.bundle_hash || throw(ArgumentError("resource bundle hash mismatch"))
    expected
end

struct EngineeringFeedbackBridgeContractV1
    schema::String
    revision::String
    request_ref::String
    binding::EngineeringFeedbackBindingV1
    resources::EngineeringFeedbackResourceBundleV1
    ledgers::Tuple{Vararg{EngineeringFeedbackLedgerClosureV1}}
    feedback_targets::Tuple{Vararg{EngineeringFeedbackFeedbackTargetV1}}
    static_flux::Rational{Int64}
    emf::Rational{Int64}
    time_derivative_declared::Bool
    motion_declared::Bool
    drive_declared::Bool
    canonical_bytes::String
    canonical_bytes_hash::Digest256
    request_hash::Digest256
    function EngineeringFeedbackBridgeContractV1(schema, revision, request_ref,
            binding, resources, ledgers, feedback_targets, static_flux, emf,
            time_derivative_declared, motion_declared, drive_declared,
            canonical_bytes, canonical_bytes_hash, request_hash)
        String(schema) == UP4_02A_SCHEMA || throw(_up4_02a_error("schema mismatch"))
        String(revision) == UP4_02A_REVISION || throw(_up4_02a_error("revision mismatch"))
        binding isa EngineeringFeedbackBindingV1 || throw(_up4_02a_error("binding untyped"))
        resources isa EngineeringFeedbackResourceBundleV1 || throw(_up4_02a_error("resources untyped"))
        ls = _up4_02a_tuple(ledgers, "ledgers")
        all(x -> x isa EngineeringFeedbackLedgerClosureV1, ls) || throw(_up4_02a_error("ledgers untyped"))
        ts = _up4_02a_tuple(feedback_targets, "feedback_targets")
        all(x -> x isa EngineeringFeedbackFeedbackTargetV1, ts) || throw(_up4_02a_error("feedback targets untyped"))
        new(UP4_02A_SCHEMA, UP4_02A_REVISION, _up4_02a_text(request_ref, "request_ref"),
            binding, resources, Tuple(ls), Tuple(ts), _up4_02a_rat(static_flux, "static_flux"),
            _up4_02a_rat(emf, "emf"), Bool(time_derivative_declared), Bool(motion_declared),
            Bool(drive_declared), _up4_02a_text(canonical_bytes, "canonical_bytes"),
            _up4_02a_digest(canonical_bytes_hash, "canonical bytes hash"),
            _up4_02a_digest(request_hash, "request hash"))
    end
end
function _up4_02a_request_body(x::EngineeringFeedbackBridgeContractV1)
    (schema=UP4_02A_SCHEMA, revision=UP4_02A_REVISION, request_ref=x.request_ref,
        binding=x.binding, resources=x.resources, ledgers=x.ledgers,
        feedback_targets=x.feedback_targets, static_flux=x.static_flux, emf=x.emf,
        time_derivative_declared=x.time_derivative_declared, motion_declared=x.motion_declared,
        drive_declared=x.drive_declared, canonical_bytes_hash=x.canonical_bytes_hash)
end
semantic_view(x::EngineeringFeedbackBridgeContractV1) = merge(_up4_02a_request_body(x), (request_hash=x.request_hash,))
canonical_hash(x::EngineeringFeedbackBridgeContractV1) = begin
    digest256_text(x.canonical_bytes) == x.canonical_bytes_hash || throw(ArgumentError("canonical bytes hash mismatch"))
    canonical_hash(x.binding); canonical_hash(x.resources); foreach(canonical_hash, x.ledgers)
    foreach(canonical_hash, x.feedback_targets)
    expected = canonical_hash(_up4_02a_request_body(x))
    expected == x.request_hash || throw(ArgumentError("engineering feedback request hash mismatch"))
    expected
end

struct EngineeringFeedbackBridgeResolutionV1
    status::Symbol
    accepted::Bool
    claim_ceiling::Symbol
    engineering_credit::Symbol
    physical_credit::Symbol
    r01_r10_credit::Symbol
    request_hash::Digest256
    failures::Tuple{Vararg{Symbol}}
    provider_gap::Bool
    solver_gap::Bool
    checker_gap::Bool
    provider_calls::Int
    solver_calls::Int
    checker_calls::Int
    resolution_hash::Digest256
    function EngineeringFeedbackBridgeResolutionV1(status, accepted, claim_ceiling,
            engineering_credit, physical_credit, r01_r10_credit, request_hash,
            failures, provider_gap, solver_gap, checker_gap, provider_calls,
            solver_calls, checker_calls, resolution_hash)
        status in (:prepared, :fail_closed, :terminal_deferred) ||
            throw(_up4_02a_error("invalid bridge resolution status"))
        accepted === false || throw(_up4_02a_error("UP4-02A cannot be accepted"))
        claim_ceiling === UP4_02A_CLAIM_CEILING || throw(_up4_02a_error("invalid claim ceiling"))
        engineering_credit === :none && physical_credit === :none && r01_r10_credit === :none ||
            throw(_up4_02a_error("UP4-02A credit must remain none"))
        fs = _up4_02a_tuple(failures, "resolution failures")
        all(x -> x isa Symbol, fs) || throw(_up4_02a_error("resolution failures must be symbols"))
        provider_calls == solver_calls == checker_calls == 0 ||
            throw(_up4_02a_error("execution counters must remain zero"))
        new(status, false, UP4_02A_CLAIM_CEILING, :none, :none, :none,
            _up4_02a_digest(request_hash, "resolution request hash"), fs,
            Bool(provider_gap), Bool(solver_gap), Bool(checker_gap), 0, 0, 0,
            _up4_02a_digest(resolution_hash, "resolution hash"))
    end
end
function _up4_02a_resolution_body(x::EngineeringFeedbackBridgeResolutionV1)
    (revision=UP4_02A_REVISION, status=x.status, accepted=x.accepted,
        claim_ceiling=x.claim_ceiling, engineering_credit=x.engineering_credit,
        physical_credit=x.physical_credit, r01_r10_credit=x.r01_r10_credit,
        request_hash=x.request_hash, failures=x.failures, provider_gap=x.provider_gap,
        solver_gap=x.solver_gap, checker_gap=x.checker_gap, provider_calls=x.provider_calls,
        solver_calls=x.solver_calls, checker_calls=x.checker_calls)
end
semantic_view(x::EngineeringFeedbackBridgeResolutionV1) = merge(_up4_02a_resolution_body(x), (resolution_hash=x.resolution_hash,))
canonical_hash(x::EngineeringFeedbackBridgeResolutionV1) = begin
    expected = canonical_hash(_up4_02a_resolution_body(x))
    expected == x.resolution_hash || throw(ArgumentError("engineering feedback resolution hash mismatch"))
    expected
end

function _up4_02a_resolution(status, request_hash, failures; provider_gap=false,
        solver_gap=false, checker_gap=false)
    fs = Tuple(unique(Symbol.(failures)))
    body = (revision=UP4_02A_REVISION, status=status, accepted=false,
        claim_ceiling=UP4_02A_CLAIM_CEILING, engineering_credit=:none,
        physical_credit=:none, r01_r10_credit=:none, request_hash=request_hash,
        failures=fs, provider_gap=provider_gap, solver_gap=solver_gap,
        checker_gap=checker_gap, provider_calls=0, solver_calls=0, checker_calls=0)
    EngineeringFeedbackBridgeResolutionV1(status, false, UP4_02A_CLAIM_CEILING,
        :none, :none, :none, request_hash, fs, provider_gap, solver_gap,
        checker_gap, 0, 0, 0, canonical_hash(body))
end

"""Pure contract validation.  Provider/solver/checker gaps are independent."""
function validate_engineering_feedback_bridge(
        request::EngineeringFeedbackBridgeContractV1)
    request_hash = canonical_hash(request)
    b, r = request.binding, request.resources
    failures = Symbol[]
    push_failure!(x) = x in failures || push!(failures, x)
    all_refs = (r.source, r.coil, r.driver, r.return_ref, r.heat_sink, r.material,
        r.manufacturing, r.cooling, r.support, r.control_fault, r.control, r.provider,
        r.solver, r.checker)
    foreach(canonical_hash, all_refs)

    # Candidate/scenario projection is closed over every identity ref and all
    # four version axes.  Candidate/scenario themselves are checked by their
    # own projection hashes, not merely by status or a foreign ref pointer.
    identity_refs = (b.candidate, b.scenario, b.g1, b.g2, b.g3, b.parent, b.mission,
        b.physical_subject, b.axes.contract_axis, b.axes.schema_axis,
        b.axes.canonicalization_axis, b.axes.compatibility_axis)
    candidate_projection_hash = _up4_02a_identity_projection_hash(b.candidate)
    scenario_projection_hash = _up4_02a_identity_projection_hash(b.scenario)
    foreach(x -> begin
        if x.kind === :candidate
            x.status === :present || push_failure!(:candidate_hash_mismatch)
            x.candidate_hash == candidate_projection_hash || push_failure!(:candidate_hash_mismatch)
            x.scenario_hash == scenario_projection_hash || push_failure!(:scenario_reuse_mismatch)
        elseif x.kind === :scenario
            x.status === :present || push_failure!(:scenario_reuse_mismatch)
            x.candidate_hash == b.candidate.ref_hash || push_failure!(:candidate_hash_mismatch)
            x.scenario_hash == scenario_projection_hash || push_failure!(:scenario_reuse_mismatch)
        else
            x.candidate_hash == b.candidate.ref_hash || push_failure!(:candidate_hash_mismatch)
            x.scenario_hash == b.scenario.ref_hash || push_failure!(:scenario_reuse_mismatch)
        end
    end, identity_refs)
    b.g3.candidate_hash == b.candidate.ref_hash || push_failure!(:g3_hash_mismatch)
    b.axes.axes_hash == canonical_hash(b.axes) || push_failure!(:candidate_hash_mismatch)
    r.realization_plan_hash == b.realization_plan_hash || push_failure!(:realization_plan_hash_mismatch)
    r.control_plan_hash == b.control_plan_hash || push_failure!(:control_plan_hash_mismatch)
    r.manufacturing.content_hash == b.realization_plan_hash || push_failure!(:realization_plan_hash_mismatch)
    r.control.content_hash == b.control_plan_hash || push_failure!(:control_plan_hash_mismatch)
    r.control_fault.content_hash == b.control_plan_hash || push_failure!(:control_plan_hash_mismatch)

    # Resource slots are closed by a per-kind rule: direction, unit, owner
    # domain and identity.  Provider/solver/checker may be typed absent, but
    # their typed slots are never inferred or silently substituted.
    expected_kinds = Tuple(x.kind for x in _UP4_02A_RESOURCE_RULES)
    Tuple(x.kind for x in all_refs) == expected_kinds || push_failure!(:missing_link)
    rules = Dict(rule.kind => rule for rule in _UP4_02A_RESOURCE_RULES)
    all(x -> haskey(rules, x.kind), all_refs) || push_failure!(:missing_link)
    foreach(x -> begin
        x.candidate_hash == b.candidate.ref_hash || push_failure!(:candidate_hash_mismatch)
        x.scenario_hash == b.scenario.ref_hash || push_failure!(:scenario_reuse_mismatch)
        x.capacity >= 0 || push_failure!(:capacity_exceeded)
        rule = rules[x.kind]
        x.direction in rule.directions || push_failure!(:direction_mismatch)
        x.unit in rule.units || push_failure!(:unit_mismatch)
    end, all_refs)

    r.source.status === :present || push_failure!(:missing_source)
    r.return_ref.status === :present || push_failure!(:missing_return)
    r.heat_sink.status === :present || push_failure!(:missing_heat_sink)
    r.support.status === :present || push_failure!(:missing_support_boundary)
    r.material.status === :present || push_failure!(:unknown_material)
    r.material.status === :unknown && push_failure!(:unknown_material)
    r.source.direction === :passive && push_failure!(:passive_source)
    r.source.direction in (:in, :bidirectional) || push_failure!(:direction_mismatch)

    # Exactly one non-empty closure per ledger kind.  The supplied residual is
    # never trusted: recompute signed amount from every entry and reject a
    # forged zero or any duplicate/missing ledger.  Entry resource hashes make
    # source/return/heat-sink mapping explicit and auditable.
    kinds = Tuple(x.ledger_kind for x in request.ledgers)
    ledger_by_kind = Dict(l.ledger_kind => l for l in request.ledgers)
    length(request.ledgers) == length(_UP4_02A_LEDGER_KINDS) || push_failure!(:duplicate_ledger)
    foreach(k -> count(==(k), kinds) == 1 || push_failure!(:duplicate_ledger), _UP4_02A_LEDGER_KINDS)
    all_ids = [e.entry_id for l in request.ledgers for e in l.entries]
    length(all_ids) == length(unique(all_ids)) || push_failure!(:duplicate_ledger)
    foreach(l -> begin
        isempty(l.entries) && push_failure!(:empty_entry)
        canonical_hash(l)
        signed_total = sum((Int(e.sign) * e.amount for e in l.entries); init=0//1)
        nonzero_total = sum((abs(e.amount) for e in l.entries); init=0//1)
        nonzero_total > 0 || push_failure!(:empty_entry)
        l.actual_residual == signed_total && l.expected_residual == signed_total ||
            push_failure!(:forged_residual)
        all(e -> e.unit == l.unit, l.entries) || push_failure!(:unit_mismatch)
        all(e -> e.owner_scope == l.owner_scope, l.entries) || push_failure!(:owner_mismatch)
        all(e -> (e.sign > 0 && e.direction in (:in, :bidirectional)) ||
            (e.sign < 0 && e.direction in (:out, :bidirectional)) ||
            push_failure!(:direction_mismatch), l.entries)
    end, request.ledgers)
    required_mapping = ((:source, r.source.ref_hash, :missing_source),
        (:return, r.return_ref.ref_hash, :missing_return),
        (:heat_sink, r.heat_sink.ref_hash, :missing_heat_sink))
    foreach(required_mapping) do (role, ref_hash, missing_code)
        any(e -> e.role === role && e.resource_hash == ref_hash,
            (e for l in request.ledgers for e in l.entries)) || push_failure!(missing_code)
    end
    resource_hashes = Set(canonical_hash(x) for x in all_refs)
    ref_by_hash = Dict(canonical_hash(x) => x for x in all_refs)
    loads = Dict{Digest256,Rational{Int64}}(h => 0//1 for h in resource_hashes)
    foreach(e -> begin
        e.resource_hash in resource_hashes || push_failure!(:missing_link)
        e.resource_hash in keys(ref_by_hash) && e.unit == ref_by_hash[e.resource_hash].unit ||
            push_failure!(:unit_mismatch)
        loads[e.resource_hash] = get(loads, e.resource_hash, 0//1) + e.amount
    end, (e for l in request.ledgers for e in l.entries))
    foreach(x -> get(loads, canonical_hash(x), 0//1) <= x.capacity ||
        push_failure!(:capacity_exceeded), all_refs)

    # Every slot closes against its declared domain owner.  Referenced ledger
    # entries additionally close unit and owner against the exact resource.
    domain_owner = Dict{Symbol,String}(
        :feedback => r.control.owner_scope,
        :capability => r.provider.owner_scope)
    foreach(kind -> haskey(ledger_by_kind, kind) &&
        (domain_owner[kind] = ledger_by_kind[kind].owner_scope), _UP4_02A_LEDGER_KINDS)
    foreach(x -> begin
        rule = rules[x.kind]
        haskey(domain_owner, rule.domain) || push_failure!(:missing_link)
        haskey(domain_owner, rule.domain) &&
            x.owner_scope == domain_owner[rule.domain] || push_failure!(:owner_mismatch)
        referenced = any(e -> e.resource_hash == canonical_hash(x),
            (e for l in request.ledgers for e in l.entries))
        if referenced && rule.domain in _UP4_02A_LEDGER_KINDS && haskey(ledger_by_kind, rule.domain)
            ledger = ledger_by_kind[rule.domain]
            x.unit == ledger.unit || push_failure!(:unit_mismatch)
            x.owner_scope == ledger.owner_scope || push_failure!(:owner_mismatch)
        end
    end, all_refs)

    request.static_flux != 0 && request.emf != 0 &&
        !(request.time_derivative_declared || request.motion_declared || request.drive_declared) &&
        push_failure!(:static_flux_to_emf)

    isempty(request.feedback_targets) && push_failure!(:feedback_edge_removed)
    control_hashes = (r.control.ref_hash, r.control_fault.ref_hash)
    foreach(t -> begin
        canonical_hash(t)
        t.status === :present || push_failure!(:feedback_edge_removed)
        t.control_resource.ref_hash in control_hashes || begin
            push_failure!(:feedback_control_resource_link_mismatch)
            push_failure!(:missing_link)
        end
        t.control_resource.kind in (:control, :control_fault) || push_failure!(:feedback_control_resource_link_mismatch)
        t.control_resource.ref_hash == (t.control_resource.kind === :control ? r.control.ref_hash : r.control_fault.ref_hash) ||
            push_failure!(:feedback_control_resource_link_mismatch)
        t.candidate_hash == b.candidate.ref_hash || push_failure!(:candidate_hash_mismatch)
        t.g1_hash == b.g1.ref_hash || push_failure!(:g3_hash_mismatch)
        t.g2_hash == b.g2.ref_hash || push_failure!(:g3_hash_mismatch)
        t.g3_hash == b.g3.ref_hash || push_failure!(:g3_hash_mismatch)
        t.control_resource.candidate_hash == b.candidate.ref_hash || push_failure!(:candidate_hash_mismatch)
        t.control_resource.scenario_hash == b.scenario.ref_hash || push_failure!(:scenario_reuse_mismatch)
        t.owner_scope == t.control_resource.owner_scope || push_failure!(:owner_mismatch)
        t.unit == t.control_resource.unit || push_failure!(:unit_mismatch)
        t.direction == t.control_resource.direction || push_failure!(:direction_mismatch)
    end, request.feedback_targets)

    provider_gap = r.provider.status !== :present || r.provider.status === :unknown
    solver_gap = r.solver.status !== :present || r.solver.status === :unknown
    checker_gap = r.checker.status !== :present || r.checker.status === :unknown
    provider_gap && push!(failures, r.provider.status === :unknown ? :ambiguous_provider : :provider_dropout)
    solver_gap && push!(failures, :solver_capability_gap)
    checker_gap && push!(failures, :checker_capability_gap)
    if !isempty(failures)
        status = any(x -> x in (:provider_dropout, :ambiguous_provider, :solver_capability_gap, :checker_capability_gap), failures) &&
            all(x -> x in (:provider_dropout, :ambiguous_provider, :solver_capability_gap, :checker_capability_gap), unique(failures)) ?
            :terminal_deferred : :fail_closed
        return _up4_02a_resolution(status, request_hash, failures;
            provider_gap, solver_gap, checker_gap)
    end
    _up4_02a_resolution(:prepared, request_hash, (); provider_gap=false,
        solver_gap=false, checker_gap=false)
end

const validate_up4_02a_engineering_feedback_bridge = validate_engineering_feedback_bridge
const engineering_feedback_bridge_validation_v1 = validate_engineering_feedback_bridge
