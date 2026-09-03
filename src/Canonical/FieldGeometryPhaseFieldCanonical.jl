"""Closed canonical transport for G2 5.3 phase-field declarations."""

const _G53_PHASE_DECLARATION_DOMAIN = "fusionconceptai:v4:g2:phase_field_declaration:v1"
const _G53_PHASE_SET_DOMAIN = "fusionconceptai:v4:g2:phase_field_set_gene:v1"

function _g53_write_phase_wire(io::Base.GenericIOBuffer, value::PhaseFieldDeclarationV1)
    invoke(_g25_write_wrap_start, Tuple{Base.GenericIOBuffer,String,String}, io,
           _G53_PHASE_DECLARATION_DOMAIN, "phase_field_declaration")
    invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, "{\"logit_root\":")
    invoke(_g25_write_root_wire, Tuple{Base.GenericIOBuffer,SpatialProgramRootRefV1}, io, value.logit_root)
    invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, ",\"phase_field_ref\":")
    invoke(_g53_write_ref_object, Tuple{Base.GenericIOBuffer,String}, io, value.phase_field_ref.value)
    invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, "}")
    invoke(_g25_write_wrap_end, Tuple{Base.GenericIOBuffer}, io)
    nothing
end

function _g53_write_set_wire(io::Base.GenericIOBuffer, value::PhaseFieldSetGeneV1)
    invoke(_g25_write_wrap_start, Tuple{Base.GenericIOBuffer,String,String}, io,
           _G53_PHASE_SET_DOMAIN, "phase_field_set_gene")
    invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, "{\"field_parameters\":[")
    i = 1
    count = fieldcount(typeof(value.field_parameters))
    while i <= count
        i > 1 && invoke(_g25_write_byte, Tuple{Base.GenericIOBuffer,UInt8}, io, UInt8(0x2c))
        parameter_json = invoke(_g53_parameter_raw_json, Tuple{FieldParameterGeneV1}, getfield(value.field_parameters, i))
        invoke(_g53_write_raw_json, Tuple{Base.GenericIOBuffer,String}, io, parameter_json)
        i += 1
    end
    invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, "],\"field_programs\":[")
    i = 1
    count = fieldcount(typeof(value.field_programs))
    while i <= count
        i > 1 && invoke(_g25_write_byte, Tuple{Base.GenericIOBuffer,UInt8}, io, UInt8(0x2c))
        program_json = invoke(_g53_program_json, Tuple{TypedFieldProgramGeneV1}, getfield(value.field_programs, i))
        invoke(_g53_write_raw_json, Tuple{Base.GenericIOBuffer,String}, io, program_json)
        i += 1
    end
    invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, "],\"phase_fields\":[")
    i = 1
    count = fieldcount(typeof(value.phase_fields))
    while i <= count
        i > 1 && invoke(_g25_write_byte, Tuple{Base.GenericIOBuffer,UInt8}, io, UInt8(0x2c))
        invoke(_g53_write_phase_wire, Tuple{Base.GenericIOBuffer,PhaseFieldDeclarationV1}, io,
               getfield(value.phase_fields, i))
        i += 1
    end
    invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, "],\"spatial_support_ref\":")
    invoke(_g53_write_ref_object, Tuple{Base.GenericIOBuffer,String}, io, value.spatial_support_ref.value)
    invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, "}")
    invoke(_g25_write_wrap_end, Tuple{Base.GenericIOBuffer}, io)
    nothing
end

function _g53_phase_json(value::PhaseFieldDeclarationV1)
    io = IOBuffer()
    invoke(_g53_write_phase_wire, Tuple{Base.GenericIOBuffer,PhaseFieldDeclarationV1}, io, value)
    invoke(_g25_finish, Tuple{Base.GenericIOBuffer}, io)
end
function _g53_set_json(value::PhaseFieldSetGeneV1)
    io = IOBuffer()
    invoke(_g53_write_set_wire, Tuple{Base.GenericIOBuffer,PhaseFieldSetGeneV1}, io, value)
    invoke(_g25_finish, Tuple{Base.GenericIOBuffer}, io)
end

canonical_json(value::PhaseFieldDeclarationV1) =
    invoke(_g53_phase_json, Tuple{PhaseFieldDeclarationV1}, value)
canonical_hash(value::PhaseFieldDeclarationV1) =
    invoke(_g25_hash_bytes, Tuple{String}, invoke(_g53_phase_json, Tuple{PhaseFieldDeclarationV1}, value))
canonical_json(value::PhaseFieldSetGeneV1) =
    invoke(_g53_set_json, Tuple{PhaseFieldSetGeneV1}, value)
canonical_hash(value::PhaseFieldSetGeneV1) =
    invoke(_g25_hash_bytes, Tuple{String}, invoke(_g53_set_json, Tuple{PhaseFieldSetGeneV1}, value))
