"""Bounded, typed G2 field-program evaluation on a declared node grid.

This module evaluates only the closed G2 program subset declared by the plan.
It is a screen-level producer for later coupled residual/PDE work; it does not
materialize a device or close any whole-device obligation.
"""

using SHA
import JSON3

const _FIELD_EVAL_CODE_HASH = Digest256(bytes2hex(SHA.sha256(read(@__FILE__))))
const _FIELD_EVAL_SUPPORTED_OPS =
    ("IDENTITY", "ADD", "SUB", "NEG", "SCALAR_MUL", "SCALAR_DIV", "DOT")
const _FIELD_EVAL_DEFERRED_OPS =
    ("GRAD", "DIV_OP", "CURL", "LAPLACE", "DT")
const _FIELD_AUDITED_BINDINGS = (
    ("ADD", "v1", Digest256("946ae165180118ba6ae0e0e2eeb21d0f9caafbbd070e17bbae4f66401121f76e")),
    ("DOT", "v1", Digest256("b67df3333381db27d8a20cbc6abe775d124d9b39ae3ff59d590b077fe21ba58b")),
    ("IDENTITY", "v1", Digest256("6b2e8e860b9b279bcea6d018db148d43cbc6e7d135961da9d281a8847521d7cf")),
    ("NEG", "v1", Digest256("a22bfd5c1bd8c4f60446355b7703abc8d07fa7387899f1d3dad6cfd890ea96fe")),
    ("SCALAR_DIV", "v1", Digest256("c866f195941558c598ef0a7102eabb725b49d36092b6255c0ec2a4fa6806a5e2")),
    ("SCALAR_MUL", "v1", Digest256("f847027543134765163c7077770cce6cd52c0330c2d5b692b41b3086f4a2f939")),
    ("SUB", "v1", Digest256("04c62613586553c60e3cc9d421cfb5a4031a420557bf40abea68ec412aecac87")),
)
struct _FieldPlanToken end
struct _FieldResultToken end
const _FIELD_PLAN_TOKEN = _FieldPlanToken()
const _FIELD_RESULT_TOKEN = _FieldResultToken()

struct FieldGridSpecV4
    axes::NTuple{3,Tuple{Vararg{Float64}}}
    grid_hash::Digest256
    function FieldGridSpecV4(axes)
        raw = try Tuple(axes) catch
            throw(ArgumentError("field grid axes must be a tuple of three axes"))
        end
        length(raw) == 3 || throw(ArgumentError("field grid must have exactly three axes"))
        normalized = ntuple(i -> begin
            axis = try Tuple(raw[i]) catch
                throw(ArgumentError("field grid axis must be tuple-like"))
            end
            2 <= length(axis) <= 64 ||
                throw(ArgumentError("field grid axis must contain 2:64 nodes"))
            vals = ntuple(j -> begin
                value = try Float64(axis[j]) catch
                    throw(ArgumentError("field grid coordinates must be finite Float64 values"))
                end
                isfinite(value) ||
                    throw(ArgumentError("field grid coordinates must be finite"))
                value == 0.0 ? 0.0 : value
            end, length(axis))
            all(isfinite, vals) || throw(ArgumentError("field grid coordinates must be finite"))
            all(i -> i == 1 || vals[i] > vals[i - 1], eachindex(vals)) ||
                throw(ArgumentError("field grid axes must be strictly increasing"))
            vals
        end, 3)
        points = length(normalized[1]) * length(normalized[2]) * length(normalized[3])
        points <= 262144 || throw(ArgumentError("field grid contains too many points"))
        new(normalized, canonical_hash(normalized))
    end
end

semantic_view(x::FieldGridSpecV4) = (axes=x.axes, grid_hash=x.grid_hash)

struct FieldEvaluationPlanV4
    candidate_hash::Digest256
    prefix_hash::Digest256
    field_geometry_hash::Digest256
    support_ref::SpatialSupportRefV1
    support_hash::Digest256
    chart_ref::ChartRefV1
    chart_hash::Digest256
    coordinate_map_hash::Digest256
    metric_hash::Digest256
    program_site_ref::FieldOperatorSiteRefV1
    program_hash::Digest256
    root_ref_hash::Digest256
    parameter_hashes::Tuple{Vararg{Digest256}}
    program::TypedFieldProgramGeneV1
    root::SpatialProgramRootRefV1
    parameters::Tuple{Vararg{FieldParameterGeneV1}}
    chart_bounds::NTuple{3,QuantityIntervalV1}
    grid::FieldGridSpecV4
    allowed_opcodes::Tuple{Vararg{String}}
    used_manifest_bindings::Tuple
    scenario_hash::Digest256
    code_hash::Digest256
    status::Symbol
    unresolved_gaps::Tuple{Vararg{String}}
    plan_hash::Digest256
    function FieldEvaluationPlanV4(::_FieldPlanToken, candidate_hash, prefix_hash,
            field_geometry_hash, support_ref, support_hash, chart_ref, chart_hash,
            coordinate_map_hash, metric_hash, program_site_ref, program_hash,
            root_ref_hash, parameter_hashes, program, root, parameters, chart_bounds,
            grid, allowed_opcodes, used_manifest_bindings, scenario_hash, code_hash,
            status, unresolved_gaps, plan_hash)
        new(candidate_hash, prefix_hash, field_geometry_hash, support_ref, support_hash,
            chart_ref, chart_hash, coordinate_map_hash, metric_hash, program_site_ref,
            program_hash, root_ref_hash, Tuple(parameter_hashes), program, root,
            Tuple(parameters), Tuple(chart_bounds), grid, Tuple(allowed_opcodes),
            Tuple(used_manifest_bindings), scenario_hash, code_hash, status,
            Tuple(unresolved_gaps), plan_hash)
    end
end
FieldEvaluationPlanV4(args...) =
    throw(ArgumentError("FieldEvaluationPlanV4 is sealed; use compile_field_evaluation_plan"))

function _field_text(value, field)
    value isa String && !isempty(value) && isvalid(value) ||
        throw(ArgumentError("$field must be a non-empty String"))
    value
end

function _field_digest(value, field)
    value isa Digest256 || throw(ArgumentError("$field must be Digest256"))
    value
end

_field_decl_hash(candidate::CandidateStatePackageV4) =
    candidate.canonical_hashes.genome_bundle_hash

function _field_collect(fields)
    raw = try Tuple(fields) catch
        throw(ArgumentError("field geometry fields must be an immutable tuple"))
    end
    supports = SpatialSupportGeneV1[]
    phase_sets = PhaseFieldSetGeneV1[]
    direct_programs = TypedFieldProgramGeneV1[]
    direct_parameters = FieldParameterGeneV1[]
    for value in raw
        typeof(value) === SpatialSupportGeneV1 && push!(supports, value)
        typeof(value) === PhaseFieldSetGeneV1 && push!(phase_sets, value)
        typeof(value) === TypedFieldProgramGeneV1 && push!(direct_programs, value)
        typeof(value) === FieldParameterGeneV1 && push!(direct_parameters, value)
    end
    length(supports) == 1 || throw(ArgumentError("fields must contain exactly one SpatialSupportGeneV1"))
    length(phase_sets) == 1 || throw(ArgumentError("fields must contain exactly one PhaseFieldSetGeneV1"))
    support = only(supports)
    phase_set = only(phase_sets)
    phase_set.spatial_support_ref == support.support_ref ||
        throw(ArgumentError("phase field set is bound to a different spatial support"))
    programs = Tuple(phase_set.field_programs)
    parameters = Tuple(phase_set.field_parameters)
    isempty(direct_programs) || throw(ArgumentError("programs must be owned by the unique phase field set"))
    isempty(direct_parameters) || throw(ArgumentError("parameters must be owned by the unique phase field set"))
    isempty(programs) && throw(ArgumentError("phase field set has no typed field program"))
    isempty(parameters) && throw(ArgumentError("phase field set has no field parameters"))
    length(unique(canonical_hash(p) for p in programs)) == length(programs) ||
        throw(ArgumentError("duplicate typed field programs are not admissible"))
    length(unique(canonical_hash(p) for p in parameters)) == length(parameters) ||
        throw(ArgumentError("duplicate field parameters are not admissible"))
    (support=support, phase_set=phase_set, programs=programs, parameters=parameters)
end

function _field_choose_program(records; program_site_ref=nothing)
    programs = records.programs
    if program_site_ref !== nothing
        program_site_ref isa FieldOperatorSiteRefV1 ||
            throw(ArgumentError("program_site_ref must be FieldOperatorSiteRefV1"))
        matches = Tuple(p for p in programs if p.operator_site_ref == program_site_ref)
        length(matches) == 1 || throw(ArgumentError("program_site_ref must select exactly one typed field program"))
        return only(matches)
    end
    length(programs) == 1 || throw(ArgumentError("multiple typed field programs require an exact program_site_ref"))
    only(programs)
end

function _field_choose_root(program::TypedFieldProgramGeneV1, phase_set::PhaseFieldSetGeneV1,
                            root_position::Int)
    roots = Tuple(r for r in program.root_refs if r.root_position == root_position)
    length(roots) == 1 || throw(ArgumentError("root_position must select exactly one program root"))
    root = only(roots)
    phases = Tuple(p for p in phase_set.phase_fields if p.logit_root == root)
    length(phases) == 1 || throw(ArgumentError("selected program root must bind exactly one phase declaration"))
    root
end

function _field_parameter_map(program::TypedFieldProgramGeneV1, parameters)
    result = Dict{Int64,FieldParameterGeneV1}()
    for binding in program.parameter_bindings
        haskey(result, binding.parameter_node_position) &&
            throw(ArgumentError("duplicate parameter node binding"))
        matches = Tuple(p for p in parameters if p.ref == binding.parameter_ref)
        length(matches) == 1 || throw(ArgumentError("parameter binding does not resolve exactly once"))
        parameter = only(matches)
        parameter.unit == parameter.bounds.unit ||
            throw(ArgumentError("parameter unit and bound unit differ"))
        parameter.bounds.interval.lower < parameter.bounds.interval.upper ||
            throw(ArgumentError("parameter bounds must be strictly ordered"))
        value = field_parameter_value(parameter)
        isfinite(Float64(value)) || throw(ArgumentError("derived field parameter is not finite"))
        result[binding.parameter_node_position] = parameter
    end
    result
end

function _field_chart_support(support::SpatialSupportGeneV1)
    length(support.charts) == 1 || return nothing
    isempty(support.chart_transition_maps) || return nothing
    chart = only(support.charts)
    isempty(chart.periodic_axes) || return nothing
    chart
end

function _field_chart_artifacts(chart::CoordinateChartGeneV1)
    chart.coordinate_map_root.declared_input_type == chart_coordinate_type_v1() ||
        throw(ArgumentError("coordinate map declaration input type mismatch"))
    chart.coordinate_map_root.declared_type == normalized_ambient_coordinate_type_v1() ||
        throw(ArgumentError("coordinate map declaration output type mismatch"))
    chart.metric_program_root.declared_input_type == chart_coordinate_type_v1() ||
        throw(ArgumentError("metric declaration input type mismatch"))
    chart.metric_program_root.declared_type == normalized_covariant_metric_type_v1() ||
        throw(ArgumentError("metric declaration output type mismatch"))
    (coordinate_map_hash=canonical_hash((declaration=chart.coordinate_map_root,)),
     metric_hash=canonical_hash((declaration=chart.metric_program_root,)))
end

function _field_node_type(node)
    (typeof(node) === ASTInputV1 || typeof(node) === ASTParameterV1 ||
     typeof(node) === ASTConstantV1 || typeof(node) === ASTApplyV1) ||
        throw(ArgumentError("field program contains an unsealed AST node"))
    node.output_type
end

function _field_operator_bindings(program::TypedFieldProgramGeneV1, operator_registry::OperatorRegistryV1)
    _field_operator_bindings(program.program, operator_registry)
end

function _field_operator_bindings(program::TypedASTProgramV1, operator_registry::OperatorRegistryV1)
    bindings = Tuple(program.used_manifest_bindings)
    isempty(bindings) && throw(ArgumentError("field program has no operator manifest bindings"))
    seen = Set{Tuple{String,String,Digest256}}()
    table = Dict{Tuple{String,String,Digest256},Symbol}()
    for (ref, digest) in bindings
        ref isa OperatorRefV1 || throw(ArgumentError("field operator binding reference is not typed"))
        digest isa Digest256 || throw(ArgumentError("field operator binding hash is not typed"))
        manifest = try operator_manifest(operator_registry, ref.qualified) catch
            throw(ArgumentError("field operator binding is absent from supplied operator registry"))
        end
        manifest.operator_ref == ref && manifest.manifest_hash == digest ||
            throw(ArgumentError("field operator manifest hash/reference mismatch"))
        key = (ref.qualified.id, ref.qualified.version, digest)
        key in seen && throw(ArgumentError("duplicate field operator manifest binding"))
        push!(seen, key)
        table[key] = key in _FIELD_AUDITED_BINDINGS ? Symbol(ref.qualified.id) : :unsupported_manifest
    end
    for node in program.nodes
        typeof(node) === ASTApplyV1 || continue
        candidates = Tuple(b for b in bindings if b[1] == node.operator_ref)
        length(candidates) == 1 || throw(ArgumentError("AST operator lacks one exact manifest binding"))
        key = (node.operator_ref.qualified.id, node.operator_ref.qualified.version, candidates[1][2])
        haskey(table, key) || throw(ArgumentError("AST operator binding is not sealed in registry"))
    end
    table
end

"""Hash body for the opt-in G1 SI source-program capability."""
function _g1_typed_source_program_body_v1(capability)
    required = (:schema, :candidate_ref, :g1_source_ref, :g1_declaration_ref,
        :g1_u_field_id, :g1_f_field_id, :g2_source_ref, :g2_declaration_ref,
        :program, :roots, :source_law, :program_hash, :binding_hash)
    all(name -> hasproperty(capability, name), required) ||
        throw(ArgumentError("G1 source-program capability is incomplete"))
    (schema=capability.schema, candidate_ref=capability.candidate_ref,
        g1_source_ref=capability.g1_source_ref,
        g1_declaration_ref=capability.g1_declaration_ref,
        g1_u_field_id=capability.g1_u_field_id,
        g1_f_field_id=capability.g1_f_field_id,
        g2_source_ref=capability.g2_source_ref,
        g2_declaration_ref=capability.g2_declaration_ref,
        program=capability.program, roots=capability.roots,
        source_law=capability.source_law, program_hash=capability.program_hash,
        binding_hash=capability.binding_hash)
end

function _g1_source_node(program::TypedASTProgramV1, position::Int)
    1 <= position <= length(program.nodes) ||
        throw(ArgumentError("G1 source AST node reference is out of range"))
    program.nodes[position]
end

function _g1_source_apply_inputs(program::TypedASTProgramV1, position::Int, id::String)
    node = _g1_source_node(program, position)
    typeof(node) === ASTApplyV1 && node.operator_ref.qualified.id == id ||
        throw(ArgumentError("G1 source AST expected $id at node $position"))
    node.inputs
end

function _g1_source_typed_constant(program::TypedASTProgramV1, position::Int,
        expected_value, expected_type::PhysicalType)
    node = _g1_source_node(program, position)
    typeof(node) === ASTConstantV1 && node.value == expected_value &&
        node.output_type == expected_type ||
        throw(ArgumentError("G1 source AST constant/value/type mismatch"))
    node
end

function _g1_typed_source_program_semantics_v1(capability)
    law = capability.source_law
    capability.candidate_ref isa QualifiedRefV1 &&
        capability.g1_source_ref isa QualifiedRefV1 &&
        capability.g1_declaration_ref isa QualifiedRefV1 &&
        capability.g2_source_ref isa QualifiedRefV1 &&
        capability.g2_declaration_ref isa QualifiedRefV1 &&
        law.chart_ref isa QualifiedRefV1 && law.chart_ref.version == "v1" &&
        law.chart_hash isa Digest256 &&
        capability.g1_u_field_id isa String && !isempty(capability.g1_u_field_id) &&
        capability.g1_f_field_id isa String && !isempty(capability.g1_f_field_id) ||
        throw(ArgumentError("G1 source-program identity refs are not exact typed values"))
    law.kind === :steady_planar_quadratic_diffusion_v1 &&
        law.physical_equation == "-d/dx(Kxx*du/dx)=q'''; Kxx is constant in x" &&
        law.source_formula == "q'''(xi)=q'''" ||
        throw(ArgumentError("G1 source law declaration mismatch"))
    law.chart_input_type == chart_coordinate_type_v1() &&
        law.chart_input_unit == UnitSignature() &&
        law.reference_x_domain == (0.0, 1.0) && law.physical_x_origin_m == 0.0 ||
        throw(ArgumentError("G1 source chart/domain binding mismatch"))
    law.boundary_faces isa Tuple && length(law.boundary_faces) == 6 ||
        throw(ArgumentError("G1 source law must retain all six typed G2 boundary faces"))
    boundary_names = Tuple(face.face for face in law.boundary_faces)
    Set(boundary_names) == Set((:x_min, :x_max, :y_min, :y_max, :z_min, :z_max)) &&
        length(unique(boundary_names)) == 6 ||
        throw(ArgumentError("G1 source law boundary face set is incomplete or duplicated"))
    boundary_map = Dict(face.face => face for face in law.boundary_faces)
    all(name -> boundary_map[name].value.kind === :dirichlet &&
        boundary_map[name].value.unit == UnitSignature((0, 0, 0, 0, 1, 0, 0)) &&
        boundary_map[name].value.value isa Real && isfinite(boundary_map[name].value.value),
        (:x_min, :x_max)) ||
        throw(ArgumentError("G1 source law x boundaries must be finite typed Dirichlet temperatures"))
    left_temperature = boundary_map[:x_min].value.value
    right_temperature = boundary_map[:x_max].value.value
    law.T0_K == left_temperature ||
        throw(ArgumentError("G1 source law T0 must bind the x_min Dirichlet temperature"))
    equal_x_faces = left_temperature == right_temperature
    expected_u_formula = equal_x_faces ?
        "u(x)=T0+(q'''/(2*Kxx))*x*(L-x)" :
        "u(x)=T_left+((T_right-T_left)/L)*x+(q'''/(2*Kxx))*x*(L-x)"
    expected_chart_formula = equal_x_faces ?
        "u(xi)=T0+(q'''*L^2/(2*Kxx))*xi*(1-xi)" :
        "u(xi)=T_left+(T_right-T_left)*xi+(q'''*L^2/(2*Kxx))*xi*(1-xi)"
    law.u_formula == expected_u_formula && law.chart_formula == expected_chart_formula ||
        throw(ArgumentError("G1 source law boundary-lift formula mismatch"))
    all(name -> boundary_map[name].value.kind === :neumann &&
        boundary_map[name].value.unit == UnitSignature((0, 1, -3, 0, 0, 0, 0)) &&
        iszero(boundary_map[name].value.value), (:y_min, :y_max, :z_min, :z_max)) ||
        throw(ArgumentError("G1 source law transverse conormal boundaries must be zero"))
    law.u_type isa PhysicalType && law.u_type.value_kind == :scalar_field &&
        law.u_type.tensor_rank == 0 &&
        law.u_type.spatial_dimension == 3 && law.u_type.temporal_type == TemporalTypeV1(static_time) &&
        law.u_type.units == UnitSignature((0, 0, 0, 0, 1, 0, 0)) &&
        law.K_type isa PhysicalType && law.K_type.tensor_rank == 2 &&
        law.K_type.spatial_dimension == 3 && law.K_type.temporal_type == TemporalTypeV1(static_time) &&
        law.K_type.units == UnitSignature((1, 1, -3, 0, -1, 0, 0)) &&
        law.f_type isa PhysicalType && law.f_type.value_kind == :scalar_field &&
        law.f_type.tensor_rank == 0 &&
        law.f_type.spatial_dimension == 3 && law.f_type.temporal_type == TemporalTypeV1(static_time) &&
        law.f_type.units == UnitSignature((-1, 1, -3, 0, 0, 0, 0)) ||
        throw(ArgumentError("G1 source law physical field types/units mismatch"))
    law.bindings.T0.source === :G2 &&
        law.bindings.T0.source_ref == capability.g2_source_ref &&
        law.bindings.T0.declaration_ref == capability.g2_declaration_ref &&
        law.bindings.T0.role === :x_min_dirichlet &&
        law.bindings.T0.unit == law.u_type.units &&
        law.bindings.T0.face_id == boundary_map[:x_min].face_id &&
        law.bindings.T_L.source === :G2 &&
        law.bindings.T_L.source_ref == capability.g2_source_ref &&
        law.bindings.T_L.declaration_ref == capability.g2_declaration_ref &&
        law.bindings.T_L.role === :x_max_dirichlet &&
        law.bindings.T_L.face_id == boundary_map[:x_max].face_id &&
        law.bindings.T_L.value == right_temperature &&
        law.bindings.T_L.unit == law.u_type.units &&
        law.bindings.transverse_zero_conormal.source === :G2 &&
        law.bindings.transverse_zero_conormal.source_ref == capability.g2_source_ref &&
        law.bindings.transverse_zero_conormal.declaration_ref == capability.g2_declaration_ref &&
        law.bindings.transverse_zero_conormal.role === :zero_conormal &&
        law.bindings.transverse_zero_conormal.face_ids ==
            Tuple(boundary_map[name].face_id for name in (:y_min, :y_max, :z_min, :z_max)) &&
        law.bindings.q.source === :G1 &&
        law.bindings.q.source_ref == capability.g1_source_ref &&
        law.bindings.q.declaration_ref == capability.g1_declaration_ref &&
        law.bindings.q.field_id == capability.g1_f_field_id &&
        law.bindings.q.unit == law.f_type.units &&
        law.bindings.Kxx.source === :G1 &&
        law.bindings.Kxx.source_ref == capability.g1_source_ref &&
        law.bindings.Kxx.declaration_ref == capability.g1_declaration_ref &&
        law.bindings.Kxx.field_id == law.K_type_field_id &&
        law.bindings.Kxx.coefficient_field_id == law.K_type_field_id &&
        law.bindings.Kxx.unit == law.K_type.units &&
        law.bindings.L.source === :G2 &&
        law.bindings.L.source_ref == capability.g2_source_ref &&
        law.bindings.L.declaration_ref == capability.g2_declaration_ref &&
        law.bindings.L.chart_ref == law.chart_ref &&
        law.bindings.L.unit == UnitSignature((1, 0, 0, 0, 0, 0, 0)) ||
        throw(ArgumentError("G1 source law references are not explicitly source-bound"))
    law.T0_K == law.bindings.T0.value && law.q_W_m3 == law.bindings.q.value &&
        law.Kxx_W_mK == law.bindings.Kxx.value && law.L_m == law.bindings.L.value ||
        throw(ArgumentError("G1 source law values disagree with bound role values"))
    expected_amplitude = law.q_W_m3 * law.L_m^2 / (2.0 * law.Kxx_W_mK)
    law.authored_amplitude.value == expected_amplitude &&
        law.authored_amplitude.unit == law.u_type.units ||
        throw(ArgumentError("G1 source temperature amplitude does not follow q*L^2/(2*Kxx)"))

    programs = capability.program
    programs isa NamedTuple && keys(programs) == (:x_coordinate, :x_bubble, :u, :f) ||
        throw(ArgumentError("G1 source program chain keys are not exact"))
    stages = values(programs)
    all(stage -> stage isa NamedTuple && keys(stage) == (:ast, :program_hash) &&
        stage.ast isa TypedASTProgramV1 && stage.program_hash == canonical_hash(stage.ast),
        stages) ||
        throw(ArgumentError("G1 source AST stage hash or shape mismatch"))
    x_program, bubble_program, u_program, f_program =
        programs.x_coordinate.ast, programs.x_bubble.ast, programs.u.ast, programs.f.ast
    all(program -> program isa TypedASTProgramV1,
        (x_program, bubble_program, u_program, f_program)) ||
        throw(ArgumentError("G1 source program chain must contain typed AST programs"))
    length(x_program.nodes) == 3 && x_program.roots == (3,) &&
        x_program.input_ports == (1,) &&
        bubble_program.roots == (length(bubble_program.nodes),) &&
        bubble_program.input_ports == (1,) &&
        ((equal_x_faces && length(bubble_program.nodes) == 4 &&
            length(u_program.nodes) == 5) ||
         (!equal_x_faces && length(bubble_program.nodes) == 8 &&
            length(u_program.nodes) == 3)) &&
        u_program.roots == (length(u_program.nodes),) &&
        u_program.input_ports == (1,) &&
        length(f_program.nodes) == 1 && f_program.roots == (1,) &&
        isempty(f_program.input_ports) ||
        throw(ArgumentError("G1 source AST chain node/root/input budget mismatch"))
    scalar = PhysicalType(:scalar_field, 0, 3,
        TemporalTypeV1(static_time), UnitSignature())

    typeof(x_program.nodes[1]) === ASTInputV1 &&
        isempty(x_program.nodes[1].parameters) &&
        x_program.nodes[1].output_type == law.chart_input_type &&
        typeof(x_program.nodes[2]) === ASTConstantV1 &&
        x_program.nodes[2].value == (1.0, 0.0, 0.0) &&
        x_program.nodes[2].output_type == law.chart_input_type ||
        throw(ArgumentError("G1 x projection AST inputs differ from the typed G2 chart"))
    x_inputs = _g1_source_apply_inputs(x_program, 3, "DOT")
    x_inputs == (1, 2) && x_program.nodes[3].output_type == scalar ||
        throw(ArgumentError("G1 x projection AST must be typed DOT(chart, x-axis)"))

    if equal_x_faces
        typeof(bubble_program.nodes[1]) === ASTInputV1 &&
            bubble_program.nodes[1].output_type == scalar &&
            isempty(bubble_program.nodes[1].parameters) &&
            typeof(bubble_program.nodes[2]) === ASTConstantV1 &&
            bubble_program.nodes[2].value == 1.0 &&
            bubble_program.nodes[2].output_type == scalar ||
            throw(ArgumentError("G1 bubble AST scalar/one inputs are not exact"))
        _g1_source_apply_inputs(bubble_program, 3, "SUB") == (2, 1) &&
            _g1_source_apply_inputs(bubble_program, 4, "SCALAR_MUL") == (1, 3) &&
            bubble_program.nodes[3].output_type == scalar &&
            bubble_program.nodes[4].output_type == scalar ||
            throw(ArgumentError("G1 bubble AST is not xi*(1-xi)"))
    else
        delta = right_temperature - left_temperature
        typeof(bubble_program.nodes[1]) === ASTInputV1 &&
            bubble_program.nodes[1].output_type == scalar &&
            isempty(bubble_program.nodes[1].parameters) &&
            typeof(bubble_program.nodes[2]) === ASTConstantV1 &&
            bubble_program.nodes[2].value == 1.0 &&
            bubble_program.nodes[2].output_type == scalar &&
            _g1_source_apply_inputs(bubble_program, 3, "SUB") == (2, 1) &&
            bubble_program.nodes[3].output_type == scalar &&
            typeof(bubble_program.nodes[4]) === ASTConstantV1 &&
            bubble_program.nodes[4].value == law.authored_amplitude.value &&
            bubble_program.nodes[4].output_type == law.u_type &&
            _g1_source_apply_inputs(bubble_program, 5, "SCALAR_MUL") == (4, 3) &&
            bubble_program.nodes[5].output_type == law.u_type &&
            typeof(bubble_program.nodes[6]) === ASTConstantV1 &&
            bubble_program.nodes[6].value == delta &&
            bubble_program.nodes[6].output_type == law.u_type &&
            _g1_source_apply_inputs(bubble_program, 7, "ADD") == (5, 6) &&
            bubble_program.nodes[7].output_type == law.u_type &&
            _g1_source_apply_inputs(bubble_program, 8, "SCALAR_MUL") == (1, 7) &&
            bubble_program.nodes[8].output_type == law.u_type ||
            throw(ArgumentError("G1 bubble AST is not the source-bound linear lift plus quadratic bubble"))
    end

    if equal_x_faces
        typeof(u_program.nodes[1]) === ASTInputV1 &&
            u_program.nodes[1].output_type == scalar &&
            isempty(u_program.nodes[1].parameters) &&
            typeof(u_program.nodes[2]) === ASTConstantV1 &&
            u_program.nodes[2].value == law.authored_amplitude.value &&
            u_program.nodes[2].output_type == law.u_type &&
            _g1_source_apply_inputs(u_program, 3, "SCALAR_MUL") == (1, 2) &&
            u_program.nodes[3].output_type == law.u_type &&
            typeof(u_program.nodes[4]) === ASTConstantV1 &&
            u_program.nodes[4].value == law.bindings.T0.value &&
            u_program.nodes[4].output_type == law.u_type &&
            _g1_source_apply_inputs(u_program, 5, "ADD") == (4, 3) &&
            u_program.nodes[5].output_type == law.u_type ||
            throw(ArgumentError("G1 temperature AST does not bind bubble, amplitude, and T0"))
    else
        typeof(u_program.nodes[1]) === ASTInputV1 &&
            u_program.nodes[1].output_type == law.u_type &&
            isempty(u_program.nodes[1].parameters) &&
            typeof(u_program.nodes[2]) === ASTConstantV1 &&
            u_program.nodes[2].value == left_temperature &&
            u_program.nodes[2].output_type == law.u_type &&
            _g1_source_apply_inputs(u_program, 3, "ADD") == (2, 1) &&
            u_program.nodes[3].output_type == law.u_type ||
            throw(ArgumentError("G1 temperature AST does not add the source-bound x_min boundary lift"))
    end

    f_node = f_program.nodes[1]
    typeof(f_node) === ASTConstantV1 && f_node.value == law.bindings.q.value &&
        f_node.output_type == law.f_type ||
        throw(ArgumentError("G1 f root is not the typed constant source"))
    true
end

"""Evaluate an authenticated G1 source-program root at caller-supplied chart points.

This is the existing FieldProgramEvaluation AST kernel with a narrow G1 source
entry point. It does not create a V4 candidate or a FieldEvaluationPlan. The
caller must first validate the capability's T0 source/declaration joins and
provide points already mapped into the declared G2 reference chart.
"""
function evaluate_g1_typed_source_program_v1(capability,
        root::SpatialProgramRootRefV1, chart_points;
        operator_registry::OperatorRegistryV1=default_operator_registry())
    if capability.schema == _G1_AUTHORED_TSP_CAP_SCHEMA_V1
        canonical_hash(_g1_authored_typed_source_program_body_v1(capability)) ==
            capability.capability_hash ||
            throw(ArgumentError("candidate-authored G1 capability hash mismatch"))
        expected_binding_hash = canonical_hash((candidate_ref=capability.candidate_ref,
            g1_source_ref=capability.g1_source_ref,
            g1_declaration_ref=capability.g1_declaration_ref,
            g1_u_field_id=capability.g1_u_field_id,
            g1_f_field_id=capability.g1_f_field_id,
            g2_source_ref=capability.g2_source_ref,
            g2_declaration_ref=capability.g2_declaration_ref,
            roots=capability.roots, source_law=capability.source_law,
            spec_hash=capability.spec_hash))
        expected_binding_hash == capability.binding_hash ||
            throw(ArgumentError("candidate-authored G1 capability binding hash mismatch"))
        _g1_authored_typed_source_semantics_v1(capability, operator_registry)
        roots = (capability.roots.u, capability.roots.f)
        root_index = findfirst(==(root), roots)
        root_index === nothing &&
            throw(ArgumentError("selected root is not bound by candidate G1 source"))
        root.root_position == root_index ||
            throw(ArgumentError("candidate-authored G1 root position mismatch"))
        coords = Tuple(chart_points)
        isempty(coords) && throw(ArgumentError("G1 source evaluation requires chart points"))
        all(p -> p isa Tuple && length(p) == 3 &&
            all(x -> x isa Real && isfinite(x), p), coords) ||
            throw(ArgumentError("G1 source chart points must be finite 3-tuples"))
        stage = root_index == 1 ? capability.program.u : capability.program.f
        ast = stage.ast
        kernel_table = isempty(ast.used_manifest_bindings) ?
            Dict{Tuple{String,String,Digest256},Symbol}() :
            _field_operator_bindings(ast, operator_registry)
        scalar_inputs = Dict{Int64,FieldParameterGeneV1}()
        values = Tuple(_field_eval_node(ast.nodes, only(ast.roots),
            ntuple(i -> Float64(p[i]), 3), scalar_inputs, Dict{Int,Any}(),
            kernel_table, ast.used_manifest_bindings) for p in coords)
        result = _field_evaluation_result(
            Tuple(ntuple(i -> Float64(p[i]), 3) for p in coords), values,
            root.declared_type)
        return (status=:ready, candidate_ref=capability.candidate_ref,
            g1_source_ref=capability.g1_source_ref,
            g1_declaration_ref=capability.g1_declaration_ref,
            g2_source_ref=capability.g2_source_ref,
            g2_declaration_ref=capability.g2_declaration_ref,
            program_hash=capability.program_hash, binding_hash=capability.binding_hash,
            root_ref=root, root_hash=canonical_hash(root), root_type=root.declared_type,
            chart_points=result.coordinates, values=result.values,
            result_hash=result.result_hash, result=result)
    end
    capability.schema == "fusionconceptai:genome-v5:g1-typed-source-field-program-v1" ||
        throw(ArgumentError("unsupported G1 source-program capability schema"))
    program = capability.program
    program isa NamedTuple && keys(program) == (:x_coordinate, :x_bubble, :u, :f) ||
        throw(ArgumentError("G1 source-program capability lacks the exact typed AST chain"))
    program_hash = canonical_hash(program)
    program_hash == capability.program_hash ||
        throw(ArgumentError("G1 source-program hash mismatch"))
    binding_hash = canonical_hash((candidate_ref=capability.candidate_ref,
        g1_source_ref=capability.g1_source_ref,
        g1_declaration_ref=capability.g1_declaration_ref,
        g1_u_field_id=capability.g1_u_field_id, g1_f_field_id=capability.g1_f_field_id,
        g2_source_ref=capability.g2_source_ref,
        g2_declaration_ref=capability.g2_declaration_ref,
        roots=capability.roots, source_law=capability.source_law))
    binding_hash == capability.binding_hash ||
        throw(ArgumentError("G1 source-program binding hash mismatch"))
    canonical_hash(_g1_typed_source_program_body_v1(capability)) == capability.capability_hash ||
        throw(ArgumentError("G1 source-program capability hash mismatch"))
    _g1_typed_source_program_semantics_v1(capability) ||
        throw(ArgumentError("G1 SI source program failed its typed law recheck"))

    capability.roots isa NamedTuple && keys(capability.roots) == (:u, :f) ||
        throw(ArgumentError("G1 source-program roots must be exactly u/f"))
    roots = (capability.roots.u, capability.roots.f)
    all(r -> r isa SpatialProgramRootRefV1, roots) ||
        throw(ArgumentError("G1 source-program root refs are not typed"))
    root_index = findfirst(==(root), roots)
    root_index === nothing &&
        throw(ArgumentError("selected root is not bound by the G1 source capability"))
    root.root_position == root_index ||
        throw(ArgumentError("selected G1 source root position is invalid"))
    program.u.ast.nodes[only(program.u.ast.roots)].output_type == roots[1].declared_type &&
        program.f.ast.nodes[only(program.f.ast.roots)].output_type == roots[2].declared_type ||
        throw(ArgumentError("G1 program AST roots do not have the declared u/f types"))
    input_type = chart_coordinate_type_v1()
    all(r -> r.operator_site_ref == roots[1].operator_site_ref &&
        r.declared_input_type == input_type, roots) ||
        throw(ArgumentError("G1 source-program root chart/site binding mismatch"))
    roots[1].declared_type == capability.source_law.u_type &&
        roots[2].declared_type == capability.source_law.f_type ||
        throw(ArgumentError("G1 source-program u/f root physical types mismatch"))
    all(t -> t.value_kind == :scalar_field && t.tensor_rank == 0,
        (roots[1].declared_type, roots[2].declared_type)) ||
        throw(ArgumentError("G1 source-program roots must be typed scalar fields"))
    capability.g1_u_field_id == capability.source_law.u_field_id &&
        capability.g1_f_field_id == capability.source_law.f_field_id ||
        throw(ArgumentError("G1 source-program output field identities mismatch"))
    program.x_coordinate.ast.nodes[only(program.x_coordinate.ast.input_ports)] isa ASTInputV1 &&
        program.x_coordinate.ast.nodes[only(program.x_coordinate.ast.input_ports)].output_type == input_type ||
        throw(ArgumentError("G1 source program input is not the typed G2 chart coordinate"))
    any(n -> typeof(n) === ASTParameterV1,
        (program.x_coordinate.ast.nodes..., program.x_bubble.ast.nodes...,
         program.u.ast.nodes..., program.f.ast.nodes...)) &&
        throw(ArgumentError("G1 SI source fixture requires explicitly source-bound constants"))
    kernel_tables = (x_coordinate=_field_operator_bindings(program.x_coordinate.ast, operator_registry),
        x_bubble=_field_operator_bindings(program.x_bubble.ast, operator_registry),
        u=_field_operator_bindings(program.u.ast, operator_registry),
        f=isempty(program.f.ast.used_manifest_bindings) ? Dict{Tuple{String,String,Digest256},Symbol}() :
            _field_operator_bindings(program.f.ast, operator_registry))

    coords = Tuple(chart_points)
    isempty(coords) && throw(ArgumentError("G1 source evaluation requires chart points"))
    all(p -> p isa Tuple && length(p) == 3 && all(x -> x isa Real && isfinite(x), p), coords) ||
        throw(ArgumentError("G1 source chart points must be finite 3-tuples"))
    all(p -> 0.0 <= Float64(p[1]) <= 1.0, coords) ||
        throw(ArgumentError("G1 source x chart points are outside the authored [0,1] domain"))
    scalar_inputs = Dict{Int64,FieldParameterGeneV1}()
    function run_one(ast::TypedASTProgramV1, coordinate, kernel_table,
            root_position::Int=1)
        _field_eval_node(ast.nodes, ast.roots[root_position], coordinate,
            scalar_inputs, Dict{Int,Any}(), kernel_table, ast.used_manifest_bindings)
    end
    values = if root_index == 1
        Tuple(begin
            chart_point = ntuple(i -> Float64(p[i]), 3)
            xi = run_one(program.x_coordinate.ast, chart_point, kernel_tables.x_coordinate)
            bubble = run_one(program.x_bubble.ast, xi, kernel_tables.x_bubble)
            run_one(program.u.ast, bubble, kernel_tables.u)
        end for p in coords)
    else
        Tuple(run_one(program.f.ast, ntuple(i -> Float64(p[i]), 3), kernel_tables.f) for p in coords)
    end
    result = _field_evaluation_result(Tuple(ntuple(i -> Float64(p[i]), 3) for p in coords),
        values, root.declared_type)
    (status=:ready, candidate_ref=capability.candidate_ref,
        g1_source_ref=capability.g1_source_ref,
        g1_declaration_ref=capability.g1_declaration_ref,
        g2_source_ref=capability.g2_source_ref,
        g2_declaration_ref=capability.g2_declaration_ref,
        program_hash=program_hash, binding_hash=binding_hash,
        root_ref=root, root_hash=canonical_hash(root), root_type=root.declared_type,
        chart_points=result.coordinates, values=result.values,
        result_hash=result.result_hash, result=result)
end

const _G1_TSP_SCHEMA = "fusionconceptai:genome-v5:g1-typed-source-field-program-v1"
const _G1_TSP_TEMPERATURE_UNIT = UnitSignature((0, 0, 0, 0, 1, 0, 0))
const _G1_TSP_COORDINATE_UNIT = UnitSignature((1, 0, 0, 0, 0, 0, 0))
const _G1_TSP_CONORMAL_UNIT = UnitSignature((0, 1, -3, 0, 0, 0, 0))
const _G1_TSP_CONDUCTIVITY_UNIT = UnitSignature((1, 1, -3, 0, -1, 0, 0))
const _G1_TSP_SOURCE_UNIT = UnitSignature((-1, 1, -3, 0, 0, 0, 0))
const _G1_TSP_DIMENSIONLESS = UnitSignature()

_g1_tsp_finite_positive(x, field) = begin
    value = Float64(x)
    isfinite(value) && value > 0.0 || throw(ArgumentError("$field must be finite and positive"))
    value
end
_g1_tsp_finite(x, field) = begin
    value = Float64(x)
    isfinite(value) || throw(ArgumentError("$field must be finite"))
    value
end

"""Build the candidate-owned u[K]/f[W m^-3] AST and its exact source bindings.

`inputs` is formed by the current T0 source authoring path from its admitted
G1/G2 declaration values. Its fields are `candidate_ref`, `g1=(source_ref,
declaration_ref,u_field_id,f_field_id,K_field_id,
u_type,K_type,f_type,grad_ref,k_apply_ref,div_ref,q_W_m3,q_unit,Kxx_W_mK,
Kxx_unit,Kxx_slope_x)`, and
`g2=(source_ref,declaration_ref,chart_ref,chart_hash,x_origin_m,x_extent_m,
reference_x_lower,reference_x_upper,T0_K,T0_unit,x_origin_unit,x_extent_unit,
faces)`, where `faces` is the actual six-face G2 source tuple. The G1 source
authoring path must store the exact returned capability at
`semantic_body.body.value.g1_typed_source_field_program`; then the enclosing T0
record hash binds the program and law without a circular self-hash. The DCCE
consumer must require object equality with that carrier and join every field to
the admitted T0 records before evaluating it. The program is a four-stage tuple
of ordinary, separately canonicalized `TypedASTProgramV1`s: chart x projection,
the dimensionless quadratic bubble, Kelvin temperature, and typed source q.
Every stage carries its own AST hash; adjacent dimensionless scalar ports are
type-checked at evaluation, and the external roots remain bound to the original
3D G2 chart input.
"""
function build_g1_steady_thermal_field_capability_v1(inputs::NamedTuple)
    candidate = inputs.candidate_ref
    g1, g2 = inputs.g1, inputs.g2
    candidate isa QualifiedRefV1 || throw(ArgumentError("candidate_ref must be QualifiedRefV1"))
    for (record, fields, label) in ((g1,
            (:source_ref, :declaration_ref, :u_field_id, :f_field_id,
             :K_field_id, :u_type, :K_type, :f_type, :grad_ref, :k_apply_ref, :div_ref,
             :q_W_m3, :q_unit, :Kxx_W_mK, :Kxx_unit, :Kxx_slope_x), :g1),
            (g2, (:source_ref, :declaration_ref, :chart_ref, :chart_hash,
             :x_origin_m, :x_extent_m, :reference_x_lower,
             :reference_x_upper, :T0_K, :T0_unit, :x_origin_unit,
             :x_extent_unit, :faces), :g2))
        all(name -> hasproperty(record, name), fields) ||
            throw(ArgumentError("$label thermal source inputs are incomplete"))
        for name in (:source_ref, :declaration_ref)
            getproperty(record, name) isa QualifiedRefV1 ||
                throw(ArgumentError("$label.$name must be an exact typed source identity"))
        end
    end
    g2.chart_ref isa QualifiedRefV1 && g2.chart_ref.version == "v1" ||
        throw(ArgumentError("G2.chart_ref must be an exact v1 QualifiedRefV1"))
    g1.u_type isa PhysicalType && g1.f_type isa PhysicalType ||
        throw(ArgumentError("G1 u/f physical types must be typed"))
    g1.u_type.tensor_rank == 0 && g1.u_type.spatial_dimension == 3 &&
        g1.u_type.temporal_type == TemporalTypeV1(static_time) &&
        g1.u_type.units == _G1_TSP_TEMPERATURE_UNIT ||
        throw(ArgumentError("G1 u root must be a static scalar Kelvin field"))
    g1.f_type.tensor_rank == 0 && g1.f_type.spatial_dimension == 3 &&
        g1.f_type.temporal_type == TemporalTypeV1(static_time) &&
        g1.f_type.units == _G1_TSP_SOURCE_UNIT ||
        throw(ArgumentError("G1 f root must be a static scalar W/m^3 field"))
    g1.K_type isa PhysicalType && g1.K_type.tensor_rank == 2 &&
        g1.K_type.spatial_dimension == 3 &&
        g1.K_type.temporal_type == TemporalTypeV1(static_time) &&
        g1.K_type.units == _G1_TSP_CONDUCTIVITY_UNIT ||
        throw(ArgumentError("G1 K component must be a static rank-two W/(m K) field"))
    g1.q_unit == _G1_TSP_SOURCE_UNIT && g1.Kxx_unit == _G1_TSP_CONDUCTIVITY_UNIT ||
        throw(ArgumentError("G1 source/conductivity scalar units mismatch"))
    q = _g1_tsp_finite(g1.q_W_m3, "q_W_m3")
    kxx = _g1_tsp_finite_positive(g1.Kxx_W_mK, "Kxx_W_mK")
    Float64(g1.Kxx_slope_x) == 0.0 ||
        throw(ArgumentError("steady planar quadratic source requires constant Kxx in x"))
    t0 = _g1_tsp_finite(g2.T0_K, "T0_K")
    origin = _g1_tsp_finite(g2.x_origin_m, "x_origin_m")
    g2.T0_unit == _G1_TSP_TEMPERATURE_UNIT && g2.x_origin_unit == _G1_TSP_COORDINATE_UNIT &&
        g2.x_extent_unit == _G1_TSP_COORDINATE_UNIT ||
        throw(ArgumentError("G2 temperature or physical x-coordinate units mismatch"))
    origin == 0.0 ||
        throw(ArgumentError("this candidate source law is defined on physical x in [0,L]"))
    length_m = _g1_tsp_finite_positive(g2.x_extent_m, "x_extent_m")
    Float64(g2.reference_x_lower) == 0.0 && Float64(g2.reference_x_upper) == 1.0 ||
        throw(ArgumentError("G2 reference x domain must be exactly [0,1]"))
    g2.faces isa Tuple && length(g2.faces) == 6 ||
        throw(ArgumentError("G2 must provide the actual six typed boundary faces"))
    all(face -> hasproperty(face, :face_id) && hasproperty(face, :face) &&
        hasproperty(face, :value) && hasproperty(face.value, :kind) &&
        hasproperty(face.value, :value) && hasproperty(face.value, :unit), g2.faces) ||
        throw(ArgumentError("G2 boundary face tuple is not the typed face-owner shape"))
    face_names = Tuple(face.face for face in g2.faces)
    Set(face_names) == Set((:x_min, :x_max, :y_min, :y_max, :z_min, :z_max)) &&
        length(unique(face_names)) == 6 ||
        throw(ArgumentError("G2 boundary faces must cover each of the six faces exactly once"))
    face_map = Dict(face.face => face for face in g2.faces)
    for name in (:x_min, :x_max)
        face = face_map[name]
        face.value.kind === :dirichlet && face.value.unit == _G1_TSP_TEMPERATURE_UNIT ||
            throw(ArgumentError("steady slab requires typed Dirichlet temperatures on both x faces"))
        _g1_tsp_finite(face.value.value, "$(name)_temperature_K")
    end
    left_temperature = Float64(face_map[:x_min].value.value)
    right_temperature = Float64(face_map[:x_max].value.value)
    t0 == left_temperature ||
        throw(ArgumentError("G2 T0 must equal the typed x_min Dirichlet temperature"))
    for name in (:y_min, :y_max, :z_min, :z_max)
        face = face_map[name]
        face.value.kind === :neumann && face.value.unit == _G1_TSP_CONORMAL_UNIT &&
            Float64(face.value.value) == 0.0 ||
            throw(ArgumentError("steady slab requires zero transverse conormal on all four faces"))
    end
    amplitude = q * length_m^2 / (2.0 * kxx)
    isfinite(amplitude) || throw(ArgumentError("derived temperature amplitude is nonfinite"))
    ntuple(i -> _G1_TSP_SOURCE_UNIT.exponents[i] + 2 * _G1_TSP_COORDINATE_UNIT.exponents[i] -
        _G1_TSP_CONDUCTIVITY_UNIT.exponents[i], 7) == _G1_TSP_TEMPERATURE_UNIT.exponents ||
        throw(ArgumentError("q*L^2/(2*Kxx) does not have Kelvin units"))

    chart = chart_coordinate_type_v1()
    scalar = PhysicalType(:scalar_field, 0, 3,
        TemporalTypeV1(static_time), _G1_TSP_DIMENSIONLESS)
    site = FieldOperatorSiteRefV1("fusionconceptai://GenomeV5/G1/steady-thermal/u-f")
    registry = default_operator_registry()
    # Keep each source operation in an ordinary typed AST. The stage outputs
    # are handed to the next AST through exact, unit-checked scalar input types.
    x_input = ASTInputV1(1, chart)
    ex = ASTConstantV1(:physical_x_axis, (1.0, 0.0, 0.0), chart)
    x = ASTApplyV1(OperatorRefV1("DOT", "v1"), (1, 2), (;);
        registry=registry, input_types=(chart, chart))
    x_program = TypedASTProgramV1((x_input, ex, x), (3,), (1,); registry=registry)

    bubble_input = ASTInputV1(1, scalar)
    one = ASTConstantV1(:one, 1.0, scalar)
    one_minus_x = ASTApplyV1(OperatorRefV1("SUB", "v1"), (2, 1), (;);
        registry=registry, input_types=(scalar, scalar))
    if left_temperature == right_temperature
        bubble = ASTApplyV1(OperatorRefV1("SCALAR_MUL", "v1"), (1, 3), (;);
            registry=registry, input_types=(scalar, scalar))
        bubble_program = TypedASTProgramV1((bubble_input, one, one_minus_x, bubble),
            (4,), (1,); registry=registry)
        temperature_input = ASTInputV1(1, scalar)
        amplitude_node = ASTConstantV1(:q_L2_over_2Kxx, amplitude, g1.u_type)
        scaled_bubble = ASTApplyV1(OperatorRefV1("SCALAR_MUL", "v1"), (1, 2), (;);
            registry=registry, input_types=(scalar, g1.u_type))
        t0_node = ASTConstantV1(:T0_at_g2_x_min, t0, g1.u_type)
        temperature = ASTApplyV1(OperatorRefV1("ADD", "v1"), (4, 3), (;);
            registry=registry, input_types=(g1.u_type, g1.u_type))
        u_program = TypedASTProgramV1((temperature_input, amplitude_node,
            scaled_bubble, t0_node, temperature), (5,), (1,); registry=registry)
    else
        amplitude_node = ASTConstantV1(:q_L2_over_2Kxx, amplitude, g1.u_type)
        scaled_quadratic = ASTApplyV1(OperatorRefV1("SCALAR_MUL", "v1"), (4, 3), (;);
            registry=registry, input_types=(g1.u_type, scalar))
        delta_node = ASTConstantV1(:T_right_minus_T_left, right_temperature-left_temperature, g1.u_type)
        lifted_slope = ASTApplyV1(OperatorRefV1("ADD", "v1"), (5, 6), (;);
            registry=registry, input_types=(g1.u_type, g1.u_type))
        temperature_correction = ASTApplyV1(OperatorRefV1("SCALAR_MUL", "v1"), (1, 7), (;);
            registry=registry, input_types=(scalar, g1.u_type))
        bubble_program = TypedASTProgramV1((bubble_input, one, one_minus_x,
            amplitude_node, scaled_quadratic, delta_node, lifted_slope,
            temperature_correction), (8,), (1,); registry=registry)
        correction_input = ASTInputV1(1, g1.u_type)
        tleft = ASTConstantV1(:T_left_at_g2_x_min, left_temperature, g1.u_type)
        temperature = ASTApplyV1(OperatorRefV1("ADD", "v1"), (2, 1), (;);
            registry=registry, input_types=(g1.u_type, g1.u_type))
        u_program = TypedASTProgramV1((correction_input, tleft, temperature),
            (3,), (1,); registry=registry)
    end
    source = ASTConstantV1(:candidate_source_q, q, g1.f_type)
    f_program = TypedASTProgramV1((source,), (1,), (); registry=registry)
    program = (x_coordinate=(ast=x_program, program_hash=canonical_hash(x_program)),
        x_bubble=(ast=bubble_program, program_hash=canonical_hash(bubble_program)),
        u=(ast=u_program, program_hash=canonical_hash(u_program)),
        f=(ast=f_program, program_hash=canonical_hash(f_program)))
    all(length(stage.ast.nodes) <= 8 for stage in values(program)) ||
        throw(ArgumentError("G1 source AST stage exceeds the P0 eight-node bound"))
    roots = (u=SpatialProgramRootRefV1(site, 1, chart, g1.u_type),
        f=SpatialProgramRootRefV1(site, 2, chart, g1.f_type))

    equal_x_faces = left_temperature == right_temperature
    source_law = (kind=:steady_planar_quadratic_diffusion_v1,
        physical_equation="-d/dx(Kxx*du/dx)=q'''; Kxx is constant in x",
        u_formula=equal_x_faces ?
            "u(x)=T0+(q'''/(2*Kxx))*x*(L-x)" :
            "u(x)=T_left+((T_right-T_left)/L)*x+(q'''/(2*Kxx))*x*(L-x)",
        chart_formula=equal_x_faces ?
            "u(xi)=T0+(q'''*L^2/(2*Kxx))*xi*(1-xi)" :
            "u(xi)=T_left+(T_right-T_left)*xi+(q'''*L^2/(2*Kxx))*xi*(1-xi)",
        source_formula="q'''(xi)=q'''",
        chart_input_type=chart, chart_input_unit=_G1_TSP_DIMENSIONLESS,
        chart_ref=g2.chart_ref, chart_hash=g2.chart_hash,
        reference_x_domain=(Float64(g2.reference_x_lower), Float64(g2.reference_x_upper)),
        physical_x_origin_m=origin, physical_x_extent_m=length_m,
        boundary_faces=Tuple(sort(collect(g2.faces), by=face -> String(face.face))),
        u_type=g1.u_type, K_type=g1.K_type, f_type=g1.f_type,
        u_field_id=String(g1.u_field_id), K_type_field_id=String(g1.K_field_id),
        f_field_id=String(g1.f_field_id), T0_K=t0, q_W_m3=q,
        Kxx_W_mK=kxx, L_m=length_m,
        bindings=(T0=(source=:G2, declaration_ref=g2.declaration_ref,
                source_ref=g2.source_ref, face_id=face_map[:x_min].face_id,
                role=:x_min_dirichlet,
                value=t0, unit=_G1_TSP_TEMPERATURE_UNIT),
            T_L=(source=:G2, declaration_ref=g2.declaration_ref,
                source_ref=g2.source_ref, face_id=face_map[:x_max].face_id,
                role=:x_max_dirichlet, value=right_temperature, unit=_G1_TSP_TEMPERATURE_UNIT),
            transverse_zero_conormal=(source=:G2, source_ref=g2.source_ref,
                declaration_ref=g2.declaration_ref,
                face_ids=Tuple(face_map[name].face_id for name in
                    (:y_min, :y_max, :z_min, :z_max)),
                role=:zero_conormal, unit=_G1_TSP_CONORMAL_UNIT),
            q=(source=:G1, source_ref=g1.source_ref,
                declaration_ref=g1.declaration_ref,
                field_id=g1.f_field_id, grad_ref=g1.grad_ref,
                k_apply_ref=g1.k_apply_ref, div_ref=g1.div_ref,
                value=q, unit=_G1_TSP_SOURCE_UNIT),
            Kxx=(source=:G1, source_ref=g1.source_ref,
                declaration_ref=g1.declaration_ref, field_id=g1.K_field_id,
                coefficient_field_id=g1.K_field_id,
                value=kxx, x_slope=Float64(g1.Kxx_slope_x), unit=_G1_TSP_CONDUCTIVITY_UNIT),
            L=(source=:G2, declaration_ref=g2.declaration_ref,
                source_ref=g2.source_ref, chart_ref=g2.chart_ref,
                value=length_m, unit=_G1_TSP_COORDINATE_UNIT)),
        authored_amplitude=(value=amplitude, unit=_G1_TSP_TEMPERATURE_UNIT))
    capability = (schema=_G1_TSP_SCHEMA, candidate_ref=candidate,
        g1_source_ref=g1.source_ref, g1_declaration_ref=g1.declaration_ref,
        g1_u_field_id=String(g1.u_field_id), g1_f_field_id=String(g1.f_field_id),
        g2_source_ref=g2.source_ref, g2_declaration_ref=g2.declaration_ref,
        program=program, roots=roots, source_law=source_law,
        program_hash=canonical_hash(program), binding_hash="")
    binding_hash = canonical_hash((candidate_ref=capability.candidate_ref,
        g1_source_ref=capability.g1_source_ref,
        g1_declaration_ref=capability.g1_declaration_ref,
        g1_u_field_id=capability.g1_u_field_id,
        g1_f_field_id=capability.g1_f_field_id,
        g2_source_ref=capability.g2_source_ref,
        g2_declaration_ref=capability.g2_declaration_ref,
        roots=capability.roots, source_law=capability.source_law))
    capability = merge(capability, (binding_hash=binding_hash,))
    body = (schema=capability.schema, candidate_ref=capability.candidate_ref,
        g1_source_ref=capability.g1_source_ref,
        g1_declaration_ref=capability.g1_declaration_ref,
        g1_u_field_id=capability.g1_u_field_id,
        g1_f_field_id=capability.g1_f_field_id,
        g2_source_ref=capability.g2_source_ref,
        g2_declaration_ref=capability.g2_declaration_ref,
        program=capability.program, roots=capability.roots,
        source_law=capability.source_law, program_hash=capability.program_hash,
        binding_hash=capability.binding_hash)
    merge(capability, (capability_hash=canonical_hash(body),))
end

const _G1_AUTHORED_TSP_SCHEMA_V1 = "fusionconceptai:genome-v5:g1-source-program-spec-v1"
const _G1_AUTHORED_SOURCE_EXPR_SCHEMA_V1 =
    "fusionconceptai:genome-v5:g1-source-expression-ast-v1"
const _G1_AUTHORED_TSP_CAP_SCHEMA_V1 =
    "fusionconceptai:genome-v5:g1-authored-typed-source-field-program-v1"

function _g1_authored_spec_normalize_v1(value)
    if value isa AbstractDict
        entries = collect(Base.pairs(value))
        names = Tuple(Symbol(String(first(pair))) for pair in entries)
        length(unique(names)) == length(names) ||
            throw(ArgumentError("candidate G1 source spec has duplicate keys"))
        values = Tuple(_g1_authored_spec_normalize_v1(last(pair)) for pair in entries)
        return NamedTuple{names}(values)
    elseif value isa AbstractVector
        return Tuple(_g1_authored_spec_normalize_v1(item) for item in value)
    end
    value
end

function _g1_authored_source_expression_root_v1(expression, role::Symbol)
    expression isa AbstractString ||
        throw(ArgumentError("candidate G1 source expression must be a string"))
    raw_text = strip(String(expression))
    startswith(raw_text, "{") || return nothing
    raw = try
        JSON3.read(raw_text)
    catch error
        throw(ArgumentError("candidate G1 source expression AST JSON is malformed: " *
            sprint(showerror, error)))
    end
    document = _g1_authored_spec_normalize_v1(raw)
    document isa NamedTuple ||
        throw(ArgumentError("candidate G1 source expression AST document must be an object"))
    hasproperty(document, :schema) ||
        throw(ArgumentError("candidate G1 source expression AST schema is missing"))
    document.schema == _G1_AUTHORED_SOURCE_EXPR_SCHEMA_V1 ||
        throw(ArgumentError("candidate G1 source expression AST schema is unsupported"))
    Set(keys(document)) == Set((:schema, :role, :nodes, :root)) ||
        throw(ArgumentError("candidate G1 source expression AST document has an invalid shape"))
    document.role == String(role) ||
        throw(ArgumentError("candidate G1 source expression AST role differs from its G1 field"))
    canonical_json(document) == raw_text ||
        throw(ArgumentError("candidate G1 source expression AST JSON is not canonical"))
    (nodes=document.nodes, root=document.root)
end

function _g1_authored_typed_source_spec_v1(g1)
    u_root = _g1_authored_source_expression_root_v1(g1.u.source_expression, :u)
    f_root = _g1_authored_source_expression_root_v1(g1.f.source_expression, :f)
    (u_root === nothing && f_root === nothing) && return nothing
    u_root !== nothing && f_root !== nothing ||
        throw(ArgumentError("candidate G1 typed source must encode both u and f AST roots"))
    (schema=_G1_AUTHORED_TSP_SCHEMA_V1, u=u_root, f=f_root)
end

_g1_authored_symbol_v1(value, label) =
    value isa Symbol ? value :
        (value isa AbstractString && isvalid(value) ? Symbol(value) :
            throw(ArgumentError("$label must be a symbol-like string")))

function _g1_authored_ast_from_spec_v1(raw, input_type::PhysicalType,
        type_roles::NamedTuple, registry::OperatorRegistryV1)
    raw isa NamedTuple && keys(raw) == (:nodes, :root) ||
        throw(ArgumentError("authored G1 AST root spec must contain nodes/root"))
    raw.nodes isa Tuple && 1 <= length(raw.nodes) <= 8 ||
        throw(ArgumentError("authored G1 AST node count exceeds the P0 eight-node bound"))
    nodes = AbstractTypedASTNodeV1[]
    input_positions = Int[]
    for (position, spec_node) in enumerate(raw.nodes)
        spec_node isa NamedTuple && hasproperty(spec_node, :kind) ||
            throw(ArgumentError("authored G1 AST node must be a typed immutable tuple"))
        kind = _g1_authored_symbol_v1(spec_node.kind, "authored G1 AST node kind")
        if kind === :input
            keys(spec_node) == (:kind, :port) && spec_node.port == 1 ||
                throw(ArgumentError("authored G1 AST input must bind the one G2 chart port"))
            push!(nodes, ASTInputV1(1, input_type))
            push!(input_positions, position)
        elseif kind === :constant
            Set(keys(spec_node)) == Set((:kind, :value, :role)) ||
                throw(ArgumentError("authored G1 AST constant has an invalid shape"))
            role = _g1_authored_symbol_v1(spec_node.role, "authored G1 AST constant role")
            haskey(type_roles, role) ||
                throw(ArgumentError("authored G1 AST constant has an unsupported type role"))
            value = if role === :chart_x_axis
                spec_node.value isa Tuple && length(spec_node.value) == 3 &&
                    all(x -> x isa Real && isfinite(Float64(x)), spec_node.value) ||
                    throw(ArgumentError("authored G1 chart axis must be a finite 3-vector"))
                Tuple(Float64.(spec_node.value))
            else
                spec_node.value isa Real && isfinite(Float64(spec_node.value)) ||
                    throw(ArgumentError("authored G1 AST constants must be finite reals"))
                Float64(spec_node.value)
            end
            push!(nodes, ASTConstantV1(:candidate_authored_constant,
                value, getproperty(type_roles, role)))
        elseif kind === :apply
            Set(keys(spec_node)) == Set((:kind, :operator, :inputs)) &&
                spec_node.operator isa String && !isempty(spec_node.operator) &&
                spec_node.inputs isa Tuple && !isempty(spec_node.inputs) ||
                throw(ArgumentError("authored G1 AST apply node has invalid operator/ports"))
            all(i -> typeof(i) === Int && 1 <= i < position, spec_node.inputs) ||
                throw(ArgumentError("authored G1 AST ports must refer to earlier nodes"))
            ref = OperatorRefV1(spec_node.operator, "v1")
            input_types = Tuple(nodes[i].output_type for i in spec_node.inputs)
            push!(nodes, ASTApplyV1(ref, spec_node.inputs, (;);
                registry=registry, input_types=input_types))
        else
            throw(ArgumentError("authored G1 AST node kind is unsupported"))
        end
    end
    length(input_positions) <= 1 ||
        throw(ArgumentError("authored G1 AST has more than one chart input"))
    typeof(raw.root) === Int && 1 <= raw.root <= length(nodes) ||
        throw(ArgumentError("authored G1 AST root position is invalid"))
    TypedASTProgramV1(Tuple(nodes), (raw.root,), Tuple(input_positions), registry)
end

function _g1_authored_typed_source_program_body_v1(capability)
    (schema=capability.schema, candidate_ref=capability.candidate_ref,
     g1_source_ref=capability.g1_source_ref,
     g1_declaration_ref=capability.g1_declaration_ref,
     g1_u_field_id=capability.g1_u_field_id, g1_f_field_id=capability.g1_f_field_id,
     g2_source_ref=capability.g2_source_ref,
     g2_declaration_ref=capability.g2_declaration_ref,
     spec_hash=capability.spec_hash, program=capability.program,
     roots=capability.roots, source_law=capability.source_law,
     program_hash=capability.program_hash, binding_hash=capability.binding_hash)
end

function _g1_authored_typed_source_semantics_v1(capability,
        registry::OperatorRegistryV1=default_operator_registry())
    capability.schema == _G1_AUTHORED_TSP_CAP_SCHEMA_V1 ||
        throw(ArgumentError("unsupported candidate-authored G1 source capability"))
    law = capability.source_law
    law.kind === :candidate_authored_typed_roots_v1 &&
        law.chart_input_type == chart_coordinate_type_v1() &&
        law.chart_ref isa QualifiedRefV1 && law.chart_hash isa Digest256 &&
        capability.g1_u_field_id == law.u_field_id &&
        capability.g1_f_field_id == law.f_field_id ||
        throw(ArgumentError("candidate-authored G1 source chart binding is malformed"))
    capability.program isa NamedTuple && keys(capability.program) == (:u, :f) &&
        capability.roots isa NamedTuple && keys(capability.roots) == (:u, :f) ||
        throw(ArgumentError("candidate-authored G1 source must bind typed u/f roots"))
    for role in (:u, :f)
        stage = getproperty(capability.program, role)
        root = getproperty(capability.roots, role)
        expected_type = getproperty(law, Symbol(role, :_type))
        stage isa NamedTuple && keys(stage) == (:ast, :program_hash) &&
            stage.ast isa TypedASTProgramV1 && stage.program_hash == canonical_hash(stage.ast) ||
            throw(ArgumentError("candidate-authored G1 root AST hash/shape mismatch"))
        ast = stage.ast
        length(ast.nodes) <= 8 && length(ast.roots) == 1 &&
            ast.input_ports in ((), (1,)) &&
            length(ast.input_ports) <= 1 ||
            throw(ArgumentError("candidate-authored G1 AST exceeds its root/port contract"))
        root isa SpatialProgramRootRefV1 && root.root_position == (role === :u ? 1 : 2) &&
            root.operator_site_ref == FieldOperatorSiteRefV1(
                capability.g1_source_ref.id * "/typed-source") &&
            root.declared_input_type == law.chart_input_type &&
            root.declared_type == expected_type ||
            throw(ArgumentError("candidate-authored G1 root is not site/type bound"))
        inputs = Tuple(node for node in ast.nodes if typeof(node) === ASTInputV1)
        length(inputs) <= 1 && (isempty(inputs) ||
            (only(inputs).port == 1 && only(inputs).output_type == law.chart_input_type)) ||
            throw(ArgumentError("candidate-authored G1 input differs from actual G2 chart"))
        any(node -> typeof(node) === ASTParameterV1, ast.nodes) &&
            throw(ArgumentError("caller parameters are not candidate-authored source constants"))
        ast.nodes[only(ast.roots)].output_type == expected_type ||
            throw(ArgumentError("candidate-authored G1 root units/type differ from declaration"))
        bindings = isempty(ast.used_manifest_bindings) ? Dict{Tuple{String,String,Digest256},Symbol}() :
            _field_operator_bindings(ast, registry)
        all(value -> value !== :unsupported_manifest, values(bindings)) ||
            throw(ArgumentError("candidate-authored G1 AST uses unsupported operator manifest"))
        for (position, node) in enumerate(ast.nodes)
            typeof(node) === ASTApplyV1 || continue
            all(i -> 1 <= i < position, node.inputs) ||
                throw(ArgumentError("candidate-authored G1 AST port is not topologically bound"))
            input_types = Tuple(ast.nodes[i].output_type for i in node.inputs)
            invoke(validate_operator_signature,
                Tuple{OperatorRegistryV1,OperatorRefV1,Any,Any},
                registry, node.operator_ref, input_types, (node.output_type,);
                parameters=node.parameters)
        end
    end
    capability.program_hash == canonical_hash(capability.program) &&
        capability.spec_hash isa Digest256 &&
        capability.candidate_ref isa QualifiedRefV1 &&
        capability.g1_source_ref isa QualifiedRefV1 &&
        capability.g1_declaration_ref isa QualifiedRefV1 &&
        capability.g2_source_ref isa QualifiedRefV1 &&
        capability.g2_declaration_ref isa QualifiedRefV1 ||
        throw(ArgumentError("candidate-authored G1 source identity/hash is malformed"))
    true
end

function build_g1_candidate_typed_source_capability_v1(inputs::NamedTuple)
    spec = _g1_authored_spec_normalize_v1(inputs.spec)
    spec isa NamedTuple && keys(spec) == (:schema, :u, :f) &&
        spec.schema == _G1_AUTHORED_TSP_SCHEMA_V1 ||
        throw(ArgumentError("candidate G1 typed source spec schema/root shape mismatch"))
    registry = default_operator_registry()
    chart = inputs.chart_input_type
    chart == chart_coordinate_type_v1() ||
        throw(ArgumentError("candidate G1 source input must use typed G2 chart coordinates"))
    dimensionless = PhysicalType(:scalar_field, 0, 3,
        TemporalTypeV1(static_time), UnitSignature())
    roles = (dimensionless=dimensionless, chart_x_axis=chart,
        u=inputs.u_type, f=inputs.f_type)
    u_ast = _g1_authored_ast_from_spec_v1(spec.u, chart, roles, registry)
    f_ast = _g1_authored_ast_from_spec_v1(spec.f, chart, roles, registry)
    program = (u=(ast=u_ast, program_hash=canonical_hash(u_ast)),
        f=(ast=f_ast, program_hash=canonical_hash(f_ast)))
    site = FieldOperatorSiteRefV1(inputs.g1_source_ref.id * "/typed-source")
    roots = (u=SpatialProgramRootRefV1(site, 1, chart, inputs.u_type),
        f=SpatialProgramRootRefV1(site, 2, chart, inputs.f_type))
    source_law = (kind=:candidate_authored_typed_roots_v1,
        chart_ref=inputs.chart_ref, chart_hash=inputs.chart_hash,
        chart_input_type=chart, u_type=inputs.u_type, f_type=inputs.f_type,
        u_field_id=inputs.u_field_id, f_field_id=inputs.f_field_id)
    draft = (schema=_G1_AUTHORED_TSP_CAP_SCHEMA_V1,
        candidate_ref=inputs.candidate_ref, g1_source_ref=inputs.g1_source_ref,
        g1_declaration_ref=inputs.g1_declaration_ref,
        g1_u_field_id=inputs.u_field_id, g1_f_field_id=inputs.f_field_id,
        g2_source_ref=inputs.g2_source_ref, g2_declaration_ref=inputs.g2_declaration_ref,
        spec_hash=canonical_hash(spec), program=program, roots=roots,
        source_law=source_law, program_hash=canonical_hash(program),
        binding_hash=Digest256(repeat("0", 64)))
    binding_hash = canonical_hash((candidate_ref=draft.candidate_ref,
        g1_source_ref=draft.g1_source_ref, g1_declaration_ref=draft.g1_declaration_ref,
        g1_u_field_id=draft.g1_u_field_id, g1_f_field_id=draft.g1_f_field_id,
        g2_source_ref=draft.g2_source_ref, g2_declaration_ref=draft.g2_declaration_ref,
        roots=draft.roots, source_law=draft.source_law, spec_hash=draft.spec_hash))
    capability = merge(draft, (binding_hash=binding_hash,))
    _g1_authored_typed_source_semantics_v1(capability, registry)
    merge(capability, (capability_hash=
        canonical_hash(_g1_authored_typed_source_program_body_v1(capability)),))
end

function _field_validate_program(program::TypedFieldProgramGeneV1, root::SpatialProgramRootRefV1,
                                 parameter_map, operator_registry::OperatorRegistryV1)
    ast = program.program
    nodes = ast.nodes
    input_positions = Tuple(i for (i, n) in enumerate(nodes) if typeof(n) === ASTInputV1)
    length(input_positions) == 1 || throw(ArgumentError("field evaluation requires exactly one AST input"))
    input = nodes[only(input_positions)]
    input.output_type.value_kind == :chart_coordinate && input.output_type.tensor_rank == 1 &&
        input.output_type.spatial_dimension == 3 ||
        throw(ArgumentError("field AST input must be a typed chart_coordinate"))
    1 <= root.root_position <= length(ast.roots) ||
        throw(ArgumentError("selected root is absent from typed program"))
    root_type = nodes[ast.roots[root.root_position]].output_type
    for (position, node) in enumerate(nodes)
        _field_node_type(node)
        if typeof(node) === ASTParameterV1
            haskey(parameter_map, position) ||
                throw(ArgumentError("AST parameter has no exact FieldProgramParameterBindingV1"))
            node.output_type.spatial_dimension == 3 ||
                throw(ArgumentError("field parameter spatial dimension is invalid"))
        elseif typeof(node) === ASTApplyV1
            id = node.operator_ref.qualified.id
            isempty(id) && throw(ArgumentError("field operator id cannot be empty"))
            all(1 <= i < position for i in node.inputs) ||
                throw(ArgumentError("field AST inputs must be topologically ordered"))
        end
    end
    root_type
end

function _field_plan_body(candidate_hash, prefix_hash, field_hash, support_ref, support_hash,
                          chart_ref, chart_hash, coordinate_map_hash, metric_hash,
                          site_ref, program_hash, root_hash,
                          parameter_hashes, program, root, parameters, bounds, grid, opcodes,
                          used_manifest_bindings, scenario_hash, code_hash, status, gaps)
    (candidate_hash=candidate_hash, prefix_hash=prefix_hash, field_geometry_hash=field_hash,
     support_ref=support_ref, support_hash=support_hash, chart_ref=chart_ref, chart_hash=chart_hash,
     coordinate_map_hash=coordinate_map_hash, metric_hash=metric_hash,
     program_site_ref=site_ref, program_hash=program_hash, root_ref_hash=root_hash,
     parameter_hashes=parameter_hashes, program=program, root=root, parameters=parameters,
     chart_bounds=bounds, grid=grid,
     allowed_opcodes=opcodes, used_manifest_bindings=used_manifest_bindings,
     scenario_hash=scenario_hash, code_hash=code_hash,
     status=status, unresolved_gaps=gaps)
end

function compile_field_evaluation_plan(candidate::CandidateStatePackageV4,
                                       compiled::CompiledCandidatePrefixV4,
                                       registry::GenomeContractRegistryV4,
                                       operator_registry::OperatorRegistryV1;
                                       scenario,
                                       grid,
                                       program_site_ref,
                                       root_position::Integer)
    _runtime_validate_compiled_prefix(compiled, candidate, registry,
        compiled.mission_payload, compiled.bounds_payload,
        compiled.minimality_scope.comparison_scope,
        compiled.minimality_scope.scenario_scope)
    compiled.candidate.canonical_hashes == candidate.canonical_hashes ||
        throw(ArgumentError("field plan candidate/prefix identity mismatch"))
    root_position isa Bool && throw(ArgumentError("root_position must be an integer"))
    root_position >= 1 || throw(ArgumentError("root_position must be positive"))
    hasproperty(scenario, :name) || throw(ArgumentError("field scenario must carry an explicit name"))
    scenario_name = _runtime_nonwild_text(getproperty(scenario, :name), "field scenario name")
    scenario_name in compiled.minimality_scope.scenario_scope ||
        throw(ArgumentError("field scenario is outside the frozen compiled scenario scope"))
    records = _field_collect(candidate.field_geometry_genome_ref.fields)
    chart = _field_chart_support(records.support)
    chart === nothing && begin
        # The declarations are still bound in the plan when possible, but no
        # evaluator is allowed to interpret multi-chart or periodic geometry.
        length(records.support.charts) >= 1 || throw(ArgumentError("spatial support has no chart"))
        length(records.support.charts) == 1 ||
            throw(ArgumentError("multi-chart field evaluation is deferred and has no executable chart selection"))
        chart = only(records.support.charts)
    end
    chart_artifacts = _field_chart_artifacts(chart)
    program = _field_choose_program(records; program_site_ref=program_site_ref)
    root = _field_choose_root(program, records.phase_set, Int(root_position))
    parameter_map = _field_parameter_map(program, records.parameters)
    kernel_table = _field_operator_bindings(program, operator_registry)
    root_type = _field_validate_program(program, root, parameter_map, operator_registry)
    grid_obj = grid isa FieldGridSpecV4 ? grid : FieldGridSpecV4(grid)
    for x in grid_obj.axes[1], y in grid_obj.axes[2], z in grid_obj.axes[3]
        coordinate = (x, y, z)
        for (i, bound) in enumerate(chart.chart_bounds)
            lower = Float64(bound.interval.lower); upper = Float64(bound.interval.upper)
            lower <= coordinate[i] <= upper ||
                throw(ArgumentError("field grid point lies outside declared chart bounds"))
        end
    end
    candidate_hash = _field_decl_hash(candidate)
    field_hash = candidate.canonical_hashes.field_geometry_hash
    canonical_hash(candidate.field_geometry_genome_ref) == field_hash ||
        throw(ArgumentError("candidate field geometry hash is not canonical"))
    scenario_hash = _runtime_scenario_hash(scenario)
    used_bindings = Tuple(sort(collect(program.program.used_manifest_bindings), by=b -> (b[1].qualified.id, b[1].qualified.version, b[2].value)))
    opcodes = Tuple(sort!(collect(unique(String(n.operator_ref.qualified.id) for n in program.program.nodes
                                      if typeof(n) === ASTApplyV1))))
    gaps = String[]
    # The plan evaluates in declared chart-coordinate space.  The chart roots are
    # declarations only; their programs are not executed by this provider.
    push!(gaps, "g2_coordinate_map_unexecuted")
    push!(gaps, "g2_metric_unexecuted")
    if length(records.support.charts) != 1
        push!(gaps, "g2_field_deferred:multi_chart")
    elseif !isempty(records.support.chart_transition_maps)
        push!(gaps, "g2_field_deferred:chart_transition")
    elseif !isempty(chart.periodic_axes)
        push!(gaps, "g2_field_deferred:periodic_grid")
    end
    root_type.temporal_type.kind == static_time && root_type.temporal_type.derivative_order == 0 ||
        push!(gaps, "g2_field_deferred:time_dependent_root")
    root_type.tensor_rank == 0 ||
        push!(gaps, "g2_field_deferred:nonscalar_root")
    for op in opcodes
        op in _FIELD_EVAL_SUPPORTED_OPS ||
            push!(gaps, op in _FIELD_EVAL_DEFERRED_OPS ?
                "g2_field_deferred:derivative_operator:$op" : "g2_field_deferred:unknown_operator:$op")
    end
    for node in program.program.nodes
        typeof(node) === ASTApplyV1 || continue
        binding = only(Tuple(b for b in program.program.used_manifest_bindings if b[1] == node.operator_ref))
        key = (node.operator_ref.qualified.id, node.operator_ref.qualified.version, binding[2])
        get(kernel_table, key, :missing) == :unsupported_manifest &&
            push!(gaps, "g2_field_deferred:operator_manifest:$(node.operator_ref.qualified.id)@$(node.operator_ref.qualified.version)")
    end
    for other in records.programs
        other == program || push!(gaps, "g2_field_scope_unselected_program:$(canonical_hash(other))")
    end
    for other_root in program.root_refs
        other_root == root || push!(gaps, "g2_field_scope_unselected_root:$(canonical_hash(other_root))")
    end
    for phase in records.phase_set.phase_fields
        phase.logit_root == root || push!(gaps, "g2_field_scope_unselected_phase:$(canonical_hash(phase))")
    end
    selected_parameter_refs = Tuple(b.parameter_ref for b in program.parameter_bindings)
    for parameter in records.parameters
        parameter.ref in selected_parameter_refs ||
            push!(gaps, "g2_field_scope_unselected_parameter:$(canonical_hash(parameter))")
    end
    bounds = chart.chart_bounds
    all(b -> b.unit == UnitSignature(), bounds) ||
        throw(ArgumentError("field chart bounds must be dimensionless"))
    body = _field_plan_body(candidate_hash, compiled.prefix_hash, field_hash,
        records.support.support_ref, canonical_hash(records.support), chart.chart_ref,
        canonical_hash(chart), chart_artifacts.coordinate_map_hash, chart_artifacts.metric_hash,
        program.operator_site_ref, canonical_hash(program),
        canonical_hash(root), Tuple(canonical_hash(p) for p in records.parameters),
        program, root, records.parameters, bounds, grid_obj, opcodes, used_bindings,
        scenario_hash, _FIELD_EVAL_CODE_HASH,
        any(startswith(g, "g2_field_deferred") || startswith(g, "g2_field_unknown") for g in gaps) ? :deferred : :ready, Tuple(sort(unique(gaps))))
    FieldEvaluationPlanV4(_FIELD_PLAN_TOKEN, body.candidate_hash, body.prefix_hash, body.field_geometry_hash,
        body.support_ref, body.support_hash, body.chart_ref, body.chart_hash,
        body.coordinate_map_hash, body.metric_hash,
        body.program_site_ref, body.program_hash, body.root_ref_hash, body.parameter_hashes,
        body.program, body.root, body.parameters, body.chart_bounds, body.grid,
        body.allowed_opcodes, body.used_manifest_bindings, body.scenario_hash, body.code_hash,
        body.status, body.unresolved_gaps, canonical_hash(body))
end

semantic_view(x::FieldEvaluationPlanV4) = (candidate_hash=x.candidate_hash,
    prefix_hash=x.prefix_hash, field_geometry_hash=x.field_geometry_hash,
    support_ref=x.support_ref, support_hash=x.support_hash, chart_ref=x.chart_ref,
    chart_hash=x.chart_hash, coordinate_map_hash=x.coordinate_map_hash,
    metric_hash=x.metric_hash, program_site_ref=x.program_site_ref, program_hash=x.program_hash,
    root_ref_hash=x.root_ref_hash, parameter_hashes=x.parameter_hashes,
    program=x.program, root=x.root, parameters=x.parameters, chart_bounds=x.chart_bounds,
    grid=x.grid, allowed_opcodes=x.allowed_opcodes, used_manifest_bindings=x.used_manifest_bindings,
    scenario_hash=x.scenario_hash, code_hash=x.code_hash, status=x.status,
    unresolved_gaps=x.unresolved_gaps, plan_hash=x.plan_hash)

struct FieldEvaluationResultV4
    coordinates::Tuple
    values::Tuple
    output_type::PhysicalType
    min_value::Union{Nothing,Float64}
    max_value::Union{Nothing,Float64}
    checksum::Digest256
    result_hash::Digest256
    function FieldEvaluationResultV4(::_FieldResultToken, coordinates, values, output_type,
                                     min_value, max_value, checksum, result_hash)
        new(Tuple(coordinates), Tuple(values), output_type, min_value, max_value, checksum, result_hash)
    end
end

function _field_evaluation_result(coordinates, values, output_type::PhysicalType)
    cs = Tuple(coordinates); vs = Tuple(values)
    length(cs) == length(vs) || throw(ArgumentError("field result coordinates and values differ in length"))
    body = (coordinates=cs, values=vs, output_type=output_type)
    is_canonical_value(body) || throw(ArgumentError("field result is not canonicalizable"))
    scalar_values = Tuple(v for v in vs if v isa Float64)
    min_value = isempty(scalar_values) ? nothing : minimum(scalar_values)
    max_value = isempty(scalar_values) ? nothing : maximum(scalar_values)
    checksum = canonical_hash(body)
    FieldEvaluationResultV4(_FIELD_RESULT_TOKEN, cs, vs, output_type, min_value, max_value, checksum,
        canonical_hash((coordinates=cs, values=vs, output_type=output_type, checksum=checksum,
                        min_value=min_value, max_value=max_value)))
end

FieldEvaluationResultV4(args...) =
    throw(ArgumentError("FieldEvaluationResultV4 is sealed; use field evaluation execution"))

semantic_view(x::FieldEvaluationResultV4) = (coordinates=x.coordinates, values=x.values,
    output_type=x.output_type,
    min_value=x.min_value, max_value=x.max_value, checksum=x.checksum, result_hash=x.result_hash)

struct FieldEvaluationReportV4
    plan::FieldEvaluationPlanV4
    status::Symbol
    result::Union{Nothing,FieldEvaluationResultV4}
    subject::Union{Nothing,ExecutablePhysicalSubjectV4}
    input::Union{Nothing,SolverInputV4}
    evidence::Union{Nothing,RuntimeEvidenceV4}
    provider_manifest_hash::Union{Nothing,Digest256}
    unresolved_gaps::Tuple{Vararg{String}}
    claim_ceiling::ClaimCeiling
end

semantic_view(x::FieldEvaluationReportV4) = (plan=x.plan, status=x.status,
    result=x.result, subject=x.subject, input=x.input, evidence=x.evidence,
    provider_manifest_hash=x.provider_manifest_hash, unresolved_gaps=x.unresolved_gaps,
    claim_ceiling=x.claim_ceiling)

function _field_value_finite(value)
    if value isa Real
        result = Float64(value)
        isfinite(result) || throw(ArgumentError("field evaluator produced a non-finite scalar"))
        return result == 0.0 ? 0.0 : result
    elseif value isa Tuple
        return Tuple(_field_value_finite(v) for v in value)
    end
    throw(ArgumentError("field evaluator produced an untyped value"))
end

function _field_scalar(value, field)
    value isa Float64 || throw(ArgumentError("$field requires a scalar Float64 value"))
    value
end

function _field_eval_node(nodes, position::Int, coordinate, parameters, cache, kernel_table, bindings)
    haskey(cache, position) && return cache[position]
    1 <= position <= length(nodes) || throw(ArgumentError("AST node position is out of range"))
    node = nodes[position]
    value = if typeof(node) === ASTInputV1
        if node.output_type == chart_coordinate_type_v1()
            coordinate
        elseif node.output_type == PhysicalType(:scalar_field, 0, 3,
                TemporalTypeV1(static_time), UnitSignature()) && isempty(node.parameters)
            coordinate isa Real && !(coordinate isa Bool) ||
                throw(ArgumentError("scalar AST input requires a scalar handoff"))
            Float64(coordinate)
        elseif node.output_type == PhysicalType(:scalar_field, 0, 3,
                TemporalTypeV1(static_time), _G1_TSP_TEMPERATURE_UNIT) &&
                isempty(node.parameters)
            coordinate isa Real && !(coordinate isa Bool) ||
                throw(ArgumentError("Kelvin AST input requires a scalar handoff"))
            _field_value_finite(coordinate)
        else
            throw(ArgumentError("AST input type/parameters mismatch"))
        end
    elseif typeof(node) === ASTParameterV1
        haskey(parameters, position) || throw(ArgumentError("unbound AST parameter"))
        _field_value_finite(field_parameter_value(parameters[position]))
    elseif typeof(node) === ASTConstantV1
        _field_value_finite(node.value)
    elseif typeof(node) === ASTApplyV1
        id = node.operator_ref.qualified.id
        id in _FIELD_EVAL_SUPPORTED_OPS || throw(ArgumentError("field operator $id is deferred or unsupported"))
        candidates = Tuple(b for b in bindings if b[1] == node.operator_ref)
        length(candidates) == 1 || throw(ArgumentError("field AST operator binding is not exact"))
        key = (node.operator_ref.qualified.id, node.operator_ref.qualified.version, candidates[1][2])
        haskey(kernel_table, key) || throw(ArgumentError("field AST operator is not in sealed kernel table"))
        id = String(kernel_table[key])
        args = Tuple(_field_eval_node(nodes, i, coordinate, parameters, cache, kernel_table, bindings) for i in node.inputs)
        if id == "IDENTITY"
            length(args) == 1 || throw(ArgumentError("IDENTITY arity mismatch")); args[1]
        elseif id == "ADD"
            length(args) == 2 || throw(ArgumentError("ADD arity mismatch"));
            _field_scalar(args[1], "ADD") + _field_scalar(args[2], "ADD")
        elseif id == "SUB"
            length(args) == 2 || throw(ArgumentError("SUB arity mismatch"));
            _field_scalar(args[1], "SUB") - _field_scalar(args[2], "SUB")
        elseif id == "NEG"
            length(args) == 1 || throw(ArgumentError("NEG arity mismatch")); -_field_scalar(args[1], "NEG")
        elseif id == "SCALAR_MUL"
            length(args) == 2 || throw(ArgumentError("SCALAR_MUL arity mismatch"));
            _field_scalar(args[1], "SCALAR_MUL") * _field_scalar(args[2], "SCALAR_MUL")
        elseif id == "DOT"
            length(args) == 2 || throw(ArgumentError("DOT arity mismatch"))
            left, right = args
            left isa Tuple && right isa Tuple && length(left) == length(right) ||
                throw(ArgumentError("DOT requires equal-length tuples"))
            sum((_field_scalar(left[i], "DOT") * _field_scalar(right[i], "DOT")
                 for i in eachindex(left)), init=0.0)
        else
            length(args) == 2 || throw(ArgumentError("SCALAR_DIV arity mismatch"))
            denominator = _field_scalar(args[2], "SCALAR_DIV")
            denominator == 0.0 && throw(ArgumentError("field evaluation division by zero"))
            _field_scalar(args[1], "SCALAR_DIV") / denominator
        end
    else
        throw(ArgumentError("field AST contains an unsealed node"))
    end
    value = _field_value_finite(value)
    cache[position] = value
    value
end

function evaluate_field_program(plan::FieldEvaluationPlanV4, program::TypedFieldProgramGeneV1,
                                root::SpatialProgramRootRefV1, parameters::Dict{Int64,FieldParameterGeneV1};
                                operator_registry::OperatorRegistryV1)
    plan.status == :ready || throw(ArgumentError("field evaluation plan is deferred: $(plan.unresolved_gaps)"))
    kernel_table = _field_operator_bindings(program, operator_registry)
    coordinates = NTuple{3,Float64}[]
    values = Any[]
    axes = plan.grid.axes
    root_position = findfirst(r -> r.root_position == root.root_position, program.root_refs)
    root_position === nothing && throw(ArgumentError("selected root is absent"))
    ast_root = program.program.roots[root_position]
    for x in axes[1], y in axes[2], z in axes[3]
        coordinate = (x, y, z)
        for (i, bound) in enumerate(plan.chart_bounds)
            lower = Float64(bound.interval.lower); upper = Float64(bound.interval.upper)
            lower <= coordinate[i] <= upper || throw(ArgumentError("grid point lies outside chart bounds"))
        end
        push!(coordinates, coordinate)
        push!(values, _field_eval_node(program.program.nodes, ast_root, coordinate, parameters, Dict{Int,Any}(), kernel_table, program.program.used_manifest_bindings))
    end
    _field_evaluation_result(Tuple(coordinates), Tuple(values), root.declared_type)
end

function _field_plan_components(candidate, plan)
    records = _field_collect(candidate.field_geometry_genome_ref.fields)
    program = _field_choose_program(records; program_site_ref=plan.program_site_ref)
    root_matches = Tuple(r for r in program.root_refs if canonical_hash(r) == plan.root_ref_hash)
    length(root_matches) == 1 || throw(ArgumentError("field plan root binding mismatch"))
    root = only(root_matches)
    params = _field_parameter_map(program, records.parameters)
    canonical_hash(records.support) == plan.support_hash || throw(ArgumentError("field support hash mismatch"))
    chart = only(records.support.charts)
    canonical_hash(chart) == plan.chart_hash || throw(ArgumentError("field chart hash mismatch"))
    artifacts = _field_chart_artifacts(chart)
    artifacts.coordinate_map_hash == plan.coordinate_map_hash &&
        artifacts.metric_hash == plan.metric_hash ||
        throw(ArgumentError("field chart artifact hash mismatch"))
    canonical_hash(program) == plan.program_hash || throw(ArgumentError("field program hash mismatch"))
    canonical_hash(root) == plan.root_ref_hash || throw(ArgumentError("field root hash mismatch"))
    Tuple(canonical_hash(p) for p in records.parameters) == plan.parameter_hashes ||
        throw(ArgumentError("field parameter hash mismatch"))
    program == plan.program || throw(ArgumentError("field program payload mismatch"))
    root == plan.root || throw(ArgumentError("field root payload mismatch"))
    Tuple(records.parameters) == plan.parameters || throw(ArgumentError("field parameter payload mismatch"))
    program, root, params
end

function _field_capability(plan::FieldEvaluationPlanV4)
    bounds = canonical_hash((candidate_hash=plan.candidate_hash, prefix_hash=plan.prefix_hash,
        field_geometry_hash=plan.field_geometry_hash, support_hash=plan.support_hash,
        chart_hash=plan.chart_hash, coordinate_map_hash=plan.coordinate_map_hash,
        metric_hash=plan.metric_hash, program_hash=plan.program_hash,
        grid_hash=plan.grid.grid_hash, scenario_hash=plan.scenario_hash))
    input_schema = canonical_hash((schema=:g2_typed_field_evaluation_input,
        plan_hash=plan.plan_hash, code_hash=plan.code_hash))
    CapabilitySignatureV4("runtime-v4", "g2-field-evaluation-v1", :g2_typed_field_evaluation,
        "typed_field_program_eval", ("chart_coordinate",), "g2_typed_field_program",
        "rectilinear_field_grid", 3, ("x", "y", "z"), "none", "none", "static",
        ("field_values", "artifact_hash"), screen_only, bounds;
        input_schema_hash=input_schema, coordinate_system="g2_chart")
end

function _field_plan_body_from_plan(plan::FieldEvaluationPlanV4)
    _field_plan_body(plan.candidate_hash, plan.prefix_hash, plan.field_geometry_hash,
        plan.support_ref, plan.support_hash, plan.chart_ref, plan.chart_hash,
        plan.coordinate_map_hash, plan.metric_hash, plan.program_site_ref,
        plan.program_hash, plan.root_ref_hash, plan.parameter_hashes,
        plan.program, plan.root, plan.parameters, plan.chart_bounds, plan.grid,
        plan.allowed_opcodes, plan.used_manifest_bindings, plan.scenario_hash,
        plan.code_hash, plan.status, plan.unresolved_gaps)
end

function _field_rehydrate_plan(payload)
    hasproperty(payload, :field_plan_hash) || throw(ArgumentError("field provider input lacks plan identity"))
    fields = (:candidate_hash, :prefix_hash, :field_geometry_hash, :support_ref, :support_hash,
        :chart_ref, :chart_hash, :coordinate_map_hash, :metric_hash, :program_site_ref,
        :program_hash, :root_ref_hash, :parameter_hashes, :program, :root, :parameters,
        :chart_bounds, :grid, :allowed_opcodes, :used_manifest_bindings, :scenario_hash,
        :code_hash, :status, :unresolved_gaps)
    all(hasproperty(payload, x) for x in fields) ||
        throw(ArgumentError("field provider payload is incomplete"))
    plan = FieldEvaluationPlanV4(_FIELD_PLAN_TOKEN, payload.candidate_hash, payload.prefix_hash,
        payload.field_geometry_hash, payload.support_ref, payload.support_hash,
        payload.chart_ref, payload.chart_hash, payload.coordinate_map_hash,
        payload.metric_hash, payload.program_site_ref, payload.program_hash,
        payload.root_ref_hash, Tuple(payload.parameter_hashes), payload.program,
        payload.root, Tuple(payload.parameters), Tuple(payload.chart_bounds), payload.grid,
        Tuple(payload.allowed_opcodes), Tuple(payload.used_manifest_bindings),
        payload.scenario_hash, payload.code_hash, payload.status,
        Tuple(payload.unresolved_gaps), payload.field_plan_hash)
    canonical_hash(_field_plan_body_from_plan(plan)) == plan.plan_hash ||
        throw(ArgumentError("field provider plan body/hash mismatch"))
    plan
end

function _field_provider_executor(input)
    payload = input.payload.materialized_payload
    plan = _field_rehydrate_plan(payload)
    input.payload.physical_subject_hash == input.physical_subject_hash ||
        throw(ArgumentError("field provider subject binding mismatch"))
    input.scenario_hash == plan.scenario_hash ||
        throw(ArgumentError("field provider scenario binding mismatch"))
    input.input_schema_hash == _field_capability(plan).input_schema_hash ||
        throw(ArgumentError("field provider input schema mismatch"))
    result = evaluate_field_program(plan, plan.program, plan.root,
        _field_parameter_map(plan.program, plan.parameters);
        operator_registry=default_operator_registry())
    (metrics=(MetricWithUnit(:grid_points, Float64(length(result.values))),),
     stage_outcome=pass, uncertainty=nothing, artifacts=(result.result_hash,))
end

function field_evaluation_manifest(plan::FieldEvaluationPlanV4)
    plan.status == :ready || throw(ArgumentError("deferred field plan has no executable provider manifest"))
    any(startswith(g, "g2_field_deferred") || startswith(g, "g2_field_unknown")
        for g in plan.unresolved_gaps) &&
        throw(ArgumentError("field provider manifest cannot cover deferred obligations"))
    capability = _field_capability(plan)
    domain = (bounds_hash=capability.applicability_bounds,
        candidate_hash=plan.candidate_hash, prefix_hash=plan.prefix_hash,
        field_geometry_hash=plan.field_geometry_hash, support_hash=plan.support_hash,
        chart_hash=plan.chart_hash, coordinate_map_hash=plan.coordinate_map_hash,
        metric_hash=plan.metric_hash, program_hash=plan.program_hash,
        root_ref_hash=plan.root_ref_hash, parameter_hashes=plan.parameter_hashes,
        grid_hash=plan.grid.grid_hash, scenario_hash=plan.scenario_hash,
        plan_hash=plan.plan_hash)
    provider = ProviderManifestV4("runtime-v4", "g2-field-evaluation-v1",
        :g2_typed_field_evaluation, capability, domain, "typed-field-interpreter", "v1",
        plan.code_hash, "runtime-v4-g2-field-evaluation", screen_only;
        input_schema_hash=capability.input_schema_hash, executor=_field_provider_executor)
    provider
end

field_evaluation_provider(plan::FieldEvaluationPlanV4) = field_evaluation_manifest(plan)

function _field_subject(candidate, compiled, plan, capability, scenario)
    payload = (field_plan_hash=plan.plan_hash, support_ref=plan.support_ref,
        candidate_hash=plan.candidate_hash, prefix_hash=plan.prefix_hash,
        field_geometry_hash=plan.field_geometry_hash, support_hash=plan.support_hash,
        chart_ref=plan.chart_ref, chart_hash=plan.chart_hash,
        coordinate_map_hash=plan.coordinate_map_hash, metric_hash=plan.metric_hash,
        program_site_ref=plan.program_site_ref, program_hash=plan.program_hash,
        root_ref_hash=plan.root_ref_hash, parameter_hashes=plan.parameter_hashes,
        grid_hash=plan.grid.grid_hash, scenario_hash=plan.scenario_hash,
        chart_bounds=plan.chart_bounds, allowed_opcodes=plan.allowed_opcodes,
        used_manifest_bindings=plan.used_manifest_bindings, code_hash=plan.code_hash,
        status=plan.status, unresolved_gaps=plan.unresolved_gaps,
        chart=plan.chart_ref, program=plan.program, root=plan.root,
        parameters=plan.parameters, grid=plan.grid)
    bindings = (candidate_hash=plan.candidate_hash, prefix_hash=plan.prefix_hash,
        field_geometry_hash=plan.field_geometry_hash, support_hash=plan.support_hash,
        chart_hash=plan.chart_hash, program_hash=plan.program_hash,
        root_ref_hash=plan.root_ref_hash, parameter_hashes=plan.parameter_hashes,
        grid_hash=plan.grid.grid_hash)
    subject = ExecutablePhysicalSubjectV4(plan.prefix_hash, candidate.canonical_hashes.genome_bundle_hash,
        canonical_hash(candidate.mission_contract_ref), compiled.minimality_scope.bounds_hash,
        (bindings,), (scenario,), payload, (capability,))
    subject
end

function _field_deferred_report(plan, reason)
    gaps = Tuple(unique((plan.unresolved_gaps..., String(reason))))
    FieldEvaluationReportV4(plan, :deferred, nothing, nothing, nothing, nothing, nothing,
        gaps, none)
end

function execute_field_evaluation(store::AbstractDict,
                                  candidate::CandidateStatePackageV4,
                                  compiled::CompiledCandidatePrefixV4,
                                  genome_registry::GenomeContractRegistryV4,
                                  operator_registry::OperatorRegistryV1,
                                  plan::FieldEvaluationPlanV4, scenario;
                                  provider=nothing)
    _runtime_validate_compiled_prefix(compiled, candidate, genome_registry,
        compiled.mission_payload, compiled.bounds_payload,
        compiled.minimality_scope.comparison_scope,
        compiled.minimality_scope.scenario_scope)
    plan.candidate_hash == _field_decl_hash(candidate) || throw(ArgumentError("field plan candidate mismatch"))
    plan.prefix_hash == compiled.prefix_hash || throw(ArgumentError("field plan prefix mismatch"))
    _runtime_scenario_hash(scenario) == plan.scenario_hash ||
        throw(ArgumentError("field scenario is outside the frozen plan"))
    expected = compile_field_evaluation_plan(candidate, compiled, genome_registry,
        operator_registry; scenario=scenario, grid=plan.grid,
        program_site_ref=plan.program_site_ref, root_position=plan.root.root_position)
    expected.plan_hash == plan.plan_hash || throw(ArgumentError("field plan body/hash is not derived from frozen inputs"))
    semantic_view(expected) == semantic_view(plan) || throw(ArgumentError("field plan payload is not the frozen derived plan"))
    plan.status == :ready || return _field_deferred_report(plan, "plan_deferred")
    provider === nothing && return _field_deferred_report(plan, "missing_provider:g2_typed_field_evaluation")
    expected_provider = field_evaluation_manifest(expected)
    provider isa ProviderManifestV4 || throw(ArgumentError("field provider must be ProviderManifestV4"))
    provider.manifest_hash == expected_provider.manifest_hash ||
        throw(ArgumentError("foreign or forged field provider manifest"))
    capability = _field_capability(plan)
    match_provider(capability, (provider,)).status == unique_match ||
        throw(ArgumentError("field provider capability does not exactly match"))
    subject = _field_subject(candidate, compiled, plan, capability, scenario)
    input = compile_solver_input(subject, scenario, capability, provider)
    if haskey(store, input.solver_input_hash)
        cached = store[input.solver_input_hash]
        cached isa RuntimeEvidenceV4 || throw(ArgumentError("field cache entry is not RuntimeEvidenceV4"))
        cached.provider_manifest_hash == provider.manifest_hash &&
            cached.physical_subject_hash == subject.physical_subject_hash &&
            cached.scenario_hash == input.scenario_hash && cached.solver_input_hash == input.solver_input_hash &&
            cached.backend_revision == provider.backend_revision &&
            cached.independence_group == provider.independence_group &&
            cached.numerical_configuration_hash == canonical_hash(input.payload.numerical_configuration) ||
            throw(ArgumentError("field cache provenance mismatch"))
    end
    evidence = execute_once!(store, input, provider)
    evidence.claim_ceiling == screen_only || throw(ArgumentError("field evidence ceiling was raised"))
    evidence.status_vector.applicability == required &&
        evidence.status_vector.match_status == unique_match &&
        evidence.status_vector.resolution == resolved &&
        evidence.status_vector.lifecycle == low_fidelity_evaluated &&
        evidence.status_vector.stage_outcome == pass ||
        throw(ArgumentError("field evidence is not exactly resolved"))
    program, root, params = _field_plan_components(candidate, plan)
    result = evaluate_field_program(plan, program, root, params; operator_registry=operator_registry)
    result.result_hash in evidence.artifact_refs || throw(ArgumentError("field artifact is not bound to evidence"))
    FieldEvaluationReportV4(plan, :evaluated_screen, result, subject, input, evidence,
        provider.manifest_hash, plan.unresolved_gaps, screen_only)
end

# Candidate-bound dynamic q input for the authenticated G1 uniform source AST.
# The frozen source AST remains the q0 reference; this sealed parameter layer
# represents one bounded runtime density value in the same W/m^3 field.
const _G1_RUNTIME_Q_SCHEMA_V1 =
    "fusionconceptai:runtime-v4:g1-bounded-source-density-parameter-v1"

_g1_runtime_q_positive_q0_v1(q0) = begin
    value = Float64(q0)
    isfinite(value) && value > 0.0 ||
        throw(ArgumentError("runtime source density reference q0 must be finite and positive"))
    value
end

struct G1RuntimeSourceDensityParameterV1
    candidate_ref::QualifiedRefV1
    g1_source_ref::QualifiedRefV1
    g1_declaration_ref::QualifiedRefV1
    g2_source_ref::QualifiedRefV1
    g2_declaration_ref::QualifiedRefV1
    f_field_id::String
    parameter_ref::FieldParameterRefV1
    q0_W_m3::Float64
    q_min_W_m3::Float64
    q_max_W_m3::Float64
    unit::UnitSignature
    profile_hash::Digest256
end

function _g1_runtime_q_profile_body_v1(profile::G1RuntimeSourceDensityParameterV1)
    (schema=_G1_RUNTIME_Q_SCHEMA_V1, candidate_ref=profile.candidate_ref,
     g1_source_ref=profile.g1_source_ref,
     g1_declaration_ref=profile.g1_declaration_ref,
     g2_source_ref=profile.g2_source_ref,
     g2_declaration_ref=profile.g2_declaration_ref,
     f_field_id=profile.f_field_id, parameter_ref=profile.parameter_ref,
     q0_W_m3=profile.q0_W_m3, q_min_W_m3=profile.q_min_W_m3,
     q_max_W_m3=profile.q_max_W_m3, unit=profile.unit)
end

semantic_view(profile::G1RuntimeSourceDensityParameterV1) =
    _g1_runtime_q_profile_body_v1(profile)
canonical_hash(profile::G1RuntimeSourceDensityParameterV1) =
    canonical_hash(semantic_view(profile))

"""Bind one bounded runtime source-density parameter to an exact G1 q0 AST."""
function g1_runtime_source_density_parameter_v1(capability;
        parameter_ref::FieldParameterRefV1,
        q_bounds_W_m3::Tuple{<:Real,<:Real})
    capability.schema == _G1_TSP_SCHEMA &&
        canonical_hash(_g1_typed_source_program_body_v1(capability)) ==
            capability.capability_hash &&
        _g1_typed_source_program_semantics_v1(capability) ||
        throw(ArgumentError("runtime source density requires the exact G1 typed source capability"))
    parameter_ref isa FieldParameterRefV1 ||
        throw(ArgumentError("runtime source density parameter ref must be FieldParameterRefV1"))
    length(q_bounds_W_m3) == 2 ||
        throw(ArgumentError("runtime source density bounds must contain two values"))
    lo, hi = Float64(q_bounds_W_m3[1]), Float64(q_bounds_W_m3[2])
    q0 = _g1_runtime_q_positive_q0_v1(capability.source_law.bindings.q.value)
    isfinite(lo) && isfinite(hi) && 0.0 <= lo < hi && lo <= q0 <= hi ||
        throw(ArgumentError("runtime source density bounds do not contain the G1 q0"))
    unit = capability.source_law.f_type.units
    unit == UnitSignature((-1, 1, -3, 0, 0, 0, 0)) ||
        throw(ArgumentError("runtime source density must retain G1 W/m^3 units"))
    draft = G1RuntimeSourceDensityParameterV1(capability.candidate_ref,
        capability.g1_source_ref, capability.g1_declaration_ref,
        capability.g2_source_ref, capability.g2_declaration_ref,
        capability.g1_f_field_id, parameter_ref, q0, lo, hi, unit,
        Digest256(repeat("0", 64)))
    body = _g1_runtime_q_profile_body_v1(draft)
    G1RuntimeSourceDensityParameterV1(draft.candidate_ref, draft.g1_source_ref,
        draft.g1_declaration_ref, draft.g2_source_ref, draft.g2_declaration_ref,
        draft.f_field_id, draft.parameter_ref, draft.q0_W_m3,
        draft.q_min_W_m3, draft.q_max_W_m3, draft.unit, canonical_hash(body))
end

struct G1RuntimeSourceDensityInputV1
    profile_hash::Digest256
    parameter_hash::Digest256
    q_W_m3::Float64
    unit::UnitSignature
    input_hash::Digest256
end

semantic_view(input::G1RuntimeSourceDensityInputV1) =
    (profile_hash=input.profile_hash, parameter_hash=input.parameter_hash,
     q_W_m3=input.q_W_m3, unit=input.unit)
canonical_hash(input::G1RuntimeSourceDensityInputV1) =
    canonical_hash(semantic_view(input))

"""Turn a typed bounded FieldParameterGene into the exact runtime q input."""
function g1_runtime_source_density_input_v1(
        profile::G1RuntimeSourceDensityParameterV1,
        parameter::FieldParameterGeneV1)
    canonical_hash(profile) == profile.profile_hash &&
        parameter.ref == profile.parameter_ref && parameter.unit == profile.unit &&
        parameter.bounds.unit == profile.unit &&
        Float64(parameter.bounds.interval.lower) == profile.q_min_W_m3 &&
        Float64(parameter.bounds.interval.upper) == profile.q_max_W_m3 &&
        parameter.transform.kind == transform_linear ||
        throw(ArgumentError("runtime q gene does not match the source-bound G1 profile"))
    q = Float64(field_parameter_value(parameter))
    isfinite(q) && profile.q_min_W_m3 <= q <= profile.q_max_W_m3 ||
        throw(ArgumentError("runtime q gene derived a value outside its declared bounds"))
    body = (profile_hash=profile.profile_hash,
        parameter_hash=canonical_hash(semantic_view(parameter)), q_W_m3=q,
        unit=profile.unit)
    G1RuntimeSourceDensityInputV1(profile.profile_hash, body.parameter_hash,
        q, profile.unit, canonical_hash(body))
end

"""Evaluate the pinned G1 f reference then apply a validated scalar q ratio."""
function evaluate_g1_runtime_source_density_v1(capability,
        profile::G1RuntimeSourceDensityParameterV1,
        input::G1RuntimeSourceDensityInputV1, chart_points;
        operator_registry::OperatorRegistryV1=default_operator_registry())
    canonical_hash(profile) == profile.profile_hash &&
        canonical_hash(input) == input.input_hash &&
        input.profile_hash == profile.profile_hash && input.unit == profile.unit &&
        profile.candidate_ref == capability.candidate_ref &&
        profile.g1_source_ref == capability.g1_source_ref &&
        profile.g1_declaration_ref == capability.g1_declaration_ref &&
        profile.g2_source_ref == capability.g2_source_ref &&
        profile.g2_declaration_ref == capability.g2_declaration_ref &&
        profile.f_field_id == capability.g1_f_field_id &&
        profile.unit == capability.source_law.f_type.units &&
        profile.q0_W_m3 == _g1_runtime_q_positive_q0_v1(
            capability.source_law.bindings.q.value) &&
        profile.q_min_W_m3 <= input.q_W_m3 <= profile.q_max_W_m3 ||
        throw(ArgumentError("runtime q profile/input does not match the current G1 source"))
    reference = evaluate_g1_typed_source_program_v1(capability,
        capability.roots.f, chart_points; operator_registry=operator_registry)
    all(==(profile.q0_W_m3), Float64.(reference.values)) ||
        throw(ArgumentError("G1 f AST no longer evaluates to the pinned reference q0"))
    values = Tuple(input.q_W_m3 * (Float64(value) / profile.q0_W_m3)
        for value in reference.values)
    body = (schema=_G1_RUNTIME_Q_SCHEMA_V1, profile_hash=profile.profile_hash,
        input_hash=input.input_hash, parameter_hash=input.parameter_hash,
        candidate_ref=profile.candidate_ref, g1_source_ref=profile.g1_source_ref,
        g1_declaration_ref=profile.g1_declaration_ref,
        g2_source_ref=profile.g2_source_ref,
        g2_declaration_ref=profile.g2_declaration_ref,
        f_field_id=profile.f_field_id, chart_points=reference.chart_points,
        values=values, unit=profile.unit)
    merge(body, (result_hash=canonical_hash(body),))
end
