"""Bounded, typed G2 field-program evaluation on a declared node grid.

This module evaluates only the closed G2 program subset declared by the plan.
It is a screen-level producer for later coupled residual/PDE work; it does not
materialize a device or close any whole-device obligation.
"""

using SHA

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
    bindings = Tuple(program.program.used_manifest_bindings)
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
    for node in program.program.nodes
        typeof(node) === ASTApplyV1 || continue
        candidates = Tuple(b for b in bindings if b[1] == node.operator_ref)
        length(candidates) == 1 || throw(ArgumentError("AST operator lacks one exact manifest binding"))
        key = (node.operator_ref.qualified.id, node.operator_ref.qualified.version, candidates[1][2])
        haskey(table, key) || throw(ArgumentError("AST operator binding is not sealed in registry"))
    end
    table
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
        node.output_type == chart_coordinate_type_v1() || throw(ArgumentError("AST input type mismatch"))
        coordinate
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
