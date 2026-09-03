"""Closed phase-field declarations for the G2 5.3 grammar."""

function _g53_phase_logit_type()
    PhysicalType(:scalar_field, 0, 3, TemporalTypeV1(static_time), UnitSignature())
end

phase_logit_type_v1() = invoke(_g53_phase_logit_type, Tuple{})

struct PhaseFieldDeclarationV1
    phase_field_ref::PhaseFieldRefV1
    logit_root::SpatialProgramRootRefV1
    function PhaseFieldDeclarationV1(phase_field_ref::Any, logit_root::Any)
        phase_field_ref isa PhaseFieldRefV1 ||
            throw(ArgumentError("phase_field_ref must be PhaseFieldRefV1"))
        logit_root isa SpatialProgramRootRefV1 ||
            throw(ArgumentError("logit_root must be SpatialProgramRootRefV1"))
        invoke(_g53_type_equal, Tuple{Any,Any}, getfield(logit_root, :declared_input_type),
               invoke(_g53_expected_chart_type, Tuple{})) ||
            throw(ArgumentError("phase logit root input must be chart_coordinate"))
        invoke(_g53_type_equal, Tuple{Any,Any}, getfield(logit_root, :declared_type),
               invoke(_g53_phase_logit_type, Tuple{})) ||
            throw(ArgumentError("phase logit root output must be scalar_field"))
        new(phase_field_ref, logit_root)
    end
end

Base.:(==)(a::PhaseFieldDeclarationV1, b::PhaseFieldDeclarationV1) =
    a.phase_field_ref == b.phase_field_ref && a.logit_root == b.logit_root
Base.hash(a::PhaseFieldDeclarationV1, h::UInt) = hash((a.phase_field_ref, a.logit_root), h)
semantic_view(a::PhaseFieldDeclarationV1) =
    (phase_field_ref=a.phase_field_ref, logit_root=a.logit_root)

function _g53_sorted_params(value::Any)
    count = invoke(_g53_tuple_count, Tuple{Any,Any}, value, "field_parameters")
    count <= 36 || throw(ArgumentError("field_parameters cannot contain more than 36 values"))
    work = Vector{FieldParameterGeneV1}(undef, count)
    i = 1
    while i <= count
        item = getfield(value, i)
        typeof(item) === FieldParameterGeneV1 ||
            throw(ArgumentError("field_parameters must contain FieldParameterGeneV1"))
        Core.arrayset(true, work, item, i)
        i += 1
    end
    i = 2
    while i <= count
        current = Core.arrayref(true, work, i)
        j = i - 1
        while j >= 1 && invoke(_g53_text_less, Tuple{String,String},
                                getfield(getfield(current, :ref), :value),
                                getfield(getfield(Core.arrayref(true, work, j), :ref), :value))
            Core.arrayset(true, work, Core.arrayref(true, work, j), j + 1)
            j -= 1
        end
        Core.arrayset(true, work, current, j + 1)
        i += 1
    end
    i = 1
    while i <= count
        current = Core.arrayref(true, work, i)
        j = i + 1
        while j <= count
            invoke(_g53_ref_equal, Tuple{Any,Any}, getfield(current, :ref),
                   getfield(Core.arrayref(true, work, j), :ref)) &&
                throw(ArgumentError("field parameter references must be unique"))
            j += 1
        end
        i += 1
    end
    ntuple(i -> Core.arrayref(true, work, i), count)
end

function _g53_sorted_programs(value::Any)
    count = invoke(_g53_tuple_count, Tuple{Any,Any}, value, "field_programs")
    1 <= count <= 6 || throw(ArgumentError("field_programs must contain 1:6 values"))
    work = Vector{TypedFieldProgramGeneV1}(undef, count)
    i = 1
    while i <= count
        item = getfield(value, i)
        typeof(item) === TypedFieldProgramGeneV1 ||
            throw(ArgumentError("field_programs must contain TypedFieldProgramGeneV1"))
        Core.arrayset(true, work, item, i)
        i += 1
    end
    i = 2
    while i <= count
        current = Core.arrayref(true, work, i)
        j = i - 1
        while j >= 1 && invoke(_g53_text_less, Tuple{String,String},
                                getfield(getfield(current, :operator_site_ref), :value),
                                getfield(getfield(Core.arrayref(true, work, j), :operator_site_ref), :value))
            Core.arrayset(true, work, Core.arrayref(true, work, j), j + 1)
            j -= 1
        end
        Core.arrayset(true, work, current, j + 1)
        i += 1
    end
    i = 1
    while i <= count
        current = Core.arrayref(true, work, i)
        j = i + 1
        while j <= count
            invoke(_g53_text_equal, Tuple{String,String}, getfield(current.operator_site_ref, :value),
                   getfield(Core.arrayref(true, work, j).operator_site_ref, :value)) &&
                throw(ArgumentError("field program operator sites must be unique"))
            j += 1
        end
        i += 1
    end
    ntuple(i -> Core.arrayref(true, work, i), count)
end

function _g53_sorted_phases(value::Any)
    count = invoke(_g53_tuple_count, Tuple{Any,Any}, value, "phase_fields")
    2 <= count <= 6 || throw(ArgumentError("phase_fields must contain 2:6 values"))
    work = Vector{PhaseFieldDeclarationV1}(undef, count)
    i = 1
    while i <= count
        item = getfield(value, i)
        typeof(item) === PhaseFieldDeclarationV1 ||
            throw(ArgumentError("phase_fields must contain PhaseFieldDeclarationV1"))
        Core.arrayset(true, work, item, i)
        i += 1
    end
    i = 2
    while i <= count
        current = Core.arrayref(true, work, i)
        j = i - 1
        while j >= 1 && invoke(_g53_text_less, Tuple{String,String},
                                getfield(getfield(current, :phase_field_ref), :value),
                                getfield(getfield(Core.arrayref(true, work, j), :phase_field_ref), :value))
            Core.arrayset(true, work, Core.arrayref(true, work, j), j + 1)
            j -= 1
        end
        Core.arrayset(true, work, current, j + 1)
        i += 1
    end
    i = 1
    while i <= count
        current = Core.arrayref(true, work, i)
        j = i + 1
        while j <= count
            invoke(_g53_text_equal, Tuple{String,String},
                   getfield(getfield(current, :phase_field_ref), :value),
                   getfield(getfield(Core.arrayref(true, work, j), :phase_field_ref), :value)) &&
                throw(ArgumentError("phase-field references must be unique"))
            j += 1
        end
        i += 1
    end
    ntuple(i -> Core.arrayref(true, work, i), count)
end

function _g53_find_parameter(parameters::Tuple, ref::FieldParameterRefV1)
    i = 1
    while i <= fieldcount(typeof(parameters))
        candidate = getfield(parameters, i)
        invoke(_g53_ref_equal, Tuple{Any,Any}, getfield(candidate, :ref), ref) && return candidate
        i += 1
    end
    nothing
end

function _g53_root_key_equal(a::SpatialProgramRootRefV1, site::FieldOperatorSiteRefV1,
                             position::Int64)
    _g53_text_equal(a.operator_site_ref.value, site.value) && a.root_position == position
end

function _g53_validate_set(parameters::Tuple, programs::Tuple, phases::Tuple,
                           support::SpatialSupportRefV1)
    total_roots = 0
    i = 1
    while i <= fieldcount(typeof(programs))
        total_roots += fieldcount(typeof(getfield(getfield(programs, i), :root_refs)))
        i += 1
    end
    total_roots == fieldcount(typeof(phases)) ||
        throw(ArgumentError("every field-program root must be used by exactly one phase field"))
    total_roots <= 6 || throw(ArgumentError("field-program roots cannot exceed six"))

    i = 1
    while i <= fieldcount(typeof(programs))
        program = getfield(programs, i)
        roots = getfield(program, :root_refs)
        bindings = getfield(program, :parameter_bindings)
        j = 1
        while j <= fieldcount(typeof(bindings))
            binding = getfield(bindings, j)
            parameter = invoke(_g53_find_parameter, Tuple{Tuple,FieldParameterRefV1}, parameters,
                               getfield(binding, :parameter_ref))
            parameter === nothing && throw(ArgumentError("parameter binding is not closed over field_parameters"))
            node = getfield(getfield(getfield(program, :program), :nodes),
                            getfield(binding, :parameter_node_position))
            output_type = getfield(node, :output_type)
            invoke(_g53_type_equal, Tuple{Any,Any}, output_type,
                   PhysicalType(:scalar_field, 0, 3, TemporalTypeV1(static_time), getfield(parameter, :unit))) ||
                throw(ArgumentError("ASTParameter type or unit does not match field parameter"))
            j += 1
        end
        j = 1
        while j <= fieldcount(typeof(roots))
            root = getfield(roots, j)
            k = j + 1
            while k <= fieldcount(typeof(roots))
                invoke(_g53_text_equal, Tuple{String,String},
                    getfield(getfield(root, :operator_site_ref), :value),
                    getfield(getfield(getfield(roots, k), :operator_site_ref), :value)) &&
                    getfield(root, :root_position) == getfield(getfield(roots, k), :root_position) &&
                    throw(ArgumentError("program root references must be unique"))
                k += 1
            end
            j += 1
        end
        i += 1
    end

    i = 1
    while i <= fieldcount(typeof(parameters))
        parameter = getfield(parameters, i)
        used = false
        j = 1
        while j <= fieldcount(typeof(programs))
            bindings = getfield(programs, j).parameter_bindings
            k = 1
            while k <= fieldcount(typeof(bindings))
                used = used || invoke(_g53_ref_equal, Tuple{Any,Any}, getfield(parameter, :ref),
                    getfield(getfield(bindings, k), :parameter_ref))
                k += 1
            end
            j += 1
        end
        used || throw(ArgumentError("every field parameter must be used by a program"))
        i += 1
    end

    i = 1
    while i <= fieldcount(typeof(phases))
        phase = getfield(phases, i)
            root = getfield(phase, :logit_root)
        j = i + 1
        while j <= fieldcount(typeof(phases))
            other_root = getfield(getfield(phases, j), :logit_root)
            invoke(_g53_text_equal, Tuple{String,String},
                getfield(getfield(root, :operator_site_ref), :value),
                getfield(getfield(other_root, :operator_site_ref), :value)) &&
                getfield(root, :root_position) == getfield(other_root, :root_position) &&
                throw(ArgumentError("phase logit roots must be unique"))
            j += 1
        end
        matches = 0
        j = 1
        while j <= fieldcount(typeof(programs))
            program = getfield(programs, j)
            roots = getfield(program, :root_refs)
            k = 1
            while k <= fieldcount(typeof(roots))
                candidate = getfield(roots, k)
                if invoke(_g53_text_equal, Tuple{String,String},
                   getfield(getfield(candidate, :operator_site_ref), :value),
                   getfield(getfield(root, :operator_site_ref), :value)) &&
                   getfield(candidate, :root_position) == getfield(root, :root_position)
                    matches += 1
                        invoke(_g53_type_equal, Tuple{Any,Any}, getfield(candidate, :declared_type),
                               getfield(root, :declared_type)) ||
                        throw(ArgumentError("phase root declaration differs from program root"))
                end
                k += 1
            end
            j += 1
        end
        matches == 1 || throw(ArgumentError("each phase logit root must resolve exactly once"))
        i += 1
    end
    nothing
end

struct PhaseFieldSetGeneV1
    spatial_support_ref::SpatialSupportRefV1
    field_parameters::Tuple{Vararg{FieldParameterGeneV1}}
    field_programs::Tuple{Vararg{TypedFieldProgramGeneV1}}
    phase_fields::Tuple{Vararg{PhaseFieldDeclarationV1}}
    function PhaseFieldSetGeneV1(spatial_support_ref::Any, field_parameters::Any,
                                 field_programs::Any, phase_fields::Any)
        spatial_support_ref isa SpatialSupportRefV1 ||
            throw(ArgumentError("spatial_support_ref must be SpatialSupportRefV1"))
        parameters = invoke(_g53_sorted_params, Tuple{Any}, field_parameters)
        programs = invoke(_g53_sorted_programs, Tuple{Any}, field_programs)
        phases = invoke(_g53_sorted_phases, Tuple{Any}, phase_fields)
        invoke(_g53_validate_set, Tuple{Tuple,Tuple,Tuple,SpatialSupportRefV1},
               parameters, programs, phases, spatial_support_ref)
        new(spatial_support_ref, parameters, programs, phases)
    end
end

Base.:(==)(a::PhaseFieldSetGeneV1, b::PhaseFieldSetGeneV1) =
    a.field_parameters == b.field_parameters && a.field_programs == b.field_programs &&
    a.phase_fields == b.phase_fields && a.spatial_support_ref == b.spatial_support_ref
Base.hash(a::PhaseFieldSetGeneV1, h::UInt) =
    hash((a.field_parameters, a.field_programs, a.phase_fields, a.spatial_support_ref), h)
semantic_view(a::PhaseFieldSetGeneV1) =
    (field_parameters=a.field_parameters, field_programs=a.field_programs,
     phase_fields=a.phase_fields, spatial_support_ref=a.spatial_support_ref)
