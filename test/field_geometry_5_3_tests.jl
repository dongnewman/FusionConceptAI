using Test
using JSON3
using SHA
using FusionConceptAI

const G53_U0 = UnitSignature()
const G53_LEN = UnitSignature((0, 1, 0, 0, 0, 0, 0))

function _g53_test_fixture()
    chart_type = chart_coordinate_type_v1()
    scalar_type = phase_logit_type_v1()
    rule = ExactTypeRuleV1((chart_type, scalar_type), (scalar_type,))
    manifest = OperatorManifestV1(OperatorRefV1("CHART_TO_SCALAR", "v1"), 2, 1,
        rule, rule; pure=false, stateful=true, allowed_roles=(:governing,))
    registry = register_operator(default_operator_registry(), manifest)
    apply1 = ASTApplyV1(OperatorRefV1("CHART_TO_SCALAR", "v1"), (1, 2), (;);
        registry=registry, input_types=(chart_type, scalar_type))
    apply2 = ASTApplyV1(OperatorRefV1("CHART_TO_SCALAR", "v1"), (1, 2), (;);
        registry=registry, input_types=(chart_type, scalar_type))
    program = TypedASTProgramV1((ASTInputV1(1, chart_type), ASTParameterV1(:p, scalar_type), apply1, apply2),
        (3, 4), (1,); registry=registry)
    site = FieldOperatorSiteRefV1("site")
    root1 = SpatialProgramRootRefV1(site, 1, chart_type, scalar_type)
    root2 = SpatialProgramRootRefV1(site, 2, chart_type, scalar_type)
    binding = FieldProgramParameterBindingV1(FieldParameterRefV1("p"), 2)
    typed = TypedFieldProgramGeneV1(site, program, (root2, root1), (binding,))
    interval = QuantityIntervalV1(ExactFiniteIntervalV1(-1, 1, false), G53_U0)
    parameter = FieldParameterGeneV1(FieldParameterRefV1("p"), G53_U0,
        ParameterTransformSpecV1(transform_linear), interval, 0.0)
    frame = CoordinateFrameRefV1("frame")
    chart = CoordinateChartGeneV1(ChartRefV1("chart"), frame, (interval, interval, interval), (),
        SpatialProgramRootRefV1(FieldOperatorSiteRefV1("coordinate"), 1, chart_type,
            normalized_ambient_coordinate_type_v1()),
        SpatialProgramRootRefV1(FieldOperatorSiteRefV1("metric"), 1, chart_type,
            normalized_covariant_metric_type_v1()))
    support = SpatialSupportGeneV1(SpatialSupportRefV1("support"), 3, (frame,), (chart,), (),
        NonnegativeQuantityV1(1, G53_LEN))
    phase1 = PhaseFieldDeclarationV1(PhaseFieldRefV1("z1"), root1)
    phase2 = PhaseFieldDeclarationV1(PhaseFieldRefV1("z2"), root2)
    set = PhaseFieldSetGeneV1(support.support_ref, (parameter,), (typed,), (phase2, phase1))
    (registry=registry, program=program, typed=typed, parameter=parameter,
        support=support, phase_set=set)
end

function _g53_parameter(ref::String, unit::UnitSignature=G53_U0)
    interval = QuantityIntervalV1(ExactFiniteIntervalV1(-1, 1, false), unit)
    FieldParameterGeneV1(FieldParameterRefV1(ref), unit,
        ParameterTransformSpecV1(transform_linear), interval, 0.0)
end

function _g53_program_with_parameter_count(n::Int; site="site", root_count=1)
    chart = chart_coordinate_type_v1()
    scalar = phase_logit_type_v1()
    inputs = (chart, ntuple(_ -> scalar, n)...)
    id = "G53_PARAM_$(n)_$(site)"
    rule = ExactTypeRuleV1(inputs, (scalar,))
    manifest = OperatorManifestV1(OperatorRefV1(id, "v1"), n + 1, 1, rule, rule;
        pure=false, stateful=true, allowed_roles=(:governing,))
    registry = register_operator(default_operator_registry(), manifest)
    params = ntuple(i -> ASTParameterV1(Symbol("p_$(site)_$(i)"), scalar), n)
    apply = ASTApplyV1(OperatorRefV1(id, "v1"), (1, 2:(n + 1)...), (;);
        registry=registry, input_types=inputs)
    nodes = (ASTInputV1(1, chart), params..., apply)
    program = TypedASTProgramV1(nodes, (n + 2,), (1,); registry=registry)
    site_ref = FieldOperatorSiteRefV1(site)
    roots = ntuple(i -> SpatialProgramRootRefV1(site_ref, i, chart, scalar), root_count)
    # A single root is the normal parameter-count fixture.  The six-root
    # boundary uses a dedicated chart-only helper below.
    root_count == 1 || throw(ArgumentError("parameter fixture has one root"))
    bindings = ntuple(i -> FieldProgramParameterBindingV1(
        FieldParameterRefV1("p_$(site)_$(i)"), i + 1), n)
    TypedFieldProgramGeneV1(site_ref, program, roots, bindings)
end

function _g53_chart_root_program(root_count::Int)
    chart = chart_coordinate_type_v1()
    id = "G53_CHART_ROOT_$(root_count)"
    rule = ExactTypeRuleV1((chart,), (chart,))
    manifest = OperatorManifestV1(OperatorRefV1(id, "v1"), 1, 1, rule, rule;
        pure=false, stateful=true, allowed_roles=(:governing,))
    registry = register_operator(default_operator_registry(), manifest)
    apps = ntuple(i -> ASTApplyV1(OperatorRefV1(id, "v1"), (1,), (;);
        registry=registry, input_types=(chart,)), root_count)
    nodes = (ASTInputV1(1, chart), apps...)
    positions = ntuple(i -> i + 1, root_count)
    program = TypedASTProgramV1(nodes, positions, (1,); registry=registry)
    site = FieldOperatorSiteRefV1("chart_roots_$(root_count)")
    roots = ntuple(i -> SpatialProgramRootRefV1(site, i, chart, chart), root_count)
    TypedFieldProgramGeneV1(site, program, roots, ())
end

function _g53_zero_parameter_program(site="zero"; root_count=2)
    chart = chart_coordinate_type_v1(); scalar = phase_logit_type_v1()
    id = "G53_ZERO_$(site)"
    rule = ExactTypeRuleV1((chart,), (scalar,))
    manifest = OperatorManifestV1(OperatorRefV1(id, "v1"), 1, 1, rule, rule;
        pure=false, stateful=true, allowed_roles=(:governing,))
    registry = register_operator(default_operator_registry(), manifest)
    apps = ntuple(_ -> ASTApplyV1(OperatorRefV1(id, "v1"), (1,), (;);
        registry=registry, input_types=(chart,)), root_count)
    p = TypedASTProgramV1((ASTInputV1(1, chart), apps...),
        ntuple(i -> i + 1, root_count), (1,); registry=registry)
    s = FieldOperatorSiteRefV1(site)
    roots = ntuple(i -> SpatialProgramRootRefV1(s, i, chart, scalar), root_count)
    TypedFieldProgramGeneV1(s, p, roots, ())
end

function _g53_literal_fixture()
    chart = chart_coordinate_type_v1()
    scalar = phase_logit_type_v1()
    rule = ExactTypeRuleV1((chart, scalar), (scalar,))
    manifest = OperatorManifestV1(OperatorRefV1("LITERAL", "v1"), 2, 1, rule, rule;
        pure=false, stateful=true, allowed_roles=(:governing,))
    registry = register_operator(default_operator_registry(), manifest)
    op = OperatorRefV1("LITERAL", "v1")
    a = ASTApplyV1(op, (1, 2), (;); registry=registry, input_types=(chart, scalar))
    a2 = ASTApplyV1(op, (1, 2), (;); registry=registry, input_types=(chart, scalar))
    ast = TypedASTProgramV1((ASTInputV1(1, chart), ASTParameterV1(:p, scalar), a, a2),
        (3, 4), (1,); registry=registry)
    site = FieldOperatorSiteRefV1("literal")
    roots = (SpatialProgramRootRefV1(site, 1, chart, scalar),
             SpatialProgramRootRefV1(site, 2, chart, scalar))
    typed = TypedFieldProgramGeneV1(site, ast, (roots[2], roots[1]),
        (FieldProgramParameterBindingV1(FieldParameterRefV1("p"), 2),))
    interval = QuantityIntervalV1(ExactFiniteIntervalV1(-1, 1, false), UnitSignature())
    parameter = FieldParameterGeneV1(FieldParameterRefV1("p"), UnitSignature(),
        ParameterTransformSpecV1(transform_linear), interval, 0.0)
    phases = (PhaseFieldDeclarationV1(PhaseFieldRefV1("a"), roots[1]),
              PhaseFieldDeclarationV1(PhaseFieldRefV1("b"), roots[2]))
    set = PhaseFieldSetGeneV1(SpatialSupportRefV1("lit"), (parameter,), (typed,), phases)
    (binding=typed.parameter_bindings[1], typed=typed, phase=phases[1], set=set)
end

function _g53_permuted_fixture()
    chart = chart_coordinate_type_v1()
    scalar = phase_logit_type_v1()
    rule = ExactTypeRuleV1((chart, scalar), (scalar,))
    manifest = OperatorManifestV1(OperatorRefV1("CHART_TO_SCALAR", "v1"), 2, 1,
        rule, rule; pure=false, stateful=true, allowed_roles=(:governing,))
    registry = register_operator(default_operator_registry(), manifest)
    op = OperatorRefV1("CHART_TO_SCALAR", "v1")
    apply1 = ASTApplyV1(op, (2, 1), (;); registry=registry, input_types=(chart, scalar))
    apply2 = ASTApplyV1(op, (2, 1), (;); registry=registry, input_types=(chart, scalar))
    ast = TypedASTProgramV1((ASTParameterV1(:p, scalar), ASTInputV1(1, chart), apply1, apply2),
        (3, 4), (2,); registry=registry)
    site = FieldOperatorSiteRefV1("site")
    root1 = SpatialProgramRootRefV1(site, 1, chart, scalar)
    root2 = SpatialProgramRootRefV1(site, 2, chart, scalar)
    typed = TypedFieldProgramGeneV1(site, ast, (root2, root1),
        (FieldProgramParameterBindingV1(FieldParameterRefV1("p"), 1),))
    interval = QuantityIntervalV1(ExactFiniteIntervalV1(-1, 1, false), UnitSignature())
    parameter = FieldParameterGeneV1(FieldParameterRefV1("p"), UnitSignature(),
        ParameterTransformSpecV1(transform_linear), interval, 0.0)
    frame = CoordinateFrameRefV1("frame")
    chart_gene = CoordinateChartGeneV1(ChartRefV1("chart"), frame,
        (interval, interval, interval), (),
        SpatialProgramRootRefV1(FieldOperatorSiteRefV1("coordinate"), 1, chart,
            normalized_ambient_coordinate_type_v1()),
        SpatialProgramRootRefV1(FieldOperatorSiteRefV1("metric"), 1, chart,
            normalized_covariant_metric_type_v1()))
    support = SpatialSupportGeneV1(SpatialSupportRefV1("support"), 3, (frame,),
        (chart_gene,), (), NonnegativeQuantityV1(1, G53_LEN))
    phases = (PhaseFieldDeclarationV1(PhaseFieldRefV1("z1"), root1),
              PhaseFieldDeclarationV1(PhaseFieldRefV1("z2"), root2))
    set = PhaseFieldSetGeneV1(support.support_ref, (parameter,), (typed,),
        (phases[2], phases[1]))
    (typed=typed, phase_set=set)
end

function _g53_typed_with_parameter_type(parameter_type::PhysicalType)
    f = _g53_test_fixture()
    chart = chart_coordinate_type_v1()
    scalar = phase_logit_type_v1()
    rule = ExactTypeRuleV1((chart, parameter_type), (scalar,))
    manifest = OperatorManifestV1(OperatorRefV1("G53_ACCEPT_BAD", "v1"), 2, 1,
        rule, rule; pure=false, stateful=true, allowed_roles=(:governing,))
    registry = register_operator(default_operator_registry(), manifest)
    op = OperatorRefV1("G53_ACCEPT_BAD", "v1")
    apply = ASTApplyV1(op, (1, 2), (;); registry=registry,
        input_types=(chart, parameter_type))
    nodes = (ASTInputV1(1, chart_coordinate_type_v1()),
             ASTParameterV1(:p, parameter_type), apply)
    ast = TypedASTProgramV1(nodes, (3,), (1,); registry=registry)
    root = SpatialProgramRootRefV1(f.typed.operator_site_ref, 1, chart, scalar)
    TypedFieldProgramGeneV1(f.typed.operator_site_ref, ast, (root,),
        (FieldProgramParameterBindingV1(FieldParameterRefV1("p"), 2),))
end

function _g53_automorphism_pair()
    chart = chart_coordinate_type_v1(); scalar = phase_logit_type_v1()
    rule = ExactTypeRuleV1((chart, scalar, scalar), (scalar,))
    manifest = OperatorManifestV1(OperatorRefV1("AUTO_TIE", "v1"), 3, 1, rule, rule;
        pure=false, stateful=true, allowed_roles=(:governing,), commutative_input_groups=((2, 3),))
    registry = register_operator(default_operator_registry(), manifest)
    op = OperatorRefV1("AUTO_TIE", "v1")
    apply_a = ASTApplyV1(op, (1, 2, 3), (;); registry=registry, input_types=(chart, scalar, scalar))
    apply_b = ASTApplyV1(op, (1, 2, 3), (;); registry=registry, input_types=(chart, scalar, scalar))
    ast_a = TypedASTProgramV1((ASTInputV1(1, chart), ASTParameterV1(:p, scalar),
        ASTParameterV1(:q, scalar), apply_a), (4,), (1,); registry=registry)
    ast_b = TypedASTProgramV1((ASTInputV1(1, chart), ASTParameterV1(:q, scalar),
        ASTParameterV1(:p, scalar), apply_b), (4,), (1,); registry=registry)
    site = FieldOperatorSiteRefV1("auto_tie")
    root = SpatialProgramRootRefV1(site, 1, chart, scalar)
    typed_a = TypedFieldProgramGeneV1(site, ast_a, (root,),
        (FieldProgramParameterBindingV1(FieldParameterRefV1("p"), 2),
         FieldProgramParameterBindingV1(FieldParameterRefV1("q"), 3)))
    typed_b = TypedFieldProgramGeneV1(site, ast_b, (root,),
        (FieldProgramParameterBindingV1(FieldParameterRefV1("p"), 3),
         FieldProgramParameterBindingV1(FieldParameterRefV1("q"), 2)))
    (a=typed_a, b=typed_b)
end

function _g53_noncommutative_pair()
    chart = chart_coordinate_type_v1(); scalar = phase_logit_type_v1()
    rule = ExactTypeRuleV1((chart, scalar, scalar), (scalar,))
    manifest = OperatorManifestV1(OperatorRefV1("NONCOMM_TIE", "v1"), 3, 1, rule, rule;
        pure=false, stateful=true, allowed_roles=(:governing,))
    registry = register_operator(default_operator_registry(), manifest)
    op = OperatorRefV1("NONCOMM_TIE", "v1")
    apply_a = ASTApplyV1(op, (1, 2, 3), (;); registry=registry, input_types=(chart, scalar, scalar))
    apply_b = ASTApplyV1(op, (1, 2, 3), (;); registry=registry, input_types=(chart, scalar, scalar))
    ast_a = TypedASTProgramV1((ASTInputV1(1, chart), ASTParameterV1(:p, scalar),
        ASTParameterV1(:q, scalar), apply_a), (4,), (1,); registry=registry)
    ast_b = TypedASTProgramV1((ASTInputV1(1, chart), ASTParameterV1(:q, scalar),
        ASTParameterV1(:p, scalar), apply_b), (4,), (1,); registry=registry)
    site = FieldOperatorSiteRefV1("noncomm_tie"); root = SpatialProgramRootRefV1(site, 1, chart, scalar)
    a = TypedFieldProgramGeneV1(site, ast_a, (root,),
        (FieldProgramParameterBindingV1(FieldParameterRefV1("p"), 2),
         FieldProgramParameterBindingV1(FieldParameterRefV1("q"), 3)))
    b = TypedFieldProgramGeneV1(site, ast_b, (root,),
        (FieldProgramParameterBindingV1(FieldParameterRefV1("p"), 3),
         FieldProgramParameterBindingV1(FieldParameterRefV1("q"), 2)))
    (a=a, b=b)
end

function _g53_independent_orders(n::Int)
    out = Tuple{Vararg{Int}}[]
    work = collect(1:n)
    function visit(k::Int)
        if k > n
            push!(out, Tuple(work))
            return nothing
        end
        i = k
        while i <= n
            work[k], work[i] = work[i], work[k]
            visit(k + 1)
            work[k], work[i] = work[i], work[k]
            i += 1
        end
        nothing
    end
    visit(1)
    out
end

function _g53_independent_node_key(node::AbstractTypedASTNodeV1,
                                   nodes::Tuple)
    if node isa ASTInputV1
        return FusionConceptAI._tac_value_string(
            (kind=:input, port=node.port, parameters=node.parameters,
             output_type=node.output_type))
    elseif node isa ASTParameterV1
        return FusionConceptAI._tac_value_string(
            (kind=:parameter, parameters=node.parameters, output_type=node.output_type))
    elseif node isa ASTConstantV1
        return FusionConceptAI._tac_value_string(
            (kind=:constant, value=node.value, parameters=node.parameters,
             output_type=node.output_type))
    elseif node isa ASTApplyV1
        ids = collect(node.inputs)
        for group in node.commutative_input_groups
            positions = collect(group)
            sort!(positions, by=position ->
                _g53_independent_node_key(nodes[node.inputs[position]], nodes))
            # Equal intrinsic keys are intentionally left equal here; the
            # candidate encoder below applies mapped-position tie breaking.
            for (slot, position) in enumerate(collect(group))
                ids[position] = node.inputs[positions[slot]]
            end
        end
        return FusionConceptAI._tac_value_string(
            (kind=:apply, operator_ref=node.operator_ref,
             inputs=ntuple(i ->
                 _g53_independent_node_key(nodes[ids[i]], nodes), length(ids)),
             output_type=node.output_type, parameters=node.parameters))
    end
    error("unsealed test node")
end

function _g53_independent_commutative_inputs(node::ASTApplyV1,
                                             nodes::Tuple,
                                             inverse::Vector{Int})
    ids = collect(node.inputs)
    for group in node.commutative_input_groups
        positions = collect(group)
        i = 2
        while i <= length(positions)
            position = positions[i]
            current = node.inputs[position]
            current_key = _g53_independent_node_key(nodes[current], nodes)
            j = i - 1
            while j >= 1
                prior_position = positions[j]
                prior = node.inputs[prior_position]
                prior_key = _g53_independent_node_key(nodes[prior], nodes)
                move = current_key < prior_key ||
                    (current_key == prior_key && inverse[current] < inverse[prior])
                move || break
                positions[j + 1] = prior_position
                j -= 1
            end
            positions[j + 1] = position
            i += 1
        end
        slot = 1
        while slot <= length(positions)
            ids[getfield(group, slot)] = node.inputs[positions[slot]]
            slot += 1
        end
    end
    ids
end

function _g53_independent_candidate_text(program::TypedASTProgramV1,
                                          order::Tuple{Vararg{Int}})
    nodes = program.nodes
    n = fieldcount(typeof(nodes))
    inverse = Vector{Int}(undef, n)
    new = 1
    while new <= n
        old = order[new]
        inverse[old] = new
        new += 1
    end
    records = ntuple(new -> begin
        node = nodes[order[new]]
        if node isa ASTInputV1
            (kind=:input, port=node.port, parameters=node.parameters, output_type=node.output_type)
        elseif node isa ASTParameterV1
            (kind=:parameter, parameters=node.parameters, output_type=node.output_type)
        elseif node isa ASTConstantV1
            (kind=:constant, value=node.value, parameters=node.parameters, output_type=node.output_type)
        else
            ids = _g53_independent_commutative_inputs(node, nodes, inverse)
            (kind=:apply, operator_ref=node.operator_ref,
             inputs=ntuple(i -> inverse[ids[i]], fieldcount(typeof(node.inputs))),
             output_type=node.output_type, parameters=node.parameters)
        end
    end, n)
    ports = ntuple(i -> (port=nodes[program.input_ports[i]].port,
                         node=inverse[program.input_ports[i]]), fieldcount(typeof(program.input_ports)))
    payload = (input_ports=ports,
               nodes=records,
               roots=ntuple(i -> inverse[program.roots[i]], fieldcount(typeof(program.roots))),
               used_manifest_bindings=program.used_manifest_bindings)
    FusionConceptAI._tac_value_string(payload)
end

function _g53_independent_mapping_less(a::Tuple{Vararg{Int}}, b::Tuple{Vararg{Int}})
    i = 1
    while i <= length(a)
        a[i] < b[i] && return true
        a[i] > b[i] && return false
        i += 1
    end
    false
end

function _g53_independent_minimizers(program::TypedASTProgramV1)
    n = fieldcount(typeof(program.nodes))
    best = nothing
    mappings = Tuple{Vararg{Int}}[]
    for order in _g53_independent_orders(n)
        text = _g53_independent_candidate_text(program, order)
        inverse = Vector{Int}(undef, n)
        new = 1
        while new <= n
            inverse[order[new]] = new
            new += 1
        end
        mapping = Tuple(inverse)
        if best === nothing || FusionConceptAI._tac_text_less(text, best)
            best = text
            empty!(mappings)
            push!(mappings, mapping)
        elseif FusionConceptAI._tac_text_equal(text, best)
            push!(mappings, mapping)
        end
    end
    sort!(mappings, lt=_g53_independent_mapping_less)
    (text=best, mappings=Tuple(mappings))
end

function _g53_multigroup_triplet()
    chart = chart_coordinate_type_v1(); scalar = phase_logit_type_v1()
    rule = ExactTypeRuleV1((chart, scalar, scalar, scalar, scalar), (scalar,))
    manifest = OperatorManifestV1(OperatorRefV1("G53_GROUPS", "v1"), 5, 1,
        rule, rule; pure=false, stateful=true, allowed_roles=(:governing,),
        commutative_input_groups=((2, 3), (4, 5)))
    registry = register_operator(default_operator_registry(), manifest)
    op = OperatorRefV1("G53_GROUPS", "v1")
    function make(names, bindings)
        params = ntuple(i -> ASTParameterV1(names[i], scalar), 4)
        apply = ASTApplyV1(op, (1, 2, 3, 4, 5), (;); registry=registry,
            input_types=(chart, scalar, scalar, scalar, scalar))
        ast = TypedASTProgramV1((ASTInputV1(1, chart), params..., apply), (6,), (1,);
            registry=registry)
        site = FieldOperatorSiteRefV1("groups")
        root = SpatialProgramRootRefV1(site, 1, chart, scalar)
        TypedFieldProgramGeneV1(site, ast, (root,), bindings)
    end
    a = make((:p, :q, :r, :s),
        (FieldProgramParameterBindingV1(FieldParameterRefV1("p"), 2),
         FieldProgramParameterBindingV1(FieldParameterRefV1("q"), 3),
         FieldProgramParameterBindingV1(FieldParameterRefV1("r"), 4),
         FieldProgramParameterBindingV1(FieldParameterRefV1("s"), 5)))
    within = make((:q, :p, :s, :r),
        (FieldProgramParameterBindingV1(FieldParameterRefV1("p"), 3),
         FieldProgramParameterBindingV1(FieldParameterRefV1("q"), 2),
         FieldProgramParameterBindingV1(FieldParameterRefV1("r"), 5),
         FieldProgramParameterBindingV1(FieldParameterRefV1("s"), 4)))
    across = make((:r, :q, :p, :s),
        (FieldProgramParameterBindingV1(FieldParameterRefV1("p"), 4),
         FieldProgramParameterBindingV1(FieldParameterRefV1("q"), 3),
         FieldProgramParameterBindingV1(FieldParameterRefV1("r"), 2),
         FieldProgramParameterBindingV1(FieldParameterRefV1("s"), 5)))
    (a=a, within=within, across=across)
end

function _g53_validate_projection_mapping(program::TypedASTProgramV1,
                                          mapping::Vector{Int}, candidate)
    nodes = program.nodes
    n = fieldcount(typeof(nodes))
    length(mapping) == n || return false
    i = 1
    while i <= n
        source = nodes[i]
        target = candidate.nodes[mapping[i]]
        if source isa ASTInputV1
            target.kind === :input || return false
            source.port === target.port || return false
            canonical_json(source.parameters) == canonical_json(target.parameters) || return false
        elseif source isa ASTParameterV1
            target.kind === :parameter || return false
            canonical_json(source.parameters) == canonical_json(target.parameters) || return false
        elseif source isa ASTConstantV1
            target.kind === :constant || return false
            canonical_json((value=source.value, parameters=source.parameters)) ==
                canonical_json((value=target.value, parameters=target.parameters)) || return false
        elseif source isa ASTApplyV1
            target.kind === :apply || return false
            canonical_json((operator_ref=source.operator_ref, parameters=source.parameters)) ==
                canonical_json((operator_ref=target.operator_ref, parameters=target.parameters)) || return false
        else
            return false
        end
        canonical_json(source.output_type) == canonical_json(target.output_type) || return false
        if source isa ASTApplyV1
            target_old = 0
            old = 1
            while old <= n
                if mapping[old] == mapping[i]
                    target_old = old
                    break
                end
                old += 1
            end
            target_old === nothing && return false
            target_old == 0 && return false
            canonical_json(source.commutative_input_groups) ==
                canonical_json(nodes[target_old].commutative_input_groups) || return false
            source.pure == nodes[target_old].pure && source.cse_allowed == nodes[target_old].cse_allowed || return false
            source_inputs = source.inputs; target_inputs = target.inputs
            ni = fieldcount(typeof(source_inputs)); ni == fieldcount(typeof(target_inputs)) || return false
            grouped = falses(ni)
            for group in source.commutative_input_groups
                positions = collect(group)
                for position in positions
                    grouped[position] = true
                end
                expected = sort([mapping[source_inputs[position]] for position in positions])
                actual = sort([target_inputs[position] for position in positions])
                expected == actual || return false
            end
            for position in 1:ni
                grouped[position] || target_inputs[position] == mapping[source_inputs[position]] || return false
            end
        end
        i += 1
    end
    for i in 1:fieldcount(typeof(program.roots))
        candidate.roots[i] == mapping[program.roots[i]] || return false
    end
    for i in 1:fieldcount(typeof(program.input_ports))
        declaration = candidate.input_ports[i]
        old = program.input_ports[i]
        declaration.node == mapping[old] || return false
        declaration.port == nodes[old].port || return false
    end
    true
end

function _g53_coupled_branch_pair()
    chart = chart_coordinate_type_v1(); scalar = phase_logit_type_v1()
    branch_rule = ExactTypeRuleV1((chart, scalar), (scalar,))
    combine_rule = ExactTypeRuleV1((scalar, scalar), (scalar,))
    branch_manifest = OperatorManifestV1(OperatorRefV1("G53_BRANCH", "v1"), 2, 1,
        branch_rule, branch_rule; pure=false, stateful=true, allowed_roles=(:governing,))
    combine_manifest = OperatorManifestV1(OperatorRefV1("G53_COMBINE", "v1"), 2, 1,
        combine_rule, combine_rule; pure=false, stateful=true, allowed_roles=(:governing,),
        commutative_input_groups=((1, 2),))
    registry = register_operator(register_operator(default_operator_registry(), branch_manifest), combine_manifest)
    branch = OperatorRefV1("G53_BRANCH", "v1"); combine = OperatorRefV1("G53_COMBINE", "v1")
    function make(names, binding_positions)
        params = ntuple(i -> ASTParameterV1(names[i], scalar), 2)
        branch_a = ASTApplyV1(branch, (1, 2), (;); registry=registry, input_types=(chart, scalar))
        branch_b = ASTApplyV1(branch, (1, 3), (;); registry=registry, input_types=(chart, scalar))
        outer = ASTApplyV1(combine, (4, 5), (;); registry=registry, input_types=(scalar, scalar))
        ast = TypedASTProgramV1((ASTInputV1(1, chart), params..., branch_a, branch_b, outer),
            (6,), (1,); registry=registry)
        site = FieldOperatorSiteRefV1("coupled")
        root = SpatialProgramRootRefV1(site, 1, chart, scalar)
        TypedFieldProgramGeneV1(site, ast, (root,),
            ntuple(i -> FieldProgramParameterBindingV1(
                FieldParameterRefV1(invoke(String, Tuple{Symbol}, names[i])),
                binding_positions[i]), 2))
    end
    a = make((:p, :q), (2, 3))
    b = make((:q, :p), (3, 2))
    (a=a, b=b, registry=registry)
end

@testset "G2 5.3 typed field-program and phase-field contracts" begin
    fixture = _g53_test_fixture()
    @test phase_logit_type_v1().value_kind === :scalar_field
    @test phase_logit_type_v1().tensor_rank == 0
    @test phase_logit_type_v1().spatial_dimension == 3
    @test fixture.typed.root_refs[1].root_position == 1
    @test fixture.typed.root_refs[2].root_position == 2
    @test fixture.phase_set.phase_fields[1].phase_field_ref.value == "z1"
    @test fixture.phase_set.phase_fields[2].phase_field_ref.value == "z2"
    @test canonical_json(fixture.typed) |> JSON3.read isa JSON3.Object
    @test canonical_json(fixture.phase_set) |> JSON3.read isa JSON3.Object
    @test canonical_hash(fixture.typed) isa Digest256
    @test canonical_hash(fixture.phase_set) isa Digest256
    @test_throws ArgumentError FieldProgramParameterBindingV1(FieldParameterRefV1("p"), 0)
    bad_typed = TypedFieldProgramGeneV1(fixture.typed.operator_site_ref, fixture.program,
        fixture.typed.root_refs, (FieldProgramParameterBindingV1(FieldParameterRefV1("other"), 2),))
    @test_throws ArgumentError PhaseFieldSetGeneV1(fixture.support.support_ref,
        (fixture.parameter,), (bad_typed,), fixture.phase_set.phase_fields)
end

@testset "G2 5.3 fixed canonical envelopes and semantic identity" begin
    f = _g53_test_fixture()
    binding = f.typed.parameter_bindings[1]
    phase = f.phase_set.phase_fields[1]
    expected_binding = "{\"canonicalization_version\":\"1\",\"domain\":\"fusionconceptai:v4:g2:field_program_parameter_binding:v1\",\"kind\":\"field_program_parameter_binding\",\"payload\":{\"parameter_node_position\":2,\"parameter_ref\":{\"value\":\"p\"}}}"
    expected_phase_prefix = "{\"canonicalization_version\":\"1\",\"domain\":\"fusionconceptai:v4:g2:phase_field_declaration:v1\",\"kind\":\"phase_field_declaration\",\"payload\":{\"logit_root\":"
    @test canonical_json(binding) === expected_binding
    @test canonical_hash(binding).value === "b7ea120d0522aa992bb6e7d2e8b88ddb55ab5dc211ceba02b8d0f3180f6be3c2"
    @test startswith(canonical_json(phase), expected_phase_prefix)
    @test canonical_hash(phase).value === "47d07e7c43da098c98ed3bd218b388954f23a5d69d3d9bfc5e8549ce9e5bf2f1"
    # These are fixed captured hashes for the nontrivial nested fixture.
    @test canonical_hash(f.typed).value === "e4d8a4d1353e6594457ba9522a181b8864bd455e2d9f3ccb359dfa1ba42d67a2"
    @test canonical_hash(f.phase_set).value === "bcc1e3cebb036511ff92a46233352461e8ed0f8fc3458e7bf529d372228376a0"
    for (value, domain, kind) in ((binding, "field_program_parameter_binding", "field_program_parameter_binding"),
                                  (f.typed, "typed_field_program_gene", "typed_field_program_gene"),
                                  (phase, "phase_field_declaration", "phase_field_declaration"),
                                  (f.phase_set, "phase_field_set_gene", "phase_field_set_gene"))
        json = canonical_json(value)
        parsed = JSON3.read(json)
        @test parsed.domain == "fusionconceptai:v4:g2:$(domain):v1"
        @test parsed.kind == kind
        @test parsed.canonicalization_version == "1"
        @test canonical_hash(value).value === bytes2hex(sha256(Vector{UInt8}(codeunits(json))))
    end
    @test occursin("field_parameter_gene:v1", canonical_json(f.phase_set))
    @test occursin("used_manifest_bindings", canonical_json(f.typed))
    program_json = canonical_json(f.typed)
    set_json = canonical_json(f.phase_set)
    @test occursin("\"payload\":{\"operator_site_ref\"", program_json)
    program_graph = JSON3.read(program_json).payload.program
    @test program_graph.domain == "fusionconceptai:v4:typed_ast_graph_orbit:v1"
    @test program_graph.kind == "typed_ast_graph_orbit"
    @test program_graph.canonicalization_version == "1"
    @test program_graph.payload.nodes isa JSON3.Array
    @test findfirst("\"parameter_bindings\"", program_json) < findfirst("\"program\"", program_json) <
        findfirst("\"root_refs\"", program_json)
    @test findfirst("\"field_parameters\"", set_json) < findfirst("\"field_programs\"", set_json) <
        findfirst("\"phase_fields\"", set_json) < findfirst("\"spatial_support_ref\"", set_json)
    @test f.typed == TypedFieldProgramGeneV1(f.typed.operator_site_ref, f.program,
        (f.typed.root_refs[2], f.typed.root_refs[1]), (binding,))
    @test f.phase_set == PhaseFieldSetGeneV1(f.support.support_ref, (f.parameter,),
        (f.typed,), (f.phase_set.phase_fields[2], f.phase_set.phase_fields[1]))
    changed_site = FieldOperatorSiteRefV1("site_changed")
    changed_roots = (SpatialProgramRootRefV1(changed_site, 1, chart_coordinate_type_v1(), phase_logit_type_v1()),
                     SpatialProgramRootRefV1(changed_site, 2, chart_coordinate_type_v1(), phase_logit_type_v1()))
    changed = TypedFieldProgramGeneV1(changed_site, f.program, changed_roots, (binding,))
    @test canonical_hash(changed) != canonical_hash(f.typed)
    changed_phase = PhaseFieldDeclarationV1(PhaseFieldRefV1("z_changed"), f.phase_set.phase_fields[1].logit_root)
    @test canonical_hash(changed_phase) != canonical_hash(f.phase_set.phase_fields[1])

    # Each coupled binding/phase semantic field is exercised with a legal
    # variant, so the sensitivity assertions do not rely on malformed values.
    two = _g53_program_with_parameter_count(2; site="semantic_binding")
    rebound = ntuple(i -> FieldProgramParameterBindingV1(
        two.parameter_bindings[i].parameter_ref,
        two.parameter_bindings[3 - i].parameter_node_position), 2)
    rebound_typed = TypedFieldProgramGeneV1(two.operator_site_ref, two.program,
        two.root_refs, rebound)
    @test canonical_hash(rebound_typed) != canonical_hash(two)
    reassigned_phases = (
        PhaseFieldDeclarationV1(f.phase_set.phase_fields[1].phase_field_ref,
            f.phase_set.phase_fields[2].logit_root),
        PhaseFieldDeclarationV1(f.phase_set.phase_fields[2].phase_field_ref,
            f.phase_set.phase_fields[1].logit_root))
    reassigned_set = PhaseFieldSetGeneV1(f.phase_set.spatial_support_ref,
        (f.parameter,), (f.typed,), reassigned_phases)
    @test canonical_hash(reassigned_set) != canonical_hash(f.phase_set)
    changed_parameter = FieldParameterGeneV1(f.parameter.ref,
        f.parameter.unit, f.parameter.transform, f.parameter.bounds, 0.5)
    changed_parameter_set = PhaseFieldSetGeneV1(f.phase_set.spatial_support_ref,
        (changed_parameter,), (f.typed,), f.phase_set.phase_fields)
    @test canonical_hash(changed_parameter_set) != canonical_hash(f.phase_set)
end

@testset "G2 5.3 binding positions follow canonical AST renumbering" begin
    a = _g53_test_fixture()
    b = _g53_permuted_fixture()
    @test canonical_json(a.typed) === canonical_json(b.typed)
    @test canonical_hash(a.typed) == canonical_hash(b.typed)
    @test canonical_json(a.phase_set) === canonical_json(b.phase_set)
    @test canonical_hash(a.phase_set) == canonical_hash(b.phase_set)
    typed_json = canonical_json(a.typed)
    @test occursin("\"parameter_node_position\":3", typed_json)
    @test occursin("\"kind\":\"parameter\"", typed_json)
    six = _g53_program_with_parameter_count(6; site="binding_permutation")
    reversed = ntuple(i -> six.parameter_bindings[7 - i], 6)
    @test canonical_json(TypedFieldProgramGeneV1(six.operator_site_ref, six.program,
        six.root_refs, reversed)) === canonical_json(six)
    auto = _g53_automorphism_pair()
    @test canonical_json(auto.a) === canonical_json(auto.b)
    @test canonical_hash(auto.a) == canonical_hash(auto.b)
    auto_orbit = FusionConceptAI._tac_graph_orbit(auto.a.program)
    @test fieldcount(typeof(auto_orbit.mappings)) == 2
    auto_independent = _g53_independent_minimizers(auto.a.program)
    @test auto_orbit.canonical_text === auto_independent.text
    @test auto_orbit.mappings == auto_independent.mappings
    for mapping in auto_orbit.mappings
        @test mapping[1] === 1
        @test mapping[4] === 2
        @test Tuple(sort([mapping[2], mapping[3]])) == (3, 4)
        @test Tuple(sort([mapping[1], mapping[2], mapping[3]])) == (1, 3, 4)
        mapped = FusionConceptAI._tac_correct_candidate_for_order(auto.a.program,
            FusionConceptAI._tac_order_from_mapping(collect(mapping), 4))
        @test _g53_validate_projection_mapping(auto.a.program, collect(mapping), mapped[1])
        @test mapped[1].roots[1] === mapping[4]
        @test mapped[1].input_ports[1].node === mapping[1]
        @test getfield(mapped[1].nodes, mapping[2]).kind === :parameter
        @test getfield(mapped[1].nodes, mapping[3]).kind === :parameter
        mapped_apply = getfield(mapped[1].nodes, mapping[4])
        @test mapped_apply.kind === :apply
        @test Tuple(sort([mapped_apply.inputs[2], mapped_apply.inputs[3]])) ===
            Tuple(sort([mapping[2], mapping[3]]))
    end
    noncomm = _g53_noncommutative_pair()
    @test canonical_hash(noncomm.a) != canonical_hash(noncomm.b)
    parsed = JSON3.read(typed_json)
    binding_count = length(parsed.payload.parameter_bindings)
    for i in 1:binding_count
        binding_position = parsed.payload.parameter_bindings[i].payload.parameter_node_position
        @test parsed.payload.program.payload.nodes[binding_position].kind == "parameter"
    end
end

@testset "G2 5.3 graph-orbit inverse and full-small-Sn oracle" begin
    f = _g53_test_fixture()
    candidate, refs = FusionConceptAI._tac_correct_candidate_for_order(
        f.program, (2, 3, 1, 4))
    @test Tuple(refs) === (3, 1, 2, 4)
    @test candidate.roots === (2, 4)
    @test candidate.input_ports[1].node === 3

    # Independent three-node enumeration checks the production minimum against
    # every order, while the graph orbit exposes only semantic automorphisms.
    three = _g53_chart_root_program(2).program
    orders = ((1, 2, 3), (1, 3, 2), (2, 1, 3),
              (2, 3, 1), (3, 1, 2), (3, 2, 1))
    texts = ntuple(i -> begin
        c, _ = FusionConceptAI._tac_correct_candidate_for_order(three, orders[i])
        FusionConceptAI._tac_value_string(c)
    end, 6)
    minimum = texts[1]
    for i in 2:6
        FusionConceptAI._tac_text_less(texts[i], minimum) && (minimum = texts[i])
    end
    orbit = FusionConceptAI._tac_graph_orbit(three)
    @test fieldcount(typeof(orbit.mappings)) == 1
    @test orbit.canonical_text === minimum
    @test FusionConceptAI._TAC_GRAPH_ORBIT_DOMAIN ===
        "fusionconceptai:v4:typed_ast_graph_orbit:v1"

    # A separately implemented S4 enumeration guards the production minimum
    # without reusing its permutation generator.
    four = f.program
    independent_orders = _g53_independent_orders(4)
    @test length(independent_orders) == 24
    texts4 = map(independent_orders) do order
        c, _ = FusionConceptAI._tac_correct_candidate_for_order(four, order)
        FusionConceptAI._tac_value_string(c)
    end
    minimum4 = texts4[1]
    for i in 2:24
        FusionConceptAI._tac_text_less(texts4[i], minimum4) && (minimum4 = texts4[i])
    end
    @test FusionConceptAI._tac_graph_orbit(four).canonical_text === minimum4
end

@testset "G2 5.3 disjoint commutative groups preserve group boundaries" begin
    groups = _g53_multigroup_triplet()
    @test canonical_json(groups.a) === canonical_json(groups.within)
    @test canonical_hash(groups.a) == canonical_hash(groups.within)
    @test canonical_hash(groups.a) != canonical_hash(groups.across)
    orbit = FusionConceptAI._tac_graph_orbit(groups.a.program)
    @test fieldcount(typeof(orbit.mappings)) == 4
    independent = _g53_independent_minimizers(groups.a.program)
    @test orbit.canonical_text === independent.text
    @test orbit.mappings == independent.mappings
    for mapping in orbit.mappings
        mapped = FusionConceptAI._tac_correct_candidate_for_order(groups.a.program,
            FusionConceptAI._tac_order_from_mapping(collect(mapping), 6))
        @test _g53_validate_projection_mapping(groups.a.program, collect(mapping), mapped[1])
    end
end

@testset "G2 5.3 coupled branch orbit is not an independent Cartesian swap" begin
    branches = _g53_coupled_branch_pair()
    @test canonical_json(branches.a) === canonical_json(branches.b)
    orbit = FusionConceptAI._tac_graph_orbit(branches.a.program)
    @test fieldcount(typeof(orbit.mappings)) == 2
    for mapping in orbit.mappings
        mapped = FusionConceptAI._tac_correct_candidate_for_order(branches.a.program,
            FusionConceptAI._tac_order_from_mapping(collect(mapping), 6))
        @test _g53_validate_projection_mapping(branches.a.program, collect(mapping), mapped[1])
        # The projection mapping targets the selected canonical candidate, so
        # branch images are not compared with their original indices.  The
        # only legal witnesses are the identity branch assignment and the
        # single coupled branch swap; independent parameter/branch swaps are
        # excluded by this exact pair of mappings plus the graph validator.
        @test (Tuple(mapping) === (1, 3, 5, 2, 4, 6) ||
               Tuple(mapping) === (1, 5, 3, 4, 2, 6))
    end
end

@testset "G2 5.3 DAG sharing, stateful duplicates, roots, and alpha names" begin
    f = _g53_test_fixture()
    parsed = JSON3.read(canonical_json(f.typed)).payload.program.payload
    @test parsed.roots[1] == 2
    @test parsed.roots[2] == 4
    @test count(node -> node.kind == "apply", parsed.nodes) == 2
    orbit = FusionConceptAI._tac_graph_orbit(f.program)
    @test fieldcount(typeof(orbit.mappings)) >= 1
    for mapping in orbit.mappings
        mapped = FusionConceptAI._tac_correct_candidate_for_order(f.program,
            FusionConceptAI._tac_order_from_mapping(collect(mapping), 4))
        @test _g53_validate_projection_mapping(f.program, collect(mapping), mapped[1])
    end

    chart = chart_coordinate_type_v1(); scalar = phase_logit_type_v1()
    shared_program = TypedASTProgramV1((f.program.nodes[1], f.program.nodes[2], f.program.nodes[3]),
        (3,), (1,); registry=f.registry)
    shared_roots = (SpatialProgramRootRefV1(f.typed.operator_site_ref, 1, chart, scalar),)
    shared = TypedFieldProgramGeneV1(f.typed.operator_site_ref, shared_program, shared_roots,
        f.typed.parameter_bindings)
    @test canonical_hash(shared) != canonical_hash(f.typed)

    # Same node cardinality and local node colors, but the final operator
    # either copies two distinct branch nodes or reuses one branch twice.
    branches = _g53_coupled_branch_pair()
    copied_nodes = branches.a.program.nodes
    pair_site = FieldOperatorSiteRefV1("shared_copied")
    pair_roots = (SpatialProgramRootRefV1(pair_site, 1, chart, scalar),
                  SpatialProgramRootRefV1(pair_site, 2, chart, scalar))
    copied_program = TypedASTProgramV1(copied_nodes, (6, 5), (1,);
        registry=branches.registry)
    copied = TypedFieldProgramGeneV1(pair_site, copied_program, pair_roots,
        branches.a.parameter_bindings)
    shared_outer = ASTApplyV1(copied_nodes[6].operator_ref, (4, 4),
        copied_nodes[6].parameters; registry=branches.registry,
        input_types=(scalar, scalar))
    shared_program = TypedASTProgramV1(
        (copied_nodes[1], copied_nodes[2], copied_nodes[3], copied_nodes[4],
         copied_nodes[5], shared_outer), copied_program.roots,
        copied_program.input_ports; registry=branches.registry)
    shared_typed = TypedFieldProgramGeneV1(pair_site, shared_program,
        pair_roots, branches.a.parameter_bindings)
    @test fieldcount(typeof(shared_program.nodes)) == fieldcount(typeof(copied_program.nodes))
    @test canonical_hash(shared_typed) != canonical_hash(copied)

    renamed_program = TypedASTProgramV1((f.program.nodes[1], ASTParameterV1(:renamed, scalar),
        f.program.nodes[3], f.program.nodes[4]), f.program.roots, f.program.input_ports;
        registry=f.registry)
    renamed = TypedFieldProgramGeneV1(f.typed.operator_site_ref, renamed_program,
        f.typed.root_refs, f.typed.parameter_bindings)
    @test canonical_json(renamed) === canonical_json(f.typed)
    external = TypedFieldProgramGeneV1(f.typed.operator_site_ref, f.program,
        f.typed.root_refs, (FieldProgramParameterBindingV1(FieldParameterRefV1("external"), 2),))
    @test canonical_hash(external) != canonical_hash(f.typed)
end

@testset "G2 5.3 immutable JSONL golden fixture" begin
    fixture_path = joinpath(@__DIR__, "fixtures", "g2_53_fixed_canonical.jsonl")
    rows = split(chomp(read(fixture_path, String)), '\n')
    @test length(rows) == 4
    expected_hashes = ("b7ea120d0522aa992bb6e7d2e8b88ddb55ab5dc211ceba02b8d0f3180f6be3c2",
                       "b8f95e0ffadb147351f322d8d3e0158474e88dead33d41f5f4a2f8fc4d475255",
                       "55f8e329d88f0d85143c1c7bec2090060b8ce6f3c417ff9da7acf763627ee730",
                       "afaa6e847779a04c720d7813c0627c59d7baeb145ba90f9aa2d4c3808fd0bb70")
    literal = _g53_literal_fixture()
    values = (literal.binding, literal.typed, literal.phase, literal.set)
    for i in 1:4
        fields = split(rows[i], '|'; limit=3)
        @test length(fields) == 3
        @test JSON3.read(fields[2]) isa JSON3.Object
        @test fields[3] == expected_hashes[i]
        @test fields[3] == bytes2hex(sha256(Vector{UInt8}(codeunits(fields[2]))))
        @test canonical_json(values[i]) == fields[2]
        @test canonical_hash(values[i]).value == fields[3]
    end
end

@testset "G2 5.3 independent full-Sn minimums for n=1:7" begin
    chart = chart_coordinate_type_v1()
    one = TypedASTProgramV1((ASTInputV1(1, chart),), (1,), (1,);
        registry=default_operator_registry())
    fixtures = (one, _g53_chart_root_program(1).program,
        _g53_chart_root_program(2).program, _g53_test_fixture().program,
        _g53_program_with_parameter_count(3; site="oracle5").program,
        _g53_program_with_parameter_count(4; site="oracle6").program,
        _g53_program_with_parameter_count(5; site="oracle7").program)
    for (expected_n, program) in enumerate(fixtures)
        n = fieldcount(typeof(program.nodes))
        @test n == expected_n
        orders = _g53_independent_orders(n)
        expected_total = 1
        for i in 2:n
            expected_total *= i
        end
        @test length(orders) == expected_total
        minimum = Ref{Union{Nothing,String}}(nothing)
        for order in orders
            text = _g53_independent_candidate_text(program, order)
            if minimum[] === nothing || FusionConceptAI._tac_text_less(text, minimum[])
                minimum[] = text
            end
        end
        orbit = FusionConceptAI._tac_graph_orbit(program)
        @test orbit.canonical_text === minimum[]
        @test fieldcount(typeof(orbit.mappings)) >= 1
        i = 2
        while i <= fieldcount(typeof(orbit.mappings))
            prior = orbit.mappings[i - 1]
            current = orbit.mappings[i]
            @test FusionConceptAI._tac_mapping_less(prior, current, n)
            i += 1
        end
    end
end

@testset "G2 5.3 cardinality, closure, and type boundaries" begin
    one = _g53_program_with_parameter_count(1)
    six = _g53_program_with_parameter_count(6; site="six")
    @test fieldcount(typeof(six.parameter_bindings)) == 6
    reversed_bindings = ntuple(i -> six.parameter_bindings[7 - i], 6)
    six_reversed = TypedFieldProgramGeneV1(six.operator_site_ref, six.program,
        six.root_refs, reversed_bindings)
    @test six_reversed == six
    @test canonical_json(six_reversed) === canonical_json(six)
    @test canonical_hash(six_reversed) == canonical_hash(six)
    @test_throws ArgumentError _g53_program_with_parameter_count(7; site="seven")
    roots_one = _g53_chart_root_program(1)
    roots_six = _g53_chart_root_program(6)
    @test fieldcount(typeof(roots_one.root_refs)) == 1
    @test fieldcount(typeof(roots_six.root_refs)) == 6
    @test_throws ArgumentError _g53_chart_root_program(7)
    @test fieldcount(typeof(_g53_zero_parameter_program().parameter_bindings)) == 0
    @test_throws ArgumentError FieldProgramParameterBindingV1(FieldParameterRefV1("p"), 0)
    @test_throws ArgumentError TypedFieldProgramGeneV1(one.operator_site_ref, one.program,
        one.root_refs, (FieldProgramParameterBindingV1(FieldParameterRefV1("p"), 7),))
    @test_throws ArgumentError TypedFieldProgramGeneV1(one.operator_site_ref, one.program,
        one.root_refs, ())
    @test_throws ArgumentError TypedFieldProgramGeneV1(one.operator_site_ref, one.program,
        one.root_refs, (FieldProgramParameterBindingV1(FieldParameterRefV1("p"), 1),))
    @test_throws ArgumentError TypedFieldProgramGeneV1(one.operator_site_ref, one.program,
        one.root_refs, (FieldProgramParameterBindingV1(FieldParameterRefV1("x"), 2),
                        FieldProgramParameterBindingV1(FieldParameterRefV1("x"), 2)))
    bad_input = ASTInputV1(1, phase_logit_type_v1())
    @test_throws ArgumentError TypedFieldProgramGeneV1(one.operator_site_ref,
        TypedASTProgramV1((bad_input,), (1,), (1,); registry=one.program.used_manifest_bindings isa Tuple ? default_operator_registry() : default_operator_registry()),
        one.root_refs, one.parameter_bindings)
    bad_phase_input = SpatialProgramRootRefV1(FieldOperatorSiteRefV1("bad"), 1,
        phase_logit_type_v1(), phase_logit_type_v1())
    @test_throws ArgumentError PhaseFieldDeclarationV1(PhaseFieldRefV1("bad"), bad_phase_input)
    bad_phase_output = SpatialProgramRootRefV1(FieldOperatorSiteRefV1("bad"), 1,
        chart_coordinate_type_v1(), chart_coordinate_type_v1())
    @test_throws ArgumentError PhaseFieldDeclarationV1(PhaseFieldRefV1("bad"), bad_phase_output)
    @test_throws ArgumentError TypedFieldProgramGeneV1(one.operator_site_ref, one.program,
        one.root_refs, [one.parameter_bindings[1]])
    @test_throws ArgumentError TypedFieldProgramGeneV1(one.operator_site_ref, one.program,
        one.root_refs, (parameter_ref=one.parameter_bindings[1],))
    @test_throws ArgumentError TypedFieldProgramGeneV1(one.operator_site_ref, one.program,
        one.root_refs, (x for x in one.parameter_bindings))
    @test_throws ArgumentError TypedFieldProgramGeneV1(one.operator_site_ref, one.program,
        (SpatialProgramRootRefV1(one.operator_site_ref, 1, phase_logit_type_v1(), phase_logit_type_v1()),),
        one.parameter_bindings)
    @test_throws ArgumentError TypedFieldProgramGeneV1(one.operator_site_ref, one.program,
        [one.root_refs[1]], one.parameter_bindings)
    @test_throws ArgumentError TypedFieldProgramGeneV1(one.operator_site_ref, one.program,
        (root=one.root_refs[1],), one.parameter_bindings)
    @test_throws ArgumentError TypedFieldProgramGeneV1(one.operator_site_ref, one.program,
        (x for x in one.root_refs), one.parameter_bindings)
    @test_throws ArgumentError TypedFieldProgramGeneV1(one.operator_site_ref, one.program,
        (SpatialProgramRootRefV1(one.operator_site_ref, 1, chart_coordinate_type_v1(), phase_logit_type_v1()),
         SpatialProgramRootRefV1(one.operator_site_ref, 1, chart_coordinate_type_v1(), phase_logit_type_v1())),
        one.parameter_bindings)
    @test_throws ArgumentError TypedFieldProgramGeneV1(one.operator_site_ref, one.program,
        (SpatialProgramRootRefV1(one.operator_site_ref, 1, chart_coordinate_type_v1(), phase_logit_type_v1()),
         SpatialProgramRootRefV1(one.operator_site_ref, 3, chart_coordinate_type_v1(), phase_logit_type_v1())),
        one.parameter_bindings)
end

@testset "G2 5.3 phase-set cardinality and cross-reference closure" begin
    f = _g53_test_fixture()
    zero = _g53_zero_parameter_program()
    zroot = zero.root_refs[1]
    zroot2 = zero.root_refs[2]
    zphase1 = PhaseFieldDeclarationV1(PhaseFieldRefV1("za"), zroot)
    zphase2 = PhaseFieldDeclarationV1(PhaseFieldRefV1("zb"), zroot2)
    @test PhaseFieldSetGeneV1(SpatialSupportRefV1("s"), (), (zero,), (zphase1, zphase2)) isa PhaseFieldSetGeneV1
    @test_throws ArgumentError PhaseFieldSetGeneV1(SpatialSupportRefV1("s"), (), (), (zphase1, zphase2))
    @test_throws ArgumentError PhaseFieldSetGeneV1(SpatialSupportRefV1("s"), (), (zero,), (zphase1,))
    @test_throws ArgumentError PhaseFieldSetGeneV1(SpatialSupportRefV1("s"), (), (zero,),
        (zphase1, zphase2, zphase1, zphase2, zphase1, zphase2, zphase1))
    @test_throws ArgumentError PhaseFieldSetGeneV1(SpatialSupportRefV1("s"), (f.parameter, f.parameter),
        (f.typed,), f.phase_set.phase_fields)
    @test_throws ArgumentError PhaseFieldSetGeneV1(SpatialSupportRefV1("s"),
        (_g53_parameter("unused"),), (f.typed,), f.phase_set.phase_fields)
    wrong_unit = _g53_parameter("p", G53_LEN)
    @test_throws ArgumentError PhaseFieldSetGeneV1(SpatialSupportRefV1("s"), (wrong_unit,),
        (f.typed,), f.phase_set.phase_fields)
    bad_binding = TypedFieldProgramGeneV1(f.typed.operator_site_ref, f.program,
        f.typed.root_refs, (FieldProgramParameterBindingV1(FieldParameterRefV1("missing"), 2),))
    @test_throws ArgumentError PhaseFieldSetGeneV1(SpatialSupportRefV1("s"),
        (f.parameter,), (bad_binding,), f.phase_set.phase_fields)
    @test_throws ArgumentError PhaseFieldSetGeneV1(SpatialSupportRefV1("s"),
        (f.parameter,), (f.typed, f.typed), f.phase_set.phase_fields)
    @test_throws ArgumentError PhaseFieldSetGeneV1(SpatialSupportRefV1("s"),
        (f.parameter,), (f.typed,), (f.phase_set.phase_fields[1],
        PhaseFieldDeclarationV1(PhaseFieldRefV1("dangling"),
            SpatialProgramRootRefV1(FieldOperatorSiteRefV1("missing"), 1,
                chart_coordinate_type_v1(), phase_logit_type_v1()))))
    @test canonical_hash(f.phase_set) isa Digest256
end

@testset "G2 5.3 admission and cross-reference matrix" begin
    chart = chart_coordinate_type_v1(); scalar = phase_logit_type_v1()
    site = FieldOperatorSiteRefV1("matrix")
    one_ast = TypedASTProgramV1((ASTInputV1(1, chart),), (1,), (1,);
        registry=default_operator_registry())
    one_root = SpatialProgramRootRefV1(site, 1, chart, chart)
    one_node = TypedFieldProgramGeneV1(site, one_ast, (one_root,), ())
    @test one_node isa TypedFieldProgramGeneV1

    id_rule = ExactTypeRuleV1((chart,), (chart,))
    id_manifest = OperatorManifestV1(OperatorRefV1("G53_NINE", "v1"), 1, 1,
        id_rule, id_rule; pure=false, stateful=true, allowed_roles=(:governing,))
    id_registry = register_operator(default_operator_registry(), id_manifest)
    id_op = OperatorRefV1("G53_NINE", "v1")
    id_apps = ntuple(i -> ASTApplyV1(id_op, (i,), (;); registry=id_registry,
        input_types=(chart,)), 8)
    ast9 = TypedASTProgramV1((ASTInputV1(1, chart), id_apps...), (9,), (1,);
        registry=id_registry)
    root9 = SpatialProgramRootRefV1(site, 1, chart, chart)
    @test_throws CanonicalizationDeferred FusionConceptAI._tac_graph_orbit(ast9)
    @test_throws ArgumentError TypedFieldProgramGeneV1(site, ast9, (root9,), ())

    # A lower-layer-valid, nonempty AST with no ASTInput reaches the G2
    # exactly-one-ASTInput gate.
    zero_input = TypedASTProgramV1((ASTParameterV1(:p, scalar),), (1,), ();
        registry=default_operator_registry())
    zero_input_error = try
        TypedFieldProgramGeneV1(site, zero_input,
            (SpatialProgramRootRefV1(site, 1, chart, scalar),),
            (FieldProgramParameterBindingV1(FieldParameterRefV1("p"), 1),))
        nothing
    catch error
        error
    end
    @test zero_input_error isa ArgumentError
    @test occursin("exactly one ASTInputV1", sprint(showerror, zero_input_error))

    # Both inputs are declared exactly once below, so TypedAST accepts this;
    # the G2 one-input-port gate is then the first rejecting authority.
    two_input = TypedASTProgramV1((ASTInputV1(1, chart), ASTInputV1(2, chart)),
        (1, 2), (1, 2); registry=default_operator_registry())
    two_input_error = try
        TypedFieldProgramGeneV1(site, two_input,
            (SpatialProgramRootRefV1(site, 1, chart, chart),
             SpatialProgramRootRefV1(site, 2, chart, chart)), ())
        nothing
    catch error
        error
    end
    @test two_input_error isa ArgumentError
    @test occursin("exactly one input port", sprint(showerror, two_input_error))
    wrong_port = TypedASTProgramV1((ASTInputV1(2, chart),), (1,), (1,);
        registry=default_operator_registry())
    @test_throws ArgumentError TypedFieldProgramGeneV1(site, wrong_port,
        (one_root,), ())

    f = _g53_test_fixture()
    duplicate_node = (FieldProgramParameterBindingV1(FieldParameterRefV1("p1"), 2),
                      FieldProgramParameterBindingV1(FieldParameterRefV1("p2"), 2))
    duplicate_ref = (FieldProgramParameterBindingV1(FieldParameterRefV1("p"), 2),
                     FieldProgramParameterBindingV1(FieldParameterRefV1("p"), 3))
    two = _g53_program_with_parameter_count(2; site="binding_matrix")
    @test_throws ArgumentError TypedFieldProgramGeneV1(two.operator_site_ref, two.program,
        two.root_refs, duplicate_node)
    @test_throws ArgumentError TypedFieldProgramGeneV1(two.operator_site_ref, two.program,
        two.root_refs, duplicate_ref)

    wrong_kind = PhysicalType(:vector_field, 0, 3, TemporalTypeV1(static_time), G53_U0)
    wrong_rank = PhysicalType(:scalar_field, 1, 3, TemporalTypeV1(static_time), G53_U0)
    wrong_dim = PhysicalType(:scalar_field, 0, 2, TemporalTypeV1(static_time), G53_U0)
    wrong_time = PhysicalType(:scalar_field, 0, 3, TemporalTypeV1(differential_time), G53_U0)
    wrong_derivative = PhysicalType(:scalar_field, 0, 3,
        TemporalTypeV1(differential_time, 1, nothing), G53_U0)
    # These reach the field-program ASTParameter gate after a lower-layer-valid AST.
    for bad_type in (wrong_kind, wrong_rank, wrong_dim, wrong_time, wrong_derivative)
        parameter_gate_error = try
            _g53_typed_with_parameter_type(bad_type)
            nothing
        catch error
            error
        end
        @test parameter_gate_error isa ArgumentError
        @test occursin("ASTParameter output", sprint(showerror, parameter_gate_error))
    end
    clock_error = try
        TemporalTypeV1(static_time, 0, QualifiedRefV1("clock", "v1"))
        nothing
    catch error
        error
    end
    @test clock_error isa ArgumentError
    @test occursin("clock", lowercase(sprint(showerror, clock_error)))

    mismatched_site = SpatialProgramRootRefV1(FieldOperatorSiteRefV1("other"), 1, chart, scalar)
    mismatched_output = SpatialProgramRootRefV1(f.typed.operator_site_ref, 1, chart, chart)
    @test_throws ArgumentError TypedFieldProgramGeneV1(f.typed.operator_site_ref, f.program,
        (mismatched_site, f.typed.root_refs[2]), f.typed.parameter_bindings)
    @test_throws ArgumentError TypedFieldProgramGeneV1(f.typed.operator_site_ref, f.program,
        (mismatched_output, f.typed.root_refs[2]), f.typed.parameter_bindings)

    @test_throws ArgumentError PhaseFieldSetGeneV1(f.phase_set.spatial_support_ref,
        [f.parameter], (f.typed,), f.phase_set.phase_fields)
    @test_throws ArgumentError PhaseFieldSetGeneV1(f.phase_set.spatial_support_ref,
        (parameter=f.parameter,), (f.typed,), f.phase_set.phase_fields)
    @test_throws ArgumentError PhaseFieldSetGeneV1(f.phase_set.spatial_support_ref,
        (x for x in (f.parameter,)), (f.typed,), f.phase_set.phase_fields)
    @test_throws ArgumentError PhaseFieldSetGeneV1(f.phase_set.spatial_support_ref,
        (f.parameter,), [f.typed], f.phase_set.phase_fields)
    @test_throws ArgumentError PhaseFieldSetGeneV1(f.phase_set.spatial_support_ref,
        (f.parameter,), (program=f.typed,), f.phase_set.phase_fields)
    @test_throws ArgumentError PhaseFieldSetGeneV1(f.phase_set.spatial_support_ref,
        (f.parameter,), (x for x in (f.typed,)), f.phase_set.phase_fields)
    @test_throws ArgumentError PhaseFieldSetGeneV1(f.phase_set.spatial_support_ref,
        (f.parameter,), (f.typed,), [f.phase_set.phase_fields[1], f.phase_set.phase_fields[2]])
    @test_throws ArgumentError PhaseFieldSetGeneV1(f.phase_set.spatial_support_ref,
        (f.parameter,), (f.typed,), (phase=f.phase_set.phase_fields[1],))
    @test_throws ArgumentError PhaseFieldSetGeneV1(f.phase_set.spatial_support_ref,
        (f.parameter,), (f.typed,), (x for x in f.phase_set.phase_fields))

    duplicate_phase_ref = PhaseFieldDeclarationV1(PhaseFieldRefV1("z1"), f.phase_set.phase_fields[2].logit_root)
    duplicate_phase_root = PhaseFieldDeclarationV1(PhaseFieldRefV1("other_phase"), f.phase_set.phase_fields[1].logit_root)
    @test_throws ArgumentError PhaseFieldSetGeneV1(f.phase_set.spatial_support_ref,
        (f.parameter,), (f.typed,), (f.phase_set.phase_fields[1], duplicate_phase_ref))
    @test_throws ArgumentError PhaseFieldSetGeneV1(f.phase_set.spatial_support_ref,
        (f.parameter,), (f.typed,), (f.phase_set.phase_fields[1], duplicate_phase_root))
    changed_support = PhaseFieldSetGeneV1(SpatialSupportRefV1("support_changed"),
        (f.parameter,), (f.typed,), f.phase_set.phase_fields)
    @test canonical_hash(changed_support) != canonical_hash(f.phase_set)
    changed_binding = FieldProgramParameterBindingV1(FieldParameterRefV1("q"), 2)
    @test canonical_hash(changed_binding) != canonical_hash(f.typed.parameter_bindings[1])
end

@testset "G2 5.3 upper cardinality boundaries" begin
    programs = ntuple(i -> _g53_program_with_parameter_count(6; site="bulk_$(i)"), 6)
    parameters = ntuple(k -> begin
        program_index = div(k - 1, 6) + 1
        local_index = mod(k - 1, 6) + 1
        _g53_parameter("p_bulk_$(program_index)_$(local_index)")
    end, 36)
    phases = ntuple(i -> PhaseFieldDeclarationV1(PhaseFieldRefV1("bulk_phase_$(i)"),
        programs[i].root_refs[1]), 6)
    big = PhaseFieldSetGeneV1(SpatialSupportRefV1("bulk_support"), parameters, programs, phases)
    @test fieldcount(typeof(big.field_parameters)) == 36
    @test fieldcount(typeof(big.field_programs)) == 6
    @test fieldcount(typeof(big.phase_fields)) == 6
    @test_throws ArgumentError PhaseFieldSetGeneV1(SpatialSupportRefV1("bulk_support"),
        (parameters..., _g53_parameter("overflow")), programs, phases)
    extra_root = _g53_zero_parameter_program("extra"; root_count=2)
    singles = ntuple(i -> _g53_zero_parameter_program("single_$(i)"; root_count=1), 5)
    seven_programs = (extra_root, singles...)
    seven_phases = (PhaseFieldDeclarationV1(PhaseFieldRefV1("r1"), extra_root.root_refs[1]),
                    PhaseFieldDeclarationV1(PhaseFieldRefV1("r2"), extra_root.root_refs[2]),
                    PhaseFieldDeclarationV1(PhaseFieldRefV1("r3"), singles[1].root_refs[1]),
                    PhaseFieldDeclarationV1(PhaseFieldRefV1("r4"), singles[2].root_refs[1]),
                    PhaseFieldDeclarationV1(PhaseFieldRefV1("r5"), singles[3].root_refs[1]),
                    PhaseFieldDeclarationV1(PhaseFieldRefV1("r6"), singles[4].root_refs[1]))
    @test_throws ArgumentError PhaseFieldSetGeneV1(SpatialSupportRefV1("roots7"),
        (), seven_programs, seven_phases)
    programs7 = ntuple(i -> _g53_zero_parameter_program("p7_$(i)"; root_count=1), 7)
    @test_throws ArgumentError PhaseFieldSetGeneV1(SpatialSupportRefV1("programs7"), (),
        programs7, (PhaseFieldDeclarationV1(PhaseFieldRefV1("a"), programs7[1].root_refs[1]),
                    PhaseFieldDeclarationV1(PhaseFieldRefV1("b"), programs7[2].root_refs[1])))
    reverse_parameters = ntuple(i -> parameters[37 - i], 36)
    reverse_programs = ntuple(i -> programs[7 - i], 6)
    reverse_phases = ntuple(i -> phases[7 - i], 6)
    big_reversed = PhaseFieldSetGeneV1(SpatialSupportRefV1("bulk_support"),
        reverse_parameters, reverse_programs, reverse_phases)
    @test big_reversed == big
    @test canonical_json(big_reversed) === canonical_json(big)
    @test canonical_hash(big_reversed) == canonical_hash(big)
    z_a = _g53_zero_parameter_program("same_ordinal_a")
    z_b = _g53_zero_parameter_program("same_ordinal_b")
    same_ordinal_phases = (PhaseFieldDeclarationV1(PhaseFieldRefV1("sa1"), z_a.root_refs[1]),
                           PhaseFieldDeclarationV1(PhaseFieldRefV1("sa2"), z_a.root_refs[2]),
                           PhaseFieldDeclarationV1(PhaseFieldRefV1("sb1"), z_b.root_refs[1]),
                           PhaseFieldDeclarationV1(PhaseFieldRefV1("sb2"), z_b.root_refs[2]))
    @test PhaseFieldSetGeneV1(SpatialSupportRefV1("same_ordinal"), (), (z_a, z_b),
        same_ordinal_phases) isa PhaseFieldSetGeneV1
end

@testset "G2 5.3 manifest-derived identity" begin
    f = _g53_test_fixture()
    original = operator_manifest(f.registry, "CHART_TO_SCALAR", "v1")
    altered = OperatorManifestV1(original.operator_ref, original.input_arity, original.output_arity,
        original.input_type_rule, original.output_type_rule;
        allowed_roles=(:boundary, :governing), parameter_schema=original.parameter_schema,
        locality=original.locality, max_derivative_contribution=Int(original.max_derivative_contribution),
        pure=original.pure, stateful=original.stateful, stochastic=original.stochastic,
        event=original.event, commutative_input_groups=original.commutative_input_groups,
        cse_allowed=original.cse_allowed,
        allowed_conservation_effects=original.allowed_conservation_effects,
        forbidden_conservation_effects=original.forbidden_conservation_effects)
    registry = register_operator(default_operator_registry(), altered)
    chart = chart_coordinate_type_v1(); scalar = phase_logit_type_v1()
    op = OperatorRefV1("CHART_TO_SCALAR", "v1")
    a1 = ASTApplyV1(op, (1, 2), (;); registry=registry, input_types=(chart, scalar))
    a2 = ASTApplyV1(op, (1, 2), (;); registry=registry, input_types=(chart, scalar))
    ast = TypedASTProgramV1((ASTInputV1(1, chart), ASTParameterV1(:p, scalar), a1, a2),
        (3, 4), (1,); registry=registry)
    site = FieldOperatorSiteRefV1("site")
    roots = (SpatialProgramRootRefV1(site, 1, chart, scalar),
             SpatialProgramRootRefV1(site, 2, chart, scalar))
    typed = TypedFieldProgramGeneV1(site, ast, roots,
        (FieldProgramParameterBindingV1(FieldParameterRefV1("p"), 2),))
    @test canonical_hash(typed) != canonical_hash(f.typed)
    altered_phases = (PhaseFieldDeclarationV1(PhaseFieldRefV1("z1"), roots[1]),
                      PhaseFieldDeclarationV1(PhaseFieldRefV1("z2"), roots[2]))
    altered_set = PhaseFieldSetGeneV1(f.support.support_ref, (f.parameter,), (typed,), altered_phases)
    @test canonical_hash(altered_set) != canonical_hash(f.phase_set)
end

@testset "G2 5.3 fresh-process authority boundary" begin
    function _g53_probe(definition, trigger; check_public=false)
        script = raw"""
        using FusionConceptAI
        using SHA
        const HIT = Ref(false)
        chart = PhysicalType(:chart_coordinate, 1, 3, TemporalTypeV1(static_time), UnitSignature())
        scalar = PhysicalType(:scalar_field, 0, 3, TemporalTypeV1(static_time), UnitSignature())
        rule = ExactTypeRuleV1((chart, scalar), (scalar,))
        manifest = OperatorManifestV1(OperatorRefV1("G53_PROBE", "v1"), 2, 1, rule, rule;
            pure=false, stateful=true, allowed_roles=(:governing,))
        registry = register_operator(default_operator_registry(), manifest)
        apply = ASTApplyV1(OperatorRefV1("G53_PROBE", "v1"), (1, 2), (;);
            registry=registry, input_types=(chart, scalar))
        apply2 = ASTApplyV1(OperatorRefV1("G53_PROBE", "v1"), (1, 2), (;);
            registry=registry, input_types=(chart, scalar))
        ast = TypedASTProgramV1((ASTInputV1(1, chart), ASTParameterV1(:p, scalar), apply, apply2),
            (3, 4), (1,); registry=registry)
        site = FieldOperatorSiteRefV1("probe")
        root = SpatialProgramRootRefV1(site, 1, chart, scalar)
        root2 = SpatialProgramRootRefV1(site, 2, chart, scalar)
        typed = TypedFieldProgramGeneV1(site, ast, (root2, root),
            (FieldProgramParameterBindingV1(FieldParameterRefV1("p"), 2),))
        interval = QuantityIntervalV1(ExactFiniteIntervalV1(-1, 1, false), UnitSignature())
        parameter = FieldParameterGeneV1(FieldParameterRefV1("p"), UnitSignature(),
            ParameterTransformSpecV1(transform_linear), interval, 0.0)
        phase = PhaseFieldDeclarationV1(PhaseFieldRefV1("phase"), root)
        phase2 = PhaseFieldDeclarationV1(PhaseFieldRefV1("phase2"), root2)
        set = PhaseFieldSetGeneV1(SpatialSupportRefV1("support"), (parameter,), (typed,), (phase2, phase))
        base_t = FusionConceptAI._g53_program_json(typed)
        base_s = FusionConceptAI._g53_set_json(set)
        public_s = canonical_json(set)
        public_sh = canonical_hash(set).value
        public_t = canonical_json(typed)
        public_th = canonical_hash(typed).value
        public_p = canonical_json(parameter)
        public_ph = canonical_hash(parameter).value
        binding = typed.parameter_bindings[1]
        public_b = canonical_json(binding)
        public_bh = canonical_hash(binding).value
        public_r = canonical_json(root)
        public_rh = canonical_hash(root).value
        public_phase = canonical_json(phase)
        public_phaseh = canonical_hash(phase).value
        base_th = FusionConceptAI._g25_hash_bytes(base_t).value
        base_sh = FusionConceptAI._g25_hash_bytes(base_s).value
        __DEFINITION__
        __TRIGGER__
        @assert HIT[]
        @assert base_t === FusionConceptAI._g53_program_json(typed)
        @assert base_s === FusionConceptAI._g53_set_json(set)
        @assert public_s === canonical_json(set)
        @assert public_sh === canonical_hash(set).value
        __PUBLIC_ASSERT__
        @assert base_th === FusionConceptAI._g25_hash_bytes(FusionConceptAI._g53_program_json(typed)).value
        @assert base_sh === FusionConceptAI._g25_hash_bytes(FusionConceptAI._g53_set_json(set)).value
        println("G53_PROBE_OK")
        exit(0)
        """
        public_assert = check_public ?
            "@assert public_t === canonical_json(typed); @assert public_th === canonical_hash(typed).value; @assert public_p === canonical_json(parameter); @assert public_ph === canonical_hash(parameter).value; @assert public_b === canonical_json(binding); @assert public_bh === canonical_hash(binding).value; @assert public_r === canonical_json(root); @assert public_rh === canonical_hash(root).value; @assert public_phase === canonical_json(phase); @assert public_phaseh === canonical_hash(phase).value" :
            "nothing"
        script = replace(script, "__DEFINITION__" => definition,
            "__TRIGGER__" => trigger, "__PUBLIC_ASSERT__" => public_assert)
        command = `$(Base.julia_cmd()) --startup-file=no --project=$(Base.active_project()) -e $script`
        output = read(pipeline(ignorestatus(command), stderr=stdout), String)
        occursin("G53_PROBE_OK", output) || println(stderr, "G53 probe failed: ", definition, "\\n", output)
        @test occursin("G53_PROBE_OK", output)
    end
    probes = (
        ("@eval Base.print(::IOBuffer,::String)=(HIT[]=true;nothing)", "Base.print(IOBuffer(),\"x\")"),
        ("@eval Base.:*(::String,::String)=(HIT[]=true;\"x\"); @eval Base.:*(::String,::String,::String...)=(HIT[]=true;\"x\")", "Base.:*(\"a\",\"b\"); Base.:*(\"a\",\"b\",\"c\")"),
        ("@eval Base.string(::Int64)=(HIT[]=true;\"x\")", "Base.string(Int64(1))"),
        ("@eval Base.repr(::Float64)=(HIT[]=true;\"x\")", "Base.repr(1.0)"),
        ("@eval Base.join(::Tuple,::AbstractString)=(HIT[]=true;\"x\")", "Base.join((1,2),\",\")"),
        ("@eval Base.getindex(::String,::Int)=(HIT[]=true;error(\"x\"))", "try \"x\"[1] catch; end"),
        ("@eval Base.iterate(::Tuple{FieldProgramParameterBindingV1},::Int)=(HIT[]=true;nothing)", "Base.iterate((typed.parameter_bindings[1],),1)"),
        ("@eval Base.getindex(::NTuple{3,Int64},::Int)=(HIT[]=true;0)", "getindex((Int64(1),Int64(2),Int64(3)),1)"),
        ("@eval Base.getindex(::Vector{Tuple{Int64,Int64}},::Int)=(HIT[]=true;(Int64(0),Int64(0)))", "getindex(Tuple{Int64,Int64}[(Int64(1),Int64(2))],1)"),
        ("@eval Base.iterate(::Vector{Tuple{Int64,Int64}},::Int)=(HIT[]=true;nothing)", "Base.iterate(Tuple{Int64,Int64}[(Int64(1),Int64(2))],1)"),
        ("@eval Base.codeunits(::String)=(HIT[]=true;UInt8[])", "Base.codeunits(\"x\")"),
        ("@eval Base.ncodeunits(::String)=(HIT[]=true;0)", "Base.ncodeunits(\"x\")"),
        ("@eval Base.bytes2hex(::Vector{UInt8})=(HIT[]=true;\"x\")", "Base.bytes2hex(UInt8[1])"),
        ("@eval SHA.sha256(::Base.CodeUnits{UInt8,String})=(HIT[]=true;UInt8[])", "SHA.sha256(codeunits(\"x\"))"),
        ("@eval Base.hash(::String,::UInt)=(HIT[]=true;UInt(0))", "Base.hash(\"x\",UInt(0))"),
        ("@eval FusionConceptAI.canonical_json(::Any)=(HIT[]=true;\"x\")", "FusionConceptAI.canonical_json(1)"),
        ("@eval FusionConceptAI.canonical_hash(::Any)=(HIT[]=true;Digest256(repeat(\"a\",64)))", "FusionConceptAI.canonical_hash(1)"),
        ("@eval FusionConceptAI.semantic_view(::Any)=(HIT[]=true;(\"x\",))", "FusionConceptAI.semantic_view(1)"),
        ("@eval FusionConceptAI.canonical_json(::TypedFieldProgramGeneV1)=(HIT[]=true;\"x\"); @eval FusionConceptAI.canonical_hash(::TypedFieldProgramGeneV1)=(HIT[]=true;Digest256(repeat(\"a\",64)))", "FusionConceptAI.canonical_json(typed); FusionConceptAI.canonical_hash(typed)"),
        ("@eval FusionConceptAI.canonical_json(::FieldParameterGeneV1)=(HIT[]=true;\"x\"); @eval FusionConceptAI.canonical_hash(::FieldParameterGeneV1)=(HIT[]=true;Digest256(repeat(\"a\",64)))", "FusionConceptAI.canonical_json(parameter); FusionConceptAI.canonical_hash(parameter)"),
        ("@eval FusionConceptAI.canonical_json(::SpatialProgramRootRefV1)=(HIT[]=true;\"x\"); @eval FusionConceptAI.canonical_hash(::SpatialProgramRootRefV1)=(HIT[]=true;Digest256(repeat(\"a\",64)))", "FusionConceptAI.canonical_json(root); FusionConceptAI.canonical_hash(root)"),
        ("@eval FusionConceptAI.canonical_json(::PhaseFieldDeclarationV1)=(HIT[]=true;\"x\"); @eval FusionConceptAI.canonical_hash(::PhaseFieldDeclarationV1)=(HIT[]=true;Digest256(repeat(\"a\",64)))", "FusionConceptAI.canonical_json(phase); FusionConceptAI.canonical_hash(phase)"),
        ("@eval FusionConceptAI.canonical_json(::TypedASTProgramV1)=(HIT[]=true;\"x\")", "FusionConceptAI.canonical_json(ast)"),
    )
    for (definition, trigger) in probes
        exact_child = occursin("::TypedFieldProgramGeneV1", definition) ||
            occursin("::FieldParameterGeneV1", definition) ||
            occursin("::SpatialProgramRootRefV1", definition) ||
            occursin("::PhaseFieldDeclarationV1", definition) ||
            occursin("::TypedASTProgramV1", definition)
        _g53_probe(definition, trigger; check_public=!exact_child)
    end
end

@testset "G2 5.3 vocabulary scan" begin
    files = (joinpath(@__DIR__, "..", "src", "Genomes", "FieldGeometryFieldPrograms.jl"),
             joinpath(@__DIR__, "..", "src", "Genomes", "FieldGeometryPhaseFields.jl"),
             joinpath(@__DIR__, "..", "src", "Canonical", "FieldGeometryFieldProgramCanonical.jl"),
             joinpath(@__DIR__, "..", "src", "Canonical", "FieldGeometryPhaseFieldCanonical.jl"))
    banned = ("family", "device", "solver", "evidence", "status", "unsupported",
              "phenotype", "material", "partition", "feasibility")
    for path in files
        source = lowercase(read(path, String))
        for token in banned
            @test !occursin(token, source)
        end
    end
end

@testset "pre-5.3 FieldGeometryGenomeV4 golden (962a508)" begin
    T = PhysicalType(:scalar_field, 0, 3, TemporalTypeV1(static_time), UnitSignature())
    nodes = (TypedNode("n-a", :state, T, "alpha"), TypedNode("n-b", :state, T, "beta"))
    ast = ast_leaf(:state, T)
    edge = TypedHyperedge("edge-x", (1,), (2,), ast, :governing)
    graph = TypedOperatorHypergraphV1(nodes, (edge,))
    contract = GenomeContractRef("urn:test:2", "v4.0.0", repeat("2", 64),
        repeat("3", 64), "profile-v4")
    old = FieldGeometryGenomeV4(2, contract, graph)
    old_rows = split(chomp(read(joinpath(@__DIR__, "fixtures",
        "g2_old_field_genome_baseline_962a508.jsonl"), String)), '\n')
    old_json = split(old_rows[1], '|'; limit=2)[2]
    old_hash = split(old_rows[2], '|'; limit=2)[2]
    @test canonical_json(old) == old_json
    @test field_geometry_hash(old).value == old_hash
    @test JSON3.read(old_json) isa JSON3.Object
end
