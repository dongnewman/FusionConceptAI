"""Candidate-bound FreeGS axisymmetric equilibrium execution bridge.

This file is intentionally isolated from `FusionRuntimeV4.jl`.  It accepts only
a typed G2-owned declaration carried by `context.subject.bindings`, revalidates
the complete `ForwardChainContextV4` at every public execution boundary, and
can emit only a physical-model screen or a recoverable unknown gap.
"""

import FusionConceptAI: semantic_view, canonical_hash
using FusionConceptAI
using SHA

const _FREEGS_AXISYMMETRIC_REVISION = "runtime-v4-freegs-axisymmetric-execution-v1"
const _FREEGS_PINNED_PYTHON = raw"D:\006-Programing\LMC\outputs\fusion_concept_ai\.venv-freegs\Scripts\python.exe"
const _FREEGS_CONTROLLED_RUNNER = abspath(normpath(joinpath(@__DIR__, "..", "..", "scripts",
    "runtime_v4_freegs_axisymmetric_runner.py")))
const _FREEGS_UNKNOWN_HASH = digest256_text("runtime-v4-freegs-axisymmetric-unknown")

struct _FreeGSAxisymmetricToken end
const _FREEGS_AXISYMMETRIC_TOKEN = _FreeGSAxisymmetricToken()

function _freegs_text(value, field::String)
    value isa AbstractString || throw(ArgumentError("$field must be a string"))
    text = strip(String(value))
    !isempty(text) && isvalid(text) || throw(ArgumentError("$field cannot be empty"))
    lowercase(text) in ("*", "any", "all", "wildcard") &&
        throw(ArgumentError("$field cannot be wildcard"))
    String(text)
end

function _freegs_finite(value, field::String; positive::Bool=false, nonnegative::Bool=false)
    value isa Bool && throw(ArgumentError("$field must be numeric, not Bool"))
    value isa Real || throw(ArgumentError("$field must be numeric"))
    result = Float64(value)
    isfinite(result) || throw(ArgumentError("$field must be finite"))
    positive && result <= 0 && throw(ArgumentError("$field must be positive"))
    nonnegative && result < 0 && throw(ArgumentError("$field must be nonnegative"))
    result
end

function _freegs_integer(value, field::String; minimum::Int=1)
    value isa Bool && throw(ArgumentError("$field must be an integer, not Bool"))
    value isa Integer || throw(ArgumentError("$field must be an integer"))
    typemin(Int) <= value <= typemax(Int) || throw(ArgumentError("$field is out of range"))
    result = Int(value)
    result >= minimum || throw(ArgumentError("$field is below its minimum"))
    result
end

struct AxisymmetricDomainV4
    r_min_m::Float64
    r_max_m::Float64
    z_min_m::Float64
    z_max_m::Float64
    nx::Int
    ny::Int
    boundary_model::Symbol
    function AxisymmetricDomainV4(r_min_m, r_max_m, z_min_m, z_max_m, nx, ny,
            boundary_model::Symbol=:free_boundary_hagenow)
        rmin = _freegs_finite(r_min_m, "domain r_min_m"; positive=true)
        rmax = _freegs_finite(r_max_m, "domain r_max_m"; positive=true)
        zmin = _freegs_finite(z_min_m, "domain z_min_m")
        zmax = _freegs_finite(z_max_m, "domain z_max_m")
        rmin < rmax || throw(ArgumentError("domain radial bounds must be ordered"))
        zmin < zmax || throw(ArgumentError("domain vertical bounds must be ordered"))
        nxi = _freegs_integer(nx, "domain nx"; minimum=17)
        nyi = _freegs_integer(ny, "domain ny"; minimum=17)
        isodd(nxi) && isodd(nyi) || throw(ArgumentError("FreeGS grid sizes must be odd"))
        nxi <= 257 && nyi <= 257 || throw(ArgumentError("FreeGS grid sizes exceed the bounded bridge"))
        boundary_model === :free_boundary_hagenow ||
            throw(ArgumentError("only free_boundary_hagenow is supported"))
        new(rmin, rmax, zmin, zmax, nxi, nyi, boundary_model)
    end
end
semantic_view(x::AxisymmetricDomainV4) = (r_min_m=x.r_min_m, r_max_m=x.r_max_m,
    z_min_m=x.z_min_m, z_max_m=x.z_max_m, nx=x.nx, ny=x.ny,
    boundary_model=x.boundary_model)

struct AxisymmetricFilamentCoilV4
    coil_id::String
    major_radius_m::Float64
    vertical_position_m::Float64
    function AxisymmetricFilamentCoilV4(coil_id, major_radius_m, vertical_position_m)
        new(_freegs_text(coil_id, "coil_id"),
            _freegs_finite(major_radius_m, "coil major_radius_m"; positive=true),
            _freegs_finite(vertical_position_m, "coil vertical_position_m"))
    end
end
semantic_view(x::AxisymmetricFilamentCoilV4) = (coil_id=x.coil_id,
    major_radius_m=x.major_radius_m, vertical_position_m=x.vertical_position_m)

struct AxisymmetricConstrainPaxisIpProfileV4
    axis_pressure_pa::Float64
    plasma_current_a::Float64
    vacuum_f_tm::Float64
    alpha_m::Float64
    alpha_n::Float64
    profile_axis_radius_m::Float64
    function AxisymmetricConstrainPaxisIpProfileV4(axis_pressure_pa, plasma_current_a,
            vacuum_f_tm, alpha_m, alpha_n, profile_axis_radius_m)
        new(_freegs_finite(axis_pressure_pa, "axis pressure"; nonnegative=true),
            _freegs_finite(plasma_current_a, "plasma current"),
            _freegs_finite(vacuum_f_tm, "vacuum F"; positive=true),
            _freegs_finite(alpha_m, "alpha_m"; positive=true),
            _freegs_finite(alpha_n, "alpha_n"; positive=true),
            _freegs_finite(profile_axis_radius_m, "profile axis radius"; positive=true))
    end
end
semantic_view(x::AxisymmetricConstrainPaxisIpProfileV4) = (
    profile_model=:constrain_paxis_ip, axis_pressure_pa=x.axis_pressure_pa,
    plasma_current_a=x.plasma_current_a, vacuum_f_tm=x.vacuum_f_tm,
    alpha_m=x.alpha_m, alpha_n=x.alpha_n,
    profile_axis_radius_m=x.profile_axis_radius_m)

struct AxisymmetricShapeConstraintsV4
    xpoints_m::Tuple{Vararg{NTuple{2,Float64}}}
    isoflux_m::Tuple{Vararg{NTuple{4,Float64}}}
    tikhonov_gamma::Float64
    function AxisymmetricShapeConstraintsV4(xpoints, isoflux, tikhonov_gamma)
        xp = Tuple(begin
            length(point) == 2 || throw(ArgumentError("each X-point must have two coordinates"))
            ntuple(i -> _freegs_finite(point[i], "X-point coordinate"), 2)
        end for point in xpoints)
        iso = Tuple(begin
            length(item) == 4 || throw(ArgumentError("each isoflux constraint must have four coordinates"))
            ntuple(i -> _freegs_finite(item[i], "isoflux coordinate"), 4)
        end for item in isoflux)
        length(xp) >= 1 || throw(ArgumentError("at least one X-point is required"))
        length(iso) >= 1 || throw(ArgumentError("at least one isoflux constraint is required"))
        new(xp, iso, _freegs_finite(tikhonov_gamma, "tikhonov gamma"; positive=true))
    end
end
semantic_view(x::AxisymmetricShapeConstraintsV4) = (xpoints_m=x.xpoints_m,
    isoflux_m=x.isoflux_m, tikhonov_gamma=x.tikhonov_gamma)

struct AxisymmetricSolverControlsV4
    rtol::Float64
    atol::Float64
    max_iterations::Int
    function AxisymmetricSolverControlsV4(rtol, atol, max_iterations)
        r = _freegs_finite(rtol, "solver rtol"; positive=true)
        a = _freegs_finite(atol, "solver atol"; positive=true)
        r < 1 || throw(ArgumentError("solver rtol must be less than one"))
        a < 1 || throw(ArgumentError("solver atol must be less than one"))
        new(r, a, _freegs_integer(max_iterations, "solver max_iterations"; minimum=1))
    end
end
semantic_view(x::AxisymmetricSolverControlsV4) = (rtol=x.rtol, atol=x.atol,
    max_iterations=x.max_iterations)

function _freegs_declaration_body(declaration_id, domain, coils, profile, constraints, solver)
    (revision=_FREEGS_AXISYMMETRIC_REVISION,
     declaration_id=declaration_id,
     model=:axisymmetric_free_boundary_grad_shafranov,
     domain=domain,
     coils=coils,
     profile=profile,
     constraints=constraints,
     solver=solver)
end

"""Typed axisymmetric boundary/coils/profile declaration owned by G2 fields."""
struct AxisymmetricEquilibriumDeclarationV4
    declaration_id::String
    domain::AxisymmetricDomainV4
    coils::Tuple{Vararg{AxisymmetricFilamentCoilV4}}
    profile::AxisymmetricConstrainPaxisIpProfileV4
    constraints::AxisymmetricShapeConstraintsV4
    solver::AxisymmetricSolverControlsV4
    declaration_hash::Digest256
    function AxisymmetricEquilibriumDeclarationV4(declaration_id,
            domain::AxisymmetricDomainV4, coils,
            profile::AxisymmetricConstrainPaxisIpProfileV4,
            constraints::AxisymmetricShapeConstraintsV4,
            solver::AxisymmetricSolverControlsV4)
        coil_tuple = Tuple(coils)
        all(x -> x isa AxisymmetricFilamentCoilV4, coil_tuple) ||
            throw(ArgumentError("all coil declarations must be typed AxisymmetricFilamentCoilV4"))
        4 <= length(coil_tuple) <= 32 ||
            throw(ArgumentError("the bounded bridge requires 4 to 32 filament coils"))
        ids = Tuple(x.coil_id for x in coil_tuple)
        length(unique(ids)) == length(ids) || throw(ArgumentError("coil IDs must be unique"))
        id = _freegs_text(declaration_id, "declaration_id")
        body = _freegs_declaration_body(id, domain, coil_tuple, profile, constraints, solver)
        is_canonical_value(body) || throw(ArgumentError("axisymmetric declaration is not canonicalizable"))
        new(id, domain, coil_tuple, profile, constraints, solver, canonical_hash(body))
    end
end

function _validate_freegs_declaration(x::AxisymmetricEquilibriumDeclarationV4)
    expected = canonical_hash(_freegs_declaration_body(x.declaration_id, x.domain,
        x.coils, x.profile, x.constraints, x.solver))
    x.declaration_hash == expected || throw(ArgumentError("axisymmetric declaration hash mismatch"))
    expected
end
canonical_hash(x::AxisymmetricEquilibriumDeclarationV4) = _validate_freegs_declaration(x)
semantic_view(x::AxisymmetricEquilibriumDeclarationV4) = (
    declaration_id=x.declaration_id, model=:axisymmetric_free_boundary_grad_shafranov,
    domain=x.domain, coils=x.coils, profile=x.profile, constraints=x.constraints,
    solver=x.solver, declaration_hash=x.declaration_hash)

function _freegs_binding_body(declaration_hash, field_geometry_genome_hash,
        field_geometry_graph_hash, field_geometry_graph_binding_hash, mission_hash,
        bounds_hash, scenario_hash)
    (revision=_FREEGS_AXISYMMETRIC_REVISION,
     binding_kind=:axisymmetric_equilibrium_subject_binding,
     declaration_hash=declaration_hash,
     field_geometry_genome_hash=field_geometry_genome_hash,
     field_geometry_graph_hash=field_geometry_graph_hash,
     field_geometry_graph_binding_hash=field_geometry_graph_binding_hash,
     mission_hash=mission_hash,
     bounds_hash=bounds_hash,
     scenario_hash=scenario_hash)
end

"""Subject binding sealed to one current G2 graph, mission, bounds, and scenario."""
struct AxisymmetricEquilibriumBindingV4
    declaration::AxisymmetricEquilibriumDeclarationV4
    field_geometry_genome_hash::Digest256
    field_geometry_graph_hash::Digest256
    field_geometry_graph_binding_hash::Digest256
    mission_hash::Digest256
    bounds_hash::Digest256
    scenario_hash::Digest256
    binding_hash::Digest256
    function AxisymmetricEquilibriumBindingV4(token::_FreeGSAxisymmetricToken,
            declaration::AxisymmetricEquilibriumDeclarationV4,
            field_geometry_genome_hash::Digest256, field_geometry_graph_hash::Digest256,
            field_geometry_graph_binding_hash::Digest256, mission_hash::Digest256,
            bounds_hash::Digest256, scenario_hash::Digest256, binding_hash::Digest256)
        token === _FREEGS_AXISYMMETRIC_TOKEN || throw(ArgumentError("private constructor"))
        new(declaration, field_geometry_genome_hash, field_geometry_graph_hash,
            field_geometry_graph_binding_hash, mission_hash, bounds_hash,
            scenario_hash, binding_hash)
    end
end

function _validate_freegs_binding_hash(binding::AxisymmetricEquilibriumBindingV4)
    declaration_hash = canonical_hash(binding.declaration)
    expected = canonical_hash(_freegs_binding_body(declaration_hash,
        binding.field_geometry_genome_hash, binding.field_geometry_graph_hash,
        binding.field_geometry_graph_binding_hash, binding.mission_hash,
        binding.bounds_hash, binding.scenario_hash))
    binding.binding_hash == expected || throw(ArgumentError("axisymmetric subject binding hash mismatch"))
    expected
end
canonical_hash(x::AxisymmetricEquilibriumBindingV4) = _validate_freegs_binding_hash(x)
semantic_view(x::AxisymmetricEquilibriumBindingV4) = (
    binding_kind=:axisymmetric_equilibrium_subject_binding,
    declaration_hash=canonical_hash(x.declaration),
    field_geometry_genome_hash=x.field_geometry_genome_hash,
    field_geometry_graph_hash=x.field_geometry_graph_hash,
    field_geometry_graph_binding_hash=x.field_geometry_graph_binding_hash,
    mission_hash=x.mission_hash, bounds_hash=x.bounds_hash,
    scenario_hash=x.scenario_hash, binding_hash=x.binding_hash)

function _freegs_owned_declaration(candidate, declaration)
    fields = candidate.field_geometry_genome_ref.fields
    matches = Tuple(field for field in fields
        if field isa AxisymmetricEquilibriumDeclarationV4 &&
           canonical_hash(field) == canonical_hash(declaration))
    length(matches) == 1 ||
        throw(ArgumentError("typed axisymmetric declaration is absent from or ambiguous in current G2 fields"))
    only(matches)
end

"""Seal one G2-owned declaration before constructing the physical subject."""
function make_axisymmetric_equilibrium_binding(compiled::CompiledCandidatePrefixV4,
        registry::GenomeContractRegistryV4, mission_payload, bounds_payload,
        comparison_scope, scenario_scope, scenario,
        declaration::AxisymmetricEquilibriumDeclarationV4)
    _runtime_validate_compiled_prefix(compiled, compiled.candidate, registry,
        mission_payload, bounds_payload, _runtime_axis_tuple(comparison_scope, "comparison_scope"),
        _runtime_axis_tuple(scenario_scope, "scenario_scope"))
    _freegs_owned_declaration(compiled.candidate, declaration)
    is_canonical_value(scenario) || throw(ArgumentError("binding scenario is not canonicalizable"))
    scenario_hash = canonical_hash(scenario)
    _forward_scenario_name(scenario) in Tuple(scenario_scope) ||
        throw(ArgumentError("binding scenario is outside frozen scenario scope"))
    graph = _make_forward_graph_binding(:field_geometry, compiled.field_geometry_graph)
    genome_hash = field_geometry_hash(compiled.candidate.field_geometry_genome_ref)
    graph_hash = canonical_hash(compiled.field_geometry_graph)
    mission_hash = _runtime_decl_hash(mission_payload)
    bounds_hash = _runtime_decl_hash(bounds_payload)
    body = _freegs_binding_body(canonical_hash(declaration), genome_hash, graph_hash,
        canonical_hash(graph), mission_hash, bounds_hash, scenario_hash)
    AxisymmetricEquilibriumBindingV4(_FREEGS_AXISYMMETRIC_TOKEN, declaration,
        genome_hash, graph_hash, canonical_hash(graph), mission_hash, bounds_hash,
        scenario_hash, canonical_hash(body))
end

function _freegs_context_binding(context::ForwardChainContextV4)
    validate_forward_chain_context(context)
    bindings = Tuple(binding for binding in context.subject.bindings
        if binding isa AxisymmetricEquilibriumBindingV4)
    length(bindings) == 1 ||
        throw(ArgumentError("physical subject must contain exactly one typed axisymmetric binding"))
    binding = only(bindings)
    _validate_freegs_binding_hash(binding)
    _freegs_owned_declaration(context.candidate, binding.declaration)
    field_graph = forward_graph_binding(context, :field_geometry)
    binding.field_geometry_genome_hash == field_geometry_hash(context.candidate.field_geometry_genome_ref) ||
        throw(ArgumentError("axisymmetric binding G2 Genome hash mismatch"))
    binding.field_geometry_graph_hash == canonical_hash(context.compiled.field_geometry_graph) ||
        throw(ArgumentError("axisymmetric binding G2 graph hash mismatch"))
    binding.field_geometry_graph_binding_hash == canonical_hash(field_graph) ||
        throw(ArgumentError("axisymmetric binding G2 graph identity mismatch"))
    binding.mission_hash == _runtime_decl_hash(context.mission_payload) ||
        throw(ArgumentError("axisymmetric binding mission mismatch"))
    binding.bounds_hash == _runtime_decl_hash(context.bounds_payload) ||
        throw(ArgumentError("axisymmetric binding bounds mismatch"))
    binding.scenario_hash == context.scenario_hash ||
        throw(ArgumentError("axisymmetric binding scenario mismatch"))
    binding
end

function _freegs_solver_payload(binding::AxisymmetricEquilibriumBindingV4)
    d = binding.declaration
    (machine=(kind="explicit_filament_coils",
              coils=Tuple((id=c.coil_id, major_radius_m=c.major_radius_m,
                           vertical_position_m=c.vertical_position_m) for c in d.coils)),
     domain=(r_min_m=d.domain.r_min_m, r_max_m=d.domain.r_max_m,
             z_min_m=d.domain.z_min_m, z_max_m=d.domain.z_max_m,
             nx=d.domain.nx, ny=d.domain.ny, boundary="freeBoundaryHagenow"),
     profile=(kind="ConstrainPaxisIp", axis_pressure_pa=d.profile.axis_pressure_pa,
              plasma_current_a=d.profile.plasma_current_a,
              vacuum_f_tm=d.profile.vacuum_f_tm, alpha_m=d.profile.alpha_m,
              alpha_n=d.profile.alpha_n,
              profile_axis_radius_m=d.profile.profile_axis_radius_m),
     constraints=(xpoints_m=d.constraints.xpoints_m,
                  isoflux_m=d.constraints.isoflux_m,
                  gamma=d.constraints.tikhonov_gamma),
     solver=(rtol=d.solver.rtol, atol=d.solver.atol,
             max_iterations=d.solver.max_iterations))
end

"""Create the canonical JSON ABI solely from the revalidated subject binding."""
function freegs_axisymmetric_solver_input(context::ForwardChainContextV4)
    validate_forward_chain_context(context)
    binding = _freegs_context_binding(context)
    (schema="fusionconceptai:runtime-v4-freegs-axisymmetric-input",
     revision=_FREEGS_AXISYMMETRIC_REVISION,
     context_hash=string(context.context_hash),
     candidate_hash=string(context.candidate_hash),
     compiled_prefix_hash=string(context.compiled.prefix_hash),
     physical_subject_hash=string(context.subject.physical_subject_hash),
     scenario_hash=string(context.scenario_hash),
     field_geometry_genome_hash=string(binding.field_geometry_genome_hash),
     field_geometry_graph_hash=string(binding.field_geometry_graph_hash),
     field_geometry_graph_binding_hash=string(binding.field_geometry_graph_binding_hash),
     binding_hash=string(binding.binding_hash),
     declaration_hash=string(canonical_hash(binding.declaration)),
     solver_input=_freegs_solver_payload(binding))
end

struct FreeGSPhysicalModelSummaryV4
    iterations::Int
    final_relative_change::Float64
    plasma_residual_l2_relative::Float64
    plasma_residual_linf_relative::Float64
    magnetic_axis_r_m::Float64
    magnetic_axis_z_m::Float64
    plasma_current_a::Float64
    plasma_volume_m3::Float64
    minor_radius_m::Float64
    elongation::Float64
    q_95::Float64
    beta_n::Float64
    xpoint_field_residual_max_t::Float64
    isoflux_residual_relative_max::Float64
end
semantic_view(x::FreeGSPhysicalModelSummaryV4) = (
    iterations=x.iterations, final_relative_change=x.final_relative_change,
    plasma_residual_l2_relative=x.plasma_residual_l2_relative,
    plasma_residual_linf_relative=x.plasma_residual_linf_relative,
    magnetic_axis_r_m=x.magnetic_axis_r_m, magnetic_axis_z_m=x.magnetic_axis_z_m,
    plasma_current_a=x.plasma_current_a, plasma_volume_m3=x.plasma_volume_m3,
    minor_radius_m=x.minor_radius_m, elongation=x.elongation, q_95=x.q_95,
    beta_n=x.beta_n, xpoint_field_residual_max_t=x.xpoint_field_residual_max_t,
    isoflux_residual_relative_max=x.isoflux_residual_relative_max)

function _freegs_summary(values::Vector{SubString{String}})
    length(values) == 14 || throw(ArgumentError("controlled runner summary metric count mismatch"))
    parsed = Tuple(parse(Float64, value) for value in values[2:end])
    all(isfinite, parsed) || throw(ArgumentError("controlled runner emitted non-finite metrics"))
    FreeGSPhysicalModelSummaryV4(parse(Int, values[1]), parsed...)
end

function _freegs_receipt_body(status, context_hash, physical_subject_hash, scenario_hash,
        binding_hash, interpreter_path, interpreter_hash, runner_path, runner_code_hash,
        freegs_version, environment_hash, input_hash, backend_input_hash, output_hash,
        backend_result_hash, stdout, stderr, exit_code, summary, gap_kind, reason)
    (revision=_FREEGS_AXISYMMETRIC_REVISION, status=status,
     context_hash=context_hash, physical_subject_hash=physical_subject_hash,
     scenario_hash=scenario_hash, binding_hash=binding_hash,
     interpreter_path=interpreter_path, interpreter_hash=interpreter_hash,
     runner_path=runner_path, runner_code_hash=runner_code_hash,
     freegs_version=freegs_version, environment_hash=environment_hash,
     input_hash=input_hash, backend_input_hash=backend_input_hash,
     output_hash=output_hash, backend_result_hash=backend_result_hash,
     stdout=stdout, stderr=stderr, exit_code=exit_code, summary=summary,
     gap_kind=gap_kind, reason=reason, claim_ceiling=screen_only,
     physical_validation=false, engineering_validation=false,
     p5_ready=false, terminal_authority=false)
end

struct FreeGSAxisymmetricExecutionReceiptV4
    status::Symbol
    context_hash::Digest256
    physical_subject_hash::Digest256
    scenario_hash::Digest256
    binding_hash::Digest256
    interpreter_path::String
    interpreter_hash::Digest256
    runner_path::String
    runner_code_hash::Digest256
    freegs_version::String
    environment_hash::Digest256
    input_hash::Digest256
    backend_input_hash::Digest256
    output_hash::Digest256
    backend_result_hash::Digest256
    stdout::String
    stderr::String
    exit_code::Int
    summary::Union{Nothing,FreeGSPhysicalModelSummaryV4}
    gap_kind::Symbol
    reason::String
    claim_ceiling::ClaimCeiling
    physical_validation::Bool
    engineering_validation::Bool
    p5_ready::Bool
    terminal_authority::Bool
    receipt_hash::Digest256
    function FreeGSAxisymmetricExecutionReceiptV4(token::_FreeGSAxisymmetricToken,
            status, context_hash, physical_subject_hash, scenario_hash, binding_hash,
            interpreter_path, interpreter_hash, runner_path, runner_code_hash,
            freegs_version, environment_hash, input_hash, backend_input_hash,
            output_hash, backend_result_hash, stdout, stderr, exit_code, summary,
            gap_kind, reason)
        token === _FREEGS_AXISYMMETRIC_TOKEN || throw(ArgumentError("private constructor"))
        body = _freegs_receipt_body(status, context_hash, physical_subject_hash,
            scenario_hash, binding_hash, interpreter_path, interpreter_hash,
            runner_path, runner_code_hash, freegs_version, environment_hash,
            input_hash, backend_input_hash, output_hash, backend_result_hash,
            stdout, stderr, exit_code, summary, gap_kind, reason)
        new(status, context_hash, physical_subject_hash, scenario_hash, binding_hash,
            interpreter_path, interpreter_hash, runner_path, runner_code_hash,
            freegs_version, environment_hash, input_hash, backend_input_hash,
            output_hash, backend_result_hash, stdout, stderr, exit_code, summary,
            gap_kind, reason, screen_only, false, false, false, false,
            canonical_hash(body))
    end
end

semantic_view(x::FreeGSAxisymmetricExecutionReceiptV4) = merge(
    _freegs_receipt_body(x.status, x.context_hash, x.physical_subject_hash,
        x.scenario_hash, x.binding_hash, x.interpreter_path, x.interpreter_hash,
        x.runner_path, x.runner_code_hash, x.freegs_version, x.environment_hash,
        x.input_hash, x.backend_input_hash, x.output_hash, x.backend_result_hash,
        x.stdout, x.stderr, x.exit_code, x.summary, x.gap_kind, x.reason),
    (receipt_hash=x.receipt_hash,))

struct FreeGSAxisymmetricExecutionArtifactsV4
    receipt::FreeGSAxisymmetricExecutionReceiptV4
    input_json::String
    output_json::String
end

_freegs_sha256_bytes(bytes) = Digest256(bytes2hex(SHA.sha256(bytes)))
_freegs_sha256_text(text::String) = _freegs_sha256_bytes(Vector{UInt8}(codeunits(text)))
_freegs_sha256_file(path::String) = _freegs_sha256_bytes(read(path))

function _freegs_make_receipt(context, binding; status=:recoverable_gap_unknown,
        interpreter_hash=_FREEGS_UNKNOWN_HASH, runner_code_hash=_FREEGS_UNKNOWN_HASH,
        freegs_version="unknown", environment_hash=_FREEGS_UNKNOWN_HASH,
        input_hash=_FREEGS_UNKNOWN_HASH, backend_input_hash=_FREEGS_UNKNOWN_HASH,
        output_hash=_FREEGS_UNKNOWN_HASH, backend_result_hash=_FREEGS_UNKNOWN_HASH,
        stdout="", stderr="", exit_code=-1, summary=nothing,
        gap_kind=:execution_unavailable, reason="recoverable execution gap")
    FreeGSAxisymmetricExecutionReceiptV4(_FREEGS_AXISYMMETRIC_TOKEN, status,
        context.context_hash, context.subject.physical_subject_hash,
        context.scenario_hash, binding.binding_hash, _FREEGS_PINNED_PYTHON,
        interpreter_hash, _FREEGS_CONTROLLED_RUNNER, runner_code_hash,
        freegs_version, environment_hash, input_hash, backend_input_hash,
        output_hash, backend_result_hash, String(stdout), String(stderr),
        Int(exit_code), summary, gap_kind, String(reason))
end

function _freegs_parse_summary(stdout::String, context, binding, output_json::String)
    lines = filter(line -> startswith(line, "FUSION_FREEGS_V4\t"), split(stdout, '\n'))
    length(lines) == 1 || throw(ArgumentError("controlled runner emitted missing or ambiguous summary"))
    parts = split(only(lines), '\t'; keepempty=true)
    length(parts) == 24 || throw(ArgumentError("controlled runner summary field count mismatch"))
    parts[6] == string(context.context_hash) || throw(ArgumentError("runner context echo mismatch"))
    parts[7] == string(binding.binding_hash) || throw(ArgumentError("runner binding echo mismatch"))
    status = Symbol(parts[2])
    freegs_version = isempty(parts[3]) ? "unknown" : String(parts[3])
    environment_hash = isempty(parts[4]) ? _FREEGS_UNKNOWN_HASH : Digest256(parts[4])
    result_hash = isempty(parts[5]) ? _FREEGS_UNKNOWN_HASH : Digest256(parts[5])
    backend_input_hash = isempty(parts[8]) ? _FREEGS_UNKNOWN_HASH : Digest256(parts[8])
    emitted_output_hash = isempty(parts[23]) ? _FREEGS_UNKNOWN_HASH : Digest256(parts[23])
    emitted_output_hash == _freegs_sha256_text(output_json) ||
        throw(ArgumentError("controlled runner stdout/output byte hash mismatch"))
    if status === :physical_model_screen
        summary = _freegs_summary(parts[9:22])
        return (status=status, freegs_version=freegs_version,
            environment_hash=environment_hash, result_hash=result_hash,
            backend_input_hash=backend_input_hash, summary=summary,
            gap_kind=:none, reason="executed FreeGS physical-model screen")
    elseif status === :recoverable_gap_unknown
        return (status=status, freegs_version=freegs_version,
            environment_hash=environment_hash, result_hash=result_hash,
            backend_input_hash=backend_input_hash, summary=nothing,
            gap_kind=Symbol(isempty(parts[24]) ? "backend_execution_gap" : parts[24]),
            reason="controlled runner reported a recoverable unknown gap")
    end
    throw(ArgumentError("controlled runner emitted an unauthorized status"))
end

function _freegs_write_artifacts(directory::String, input_json::String,
        output_json::String, receipt::FreeGSAxisymmetricExecutionReceiptV4)
    absolute = abspath(directory)
    mkpath(absolute)
    write(joinpath(absolute, "solver_input.canonical.json"), input_json)
    write(joinpath(absolute, "solver_output.json"), output_json)
    write(joinpath(absolute, "execution_receipt.canonical.json"),
        canonical_json(receipt) * "\n")
    absolute
end

"""Run the pinned local FreeGS interpreter; all infrastructure failures stay unknown."""
function execute_freegs_axisymmetric_screen(context::ForwardChainContextV4;
        artifact_directory::Union{Nothing,AbstractString}=nothing)
    validate_forward_chain_context(context)
    binding = _freegs_context_binding(context)
    solver_input = freegs_axisymmetric_solver_input(context)
    input_json = canonical_json(solver_input) * "\n"
    input_hash = _freegs_sha256_text(input_json)
    runner_hash = isfile(_FREEGS_CONTROLLED_RUNNER) ?
        _freegs_sha256_file(_FREEGS_CONTROLLED_RUNNER) : _FREEGS_UNKNOWN_HASH
    interpreter_hash = isfile(_FREEGS_PINNED_PYTHON) ?
        _freegs_sha256_file(_FREEGS_PINNED_PYTHON) : _FREEGS_UNKNOWN_HASH

    if !isfile(_FREEGS_CONTROLLED_RUNNER) || !isfile(_FREEGS_PINNED_PYTHON)
        receipt = _freegs_make_receipt(context, binding;
            interpreter_hash=interpreter_hash, runner_code_hash=runner_hash,
            input_hash=input_hash, gap_kind=:dependency_unavailable,
            reason="pinned interpreter or controlled runner is unavailable")
        artifact_directory === nothing || _freegs_write_artifacts(
            String(artifact_directory), input_json, "", receipt)
        return FreeGSAxisymmetricExecutionArtifactsV4(receipt, input_json, "")
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
        command = `$_FREEGS_PINNED_PYTHON $_FREEGS_CONTROLLED_RUNNER --input $input_path --output $output_path`
        try
            process = open(stdout_path, "w") do stdout_io
                open(stderr_path, "w") do stderr_io
                    run(pipeline(ignorestatus(command), stdout=stdout_io, stderr=stderr_io))
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
                parsed = _freegs_parse_summary(stdout, context, binding, output_json)
            catch error
                execution_error = error
            end
        end
    end

    output_hash = isempty(output_json) ? _FREEGS_UNKNOWN_HASH : _freegs_sha256_text(output_json)
    receipt = if execution_error === nothing && exit_code == 0 &&
            parsed.status === :physical_model_screen
        _freegs_make_receipt(context, binding; status=:physical_model_screen,
            interpreter_hash=interpreter_hash, runner_code_hash=runner_hash,
            freegs_version=parsed.freegs_version,
            environment_hash=parsed.environment_hash, input_hash=input_hash,
            backend_input_hash=parsed.backend_input_hash, output_hash=output_hash,
            backend_result_hash=parsed.result_hash, stdout=stdout, stderr=stderr,
            exit_code=exit_code, summary=parsed.summary, gap_kind=:none,
            reason=parsed.reason)
    else
        kind = execution_error === nothing && parsed !== nothing ? parsed.gap_kind :
            exit_code == 0 ? :malformed_backend_output : :backend_process_failure
        reason = execution_error === nothing ?
            "FreeGS execution remained a recoverable unknown gap" :
            "FreeGS execution artifact could not be accepted: $(typeof(execution_error))"
        _freegs_make_receipt(context, binding;
            interpreter_hash=interpreter_hash, runner_code_hash=runner_hash,
            freegs_version=parsed === nothing ? "unknown" : parsed.freegs_version,
            environment_hash=parsed === nothing ? _FREEGS_UNKNOWN_HASH : parsed.environment_hash,
            input_hash=input_hash,
            backend_input_hash=parsed === nothing ? _FREEGS_UNKNOWN_HASH : parsed.backend_input_hash,
            output_hash=output_hash,
            backend_result_hash=parsed === nothing ? _FREEGS_UNKNOWN_HASH : parsed.result_hash,
            stdout=stdout, stderr=stderr, exit_code=exit_code, summary=nothing,
            gap_kind=kind, reason=reason)
    end
    validate_freegs_axisymmetric_receipt(context, receipt)
    artifact_directory === nothing || _freegs_write_artifacts(
        String(artifact_directory), input_json, output_json, receipt)
    FreeGSAxisymmetricExecutionArtifactsV4(receipt, input_json, output_json)
end

"""Externally revalidate the context and every receipt identity and claim boundary."""
function validate_freegs_axisymmetric_receipt(context::ForwardChainContextV4,
        receipt::FreeGSAxisymmetricExecutionReceiptV4)
    validate_forward_chain_context(context)
    binding = _freegs_context_binding(context)
    receipt.context_hash == context.context_hash || throw(ArgumentError("FreeGS receipt context mismatch"))
    receipt.physical_subject_hash == context.subject.physical_subject_hash || throw(ArgumentError("FreeGS receipt subject mismatch"))
    receipt.scenario_hash == context.scenario_hash || throw(ArgumentError("FreeGS receipt scenario mismatch"))
    receipt.binding_hash == binding.binding_hash || throw(ArgumentError("FreeGS receipt binding mismatch"))
    receipt.interpreter_path == _FREEGS_PINNED_PYTHON || throw(ArgumentError("FreeGS receipt interpreter path mismatch"))
    receipt.runner_path == _FREEGS_CONTROLLED_RUNNER || throw(ArgumentError("FreeGS receipt runner path mismatch"))
    receipt.claim_ceiling == screen_only || throw(ArgumentError("FreeGS receipt exceeded screen_only"))
    !receipt.physical_validation && !receipt.engineering_validation && !receipt.p5_ready &&
        !receipt.terminal_authority || throw(ArgumentError("FreeGS receipt contains unauthorized authority"))
    receipt.status in (:physical_model_screen, :recoverable_gap_unknown) ||
        throw(ArgumentError("FreeGS receipt status is not closed"))
    if receipt.status === :physical_model_screen
        receipt.exit_code == 0 && receipt.summary !== nothing && receipt.gap_kind === :none ||
            throw(ArgumentError("successful FreeGS screen is internally inconsistent"))
        isfile(_FREEGS_PINNED_PYTHON) &&
            receipt.interpreter_hash == _freegs_sha256_file(_FREEGS_PINNED_PYTHON) ||
            throw(ArgumentError("pinned FreeGS interpreter hash mismatch"))
        isfile(_FREEGS_CONTROLLED_RUNNER) &&
            receipt.runner_code_hash == _freegs_sha256_file(_FREEGS_CONTROLLED_RUNNER) ||
            throw(ArgumentError("controlled FreeGS runner hash mismatch"))
    else
        receipt.summary === nothing || throw(ArgumentError("unknown FreeGS gap cannot carry solver metrics"))
        receipt.gap_kind !== :none || throw(ArgumentError("unknown FreeGS gap must remain explicit"))
    end
    body = _freegs_receipt_body(receipt.status, receipt.context_hash,
        receipt.physical_subject_hash, receipt.scenario_hash, receipt.binding_hash,
        receipt.interpreter_path, receipt.interpreter_hash, receipt.runner_path,
        receipt.runner_code_hash, receipt.freegs_version, receipt.environment_hash,
        receipt.input_hash, receipt.backend_input_hash, receipt.output_hash,
        receipt.backend_result_hash, receipt.stdout, receipt.stderr,
        receipt.exit_code, receipt.summary, receipt.gap_kind, receipt.reason)
    expected = canonical_hash(body)
    receipt.receipt_hash == expected || throw(ArgumentError("FreeGS receipt hash mismatch"))
    expected
end

canonical_hash(x::FreeGSAxisymmetricExecutionReceiptV4) = x.receipt_hash

freegs_axisymmetric_execution_manifest() = (
    schema="fusionconceptai:runtime-v4-freegs-axisymmetric-execution",
    revision=_FREEGS_AXISYMMETRIC_REVISION,
    interpreter_path=_FREEGS_PINNED_PYTHON,
    runner_path=_FREEGS_CONTROLLED_RUNNER,
    source_binding=:context_subject_typed_axisymmetric_binding,
    outcomes=(:physical_model_screen, :recoverable_gap_unknown),
    claim_ceiling=screen_only,
    physical_validation=false,
    engineering_validation=false,
    p5_ready=false,
    terminal_authority=false)
