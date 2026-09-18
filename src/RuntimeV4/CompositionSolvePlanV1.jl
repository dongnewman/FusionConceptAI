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
    input_hash::Digest256
    function CompositionSolveInputV1(binding::CompositionSolveBindingV1, components,
            protocol::Union{Nothing,CompositionSolveProtocolV1}; preclassification=:none)
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
        body = (schema=CSP_SCHEMA_V1, binding=semantic_view(binding),
            components=Tuple(_csp_component_key(c) for c in cs),
            protocol=protocol === nothing ? nothing : semantic_view(protocol),
            preclassification=pc)
        new(binding, cs, protocol, pc, canonical_hash(body))
    end
end

semantic_view(x::CompositionSolveInputV1) =
    (schema=CSP_SCHEMA_V1, binding=semantic_view(x.binding),
     components=Tuple(_csp_component_key(c) for c in x.components),
     protocol=x.protocol === nothing ? nothing : semantic_view(x.protocol),
     preclassification=x.preclassification)

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

function _csp_topological_order(components, edges, failures)
    refs = Tuple(c.component_ref for c in components)
    incoming = Dict{Digest256,Int}(r => 0 for r in refs)
    outgoing = Dict{Digest256,Vector{Digest256}}(r => Digest256[] for r in refs)
    for edge in edges
        haskey(incoming, edge.producer_component) && haskey(incoming, edge.consumer_component) || begin
            _csp_add_failure!(failures, :cycle, "edges", "edge references unknown component")
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
                push!(edges, CompositionSolveEdgeV1(producer.component_ref, out.slot,
                    consumer.component_ref, inp.slot,
                    canonical_hash((unit=semantic_view(out.unit), space=semantic_view(out.space),
                        direction=(out.direction, inp.direction)))))
            end
        end
    end
    order = isempty(failures) ? _csp_topological_order(components, edges, failures) : Digest256[]
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
