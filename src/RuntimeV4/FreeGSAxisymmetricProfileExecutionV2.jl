"""Generic tabulated-profile axisymmetric source and FreeGS v2 execution.

This isolated bridge binds one verified source-snapshot file to the current G2
Genome and forward context.  The controlled Python backend uses an explicit
empty machine and the snapshot's observed Dirichlet boundary.  It never routes
on a device name and never upgrades the same-source solve to validation.
"""

import FusionConceptAI: semantic_view, canonical_hash
using FusionConceptAI
using SHA

const _GAF_REVISION = "runtime-v4-freegs-axisymmetric-profile-execution-v2"
const _GAF_INPUT_SCHEMA = "fusionconceptai:runtime-v4-freegs-axisymmetric-profile-input-v2"
const _GAF_PINNED_PYTHON = raw"D:\006-Programing\LMC\outputs\fusion_concept_ai\.venv-freegs\Scripts\python.exe"
const _GAF_RUNNER = abspath(normpath(joinpath(@__DIR__, "..", "..", "scripts",
    "runtime_v4_freegs_axisymmetric_profile_runner_v2.py")))
const _GAF_UNKNOWN_HASH = digest256_text("runtime-v4-freegs-profile-v2-unknown")
const _GAF_CLAIM = :same_source_observed_dirichlet_solver_converged_residual_measured_only
const _GAF_COCOS_MAPPING = :identity_no_sign_or_2pi_transform
const _GAF_COCOS_SCOPE = :gs_bp_subset_only_q_theta_not_consumed
const _GAF_EXECUTABLE_SOURCE_SCOPE = :G2_profile_fixed_boundary

struct _GAFToken end
const _GAF_TOKEN = _GAFToken()

_gaf_sha256_bytes(bytes) = Digest256(bytes2hex(SHA.sha256(bytes)))
_gaf_sha256_text(text::String) = _gaf_sha256_bytes(Vector{UInt8}(codeunits(text)))
_gaf_sha256_file(path::String) = _gaf_sha256_bytes(read(path))

function _gaf_text(value, field::String)
    value isa AbstractString || throw(ArgumentError("$field must be a string"))
    result = String(strip(String(value)))
    !isempty(result) && isvalid(result) || throw(ArgumentError("$field cannot be empty"))
    lowercase(result) in ("*", "all", "any", "wildcard") &&
        throw(ArgumentError("$field cannot be wildcard"))
    result
end

function _gaf_finite(value, field::String; positive::Bool=false,
        nonnegative::Bool=false)
    value isa Bool && throw(ArgumentError("$field cannot be Bool"))
    value isa Real || throw(ArgumentError("$field must be numeric"))
    result = Float64(value)
    isfinite(result) || throw(ArgumentError("$field must be finite"))
    positive && result <= 0 && throw(ArgumentError("$field must be positive"))
    nonnegative && result < 0 && throw(ArgumentError("$field must be nonnegative"))
    result
end

function _gaf_integer(value, field::String; minimum::Int=1, maximum::Int=typemax(Int))
    value isa Bool && throw(ArgumentError("$field cannot be Bool"))
    value isa Integer || throw(ArgumentError("$field must be an integer"))
    result = Int(value)
    minimum <= result <= maximum || throw(ArgumentError("$field is outside its range"))
    result
end

function _gaf_source_body(source_id, snapshot_path, snapshot_file_hash,
        snapshot_payload_hash, source_binding_hash, shot_id, efm_time_index,
        efm_time_s, coil_geometry_status, reference_role)
    (revision=_GAF_REVISION, source_id=source_id,
     snapshot_path=snapshot_path,
     snapshot_file_hash=snapshot_file_hash,
     snapshot_payload_hash=snapshot_payload_hash,
     source_binding_hash=source_binding_hash,
     shot_id=shot_id, efm_time_index=efm_time_index,
     efm_time_s=efm_time_s,
     coil_geometry_status=coil_geometry_status,
     reference_role=reference_role,
     device_routing=:none)
end

"""Device-neutral identity for one externally verified axisymmetric snapshot."""
struct GenericAxisymmetricSourceReferenceV1
    source_id::String
    snapshot_path::String
    snapshot_file_hash::Digest256
    snapshot_payload_hash::Digest256
    source_binding_hash::Digest256
    shot_id::Int
    efm_time_index::Int
    efm_time_s::Float64
    coil_geometry_status::Symbol
    reference_role::Symbol
    source_hash::Digest256
    function GenericAxisymmetricSourceReferenceV1(source_id, snapshot_path,
            snapshot_file_hash::Digest256, snapshot_payload_hash::Digest256,
            source_binding_hash::Digest256, shot_id, efm_time_index, efm_time_s;
            coil_geometry_status::Symbol=:typed_absent_from_bound_source_protocol,
            reference_role::Symbol=:same_source_reference_reconstruction)
        id = _gaf_text(source_id, "source_id")
        path = abspath(normpath(_gaf_text(snapshot_path, "snapshot_path")))
        isfile(path) || throw(ArgumentError("source snapshot file is absent"))
        actual = _gaf_sha256_file(path)
        actual == snapshot_file_hash ||
            throw(ArgumentError("source snapshot file hash mismatch"))
        sid = _gaf_integer(shot_id, "shot_id"; minimum=1)
        index = _gaf_integer(efm_time_index, "efm_time_index"; minimum=0)
        time = _gaf_finite(efm_time_s, "efm_time_s")
        coil_geometry_status === :typed_absent_from_bound_source_protocol ||
            throw(ArgumentError("v1 source must preserve unbound coil geometry"))
        reference_role === :same_source_reference_reconstruction ||
            throw(ArgumentError("v1 source role differs"))
        body = _gaf_source_body(id, path, snapshot_file_hash,
            snapshot_payload_hash, source_binding_hash, sid, index, time,
            coil_geometry_status, reference_role)
        new(id, path, snapshot_file_hash, snapshot_payload_hash,
            source_binding_hash, sid, index, time, coil_geometry_status,
            reference_role, canonical_hash(body))
    end
end

function validate_generic_axisymmetric_source(source::GenericAxisymmetricSourceReferenceV1)
    isfile(source.snapshot_path) || throw(ArgumentError("source snapshot file disappeared"))
    _gaf_sha256_file(source.snapshot_path) == source.snapshot_file_hash ||
        throw(ArgumentError("live source snapshot file hash mismatch"))
    body = _gaf_source_body(source.source_id, source.snapshot_path,
        source.snapshot_file_hash, source.snapshot_payload_hash,
        source.source_binding_hash, source.shot_id, source.efm_time_index,
        source.efm_time_s, source.coil_geometry_status, source.reference_role)
    expected = canonical_hash(body)
    source.source_hash == expected || throw(ArgumentError("source identity hash mismatch"))
    expected
end

canonical_hash(x::GenericAxisymmetricSourceReferenceV1) =
    validate_generic_axisymmetric_source(x)
semantic_view(x::GenericAxisymmetricSourceReferenceV1) = merge(
    _gaf_source_body(x.source_id, x.snapshot_path, x.snapshot_file_hash,
        x.snapshot_payload_hash, x.source_binding_hash, x.shot_id,
        x.efm_time_index, x.efm_time_s, x.coil_geometry_status,
        x.reference_role), (source_hash=x.source_hash,))

struct ObservedDirichletProfileControlsV2
    rtol::Float64
    atol::Float64
    max_iterations::Int
    blend::Float64
    function ObservedDirichletProfileControlsV2(rtol, atol, max_iterations,
            blend=0.0)
        r = _gaf_finite(rtol, "rtol"; positive=true)
        a = _gaf_finite(atol, "atol"; positive=true)
        r < 1 && a < 1 || throw(ArgumentError("rtol/atol must be less than one"))
        b = _gaf_finite(blend, "blend"; nonnegative=true)
        b < 1 || throw(ArgumentError("blend must be less than one"))
        new(r, a, _gaf_integer(max_iterations, "max_iterations";
            minimum=1, maximum=1000), b)
    end
end
semantic_view(x::ObservedDirichletProfileControlsV2) = (
    rtol=x.rtol, atol=x.atol, max_iterations=x.max_iterations, blend=x.blend,
    coordinate_transform=:linear_interp_source_r_to_uniform_solver_r,
    machine=:explicit_empty_machine,
    boundary=:observed_dirichlet_box_edges,
    cocos_mapping=_GAF_COCOS_MAPPING,
    cocos_scope=_GAF_COCOS_SCOPE)

function _gaf_canonical_field_observations(value::NamedTuple, prefix::String)
    Tuple((path="$prefix.$(name)", value_type=string(typeof(field)),
           canonical=is_canonical_value(field))
          for (name, field) in pairs(value))
end

"""Describe the exact pre-constructor canonical boundary without weakening it.

The `stripped_declaration_id` branch preserves the v6 intermediate that reached
the declaration body before the owned text-normalization repair.  This
observation is emitted before the constructor guard in the executable fixture,
so a future regression leaves the field/type path in recorded stdout.
"""
function _gaf_declaration_canonical_observation(declaration_id,
        source::GenericAxisymmetricSourceReferenceV1,
        controls::ObservedDirichletProfileControlsV2)
    raw_declaration_id = String(declaration_id)
    stripped_declaration_id = strip(raw_declaration_id)
    normalized_declaration_id = _gaf_text(declaration_id, "declaration_id")
    legacy_body = _gaf_declaration_body(stripped_declaration_id, source, controls)
    normalized_body = _gaf_declaration_body(normalized_declaration_id, source, controls)
    legacy_fields = _gaf_canonical_field_observations(legacy_body, "\$")
    first_noncanonical_path = "none"
    for field in legacy_fields
        if !field.canonical
            first_noncanonical_path = field.path
            break
        end
    end
    source_view = semantic_view(source)
    controls_view = semantic_view(controls)
    (schema="fusionconceptai:native-gs-declaration-canonical-observation-v1",
     input_declaration_id_type=string(typeof(declaration_id)),
     stripped_declaration_id_type=string(typeof(stripped_declaration_id)),
     normalized_declaration_id_type=string(typeof(normalized_declaration_id)),
     legacy_body_field_observations=legacy_fields,
     source_semantic_field_observations=
        _gaf_canonical_field_observations(source_view, "\$.source"),
     controls_semantic_field_observations=
        _gaf_canonical_field_observations(controls_view, "\$.controls"),
     first_legacy_noncanonical_path=first_noncanonical_path,
     legacy_body_canonical=is_canonical_value(legacy_body),
     normalized_body_canonical=is_canonical_value(normalized_body))
end

function _gaf_declaration_body(declaration_id, source, controls)
    (revision=_GAF_REVISION, declaration_id=declaration_id,
     model=:axisymmetric_grad_shafranov_tabulated_profile,
     execution_mode=:source_and_observed_dirichlet_fixed_boundary,
      source=source, controls=controls,
      free_boundary_status=:typed_absent_unmapped_coil_geometry,
      reference_inversion_G1_G2_G3=false,
      executable_source_scope=_GAF_EXECUTABLE_SOURCE_SCOPE,
      independent_validation=false, likelihood_ready=false,
     claim_ceiling=_GAF_CLAIM)
end

"""G2-owned declaration for the generic source and conditional solve."""
struct GenericAxisymmetricProfileDeclarationV2
    declaration_id::String
    source::GenericAxisymmetricSourceReferenceV1
    controls::ObservedDirichletProfileControlsV2
    declaration_hash::Digest256
    function GenericAxisymmetricProfileDeclarationV2(declaration_id,
            source::GenericAxisymmetricSourceReferenceV1,
            controls::ObservedDirichletProfileControlsV2)
        id = _gaf_text(declaration_id, "declaration_id")
        validate_generic_axisymmetric_source(source)
        body = _gaf_declaration_body(id, source, controls)
        is_canonical_value(body) || throw(ArgumentError("declaration is not canonicalizable"))
        new(id, source, controls, canonical_hash(body))
    end
end

function validate_generic_axisymmetric_profile_declaration(
        declaration::GenericAxisymmetricProfileDeclarationV2)
    validate_generic_axisymmetric_source(declaration.source)
    expected = canonical_hash(_gaf_declaration_body(declaration.declaration_id,
        declaration.source, declaration.controls))
    declaration.declaration_hash == expected ||
        throw(ArgumentError("profile declaration hash mismatch"))
    expected
end

canonical_hash(x::GenericAxisymmetricProfileDeclarationV2) =
    validate_generic_axisymmetric_profile_declaration(x)
semantic_view(x::GenericAxisymmetricProfileDeclarationV2) = merge(
    _gaf_declaration_body(x.declaration_id, x.source, x.controls),
    (declaration_hash=x.declaration_hash,))

function _gaf_binding_body(declaration_hash, field_geometry_genome_hash,
        field_geometry_graph_hash, field_geometry_graph_binding_hash,
        mission_hash, bounds_hash, scenario_hash)
    (revision=_GAF_REVISION,
     binding_kind=:generic_axisymmetric_profile_source_binding,
     declaration_hash=declaration_hash,
     field_geometry_genome_hash=field_geometry_genome_hash,
     field_geometry_graph_hash=field_geometry_graph_hash,
     field_geometry_graph_binding_hash=field_geometry_graph_binding_hash,
     mission_hash=mission_hash, bounds_hash=bounds_hash,
     scenario_hash=scenario_hash)
end

struct GenericAxisymmetricProfileBindingV2
    declaration::GenericAxisymmetricProfileDeclarationV2
    field_geometry_genome_hash::Digest256
    field_geometry_graph_hash::Digest256
    field_geometry_graph_binding_hash::Digest256
    mission_hash::Digest256
    bounds_hash::Digest256
    scenario_hash::Digest256
    binding_hash::Digest256
    function GenericAxisymmetricProfileBindingV2(token::_GAFToken,
            declaration::GenericAxisymmetricProfileDeclarationV2,
            field_geometry_genome_hash::Digest256,
            field_geometry_graph_hash::Digest256,
            field_geometry_graph_binding_hash::Digest256,
            mission_hash::Digest256, bounds_hash::Digest256,
            scenario_hash::Digest256, binding_hash::Digest256)
        token === _GAF_TOKEN || throw(ArgumentError("private constructor"))
        new(declaration, field_geometry_genome_hash, field_geometry_graph_hash,
            field_geometry_graph_binding_hash, mission_hash, bounds_hash,
            scenario_hash, binding_hash)
    end
end

function validate_generic_axisymmetric_profile_binding(
        binding::GenericAxisymmetricProfileBindingV2)
    declaration_hash = validate_generic_axisymmetric_profile_declaration(
        binding.declaration)
    expected = canonical_hash(_gaf_binding_body(declaration_hash,
        binding.field_geometry_genome_hash, binding.field_geometry_graph_hash,
        binding.field_geometry_graph_binding_hash, binding.mission_hash,
        binding.bounds_hash, binding.scenario_hash))
    binding.binding_hash == expected || throw(ArgumentError("profile binding hash mismatch"))
    expected
end

canonical_hash(x::GenericAxisymmetricProfileBindingV2) =
    validate_generic_axisymmetric_profile_binding(x)
semantic_view(x::GenericAxisymmetricProfileBindingV2) = merge(
    _gaf_binding_body(canonical_hash(x.declaration), x.field_geometry_genome_hash,
        x.field_geometry_graph_hash, x.field_geometry_graph_binding_hash,
        x.mission_hash, x.bounds_hash, x.scenario_hash),
    (binding_hash=x.binding_hash,))

function _gaf_owned_declaration(candidate, declaration)
    matches = Tuple(field for field in candidate.field_geometry_genome_ref.fields
        if field isa GenericAxisymmetricProfileDeclarationV2 &&
           canonical_hash(field) == canonical_hash(declaration))
    length(matches) == 1 || throw(ArgumentError(
        "generic axisymmetric declaration is absent from or ambiguous in current G2 fields"))
    only(matches)
end

function make_generic_axisymmetric_profile_binding(
        compiled::CompiledCandidatePrefixV4, registry::GenomeContractRegistryV4,
        mission_payload, bounds_payload, comparison_scope, scenario_scope,
        scenario, declaration::GenericAxisymmetricProfileDeclarationV2)
    _runtime_validate_compiled_prefix(compiled, compiled.candidate, registry,
        mission_payload, bounds_payload,
        _runtime_axis_tuple(comparison_scope, "comparison_scope"),
        _runtime_axis_tuple(scenario_scope, "scenario_scope"))
    _gaf_owned_declaration(compiled.candidate, declaration)
    is_canonical_value(scenario) || throw(ArgumentError("scenario is not canonicalizable"))
    scenario_hash = canonical_hash(scenario)
    _forward_scenario_name(scenario) in Tuple(scenario_scope) ||
        throw(ArgumentError("scenario is outside frozen scope"))
    graph = _make_forward_graph_binding(:field_geometry, compiled.field_geometry_graph)
    body = _gaf_binding_body(canonical_hash(declaration),
        field_geometry_hash(compiled.candidate.field_geometry_genome_ref),
        canonical_hash(compiled.field_geometry_graph), canonical_hash(graph),
        _runtime_decl_hash(mission_payload), _runtime_decl_hash(bounds_payload),
        scenario_hash)
    GenericAxisymmetricProfileBindingV2(_GAF_TOKEN, declaration,
        field_geometry_hash(compiled.candidate.field_geometry_genome_ref),
        canonical_hash(compiled.field_geometry_graph), canonical_hash(graph),
        _runtime_decl_hash(mission_payload), _runtime_decl_hash(bounds_payload),
        scenario_hash, canonical_hash(body))
end

function _gaf_context_binding(context::ForwardChainContextV4)
    validate_forward_chain_context(context)
    matches = Tuple(binding for binding in context.subject.bindings
        if binding isa GenericAxisymmetricProfileBindingV2)
    length(matches) == 1 || throw(ArgumentError(
        "physical subject must contain exactly one generic axisymmetric profile binding"))
    binding = only(matches)
    validate_generic_axisymmetric_profile_binding(binding)
    _gaf_owned_declaration(context.candidate, binding.declaration)
    graph = forward_graph_binding(context, :field_geometry)
    binding.field_geometry_genome_hash ==
        field_geometry_hash(context.candidate.field_geometry_genome_ref) ||
        throw(ArgumentError("profile binding G2 Genome mismatch"))
    binding.field_geometry_graph_hash == canonical_hash(context.compiled.field_geometry_graph) ||
        throw(ArgumentError("profile binding G2 graph mismatch"))
    binding.field_geometry_graph_binding_hash == canonical_hash(graph) ||
        throw(ArgumentError("profile binding graph identity mismatch"))
    binding.mission_hash == _runtime_decl_hash(context.mission_payload) ||
        throw(ArgumentError("profile binding mission mismatch"))
    binding.bounds_hash == _runtime_decl_hash(context.bounds_payload) ||
        throw(ArgumentError("profile binding bounds mismatch"))
    binding.scenario_hash == context.scenario_hash ||
        throw(ArgumentError("profile binding scenario mismatch"))
    binding
end

function freegs_axisymmetric_profile_solver_input_v2(context::ForwardChainContextV4)
    validate_forward_chain_context(context)
    binding = _gaf_context_binding(context)
    declaration = binding.declaration
    source = declaration.source
    validate_generic_axisymmetric_source(source)
    controls = declaration.controls
    (schema=_GAF_INPUT_SCHEMA, revision=_GAF_REVISION,
     context_hash=string(context.context_hash),
     candidate_hash=string(context.candidate_hash),
     compiled_prefix_hash=string(context.compiled.prefix_hash),
     physical_subject_hash=string(context.subject.physical_subject_hash),
     scenario_hash=string(context.scenario_hash),
     field_geometry_genome_hash=string(binding.field_geometry_genome_hash),
     field_geometry_graph_hash=string(binding.field_geometry_graph_hash),
     field_geometry_graph_binding_hash=string(binding.field_geometry_graph_binding_hash),
     binding_hash=string(binding.binding_hash),
     declaration_hash=string(declaration.declaration_hash),
     source_snapshot_file_sha256=string(source.snapshot_file_hash),
     source_snapshot_payload_sha256=string(source.snapshot_payload_hash),
     controls=(mode="source_and_observed_dirichlet_fixed_boundary",
        rtol=controls.rtol, atol=controls.atol,
        max_iterations=controls.max_iterations, blend=controls.blend,
         coordinate_transform="linear_interp_source_r_to_uniform_solver_r",
         machine="explicit_empty_machine",
         boundary="observed_dirichlet_box_edges",
         cocos_mapping="identity_no_sign_or_2pi_transform",
         cocos_scope="gs_bp_subset_only_q_theta_not_consumed"))
end

struct GenericAxisymmetricForwardStateV1
    role::Symbol
    state_hash::Digest256
    source_snapshot_payload_hash::Digest256
    claim_ceiling::Symbol
    independent_validation::Bool
    likelihood_ready::Bool
end

function validate_generic_axisymmetric_forward_state(
        state::GenericAxisymmetricForwardStateV1,
        source::GenericAxisymmetricSourceReferenceV1)
    state.role in (:same_source_reference_reconstruction,
        :conditional_fixed_boundary_solution) ||
        throw(ArgumentError("generic forward-state role is unsupported"))
    state.source_snapshot_payload_hash == source.snapshot_payload_hash ||
        throw(ArgumentError("generic forward-state source mismatch"))
    state.claim_ceiling === _GAF_CLAIM ||
        throw(ArgumentError("generic forward-state claim ceiling differs"))
    !state.independent_validation && !state.likelihood_ready ||
        throw(ArgumentError("generic forward state contains unauthorized readiness"))
    state.state_hash
end

semantic_view(x::GenericAxisymmetricForwardStateV1) = (
    role=x.role, state_hash=x.state_hash,
    source_snapshot_payload_hash=x.source_snapshot_payload_hash,
    claim_ceiling=x.claim_ceiling,
    independent_validation=x.independent_validation,
    likelihood_ready=x.likelihood_ready)
canonical_hash(x::GenericAxisymmetricForwardStateV1) = x.state_hash

struct GenericAxisymmetricForwardComparisonV1
    reference_state::GenericAxisymmetricForwardStateV1
    solved_state::GenericAxisymmetricForwardStateV1
    comparison_hash::Digest256
    conditional_boundary_from_reconstruction::Bool
    independent_validation::Bool
    likelihood_ready::Bool
end

function validate_generic_axisymmetric_forward_comparison(
        comparison::GenericAxisymmetricForwardComparisonV1,
        source::GenericAxisymmetricSourceReferenceV1)
    validate_generic_axisymmetric_forward_state(comparison.reference_state, source)
    validate_generic_axisymmetric_forward_state(comparison.solved_state, source)
    comparison.reference_state.role === :same_source_reference_reconstruction ||
        throw(ArgumentError("comparison reference role differs"))
    comparison.solved_state.role === :conditional_fixed_boundary_solution ||
        throw(ArgumentError("comparison solved role differs"))
    comparison.conditional_boundary_from_reconstruction ||
        throw(ArgumentError("comparison lost conditional boundary label"))
    !comparison.independent_validation && !comparison.likelihood_ready ||
        throw(ArgumentError("comparison contains unauthorized readiness"))
    comparison.comparison_hash
end

struct FreeGSAxisymmetricProfileSummaryV2
    iterations::Int
    final_relative_change::Float64
    psi_l2_relative::Float64
    jtor_l2_relative::Float64
    reference_state::GenericAxisymmetricForwardStateV1
    solved_state::GenericAxisymmetricForwardStateV1
    comparison::GenericAxisymmetricForwardComparisonV1
    observed_boundary_hash::Digest256
end

function _gaf_receipt_body(status, context_hash, physical_subject_hash,
        scenario_hash, binding_hash, source_snapshot_file_hash,
        source_snapshot_payload_hash, interpreter_hash, runner_hash,
        input_hash, backend_input_hash, output_hash, result_hash,
        stdout, stderr, exit_code, summary, gap_kind, reason)
    (revision=_GAF_REVISION, status=status,
     context_hash=context_hash, physical_subject_hash=physical_subject_hash,
     scenario_hash=scenario_hash, binding_hash=binding_hash,
     source_snapshot_file_hash=source_snapshot_file_hash,
     source_snapshot_payload_hash=source_snapshot_payload_hash,
     interpreter_path=_GAF_PINNED_PYTHON, interpreter_hash=interpreter_hash,
     runner_path=_GAF_RUNNER, runner_hash=runner_hash,
     input_hash=input_hash, backend_input_hash=backend_input_hash,
     output_hash=output_hash, result_hash=result_hash,
     stdout=stdout, stderr=stderr, exit_code=exit_code,
     summary=summary, gap_kind=gap_kind, reason=reason,
      claim_ceiling=_GAF_CLAIM,
      reference_inversion_G1_G2_G3=false,
      executable_source_scope=_GAF_EXECUTABLE_SOURCE_SCOPE,
      conditional_boundary_from_reconstruction=true,
     same_source_reference=true, independent_validation=false,
     physical_validation=false, engineering_validation=false,
     likelihood_ready=false, formal_acceptance=false,
     terminal_authority=false)
end

struct FreeGSAxisymmetricProfileReceiptV2
    status::Symbol
    context_hash::Digest256
    physical_subject_hash::Digest256
    scenario_hash::Digest256
    binding_hash::Digest256
    source_snapshot_file_hash::Digest256
    source_snapshot_payload_hash::Digest256
    interpreter_hash::Digest256
    runner_hash::Digest256
    input_hash::Digest256
    backend_input_hash::Digest256
    output_hash::Digest256
    result_hash::Digest256
    stdout::String
    stderr::String
    exit_code::Int
    summary::Union{Nothing,FreeGSAxisymmetricProfileSummaryV2}
    gap_kind::Symbol
    reason::String
    claim_ceiling::Symbol
    conditional_boundary_from_reconstruction::Bool
    same_source_reference::Bool
    independent_validation::Bool
    physical_validation::Bool
    engineering_validation::Bool
    likelihood_ready::Bool
    formal_acceptance::Bool
    terminal_authority::Bool
    reference_inversion_G1_G2_G3::Bool
    executable_source_scope::Symbol
    receipt_hash::Digest256
    function FreeGSAxisymmetricProfileReceiptV2(token::_GAFToken, status,
            context_hash, physical_subject_hash, scenario_hash, binding_hash,
            source_snapshot_file_hash, source_snapshot_payload_hash,
            interpreter_hash, runner_hash, input_hash, backend_input_hash,
            output_hash, result_hash, stdout, stderr, exit_code, summary,
            gap_kind, reason)
        token === _GAF_TOKEN || throw(ArgumentError("private constructor"))
        body = _gaf_receipt_body(status, context_hash, physical_subject_hash,
            scenario_hash, binding_hash, source_snapshot_file_hash,
            source_snapshot_payload_hash, interpreter_hash, runner_hash,
            input_hash, backend_input_hash, output_hash, result_hash,
            String(stdout), String(stderr), Int(exit_code), summary,
            gap_kind, String(reason))
        new(status, context_hash, physical_subject_hash, scenario_hash,
            binding_hash, source_snapshot_file_hash,
            source_snapshot_payload_hash, interpreter_hash, runner_hash,
            input_hash, backend_input_hash, output_hash, result_hash,
            String(stdout), String(stderr), Int(exit_code), summary, gap_kind,
            String(reason), _GAF_CLAIM, true, true, false, false, false,
            false, false, false, false, _GAF_EXECUTABLE_SOURCE_SCOPE,
            canonical_hash(body))
    end
end

semantic_view(x::FreeGSAxisymmetricProfileReceiptV2) = merge(
    _gaf_receipt_body(x.status, x.context_hash, x.physical_subject_hash,
        x.scenario_hash, x.binding_hash, x.source_snapshot_file_hash,
        x.source_snapshot_payload_hash, x.interpreter_hash, x.runner_hash,
        x.input_hash, x.backend_input_hash, x.output_hash, x.result_hash,
        x.stdout, x.stderr, x.exit_code, x.summary, x.gap_kind, x.reason),
    (receipt_hash=x.receipt_hash,))
canonical_hash(x::FreeGSAxisymmetricProfileReceiptV2) = x.receipt_hash

struct FreeGSAxisymmetricProfileArtifactsV2
    receipt::FreeGSAxisymmetricProfileReceiptV2
    input_json::String
    output_json::String
end

function _gaf_make_receipt(context, binding; status=:program_exception,
        interpreter_hash=_GAF_UNKNOWN_HASH, runner_hash=_GAF_UNKNOWN_HASH,
        input_hash=_GAF_UNKNOWN_HASH, backend_input_hash=_GAF_UNKNOWN_HASH,
        output_hash=_GAF_UNKNOWN_HASH, result_hash=_GAF_UNKNOWN_HASH,
        stdout="", stderr="", exit_code=-1, summary=nothing,
        gap_kind=:program_exception, reason="profile execution program exception")
    source = binding.declaration.source
    FreeGSAxisymmetricProfileReceiptV2(_GAF_TOKEN, status,
        context.context_hash, context.subject.physical_subject_hash,
        context.scenario_hash, binding.binding_hash,
        source.snapshot_file_hash, source.snapshot_payload_hash,
        interpreter_hash, runner_hash, input_hash, backend_input_hash,
        output_hash, result_hash, stdout, stderr, exit_code, summary,
        gap_kind, reason)
end

function _gaf_parse_summary(stdout::String, output_json::String, context,
        binding, input_hash::Digest256)
    lines = filter(line -> startswith(line, "FUSION_FREEGS_PROFILE_V2\t"),
        split(stdout, '\n'))
    length(lines) == 1 || throw(ArgumentError("profile runner summary is missing or ambiguous"))
    parts = split(only(lines), '\t'; keepempty=true)
    length(parts) == 16 || throw(ArgumentError("profile runner summary field count mismatch"))
    parts[4] == string(context.context_hash) ||
        throw(ArgumentError("profile runner context echo mismatch"))
    parts[5] == string(binding.binding_hash) ||
        throw(ArgumentError("profile runner binding echo mismatch"))
    parts[6] == string(binding.declaration.source.snapshot_payload_hash) ||
        throw(ArgumentError("profile runner source echo mismatch"))
    emitted_output_hash = Digest256(parts[11])
    emitted_output_hash == _gaf_sha256_text(output_json) ||
        throw(ArgumentError("profile runner stdout/output byte hash mismatch"))
    backend_input_hash = Digest256(parts[12])
    backend_input_hash == input_hash ||
        throw(ArgumentError("profile runner semantic input hash mismatch"))
    status = Symbol(parts[2])
    result_hash = Digest256(parts[3])
    if status === :conditional_fixed_boundary_solver_converged_residual_measured
        all(!isempty(parts[i]) for i in 7:16) ||
            throw(ArgumentError("successful profile summary is incomplete"))
        reference = GenericAxisymmetricForwardStateV1(
            :same_source_reference_reconstruction, Digest256(parts[13]),
            binding.declaration.source.snapshot_payload_hash, _GAF_CLAIM,
            false, false)
        solved = GenericAxisymmetricForwardStateV1(
            :conditional_fixed_boundary_solution, Digest256(parts[14]),
            binding.declaration.source.snapshot_payload_hash, _GAF_CLAIM,
            false, false)
        comparison = GenericAxisymmetricForwardComparisonV1(reference, solved,
            Digest256(parts[15]), true, false, false)
        validate_generic_axisymmetric_forward_comparison(comparison,
            binding.declaration.source)
        summary = FreeGSAxisymmetricProfileSummaryV2(parse(Int, parts[7]),
            parse(Float64, parts[8]), parse(Float64, parts[9]),
            parse(Float64, parts[10]), reference, solved, comparison,
            Digest256(parts[16]))
        all(isfinite, (summary.final_relative_change,
            summary.psi_l2_relative, summary.jtor_l2_relative)) ||
            throw(ArgumentError("profile runner emitted nonfinite summary metrics"))
        return (status=status, result_hash=result_hash,
            backend_input_hash=backend_input_hash, summary=summary,
            gap_kind=:none,
            reason="solver iteration converged; independent GS residual measured without an acceptance threshold")
    elseif status === :validated_input_no_solve
        return (status=status, result_hash=result_hash,
            backend_input_hash=backend_input_hash, summary=nothing,
            gap_kind=:not_executed,
            reason="validated exact source/wrapper input without numerical solve")
    elseif status === :input_validation_failed
        return (status=status, result_hash=result_hash,
            backend_input_hash=backend_input_hash, summary=nothing,
            gap_kind=:input_validation_failed,
            reason="profile runner rejected the bound input or source")
    elseif status === :backend_unavailable
        return (status=status, result_hash=result_hash,
            backend_input_hash=backend_input_hash, summary=nothing,
            gap_kind=:dependency_unavailable,
            reason="profile runner could not load the pinned backend")
    elseif status === :numerical_fail_nonconvergence
        return (status=status, result_hash=result_hash,
            backend_input_hash=backend_input_hash, summary=nothing,
            gap_kind=:numerical_fail,
            reason="FreeGS Picard iteration reached its explicit iteration limit")
    elseif status === :program_exception
        return (status=status, result_hash=result_hash,
            backend_input_hash=backend_input_hash, summary=nothing,
            gap_kind=:program_exception,
            reason="profile runner raised a non-normalized program exception")
    end
    throw(ArgumentError("profile runner status is unauthorized"))
end

function _gaf_write_artifacts(directory::String, input_json::String,
        output_json::String, receipt::FreeGSAxisymmetricProfileReceiptV2)
    absolute = abspath(directory)
    mkpath(absolute)
    write(joinpath(absolute, "solver_input.canonical.json"), input_json)
    write(joinpath(absolute, "solver_output.json"), output_json)
    write(joinpath(absolute, "execution_receipt.canonical.json"),
        canonical_json(receipt) * "\n")
    absolute
end

function execute_freegs_axisymmetric_profile_v2(context::ForwardChainContextV4;
        artifact_directory::Union{Nothing,AbstractString}=nothing,
        validate_only::Bool=false)
    validate_forward_chain_context(context)
    binding = _gaf_context_binding(context)
    source = binding.declaration.source
    validate_generic_axisymmetric_source(source)
    input = freegs_axisymmetric_profile_solver_input_v2(context)
    input_json = canonical_json(input) * "\n"
    input_hash = _gaf_sha256_text(input_json)
    runner_hash = isfile(_GAF_RUNNER) ? _gaf_sha256_file(_GAF_RUNNER) : _GAF_UNKNOWN_HASH
    interpreter_hash = isfile(_GAF_PINNED_PYTHON) ?
        _gaf_sha256_file(_GAF_PINNED_PYTHON) : _GAF_UNKNOWN_HASH
    if !isfile(_GAF_RUNNER) || !isfile(_GAF_PINNED_PYTHON)
        receipt = _gaf_make_receipt(context, binding; status=:backend_unavailable,
            interpreter_hash=interpreter_hash, runner_hash=runner_hash,
            input_hash=input_hash, exit_code=3,
            gap_kind=:dependency_unavailable,
            reason="pinned interpreter or profile runner is unavailable")
        artifact_directory === nothing || _gaf_write_artifacts(
            String(artifact_directory), input_json, "", receipt)
        return FreeGSAxisymmetricProfileArtifactsV2(receipt, input_json, "")
    end
    stdout = ""
    stderr = ""
    output_json = ""
    exit_code = -1
    parsed = nothing
    execution_error = nothing
    mktempdir() do directory
        input_path = joinpath(directory, "input.json")
        output_path = joinpath(directory, "output.json")
        stdout_path = joinpath(directory, "stdout.txt")
        stderr_path = joinpath(directory, "stderr.txt")
        write(input_path, input_json)
        command = validate_only ?
            `$_GAF_PINNED_PYTHON $_GAF_RUNNER --input $input_path --source $(source.snapshot_path) --output $output_path --validate-only` :
            `$_GAF_PINNED_PYTHON $_GAF_RUNNER --input $input_path --source $(source.snapshot_path) --output $output_path`
        try
            process = open(stdout_path, "w") do stdout_io
                open(stderr_path, "w") do stderr_io
                    run(pipeline(ignorestatus(command), stdout=stdout_io,
                        stderr=stderr_io))
                end
            end
            exit_code = process.exitcode
        catch error
            execution_error = error
        end
        stdout = isfile(stdout_path) ? read(stdout_path, String) : ""
        stderr = isfile(stderr_path) ? read(stderr_path, String) : ""
        output_json = isfile(output_path) ? read(output_path, String) : ""
        if execution_error === nothing
            try
                parsed = _gaf_parse_summary(stdout, output_json, context,
                    binding, input_hash)
            catch error
                execution_error = error
            end
        end
    end
    output_hash = isempty(output_json) ? _GAF_UNKNOWN_HASH : _gaf_sha256_text(output_json)
    success = execution_error === nothing && exit_code == 0 && parsed !== nothing &&
        parsed.status in (:conditional_fixed_boundary_solver_converged_residual_measured,
            :validated_input_no_solve)
    receipt = if success
        _gaf_make_receipt(context, binding; status=parsed.status,
            interpreter_hash=interpreter_hash, runner_hash=runner_hash,
            input_hash=input_hash, backend_input_hash=parsed.backend_input_hash,
            output_hash=output_hash, result_hash=parsed.result_hash,
            stdout=stdout, stderr=stderr, exit_code=exit_code,
            summary=parsed.summary, gap_kind=parsed.gap_kind,
            reason=parsed.reason)
    else
        status = parsed === nothing ? :program_exception : parsed.status
        kind = parsed === nothing ? :malformed_backend_output : parsed.gap_kind
        reason = parsed === nothing ?
            "profile runner output could not be authenticated or parsed" : parsed.reason
        _gaf_make_receipt(context, binding; status=status,
            interpreter_hash=interpreter_hash, runner_hash=runner_hash,
            input_hash=input_hash,
            backend_input_hash=parsed === nothing ? _GAF_UNKNOWN_HASH : parsed.backend_input_hash,
            output_hash=output_hash,
            result_hash=parsed === nothing ? _GAF_UNKNOWN_HASH : parsed.result_hash,
            stdout=stdout, stderr=stderr, exit_code=exit_code,
            summary=nothing, gap_kind=kind,
            reason=reason)
    end
    validate_freegs_axisymmetric_profile_receipt_v2(context, receipt)
    artifact_directory === nothing || _gaf_write_artifacts(
        String(artifact_directory), input_json, output_json, receipt)
    FreeGSAxisymmetricProfileArtifactsV2(receipt, input_json, output_json)
end

function validate_freegs_axisymmetric_profile_receipt_v2(
        context::ForwardChainContextV4,
        receipt::FreeGSAxisymmetricProfileReceiptV2)
    validate_forward_chain_context(context)
    binding = _gaf_context_binding(context)
    source = binding.declaration.source
    receipt.context_hash == context.context_hash ||
        throw(ArgumentError("profile receipt context mismatch"))
    receipt.physical_subject_hash == context.subject.physical_subject_hash ||
        throw(ArgumentError("profile receipt subject mismatch"))
    receipt.scenario_hash == context.scenario_hash ||
        throw(ArgumentError("profile receipt scenario mismatch"))
    receipt.binding_hash == binding.binding_hash ||
        throw(ArgumentError("profile receipt binding mismatch"))
    receipt.source_snapshot_file_hash == source.snapshot_file_hash ||
        throw(ArgumentError("profile receipt source-file mismatch"))
    receipt.source_snapshot_payload_hash == source.snapshot_payload_hash ||
        throw(ArgumentError("profile receipt source-payload mismatch"))
    receipt.claim_ceiling === _GAF_CLAIM ||
        throw(ArgumentError("profile receipt claim ceiling differs"))
    !receipt.reference_inversion_G1_G2_G3 &&
        receipt.executable_source_scope === _GAF_EXECUTABLE_SOURCE_SCOPE ||
        throw(ArgumentError("profile receipt source scope differs"))
    receipt.conditional_boundary_from_reconstruction &&
        receipt.same_source_reference && !receipt.independent_validation &&
        !receipt.physical_validation && !receipt.engineering_validation &&
        !receipt.likelihood_ready && !receipt.formal_acceptance &&
        !receipt.terminal_authority ||
        throw(ArgumentError("profile receipt contains unauthorized authority"))
    receipt.status in (:conditional_fixed_boundary_solver_converged_residual_measured,
        :validated_input_no_solve, :input_validation_failed,
        :backend_unavailable, :numerical_fail_nonconvergence,
        :program_exception) ||
        throw(ArgumentError("profile receipt status is unauthorized"))
    if receipt.status === :conditional_fixed_boundary_solver_converged_residual_measured
        receipt.exit_code == 0 && receipt.summary !== nothing &&
            receipt.gap_kind === :none ||
            throw(ArgumentError("successful profile solve receipt is inconsistent"))
        validate_generic_axisymmetric_forward_comparison(
            receipt.summary.comparison, source)
    elseif receipt.status === :validated_input_no_solve
        receipt.exit_code == 0 && receipt.summary === nothing &&
            receipt.gap_kind === :not_executed ||
            throw(ArgumentError("validation-only receipt is inconsistent"))
    elseif receipt.status === :input_validation_failed
        receipt.exit_code == 2 && receipt.summary === nothing &&
            receipt.gap_kind === :input_validation_failed ||
            throw(ArgumentError("input-validation failure receipt is inconsistent"))
    elseif receipt.status === :backend_unavailable
        receipt.exit_code == 3 && receipt.summary === nothing &&
            receipt.gap_kind === :dependency_unavailable ||
            throw(ArgumentError("backend-unavailable receipt is inconsistent"))
    elseif receipt.status === :numerical_fail_nonconvergence
        receipt.exit_code == 4 && receipt.summary === nothing &&
            receipt.gap_kind === :numerical_fail ||
            throw(ArgumentError("numerical failure receipt is inconsistent"))
    else
        receipt.summary === nothing &&
            ((receipt.gap_kind === :program_exception && receipt.exit_code == 5) ||
             receipt.gap_kind === :malformed_backend_output) ||
            throw(ArgumentError("program-exception receipt is inconsistent"))
    end
    if receipt.status !== :backend_unavailable
        isfile(_GAF_PINNED_PYTHON) &&
            receipt.interpreter_hash == _gaf_sha256_file(_GAF_PINNED_PYTHON) ||
            throw(ArgumentError("profile interpreter hash mismatch"))
        isfile(_GAF_RUNNER) && receipt.runner_hash == _gaf_sha256_file(_GAF_RUNNER) ||
            throw(ArgumentError("profile runner hash mismatch"))
    end
    body = _gaf_receipt_body(receipt.status, receipt.context_hash,
        receipt.physical_subject_hash, receipt.scenario_hash,
        receipt.binding_hash, receipt.source_snapshot_file_hash,
        receipt.source_snapshot_payload_hash, receipt.interpreter_hash,
        receipt.runner_hash, receipt.input_hash, receipt.backend_input_hash,
        receipt.output_hash, receipt.result_hash, receipt.stdout, receipt.stderr,
        receipt.exit_code, receipt.summary, receipt.gap_kind, receipt.reason)
    expected = canonical_hash(body)
    receipt.receipt_hash == expected || throw(ArgumentError("profile receipt hash mismatch"))
    expected
end

freegs_axisymmetric_profile_execution_manifest_v2() = (
    schema="fusionconceptai:runtime-v4-freegs-axisymmetric-profile-execution",
    revision=_GAF_REVISION,
    source_type=:generic_axisymmetric_profile_source,
    device_name_routing=false,
    machine=:explicit_empty_machine,
     boundary=:observed_dirichlet_box_edges,
     cocos_mapping=_GAF_COCOS_MAPPING,
     cocos_scope=_GAF_COCOS_SCOPE,
     reference_inversion_G1_G2_G3=false,
     executable_source_scope=_GAF_EXECUTABLE_SOURCE_SCOPE,
     free_boundary_status=:typed_absent_unmapped_coil_geometry,
     outcomes=(:conditional_fixed_boundary_solver_converged_residual_measured,
        :validated_input_no_solve, :input_validation_failed,
        :backend_unavailable, :numerical_fail_nonconvergence,
        :program_exception),
    claim_ceiling=_GAF_CLAIM,
    independent_validation=false, physical_validation=false,
    engineering_validation=false, likelihood_ready=false,
    formal_acceptance=false, terminal_authority=false)
