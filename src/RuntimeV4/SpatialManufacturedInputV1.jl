# Closed numerical N1 input/provider. Definitions only; no include-time execution,
# no DESC authority, no alternate residual or nonlinear solver.
using FusionConceptAI, LinearAlgebra, SHA
import FusionConceptAI: semantic_view, canonical_hash

const _SMM_SOURCE_V1=abspath(@__FILE__)
const _SMM_LOADED_SHA_V1=bytes2hex(SHA.sha256(read(_SMM_SOURCE_V1)))
const _SMM_REVISION_V1="spatial-manufactured-n1-input-v1"
const _SMR_MANUFACTURED_REVISION_V1="spatial-q1-static-mhd-manufactured-n1-bounded-step-v1"
const _SMR_G2_THREE_REGION_SOURCE_REVISION_V1="spatial-q1-static-mhd-g2-three-region-source-v1"
const _SMM_CANDIDATE_ID_V1="spatial-coupled-manufactured-n1-bounded-step-v1"
const _SMM_NCOORD_V1=OperatorRefV1("SPATIAL_MANUFACTURED_CIRCULAR_COORDINATE_V1","v1")
const _SMM_NMETRIC_V1=OperatorRefV1("SPATIAL_MANUFACTURED_CIRCULAR_METRIC_V1","v1")
const _SMM_NCOORD_M1N1_V1=OperatorRefV1("SPATIAL_MANUFACTURED_M1N1_COORDINATE_V1","v1")
const _SMM_NMETRIC_M1N1_V1=OperatorRefV1("SPATIAL_MANUFACTURED_M1N1_METRIC_V1","v1")
const _SMM_COORD_V1=OperatorRefV1("RUNTIME_V4_SUPPORT_SCALE_COORDINATE","v1")
const _SMM_METRIC_V1=OperatorRefV1("RUNTIME_V4_SUPPORT_SCALE_METRIC","v1")

_smm_view_v1(x)=NamedTuple{fieldnames(typeof(x))}(Tuple(getfield(x,k) for k in fieldnames(typeof(x))))
_smm_matrix_v1(A)=ntuple(i->ntuple(j->A[i,j],3),3)
_smm_is_declaration_v1(d)=d.revision==_SMR_MANUFACTURED_REVISION_V1
_smm_is_g2_three_region_source_v1(d)=d.revision==_SMR_G2_THREE_REGION_SOURCE_REVISION_V1

function spatial_manufactured_provider_identity_v1()
    bytes2hex(SHA.sha256(read(_SMM_SOURCE_V1)))==_SMM_LOADED_SHA_V1 ||
        throw(ArgumentError("manufactured provider source changed after loading"))
    bytes2hex(SHA.sha256(read(_SMR_SOURCE)))==_SMR_LOADED_SOURCE_SHA ||
        throw(ArgumentError("manufactured shared geometry/assembly dependency changed after loading"))
    (revision="spatial-manufactured-analytic-provider-v1",model=:n1_toroidal_polynomial,
        implementation_sha256=_SMM_LOADED_SHA_V1,spatial_dependency_sha256=_SMR_LOADED_SOURCE_SHA,scope=:manufactured_numerical_only,
        desc_execution=:not_executed,physical_validation=:unsupported,authority=:no_publish)
end

struct SpatialManufacturedNumericalInputV1
    revision::String
    geometry::NamedTuple
    fields::NamedTuple
    initialization::NamedTuple
    mesh::NamedTuple
    quadrature::NamedTuple
    boundary::NamedTuple
    flux::NamedTuple
    numerics::NamedTuple
    provenance::NamedTuple
end
semantic_view(x::SpatialManufacturedNumericalInputV1)=_smm_view_v1(x)
canonical_hash(x::SpatialManufacturedNumericalInputV1)=canonical_hash(semantic_view(x))

_smm_tesla_unit_v1()=UnitSignature((1,0,-2,-1,0,0,0))
_smm_tesla_per_m_unit_v1()=UnitSignature((1,-1,-2,-1,0,0,0))
_smm_outward_conormal_type_v1()=PhysicalType(:outward_unit_conormal,1,3,
    TemporalTypeV1(static_time),UnitSignature())
_smm_normal_field_type_v1()=PhysicalType(:normal_magnetic_field,0,0,
    TemporalTypeV1(static_time),_smm_tesla_unit_v1())
function _smm_m1n1_normal_law_v1(geometry,beta_T_m)
    field=(model=:beta_R_e_phi,beta_T_m=Float64(beta_T_m),unit="T m^-1",
        unit_signature=_smm_tesla_per_m_unit_v1(),component_law=:B_cyl_equals_0_beta_R_0)
    (schema="spatial-manufactured-normal-field-law-v1",
        model=:m1n1_analytic_B_dot_outward_unit_conormal,
        geometry_map_hash=canonical_hash(geometry),field=field,field_hash=canonical_hash(field),
        conormal=(coordinate=:rho,location=:rho_1,direction=:outward_increasing_rho,
            construction=:normalized_E_inverse_transpose_e_rho,
            unnormalized_phi_component=:rho_epsilon_sin_zeta_over_D_R,
            physical_type=_smm_outward_conormal_type_v1()),
        formula=:beta_a_rho_epsilon_sin_zeta_over_sqrt_D_plus_metric_term,
        formula_text="beta*a*rho*epsilon*sin(zeta)/sqrt(D+(a*rho*epsilon*sin(zeta)/R)^2)",
        formula_parameters=(D=:one_plus_epsilon_squared_plus_two_epsilon_cos_zeta,
            R=:m1n1_mapped_cylindrical_major_radius,
            map_hash=canonical_hash(geometry)),
        output=(quantity=:B_dot_outward_conormal,unit="T",
            unit_signature=_smm_tesla_unit_v1(),physical_type=_smm_normal_field_type_v1()),
        evaluation=:pointwise_outer_face_quadrature,no_constant_scalar=true)
end
function _smm_validate_m1n1_normal_law_v1(x,law;bind_input::Bool=false)
    x.geometry.model===:m1n1_ripple_torus || throw(ArgumentError("m1n1 normal law requires its mapped geometry"))
    expected=_smm_m1n1_normal_law_v1(x.geometry,x.fields.beta_T_m)
    bind_input && (expected=merge(expected,(input_hash=canonical_hash(x),)))
    canonical_json(law)==canonical_json(expected) ||
        throw(ArgumentError("manufactured normal law is not bound to this geometry, field, units, and candidate input"))
    true
end

"Return a frozen manufactured input at the unchanged coarse, Q1_4, or Q1_8 level."
function spatial_n1_manufactured_input_v1(; level::Symbol=:coarse,interior_map::Symbol=:circular_v1)
    mesh = if level === :coarse
        (level=:coarse,original_benchmark_level=:q1_2,rho=(0.0,0.5,1.0),theta_count=2,zeta_per_period=2,
         nfp=1,unknowns=40,rows=289,space=:continuous_Q1_cylindrical_B_and_p)
    elseif level === :q1_4
        (level=:q1_4,original_benchmark_level=:q1_4,rho=(0.0,0.25,0.5,0.75,1.0),theta_count=4,zeta_per_period=4,
         nfp=1,unknowns=272,rows=2177,space=:continuous_Q1_cylindrical_B_and_p)
    elseif level === :q1_8
        (level=:q1_8,original_benchmark_level=:q1_8,
         rho=(0.0,0.125,0.25,0.375,0.5,0.625,0.75,0.875,1.0),theta_count=8,zeta_per_period=8,
         nfp=1,unknowns=2080,rows=16897,space=:continuous_Q1_cylindrical_B_and_p)
    else
        throw(ArgumentError("unsupported manufactured input level: $level"))
    end
    revision = level === :coarse ? _SMM_REVISION_V1 :
        level === :q1_4 ? "spatial-manufactured-n1-q1_4-input-v1" : "spatial-manufactured-n1-q1_8-input-v1"
    geometry=if interior_map===:circular_v1
        (model=:circular_torus,R0_m=3.0,minor_radius_m=1.0,nfp=1,support_scale_m=1.0,
         raw_chart=(:rho,:theta_radians,:zeta_radians),typed_chart=(:rho,:theta_turns,:zeta_turns),
         angle_pullback=(1.0,2pi,2pi),orientation=:detE_negative,
         cylindrical_basis=(:e_R,:e_phi,:e_Z),cartesian_rotation=:Q_phi,
         raw_metric=:E_rad_columns_dX_d_rho_theta_zeta,
         typed_jacobian=:Q_E_rad_D,typed_metric=:D_transpose_E_rad_transpose_E_rad_D,
         normalized_metric=:typed_metric_divided_by_support_scale_squared,
         radial_extension=:explicit_linear_minor_radius,axis=:merged_nodes,
         angular=:full_torus_periodic,unit="m")
    elseif interior_map===:m1n1_ripple_v1
        (model=:m1n1_ripple_torus,R0_m=3.0,minor_radius_m=1.0,ripple_amplitude=0.05,
         nfp=1,support_scale_m=1.0,
         raw_chart=(:rho,:theta_radians,:zeta_radians),typed_chart=(:rho,:theta_turns,:zeta_turns),
         angle_pullback=(1.0,2pi,2pi),orientation=:detE_negative,
         cylindrical_basis=(:e_R,:e_phi,:e_Z),cartesian_rotation=:Q_phi,
         raw_metric=:E_rad_columns_dX_d_rho_theta_zeta,
         typed_jacobian=:Q_E_rad_D,typed_metric=:D_transpose_E_rad_transpose_E_rad_D,
         normalized_metric=:typed_metric_divided_by_support_scale_squared,
         radial_extension=:explicit_linear_m1n1_toroidal_ripple,axis=:merged_nodes,
         angular=:full_torus_periodic,unit="m")
    else
        throw(ArgumentError("unsupported manufactured interior map: $interior_map"))
    end
    flux_wb=(1/3)*geometry.R0_m*pi*geometry.minor_radius_m^2*
        (geometry.model===:m1n1_ripple_torus ? (1+geometry.ripple_amplitude)^2 : 1.0)
    boundary=if geometry.model===:circular_torus
        (traction=:analytic_cauchy_stress_times_raw_normal,traction_unit="Pa",
         normal_model=:analytic_B_dot_raw_normal,analytic_normal_B_T=0.0,normal_unit="T",
         normal_roundoff=:retain_original_dot_arithmetic,closed_surface_flux=:analytically_zero)
    else
        (traction=:analytic_cauchy_stress_times_raw_normal,traction_unit="Pa",
         normal_model=:m1n1_analytic_B_dot_outward_unit_conormal,
         analytic_normal_B_T=nothing,normal_unit="T",
         normal_law=_smm_m1n1_normal_law_v1(geometry,1/3),
         normal_roundoff=:retain_original_dot_arithmetic,closed_surface_flux=:analytically_zero)
    end
    SpatialManufacturedNumericalInputV1(revision,
        geometry,
        (model=:beta_R_e_phi_polynomial_pressure,beta_T_m=1/3,alpha_Pa_m2=1.0e4,p0_Pa=1.0e5,
         mu0_N_A2=1.25663706127e-6,beta_unit="T m^-1",alpha_unit="Pa m^-2",p0_unit="Pa",mu0_unit="N A^-2",
         source_model=:cartesian_div_cauchy_stress,source_unit="N m^-3",
         pressure_profile_role=:manufactured_reference_not_solved_pressure_constraint),
        (model=:nodal_analytic_field_plus_constant_perturbation,
         perturbation=(0.11,-0.07,0.05,2.0e3),units=("T","T","T","Pa"),
         state_order=(:B_R,:B_phi,:B_Z,:p),traction_reference=:unperturbed_analytic_field),
        mesh,
        (rule=:tensor_gauss_legendre,order=3,roots=(-sqrt(3/5),0.0,sqrt(3/5)),weights=(5/9,8/9,5/9),
         volume_loop=(:iz,:it,:ir),volume_qp=:iz_minus_1_times_9_plus_it_minus_1_times_3_plus_ir,
         face_loop=(:j,:i),face_normal=:positive_coordinate_Einv_row_rotated_to_Cartesian,
         face_weight=:cross_other_E_columns_norm,incidence=:unchanged_mesh_left_plus_right_minus,
         volume_weight=:absolute_signed_detE,exact_faces=true),
        boundary,
        (model=geometry.model===:m1n1_ripple_torus ? :beta_R0_pi_a_squared_at_zeta_zero : :beta_R0_pi_a_squared,
         nominal_Wb=flux_wb,unit="Wb",cut=:positive_e_phi_zeta_zero),
        (max_iterations=12,seconds=level === :q1_8 ? 600.0 : 120.0,
         residual_tolerance=1.0e-6,gradient_tolerance=1.0e-10,
         rank_relative_tolerance=1.0e-10,kkt_absolute_tolerance=1.0e-10,line_search_steps=20,pressure_lower_Pa=0.0),
        (source_class=:manufactured_analytic_not_measured,
         original_n1_source_sha256="4bb989f792ccd022fc2354e1ee616a80bd2101e279ea13323a6d1412c8d8e9a0",
         provider=spatial_manufactured_provider_identity_v1(),evidence_authority=:none,publish=:no_publish,
         exterior_B_out=(status=:typed_absent,value=nothing),outer_K=(status=:typed_absent,value=nothing),
         return_current=(status=:typed_absent,value=nothing),pressure_current_topology=:not_fixed,
         desc_execution=:not_executed,physical_validation=:unsupported))
end

function validate_spatial_manufactured_input_v1(x::SpatialManufacturedNumericalInputV1)
    map_id=x.geometry.model===:circular_torus ? :circular_v1 :
        x.geometry.model===:m1n1_ripple_torus ? :m1n1_ripple_v1 : :unsupported
    expected=spatial_n1_manufactured_input_v1(;level=x.mesh.level,interior_map=map_id)
    canonical_json(x)==canonical_json(expected) || throw(ArgumentError("foreign manufactured input/units/model/policy"))
    x.fields.mu0_N_A2==_SMR_MU0 || throw(ArgumentError("manufactured mu0 differs from actual assembler"))
    true
end

function _smm_manufactured_declaration_validated_v1(x::SpatialManufacturedNumericalInputV1)
    b=spatial_multiregion_declaration_v4(flux_Wb=x.flux.nominal_Wb)
    identity=_smr_bounded_identity_v1()
    identity.policy.kkt_absolute_tolerance==x.numerics.kkt_absolute_tolerance || error("manufactured KKT policy mismatch")
    for key in (:residual_tolerance,:gradient_tolerance,:rank_relative_tolerance,:line_search_steps,:pressure_lower_Pa)
        getproperty(b.solver,key)==getproperty(x.numerics,key) || error("manufactured original solver gate mismatch: $key")
    end
    SpatialMultiRegionDeclarationV4(_SMR_MANUFACTURED_REVISION_V1,b.regions,
        Tuple(merge(s,(initial_source=:manufactured_analytic_plus_declared_perturbation,)) for s in b.states),b.interfaces,
        (equation="div(T)=source",model=:manufactured_n1_cartesian,input=x,unit="N m^-3",
         source="Canonical analytic manufactured input; not measured data"),
        (x.geometry.model===:circular_torus ?
            merge(b.boundary,(traction=:manufactured_analytic_reference,normal_B_T=0.0,normal_B_unit="T",
                normal_model=x.boundary.normal_model,input_hash=canonical_hash(x),source="Canonical manufactured boundary; exterior current closure absent")) :
            merge(b.boundary,(traction=:manufactured_analytic_reference,normal_B_T=nothing,normal_B_unit="T",
                normal_model=x.boundary.normal_model,
                normal_law=merge(x.boundary.normal_law,(input_hash=canonical_hash(x),)),
                input_hash=canonical_hash(x),source="M1N1 manufactured spatial B dot outward conormal law; exterior current closure absent"))),
        ((level=x.mesh.level,rho=x.mesh.rho,theta_count=x.mesh.theta_count,zeta_per_period=x.mesh.zeta_per_period),),
        (nominal_Wb=x.flux.nominal_Wb,interval_Wb=(x.flux.nominal_Wb,x.flux.nominal_Wb),unit="Wb",
         source="Canonical manufactured analytic flux; no observed-device claim",cut=:zeta_zero),
        ((case_id="n1_$(x.mesh.original_benchmark_level)",level=x.mesh.level,flux_Wb=x.flux.nominal_Wb),),b.parameters,b.quadrature,b.scaling,
        merge(b.solver,(method=identity.method,bounded_linear_step=identity,coarse_iterations=x.numerics.max_iterations,
            coarse_seconds=x.numerics.seconds)),
        (b.applicability...,:manufactured_numerical_only,:no_DESC_execution,:no_publish))
end
function spatial_n1_manufactured_declaration_v1(x::SpatialManufacturedNumericalInputV1)
    validate_spatial_manufactured_input_v1(x)
    _smm_manufactured_declaration_validated_v1(x)
end

"""Declare a geometry-only G2 three-region partition on a Q1_4 source mesh.

The analytic chart and raw geometry samples remain bound to `x`; the new
declaration hash binds the two native radial cuts at rho=.25 and rho=.5. This
is a numerical geometry fixture and carries no physical MHD authority.
"""
function spatial_g2_three_region_source_declaration_v1(x::SpatialManufacturedNumericalInputV1)
    validate_spatial_manufactured_input_v1(x)
    all(rho->rho in x.mesh.rho,(0.25,0.5)) ||
        throw(ArgumentError("three-region G2 source geometry requires native Q1_4 radial faces at rho=.25 and rho=.5"))
    base=_smm_manufactured_declaration_validated_v1(x)
    regions=((id="plasma_core",rho=(0.0,0.25),material=:static_ideal_mhd,owner=:G2),
        (id="plasma_mid",rho=(0.25,0.5),material=:static_ideal_mhd,owner=:G2),
        (id="plasma_edge",rho=(0.5,1.0),material=:static_ideal_mhd,owner=:G2))
    interfaces=((rho=0.25,law=:continuous_same_material_trace,current_sheet=:none,ownership=:shared_nodes),
        (rho=0.5,law=:continuous_same_material_trace,current_sheet=:none,ownership=:shared_nodes))
    source=merge(base.source,(scope=:g2_three_region_source_mesh_only,
        physical_validation=:unsupported,authority=:no_publish))
    cases=((case_id="g2_three_region_source_mesh",level=x.mesh.level,flux_Wb=x.flux.nominal_Wb),)
    SpatialMultiRegionDeclarationV4(_SMR_G2_THREE_REGION_SOURCE_REVISION_V1,regions,base.states,interfaces,
        source,base.boundary,base.spaces,base.flux,cases,base.parameters,base.quadrature,
        base.scaling,base.solver,(base.applicability...,:g2_source_mesh_only,:physical_validation_unsupported,:no_publish))
end

function validate_spatial_g2_three_region_source_declaration_v1(d::SpatialMultiRegionDeclarationV4)
    _smm_is_g2_three_region_source_v1(d) && hasproperty(d.source,:input) &&
        d.source.input isa SpatialManufacturedNumericalInputV1 ||
        throw(ArgumentError("typed G2 three-region source declaration/input required"))
    expected=spatial_g2_three_region_source_declaration_v1(d.source.input)
    canonical_json(d)==canonical_json(expected) ||
        throw(ArgumentError("G2 three-region source declaration differs from its canonical reconstruction"))
    true
end

function validate_spatial_n1_manufactured_declaration_v1(d::SpatialMultiRegionDeclarationV4)
    _smm_is_declaration_v1(d) && hasproperty(d.source,:input) && d.source.input isa SpatialManufacturedNumericalInputV1 ||
        throw(ArgumentError("typed manufactured declaration/input required"))
    validate_spatial_manufactured_input_v1(d.source.input)
    canonical_json(d)==canonical_json(_smm_manufactured_declaration_validated_v1(d.source.input)) ||
        throw(ArgumentError("manufactured declaration differs from its complete canonical reconstruction"))
    true
end

function _smm_xyz_v1(xyz)
    (xyz isa Tuple || xyz isa AbstractVector) && length(xyz)==3 || throw(ArgumentError("three Cartesian coordinates required"))
    all(v->v isa Real && !(v isa Bool) && isfinite(v),xyz) || throw(ArgumentError("nonfinite Cartesian coordinates"))
    Float64.(xyz)
end

# Internal analytic kernels consume an input already checked once at the public
# execution/assembly boundary. Their arithmetic follows the retained N1 fixture.
function _smm_field_v1(x::SpatialManufacturedNumericalInputV1,xyz)
    X,Y,Z=_smm_xyz_v1(xyz);R=hypot(X,Y);R>0.0 || throw(ArgumentError("manufactured torus excludes R=0"))
    b=x.fields.beta_T_m;a=x.fields.alpha_Pa_m2;r0=x.geometry.R0_m
    B=(-b*Y,b*X,0.0);p=x.fields.p0_Pa+a*((R-r0)^2+Z^2)
    radial=-2b^2*R/x.fields.mu0_N_A2-2a*(R-r0)
    result=(B=B,p=p,source=(radial*X/R,radial*Y/R,-2a*Z),B_cyl=(0.0,b*R,0.0),J_xyz=(0.0,0.0,2b/x.fields.mu0_N_A2))
    all(isfinite,(result.B...,result.p,result.source...,result.B_cyl...,result.J_xyz...)) ||
        throw(ArgumentError("manufactured field/source overflow"))
    result
end
_smm_source_v1(x,xyz)=_smm_field_v1(x,xyz).source
function _smm_traction_v1(x,xyz,normal)
    f=_smm_field_v1(x,xyz);_smr_stress(collect(f.B),f.p)*collect(_smm_xyz_v1(normal))
end
_smm_normal_v1(x,xyz,normal)=dot(collect(_smm_field_v1(x,xyz).B),collect(_smm_xyz_v1(normal)))
function _smm_m1n1_normal_value_validated_v1(x,q,R)
    x.geometry.model===:m1n1_ripple_torus || throw(ArgumentError("mapped normal evaluator requires the m1n1 chart"))
    rho,_,zeta=q
    abs(rho-1.0)<=8eps(Float64) || throw(ArgumentError("mapped normal law is defined on rho=1 outer boundary"))
    epsmap=x.geometry.ripple_amplitude;D=1+epsmap^2+2epsmap*cos(zeta)
    denominator=sqrt(D+(x.geometry.minor_radius_m*rho*epsmap*sin(zeta)/R)^2)
    value=x.fields.beta_T_m*x.geometry.minor_radius_m*rho*epsmap*sin(zeta)/denominator
    isfinite(value) && D>0.0 && denominator>0.0 || throw(ArgumentError("nonfinite mapped normal field"))
    value
end
function spatial_manufactured_field_v1(x::SpatialManufacturedNumericalInputV1,xyz)
    validate_spatial_manufactured_input_v1(x);_smm_field_v1(x,xyz)
end

function _smm_sample_v1(x,entity,qp,q,qw,axis)
    rho,theta,zeta=q;a=x.geometry.minor_radius_m;phi=zeta
    if x.geometry.model===:circular_torus
        R=x.geometry.R0_m+a*rho*cos(theta)
        Z=a*rho*sin(theta)
        E=[a*cos(theta) -a*rho*sin(theta) 0.0;0.0 0.0 R;a*sin(theta) a*rho*cos(theta) 0.0]
    elseif x.geometry.model===:m1n1_ripple_torus
        eps=x.geometry.ripple_amplitude;phase=theta-zeta
        c=cos(theta)+eps*cos(phase);s=sin(theta)+eps*sin(phase)
        R=x.geometry.R0_m+a*rho*c
        Z=a*rho*s
        E=[a*c -a*rho*s a*rho*eps*sin(phase);
           0.0 0.0 R;
           a*s a*rho*c -a*rho*eps*cos(phase)]
    else
        throw(ArgumentError("unsupported manufactured interior map"))
    end
    invE=rho==0.0 ? zeros(3,3) : inv(E);rot=_smr_rot(phi);normal=zeros(3);weight=qw*abs(det(E))
    if axis!=0
        dual=invE[axis,:];normal=rot*dual/norm(dual);other=filter(!=(axis),1:3)
        weight=qw*norm(cross(E[:,other[1]],E[:,other[2]]))
    end
    xyz=(R*cos(phi),R*sin(phi),Z);f=_smm_field_v1(x,xyz)
    (entity_id=entity,qp_id=qp,q=Tuple(q),xyz=xyz,R=R,phi=phi,weight=weight,detE=det(E),normal=Tuple(normal),
        E=E,Einv=invE,B_reference_cyl=f.B_cyl,p_reference=f.p)
end

function _smm_chart_value_v1(x,qturn)
    q=_smm_xyz_v1(qturn);all(v->0.0<=v<=1.0,q) || throw(ArgumentError("unit-turn chart outside [0,1]^3"))
    raw=(q[1],2pi*q[2],2pi*q[3]);s=_smm_sample_v1(x,1,1,raw,0.0,0)
    D=Diagonal(collect(x.geometry.angle_pullback));Q=_smr_rot(s.phi)
    Jrad=Q*s.E;Jturn=Jrad*D;grad=transpose(s.E)*s.E;gturn=transpose(D)*grad*D
    scale=x.geometry.support_scale_m
    (raw_coordinates=raw,coordinate=s.xyz,normalized_coordinate=Tuple(v/scale for v in s.xyz),
        raw_E=_smm_matrix_v1(s.E),cartesian_rotation=_smm_matrix_v1(Q),
        raw_cartesian_jacobian=_smm_matrix_v1(Jrad),turn_cartesian_jacobian=_smm_matrix_v1(Jturn),
        raw_metric=_smm_matrix_v1(grad),turn_metric=_smm_matrix_v1(gturn),
        normalized_metric=_smm_matrix_v1(gturn./scale^2),signed_raw_detE=s.detE,
        signed_turn_detJ=det(Jturn),pullback=x.geometry.angle_pullback)
end
function spatial_manufactured_chart_value_v1(x::SpatialManufacturedNumericalInputV1,qturn)
    validate_spatial_manufactured_input_v1(x);_smm_chart_value_v1(x,qturn)
end
function validate_spatial_manufactured_chart_value_v1(x,qturn,value)
    expected=spatial_manufactured_chart_value_v1(x,qturn)
    canonical_json(value)==canonical_json(expected) || throw(ArgumentError("manufactured chart/pullback/rotation mismatch"))
    true
end

_smm_length_unit_v1()=UnitSignature((0,1,0,0,0,0,0))
_smm_metric_unit_v1()=UnitSignature((0,2,0,0,0,0,0))
_smm_coordinate_type_v1()=PhysicalType(:physical_coordinate_map,1,3,TemporalTypeV1(static_time),_smm_length_unit_v1())
_smm_metric_type_v1()=PhysicalType(:covariant_metric,2,3,TemporalTypeV1(static_time),_smm_metric_unit_v1())
_smm_payload_type_v1()=PhysicalType(:spatial_manufactured_geometry_payload,0,3,TemporalTypeV1(static_time),UnitSignature())
_smm_scale_type_v1()=PhysicalType(:support_scale,0,3,TemporalTypeV1(static_time),_smm_length_unit_v1())
_smm_scale2_type_v1()=PhysicalType(:support_scale_squared,0,3,TemporalTypeV1(static_time),_smm_metric_unit_v1())
function _smm_manifest_v1(ref,inputs,output)
    rule=ExactTypeRuleV1(inputs,(output,))
    OperatorManifestV1(ref,length(inputs),1,rule,rule;allowed_roles=(:constraint,),locality=:local,pure=true,
        stateful=false,stochastic=false,event=false,parameter_schema=(),allowed_conservation_effects=(),forbidden_conservation_effects=())
end
function spatial_manufactured_geometry_registry_v1()
    registry=default_operator_registry()
    for manifest in (
        _smm_manifest_v1(_SMM_NCOORD_V1,(chart_coordinate_type_v1(),_smm_payload_type_v1()),normalized_ambient_coordinate_type_v1()),
        _smm_manifest_v1(_SMM_NMETRIC_V1,(chart_coordinate_type_v1(),_smm_payload_type_v1()),normalized_covariant_metric_type_v1()),
        _smm_manifest_v1(_SMM_NCOORD_M1N1_V1,(chart_coordinate_type_v1(),_smm_payload_type_v1()),normalized_ambient_coordinate_type_v1()),
        _smm_manifest_v1(_SMM_NMETRIC_M1N1_V1,(chart_coordinate_type_v1(),_smm_payload_type_v1()),normalized_covariant_metric_type_v1()),
        _smm_manifest_v1(_SMM_COORD_V1,(normalized_ambient_coordinate_type_v1(),_smm_scale_type_v1()),_smm_coordinate_type_v1()),
        _smm_manifest_v1(_SMM_METRIC_V1,(normalized_covariant_metric_type_v1(),_smm_scale2_type_v1()),_smm_metric_type_v1()))
        registry=register_operator(registry,manifest)
    end
    registry
end
# The AST payload owns the physical chart map. Exact numerical-input identity stays
# bound by the returned geometry binding and the manufactured child declaration.
_smm_payload_v1(x)=(schema="spatial-manufactured-geometry-payload-v1",
    geometry=x.geometry,provider=spatial_manufactured_provider_identity_v1())
function _smm_ast_v1(x,nref,ntype,sref,stype,scale,ptype,registry)
    nodes=(ASTInputV1(1,chart_coordinate_type_v1()),
        ASTConstantV1(:spatial_manufactured_geometry_payload,_smm_payload_v1(x),_smm_payload_type_v1()),
        ASTApplyV1(nref,(1,2),(;);registry=registry,input_types=(chart_coordinate_type_v1(),_smm_payload_type_v1())),
        ASTConstantV1(:support_scale,scale,stype),ASTApplyV1(sref,(3,4),(;);registry=registry,input_types=(ntype,stype)))
    nodes[5].output_type==ptype || error("manufactured typed scale root mismatch")
    TypedASTProgramV1(nodes,(3,5),(1,);registry=registry)
end
function _smm_geometry_binding_validated_v1(x::SpatialManufacturedNumericalInputV1,
        coordinate_site::FieldOperatorSiteRefV1,metric_site::FieldOperatorSiteRefV1)
    coordinate_site!=metric_site || throw(ArgumentError("manufactured roots must be distinct"))
    registry=spatial_manufactured_geometry_registry_v1();scale=1//1
    ncoord,nmetric=x.geometry.model===:circular_torus ? (_SMM_NCOORD_V1,_SMM_NMETRIC_V1) :
        x.geometry.model===:m1n1_ripple_torus ? (_SMM_NCOORD_M1N1_V1,_SMM_NMETRIC_M1N1_V1) :
        throw(ArgumentError("unsupported candidate-bound chart model"))
    cp=_smm_ast_v1(x,ncoord,normalized_ambient_coordinate_type_v1(),_SMM_COORD_V1,_smm_scale_type_v1(),scale,_smm_coordinate_type_v1(),registry)
    mp=_smm_ast_v1(x,nmetric,normalized_covariant_metric_type_v1(),_SMM_METRIC_V1,_smm_scale2_type_v1(),scale^2,_smm_metric_type_v1(),registry)
    ce=AtomicMIMOHyperedgeV1(coordinate_site.value,(MIMOInputBindingV1(1,1),),
        (MIMOOutputBindingV1(1,2),MIMOOutputBindingV1(2,3)),cp,constraint;registry=registry)
    me=AtomicMIMOHyperedgeV1(metric_site.value,(MIMOInputBindingV1(1,1),),
        (MIMOOutputBindingV1(1,4),MIMOOutputBindingV1(2,5)),mp,constraint;registry=registry)
    (revision="spatial-manufactured-geometry-binding-v1",input_hash=canonical_hash(x),
        coordinate_site_ref=coordinate_site,metric_site_ref=metric_site,
        coordinate_program=cp,metric_program=mp,coordinate_edge=ce,metric_edge=me,registry=registry)
end
function spatial_manufactured_geometry_binding_v1(x::SpatialManufacturedNumericalInputV1,
        coordinate_site::FieldOperatorSiteRefV1,metric_site::FieldOperatorSiteRefV1)
    validate_spatial_manufactured_input_v1(x)
    _smm_geometry_binding_validated_v1(x,coordinate_site,metric_site)
end
function interpret_spatial_manufactured_geometry_v1(x,binding,qturn)
    expected=spatial_manufactured_geometry_binding_v1(x,binding.coordinate_site_ref,binding.metric_site_ref)
    canonical_json(binding)==canonical_json(expected) || throw(ArgumentError("foreign manufactured typed operator/payload/roots"))
    # Only this exact two-program ABI has semantics here; arbitrary ASTs cannot
    # receive these values by reusing the numerical input's model name.
    value=_smm_chart_value_v1(x,qturn)
    (binding_hash=canonical_hash(binding),input_hash=canonical_hash(x),value=value,
        provider=spatial_manufactured_provider_identity_v1(),desc_authorized=false,physical_validation=:unsupported)
end

"Build real typed geometry/input objects; it does not compile or run a candidate."
function spatial_manufactured_parent_geometry_v1(x::SpatialManufacturedNumericalInputV1)
    validate_spatial_manufactured_input_v1(x)
    _smm_parent_geometry_validated_v1(x)
end

function _smm_parent_geometry_validated_v1(x::SpatialManufacturedNumericalInputV1)
    csite=FieldOperatorSiteRefV1("manufactured-n1-coordinate")
    msite=FieldOperatorSiteRefV1("manufactured-n1-metric")
    binding=_smm_geometry_binding_validated_v1(x,csite,msite)
    graph=TypedOperatorHypergraphV1((
        node(:chart_coordinate,chart_coordinate_type_v1();id="manufactured-n1-chart-input"),
        node(:normalized_coordinate,normalized_ambient_coordinate_type_v1();id="manufactured-n1-normalized-coordinate"),
        node(:physical_coordinate,_smm_coordinate_type_v1();id="manufactured-n1-physical-coordinate"),
        node(:normalized_metric,normalized_covariant_metric_type_v1();id="manufactured-n1-normalized-metric"),
        node(:physical_metric,_smm_metric_type_v1();id="manufactured-n1-physical-metric")),
        (binding.coordinate_edge,binding.metric_edge);registry=binding.registry)
    prebinding=_make_forward_graph_binding(:field_geometry,graph)
    support_ref=SpatialSupportRefV1("manufactured-n1-support")
    chart_ref=ChartRefV1("manufactured-n1-chart");frame_ref=CoordinateFrameRefV1("manufactured-n1-frame")
    bounds=ntuple(_->QuantityIntervalV1(ExactFiniteIntervalV1(0,1,false),UnitSignature()),3)
    periodic=(PeriodicAxisV1(2,NonnegativeQuantityV1(1,UnitSignature())),PeriodicAxisV1(3,NonnegativeQuantityV1(1,UnitSignature())))
    support=SpatialSupportGeneV1(support_ref,3,(frame_ref,),
        (CoordinateChartGeneV1(chart_ref,frame_ref,bounds,periodic,
            SpatialProgramRootRefV1(csite,1,chart_coordinate_type_v1(),normalized_ambient_coordinate_type_v1()),
            SpatialProgramRootRefV1(msite,1,chart_coordinate_type_v1(),normalized_covariant_metric_type_v1())),),
        (),NonnegativeQuantityV1(1,_smm_length_unit_v1()))
    cm=ThreeDCoordinateMetricV4(support_ref,chart_ref,csite,msite,
        prebinding.ast_root_identity_hashes[2],prebinding.ast_root_identity_hashes[4],
        _smm_coordinate_type_v1(),_smm_metric_type_v1(),bounds)
    boundary=if x.geometry.model===:circular_torus
        ThreeDFourierBoundaryV4("manufactured-n1-circular-boundary",1,true,
            (ThreeDFourierCoefficientV4(0,0,x.geometry.R0_m),ThreeDFourierCoefficientV4(1,0,x.geometry.minor_radius_m)),
            (ThreeDFourierCoefficientV4(1,0,x.geometry.minor_radius_m),))
    elseif x.geometry.model===:m1n1_ripple_torus
        ripple=x.geometry.minor_radius_m*x.geometry.ripple_amplitude
        ThreeDFourierBoundaryV4("manufactured-n1-m1n1-ripple-boundary",1,true,
            (ThreeDFourierCoefficientV4(0,0,x.geometry.R0_m),
             ThreeDFourierCoefficientV4(1,0,x.geometry.minor_radius_m),
             ThreeDFourierCoefficientV4(1,1,ripple)),
            (ThreeDFourierCoefficientV4(1,0,x.geometry.minor_radius_m),
             ThreeDFourierCoefficientV4(1,1,ripple)))
    else
        throw(ArgumentError("unsupported manufactured boundary map"))
    end
    radial=QuantityIntervalV1(ExactFiniteIntervalV1(0,1,false),UnitSignature())
    # These are explicitly derived manufactured initialization metadata. The
    # spatial solver only consumes its independent nodal unknowns and equations.
    pressure=ThreeDRadialProfileV4("manufactured-n1-reference-pressure",:pressure,
        (x.fields.p0_Pa,0.0,x.fields.alpha_Pa_m2*x.geometry.minor_radius_m^2),
        UnitSignature((1,-1,-2,0,0,0,0)),radial)
    iota=ThreeDRadialProfileV4("manufactured-n1-pure-toroidal-reference-iota",:iota,(0.0,),UnitSignature(),radial)
    profiles=ThreeDProfilesFluxV4("manufactured-n1-reference-profiles",pressure,iota,x.flux.nominal_Wb)
    physical_input=ThreeDPhysicalProviderInputV4("manufactured-n1-declaration",boundary,cm,profiles)
    (graph=graph,support=support,physical_input=physical_input,typed_binding=binding,
        provenance=(provider=:manufactured_analytic_numerical,input_hash=canonical_hash(x),
            pressure_iota_role=:reference_initialization_only,desc_execution=:not_executed,authority=:no_publish))
end

# Private geometry check: its callers have just constructed or validated the
# complete forward context in the same invocation. Public entries validate anew.
function _smm_validate_candidate_geometry_v1(context,x)
    context.candidate.identity_ref==_SMM_CANDIDATE_ID_V1 || throw(ArgumentError("manufactured candidate revision required"))
    g=context.candidate.field_geometry_genome_ref
    d=only(filter(v->v isa SpatialMultiRegionDeclarationV4,g.fields))
    # Both private callers validate the complete declaration before checking
    # its candidate geometry; keep the candidate/input/geometry bindings here
    # without repeating that input and declaration reconstruction.
    canonical_hash(d.source.input)==canonical_hash(x) || throw(ArgumentError("foreign candidate manufactured input"))
    expected=_smm_parent_geometry_validated_v1(x)
    physical=only(filter(v->v isa ThreeDPhysicalProviderInputV4,g.fields))
    support=only(filter(v->v isa SpatialSupportGeneV1,g.fields))
    canonical_hash(physical)==canonical_hash(expected.physical_input) && canonical_hash(support)==canonical_hash(expected.support) ||
        throw(ArgumentError("manufactured candidate does not own the exact candidate-bound geometry/input"))
    length(g.graph.nodes)>=5 && length(g.graph.hyperedges)>=2 || throw(ArgumentError("manufactured coordinate/metric roots absent"))
    base=TypedOperatorHypergraphV1(g.graph.nodes[1:5],g.graph.hyperedges[1:2];registry=first(g.graph.hyperedges).registry)
    canonical_hash(base)==canonical_hash(expected.graph) || throw(ArgumentError("foreign manufactured coordinate/metric operator graph"))
    true
end
function validate_spatial_manufactured_candidate_input_v1(context,x)
    validate_spatial_candidate_v4(context)
    # The candidate guard already checked its canonical geometry and own input.
    # Bind this caller's input without repeating that complete reconstruction.
    validate_spatial_manufactured_input_v1(x)
    d=only(filter(v->v isa SpatialMultiRegionDeclarationV4,context.candidate.field_geometry_genome_ref.fields))
    _smm_is_declaration_v1(d) && canonical_json(d.source.input)==canonical_json(x) ||
        throw(ArgumentError("foreign candidate manufactured input"))
    true
end

function _smm_geometry_samples_for_declaration_v1(x::SpatialManufacturedNumericalInputV1,d::SpatialMultiRegionDeclarationV4)
    validate_spatial_manufactured_input_v1(x)
    if _smm_is_declaration_v1(d)
        validate_spatial_n1_manufactured_declaration_v1(d)
    elseif _smm_is_g2_three_region_source_v1(d)
        validate_spatial_g2_three_region_source_declaration_v1(d)
    else
        throw(ArgumentError("unsupported manufactured geometry declaration"))
    end
    canonical_hash(d.source.input)==canonical_hash(x) || throw(ArgumentError("foreign manufactured source input"))
    mesh=build_spatial_mesh_v4(d,x.mesh.level,x.mesh.nfp)
    4size(mesh.nodes_q,2)==x.mesh.unknowns || error("manufactured node ownership count mismatch")
    _smm_is_declaration_v1(d) && length(mesh.row_blocks)!=x.mesh.rows && error("manufactured row ownership count mismatch")
    roots=x.quadrature.roots;weights=x.quadrature.weights
    nodes=[_smm_sample_v1(x,i,1,mesh.nodes_q[:,i],0.0,0) for i in axes(mesh.nodes_q,2)]
    volume=NamedTuple[];faces=NamedTuple[]
    for (cell,b) in enumerate(mesh.cell_bounds),iz in 1:3,it in 1:3,ir in 1:3
        ix=(ir,it,iz);q=ntuple(a->sum(b[a])/2+roots[ix[a]]*(b[a][2]-b[a][1])/2,3)
        w=prod(weights[ix[a]]*(b[a][2]-b[a][1])/2 for a in 1:3)
        push!(volume,_smm_sample_v1(x,cell,(iz-1)*9+(it-1)*3+ir,q,w,0))
    end
    for (fid,f) in enumerate(mesh.faces)
        b=mesh.cell_bounds[f.right_cell==0 ? f.left_cell : f.right_cell];other=filter(!=(f.axis),1:3);qp=0
        for j in 1:3,i in 1:3
            q=zeros(3);q[f.axis]=f.fixed;w=1.0
            for (a,ix) in zip(other,(i,j))
                q[a]=sum(b[a])/2+roots[ix]*(b[a][2]-b[a][1])/2;w*=weights[ix]*(b[a][2]-b[a][1])/2
            end
            qp+=1;push!(faces,_smm_sample_v1(x,fid,qp,q,w,f.axis))
        end
    end
    reference=Float64[]
    for s in nodes;append!(reference,s.B_reference_cyl);push!(reference,s.p_reference);end
    initial=reference.+repeat(collect(x.initialization.perturbation),div(length(reference),4))
    (mesh=mesh,nodes=nodes,volume=volume,face_quadrature=faces,reference_state=reference,initial_state=initial)
end

spatial_manufactured_geometry_samples_v1(x::SpatialManufacturedNumericalInputV1)=
    _smm_geometry_samples_for_declaration_v1(x,spatial_n1_manufactured_declaration_v1(x))
spatial_g2_three_region_source_geometry_samples_v1(x::SpatialManufacturedNumericalInputV1,d::SpatialMultiRegionDeclarationV4)=
    _smm_geometry_samples_for_declaration_v1(x,d)

function _spatial_q1_nested_pair_gate_v1(coarse_input::SpatialManufacturedNumericalInputV1,
        coarse_mesh, fine_input::SpatialManufacturedNumericalInputV1, fine_mesh)
    coarse_mesh isa SpatialMeshV4 && fine_mesh isa SpatialMeshV4 ||
        throw(ArgumentError("Q1 continuation requires canonical spatial meshes"))
    validate_spatial_manufactured_input_v1(coarse_input)
    validate_spatial_manufactured_input_v1(fine_input)
    level_rank(level) = level === :q1_2 ? 1 : level === :q1_4 ? 2 : level === :q1_8 ? 3 : 0
    level_rank(fine_input.mesh.level) == level_rank(coarse_input.mesh.level) + 1 ||
        throw(ArgumentError("Q1 transfer requires adjacent supported refinement levels"))
    coarse_input.geometry == fine_input.geometry && coarse_input.fields == fine_input.fields &&
        coarse_input.initialization == fine_input.initialization &&
        coarse_input.quadrature == fine_input.quadrature && coarse_input.boundary == fine_input.boundary &&
        coarse_input.flux == fine_input.flux && coarse_input.provenance == fine_input.provenance ||
        throw(ArgumentError("Q1 transfer source and target physics inputs differ"))
    coarse_policy = Tuple((key, getproperty(coarse_input.numerics, key))
        for key in keys(coarse_input.numerics) if key !== :seconds)
    fine_policy = Tuple((key, getproperty(fine_input.numerics, key))
        for key in keys(fine_input.numerics) if key !== :seconds)
    coarse_policy == fine_policy || throw(ArgumentError("Q1 transfer numerical policies differ"))
    coarse_input.mesh.rho == fine_input.mesh.rho[1:2:end] &&
        2 * coarse_input.mesh.theta_count == fine_input.mesh.theta_count &&
        2 * coarse_input.mesh.zeta_per_period == fine_input.mesh.zeta_per_period &&
        coarse_input.mesh.nfp == fine_input.mesh.nfp ||
        throw(ArgumentError("Q1 transfer target is not the factor-two nested mesh"))
    coarse_mesh.level === coarse_input.mesh.level && fine_mesh.level === fine_input.mesh.level &&
        coarse_mesh.nfp == fine_mesh.nfp == coarse_input.mesh.nfp &&
        size(coarse_mesh.nodes_q, 2) == coarse_input.mesh.unknowns ÷ 4 &&
        size(fine_mesh.nodes_q, 2) == fine_input.mesh.unknowns ÷ 4 ||
        throw(ArgumentError("Q1 transfer meshes/state do not match their declared inputs"))
    coarse_expected = build_spatial_mesh_v4(spatial_n1_manufactured_declaration_v1(coarse_input),
        coarse_input.mesh.level, coarse_input.mesh.nfp)
    fine_expected = build_spatial_mesh_v4(spatial_n1_manufactured_declaration_v1(fine_input),
        fine_input.mesh.level, fine_input.mesh.nfp)
    coarse_mesh.nodes_q == coarse_expected.nodes_q &&
        coarse_mesh.cell_nodes == coarse_expected.cell_nodes &&
        coarse_mesh.corner_to_local == coarse_expected.corner_to_local &&
        coarse_mesh.cell_bounds == coarse_expected.cell_bounds &&
        fine_mesh.nodes_q == fine_expected.nodes_q &&
        fine_mesh.cell_nodes == fine_expected.cell_nodes &&
        fine_mesh.corner_to_local == fine_expected.corner_to_local &&
        fine_mesh.cell_bounds == fine_expected.cell_bounds ||
        throw(ArgumentError("Q1 transfer mesh differs from its canonical chart mesh"))
    (coarse_mesh=coarse_mesh, fine_mesh=fine_mesh)
end

"Prolongate a four-field Q1 nodal state across one exact factor-two chart refinement."
function spatial_q1_nested_prolongation_v1(coarse_input::SpatialManufacturedNumericalInputV1,
        coarse_mesh, coarse_state, fine_input::SpatialManufacturedNumericalInputV1,
        fine_mesh; pressure_scale_Pa)
    _spatial_q1_nested_pair_gate_v1(coarse_input,coarse_mesh,fine_input,fine_mesh)
    length(coarse_state) == coarse_input.mesh.unknowns ||
        throw(ArgumentError("Q1 transfer source state shape mismatch"))
    all(value -> value isa Real && !(value isa Bool) && isfinite(value), coarse_state) ||
        throw(ArgumentError("Q1 transfer source state is nonfinite or nonnumeric"))
    isfinite(pressure_scale_Pa) && pressure_scale_Pa > 0 ||
        throw(ArgumentError("Q1 transfer pressure scale is invalid"))
    all(i -> _smr_pressure_feasible(Float64(coarse_state[i]), pressure_scale_Pa),
        4:4:length(coarse_state)) || throw(ArgumentError("Q1 transfer source pressure is infeasible"))
    result = Vector{Float64}(undef, 4 * size(fine_mesh.nodes_q, 2))
    tolerance = 64 * eps(Float64) * 2pi
    for node in axes(fine_mesh.nodes_q, 2)
        q = fine_mesh.nodes_q[:, node]
        coarse_node = findfirst(candidate -> maximum(abs.(coarse_mesh.nodes_q[:, candidate] .- q)) <= tolerance,
            axes(coarse_mesh.nodes_q, 2))
        if coarse_node !== nothing
            result[4 * node - 3:4 * node] .= Float64.(coarse_state[4 * coarse_node - 3:4 * coarse_node])
            continue
        end
        cell = findfirst(bounds -> all(axis ->
            bounds[axis][1] - tolerance <= q[axis] <= bounds[axis][2] + tolerance, 1:3),
            coarse_mesh.cell_bounds)
        cell === nothing && throw(ArgumentError("Q1 transfer target node is outside the source chart mesh"))
        basis = spatial_basis_v4(coarse_mesh, cell, q)
        for component in 1:4
            result[4 * node - 4 + component] = sum(basis.N[j] * Float64(coarse_state[4 * basis.ids[j] - 4 + component])
                for j in eachindex(basis.ids))
        end
    end
    all(isfinite, result) && all(i -> _smr_pressure_feasible(result[i], pressure_scale_Pa), 4:4:length(result)) ||
        throw(ArgumentError("Q1 transfer result is nonfinite or pressure-infeasible"))
    result
end

"Exact shared-node merge-back from one nested Q1 refinement to its coarse chart."
function spatial_q1_nested_mergeback_v1(coarse_input::SpatialManufacturedNumericalInputV1,
        coarse_mesh, fine_state, fine_input::SpatialManufacturedNumericalInputV1,
        fine_mesh; pressure_scale_Pa)
    length(fine_state) == fine_input.mesh.unknowns ||
        throw(ArgumentError("Q1 merge-back fine state shape mismatch"))
    _spatial_q1_nested_pair_gate_v1(coarse_input,coarse_mesh,fine_input,fine_mesh)
    all(value -> value isa Real && !(value isa Bool) && isfinite(value), fine_state) ||
        throw(ArgumentError("Q1 merge-back fine state is nonfinite or nonnumeric"))
    isfinite(pressure_scale_Pa) && pressure_scale_Pa > 0 ||
        throw(ArgumentError("Q1 merge-back pressure scale is invalid"))
    all(i -> _smr_pressure_feasible(Float64(fine_state[i]), pressure_scale_Pa),
        4:4:length(fine_state)) || throw(ArgumentError("Q1 merge-back fine pressure is infeasible"))
    result = Vector{Float64}(undef, coarse_input.mesh.unknowns)
    tolerance = 64 * eps(Float64) * 2pi
    for node in axes(coarse_mesh.nodes_q, 2)
        q = coarse_mesh.nodes_q[:, node]
        fine_node = findfirst(candidate -> maximum(abs.(fine_mesh.nodes_q[:, candidate] .- q)) <= tolerance,
            axes(fine_mesh.nodes_q, 2))
        fine_node === nothing && throw(ArgumentError("Q1 merge-back coarse node is absent from fine mesh"))
        result[4 * node - 3:4 * node] .= Float64.(fine_state[4 * fine_node - 3:4 * fine_node])
    end
    result
end

"Restrict physical geometry nodes by the source Q1 map on the nested chart."
function spatial_q1_nested_geometry_restriction_v1(coarse_mesh, source_xyz,
        fine_mesh)
    coarse_mesh isa SpatialMeshV4 && fine_mesh isa SpatialMeshV4 ||
        throw(ArgumentError("Q1 geometry restriction requires canonical spatial meshes"))
    size(coarse_mesh.nodes_q,1)==3 && size(fine_mesh.nodes_q,1)==3 ||
        throw(ArgumentError("Q1 geometry restriction requires three chart coordinates"))
    size(source_xyz) == (3, size(coarse_mesh.nodes_q, 2)) ||
        throw(ArgumentError("Q1 source geometry must contain one Cartesian xyz column per source node"))
    all(isfinite, source_xyz) || throw(ArgumentError("Q1 source geometry contains nonfinite coordinates"))
    result = Matrix{Float64}(undef, 3, size(fine_mesh.nodes_q, 2))
    tolerance = 64 * eps(Float64) * 2pi
    for node in axes(fine_mesh.nodes_q, 2)
        q = fine_mesh.nodes_q[:, node]
        source_node = findfirst(candidate -> maximum(abs.(coarse_mesh.nodes_q[:, candidate] .- q)) <= tolerance,
            axes(coarse_mesh.nodes_q, 2))
        if source_node !== nothing
            result[:, node] .= source_xyz[:, source_node]
            continue
        end
        cell = findfirst(bounds -> all(axis ->
            bounds[axis][1] - tolerance <= q[axis] <= bounds[axis][2] + tolerance, 1:3),
            coarse_mesh.cell_bounds)
        cell === nothing && throw(ArgumentError("Q1 target geometry node is outside source chart"))
        basis = spatial_basis_v4(coarse_mesh, cell, q)
        result[:, node] .= source_xyz[:, basis.ids] * basis.N
    end
    all(isfinite, result) || throw(ArgumentError("Q1 restricted target geometry is nonfinite"))
    result
end

"""Audit one saved Q1 field state on the exact nested target chart.

`coarse_data` and `fine_data` are the existing GlobalWeak consumer data records;
the fine field is evaluated from the transferred nodal warm start.  DivB and
field comparisons use the same target quadrature geometry samples, while the
separate geometry residual compares the fine sampled geometry against the
source-Q1-restricted physical nodes.  This distinction prevents a curved-map
change from being silently reported as an exact physical-field invariant.
"""
function spatial_q1_nested_saved_field_audit_v1(coarse_input, coarse_data,
        coarse_state, fine_input, fine_data; pressure_scale_Pa,
        geometry_tolerance=64 * eps(Float64))
    coarse_input isa SpatialManufacturedNumericalInputV1 &&
        fine_input isa SpatialManufacturedNumericalInputV1 ||
        throw(ArgumentError("saved field audit requires typed manufactured Q1 inputs"))
    transferred = spatial_q1_nested_prolongation_v1(coarse_input, coarse_data.mesh,
        coarse_state, fine_input, fine_data.mesh; pressure_scale_Pa)
    merged = spatial_q1_nested_mergeback_v1(coarse_input, coarse_data.mesh,
        transferred, fine_input, fine_data.mesh; pressure_scale_Pa)
    source_xyz = reduce(hcat, (Float64.(collect(sample.xyz)) for sample in coarse_data.nodes))
    actual_fine_xyz = reduce(hcat, (Float64.(collect(sample.xyz)) for sample in fine_data.nodes))
    restricted_xyz = spatial_q1_nested_geometry_restriction_v1(coarse_data.mesh,
        source_xyz, fine_data.mesh)
    geometry_abs = maximum(abs.(actual_fine_xyz .- restricted_xyz); init=0.0)
    geometry_scale = max(1.0, maximum(abs, actual_fine_xyz; init=0.0))
    geometry_rel = geometry_abs / geometry_scale
    max_B = 0.0
    max_pressure = 0.0
    max_divB = 0.0
    scale_B = 0.0
    scale_pressure = 0.0
    scale_divB = 0.0
    tolerance = 64 * eps(Float64) * 2pi
    for sample in fine_data.volume
        q = sample.q
        source_cell = findfirst(bounds -> all(axis ->
            bounds[axis][1] - tolerance <= q[axis] <= bounds[axis][2] + tolerance, 1:3),
            coarse_data.mesh.cell_bounds)
        source_cell === nothing && throw(ArgumentError("target quadrature point is outside the saved source chart"))
        coarse_field = spatial_field_v4(coarse_data, source_cell, sample, coarse_state)
        fine_field = spatial_field_v4(fine_data, sample.entity_id, sample, transferred)
        max_B = max(max_B, maximum(abs.(coarse_field.B_xyz .- fine_field.B_xyz); init=0.0))
        max_pressure = max(max_pressure, abs(coarse_field.p - fine_field.p))
        max_divB = max(max_divB, abs(coarse_field.divB - fine_field.divB))
        scale_B = max(scale_B, maximum(abs, coarse_field.B_xyz; init=0.0),
            maximum(abs, fine_field.B_xyz; init=0.0))
        scale_pressure = max(scale_pressure, abs(coarse_field.p), abs(fine_field.p))
        scale_divB = max(scale_divB, abs(coarse_field.divB), abs(fine_field.divB))
    end
    B_tolerance = 256eps(Float64) * max(1.0, scale_B)
    pressure_tolerance = 256eps(Float64) * max(1.0, scale_pressure)
    divB_tolerance = 256eps(Float64) * max(1.0, scale_divB)
    (schema="spatial-q1-nested-saved-field-transfer-audit-v1",
        source_level=coarse_input.mesh.level, target_level=fine_input.mesh.level,
        source_unknowns=length(coarse_state), target_unknowns=length(transferred),
        source_state_hash=string(canonical_hash(Tuple(Float64.(collect(coarse_state))))),
        transferred_state_hash=string(canonical_hash(Tuple(transferred))),
        mergeback_state_hash=string(canonical_hash(Tuple(merged))),
        mergeback_max_abs=maximum(abs.(merged .- Float64.(collect(coarse_state))); init=0.0),
        pressure_min_source=minimum(Float64(coarse_state[i]) for i in 4:4:length(coarse_state)),
        pressure_min_target=minimum(transferred[i] for i in 4:4:length(transferred)),
        pressure_feasible=true, B_xyz_max_abs_on_fine_quadrature=max_B,
        p_Pa_max_abs_on_fine_quadrature=max_pressure,
        divB_max_abs_on_fine_quadrature=max_divB,
        field_and_divB_preserved=max_B <= B_tolerance &&
            max_pressure <= pressure_tolerance && max_divB <= divB_tolerance,
        B_xyz_tolerance=B_tolerance, pressure_tolerance=pressure_tolerance,
        divB_tolerance=divB_tolerance,
        physical_geometry_restriction_max_abs=geometry_abs,
        physical_geometry_restriction_relative=geometry_rel,
        physical_geometry_restriction_passed=geometry_rel <= geometry_tolerance,
        gauge_status=:not_applicable_state_is_Bxyz_and_pressure_not_vector_potential,
        physical_validation=:not_assessed, claim_ceiling=:software_transfer_invariant)
end

"Backward-compatible name for the current saved Q1_4 to Q1_8 warm-start consumer."
function spatial_q1_4_to_q1_8_initial_state_v1(coarse_input::SpatialManufacturedNumericalInputV1,
        coarse_mesh, coarse_state, fine_input::SpatialManufacturedNumericalInputV1,
        fine_mesh; pressure_scale_Pa)
    coarse_input.mesh.level === :q1_4 && fine_input.mesh.level === :q1_8 ||
        throw(ArgumentError("legacy continuation requires Q1_4 source and Q1_8 target"))
    spatial_q1_nested_prolongation_v1(coarse_input, coarse_mesh, coarse_state,
        fine_input, fine_mesh; pressure_scale_Pa)
end

function _smm_geometry_text_v1(rows)
    io=IOBuffer();println(io,_SMR_RAW_HEADER)
    for s in rows
        values=(s.entity_id,s.qp_id,s.q...,s.xyz...,s.R,s.phi,s.weight,s.detE,s.normal...,
            (s.E[i,j] for i in 1:3 for j in 1:3)...,(s.Einv[i,j] for i in 1:3 for j in 1:3)...,
            s.B_reference_cyl...,s.p_reference)
        println(io,join(values,','))
    end
    String(take!(io))
end

struct SpatialManufacturedGeometryReceiptV1
    schema::String
    candidate_hash::Digest256
    context_hash::Digest256
    declaration_hash::Digest256
    input_hash::Digest256
    provider::NamedTuple
    provider_source::SpatialArtifactV4
    raw_artifacts::NamedTuple
    initializer_hash::Digest256
    reference_state_hash::Digest256
    enclosure::NamedTuple
    desc_execution::Symbol
    physical_validation::Symbol
    authority::Symbol
end
semantic_view(x::SpatialManufacturedGeometryReceiptV1)=_smm_view_v1(x)
canonical_hash(x::SpatialManufacturedGeometryReceiptV1)=canonical_hash(semantic_view(x))
function _smm_enclosure_v1(x)
    if x.geometry.model===:circular_torus
        return (supported=true,R_upper_m=nextfloat(x.geometry.R0_m+x.geometry.minor_radius_m),
            method=:analytic_circular_R0_plus_minor_radius_outward_float,
            applicability=:canonical_manufactured_circle_only,desc_spectral_enclosure=:not_executed)
    elseif x.geometry.model===:m1n1_ripple_torus
        upper=nextfloat(x.geometry.R0_m+x.geometry.minor_radius_m*(1+x.geometry.ripple_amplitude))
        return (supported=true,R_upper_m=upper,method=:analytic_m1n1_absolute_trigonometric_bound_outward_float,
            applicability=:manufactured_m1n1_ripple_map_only,desc_spectral_enclosure=:not_executed)
    end
    throw(ArgumentError("unsupported manufactured enclosure map"))
end

function _smm_materialize_geometry_v1(x,d,binding,dir)
    validate_spatial_manufactured_input_v1(x)
    if _smm_is_declaration_v1(d)
        validate_spatial_n1_manufactured_declaration_v1(d)
    elseif _smm_is_g2_three_region_source_v1(d)
        validate_spatial_g2_three_region_source_declaration_v1(d)
    else
        throw(ArgumentError("unsupported manufactured geometry declaration"))
    end
    canonical_hash(d.source.input)==canonical_hash(x) || throw(ArgumentError("foreign manufactured source input"))
    keys(binding)==(:candidate_hash,:context_hash) && all(v->v isa Digest256,values(binding)) ||
        throw(ArgumentError("exact candidate/context binding required"))
    ispath(dir) && !isempty(readdir(dir)) && throw(ArgumentError("preserve existing manufactured provider evidence"))
    mkpath(dir);root=realpath(dir);samples=_smm_geometry_samples_for_declaration_v1(x,d)
    names=(:nodes,:volume,:faces);rows=(samples.nodes,samples.volume,samples.face_quadrature)
    artifacts=NamedTuple{names}(Tuple(begin
        path=joinpath(root,"manufactured_$(name).csv")
        (ispath(path)||islink(path)) && throw(ArgumentError("refuse provider artifact overwrite"))
        write(path,_smm_geometry_text_v1(values))
        _smr_artifact(path,"spatial-manufactured-geometry-v1",length(values))
    end for (name,values) in zip(names,rows)))
    receipt=SpatialManufacturedGeometryReceiptV1("spatial-manufactured-geometry-receipt-v1",binding.candidate_hash,
        binding.context_hash,canonical_hash(d),canonical_hash(x),spatial_manufactured_provider_identity_v1(),
        _smr_artifact(_SMM_SOURCE_V1,"julia_source",countlines(_SMM_SOURCE_V1)),artifacts,
        canonical_hash(Tuple(samples.initial_state)),canonical_hash(Tuple(samples.reference_state)),
        _smm_enclosure_v1(x),:not_executed,:unsupported,:no_publish)
    write(joinpath(root,"manufactured_provider.json"),canonical_json(receipt)*"\n")
    receipt
end

function _smm_validate_geometry_receipt_v1(x,d,binding,r::SpatialManufacturedGeometryReceiptV1)
    validate_spatial_manufactured_input_v1(x)
    if _smm_is_declaration_v1(d)
        validate_spatial_n1_manufactured_declaration_v1(d)
    elseif _smm_is_g2_three_region_source_v1(d)
        validate_spatial_g2_three_region_source_declaration_v1(d)
    else
        throw(ArgumentError("unsupported manufactured geometry declaration"))
    end
    r.schema=="spatial-manufactured-geometry-receipt-v1" && r.candidate_hash==binding.candidate_hash &&
        r.context_hash==binding.context_hash && r.declaration_hash==canonical_hash(d) && r.input_hash==canonical_hash(x) ||
        throw(ArgumentError("foreign manufactured geometry receipt"))
    r.provider==spatial_manufactured_provider_identity_v1() && r.provider_source.path==_SMM_SOURCE_V1 &&
        string(r.provider_source.sha256)==_SMM_LOADED_SHA_V1 && r.provider_source.schema=="julia_source" &&
        r.provider_source.row_count==countlines(_SMM_SOURCE_V1) || throw(ArgumentError("manufactured provider identity mismatch"))
    validate_spatial_artifact_v4(r.provider_source)
    r.desc_execution==:not_executed && r.physical_validation==:unsupported && r.authority==:no_publish ||
        throw(ArgumentError("manufactured receipt cannot acquire physical/DESC authority"))
    samples=_smm_geometry_samples_for_declaration_v1(x,d)
    keys(r.raw_artifacts)==(:nodes,:volume,:faces) || throw(ArgumentError("manufactured raw artifact coverage mismatch"))
    rows=(samples.nodes,samples.volume,samples.face_quadrature)
    root=realpath(dirname(r.raw_artifacts.nodes.path))
    for (key,values) in zip(keys(r.raw_artifacts),rows)
        art=getproperty(r.raw_artifacts,key);validate_spatial_artifact_v4(art)
        expected_path=joinpath(root,"manufactured_$(key).csv")
        art.path==expected_path && realpath(art.path)==expected_path || throw(ArgumentError("manufactured artifact path/schema ownership mismatch"))
        art.schema=="spatial-manufactured-geometry-v1" && art.row_count==length(values) &&
            read(art.path,String)==_smm_geometry_text_v1(values) || throw(ArgumentError("manufactured raw geometry/model replay mismatch"))
    end
    r.initializer_hash==canonical_hash(Tuple(samples.initial_state)) && r.reference_state_hash==canonical_hash(Tuple(samples.reference_state)) &&
        r.enclosure==_smm_enclosure_v1(x) || throw(ArgumentError("manufactured initializer/enclosure mismatch"))
    true
end

"Read real manufactured files through the production geometry parser."
function load_spatial_manufactured_data_v1(d::SpatialMultiRegionDeclarationV4,c)
    validate_spatial_manufactured_input_v1(d.source.input)
    if _smm_is_declaration_v1(d)
        validate_spatial_n1_manufactured_declaration_v1(d)
    elseif _smm_is_g2_three_region_source_v1(d)
        validate_spatial_g2_three_region_source_declaration_v1(d)
    else
        throw(ArgumentError("unsupported manufactured geometry declaration"))
    end
    x=d.source.input
    Symbol(c.level)==x.mesh.level && c.nfp==x.mesh.nfp || throw(ArgumentError("manufactured mesh/nfp mismatch"))
    hasproperty(c,:flux_Wb) && c.flux_Wb!=x.flux.nominal_Wb && throw(ArgumentError("manufactured flux mismatch"))
    keys(c.raw_artifacts)==(:nodes,:volume,:faces) || throw(ArgumentError("manufactured sample coverage mismatch"))
    expected=_smm_geometry_samples_for_declaration_v1(x,d)
    samples=map(((:nodes,expected.nodes),(:volume,expected.volume),(:faces,expected.face_quadrature))) do pair
        key,rows=pair;artifact=getproperty(c.raw_artifacts,key)
        validate_spatial_artifact_v4(artifact)
        artifact.schema=="spatial-manufactured-geometry-v1" && artifact.row_count==length(rows) &&
            read(artifact.path,String)==_smm_geometry_text_v1(rows) || throw(ArgumentError("manufactured raw data differs from declared model"))
        _smr_read_geometry(artifact;nodes=key==:nodes)
    end
    nodes,volume,faces=samples
    reference=Float64[]
    for s in nodes;append!(reference,s.B_reference_cyl);push!(reference,s.p_reference);end
    initial=reference.+repeat(collect(x.initialization.perturbation),div(length(reference),4))
    initial==expected.initial_state || throw(ArgumentError("manufactured parsed initializer changed"))
    loaded=(mesh=expected.mesh,nodes=nodes,volume=volume,face_quadrature=faces,initial_state=initial,
        raw_artifacts=c.raw_artifacts,continuous_enclosure=_smm_enclosure_v1(x))
    _smm_is_g2_three_region_source_v1(d) ? merge(loaded,(g2_source_identity=(declaration_hash=canonical_hash(d),
        source_face_sha256=c.raw_artifacts.faces.sha256,scope=:g2_three_region_source_mesh_only,
        physical_validation=:unsupported,authority=:no_publish),)) : loaded
end

# Public producer/consumer require the actual candidate guard; during the
# definition-only rollout the old guard correctly rejects this new declaration.
function materialize_spatial_manufactured_geometry_v1(context,x,dir)
    validate_spatial_manufactured_candidate_input_v1(context,x)
    d=only(filter(v->v isa SpatialMultiRegionDeclarationV4,context.candidate.field_geometry_genome_ref.fields))
    _smm_materialize_geometry_v1(x,d,(candidate_hash=context.candidate_hash,context_hash=context.context_hash),dir)
end
function validate_spatial_manufactured_geometry_v1(context,x,r::SpatialManufacturedGeometryReceiptV1)
    validate_spatial_manufactured_candidate_input_v1(context,x)
    d=only(filter(v->v isa SpatialMultiRegionDeclarationV4,context.candidate.field_geometry_genome_ref.fields))
    _smm_validate_geometry_receipt_v1(x,d,
        (candidate_hash=context.candidate_hash,context_hash=context.context_hash),r)
end

"Materialize candidate/declaration-bound raw source geometry for the G2 three-region fixture."
function materialize_spatial_g2_three_region_source_geometry_v1(x::SpatialManufacturedNumericalInputV1,
        d::SpatialMultiRegionDeclarationV4,binding,dir)
    validate_spatial_manufactured_input_v1(x)
    validate_spatial_g2_three_region_source_declaration_v1(d)
    canonical_hash(d.source.input)==canonical_hash(x) || throw(ArgumentError("foreign G2 source input"))
    _smm_materialize_geometry_v1(x,d,binding,dir)
end

"Validate the complete G2 geometry receipt and every declaration-bound raw file."
function validate_spatial_g2_three_region_source_geometry_v1(x::SpatialManufacturedNumericalInputV1,
        d::SpatialMultiRegionDeclarationV4,binding,r::SpatialManufacturedGeometryReceiptV1)
    validate_spatial_manufactured_input_v1(x)
    validate_spatial_g2_three_region_source_declaration_v1(d)
    canonical_hash(d.source.input)==canonical_hash(x) || throw(ArgumentError("foreign G2 source input"))
    _smm_validate_geometry_receipt_v1(x,d,binding,r)
end
