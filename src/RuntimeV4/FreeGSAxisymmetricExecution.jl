"""Candidate-bound FreeGS axisymmetric equilibrium execution bridge.

This file is intentionally isolated from `FusionRuntimeV4.jl`.  It accepts only
a typed G2-owned declaration carried by `context.subject.bindings`, revalidates
the complete `ForwardChainContextV4` at every public execution boundary, and
can emit only a physical-model screen or a recoverable unknown gap.
"""

import FusionConceptAI: semantic_view, canonical_hash
using FusionConceptAI
using SHA, JSON3

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

function _freegs_outer_boundary_incidences(domain::AxisymmetricDomainV4)
    nr,nz=domain.nx,domain.ny
    out=Tuple{Symbol,Int}[]
    append!(out,((:R_min,j) for j in 1:nz))
    append!(out,((:R_max,(nr-1)*nz+j) for j in 1:nz))
    append!(out,((:Z_min,(i-1)*nz+1) for i in 1:nr))
    append!(out,((:Z_max,i*nz) for i in 1:nr))
    Tuple(out)
end

function _freegs_outer_boundary_support(domain::AxisymmetricDomainV4, native_ids)
    R=collect(range(domain.r_min_m,domain.r_max_m;length=domain.nx))
    Z=collect(range(domain.z_min_m,domain.z_max_m;length=domain.ny))
    Tuple((R[div(id-1,domain.ny)+1],Z[mod1(id,domain.ny)]) for id in native_ids)
end
_freegs_map_coordinate_matches(a,b) = isapprox(a,b;rtol=0,
    atol=16eps(Float64)*max(1.0,abs(a),abs(b)))
function _freegs_expected_outer_normal(side::Symbol)
    side===:R_min && return (-1.0,0.0)
    side===:R_max && return (1.0,0.0)
    side===:Z_min && return (0.0,-1.0)
    side===:Z_max && return (0.0,1.0)
    throw(ArgumentError("unknown FreeGS outer boundary side: $side"))
end
function _freegs_incidence_is_outward(side::Symbol,normal,orientation_sign)
    expected=_freegs_expected_outer_normal(side)
    all(k->isapprox(orientation_sign*normal[k],expected[k];rtol=0,atol=1e-10),1:2)
end

_freegs_outer_face_map_body(domain_hash,field_geometry_graph_hash,face_node_ids,face_support_ids,side_ids,native_ids,
    face_dof_ids,support_RZ_m,normals_RZ,orientation_signs,provenance) =
    (revision="axisymmetric-g2-outer-face-map-v1",domain_hash=domain_hash,
     field_geometry_graph_hash=field_geometry_graph_hash,
     face_node_ids=face_node_ids,face_support_ids=face_support_ids,side_ids=side_ids,
     native_boundary_ids=native_ids,face_dof_ids=face_dof_ids,support_RZ_m=support_RZ_m,
     normals_RZ=normals_RZ,orientation_signs=orientation_signs,provenance=provenance)

"""Explicit candidate-bound G2 face incidence map for the FreeGS RZ boundary.

One entry represents one oriented face incidence. `normals_RZ` is the face-local
unit normal; `orientation_signs` converts it to the side-specific geometric outward
normal. Corner entries retain each adjacent face's separate normal and share one native
RZ node, so they gather the same full-state columns without merging incidences.
"""
struct AxisymmetricG2OuterFaceMapV1
    domain_hash::String
    field_geometry_graph_hash::String
    face_node_ids::Tuple{Vararg{String}}
    face_support_ids::Tuple{Vararg{String}}
    side_ids::Tuple{Vararg{Symbol}}
    native_boundary_ids::Tuple{Vararg{Int}}
    face_dof_ids::Tuple{Vararg{Int}}
    support_RZ_m::Tuple{Vararg{NTuple{2,Float64}}}
    normals_RZ::Tuple{Vararg{NTuple{2,Float64}}}
    orientation_signs::Tuple{Vararg{Int8}}
    provenance::Symbol
    map_hash::Digest256
    function AxisymmetricG2OuterFaceMapV1(domain::AxisymmetricDomainV4,field_geometry_graph_hash,
            face_node_ids,face_support_ids,side_ids,native_boundary_ids,face_dof_ids,
            support_RZ_m,normals_RZ,orientation_signs;provenance=:candidate_declared_physical_surface)
        graph_hash=_freegs_text(field_geometry_graph_hash,"G2 field geometry graph hash")
        occursin(r"^[0-9a-f]{64}$",graph_hash) || throw(ArgumentError("G2 field geometry graph hash must be lowercase SHA-256"))
        faces=Tuple(_freegs_text(x,"outer G2 face node ID") for x in face_node_ids)
        supports=Tuple(_freegs_text(x,"outer G2 face support ID") for x in face_support_ids)
        sides=Tuple(Symbol(x) for x in side_ids)
        ids=Tuple(_freegs_integer(x,"outer native RZ boundary ID") for x in native_boundary_ids)
        dofs=Tuple(_freegs_integer(x,"outer face local DOF ID") for x in face_dof_ids)
        points=Tuple(begin
            (p isa Tuple || p isa AbstractVector) && length(p)==2 ||
                throw(ArgumentError("outer face support points must be (R,Z) pairs"))
            (_freegs_finite(p[1],"outer face support R";positive=true),
             _freegs_finite(p[2],"outer face support Z"))
        end for p in support_RZ_m)
        normals=Tuple(begin
            (q isa Tuple || q isa AbstractVector) && length(q)==2 ||
                throw(ArgumentError("outer face normals must be (R,Z) pairs"))
            (_freegs_finite(q[1],"outer face normal R"),_freegs_finite(q[2],"outer face normal Z"))
        end for q in normals_RZ)
        signs=Tuple(begin
            x isa Integer && !(x isa Bool) && x in (-1,1) ||
                throw(ArgumentError("outer face orientation sign must be integer +1 or -1"))
            Int8(x)
        end for x in orientation_signs)
        expected=_freegs_outer_boundary_incidences(domain)
        sides==Tuple(first(x) for x in expected) && ids==Tuple(last(x) for x in expected) ||
            throw(ArgumentError("outer face map must cover every oriented native RZ boundary incidence in canonical side order"))
        n=length(expected)
        length(faces)==length(supports)==length(dofs)==length(points)==length(normals)==length(signs)==n ||
            throw(ArgumentError("outer face incidence fields have inconsistent lengths"))
        length(Set(zip(faces,dofs)))==n ||
            throw(ArgumentError("face-local DOF IDs must be unique within each G2 face"))
        for side in unique(sides)
            indices=findall(==(side),sides)
            length(unique(faces[indices]))==1 && length(unique(supports[indices]))==1 &&
                length(unique(signs[indices]))==1 ||
                throw(ArgumentError("each oriented RZ side must bind one G2 face/support with a consistent orientation"))
        end
        expected_points=_freegs_outer_boundary_support(domain,ids)
        all(k->_freegs_map_coordinate_matches(points[k][1],expected_points[k][1]) &&
            _freegs_map_coordinate_matches(points[k][2],expected_points[k][2]),eachindex(ids)) ||
            throw(ArgumentError("declared G2 support coordinates differ from mapped native boundary nodes"))
        all(q->isapprox(hypot(q...),1.0;rtol=0,atol=1e-10),normals) ||
            throw(ArgumentError("outer face normals must be unit RZ vectors"))
        all(k->_freegs_incidence_is_outward(sides[k],normals[k],signs[k]),eachindex(sides)) ||
            throw(ArgumentError("each oriented G2 face incidence must resolve to its side-specific outward RZ normal"))
        provenance in (:candidate_declared_physical_surface,:mms_geometry_mechanism) ||
            throw(ArgumentError("outer face provenance must identify an explicit candidate surface or MMS geometry mechanism"))
        # Every adjacent-face corner incidence retains its own face DOF; the native
        # node index is deliberately duplicated and is not turned into another state.
        dh=string(canonical_hash(semantic_view(domain)))
        body=_freegs_outer_face_map_body(dh,graph_hash,faces,supports,sides,ids,dofs,points,normals,signs,provenance)
        is_canonical_value(body) || throw(ArgumentError("outer face map is not canonicalizable"))
        new(dh,graph_hash,faces,supports,sides,ids,dofs,points,normals,signs,provenance,canonical_hash(body))
    end
end

function _validate_freegs_outer_face_map(map::AxisymmetricG2OuterFaceMapV1,domain::AxisymmetricDomainV4)
    body=_freegs_outer_face_map_body(map.domain_hash,map.field_geometry_graph_hash,
        map.face_node_ids,map.face_support_ids,
        map.side_ids,map.native_boundary_ids,map.face_dof_ids,map.support_RZ_m,
        map.normals_RZ,map.orientation_signs,map.provenance)
    map.map_hash==canonical_hash(body) || throw(ArgumentError("G2 outer face map hash mismatch"))
    map.domain_hash==string(canonical_hash(semantic_view(domain))) ||
        throw(ArgumentError("G2 outer face map is stale for this FreeGS domain/grid"))
    map.side_ids==Tuple(first(x) for x in _freegs_outer_boundary_incidences(domain)) &&
        map.native_boundary_ids==Tuple(last(x) for x in _freegs_outer_boundary_incidences(domain)) ||
        throw(ArgumentError("G2 outer face incidence map differs from this FreeGS domain/grid"))
    all(k->_freegs_incidence_is_outward(map.side_ids[k],map.normals_RZ[k],map.orientation_signs[k]),
        eachindex(map.side_ids)) ||
        throw(ArgumentError("G2 face incidence normal is not outward for its mapped FreeGS side"))
    expected_points=_freegs_outer_boundary_support(domain,map.native_boundary_ids)
    all(k->_freegs_map_coordinate_matches(map.support_RZ_m[k][1],expected_points[k][1]) &&
        _freegs_map_coordinate_matches(map.support_RZ_m[k][2],expected_points[k][2]),eachindex(expected_points)) ||
        throw(ArgumentError("G2 outer face support coordinates differ from this FreeGS domain/grid"))
    map.map_hash
end
function semantic_view(x::AxisymmetricG2OuterFaceMapV1)
    merge(_freegs_outer_face_map_body(x.domain_hash,x.field_geometry_graph_hash,
        x.face_node_ids,x.face_support_ids,
        x.side_ids,x.native_boundary_ids,x.face_dof_ids,x.support_RZ_m,x.normals_RZ,
        x.orientation_signs,x.provenance),(map_hash=x.map_hash,))
end

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
    critical_point_refinement::Symbol
    function AxisymmetricConstrainPaxisIpProfileV4(axis_pressure_pa, plasma_current_a,
            vacuum_f_tm, alpha_m, alpha_n, profile_axis_radius_m;
            critical_point_refinement=:freegs_native_v1)
        rule=Symbol(critical_point_refinement)
        rule in (:freegs_native_v1,:stationary_cubic_spline_gradient_hessian_v2) ||
            throw(ArgumentError("unsupported critical-point refinement rule"))
        new(_freegs_finite(axis_pressure_pa, "axis pressure"; nonnegative=true),
            _freegs_finite(plasma_current_a, "plasma current"),
            _freegs_finite(vacuum_f_tm, "vacuum F"; positive=true),
            _freegs_finite(alpha_m, "alpha_m"; positive=true),
            _freegs_finite(alpha_n, "alpha_n"; positive=true),
            _freegs_finite(profile_axis_radius_m, "profile axis radius"; positive=true),rule)
    end
end
function semantic_view(x::AxisymmetricConstrainPaxisIpProfileV4)
    base=(profile_model=:constrain_paxis_ip, axis_pressure_pa=x.axis_pressure_pa,
        plasma_current_a=x.plasma_current_a, vacuum_f_tm=x.vacuum_f_tm,
        alpha_m=x.alpha_m, alpha_n=x.alpha_n,
        profile_axis_radius_m=x.profile_axis_radius_m)
    x.critical_point_refinement===:freegs_native_v1 && return base
    merge(base,(critical_point_refinement=x.critical_point_refinement,))
end

"""Candidate-owned pressure support for a fixed, LCFS-bounded plasma/vacuum model."""
struct AxisymmetricPressureDomainV1
    plasma_region_id::String
    vacuum_region_id::String
    interface_node_id::String
    boundary_node_id::String
    exterior_pressure_pa::Float64
    classification_rule::Symbol
    open_flux_policy::Symbol
    function AxisymmetricPressureDomainV1(plasma_region_id,vacuum_region_id,
            interface_node_id,boundary_node_id,exterior_pressure_pa,
            classification_rule,open_flux_policy)
        plasma=_freegs_text(plasma_region_id,"plasma pressure region")
        vacuum=_freegs_text(vacuum_region_id,"vacuum pressure region")
        interface=_freegs_text(interface_node_id,"pressure LCFS interface")
        boundary=_freegs_text(boundary_node_id,"pressure LCFS boundary")
        plasma!=vacuum || throw(ArgumentError("plasma and vacuum pressure regions must differ"))
        boundary==_FREEGS_LCFS_NODE || throw(ArgumentError("pressure domain must bind the actual G2 LCFS"))
        pressure=_freegs_finite(exterior_pressure_pa,"exterior pressure";nonnegative=true)
        pressure==0.0 || throw(ArgumentError("this candidate input supports only the declared zero-pressure vacuum law"))
        classification_rule===:receipt_bound_native_flux_connected_core_mask ||
            throw(ArgumentError("pressure regions require receipt-bound discrete FreeGS native-core roles"))
        open_flux_policy===:exterior_vacuum_even_when_psi_n_below_one ||
            throw(ArgumentError("open-flux exterior pressure policy is unsupported"))
        new(plasma,vacuum,interface,boundary,pressure,classification_rule,open_flux_policy)
    end
end
semantic_view(x::AxisymmetricPressureDomainV1) = (
    plasma_region_id=x.plasma_region_id,vacuum_region_id=x.vacuum_region_id,
    interface_node_id=x.interface_node_id,boundary_node_id=x.boundary_node_id,
    exterior_pressure_pa=x.exterior_pressure_pa,
    classification_rule=x.classification_rule,open_flux_policy=x.open_flux_policy)

struct AxisymmetricShapeConstraintsV4
    xpoints_m::Tuple{Vararg{NTuple{2,Float64}}}
    isoflux_m::Tuple{Vararg{NTuple{4,Float64}}}
    tikhonov_gamma::Float64
    current_lims_A_per_turn::Union{Nothing,Tuple{Vararg{NTuple{2,Float64}}}}
    max_total_current_A::Union{Nothing,Float64}
    function AxisymmetricShapeConstraintsV4(xpoints, isoflux, tikhonov_gamma;
            current_lims_A_per_turn=nothing, max_total_current_A=nothing)
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
        limits = current_lims_A_per_turn === nothing ? nothing : Tuple(begin
            length(pair) == 2 || throw(ArgumentError("each per-turn current limit must be (lower, upper)"))
            lower = _freegs_finite(pair[1], "per-turn current lower limit")
            upper = _freegs_finite(pair[2], "per-turn current upper limit")
            lower <= upper || throw(ArgumentError("per-turn current limits are reversed"))
            (lower, upper)
        end for pair in current_lims_A_per_turn)
        total_limit = max_total_current_A === nothing ? nothing :
            _freegs_finite(max_total_current_A, "maximum total controlled-coil current")
        total_limit===nothing || total_limit>=0.0 ||
            throw(ArgumentError("maximum total controlled-coil current cannot be negative"))
        new(xp, iso, _freegs_finite(tikhonov_gamma, "tikhonov gamma"; positive=true),
            limits, total_limit)
    end
end
function semantic_view(x::AxisymmetricShapeConstraintsV4)
    body=(xpoints_m=x.xpoints_m, isoflux_m=x.isoflux_m, tikhonov_gamma=x.tikhonov_gamma)
    body=x.current_lims_A_per_turn===nothing ? body :
        merge(body,(current_lims_A_per_turn=x.current_lims_A_per_turn,))
    x.max_total_current_A===nothing ? body :
        merge(body,(max_total_current_A=x.max_total_current_A,))
end

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

# A new current-reconstruction model is sealed by the existing declaration hash.
# It never reinterprets the legacy offset Hagenow boundary equation.
function _freegs_exterior_field_model_body(model)
    model===nothing && return nothing
    if model===:native_q1_volume_green_v1
        # Preserve this original semantic identity exactly: full Q1 cell support
        # observed at the candidate G2 rectangle, not at the LCFS.
        return (model=model,source_coefficients=:current_profile_native_core_Jphi,
            source_basis=:native_tensor_Q1_zero_noncore_coefficients,
            source_cells=:every_cell_touching_a_core_hat,
            observation_support=:actual_candidate_G2_outer_face_map,
            kernel=:unregularized_circular_filament_Green_gradient,
            quadrature_orders=(8,16,32),response_entry_truncation_budget_T_per_A_m2=1e-14,
            response_coefficient_unit="T/(A m^-2)",
            separation_rule=:positive_source_cell_to_target_distance,
            floating_point_error_certified=false,
            legacy_H512=:unchanged_offset_GS4_Hagenow_benchmark)
    elseif model===:native_q1_lcfs_clipped_green_v1
        # New candidate identity: this changes the Q1 support definition and
        # remains HOLD until singular cut-cell integration and geometry terms exist.
        return (model=model,source_coefficients=:current_profile_native_core_Jphi,
            source_basis=:native_tensor_Q1_restricted_to_actual_LCFS_zero_outside,
            source_cells=:polygon_cut_intersection_of_every_cell_touching_a_core_hat,
            observation_support=:actual_candidate_LCFS_trace_coordinates,
            clipping_geometry=:accepted_actual_final_psi_LCFS_polygon,
            kernel=:circular_filament_Green_gradient_with_cut_cell_Duffy_required,
            quadrature_orders=(8,16,32),response_coefficient_unit="T/(A m^-2)",
            response_status=:typed_absent_until_Duffy_and_moving_geometry_derivatives,
            legacy_H512=:unchanged_offset_GS4_Hagenow_benchmark)
    end
    throw(ArgumentError("unsupported exterior current-reconstruction model"))
end

function _freegs_plasma_current_topology_body(current_topology,return_current_path)
    current_topology===nothing && return_current_path===nothing && return nothing
    current_topology===:ideal_axisymmetric_periodic_lcfs_no_normal_current &&
        return_current_path===:periodic_toroidal_plasma_with_zero_normal_current_at_LCFS ||
        throw(ArgumentError("unsupported explicit plasma current topology / return path"))
    (model=current_topology,phi_interval=(lower_rad=0.0,upper_rad=2pi,periodic=true),
        lcfs_boundary_law=:J_dot_n_zero,
        external_return_conductor=:outside_declared_model,return_current_path=return_current_path)
end

function _freegs_declaration_body(declaration_id, domain, coils, profile, constraints, solver,
        outer_face_map=nothing,exterior_field_model=nothing,
        current_topology=nothing,return_current_path=nothing)
    body=(revision=_FREEGS_AXISYMMETRIC_REVISION,
        declaration_id=declaration_id,
        model=:axisymmetric_free_boundary_grad_shafranov,
        domain=domain,
        coils=coils,
        profile=profile,
        constraints=constraints,
        solver=solver)
    body=outer_face_map===nothing ? body : merge(body,(outer_face_map=outer_face_map,))
    body=exterior_field_model===nothing ? body : merge(body,
        (exterior_current_reconstruction=_freegs_exterior_field_model_body(exterior_field_model),))
    topology=_freegs_plasma_current_topology_body(current_topology,return_current_path)
    topology===nothing ? body : merge(body,(plasma_current_topology=topology,))
end

"""Typed axisymmetric boundary/coils/profile declaration owned by G2 fields."""
struct AxisymmetricEquilibriumDeclarationV4
    declaration_id::String
    domain::AxisymmetricDomainV4
    coils::Tuple{Vararg{AxisymmetricFilamentCoilV4}}
    profile::AxisymmetricConstrainPaxisIpProfileV4
    constraints::AxisymmetricShapeConstraintsV4
    solver::AxisymmetricSolverControlsV4
    outer_face_map::Union{Nothing,AxisymmetricG2OuterFaceMapV1}
    exterior_field_model::Union{Nothing,Symbol}
    current_topology::Union{Nothing,Symbol}
    return_current_path::Union{Nothing,Symbol}
    declaration_hash::Digest256
    function AxisymmetricEquilibriumDeclarationV4(declaration_id,
            domain::AxisymmetricDomainV4, coils,
            profile::AxisymmetricConstrainPaxisIpProfileV4,
            constraints::AxisymmetricShapeConstraintsV4,
            solver::AxisymmetricSolverControlsV4;outer_face_map=nothing,exterior_field_model=nothing,
            current_topology=nothing,return_current_path=nothing)
        coil_tuple = Tuple(coils)
        all(x -> x isa AxisymmetricFilamentCoilV4, coil_tuple) ||
            throw(ArgumentError("all coil declarations must be typed AxisymmetricFilamentCoilV4"))
        4 <= length(coil_tuple) <= 32 ||
            throw(ArgumentError("the bounded bridge requires 4 to 32 filament coils"))
        constraints.current_lims_A_per_turn===nothing ||
            length(constraints.current_lims_A_per_turn)==length(coil_tuple) ||
            throw(ArgumentError("per-turn current limits must match every declared coil in order"))
        ids = Tuple(x.coil_id for x in coil_tuple)
        length(unique(ids)) == length(ids) || throw(ArgumentError("coil IDs must be unique"))
        id = _freegs_text(declaration_id, "declaration_id")
        outer_face_map===nothing || outer_face_map isa AxisymmetricG2OuterFaceMapV1 ||
            throw(ArgumentError("outer_face_map must be a typed candidate-bound G2 map"))
        outer_face_map===nothing || _validate_freegs_outer_face_map(outer_face_map,domain)
        _freegs_exterior_field_model_body(exterior_field_model)
        exterior_field_model===nothing || outer_face_map!==nothing ||
            throw(ArgumentError("Q1 exterior current model requires a candidate-owned G2 outer face map"))
        body = _freegs_declaration_body(id, domain, coil_tuple, profile, constraints, solver,
            outer_face_map,exterior_field_model,current_topology,return_current_path)
        is_canonical_value(body) || throw(ArgumentError("axisymmetric declaration is not canonicalizable"))
        new(id, domain, coil_tuple, profile, constraints, solver, outer_face_map,
            exterior_field_model,current_topology,return_current_path,canonical_hash(body))
    end
end

function _validate_freegs_declaration(x::AxisymmetricEquilibriumDeclarationV4)
    x.outer_face_map===nothing || _validate_freegs_outer_face_map(x.outer_face_map,x.domain)
    expected = canonical_hash(_freegs_declaration_body(x.declaration_id, x.domain,
        x.coils, x.profile, x.constraints, x.solver,x.outer_face_map,x.exterior_field_model,
        x.current_topology,x.return_current_path))
    x.declaration_hash == expected || throw(ArgumentError("axisymmetric declaration hash mismatch"))
    expected
end
canonical_hash(x::AxisymmetricEquilibriumDeclarationV4) = _validate_freegs_declaration(x)
function semantic_view(x::AxisymmetricEquilibriumDeclarationV4)
    body=(declaration_id=x.declaration_id, model=:axisymmetric_free_boundary_grad_shafranov,
        domain=x.domain, coils=x.coils, profile=x.profile, constraints=x.constraints,
        solver=x.solver, declaration_hash=x.declaration_hash)
    body=x.outer_face_map===nothing ? body : merge(body,(outer_face_map=x.outer_face_map,))
    body=x.exterior_field_model===nothing ? body : merge(body,
        (exterior_current_reconstruction=_freegs_exterior_field_model_body(x.exterior_field_model),))
    topology=_freegs_plasma_current_topology_body(x.current_topology,x.return_current_path)
    topology===nothing ? body : merge(body,(plasma_current_topology=topology,))
end

# The authored laws use existing typed AST/MIMO/G1/G3 structures. These names
# select exact graph sites, never a device name, candidate label or absent law.
const _FREEGS_K_SITE = "freegs-authored-no-delta-sheet-v1"
const _FREEGS_LCFS_NODE = "freegs-authored-actual-final-psi-LCFS-v1"
const _FREEGS_PRESSURE_VACUUM_SITE = "freegs-authored-exterior-pressure-vacuum-v1"
const _FREEGS_PLASMA_REGION_NODE = "freegs-authored-plasma-pressure-region-v1"
const _FREEGS_VACUUM_REGION_NODE = "freegs-authored-vacuum-pressure-region-v1"
const _FREEGS_PRESSURE_LCFS_INTERFACE_NODE = "freegs-authored-pressure-LCFS-interface-v1"
const _FREEGS_TF_SITES = ("freegs-authored-tf-NI-v1", "freegs-authored-tf-coefficient-v1",
    "freegs-authored-tf-field-v1", "freegs-authored-tf-closed-path-v1", "freegs-authored-tf-uniform-v1")
const _FREEGS_SOURCE_MU0 = 4pi*1.0e-7
const _FREEGS_SOURCE_UNITS = (length=UnitSignature((0,1,0,0,0,0,0)),
    current=UnitSignature((0,0,0,1,0,0,0)), sheet=UnitSignature((0,-1,0,1,0,0,0)),
    magnetic=UnitSignature((1,0,-2,-1,0,0,0)), coefficient=UnitSignature((1,1,-2,-1,0,0,0)),
    pressure=UnitSignature((1,-1,-2,0,0,0,0)),
    permeability=UnitSignature((1,1,-2,-2,0,0,0)), dimensionless=UnitSignature())

"""Published TF hardware basis for a magnitude-only source screen.

The current reference is retained for exposed consistency reporting; it is not
an inverse bound or prior. Polarity is deliberately typed absent.
"""
struct FreeGSTFHardwareBasisV1
    coil_count::Int
    turns_per_coil::Int
    current_seed_A::Float64
    published_current_reference_A::Float64
    R0_m::Float64
    B0_T::Float64
    coil_count_source_ref::String
    turns_source_ref::String
    current_source_ref::String
    field_source_ref::String
    polarity_status::Symbol
    function FreeGSTFHardwareBasisV1(coil_count, turns_per_coil, current_seed_A,
            published_current_reference_A, R0_m, B0_T, coil_count_source_ref,
            turns_source_ref, current_source_ref, field_source_ref;
            polarity_status=:typed_absent)
        for (value, label) in ((coil_count, "TF coil count"),
                (turns_per_coil, "TF turns per coil"))
            typeof(value) <: Integer && !(value isa Bool) && 0 < value <= typemax(Int) ||
                throw(ArgumentError("$label must be a positive Int"))
        end
        try
            Base.Checked.checked_mul(Int(coil_count),Int(turns_per_coil))
        catch err
            err isa OverflowError || rethrow()
            throw(ArgumentError("effective TF turns overflow Int"))
        end
        polarity_status === :typed_absent ||
            throw(ArgumentError("ITER TF polarity is not supplied by this source basis"))
        new(Int(coil_count), Int(turns_per_coil),
            _freegs_finite(current_seed_A, "TF inverse current seed A"; positive=true),
            _freegs_finite(published_current_reference_A, "published TF current reference A"; positive=true),
            _freegs_finite(R0_m, "ITER TF reference radius m"; positive=true),
            _freegs_finite(B0_T, "ITER TF reference field T"; positive=true),
            _freegs_text(coil_count_source_ref, "TF coil-count source ref"),
            _freegs_text(turns_source_ref, "TF turns source ref"),
            _freegs_text(current_source_ref, "TF current source ref"),
            _freegs_text(field_source_ref, "TF field source ref"), polarity_status)
    end
end
semantic_view(x::FreeGSTFHardwareBasisV1) =
    (revision="freegs-tf-hardware-basis-v1", coil_count=x.coil_count,
     turns_per_coil=x.turns_per_coil, current_seed_A=x.current_seed_A,
     published_current_reference_A=x.published_current_reference_A, R0_m=x.R0_m, B0_T=x.B0_T,
     coil_count_source_ref=x.coil_count_source_ref,
     turns_source_ref=x.turns_source_ref,
     current_source_ref=x.current_source_ref, field_source_ref=x.field_source_ref,
     polarity_status=x.polarity_status)

_freegs_source_type(unit;rank=0)=PhysicalType(rank==0 ? :scalar_field : :vector_field,
    rank,3,TemporalTypeV1(static_time),unit)

# Narrow executable subset of the existing AST: constants, inputs and the
# existing arithmetic manifests. Reconstructing the program rechecks units,
# registry manifests, reachability and typed ports before numeric evaluation.
function _freegs_validate_source_ast(edge::AtomicMIMOHyperedgeV1)
    p=edge.program
    checked=TypedASTProgramV1(p.nodes,p.roots,p.input_ports;registry=edge.registry)
    canonical_hash(checked)==edge.program_hash ||
        throw(ArgumentError("authored source AST/port binding differs"))
    p
end

function _freegs_eval_source_ast(edge::AtomicMIMOHyperedgeV1,inputs::Tuple)
    _freegs_eval_source_program(_freegs_validate_source_ast(edge),inputs)
end

# The closed-form d|Bphi|/dI used by the narrow inverse is valid only for this
# exact current -> turns -> coil-count -> mu0/(2pi) -> C/R AST composition.
# Recheck ports, node order/roles, operands, constants and SI types each time.
function _freegs_tf_apply_is(node,id,inputs)
    node isa ASTApplyV1 && node.operator_ref.qualified.id==id &&
        node.operator_ref.qualified.version=="v1" && node.inputs==inputs &&
        isempty(keys(node.parameters))
end
function _freegs_tf_input_is(node,port,unit;expected_parameters=(;))
    node isa ASTInputV1 && node.port==port && node.output_type==_freegs_source_type(unit) &&
        node.parameters==expected_parameters
end
function _freegs_tf_constant_is(node,value,unit,role,source_ref=nothing)
    node isa ASTConstantV1 || return false
    role_ok=role===:constant ? isempty(keys(node.parameters)) :
        hasproperty(node.parameters,:role) && node.parameters.role===role
    source_ok=source_ref===nothing ||
        hasproperty(node.parameters,:source_ref) && node.parameters.source_ref==source_ref
    node.value==Float64(value) && node.output_type==_freegs_source_type(unit) && role_ok && source_ok
end
function _freegs_validate_tf_hardware_programs(ni::TypedASTProgramV1,
        coefficient::TypedASTProgramV1,field::TypedASTProgramV1,basis::FreeGSTFHardwareBasisV1)
    u=_FREEGS_SOURCE_UNITS
    length(ni.nodes)==5 && ni.roots==(5,) && ni.input_ports==(1,) &&
        _freegs_tf_input_is(ni.nodes[1],1,u.current;expected_parameters=
            (role=:unknown_tf_conductor_current_A,unit=:A,polarity=:typed_absent)) &&
        keys(ni.nodes[1].parameters)==(:role,:unit,:polarity) &&
        ni.nodes[1].parameters.role===:unknown_tf_conductor_current_A &&
        ni.nodes[1].parameters.unit===:A && ni.nodes[1].parameters.polarity===:typed_absent &&
        _freegs_tf_constant_is(ni.nodes[2],basis.turns_per_coil,u.dimensionless,:turns_per_coil,basis.turns_source_ref) &&
        keys(ni.nodes[2].parameters)==(:role,:source_ref,:unit) && ni.nodes[2].parameters.unit===:turn_count &&
        _freegs_tf_constant_is(ni.nodes[3],basis.coil_count,u.dimensionless,:coil_count,basis.coil_count_source_ref) &&
        keys(ni.nodes[3].parameters)==(:role,:source_ref,:unit) && ni.nodes[3].parameters.unit===:coil_count &&
        _freegs_tf_apply_is(ni.nodes[4],"SCALAR_MUL",(1,2)) &&
        ni.nodes[4].output_type==_freegs_source_type(u.current) &&
        _freegs_tf_apply_is(ni.nodes[5],"SCALAR_MUL",(4,3)) &&
        ni.nodes[5].output_type==_freegs_source_type(u.current) ||
        throw(ArgumentError("G3 hardware NI AST does not match exact current-turn-count semantics"))
    length(coefficient.nodes)==5 && coefficient.roots==(5,) && coefficient.input_ports==(1,) &&
        _freegs_tf_input_is(coefficient.nodes[1],1,u.current) &&
        _freegs_tf_constant_is(coefficient.nodes[2],_FREEGS_SOURCE_MU0,u.permeability,:constant) &&
        _freegs_tf_constant_is(coefficient.nodes[3],2pi,u.dimensionless,:constant) &&
        _freegs_tf_apply_is(coefficient.nodes[4],"SCALAR_MUL",(1,2)) &&
        coefficient.nodes[4].output_type==_freegs_source_type(u.coefficient) &&
        _freegs_tf_apply_is(coefficient.nodes[5],"SCALAR_DIV",(4,3)) &&
        coefficient.nodes[5].output_type==_freegs_source_type(u.coefficient) ||
        throw(ArgumentError("G3 coefficient AST is not exact mu0*NI/(2pi)"))
    length(field.nodes)==3 && field.roots==(3,) && field.input_ports==(1,2) &&
        _freegs_tf_input_is(field.nodes[1],1,u.coefficient) &&
        _freegs_tf_input_is(field.nodes[2],2,u.length) &&
        _freegs_tf_apply_is(field.nodes[3],"SCALAR_DIV",(1,2)) &&
        field.nodes[3].output_type==_freegs_source_type(u.magnetic) ||
        throw(ArgumentError("G3 field AST is not exact C/R"))
    true
end

# The same immutable program is validated after the first sample passes domain checks.
# Numeric arity/finiteness checks still run for every changing input value.
function _freegs_eval_source_program(p::TypedASTProgramV1,inputs::Tuple)
    length(inputs)==length(p.input_ports) ||
        throw(ArgumentError("authored source AST/port binding differs"))
    values=Any[]
    for (i,n) in enumerate(p.nodes)
        value=if n isa ASTConstantV1
            n.value
        elseif n isa ASTInputV1
            inputs[only(findall(==(i),p.input_ports))]
        elseif n isa ASTApplyV1
            op=n.operator_ref.qualified.id
            args=Tuple(values[j] for j in n.inputs)
            op=="SCALAR_MUL" ? args[1]*args[2] :
            op=="SCALAR_DIV" ? args[1]/args[2] :
            op=="IDENTITY" || op=="ALGEBRAIC_CONSTRAINT" ? only(args) :
            throw(ArgumentError("unsupported authored source AST operator: $op"))
        else
            throw(ArgumentError("unbound authored source parameter"))
        end
        valid=v -> v isa Real && !(v isa Bool) && isfinite(v)
        (valid(value) || value isa Tuple && all(valid,value)) ||
            throw(ArgumentError("authored source AST produced a nonfinite/nonphysical value"))
        push!(values,value)
    end
    Tuple(values[i] for i in p.roots)
end

function _freegs_source_edge(graph,id,role,inputs,outputs)
    matches=Tuple(e for e in graph.hyperedges if e.edge_id==id)
    length(matches)==1 && only(matches) isa AtomicMIMOHyperedgeV1 ||
        throw(ArgumentError("authored source graph site absent or ambiguous: $id"))
    e=only(matches)
    e.role==role && length(e.input_bindings)==length(inputs) && length(e.output_bindings)==length(outputs) ||
        throw(ArgumentError("authored source role/arity differs: $id"))
    input_nodes=Tuple(graph.nodes[only(b.graph_node_index for b in e.input_bindings if b.program_position==k)] for k in eachindex(inputs))
    output_nodes=Tuple(graph.nodes[only(b.graph_node_index for b in e.output_bindings if b.program_position==k)] for k in eachindex(outputs))
    Tuple(n.physical_type for n in input_nodes)==inputs && Tuple(n.physical_type for n in output_nodes)==outputs ||
        throw(ArgumentError("authored source units/types differ: $id"))
    e
end

"Evaluate declared G1 no-sheet/pressure and G3 closed distributed TF source graphs."
function _freegs_authored_source_values(mechanism,realization,domain;sample_RZ=(),NI_A_turn=nothing,
        pressure_domain=nothing,tf_hardware_basis=nothing,current_A=nothing)
    g1=mechanism.payload.operator_graph; g3=realization.realization_graph
    tf_hardware_basis===nothing || tf_hardware_basis isa FreeGSTFHardwareBasisV1 ||
        throw(ArgumentError("tf_hardware_basis must be FreeGSTFHardwareBasisV1 or nothing"))
    has_k=any(e -> e.edge_id==_FREEGS_K_SITE,g1.hyperedges)
    has_pressure=any(e -> e.edge_id==_FREEGS_PRESSURE_VACUUM_SITE,g1.hyperedges)
    has_tf=any(e -> e.edge_id in _FREEGS_TF_SITES,g3.hyperedges)
    !has_k && !has_tf && return (status=:typed_absent,reason=:candidate_has_no_authored_sheet_TF_source)
    has_k && has_tf || throw(ArgumentError("authored model requires both actual G1 and G3 source graphs"))
    has_pressure==(pressure_domain!==nothing) ||
        throw(ArgumentError("authored vacuum-pressure source/domain declaration presence differs"))
    u=_FREEGS_SOURCE_UNITS
    kt=_freegs_source_type(u.sheet;rank=1); pt=_freegs_source_type(u.pressure)
    it=_freegs_source_type(u.current)
    ct=_freegs_source_type(u.coefficient); rt=_freegs_source_type(u.length)
    bt=_freegs_source_type(u.magnetic); vt=_freegs_source_type(u.length;rank=1)
    dt=_freegs_source_type(u.dimensionless)
    ke=_freegs_source_edge(g1,_FREEGS_K_SITE,constraint,(),(kt,))
    scopes=Tuple(n.parameters.boundary_node_id for n in ke.program.nodes
        if n isa ASTConstantV1 && hasproperty(n.parameters,:boundary_node_id))
    scopes==(_FREEGS_LCFS_NODE,) || throw(ArgumentError("G1 no-sheet source lacks its exact G2 LCFS boundary reference"))
    K=only(_freegs_eval_source_ast(ke,()))
    K isa Tuple && length(K)==3 && all(==(0.0),K) ||
        throw(ArgumentError("G1 no-delta-sheet model requires its executed K source to be exactly zero"))
    pressure_zero=nothing
    if pressure_domain!==nothing
        pe=_freegs_source_edge(g1,_FREEGS_PRESSURE_VACUUM_SITE,constraint,(),(pt,))
        length(pe.program.nodes)==1 && only(pe.program.nodes) isa ASTConstantV1 ||
            throw(ArgumentError("G1 exterior pressure law must be one typed constant source"))
        pressure_scopes=Tuple(n.parameters for n in pe.program.nodes if n isa ASTConstantV1)
        pressure_scopes==((pressure_domain_id=string(canonical_hash(pressure_domain)),
            region_node_id=pressure_domain.vacuum_region_id,
            interface_node_id=pressure_domain.interface_node_id,
            boundary_node_id=pressure_domain.boundary_node_id,
            classification_rule=pressure_domain.classification_rule,
            open_flux_policy=pressure_domain.open_flux_policy),) ||
            throw(ArgumentError("G1 vacuum-pressure source lacks its exact G2 region/interface scope"))
        pressure_zero=only(_freegs_eval_source_ast(pe,()))
        pressure_zero==pressure_domain.exterior_pressure_pa==0.0 ||
            throw(ArgumentError("G1 exterior pressure must execute as exact zero Pa"))
    end
    ni_input_types=tf_hardware_basis===nothing ? () : (it,)
    nie=_freegs_source_edge(g3,_FREEGS_TF_SITES[1],constraint,ni_input_types,(it,))
    ce=_freegs_source_edge(g3,_FREEGS_TF_SITES[2],constraint,(it,),(ct,))
    be=_freegs_source_edge(g3,_FREEGS_TF_SITES[3],constraint,(ct,rt),(bt,))
    pe=_freegs_source_edge(g3,_FREEGS_TF_SITES[4],constraint,(),ntuple(_->vt,5))
    ue=_freegs_source_edge(g3,_FREEGS_TF_SITES[5],constraint,(),(dt,))
    # Require actual graph connectivity, not merely equal numeric values.
    node_at(bindings,k)=only(b.graph_node_index for b in bindings if b.program_position==k)
    node_at(nie.output_bindings,1)==node_at(ce.input_bindings,1) &&
        node_at(ce.output_bindings,1)==node_at(be.input_bindings,1) ||
        throw(ArgumentError("TF NI/coefficient/field graph is disconnected"))
    path=_freegs_eval_source_ast(pe,())
    all(p -> p isa Tuple && length(p)==3 && p[1]>0 && p[2]==0.0,path) && path[1]==path[end] ||
        throw(ArgumentError("TF poloidal current path is not explicitly closed in the RZ plane"))
    rs=sort(unique(p[1] for p in path)); zs=sort(unique(p[3] for p in path))
    length(rs)==2 && length(zs)==2 || throw(ArgumentError("TF source requires a nondegenerate rectangular closed path"))
    rlo,rhi=rs; zlo,zhi=zs
    forward=((rlo,0.0,zlo),(rlo,0.0,zhi),(rhi,0.0,zhi),(rhi,0.0,zlo),(rlo,0.0,zlo))
    direction=path==forward ? 1.0 : path==reverse(forward) ? -1.0 :
        throw(ArgumentError("TF winding has unsupported path order or crossing"))
    density=only(_freegs_eval_source_ast(ue,()))
    isapprox(2pi*density,1.0;rtol=32eps(Float64),atol=0.0) ||
        throw(ArgumentError("TF source is not a uniform normalized toroidal distribution"))
    rlo<domain.r_min_m<domain.r_max_m<rhi && zlo<domain.z_min_m<domain.z_max_m<zhi ||
        throw(ArgumentError("actual FreeGS domain is not strictly inside the closed TF winding"))
    if tf_hardware_basis===nothing
        current_A===nothing || throw(ArgumentError("current_A requires a TF hardware basis"))
        declared_NI=_freegs_finite(only(_freegs_eval_source_ast(nie,())),"authored NI A-turn")
        NI=NI_A_turn===nothing ? declared_NI : _freegs_finite(NI_A_turn,"changing TF NI A-turn")
    else
        NI_A_turn===nothing || throw(ArgumentError("NI_A_turn override is disallowed for the hardware current AST"))
        current= current_A===nothing ? tf_hardware_basis.current_seed_A :
            _freegs_finite(current_A,"TF conductor current A";positive=true)
        declared_NI=_freegs_finite(only(_freegs_eval_source_ast(nie,(current,))),"authored NI A-turn")
        effective_turns=Base.Checked.checked_mul(tf_hardware_basis.coil_count,
            tf_hardware_basis.turns_per_coil)
        expected_NI=_freegs_finite(Float64(effective_turns)*current,"hardware-mapped NI A-turn";positive=true)
        isapprox(declared_NI,expected_NI;rtol=64eps(Float64),atol=0.0) ||
            throw(ArgumentError("G3 hardware current AST differs from its bound count/turn metadata"))
        NI=declared_NI
    end
    C=direction*_freegs_finite(only(_freegs_eval_source_ast(ce,(NI,))),"authored TF coefficient")
    expected=direction*_FREEGS_SOURCE_MU0*NI/(2pi)
    isapprox(C,expected;rtol=64eps(Float64),atol=0.0) ||
        throw(ArgumentError("executed TF coefficient differs from Ampere law"))
    points=Tuple(sample_RZ)
    field_program=nothing
    fields=Tuple(begin
        length(p)==2 && all(v -> v isa Real && !(v isa Bool) && isfinite(v),p) &&
            domain.r_min_m<=p[1]<=domain.r_max_m && domain.z_min_m<=p[2]<=domain.z_max_m ||
            throw(ArgumentError("TF sample is outside the candidate domain"))
        field_program===nothing && (field_program=_freegs_validate_source_ast(be))
        B=_freegs_finite(only(_freegs_eval_source_program(field_program,(C,p[1]))),"authored TF field")
        isapprox(B,expected/p[1];rtol=64eps(Float64),atol=0.0) ||
            throw(ArgumentError("executed TF field differs from Ampere law"))
        B
    end for p in points)
    base_values=(status=:evaluated_authored_G1_G3_sources,K_cylindrical_A_per_m=K,boundary_node_id=only(scopes),
        declared_NI_A_turn=declared_NI,NI_A_turn=NI,vacuum_f_tm=C,TF_Bphi_T=fields,
        TF_dBphi_dNI_T_per_A=Tuple(direction*_FREEGS_SOURCE_MU0/(2pi*p[1]) for p in points),
        mu0_N_per_A2=_FREEGS_SOURCE_MU0,closed_path_m=path,winding_orientation=direction,
        uniform_toroidal_density=density,coordinates_RZ_m=points,
        g1_program_hash=string(ke.program_hash),g3_program_hashes=Tuple(string(e.program_hash) for e in (nie,ce,be,pe,ue)),
        g1_edge=ke,TF_coefficient_edge=ce,TF_field_edge=be,
        domain_RZ_m=(domain.r_min_m,domain.r_max_m,domain.z_min_m,domain.z_max_m),
        mechanism_hash=string(mechanism_hash(mechanism)),realization_hash=string(realization_control_hash(realization)),
        pressure_domain=pressure_domain,exterior_pressure_Pa=pressure_zero,
        pressure_domain_declaration_status=pressure_domain===nothing ? :typed_absent : :authored_law_only,
        pressure_domain_geometry_map_status=pressure_domain===nothing ? :typed_absent : :typed_absent,
        pressure_domain_consumer_status=pressure_domain===nothing ? :typed_absent : :not_executed,
        model_scope=pressure_domain===nothing ?
            :authored_finite_volume_plasma_no_delta_sheet_closed_distributed_TF :
            :authored_LCFS_bounded_plasma_and_zero_pressure_exterior_no_delta_sheet_closed_TF,
        TF_is_internal_plasma_total_Bphi=false,physical_validation=false,engineering_validation=false)
    tf_hardware_basis===nothing ? base_values :
        merge(base_values,(TF_NI_edge=nie,tf_hardware_basis=tf_hardware_basis))
end

"Reexecute the declared graph programs at current NI and actual sample radii."
function evaluate_freegs_authored_sources(values;sample_RZ,NI_A_turn=nothing,current_A=nothing,
        source_only_R_m=())
    values.status===:evaluated_authored_G1_G3_sources || return values
    K=only(_freegs_eval_source_ast(values.g1_edge,()))
    K==values.K_cylindrical_A_per_m && all(==(0.0),K) ||
        throw(ArgumentError("executed G1 no-sheet source changed"))
    basis=hasproperty(values,:tf_hardware_basis) ? values.tf_hardware_basis : nothing
    if basis===nothing
        current_A===nothing || throw(ArgumentError("current_A requires a TF hardware basis"))
        NI=NI_A_turn===nothing ? values.declared_NI_A_turn : _freegs_finite(NI_A_turn,"changing TF NI")
        effective_turns=nothing
        source_current=nothing
    else
        NI_A_turn===nothing || throw(ArgumentError("NI_A_turn override is disallowed for the hardware current AST"))
        _freegs_validate_tf_hardware_programs(_freegs_validate_source_ast(values.TF_NI_edge),
            _freegs_validate_source_ast(values.TF_coefficient_edge),
            _freegs_validate_source_ast(values.TF_field_edge),basis)
        source_current=current_A===nothing ? basis.current_seed_A :
            _freegs_finite(current_A,"TF conductor current A";positive=true)
        NI=only(_freegs_eval_source_ast(values.TF_NI_edge,(source_current,)))
        effective_turns=Base.Checked.checked_mul(basis.coil_count,basis.turns_per_coil)
        expected_NI=_freegs_finite(Float64(effective_turns)*source_current,
            "hardware-mapped NI A-turn";positive=true)
        isapprox(NI,expected_NI;rtol=64eps(Float64),atol=0.0) ||
            throw(ArgumentError("G3 hardware current AST differs from its bound count/turn metadata"))
    end
    C=values.winding_orientation*only(_freegs_eval_source_ast(values.TF_coefficient_edge,(NI,)))
    expected=values.winding_orientation*values.mu0_N_per_A2*NI/(2pi)
    isapprox(C,expected;rtol=64eps(Float64),atol=0.0) || throw(ArgumentError("changing TF coefficient violates Ampere law"))
    lo,hi,zlo,zhi=values.domain_RZ_m; pts=Tuple(sample_RZ)
    field_program=nothing
    B=Tuple(begin
        length(p)==2 && all(v->v isa Real && !(v isa Bool) && isfinite(v),p) &&
            lo<=p[1]<=hi && zlo<=p[2]<=zhi || throw(ArgumentError("changing TF sample outside candidate domain"))
        field_program===nothing && (field_program=_freegs_validate_source_ast(values.TF_field_edge))
        result=only(_freegs_eval_source_program(field_program,(C,p[1])))
        isapprox(result,expected/p[1];rtol=64eps(Float64),atol=0.0) || throw(ArgumentError("changing TF field violates Ampere law"))
        Float64(result)
    end for p in pts)
    source_radii=Tuple(_freegs_finite(r,"source-only TF radius m";positive=true) for r in source_only_R_m)
    source_B=Tuple(begin
        field_program===nothing && (field_program=_freegs_validate_source_ast(values.TF_field_edge))
        result=_freegs_finite(only(_freegs_eval_source_program(field_program,(C,R))),"source-only TF Bphi T")
        isapprox(result,values.winding_orientation*values.mu0_N_per_A2*NI/(2pi*R);
            rtol=64eps(Float64),atol=0.0) || throw(ArgumentError("source-only TF field differs from authored AST"))
        result
    end for R in source_radii)
    fixture_R_range=basis===nothing ? nothing :
        (minimum(p[1] for p in values.closed_path_m),maximum(p[1] for p in values.closed_path_m))
    source_outside=basis===nothing ? () : Tuple(!(fixture_R_range[1]<=R<=fixture_R_range[2]) for R in source_radii)
    dB_dI=basis===nothing ? () : Tuple(values.winding_orientation*values.mu0_N_per_A2*
        effective_turns/(2pi*R) for R in source_radii)
    base_result=(status=:evaluated_authored_G1_G3_sources,K_cylindrical_A_per_m=K,NI_A_turn=NI,
        vacuum_f_tm=C,TF_Bphi_T=B,TF_dBphi_dNI_T_per_A=Tuple(values.winding_orientation*values.mu0_N_per_A2/(2pi*p[1]) for p in pts),
        g1_program_hash=values.g1_program_hash,g3_program_hashes=values.g3_program_hashes,
        model_scope=values.model_scope,TF_is_internal_plasma_total_Bphi=false,
        physical_validation=false,engineering_validation=false)
    basis===nothing ? base_result : merge(base_result,
        (current_A=source_current,effective_turns=effective_turns,
         source_only_R_m=source_radii,source_only_Bphi_T=source_B,
         source_only_dBphi_dI_T_per_A=dB_dI,
         sensitivity_method=:known_graph_analytic_derivative,
         tf_hardware_basis=basis,
         source_only_g2_geometry=:typed_absent,source_only_polarity=:typed_absent,
         source_only_plasma_total_Bphi=:typed_absent,
         source_only_evaluation_kind=Tuple(outside ? :algebraic_source_law_extrapolation :
             :authored_source_law_evaluation for outside in source_outside),
         source_only_geometry_validity=:typed_absent,
         fixture_winding_R_range_m=fixture_R_range,
         source_R_outside_fixture_winding=source_outside))
end

"""One unweighted Gauss-Newton screen step for the authored TF source magnitude.

The forward H is evaluated by the existing G3 coefficient/field AST. No solver
Bphi, sign, G2 pack geometry, uncertainty, or acceptance tolerance is inferred.
"""
function freegs_authored_tf_source_inverse_step(values;initial_current_A,
        R0_m=nothing,B0_T=nothing)
    basis=values.tf_hardware_basis
    basis isa FreeGSTFHardwareBasisV1 ||
        throw(ArgumentError("TF inverse step requires its bound hardware basis"))
    R=R0_m===nothing ? basis.R0_m : _freegs_finite(R0_m,"TF inverse R0 m";positive=true)
    target=B0_T===nothing ? basis.B0_T : _freegs_finite(B0_T,"TF inverse target B0 T";positive=true)
    R==basis.R0_m && target==basis.B0_T ||
        throw(ArgumentError("TF inverse R0/B0 differs from the bound design source"))
    I0=_freegs_finite(initial_current_A,"TF inverse current A";positive=true)
    evaluate(I)=evaluate_freegs_authored_sources(values;sample_RZ=(),current_A=I,
        source_only_R_m=(R,))
    first=evaluate(I0)
    H0=abs(only(first.source_only_Bphi_T))
    slope=abs(only(first.source_only_dBphi_dI_T_per_A))
    residual=H0-target
    objective=residual^2
    gradient=2residual*slope
    hessian_gn=2slope^2
    hessian_gn>0 && isfinite(hessian_gn) ||
        throw(ArgumentError("TF inverse source Jacobian is singular"))
    step=-gradient/hessian_gn
    I1=_freegs_finite(I0+step,"TF inverse updated current A";positive=true)
    second=evaluate(I1)
    H1=abs(only(second.source_only_Bphi_T))
    (status=:screen_only,reason=:one_unweighted_gauss_newton_source_magnitude_step,
     claim_ceiling=:screen_only,R0_m=R,B0_target_T=target,
     current_initial_A=I0,H_initial_T=H0,residual_initial_T=residual,
     objective_initial_T2=objective,gradient_initial_T2_per_A=gradient,
     jacobian_abs_T_per_A=slope,sensitivity_method=:known_graph_analytic_derivative,
     gauss_newton_step_A=step,
     current_updated_A=I1,H_updated_T=H1,residual_updated_T=H1-target,
     objective_unit=:T2,uncertainty=:typed_absent,tolerance=:not_declared,
     hardware_current_constraint=:typed_absent,
     exposed_current_reference_A=basis.published_current_reference_A,
     exposed_current_delta_A=I1-basis.published_current_reference_A,
     exposed_current_relative_delta=I1/basis.published_current_reference_A-1.0,
     current_reference_use=:exposed_consistency_only_not_blind_holdout,
     polarity=:typed_absent,G2_pack_geometry=:typed_absent,
     plasma_total_Bphi=:typed_absent,
     source_evaluation_kind=only(first.source_only_evaluation_kind),
     geometry_validity=first.source_only_geometry_validity,
     fixture_winding_R_range_m=first.fixture_winding_R_range_m,
     source_R_outside_fixture_winding=only(first.source_R_outside_fixture_winding),
     model_scope=:toroidally_averaged_external_TF_source_magnitude_only,
     source_refs=(basis.coil_count_source_ref,basis.turns_source_ref,
        basis.current_source_ref,basis.field_source_ref),
     g3_program_hashes=values.g3_program_hashes)
end

function freegs_axisymmetric_authored_source_values(context;sample_RZ=(),NI_A_turn=nothing,
        current_A=nothing)
    validate_forward_chain_context(context)
    binding=_freegs_context_binding(context)
    pressure_domain=_freegs_owned_pressure_domain(context.candidate)
    value=_freegs_authored_source_values(context.candidate.mechanism_genome_ref,
        context.candidate.realization_control_genome_ref,binding.declaration.domain;sample_RZ,NI_A_turn,
        pressure_domain=pressure_domain,current_A)
    merge(value,(candidate_hash=string(context.candidate_hash),context_hash=string(context.context_hash)))
end

"Build new G1/G3 values using the existing generic structures, without mutating old values."
function build_freegs_authored_source_genomes(mechanism,realization,domain;
        NI_scale=1.0,sheet_value=(0.0,0.0,0.0),sheet_unit=_FREEGS_SOURCE_UNITS.sheet,
        pressure_domain=nothing,tf_hardware_basis=nothing,
        path=((0.08,0.0,-1.2),(0.08,0.0,1.2),(2.1,0.0,1.2),(2.1,0.0,-1.2),(0.08,0.0,-1.2)))
    pressure_domain===nothing || pressure_domain isa AxisymmetricPressureDomainV1 ||
        throw(ArgumentError("pressure_domain must be an authored AxisymmetricPressureDomainV1"))
    tf_hardware_basis===nothing || tf_hardware_basis isa FreeGSTFHardwareBasisV1 ||
        throw(ArgumentError("tf_hardware_basis must be FreeGSTFHardwareBasisV1 or nothing"))
    reg=default_operator_registry(); u=_FREEGS_SOURCE_UNITS
    scalar(unit)=_freegs_source_type(unit)
    constant(value,type)=ASTConstantV1(value,type)
    function apply(nodes,id,inputs)
        ASTApplyV1(OperatorRefV1(id,"v1"),inputs,(;);registry=reg,
            input_types=Tuple(nodes[i].output_type for i in inputs))
    end
    kt=_freegs_source_type(sheet_unit;rank=1)
    kp=TypedASTProgramV1((ASTConstantV1(:constant,sheet_value,kt,
        (boundary_node_id=_FREEGS_LCFS_NODE,)),),(1,),();registry=reg)
    payload=mechanism.payload; oldgraph=payload.operator_graph; kindex=length(oldgraph.nodes)+1
    kg=node(:state,kt;id="authored-LCFS-K-source")
    ke=AtomicMIMOHyperedgeV1(_FREEGS_K_SITE,(),(MIMOOutputBindingV1(1,kindex),),kp,constraint;registry=reg)
    g1_nodes=(kg,);g1_edges=(ke,)
    kstate=StateGeneV1(StateGeneRefV1(kg.node_id),kt,
        QuantityIntervalV1(ExactFiniteIntervalV1(-1,1,false),sheet_unit),(),(),
        (ConstraintRefV1(_FREEGS_K_SITE),),state_derived)
    authored_states=(kstate,)
    if pressure_domain!==nothing
        pt=_freegs_source_type(_FREEGS_SOURCE_UNITS.pressure)
        pindex=length(oldgraph.nodes)+length(g1_nodes)+1
        pvnode=node(:state,pt;id="authored-vacuum-exterior-pressure-zero")
        parameters=(pressure_domain_id=string(canonical_hash(pressure_domain)),
            region_node_id=pressure_domain.vacuum_region_id,
            interface_node_id=pressure_domain.interface_node_id,
            boundary_node_id=pressure_domain.boundary_node_id,
            classification_rule=pressure_domain.classification_rule,
            open_flux_policy=pressure_domain.open_flux_policy)
        pprogram=TypedASTProgramV1((ASTConstantV1(:constant,
            pressure_domain.exterior_pressure_pa,pt,parameters),),(1,),();registry=reg)
        pve=AtomicMIMOHyperedgeV1(_FREEGS_PRESSURE_VACUUM_SITE,(),
            (MIMOOutputBindingV1(1,pindex),),pprogram,constraint;registry=reg)
        g1_nodes=(g1_nodes...,pvnode);g1_edges=(g1_edges...,pve)
        pvstate=StateGeneV1(StateGeneRefV1(pvnode.node_id),pt,
            QuantityIntervalV1(ExactFiniteIntervalV1(0,0,true),_FREEGS_SOURCE_UNITS.pressure),(),(),
            (ConstraintRefV1(_FREEGS_PRESSURE_VACUUM_SITE),),state_derived)
        authored_states=(authored_states...,pvstate)
    end
    graph=TypedOperatorHypergraphV1((oldgraph.nodes...,g1_nodes...),
        (oldgraph.hyperedges...,g1_edges...);registry=reg)
    newpayload=MechanismGenomePayloadV1((payload.states...,authored_states...),payload.invariants,graph,
        payload.parameters,payload.symmetries,payload.observables,payload.operator_holes)
    newmechanism=MechanismGenomeV4(mechanism.seed+101,mechanism.contract_ref,newpayload)
    # Historical fixtures derive NI from a normalized 1 T m scale. The
    # optional hardware path instead maps a declared unknown conductor current
    # through official turns/count constants inside the G3 AST.
    ni_input_bindings=()
    if tf_hardware_basis===nothing
        nodes=(constant(1.0,scalar(u.coefficient)),constant(2pi,scalar(u.dimensionless)),
            constant(_FREEGS_SOURCE_MU0,scalar(u.permeability)),constant(_freegs_finite(NI_scale,"NI scale"),scalar(u.dimensionless)))
        nodes=(nodes...,apply(nodes,"SCALAR_MUL",(1,2)))
        nodes=(nodes...,apply(nodes,"SCALAR_DIV",(5,3)))
        nodes=(nodes...,apply(nodes,"SCALAR_MUL",(6,4)))
        nip=TypedASTProgramV1(nodes,(7,),();registry=reg)
    else
        current_type=scalar(u.current); dimensionless_type=scalar(u.dimensionless)
        current_input=ASTInputV1(1,current_type,(role=:unknown_tf_conductor_current_A,
            unit=:A,polarity=:typed_absent))
        turns_constant=ASTConstantV1(:constant,Float64(tf_hardware_basis.turns_per_coil),
            dimensionless_type,(role=:turns_per_coil,
                source_ref=tf_hardware_basis.turns_source_ref,unit=:turn_count))
        coil_constant=ASTConstantV1(:constant,Float64(tf_hardware_basis.coil_count),
            dimensionless_type,(role=:coil_count,
                source_ref=tf_hardware_basis.coil_count_source_ref,unit=:coil_count))
        nodes=(current_input,turns_constant,coil_constant)
        nodes=(nodes...,apply(nodes,"SCALAR_MUL",(1,2)))
        nodes=(nodes...,apply(nodes,"SCALAR_MUL",(4,3)))
        nip=TypedASTProgramV1(nodes,(5,),(1,);registry=reg)
        ni_input_bindings=(MIMOInputBindingV1(1,1),)
    end
    nodes=(ASTInputV1(1,scalar(u.current)),constant(_FREEGS_SOURCE_MU0,scalar(u.permeability)),constant(2pi,scalar(u.dimensionless)))
    nodes=(nodes...,apply(nodes,"SCALAR_MUL",(1,2)))
    nodes=(nodes...,apply(nodes,"SCALAR_DIV",(4,3)))
    cp=TypedASTProgramV1(nodes,(5,),(1,);registry=reg)
    nodes=(ASTInputV1(1,scalar(u.coefficient)),ASTInputV1(2,scalar(u.length)))
    nodes=(nodes...,apply(nodes,"SCALAR_DIV",(1,2)))
    bp=TypedASTProgramV1(nodes,(3,),(1,2);registry=reg)
    vt=_freegs_source_type(u.length;rank=1)
    pp=TypedASTProgramV1(Tuple(constant(p,vt) for p in path),Tuple(1:length(path)),();registry=reg)
    up=TypedASTProgramV1((constant(1/(2pi),scalar(u.dimensionless)),),(1,),();registry=reg)
    # The graph itself binds NI -> coefficient -> Bphi; R is the physical sample input.
    gn=tf_hardware_basis===nothing ?
        (node(:source,scalar(u.current);id="authored-TF-NI"),
         node(:source,scalar(u.coefficient);id="authored-TF-C"),node(:parameter,scalar(u.length);id="authored-TF-R"),
         node(:field,scalar(u.magnetic);id="authored-TF-Bphi"),
         (node(:geometry,vt;id="authored-TF-vertex-$i") for i in 1:length(path))...,
         node(:source,scalar(u.dimensionless);id="authored-TF-angular-density")) :
        (node(:parameter,scalar(u.current);id="iter-tf-unknown-conductor-current-A"),
         node(:source,scalar(u.current);id="authored-TF-NI"),
         node(:source,scalar(u.coefficient);id="authored-TF-C"),node(:parameter,scalar(u.length);id="authored-TF-R"),
         node(:field,scalar(u.magnetic);id="authored-TF-Bphi"),
         (node(:geometry,vt;id="authored-TF-vertex-$i") for i in 1:length(path))...,
         node(:source,scalar(u.dimensionless);id="authored-TF-angular-density"))
    ge=(AtomicMIMOHyperedgeV1(_FREEGS_TF_SITES[1],ni_input_bindings,(MIMOOutputBindingV1(1,tf_hardware_basis===nothing ? 1 : 2),),nip,constraint;registry=reg),
        AtomicMIMOHyperedgeV1(_FREEGS_TF_SITES[2],(MIMOInputBindingV1(1,tf_hardware_basis===nothing ? 1 : 2),),(MIMOOutputBindingV1(1,tf_hardware_basis===nothing ? 2 : 3),),cp,constraint;registry=reg),
        AtomicMIMOHyperedgeV1(_FREEGS_TF_SITES[3],(MIMOInputBindingV1(1,tf_hardware_basis===nothing ? 2 : 3),MIMOInputBindingV1(2,tf_hardware_basis===nothing ? 3 : 4)),(MIMOOutputBindingV1(1,tf_hardware_basis===nothing ? 4 : 5),),bp,constraint;registry=reg),
        AtomicMIMOHyperedgeV1(_FREEGS_TF_SITES[4],(),Tuple(MIMOOutputBindingV1(i,(tf_hardware_basis===nothing ? 4 : 5)+i) for i in 1:length(path)),pp,constraint;registry=reg),
        AtomicMIMOHyperedgeV1(_FREEGS_TF_SITES[5],(),(MIMOOutputBindingV1(1,length(gn)),),up,constraint;registry=reg))
    realization_payload=tf_hardware_basis===nothing ? realization.realization :
        (realization.realization...,semantic_view(tf_hardware_basis))
    newrealization=RealizationControlGenomeV4(realization.seed+101,realization.control_seed+101,
        realization.contract_ref,TypedOperatorHypergraphV1(gn,ge;registry=reg),realization.control_graph;
        realization=realization_payload,control=realization.control)
    values=_freegs_authored_source_values(newmechanism,newrealization,domain;
        sample_RZ=((domain.r_min_m,domain.z_min_m),(domain.r_max_m,domain.z_max_m)),
        pressure_domain=pressure_domain,tf_hardware_basis=tf_hardware_basis,
        current_A=tf_hardware_basis===nothing ? nothing : tf_hardware_basis.current_seed_A)
    base_genomes=(mechanism=newmechanism,realization=newrealization,values=values)
    tf_hardware_basis===nothing ? base_genomes :
        merge(base_genomes,(tf_hardware_basis=tf_hardware_basis,))
end


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
    declaration=only(matches)
    _freegs_validate_outer_face_graph(candidate,declaration.outer_face_map,declaration.domain)
    declaration
end

function _freegs_validate_outer_face_graph(candidate,map,domain)
    map===nothing && return :typed_absent
    map isa AxisymmetricG2OuterFaceMapV1 || throw(ArgumentError("G2 outer face map is not typed"))
    _validate_freegs_outer_face_map(map,domain)
    graph=candidate.field_geometry_genome_ref.graph
    string(canonical_hash(graph))==map.field_geometry_graph_hash ||
        throw(ArgumentError("G2 outer face map is stale for this field geometry graph"))
    for face_id in unique(map.face_node_ids)
        face_id==_FREEGS_LCFS_NODE &&
            throw(ArgumentError("the G2 LCFS cannot be reused as the computational outer face"))
        matches=Tuple(node for node in graph.nodes if node.node_id==face_id)
        length(matches)==1 && only(matches).node_kind===:boundary &&
            only(matches).physical_type==_freegs_source_type(_FREEGS_SOURCE_UNITS.length;rank=1) ||
            throw(ArgumentError("declared outer face identity is not an exact typed G2 boundary node: $face_id"))
    end
    map.map_hash
end

function _freegs_owned_pressure_domain(candidate)
    fields=candidate.field_geometry_genome_ref.fields
    domains=Tuple(field for field in fields if field isa AxisymmetricPressureDomainV1)
    length(domains)<=1 || throw(ArgumentError("G2 has ambiguous authored pressure domains"))
    has_source=any(edge->edge.edge_id==_FREEGS_PRESSURE_VACUUM_SITE,
        candidate.mechanism_genome_ref.payload.operator_graph.hyperedges)
    has_source==(length(domains)==1) ||
        throw(ArgumentError("authored vacuum-pressure source/domain declaration presence differs"))
    isempty(domains) && return nothing
    domain=only(domains)
    graph=candidate.field_geometry_genome_ref.graph
    expected=((domain.plasma_region_id,:region,_freegs_source_type(_FREEGS_SOURCE_UNITS.pressure)),
        (domain.vacuum_region_id,:region,_freegs_source_type(_FREEGS_SOURCE_UNITS.pressure)),
        (domain.interface_node_id,:interface,_freegs_source_type(_FREEGS_SOURCE_UNITS.length;rank=1)),
        (domain.boundary_node_id,:boundary,_freegs_source_type(_FREEGS_SOURCE_UNITS.length;rank=1)))
    for (id,kind,physical_type) in expected
        matches=Tuple(n for n in graph.nodes if n.node_id==id)
        length(matches)==1 && only(matches).node_kind===kind &&
            only(matches).physical_type==physical_type ||
            throw(ArgumentError("authored pressure domain lacks its exact typed G2 node: $id"))
    end
    domain
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
    pressure_domain=_freegs_owned_pressure_domain(context.candidate)
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
    authored=_freegs_authored_source_values(context.candidate.mechanism_genome_ref,
        context.candidate.realization_control_genome_ref,binding.declaration.domain;
        pressure_domain=pressure_domain)
    if authored.status===:evaluated_authored_G1_G3_sources
        boundary_nodes=Tuple(n for n in context.candidate.field_geometry_genome_ref.graph.nodes
            if n.node_id==authored.boundary_node_id && n.node_kind===:boundary)
        length(boundary_nodes)==1 && only(boundary_nodes).physical_type==
            _freegs_source_type(_FREEGS_SOURCE_UNITS.length;rank=1) ||
            throw(ArgumentError("authored G1 no-sheet law does not resolve to the actual G2 LCFS boundary"))
        isapprox(binding.declaration.profile.vacuum_f_tm,authored.vacuum_f_tm;
            rtol=64eps(Float64),atol=0.0) ||
            throw(ArgumentError("FreeGS vacuum F input differs from executed G3 TF current source"))
    end
    binding
end

function _freegs_sample_points(points, domain::AxisymmetricDomainV4)
    (points isa Tuple || points isa AbstractVector) ||
        throw(ArgumentError("sample_points_rz_m must be a tuple or vector of (R,Z) points"))
    Tuple(begin
        (point isa Tuple || point isa AbstractVector) && length(point) == 2 ||
            throw(ArgumentError("each sample point must contain exactly (R,Z)"))
        R = _freegs_finite(point[1], "sample R_m"; positive=true)
        Z = _freegs_finite(point[2], "sample Z_m")
        domain.r_min_m <= R <= domain.r_max_m && domain.z_min_m <= Z <= domain.z_max_m ||
            throw(ArgumentError("sample point lies outside the declared (R,Z) domain"))
        (R, Z)
    end for point in points)
end

function _freegs_solver_payload(binding::AxisymmetricEquilibriumBindingV4;
        sample_points_rz_m=(), sample_constitutive_fields::Bool=false,
        sample_lcfs_trace::Bool=false, coil_current_mode::Symbol=:shape_controlled,
        fixed_coil_currents_A_per_turn=(), capture_control_result::Bool=false,
        initial_plasma_psi_wb_per_rad=nothing, state_sample_time_s=nothing)
    d = binding.declaration
    profile_payload=(kind="ConstrainPaxisIp", axis_pressure_pa=d.profile.axis_pressure_pa,
              plasma_current_a=d.profile.plasma_current_a,
              vacuum_f_tm=d.profile.vacuum_f_tm, alpha_m=d.profile.alpha_m,
              alpha_n=d.profile.alpha_n,
              profile_axis_radius_m=d.profile.profile_axis_radius_m)
    if d.profile.critical_point_refinement!==:freegs_native_v1
        profile_payload=merge(profile_payload,
            (critical_point_refinement=String(d.profile.critical_point_refinement),))
    end
    coil_rows = Tuple((id=c.coil_id, major_radius_m=c.major_radius_m,
                       vertical_position_m=c.vertical_position_m) for c in d.coils)
    coil_current_mode in (:shape_controlled,:fixed_current_forward) ||
        throw(ArgumentError("unsupported FreeGS coil current mode"))
    if coil_current_mode===:fixed_current_forward
        rows=Tuple(fixed_coil_currents_A_per_turn)
        length(rows)==length(d.coils) ||
            throw(ArgumentError("fixed current forward mode requires one current for every declared coil"))
        Tuple(String(row[1]) for row in rows)==Tuple(c.coil_id for c in d.coils) ||
            throw(ArgumentError("fixed current order/IDs must match declared coils"))
        coil_rows=Tuple(merge(coil_rows[i],
            (current_A_per_turn=_freegs_finite(rows[i][2],"fixed coil current A per turn"),))
            for i in eachindex(coil_rows))
    elseif !isempty(fixed_coil_currents_A_per_turn)
        throw(ArgumentError("fixed coil currents are valid only in fixed_current_forward mode"))
    end
    constraints_payload = (xpoints_m=d.constraints.xpoints_m,
                           isoflux_m=d.constraints.isoflux_m,
                           gamma=d.constraints.tikhonov_gamma)
    if d.constraints.current_lims_A_per_turn!==nothing
        constraints_payload=merge(constraints_payload,
            (current_lims_A_per_turn=d.constraints.current_lims_A_per_turn,))
    end
    if d.constraints.max_total_current_A!==nothing
        constraints_payload=merge(constraints_payload,
            (max_total_current_A=d.constraints.max_total_current_A,))
    end
    payload = (machine=(kind="explicit_filament_coils", coils=coil_rows),
      domain=(r_min_m=d.domain.r_min_m, r_max_m=d.domain.r_max_m,
              z_min_m=d.domain.z_min_m, z_max_m=d.domain.z_max_m,
              nx=d.domain.nx, ny=d.domain.ny, boundary="freeBoundaryHagenow"),
      profile=profile_payload,
      constraints=constraints_payload,
      solver=(rtol=d.solver.rtol, atol=d.solver.atol,
              max_iterations=d.solver.max_iterations))
    if state_sample_time_s !== nothing
        time_s=_freegs_finite(state_sample_time_s,"state_sample_time_s")
        payload=merge(payload,(state_sample_time_s=time_s,))
    end
    topology=_freegs_plasma_current_topology_body(d.current_topology,d.return_current_path)
    payload=topology===nothing ? payload : merge(payload,(plasma_current_topology=topology,))
    payload=coil_current_mode===:shape_controlled ? payload :
        merge(payload,(coil_current_mode=String(coil_current_mode),))
    limits_present = d.constraints.current_lims_A_per_turn !== nothing ||
        d.constraints.max_total_current_A !== nothing
    if coil_current_mode===:shape_controlled && (capture_control_result || limits_present)
        payload=merge(payload,(capture_control_result=true,))
    end
    if initial_plasma_psi_wb_per_rad!==nothing
        coil_current_mode===:fixed_current_forward ||
            throw(ArgumentError("initial plasma psi is valid only in fixed-current forward mode"))
        psi=initial_plasma_psi_wb_per_rad
        rows = if psi isa AbstractMatrix
            size(psi)==(d.domain.nx,d.domain.ny) ||
                throw(ArgumentError("initial plasma psi shape must match the declared [R_index][Z_index] grid"))
            (Tuple(psi[i,j] for j in 1:d.domain.ny) for i in 1:d.domain.nx)
        elseif (psi isa Tuple || psi isa AbstractVector) && length(psi)==d.domain.nx &&
                all(row->(row isa Tuple || row isa AbstractVector) && length(row)==d.domain.ny,psi)
            psi
        else
            throw(ArgumentError("initial plasma psi shape must match the declared [R_index][Z_index] grid"))
        end
        matrix=Tuple(Tuple(_freegs_finite(v,"initial plasma psi") for v in row) for row in rows)
        payload=merge(payload,(initial_plasma_psi_wb_per_rad=matrix,))
    end
    samples = _freegs_sample_points(sample_points_rz_m, d.domain)
    sample_constitutive_fields && isempty(samples) &&
        throw(ArgumentError("constitutive sampling requires sample_points_rz_m"))
    payload = isempty(samples) ? payload : merge(payload, (sample_points_rz_m=samples,))
    payload = sample_constitutive_fields ? merge(payload, (sample_constitutive_fields=true,)) : payload
    sample_lcfs_trace ? merge(payload, (sample_lcfs_trace=true,)) : payload
end

"""Select only typed AST objects eligible for canonical payload reuse."""
function _freegs_context_ast_payload_targets(context::ForwardChainContextV4)
    Tuple(edge.program for genome_binding in context.genome_bindings
        for graph_binding in genome_binding.graph_bindings
        for edge in graph_binding.graph.hyperedges
        if typeof(edge) === AtomicMIMOHyperedgeV1)
end

function _freegs_with_context_ast_payload_memo(f::Function,
        context::ForwardChainContextV4)
    ast_programs = _freegs_context_ast_payload_targets(context)
    isempty(ast_programs) && return f()
    # Context, graph, identity, source, and validation values remain live; only
    # canonical projections of these exact immutable ASTs may be reused.
    FusionConceptAI._with_canonical_json_memo(ast_programs;
            payload_targets=ast_programs) do
        f()
    end
end

"""Create the canonical JSON ABI solely from the revalidated subject binding."""
function freegs_axisymmetric_solver_input(context::ForwardChainContextV4;
        sample_points_rz_m=(), sample_constitutive_fields::Bool=false,
        sample_lcfs_trace::Bool=false, coil_current_mode::Symbol=:shape_controlled,
        fixed_coil_currents_A_per_turn=(), capture_control_result::Bool=false,
        initial_plasma_psi_wb_per_rad=nothing, state_sample_time_s=nothing,
        mastu_source_adapter_report_path=nothing)
    _freegs_with_context_ast_payload_memo(context) do
        _freegs_axisymmetric_solver_input_uncached(context;
            sample_points_rz_m=sample_points_rz_m,
            sample_constitutive_fields=sample_constitutive_fields,
            sample_lcfs_trace=sample_lcfs_trace,
            coil_current_mode=coil_current_mode,
            fixed_coil_currents_A_per_turn=fixed_coil_currents_A_per_turn,
            capture_control_result=capture_control_result,
            initial_plasma_psi_wb_per_rad=initial_plasma_psi_wb_per_rad,
            state_sample_time_s=state_sample_time_s,
            mastu_source_adapter_report_path=mastu_source_adapter_report_path)
    end
end

function _freegs_axisymmetric_solver_input_uncached(context::ForwardChainContextV4;
        sample_points_rz_m=(), sample_constitutive_fields::Bool=false,
        sample_lcfs_trace::Bool=false, coil_current_mode::Symbol=:shape_controlled,
        fixed_coil_currents_A_per_turn=(), capture_control_result::Bool=false,
        initial_plasma_psi_wb_per_rad=nothing, state_sample_time_s=nothing,
        mastu_source_adapter_report_path=nothing)
    validate_forward_chain_context(context)
    binding = _freegs_context_binding(context)
    body=(schema="fusionconceptai:runtime-v4-freegs-axisymmetric-input",
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
     solver_input=_freegs_solver_payload(binding; sample_points_rz_m=sample_points_rz_m,
         sample_constitutive_fields=sample_constitutive_fields,
         sample_lcfs_trace=sample_lcfs_trace,coil_current_mode=coil_current_mode,
         fixed_coil_currents_A_per_turn=fixed_coil_currents_A_per_turn,
         capture_control_result=capture_control_result,
         initial_plasma_psi_wb_per_rad=initial_plasma_psi_wb_per_rad,
         state_sample_time_s=state_sample_time_s))
    mastu_source_adapter_report_path===nothing ? body : merge(body,
        (mastu_source_adapter=freegs_mastu_source_adapter_request_v1(
            mastu_source_adapter_report_path),))
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
    field_samples_rz_m::Tuple
    hagenow_source_response::Union{Nothing,NamedTuple}
end
FreeGSAxisymmetricExecutionArtifactsV4(receipt, input_json::String, output_json::String) =
    FreeGSAxisymmetricExecutionArtifactsV4(receipt, input_json, output_json, (), nothing)
FreeGSAxisymmetricExecutionArtifactsV4(receipt, input_json::String, output_json::String, samples) =
    FreeGSAxisymmetricExecutionArtifactsV4(receipt, input_json, output_json, samples, nothing)

"""Return currents only from a complete shape-controlled run with consumed SLSQP status."""
function freegs_optimized_coil_current_state(context::ForwardChainContextV4,
        artifacts::FreeGSAxisymmetricExecutionArtifactsV4)
    validate_freegs_axisymmetric_receipt(context,artifacts.receipt)
    receipt=artifacts.receipt
    receipt.status===:physical_model_screen && receipt.exit_code==0 &&
        !isempty(artifacts.input_json) && !isempty(artifacts.output_json) ||
        throw(ArgumentError("optimized coil handback requires an accepted complete screen receipt"))
    _freegs_sha256_text(artifacts.input_json)==receipt.input_hash ||
        throw(ArgumentError("optimized coil handback input bytes mismatch"))
    _freegs_sha256_text(artifacts.output_json)==receipt.output_hash ||
        throw(ArgumentError("optimized coil handback output bytes mismatch"))
    input=JSON3.read(artifacts.input_json)
    solver=input[:solver_input]
    String(get(solver,:coil_current_mode,"shape_controlled"))=="shape_controlled" ||
        throw(ArgumentError("optimized coil handback requires shape-controlled input"))
    get(solver,:capture_control_result,false)===true ||
        throw(ArgumentError("optimized coil handback requires opted-in SLSQP result capture"))
    output=JSON3.read(artifacts.output_json)
    String(output[:result_hash])==string(receipt.backend_result_hash) ||
        throw(ArgumentError("optimized coil handback result hash mismatch"))
    String(output[:context_hash])==string(context.context_hash) &&
        String(output[:binding_hash])==string(_freegs_context_binding(context).binding_hash) ||
        throw(ArgumentError("optimized coil handback output identity mismatch"))
    binding=_freegs_context_binding(context)
    has_current_bounds = binding.declaration.constraints.current_lims_A_per_turn !== nothing ||
        binding.declaration.constraints.max_total_current_A !== nothing
    has_current_bounds ||
        throw(ArgumentError("optimized coil handback requires declared per-coil or total-current bounds"))
    ids=Tuple(c.coil_id for c in binding.declaration.coils)
    validated=_freegs_validate_coil_control(output,"shape_controlled",ids,(),
        binding.declaration.constraints.current_lims_A_per_turn,
        binding.declaration.constraints.max_total_current_A)
    validated.status===:slsqp_success || throw(ArgumentError("optimizer status was not successful"))
    validated.coil_currents_A_per_turn
end

"""Create a fixed-current forward input from the validated optimizer handback."""
function freegs_axisymmetric_forward_input(context::ForwardChainContextV4,
        artifacts::FreeGSAxisymmetricExecutionArtifactsV4; kwargs...)
    currents=freegs_optimized_coil_current_state(context,artifacts)
    freegs_axisymmetric_solver_input(context;coil_current_mode=:fixed_current_forward,
        fixed_coil_currents_A_per_turn=currents,kwargs...)
end

"""Run the same declared evaluator with the validated optimized coil currents held fixed."""
function execute_freegs_axisymmetric_forward(context::ForwardChainContextV4,
        artifacts::FreeGSAxisymmetricExecutionArtifactsV4; kwargs...)
    currents=freegs_optimized_coil_current_state(context,artifacts)
    execute_freegs_axisymmetric_screen(context;coil_current_mode=:fixed_current_forward,
        fixed_coil_currents_A_per_turn=currents,kwargs...)
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

function _freegs_parse_constitutive(row, R, Z)
    fields = (:native_R_m, :native_Z_m, :psi_normalized, :Btor_T,
        :pressure_Pa, :Jphi_A_per_m2, :psi_native_wb_per_rad,
        :psi_axis_wb_per_rad, :psi_boundary_wb_per_rad, :core_mask,
        :pprime_Pa_per_flux, :ffprime_T2_m2_per_flux, :mu0_N_per_A2)
    row isa AbstractDict && Set(collect(keys(row))) == Set((:status, :reason, fields...)) ||
        throw(ArgumentError("controlled runner constitutive sample fields mismatch"))
    status, reason = row[:status], row[:reason]
    if status == "typed_absent"
        reason in ("not_native_grid", "core_mask_unavailable", "domain_boundary",
            "outside_supported_core", "unsupported_fvac_branch") ||
            throw(ArgumentError("controlled runner constitutive absence reason mismatch"))
        all(key -> row[key] === nothing, fields) ||
            throw(ArgumentError("absent constitutive sample cannot carry numerical values"))
        return merge((status=:typed_absent, reason=Symbol(reason)),
            NamedTuple{fields}(ntuple(_ -> nothing, length(fields))))
    end
    status == "present" && reason == "native_core_final_psi" ||
        throw(ArgumentError("controlled runner constitutive sample status mismatch"))
    values = NamedTuple{fields}(Tuple(_freegs_finite(row[key], String(key)) for key in fields))
    tol = 8eps(Float64) * max(1.0, abs(R), abs(Z))
    abs(values.native_R_m - R) <= tol && abs(values.native_Z_m - Z) <= tol ||
        throw(ArgumentError("constitutive native coordinates mismatch"))
    values.native_R_m > 0 && 0 <= values.psi_normalized <= 1 &&
        values.core_mask == 1 && values.mu0_N_per_A2 > 0 &&
        values.psi_boundary_wb_per_rad != values.psi_axis_wb_per_rad ||
        throw(ArgumentError("constitutive sample is outside its declared support"))
    merge((status=:present, reason=:native_core_final_psi), values)
end

function _freegs_parse_field_samples_document(document, requested_points;
        sample_constitutive_fields::Bool=false)
    isempty(requested_points) && return ()
    document isa AbstractDict && haskey(document, :field_samples_rz_m) ||
        throw(ArgumentError("controlled runner omitted requested RZ field samples"))
    rows = document[:field_samples_rz_m]
    rows isa AbstractVector && length(rows) == length(requested_points) ||
        throw(ArgumentError("controlled runner RZ sample count mismatch"))
    expected_keys = Set((:R_m, :Z_m, :psi_wb_per_rad, :Br_T, :Bz_T))
    sample_constitutive_fields && push!(expected_keys, :constitutive)
    Tuple(begin
        row = rows[i]
        row isa AbstractDict && Set(collect(keys(row))) == expected_keys ||
            throw(ArgumentError("controlled runner RZ sample fields mismatch"))
        expected_R, expected_Z = requested_points[i]
        R = _freegs_finite(row[:R_m], "sample R_m"; positive=true)
        Z = _freegs_finite(row[:Z_m], "sample Z_m")
        R == expected_R && Z == expected_Z ||
            throw(ArgumentError("controlled runner RZ sample coordinates mismatch"))
        psi = _freegs_finite(row[:psi_wb_per_rad], "sample psi_wb_per_rad")
        Br = _freegs_finite(row[:Br_T], "sample Br_T")
        Bz = _freegs_finite(row[:Bz_T], "sample Bz_T")
        sample = (R_m=R, Z_m=Z, psi_wb_per_rad=psi, Br_T=Br, Bz_T=Bz)
        sample_constitutive_fields ? merge(sample,
            (constitutive=_freegs_parse_constitutive(row[:constitutive], R, Z),)) : sample
    end for i in eachindex(requested_points))
end

function _freegs_parse_field_samples(output_json::String, requested_points;
        sample_constitutive_fields::Bool=false)
    isempty(requested_points) && return ()
    _freegs_parse_field_samples_document(JSON3.read(output_json), requested_points;
        sample_constitutive_fields=sample_constitutive_fields)
end


const _FREEGS_MAST_MAGPR_CHANNELS = Tuple(vcat(
    ["CCBV" * lpad(string(i), 2, '0') for i in 1:40],
    ["OBV" * lpad(string(i), 2, '0') for i in 1:19],
    ["OBR" * lpad(string(i), 2, '0') for i in 1:19]))

_freegs_sha256_literal(value, field) = begin
    text=_freegs_text(value,field)
    occursin(r"^[0-9a-f]{64}$",text) || throw(ArgumentError("$field must be lowercase SHA-256"))
    text
end

function _freegs_mast_f32_c_order_sha256(values)
    Base.ENDIAN_BOM==0x04030201 ||
        throw(ArgumentError("MAST float32 source bytes require little-endian host order"))
    source=collect(values)
    raw=collect(Float32.(source))
    all(isfinite,raw) || throw(ArgumentError("MAST float32 source values must remain finite after conversion"))
    all(Float64(raw[i])==Float64(source[i]) for i in eachindex(raw,source)) ||
        throw(ArgumentError("source values must be exactly representable as float32 before hashing"))
    bytes=Vector{UInt8}(reinterpret(UInt8,vec(raw)))
    string(_freegs_sha256_bytes(bytes))
end

function _freegs_mastu_json_tree_tuple_arrays(value)
    Base.@nospecialize value
    if value isa AbstractDict
        return Dict{String,Any}(
            String(key) => _freegs_mastu_json_tree_tuple_arrays(child)
            for (key,child) in pairs(value))
    elseif value isa AbstractVector
        return Tuple(_freegs_mastu_json_tree_tuple_arrays(child) for child in value)
    end
    value
end

"""Read the retained official shot-45425 static report for fail-closed consumer routing.

The exact index-134 arrays and name joins are carried to the current controlled
runner. They are not converted to SI coil/profile inputs because the report does
not bind those physical conventions. The runner must return a structured gap
without importing or invoking FreeGS when this adapter field is present.
"""
function freegs_mastu_source_adapter_request_v1(report_path::AbstractString)
    report_path_string=abspath(String(report_path))
    isfile(report_path_string) || throw(ArgumentError("MAST-U static report does not exist"))
    report=JSON3.read(read(report_path_string,String))
    get(report,:stage,nothing)=="STATIC_PARSE_COMPLETED" ||
        throw(ArgumentError("MAST-U report is not a completed static parse"))
    source=get(report,:source_member,nothing)
    source isa AbstractDict || throw(ArgumentError("MAST-U source-member receipt is missing"))
    source_bytes=get(source,:source_bytes,nothing)
    source_bytes==86_888_862 ||
        throw(ArgumentError("MAST-U member size differs from the reviewed source"))
    member_path=get(source,:path,nothing)
    member_path isa AbstractString && !isempty(member_path) ||
        throw(ArgumentError("MAST-U raw member path is missing"))
    member_path=abspath(String(member_path))
    endswith(lowercase(member_path),"mast-u_shot_45425.pickle") ||
        throw(ArgumentError("MAST-U raw member path is not shot 45425"))
    inspection=get(report,:static_inspection,nothing)
    inspection isa AbstractDict || throw(ArgumentError("MAST-U static inspection receipt is missing"))
    get(inspection,:member_path,nothing)==String(source[:path]) ||
        throw(ArgumentError("MAST-U source and inspection paths differ"))
    get(inspection,:member_bytes,nothing)==source_bytes ||
        throw(ArgumentError("MAST-U source and inspection byte counts differ"))
    isfile(member_path) || throw(ArgumentError("MAST-U raw source member is unavailable for byte verification"))
    filesize(member_path)==source_bytes ||
        throw(ArgumentError("MAST-U raw member byte count differs from its receipt"))
    reported_sha=get(source,:result_sha256,nothing)
    reported_sha isa AbstractString && occursin(r"^[0-9a-f]{64}$",String(reported_sha)) ||
        throw(ArgumentError("MAST-U source-member data SHA-256 is malformed"))
    actual_sha=string(_freegs_sha256_file(member_path))
    actual_sha==String(reported_sha) ||
        throw(ArgumentError("MAST-U raw member bytes do not match source_member.result_sha256"))
    extraction=get(get(inspection,:index_134_extraction,nothing),:index,nothing)
    # Resolve the exact extraction object only after source bytes are verified.
    extraction_doc=get(inspection,:index_134_extraction,nothing)
    extraction_doc isa AbstractDict || throw(ArgumentError("MAST-U index-134 extraction is missing"))
    extraction==134 || throw(ArgumentError("MAST-U source adapter requires index 134"))
    get(extraction_doc,:reference_time_path,nothing)=="root.efit_times" ||
        throw(ArgumentError("MAST-U source adapter time path mismatch"))
    get(extraction_doc,:reference_time_value,nothing)==0.7 ||
        throw(ArgumentError("MAST-U source adapter time must equal the exact recorded 0.7 value"))
    joins=get(extraction_doc,:time_axis_joins,nothing)
    joins isa AbstractVector && length(joins)==5 ||
        throw(ArgumentError("MAST-U source adapter requires five exact time joins"))
    all(row->get(row,:exact_match_to_efit_times,false)===true &&
        get(row,:index,nothing)==134 && get(row,:time_value,nothing)==0.7,joins) ||
        throw(ArgumentError("MAST-U index-134 time joins differ from the reviewed extraction"))
    currents=get(extraction_doc,:active_current_name_value_joins,nothing)
    currents isa AbstractDict && length(get(currents,:rows,()))==64 ||
        throw(ArgumentError("MAST-U source current rows are incomplete"))
    branches=get(extraction_doc,:pfcoil_branches,nothing)
    branches isa AbstractVector && length(branches)==25 &&
        sum(Int(get(row,:count,0)) for row in branches)==1484 ||
        throw(ArgumentError("MAST-U PF branch/geometry count differs from the reviewed extraction"))
    passive=get(extraction_doc,:passive_geometry_components,nothing)
    passive isa AbstractVector && length(passive)==45 ||
        throw(ArgumentError("MAST-U passive geometry component count differs from the reviewed extraction"))
    passive_joins=get(extraction_doc,:passive_geometry_current_name_joins,nothing)
    passive_joins isa AbstractVector && length(passive_joins)==201 ||
        throw(ArgumentError("MAST-U passive current join count differs from the reviewed extraction"))
    unmatched_passive=count(row->get(row,:matching_current_channel_count,0)!=1,passive_joins)
    unmatched_passive==133 ||
        throw(ArgumentError("MAST-U unmatched/ambiguous passive row count differs from the reviewed extraction"))
    diagnostics=get(extraction_doc,:diagnostic_value_geometry_joins,nothing)
    diagnostics isa AbstractDict || throw(ArgumentError("MAST-U sensor geometry joins are missing"))
    pickups=get(diagnostics,:pickups,nothing)
    fluxloops=get(diagnostics,:fluxloops,nothing)
    pickups isa AbstractDict && fluxloops isa AbstractDict ||
        throw(ArgumentError("MAST-U pickup/flux-loop joins are malformed"))
    pickup_rows=get(pickups,:rows,())
    fluxloop_rows=get(fluxloops,:rows,())
    length(pickup_rows)==186 && length(fluxloop_rows)==71 ||
        throw(ArgumentError("MAST-U diagnostic row counts differ from the reviewed extraction"))
    all(row->get(row,:full_name_match_count,0)==1,pickup_rows) &&
        all(row->get(row,:full_name_match_count,0)==1,fluxloop_rows) ||
        throw(ArgumentError("MAST-U diagnostic names do not join uniquely to geometry"))
    length(get(extraction_doc,:time_major_arrays_at_index,()))==38 ||
        throw(ArgumentError("MAST-U index-134 numeric array inventory differs from the reviewed extraction"))
    (schema="fusionconceptai:mastu-static-source-adapter-v1",
     source_member_path=member_path,
     source_member_bytes=source_bytes,
     source_member_sha256=actual_sha,
     static_report_path=report_path_string,
     source_role="EFIT++ reconstruction package; not independent observation",
     index_134_extraction=_freegs_mastu_json_tree_tuple_arrays(extraction_doc),
     expected_missing_bindings=(
        :pf_geometry_units_and_branch_orientation,
        :pf_channel_to_branch_signed_current_turn_mapping,
        :current_A_vs_A_per_turn_semantics,
        :passive_current_mapping_and_dynamic_response,
        :ConstrainPaxisIp_axis_pressure_field_binding,
        :ConstrainPaxisIp_vacuum_F_signed_branch_binding,
        :sensor_calibration_and_independence,
        :sigma_units_and_statistical_semantics,
        :heldout_observation_rows))
end

"""Validate the official 30421 EFM MAGPR_X input and its matching probe geometry.

Angles enter in source degrees and are converted exactly once here. The return
value is a read-only-by-contract source record; `MAGPR_C` is not an input.
"""
function freegs_mast_magpr_observation_v1(;shot, channel_names, mag_probe_n, time_s,
        observed_T, R_m, Z_m, angle_deg, length_m, units, quality,
        source_hashes, source_ref, mapping_ref)
    _freegs_integer(shot,"MAST shot";minimum=1)==30421 ||
        throw(ArgumentError("this bounded source adapter is fixed to shot 30421"))
    channels=Tuple(_freegs_text(name,"MAGPR channel name") for name in channel_names)
    channels==_FREEGS_MAST_MAGPR_CHANNELS ||
        throw(ArgumentError("MAGPR channel order must match the official 78-channel EFM map"))
    units isa NamedTuple && units == (time="S", channel="", observed="T",
        R="m", Z="m", angle="deg", length="m") ||
        throw(ArgumentError("MAGPR source units must exactly match shot-30421 Level-1 metadata"))
    String(quality)=="Not Checked" ||
        throw(ArgumentError("MAGPR quality status must preserve the source Not Checked label"))
    times=Tuple(_freegs_finite(t,"MAGPR time s") for t in time_s)
    length(times)==120 && all(times[i]<times[i+1] for i in 1:length(times)-1) ||
        throw(ArgumentError("shot-30421 MAGPR time axis must be 120 strictly increasing seconds"))
    nprobe=length(channels)
    slots=Tuple(_freegs_finite(x,"MAGPR channel slot") for x in mag_probe_n)
    slots==Tuple(Float64(i-1) for i in 1:nprobe) ||
        throw(ArgumentError("MAGPR channel slots must be the exact zero-based 0:77 axis"))
    observed=Matrix{Float64}(observed_T)
    size(observed)==(length(times),nprobe) ||
        throw(ArgumentError("MAGPR_X must have exact [time,channel]=[120,78] dimensions"))
    all(isfinite,observed) || throw(ArgumentError("MAGPR_X has non-finite raw observations"))
    R=Tuple(_freegs_finite(x,"MAGPR R m";positive=true) for x in R_m)
    Z=Tuple(_freegs_finite(x,"MAGPR Z m") for x in Z_m)
    angle=Tuple(_freegs_finite(x,"MAGPR angle deg") for x in angle_deg)
    probe_length=Tuple(_freegs_finite(x,"MAGPR length m";positive=true) for x in length_m)
    all(length(x)==nprobe for x in (R,Z,angle,probe_length)) ||
        throw(ArgumentError("MAGPR geometry vectors must contain exactly 78 channels"))
    angle_rad=Tuple(deg2rad(x) for x in angle)
    all(isfinite,angle_rad) || throw(ArgumentError("MAGPR angle conversion produced non-finite values"))
    required_hashes=(:efm_time,:efm_mag_probe_n,:efm_magpr_x,:efm_magpr_r,
        :efm_magpr_z,:efm_magpr_ang,:efm_magpr_len)
    source_hashes isa NamedTuple && Set(keys(source_hashes))==Set(required_hashes) ||
        throw(ArgumentError("MAGPR provenance must hash exactly the seven selected source arrays"))
    hashes=NamedTuple{required_hashes}(Tuple(_freegs_sha256_literal(getproperty(source_hashes,k),String(k))
        for k in required_hashes))
    computed_hashes=(efm_time=_freegs_mast_f32_c_order_sha256(times),
        efm_mag_probe_n=_freegs_mast_f32_c_order_sha256(slots),
        efm_magpr_x=_freegs_mast_f32_c_order_sha256(vec(permutedims(observed))),
        efm_magpr_r=_freegs_mast_f32_c_order_sha256(R),
        efm_magpr_z=_freegs_mast_f32_c_order_sha256(Z),
        efm_magpr_ang=_freegs_mast_f32_c_order_sha256(angle),
        efm_magpr_len=_freegs_mast_f32_c_order_sha256(probe_length))
    hashes==computed_hashes || throw(ArgumentError("MAGPR data bytes differ from the seven source hashes"))
    src=_freegs_text(source_ref,"MAGPR source reference")
    mapref=_freegs_text(mapping_ref,"MAGPR mapping reference")
    (schema=:mast_efm_magpr_x_observation_v1,shot=30421,channels=channels,
        mag_probe_n=slots,time_s=times,observed_T=observed,R_m=R,Z_m=Z,
        angle_deg=angle,angle_rad=angle_rad,length_m=probe_length,
        observed_units="T",coordinate_units="m",source_time_units="S",time_units="s",
        source_quality="Not Checked",source_value_role=:efm_measured_input_constraint,
        source_ref=src,mapping_ref=mapref,source_array_sha256=hashes,
        calibration_status=:typed_absent,correction_status=:typed_absent,
        finite_length_response_status=:typed_absent,
        uncertainty_status=:typed_absent,likelihood_status=:typed_absent,
        source_provider_efit_role=:fit_constraint_not_independent_holdout)
end

"""Return one declared-time, unweighted MAGPR raw residual screen.

The state-time label is in the authenticated Julia-to-runner request and must
be echoed by that exact solver output, then exactly match one observation row.
This does not prove time-varying MAST inputs were selected or establish PF
current provenance, probe corrections, finite-length response, or likelihood.
"""
function freegs_mast_magpr_raw_residual_v1(context::ForwardChainContextV4,
        artifacts::FreeGSAxisymmetricExecutionArtifactsV4, observation;
        time_index)
    hasproperty(observation,:schema) && observation.schema===:mast_efm_magpr_x_observation_v1 ||
        throw(ArgumentError("unsupported MAST MAGPR observation record"))
    validate_freegs_axisymmetric_receipt(context,artifacts.receipt)
    receipt=artifacts.receipt
    receipt.status===:physical_model_screen && receipt.exit_code==0 ||
        throw(ArgumentError("MAGPR residual requires a completed candidate physical-model screen"))
    _freegs_sha256_text(artifacts.input_json)==receipt.input_hash ||
        throw(ArgumentError("MAGPR screen input bytes do not match the receipt"))
    _freegs_sha256_text(artifacts.output_json)==receipt.output_hash ||
        throw(ArgumentError("MAGPR screen output bytes do not match the receipt"))
    input=JSON3.read(artifacts.input_json)
    output=JSON3.read(artifacts.output_json)
    solver=input[:solver_input]
    haskey(solver,:state_sample_time_s) ||
        throw(ArgumentError("MAGPR residual requires a serialized candidate state timestamp"))
    i=_freegs_integer(time_index,"MAGPR time index";minimum=1)
    i<=length(observation.time_s) || throw(ArgumentError("MAGPR time index is out of range"))
    state_time=_freegs_finite(solver[:state_sample_time_s],"serialized candidate state time s")
    state_time==observation.time_s[i] ||
        throw(ArgumentError("candidate timestamp is not an exact MAGPR time-axis row"))
    haskey(output,:state_sample_time_s) ||
        throw(ArgumentError("FreeGS runner omitted the requested state timestamp echo"))
    _freegs_finite(output[:state_sample_time_s],"runner candidate state time s")==state_time ||
        throw(ArgumentError("FreeGS output timestamp echo differs from the hashed input"))
    points=Tuple((observation.R_m[j],observation.Z_m[j]) for j in eachindex(observation.channels))
    haskey(solver,:sample_points_rz_m) ||
        throw(ArgumentError("MAGPR residual requires the exact observation RZ sample list in solver input"))
    requested=Tuple((Float64(p[1]),Float64(p[2])) for p in solver[:sample_points_rz_m])
    requested==points || throw(ArgumentError("solver sample points do not match the ordered MAGPR geometry"))
    expected=_freegs_parse_field_samples_document(output,points)
    Tuple((x.R_m,x.Z_m,x.psi_wb_per_rad,x.Br_T,x.Bz_T) for x in artifacts.field_samples_rz_m)==
        Tuple((x.R_m,x.Z_m,x.psi_wb_per_rad,x.Br_T,x.Bz_T) for x in expected) ||
        throw(ArgumentError("stored FreeGS field samples differ from the authenticated output"))
    predictions=Tuple(expected[j].Br_T*cos(observation.angle_rad[j])+
        expected[j].Bz_T*sin(observation.angle_rad[j]) for j in eachindex(observation.channels))
    observed=Tuple(observation.observed_T[i,j] for j in eachindex(observation.channels))
    residual=Tuple(predictions[j]-observed[j] for j in eachindex(predictions))
    all(isfinite,predictions) && all(isfinite,residual) ||
        throw(ArgumentError("MAGPR projection produced non-finite values"))
    body=(schema=:mast_magpr_raw_residual_screen_v1,status=:raw_residual_screen,
        claim_ceiling=:screen_only,operator=:Br_cos_angle_plus_Bz_sin_angle,
        candidate_state_time_s=state_time,time_index=i,channel_order=observation.channels,
        predicted_T=predictions,observed_T=observed,residual_T=residual,
        residual_definition="candidate H minus measured EFM_MAGPR_X",residual_units="T",
        probe_sampling=:point_at_reported_RZ,probe_length_m=observation.length_m,
        finite_length_response=:typed_absent,
        candidate_context_hash=string(context.context_hash),
        candidate_input_hash=string(receipt.input_hash),
        candidate_output_hash=string(receipt.output_hash),
        observed_source_ref=observation.source_ref,mapping_ref=observation.mapping_ref,
        observed_MAGPR_X_sha256=observation.source_array_sha256.efm_magpr_x,
        observation_relation=:efm_fit_constraint_not_independent_holdout,
        G1_PF_current_mapping=:typed_absent,G3_MAST_current_provenance=:typed_absent,
        candidate_state_time_label=:input_output_receipt_echo,
        G2_same_time_machine_state_provenance=:typed_absent,
        probe_calibration=:typed_absent,probe_correction=:typed_absent,
        source_quality=observation.source_quality,uncertainty=:typed_absent,
        likelihood=:typed_absent,inverse=:typed_absent,forward_authority=false)
    merge(body,(result_hash=canonical_hash(body),))
end

function _freegs_check_current_limits(current_state, coil_ids, current_lims, max_total_current)
    length(current_state)==length(coil_ids) ||
        throw(ArgumentError("coil-current feasibility state is incomplete"))
    total=sum(abs(row[2]) for row in current_state)
    isfinite(total) || throw(ArgumentError("sum of controlled-coil absolute currents is non-finite"))
    if current_lims!==nothing
        length(current_lims)==length(coil_ids) ||
            throw(ArgumentError("per-turn current limits do not match declared coils"))
        for i in eachindex(coil_ids)
            lower,upper=current_lims[i]
            lower <= current_state[i][2] <= upper ||
                throw(ArgumentError("coil current is outside its exact declared per-turn bounds"))
        end
    end
    max_total_current===nothing || total<=max_total_current ||
        throw(ArgumentError("sum of controlled-coil absolute currents exceeds declared maximum"))
    total
end

function _freegs_validate_coil_control(document, requested_mode::String, coil_ids, fixed_currents,
        current_lims, max_total_current)
    document isa AbstractDict && haskey(document,:coil_control) ||
        throw(ArgumentError("controlled runner omitted coil-control result status"))
    control=document[:coil_control]
    control isa AbstractDict && Set(collect(keys(control))) ==
        Set((:mode,:status,:optimizer_calls,:coil_currents_a_per_turn)) ||
        throw(ArgumentError("controlled runner coil-control result fields mismatch"))
    String(control[:mode])==requested_mode ||
        throw(ArgumentError("controlled runner coil-control mode mismatch"))
    currents=control[:coil_currents_a_per_turn]
    currents isa AbstractDict && Set(String.(collect(keys(currents))))==Set(coil_ids) ||
        throw(ArgumentError("controlled runner coil-current IDs mismatch"))
    current_by_id=Dict(String(id)=>value for (id,value) in currents)
    current_state=Tuple((String(id),_freegs_finite(current_by_id[String(id)],"returned coil current A per turn"))
        for id in coil_ids)
    _freegs_check_current_limits(current_state,coil_ids,current_lims,max_total_current)
    calls=control[:optimizer_calls]
    calls isa AbstractVector || throw(ArgumentError("optimizer-call status must be an array"))
    status=String(control[:status])
    if requested_mode=="shape_controlled"
        status=="slsqp_success" && !isempty(calls) ||
            throw(ArgumentError("shape-controlled result has no successful SLSQP status"))
        for result in calls
            result isa AbstractDict && Set(collect(keys(result)))==
                Set((:success,:message,:iterations,:objective,
                    :candidate_currents_a_per_turn)) ||
                throw(ArgumentError("SLSQP result record fields mismatch"))
            result[:success]===true || throw(ArgumentError("SLSQP result was unsuccessful"))
            result[:message] isa AbstractString || throw(ArgumentError("SLSQP message is invalid"))
            result[:iterations] isa Integer && result[:iterations]>=0 ||
                throw(ArgumentError("SLSQP iteration count is invalid"))
            _freegs_finite(result[:objective],"SLSQP objective")
            candidate=result[:candidate_currents_a_per_turn]
            candidate isa AbstractDict && Set(String.(collect(keys(candidate))))==Set(coil_ids) ||
                throw(ArgumentError("SLSQP candidate current IDs mismatch"))
            candidate_by_id=Dict(String(id)=>value for (id,value) in candidate)
            candidate_state=Tuple((String(id),_freegs_finite(candidate_by_id[String(id)],
                "SLSQP candidate current A per turn")) for id in coil_ids)
            _freegs_check_current_limits(candidate_state,coil_ids,current_lims,max_total_current)
        end
    elseif requested_mode=="fixed_current_forward"
        status=="fixed_current_forward" && isempty(calls) ||
            throw(ArgumentError("fixed-current forward unexpectedly invoked coil optimization"))
        length(fixed_currents)==length(coil_ids) ||
            throw(ArgumentError("fixed-current forward input is incomplete"))
        Tuple(String(row[1]) for row in fixed_currents)==Tuple(coil_ids) ||
            throw(ArgumentError("fixed-current forward IDs/order mismatch"))
        for i in eachindex(current_state)
            current_state[i][2]==_freegs_finite(fixed_currents[i][2],"input coil current A per turn") ||
                throw(ArgumentError("fixed-current forward changed a supplied coil current"))
        end
    else
        throw(ArgumentError("unsupported requested coil-control mode"))
    end
    (status=Symbol(status),optimizer_calls=length(calls),coil_currents_A_per_turn=current_state)
end

function _freegs_parse_summary(stdout::String, context, binding, output_json::String;
        sample_points_rz_m=(), sample_constitutive_fields::Bool=false,
        sample_lcfs_trace::Bool=false, coil_current_mode::String="shape_controlled",
        fixed_coil_currents_A_per_turn=(), capture_control_result::Bool=false,
        state_sample_time_s=nothing)
    lines = filter(line -> startswith(line, "FUSION_FREEGS_V4\t"), split(stdout, '\n'))
    length(lines) == 1 || throw(ArgumentError("controlled runner emitted missing or ambiguous summary"))
    line=only(lines)
    endswith(line,"\r") && (line=chop(line;tail=1))
    parts = split(line, '\t'; keepempty=true)
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
        output_document = JSON3.read(output_json)
        reported_state_time=get(output_document,:state_sample_time_s,nothing)
        if state_sample_time_s===nothing
            reported_state_time===nothing || throw(ArgumentError("runner emitted an unrequested state timestamp"))
        else
            requested_time=_freegs_finite(state_sample_time_s,"requested state sample time s")
            reported_state_time!==nothing || throw(ArgumentError("runner omitted requested state timestamp"))
            _freegs_finite(reported_state_time,"runner state sample time s")==requested_time ||
                throw(ArgumentError("runner state timestamp echo mismatch"))
        end
        coil_control=nothing
        if coil_current_mode=="fixed_current_forward" || capture_control_result
            expected_ids=Tuple(c.coil_id for c in binding.declaration.coils)
            expected_fixed=Tuple(fixed_coil_currents_A_per_turn)
            d=binding.declaration
            coil_control=_freegs_validate_coil_control(output_document,coil_current_mode,
                expected_ids,expected_fixed,d.constraints.current_lims_A_per_turn,
                d.constraints.max_total_current_A)
        end
        trace_present = output_document isa AbstractDict && haskey(output_document, :lcfs_trace)
        trace_present == sample_lcfs_trace ||
            throw(ArgumentError("controlled runner LCFS trace opt-in/output mismatch"))
        if trace_present
            trace = output_document[:lcfs_trace]
            trace isa AbstractDict && haskey(trace, :status) ||
                throw(ArgumentError("controlled runner LCFS trace status is missing"))
            String(trace[:status]) in ("present", "typed_absent") ||
                throw(ArgumentError("controlled runner LCFS trace status is unauthorized"))
        end
        summary = _freegs_summary(parts[9:22])
        summary_result=(status=status, freegs_version=freegs_version,
            environment_hash=environment_hash, result_hash=result_hash,
            backend_input_hash=backend_input_hash, summary=summary,
            state_sample_time_s=state_sample_time_s===nothing ? nothing : Float64(state_sample_time_s),
            field_samples_rz_m=_freegs_parse_field_samples_document(output_document,
                sample_points_rz_m; sample_constitutive_fields=sample_constitutive_fields),
            gap_kind=:none, reason="executed FreeGS physical-model screen")
        return coil_control===nothing ? summary_result :
            merge(summary_result,(coil_control=coil_control,))
    elseif status === :recoverable_gap_unknown
        return (status=status, freegs_version=freegs_version,
            environment_hash=environment_hash, result_hash=result_hash,
            backend_input_hash=backend_input_hash, summary=nothing,
            field_samples_rz_m=(),
            gap_kind=Symbol(isempty(parts[24]) ? "backend_execution_gap" : parts[24]),
            reason="controlled runner reported a recoverable unknown gap")
    end
    throw(ArgumentError("controlled runner emitted an unauthorized status"))
end

_freegs_accepted_field_samples(parsed, status, exit_code) =
    status === :physical_model_screen && exit_code == 0 && parsed !== nothing ?
        parsed.field_samples_rz_m : ()


# The binary is an existing solver-output attachment, read and authenticated once
# while the execution temporary directory still exists. Evaluators never read it.
function _freegs_hagenow_source_metadata(document)
    gs=get(document,:native_gs_state,nothing)
    gs===nothing && return nothing
    source=get(gs,:hagenow_source_feedback,nothing)
    source===nothing && return nothing
    get(source,:source_response_matrix,nothing)
end

function _freegs_read_hagenow_source_response(directory::AbstractString, output_json::String)
    document=JSON3.read(output_json)
    metadata=_freegs_hagenow_source_metadata(document)
    metadata===nothing && return nothing
    metadata isa AbstractDict || throw(ArgumentError("Hagenow matrix metadata must be an object"))
    String(metadata[:status])=="present" &&
        String(metadata[:file_name])=="hagenow_source_response.f64" &&
        String(metadata[:encoding])=="ieee754_float64_little_endian_column_major" ||
        throw(ArgumentError("unsupported Hagenow source matrix attachment"))
    gs=document[:native_gs_state]
    String(gs[:status])=="present" || throw(ArgumentError("Hagenow attachment lacks native GS state"))
    nr=length(gs[:plasma_psi_wb_per_rad]);nr>=2 || throw(ArgumentError("invalid native R grid"))
    nz=length(gs[:plasma_psi_wb_per_rad][1]);nz>=2 || throw(ArgumentError("invalid native Z grid"))
    n=Base.checked_mul(nr,nz)
    function ids(name)
        raw=metadata[name]
        !isempty(raw) && length(raw)<=n &&
            all(v->v isa Integer && !(v isa Bool) && 1<=v<=n,raw) ||
            throw(ArgumentError("Hagenow source matrix native IDs are invalid"))
        result=Int.(raw)
        issorted(result) && allunique(result) || throw(ArgumentError("Hagenow source matrix IDs are not sorted unique"))
        result
    end
    boundary=ids(:boundary_native_ids);core=ids(:core_native_ids)
    expected_boundary=sort!(unique!(vcat(collect(1:nz),collect((nr-1)*nz+1:n),
        [((i-1)*nz+1) for i in 1:nr],[i*nz for i in 1:nr])))
    boundary==expected_boundary || throw(ArgumentError("Hagenow attachment boundary order differs"))
    shape=metadata[:shape]
    length(shape)==2 && all(v->v isa Integer && !(v isa Bool),shape) &&
        Int.(shape)==[length(boundary),length(core)] || throw(ArgumentError("Hagenow matrix shape differs from IDs"))
    byte_count=Base.checked_mul(8,Base.checked_mul(length(boundary),length(core)))
    metadata[:byte_count] isa Integer && !(metadata[:byte_count] isa Bool) &&
        metadata[:byte_count]==byte_count || throw(ArgumentError("Hagenow attachment byte count differs"))
    digest=String(metadata[:sha256])
    occursin(r"^[0-9a-f]{64}$",digest) || throw(ArgumentError("invalid Hagenow attachment digest"))
    path=joinpath(directory,"hagenow_source_response.f64")
    isfile(path) && filesize(path)==byte_count || throw(ArgumentError("Hagenow matrix attachment missing or truncated"))
    bytes=read(path)
    length(bytes)==byte_count && string(_freegs_sha256_bytes(bytes))==digest ||
        throw(ArgumentError("Hagenow matrix attachment digest differs"))
    # ltoh is identity on the current Windows host and explicit on other hosts.
    values=copy(reshape(reinterpret(Float64,ltoh.(reinterpret(UInt64,bytes))),
        length(boundary),length(core)))
    all(isfinite,values) || throw(ArgumentError("Hagenow source matrix contains nonfinite values"))
    (values=values,bytes=bytes,sha256=digest,boundary_native_ids=boundary,
        core_native_ids=core,encoding=:ieee754_float64_little_endian_column_major)
end

function _freegs_write_artifacts(directory::String, input_json::String,
        output_json::String, receipt::FreeGSAxisymmetricExecutionReceiptV4, hagenow_source_response=nothing)
    absolute = abspath(directory)
    mkpath(absolute)
    write(joinpath(absolute, "solver_input.canonical.json"), input_json)
    write(joinpath(absolute, "solver_output.json"), output_json)
    write(joinpath(absolute, "execution_receipt.canonical.json"),
        canonical_json(receipt) * "\n")
    hagenow_source_response===nothing || write(joinpath(absolute,"hagenow_source_response.f64"),hagenow_source_response.bytes)
    absolute
end

"""Run the pinned local FreeGS interpreter; all infrastructure failures stay unknown."""
function execute_freegs_axisymmetric_screen(context::ForwardChainContextV4;
        artifact_directory::Union{Nothing,AbstractString}=nothing,
        sample_points_rz_m=(), sample_constitutive_fields::Bool=false,
        sample_lcfs_trace::Bool=false, coil_current_mode::Symbol=:shape_controlled,
        fixed_coil_currents_A_per_turn=(), capture_control_result::Bool=false,
        initial_plasma_psi_wb_per_rad=nothing, state_sample_time_s=nothing,
        mastu_source_adapter_report_path=nothing)
    _freegs_with_context_ast_payload_memo(context) do
        _execute_freegs_axisymmetric_screen_uncached(context;
            artifact_directory=artifact_directory,
            sample_points_rz_m=sample_points_rz_m,
            sample_constitutive_fields=sample_constitutive_fields,
            sample_lcfs_trace=sample_lcfs_trace,
            coil_current_mode=coil_current_mode,
            fixed_coil_currents_A_per_turn=fixed_coil_currents_A_per_turn,
            capture_control_result=capture_control_result,
            initial_plasma_psi_wb_per_rad=initial_plasma_psi_wb_per_rad,
            state_sample_time_s=state_sample_time_s,
            mastu_source_adapter_report_path=mastu_source_adapter_report_path)
    end
end

function _execute_freegs_axisymmetric_screen_uncached(context::ForwardChainContextV4;
        artifact_directory::Union{Nothing,AbstractString}=nothing,
        sample_points_rz_m=(), sample_constitutive_fields::Bool=false,
        sample_lcfs_trace::Bool=false, coil_current_mode::Symbol=:shape_controlled,
        fixed_coil_currents_A_per_turn=(), capture_control_result::Bool=false,
        initial_plasma_psi_wb_per_rad=nothing, state_sample_time_s=nothing,
        mastu_source_adapter_report_path=nothing)
    validate_forward_chain_context(context)
    binding = _freegs_context_binding(context)
    solver_input = freegs_axisymmetric_solver_input(context;
        sample_points_rz_m=sample_points_rz_m,
        sample_constitutive_fields=sample_constitutive_fields,
        sample_lcfs_trace=sample_lcfs_trace,coil_current_mode=coil_current_mode,
        fixed_coil_currents_A_per_turn=fixed_coil_currents_A_per_turn,
        capture_control_result=capture_control_result,
        initial_plasma_psi_wb_per_rad=initial_plasma_psi_wb_per_rad,
        state_sample_time_s=state_sample_time_s,
        mastu_source_adapter_report_path=mastu_source_adapter_report_path)
    requested_capture_control_result =
        hasproperty(solver_input.solver_input,:capture_control_result) ?
            solver_input.solver_input.capture_control_result : false
    requested_samples = hasproperty(solver_input.solver_input, :sample_points_rz_m) ?
        solver_input.solver_input.sample_points_rz_m : ()
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
    hagenow_source_response = nothing
    execution_error = nothing
    mktempdir() do directory
        input_path = joinpath(directory, "input.json")
        output_path = joinpath(directory, "output.json")
        stdout_path = joinpath(directory, "stdout.txt")
        stderr_path = joinpath(directory, "stderr.txt")
        write(input_path, input_json)
        command = Cmd(`$_FREEGS_PINNED_PYTHON $_FREEGS_CONTROLLED_RUNNER --input $input_path --output $output_path`; windows_hide=true)
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
                parsed = _freegs_parse_summary(stdout, context, binding, output_json;
                    sample_points_rz_m=requested_samples,
                    sample_constitutive_fields=sample_constitutive_fields,
                    sample_lcfs_trace=sample_lcfs_trace,
                    coil_current_mode=String(coil_current_mode),
                    fixed_coil_currents_A_per_turn=fixed_coil_currents_A_per_turn,
                    capture_control_result=requested_capture_control_result,
                    state_sample_time_s=state_sample_time_s)
                hagenow_source_response = _freegs_read_hagenow_source_response(directory,output_json)
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
    # This run alone self-checks the producer bytes it recorded; historical
    # receipt readers validate the saved result without this live-file gate.
    if receipt.status===:physical_model_screen
        _freegs_assert_current_execution_producer_hashes(runner_hash,interpreter_hash)
    end
    validate_freegs_axisymmetric_receipt(context, receipt)
    artifact_directory === nothing || _freegs_write_artifacts(
        String(artifact_directory), input_json, output_json, receipt, hagenow_source_response)
    accepted_samples = _freegs_accepted_field_samples(parsed, receipt.status, receipt.exit_code)
    FreeGSAxisymmetricExecutionArtifactsV4(receipt, input_json, output_json,
        accepted_samples, hagenow_source_response)
end

function _freegs_assert_current_execution_producer_hashes(runner_hash,interpreter_hash)
    isfile(_FREEGS_PINNED_PYTHON) &&
        interpreter_hash==_freegs_sha256_file(_FREEGS_PINNED_PYTHON) ||
        throw(ArgumentError("pinned FreeGS interpreter changed during current execution"))
    isfile(_FREEGS_CONTROLLED_RUNNER) &&
        runner_hash==_freegs_sha256_file(_FREEGS_CONTROLLED_RUNNER) ||
        throw(ArgumentError("controlled FreeGS runner changed during current execution"))
    nothing
end

"""Revalidate receipt integrity, context identity, and claim limits.

Producer executable hashes are historical receipt fields. Current execution
checks its own producer bytes before returning; saved-result consumers do not
compare an old producer hash with today's installation.
"""
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

function _freegs_typed_absent_lcfs(reason::AbstractString)
    (status=:typed_absent, reason=Symbol(replace(String(reason), r"[^A-Za-z0-9_]+" => "_")),
     representation=:final_total_psi_grid_spline_radial_lcfs)
end

function _freegs_require_object(value, field::String, keys_expected)
    value isa AbstractDict || throw(ArgumentError("$field must be an object"))
    Set(collect(keys(value))) == Set(keys_expected) ||
        throw(ArgumentError("$field fields mismatch"))
    value
end

function _freegs_parse_native_critical_points(raw,R,Z,psi_boundary;
        critical_point_refinement::Symbol=:freegs_native_v1)
    raw===nothing && return (status=:typed_absent,reason=:actual_critical_points_not_emitted)
    base_fields=(:method,:flux_source,:core_mask_method,:xpoint_neighborhood_rule,
        :opoints,:xpoints,:core_mask_psi_axis_wb_per_rad,:core_mask_psi_boundary_wb_per_rad)
    fields=critical_point_refinement===:freegs_native_v1 ? base_fields :
        critical_point_refinement===:stationary_cubic_spline_gradient_hessian_v2 ?
            (base_fields...,:critical_point_refinement) :
            throw(ArgumentError("unsupported bound critical-point refinement rule"))
    _freegs_require_object(raw,"native critical points",fields)
    method=critical_point_refinement===:freegs_native_v1 ? "freegs.critical.find_critical" :
        "fusionconceptai.stationary_cubic_spline_gradient_hessian_v2"
    String(raw[:method])==method &&
        String(raw[:flux_source])=="sampled_eq.psi_native_total_grid" &&
        String(raw[:core_mask_method])=="freegs.critical.core_mask" &&
        String(raw[:xpoint_neighborhood_rule])=="block_nearest_3x3_then_restore_psiN_lt_1_without_connectivity_recheck" ||
        throw(ArgumentError("native critical-point source semantics differ"))
    critical_point_refinement===:freegs_native_v1 ||
        String(raw[:critical_point_refinement])==String(critical_point_refinement) ||
        throw(ArgumentError("native critical-point refinement rule is unbound"))
    function read_points(key)
        records=raw[key]
        records isa AbstractVector && !isempty(records) ||
            throw(ArgumentError("native critical-point inventory is empty or malformed"))
        Tuple(begin
            _freegs_require_object(record,"native critical point",(:R_m,:Z_m,:psi_wb_per_rad,:nearest_native_id))
            r=_freegs_finite(record[:R_m],"critical R_m";positive=true)
            z=_freegs_finite(record[:Z_m],"critical Z_m")
            psi=_freegs_finite(record[:psi_wb_per_rad],"critical psi")
            i=argmin([abs(value-r) for value in R]);j=argmin([abs(value-z) for value in Z])
            node=_freegs_integer(record[:nearest_native_id],"critical nearest native ID";minimum=1)
            node==(i-1)*length(Z)+j || throw(ArgumentError("critical nearest native ID/order differs"))
            (R_m=r,Z_m=z,psi_wb_per_rad=psi,nearest_native_id=node)
        end for record in records)
    end
    opoints=read_points(:opoints);xpoints=read_points(:xpoints)
    axis=_freegs_finite(raw[:core_mask_psi_axis_wb_per_rad],"core_mask actual axis psi")
    boundary=_freegs_finite(raw[:core_mask_psi_boundary_wb_per_rad],"core_mask actual boundary psi")
    axis==first(opoints).psi_wb_per_rad && boundary==psi_boundary && axis!=boundary ||
        throw(ArgumentError("native critical-point core_mask normalization differs"))
    parsed=(status=:present,method=critical_point_refinement===:freegs_native_v1 ?
        :freegs_critical_find_critical : :stationary_cubic_spline_gradient_hessian_v2,
        flux_source=:sampled_eq_psi_native_total_grid,
        core_mask_method=:freegs_critical_core_mask,opoints=opoints,xpoints=xpoints,
        core_mask_psi_axis_wb_per_rad=axis,core_mask_psi_boundary_wb_per_rad=boundary,
        xpoint_neighborhood_rule=:block_nearest_3x3_then_restore_psiN_lt_1_without_connectivity_recheck,
        continuous_component_membership=:not_validated)
    critical_point_refinement===:freegs_native_v1 ? parsed :
        merge(parsed,(critical_point_refinement=critical_point_refinement,))
end

function _freegs_parse_native_current_support(support, solver, output,
        psi_axis::Float64, psi_boundary::Float64;
        critical_point_refinement::Symbol=:freegs_native_v1)
    support isa AbstractDict && haskey(support, :status) ||
        throw(ArgumentError("FreeGS native current support is malformed"))
    status = String(support[:status])
    if status == "typed_absent"
        Set(collect(keys(support))) == Set((:status, :reason, :representation)) ||
            throw(ArgumentError("typed-absent native current support fields mismatch"))
        return (status=:typed_absent,
            reason=Symbol(replace(String(support[:reason]), r"[^A-Za-z0-9_]+" => "_")),
            representation=:final_psi_profile_native_grid_Jphi)
    end
    status == "present" || throw(ArgumentError("native current support status is unauthorized"))
    fields = (:status, :reason, :representation, :axis_order,
        :current_density_component, :positive_current_direction, :R_m, :Z_m,
        :psi_wb_per_rad, :psi_normalized, :core_mask, :Jphi_A_per_m2,
        :area_weight_m2, :ring_current_A, :dR_m, :dZ_m, :area_weight_rule,
        :ring_current_rule, :current_integral_trapezoid_A,
        :solver_plasma_current_A, :native_RZ_area_m2,
        :independent_toroidal_field_source)
    support_fields=haskey(support,:critical_points) ? (fields...,:critical_points) : fields
    _freegs_require_object(support, "native current support", support_fields)
    String(support[:reason]) == "same_final_psi_profile_native_grid_Jphi" ||
        throw(ArgumentError("native current support provenance mismatch"))
    String(support[:representation]) == "FreeGS_profile_Jtor_final_psi_RZ_nodes" ||
        throw(ArgumentError("native current support representation mismatch"))
    String(support[:axis_order]) == "[R_index][Z_index]" ||
        throw(ArgumentError("native current support axis order mismatch"))
    String(support[:current_density_component]) == "toroidal_Jphi_A_per_m2" ||
        throw(ArgumentError("native current component mismatch"))
    String(support[:positive_current_direction]) ==
        "positive_cylindrical_phi; values remain signed" ||
        throw(ArgumentError("native current sign convention mismatch"))
    String(support[:area_weight_rule]) ==
        "tensor_product_trapezoid; dR*dZ interior, half endpoint widths" ||
        throw(ArgumentError("native RZ area rule mismatch"))
    String(support[:ring_current_rule]) ==
        "I_phi[i,j] = Jphi[i,j] * area_weight_m2[i,j]" ||
        throw(ArgumentError("native ring current rule mismatch"))

    domain = get(solver, :domain, nothing)
    domain isa AbstractDict || throw(ArgumentError("native current support domain is missing"))
    nr = _freegs_integer(domain[:nx], "native current grid nx"; minimum=2)
    nz = _freegs_integer(domain[:ny], "native current grid ny"; minimum=2)
    rmin = _freegs_finite(domain[:r_min_m], "native current r_min_m"; positive=true)
    rmax = _freegs_finite(domain[:r_max_m], "native current r_max_m"; positive=true)
    zmin = _freegs_finite(domain[:z_min_m], "native current z_min_m")
    zmax = _freegs_finite(domain[:z_max_m], "native current z_max_m")
    R_doc, Z_doc = support[:R_m], support[:Z_m]
    R_doc isa AbstractVector && length(R_doc) == nr || throw(ArgumentError("native R axis length mismatch"))
    Z_doc isa AbstractVector && length(Z_doc) == nz || throw(ArgumentError("native Z axis length mismatch"))
    R = Tuple(_freegs_finite(value, "native R_m"; positive=true) for value in R_doc)
    Z = Tuple(_freegs_finite(value, "native Z_m") for value in Z_doc)
    dR_expected, dZ_expected = (rmax-rmin)/(nr-1), (zmax-zmin)/(nz-1)
    coordinate_tol = 16eps(Float64) * max(1.0, abs(rmin), abs(rmax), abs(zmin), abs(zmax))
    abs(R[1]-rmin) <= coordinate_tol && abs(R[end]-rmax) <= coordinate_tol &&
        abs(Z[1]-zmin) <= coordinate_tol && abs(Z[end]-zmax) <= coordinate_tol ||
        throw(ArgumentError("native RZ axes do not match the candidate domain"))
    all(i -> abs((R[i+1]-R[i])-dR_expected) <= coordinate_tol, 1:nr-1) &&
        all(j -> abs((Z[j+1]-Z[j])-dZ_expected) <= coordinate_tol, 1:nz-1) ||
        throw(ArgumentError("native RZ grid is not uniform"))
    dR = _freegs_finite(support[:dR_m], "native dR_m"; positive=true)
    dZ = _freegs_finite(support[:dZ_m], "native dZ_m"; positive=true)
    abs(dR-dR_expected) <= coordinate_tol && abs(dZ-dZ_expected) <= coordinate_tol ||
        throw(ArgumentError("native RZ spacing differs from the candidate domain"))

    function parse_grid(key::Symbol, label::String)
        source = support[key]
        source isa AbstractVector && length(source) == nr ||
            throw(ArgumentError("$label R dimension mismatch"))
        grid = Matrix{Float64}(undef, nr, nz)
        for i in 1:nr
            source[i] isa AbstractVector && length(source[i]) == nz ||
                throw(ArgumentError("$label Z dimension mismatch"))
            for j in 1:nz
                grid[i,j] = _freegs_finite(source[i][j], "$label[$i,$j]")
            end
        end
        grid
    end
    psi_grid = parse_grid(:psi_wb_per_rad, "native psi Wb/rad")
    psi_n_grid = parse_grid(:psi_normalized, "native psi_N")
    mask_grid = parse_grid(:core_mask, "native core mask")
    Jphi = parse_grid(:Jphi_A_per_m2, "native Jphi A/m2")
    area = parse_grid(:area_weight_m2, "native RZ area weight m2")
    ring = parse_grid(:ring_current_A, "native ring current A")
    span = psi_boundary - psi_axis
    for i in 1:nr, j in 1:nz
        isapprox((psi_grid[i,j]-psi_axis)/span, psi_n_grid[i,j]; rtol=1.0e-12, atol=1.0e-12) ||
            throw(ArgumentError("native psi and normalized psi differ"))
        mask_grid[i,j] in (0.0, 1.0) || throw(ArgumentError("native core mask is outside {0,1}"))
        mask_grid[i,j] == 0.0 && Jphi[i,j] != 0.0 &&
            throw(ArgumentError("native Jphi is nonzero outside final core support"))
        area_factor = (i == 1 || i == nr ? 0.5 : 1.0) * (j == 1 || j == nz ? 0.5 : 1.0)
        expected_area = dR * dZ * area_factor
        isapprox(area[i,j], expected_area; rtol=16eps(Float64), atol=0.0) ||
            throw(ArgumentError("native RZ quadrature weight mismatch"))
        isapprox(ring[i,j], Jphi[i,j] * area[i,j]; rtol=16eps(Float64), atol=0.0) ||
            throw(ArgumentError("native ring current differs from Jphi times area"))
    end
    current_integral = _freegs_finite(support[:current_integral_trapezoid_A],
        "native trapezoid current integral")
    isapprox(current_integral, sum(ring); rtol=1.0e-12, atol=1.0e-8) ||
        throw(ArgumentError("native ring-current sum mismatch"))
    area_total = _freegs_finite(support[:native_RZ_area_m2], "native RZ area m2"; positive=true)
    isapprox(area_total, (rmax-rmin)*(zmax-zmin); rtol=1.0e-12, atol=1.0e-12) ||
        throw(ArgumentError("native RZ area sum mismatch"))
    equilibrium = get(output, :equilibrium, nothing)
    equilibrium isa AbstractDict || throw(ArgumentError("FreeGS equilibrium summary is missing"))
    solver_current = _freegs_finite(support[:solver_plasma_current_A], "support solver plasma current")
    solver_current == _freegs_finite(equilibrium[:plasma_current_a], "reported solver plasma current") ||
        throw(ArgumentError("native current support solver-current binding mismatch"))
    tf = _freegs_require_object(support[:independent_toroidal_field_source],
        "independent TF source", (:status, :reason))
    String(tf[:status]) == "typed_absent" &&
        String(tf[:reason]) == "candidate_bound_TF_coil_current_and_geometry_unavailable" ||
        throw(ArgumentError("independent TF source absence was not retained"))
    critical_points=_freegs_parse_native_critical_points(get(support,:critical_points,nothing),R,Z,
        psi_boundary;critical_point_refinement=critical_point_refinement)
    matrix_tuple(A) = Tuple(Tuple(A[i,j] for j in 1:nz) for i in 1:nr)
    (status=:present, reason=:same_final_psi_profile_native_grid_Jphi,
     representation=:FreeGS_profile_Jtor_final_psi_RZ_nodes, axis_order=:R_then_Z,
     R_m=R, Z_m=Z, psi_wb_per_rad=matrix_tuple(psi_grid),
     psi_normalized=matrix_tuple(psi_n_grid), core_mask=matrix_tuple(mask_grid),
     critical_points=critical_points,
     Jphi_A_per_m2=matrix_tuple(Jphi), area_weight_m2=matrix_tuple(area),
     ring_current_A=matrix_tuple(ring), dR_m=dR, dZ_m=dZ,
     area_weight_rule=:tensor_product_trapezoid,
     current_integral_trapezoid_A=current_integral,
     solver_plasma_current_A=solver_current, native_RZ_area_m2=area_total,
     independent_toroidal_field_source=(status=:typed_absent,
        reason=:candidate_bound_TF_coil_current_and_geometry_unavailable))
end

function _freegs_parse_solver_jtor_diagnostic(diagnostic, solver, output)
    absent = (status=:typed_absent,
        reason=:solver_jtor_diagnostic_not_emitted,
        representation=:FreeGS_eq_Jtor_last_linear_solve_RZ_nodes)
    diagnostic === nothing && return absent
    diagnostic isa AbstractDict && haskey(diagnostic, :status) ||
        throw(ArgumentError("solver Jtor diagnostic is malformed"))
    status = String(diagnostic[:status])
    if status == "typed_absent"
        Set(collect(keys(diagnostic))) == Set((:status, :reason, :representation)) ||
            throw(ArgumentError("typed-absent solver Jtor diagnostic fields mismatch"))
        return (status=:typed_absent,
            reason=Symbol(replace(String(diagnostic[:reason]), r"[^A-Za-z0-9_]+" => "_")),
            representation=:FreeGS_eq_Jtor_last_linear_solve_RZ_nodes)
    end
    status == "present" || throw(ArgumentError("solver Jtor diagnostic status is unauthorized"))
    fields = (:status, :reason, :representation, :axis_order,
        :current_density_component, :positive_current_direction,
        :solver_array_provenance, :solver_array_update_semantics,
        :comparison_array_provenance, :R_m, :Z_m,
        :solver_eq_Jtor_A_per_m2, :recomputed_final_psi_Jphi_A_per_m2,
        :solver_minus_recomputed_norms, :current_integrals,
        :RZ_area_weight_rule, :difference_integral_rule)
    _freegs_require_object(diagnostic, "solver Jtor diagnostic", fields)
    String(diagnostic[:reason]) ==
        "accepted_final_equilibrium_last_solve_vs_recomputed_final_psi_profile" ||
        throw(ArgumentError("solver Jtor diagnostic provenance mismatch"))
    String(diagnostic[:representation]) ==
        "FreeGS_eq_Jtor_last_linear_solve_RZ_nodes" ||
        throw(ArgumentError("solver Jtor diagnostic representation mismatch"))
    String(diagnostic[:axis_order]) == "[R_index][Z_index]" ||
        throw(ArgumentError("solver Jtor axis order mismatch"))
    String(diagnostic[:current_density_component]) == "toroidal_Jphi_A_per_m2" ||
        throw(ArgumentError("solver Jtor current component mismatch"))
    String(diagnostic[:positive_current_direction]) ==
        "positive_cylindrical_phi; values remain signed" ||
        throw(ArgumentError("solver Jtor sign convention mismatch"))
    String(diagnostic[:solver_array_provenance]) ==
        "eq.Jtor retained after final Picard Equilibrium.solve call; last Grad-Shafranov RHS current-density grid" ||
        throw(ArgumentError("solver Jtor array provenance mismatch"))
    String(diagnostic[:solver_array_update_semantics]) ==
        "Equilibrium.solve computes or receives Jtor before its elliptic flux update, then assigns self.Jtor=Jtor; Picard calls solve repeatedly and returns with the final call retained" ||
        throw(ArgumentError("solver Jtor update semantics mismatch"))
    String(diagnostic[:comparison_array_provenance]) ==
        "ConstrainPaxisIp.Jtor recomputed from accepted final psi on a linked deep copy; separate from retained eq.Jtor" ||
        throw(ArgumentError("solver Jtor comparison provenance mismatch"))
    String(diagnostic[:RZ_area_weight_rule]) ==
        "tensor_product_trapezoid; dR*dZ interior, half endpoint widths" ||
        throw(ArgumentError("solver Jtor area rule mismatch"))
    String(diagnostic[:difference_integral_rule]) ==
        "sum((solver_eq_Jtor - recomputed_final_psi_Jphi) * RZ_area_weight)" ||
        throw(ArgumentError("solver Jtor difference integral rule mismatch"))

    domain = get(solver, :domain, nothing)
    domain isa AbstractDict || throw(ArgumentError("solver Jtor domain is missing"))
    nr = _freegs_integer(domain[:nx], "solver Jtor grid nx"; minimum=2)
    nz = _freegs_integer(domain[:ny], "solver Jtor grid ny"; minimum=2)
    rmin = _freegs_finite(domain[:r_min_m], "solver Jtor r_min_m"; positive=true)
    rmax = _freegs_finite(domain[:r_max_m], "solver Jtor r_max_m"; positive=true)
    zmin = _freegs_finite(domain[:z_min_m], "solver Jtor z_min_m")
    zmax = _freegs_finite(domain[:z_max_m], "solver Jtor z_max_m")
    R_doc, Z_doc = diagnostic[:R_m], diagnostic[:Z_m]
    R_doc isa AbstractVector && length(R_doc) == nr ||
        throw(ArgumentError("solver Jtor R axis length mismatch"))
    Z_doc isa AbstractVector && length(Z_doc) == nz ||
        throw(ArgumentError("solver Jtor Z axis length mismatch"))
    R = Tuple(_freegs_finite(v, "solver Jtor R_m"; positive=true) for v in R_doc)
    Z = Tuple(_freegs_finite(v, "solver Jtor Z_m") for v in Z_doc)
    dR, dZ = (rmax-rmin)/(nr-1), (zmax-zmin)/(nz-1)
    all(isfinite, (dR, dZ)) && dR > 0.0 && dZ > 0.0 ||
        throw(ArgumentError("solver Jtor grid spacing is nonfinite or nonpositive"))
    coordinate_tol = 16eps(Float64) * max(1.0, abs(rmin), abs(rmax), abs(zmin), abs(zmax))
    abs(R[1]-rmin) <= coordinate_tol && abs(R[end]-rmax) <= coordinate_tol &&
        abs(Z[1]-zmin) <= coordinate_tol && abs(Z[end]-zmax) <= coordinate_tol ||
        throw(ArgumentError("solver Jtor RZ axes do not match candidate domain"))
    all(i -> abs((R[i+1]-R[i])-dR) <= coordinate_tol, 1:nr-1) &&
        all(j -> abs((Z[j+1]-Z[j])-dZ) <= coordinate_tol, 1:nz-1) ||
        throw(ArgumentError("solver Jtor grid is not uniform"))

    function parse_grid(key::Symbol, label::String)
        source = diagnostic[key]
        source isa AbstractVector && length(source) == nr ||
            throw(ArgumentError("$label R dimension mismatch"))
        grid = Matrix{Float64}(undef, nr, nz)
        for i in 1:nr
            source[i] isa AbstractVector && length(source[i]) == nz ||
                throw(ArgumentError("$label Z dimension mismatch"))
            for j in 1:nz
                grid[i,j] = _freegs_finite(source[i][j], "$label[$i,$j]")
            end
        end
        grid
    end
    solver_grid = parse_grid(:solver_eq_Jtor_A_per_m2, "solver eq.Jtor A/m2")
    profile_grid = parse_grid(:recomputed_final_psi_Jphi_A_per_m2,
        "recomputed final-psi Jphi A/m2")
    delta = solver_grid .- profile_grid
    all(isfinite, delta) || throw(ArgumentError("solver Jtor difference grid overflowed"))
    area = Matrix{Float64}(undef, nr, nz)
    for i in 1:nr, j in 1:nz
        area[i,j] = dR*dZ*(i == 1 || i == nr ? 0.5 : 1.0)*
            (j == 1 || j == nz ? 0.5 : 1.0)
    end
    all(isfinite, area) || throw(ArgumentError("solver Jtor quadrature weights overflowed"))
    difference_linf = maximum(abs, delta)
    solver_l2 = sqrt(sum(abs2, solver_grid))
    profile_l2 = sqrt(sum(abs2, profile_grid))
    difference_l2 = sqrt(sum(abs2, delta))
    relative_l2 = difference_l2 / max(solver_l2, profile_l2, 1.0e-300)
    all(isfinite, (solver_l2, profile_l2, difference_l2, relative_l2)) ||
        throw(ArgumentError("solver Jtor comparison norms overflowed"))
    solver_integral = sum(solver_grid .* area)
    profile_integral = sum(profile_grid .* area)
    difference_integral = sum(delta .* area)
    norms = _freegs_require_object(diagnostic[:solver_minus_recomputed_norms],
        "solver Jtor comparison norms", (:difference_Linf_A_per_m2,
        :difference_L2_frobenius_A_per_m2, :relative_difference_L2_dimensionless,
        :difference_RZ_trapezoid_integral_A))
    integrals = _freegs_require_object(diagnostic[:current_integrals],
        "solver Jtor current integrals", (:solver_eq_Jtor_RZ_trapezoid_A,
        :recomputed_final_psi_Jphi_RZ_trapezoid_A,
        :difference_solver_minus_recomputed_trapezoid_A,
        :solver_eq_plasmaCurrent_Romberg_A))
    function check_reported(actual, recorded, label; atol=1.0e-8)
        value = _freegs_finite(recorded, label)
        isfinite(actual) || throw(ArgumentError("$label recomputation overflowed"))
        abs(actual-value) <= max(atol, 1.0e-11*max(abs(actual),abs(value))) ||
            throw(ArgumentError("$label does not match the signed RZ data"))
        value
    end
    check_reported(difference_linf, norms[:difference_Linf_A_per_m2], "Jtor Linf")
    check_reported(difference_l2, norms[:difference_L2_frobenius_A_per_m2], "Jtor L2")
    check_reported(relative_l2, norms[:relative_difference_L2_dimensionless], "Jtor relative L2";
        atol=1.0e-13)
    check_reported(difference_integral, norms[:difference_RZ_trapezoid_integral_A],
        "Jtor norm difference integral"; atol=1.0e-7)
    check_reported(solver_integral, integrals[:solver_eq_Jtor_RZ_trapezoid_A],
        "solver Jtor trapezoid integral"; atol=1.0e-7)
    check_reported(profile_integral, integrals[:recomputed_final_psi_Jphi_RZ_trapezoid_A],
        "profile Jphi trapezoid integral"; atol=1.0e-7)
    check_reported(difference_integral,
        integrals[:difference_solver_minus_recomputed_trapezoid_A],
        "solver Jtor difference integral"; atol=1.0e-7)
    equilibrium = get(output, :equilibrium, nothing)
    equilibrium isa AbstractDict || throw(ArgumentError("FreeGS equilibrium summary is missing"))
    solver_current = _freegs_finite(integrals[:solver_eq_plasmaCurrent_Romberg_A],
        "solver Jtor Romberg plasma current")
    solver_current == _freegs_finite(equilibrium[:plasma_current_a],
        "reported solver plasma current") ||
        throw(ArgumentError("solver Jtor Romberg current binding mismatch"))
    matrix_tuple(A) = Tuple(Tuple(A[i,j] for j in 1:nz) for i in 1:nr)
    (status=:present,
     reason=:accepted_final_equilibrium_last_solve_vs_recomputed_final_psi_profile,
     representation=:FreeGS_eq_Jtor_last_linear_solve_RZ_nodes,
     axis_order=:R_then_Z, R_m=R, Z_m=Z,
     solver_eq_Jtor_A_per_m2=matrix_tuple(solver_grid),
     recomputed_final_psi_Jphi_A_per_m2=matrix_tuple(profile_grid),
     area_weight_m2=matrix_tuple(area), dR_m=dR, dZ_m=dZ,
     solver_minus_recomputed_norms=(difference_Linf_A_per_m2=difference_linf,
        difference_L2_frobenius_A_per_m2=difference_l2,
        relative_difference_L2_dimensionless=relative_l2,
        difference_RZ_trapezoid_integral_A=difference_integral),
     current_integrals=(solver_eq_Jtor_RZ_trapezoid_A=solver_integral,
        recomputed_final_psi_Jphi_RZ_trapezoid_A=profile_integral,
        difference_solver_minus_recomputed_trapezoid_A=difference_integral,
        solver_eq_plasmaCurrent_Romberg_A=solver_current))
end

function _freegs_lcfs_identity(output, input, context, receipt)
    for (key, expected) in ((:context_hash, string(context.context_hash)),
            (:candidate_hash, string(context.candidate_hash)),
            (:compiled_prefix_hash, string(context.compiled.prefix_hash)),
            (:physical_subject_hash, string(context.subject.physical_subject_hash)),
            (:scenario_hash, string(context.scenario_hash)),
            (:binding_hash, string(receipt.binding_hash)))
        haskey(output, key) && String(output[key]) == expected ||
            throw(ArgumentError("LCFS output identity mismatch: $key"))
        haskey(input, key) && String(input[key]) == expected ||
            throw(ArgumentError("LCFS input identity mismatch: $key"))
    end
    haskey(output, :result_hash) && String(output[:result_hash]) == string(receipt.backend_result_hash) ||
        throw(ArgumentError("LCFS backend result hash mismatch"))
    true
end

"""Read opt-in same-final-equilibrium LCFS and actuator data from accepted artifacts.

The result is a screen-only numerical input. Coil responses hold the solved
plasma, geometry, and profile fixed; they do not close the nonlinear MHD system.
"""
function _freegs_parse_lcfs_offgrid_method(raw)
    raw===nothing && return nothing
    expected=(schema="lcfs_offgrid_source_v1",psi_method="FreeGS_Equilibrium_psiRZ",
        btor_method="FreeGS_Equilibrium_Btor",profile_method="linked_sampled_profiles_at_eq_psi_normalized",
        mask_method="sampled_eq_mask_func_RectBivariateSpline_value_and_first_derivatives",
        mask_support_comparison="numpy_array_equal_sampled_eq_mask_vs_refreshed_core_mask",
        gradient_method="analytic_installed_FreeGS_Greens_sum_weighted_by_current_times_turns",
        gradient_validation="centered_difference_of_installed_FreeGS_Greens_source_per_LCFS_point",
        gradient_validation_rtol=5.0e-6,gradient_validation_atol_Wb_per_rad_m=1.0e-12,
        gradient_support_rule="typed_absent_on_any_clipped_or_singular_source_stencil_or_gradient_mismatch")
    row=_freegs_require_object(raw,"LCFS offgrid source method",keys(expected))
    all(k->row[k]==getproperty(expected,k),keys(expected)) ||
        throw(ArgumentError("LCFS offgrid source method differs from supported source"))
    expected
end

function _freegs_parse_lcfs_offgrid_source(raw,R,law,profile_axis,profile_boundary)
    raw===nothing && return (status=:typed_absent,reason=:offgrid_source_not_emitted)
    raw isa AbstractDict && haskey(raw,:status) || throw(ArgumentError("LCFS offgrid source is malformed"))
    representation="linked_copied_equilibrium_profile_at_lcfs_point"
    if raw[:status]=="typed_absent"
        Set(keys(raw)) in (Set((:status,:reason,:representation)),Set((:status,:reason,:representation,:detail_reason))) ||
            throw(ArgumentError("LCFS offgrid absence fields mismatch"))
        raw[:reason] in ("offgrid_source_evaluation_failed","offgrid_source_evaluation_unavailable") &&
            raw[:representation]==representation || throw(ArgumentError("LCFS offgrid absence provenance mismatch"))
        haskey(raw,:detail_reason) && !(raw[:detail_reason] isa AbstractString) &&
            throw(ArgumentError("LCFS offgrid absence detail is malformed"))
        return (status=:typed_absent,reason=Symbol(raw[:reason]),detail_reason=String(get(raw,:detail_reason,"")))
    end
    raw[:status]=="present" || throw(ArgumentError("LCFS offgrid source status is invalid"))
    scalars=(:psi_physical_wb_per_rad,:coil_psi_wb_per_rad,:eq_psi_axis_wb_per_rad,
        :eq_psi_boundary_wb_per_rad,:profile_psi_axis_wb_per_rad,:profile_psi_boundary_wb_per_rad,
        :mask_value,:Btor_T,:profile_pressure_Pa,:fpol_T_m,:psi_normalized)
    fields=(:status,:reason,:representation,scalars...,:mask_gradient_RZ_per_m,:mask_source,
        :mask_matches_refreshed_current_support,:coil_psi_gradient_status,:coil_psi_gradient_reason,:branch_metadata)
    haskey(raw,:coil_psi_gradient_status) || throw(ArgumentError("LCFS coil gradient status missing"))
    gradient_present=raw[:coil_psi_gradient_status]=="present"
    raw[:coil_psi_gradient_status] in ("present","typed_absent") ||
        throw(ArgumentError("LCFS coil gradient status invalid"))
    _freegs_require_object(raw,"LCFS offgrid source",gradient_present ?
        (fields...,:coil_psi_gradient_RZ_Wb_per_rad_m) : fields)
    raw[:reason]=="actual_linked_freegs_source_evaluations" && raw[:representation]==representation ||
        throw(ArgumentError("LCFS offgrid source provenance mismatch"))
    values=NamedTuple{scalars}(Tuple(_freegs_finite(raw[k],"LCFS offgrid $(k)") for k in scalars))
    values.eq_psi_axis_wb_per_rad!=values.eq_psi_boundary_wb_per_rad &&
        values.profile_psi_axis_wb_per_rad==profile_axis &&
        values.profile_psi_boundary_wb_per_rad==profile_boundary ||
        throw(ArgumentError("LCFS offgrid source axis binding mismatch"))
    isapprox((values.psi_physical_wb_per_rad-values.eq_psi_axis_wb_per_rad)/
        (values.eq_psi_boundary_wb_per_rad-values.eq_psi_axis_wb_per_rad),values.psi_normalized;
        rtol=1e-12,atol=1e-12) || throw(ArgumentError("LCFS offgrid normalization mismatch"))
    raw[:mask_source]=="sampled_eq.mask_func RectBivariateSpline of sampled_eq.mask" &&
        raw[:mask_matches_refreshed_current_support] isa Bool ||
        throw(ArgumentError("LCFS actual Btor mask source is missing"))
    # The mask may overshoot and need not equal the refreshed native core mask.
    function pair(k)
        a=raw[k];a isa AbstractVector && length(a)==2 ||
            throw(ArgumentError("LCFS offgrid gradient must contain R/Z entries"))
        Tuple(_freegs_finite(v,"LCFS offgrid $(k)") for v in a)
    end
    mask_gradient=pair(:mask_gradient_RZ_per_m)
    gradient_reason=gradient_present ? "analytic_greens_gradient_checked_against_source_centered_difference" :
        "coil_psi_gradient_clip_singularity_or_source_difference_failed"
    raw[:coil_psi_gradient_reason]==gradient_reason || throw(ArgumentError("LCFS gradient support reason mismatch"))
    gradient=gradient_present ? pair(:coil_psi_gradient_RZ_Wb_per_rad_m) : nothing
    branch=_freegs_require_object(raw[:branch_metadata],"LCFS offgrid source branch",
        (:profile_type,:fpol_sqrt_branch,:fpol_positive_checked,:pressure_evaluation,
         :psi_normalization_axis_pair,:profile_integral_axis_pair,:eq_profile_axis_pairs_equal))
    branch[:profile_type]=="ConstrainPaxisIp" && branch[:fpol_sqrt_branch]=="positive" &&
        branch[:fpol_positive_checked]===true && values.fpol_T_m>0 &&
        branch[:pressure_evaluation]=="FreeGS_profile_pressure_at_eq_normalized_psi" &&
        branch[:psi_normalization_axis_pair]=="equilibrium" && branch[:profile_integral_axis_pair]=="profile" ||
        throw(ArgumentError("LCFS offgrid profile branch unsupported"))
    eq_profile_equal=values.eq_psi_axis_wb_per_rad==profile_axis && values.eq_psi_boundary_wb_per_rad==profile_boundary
    branch[:eq_profile_axis_pairs_equal] isa Bool && branch[:eq_profile_axis_pairs_equal]==eq_profile_equal ||
        throw(ArgumentError("LCFS equilibrium/profile axis equality assertion is false"))
    expected_B=(values.mask_value*values.fpol_T_m+(1-values.mask_value)*law.fvac_T_m)/R
    isapprox(values.Btor_T,expected_B;rtol=128eps(Float64),atol=128eps(Float64)*max(1.0,abs(expected_B))) ||
        throw(ArgumentError("LCFS executed Btor differs from its masked source law"))
    merge(values,(status=:present,reason=:actual_linked_freegs_source_evaluations,
        mask_gradient_RZ_per_m=mask_gradient,mask_source=String(raw[:mask_source]),
        mask_matches_refreshed_current_support=raw[:mask_matches_refreshed_current_support],
        eq_profile_axis_pairs_equal=eq_profile_equal,
        coil_psi_gradient_status=gradient_present ? :present : :typed_absent,
        coil_psi_gradient_reason=Symbol(gradient_reason),coil_psi_gradient_RZ_Wb_per_rad_m=gradient))
end

function freegs_axisymmetric_lcfs_trace_samples(context::ForwardChainContextV4,
        artifacts::FreeGSAxisymmetricExecutionArtifactsV4)
    receipt = artifacts.receipt
    validate_freegs_axisymmetric_receipt(context, receipt)
    receipt.status === :physical_model_screen && receipt.exit_code == 0 ||
        return _freegs_typed_absent_lcfs("freegs_screen_not_accepted")
    isempty(artifacts.input_json) && throw(ArgumentError("accepted FreeGS input bytes are missing"))
    _freegs_sha256_text(artifacts.input_json) == receipt.input_hash ||
        throw(ArgumentError("FreeGS input artifact hash mismatch"))
    input = JSON3.read(artifacts.input_json)
    input isa AbstractDict || throw(ArgumentError("FreeGS input artifact is not an object"))
    haskey(input, :solver_input) && input[:solver_input] isa AbstractDict ||
        throw(ArgumentError("FreeGS solver input is missing"))
    solver = input[:solver_input]
    requested = haskey(solver, :sample_lcfs_trace) && solver[:sample_lcfs_trace] === true
    haskey(solver, :sample_lcfs_trace) && solver[:sample_lcfs_trace] isa Bool ||
        !haskey(solver, :sample_lcfs_trace) ||
        throw(ArgumentError("FreeGS LCFS trace opt-in is malformed"))
    isempty(artifacts.output_json) && throw(ArgumentError("accepted FreeGS output bytes are missing"))
    _freegs_sha256_text(artifacts.output_json) == receipt.output_hash ||
        throw(ArgumentError("FreeGS output artifact hash mismatch"))
    output = JSON3.read(artifacts.output_json)
    output isa AbstractDict || throw(ArgumentError("FreeGS output artifact is not an object"))
    _freegs_lcfs_identity(output, input, context, receipt)
    if !requested
        !haskey(output, :lcfs_trace) ||
            throw(ArgumentError("unrequested FreeGS LCFS trace was emitted"))
        return _freegs_typed_absent_lcfs("trace_not_requested")
    end
    haskey(output, :lcfs_trace) || throw(ArgumentError("requested FreeGS LCFS trace is missing"))
    trace = output[:lcfs_trace]
    trace isa AbstractDict && haskey(trace, :status) ||
        throw(ArgumentError("FreeGS LCFS trace is malformed"))
    trace_status = String(trace[:status])
    if trace_status == "typed_absent"
        Set(collect(keys(trace))) == Set((:status, :reason, :representation)) ||
            throw(ArgumentError("typed-absent LCFS trace fields mismatch"))
        return _freegs_typed_absent_lcfs(String(trace[:reason]))
    end
    trace_status == "present" || throw(ArgumentError("FreeGS LCFS trace status is unauthorized"))
    trace_keys = (:status, :reason, :representation, :psi_axis_wb_per_rad,
        :psi_boundary_wb_per_rad, :mu0_N_per_A2, :profile_boundary_pressure_Pa,
        :profile_law, :coil_current_semantics, :coil_response_method,
        :coil_response_identity_max_abs_error_T, :coils, :samples)
    trace_keys_with_current = (trace_keys..., :current_support)
    trace isa AbstractDict && Set(collect(keys(trace))) in
        (Set(trace_keys), Set(trace_keys_with_current),
         Set((trace_keys...,:offgrid_source_method)), Set((trace_keys_with_current...,:offgrid_source_method))) ||
        throw(ArgumentError("LCFS trace fields mismatch"))
    String(trace[:reason]) == "same_final_equilibrium_lcfs_trace" ||
        throw(ArgumentError("LCFS trace provenance mismatch"))
    String(trace[:representation]) == "final_total_psi_grid_spline_radial_lcfs" ||
        throw(ArgumentError("LCFS trace representation mismatch"))
    psi_axis = _freegs_finite(trace[:psi_axis_wb_per_rad], "LCFS psi_axis_wb_per_rad")
    psi_boundary = _freegs_finite(trace[:psi_boundary_wb_per_rad], "LCFS psi_boundary_wb_per_rad")
    psi_axis != psi_boundary || throw(ArgumentError("LCFS psi span is zero"))
    mu0_value = _freegs_finite(trace[:mu0_N_per_A2], "LCFS mu0_N_per_A2"; positive=true)
    p_boundary = _freegs_finite(trace[:profile_boundary_pressure_Pa], "LCFS profile boundary pressure"; nonnegative=true)
    profile = _freegs_require_object(trace[:profile_law], "LCFS profile law",
        (:L_A_per_m2, :Beta0, :alpha_m, :alpha_n, :Raxis_m, :fvac_T_m))
    profile_law = (
        L_A_per_m2=_freegs_finite(profile[:L_A_per_m2], "profile L_A_per_m2"),
        Beta0=_freegs_finite(profile[:Beta0], "profile Beta0"),
        alpha_m=_freegs_finite(profile[:alpha_m], "profile alpha_m"; positive=true),
        alpha_n=_freegs_finite(profile[:alpha_n], "profile alpha_n"; positive=true),
        Raxis_m=_freegs_finite(profile[:Raxis_m], "profile Raxis_m"; positive=true),
        fvac_T_m=_freegs_finite(profile[:fvac_T_m], "profile fvac_T_m"))
    String(trace[:coil_current_semantics]) ==
        "current_A_per_turn; turns reported separately; actuator response is T per A-per-turn at fixed plasma/geometry/profile" ||
        throw(ArgumentError("LCFS actuator current semantics mismatch"))
    String(trace[:coil_response_method]) ==
        "FreeGS tokamak.controlBr/controlBz on the same final equilibrium; each response includes that coil's turns" ||
        throw(ArgumentError("LCFS actuator response provenance mismatch"))

    input_machine = get(solver, :machine, nothing)
    input_machine isa AbstractDict && haskey(input_machine, :coils) ||
        throw(ArgumentError("LCFS candidate coil input is missing"))
    input_coils = input_machine[:coils]
    input_coils isa AbstractVector || throw(ArgumentError("LCFS candidate coils must be an array"))
    expected_ids = Tuple(String(c[:id]) for c in input_coils)
    length(expected_ids) == 4 || throw(ArgumentError("LCFS trace requires the declared four-coil candidate"))
    length(unique(expected_ids)) == length(expected_ids) || throw(ArgumentError("candidate coil IDs are not unique"))
    coils_doc = trace[:coils]
    coils_doc isa AbstractVector && length(coils_doc) == length(expected_ids) ||
        throw(ArgumentError("LCFS coil count mismatch"))
    coil_current_doc = get(output, :coil_currents_a, nothing)
    coil_current_doc isa AbstractDict || throw(ArgumentError("FreeGS solved coil currents are missing"))
    Set(String(k) for k in keys(coil_current_doc)) == Set(expected_ids) ||
        throw(ArgumentError("FreeGS solved coil current IDs mismatch"))
    coil_fields = (:coil_id, :major_radius_m, :vertical_position_m,
        :current_A_per_turn, :turns, :ampere_turns_A, :control)
    coils = Tuple(begin
        row = _freegs_require_object(coils_doc[i], "LCFS coil", coil_fields)
        candidate = input_coils[i]
        String(row[:coil_id]) == expected_ids[i] || throw(ArgumentError("LCFS coil order mismatch"))
        R = _freegs_finite(row[:major_radius_m], "coil major_radius_m"; positive=true)
        Z = _freegs_finite(row[:vertical_position_m], "coil vertical_position_m")
        R == _freegs_finite(candidate[:major_radius_m], "candidate coil major_radius_m"; positive=true) &&
            Z == _freegs_finite(candidate[:vertical_position_m], "candidate coil vertical_position_m") ||
            throw(ArgumentError("LCFS coil geometry differs from candidate input"))
        current = _freegs_finite(row[:current_A_per_turn], "coil current_A_per_turn")
        turns = _freegs_integer(row[:turns], "coil turns")
        ampere_turns = _freegs_finite(row[:ampere_turns_A], "coil ampere_turns_A")
        abs(ampere_turns - current * turns) <= 8eps(Float64) * max(1.0, abs(ampere_turns)) ||
            throw(ArgumentError("LCFS coil ampere-turn identity mismatch"))
        row[:control] === true || throw(ArgumentError("LCFS candidate coil is not a controlled PF coil"))
        abs(_freegs_finite(coil_current_doc[Symbol(expected_ids[i])], "solved coil current") - current) <=
            8eps(Float64) * max(1.0, abs(current)) ||
            throw(ArgumentError("LCFS current differs from accepted solved current"))
        (coil_id=expected_ids[i], major_radius_m=R, vertical_position_m=Z,
         current_A_per_turn=current, turns=turns, ampere_turns_A=ampere_turns,
         control=true)
    end for i in eachindex(expected_ids))

    sample_rows = trace[:samples]
    sample_rows isa AbstractVector && length(sample_rows) == 64 ||
        throw(ArgumentError("LCFS trace must contain exactly 64 samples"))
    sample_fields = (:R_m, :Z_m, :normal_R, :normal_Z, :psi_normalized,
        :psi_wb_per_rad, :Br_T, :Btor_T, :Bz_T, :pressure_Pa, :F_T_m,
        :Jphi_A_per_m2, :core_mask_inside, :core_mask_outside, :coil_Br_T,
        :coil_Bz_T, :coil_response)
    response_fields = (:coil_id, :current_A_per_turn, :turns,
        :dBr_dI_per_turn_T_per_A, :dBz_dI_per_turn_T_per_A)
    offgrid_method=_freegs_parse_lcfs_offgrid_method(get(trace,:offgrid_source_method,nothing))
    sample_values = Tuple(begin
        sample_has_source=haskey(sample_rows[i],:offgrid_source)
        sample_has_source==(offgrid_method!==nothing) || throw(ArgumentError("LCFS offgrid sample/method presence differs"))
        row = _freegs_require_object(sample_rows[i], "LCFS sample",
            sample_has_source ? (sample_fields...,:offgrid_source) : sample_fields)
        vals = NamedTuple{(:R_m, :Z_m, :normal_R, :normal_Z, :psi_normalized,
            :psi_wb_per_rad, :Br_T, :Btor_T, :Bz_T, :pressure_Pa, :F_T_m,
            :Jphi_A_per_m2, :core_mask_inside, :core_mask_outside, :coil_Br_T,
            :coil_Bz_T)}(Tuple(_freegs_finite(row[key], "LCFS sample $(key)") for key in sample_fields[1:end-1]))
        vals.R_m > 0 && vals.pressure_Pa >= 0 && abs(vals.psi_normalized - 1.0) <= 1.0e-9 ||
            throw(ArgumentError("LCFS sample is outside its declared flux/profile support"))
        isapprox((vals.psi_wb_per_rad - psi_axis) / (psi_boundary - psi_axis),
            vals.psi_normalized; rtol=1.0e-12, atol=1.0e-12) ||
            throw(ArgumentError("LCFS absolute and normalized flux values differ"))
        isapprox(vals.F_T_m, vals.R_m * vals.Btor_T; rtol=128eps(Float64), atol=0.0) &&
            isapprox(vals.F_T_m, profile_law.fvac_T_m; rtol=128eps(Float64), atol=0.0) ||
            throw(ArgumentError("LCFS toroidal profile endpoint fields differ"))
        abs(hypot(vals.normal_R, vals.normal_Z) - 1.0) <= 1.0e-8 ||
            throw(ArgumentError("LCFS normal is not unit length"))
        vals.core_mask_inside == 1.0 && vals.core_mask_outside == 0.0 ||
            throw(ArgumentError("LCFS core-mask side support is invalid"))
        responses_doc = row[:coil_response]
        responses_doc isa AbstractVector && length(responses_doc) == length(coils) ||
            throw(ArgumentError("LCFS sample actuator response count mismatch"))
        responses = Tuple(begin
            response = _freegs_require_object(responses_doc[j], "LCFS actuator response", response_fields)
            String(response[:coil_id]) == coils[j].coil_id || throw(ArgumentError("LCFS response coil order mismatch"))
            current = _freegs_finite(response[:current_A_per_turn], "response current_A_per_turn")
            turns = _freegs_integer(response[:turns], "response turns")
            current == coils[j].current_A_per_turn && turns == coils[j].turns ||
                throw(ArgumentError("LCFS response current binding mismatch"))
            (coil_id=coils[j].coil_id, current_A_per_turn=current, turns=turns,
             dBr_dI_per_turn_T_per_A=_freegs_finite(response[:dBr_dI_per_turn_T_per_A], "dBr/dI per turn"),
             dBz_dI_per_turn_T_per_A=_freegs_finite(response[:dBz_dI_per_turn_T_per_A], "dBz/dI per turn"))
        end for j in eachindex(coils))
        reconstructed_br = sum(responses[j].current_A_per_turn * responses[j].dBr_dI_per_turn_T_per_A for j in eachindex(responses))
        reconstructed_bz = sum(responses[j].current_A_per_turn * responses[j].dBz_dI_per_turn_T_per_A for j in eachindex(responses))
        scale_br = max(1.0, abs(vals.coil_Br_T),
            sum(abs(responses[j].current_A_per_turn * responses[j].dBr_dI_per_turn_T_per_A) for j in eachindex(responses)))
        scale_bz = max(1.0, abs(vals.coil_Bz_T),
            sum(abs(responses[j].current_A_per_turn * responses[j].dBz_dI_per_turn_T_per_A) for j in eachindex(responses)))
        tolerance_br, tolerance_bz = 128eps(Float64) * scale_br, 128eps(Float64) * scale_bz
        abs(reconstructed_br - vals.coil_Br_T) <= tolerance_br &&
            abs(reconstructed_bz - vals.coil_Bz_T) <= tolerance_bz ||
            throw(ArgumentError("LCFS coil response superposition identity mismatch"))
        offgrid=_freegs_parse_lcfs_offgrid_source(get(row,:offgrid_source,nothing),vals.R_m,
            profile_law,psi_axis,psi_boundary)
        merge(vals, (coil_response=responses,offgrid_source=offgrid))
    end for i in eachindex(sample_rows))
    identity_error = _freegs_finite(trace[:coil_response_identity_max_abs_error_T],
        "LCFS coil response identity error"; nonnegative=true)
    identity_error <= 1.0e-10 * max(1.0, maximum(abs(row.coil_Br_T) for row in sample_values),
        maximum(abs(row.coil_Bz_T) for row in sample_values)) ||
        throw(ArgumentError("LCFS reported coil response identity error exceeds tolerance"))
    current_support = haskey(trace, :current_support) ?
        _freegs_parse_native_current_support(trace[:current_support], solver, output,
            psi_axis, psi_boundary;
            critical_point_refinement=_freegs_context_binding(context).declaration.profile.critical_point_refinement) :
        (status=:typed_absent, reason=:native_current_support_not_emitted,
         representation=:final_psi_profile_native_grid_Jphi)
    solver_jtor_diagnostic = _freegs_parse_solver_jtor_diagnostic(
        get(output, :solver_jtor_diagnostic, nothing), solver, output)
    if current_support.status === :present && solver_jtor_diagnostic.status === :present
        solver_jtor_diagnostic.recomputed_final_psi_Jphi_A_per_m2 ==
            current_support.Jphi_A_per_m2 ||
            throw(ArgumentError("solver Jtor comparison differs from accepted native current support"))
        solver_jtor_diagnostic.R_m == current_support.R_m &&
            solver_jtor_diagnostic.Z_m == current_support.Z_m ||
            throw(ArgumentError("solver Jtor diagnostic grid differs from native current grid"))
    end
    (status=:present, reason=:same_final_equilibrium_lcfs_trace,
     representation=:final_total_psi_grid_spline_radial_lcfs,
     psi_axis_wb_per_rad=psi_axis, psi_boundary_wb_per_rad=psi_boundary,
     mu0_N_per_A2=mu0_value, profile_boundary_pressure_Pa=p_boundary,
     profile_law=profile_law, coil_current_semantics=String(trace[:coil_current_semantics]),
     coil_response_method=String(trace[:coil_response_method]),
     coil_response_identity_max_abs_error_T=identity_error,
     coils=coils, samples=sample_values, current_support=current_support,
     offgrid_source_method=offgrid_method,
     solver_jtor_diagnostic=solver_jtor_diagnostic)
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
