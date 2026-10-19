"""Additive UP3 composition/solve admission contract.

This file is deliberately contract-only. It builds a deterministic typed plan
from candidate/subject/mission/scenario/provider/code/backend/protocol bindings,
ports, and ledger declarations. It never resolves a provider, constructs a
mesh, invokes a solver, or emits a numerical result.
"""

import FusionConceptAI: Digest256, canonical_hash, semantic_view

const CSP_SCHEMA_V1 = "fusionconceptai:composition-solve-plan-v1"
const _CSP_STATUSES = (:ready, :terminal_deferred, :fail_closed)
const _CSP_PRECLASSIFICATIONS = (:none, :singular, :nonconvergent)
const _CSP_SINGULAR_REASON = "singular_preclassified"
const _CSP_NONCONVERGENT_REASON = "nonconvergent_preclassified"
const _CSP_QUANTITIES = (:power, :current, :voltage, :heat, :material, :field)
const _CSP_DIRECTIONS = (:input, :output)
const _CSP_ROLES = (:source, :sink, :state, :return)
const _CSP_FAILURE_CODES = (:invalid_input, :duplicate_component, :duplicate_port,
    :provider_poisoning, :code_poisoning, :backend_poisoning, :protocol_mismatch,
    :direction_mismatch, :unmatched_port, :ambiguous_match, :cycle,
    :missing_ledger, :validation_mismatch)

_csp_text(x, field) = begin
    x isa AbstractString || throw(ArgumentError("$field must be a string"))
    s = String(x)
    isempty(strip(s)) && throw(ArgumentError("$field cannot be empty"))
    isvalid(s) || throw(ArgumentError("$field must be valid UTF-8"))
    s
end

_csp_digest_or_nothing(x, field) = begin
    x === nothing || x isa Digest256 || throw(ArgumentError("$field must be Digest256 or nothing"))
    x
end

struct CompositionSolveUnitV1
    quantity::Symbol
    exponents::NTuple{7,Int}
    function CompositionSolveUnitV1(quantity, exponents)
        quantity isa Symbol && quantity in _CSP_QUANTITIES ||
            throw(ArgumentError("invalid unit quantity"))
        raw = Tuple(exponents)
        length(raw) == 7 || throw(ArgumentError("unit requires seven exponents"))
        xs = ntuple(i -> Int(raw[i]), 7)
        new(quantity, xs)
    end
end

semantic_view(x::CompositionSolveUnitV1) =
    (quantity=x.quantity, exponents=x.exponents)

struct CompositionSolveSpaceV1
    space_ref::Digest256
    kind::Symbol
    dimension::Int
    chart_ref::Digest256
    function CompositionSolveSpaceV1(space_ref::Digest256, kind, dimension, chart_ref::Digest256)
        kind isa Symbol && kind in (:scalar, :vector, :tensor, :thermal, :circuit) ||
            throw(ArgumentError("invalid function-space kind"))
        d = Int(dimension)
        1 <= d <= 3 || throw(ArgumentError("space dimension must be 1..3"))
        new(space_ref, kind, d, chart_ref)
    end
end

semantic_view(x::CompositionSolveSpaceV1) =
    (space_ref=x.space_ref, kind=x.kind, dimension=x.dimension, chart_ref=x.chart_ref)

struct CompositionSolveBindingV1
    candidate_ref::Union{Nothing,Digest256}
    subject_ref::Union{Nothing,Digest256}
    mission_ref::Union{Nothing,Digest256}
    scenario_ref::Union{Nothing,Digest256}
    provider_ref::Union{Nothing,Digest256}
    code_ref::Union{Nothing,Digest256}
    backend_ref::Union{Nothing,Digest256}
    protocol_ref::Union{Nothing,Digest256}
    function CompositionSolveBindingV1(candidate_ref, subject_ref, mission_ref,
            scenario_ref, provider_ref, code_ref, backend_ref, protocol_ref)
        refs = (candidate_ref, subject_ref, mission_ref, scenario_ref,
            provider_ref, code_ref, backend_ref, protocol_ref)
        names = (:candidate_ref, :subject_ref, :mission_ref, :scenario_ref,
            :provider_ref, :code_ref, :backend_ref, :protocol_ref)
        for (ref, name) in zip(refs, names)
            _csp_digest_or_nothing(ref, name)
        end
        new(candidate_ref, subject_ref, mission_ref, scenario_ref,
            provider_ref, code_ref, backend_ref, protocol_ref)
    end
end

semantic_view(x::CompositionSolveBindingV1) =
    (candidate_ref=x.candidate_ref, subject_ref=x.subject_ref,
     mission_ref=x.mission_ref, scenario_ref=x.scenario_ref,
     provider_ref=x.provider_ref, code_ref=x.code_ref,
     backend_ref=x.backend_ref, protocol_ref=x.protocol_ref)

struct CompositionSolvePortV1
    label::String
    slot::Int
    direction::Symbol
    quantity::Symbol
    unit::CompositionSolveUnitV1
    space::CompositionSolveSpaceV1
    account::String
    owner::String
    ledger_sign::Int
    role::Symbol
    function CompositionSolvePortV1(label, slot, direction, quantity,
            unit::CompositionSolveUnitV1, space::CompositionSolveSpaceV1,
            account, owner, ledger_sign, role)
        name = _csp_text(label, "port label")
        s = Int(slot)
        s >= 1 || throw(ArgumentError("port slot must be positive"))
        direction isa Symbol && direction in _CSP_DIRECTIONS ||
            throw(ArgumentError("invalid port direction"))
        quantity isa Symbol && quantity in _CSP_QUANTITIES ||
            throw(ArgumentError("invalid port quantity"))
        account_text, owner_text = _csp_text(account, "ledger account"), _csp_text(owner, "ledger owner")
        sign = Int(ledger_sign)
        role isa Symbol && role in _CSP_ROLES || throw(ArgumentError("invalid ledger role"))
        role === :state ? sign == 0 : abs(sign) == 1 ||
            throw(ArgumentError("non-state ledger sign must be +/-1"))
        new(name, s, direction, quantity, unit, space, account_text, owner_text, sign, role)
    end
end

_csp_port_key(p::CompositionSolvePortV1) =
    (slot=p.slot, direction=p.direction, quantity=p.quantity, unit=semantic_view(p.unit),
     space=semantic_view(p.space), account=p.account, owner=p.owner,
     ledger_sign=p.ledger_sign, role=p.role)

"""Labels are diagnostics; slot locates a local endpoint, typed fields route edges."""
semantic_view(x::CompositionSolvePortV1) = _csp_port_key(x)

struct CompositionSolvePortValueV1
    component_ref::Digest256
    port::CompositionSolvePortV1
    payload::Any
    source_identity_hashes::Tuple
    payload_hash::Digest256
    function CompositionSolvePortValueV1(component_ref::Digest256,
            port::CompositionSolvePortV1, payload, source_identity_hashes)
        port.direction === :output ||
            throw(ArgumentError("composition port value must be an output port"))
        sources = Tuple(source_identity_hashes)
        !isempty(sources) && all(x -> x isa Digest256, sources) ||
            throw(ArgumentError("composition port value needs source identity hashes"))
        payload_hash = canonical_hash((payload=payload,
            source_identity_hashes=sources))
        new(component_ref, port, payload, sources, payload_hash)
    end
end

function _csp_validate_port_value(value::CompositionSolvePortValueV1,
        component_ref::Digest256, expected::CompositionSolvePortV1,
        source_identity_hashes::Tuple)
    value.component_ref == component_ref &&
        value.port.direction === :output &&
        semantic_view(value.port) == semantic_view(expected) &&
        value.source_identity_hashes == source_identity_hashes &&
        value.payload_hash == canonical_hash((payload=value.payload,
            source_identity_hashes=value.source_identity_hashes))
end

struct CompositionSolveComponentV1
    component_ref::Digest256
    provider_ref::Union{Nothing,Digest256}
    code_ref::Union{Nothing,Digest256}
    backend_ref::Union{Nothing,Digest256}
    inputs::Tuple
    outputs::Tuple
    function CompositionSolveComponentV1(component_ref::Digest256, provider_ref,
            code_ref, backend_ref, inputs, outputs)
        pr, cr, br = _csp_digest_or_nothing(provider_ref, "component provider_ref"),
            _csp_digest_or_nothing(code_ref, "component code_ref"),
            _csp_digest_or_nothing(backend_ref, "component backend_ref")
        ins, outs = Tuple(inputs), Tuple(outputs)
        all(p -> p isa CompositionSolvePortV1, ins) ||
            throw(ArgumentError("component inputs are not typed ports"))
        all(p -> p isa CompositionSolvePortV1, outs) ||
            throw(ArgumentError("component outputs are not typed ports"))
        new(component_ref, pr, cr, br, ins, outs)
    end
end

_csp_component_key(c::CompositionSolveComponentV1) =
    (component_ref=c.component_ref, provider_ref=c.provider_ref, code_ref=c.code_ref,
     backend_ref=c.backend_ref,
     inputs=Tuple(sort!([_csp_port_key(p) for p in c.inputs], by=string)),
     outputs=Tuple(sort!([_csp_port_key(p) for p in c.outputs], by=string)))
semantic_view(x::CompositionSolveComponentV1) = _csp_component_key(x)

struct CompositionSolveProtocolV1
    protocol_ref::Digest256
    max_iterations::Int
    residual_tolerance::Float64
    singular_policy::Symbol
    nonconvergent_policy::Symbol
    function CompositionSolveProtocolV1(protocol_ref::Digest256, max_iterations,
            residual_tolerance; singular_policy=:terminal_deferred,
            nonconvergent_policy=:terminal_deferred)
        it = Int(max_iterations)
        it > 0 || throw(ArgumentError("max_iterations must be positive"))
        tol = Float64(residual_tolerance)
        isfinite(tol) && tol > 0 || throw(ArgumentError("residual tolerance must be finite and positive"))
        singular_policy in (:terminal_deferred, :fail_closed) ||
            throw(ArgumentError("invalid singular policy"))
        nonconvergent_policy in (:terminal_deferred, :fail_closed) ||
            throw(ArgumentError("invalid nonconvergent policy"))
        new(protocol_ref, it, tol, singular_policy, nonconvergent_policy)
    end
end

semantic_view(x::CompositionSolveProtocolV1) =
    (protocol_ref=x.protocol_ref, max_iterations=x.max_iterations,
     residual_tolerance=x.residual_tolerance, singular_policy=x.singular_policy,
     nonconvergent_policy=x.nonconvergent_policy)

struct CompositionSolveEdgeV1
    producer_component::Digest256
    producer_slot::Int
    consumer_component::Digest256
    consumer_slot::Int
    transfer_hash::Digest256
end

semantic_view(x::CompositionSolveEdgeV1) =
    (producer_component=x.producer_component, producer_slot=x.producer_slot,
     consumer_component=x.consumer_component, consumer_slot=x.consumer_slot,
     transfer_hash=x.transfer_hash)

struct CompositionSolveProviderBindingV1
    component_ref::Digest256
    provider_ref::Digest256
    code_ref::Digest256
    backend_ref::Digest256
    source_identity_hashes::Tuple
    callback_kind::Symbol
    invoke::Function
    function CompositionSolveProviderBindingV1(component_ref::Digest256,
            provider_ref::Digest256, code_ref::Digest256, backend_ref::Digest256,
            source_identity_hashes, callback_kind, invoke::Function)
        sources = Tuple(source_identity_hashes)
        !isempty(sources) && all(x -> x isa Digest256, sources) ||
            throw(ArgumentError("composition provider binding needs source identity hashes"))
        callback_kind isa Symbol && callback_kind in (:provider, :solver) ||
            throw(ArgumentError("invalid composition callback kind"))
        new(component_ref, provider_ref, code_ref, backend_ref, sources,
            callback_kind, invoke)
    end
end

struct CompositionSolveFeedbackSeedV1
    feedback_edge::CompositionSolveEdgeV1
    seed_edge::CompositionSolveEdgeV1
    seed_value::CompositionSolvePortValueV1
    residual_scale::Float64
    residual_unit::CompositionSolveUnitV1
    residual_tolerance::Float64
    function CompositionSolveFeedbackSeedV1(feedback_edge::CompositionSolveEdgeV1,
            seed_edge::CompositionSolveEdgeV1,
            seed_value::CompositionSolvePortValueV1, residual_scale,
            residual_unit::CompositionSolveUnitV1, residual_tolerance)
        scale, tolerance = Float64(residual_scale), Float64(residual_tolerance)
        isfinite(scale) && scale > 0.0 ||
            throw(ArgumentError("composition feedback residual scale must be positive"))
        isfinite(tolerance) && tolerance > 0.0 ||
            throw(ArgumentError("composition feedback residual tolerance must be positive"))
        residual_unit.quantity === :heat &&
            residual_unit.exponents == (-1, 1, -3, 0, 0, 0, 0) ||
            throw(ArgumentError("composition feedback residual unit must be W/m^3"))
        new(feedback_edge, seed_edge, seed_value, scale, residual_unit, tolerance)
    end
end

struct CompositionSolveFailureV1
    code::Symbol
    path::String
    detail::String
    function CompositionSolveFailureV1(code, path, detail)
        code isa Symbol && code in _CSP_FAILURE_CODES || throw(ArgumentError("invalid solve failure code"))
        new(code, _csp_text(path, "failure path"), _csp_text(detail, "failure detail"))
    end
end

_csp_failure_path(path) = startswith(String(path), "label:") ? "port" : String(path)
_csp_failure_key(f::CompositionSolveFailureV1) =
    (code=f.code, path=_csp_failure_path(f.path), detail=f.detail)
semantic_view(x::CompositionSolveFailureV1) = _csp_failure_key(x)

struct CompositionSolveInputV1
    binding::CompositionSolveBindingV1
    components::Tuple
    protocol::Union{Nothing,CompositionSolveProtocolV1}
    preclassification::Symbol
    feedback_edge_keys::Tuple
    input_hash::Digest256
    function CompositionSolveInputV1(binding::CompositionSolveBindingV1, components,
            protocol::Union{Nothing,CompositionSolveProtocolV1}; preclassification=:none,
            feedback_edge_keys=())
        # Keep the validated Symbol itself.  The old short-circuit expression
        # assigned the Boolean result of `isa && in` to `pc`; a valid value
        # then reached the typed Symbol field as `true`.
        (preclassification isa Symbol && preclassification in _CSP_PRECLASSIFICATIONS) ||
            throw(ArgumentError("invalid numerical preclassification"))
        pc = preclassification
        raw_components = try
            Tuple(components)
        catch
            throw(ArgumentError("components must be an iterable of typed CompositionSolveComponentV1"))
        end
        all(c -> c isa CompositionSolveComponentV1, raw_components) ||
            throw(ArgumentError("components must be typed CompositionSolveComponentV1"))
        cs = Tuple(sort(collect(raw_components), by=c -> string(c.component_ref)))
        edge_keys = Tuple(feedback_edge_keys)
        all(k -> k isa Tuple && length(k) == 4 && k[1] isa Digest256 &&
            k[2] isa Integer && k[3] isa Digest256 && k[4] isa Integer, edge_keys) ||
            throw(ArgumentError("feedback_edge_keys must contain typed component/slot tuples"))
        length(unique(edge_keys)) == length(edge_keys) ||
            throw(ArgumentError("feedback_edge_keys contain duplicates"))
        body = (schema=CSP_SCHEMA_V1, binding=semantic_view(binding),
            components=Tuple(_csp_component_key(c) for c in cs),
            protocol=protocol === nothing ? nothing : semantic_view(protocol),
            preclassification=pc)
        !isempty(edge_keys) && (body = merge(body, (feedback_edge_keys=edge_keys,)))
        new(binding, cs, protocol, pc, edge_keys, canonical_hash(body))
    end
end

function semantic_view(x::CompositionSolveInputV1)
    body = (schema=CSP_SCHEMA_V1, binding=semantic_view(x.binding),
        components=Tuple(_csp_component_key(c) for c in x.components),
        protocol=x.protocol === nothing ? nothing : semantic_view(x.protocol),
        preclassification=x.preclassification)
    isempty(x.feedback_edge_keys) ? body :
        merge(body, (feedback_edge_keys=x.feedback_edge_keys,))
end

struct CompositionSolvePlanV1
    input::CompositionSolveInputV1
    edges::Tuple
    topological_order::Tuple
    unresolved::Tuple
    failures::Tuple
    deferred_reasons::Tuple
    status::Symbol
    provider_invocation_count::Int
    solver_invocation_count::Int
    plan_hash::Digest256
    function CompositionSolvePlanV1(input::CompositionSolveInputV1, edges, order,
            unresolved, failures, deferred_reasons, status,
            provider_invocation_count::Integer, solver_invocation_count::Integer)
        status in _CSP_STATUSES || throw(ArgumentError("invalid composition solve status"))
        provider_invocation_count == 0 && solver_invocation_count == 0 ||
            throw(ArgumentError("contract plan invocation counts must be zero"))
        es, os, us = Tuple(edges), Tuple(order), Tuple(unresolved)
        fs, ds = Tuple(failures), Tuple(deferred_reasons)
        all(e -> e isa CompositionSolveEdgeV1, es) || throw(ArgumentError("invalid solve edge"))
        all(r -> r isa Digest256, os) || throw(ArgumentError("invalid topological order"))
        all(f -> f isa CompositionSolveFailureV1, fs) || throw(ArgumentError("invalid solve failure"))
        body = (schema=CSP_SCHEMA_V1, input_hash=input.input_hash,
            edges=Tuple(semantic_view(e) for e in es), topological_order=os,
            unresolved=us, failures=Tuple(_csp_failure_key(f) for f in fs),
            deferred_reasons=ds, status=status,
            provider_invocation_count=0, solver_invocation_count=0)
        new(input, es, os, us, fs, ds, status, 0, 0, canonical_hash(body))
    end
end

function semantic_view(x::CompositionSolvePlanV1)
    (schema=CSP_SCHEMA_V1, input_hash=x.input.input_hash,
     edges=Tuple(semantic_view(e) for e in x.edges), topological_order=x.topological_order,
     unresolved=x.unresolved, failures=Tuple(_csp_failure_key(f) for f in x.failures),
     deferred_reasons=x.deferred_reasons, status=x.status,
     provider_invocation_count=x.provider_invocation_count,
     solver_invocation_count=x.solver_invocation_count)
end

struct CompositionSolveOutcomeV1
    status::Symbol
    code::Symbol
    reasons::Tuple
    input_hash::Digest256
    plan_hash::Union{Nothing,Digest256}
    provider_invocation_count::Int
    solver_invocation_count::Int
    result_hash::Digest256
    function CompositionSolveOutcomeV1(status, code, reasons, input_hash,
            plan_hash, provider_invocation_count, solver_invocation_count)
        status in _CSP_STATUSES || throw(ArgumentError("invalid outcome status"))
        code isa Symbol || throw(ArgumentError("outcome code must be Symbol"))
        plan_hash === nothing || plan_hash isa Digest256 || throw(ArgumentError("invalid plan hash"))
        provider_invocation_count == 0 && solver_invocation_count == 0 ||
            throw(ArgumentError("outcome invocation counts must be zero"))
        body = (schema=CSP_SCHEMA_V1, status=status, code=code,
            reasons=Tuple(String.(reasons)), input_hash=input_hash,
            plan_hash=plan_hash, provider_invocation_count=0, solver_invocation_count=0)
        new(status, code, Tuple(String.(reasons)), input_hash, plan_hash, 0, 0,
            canonical_hash(body))
    end
end

semantic_view(x::CompositionSolveOutcomeV1) =
    (schema=CSP_SCHEMA_V1, status=x.status, code=x.code, reasons=x.reasons,
     input_hash=x.input_hash, plan_hash=x.plan_hash,
     provider_invocation_count=0, solver_invocation_count=0)

# Receipt construction is intentionally split into the canonical outcome path
# and an explicitly named wire/deserialization path.  The latter exists only
# for adversarial-record tests: it is the sole route that can materialize raw
# fields without granting an ordinary positional constructor.
struct _CompositionSolveReceiptWireToken end
const _CSP_RECEIPT_WIRE_TOKEN = _CompositionSolveReceiptWireToken()

struct CompositionSolveReceiptV1
    input_hash::Digest256
    plan_hash::Union{Nothing,Digest256}
    result_hash::Digest256
    status::Symbol
    provider_invocation_count::Int
    solver_invocation_count::Int
    claim_ceiling::Symbol
    receipt_hash::Digest256
    function CompositionSolveReceiptV1(outcome::CompositionSolveOutcomeV1)
        body = (schema=CSP_SCHEMA_V1, input_hash=outcome.input_hash,
            plan_hash=outcome.plan_hash, result_hash=outcome.result_hash,
            status=outcome.status, provider_invocation_count=0,
            solver_invocation_count=0, claim_ceiling=:contract_only)
        new(outcome.input_hash, outcome.plan_hash, outcome.result_hash,
            outcome.status, 0, 0, :contract_only, canonical_hash(body))
    end

    function CompositionSolveReceiptV1(::_CompositionSolveReceiptWireToken,
            input_hash::Digest256, plan_hash::Union{Nothing,Digest256},
            result_hash::Digest256, status::Symbol,
            provider_invocation_count::Integer, solver_invocation_count::Integer,
            claim_ceiling::Symbol, receipt_hash::Digest256)
        new(input_hash, plan_hash, result_hash, status,
            Int(provider_invocation_count), Int(solver_invocation_count),
            claim_ceiling, receipt_hash)
    end
end

semantic_view(x::CompositionSolveReceiptV1) =
    (schema=CSP_SCHEMA_V1, input_hash=x.input_hash, plan_hash=x.plan_hash,
     result_hash=x.result_hash, status=x.status, provider_invocation_count=0,
     solver_invocation_count=0, claim_ceiling=x.claim_ceiling,
     receipt_hash=x.receipt_hash)

struct CompositionSolveAdmissionV1
    input::Union{Nothing,CompositionSolveInputV1}
    plan::Union{Nothing,CompositionSolvePlanV1}
    outcome::CompositionSolveOutcomeV1
    receipt::CompositionSolveReceiptV1
end

semantic_view(x::CompositionSolveAdmissionV1) =
    (input=x.input, plan=x.plan, outcome=x.outcome, receipt=x.receipt)

_csp_missing_binding(b::CompositionSolveBindingV1) = begin
    names = (:candidate_ref, :subject_ref, :mission_ref, :scenario_ref,
        :provider_ref, :code_ref, :backend_ref, :protocol_ref)
    Tuple(String(name) for (name, value) in zip(names,
        (b.candidate_ref, b.subject_ref, b.mission_ref, b.scenario_ref,
         b.provider_ref, b.code_ref, b.backend_ref, b.protocol_ref)) if value === nothing)
end

_csp_add_failure!(fs, code, path, detail) = push!(fs, CompositionSolveFailureV1(code, path, detail))

function _csp_port_for(c::CompositionSolveComponentV1, direction::Symbol, slot::Int)
    ports = direction === :input ? c.inputs : c.outputs
    matches = [p for p in ports if p.slot == slot]
    length(matches) == 1 ? only(matches) : nothing
end

function _csp_compatible(out::CompositionSolvePortV1, inp::CompositionSolvePortV1)
    # Slots belong to their respective components and are retained on the
    # edge; they are not global channel names.  Routing is therefore strict on
    # the complete typed contract, while a same-typed second producer remains
    # an ambiguity that must fail closed.
    out.direction === :output && inp.direction === :input &&
        out.quantity === inp.quantity && semantic_view(out.unit) == semantic_view(inp.unit) &&
        semantic_view(out.space) == semantic_view(inp.space)
end

function _csp_topological_order(components, edges, failures; excluded_edge_keys=())
    refs = Tuple(c.component_ref for c in components)
    incoming = Dict{Digest256,Int}(r => 0 for r in refs)
    outgoing = Dict{Digest256,Vector{Digest256}}(r => Digest256[] for r in refs)
    for edge in edges
        haskey(incoming, edge.producer_component) && haskey(incoming, edge.consumer_component) || begin
            _csp_add_failure!(failures, :cycle, "edges", "edge references unknown component")
            continue
        end
        producer = only(c for c in components if c.component_ref == edge.producer_component)
        consumer = only(c for c in components if c.component_ref == edge.consumer_component)
        out = _csp_port_for(producer, :output, edge.producer_slot)
        inp = _csp_port_for(consumer, :input, edge.consumer_slot)
        edge_key = (edge.producer_component, edge.producer_slot,
            edge.consumer_component, edge.consumer_slot)
        if edge_key in excluded_edge_keys
            out.role === :state && inp.role === :state || begin
                _csp_add_failure!(failures, :direction_mismatch,
                    "edges", "only declared state-to-state edges may be feedback")
                continue
            end
            continue
        end
        # Topology is component-level: parallel typed edges between the same
        # producer and consumer contribute one predecessor relation.  Keeping
        # the same deduplication rule for incoming and outgoing avoids a false
        # cycle when a MIMO pair carries multiple legal port edges.
        if !(edge.consumer_component in outgoing[edge.producer_component])
            incoming[edge.consumer_component] += 1
            push!(outgoing[edge.producer_component], edge.consumer_component)
        end
    end
    ready = sort!([r for r in refs if incoming[r] == 0], by=string)
    order = Digest256[]
    while !isempty(ready)
        current = popfirst!(ready)
        push!(order, current)
        for child in sort!(outgoing[current], by=string)
            incoming[child] -= 1
            incoming[child] == 0 && push!(ready, child)
        end
        sort!(ready, by=string)
    end
    length(order) == length(refs) || _csp_add_failure!(failures, :cycle,
        "topological_order", "composition graph contains a cycle")
    Tuple(order)
end

function _csp_feedback_scc_shape(edges, feedback_edge)
    a, b = feedback_edge.producer_component, feedback_edge.consumer_component
    a != b || throw(ArgumentError("self-feedback SCC is unsupported"))
    ordinary = Tuple(e for e in edges if e != feedback_edge)
    returns = Tuple(e for e in ordinary if
        e.producer_component == b && e.consumer_component == a)
    length(returns) == 1 ||
        throw(ArgumentError("unsupported composition feedback SCC shape"))
    from_b = Set((b,))
    to_a = Set((a,))
    changed = true
    while changed
        changed = false
        for edge in ordinary
            if edge.producer_component in from_b &&
                    !(edge.consumer_component in from_b)
                push!(from_b, edge.consumer_component)
                changed = true
            end
            if edge.consumer_component in to_a &&
                    !(edge.producer_component in to_a)
                push!(to_a, edge.producer_component)
                changed = true
            end
        end
    end
    intersect(from_b, to_a) == Set((a, b)) ||
        throw(ArgumentError("unsupported composition feedback SCC shape"))
    only(returns)
end

function _csp_build_plan(input::CompositionSolveInputV1)
    b = input.binding
    components = sort(collect(input.components), by=c -> string(c.component_ref))
    failures = CompositionSolveFailureV1[]
    deferred = String[]
    unresolved = String[]
    isempty(components) && _csp_add_failure!(failures, :invalid_input,
        "components", "composition requires at least one typed component")
    missing = _csp_missing_binding(b)
    append!(deferred, String["binding_missing:" * name for name in missing])
    input.protocol === nothing && push!(deferred, "protocol_missing")
    input.protocol !== nothing && b.protocol_ref !== nothing &&
        b.protocol_ref != input.protocol.protocol_ref &&
        _csp_add_failure!(failures, :protocol_mismatch, "binding.protocol_ref",
            "protocol identity differs from bound protocol")
    refs = [c.component_ref for c in components]
    length(unique(refs)) == length(refs) ||
        _csp_add_failure!(failures, :duplicate_component, "components", "component identity is duplicated")
    for c in components
        for (ports, direction) in ((c.inputs, :input), (c.outputs, :output))
            for p in ports
                p.direction === direction ||
                    _csp_add_failure!(failures, :direction_mismatch,
                        string("component:", c.component_ref, ":", direction,
                            ":slot:", p.slot),
                        string("port direction ", p.direction,
                            " does not match ", direction, " collection"))
            end
            slots = [p.slot for p in ports]
            length(unique(slots)) == length(slots) ||
                _csp_add_failure!(failures, :duplicate_port, string("component:", c.component_ref, ":", direction),
                    "port slot is duplicated")
        end
        c.provider_ref === nothing && push!(deferred, string("provider_missing:", c.component_ref))
        c.code_ref === nothing && push!(deferred, string("code_missing:", c.component_ref))
        c.backend_ref === nothing && push!(deferred, string("backend_missing:", c.component_ref))
        b.provider_ref !== nothing && c.provider_ref !== nothing && c.provider_ref != b.provider_ref &&
            _csp_add_failure!(failures, :provider_poisoning, string("component:", c.component_ref),
                "component provider differs from bound provider")
        b.code_ref !== nothing && c.code_ref !== nothing && c.code_ref != b.code_ref &&
            _csp_add_failure!(failures, :code_poisoning, string("component:", c.component_ref),
                "component code differs from bound code")
        b.backend_ref !== nothing && c.backend_ref !== nothing && c.backend_ref != b.backend_ref &&
            _csp_add_failure!(failures, :backend_poisoning, string("component:", c.component_ref),
                "component backend differs from bound backend")
    end
    ledger = Dict{Tuple{String,String},Int}()
    for c in components, p in (c.inputs..., c.outputs...)
        p.role === :state && continue
        key = (p.account, p.owner)
        ledger[key] = get(ledger, key, 0) + p.ledger_sign
    end
    for (key, total) in sort!(collect(ledger), by=string)
        total == 0 || _csp_add_failure!(failures, :missing_ledger,
            string("ledger:", key[1], "/", key[2]), "ledger does not close")
    end
    edges = CompositionSolveEdgeV1[]
    if isempty(failures)
        for consumer in components, inp in sort(collect(consumer.inputs), by=p -> p.slot)
            matches = Tuple((producer, out) for producer in components
                if producer.component_ref != consumer.component_ref
                for out in producer.outputs if _csp_compatible(out, inp))
            if isempty(matches)
                _csp_add_failure!(failures, :unmatched_port,
                    string("component:", consumer.component_ref, ":slot:", inp.slot),
                    "no compatible output matched the typed unit/space/direction")
            elseif length(matches) > 1
                _csp_add_failure!(failures, :ambiguous_match,
                    string("component:", consumer.component_ref, ":slot:", inp.slot),
                    "more than one compatible output matched")
            else
                producer, out = only(matches)
                if (out.role === :state) != (inp.role === :state)
                    _csp_add_failure!(failures, :direction_mismatch,
                        string("component:", consumer.component_ref, ":slot:", inp.slot),
                        "feedback edges require state-role output and input ports")
                    continue
                end
                push!(edges, CompositionSolveEdgeV1(producer.component_ref, out.slot,
                    consumer.component_ref, inp.slot,
                    canonical_hash((unit=semantic_view(out.unit), space=semantic_view(out.space),
                        direction=(out.direction, inp.direction)))))
            end
        end
    end
    edge_keys = Set((e.producer_component, e.producer_slot,
        e.consumer_component, e.consumer_slot) for e in edges)
    all(k -> k in edge_keys, input.feedback_edge_keys) ||
        _csp_add_failure!(failures, :validation_mismatch, "feedback_edge_keys",
            "a declared feedback edge is absent from the typed composition")
    declared_feedback = Set(input.feedback_edge_keys)
    length(declared_feedback) <= 1 ||
        _csp_add_failure!(failures, :cycle, "feedback_edge_keys",
            "only one declared feedback edge is supported")
    for edge in edges
        (edge.producer_component, edge.producer_slot,
            edge.consumer_component, edge.consumer_slot) in declared_feedback ||
            continue
        try
            out = _csp_port_for_component(components, edge.producer_component,
                :output, edge.producer_slot)
            inp = _csp_port_for_component(components, edge.consumer_component,
                :input, edge.consumer_slot)
            out.role === :state && inp.role === :state ||
                throw(ArgumentError("only state-to-state edges may be feedback"))
            _csp_feedback_scc_shape(edges, edge)
        catch err
            _csp_add_failure!(failures, :cycle, "feedback_edge_keys",
                string(typeof(err), ":", err))
        end
    end
    order = isempty(failures) ? _csp_topological_order(components, edges, failures;
        excluded_edge_keys=declared_feedback) : Digest256[]
    if input.preclassification !== :none
        push!(deferred, input.preclassification === :singular ? _CSP_SINGULAR_REASON : _CSP_NONCONVERGENT_REASON)
    end
    status = !isempty(failures) ? :fail_closed :
        (!isempty(deferred) ? :terminal_deferred : :ready)
    CompositionSolvePlanV1(input, edges, order, unresolved, failures, deferred,
        status, 0, 0)
end

function _csp_invalid_admission(input, detail)
    ih = canonical_hash((schema=CSP_SCHEMA_V1, invalid_input=string(typeof(input), ":", detail)))
    outcome = CompositionSolveOutcomeV1(:fail_closed, :invalid_input,
        (String(detail),), ih, nothing, 0, 0)
    CompositionSolveAdmissionV1(nothing, nothing, outcome, CompositionSolveReceiptV1(outcome))
end

function admit_composition_solve(input)
    input isa CompositionSolveInputV1 || return _csp_invalid_admission(input, "input is not typed CompositionSolveInputV1")
    all(c -> c isa CompositionSolveComponentV1, input.components) ||
        return _csp_invalid_admission(input, "malformed_component: components must be typed CompositionSolveComponentV1")
    try
        plan = _csp_build_plan(input)
        code = plan.status === :ready ? :ready :
            plan.status === :terminal_deferred ? :deferred : :structural_reject
        reasons = plan.status === :fail_closed ?
            Tuple(f.code for f in plan.failures) : plan.deferred_reasons
        outcome = CompositionSolveOutcomeV1(plan.status, code, reasons,
            input.input_hash, plan.plan_hash, 0, 0)
        CompositionSolveAdmissionV1(input, plan, outcome, CompositionSolveReceiptV1(outcome))
    catch err
        # Admission is a fail-closed boundary.  Malformed legacy/forged input
        # must not leak a MethodError, BoundsError, or other implementation
        # exception to callers.
        _csp_invalid_admission(input, string(typeof(err), ":", err))
    end
end

function validate_composition_solve_plan(plan)
    plan isa CompositionSolvePlanV1 || return nothing
    expected = _csp_build_plan(plan.input)
    drift = String[]
    Tuple(semantic_view(e) for e in plan.edges) == Tuple(semantic_view(e) for e in expected.edges) ||
        push!(drift, "edges")
    plan.topological_order == expected.topological_order || push!(drift, "topological_order")
    plan.unresolved == expected.unresolved || push!(drift, "unresolved")
    Tuple(_csp_failure_key(f) for f in plan.failures) ==
        Tuple(_csp_failure_key(f) for f in expected.failures) || push!(drift, "failures")
    plan.deferred_reasons == expected.deferred_reasons || push!(drift, "deferred_reasons")
    plan.status === expected.status || push!(drift, "status")
    plan.plan_hash == expected.plan_hash || push!(drift, "plan_hash")
    plan.provider_invocation_count == 0 && plan.solver_invocation_count == 0 ||
        push!(drift, "invocation_counts")
    isempty(drift) && return plan
    CompositionSolvePlanV1(plan.input, expected.edges, expected.topological_order,
        expected.unresolved, Tuple(vcat(collect(expected.failures),
            [CompositionSolveFailureV1(:validation_mismatch, "plan", join(sort!(drift), ","))])),
        expected.deferred_reasons, :fail_closed, 0, 0)
end

_csp_port_for_component(components, component_ref, direction, slot) =
    _csp_port_for(only(c for c in components if c.component_ref == component_ref),
        direction, slot)

function _csp_validate_execution_edges(plan::CompositionSolvePlanV1)
    components = plan.input.components
    for edge in plan.edges
        out = _csp_port_for_component(components, edge.producer_component,
            :output, edge.producer_slot)
        inp = _csp_port_for_component(components, edge.consumer_component,
            :input, edge.consumer_slot)
        (out === nothing || inp === nothing) &&
            throw(ArgumentError("composition edge endpoint slot is absent"))
        out.direction === :output && inp.direction === :input ||
            throw(ArgumentError("composition edge endpoint direction mismatch"))
        out.quantity === inp.quantity &&
            semantic_view(out.unit) == semantic_view(inp.unit) &&
            semantic_view(out.space) == semantic_view(inp.space) ||
            throw(ArgumentError("composition edge quantity, unit, or space mismatch"))
        out.account == inp.account && out.owner == inp.owner ||
            throw(ArgumentError("composition edge account or owner mismatch"))
        valid_ledger_role =
            (out.role === :source && inp.role === :sink &&
                out.ledger_sign == 1 && inp.ledger_sign == -1) ||
            (out.role === :state && inp.role === :state &&
                out.ledger_sign == 0 && inp.ledger_sign == 0)
        valid_ledger_role ||
            throw(ArgumentError("composition edge role or ledger sign mismatch"))
    end
    true
end

function _csp_feedback_edges(plan::CompositionSolvePlanV1)
    declared = Set(plan.input.feedback_edge_keys)
    Tuple(edge for edge in plan.edges if
        (edge.producer_component, edge.producer_slot,
            edge.consumer_component, edge.consumer_slot) in declared)
end

function _csp_binding_map(plan, bindings)
    raw = Tuple(bindings)
    all(x -> x isa CompositionSolveProviderBindingV1, raw) ||
        throw(ArgumentError("composition execution bindings are not typed"))
    length(raw) == length(plan.input.components) ||
        throw(ArgumentError("composition provider binding count differs from plan"))
    by_ref = Dict{Digest256,CompositionSolveProviderBindingV1}()
    for binding in raw
        haskey(by_ref, binding.component_ref) &&
            throw(ArgumentError("composition provider binding is duplicated"))
        component = only(c for c in plan.input.components
            if c.component_ref == binding.component_ref)
        binding.provider_ref == component.provider_ref &&
            binding.code_ref == component.code_ref &&
            binding.backend_ref == component.backend_ref ||
            throw(ArgumentError("composition runtime provider/code/backend identity mismatch"))
        by_ref[binding.component_ref] = binding
    end
    Set(keys(by_ref)) == Set(c.component_ref for c in plan.input.components) ||
        throw(ArgumentError("composition runtime provider binding is missing"))
    count(binding -> binding.callback_kind === :solver, values(by_ref)) == 1 ||
        throw(ArgumentError("composition runtime requires exactly one solver callback"))
    by_ref
end

function _csp_output_map(binding, component, returned)
    returned isa NamedTuple && hasproperty(returned, :outputs) &&
        hasproperty(returned, :result) ||
        throw(ArgumentError("composition callback must return outputs and result"))
    outputs = Tuple(returned.outputs)
    expected = Tuple(sort(collect(component.outputs), by=p -> p.slot))
    length(outputs) == length(expected) ||
        throw(ArgumentError("composition callback output count differs from component"))
    mapped = Dict{Int,CompositionSolvePortValueV1}()
    for value in outputs
        value isa CompositionSolvePortValueV1 ||
            throw(ArgumentError("composition callback output is not a typed port value"))
        haskey(mapped, value.port.slot) &&
            throw(ArgumentError("composition callback output slot is duplicated"))
        _csp_validate_port_value(value, component.component_ref,
            _csp_port_for(component, :output, value.port.slot),
            binding.source_identity_hashes) ||
            throw(ArgumentError("composition callback output identity or payload hash mismatch"))
        mapped[value.port.slot] = value
    end
    Set(keys(mapped)) == Set(p.slot for p in expected) ||
        throw(ArgumentError("composition callback output slots differ from plan"))
    (outputs=mapped, result=returned.result)
end

function _csp_feedback_scalar(payload)
    value = payload isa Number ? payload :
        hasproperty(payload, :q_W_m3) ? getproperty(payload, :q_W_m3) :
        throw(ArgumentError("feedback payload must be a scalar or expose q_W_m3"))
    q = Float64(value)
    isfinite(q) || throw(ArgumentError("feedback scalar is nonfinite"))
    q
end

function _csp_numeric_route_value(payload)
    value = payload isa Number ? payload :
        hasproperty(payload, :q_W_m3) ? getproperty(payload, :q_W_m3) : payload
    if value isa Real
        x = Float64(value)
        return isfinite(x) ? x : nothing
    elseif value isa AbstractArray{<:Real}
        xs = Tuple(Float64.(vec(value)))
        return all(isfinite, xs) ? xs : nothing
    end
    nothing
end

function _csp_route_balance(outport, inport, value)
    numeric = _csp_numeric_route_value(value.payload)
    numeric === nothing && return (numeric_value=nothing,
        signed_balance=nothing, absolute_error=nothing,
        status=:payload_identity_only)
    if numeric isa Real
        balance = outport.ledger_sign * numeric + inport.ledger_sign * numeric
        error = abs(balance)
        return (numeric_value=numeric, signed_balance=balance,
            absolute_error=error,
            status=error <= 8eps(max(abs(numeric), 1.0)) ? :transfer_accounted : :failed)
    end
    balance = Tuple(outport.ledger_sign * x + inport.ledger_sign * x for x in numeric)
    error = isempty(balance) ? 0.0 : maximum(abs, balance)
    scale = isempty(numeric) ? 1.0 : max(maximum(abs, numeric), 1.0)
    (numeric_value=numeric, signed_balance=balance, absolute_error=error,
        status=error <= 8eps(scale) ? :transfer_accounted : :failed)
end

function _csp_scc_for_feedback(plan, feedback_edge)
    # Admission and execution share the same exact two-node SCC check.
    a, b = feedback_edge.producer_component, feedback_edge.consumer_component
    return_edge = _csp_feedback_scc_shape(plan.edges, feedback_edge)
    (provider=a, solver=b, return_edge=return_edge)
end

function _csp_validate_feedback_seed(plan, bindings, seed, feedback_edge)
    seed isa CompositionSolveFeedbackSeedV1 ||
        throw(ArgumentError("composition feedback seed is not typed"))
    seed.feedback_edge == feedback_edge ||
        throw(ArgumentError("composition feedback seed targets another edge"))
    seed.seed_edge in plan.edges ||
        throw(ArgumentError("composition feedback seed source edge is absent"))
    seed.seed_edge.consumer_component == feedback_edge.consumer_component ||
        throw(ArgumentError("composition feedback seed must enter the same solver component"))
    seed_output = _csp_port_for_component(plan.input.components,
        seed.seed_edge.producer_component, :output, seed.seed_edge.producer_slot)
    seed_input = _csp_port_for_component(plan.input.components,
        seed.seed_edge.consumer_component, :input, seed.seed_edge.consumer_slot)
    _csp_validate_port_value(seed.seed_value, seed.seed_edge.producer_component,
        seed_output, bindings[seed.seed_edge.producer_component].source_identity_hashes) ||
        throw(ArgumentError("composition feedback seed source identity mismatch"))
    semantic_view(seed.seed_value.port) == semantic_view(seed_output) ||
        throw(ArgumentError("composition feedback seed owner/account/slot mismatch"))
    seed_input.quantity === seed_output.quantity &&
        semantic_view(seed_input.unit) == semantic_view(seed_output.unit) &&
        semantic_view(seed_input.space) == semantic_view(seed_output.space) ||
        throw(ArgumentError("composition feedback seed edge type mismatch"))
    feedback_input = _csp_port_for_component(plan.input.components,
        feedback_edge.consumer_component, :input, feedback_edge.consumer_slot)
    feedback_output = _csp_port_for_component(plan.input.components,
        feedback_edge.producer_component, :output, feedback_edge.producer_slot)
    feedback_input.role === :state && feedback_output.role === :state &&
        feedback_input.ledger_sign == feedback_output.ledger_sign == 0 &&
        feedback_input.account == feedback_output.account &&
        feedback_input.owner == feedback_output.owner ||
        throw(ArgumentError("composition feedback endpoint role, ledger, account, or owner mismatch"))
    seed_output.account == seed_input.account &&
        seed_output.owner == seed_input.owner &&
        seed_output.role === :source && seed_input.role === :sink &&
        seed_output.ledger_sign == 1 && seed_input.ledger_sign == -1 ||
        throw(ArgumentError("composition feedback seed edge role, ledger, account, or owner mismatch"))
    # The G1 seed is a scalar q0 anchor while the feedback endpoint is the
    # solver's spatial q state.  Their spaces may differ, but the seed edge
    # itself was already checked for exact endpoint space/account/owner/role/sign.
    seed_input.quantity === feedback_input.quantity === feedback_output.quantity &&
        semantic_view(seed_input.unit) == semantic_view(feedback_input.unit) ==
            semantic_view(feedback_output.unit) ||
        throw(ArgumentError("composition feedback seed quantity or unit mismatch"))
    feedback_input.unit.quantity === :heat &&
        feedback_input.unit.exponents == (-1, 1, -3, 0, 0, 0, 0) &&
        semantic_view(seed.residual_unit) == semantic_view(feedback_input.unit) ||
        throw(ArgumentError("composition feedback residual unit must be W/m^3"))
    seed.residual_scale > 0.0 && seed.residual_tolerance > 0.0 ||
        throw(ArgumentError("composition feedback residual scale or tolerance invalid"))
    seed.residual_tolerance == plan.input.protocol.residual_tolerance ||
        throw(ArgumentError("composition feedback tolerance differs from bound protocol"))
    true
end

"""Execute a ready typed plan through source-bound runtime provider callbacks.

The original admission plan and receipt stay contract-only. This caller-owned
runtime resolves declared edge values by component and slot, validates the
thermal adapter's endpoint ledger semantics, and supports one explicit
two-component state-feedback SCC with a typed seed and unit-bearing residual
scale/tolerance. Provider code/backend digests are caller-supplied metadata;
they do not authenticate callback implementations.
"""
function execute_composition_solve_v1(admission::CompositionSolveAdmissionV1,
        provider_bindings; feedback_seeds=())
    trace_enabled = get(ENV, "UP3_COMPOSITION_TRACE", "") == "1"
    input = admission.input
    plan = admission.plan
    input isa CompositionSolveInputV1 &&
        plan isa CompositionSolvePlanV1 &&
        admission.outcome.status === :ready &&
        validate_composition_solve_plan(plan) === plan ||
        return (status=:fail_closed, result=nothing, resolved_edge_values=(),
            provider_callback_count=0, solver_callback_count=0,
            feedback_trace=(), routed_value_audit=(), failure_code=:admission_invalid,
            failure_detail="composition admission is not a validated ready plan")
    try
        _csp_validate_execution_edges(plan)
    catch err
        return (status=:fail_closed, result=nothing, resolved_edge_values=(),
            provider_callback_count=0, solver_callback_count=0,
            feedback_trace=(), routed_value_audit=(), failure_code=:edge_contract_invalid,
            failure_detail=sprint(showerror, err))
    end
    bindings = try
        _csp_binding_map(plan, provider_bindings)
    catch err
        return (status=:fail_closed, result=nothing, resolved_edge_values=(),
            provider_callback_count=0, solver_callback_count=0,
            feedback_trace=(), routed_value_audit=(), failure_code=:binding_invalid,
            failure_detail=sprint(showerror, err))
    end
    feedback_edges = _csp_feedback_edges(plan)
    length(feedback_edges) <= 1 ||
        return (status=:fail_closed, result=nothing, resolved_edge_values=(),
            provider_callback_count=0, solver_callback_count=0,
            feedback_trace=(), routed_value_audit=(), failure_code=:unsupported_feedback_shape,
            failure_detail="only one feedback edge is supported")
    seeds = Tuple(feedback_seeds)
    length(seeds) == length(feedback_edges) ||
        return (status=:fail_closed, result=nothing, resolved_edge_values=(),
            provider_callback_count=0, solver_callback_count=0,
            feedback_trace=(), routed_value_audit=(), failure_code=:feedback_seed_missing,
            failure_detail="feedback seed count differs from feedback edge count")
    seed_by_edge = Dict{CompositionSolveEdgeV1,CompositionSolveFeedbackSeedV1}()
    try
        for (edge, seed) in zip(feedback_edges, seeds)
            _csp_validate_feedback_seed(plan, bindings, seed, edge)
            haskey(seed_by_edge, edge) &&
                throw(ArgumentError("duplicate composition feedback seed"))
            seed_by_edge[edge] = seed
        end
    catch err
        return (status=:fail_closed, result=nothing, resolved_edge_values=(),
            provider_callback_count=0, solver_callback_count=0,
            feedback_trace=(), routed_value_audit=(), failure_code=:feedback_seed_invalid,
            failure_detail=sprint(showerror, err))
    end

    scc = isempty(feedback_edges) ? nothing : try
        _csp_scc_for_feedback(plan, only(feedback_edges))
    catch err
        return (status=:fail_closed, result=nothing, resolved_edge_values=(),
            provider_callback_count=0, solver_callback_count=0,
            feedback_trace=(), routed_value_audit=(), failure_code=:unsupported_feedback_shape,
            failure_detail=sprint(showerror, err))
    end
    feedback_edge = isempty(feedback_edges) ? nothing : only(feedback_edges)
    seed = isempty(seeds) ? nothing : only(seeds)
    source_components = plan.input.components
    outputs_by_component = Dict{Digest256,Dict{Int,CompositionSolvePortValueV1}}()
    callback_results = Dict{Digest256,Any}()
    resolved = Dict{CompositionSolveEdgeV1,CompositionSolvePortValueV1}()
    provider_calls = 0
    solver_calls = 0
    feedback_trace = NamedTuple[]
    routed_value_audit = NamedTuple[]
    callback_sequence = 0
    function incoming(component_ref; allow_seed=false)
        component = only(c for c in source_components if c.component_ref == component_ref)
        values = Dict{Int,CompositionSolvePortValueV1}()
        for edge in plan.edges
            edge.consumer_component == component_ref || continue
            if edge == feedback_edge
                if haskey(resolved, edge)
                    values[edge.consumer_slot] = resolved[edge]
                elseif allow_seed
                    values[edge.consumer_slot] = seed.seed_value
                else
                    continue
                end
            else
                if !haskey(resolved, edge) && allow_seed &&
                    scc !== nothing && edge == scc.return_edge
                continue
            end
            haskey(resolved, edge) ||
                    throw(ArgumentError("composition input edge was not resolved in execution order"))
            values[edge.consumer_slot] = resolved[edge]
            end
        end
        component = only(c for c in source_components if c.component_ref == component_ref)
        for edge in plan.edges
            edge.consumer_component == component_ref || continue
            haskey(values, edge.consumer_slot) || continue
            value = values[edge.consumer_slot]
            outport = _csp_port_for_component(source_components,
                edge.producer_component, :output, edge.producer_slot)
            inport = _csp_port_for_component(source_components,
                edge.consumer_component, :input, edge.consumer_slot)
            _csp_validate_port_value(value, edge.producer_component, outport,
                bindings[edge.producer_component].source_identity_hashes) ||
                throw(ArgumentError("composition routed value identity or payload hash mismatch"))
            semantic_view(inport) == semantic_view(_csp_port_for(component,
                :input, edge.consumer_slot)) ||
                throw(ArgumentError("composition routed consumer slot mismatch"))
            balance = _csp_route_balance(outport, inport, value)
            balance.status in (:transfer_accounted, :payload_identity_only) ||
                throw(ArgumentError("composition routed numeric balance failed"))
            push!(routed_value_audit, (edge=edge,
                producer_slot=edge.producer_slot, consumer_slot=edge.consumer_slot,
                quantity=outport.quantity, unit=semantic_view(outport.unit),
                account=outport.account, owner=outport.owner,
                producer_ledger_sign=outport.ledger_sign,
                consumer_ledger_sign=inport.ledger_sign,
                payload_hash=value.payload_hash,
                audit_scope=:edge_transfer_accounting,
                numeric_value=balance.numeric_value,
                signed_balance=balance.signed_balance,
                absolute_error=balance.absolute_error, status=balance.status))
        end
        values
    end
    function invoke_component(component_ref; allow_seed=false)
        component = only(c for c in source_components if c.component_ref == component_ref)
        binding = bindings[component_ref]
        if trace_enabled
            callback_sequence += 1
            callback_id = string(component_ref)
            input_started_ns = time_ns()
            println("UP3_TRACE_INPUT_BEGIN seq=", callback_sequence,
                " kind=", binding.callback_kind, " component=", callback_id)
            flush(stdout)
        end
        inputs = incoming(component_ref; allow_seed=allow_seed)
        if trace_enabled
            println("UP3_TRACE_INPUT_END seq=", callback_sequence,
                " kind=", binding.callback_kind, " component=", callback_id,
                " elapsed_ns=", time_ns() - input_started_ns)
            flush(stdout)
        end
        # Count the actual callback attempt, including callbacks that throw or
        # return malformed output.  Input-resolution failures above do not
        # count because the callback was never invoked.
        binding.callback_kind === :solver ? (solver_calls += 1) : (provider_calls += 1)
        if trace_enabled
            println("UP3_TRACE_CALLBACK_BEGIN seq=", callback_sequence,
                " kind=", binding.callback_kind, " component=", callback_id,
                " solver_calls=", solver_calls, " provider_calls=", provider_calls)
            flush(stdout)
        end
        callback_started_ns = trace_enabled ? time_ns() : 0
        returned = binding.invoke(inputs)
        if trace_enabled
            println("UP3_TRACE_CALLBACK_END seq=", callback_sequence,
                " kind=", binding.callback_kind, " component=", callback_id,
                " elapsed_ns=", time_ns() - callback_started_ns)
            flush(stdout)
        end
        validation_started_ns = trace_enabled ? time_ns() : 0
        if trace_enabled
            println("UP3_TRACE_OUTPUT_VALIDATION_BEGIN seq=", callback_sequence,
                " kind=", binding.callback_kind, " component=", callback_id)
            flush(stdout)
        end
        output = _csp_output_map(binding, component, returned)
        if trace_enabled
            println("UP3_TRACE_OUTPUT_VALIDATION_END seq=", callback_sequence,
                " kind=", binding.callback_kind, " component=", callback_id,
                " elapsed_ns=", time_ns() - validation_started_ns)
            flush(stdout)
        end
        outputs_by_component[component_ref] = output.outputs
        callback_results[component_ref] = output.result
        for edge in plan.edges
            edge.producer_component == component_ref || continue
            value = output.outputs[edge.producer_slot]
            # Feedback edges replace the latest edge value each iteration.
            resolved[edge] = value
        end
        output
    end

    try
        if scc === nothing
            for component_ref in plan.topological_order
                invoke_component(component_ref)
            end
        else
            feedback_seed_value = seed.seed_value
            # Bootstrap only from the declared source edge.  The SCC provider
            # must provide the same source-law value before the first solver call.
            for component_ref in plan.topological_order
                component_ref in (scc.provider, scc.solver) && continue
                invoke_component(component_ref)
            end
            provider_boot = invoke_component(scc.provider; allow_seed=true)
            q_applied = _csp_feedback_scalar(
                provider_boot.outputs[feedback_edge.producer_slot].payload)
            seed_q = _csp_feedback_scalar(feedback_seed_value.payload)
            isapprox(q_applied, seed_q; atol=8eps(max(abs(seed_q), 1.0)), rtol=0.0) ||
                throw(ArgumentError("feedback provider bootstrap differs from typed q seed"))
            # First solver evaluation uses q0.  Each subsequent provider output
            # is compared with the q actually applied by the previous solve.
            solver_result = invoke_component(scc.solver)
            converged = false
            for iteration in 1:input.protocol.max_iterations
                provider_result = invoke_component(scc.provider)
                q_next = _csp_feedback_scalar(
                    provider_result.outputs[feedback_edge.producer_slot].payload)
                residual_raw = abs(q_next - q_applied)
                residual = residual_raw / seed.residual_scale
                isfinite(residual) ||
                    throw(ArgumentError("composition feedback residual is nonfinite"))
                temperature_K = hasproperty(provider_result.result, :temperature_K) ?
                    Float64(provider_result.result.temperature_K) : nothing
                push!(feedback_trace, (iteration=iteration,
                    applied=q_applied, next=q_next, residual_raw=residual_raw,
                    residual=residual, unit=:W_m3, temperature_K=temperature_K,
                    provider_result=provider_result.result,
                    solver_result=solver_result.result,
                    provider_result_hash=canonical_hash(provider_result.result),
                    solver_result_hash=canonical_hash(solver_result.result)))
                if residual <= seed.residual_tolerance
                    converged = true
                    break
                end
                iteration < input.protocol.max_iterations || break
                q_applied = q_next
                solver_result = invoke_component(scc.solver)
            end
        end
    catch err
        return (status=:fail_closed, result=nothing,
            resolved_edge_values=Tuple((edge=edge, value=value)
                for (edge, value) in sort!(collect(resolved), by=x -> string(x.first))),
            provider_callback_count=provider_calls,
            solver_callback_count=solver_calls, feedback_trace=Tuple(feedback_trace),
            routed_value_audit=Tuple(routed_value_audit),
            failure_code=:runtime_callback_failed,
            failure_detail=sprint(showerror, err))
    end
    final_solver = if scc === nothing
        only((callback_results[c.component_ref] for c in source_components
            if bindings[c.component_ref].callback_kind === :solver))
    else
        callback_results[scc.solver]
    end
    status = isempty(feedback_edges) ? :executed :
        !isempty(feedback_trace) &&
        last(feedback_trace).residual <= seed.residual_tolerance ? :executed :
        input.protocol.nonconvergent_policy === :fail_closed ? :fail_closed :
        :terminal_deferred
    (status=status, result=final_solver,
     resolved_edge_values=Tuple((edge=edge, value=value)
        for (edge, value) in sort!(collect(resolved), by=x -> string(x.first))),
     provider_callback_count=provider_calls, solver_callback_count=solver_calls,
     feedback_trace=Tuple(feedback_trace),
     routed_value_audit=Tuple(routed_value_audit),
     failure_code=status === :executed ? :none : :feedback_nonconvergent,
     failure_detail=status === :executed ? "" : "feedback residual exceeded tolerance")
end

"""One bounded, typed subset of a component pool; no numerical work is implied."""
struct CompositionSolveEnumerationCaseV1
    admission::CompositionSolveAdmissionV1
    partition::Symbol
    reason::Symbol
end

struct CompositionSolveEnumerationV1
    cases::Tuple
    build::Tuple
    holdout::Tuple
    status::Symbol
    split_hash::Digest256
    claim_ceiling::Symbol
end

function _csp_connected(plan::CompositionSolvePlanV1)
    refs = Set(c.component_ref for c in plan.input.components)
    isempty(refs) && return false
    neighbors = Dict(r => Set{Digest256}() for r in refs)
    for edge in plan.edges
        push!(neighbors[edge.producer_component], edge.consumer_component)
        push!(neighbors[edge.consumer_component], edge.producer_component)
    end
    seen = Set{Digest256}()
    stack = [first(refs)]
    while !isempty(stack)
        ref = pop!(stack)
        ref in seen && continue
        push!(seen, ref)
        append!(stack, neighbors[ref])
    end
    seen == refs
end

"""Enumerate typed connected combinations and reserve a deterministic contract-only holdout.

The split is a preparation aid. A different reviewer must freeze an unseen
combination and replay it through the future UP2-05 residual/provider/solver
consumer before UP3-02 can claim acceptance.
"""
function enumerate_composition_solve(binding::CompositionSolveBindingV1,
        component_pool, protocol::Union{Nothing,CompositionSolveProtocolV1};
        min_components::Integer=2, max_components::Integer=length(component_pool),
        holdout_count::Integer=1, split_ref::Digest256)
    pool = Tuple(component_pool)
    all(c -> c isa CompositionSolveComponentV1, pool) ||
        throw(ArgumentError("component pool must contain typed components"))
    n = length(pool)
    2 <= n <= 12 || throw(ArgumentError("component pool size must be 2..12"))
    length(unique(c.component_ref for c in pool)) == n ||
        throw(ArgumentError("component pool contains duplicate identities"))
    2 <= min_components <= max_components <= n ||
        throw(ArgumentError("invalid combination size range"))
    holdout_count >= 0 || throw(ArgumentError("holdout_count must be nonnegative"))
    sorted_pool = sort!(collect(pool), by=c -> string(c.component_ref))
    admissions = CompositionSolveAdmissionV1[]
    reasons = Symbol[]
    chosen = CompositionSolveComponentV1[]
    function visit(next::Int)
        if min_components <= length(chosen) <= max_components
            admission = admit_composition_solve(CompositionSolveInputV1(
                binding, Tuple(chosen), protocol))
            push!(admissions, admission)
            push!(reasons, admission.outcome.status === :fail_closed ?
                :structural_reject : _csp_connected(admission.plan) ?
                :typed_legal : :disconnected)
        end
        length(chosen) == max_components && return
        for i in next:n
            push!(chosen, sorted_pool[i])
            visit(i + 1)
            pop!(chosen)
        end
    end
    visit(1)
    legal = [i for i in eachindex(admissions) if reasons[i] === :typed_legal]
    # Split on canonical input identity, never display labels or component order.
    sort!(legal, by=i -> (string(canonical_hash((split_ref=split_ref,
        input_hash=admissions[i].outcome.input_hash))),
        string(admissions[i].outcome.input_hash)))
    enough = length(legal) > holdout_count
    reserved = enough && holdout_count > 0 ? Set(legal[1:holdout_count]) : Set{Int}()
    cases = Tuple(CompositionSolveEnumerationCaseV1(admissions[i],
        reasons[i] !== :typed_legal ? :rejected : i in reserved ? :holdout : :build,
        reasons[i]) for i in eachindex(admissions))
    build = Tuple(c.admission for c in cases if c.partition === :build)
    holdout = Tuple(c.admission for c in cases if c.partition === :holdout)
    status = enough ? :prepared : :insufficient_legal_combinations
    split_hash = canonical_hash((schema=CSP_SCHEMA_V1, split_ref=split_ref,
        pool=Tuple(_csp_component_key(c) for c in sorted_pool),
        build=Tuple(a.outcome.input_hash for a in build),
        holdout=Tuple(a.outcome.input_hash for a in holdout), status=status))
    CompositionSolveEnumerationV1(cases, build, holdout, status,
        split_hash, :contract_only)
end

"""Select a build-only, structurally ready plan by canonical input identity.

This does not grant execution or physics credit. A held-out, rejected, or
deferred case is deliberately unavailable to a build consumer.
"""
function select_composition_solve(enumeration::CompositionSolveEnumerationV1,
        input_hash::Digest256)
    matches = [a for a in enumeration.build if
        a.outcome.input_hash == input_hash && a.outcome.status === :ready]
    length(matches) == 1 ? only(matches) : nothing
end

function composition_solve_receipt(admission::CompositionSolveAdmissionV1)
    admission.receipt
end

"""Materialize an untrusted wire receipt for adversarial validation tests.

This is deliberately named and token-gated; production construction remains
`CompositionSolveReceiptV1(outcome::CompositionSolveOutcomeV1)`.
"""
function composition_solve_receipt_from_wire(input_hash::Digest256,
        plan_hash::Union{Nothing,Digest256}, result_hash::Digest256,
        status::Symbol, provider_invocation_count::Integer,
        solver_invocation_count::Integer, claim_ceiling::Symbol,
        receipt_hash::Digest256)
    CompositionSolveReceiptV1(_CSP_RECEIPT_WIRE_TOKEN, input_hash, plan_hash,
        result_hash, status, provider_invocation_count, solver_invocation_count,
        claim_ceiling, receipt_hash)
end

# Keep the raw/deserialization seam explicit for callers that describe the
# transport layer by either name; neither alias opens a positional constructor.
raw_composition_solve_receipt(args...) = composition_solve_receipt_from_wire(args...)
deserialize_composition_solve_receipt(args...) = composition_solve_receipt_from_wire(args...)

function validate_composition_solve_receipt(receipt)
    receipt isa CompositionSolveReceiptV1 || return false
    receipt.status in _CSP_STATUSES || return false
    receipt.claim_ceiling === :contract_only || return false
    body = (schema=CSP_SCHEMA_V1, input_hash=receipt.input_hash,
        plan_hash=receipt.plan_hash, result_hash=receipt.result_hash,
        status=receipt.status, provider_invocation_count=0,
        solver_invocation_count=0, claim_ceiling=:contract_only)
    receipt.receipt_hash == canonical_hash(body) &&
        receipt.provider_invocation_count == 0 && receipt.solver_invocation_count == 0
end
