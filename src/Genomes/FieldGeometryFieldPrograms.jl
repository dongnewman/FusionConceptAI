"""Closed typed field-program declarations for the G2 5.3 grammar."""

function _g53_signed_int64(value::Any, field::Any)
    value_type = typeof(value)
    (value_type === Int8 || value_type === Int16 || value_type === Int32 ||
     value_type === Int64 || value_type === Int128) ||
        throw(ArgumentError("$field requires a fixed-width signed integer"))
    typemin(Int64) <= value <= typemax(Int64) ||
        throw(ArgumentError("$field is outside the Int64 range"))
    Int64(value)
end

function _g53_tuple_count(value::Any, field::Any)
    value isa Tuple && !(value isa NamedTuple) ||
        throw(ArgumentError("$field must be an immutable tuple"))
    fieldcount(typeof(value))
end

function _g53_text_equal(a::String, b::String)::Bool
    invoke(==, Tuple{String,String}, a, b)
end
function _g53_text_less(a::String, b::String)::Bool
    invoke(isless, Tuple{String,String}, a, b)
end
function _g53_ref_equal(a::Any, b::Any)::Bool
    typeof(a) === typeof(b) && invoke(_g53_text_equal, Tuple{String,String},
        getfield(a, :value), getfield(b, :value))
end

function _g53_unit_equal(a::UnitSignature, b::UnitSignature)::Bool
    invoke(_g25_unit_matches, Tuple{UnitSignature,UnitSignature}, a, b)
end

function _g53_type_equal(a::Any, b::Any)::Bool
    typeof(a) === PhysicalType && typeof(b) === PhysicalType || return false
    invoke(_g25_type_matches, Tuple{Any,Any}, a, b)
end

function _g53_expected_chart_type()
    PhysicalType(:chart_coordinate, 1, 3, TemporalTypeV1(static_time), UnitSignature())
end
function _g53_expected_phase_type()
    PhysicalType(:scalar_field, 0, 3, TemporalTypeV1(static_time), UnitSignature())
end
function _g53_is_parameter_type(value::Any)::Bool
    typeof(value) === PhysicalType || return false
    temporal = getfield(value, :temporal_type)
    typeof(temporal) === TemporalTypeV1 || return false
    getfield(value, :value_kind) === :scalar_field &&
    getfield(value, :tensor_rank) === 0 && getfield(value, :spatial_dimension) === 3 &&
    getfield(temporal, :kind) === static_time && getfield(temporal, :derivative_order) == 0 &&
    getfield(temporal, :clock_ref) === nothing && typeof(getfield(value, :units)) === UnitSignature
end

struct FieldProgramParameterBindingV1
    parameter_ref::FieldParameterRefV1
    parameter_node_position::Int64
    function FieldProgramParameterBindingV1(parameter_ref::Any, parameter_node_position::Any)
        parameter_ref isa FieldParameterRefV1 ||
            throw(ArgumentError("parameter_ref must be FieldParameterRefV1"))
        position = invoke(_g53_signed_int64, Tuple{Any,Any}, parameter_node_position,
                          "parameter_node_position")
        position >= 1 || throw(ArgumentError("parameter_node_position must be positive"))
        new(parameter_ref, position)
    end
end

Base.:(==)(a::FieldProgramParameterBindingV1, b::FieldProgramParameterBindingV1) =
    a.parameter_ref == b.parameter_ref && a.parameter_node_position == b.parameter_node_position
Base.hash(a::FieldProgramParameterBindingV1, h::UInt) =
    hash((a.parameter_ref, a.parameter_node_position), h)
semantic_view(a::FieldProgramParameterBindingV1) =
    (parameter_ref=a.parameter_ref, parameter_node_position=a.parameter_node_position)

function _g53_sorted_bindings(value::Any)
    count = invoke(_g53_tuple_count, Tuple{Any,Any}, value, "parameter_bindings")
    count <= 6 || throw(ArgumentError("parameter_bindings cannot contain more than six values"))
    work = Vector{FieldProgramParameterBindingV1}(undef, count)
    i = 1
    while i <= count
        item = getfield(value, i)
        typeof(item) === FieldProgramParameterBindingV1 ||
            throw(ArgumentError("parameter_bindings must contain FieldProgramParameterBindingV1"))
        Core.arrayset(true, work, item, i)
        i += 1
    end
    i = 2
    while i <= count
        current = Core.arrayref(true, work, i)
        j = i - 1
        while j >= 1
            prior = Core.arrayref(true, work, j)
            current_position = getfield(current, :parameter_node_position)
            prior_position = getfield(prior, :parameter_node_position)
            move = current_position < prior_position
            move || (current_position == prior_position &&
                     invoke(_g53_text_less, Tuple{String,String},
                            getfield(getfield(current, :parameter_ref), :value),
                            getfield(getfield(prior, :parameter_ref), :value)))
            move || break
            Core.arrayset(true, work, prior, j + 1)
            j -= 1
        end
        Core.arrayset(true, work, current, j + 1)
        i += 1
    end
    ntuple(i -> Core.arrayref(true, work, i), count)
end

function _g53_sorted_roots(value::Any)
    count = invoke(_g53_tuple_count, Tuple{Any,Any}, value, "root_refs")
    1 <= count <= 6 || throw(ArgumentError("root_refs must contain 1:6 values"))
    work = Vector{SpatialProgramRootRefV1}(undef, count)
    i = 1
    while i <= count
        item = getfield(value, i)
        typeof(item) === SpatialProgramRootRefV1 ||
            throw(ArgumentError("root_refs must contain SpatialProgramRootRefV1"))
        Core.arrayset(true, work, item, i)
        i += 1
    end
    i = 2
    while i <= count
        current = Core.arrayref(true, work, i)
        j = i - 1
        while j >= 1 && current.root_position < Core.arrayref(true, work, j).root_position
            Core.arrayset(true, work, Core.arrayref(true, work, j), j + 1)
            j -= 1
        end
        Core.arrayset(true, work, current, j + 1)
        i += 1
    end
    i = 1
    while i <= count
        getfield(Core.arrayref(true, work, i), :root_position) == i ||
            throw(ArgumentError("root_refs must cover root positions 1:N exactly"))
        i += 1
    end
    ntuple(i -> Core.arrayref(true, work, i), count)
end

function _g53_ast_node_output(program::TypedASTProgramV1, position::Int64)
    nodes = getfield(program, :nodes)
    position <= fieldcount(typeof(nodes)) || throw(ArgumentError("AST node position is out of range"))
    node = getfield(nodes, position)
    (typeof(node) === ASTInputV1 || typeof(node) === ASTParameterV1 ||
     typeof(node) === ASTConstantV1 || typeof(node) === ASTApplyV1) ||
        throw(ArgumentError("AST contains an unsealed node kind"))
    getfield(node, :output_type)
end

function _g53_validate_program(program::TypedASTProgramV1,
                               site::FieldOperatorSiteRefV1,
                               roots::Tuple,
                               bindings::Tuple)
    nodes = getfield(program, :nodes)
    node_count = fieldcount(typeof(nodes))
    1 <= node_count <= 8 || throw(ArgumentError("field program AST nodes must be 1:8"))
    # Check the semantic ASTInput cardinality before examining the lower-level
    # input-port declaration.  This keeps a nonempty, input-free TypedAST on
    # the G2-owned exactly-one-ASTInput gate instead of masking it as a port
    # count error.
    input_node_count = 0
    i = 1
    while i <= node_count
        typeof(getfield(nodes, i)) === ASTInputV1 && (input_node_count += 1)
        i += 1
    end
    input_node_count == 0 &&
        throw(ArgumentError("field program must contain exactly one ASTInputV1"))
    ast_roots = getfield(program, :roots)
    root_count = fieldcount(typeof(ast_roots))
    1 <= root_count <= 6 || throw(ArgumentError("field program AST roots must be 1:6"))
    ports = getfield(program, :input_ports)
    fieldcount(typeof(ports)) == 1 && getfield(ports, 1) >= 1 ||
        throw(ArgumentError("field program must declare exactly one input port"))
    input_node_count == 1 ||
        throw(ArgumentError("field program must contain exactly one ASTInputV1"))
    input_position = Int64(getfield(ports, 1))
    input_position <= node_count || throw(ArgumentError("field program input port is out of range"))
    input_node = getfield(nodes, input_position)
    typeof(input_node) === ASTInputV1 || throw(ArgumentError("the input port must identify ASTInputV1"))
    getfield(input_node, :port) == 1 || throw(ArgumentError("field program input port must be 1"))
    invoke(_g53_type_equal, Tuple{Any,Any}, getfield(input_node, :output_type),
           invoke(_g53_expected_chart_type, Tuple{})) ||
        throw(ArgumentError("field program input must have chart_coordinate type"))

    fieldcount(typeof(roots)) == root_count ||
        throw(ArgumentError("root_refs must map program.roots exactly"))
    i = 1
    while i <= root_count
        ast_position = getfield(ast_roots, i)
        ast_position >= 1 && ast_position <= node_count ||
            throw(ArgumentError("AST root is out of range"))
        root = getfield(roots, i)
        invoke(_g53_ref_equal, Tuple{Any,Any}, getfield(root, :operator_site_ref), site) ||
            throw(ArgumentError("root reference site does not match field program site"))
        invoke(_g53_type_equal, Tuple{Any,Any}, getfield(root, :declared_input_type),
               invoke(_g53_expected_chart_type, Tuple{})) ||
            throw(ArgumentError("field program root input must be chart_coordinate"))
        invoke(_g53_type_equal, Tuple{Any,Any}, getfield(root, :declared_type),
               invoke(_g53_ast_node_output, Tuple{TypedASTProgramV1,Int64}, program, Int64(ast_position))) ||
            throw(ArgumentError("root declaration does not match AST root output"))
        i += 1
    end

    input_node_count = 0
    parameter_count = 0
    i = 1
    while i <= node_count
        node = getfield(nodes, i)
        if typeof(node) === ASTInputV1
            input_node_count += 1
        elseif typeof(node) === ASTParameterV1
            parameter_count += 1
            invoke(_g53_is_parameter_type, Tuple{Any}, getfield(node, :output_type)) ||
                throw(ArgumentError("ASTParameter output must be static 3D scalar_field"))
        end
        i += 1
    end
    input_node_count == 1 ||
        throw(ArgumentError("field program must contain exactly one ASTInputV1"))
    fieldcount(typeof(bindings)) == parameter_count ||
        throw(ArgumentError("every ASTParameter must be bound exactly once"))
    i = 1
    while i <= fieldcount(typeof(bindings))
        binding = getfield(bindings, i)
        position = getfield(binding, :parameter_node_position)
        position <= node_count || throw(ArgumentError("parameter binding node position is out of range"))
        typeof(getfield(nodes, position)) === ASTParameterV1 ||
            throw(ArgumentError("parameter binding must identify ASTParameterV1"))
        j = i + 1
        while j <= fieldcount(typeof(bindings))
            getfield(getfield(bindings, j), :parameter_node_position) == position &&
                throw(ArgumentError("ASTParameter node positions must be unique"))
            invoke(_g53_ref_equal, Tuple{Any,Any}, getfield(getfield(bindings, j), :parameter_ref),
                   getfield(binding, :parameter_ref)) &&
                throw(ArgumentError("field parameter references must be bound once per program"))
            j += 1
        end
        i += 1
    end
    nothing
end

struct TypedFieldProgramGeneV1
    operator_site_ref::FieldOperatorSiteRefV1
    program::TypedASTProgramV1
    root_refs::Tuple{Vararg{SpatialProgramRootRefV1}}
    parameter_bindings::Tuple{Vararg{FieldProgramParameterBindingV1}}
    function TypedFieldProgramGeneV1(operator_site_ref::Any, program::Any,
                                     root_refs::Any, parameter_bindings::Any)
        operator_site_ref isa FieldOperatorSiteRefV1 ||
            throw(ArgumentError("operator_site_ref must be FieldOperatorSiteRefV1"))
        program isa TypedASTProgramV1 || throw(ArgumentError("program must be TypedASTProgramV1"))
        roots = invoke(_g53_sorted_roots, Tuple{Any}, root_refs)
        bindings = invoke(_g53_sorted_bindings, Tuple{Any}, parameter_bindings)
        invoke(_g53_validate_program, Tuple{TypedASTProgramV1,FieldOperatorSiteRefV1,Tuple,Tuple},
               program, operator_site_ref, roots, bindings)
        new(operator_site_ref, program, roots, bindings)
    end
end

Base.:(==)(a::TypedFieldProgramGeneV1, b::TypedFieldProgramGeneV1) =
    a.operator_site_ref == b.operator_site_ref && a.parameter_bindings == b.parameter_bindings &&
    a.program == b.program && a.root_refs == b.root_refs
Base.hash(a::TypedFieldProgramGeneV1, h::UInt) =
    hash((a.operator_site_ref, a.parameter_bindings, a.program, a.root_refs), h)
semantic_view(a::TypedFieldProgramGeneV1) =
    (operator_site_ref=a.operator_site_ref, parameter_bindings=a.parameter_bindings,
     program=a.program, root_refs=a.root_refs)
