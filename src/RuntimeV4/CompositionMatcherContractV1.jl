"""Typed, contract-only composition matching.

This standalone additive module builds a deterministic port/DAG plan from
complete capability signatures. It does not select or invoke a provider, a
solver, a mesh, or a physical backend. Display labels and port ids are kept
only for diagnostics; canonical identity is derived from complete typed
signatures and normalized edges/components.
"""

# This file is intentionally safe to include into a fresh module. Do not rely
# on package export visibility: CapabilitySignatureV4 is supplied by the
# preceding RuntimeV4 Contracts include in the isolated loader.  The matcher
# only imports package-core values that are already part of FusionConceptAI's
# public IR/canonical surface.
import FusionConceptAI: Digest256, PhysicalType, UnitSignature,
    canonical_hash, semantic_view

const CMC_SCHEMA_V1 = "fusionconceptai:composition-matcher-contract-v1"

_cmc_text(x, field) = begin
    x isa AbstractString || throw(ArgumentError("$field must be a string"))
    s = String(x)
    !isempty(s) && isvalid(s) || throw(ArgumentError("$field cannot be empty"))
    lowercase(s) in ("*", "any", "all", "wildcard") &&
        throw(ArgumentError("$field cannot be wildcard"))
    s
end

struct CompositionMatcherFailureV1
    code::Symbol
    path::String
    detail::String
end

_cmc_failure(code, path, detail) =
    CompositionMatcherFailureV1(Symbol(code), String(path), String(detail))

"""A port carries all routing-relevant physical and ledger semantics."""
struct CompositionPortContractV1
    port_id::String
    side::Symbol
    signature::CapabilitySignatureV4
    physical_type::PhysicalType
    unit::UnitSignature
    space_ref::Digest256
    domain_ref::Digest256
    boundary_relation::String
    interface_relation::String
    ledger_role::Symbol
    ledger_account::String
    ledger_owner::String
    ledger_sign::Int
    function CompositionPortContractV1(port_id, side::Symbol,
            signature::CapabilitySignatureV4, physical_type::PhysicalType,
            unit::UnitSignature, space_ref::Digest256, domain_ref::Digest256,
            boundary_relation, interface_relation, ledger_role::Symbol,
            ledger_account, ledger_owner, ledger_sign::Integer)
        id = _cmc_text(port_id, "port_id")
        side in (:input, :output) || throw(ArgumentError("port side must be input/output"))
        physical_type.spatial_dimension == signature.dimension ||
            throw(ArgumentError("port dimension does not match capability signature"))
        physical_type.units == unit || throw(ArgumentError("port unit differs from physical type"))
        br = _cmc_text(boundary_relation, "boundary_relation")
        ir = _cmc_text(interface_relation, "interface_relation")
        ledger_role in (:state, :source, :sink, :return) ||
            throw(ArgumentError("unsupported ledger role"))
        account = _cmc_text(ledger_account, "ledger_account")
        owner = _cmc_text(ledger_owner, "ledger_owner")
        sign = Int(ledger_sign)
        ledger_role === :state ? sign == 0 : abs(sign) == 1 ||
            throw(ArgumentError("non-state ledger sign must be +/-1"))
        new(id, side, signature, physical_type, unit, space_ref, domain_ref,
            br, ir, ledger_role, account, owner, sign)
    end
end

"""A component declaration; provider/authority are declaration statuses only."""
struct CompositionComponentContractV1
    component_ref::Digest256
    source_ref::Digest256
    capability::CapabilitySignatureV4
    inputs::Tuple{Vararg{CompositionPortContractV1}}
    outputs::Tuple{Vararg{CompositionPortContractV1}}
    provider_status::Symbol
    authority_status::Symbol
    function CompositionComponentContractV1(component_ref::Digest256,
            source_ref::Digest256, capability::CapabilitySignatureV4,
            inputs, outputs, provider_status::Symbol, authority_status::Symbol)
        ins = Tuple(inputs); outs = Tuple(outputs)
        all(x -> x isa CompositionPortContractV1 && x.side === :input, ins) ||
            throw(ArgumentError("component inputs are not typed input ports"))
        all(x -> x isa CompositionPortContractV1 && x.side === :output, outs) ||
            throw(ArgumentError("component outputs are not typed output ports"))
        provider_status in (:declared, :missing, :out_of_domain) ||
            throw(ArgumentError("invalid provider status"))
        authority_status in (:contract_only, :checked_present, :typed_absent) ||
            throw(ArgumentError("invalid authority status"))
        new(component_ref, source_ref, capability, ins, outs, provider_status,
            authority_status)
    end
end

struct CompositionMatchEdgeV1
    producer_component::Digest256
    producer_port::String
    consumer_component::Digest256
    consumer_port::String
    signature_hash::Digest256
end

struct CompositionMatchPlanV1
    schema::String
    components::Tuple{Vararg{CompositionComponentContractV1}}
    edges::Tuple{Vararg{CompositionMatchEdgeV1}}
    topological_order::Tuple{Vararg{Digest256}}
    unresolved_ports::Tuple{Vararg{String}}
    unresolved_keys::Tuple
    ledger_defects::Tuple{Vararg{String}}
    failures::Tuple{Vararg{CompositionMatcherFailureV1}}
    deferred_reasons::Tuple{Vararg{String}}
    status::Symbol
    provider_invocation_count::Int
    solver_invocation_count::Int
    input_hash::Digest256
    plan_hash::Digest256
end

"""Full signature key. It deliberately includes every routing field."""
_cmc_signature_key(s::CapabilitySignatureV4) =
    (schema=s.schema, revision=s.revision, kind=s.kind, operator=s.operator,
     states=s.states, source_space=s.source_space, target_space=s.target_space,
     dimension=s.dimension, coordinates=s.coordinates,
     boundary_relation=s.boundary_relation, interface_relation=s.interface_relation,
     time_semantics=s.time_semantics, required_output=s.required_output,
     evidence_level=s.evidence_level, applicability_bounds=s.applicability_bounds,
     input_schema_hash=s.input_schema_hash, coordinate_system=s.coordinate_system)

_cmc_physical_key(p::PhysicalType) =
    (value_kind=p.value_kind, tensor_rank=p.tensor_rank,
     spatial_dimension=p.spatial_dimension, temporal_type=p.temporal_type,
     units=p.units)

"""Canonical port identity excludes the display-only port id."""
_cmc_port_key(p::CompositionPortContractV1) =
    (side=p.side, signature=_cmc_signature_key(p.signature),
     physical_type=_cmc_physical_key(p.physical_type), unit=p.unit,
     space_ref=p.space_ref, domain_ref=p.domain_ref,
     boundary_relation=p.boundary_relation, interface_relation=p.interface_relation,
     ledger_role=p.ledger_role, ledger_account=p.ledger_account,
     ledger_owner=p.ledger_owner, ledger_sign=p.ledger_sign)

_cmc_port_sort_key(p::CompositionPortContractV1) = string(canonical_hash(_cmc_port_key(p)))
_cmc_sorted_inputs(c::CompositionComponentContractV1) = sort(collect(c.inputs), by=_cmc_port_sort_key)
_cmc_sorted_outputs(c::CompositionComponentContractV1) = sort(collect(c.outputs), by=_cmc_port_sort_key)

"""Canonical component identity excludes input/output tuple order and port ids."""
_cmc_component_key(c::CompositionComponentContractV1) =
    (component_ref=c.component_ref, source_ref=c.source_ref,
     capability=_cmc_signature_key(c.capability),
     inputs=Tuple(_cmc_port_key(p) for p in _cmc_sorted_inputs(c)),
     outputs=Tuple(_cmc_port_key(p) for p in _cmc_sorted_outputs(c)),
     provider_status=c.provider_status, authority_status=c.authority_status)

_cmc_component_sort_key(c::CompositionComponentContractV1) = string(c.component_ref)
_cmc_sorted_components(cs) = sort(collect(cs), by=_cmc_component_sort_key)

semantic_view(x::CompositionPortContractV1) = _cmc_port_key(x)
semantic_view(x::CompositionComponentContractV1) = _cmc_component_key(x)
semantic_view(x::CompositionMatchEdgeV1) =
    (producer_component=x.producer_component, consumer_component=x.consumer_component,
     signature_hash=x.signature_hash)

function _cmc_signature_compatible(out::CapabilitySignatureV4,
        inp::CapabilitySignatureV4)
    out.schema == inp.schema && out.revision == inp.revision &&
        out.kind == inp.kind && out.operator == inp.operator &&
        out.states == inp.states && out.target_space == inp.source_space &&
        out.dimension == inp.dimension && out.coordinates == inp.coordinates &&
        out.boundary_relation == inp.boundary_relation &&
        out.interface_relation == inp.interface_relation &&
        out.time_semantics == inp.time_semantics &&
        out.required_output == inp.required_output &&
        out.evidence_level == inp.evidence_level &&
        out.applicability_bounds == inp.applicability_bounds &&
        out.input_schema_hash == inp.input_schema_hash &&
        out.coordinate_system == inp.coordinate_system
end

function _cmc_port_compatible(out::CompositionPortContractV1,
        inp::CompositionPortContractV1)
    out.side === :output && inp.side === :input || return false
    _cmc_signature_compatible(out.signature, inp.signature) || return false
    out.physical_type == inp.physical_type && out.unit == inp.unit &&
        out.space_ref == inp.space_ref && out.domain_ref == inp.domain_ref &&
        out.boundary_relation == inp.boundary_relation &&
        out.interface_relation == inp.interface_relation &&
        out.ledger_account == inp.ledger_account &&
        out.ledger_owner == inp.ledger_owner &&
        out.ledger_role == inp.ledger_role && out.ledger_sign == -inp.ledger_sign
end

function _cmc_validate_component!(failures, deferred, component)
    component isa CompositionComponentContractV1 || begin
        push!(failures, _cmc_failure(:invalid_component, "components",
            "component is not CompositionComponentContractV1")); return
    end
    length(unique(p.port_id for p in component.inputs)) == length(component.inputs) ||
        push!(failures, _cmc_failure(:duplicate_port, string("component:", component.component_ref, ":inputs"), "duplicate input port"))
    length(unique(p.port_id for p in component.outputs)) == length(component.outputs) ||
        push!(failures, _cmc_failure(:duplicate_port, string("component:", component.component_ref, ":outputs"), "duplicate output port"))
    component.authority_status === :typed_absent &&
        push!(deferred, string("authority_absent:", component.component_ref))
    component.provider_status !== :declared &&
        push!(deferred, string("provider_unavailable:", component.component_ref, ":", component.provider_status))
end

function _cmc_topological_order(components, edges, failures)
    refs = Tuple(c.component_ref for c in components)
    incoming = Dict{Digest256,Int}(r => 0 for r in refs)
    outgoing = Dict{Digest256,Vector{Digest256}}(r => Digest256[] for r in refs)
    for e in edges
        haskey(incoming, e.producer_component) && haskey(incoming, e.consumer_component) || begin
            push!(failures, _cmc_failure(:invalid_edge, "edges", "edge references unknown component")); continue
        end
        e.producer_component == e.consumer_component && begin
            push!(failures, _cmc_failure(:cycle, "edges", "self-loop in composition graph")); continue
        end
        incoming[e.consumer_component] += 1
        push!(outgoing[e.producer_component], e.consumer_component)
    end
    ready = sort!([r for r in refs if incoming[r] == 0], by=string)
    order = Digest256[]
    while !isempty(ready)
        r = popfirst!(ready); push!(order, r)
        for child in sort!(unique(outgoing[r]), by=string)
            incoming[child] -= 1
            incoming[child] == 0 && push!(ready, child)
        end
        sort!(ready, by=string)
    end
    length(order) == length(refs) || push!(failures,
        _cmc_failure(:cycle, "topological_order", "composition graph contains a cycle"))
    Tuple(order)
end

function _cmc_ledger_defects(components)
    sums = Dict{Tuple{String,String},Int}()
    seen = Set{Tuple{String,String}}()
    for c in components, p in (c.inputs..., c.outputs...)
        p.ledger_role === :state && continue
        key = (p.ledger_account, p.ledger_owner)
        sums[key] = get(sums, key, 0) + p.ledger_sign
        push!(seen, key)
    end
    [string("ledger_unclosed:", k[1], "/", k[2], ":sum=", sums[k])
        for k in sort!(collect(seen), by=string) if sums[k] != 0]
end

function _cmc_normalized_edge(e, components)
    producer = only(c for c in components if c.component_ref == e.producer_component)
    consumer = only(c for c in components if c.component_ref == e.consumer_component)
    out = only(p for p in producer.outputs if p.port_id == e.producer_port)
    inp = only(p for p in consumer.inputs if p.port_id == e.consumer_port)
    (producer_component=e.producer_component, producer_port=_cmc_port_key(out),
     consumer_component=e.consumer_component, consumer_port=_cmc_port_key(inp),
     signature_hash=e.signature_hash)
end

"""Normalize diagnostic paths while retaining the typed failure fields.

`input.<display-label>` and `port.<display-label>` are diagnostic spellings,
not semantic identity. Matcher-generated component/signature paths already
carry typed component refs or signature hashes and are retained verbatim.
"""
function _cmc_failure_path_key(path)
    p = String(path)
    startswith(p, "input.") && return "input"
    startswith(p, "port.") && return "port"
    p
end

"""Stable, label-erased typed failure identity used by the plan hash."""
function _cmc_failure_key(f::CompositionMatcherFailureV1)
    (code=f.code, path=_cmc_failure_path_key(f.path), detail=String(f.detail))
end

_cmc_failure_sort_key(f::CompositionMatcherFailureV1) =
    (String(f.code), _cmc_failure_path_key(f.path), String(f.detail))

function _cmc_plan_body(schema, components, edges, order, unresolved_keys,
        ledger_defects, failures, deferred, status, input_hash)
    (schema=schema,
     components=Tuple(_cmc_component_key(c) for c in _cmc_sorted_components(components)),
     edges=Tuple(sort!([_cmc_normalized_edge(e, components) for e in edges], by=string)),
     topological_order=order,
     unresolved_keys=Tuple(sort!(collect(unresolved_keys), by=string)),
     ledger_defects=Tuple(sort!(collect(ledger_defects), by=string)),
     failures=Tuple(_cmc_failure_key(f) for f in sort(collect(failures), by=_cmc_failure_sort_key)),
     deferred_reasons=Tuple(sort!(collect(deferred), by=string)),
     status=status, provider_invocation_count=0, solver_invocation_count=0,
     input_hash=input_hash)
end

function _cmc_make_plan(components, edges, order, unresolved, unresolved_keys,
        ledger_defects, failures, deferred, status; input_hash=nothing)
    cs = Tuple(_cmc_sorted_components(components))
    ih = input_hash === nothing ? canonical_hash((schema=CMC_SCHEMA_V1,
        components=Tuple(_cmc_component_key(c) for c in cs))) : input_hash
    body = _cmc_plan_body(CMC_SCHEMA_V1, cs, edges, order, unresolved_keys,
        ledger_defects, failures, deferred, status, ih)
    ph = canonical_hash(body)
    CompositionMatchPlanV1(CMC_SCHEMA_V1, cs, Tuple(edges), Tuple(order),
        Tuple(unresolved), Tuple(unresolved_keys), Tuple(ledger_defects),
        Tuple(failures), Tuple(deferred), status, 0, 0, ih, ph)
end

function _cmc_error_plan(code, detail; input=nothing)
    raw = try string(typeof(input), ":", input) catch; "invalid input" end
    ih = canonical_hash((schema=CMC_SCHEMA_V1, invalid_input=raw))
    _cmc_make_plan(CompositionComponentContractV1[], CompositionMatchEdgeV1[],
        Digest256[], String[], Any[], String[],
        [_cmc_failure(code, "components", detail)], String[], :fail_closed;
        input_hash=ih)
end

"""Build a deterministic plan without provider, solver, mesh, or execution."""
function match_composition_contract(components)
    raw = try Tuple(components) catch
        return _cmc_error_plan(:invalid_input, "components is not iterable"; input=components)
    end
    valid = Tuple(c for c in raw if c isa CompositionComponentContractV1)
    failures = CompositionMatcherFailureV1[]
    length(valid) == length(raw) || push!(failures, _cmc_failure(:invalid_component,
        "components", "all components must be typed CompositionComponentContractV1"))
    refs = Tuple(c.component_ref for c in valid)
    length(unique(refs)) == length(refs) ||
        push!(failures, _cmc_failure(:duplicate_component, "components", "component refs are not unique"))
    deferred = String[]
    for c in valid
        _cmc_validate_component!(failures, deferred, c)
    end

    try
        ordered = Tuple(_cmc_sorted_components(valid))
        edges = CompositionMatchEdgeV1[]
        unresolved = String[]
        unresolved_keys = Any[]
        if isempty(failures)
            for consumer in ordered, inp in _cmc_sorted_inputs(consumer)
                matches = Tuple((producer, out) for producer in ordered
                    if producer.component_ref != consumer.component_ref
                    for out in _cmc_sorted_outputs(producer) if _cmc_port_compatible(out, inp))
                if isempty(matches)
                    if isempty(deferred)
                        push!(failures, _cmc_failure(:unmatched_signature,
                            string("component:", consumer.component_ref, ":input:",
                                canonical_hash(_cmc_port_key(inp))),
                            "no complete typed signature matched"))
                    else
                        push!(unresolved, string(consumer.component_ref, ":", inp.port_id))
                        push!(unresolved_keys, (component=consumer.component_ref, port=_cmc_port_key(inp)))
                    end
                elseif length(matches) > 1
                    sigkey = string(canonical_hash(_cmc_port_key(inp)))
                    push!(failures, _cmc_failure(:ambiguous_match,
                        string("component:", consumer.component_ref, ":input:", sigkey),
                        "more than one complete typed signature matched"))
                else
                    producer, out = only(matches)
                    push!(edges, CompositionMatchEdgeV1(producer.component_ref, out.port_id,
                        consumer.component_ref, inp.port_id, canonical_hash(out.signature)))
                end
            end
        end
        ledger_defects = isempty(failures) ? _cmc_ledger_defects(ordered) : String[]
        foreach(x -> push!(failures, _cmc_failure(:unclosed_ledger, "ledger", x)), ledger_defects)
        order = isempty(failures) ? _cmc_topological_order(ordered, edges, failures) : Digest256[]
        status = !isempty(failures) ? :fail_closed :
            (!isempty(unresolved) || !isempty(deferred) ? :terminal_deferred : :contract_only)
        _cmc_make_plan(ordered, edges, order, unresolved, unresolved_keys,
            ledger_defects, failures, deferred, status)
    catch err
        _cmc_error_plan(:invalid_input, string("typed plan construction failed: ", typeof(err)); input=raw)
    end
end

function semantic_view(x::CompositionMatchPlanV1)
    _cmc_plan_body(x.schema, x.components, x.edges, x.topological_order,
        x.unresolved_keys, x.ledger_defects, x.failures, x.deferred_reasons,
        x.status, x.input_hash)
end

"""Recompute all derived plan fields and return a typed fail-closed plan on drift."""
function validate_composition_match(x)
    x isa CompositionMatchPlanV1 || return _cmc_error_plan(:invalid_plan,
        "value is not CompositionMatchPlanV1"; input=x)
    expected = match_composition_contract(x.components)
    drift = String[]
    x.schema == expected.schema || push!(drift, "schema")
    x.edges == expected.edges || push!(drift, "edges")
    x.topological_order == expected.topological_order || push!(drift, "topological_order")
    x.unresolved_ports == expected.unresolved_ports || push!(drift, "unresolved_ports")
    x.unresolved_keys == expected.unresolved_keys || push!(drift, "unresolved_keys")
    x.ledger_defects == expected.ledger_defects || push!(drift, "ledger_defects")
    x.failures == expected.failures || push!(drift, "failures")
    x.deferred_reasons == expected.deferred_reasons || push!(drift, "deferred_reasons")
    x.status == expected.status || push!(drift, "status")
    x.provider_invocation_count == 0 && x.solver_invocation_count == 0 ||
        push!(drift, "invocation_counts")
    x.input_hash == expected.input_hash || push!(drift, "input_hash")
    x.plan_hash == expected.plan_hash || push!(drift, "plan_hash")
    isempty(drift) ? x : _cmc_make_plan(expected.components, expected.edges,
        expected.topological_order, expected.unresolved_ports,
        expected.unresolved_keys, expected.ledger_defects,
        [expected.failures...,
         _cmc_failure(:validation_mismatch, "plan", join(sort!(drift), ","))],
        expected.deferred_reasons, :fail_closed; input_hash=expected.input_hash)
end

composition_match_payload(x::CompositionMatchPlanV1) = semantic_view(x)
# Hash the same canonical semantic body used during plan construction. Hashing
# the full stored struct would include `plan_hash` itself and cannot reproduce
# the construction-time digest.
composition_match_hash(x::CompositionMatchPlanV1) = canonical_hash(semantic_view(x))
