"""Isolated manufactured ConditionalEGraph adapter for the frozen M5 lane.

This adapter is intentionally additive.  It consumes the frozen M5-A
manufactured composition and M5-B inverse-feedback product, constructs a
small typed rewrite catalog, and delegates graph construction, saturation,
canonicalization, replay, and equality queries to the existing P1 engine.
It does not modify the engine, the shared registry, or any candidate/provider
path.  Its only claim is synthetic e-graph equality at ``screen_only`` scope.
"""

# Keep this source independently includable from the package entry point.
if !isdefined(@__MODULE__, :ManufacturedInverseFeedbackV1)
    include(joinpath(@__DIR__, "ManufacturedInverseFeedbackV1.jl"))
end
if !isdefined(@__MODULE__, :ConditionalEGraphBudgetV1)
    if !isdefined(@__MODULE__, :_ccbw_new)
        include(joinpath(@__DIR__, "../../Canonical/ClosedCanonicalByteWriter.jl"))
    end
    if !isdefined(@__MODULE__, :CanonicalizationDeferred)
        include(joinpath(@__DIR__, "../../Canonical/CanonicalJSON.jl"))
    end
    if !isdefined(@__MODULE__, :CanonicalizationProfileV1)
        include(joinpath(@__DIR__, "../../Canonical/ExactGraphCanonicalization.jl"))
    end
    if !isdefined(@__MODULE__, :_typed_ast_program_json)
        include(joinpath(@__DIR__, "../../Canonical/TypedASTProgramCanonical.jl"))
    end
    include(joinpath(@__DIR__, "../../IR/ConditionalEGraph.jl"))
    include(joinpath(@__DIR__, "../../IR/ConditionalEGraphTypes.jl"))
    include(joinpath(@__DIR__, "../../Canonical/ConditionalEGraphCanonical.jl"))
    include(joinpath(@__DIR__, "../../IR/ConditionalEGraphSaturation.jl"))
end

const M5CEG_SCHEMA_V1 = "M5-MANUFACTURED-CONDITIONAL-EGRAPH-V1"
const M5CEG_CLAIM_CEILING_V1 = :synthetic_egraph_equality
const M5CEG_EVIDENCE_SCOPE_V1 = :screen_only
const M5CEG_CONDITION_KINDS_V1 =
    (:type, :rank, :domain, :unit, :port, :owner, :interface, :conservation)

# Frozen scope inputs.  These are source identities, not identities inferred
# from a mutable checkout.  The composition hash is checked against the
# supplied M5-A product; the M5-B inverse hash remains product-derived.
const M5CEG_M5A_SOURCE_SHA256_V1 =
    Digest256("284094e7781f41075915ab0f3b930e17e099e1fa45853218f2f639ea57e1a209")
const M5CEG_M5A_COMPOSITION_SHA256_V1 =
    Digest256("722e59e841d6551fe9001e1279266e1aaf5a798ca0d16625d5a4fd81a59ab694")
const M5CEG_M5B_SOURCE_SHA256_V1 =
    # Accepted-limited M5 inverse-feedback repair source (not M4-B residual).
    Digest256("477b5a41c1a021fae84aeebaf13e3967c93b001ace7f38746af1ab1212110e59")

struct ManufacturedConditionalEGraphFailureV1
    code::Symbol
    path::String
    detail::String
end

_m5ceg_failure(code::Symbol, path, detail) =
    ManufacturedConditionalEGraphFailureV1(code, String(path), String(detail))

"""Typed condition metadata retained beside the engine's closed requirement."""
struct ManufacturedConditionalEGraphConditionV1
    kind::Symbol
    requirement::EqualityConditionRequirementV1
    expected_hash::Digest256
end

function _m5ceg_condition(kind::Symbol, a, b)
    kind in M5CEG_CONDITION_KINDS_V1 ||
        throw(ArgumentError("unsupported manufactured e-graph condition kind"))
    # Include both upstream identities in every condition contract.  This
    # prevents a condition copied between manufactured products from passing.
    value = digest256_text(string("M5CEG|", kind, "|",
        manufactured_auto_composition_hash(a).value, "|",
        manufactured_inverse_feedback_hash(b).value))
    ref = QualifiedRefV1(string("M5CEG.condition.", kind), "v1")
    req = EqualityConditionRequirementV1(ref, value)
    ManufacturedConditionalEGraphConditionV1(kind, req, value)
end

struct ManufacturedConditionalEGraphV1
    schema::String
    source_program::TypedASTProgramV1
    source_program_hash::Digest256
    m5a_source_sha256::Digest256
    m5a_composition_hash::Digest256
    m5b_source_sha256::Digest256
    m5b_inverse_hash::Digest256
    owner_bindings::NamedTuple
    provenance_bindings::NamedTuple
    condition_catalog::Tuple{Vararg{ManufacturedConditionalEGraphConditionV1}}
    rewrite_set::ConditionalRewriteSetV1
    registry::OperatorRegistryV1
    budget::ConditionalEGraphBudgetV1
    profile::CanonicalizationProfileV1
    derivation::Union{Nothing,ConditionalEGraphDerivationResultV1}
    graph::Union{Nothing,DerivedConditionalEGraphV1}
    status::Symbol
    claim_ceiling::Symbol
    evidence_scope::Symbol
end

struct ManufacturedConditionalEGraphResultV1
    valid::Bool
    status::Symbol
    egraph::Union{Nothing,ManufacturedConditionalEGraphV1}
    failures::Tuple{Vararg{ManufacturedConditionalEGraphFailureV1}}
    claim_ceiling::Symbol
    evidence_scope::Symbol
end

const ManufacturedConditionalEGraphValidationV1 = ManufacturedConditionalEGraphResultV1

_m5ceg_failure_tuple(fs) = Tuple(ManufacturedConditionalEGraphFailureV1[f for f in fs])
_m5ceg_invalid(fs; status=:typed_failure) = ManufacturedConditionalEGraphResultV1(
    false, status, nothing, _m5ceg_failure_tuple(fs),
    M5CEG_CLAIM_CEILING_V1, M5CEG_EVIDENCE_SCOPE_V1)

function _m5ceg_unwrap_a(x)
    x isa ManufacturedAutoCompositionV1 && return x
    x isa ManufacturedAutoCompositionResultV1 && x.valid && x.composition !== nothing &&
        return x.composition
    nothing
end
function _m5ceg_unwrap_b(x)
    x isa ManufacturedInverseFeedbackV1 && return x
    x isa ManufacturedInverseFeedbackResultV1 && x.valid && x.inverse !== nothing &&
        return x.inverse
    nothing
end

function _m5ceg_hash(x)
    x isa Digest256 && return x
    digest256_text(String(x))
end

function _m5ceg_upstream_checks!(fs, a, b)
    a === nothing && push!(fs, _m5ceg_failure(:invalid_m5a, "M5-A",
        "expected a valid ManufacturedAutoCompositionV1"))
    b === nothing && push!(fs, _m5ceg_failure(:invalid_m5b, "M5-B",
        "expected a valid ManufacturedInverseFeedbackV1"))
    a === nothing || begin
        try
            validate_manufactured_auto_composition(a).valid ||
                push!(fs, _m5ceg_failure(:invalid_m5a, "M5-A.validation",
                    "M5-A validation failed"))
            a.source_hashes == M5A_SOURCE_SHA256_V1 ||
                push!(fs, _m5ceg_failure(:foreign_hash, "M5-A.source_hashes",
                    "M5-A source identities are not frozen"))
            manufactured_auto_composition_hash(a) == M5CEG_M5A_COMPOSITION_SHA256_V1 ||
                push!(fs, _m5ceg_failure(:foreign_hash, "M5-A.composition_hash",
                    "M5-A composition hash does not match the frozen scope"))
        catch err
            push!(fs, _m5ceg_failure(:invalid_m5a, "M5-A",
                sprint(showerror, err)))
        end
    end
    b === nothing || begin
        try
            validate_inverse(b).valid ||
                push!(fs, _m5ceg_failure(:invalid_m5b, "M5-B.validation",
                    "M5-B validation failed"))
            b.m5a_source_sha256 == M5CEG_M5A_SOURCE_SHA256_V1 ||
                push!(fs, _m5ceg_failure(:foreign_hash, "M5-B.m5a_source_sha256",
                    "M5-B is not bound to frozen M5-A"))
            b.m5a_composition_hash == M5CEG_M5A_COMPOSITION_SHA256_V1 ||
                push!(fs, _m5ceg_failure(:foreign_hash, "M5-B.m5a_composition_hash",
                    "M5-B inverse receipt has a foreign M5-A composition hash"))
            b.claim_ceiling == M5I_CLAIM_CEILING_V1 &&
                b.evidence_scope == M5I_EVIDENCE_SCOPE_V1 ||
                push!(fs, _m5ceg_failure(:foreign_provenance, "M5-B.scope",
                    "M5-B must remain manufactured/screen_only"))
        catch err
            push!(fs, _m5ceg_failure(:invalid_m5b, "M5-B",
                sprint(showerror, err)))
        end
    end
    a === nothing || b === nothing || begin
        b.m5a_upstream === a || push!(fs, _m5ceg_failure(:foreign_hash,
            "M5-A/M5-B.join", "M5-B does not retain the supplied M5-A object"))
        b.owner_bindings == _m5ceg_owner_projection(a, b) ||
            push!(fs, _m5ceg_failure(:foreign_owner, "M5-B.owner_bindings",
                "owner binding ledger is not the retained M5-B projection"))
        b.provenance_bindings == _m5ceg_provenance_projection(a, b) ||
            push!(fs, _m5ceg_failure(:foreign_provenance, "M5-B.provenance_bindings",
                "provenance ledger is not the retained M5-B projection"))
    end
    nothing
end

_m5ceg_owner_projection(a, b) = b.owner_bindings
_m5ceg_provenance_projection(a, b) = b.provenance_bindings

function _m5ceg_condition_catalog(a, b)
    Tuple(_m5ceg_condition(k, a, b) for k in M5CEG_CONDITION_KINDS_V1)
end

function _m5ceg_requirements(catalog)
    cs = Tuple(catalog)
    length(cs) == length(M5CEG_CONDITION_KINDS_V1) ||
        throw(ArgumentError("manufactured e-graph requires eight typed conditions"))
    seen = Symbol[]
    req = EqualityConditionRequirementV1[]
    for c in cs
        c isa ManufacturedConditionalEGraphConditionV1 ||
            throw(ArgumentError("condition catalog contains an untyped value"))
        c.kind in M5CEG_CONDITION_KINDS_V1 ||
            throw(ArgumentError("condition catalog contains an unsupported kind"))
        c.kind in seen && throw(ArgumentError("condition catalog contains duplicate kinds"))
        push!(seen, c.kind)
        c.requirement.condition_contract_hash == c.expected_hash ||
            throw(ArgumentError("condition contract hash does not match expected hash"))
        push!(req, c.requirement)
    end
    all(k -> k in seen, M5CEG_CONDITION_KINDS_V1) ||
        throw(ArgumentError("condition catalog is missing a typed condition"))
    Tuple(req)
end

function _m5ceg_catalog_matches(catalog, a, b)
    expected = _m5ceg_condition_catalog(a, b)
    actual = Tuple(catalog)
    length(actual) == length(expected) || return false
    for i in eachindex(expected)
        left, right = expected[i], actual[i]
        left.kind == right.kind || return false
        _ceg_ref_equal(left.requirement.condition_ref, right.requirement.condition_ref) || return false
        left.expected_hash == right.expected_hash || return false
        left.requirement.condition_contract_hash == right.requirement.condition_contract_hash || return false
    end
    true
end

function _m5ceg_rhs(source::TypedASTProgramV1; registry::OperatorRegistryV1)
    nodes = getfield(source, :nodes)
    ports = getfield(source, :input_ports)
    fieldcount(typeof(ports)) == 3 && fieldcount(typeof(nodes)) == 8 ||
        throw(ArgumentError("frozen M5-A canonical program shape is required"))
    all(typeof(getfield(nodes, i)) === ASTInputV1 for i in 1:3) ||
        throw(ArgumentError("M5-A canonical inputs are not typed AST inputs"))
    t1, t2, t3 = (getfield(getfield(nodes, i), :output_type) for i in 1:3)
    add = OperatorRefV1("ADD", "v1")
    neg = OperatorRefV1("NEG", "v1")
    n4 = ASTApplyV1(add, (1, 3), (;); registry=registry, input_types=(t1, t3))
    n5 = ASTApplyV1(add, (4, 2), (;); registry=registry,
        input_types=(getfield(n4, :output_type), t2))
    n6 = ASTApplyV1(neg, (5,), (;); registry=registry,
        input_types=(getfield(n5, :output_type),))
    n7 = ASTApplyV1(neg, (6,), (;); registry=registry,
        input_types=(getfield(n6, :output_type),))
    n8 = ASTApplyV1(OperatorRefV1("IDENTITY", "v1"), (7,), (;);
        registry=registry, input_types=(getfield(n7, :output_type),))
    TypedASTProgramV1((getfield(nodes, 1), getfield(nodes, 2), getfield(nodes, 3),
        n4, n5, n6, n7, n8), getfield(source, :roots), getfield(source, :input_ports), registry)
end

function _m5ceg_rewrite_set(source, catalog; registry::OperatorRegistryV1)
    req = _m5ceg_requirements(catalog)
    rhs = _m5ceg_rhs(source; registry=registry)
    checker = QualifiedRefV1("M5CEG.synthetic.condition.checker", "v1")
    checker_hash = digest256_text("M5CEG|typed-condition-checker|v1")
    rules = WholeProgramConditionalRewriteV1[]
    push!(rules, WholeProgramConditionalRewriteV1(
        QualifiedRefV1("M5CEG.reassociate_add", "v1"), source, rhs,
        req, checker, checker_hash; registry=registry))
    # A second orientation-changing root order is deliberately tiny and
    # remains within the same typed interface.  It is still synthetic.
    reordered = TypedASTProgramV1(getfield(source, :nodes),
        reverse(getfield(source, :roots)), getfield(source, :input_ports), registry)
    push!(rules, WholeProgramConditionalRewriteV1(
        QualifiedRefV1("M5CEG.root_order", "v1"), source, reordered,
        req, checker, checker_hash; registry=registry))
    ConditionalRewriteSetV1(Tuple(rules))
end

function _m5ceg_build(a, b; registry=nothing,
        budget::ConditionalEGraphBudgetV1=ConditionalEGraphBudgetV1(),
        profile::CanonicalizationProfileV1=default_canonicalization_profile(),
        condition_catalog=nothing)
    registry_obj = registry === nothing ? default_operator_registry() : registry
    registry_obj isa OperatorRegistryV1 || throw(ArgumentError("registry must be OperatorRegistryV1"))
    catalog = condition_catalog === nothing ? _m5ceg_condition_catalog(a, b) : Tuple(condition_catalog)
    source = a.canonical_program
    source_hash = invoke(_ceg_program_hash, Tuple{TypedASTProgramV1}, source)
    rules = _m5ceg_rewrite_set(source, catalog; registry=registry_obj)
    derivation = derive_conditional_program_egraph(source, rules, registry_obj;
        saturation_budget=budget, canonicalization_profile=profile)
    graph = derivation.artifact
    status = graph === nothing ? :terminal_deferred :
        (graph.complete ? :valid : :terminal_deferred)
    inverse_hash = manufactured_inverse_feedback_hash(b)
    ManufacturedConditionalEGraphV1(M5CEG_SCHEMA_V1, source, source_hash,
        M5CEG_M5A_SOURCE_SHA256_V1, M5CEG_M5A_COMPOSITION_SHA256_V1,
        M5CEG_M5B_SOURCE_SHA256_V1, inverse_hash, b.owner_bindings,
        b.provenance_bindings, catalog, rules, registry_obj, budget, profile,
        derivation, graph, status, M5CEG_CLAIM_CEILING_V1,
        M5CEG_EVIDENCE_SCOPE_V1)
end

function build_manufactured_conditional_egraph(a_input, b_input;
        registry=nothing, budget=ConditionalEGraphBudgetV1(),
        profile=default_canonicalization_profile(), condition_catalog=nothing)
    a, b = _m5ceg_unwrap_a(a_input), _m5ceg_unwrap_b(b_input)
    fs = ManufacturedConditionalEGraphFailureV1[]
    _m5ceg_upstream_checks!(fs, a, b)
    isempty(fs) || return _m5ceg_invalid(fs; status=:fail_closed)
    budget isa ConditionalEGraphBudgetV1 ||
        push!(fs, _m5ceg_failure(:invalid_budget, "budget", "budget is not typed"))
    profile isa CanonicalizationProfileV1 ||
        push!(fs, _m5ceg_failure(:invalid_profile, "profile", "profile is not typed"))
    if condition_catalog !== nothing
        try
            _m5ceg_requirements(condition_catalog)
            _m5ceg_catalog_matches(condition_catalog, a, b) ||
                push!(fs, _m5ceg_failure(:condition_rejected, "conditions",
                    "condition catalog is not bound to the supplied M5-A/M5-B identities"))
        catch err
            push!(fs, _m5ceg_failure(:condition_rejected, "conditions",
                sprint(showerror, err)))
        end
    end
    isempty(fs) || return _m5ceg_invalid(fs; status=:fail_closed)
    try
        product = _m5ceg_build(a, b; registry=registry, budget=budget,
            profile=profile, condition_catalog=condition_catalog)
        checked = validate_manufactured_conditional_egraph(product)
        checked.valid ? checked : ManufacturedConditionalEGraphResultV1(
            false, checked.status, product, checked.failures,
            M5CEG_CLAIM_CEILING_V1, M5CEG_EVIDENCE_SCOPE_V1)
    catch err
        _m5ceg_invalid([_m5ceg_failure(:fail_closed, "construction",
            sprint(showerror, err))]; status=:fail_closed)
    end
end

function saturate_manufactured_conditional_egraph(x::ManufacturedConditionalEGraphV1;
        budget=x.budget)
    budget isa ConditionalEGraphBudgetV1 || throw(ArgumentError("budget must be typed"))
    # Build already performs one bounded saturation.  This operation is a
    # receipt-preserving idempotent view; no second engine is introduced here.
    x
end
saturate_manufactured_conditional_egraph(x::ManufacturedConditionalEGraphResultV1; kwargs...) =
    x.egraph === nothing ? x : saturate_manufactured_conditional_egraph(x.egraph; kwargs...)
saturate_manufactured_conditional_egraph(a_input, b_input; kwargs...) =
    build_manufactured_conditional_egraph(a_input, b_input; kwargs...)

function replay_manufactured_conditional_egraph(x::ManufacturedConditionalEGraphV1,
        target::TypedASTProgramV1, provenance::ConditionalEqualityProvenanceV1)
    replay_conditional_rewrite_trace(x.source_program, target, x.rewrite_set,
        x.registry, provenance)
end
replay_manufactured_conditional_egraph(x::ManufacturedConditionalEGraphResultV1,
        target::TypedASTProgramV1, provenance::ConditionalEqualityProvenanceV1) =
    x.egraph === nothing ? false : replay_manufactured_conditional_egraph(x.egraph, target, provenance)
function replay_manufactured_conditional_egraph(x::ManufacturedConditionalEGraphV1,
        target::TypedASTProgramV1)
    result = query_manufactured_conditional_equality(x, target)
    result === nothing || result.provenance === nothing ? false :
        replay_manufactured_conditional_egraph(x, target, result.provenance)
end
replay_manufactured_conditional_egraph(x::ManufacturedConditionalEGraphResultV1,
        target::TypedASTProgramV1) =
    x.egraph === nothing ? false : replay_manufactured_conditional_egraph(x.egraph, target)

function query_manufactured_conditional_equality(x::ManufacturedConditionalEGraphV1,
        target::TypedASTProgramV1)
    x.graph === nothing ? nothing : query_conditional_equality(x.graph, target)
end
query_manufactured_conditional_equality(x::ManufacturedConditionalEGraphResultV1,
        target::TypedASTProgramV1) =
    x.egraph === nothing ? nothing : query_manufactured_conditional_equality(x.egraph, target)

function validate_manufactured_conditional_egraph(x::ManufacturedConditionalEGraphV1)
    fs = ManufacturedConditionalEGraphFailureV1[]
    x.schema == M5CEG_SCHEMA_V1 || push!(fs, _m5ceg_failure(:foreign_identity, "schema", "schema is foreign"))
    x.claim_ceiling == M5CEG_CLAIM_CEILING_V1 && x.evidence_scope == M5CEG_EVIDENCE_SCOPE_V1 ||
        push!(fs, _m5ceg_failure(:foreign_provenance, "scope", "claim ceiling is not synthetic/screen_only"))
    try
        _ceg_digest_equal(x.source_program_hash, _ceg_program_hash(x.source_program)) ||
            push!(fs, _m5ceg_failure(:foreign_hash, "source_program_hash", "source hash does not replay"))
        x.m5a_source_sha256 == M5CEG_M5A_SOURCE_SHA256_V1 ||
            push!(fs, _m5ceg_failure(:foreign_hash, "m5a_source_sha256", "M5-A source hash is foreign"))
        x.m5a_composition_hash == M5CEG_M5A_COMPOSITION_SHA256_V1 ||
            push!(fs, _m5ceg_failure(:foreign_hash, "m5a_composition_hash", "M5-A composition hash is foreign"))
        x.m5b_source_sha256 == M5CEG_M5B_SOURCE_SHA256_V1 ||
            push!(fs, _m5ceg_failure(:foreign_hash, "m5b_source_sha256", "M5-B source hash is foreign"))
        _m5ceg_requirements(x.condition_catalog)
        x.graph === nothing && x.derivation === nothing &&
            push!(fs, _m5ceg_failure(:missing_derivation, "derivation", "no derivation receipt retained"))
        if x.graph === nothing
            x.status == :terminal_deferred || push!(fs, _m5ceg_failure(
                :status_mismatch, "status", "an absent graph must be terminal_deferred"))
        else
            x.graph.source_hash == x.source_program_hash ||
                push!(fs, _m5ceg_failure(:foreign_hash, "graph.source_hash", "graph source hash is foreign"))
            status_ok = x.graph.complete ? (x.status == :valid) :
                (x.status == :terminal_deferred)
            status_ok || push!(fs, _m5ceg_failure(:status_mismatch, "status", "graph completeness and status are inconsistent"))
        end
    catch err
        push!(fs, _m5ceg_failure(:fail_closed, "validation", sprint(showerror, err)))
    end
    ManufacturedConditionalEGraphResultV1(isempty(fs), isempty(fs) ? x.status : :typed_failure,
        x, _m5ceg_failure_tuple(fs), M5CEG_CLAIM_CEILING_V1, M5CEG_EVIDENCE_SCOPE_V1)
end
validate_manufactured_conditional_egraph(x::ManufacturedConditionalEGraphResultV1) =
    x.egraph === nothing ? x : validate_manufactured_conditional_egraph(x.egraph)
validate_manufactured_conditional_egraph(x) = _m5ceg_invalid([_m5ceg_failure(
    :invalid_input, "input", "expected ManufacturedConditionalEGraphV1")]; status=:fail_closed)

function manufactured_conditional_egraph_payload(x::ManufacturedConditionalEGraphV1)
    (schema=x.schema, source_program=invoke(_typed_ast_program_json,
        Tuple{TypedASTProgramV1}, x.source_program), source_program_hash=x.source_program_hash,
     m5a_source_sha256=x.m5a_source_sha256, m5a_composition_hash=x.m5a_composition_hash,
     m5b_source_sha256=x.m5b_source_sha256, m5b_inverse_hash=x.m5b_inverse_hash,
     owners=x.owner_bindings, provenance=x.provenance_bindings,
     conditions=Tuple((kind=c.kind, requirement=c.requirement,
        expected_hash=c.expected_hash) for c in x.condition_catalog),
     rewrite_set=canonical_json(x.rewrite_set), budget=x.budget, profile=x.profile,
     derivation=x.derivation === nothing ? nothing : canonical_json(x.derivation),
     graph=x.graph === nothing ? nothing : canonical_json(x.graph), status=x.status,
     claim_ceiling=x.claim_ceiling, evidence_scope=x.evidence_scope)
end
manufactured_conditional_egraph_payload(x) =
    (schema=M5CEG_SCHEMA_V1, status=:typed_failure, input_type=typeof(x))

function manufactured_conditional_egraph_hash(x::ManufacturedConditionalEGraphV1)
    p = manufactured_conditional_egraph_payload(x)
    bytes = try
        canonical_json(p)
    catch
        try
            invoke(_tac_value_string, Tuple{Any}, p)
        catch
            repr(p)
        end
    end
    digest256_text(bytes)
end
manufactured_conditional_egraph_hash(x) = digest256_text(
    string(manufactured_conditional_egraph_payload(x)))

is_valid_manufactured_conditional_egraph(x::ManufacturedConditionalEGraphV1) =
    validate_manufactured_conditional_egraph(x).valid
is_valid_manufactured_conditional_egraph(x::ManufacturedConditionalEGraphResultV1) = x.valid
is_valid_manufactured_conditional_egraph(x) = false

const build_manufactured_conditional_egraph_v1 = build_manufactured_conditional_egraph
const manufactured_conditional_egraph = build_manufactured_conditional_egraph
const validate_manufactured_conditional_egraph_v1 = validate_manufactured_conditional_egraph
const manufactured_conditional_egraph_payload_v1 = manufactured_conditional_egraph_payload
const manufactured_conditional_egraph_hash_v1 = manufactured_conditional_egraph_hash
const is_valid_manufactured_conditional_egraph_v1 = is_valid_manufactured_conditional_egraph
if !isdefined(@__MODULE__, :build_conditional_egraph)
    const build_conditional_egraph = build_manufactured_conditional_egraph
end
if !isdefined(@__MODULE__, :saturate_conditional_egraph)
    const saturate_conditional_egraph = saturate_manufactured_conditional_egraph
end
if !isdefined(@__MODULE__, :replay_conditional_egraph)
    const replay_conditional_egraph = replay_manufactured_conditional_egraph
end
if !isdefined(@__MODULE__, :query_conditional_egraph)
    const query_conditional_egraph = query_manufactured_conditional_equality
end
if !isdefined(@__MODULE__, :validate)
    const validate = validate_manufactured_conditional_egraph
end
if !isdefined(@__MODULE__, :payload)
    const payload = manufactured_conditional_egraph_payload
end
if !isdefined(@__MODULE__, :is_valid)
    const is_valid = is_valid_manufactured_conditional_egraph
end
