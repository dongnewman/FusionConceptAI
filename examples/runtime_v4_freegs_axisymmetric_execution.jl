"""Current Runtime V4 candidate fixture for the isolated FreeGS bridge.

The numerical declaration is a typed G2 field value.  The subject carries a
separately sealed binding to that declaration, the exact current G2 graph,
mission, bounds, and one frozen scenario.  This is a manufactured software
integration fixture, not experimental or engineering validation.
"""

using FusionConceptAI

module FreeGSAxisymmetricRuntime
using FusionConceptAI
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "Contracts.jl"))
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "Compiler.jl"))
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "ForwardChainContext.jl"))
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "FreeGSAxisymmetricExecution.jl"))
end

include(joinpath(@__DIR__, "runtime_v4_declared_fixture.jl"))

const freegs_axisymmetric_declaration =
    FreeGSAxisymmetricRuntime.AxisymmetricEquilibriumDeclarationV4(
        "current-runtime-v4-freegs-axisymmetric-fixture",
        FreeGSAxisymmetricRuntime.AxisymmetricDomainV4(0.1, 2.0, -1.0, 1.0, 65, 65),
        (FreeGSAxisymmetricRuntime.AxisymmetricFilamentCoilV4("pf-lower-inner", 1.0, -1.1),
         FreeGSAxisymmetricRuntime.AxisymmetricFilamentCoilV4("pf-upper-inner", 1.0, 1.1),
         FreeGSAxisymmetricRuntime.AxisymmetricFilamentCoilV4("pf-lower-outer", 1.75, -0.6),
         FreeGSAxisymmetricRuntime.AxisymmetricFilamentCoilV4("pf-upper-outer", 1.75, 0.6)),
        FreeGSAxisymmetricRuntime.AxisymmetricConstrainPaxisIpProfileV4(
            10_000.0, 1_000_000.0, 1.0, 1.0, 2.0, 1.0),
        FreeGSAxisymmetricRuntime.AxisymmetricShapeConstraintsV4(
            ((1.1, -0.6), (1.1, 0.8)), ((1.1, -0.6, 1.1, 0.6),), 1.0e-12),
        FreeGSAxisymmetricRuntime.AxisymmetricSolverControlsV4(1.0e-4, 1.0e-10, 100))

const freegs_field_genome = FieldGeometryGenomeV4(20260910, _fixture_refs[2],
    _fixture_graph(); fields=(freegs_axisymmetric_declaration,))
const freegs_candidate = CandidateStatePackageV4(
    "runtime-v4-freegs-axisymmetric-current-fixture", _fixture_mission,
    _fixture_mechanism, freegs_field_genome, _fixture_realization, registry)
const freegs_mission_payload = (
    mission_id="current-runtime-v4-axisymmetric-equilibrium-screen",
    model_scope="static-axisymmetric-free-boundary-grad-shafranov",
    contract=freegs_candidate.mission_contract_ref)
const freegs_bounds_payload = (
    declaration_hash=canonical_hash(freegs_axisymmetric_declaration),
    model="FreeGS-0.8.2-explicit-filament-bounded-subset",
    maximum_grid_points_per_axis=257)
const freegs_comparison_scope = ("single-current-candidate-physical-model-screen",)
const freegs_scenario = (name="nominal-static-equilibrium", load_case="manufactured-integration-fixture")
const freegs_scenario_scope = (freegs_scenario.name,)
const freegs_compiled = FreeGSAxisymmetricRuntime.compile_candidate(
    freegs_candidate, registry; mission_payload=freegs_mission_payload,
    bounds_payload=freegs_bounds_payload, comparison_scope=freegs_comparison_scope,
    scenario_scope=freegs_scenario_scope)
const freegs_subject_binding =
    FreeGSAxisymmetricRuntime.make_axisymmetric_equilibrium_binding(
        freegs_compiled, registry, freegs_mission_payload, freegs_bounds_payload,
        freegs_comparison_scope, freegs_scenario_scope, freegs_scenario,
        freegs_axisymmetric_declaration)
const freegs_subject = FreeGSAxisymmetricRuntime.ExecutablePhysicalSubjectV4(
    freegs_compiled.prefix_hash,
    freegs_candidate.canonical_hashes.genome_bundle_hash,
    freegs_compiled.minimality_scope.mission_hash,
    freegs_compiled.minimality_scope.bounds_hash,
    (freegs_subject_binding,), (freegs_scenario,),
    (materialization="typed-current-freegs-fixture",
     declaration_hash=canonical_hash(freegs_axisymmetric_declaration)),
    FreeGSAxisymmetricRuntime.derive_capability_obligations(freegs_compiled))
const freegs_context = FreeGSAxisymmetricRuntime.make_forward_chain_context(
    freegs_candidate, freegs_compiled, registry, freegs_mission_payload,
    freegs_bounds_payload, freegs_comparison_scope, freegs_scenario_scope,
    freegs_subject, freegs_scenario)

if abspath(PROGRAM_FILE) == @__FILE__
    input = FreeGSAxisymmetricRuntime.freegs_axisymmetric_solver_input(freegs_context)
    println("context_hash=", freegs_context.context_hash)
    println("subject_hash=", freegs_subject.physical_subject_hash)
    println("g2_graph_hash=", freegs_subject_binding.field_geometry_graph_hash)
    println("binding_hash=", freegs_subject_binding.binding_hash)
    println("input_hash=", canonical_hash(input))
    println("claim_ceiling=screen_only")
end
