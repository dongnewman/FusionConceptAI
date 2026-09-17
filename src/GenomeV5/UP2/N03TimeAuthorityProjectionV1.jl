"""Candidate-bound, contract-only N03 time authority projection.

The five rows are projected from an actual CandidateStatePackageV5.  G1 checks
are local equation/operator checks.  G3 event values are locally typed, but a
cross-layer time-basis policy is deliberately absent in this revision and is
therefore reported as an explicit terminal gap.  No compiler, provider, mesh,
or solver is called here.
"""

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
