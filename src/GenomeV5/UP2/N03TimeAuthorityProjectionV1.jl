"""Candidate-bound, contract-only N03 time authority projection.

The five rows are projected from an actual CandidateStatePackageV5.  G1 checks
are local equation/operator checks.  A candidate-bound G3 event-time policy is
consumed as local design data; it does not establish measured controller-clock
or formal cross-layer authority.  No compiler, provider, mesh, or solver is
called here.
"""

import JSON3

const _N03_TIME_KINDS = (static_time, algebraic_time, differential_time, discrete_time, event_time)

_n03_has(x, name::Symbol) = x !== nothing && hasproperty(x, name)
_n03_get(x, name::Symbol, default=nothing) = _n03_has(x, name) ? getproperty(x, name) : default
_n03_text(x, field) = x isa AbstractString && !isempty(String(x)) ? String(x) : throw(ArgumentError("$field must be non-empty"))
_n03_ref(x) = x isa GenomeContractRef ? x : throw(ArgumentError("N03 requires a public GenomeContractRef"))
_n03_digest(x, field) = x isa Digest256 ? x : throw(ArgumentError("$field must be Digest256"))
_n03_time_kind(x, field) = x isa TimeKindV1 ? x : throw(ArgumentError("$field must be TimeKindV1"))

struct N03TimeDeclarationV1
    id::String
    field_path::String
    source_locator::String
    source_type::String
    candidate_ref::QualifiedRefV1
    genome_ref::GenomeContractRef
    component_hash::Digest256
    schema_hash::Digest256
    canonicalization_hash::Digest256
    original_value::Any
    authority_scope::Symbol
    authority_gap::String
    function N03TimeDeclarationV1(id, field_path, source_locator, source_type,
                                  candidate_ref, genome_ref, component_hash,
                                  original_value; authority_scope=:local,
                                  authority_gap="")
        candidate_ref isa QualifiedRefV1 && candidate_ref.version == "v5" ||
            throw(ArgumentError("N03 candidate ref must be v5"))
        ref = _n03_ref(genome_ref)
        ref.version == "v5" || throw(ArgumentError("N03 genome ref must be v5"))
        hash = _n03_digest(component_hash, "N03 component_hash")
        scope = authority_scope isa Symbol ? authority_scope : Symbol(authority_scope)
        scope in (:local, :cross_layer) || throw(ArgumentError("unsupported N03 authority scope"))
        gap = String(authority_gap)
        scope == :cross_layer && isempty(gap) &&
            throw(ArgumentError("cross-layer N03 declaration requires an explicit gap"))
        new(_n03_text(id, "N03 id"), _n03_text(field_path, "N03 field_path"),
            _n03_text(source_locator, "N03 source_locator"), _n03_text(source_type, "N03 source_type"),
            candidate_ref, ref, hash, ref.schema_hash, ref.canonicalization_hash,
            original_value, scope, gap)
    end
end

semantic_view(x::N03TimeDeclarationV1) =
    (id=x.id, field_path=x.field_path, source_locator=x.source_locator,
     source_type=x.source_type, candidate_ref=x.candidate_ref, genome_ref=x.genome_ref,
     component_hash=x.component_hash, schema_hash=x.schema_hash,
     canonicalization_hash=x.canonicalization_hash,
     original_value=x.original_value isa TimeKindV1 ? Symbol(x.original_value) : x.original_value,
     authority_scope=x.authority_scope, authority_gap=x.authority_gap)

struct N03TimeAuthorityProjectionV1
    candidate_ref::QualifiedRefV1
    package_hash::Digest256
    declarations::Tuple{Vararg{N03TimeDeclarationV1}}
    gaps::Tuple{Vararg{String}}
    g1_equation_temporal_kind::TimeKindV1
    g1_operator_temporal_kinds::Tuple{Vararg{TimeKindV1}}
    g1_operator_max_derivative_order::Int
    projection_hash::Digest256
    function N03TimeAuthorityProjectionV1(candidate_ref, package_hash, declarations, gaps;
                                           g1_equation_temporal_kind=first(declarations).original_value,
                                           g1_operator_temporal_kinds=(),
                                           g1_operator_max_derivative_order=-1)
        candidate_ref isa QualifiedRefV1 && candidate_ref.version == "v5" ||
            throw(ArgumentError("N03 projection requires v5 candidate ref"))
        package_hash isa Digest256 || throw(ArgumentError("N03 projection requires package hash"))
        declarations isa Tuple && all(x -> x isa N03TimeDeclarationV1, declarations) ||
            throw(ArgumentError("N03 declarations must be a tuple"))
        length(declarations) == 5 || throw(ArgumentError("N03 requires exactly five declarations"))
        all(x -> x.candidate_ref == candidate_ref, declarations) ||
            throw(ArgumentError("N03 declaration candidate binding mismatch"))
        length(unique(x.id for x in declarations)) == 5 || throw(ArgumentError("N03 declaration ids must be unique"))
        length(unique(x.field_path for x in declarations)) == 5 || throw(ArgumentError("N03 field paths must be unique"))
        gs = Tuple(_n03_text(g, "N03 gap") for g in gaps)
        equation_kind = _n03_time_kind(g1_equation_temporal_kind, "N03 equation temporal kind")
        operator_kinds = Tuple(_n03_time_kind(x, "N03 operator temporal kind") for x in g1_operator_temporal_kinds)
        max_order = Int(g1_operator_max_derivative_order)
        0 <= max_order <= typemax(UInt8) || throw(ArgumentError("N03 operator derivative bound is invalid"))
        context = (g1_equation_temporal_kind=equation_kind,
                   g1_operator_temporal_kinds=operator_kinds,
                   g1_operator_max_derivative_order=max_order)
        body = (candidate_ref=candidate_ref, package_hash=package_hash,
                declarations=declarations, gaps=gs, context=context)
        new(candidate_ref, package_hash, declarations, gs, context.g1_equation_temporal_kind,
            context.g1_operator_temporal_kinds, context.g1_operator_max_derivative_order,
            canonical_hash(body))
    end
end
semantic_view(x::N03TimeAuthorityProjectionV1) =
    (candidate_ref=x.candidate_ref, package_hash=x.package_hash,
     declarations=x.declarations, gaps=x.gaps,
     g1_equation_temporal_kind=x.g1_equation_temporal_kind,
     g1_operator_temporal_kinds=x.g1_operator_temporal_kinds,
     g1_operator_max_derivative_order=x.g1_operator_max_derivative_order,
     projection_hash=x.projection_hash)

function _n03_contract_ref(x)
    ref = _n03_get(x, :contract_ref)
    ref isa GenomeContractRef && return ref
    b = _n03_get(x, :contract_binding)
    ref = _n03_get(b, :contract_ref)
    ref isa GenomeContractRef && return ref
    throw(ArgumentError("N03 source has no public contract ref"))
end
function _n03_component_hash(x)
    h = _n03_get(x, :candidate_hash)
    h isa Digest256 ? h : throw(ArgumentError("N03 source has no candidate component hash"))
end

function _n03_operator(profile, ref)
    ops = _n03_get(profile, :operators, ())
    found = findfirst(op -> _n03_get(op, :ref) == ref, ops)
    found === nothing && throw(ArgumentError("N03 equation operator ref is not in grammar profile"))
    ops[found]
end

"""Project the actual first G1 equation/operator and first G3 controller event."""
function n03_time_authority_projection(package)
    package isa CandidateStatePackageV5 || throw(ArgumentError("N03 requires CandidateStatePackageV5"))
    candidate = package.candidate_ref
    g1 = package.g1; g3 = package.g3
    g1payload = _n03_get(g1, :payload)
    plan = _n03_get(g1payload, :equation_plan)
    equations = _n03_get(plan, :equations, ())
    isempty(equations) && throw(ArgumentError("N03 missing G1 equation"))
    equation = first(equations)
    profile = _n03_get(g1payload, :grammar_profile)
    operator = _n03_operator(profile, equation.operator_ref)
    g1ref = _n03_contract_ref(g1); g1hash = _n03_component_hash(g1)
    g3control = _n03_get(g3, :control)
    controllers = _n03_get(g3control, :controllers, ())
    isempty(controllers) && throw(ArgumentError("N03 missing G3 controller"))
    controller = first(controllers)
    events = _n03_get(controller, :events, ())
    isempty(events) && throw(ArgumentError("N03 missing G3 controller event"))
    event_value = first(events)
    g3ref = _n03_contract_ref(g3control); g3hash = _n03_component_hash(g3control)
    declarations = (
        N03TimeDeclarationV1("N03-01", "/g1/payload/equation_plan/equations/0/temporal_kind",
            "G1EquationV2.temporal_kind::TimeKindV1", "TimeKindV1", candidate, g1ref, g1hash,
            equation.temporal_kind),
        N03TimeDeclarationV1("N03-02", "/g1/payload/equation_plan/equations/0/derivative_order",
            "G1EquationV2.derivative_order::Int", "Int", candidate, g1ref, g1hash,
            equation.derivative_order),
        N03TimeDeclarationV1("N03-03", "/g1/payload/grammar_profile/operators/0/temporal_kinds",
            "G1OperatorSpecV2.temporal_kinds::Tuple{Vararg{TimeKindV1}}", "Tuple{TimeKindV1}",
            candidate, g1ref, g1hash, operator.temporal_kinds),
        N03TimeDeclarationV1("N03-04", "/g3/control/controllers/0/events/0/trigger",
            "G3EventV2.trigger::Symbol", "Symbol", candidate, g3ref, g3hash, event_value.trigger;
            authority_scope=:cross_layer,
            authority_gap="missing_candidate_bound_g3_event_time_basis_policy"),
        N03TimeDeclarationV1("N03-05", "/g3/control/controllers/0/events/0/time",
            "G3EventV2.time::Rational{Int64}", "Rational{Int64}", candidate, g3ref, g3hash,
            event_value.time; authority_scope=:cross_layer,
            authority_gap="missing_candidate_bound_g3_event_time_basis_policy")
    )
    N03TimeAuthorityProjectionV1(candidate, package.candidate_hash, declarations,
        ("missing_candidate_bound_g3_event_time_basis_policy",);
        g1_equation_temporal_kind=equation.temporal_kind,
        g1_operator_temporal_kinds=operator.temporal_kinds,
        g1_operator_max_derivative_order=operator.max_derivative_order)
end

"""A raw source pin supplied by the independently checked freeze manifest.

`g1_builder`/`g2_builder` pin candidate-authored inputs embedded in semantic
bodies. `g1_declaration_source`/`g2_declaration_source` pin the production
source files carried by declaration `source_bytes`; these are distinct inputs.
"""
struct N03VNextRawSourcePinV1
    role::Symbol
    byte_count::Int
    sha256::Digest256
    function N03VNextRawSourcePinV1(role, byte_count, sha256)
        r = Symbol(role)
        r in (:g1_builder, :g1_declaration_source, :g2_builder,
            :g2_declaration_source, :g3_builder, :g3_child_design) ||
            throw(ArgumentError("unsupported N03 VNext source role"))
        n = Int(byte_count)
        n > 0 && sha256 isa Digest256 || throw(ArgumentError("invalid N03 VNext source pin"))
        new(r, n, sha256)
    end
end
semantic_view(x::N03VNextRawSourcePinV1) =
    (role=x.role, byte_count=x.byte_count, sha256=x.sha256)

"""Typed local source projection from a hash-checked VNext T1 package.

It carries candidate-design event values only. A receipt-bound authored policy
can establish the local event basis, but does not establish a measured controller
clock or formal cross-layer authority.
"""
struct N03VNextLocalEventProjectionV1
    status::Symbol
    resolution::Symbol
    reason::Symbol
    candidate_ref::Union{Nothing,QualifiedRefV1}
    candidate_id::Union{Nothing,String}
    scenario_id::Union{Nothing,String}
    snapshot_id::Union{Nothing,String}
    manifest_sha256::Union{Nothing,Digest256}
    package_hash::Union{Nothing,Digest256}
    semantic_identity::Union{Nothing,Digest256}
    bundle_hash::Union{Nothing,Digest256}
    source_pins::Tuple{Vararg{N03VNextRawSourcePinV1}}
    event_id::Union{Nothing,String}
    trigger::Union{Nothing,Symbol}
    time::Union{Nothing,Rational{Int64}}
    time_basis::Union{Nothing,Symbol}
    authority_scope::Symbol
    authority_gap::String
    projection_hash::Digest256
end
semantic_view(x::N03VNextLocalEventProjectionV1) =
    (status=x.status, resolution=x.resolution, reason=x.reason,
     candidate_ref=x.candidate_ref, candidate_id=x.candidate_id,
     scenario_id=x.scenario_id, snapshot_id=x.snapshot_id,
     manifest_sha256=x.manifest_sha256, package_hash=x.package_hash,
     semantic_identity=x.semantic_identity, bundle_hash=x.bundle_hash,
     source_pins=x.source_pins, event_id=x.event_id, trigger=x.trigger,
     time=x.time, time_basis=x.time_basis, authority_scope=x.authority_scope,
     authority_gap=x.authority_gap, projection_hash=x.projection_hash)

const _N03_VNEXT_TIME_BASIS_GAP = "missing_candidate_bound_g3_event_time_basis_policy"
const _N03_VNEXT_POLICY_CEILING = "candidate_authored_event_time_policy_is_design_only"
const _N03_VNEXT_SOURCE_ROLES = (:g1_builder, :g1_declaration_source,
    :g2_builder, :g2_declaration_source, :g3_builder, :g3_child_design)

function _n03_vnext_projection(status, resolution, reason; candidate_ref=nothing,
        candidate_id=nothing, scenario_id=nothing, snapshot_id=nothing,
        manifest_sha256=nothing, package_hash=nothing, semantic_identity=nothing,
        bundle_hash=nothing, source_pins=(), event_id=nothing, trigger=nothing,
        time=nothing, time_basis=nothing, authority_scope=:local_source_data,
        authority_gap=_N03_VNEXT_TIME_BASIS_GAP)
    body = (status=status, resolution=resolution, reason=reason,
        candidate_ref=candidate_ref, candidate_id=candidate_id, scenario_id=scenario_id,
        snapshot_id=snapshot_id, manifest_sha256=manifest_sha256,
        package_hash=package_hash, semantic_identity=semantic_identity,
        bundle_hash=bundle_hash, source_pins=source_pins, event_id=event_id,
        trigger=trigger, time=time, time_basis=time_basis,
        authority_scope=authority_scope, authority_gap=authority_gap)
    N03VNextLocalEventProjectionV1(status, resolution, reason, candidate_ref,
        candidate_id, scenario_id, snapshot_id, manifest_sha256, package_hash,
        semantic_identity, bundle_hash, Tuple(source_pins), event_id, trigger, time,
        time_basis, authority_scope, authority_gap, canonical_hash(body))
end

function _n03_vnext_carrier_matches(carrier, pin)
    isdefined(@__MODULE__, :VNextT1CanonicalBytesV2) || return false
    carrier isa getfield(@__MODULE__, :VNextT1CanonicalBytesV2) || return false
    raw = copy_bytes(carrier)
    length(raw) == pin.byte_count == byte_length(carrier) || return false
    digest = Digest256(bytes2hex(SHA.sha256(raw)))
    digest == carrier.sha256 == pin.sha256
end
function _n03_vnext_semantic_input_matches(declaration, field, pin)
    body = try
        JSON3.read(String(copy_bytes(declaration.semantic_body_bytes)))
    catch
        return false
    end
    payload = _n03_get(body, field)
    bytes_node = _n03_get(payload, :bytes)
    shape, values = _n03_get(bytes_node, :shape), _n03_get(bytes_node, :values)
    shape isa AbstractVector && length(shape) == 1 &&
        first(shape) isa Integer && !(first(shape) isa Bool) || return false
    0 <= first(shape) <= typemax(Int) || return false
    values isa AbstractVector || return false
    declared_length = Int(first(shape))
    declared_length == pin.byte_count == length(values) || return false
    all(x -> x isa Integer && !(x isa Bool) && 0 <= x <= typemax(UInt8), values) ||
        return false
    raw = UInt8.(values)
    declared_sha = _n03_get(_n03_get(payload, :sha256), :value)
    declared_sha isa AbstractString && occursin(r"^[0-9a-f]{64}$", declared_sha) ||
        return false
    computed_sha = bytes2hex(SHA.sha256(raw))
    computed_sha == String(declared_sha) && computed_sha == pin.sha256.value
end
_n03_vnext_digest(object, key) = Digest256(String(_n03_get(_n03_get(object, key), :value)))
function _n03_vnext_time(value)
    n, d = _n03_get(value, :numerator), _n03_get(value, :denominator)
    n isa Integer && d isa Integer && d > 0 || throw(ArgumentError("event time is not exact rational"))
    Rational{Int64}(Int64(n), Int64(d))
end

"""Read the R54 T1 VNext package without adapting it to legacy CandidateStatePackageV5.

Expected identities and six source pins must be constructed by the caller from
the verified T1 sidecar and freeze receipt; this method checks the supplied
values but does not independently verify receipt provenance. G3 semantic-body
child bytes must equal the package child bytes.
"""
function n03_vnext_t1_local_event_projection(package;
        candidate_ref=nothing, candidate_id=nothing, scenario_id=nothing,
        snapshot_id=nothing, manifest_sha256=nothing, package_hash=nothing,
        semantic_identity=nothing, bundle_hash=nothing, source_pins=nothing)
    identity = (candidate_ref, candidate_id, scenario_id, snapshot_id,
        manifest_sha256, package_hash, semantic_identity, bundle_hash)
    text_identity = (candidate_id, scenario_id, snapshot_id)
    digest_identity = (manifest_sha256, package_hash, semantic_identity, bundle_hash)
    pins_complete = source_pins isa NamedTuple &&
        Tuple(sort!(collect(keys(source_pins)))) == _N03_VNEXT_SOURCE_ROLES
    complete = candidate_ref isa QualifiedRefV1 &&
        all(x -> x isa AbstractString && !isempty(String(x)), text_identity) &&
        all(x -> x isa Digest256, digest_identity) && pins_complete
    complete || return _n03_vnext_projection(:typed_absent, :terminal_deferred,
        :candidate_scenario_package_or_source_pin_absent)
    expected_pins = try
        Tuple(N03VNextRawSourcePinV1(role, getproperty(source_pins, role).bytes,
            getproperty(source_pins, role).sha256) for role in _N03_VNEXT_SOURCE_ROLES)
    catch
        return _n03_vnext_projection(:typed_absent, :terminal_deferred,
            :raw_source_pin_incomplete; candidate_ref=candidate_ref,
            candidate_id=candidate_id, scenario_id=scenario_id, snapshot_id=snapshot_id,
            manifest_sha256=manifest_sha256, package_hash=package_hash,
            semantic_identity=semantic_identity, bundle_hash=bundle_hash)
    end
    context = (; candidate_ref, candidate_id=String(candidate_id),
        scenario_id=String(scenario_id), snapshot_id=String(snapshot_id),
        manifest_sha256, package_hash, semantic_identity, bundle_hash,
        source_pins=expected_pins)
    candidate_ref.version == "v5" ||
        return _n03_vnext_projection(:fail_closed, :none, :candidate_ref_invalid;
            context...)
    missing_runtime_types = !all(name -> isdefined(@__MODULE__, name),
        (:CandidateStatePackageV5NextV2, :VNextT1CanonicalBytesV2,
         :vnext_t1_package_v2_validate, :vnext_t1_package_binding_adapter_v2))
    (package === nothing || missing_runtime_types) &&
        return _n03_vnext_projection(:typed_absent, :terminal_deferred,
            package === nothing ? :vnext_t1_package_absent : :vnext_t1_types_not_loaded;
            context...)
    package isa getfield(@__MODULE__, :CandidateStatePackageV5NextV2) ||
        return _n03_vnext_projection(:fail_closed, :none, :unsupported_t1_package_type;
            context...)
    validation = getfield(@__MODULE__, :vnext_t1_package_v2_validate)(package)
    validation === nothing || return _n03_vnext_projection(:fail_closed, :none,
        Symbol("t1_package_" * String(validation)); context...)
    adapter = if deep_immutable(package) && isdefined(@__MODULE__,
            :_vnext_t1_package_binding_adapter_v2_after_validation)
        getfield(@__MODULE__,
            :_vnext_t1_package_binding_adapter_v2_after_validation)(package)
    else
        getfield(@__MODULE__, :vnext_t1_package_binding_adapter_v2)(package)
    end
    adapter.status === :prepared_not_executed && adapter.package_hash == package.package_hash &&
        adapter.semantic_identity == package.semantic_identity ||
        return _n03_vnext_projection(:fail_closed, :none, :t1_reload_binding_rejected;
            context...)
    package.candidate_ref == candidate_ref && package.package_hash == package_hash &&
        package.semantic_identity == semantic_identity && package.bundle_hash == bundle_hash ||
        return _n03_vnext_projection(:fail_closed, :none, :t1_identity_or_bundle_mismatch;
            context...)
    candidate_ref.id == "fusionconceptai://candidate-design/" * String(candidate_id) ||
        return _n03_vnext_projection(:fail_closed, :none, :candidate_design_id_mismatch;
            context...)
    declarations = Dict(d.layer => d for d in package.declarations)
    Tuple(sort!(collect(keys(declarations)))) == (:G1, :G2, :G3) ||
        return _n03_vnext_projection(:typed_absent, :terminal_deferred,
            :g1_g2_g3_source_absent; context...)
    for (layer, role) in ((:G1, :g1_declaration_source),
            (:G2, :g2_declaration_source), (:G3, :g3_builder))
        d, pin = declarations[layer], only(filter(x -> x.role === role, expected_pins))
        _n03_vnext_carrier_matches(d.source_bytes, pin) ||
            return _n03_vnext_projection(:fail_closed, :none,
                Symbol(String(role) * "_source_hash_mismatch"); context...)
    end
    for (layer, role) in ((:G1, :g1_builder), (:G2, :g2_builder))
        d, pin = declarations[layer], only(filter(x -> x.role === role, expected_pins))
        _n03_vnext_semantic_input_matches(d, :authored_builder_input, pin) ||
            return _n03_vnext_projection(:fail_closed, :none,
                Symbol(String(role) * "_semantic_input_hash_mismatch"); context...)
    end
    children = package.children
    Tuple(sort!(collect(x.kind for x in children))) == (:binding, :control, :realization) ||
        return _n03_vnext_projection(:typed_absent, :terminal_deferred,
            :g3_children_absent; context...)
    all(x -> x.candidate_ref == candidate_ref && x.status === :present &&
        x.source_bytes !== nothing, children) ||
        return _n03_vnext_projection(:typed_absent, :terminal_deferred,
            :g3_child_source_absent; context...)
    control_child = first(filter(x -> x.kind === :control, children))
    child_pin = only(filter(x -> x.role === :g3_child_design, expected_pins))
    all(x -> x.source_ref == control_child.source_ref &&
        _n03_vnext_carrier_matches(x.source_bytes, child_pin), children) ||
        return _n03_vnext_projection(:fail_closed, :none,
            :g3_child_source_hash_mismatch; context...)
    g3 = declarations[:G3]
    body = try JSON3.read(String(copy_bytes(g3.semantic_body_bytes))) catch
        return _n03_vnext_projection(:fail_closed, :none, :g3_semantic_body_invalid;
            context...)
    end
    design = _n03_get(body, :authored_child_design)
    body_candidate, body_source = _n03_get(body, :candidate_ref), _n03_get(body, :source_ref)
    _n03_get(body_candidate, :id) == candidate_ref.id &&
        _n03_get(body_source, :id) == g3.source_ref.id &&
        _n03_get(design, :schema) in ("up4-r2-g3-child-design-source-v1",
            "up4-r2-g3-child-design-source-v2") &&
        (_n03_get(design, :schema) == "up4-r2-g3-child-design-source-v1" ||
            _n03_get(design, :unit_basis) == ["kg", "m", "s", "A", "K", "mol", "cd"]) &&
        _n03_get(design, :design_scope) == "candidate_design_only" &&
        _n03_get(design, :candidate_id) == candidate_id &&
        _n03_get(design, :scenario_id) == scenario_id ||
        return _n03_vnext_projection(:fail_closed, :none,
            :g3_candidate_scenario_binding_mismatch; context...)
    child_body = _n03_get(body, :authored_child_design_input)
    try
        byte_array = _n03_get(child_body, :bytes)
        shape = _n03_get(byte_array, :shape)
        values = _n03_get(byte_array, :values)
        shape isa AbstractVector && length(shape) == 1 &&
            first(shape) isa Integer && !(first(shape) isa Bool) ||
            throw(ArgumentError("G3 source byte shape is invalid"))
        values isa AbstractVector || throw(ArgumentError("G3 source byte values are invalid"))
        declared_length = Int(first(shape))
        length(values) == declared_length == byte_length(control_child.source_bytes) ||
            throw(ArgumentError("G3 source byte length mismatch"))
        all(x -> x isa Integer && !(x isa Bool) && 0 <= x <= typemax(UInt8), values) ||
            throw(ArgumentError("G3 source contains a non-UInt8 value"))
        raw = UInt8.(values)
        digest = Digest256(bytes2hex(SHA.sha256(raw)))
        digest == _n03_vnext_digest(child_body, :sha256) == control_child.source_bytes.sha256 &&
            raw == copy_bytes(control_child.source_bytes) ||
            throw(ArgumentError("G3 source bytes mismatch"))
    catch
        return _n03_vnext_projection(:fail_closed, :none,
            :g3_semantic_child_source_mismatch; context...)
    end
    controllers = _n03_get(_n03_get(design, :control), :controllers, ())
    events = isempty(controllers) ? () : _n03_get(first(controllers), :events, ())
    isempty(events) && return _n03_vnext_projection(:typed_absent, :terminal_deferred,
        :g3_event_absent; context...)
    event = first(events)
    trigger_text = _n03_get(event, :trigger)
    trigger_text isa AbstractString || return _n03_vnext_projection(:fail_closed, :none,
        :g3_event_trigger_invalid; context...)
    trigger = Symbol(trigger_text)
    trigger in (:initial, :scheduled, :fault, :threshold) ||
        return _n03_vnext_projection(:fail_closed, :none, :g3_event_trigger_invalid;
            context...)
    event_id = _n03_get(event, :event_id)
    event_id isa AbstractString && !isempty(String(event_id)) ||
        return _n03_vnext_projection(:fail_closed, :none, :g3_event_id_invalid;
            context...)
    time = try _n03_vnext_time(_n03_get(event, :time)) catch
        return _n03_vnext_projection(:fail_closed, :none, :g3_event_time_invalid;
            context...)
    end
    time >= 0 || return _n03_vnext_projection(:fail_closed, :none,
        :g3_event_time_negative; context...)
    control_design = _n03_get(design, :control_design)
    policy = _n03_get(control_design, :event_time_policy)
    policy === nothing && return _n03_vnext_projection(:local_source_bound,
        :terminal_deferred, :candidate_design_event_time_basis_absent;
        context..., event_id=String(event_id), trigger=trigger, time=time,
        time_basis=nothing, authority_scope=:cross_layer,
        authority_gap=_N03_VNEXT_TIME_BASIS_GAP)
    policy_fields = Tuple(_n03_get(policy, name) for name in
        (:basis, :unit, :clock, :origin, :initial_trigger, :initial_time))
    any(isnothing, policy_fields) && return _n03_vnext_projection(:typed_absent,
        :terminal_deferred, :g3_event_time_policy_incomplete; context...,
        event_id=String(event_id), trigger=trigger, time=time)
    basis_text, unit_text, clock_text, origin_text, initial_trigger_text, initial_time_raw = policy_fields
    all(x -> x isa AbstractString, (basis_text, unit_text, clock_text, origin_text,
        initial_trigger_text)) || return _n03_vnext_projection(:fail_closed, :none,
        :g3_event_time_policy_invalid; context..., event_id=String(event_id),
        trigger=trigger, time=time)
    initial_time = try _n03_vnext_time(initial_time_raw) catch
        return _n03_vnext_projection(:fail_closed, :none,
            :g3_event_time_policy_invalid; context..., event_id=String(event_id),
            trigger=trigger, time=time)
    end
    String(basis_text) == "event" && String(unit_text) == "second" &&
        String(clock_text) == "controller_elapsed" &&
        String(origin_text) == "controller_initialization" &&
        String(initial_trigger_text) == "initial" && initial_time >= 0 ||
        return _n03_vnext_projection(:fail_closed, :none,
            :g3_event_time_policy_invalid; context..., event_id=String(event_id),
            trigger=trigger, time=time)
    trigger === Symbol(initial_trigger_text) || return _n03_vnext_projection(
        :fail_closed, :none, :g3_event_trigger_policy_mismatch; context...,
        event_id=String(event_id), trigger=trigger, time=time, time_basis=:event,
        authority_scope=:local_source_data, authority_gap=_N03_VNEXT_POLICY_CEILING)
    time == initial_time || return _n03_vnext_projection(:fail_closed, :none,
        :g3_event_initial_time_policy_mismatch; context..., event_id=String(event_id),
        trigger=trigger, time=time, time_basis=:event,
        authority_scope=:local_source_data, authority_gap=_N03_VNEXT_POLICY_CEILING)
    _n03_vnext_projection(:local_source_bound, :terminal_deferred,
        :candidate_design_event_time_policy_consumed; context...,
        event_id=String(event_id), trigger=trigger, time=time, time_basis=:event,
        authority_scope=:local_source_data, authority_gap=_N03_VNEXT_POLICY_CEILING)
end
n03_projection_complete(x::N03TimeAuthorityProjectionV1) =
    length(x.declarations) == 5 && !isempty(x.gaps) &&
    all(d -> d.candidate_ref == x.candidate_ref, x.declarations) &&
    !isempty(x.g1_operator_temporal_kinds) && x.g1_operator_max_derivative_order >= 0

struct N03TimeMutationSpecV1
    id::String
    field_path::String
    source_locator::String
    mutation_kind::Symbol
    mutated_value::Any
    expected_error::Symbol
    expected_resolution::Symbol
    expected_compile_calls::Int
    expected_provider_calls::Int
    expected_solver_calls::Int
    function N03TimeMutationSpecV1(id, field_path, source_locator, mutation_kind,
                                    mutated_value, expected_error, expected_resolution,
                                    expected_compile_calls, expected_provider_calls, expected_solver_calls)
        ec, ep, es = Int(expected_compile_calls), Int(expected_provider_calls), Int(expected_solver_calls)
        ec == 0 && ep == 0 && es == 0 || throw(ArgumentError("N03 mutations require zero execution calls"))
        Symbol(expected_resolution) in (:fail_closed, :terminal_deferred) ||
            throw(ArgumentError("N03 resolution metadata is invalid"))
        new(_n03_text(id, "N03 mutation id"), _n03_text(field_path, "N03 mutation field_path"),
            _n03_text(source_locator, "N03 mutation source_locator"), Symbol(mutation_kind), mutated_value,
            Symbol(expected_error), Symbol(expected_resolution), ec, ep, es)
    end
end

struct N03TimeMutationResultV1
    mutation_id::String
    input_hash::Digest256
    mutated_projection_hash::Digest256
    candidate_ref::QualifiedRefV1
    genome_ref::GenomeContractRef
    component_hash::Digest256
    schema_hash::Digest256
    canonicalization_hash::Digest256
    original_value::Any
    mutated_value::Any
    status::Symbol
    resolution::ResolutionStatus
    error_code::Symbol
    error_path::String
    detail::String
    authority_gap::String
    compile_calls::Int
    provider_calls::Int
    solver_calls::Int
end
semantic_view(x::N03TimeMutationResultV1) =
    (mutation_id=x.mutation_id, input_hash=x.input_hash,
     mutated_projection_hash=x.mutated_projection_hash, candidate_ref=x.candidate_ref,
     genome_ref=x.genome_ref, component_hash=x.component_hash, schema_hash=x.schema_hash,
     canonicalization_hash=x.canonicalization_hash, original_value=x.original_value,
     mutated_value=x.mutated_value, status=x.status, resolution=x.resolution,
     error_code=x.error_code, error_path=x.error_path, detail=x.detail,
     authority_gap=x.authority_gap, compile_calls=x.compile_calls,
     provider_calls=x.provider_calls, solver_calls=x.solver_calls)

function _n03_mutated_projection(projection, spec)
    i = findfirst(x -> x.field_path == spec.field_path, projection.declarations)
    i === nothing && throw(ArgumentError("N03 mutation path is not authoritative"))
    d = projection.declarations[i]
    d.source_locator == spec.source_locator || throw(ArgumentError("N03 source locator mismatch"))
    isequal(d.original_value, spec.mutated_value) && throw(ArgumentError("N03 mutation does not change source value"))
    rebuilt = ntuple(j -> j == i ? N03TimeDeclarationV1(d.id, d.field_path, d.source_locator,
        d.source_type, d.candidate_ref, d.genome_ref, d.component_hash, spec.mutated_value;
        authority_scope=d.authority_scope, authority_gap=d.authority_gap) : projection.declarations[j],
        length(projection.declarations))
    projection2 = N03TimeAuthorityProjectionV1(projection.candidate_ref, projection.package_hash,
        rebuilt, projection.gaps; g1_equation_temporal_kind=projection.g1_equation_temporal_kind,
        g1_operator_temporal_kinds=projection.g1_operator_temporal_kinds,
        g1_operator_max_derivative_order=projection.g1_operator_max_derivative_order)
    i, d, projection2
end

function _n03_counters(counter)
    counter === nothing && return (0, 0, 0)
    all(_n03_has(counter, x) for x in (:compile_calls, :provider_calls, :solver_calls)) ||
        throw(ArgumentError("N03 counter lacks execution fields"))
    c, p, s = Int(counter.compile_calls), Int(counter.provider_calls), Int(counter.solver_calls)
    c == 0 && p == 0 && s == 0 || throw(ArgumentError("N03 structural gate rejects nonzero execution counter"))
    (c, p, s)
end

"""Classify only the typed mutation and source-backed local authority."""
function n03_validate_mutation(projection::N03TimeAuthorityProjectionV1,
                               spec::N03TimeMutationSpecV1; counter=nothing)
    n03_projection_complete(projection) || throw(ArgumentError("N03 projection is incomplete"))
    c, p, s = _n03_counters(counter)
    i, original, mutated = _n03_mutated_projection(projection, spec)
    d = projection.declarations[i]
    status = :terminal_deferred; code = :time_basis_authority_gap
    gap = d.authority_gap; detail = "missing_candidate_bound_g3_event_time_basis_policy"
    if d.id == "N03-01"
        mutated_value = _n03_time_kind(spec.mutated_value, "N03-01 mutation")
        equation_kind = projection.g1_equation_temporal_kind
        mutated_value in (static_time, algebraic_time, differential_time, discrete_time, event_time) ||
            throw(ArgumentError("N03-01 mutation has unknown time kind"))
        # The operator whitelist is represented by the source declaration's gap-free local scope;
        # the focused test supplies a value outside the actual operator temporal_kinds.
        if !(mutated_value in projection.g1_operator_temporal_kinds)
            status = :fail_closed; code = :invalid_type; gap = ""; detail = "temporal_kind_not_supported: G1 equation temporal_kind/operator temporal_kinds mismatch"
        end
    elseif d.id == "N03-02"
        value = spec.mutated_value isa Integer ? Int(spec.mutated_value) : throw(ArgumentError("N03-02 requires integer"))
        value >= 0 || (status = :fail_closed; code = :invalid_type; gap = ""; detail = "derivative_order_negative: G1 derivative order is negative")
        value > projection.g1_operator_max_derivative_order && (status = :fail_closed; code = :invalid_type; gap = ""; detail = "derivative_order_exceeds_operator: G1 derivative order exceeds operator bound")
        status == :terminal_deferred && (code = :derivative_order_authority_gap; detail = "derivative mutation was not locally rejected")
    elseif d.id == "N03-03"
        value = spec.mutated_value isa Tuple ? spec.mutated_value : throw(ArgumentError("N03-03 requires a tuple"))
        original_kind = projection.g1_equation_temporal_kind
        original_kind in value || (status = :fail_closed; code = :invalid_type; gap = ""; detail = "temporal_kind_not_supported: G1 operator temporal_kinds excludes equation kind")
    elseif d.id == "N03-04"
        value = spec.mutated_value isa Symbol ? spec.mutated_value : Symbol(spec.mutated_value)
        value in (:initial, :scheduled, :fault, :threshold) || (status = :fail_closed; code = :invalid_type; gap = ""; detail = "event_trigger_invalid: G3 event trigger enum invalid")
    elseif d.id == "N03-05"
        value = spec.mutated_value isa Rational ? spec.mutated_value : throw(ArgumentError("N03-05 requires Rational"))
        value < 0 && (status = :fail_closed; code = :invalid_type; gap = ""; detail = "event_time_negative: G3 event time must be nonnegative")
    else
        throw(ArgumentError("unknown N03 declaration id"))
    end
    N03TimeMutationResultV1(spec.id, projection.projection_hash, mutated.projection_hash,
        d.candidate_ref, d.genome_ref, d.component_hash, d.schema_hash,
        d.canonicalization_hash, original.original_value, spec.mutated_value, status,
        terminal_deferred, code, d.field_path, detail, gap, c, p, s)
end
