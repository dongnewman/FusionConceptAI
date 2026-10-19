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

const freegs_base_axisymmetric_declaration =
    FreeGSAxisymmetricRuntime.AxisymmetricEquilibriumDeclarationV4(
        "current-runtime-v4-freegs-axisymmetric-fixture",
        FreeGSAxisymmetricRuntime.AxisymmetricDomainV4(0.1, 2.0, -1.0, 1.0, 129, 129),
        (FreeGSAxisymmetricRuntime.AxisymmetricFilamentCoilV4("pf-lower-inner", 1.0, -1.1),
         FreeGSAxisymmetricRuntime.AxisymmetricFilamentCoilV4("pf-upper-inner", 1.0, 1.1),
         FreeGSAxisymmetricRuntime.AxisymmetricFilamentCoilV4("pf-lower-outer", 1.75, -0.6),
         FreeGSAxisymmetricRuntime.AxisymmetricFilamentCoilV4("pf-upper-outer", 1.75, 0.6)),
        FreeGSAxisymmetricRuntime.AxisymmetricConstrainPaxisIpProfileV4(
            10_000.0, 1_000_000.0, 1.0, 1.0, 2.0, 1.0),
        FreeGSAxisymmetricRuntime.AxisymmetricShapeConstraintsV4(
            ((1.1, -0.6), (1.1, 0.8)), ((1.1, -0.6, 1.1, 0.6),), 1.0e-12),
        FreeGSAxisymmetricRuntime.AxisymmetricSolverControlsV4(1.0e-4, 1.0e-10, 100))

# Explicit MMS-only geometry producer for the map API. It declares four distinct
# G2 boundary patches and 516 oriented incidences; it does not identify the LCFS
# or grant any experimental/engineering outer-boundary interpretation.
const freegs_mms_outer_face_map_mode = get(ENV,"FUSION_FREEGS_MMS_OUTER_FACE_MAP","0")=="1"
const freegs_q1_exterior_green_mode = get(ENV,"FUSION_FREEGS_Q1_EXTERIOR_GREEN","0")=="1"
const freegs_mms_outer_face_node_ids = ("freegs-mms-g2-outer-Rmin-v1",
    "freegs-mms-g2-outer-Rmax-v1","freegs-mms-g2-outer-Zmin-v1",
    "freegs-mms-g2-outer-Zmax-v1")
const freegs_authored_mode = get(ENV,"FUSION_FREEGS_AUTHORED_SOURCES","0")=="1"
const freegs_pressure_domain_mode = get(ENV,"FUSION_FREEGS_PRESSURE_DOMAIN","0")=="1"
const freegs_ideal_periodic_mode_raw=get(ENV,"FUSION_FREEGS_IDEAL_PERIODIC_PLASMA","0")
freegs_ideal_periodic_mode_raw in ("0","1") ||
    throw(ArgumentError("FUSION_FREEGS_IDEAL_PERIODIC_PLASMA must be 0 or 1"))
const freegs_ideal_periodic_mode=freegs_ideal_periodic_mode_raw=="1"
freegs_ideal_periodic_mode && !(freegs_authored_mode && freegs_pressure_domain_mode) &&
    throw(ArgumentError("ideal periodic plasma requires authored sources and the LCFS pressure domain"))
const freegs_stationary_critical_mode =
    get(ENV,"FUSION_FREEGS_STATIONARY_CRITICAL_POINTS","0")=="1"
freegs_q1_exterior_green_mode && !(freegs_authored_mode && freegs_mms_outer_face_map_mode) &&
    throw(ArgumentError("Q1 exterior model requires the authored sources and explicit G2 map fixture"))
freegs_pressure_domain_mode && !freegs_authored_mode &&
    throw(ArgumentError("pressure-domain candidate requires the existing authored G1/G3 fixture mode"))
freegs_stationary_critical_mode && !freegs_authored_mode &&
    throw(ArgumentError("stationary-critical candidate requires the authored G1/G3 fixture mode"))
const freegs_pressure_domain = freegs_pressure_domain_mode ?
    FreeGSAxisymmetricRuntime.AxisymmetricPressureDomainV1(
        FreeGSAxisymmetricRuntime._FREEGS_PLASMA_REGION_NODE,
        FreeGSAxisymmetricRuntime._FREEGS_VACUUM_REGION_NODE,
        FreeGSAxisymmetricRuntime._FREEGS_PRESSURE_LCFS_INTERFACE_NODE,
        FreeGSAxisymmetricRuntime._FREEGS_LCFS_NODE,0.0,
        :receipt_bound_native_flux_connected_core_mask,
        :exterior_vacuum_even_when_psi_n_below_one) : nothing
const freegs_authored_genomes = freegs_authored_mode ?
    FreeGSAxisymmetricRuntime.build_freegs_authored_source_genomes(_fixture_mechanism,
        _fixture_realization,freegs_base_axisymmetric_declaration.domain;
        pressure_domain=freegs_pressure_domain) : nothing
# Build the exact G2 graph before creating the map: the map is sealed to this hash.
const freegs_source_field_graph = begin
    base_graph = if freegs_authored_mode
        base=_fixture_graph()
        boundary_node=node(:boundary,FreeGSAxisymmetricRuntime._freegs_source_type(
            FreeGSAxisymmetricRuntime._FREEGS_SOURCE_UNITS.length;rank=1);
            id=FreeGSAxisymmetricRuntime._FREEGS_LCFS_NODE)
        if freegs_pressure_domain_mode
            pressure_type=FreeGSAxisymmetricRuntime._freegs_source_type(
                FreeGSAxisymmetricRuntime._FREEGS_SOURCE_UNITS.pressure)
            interface_type=FreeGSAxisymmetricRuntime._freegs_source_type(
                FreeGSAxisymmetricRuntime._FREEGS_SOURCE_UNITS.length;rank=1)
            plasma_region=node(:region,pressure_type;
                id=freegs_pressure_domain.plasma_region_id,label="G2 LCFS interior pressure support")
            vacuum_region=node(:region,pressure_type;
                id=freegs_pressure_domain.vacuum_region_id,label="G2 LCFS exterior zero-pressure support")
            interface_node=node(:interface,interface_type;
                id=freegs_pressure_domain.interface_node_id,label="G2 actual LCFS pressure interface")
            TypedOperatorHypergraphV1((base.nodes...,boundary_node,plasma_region,vacuum_region,interface_node),
                base.hyperedges;registry=_fixture_ops)
        else
            TypedOperatorHypergraphV1((base.nodes...,boundary_node),base.hyperedges;registry=_fixture_ops)
        end
    else
        _fixture_graph()
    end
    if freegs_mms_outer_face_map_mode
        type=FreeGSAxisymmetricRuntime._freegs_source_type(
            FreeGSAxisymmetricRuntime._FREEGS_SOURCE_UNITS.length;rank=1)
        outer_nodes=Tuple(node(:boundary,type;id=id,
            label="MMS geometry mechanism: explicit G2 outer face support")
            for id in freegs_mms_outer_face_node_ids)
        TypedOperatorHypergraphV1((base_graph.nodes...,outer_nodes...),base_graph.hyperedges;
            registry=_fixture_ops)
    else
        base_graph
    end
end
function _freegs_mms_declared_outer_face_map(domain,graph_hash)
    F=FreeGSAxisymmetricRuntime
    incidence=F._freegs_outer_boundary_incidences(domain)
    sides=Tuple(first(x) for x in incidence)
    ids=Tuple(last(x) for x in incidence)
    points=F._freegs_outer_boundary_support(domain,ids)
    face_for=Dict(:R_min=>freegs_mms_outer_face_node_ids[1],
        :R_max=>freegs_mms_outer_face_node_ids[2],
        :Z_min=>freegs_mms_outer_face_node_ids[3],
        :Z_max=>freegs_mms_outer_face_node_ids[4])
    support_for=Dict(:R_min=>"mms-explicit-support-Rmin",:R_max=>"mms-explicit-support-Rmax",
        :Z_min=>"mms-explicit-support-Zmin",:Z_max=>"mms-explicit-support-Zmax")
    normal_for=Dict(:R_min=>(-1.0,0.0),:R_max=>(1.0,0.0),:Z_min=>(0.0,-1.0),:Z_max=>(0.0,1.0))
    face_ids=Tuple(face_for[s] for s in sides)
    support_ids=Tuple(support_for[s] for s in sides)
    face_dofs=Int[]; face_local_dof=Dict(s=>0 for s in keys(face_for))
    for side in sides
        face_local_dof[side]+=1; push!(face_dofs,face_local_dof[side])
    end
    normals=Tuple(normal_for[s] for s in sides)
    F.AxisymmetricG2OuterFaceMapV1(domain,graph_hash,face_ids,support_ids,sides,ids,
        Tuple(face_dofs),points,normals,ntuple(_->Int8(1),length(ids));
        provenance=:mms_geometry_mechanism)
end
const freegs_mms_outer_face_map = freegs_mms_outer_face_map_mode ?
    _freegs_mms_declared_outer_face_map(freegs_base_axisymmetric_declaration.domain,
        string(canonical_hash(freegs_source_field_graph))) : nothing
const freegs_axisymmetric_declaration = if freegs_authored_mode
    base=freegs_base_axisymmetric_declaration; p=base.profile
    profile=FreeGSAxisymmetricRuntime.AxisymmetricConstrainPaxisIpProfileV4(
        p.axis_pressure_pa,p.plasma_current_a,freegs_authored_genomes.values.vacuum_f_tm,
        p.alpha_m,p.alpha_n,p.profile_axis_radius_m;
        critical_point_refinement=freegs_stationary_critical_mode ?
            :stationary_cubic_spline_gradient_hessian_v2 : :freegs_native_v1)
    FreeGSAxisymmetricRuntime.AxisymmetricEquilibriumDeclarationV4(
        freegs_q1_exterior_green_mode ? "authored-native-Q1-exterior-Green-v1" :
        freegs_stationary_critical_mode ?
            "authored-stationary-cubic-spline-critical-points-v2" :
        freegs_pressure_domain_mode ?
            "authored-LCFS-zero-pressure-vacuum-no-sheet-closed-TF-v1" :
            "authored-finite-volume-no-sheet-closed-distributed-TF-v1",base.domain,base.coils,
        profile,base.constraints,base.solver;outer_face_map=freegs_mms_outer_face_map,
        exterior_field_model=freegs_q1_exterior_green_mode ? :native_q1_volume_green_v1 : nothing,
        current_topology=freegs_ideal_periodic_mode ? :ideal_axisymmetric_periodic_lcfs_no_normal_current : nothing,
        return_current_path=freegs_ideal_periodic_mode ? :periodic_toroidal_plasma_with_zero_normal_current_at_LCFS : nothing)
elseif freegs_mms_outer_face_map!==nothing
    base=freegs_base_axisymmetric_declaration
    FreeGSAxisymmetricRuntime.AxisymmetricEquilibriumDeclarationV4(base.declaration_id,
        base.domain,base.coils,base.profile,base.constraints,base.solver;
        outer_face_map=freegs_mms_outer_face_map)
else
    freegs_base_axisymmetric_declaration
end
const freegs_field_genome = FieldGeometryGenomeV4(20260910, _fixture_refs[2],
    freegs_source_field_graph; fields=freegs_pressure_domain===nothing ?
        (freegs_axisymmetric_declaration,) : (freegs_axisymmetric_declaration,freegs_pressure_domain))
const freegs_candidate = CandidateStatePackageV4(
    freegs_q1_exterior_green_mode ? "runtime-v4-freegs-native-Q1-exterior-Green-candidate-v1" :
    freegs_stationary_critical_mode ?
    "runtime-v4-freegs-authored-stationary-cubic-spline-critical-points-candidate-v2" :
    freegs_pressure_domain_mode ? "runtime-v4-freegs-authored-LCFS-zero-pressure-vacuum-candidate-v1" :
    freegs_authored_mode ? "runtime-v4-freegs-authored-no-sheet-closed-TF-v1" : "runtime-v4-freegs-axisymmetric-current-fixture", _fixture_mission,
    freegs_authored_mode ? freegs_authored_genomes.mechanism : _fixture_mechanism,
    freegs_field_genome,
    freegs_authored_mode ? freegs_authored_genomes.realization : _fixture_realization, registry)
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
