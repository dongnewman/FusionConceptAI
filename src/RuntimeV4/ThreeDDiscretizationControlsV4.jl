"""Candidate/context-bound typed 3-D discretization controls.

This isolated slice compiles immutable mesh, discrete-space, solver-policy, and
refinement declarations.  When an accepted oriented-interface declaration is
present, its exact G2-derived space and binding identities are mandatory.  No
provider or solver is invoked and no evidence, pass, P5, or terminal authority
is produced.
"""

using FusionConceptAI
import FusionConceptAI: canonical_hash, semantic_view

const _TDDC_REVISION = "runtime-v4-three-d-discretization-controls-v1"
const _TDDC_SCHEMA = "fusionconceptai:runtime-v4-three-d-discretization-controls"
const _TDDC_TOKEN = Val(:three_d_discretization_controls_private)
const _TDDC_REQUIRED_GAPS = (
    "required_typed_three_d_discretization_controls",
    "required_three_d_discretization_controls_subject_binding")
const _TDDC_ORIENTED_GAP =
    "required_typed_three_d_oriented_interface_input_for_discretization"

function _tddc_text(value, field::String)
    typeof(value) === String || throw(ArgumentError("$field must be an immutable String"))
    text = strip(value)
    !isempty(text) && isvalid(text) || throw(ArgumentError("$field cannot be empty"))
    lowered = lowercase(text)
    (lowered in ("*", "any", "all", "wildcard") || occursin('*', text)) &&
        throw(ArgumentError("$field cannot contain a wildcard"))
    String(text)
end

function _tddc_int(value, field::String; minimum::Int, maximum::Int)
    value isa Bool && throw(ArgumentError("$field must be an integer, not Bool"))
    typeof(value) <: Integer || throw(ArgumentError("$field must be an integer"))
    typemin(Int) <= value <= typemax(Int) || throw(ArgumentError("$field is out of range"))
    result = Int(value)
    minimum <= result <= maximum ||
        throw(ArgumentError("$field is outside its admitted range"))
    result
end

function _tddc_finite_positive(value, field::String; maximum::Float64)
    value isa Bool && throw(ArgumentError("$field must be numeric, not Bool"))
    value isa Real || throw(ArgumentError("$field must be numeric"))
    result = Float64(value)
    isfinite(result) && 0.0 < result <= maximum ||
        throw(ArgumentError("$field must be finite, positive, and bounded"))
    result
end

@enum ThreeDNonlinearMethodV4 trust_region_newton line_search_newton
@enum ThreeDJacobianPolicyV4 assembled_jacobian matrix_free_jacobian
@enum ThreeDLinearMethodV4 sparse_direct gmres minres
@enum ThreeDPreconditionerV4 no_preconditioner ilu_preconditioner amg_preconditioner
@enum ThreeDRefinementStrategyV4 uniform_refinement residual_adaptive_refinement

struct ThreeDMeshResolutionControlV4
    mesh_id::String
    mesh_family::QualifiedRefV1
    characteristic_length_m::Float64
    radial_resolution::Int
    poloidal_resolution::Int
    toroidal_resolution::Int
    geometry_order::Int
    function ThreeDMeshResolutionControlV4(mesh_id,
            mesh_family::QualifiedRefV1, characteristic_length_m,
            radial_resolution, poloidal_resolution, toroidal_resolution,
            geometry_order)
        new(_tddc_text(mesh_id, "mesh_id"), mesh_family,
            _tddc_finite_positive(characteristic_length_m,
                "characteristic_length_m"; maximum=1.0e6),
            _tddc_int(radial_resolution, "radial_resolution";
                minimum=2, maximum=4096),
            _tddc_int(poloidal_resolution, "poloidal_resolution";
                minimum=2, maximum=4096),
            _tddc_int(toroidal_resolution, "toroidal_resolution";
                minimum=1, maximum=4096),
            _tddc_int(geometry_order, "geometry_order";
                minimum=1, maximum=12))
    end
end
semantic_view(x::ThreeDMeshResolutionControlV4) = (
    mesh_id=x.mesh_id, mesh_family=x.mesh_family,
    characteristic_length_m=x.characteristic_length_m,
    radial_resolution=x.radial_resolution,
    poloidal_resolution=x.poloidal_resolution,
    toroidal_resolution=x.toroidal_resolution,
    geometry_order=x.geometry_order)

struct ThreeDDiscreteSpaceControlV4
    space_id::String
    polynomial_order::Int
    quadrature_order::Int
    function ThreeDDiscreteSpaceControlV4(space_id, polynomial_order,
            quadrature_order)
        new(_tddc_text(space_id, "space_id"),
            _tddc_int(polynomial_order, "polynomial_order";
                minimum=1, maximum=8),
            _tddc_int(quadrature_order, "quadrature_order";
                minimum=1, maximum=32))
    end
end
semantic_view(x::ThreeDDiscreteSpaceControlV4) = (
    space_id=x.space_id, polynomial_order=x.polynomial_order,
    quadrature_order=x.quadrature_order)

struct ThreeDNonlinearSolverPolicyV4
    method::ThreeDNonlinearMethodV4
    jacobian_policy::ThreeDJacobianPolicyV4
    absolute_tolerance::Float64
    relative_tolerance::Float64
    step_tolerance::Float64
    max_iterations::Int
    function ThreeDNonlinearSolverPolicyV4(method::ThreeDNonlinearMethodV4,
            jacobian_policy::ThreeDJacobianPolicyV4, absolute_tolerance,
            relative_tolerance, step_tolerance, max_iterations)
        new(method, jacobian_policy,
            _tddc_finite_positive(absolute_tolerance,
                "nonlinear absolute_tolerance"; maximum=1.0e-2),
            _tddc_finite_positive(relative_tolerance,
                "nonlinear relative_tolerance"; maximum=1.0e-2),
            _tddc_finite_positive(step_tolerance,
                "nonlinear step_tolerance"; maximum=1.0e-2),
            _tddc_int(max_iterations, "nonlinear max_iterations";
                minimum=1, maximum=10000))
    end
end
semantic_view(x::ThreeDNonlinearSolverPolicyV4) = (
    method=x.method, jacobian_policy=x.jacobian_policy,
    absolute_tolerance=x.absolute_tolerance,
    relative_tolerance=x.relative_tolerance,
    step_tolerance=x.step_tolerance, max_iterations=x.max_iterations)

struct ThreeDLinearSolverPolicyV4
    method::ThreeDLinearMethodV4
    preconditioner::ThreeDPreconditionerV4
    relative_tolerance::Float64
    max_iterations::Int
    restart_length::Int
    function ThreeDLinearSolverPolicyV4(method::ThreeDLinearMethodV4,
            preconditioner::ThreeDPreconditionerV4, relative_tolerance,
            max_iterations, restart_length)
        if method === sparse_direct
            preconditioner === no_preconditioner ||
                throw(ArgumentError("sparse_direct cannot declare an iterative preconditioner"))
            restart_length == 1 ||
                throw(ArgumentError("sparse_direct requires restart_length=1"))
        elseif method === minres
            preconditioner !== ilu_preconditioner ||
                throw(ArgumentError("MINRES does not admit the nonsymmetric ILU policy"))
        end
        new(method, preconditioner,
            _tddc_finite_positive(relative_tolerance,
                "linear relative_tolerance"; maximum=1.0e-2),
            _tddc_int(max_iterations, "linear max_iterations";
                minimum=1, maximum=100000),
            _tddc_int(restart_length, "linear restart_length";
                minimum=1, maximum=10000))
    end
end
semantic_view(x::ThreeDLinearSolverPolicyV4) = (
    method=x.method, preconditioner=x.preconditioner,
    relative_tolerance=x.relative_tolerance,
    max_iterations=x.max_iterations, restart_length=x.restart_length)

struct ThreeDRefinementPolicyV4
    strategy::ThreeDRefinementStrategyV4
    indicator_tolerance::Float64
    max_levels::Int
    refinement_ratio::Int
    function ThreeDRefinementPolicyV4(strategy::ThreeDRefinementStrategyV4,
            indicator_tolerance, max_levels, refinement_ratio)
        new(strategy, _tddc_finite_positive(indicator_tolerance,
                "refinement indicator_tolerance"; maximum=1.0),
            _tddc_int(max_levels, "refinement max_levels";
                minimum=0, maximum=12),
            _tddc_int(refinement_ratio, "refinement_ratio";
                minimum=2, maximum=4))
    end
end
semantic_view(x::ThreeDRefinementPolicyV4) = (
    strategy=x.strategy, indicator_tolerance=x.indicator_tolerance,
    max_levels=x.max_levels, refinement_ratio=x.refinement_ratio)

function _tddc_declaration_body(declaration_id, mesh, spaces, nonlinear,
        linear, refinement)
    (revision=_TDDC_REVISION, declaration_id=declaration_id, mesh=mesh,
     discrete_spaces=spaces, nonlinear_policy=nonlinear,
     linear_policy=linear, refinement_policy=refinement,
     model_class=:manufactured_input_fixture, claim_ceiling=screen_only,
     provider_selected=false, solver_executed=false, emits_evidence=false,
     grants_pass=false, p5_ready=false, terminal_authority=false,
     credible_physical_device_count=0)
end

struct ThreeDDiscretizationControlDeclarationV4
    declaration_id::String
    mesh::ThreeDMeshResolutionControlV4
    discrete_spaces::Tuple{Vararg{ThreeDDiscreteSpaceControlV4}}
    nonlinear_policy::ThreeDNonlinearSolverPolicyV4
    linear_policy::ThreeDLinearSolverPolicyV4
    refinement_policy::ThreeDRefinementPolicyV4
    model_class::Symbol
    claim_ceiling::ClaimCeiling
    provider_selected::Bool
    solver_executed::Bool
    emits_evidence::Bool
    grants_pass::Bool
    p5_ready::Bool
    terminal_authority::Bool
    credible_physical_device_count::Int
    declaration_hash::Digest256
    function ThreeDDiscretizationControlDeclarationV4(declaration_id,
            mesh::ThreeDMeshResolutionControlV4, spaces,
            nonlinear::ThreeDNonlinearSolverPolicyV4,
            linear::ThreeDLinearSolverPolicyV4,
            refinement::ThreeDRefinementPolicyV4)
        spaces isa Tuple && !(spaces isa NamedTuple) && !isempty(spaces) &&
            all(x -> typeof(x) === ThreeDDiscreteSpaceControlV4, spaces) ||
            throw(ArgumentError("discrete-space controls must be a nonempty immutable typed tuple"))
        ordered = Tuple(sort(collect(spaces), by=x -> x.space_id))
        length(unique(x.space_id for x in ordered)) == length(ordered) ||
            throw(ArgumentError("discrete-space control IDs must be unique"))
        id = _tddc_text(declaration_id, "declaration_id")
        body = _tddc_declaration_body(id, mesh, ordered, nonlinear, linear,
            refinement)
        new(id, mesh, ordered, nonlinear, linear, refinement,
            :manufactured_input_fixture, screen_only, false, false, false,
            false, false, false, 0, canonical_hash(body))
    end
    function ThreeDDiscretizationControlDeclarationV4(
            token::Val{:three_d_discretization_controls_private}, fields...)
        token === _TDDC_TOKEN || throw(ArgumentError("private discretization declaration constructor"))
        new(fields...)
    end
end

semantic_view(x::ThreeDDiscretizationControlDeclarationV4) = merge(
    _tddc_declaration_body(x.declaration_id, x.mesh, x.discrete_spaces,
        x.nonlinear_policy, x.linear_policy, x.refinement_policy),
    (declaration_hash=x.declaration_hash,))

function canonical_hash(x::ThreeDDiscretizationControlDeclarationV4)
    expected = canonical_hash(_tddc_declaration_body(x.declaration_id,
        x.mesh, x.discrete_spaces, x.nonlinear_policy, x.linear_policy,
        x.refinement_policy))
    expected == x.declaration_hash ||
        throw(ArgumentError("3-D discretization declaration hash mismatch"))
    x.model_class === :manufactured_input_fixture &&
        x.claim_ceiling == screen_only && !x.provider_selected &&
        !x.solver_executed && !x.emits_evidence && !x.grants_pass &&
        !x.p5_ready && !x.terminal_authority &&
        x.credible_physical_device_count == 0 ||
        throw(ArgumentError("3-D discretization declaration authority ceiling was exceeded"))
    expected
end

function _tddc_oriented_declaration(candidate::CandidateStatePackageV4)
    declarations = Tuple(x for x in candidate.field_geometry_genome_ref.fields
        if typeof(x) === ThreeDOrientedInterfaceDeclarationSetV4)
    length(declarations) == 1 ||
        throw(ArgumentError("discretization controls require one exact oriented-interface declaration in G2"))
    only(declarations)
end

function _tddc_oriented_spaces(regions, interfaces)
    values = ThreeDDiscreteSpaceV4[]
    append!(values, (r.volume_space for r in regions))
    for interface_ref in interfaces
        push!(values, interface_ref.minus_trace_space,
            interface_ref.plus_trace_space, interface_ref.multiplier_space)
    end
    ordered = Tuple(sort(values, by=x -> x.space_id))
    length(unique(x.space_id for x in ordered)) == length(ordered) ||
        throw(ArgumentError("oriented input contains duplicate discrete-space IDs"))
    ordered
end

function _tddc_validate_declaration(candidate::CandidateStatePackageV4,
        graph::ForwardGraphBindingV4,
        declaration::ThreeDDiscretizationControlDeclarationV4)
    canonical_hash(declaration)
    owned = Tuple(x for x in candidate.field_geometry_genome_ref.fields
        if typeof(x) === ThreeDDiscretizationControlDeclarationV4 &&
           canonical_hash(x) == declaration.declaration_hash)
    length(owned) == 1 ||
        throw(ArgumentError("discretization declaration is absent from or ambiguous in current G2 fields"))
    oriented = _tddc_oriented_declaration(candidate)
    regions, interfaces = _tdoi_compile_declaration(candidate, graph, oriented)
    spaces = _tddc_oriented_spaces(regions, interfaces)
    expected_controls = Tuple(ThreeDDiscreteSpaceControlV4(x.space_id,
        x.polynomial_order, x.quadrature_order) for x in spaces)
    declaration.discrete_spaces == expected_controls ||
        throw(ArgumentError("discretization controls do not exactly match current oriented discrete spaces"))
    (oriented=oriented, regions=regions, interfaces=interfaces,
     spaces=spaces, space_identity_hashes=Tuple(canonical_hash(x) for x in spaces))
end

function _tddc_binding_body(declaration_hash, candidate_hash, genome_hash,
        graph_hash, graph_binding_hash, mesh_id, space_identity_hashes,
        oriented_declaration_hash, oriented_binding_hash,
        region_ref_hashes, interface_ref_hashes, mission_hash, bounds_hash,
        scenario_hash)
    (revision=_TDDC_REVISION,
     binding_kind=:three_d_discretization_controls_subject_binding,
     declaration_hash=declaration_hash, candidate_hash=candidate_hash,
     field_geometry_genome_hash=genome_hash,
     field_geometry_graph_hash=graph_hash,
     field_geometry_graph_binding_hash=graph_binding_hash,
     mesh_id=mesh_id, discrete_space_identity_hashes=space_identity_hashes,
     oriented_declaration_hash=oriented_declaration_hash,
     oriented_binding_hash=oriented_binding_hash,
     oriented_region_ref_hashes=region_ref_hashes,
     oriented_interface_ref_hashes=interface_ref_hashes,
     mission_hash=mission_hash, bounds_hash=bounds_hash,
     scenario_hash=scenario_hash)
end

struct ThreeDDiscretizationControlBindingV4
    declaration_hash::Digest256
    candidate_hash::Digest256
    field_geometry_genome_hash::Digest256
    field_geometry_graph_hash::Digest256
    field_geometry_graph_binding_hash::Digest256
    mesh_id::String
    discrete_space_identity_hashes::Tuple{Vararg{Digest256}}
    oriented_declaration_hash::Digest256
    oriented_binding_hash::Digest256
    oriented_region_ref_hashes::Tuple{Vararg{Digest256}}
    oriented_interface_ref_hashes::Tuple{Vararg{Digest256}}
    mission_hash::Digest256
    bounds_hash::Digest256
    scenario_hash::Digest256
    binding_hash::Digest256
    function ThreeDDiscretizationControlBindingV4(
            token::Val{:three_d_discretization_controls_private}, fields...)
        token === _TDDC_TOKEN || throw(ArgumentError("private discretization binding constructor"))
        new(fields...)
    end
end

semantic_view(x::ThreeDDiscretizationControlBindingV4) = merge(
    _tddc_binding_body(x.declaration_hash, x.candidate_hash,
        x.field_geometry_genome_hash, x.field_geometry_graph_hash,
        x.field_geometry_graph_binding_hash, x.mesh_id,
        x.discrete_space_identity_hashes, x.oriented_declaration_hash,
        x.oriented_binding_hash, x.oriented_region_ref_hashes,
        x.oriented_interface_ref_hashes, x.mission_hash, x.bounds_hash,
        x.scenario_hash), (binding_hash=x.binding_hash,))

function canonical_hash(x::ThreeDDiscretizationControlBindingV4)
    expected = canonical_hash(_tddc_binding_body(x.declaration_hash,
        x.candidate_hash, x.field_geometry_genome_hash,
        x.field_geometry_graph_hash, x.field_geometry_graph_binding_hash,
        x.mesh_id, x.discrete_space_identity_hashes,
        x.oriented_declaration_hash, x.oriented_binding_hash,
        x.oriented_region_ref_hashes, x.oriented_interface_ref_hashes,
        x.mission_hash, x.bounds_hash, x.scenario_hash))
    expected == x.binding_hash ||
        throw(ArgumentError("3-D discretization binding hash mismatch"))
    expected
end

function make_three_d_discretization_control_binding(
        compiled::CompiledCandidatePrefixV4,
        registry::GenomeContractRegistryV4, mission_payload, bounds_payload,
        comparison_scope, scenario_scope, scenario,
        declaration::ThreeDDiscretizationControlDeclarationV4,
        oriented_binding::ThreeDOrientedInterfaceBindingV4)
    comparison = _runtime_axis_tuple(comparison_scope, "comparison_scope")
    scenarios = _runtime_axis_tuple(scenario_scope, "scenario_scope")
    _runtime_validate_compiled_prefix(compiled, compiled.candidate, registry,
        mission_payload, bounds_payload, comparison, scenarios)
    is_canonical_value(scenario) ||
        throw(ArgumentError("discretization binding scenario is not canonicalizable"))
    _forward_scenario_name(scenario) in scenarios ||
        throw(ArgumentError("discretization binding scenario is outside frozen scope"))
    graph = _make_forward_graph_binding(:field_geometry,
        compiled.field_geometry_graph)
    values = _tddc_validate_declaration(compiled.candidate, graph, declaration)
    rebuilt_oriented = make_three_d_oriented_interface_binding(compiled,
        registry, mission_payload, bounds_payload, comparison, scenarios,
        scenario, values.oriented)
    canonical_hash(oriented_binding) == canonical_hash(rebuilt_oriented) &&
        semantic_view(oriented_binding) == semantic_view(rebuilt_oriented) ||
        throw(ArgumentError("oriented-interface binding is foreign to discretization context"))
    body = _tddc_binding_body(canonical_hash(declaration),
        _forward_candidate_identity(compiled.candidate),
        field_geometry_hash(compiled.candidate.field_geometry_genome_ref),
        graph.canonical_graph_hash, canonical_hash(graph),
        declaration.mesh.mesh_id, values.space_identity_hashes,
        canonical_hash(values.oriented), canonical_hash(oriented_binding),
        Tuple(x.ref_hash for x in values.regions),
        Tuple(x.ref_hash for x in values.interfaces),
        _runtime_decl_hash(mission_payload), _runtime_decl_hash(bounds_payload),
        canonical_hash(scenario))
    ThreeDDiscretizationControlBindingV4(_TDDC_TOKEN,
        body.declaration_hash, body.candidate_hash,
        body.field_geometry_genome_hash, body.field_geometry_graph_hash,
        body.field_geometry_graph_binding_hash, body.mesh_id,
        body.discrete_space_identity_hashes, body.oriented_declaration_hash,
        body.oriented_binding_hash, body.oriented_region_ref_hashes,
        body.oriented_interface_ref_hashes, body.mission_hash,
        body.bounds_hash, body.scenario_hash, canonical_hash(body))
end

function _tddc_context_binding(context::ForwardChainContextV4,
        declaration::ThreeDDiscretizationControlDeclarationV4)
    bindings = Tuple(x for x in context.subject.bindings
        if typeof(x) === ThreeDDiscretizationControlBindingV4)
    length(bindings) == 1 ||
        throw(ArgumentError("physical subject must contain exactly one discretization binding"))
    oriented_bindings = Tuple(x for x in context.subject.bindings
        if typeof(x) === ThreeDOrientedInterfaceBindingV4)
    length(oriented_bindings) == 1 ||
        throw(ArgumentError("physical subject must contain exactly one oriented-interface binding"))
    binding = only(bindings)
    rebuilt = make_three_d_discretization_control_binding(context.compiled,
        context.registry, context.mission_payload, context.bounds_payload,
        context.comparison_scope, context.scenario_scope, context.scenario,
        declaration, only(oriented_bindings))
    canonical_hash(binding) == canonical_hash(rebuilt) &&
        semantic_view(binding) == semantic_view(rebuilt) ||
        throw(ArgumentError("discretization binding is foreign to current context"))
    binding
end

function _tddc_input_body(context, declaration, binding)
    (revision=_TDDC_REVISION, schema=_TDDC_SCHEMA,
     context_hash=context.context_hash, candidate_hash=context.candidate_hash,
     compiled_prefix_hash=context.compiled.prefix_hash,
     physical_subject_hash=context.subject.physical_subject_hash,
     declaration_hash=declaration.declaration_hash,
     binding_hash=binding.binding_hash,
     field_geometry_genome_hash=binding.field_geometry_genome_hash,
     field_geometry_graph_hash=binding.field_geometry_graph_hash,
     field_geometry_graph_binding_hash=binding.field_geometry_graph_binding_hash,
     mesh=declaration.mesh, discrete_spaces=declaration.discrete_spaces,
     nonlinear_policy=declaration.nonlinear_policy,
     linear_policy=declaration.linear_policy,
     refinement_policy=declaration.refinement_policy,
     oriented_declaration_hash=binding.oriented_declaration_hash,
     oriented_binding_hash=binding.oriented_binding_hash,
     oriented_region_ref_hashes=binding.oriented_region_ref_hashes,
     oriented_interface_ref_hashes=binding.oriented_interface_ref_hashes,
     mission_hash=binding.mission_hash, bounds_hash=binding.bounds_hash,
     scenario_hash=binding.scenario_hash,
     model_class=:manufactured_input_fixture, claim_ceiling=screen_only,
     provider_selected=false, provider_executed=false,
     solver_executed=false, emits_evidence=false, grants_pass=false,
     p5_ready=false, terminal_authority=false,
     credible_physical_device_count=0)
end

struct ThreeDDiscretizationControlInputV4
    context_hash::Digest256
    candidate_hash::Digest256
    compiled_prefix_hash::Digest256
    physical_subject_hash::Digest256
    declaration_hash::Digest256
    binding_hash::Digest256
    field_geometry_genome_hash::Digest256
    field_geometry_graph_hash::Digest256
    field_geometry_graph_binding_hash::Digest256
    mesh::ThreeDMeshResolutionControlV4
    discrete_spaces::Tuple{Vararg{ThreeDDiscreteSpaceControlV4}}
    nonlinear_policy::ThreeDNonlinearSolverPolicyV4
    linear_policy::ThreeDLinearSolverPolicyV4
    refinement_policy::ThreeDRefinementPolicyV4
    oriented_declaration_hash::Digest256
    oriented_binding_hash::Digest256
    oriented_region_ref_hashes::Tuple{Vararg{Digest256}}
    oriented_interface_ref_hashes::Tuple{Vararg{Digest256}}
    mission_hash::Digest256
    bounds_hash::Digest256
    scenario_hash::Digest256
    model_class::Symbol
    claim_ceiling::ClaimCeiling
    provider_selected::Bool
    provider_executed::Bool
    solver_executed::Bool
    emits_evidence::Bool
    grants_pass::Bool
    p5_ready::Bool
    terminal_authority::Bool
    credible_physical_device_count::Int
    input_hash::Digest256
    function ThreeDDiscretizationControlInputV4(
            token::Val{:three_d_discretization_controls_private}, fields...)
        token === _TDDC_TOKEN || throw(ArgumentError("private discretization input constructor"))
        new(fields...)
    end
end

function _tddc_make_input(context, declaration, binding)
    body = _tddc_input_body(context, declaration, binding)
    ThreeDDiscretizationControlInputV4(_TDDC_TOKEN,
        body.context_hash, body.candidate_hash, body.compiled_prefix_hash,
        body.physical_subject_hash, body.declaration_hash, body.binding_hash,
        body.field_geometry_genome_hash, body.field_geometry_graph_hash,
        body.field_geometry_graph_binding_hash, body.mesh,
        body.discrete_spaces, body.nonlinear_policy, body.linear_policy,
        body.refinement_policy, body.oriented_declaration_hash,
        body.oriented_binding_hash, body.oriented_region_ref_hashes,
        body.oriented_interface_ref_hashes, body.mission_hash,
        body.bounds_hash, body.scenario_hash, body.model_class,
        body.claim_ceiling, body.provider_selected, body.provider_executed,
        body.solver_executed, body.emits_evidence, body.grants_pass,
        body.p5_ready, body.terminal_authority,
        body.credible_physical_device_count, canonical_hash(body))
end

semantic_view(x::ThreeDDiscretizationControlInputV4) = merge(
    (revision=_TDDC_REVISION, schema=_TDDC_SCHEMA,
     context_hash=x.context_hash, candidate_hash=x.candidate_hash,
     compiled_prefix_hash=x.compiled_prefix_hash,
     physical_subject_hash=x.physical_subject_hash,
     declaration_hash=x.declaration_hash, binding_hash=x.binding_hash,
     field_geometry_genome_hash=x.field_geometry_genome_hash,
     field_geometry_graph_hash=x.field_geometry_graph_hash,
     field_geometry_graph_binding_hash=x.field_geometry_graph_binding_hash,
     mesh=x.mesh, discrete_spaces=x.discrete_spaces,
     nonlinear_policy=x.nonlinear_policy, linear_policy=x.linear_policy,
     refinement_policy=x.refinement_policy,
     oriented_declaration_hash=x.oriented_declaration_hash,
     oriented_binding_hash=x.oriented_binding_hash,
     oriented_region_ref_hashes=x.oriented_region_ref_hashes,
     oriented_interface_ref_hashes=x.oriented_interface_ref_hashes,
     mission_hash=x.mission_hash, bounds_hash=x.bounds_hash,
     scenario_hash=x.scenario_hash, model_class=x.model_class,
     claim_ceiling=x.claim_ceiling, provider_selected=x.provider_selected,
     provider_executed=x.provider_executed,
     solver_executed=x.solver_executed, emits_evidence=x.emits_evidence,
     grants_pass=x.grants_pass, p5_ready=x.p5_ready,
     terminal_authority=x.terminal_authority,
     credible_physical_device_count=x.credible_physical_device_count),
    (input_hash=x.input_hash,))

function canonical_hash(x::ThreeDDiscretizationControlInputV4)
    view = semantic_view(x)
    body = NamedTuple{keys(view)[1:end-1]}(values(view)[1:end-1])
    expected = canonical_hash(body)
    expected == x.input_hash ||
        throw(ArgumentError("3-D discretization input hash mismatch"))
    x.model_class === :manufactured_input_fixture &&
        x.claim_ceiling == screen_only && !x.provider_selected &&
        !x.provider_executed && !x.solver_executed && !x.emits_evidence &&
        !x.grants_pass && !x.p5_ready && !x.terminal_authority &&
        x.credible_physical_device_count == 0 ||
        throw(ArgumentError("3-D discretization input authority ceiling was exceeded"))
    expected
end

function validate_three_d_discretization_control_input(
        context::ForwardChainContextV4,
        input::ThreeDDiscretizationControlInputV4)
    validate_forward_chain_context(context)
    declarations = Tuple(x for x in context.candidate.field_geometry_genome_ref.fields
        if typeof(x) === ThreeDDiscretizationControlDeclarationV4)
    length(declarations) == 1 ||
        throw(ArgumentError("current context lacks one discretization declaration"))
    declaration = only(declarations)
    binding = _tddc_context_binding(context, declaration)
    expected = _tddc_make_input(context, declaration, binding)
    canonical_hash(input) == canonical_hash(expected) &&
        semantic_view(input) == semantic_view(expected) ||
        throw(ArgumentError("discretization input differs from current context"))
    input.input_hash
end

function _tddc_resolution_body(context_hash, status, input, gaps)
    (revision=_TDDC_REVISION, kind=:three_d_discretization_control_resolution,
     context_hash=context_hash, status=status,
     input_hash=input === nothing ? nothing : canonical_hash(input),
     recoverable_gaps=gaps, claim_ceiling=screen_only,
     provider_selected=false, provider_executed=false,
     solver_executed=false, emits_evidence=false, grants_pass=false,
     p5_ready=false, terminal_authority=false,
     credible_physical_device_count=0)
end

struct ThreeDDiscretizationControlResolutionV4
    context_hash::Digest256
    status::Symbol
    input::Union{Nothing,ThreeDDiscretizationControlInputV4}
    recoverable_gaps::Tuple{Vararg{String}}
    claim_ceiling::ClaimCeiling
    provider_selected::Bool
    provider_executed::Bool
    solver_executed::Bool
    emits_evidence::Bool
    grants_pass::Bool
    p5_ready::Bool
    terminal_authority::Bool
    credible_physical_device_count::Int
    resolution_hash::Digest256
    function ThreeDDiscretizationControlResolutionV4(
            token::Val{:three_d_discretization_controls_private}, fields...)
        token === _TDDC_TOKEN || throw(ArgumentError("private discretization resolution constructor"))
        new(fields...)
    end
end

semantic_view(x::ThreeDDiscretizationControlResolutionV4) = merge(
    _tddc_resolution_body(x.context_hash, x.status, x.input,
        x.recoverable_gaps), (resolution_hash=x.resolution_hash,))

function canonical_hash(x::ThreeDDiscretizationControlResolutionV4)
    x.status in (:input_complete, :recoverable_gap) ||
        throw(ArgumentError("invalid discretization resolution status"))
    (x.status === :input_complete) == (x.input !== nothing) ||
        throw(ArgumentError("discretization resolution payload mismatch"))
    x.status === :input_complete ? isempty(x.recoverable_gaps) :
        !isempty(x.recoverable_gaps) ||
        throw(ArgumentError("recoverable discretization result needs exact gaps"))
    expected = canonical_hash(_tddc_resolution_body(x.context_hash,
        x.status, x.input, x.recoverable_gaps))
    expected == x.resolution_hash ||
        throw(ArgumentError("discretization resolution hash mismatch"))
    x.claim_ceiling == screen_only && !x.provider_selected &&
        !x.provider_executed && !x.solver_executed && !x.emits_evidence &&
        !x.grants_pass && !x.p5_ready && !x.terminal_authority &&
        x.credible_physical_device_count == 0 ||
        throw(ArgumentError("discretization resolution authority ceiling was exceeded"))
    expected
end

function _tddc_resolution(context_hash, input, gaps)
    gap_tuple = Tuple(String(x) for x in gaps)
    status = input === nothing ? :recoverable_gap : :input_complete
    status === :input_complete && !isempty(gap_tuple) &&
        throw(ArgumentError("input_complete cannot retain gaps"))
    status === :recoverable_gap && isempty(gap_tuple) &&
        throw(ArgumentError("recoverable result requires a gap"))
    body = _tddc_resolution_body(context_hash, status, input, gap_tuple)
    ThreeDDiscretizationControlResolutionV4(_TDDC_TOKEN, context_hash,
        status, input, gap_tuple, screen_only, false, false, false, false,
        false, false, false, 0, canonical_hash(body))
end

function resolve_three_d_discretization_controls(context::ForwardChainContextV4)
    validate_forward_chain_context(context)
    declarations = Tuple(x for x in context.candidate.field_geometry_genome_ref.fields
        if typeof(x) === ThreeDDiscretizationControlDeclarationV4)
    bindings = Tuple(x for x in context.subject.bindings
        if typeof(x) === ThreeDDiscretizationControlBindingV4)
    gaps = String[]
    isempty(declarations) ? push!(gaps, _TDDC_REQUIRED_GAPS[1]) :
        length(declarations) == 1 ||
        push!(gaps, "ambiguous_typed_three_d_discretization_controls")
    isempty(bindings) ? push!(gaps, _TDDC_REQUIRED_GAPS[2]) :
        length(bindings) == 1 ||
        push!(gaps, "ambiguous_three_d_discretization_controls_subject_binding")
    if !isempty(declarations)
        oriented = Tuple(x for x in context.candidate.field_geometry_genome_ref.fields
            if typeof(x) === ThreeDOrientedInterfaceDeclarationSetV4)
        length(oriented) == 1 || push!(gaps, _TDDC_ORIENTED_GAP)
    end
    isempty(gaps) || return _tddc_resolution(context.context_hash, nothing,
        Tuple(unique(gaps)))
    declaration = only(declarations)
    binding = _tddc_context_binding(context, declaration)
    input = _tddc_make_input(context, declaration, binding)
    validate_three_d_discretization_control_input(context, input)
    _tddc_resolution(context.context_hash, input, ())
end

three_d_discretization_controls_manifest() = (
    schema=_TDDC_SCHEMA, revision=_TDDC_REVISION,
    purpose=:typed_three_d_discretization_controls_input_compiler,
    statuses=(:input_complete, :recoverable_gap),
    model_class=:manufactured_input_fixture, claim_ceiling=screen_only,
    provider_selected=false, provider_executed=false,
    solver_executed=false, emits_evidence=false, grants_pass=false,
    physical_validation=false, engineering_validation=false,
    p5_ready=false, terminal_authority=false,
    credible_physical_device_count=0)
