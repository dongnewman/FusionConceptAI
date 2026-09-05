"""Strong, local G1 mechanism gene records."""

function _g1_gene_tuple(value::Any, field::String)
    value isa Tuple || throw(ArgumentError("$field must be an immutable tuple"))
    value
end

_g1_gene_rational(value::Any, field::String) =
    invoke(_gene_rational, Tuple{Any,Any}, value, field)

_g1_ref_key(value::QualifiedRefV1) = (value.id, value.version)

function _g1_local_ref_key(value::Any)
    value isa StateGeneRefV1 && return value.value
    value isa InvariantRefV1 && return value.value
    value isa ParameterRefV1 && return value.value
    value isa SymmetryRefV1 && return value.value
    value isa ObservableRefV1 && return value.value
    value isa OperatorSiteRefV1 && return value.value
    value isa ConstraintRefV1 && return value.value
    value isa HoleRefV1 && return value.value
    throw(ArgumentError("unsupported G1 local reference"))
end

function _g1_require_tuple_type(value::Any, T::Type, field::String)
    tuple = invoke(_g1_gene_tuple, Tuple{Any,String}, value, field)
    all(item -> typeof(item) === T, tuple) || throw(ArgumentError("$field contains an invalid value"))
    tuple
end

function _g1_unique_keys(values::Tuple, field::String, key::Function=_g1_local_ref_key)
    keys = Any[key(value) for value in values]
    length(unique(keys)) == length(keys) || throw(ArgumentError("$field contains duplicate references"))
    values
end

struct StateGeneV1
    state_ref::StateGeneRefV1
    physical_type::PhysicalType
    physical_bounds::QuantityIntervalV1
    parity_actions::Tuple
    gauge_refs::Tuple
    constraint_refs::Tuple
    epistemic_state::StateEpistemicV1
    function StateGeneV1(state_ref::Any, physical_type::Any, physical_bounds::Any,
                         parity_actions::Any, gauge_refs::Any, constraint_refs::Any,
                         epistemic_state::Any)
        state_ref isa StateGeneRefV1 || throw(ArgumentError("state_ref must be StateGeneRefV1"))
        physical_type isa PhysicalType || throw(ArgumentError("physical_type must be PhysicalType"))
        physical_bounds isa QuantityIntervalV1 || throw(ArgumentError("physical_bounds must be QuantityIntervalV1"))
        physical_bounds.unit == physical_type.units || throw(ArgumentError("physical bounds unit must match physical_type units"))
        parity = invoke(_g1_require_tuple_type, Tuple{Any,Type,String}, parity_actions, ParityActionV1, "parity_actions")
        gauges = invoke(_g1_require_tuple_type, Tuple{Any,Type,String}, gauge_refs, SymmetryRefV1, "gauge_refs")
        constraints = invoke(_g1_require_tuple_type, Tuple{Any,Type,String}, constraint_refs, ConstraintRefV1, "constraint_refs")
        invoke(_g1_unique_keys, Tuple{Tuple,String,Function}, parity, "parity_actions", action -> invoke(_g1_ref_key, Tuple{QualifiedRefV1}, action.generator_ref))
        invoke(_g1_unique_keys, Tuple{Tuple,String,Function}, gauges, "gauge_refs", value -> invoke(_g1_local_ref_key, Tuple{Any}, value))
        invoke(_g1_unique_keys, Tuple{Tuple,String,Function}, constraints, "constraint_refs", value -> invoke(_g1_local_ref_key, Tuple{Any}, value))
        isempty(intersect(Set(x.value for x in gauges), Set(x.value for x in constraints))) ||
            throw(ArgumentError("gauge and constraint references must not overlap"))
        epistemic_state isa StateEpistemicV1 || throw(ArgumentError("invalid epistemic_state"))
        new(state_ref, physical_type, physical_bounds, parity, gauges, constraints, epistemic_state)
    end
end

struct InvariantTermV1
    state_ref::StateGeneRefV1
    coefficient::Rational{Int64}
    function InvariantTermV1(state_ref::Any, coefficient::Any)
        state_ref isa StateGeneRefV1 || throw(ArgumentError("invariant term state_ref must be StateGeneRefV1"))
        value = invoke(_g1_gene_rational, Tuple{Any,String}, coefficient, "invariant term coefficient")
        value != 0 || throw(ArgumentError("invariant term coefficient cannot be zero"))
        new(state_ref, value)
    end
end

struct InvariantV1
    invariant_ref::InvariantRefV1
    ledger_identity::ConservationLedgerIdentityV1
    scope::ConservationInvariantScopeV1
    terms::Tuple
    owned_ledger_occurrence_refs::Tuple{Vararg{ConservationLedgerOccurrenceRefV1}}
    tolerance_log10::Int16
    entropy_direction::EntropyDirectionV1
    function InvariantV1(invariant_ref::Any, ledger_identity::Any, scope::Any,
                        terms::Any, owned_ledger_occurrence_refs::Any,
                        tolerance_log10::Any, entropy_direction::Any)
        invariant_ref isa InvariantRefV1 || throw(ArgumentError("invariant_ref must be InvariantRefV1"))
        typeof(ledger_identity) === ConservationLedgerIdentityV1 ||
            throw(ArgumentError("ledger_identity must be exactly ConservationLedgerIdentityV1"))
        scope_type = typeof(scope)
        scope_type in (GlobalConservationScopeV1, DomainConservationScopeV1, InterfaceConservationScopeV1) ||
            throw(ArgumentError("scope must be exactly one sealed conservation scope type"))
        term_tuple = invoke(_g1_require_tuple_type, Tuple{Any,Type,String}, terms, InvariantTermV1, "terms")
        isempty(term_tuple) && throw(ArgumentError("invariant terms cannot be empty"))
        invoke(_g1_unique_keys, Tuple{Tuple,String,Function}, term_tuple, "terms", term -> term.state_ref.value)
        occurrence_tuple = invoke(_g1_require_tuple_type, Tuple{Any,Type,String}, owned_ledger_occurrence_refs,
            ConservationLedgerOccurrenceRefV1, "owned_ledger_occurrence_refs")
        keys = Tuple[invoke(_g1_occurrence_key, Tuple{ConservationLedgerOccurrenceRefV1}, value) for value in occurrence_tuple]
        length(unique(keys)) == length(keys) || throw(ArgumentError("owned ledger occurrence references must be unique"))
        all(_ledger_identity_full_key(getfield(value, :ledger_identity)) == _ledger_identity_full_key(ledger_identity)
            for value in occurrence_tuple) || throw(ArgumentError("owned occurrence ledger identity differs from invariant ledger identity"))
        tolerance_type = typeof(tolerance_log10)
        tolerance_type in (Int8, Int16, Int32, Int64, UInt8, UInt16, UInt32, UInt64) || throw(ArgumentError("tolerance_log10 must be a fixed-width integer"))
        if tolerance_type <: Signed
            typemin(Int16) <= tolerance_log10 <= typemax(Int16) ||
                throw(ArgumentError("tolerance_log10 is outside Int16 range"))
        else
            tolerance_log10 <= typemax(Int16) || throw(ArgumentError("tolerance_log10 is outside Int16 range"))
        end
        tolerance = Int16(tolerance_log10)
        tolerance <= 0 || throw(ArgumentError("tolerance_log10 must be non-positive"))
        entropy_direction isa EntropyDirectionV1 || throw(ArgumentError("invalid entropy_direction"))
        new(invariant_ref, ledger_identity, scope, term_tuple, occurrence_tuple, tolerance, entropy_direction)
    end
end
struct ParameterTransformSpecV1
    kind::ParameterTransformKindV1
    scale::Union{Nothing,NonnegativeQuantityV1}
    function ParameterTransformSpecV1(kind::Any, scale::Any)
        kind isa ParameterTransformKindV1 || throw(ArgumentError("kind must be ParameterTransformKindV1"))
        scale === nothing || scale isa NonnegativeQuantityV1 || throw(ArgumentError("scale must be NonnegativeQuantityV1 or nothing"))
        if kind in (transform_linear, transform_log)
            scale === nothing || throw(ArgumentError("linear/log transform cannot carry a scale"))
        elseif kind == transform_signed_log
            scale !== nothing && scale.value > 0 || throw(ArgumentError("signed_log requires a strictly positive scale"))
        else
            throw(ArgumentError("unknown parameter transform kind"))
        end
        new(kind, scale)
    end
end

ParameterTransformSpecV1(kind::Any) = ParameterTransformSpecV1(kind, nothing)

function _g1_finite_float(value::Any, field::String)
    value_type = typeof(value)
    value_type in (Int8, Int16, Int32, Int64, Int128, UInt8, UInt16, UInt32, UInt64, UInt128,
                   Float16, Float32, Float64, Rational{Int64}) || throw(ArgumentError("$field requires a fixed-width finite numeric value"))
    converted = try Float64(value) catch; throw(ArgumentError("$field cannot be converted to Float64")) end
    isfinite(converted) || throw(ArgumentError("$field must be finite after Float64 conversion"))
    converted == 0.0 ? 0.0 : converted
end

struct ParameterGeneV1
    ref::ParameterRefV1
    unit::UnitSignature
    transform::ParameterTransformSpecV1
    bounds::QuantityIntervalV1
    normalized_gene::Float64
    function ParameterGeneV1(ref::Any, unit::Any, transform::Any, bounds::Any, normalized_gene::Any)
        ref isa ParameterRefV1 || throw(ArgumentError("ref must be ParameterRefV1"))
        unit isa UnitSignature || throw(ArgumentError("unit must be UnitSignature"))
        transform isa ParameterTransformSpecV1 || throw(ArgumentError("transform must be ParameterTransformSpecV1"))
        bounds isa QuantityIntervalV1 || throw(ArgumentError("bounds must be QuantityIntervalV1"))
        bounds.unit == unit || throw(ArgumentError("parameter bounds unit must match parameter unit"))
        bounds.interval.lower < bounds.interval.upper || throw(ArgumentError("parameter bounds must be strictly ordered"))
        transform.kind == transform_log && bounds.interval.lower > 0 || transform.kind != transform_log || throw(ArgumentError("log parameter bounds must be positive"))
        transform.kind == transform_signed_log && transform.scale.unit == unit || transform.kind != transform_signed_log || throw(ArgumentError("signed_log scale unit must match parameter unit"))
        normalized = invoke(_g1_finite_float, Tuple{Any,String}, normalized_gene, "normalized_gene")
        -1.0 <= normalized <= 1.0 || throw(ArgumentError("normalized_gene must lie in [-1,1]"))
        new(ref, unit, transform, bounds, normalized)
    end
end

function _g1_matrix_shape(matrix::ExactRationalMatrixV1)
    rows = matrix.rows
    n = length(rows); n > 0 || throw(ArgumentError("matrix must be non-empty"))
    m = length(first(rows)); m > 0 || throw(ArgumentError("matrix rows must be non-empty"))
    all(length(row) == m for row in rows) || throw(ArgumentError("matrix must be rectangular"))
    (n, m)
end

function _g1_square_matrix(matrix::Any, field::String)
    matrix isa ExactRationalMatrixV1 || throw(ArgumentError("$field must be ExactRationalMatrixV1"))
    shape = _g1_matrix_shape(matrix); shape[1] == shape[2] || throw(ArgumentError("$field must be square")); matrix
end

function _g1_identity_matrix(n::Int)
    n > 0 || throw(ArgumentError("matrix dimension must be positive"))
    ExactRationalMatrixV1(ntuple(i -> ntuple(j -> i == j ? (1 // 1) : (0 // 1), n), n))
end

function _g1_matrix_multiply(left::ExactRationalMatrixV1, right::ExactRationalMatrixV1)
    n, inner = _g1_matrix_shape(left); inner_right, m = _g1_matrix_shape(right)
    inner == inner_right || throw(ArgumentError("matrix dimensions are incompatible"))
    rows = try
        ntuple(i -> ntuple(j -> begin
            total = 0 // 1
            for k in 1:inner
                total = total + left.rows[i][k] * right.rows[k][j]
                typeof(total) === Rational{Int64} || throw(ArgumentError("matrix rational overflow"))
            end
            total
        end, m), n)
    catch error
        error isa ArgumentError && rethrow(); throw(ArgumentError("matrix multiplication overflow"))
    end
    ExactRationalMatrixV1(rows)
end

function _g1_matrix_power(matrix::ExactRationalMatrixV1, exponent::UInt32)
    n, m = _g1_matrix_shape(matrix); n == m || throw(ArgumentError("matrix power requires a square matrix"))
    result = _g1_identity_matrix(n); base = matrix; power = UInt64(exponent)
    while power > 0
        isodd(power) && (result = _g1_matrix_multiply(result, base))
        power >>= 1
        power > 0 && (base = _g1_matrix_multiply(base, base))
    end
    result
end

function _g1_is_identity(matrix::ExactRationalMatrixV1)
    n, m = _g1_matrix_shape(matrix); n == m || return false
    all(matrix.rows[i][j] == (i == j ? (1 // 1) : (0 // 1)) for i in 1:n, j in 1:n)
end

struct StateSymmetryActionV1
    state_ref::StateGeneRefV1
    matrix::ExactRationalMatrixV1
    function StateSymmetryActionV1(state_ref::Any, matrix::Any)
        state_ref isa StateGeneRefV1 || throw(ArgumentError("state_ref must be StateGeneRefV1"))
        invoke(_g1_square_matrix, Tuple{Any,String}, matrix, "state symmetry action matrix")
        new(state_ref, matrix)
    end
end

struct SymmetryGeneV1
    ref::SymmetryRefV1
    generator_ref::QualifiedRefV1
    group_kind::SymmetryGroupKindV1
    coordinate_generator_matrix::ExactRationalMatrixV1
    state_actions::Tuple
    group_order::Union{Nothing,UInt32}
    behavior::SymmetryBehaviorV1
    tolerance::Rational{Int64}
    function SymmetryGeneV1(ref::Any, generator_ref::Any, group_kind::Any, coordinate_generator_matrix::Any,
                            state_actions::Any, group_order::Any, behavior::Any, tolerance::Any)
        ref isa SymmetryRefV1 || throw(ArgumentError("ref must be SymmetryRefV1"))
        generator_ref isa QualifiedRefV1 || throw(ArgumentError("generator_ref must be QualifiedRefV1"))
        group_kind isa SymmetryGroupKindV1 || throw(ArgumentError("group_kind must be SymmetryGroupKindV1"))
        coordinate = invoke(_g1_square_matrix, Tuple{Any,String}, coordinate_generator_matrix, "coordinate_generator_matrix")
        n, _ = _g1_matrix_shape(coordinate)
        actions = invoke(_g1_require_tuple_type, Tuple{Any,Type,String}, state_actions, StateSymmetryActionV1, "state_actions")
        invoke(_g1_unique_keys, Tuple{Tuple,String,Function}, actions, "state_actions", action -> action.state_ref.value)
        all(_g1_matrix_shape(action.matrix) == (n, n) for action in actions) || throw(ArgumentError("state action matrix dimensions must match coordinate matrix"))
        order = nothing
        if group_kind == symmetry_discrete
            order_type = typeof(group_order)
            order_type in (UInt8, UInt16, UInt32, Int8, Int16, Int32, Int64) || throw(ArgumentError("discrete group_order must be a fixed-width integer"))
            group_order isa Signed && group_order < 0 && throw(ArgumentError("group_order cannot be negative"))
            order_value = UInt64(group_order)
            order_value >= 2 && order_value <= typemax(UInt32) || throw(ArgumentError("discrete group_order must be at least 2 and fit UInt32"))
            order = UInt32(order_value)
            _g1_is_identity(_g1_matrix_power(coordinate, order)) || throw(ArgumentError("coordinate generator does not satisfy group order"))
            all(_g1_is_identity(_g1_matrix_power(action.matrix, order)) for action in actions) || throw(ArgumentError("state action does not satisfy group order"))
        elseif group_kind == symmetry_continuous
            group_order === nothing || throw(ArgumentError("continuous symmetry requires group_order=nothing"))
        else
            throw(ArgumentError("unknown symmetry group kind"))
        end
        tolerance_value = invoke(_g1_gene_rational, Tuple{Any,String}, tolerance, "symmetry tolerance")
        tolerance_value >= 0 || throw(ArgumentError("symmetry tolerance must be non-negative"))
        behavior isa SymmetryBehaviorV1 || throw(ArgumentError("invalid symmetry behavior"))
        new(ref, generator_ref, group_kind, coordinate, actions, order, behavior, tolerance_value)
    end
end

function _g1_derive_parameter_value_sealed(gene::ParameterGeneV1, normalized_gene::Any)
    z = invoke(_g1_finite_float, Tuple{Any,String}, normalized_gene, "normalized_gene")
    -1.0 <= z <= 1.0 || throw(ArgumentError("normalized_gene must lie in [-1,1]"))
    lower = Float64(gene.bounds.interval.lower); upper = Float64(gene.bounds.interval.upper)
    z == -1.0 && return lower
    z == 1.0 && return upper
    t = (z + 1.0) / 2.0
    gene.transform.kind == transform_linear && return lower + t * (upper - lower)
    gene.transform.kind == transform_log && return exp(log(lower) + t * (log(upper) - log(lower)))
    gene.transform.kind == transform_signed_log || throw(ArgumentError("unknown parameter transform kind"))
    scale = Float64(gene.transform.scale.value)
    forward(x) = sign(x) * log1p(abs(x) / scale)
    inverse(x) = sign(x) * scale * expm1(abs(x))
    inverse(forward(lower) + t * (forward(upper) - forward(lower)))
end
derive_parameter_value(gene::ParameterGeneV1) =
    invoke(_g1_derive_parameter_value_sealed, Tuple{ParameterGeneV1,Any}, gene, gene.normalized_gene)
derive_parameter_value(gene::ParameterGeneV1, normalized_gene::Any) =
    invoke(_g1_derive_parameter_value_sealed, Tuple{ParameterGeneV1,Any}, gene, normalized_gene)
parameter_value(gene::ParameterGeneV1) =
    invoke(_g1_derive_parameter_value_sealed, Tuple{ParameterGeneV1,Any}, gene, gene.normalized_gene)
parameter_value(gene::ParameterGeneV1, normalized_gene::Any) =
    invoke(_g1_derive_parameter_value_sealed, Tuple{ParameterGeneV1,Any}, gene, normalized_gene)

_g1_gene_ref_payload(value::String) = "{\"value\":" * invoke(_g1_quote, Tuple{String}, value) * "}"
_g1_gene_qualified_ref_payload(value::QualifiedRefV1) =
    "{\"id\":" * invoke(_g1_quote, Tuple{String}, value.id) *
    ",\"version\":" * invoke(_g1_quote, Tuple{String}, value.version) * "}"
_g1_gene_sorted_payload(values, encoder::Function) = "[" * join(sort(String[encoder(value) for value in values]), ",") * "]"
function _g1_occurrence_payload(value::ConservationLedgerOccurrenceRefV1)
    kind = getfield(value, :occurrence_kind)
    label = kind === occurrence_source_effect ? "occurrence_source_effect" : kind === occurrence_sink_effect ? "occurrence_sink_effect" :
        kind === occurrence_boundary_effect ? "occurrence_boundary_effect" : kind === occurrence_internal_effect ? "occurrence_internal_effect" : kind === occurrence_interface_minus ? "occurrence_interface_minus" : kind === occurrence_interface_plus ? "occurrence_interface_plus" :
        throw(ArgumentError("unsealed occurrence kind"))
    ref = getfield(value, :operator_site_ref)
    "{\"direction\":" * invoke(_g1_quote, Tuple{String}, String(getfield(value, :direction))) *
        ",\"kind\":" * invoke(_g1_quote, Tuple{String}, label) *
        ",\"ledger_identity\":" * invoke(_ledger_identity_wire, Tuple{ConservationLedgerIdentityV1}, getfield(value, :ledger_identity)) *
        ",\"operator_site_ref\":" * _g1_gene_ref_payload(getfield(ref, :value)) *
        ",\"port_index\":" * string(getfield(value, :port_index)) *
        ",\"port_side\":" * invoke(_g1_quote, Tuple{String}, String(getfield(value, :port_side))) * "}"
end

function _g1_gene_physical_type_payload(value::PhysicalType)
    temporal = value.temporal_type
    clock = temporal.clock_ref === nothing ? "null" : "{\"id\":" * invoke(_g1_quote, Tuple{String}, temporal.clock_ref.id) *
        ",\"version\":" * invoke(_g1_quote, Tuple{String}, temporal.clock_ref.version) * "}"
    "{\"spatial_dimension\":" * string(value.spatial_dimension) * ",\"tensor_rank\":" * string(value.tensor_rank) *
        ",\"temporal_type\":{\"clock_ref\":" * clock * ",\"derivative_order\":" * string(temporal.derivative_order) *
        ",\"kind\":" * invoke(_g1_quote, Tuple{String}, String(Symbol(temporal.kind))) * "},\"units\":" *
        invoke(_g1_unit, Tuple{UnitSignature}, value.units) * ",\"value_kind\":" * invoke(_g1_quote, Tuple{String}, String(value.value_kind)) * "}"
end

function _g1_gene_interval_payload(value::ExactFiniteIntervalV1)
    "{\"allow_equal\":" * (value.allow_equal ? "true" : "false") * ",\"lower\":" *
        invoke(_g1_rational, Tuple{Rational{Int64}}, value.lower) * ",\"upper\":" *
        invoke(_g1_rational, Tuple{Rational{Int64}}, value.upper) * "}"
end

function _g1_gene_quantity_payload(value::QuantityIntervalV1)
    "{\"interval\":" * invoke(_g1_gene_interval_payload, Tuple{ExactFiniteIntervalV1}, value.interval) *
        ",\"unit\":" * invoke(_g1_unit, Tuple{UnitSignature}, value.unit) * "}"
end

function _g1_state_gene_wire(value::StateGeneV1)
    action_payload(action::ParityActionV1) = "{\"generator_ref\":{\"id\":" * invoke(_g1_quote, Tuple{String}, action.generator_ref.id) *
        ",\"version\":" * invoke(_g1_quote, Tuple{String}, action.generator_ref.version) * "},\"sign\":" *
        invoke(_g1_quote, Tuple{String}, action.sign == even ? "even" : "odd") * "}"
    ref_payload(ref) = _g1_gene_ref_payload(ref.value)
    payload = "{\"constraint_refs\":" * invoke(_g1_gene_sorted_payload, Tuple{Any,Function}, value.constraint_refs, ref_payload) *
        ",\"epistemic_state\":" * invoke(_g1_gene_state_label, Tuple{StateEpistemicV1}, value.epistemic_state) *
        ",\"gauge_refs\":" * invoke(_g1_gene_sorted_payload, Tuple{Any,Function}, value.gauge_refs, ref_payload) *
        ",\"parity_actions\":" * invoke(_g1_gene_sorted_payload, Tuple{Any,Function}, value.parity_actions, action_payload) *
        ",\"physical_bounds\":" * invoke(_g1_gene_quantity_payload, Tuple{QuantityIntervalV1}, value.physical_bounds) *
        ",\"physical_type\":" * invoke(_g1_gene_physical_type_payload, Tuple{PhysicalType}, value.physical_type) *
        ",\"state_ref\":" * _g1_gene_ref_payload(value.state_ref.value) * "}"
    invoke(_g1_wrap, Tuple{String,String}, "state_gene", payload)
end

_g1_invariant_term_payload(value::InvariantTermV1) = "{\"coefficient\":" *
    invoke(_g1_rational, Tuple{Rational{Int64}}, value.coefficient) * ",\"state_ref\":" * _g1_gene_ref_payload(value.state_ref.value) * "}"

_g1_invariant_term_wire(value::InvariantTermV1) =
    invoke(_g1_wrap, Tuple{String,String}, "invariant_term", _g1_invariant_term_payload(value))

function _g1_invariant_wire(value::InvariantV1)
    ref_payload(ref) = _g1_gene_ref_payload(ref.value)
    scope = getfield(value, :scope)
    scope_wire = typeof(scope) === GlobalConservationScopeV1 ? invoke(_g1_scope_wire, Tuple{GlobalConservationScopeV1}, scope) :
        typeof(scope) === DomainConservationScopeV1 ? invoke(_g1_scope_wire, Tuple{DomainConservationScopeV1}, scope) :
        typeof(scope) === InterfaceConservationScopeV1 ? invoke(_g1_scope_wire, Tuple{InterfaceConservationScopeV1}, scope) :
        throw(ArgumentError("unsealed conservation invariant scope"))
    occurrence_refs = getfield(value, :owned_ledger_occurrence_refs)
    payload = "{\"owned_ledger_occurrence_refs\":" * invoke(_g1_gene_sorted_payload, Tuple{Any,Function}, occurrence_refs,
        value -> invoke(_g1_occurrence_payload, Tuple{ConservationLedgerOccurrenceRefV1}, value)) *
        ",\"entropy_direction\":" * invoke(_g1_gene_entropy_label, Tuple{EntropyDirectionV1}, value.entropy_direction) *
        ",\"invariant_ref\":" * _g1_gene_ref_payload(value.invariant_ref.value) * ",\"ledger_identity\":" * invoke(_ledger_identity_wire, Tuple{ConservationLedgerIdentityV1}, value.ledger_identity) * ",\"scope\":" *
        scope_wire *
        ",\"terms\":" * invoke(_g1_gene_sorted_payload, Tuple{Any,Function}, value.terms, term -> invoke(_g1_invariant_term_payload, Tuple{InvariantTermV1}, term)) * ",\"tolerance_log10\":" * string(value.tolerance_log10) * "}"
    _g1_v2_wrap("invariant", payload, "fusionconceptai:v4:g1-invariant:v2")
end

function _g1_v2_wrap(kind::String, payload::String, domain::String)
    "{\"canonicalization_version\":\"2\",\"domain\":" * invoke(_g1_quote, Tuple{String}, domain) *
        ",\"kind\":" * invoke(_g1_quote, Tuple{String}, kind) * ",\"payload\":" * payload * "}"
end

function _g1_parameter_transform_payload(value::ParameterTransformSpecV1)
    scale = value.scale === nothing ? "null" : "{\"unit\":" * invoke(_g1_unit, Tuple{UnitSignature}, value.scale.unit) *
        ",\"value\":" * invoke(_g1_rational, Tuple{Rational{Int64}}, value.scale.value) * "}"
    "{\"kind\":" * invoke(_g1_gene_transform_label, Tuple{ParameterTransformKindV1}, value.kind) * ",\"scale\":" * scale * "}"
end

_g1_parameter_transform_wire(value::ParameterTransformSpecV1) =
    invoke(_g1_wrap, Tuple{String,String}, "parameter_transform", _g1_parameter_transform_payload(value))

function _g1_parameter_gene_wire(value::ParameterGeneV1)
    payload = "{\"bounds\":" * invoke(_g1_gene_quantity_payload, Tuple{QuantityIntervalV1}, value.bounds) *
        ",\"normalized_gene\":" * repr(value.normalized_gene) * ",\"ref\":" * _g1_gene_ref_payload(value.ref.value) *
        ",\"transform\":" * invoke(_g1_parameter_transform_payload, Tuple{ParameterTransformSpecV1}, value.transform) *
        ",\"unit\":" * invoke(_g1_unit, Tuple{UnitSignature}, value.unit) * "}"
    invoke(_g1_wrap, Tuple{String,String}, "parameter_gene", payload)
end

function _g1_matrix_payload(value::ExactRationalMatrixV1)
    rows = String[]
    for row in value.rows
        push!(rows, "[" * join((invoke(_g1_rational, Tuple{Rational{Int64}}, entry) for entry in row), ",") * "]")
    end
    "{\"rows\":[" * join(rows, ",") * "]}"
end

function _g1_state_action_payload(value::StateSymmetryActionV1)
    "{\"matrix\":" * invoke(_g1_matrix_payload, Tuple{ExactRationalMatrixV1}, value.matrix) *
        ",\"state_ref\":" * _g1_gene_ref_payload(value.state_ref.value) * "}"
end

_g1_state_action_wire(value::StateSymmetryActionV1) =
    invoke(_g1_wrap, Tuple{String,String}, "state_symmetry_action", _g1_state_action_payload(value))

function _g1_symmetry_gene_wire(value::SymmetryGeneV1)
    order = value.group_order === nothing ? "null" : string(value.group_order)
    payload = "{\"behavior\":" * invoke(_g1_gene_behavior_label, Tuple{SymmetryBehaviorV1}, value.behavior) *
        ",\"coordinate_generator_matrix\":" * invoke(_g1_matrix_payload, Tuple{ExactRationalMatrixV1}, value.coordinate_generator_matrix) *
        ",\"generator_ref\":" * invoke(_g1_gene_qualified_ref_payload, Tuple{QualifiedRefV1}, value.generator_ref) *
        ",\"group_kind\":" * invoke(_g1_gene_group_label, Tuple{SymmetryGroupKindV1}, value.group_kind) *
        ",\"group_order\":" * order * ",\"ref\":" * _g1_gene_ref_payload(value.ref.value) *
        ",\"state_actions\":" * invoke(_g1_gene_sorted_payload, Tuple{Any,Function}, value.state_actions, action -> invoke(_g1_state_action_payload, Tuple{StateSymmetryActionV1}, action)) *
        ",\"tolerance\":" * invoke(_g1_rational, Tuple{Rational{Int64}}, value.tolerance) * "}"
    invoke(_g1_wrap, Tuple{String,String}, "symmetry_gene", payload)
end

function _g1_gene_enum_label(value::Enum, labels::Tuple{Vararg{String}})
    index = Int(value) + 1
    1 <= index <= length(labels) || throw(ArgumentError("invalid G1 enum value"))
    invoke(_g1_quote, Tuple{String}, labels[index])
end
_g1_gene_state_label(value::StateEpistemicV1) = invoke(_g1_gene_enum_label, Tuple{Enum,Tuple{Vararg{String}}}, value,
    ("derived", "measured", "declared_known", "hypothesized", "learned", "empirical_prior", "unknown_placeholder", "not_applicable"))
_g1_gene_entropy_label(value::EntropyDirectionV1) = invoke(_g1_gene_enum_label, Tuple{Enum,Tuple{Vararg{String}}}, value, ("not_applicable", "nondecreasing", "nonincreasing", "conserved"))
_g1_gene_transform_label(value::ParameterTransformKindV1) = invoke(_g1_gene_enum_label, Tuple{Enum,Tuple{Vararg{String}}}, value, ("linear", "log", "signed_log"))
_g1_gene_group_label(value::SymmetryGroupKindV1) = invoke(_g1_gene_enum_label, Tuple{Enum,Tuple{Vararg{String}}}, value, ("discrete", "continuous"))
_g1_gene_behavior_label(value::SymmetryBehaviorV1) = invoke(_g1_gene_enum_label, Tuple{Enum,Tuple{Vararg{String}}}, value, ("invariant", "equivariant"))

canonical_json(value::StateGeneV1) = _g1_state_gene_wire(value)
canonical_json(value::InvariantTermV1) = _g1_invariant_term_wire(value)
canonical_json(value::InvariantV1) = _g1_invariant_wire(value)
canonical_json(value::ParameterTransformSpecV1) = _g1_parameter_transform_wire(value)
canonical_json(value::ParameterGeneV1) = _g1_parameter_gene_wire(value)
canonical_json(value::StateSymmetryActionV1) = _g1_state_action_wire(value)
canonical_json(value::SymmetryGeneV1) = _g1_symmetry_gene_wire(value)

canonical_hash(value::StateGeneV1) = invoke(_g1_hash_bytes, Tuple{String}, _g1_state_gene_wire(value))
canonical_hash(value::InvariantTermV1) = invoke(_g1_hash_bytes, Tuple{String}, _g1_invariant_term_wire(value))
canonical_hash(value::InvariantV1) = invoke(_g1_hash_bytes, Tuple{String}, _g1_invariant_wire(value))
canonical_hash(value::ParameterTransformSpecV1) = invoke(_g1_hash_bytes, Tuple{String}, _g1_parameter_transform_wire(value))
canonical_hash(value::ParameterGeneV1) = invoke(_g1_hash_bytes, Tuple{String}, _g1_parameter_gene_wire(value))
canonical_hash(value::StateSymmetryActionV1) = invoke(_g1_hash_bytes, Tuple{String}, _g1_state_action_wire(value))
canonical_hash(value::SymmetryGeneV1) = invoke(_g1_hash_bytes, Tuple{String}, _g1_symmetry_gene_wire(value))

semantic_view(x::StateGeneV1) = (state_ref=x.state_ref, physical_type=x.physical_type, physical_bounds=x.physical_bounds,
    parity_actions=x.parity_actions, gauge_refs=x.gauge_refs, constraint_refs=x.constraint_refs, epistemic_state=x.epistemic_state)
semantic_view(x::InvariantTermV1) = (state_ref=x.state_ref, coefficient=x.coefficient)
semantic_view(x::InvariantV1) = (invariant_ref=x.invariant_ref, ledger_identity=x.ledger_identity, scope=getfield(x, :scope),
    terms=x.terms, owned_ledger_occurrence_refs=getfield(x, :owned_ledger_occurrence_refs),
    tolerance_log10=x.tolerance_log10, entropy_direction=x.entropy_direction)
semantic_view(x::ConservationLedgerOccurrenceRefV1) =
    (operator_site_ref=getfield(x, :operator_site_ref), port_side=getfield(x, :port_side),
     port_index=getfield(x, :port_index), direction=getfield(x, :direction),
     occurrence_kind=getfield(x, :occurrence_kind), ledger_identity=getfield(x, :ledger_identity))
semantic_view(x::ParameterTransformSpecV1) = (kind=x.kind, scale=x.scale)
semantic_view(x::ParameterGeneV1) = (ref=x.ref, unit=x.unit, transform=x.transform, bounds=x.bounds, normalized_gene=x.normalized_gene)
semantic_view(x::StateSymmetryActionV1) = (state_ref=x.state_ref, matrix=x.matrix)
semantic_view(x::SymmetryGeneV1) = (ref=x.ref, generator_ref=x.generator_ref, group_kind=x.group_kind, coordinate_generator_matrix=x.coordinate_generator_matrix,
    state_actions=x.state_actions, group_order=x.group_order, behavior=x.behavior, tolerance=x.tolerance)
