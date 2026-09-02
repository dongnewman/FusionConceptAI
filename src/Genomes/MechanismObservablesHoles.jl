"""Local observable, root-reference, and typed operator-hole records."""

const _G1_SAFE_GENE_INTEGERS = (Int8, Int16, Int32, Int64, Int128, UInt8, UInt16, UInt32, UInt64, UInt128)

function _g1_positive_gene_int(value::Any, field::String)
    typeof(value) in _G1_SAFE_GENE_INTEGERS && !(value isa Bool) ||
        throw(ArgumentError("$field must be a fixed-width positive integer"))
    typemin(Int) <= value <= typemax(Int) && value >= 1 || throw(ArgumentError("$field is out of range"))
    Int(value)
end

function _g1_nonnegative_gene_int(value::Any, field::String)
    typeof(value) in _G1_SAFE_GENE_INTEGERS && !(value isa Bool) ||
        throw(ArgumentError("$field must be a fixed-width non-negative integer"))
    typemin(Int) <= value <= typemax(Int) && value >= 0 || throw(ArgumentError("$field is out of range"))
    Int(value)
end

struct ProgramRootRefV1
    operator_site_ref::OperatorSiteRefV1
    root_position::Int
    declared_type::PhysicalType
    function ProgramRootRefV1(operator_site_ref::Any, root_position::Any, declared_type::Any)
        operator_site_ref isa OperatorSiteRefV1 || throw(ArgumentError("operator_site_ref must be OperatorSiteRefV1"))
        position = invoke(_g1_positive_gene_int, Tuple{Any,String}, root_position, "root_position")
        declared_type isa PhysicalType || throw(ArgumentError("declared_type must be PhysicalType"))
        new(operator_site_ref, position, declared_type)
    end
end

function _g1_qualified_ref_tuple(value::Any, field::String)
    tuple = invoke(_g1_gene_tuple, Tuple{Any,String}, value, field)
    all(item -> typeof(item) === QualifiedRefV1, tuple) || throw(ArgumentError("$field contains an invalid qualified reference"))
    tuple
end

function _g1_observable_ref_tuple(value::Any, field::String)
    tuple = invoke(_g1_gene_tuple, Tuple{Any,String}, value, field)
    all(item -> typeof(item) === ObservableRefV1, tuple) || throw(ArgumentError("$field contains an invalid observable reference"))
    tuple
end

function _g1_site_ref_tuple(value::Any, field::String)
    tuple = invoke(_g1_gene_tuple, Tuple{Any,String}, value, field)
    all(item -> typeof(item) === OperatorSiteRefV1, tuple) || throw(ArgumentError("$field contains an invalid operator site reference"))
    tuple
end

function _g1_effect_tuple(value::Any, field::String)
    tuple = invoke(_g1_gene_tuple, Tuple{Any,String}, value, field)
    all(item -> typeof(item) === ConservationEffectKindV1, tuple) || throw(ArgumentError("$field contains an invalid conservation effect"))
    tuple
end

function _g1_observable_program_type(program::TypedASTProgramV1)
    length(program.input_ports) == 1 && length(program.roots) == 1 ||
        throw(ArgumentError("sampling_program must have exactly one input and one root"))
    input_index = program.input_ports[1]
    root_index = program.roots[1]
    input_node = program.nodes[input_index]
    root_node = program.nodes[root_index]
    typeof(input_node) === ASTInputV1 || throw(ArgumentError("sampling_program input port must bind an ASTInput"))
    typeof(root_node) in (ASTInputV1, ASTParameterV1, ASTConstantV1, ASTApplyV1) ||
        throw(ArgumentError("sampling_program root is not a typed AST node"))
    input_node.output_type, _ast_program_output_type(root_node)
end

struct ObservableGeneV1
    observable_ref::ObservableRefV1
    expression_root::ProgramRootRefV1
    intervention_ref::QualifiedRefV1
    sampling_program::TypedASTProgramV1
    expected_effect_interval::QuantityIntervalV1
    noise_model_ref::QualifiedRefV1
    noise_floor::NonnegativeQuantityV1
    numerical_floor::NonnegativeQuantityV1
    minimum_effect_size::NonnegativeQuantityV1
    competing_prediction_refs::Tuple{Vararg{QualifiedRefV1}}
    function ObservableGeneV1(observable_ref::Any, expression_root::Any, intervention_ref::Any,
                              sampling_program::Any, expected_effect_interval::Any, noise_model_ref::Any,
                              noise_floor::Any, numerical_floor::Any, minimum_effect_size::Any,
                              competing_prediction_refs::Any)
        observable_ref isa ObservableRefV1 || throw(ArgumentError("observable_ref must be ObservableRefV1"))
        expression_root isa ProgramRootRefV1 || throw(ArgumentError("expression_root must be ProgramRootRefV1"))
        intervention_ref isa QualifiedRefV1 || throw(ArgumentError("intervention_ref must be QualifiedRefV1"))
        sampling_program isa TypedASTProgramV1 || throw(ArgumentError("sampling_program must be TypedASTProgramV1"))
        expected_effect_interval isa QuantityIntervalV1 || throw(ArgumentError("expected_effect_interval must be QuantityIntervalV1"))
        noise_model_ref isa QualifiedRefV1 || throw(ArgumentError("noise_model_ref must be QualifiedRefV1"))
        noise_floor isa NonnegativeQuantityV1 || throw(ArgumentError("noise_floor must be NonnegativeQuantityV1"))
        numerical_floor isa NonnegativeQuantityV1 || throw(ArgumentError("numerical_floor must be NonnegativeQuantityV1"))
        minimum_effect_size isa NonnegativeQuantityV1 || throw(ArgumentError("minimum_effect_size must be NonnegativeQuantityV1"))
        competitors = invoke(_g1_qualified_ref_tuple, Tuple{Any,String}, competing_prediction_refs, "competing_prediction_refs")
        isempty(competitors) && throw(ArgumentError("competing_prediction_refs cannot be empty"))
        _g1_unique_keys(competitors, "competing_prediction_refs", ref -> invoke(_g1_ref_key, Tuple{QualifiedRefV1}, ref))
        input_type, root_type = invoke(_g1_observable_program_type, Tuple{TypedASTProgramV1}, sampling_program)
        input_type == expression_root.declared_type || throw(ArgumentError("sampling input type must match expression root type"))
        root_type.units == expected_effect_interval.unit || throw(ArgumentError("expression root units must match expected effect units"))
        all(floor.unit == expected_effect_interval.unit for floor in (noise_floor, numerical_floor, minimum_effect_size)) ||
            throw(ArgumentError("observable effect and noise units must match"))
        max_effect = max(abs(expected_effect_interval.interval.lower), abs(expected_effect_interval.interval.upper))
        max_effect >= minimum_effect_size.value || throw(ArgumentError("minimum effect exceeds expected effect support"))
        minimum_effect_size.value > noise_floor.value + numerical_floor.value ||
            throw(ArgumentError("minimum effect must exceed noise and numerical floors"))
        new(observable_ref, expression_root, intervention_ref, sampling_program, expected_effect_interval,
            noise_model_ref, noise_floor, numerical_floor, minimum_effect_size, competitors)
    end
end

struct HoleComplexityBudgetV1
    max_ast_nodes::Int
    max_derivative_order::Int
    max_memory_length::Int
    max_free_parameters::Int
    max_free_functions::Int
    max_suboperators::Int
    function HoleComplexityBudgetV1(max_ast_nodes::Any, max_derivative_order::Any, max_memory_length::Any,
                                    max_free_parameters::Any, max_free_functions::Any, max_suboperators::Any)
        ast = invoke(_g1_positive_gene_int, Tuple{Any,String}, max_ast_nodes, "max_ast_nodes")
        derivative = invoke(_g1_nonnegative_gene_int, Tuple{Any,String}, max_derivative_order, "max_derivative_order")
        memory = invoke(_g1_nonnegative_gene_int, Tuple{Any,String}, max_memory_length, "max_memory_length")
        parameters = invoke(_g1_nonnegative_gene_int, Tuple{Any,String}, max_free_parameters, "max_free_parameters")
        functions = invoke(_g1_nonnegative_gene_int, Tuple{Any,String}, max_free_functions, "max_free_functions")
        suboperators = invoke(_g1_positive_gene_int, Tuple{Any,String}, max_suboperators, "max_suboperators")
        ast <= 12 || throw(ArgumentError("max_ast_nodes exceeds the v1 bound"))
        derivative <= 2 || throw(ArgumentError("max_derivative_order exceeds the v1 bound"))
        memory <= 1 || throw(ArgumentError("max_memory_length exceeds the v1 bound"))
        parameters <= 4096 && functions <= 4096 && suboperators <= 16384 ||
            throw(ArgumentError("complexity budget exceeds the finite v1 bound"))
        new(ast, derivative, memory, parameters, functions, suboperators)
    end
end

struct IdentifiabilityConditionV1
    intervention_ref::QualifiedRefV1
    observable_ref::ObservableRefV1
    minimum_effect::NonnegativeQuantityV1
    noise_and_numerical_floor::NonnegativeQuantityV1
    function IdentifiabilityConditionV1(intervention_ref::Any, observable_ref::Any,
                                        minimum_effect::Any, noise_and_numerical_floor::Any)
        intervention_ref isa QualifiedRefV1 || throw(ArgumentError("intervention_ref must be QualifiedRefV1"))
        observable_ref isa ObservableRefV1 || throw(ArgumentError("observable_ref must be ObservableRefV1"))
        minimum_effect isa NonnegativeQuantityV1 || throw(ArgumentError("minimum_effect must be NonnegativeQuantityV1"))
        noise_and_numerical_floor isa NonnegativeQuantityV1 || throw(ArgumentError("noise floor must be NonnegativeQuantityV1"))
        minimum_effect.unit == noise_and_numerical_floor.unit || throw(ArgumentError("identifiability units must match"))
        minimum_effect.value > noise_and_numerical_floor.value || throw(ArgumentError("minimum effect must strictly exceed floor"))
        new(intervention_ref, observable_ref, minimum_effect, noise_and_numerical_floor)
    end
end

function _g1_unique_local_refs(values::Tuple, field::String)
    _g1_unique_keys(values, field, value -> invoke(_g1_local_ref_key, Tuple{Any}, value))
end

struct TypedOperatorHoleV1
    hole_ref::HoleRefV1
    ordered_input_state_refs::Tuple{Vararg{StateGeneRefV1}}
    ordered_output_types::Tuple{Vararg{PhysicalType}}
    causal_direction_ref::QualifiedRefV1
    allowed_effects::Tuple{Vararg{ConservationEffectKindV1}}
    forbidden_effects::Tuple{Vararg{ConservationEffectKindV1}}
    complexity_budget::HoleComplexityBudgetV1
    null_model_ref::QualifiedRefV1
    alternative_model_refs::Tuple{Vararg{QualifiedRefV1}}
    identifiability_conditions::Tuple{Vararg{IdentifiabilityConditionV1}}
    observable_refs::Tuple{Vararg{ObservableRefV1}}
    out_of_sample_prediction_refs::Tuple{Vararg{QualifiedRefV1}}
    function TypedOperatorHoleV1(hole_ref::Any, ordered_input_state_refs::Any, ordered_output_types::Any,
                                 causal_direction_ref::Any, allowed_effects::Any, forbidden_effects::Any,
                                 complexity_budget::Any, null_model_ref::Any, alternative_model_refs::Any,
                                 identifiability_conditions::Any, observable_refs::Any,
                                 out_of_sample_prediction_refs::Any)
        hole_ref isa HoleRefV1 || throw(ArgumentError("hole_ref must be HoleRefV1"))
        inputs = invoke(_g1_require_tuple_type, Tuple{Any,Type,String}, ordered_input_state_refs, StateGeneRefV1, "ordered_input_state_refs")
        outputs = invoke(_g1_require_tuple_type, Tuple{Any,Type,String}, ordered_output_types, PhysicalType, "ordered_output_types")
        isempty(inputs) && throw(ArgumentError("ordered_input_state_refs cannot be empty"))
        isempty(outputs) && throw(ArgumentError("ordered_output_types cannot be empty"))
        _g1_unique_local_refs(inputs, "ordered_input_state_refs")
        causal_direction_ref isa QualifiedRefV1 || throw(ArgumentError("causal_direction_ref must be QualifiedRefV1"))
        allowed = invoke(_g1_effect_tuple, Tuple{Any,String}, allowed_effects, "allowed_effects")
        forbidden = invoke(_g1_effect_tuple, Tuple{Any,String}, forbidden_effects, "forbidden_effects")
        _g1_unique_keys(allowed, "allowed_effects", value -> String(Symbol(value)))
        _g1_unique_keys(forbidden, "forbidden_effects", value -> String(Symbol(value)))
        isempty(intersect(Set(String(Symbol(value)) for value in allowed), Set(String(Symbol(value)) for value in forbidden))) ||
            throw(ArgumentError("allowed and forbidden effects must not overlap"))
        complexity_budget isa HoleComplexityBudgetV1 || throw(ArgumentError("complexity_budget must be HoleComplexityBudgetV1"))
        null_model_ref isa QualifiedRefV1 || throw(ArgumentError("null_model_ref must be QualifiedRefV1"))
        alternatives = invoke(_g1_qualified_ref_tuple, Tuple{Any,String}, alternative_model_refs, "alternative_model_refs")
        isempty(alternatives) && throw(ArgumentError("alternative_model_refs cannot be empty"))
        _g1_unique_keys(alternatives, "alternative_model_refs", ref -> invoke(_g1_ref_key, Tuple{QualifiedRefV1}, ref))
        any(ref -> invoke(_g1_ref_key, Tuple{QualifiedRefV1}, ref) == invoke(_g1_ref_key, Tuple{QualifiedRefV1}, null_model_ref), alternatives) &&
            throw(ArgumentError("null model cannot also be an alternative"))
        conditions = invoke(_g1_require_tuple_type, Tuple{Any,Type,String}, identifiability_conditions, IdentifiabilityConditionV1, "identifiability_conditions")
        observables = invoke(_g1_observable_ref_tuple, Tuple{Any,String}, observable_refs, "observable_refs")
        predictions = invoke(_g1_qualified_ref_tuple, Tuple{Any,String}, out_of_sample_prediction_refs, "out_of_sample_prediction_refs")
        isempty(conditions) && throw(ArgumentError("identifiability_conditions cannot be empty"))
        isempty(observables) && throw(ArgumentError("observable_refs cannot be empty"))
        isempty(predictions) && throw(ArgumentError("out_of_sample_prediction_refs cannot be empty"))
        _g1_unique_keys(conditions, "identifiability_conditions", condition -> invoke(_g1_ref_key, Tuple{QualifiedRefV1}, condition.intervention_ref))
        _g1_unique_keys(observables, "observable_refs", ref -> invoke(_g1_local_ref_key, Tuple{Any}, ref))
        _g1_unique_keys(predictions, "out_of_sample_prediction_refs", ref -> invoke(_g1_ref_key, Tuple{QualifiedRefV1}, ref))
        observable_keys = Set(ref.value for ref in observables)
        all(condition.observable_ref.value in observable_keys for condition in conditions) ||
            throw(ArgumentError("identifiability condition references an undeclared observable"))
        new(hole_ref, inputs, outputs, causal_direction_ref, allowed, forbidden, complexity_budget, null_model_ref,
            alternatives, conditions, observables, predictions)
    end
end

function _g1_hole_sorted(values::Tuple, encode::Function)
    "[" * join(sort(String[encode(value) for value in values]), ",") * "]"
end

function _g1_qualified_payload(value::QualifiedRefV1)
    "{\"id\":" * invoke(_g1_quote, Tuple{String}, value.id) *
        ",\"version\":" * invoke(_g1_quote, Tuple{String}, value.version) * "}"
end

_g1_root_payload(value::ProgramRootRefV1) = "{\"declared_type\":" * invoke(_g1_gene_physical_type_payload, Tuple{PhysicalType}, value.declared_type) *
    ",\"operator_site_ref\":" * _g1_gene_ref_payload(value.operator_site_ref.value) * ",\"root_position\":" * string(value.root_position) * "}"
_g1_budget_payload(value::HoleComplexityBudgetV1) = "{\"max_ast_nodes\":" * string(value.max_ast_nodes) * ",\"max_derivative_order\":" * string(value.max_derivative_order) *
    ",\"max_free_functions\":" * string(value.max_free_functions) * ",\"max_free_parameters\":" * string(value.max_free_parameters) *
    ",\"max_memory_length\":" * string(value.max_memory_length) * ",\"max_suboperators\":" * string(value.max_suboperators) * "}"

function _g1_observable_wire(value::ObservableGeneV1)
    competitors = invoke(_g1_hole_sorted, Tuple{Tuple,Function}, value.competing_prediction_refs,
        ref -> invoke(_g1_qualified_payload, Tuple{QualifiedRefV1}, ref))
    payload = "{\"competing_prediction_refs\":" * competitors * ",\"expected_effect_interval\":" * invoke(_g1_gene_quantity_payload, Tuple{QuantityIntervalV1}, value.expected_effect_interval) *
        ",\"expression_root\":" * invoke(_g1_root_payload, Tuple{ProgramRootRefV1}, value.expression_root) * ",\"intervention_ref\":" * invoke(_g1_qualified_payload, Tuple{QualifiedRefV1}, value.intervention_ref) *
        ",\"minimum_effect_size\":{\"unit\":" * invoke(_g1_unit, Tuple{UnitSignature}, value.minimum_effect_size.unit) *
        ",\"value\":" * invoke(_g1_rational, Tuple{Rational{Int64}}, value.minimum_effect_size.value) * "},\"noise_floor\":{\"unit\":" * invoke(_g1_unit, Tuple{UnitSignature}, value.noise_floor.unit) *
        ",\"value\":" * invoke(_g1_rational, Tuple{Rational{Int64}}, value.noise_floor.value) * "},\"noise_model_ref\":" * invoke(_g1_qualified_payload, Tuple{QualifiedRefV1}, value.noise_model_ref) * ",\"numerical_floor\":{\"unit\":" * invoke(_g1_unit, Tuple{UnitSignature}, value.numerical_floor.unit) *
        ",\"value\":" * invoke(_g1_rational, Tuple{Rational{Int64}}, value.numerical_floor.value) * "},\"observable_ref\":" * _g1_gene_ref_payload(value.observable_ref.value) *
        ",\"sampling_program\":" * invoke(canonical_json, Tuple{TypedASTProgramV1}, value.sampling_program) * "}"
    invoke(_g1_wrap, Tuple{String,String}, "observable_gene", payload)
end

function _g1_hole_wire(value::TypedOperatorHoleV1)
    refs = ref -> _g1_gene_ref_payload(ref.value)
    qualified = ref -> invoke(_g1_qualified_payload, Tuple{QualifiedRefV1}, ref)
    condition = item -> "{\"intervention_ref\":" * qualified(item.intervention_ref) * ",\"minimum_effect\":{\"unit\":" * invoke(_g1_unit, Tuple{UnitSignature}, item.minimum_effect.unit) *
        ",\"value\":" * invoke(_g1_rational, Tuple{Rational{Int64}}, item.minimum_effect.value) * "},\"noise_and_numerical_floor\":{\"unit\":" * invoke(_g1_unit, Tuple{UnitSignature}, item.noise_and_numerical_floor.unit) *
        ",\"value\":" * invoke(_g1_rational, Tuple{Rational{Int64}}, item.noise_and_numerical_floor.value) * "},\"observable_ref\":" * _g1_gene_ref_payload(item.observable_ref.value) * "}"
    payload = "{\"allowed_effects\":" * invoke(_g1_hole_sorted, Tuple{Tuple,Function}, value.allowed_effects, x -> invoke(_g1_quote, Tuple{String}, String(Symbol(x)))) *
        ",\"alternative_model_refs\":" * invoke(_g1_hole_sorted, Tuple{Tuple,Function}, value.alternative_model_refs, qualified) * ",\"causal_direction_ref\":" * qualified(value.causal_direction_ref) *
        ",\"complexity_budget\":" * invoke(_g1_budget_payload, Tuple{HoleComplexityBudgetV1}, value.complexity_budget) * ",\"forbidden_effects\":" * invoke(_g1_hole_sorted, Tuple{Tuple,Function}, value.forbidden_effects, x -> invoke(_g1_quote, Tuple{String}, String(Symbol(x)))) *
        ",\"hole_ref\":" * refs(value.hole_ref) * ",\"identifiability_conditions\":" * invoke(_g1_hole_sorted, Tuple{Tuple,Function}, value.identifiability_conditions, condition) *
        ",\"null_model_ref\":" * qualified(value.null_model_ref) * ",\"ordered_input_state_refs\":[" * join((_g1_gene_ref_payload(ref.value) for ref in value.ordered_input_state_refs), ",") *
        "],\"ordered_output_types\":[" * join((invoke(_g1_gene_physical_type_payload, Tuple{PhysicalType}, typ) for typ in value.ordered_output_types), ",") *
        "],\"observable_refs\":" * invoke(_g1_hole_sorted, Tuple{Tuple,Function}, value.observable_refs, refs) * ",\"out_of_sample_prediction_refs\":" * invoke(_g1_hole_sorted, Tuple{Tuple,Function}, value.out_of_sample_prediction_refs, qualified) * "}"
    invoke(_g1_wrap, Tuple{String,String}, "typed_operator_hole", payload)
end

canonical_json(value::ProgramRootRefV1) = invoke(_g1_wrap, Tuple{String,String}, "program_root_ref", _g1_root_payload(value))
canonical_json(value::ObservableGeneV1) = _g1_observable_wire(value)
canonical_json(value::HoleComplexityBudgetV1) = invoke(_g1_wrap, Tuple{String,String}, "hole_complexity_budget", _g1_budget_payload(value))
canonical_json(value::IdentifiabilityConditionV1) = invoke(_g1_wrap, Tuple{String,String}, "identifiability_condition", "{\"intervention_ref\":" * invoke(_g1_qualified_payload, Tuple{QualifiedRefV1}, value.intervention_ref) * ",\"minimum_effect\":{\"unit\":" * invoke(_g1_unit, Tuple{UnitSignature}, value.minimum_effect.unit) *
    ",\"value\":" * invoke(_g1_rational, Tuple{Rational{Int64}}, value.minimum_effect.value) * "},\"noise_and_numerical_floor\":{\"unit\":" * invoke(_g1_unit, Tuple{UnitSignature}, value.noise_and_numerical_floor.unit) *
    ",\"value\":" * invoke(_g1_rational, Tuple{Rational{Int64}}, value.noise_and_numerical_floor.value) * "},\"observable_ref\":" * _g1_gene_ref_payload(value.observable_ref.value) * "}")
canonical_json(value::TypedOperatorHoleV1) = _g1_hole_wire(value)

canonical_hash(value::ProgramRootRefV1) = invoke(_g1_hash_bytes, Tuple{String}, canonical_json(value))
canonical_hash(value::ObservableGeneV1) = invoke(_g1_hash_bytes, Tuple{String}, _g1_observable_wire(value))
canonical_hash(value::HoleComplexityBudgetV1) = invoke(_g1_hash_bytes, Tuple{String}, canonical_json(value))
canonical_hash(value::IdentifiabilityConditionV1) = invoke(_g1_hash_bytes, Tuple{String}, canonical_json(value))
canonical_hash(value::TypedOperatorHoleV1) = invoke(_g1_hash_bytes, Tuple{String}, _g1_hole_wire(value))

semantic_view(x::ProgramRootRefV1) = (operator_site_ref=x.operator_site_ref, root_position=x.root_position, declared_type=x.declared_type)
semantic_view(x::ObservableGeneV1) = (observable_ref=x.observable_ref, expression_root=x.expression_root, intervention_ref=x.intervention_ref,
    sampling_program=x.sampling_program, expected_effect_interval=x.expected_effect_interval, noise_model_ref=x.noise_model_ref,
    noise_floor=x.noise_floor, numerical_floor=x.numerical_floor, minimum_effect_size=x.minimum_effect_size,
    competing_prediction_refs=x.competing_prediction_refs)
semantic_view(x::HoleComplexityBudgetV1) = (max_ast_nodes=x.max_ast_nodes, max_derivative_order=x.max_derivative_order,
    max_memory_length=x.max_memory_length, max_free_parameters=x.max_free_parameters, max_free_functions=x.max_free_functions,
    max_suboperators=x.max_suboperators)
semantic_view(x::IdentifiabilityConditionV1) = (intervention_ref=x.intervention_ref, observable_ref=x.observable_ref,
    minimum_effect=x.minimum_effect, noise_and_numerical_floor=x.noise_and_numerical_floor)
semantic_view(x::TypedOperatorHoleV1) = (hole_ref=x.hole_ref, ordered_input_state_refs=x.ordered_input_state_refs,
    ordered_output_types=x.ordered_output_types, causal_direction_ref=x.causal_direction_ref, allowed_effects=x.allowed_effects,
    forbidden_effects=x.forbidden_effects, complexity_budget=x.complexity_budget, null_model_ref=x.null_model_ref,
    alternative_model_refs=x.alternative_model_refs, identifiability_conditions=x.identifiability_conditions,
    observable_refs=x.observable_refs, out_of_sample_prediction_refs=x.out_of_sample_prediction_refs)
