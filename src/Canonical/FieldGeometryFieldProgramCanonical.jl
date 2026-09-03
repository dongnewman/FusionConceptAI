"""Closed canonical transport for G2 5.3 typed field-program declarations."""

const _G53_FIELD_PROGRAM_BINDING_DOMAIN = "fusionconceptai:v4:g2:field_program_parameter_binding:v1"
const _G53_TYPED_FIELD_PROGRAM_DOMAIN = "fusionconceptai:v4:g2:typed_field_program_gene:v1"

function _g53_write_raw_json(io::Base.GenericIOBuffer, value::String)
    invoke(_ccbw_utf8!, Tuple{Base.GenericIOBuffer,AbstractString}, io, value)
    nothing
end

function _g53_write_ref_object(io::Base.GenericIOBuffer, value::String)
    invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, "{\"value\":")
    invoke(_g25_write_quoted, Tuple{Base.GenericIOBuffer,String}, io, value)
    invoke(_g25_write_byte, Tuple{Base.GenericIOBuffer,UInt8}, io, UInt8(0x7d))
    nothing
end

function _g53_ast_raw_json(value::TypedASTProgramV1)
    payload = invoke(_ast_program_semantic_payload, Tuple{TypedASTProgramV1}, value)
    invoke(_ast_program_canonical, Tuple{Any}, payload)
end

function _g53_parameter_raw_json(value::FieldParameterGeneV1)
    invoke(_g2_field_parameter_json, Tuple{FieldParameterGeneV1}, value)
end

function _g53_write_binding_wire(io::Base.GenericIOBuffer, value::FieldProgramParameterBindingV1)
    invoke(_g25_write_wrap_start, Tuple{Base.GenericIOBuffer,String,String}, io,
           _G53_FIELD_PROGRAM_BINDING_DOMAIN, "field_program_parameter_binding")
    invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, "{\"parameter_node_position\":")
    invoke(_g25_write_int64, Tuple{Base.GenericIOBuffer,Int64}, io, value.parameter_node_position)
    invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, ",\"parameter_ref\":")
    invoke(_g53_write_ref_object, Tuple{Base.GenericIOBuffer,String}, io, value.parameter_ref.value)
    invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, "}")
    invoke(_g25_write_wrap_end, Tuple{Base.GenericIOBuffer}, io)
    nothing
end

function _g53_write_binding_wire_at(io::Base.GenericIOBuffer,
                                    value::FieldProgramParameterBindingV1,
                                    position::Int64)
    invoke(_g25_write_wrap_start, Tuple{Base.GenericIOBuffer,String,String}, io,
           _G53_FIELD_PROGRAM_BINDING_DOMAIN, "field_program_parameter_binding")
    invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, "{\"parameter_node_position\":")
    invoke(_g25_write_int64, Tuple{Base.GenericIOBuffer,Int64}, io, position)
    invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, ",\"parameter_ref\":")
    invoke(_g53_write_ref_object, Tuple{Base.GenericIOBuffer,String}, io, getfield(getfield(value, :parameter_ref), :value))
    invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, "}")
    invoke(_g25_write_wrap_end, Tuple{Base.GenericIOBuffer}, io)
    nothing
end

function _g53_binding_array_json(value::TypedFieldProgramGeneV1, refs::Tuple{Vararg{Int}})
    io = _ccbw_new()
    invoke(_g25_write_byte, Tuple{Base.GenericIOBuffer,UInt8}, io, UInt8(0x5b))
    bindings = getfield(value, :parameter_bindings)
    count = fieldcount(typeof(bindings))
    mapped = Vector{Tuple{Int,FieldProgramParameterBindingV1}}(undef, count)
    i = 1
    while i <= count
        binding = getfield(bindings, i)
        old_position = getfield(binding, :parameter_node_position)
        new_position = getfield(refs, old_position)
        Core.arrayset(true, mapped, (new_position, binding), i)
        i += 1
    end
    i = 2
    while i <= count
        current = Core.arrayref(true, mapped, i)
        j = i - 1
        while j >= 1 && getfield(current, 1) < getfield(Core.arrayref(true, mapped, j), 1)
            Core.arrayset(true, mapped, Core.arrayref(true, mapped, j), j + 1)
            j -= 1
        end
        Core.arrayset(true, mapped, current, j + 1)
        i += 1
    end
    i = 1
    while i <= count
        i > 1 && invoke(_g25_write_byte, Tuple{Base.GenericIOBuffer,UInt8}, io, UInt8(0x2c))
        pair = Core.arrayref(true, mapped, i)
        invoke(_g53_write_binding_wire_at,
               Tuple{Base.GenericIOBuffer,FieldProgramParameterBindingV1,Int64},
               io, getfield(pair, 2), Int64(getfield(pair, 1)))
        i += 1
    end
    invoke(_g25_write_byte, Tuple{Base.GenericIOBuffer,UInt8}, io, UInt8(0x5d))
    invoke(_ccbw_finish, Tuple{Base.GenericIOBuffer}, io)
end

function _g53_program_parts(value::TypedFieldProgramGeneV1)
    ast = getfield(value, :program)
    orbit = invoke(_tac_graph_orbit, Tuple{TypedASTProgramV1}, ast)
    best_ast = getfield(orbit, :canonical_text)
    mappings = getfield(orbit, :mappings)
    mapping_count = fieldcount(typeof(mappings))
    best_bindings = nothing
    pi = 1
    while pi <= mapping_count
        refs = getfield(mappings, pi)
        binding_json = invoke(_g53_binding_array_json,
            Tuple{TypedFieldProgramGeneV1,Tuple{Vararg{Int}}}, value, refs)
        if best_bindings === nothing || invoke(_tac_string_less,
            Tuple{AbstractString,AbstractString}, binding_json, best_bindings)
            best_bindings = binding_json
        end
        pi += 1
    end
    (best_ast::String, best_bindings::String)
end

function _g53_graph_orbit_json(ast_json::String)
    io = _ccbw_new()
    invoke(_g25_write_wrap_start, Tuple{Base.GenericIOBuffer,String,String}, io,
           _TAC_GRAPH_ORBIT_DOMAIN, "typed_ast_graph_orbit")
    invoke(_g53_write_raw_json, Tuple{Base.GenericIOBuffer,String}, io, ast_json)
    invoke(_g25_write_wrap_end, Tuple{Base.GenericIOBuffer}, io)
    invoke(_ccbw_finish, Tuple{Base.GenericIOBuffer}, io)
end

function _g53_write_program_wire(io::Base.GenericIOBuffer, value::TypedFieldProgramGeneV1)
    invoke(_g25_write_wrap_start, Tuple{Base.GenericIOBuffer,String,String}, io,
           _G53_TYPED_FIELD_PROGRAM_DOMAIN, "typed_field_program_gene")
    invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, "{\"operator_site_ref\":")
    invoke(_g53_write_ref_object, Tuple{Base.GenericIOBuffer,String}, io, value.operator_site_ref.value)
    ast_json, binding_json = invoke(_g53_program_parts,
        Tuple{TypedFieldProgramGeneV1}, value)
    graph_json = invoke(_g53_graph_orbit_json, Tuple{String}, ast_json)
    invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, ",\"parameter_bindings\":")
    invoke(_g53_write_raw_json, Tuple{Base.GenericIOBuffer,String}, io, binding_json)
    invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, ",\"program\":")
    invoke(_g53_write_raw_json, Tuple{Base.GenericIOBuffer,String}, io, graph_json)
    invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, ",\"root_refs\":[")
    i = 1
    count = fieldcount(typeof(value.root_refs))
    while i <= count
        i > 1 && invoke(_g25_write_byte, Tuple{Base.GenericIOBuffer,UInt8}, io, UInt8(0x2c))
        invoke(_g25_write_root_wire, Tuple{Base.GenericIOBuffer,SpatialProgramRootRefV1}, io,
               getfield(value.root_refs, i))
        i += 1
    end
    invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, "]}")
    invoke(_g25_write_wrap_end, Tuple{Base.GenericIOBuffer}, io)
    nothing
end

function _g53_binding_json(value::FieldProgramParameterBindingV1)
    io = IOBuffer()
    invoke(_g53_write_binding_wire, Tuple{Base.GenericIOBuffer,FieldProgramParameterBindingV1}, io, value)
    invoke(_g25_finish, Tuple{Base.GenericIOBuffer}, io)
end
function _g53_program_json(value::TypedFieldProgramGeneV1)
    io = IOBuffer()
    invoke(_g53_write_program_wire, Tuple{Base.GenericIOBuffer,TypedFieldProgramGeneV1}, io, value)
    invoke(_g25_finish, Tuple{Base.GenericIOBuffer}, io)
end

canonical_json(value::FieldProgramParameterBindingV1) =
    invoke(_g53_binding_json, Tuple{FieldProgramParameterBindingV1}, value)
canonical_hash(value::FieldProgramParameterBindingV1) =
    invoke(_g25_hash_bytes, Tuple{String}, invoke(_g53_binding_json, Tuple{FieldProgramParameterBindingV1}, value))
canonical_json(value::TypedFieldProgramGeneV1) =
    invoke(_g53_program_json, Tuple{TypedFieldProgramGeneV1}, value)
canonical_hash(value::TypedFieldProgramGeneV1) =
    invoke(_g25_hash_bytes, Tuple{String}, invoke(_g53_program_json, Tuple{TypedFieldProgramGeneV1}, value))
