# Actual spatial-current to finite-aperture flux, with separate conditional circuitry.
using FusionConceptAI, LinearAlgebra, SHA
import FusionConceptAI: semantic_view, canonical_hash, Digest256

const _SPE_SOURCE=abspath(@__FILE__)
const _SPE_MU0=1.25663706127e-6
_spe_sha(path)=Digest256(bytes2hex(SHA.sha256(read(path))))
_spe_body(x)=NamedTuple{fieldnames(typeof(x))[1:end-1]}(ntuple(i->getfield(x,i),fieldcount(typeof(x))-1))

struct SpatialEngineeringParameterV4
    name::Symbol
    value::Float64
    unit::String
    interval::NTuple{2,Float64}
    source::String
    applicability::String
end
semantic_view(x::SpatialEngineeringParameterV4)=NamedTuple{fieldnames(typeof(x))}(Tuple(getfield(x,k) for k in fieldnames(typeof(x))))

struct SpatialPickupEngineeringDeclarationV4
    revision::String
    parameters::Tuple{Vararg{SpatialEngineeringParameterV4}}
    geometry::NamedTuple
    transfer::NamedTuple
    static_model::NamedTuple
    conditional_model::NamedTuple
    case_ids::NTuple{4,String}
    required_operator_ids::Tuple{Vararg{String}}
end
semantic_view(x::SpatialPickupEngineeringDeclarationV4)=NamedTuple{fieldnames(typeof(x))}(Tuple(getfield(x,k) for k in fieldnames(typeof(x))))

function spatial_engineering_declaration_v4()
    source="Exploratory spatial pickup design specification 2026-09-12 revision 1; not measured or a probability distribution"
    scope="Ideal stationary circular winding, isothermal lumped circuit and ideal closed-path relay; component and environmental applicability unvalidated"
    specs=((:radius_m,.005,"m",(.0045,.0055)),(:center_offset_m,.05,"m",(.05,.05)),
        (:turns,10.0,"1",(10.0,10.0)),(:wire_radius_m,.0001,"m",(.0001,.0001)),
        (:resistivity_ohm_m,1.72e-8,"ohm m",(1.6e-8,1.9e-8)),
        (:inductance_H,.001,"H",(.001,.001)),(:load_resistance_ohm,10.,"ohm",(8.,12.)),
        (:ramp_fraction,.1,"1",(.1,.1)),(:ramp_duration_s,.002,"s",(.002,.002)),
        (:duration_s,.004,"s",(.004,.004)),(:detection_cadence_s,1e-5,"s",(1e-5,1e-5)),
        (:short_time_s,.001,"s",(.001,.001)),(:short_resistance_ohm,.01,"ohm",(.01,.01)),
        (:trip_current_A,.02,"A",(.02,.02)),(:dump_resistance_ohm,100.,"ohm",(100.,100.)))
    parameters=(Tuple(SpatialEngineeringParameterV4(k,v,u,b,source,scope) for (k,v,u,b) in specs)...,
        SpatialEngineeringParameterV4(:mu0_N_A2,_SPE_MU0,"N A^-2",(_SPE_MU0,_SPE_MU0),
            "NIST CODATA 2022 nominal https://physics.nist.gov/cgi-bin/cuu/Value?mu0",
            "Fixed nominal classical magnetostatic permeability; uncertainty not propagated"))
    SpatialPickupEngineeringDeclarationV4("spatial-pickup-engineering-v1",parameters,
        (center_rule=:analytic_R_upper_plus_offset,normal_xyz=(0.,0.,1.),
            shape=:circular_finite_disk,clearance_rule=:center_offset_minus_radius,
            enclosure=:candidate_analytic_cylindrical_bound),
        (volume_law="B(x)=mu0/(4pi)*integral[J(y) cross (x-y)/|x-y|^3 dV]",
            sheet_law="B_sheet(x)=mu0/(4pi)*integral[K(y) cross (x-y)/|x-y|^3 dA]",
            flux_law="flux_linkage=N*integral_disk(B dot n dA)",
            reciprocity="flux_linkage=N*integral(J dot A_unit_loop dV + K dot A_unit_loop dA)/(1 A)",
            disk_radial_order=4,disk_angular_count=32,reciprocity_wire_count=128,
            absolute_tolerance_Wb=1e-14,relative_tolerance=1e-8,
            scope=:plasma_volume_and_declared_internal_sheet_current_contribution,
            external_coils=:unknown,outer_sheet_current=:unknown,current_closure=:must_be_propagated),
        (field_time_dependence=:static,coil_motion=:stationary,induced_emf_V=0.,
            physical_quantity=:plasma_contribution_to_static_flux_linkage,
            total_external_field=false,physical_validation=:unsupported),
        (excitation=:prescribed_fractional_flux_ramp_not_plasma_dynamics,
            initial_current_A=0.,initial_flux_change_estimate_Wb=0.,
            state_equation="L di/dt+(Rwire+Rbranch)i=-dflux_linkage/dt",
            integrator="d(flux_change_estimate)/dt=-Rbranch*i while readout connected",
            propagation=:exact_piecewise_linear_flow,
            detector=:fixed_cadence_latched_threshold,commutation=:closed_dump_path,
            scenarios=(:none,:load_short)),
        ("nominal_coarse","nominal_fine","flux_low_coarse","flux_high_coarse"),
        ("SPATIAL_CURRENT_BIOT_SAVART_V4","FINITE_APERTURE_FLUX_V4","EXACT_PICKUP_RL_PROTECTION_V4"))
end

function _spe_parameters(d)
    all(p->isfinite(p.value)&&0<p.interval[1]<=p.value<=p.interval[2]&&
        !isempty(p.source)&&!isempty(p.unit)&&!isempty(p.applicability),d.parameters) ||
        throw(ArgumentError("invalid sourced spatial engineering parameter"))
    names=Tuple(p.name for p in d.parameters)
    length(unique(names))==length(names) || throw(ArgumentError("duplicate spatial engineering parameter"))
    NamedTuple{names}(Tuple(p.value for p in d.parameters))
end

struct SpatialCurrentQuadratureV4
    position_xyz_m::NTuple{3,Float64}
    weighted_current_Am::NTuple{3,Float64}
    kind::Symbol
end
semantic_view(x::SpatialCurrentQuadratureV4)=(position_xyz_m=x.position_xyz_m,weighted_current_Am=x.weighted_current_Am,kind=x.kind)

function _spe_csv_rows(artifact,header)
    validate_spatial_artifact_v4(artifact)
    lines=readlines(artifact.path)
    !isempty(lines)&&first(lines)==header || throw(ArgumentError("spatial current CSV schema mismatch"))
    length(lines)-1==artifact.row_count || throw(ArgumentError("spatial current CSV row count mismatch"))
    rows=split.(lines[2:end],',')
    all(r->length(r)==length(split(header,',')),rows) || throw(ArgumentError("ragged spatial current CSV"))
    rows
end

function spatial_current_sources_v4(input::SpatialCurrentInputV4;mu0=_SPE_MU0)
    validate_spatial_current_input_v4(input)
    volume=_spe_csv_rows(input.volume,SPATIAL_VOLUME_HEADER_V4)
    interfaces=_spe_csv_rows(input.interfaces,SPATIAL_INTERFACE_HEADER_V4)
    exterior=_spe_csv_rows(input.exterior,SPATIAL_EXTERIOR_HEADER_V4)
    isempty(volume)&&throw(ArgumentError("actual volume-current quadrature is required"))
    sources=SpatialCurrentQuadratureV4[]
    positions=NTuple{3,Float64}[]
    volume_current_integral=zeros(3);sheet_current_integral=zeros(3)
    exterior_current=0.;exterior_abs_current=0.;sheet_jump_mismatch=0.;normal_trace_jump_peak=0.
    for row in volume
        a=parse.(Float64,row[3:end]);all(isfinite,a)&&a[4]>0 || throw(ArgumentError("invalid volume current data"))
        xyz=Tuple(a[1:3]);weight=a[4];J=Tuple(a[8:10])
        weighted=ntuple(k->weight*J[k],3)
        push!(sources,SpatialCurrentQuadratureV4(xyz,weighted,:volume));push!(positions,xyz)
        volume_current_integral .+= collect(weighted)
    end
    for row in interfaces
        a=parse.(Float64,row[4:end]);all(isfinite,a)&&a[4]>0 || throw(ArgumentError("invalid interface current data"))
        xyz=Tuple(a[1:3]);weight=a[4];n=a[5:7];minus=a[8:10];plus=a[11:13];K=a[14:16]
        abs(norm(n)-1)<1e-10 || throw(ArgumentError("interface current normal not unit"))
        derived=cross(n,plus-minus)/mu0
        mismatch=maximum(abs,derived-K);sheet_jump_mismatch=max(sheet_jump_mismatch,mismatch)
        mismatch<=1e-8+1e-10*max(norm(derived),norm(K)) || throw(ArgumentError("sheet current does not match actual B traces"))
        normal_trace_jump_peak=max(normal_trace_jump_peak,abs(a[17]-a[18]))
        weighted=ntuple(k->weight*K[k],3)
        push!(sources,SpatialCurrentQuadratureV4(xyz,weighted,:interface));push!(positions,xyz)
        sheet_current_integral .+= collect(weighted)
    end
    for row in exterior
        a=parse.(Float64,row[2:end]);all(isfinite,a)&&a[4]>0 || throw(ArgumentError("invalid exterior current data"))
        xyz=Tuple(a[1:3]);n=a[5:7];J=a[11:13]
        abs(norm(n)-1)<1e-10 || throw(ArgumentError("exterior current normal not unit"))
        flux=dot(J,n)*a[4];exterior_current+=flux;exterior_abs_current+=abs(flux)
        push!(positions,xyz)
    end
    # Keep large current clouds as vectors: tuple length must not specialize
    # thousands of source points into a distinct compiler-generated method.
    (sources=sources,positions=positions,diagnostics=(
        volume_current_integral_Am=Tuple(volume_current_integral),
        interface_current_integral_Am=Tuple(sheet_current_integral),
        exterior_net_current_A=exterior_current,exterior_absolute_current_A=exterior_abs_current,
        interface_K_jump_mismatch_A_m=sheet_jump_mismatch,
        interface_normal_current_jump_peak_A_m2=normal_trace_jump_peak,
        outer_sheet_current=:unknown,external_return_current=:unknown,
        source_closure_certified=false,input_closure=input.current_closure))
end

function spatial_plasma_field_v4(x,sources;mu0=_SPE_MU0)
    all(isfinite,x)&&length(x)==3 || throw(ArgumentError("finite 3-D field target required"))
    b1=0.;b2=0.;b3=0.
    for s in sources
        y=s.position_xyz_m;j=s.weighted_current_Am
        r1=x[1]-y[1];r2=x[2]-y[2];r3=x[3]-y[3]
        r_sq=r1*r1+r2*r2+r3*r3
        r_sq>0&&isfinite(r_sq) || throw(ArgumentError("Biot-Savart target intersects current quadrature"))
        f=mu0/(4pi*r_sq*sqrt(r_sq))
        b1+=f*(j[2]*r3-j[3]*r2);b2+=f*(j[3]*r1-j[1]*r3);b3+=f*(j[1]*r2-j[2]*r1)
    end
    B=(b1,b2,b3);all(isfinite,B)||throw(ArgumentError("non-finite plasma contribution field"));B
end

function _spe_disk_quadrature(center,radius,nr,nt)
    nr>=1&&nt>=4&&radius>0 || throw(ArgumentError("invalid finite disk quadrature"))
    eig=eigen(SymTridiagonal(zeros(nr),[k/sqrt(4k*k-1) for k in 1:nr-1]))
    Tuple(begin
        s=(eig.values[i]+1)/2;w=eig.vectors[1,i]^2;theta=2pi*(j-.5)/nt
        (position_xyz_m=(center[1]+radius*s*cos(theta),center[2]+radius*s*sin(theta),center[3]),
         area_weight_m2=radius^2*s*w*2pi/nt)
    end for i in 1:nr for j in 1:nt)
end

function spatial_pickup_transfer_v4(sources,center;
        declaration=spatial_engineering_declaration_v4())
    p=_spe_parameters(declaration);q=declaration.transfer
    disk=_spe_disk_quadrature(center,p.radius_m,q.disk_radial_order,q.disk_angular_count)
    fields=Tuple(merge(point,(B_xyz_T=spatial_plasma_field_v4(point.position_xyz_m,sources;mu0=p.mu0_N_A2),)) for point in disk)
    flux=p.turns*sum(point.area_weight_m2*point.B_xyz_T[3] for point in fields)
    # Independent formulation: source integral against vector potential of a
    # unit-current circular test loop. No actual test excitation is asserted.
    reciprocal=0.
    for s in sources
        A1=0.;A2=0.
        for j in 1:q.reciprocity_wire_count
            theta=2pi*(j-.5)/q.reciprocity_wire_count
            c=cos(theta);si=sin(theta)
            loop=(center[1]+p.radius_m*c,center[2]+p.radius_m*si,center[3])
            distance=sqrt(sum((s.position_xyz_m[k]-loop[k])^2 for k in 1:3))
            distance>0 || throw(ArgumentError("unit test loop intersects source"))
            coefficient=p.mu0_N_A2/(4pi)*p.radius_m*2pi/q.reciprocity_wire_count/distance
            A1-=coefficient*si;A2+=coefficient*c
        end
        reciprocal+=p.turns*(s.weighted_current_Am[1]*A1+s.weighted_current_Am[2]*A2)
    end
    difference=abs(flux-reciprocal);scale=max(abs(flux),abs(reciprocal))
    numerical=difference<=q.absolute_tolerance_Wb+q.relative_tolerance*scale
    (biot_savart_flux_Wb=flux,reciprocity_flux_Wb=reciprocal,
        absolute_difference_Wb=difference,relative_difference=difference/max(scale,1e-30),
        status=numerical ? :pass : :fail,executed=true,
        solver_exit_code=numerical ? 0 : 1,disk_samples=fields,
        disk_area_m2=sum(point.area_weight_m2 for point in disk),
        quadrature=(radial_order=q.disk_radial_order,angular_count=q.disk_angular_count,
            reciprocity_wire_count=q.reciprocity_wire_count),
        scope=:plasma_current_contribution_not_total_external_field,
        reciprocity_excitation=:mathematical_unit_current_not_actual_driver)
end

"Exact constant-emf RL flow and analytic current/current-squared integrals."
function spatial_exact_rl_segment_v4(i0,emf,R,L,h)
    all(isfinite,(i0,emf,R,L,h))&&R>0&&L>0&&h>0 || throw(ArgumentError("invalid exact RL segment"))
    u=h*R/L;s=emf/R;d=s-i0
    # Stable analytic integrals of (1-exp(-t/tau)) and its square. The small-u
    # series avoid subtracting nearly equal terms; they are not time steps.
    m1,m2=if u<.01
        (u/2-u^2/6+u^3/24-u^4/120+u^5/720-u^6/5040+u^7/40320,
         u^2/3-u^3/4+7u^4/60-u^5/24+31u^6/2520-u^7/320)
    else
        phi1=-expm1(-u)/u;phi2=-expm1(-2u)/(2u)
        (1-phi1,1-2phi1+phi2)
    end
    integral_i=h*(i0+d*m1)
    integral_i2=h*(i0*i0+2i0*d*m1+d*d*m2)
    integral_i2>=0 || throw(ArgumentError("negative analytic squared-current integral"))
    next=s+(i0-s)*exp(-u)
    (current_A=next,integral_i_A_s=integral_i,integral_i2_A2_s=integral_i2,
        input_energy_J=emf*integral_i,joule_energy_J=R*integral_i2,
        energy_identity_error_J=emf*integral_i-R*integral_i2-.5L*(next^2-i0^2))
end

function spatial_pickup_exact_response_v4(flux_linkage_Wb;
        declaration=spatial_engineering_declaration_v4(),fault=:none)
    isfinite(flux_linkage_Wb)&&fault in declaration.conditional_model.scenarios ||
        throw(ArgumentError("finite genuine flux and declared fault scenario required"))
    p=_spe_parameters(declaration)
    p.duration_s>p.ramp_duration_s>p.short_time_s>0 || throw(ArgumentError("invalid circuit event ordering"))
    cadence=p.detection_cadence_s;n=round(Int,p.duration_s/cadence)
    all(t->isapprox(t/cadence,round(t/cadence);rtol=0,atol=1e-10),
        (p.duration_s,p.short_time_s,p.ramp_duration_s)) || throw(ArgumentError("declared events must align to fixed detector cadence"))
    Rwire=p.resistivity_ohm_m*(2pi*p.radius_m*p.turns)/(pi*p.wire_radius_m^2)
    L=p.inductance_H;emf_ramp=-Float64(flux_linkage_Wb)*p.ramp_fraction/p.ramp_duration_s
    current=0.;flux_estimate=0.;input_energy=0.;joule=0.;latched=false
    trip_time=nothing;crossing_time=nothing;peak_current=0.;peak_voltage=0.;segment_energy_error=0.
    previous_branch=p.load_resistance_ohm
    rows=NamedTuple[];events=NamedTuple[]
    push!(rows,(time_s=0.,flux_linkage_Wb=Float64(flux_linkage_Wb),emf_V=0.,
        current_A=0.,branch_voltage_V=0.,flux_change_estimate_Wb=0.,
        branch_resistance_ohm=previous_branch,relay_latched=false,readout_connected=true,
        sample_phase=:initial_condition,commutation_pending=false))
    previous_connected=true
    for k in 1:n
        t0=(k-1)*cadence;t1=k*cadence;h=t1-t0
        emf=(t0+t1)/2<p.ramp_duration_s ? emf_ramp : 0.
        shorted=fault===:load_short&&t0>=p.short_time_s
        branch=latched ? p.dump_resistance_ohm : (shorted ? p.short_resistance_ohm : p.load_resistance_ohm)
        connected=!latched
        if branch!=previous_branch
            push!(events,(time_s=t0,kind=latched ? :dump_commutation : :load_short,
                event_phase=:instantaneous_commutation_left_right_limits,
                current_left_A=current,current_right_A=current,
                branch_voltage_left_V=previous_branch*current,branch_voltage_right_V=branch*current,
                branch_resistance_left_ohm=previous_branch,branch_resistance_right_ohm=branch,
                readout_connected_left=previous_connected,readout_connected_right=connected))
            peak_voltage=max(peak_voltage,abs(previous_branch*current),abs(branch*current))
        end
        segment=spatial_exact_rl_segment_v4(current,emf,Rwire+branch,L,h)
        input_energy+=segment.input_energy_J;joule+=segment.joule_energy_J
        connected&&(flux_estimate-=branch*segment.integral_i_A_s)
        segment_energy_error=max(segment_energy_error,abs(segment.energy_identity_error_J))
        next=segment.current_A
        if !latched&&abs(next)>=p.trip_current_A
            # The analog crossing is diagnostic; the actual declared detector
            # still triggers only at t1 on its fixed 10-us sampling schedule.
            steady=emf/(Rwire+branch);target=sign(next)*p.trip_current_A
            ratio=(target-steady)/(current-steady)
            crossing_time=0<ratio<=1 ? t0-L/(Rwire+branch)*log(ratio) : t1
            latched=true;trip_time=t1
        end
        peak_current=max(peak_current,abs(current),abs(next))
        peak_voltage=max(peak_voltage,abs(branch*current),abs(branch*next))
        current=next;previous_branch=branch
        push!(rows,(time_s=t1,
            flux_linkage_Wb=Float64(flux_linkage_Wb)*(1+p.ramp_fraction*min(t1/p.ramp_duration_s,1.)),
            emf_V=emf,current_A=current,branch_voltage_V=branch*current,
            flux_change_estimate_Wb=flux_estimate,branch_resistance_ohm=branch,
            relay_latched=latched,readout_connected=connected,
            sample_phase=:pre_commutation_right_limit,
            commutation_pending=latched&&branch!=p.dump_resistance_ohm))
        previous_connected=connected
    end
    stored=.5L*current^2;defect=input_energy-joule-stored
    finite=all(isfinite,(current,flux_estimate,joule,input_energy,defect))
    finite || throw(ArgumentError("non-finite exact conditional circuit"))
    metrics=(current_peak_A=peak_current,branch_voltage_peak_V=peak_voltage,
        induced_emf_peak_V=abs(emf_ramp),final_current_A=current,
        flux_change_estimate_Wb=flux_estimate,imposed_flux_change_Wb=Float64(flux_linkage_Wb)*p.ramp_fraction,
        input_energy_J=input_energy,joule_energy_J=joule,final_stored_energy_J=stored,
        energy_identity_error_J=defect,maximum_segment_energy_identity_error_J=segment_energy_error,
        numerical_dissipation_added_J=0.,trip_time_s=trip_time,
        continuous_threshold_crossing_s=crossing_time,protection_latched=latched,
        local_readout_valid=fault===:none&&!latched,detection_cadence_s=cadence,
        interval_count=n,smallest_circuit_time_constant_s=L/(Rwire+p.dump_resistance_ohm))
    (fault=fault,executed=true,solver_exit_code=0,
        method=:exact_piecewise_exponential_with_analytic_energy_integrals,
        static_flux_linkage_input_Wb=Float64(flux_linkage_Wb),metrics=metrics,
        derived=(winding_resistance_ohm=Rwire,inductance_H=L,N_area_m2=p.turns*pi*p.radius_m^2),
        trajectory=Tuple(rows),events=Tuple(events),
        trajectory_semantics=(
            sample_phase=:pre_commutation_right_limit,
            branch_resistance_ohm=:branch_active_over_preceding_interval,
            readout_connected=:connection_active_over_preceding_interval,
            relay_latched=:post_endpoint_detection_state,
            commutation_pending=:latched_but_dump_branch_not_yet_active),
        event_semantics=(phase=:instantaneous_commutation_left_right_limits,
            current=:continuous_inductor_current,
            voltage_and_branch=:discontinuous_left_right_limits),
        scenario_scope=:conditional_prescribed_flux_ramp_not_solved_plasma_dynamics,
        peak_voltage_scope=:ideal_active_branch_voltage_including_event_limits_not_switch_arc_model)
end

struct SpatialPickupCaseResultV4
    candidate_hash::Digest256
    context_hash::Digest256
    case_id::String
    state_hash::Digest256
    input_hash::Digest256
    source_input::SpatialCurrentInputV4
    executed::Bool
    transfer_exit_code::Int
    circuit_exit_code::Int
    solver_exit_code::Int
    status::Symbol
    upstream_status::Symbol
    input_identity_valid::Bool
    physical_upstream_valid::Bool
    upstream_valid::Bool
    applicability_status::Symbol
    geometry::NamedTuple
    static::NamedTuple
    transfer::NamedTuple
    conditional::NamedTuple
    current_closure::NamedTuple
    artifacts::Tuple
    case_hash::Digest256
end
semantic_view(x::SpatialPickupCaseResultV4)=_spe_body(x)
function canonical_hash(x::SpatialPickupCaseResultV4)
    validate_spatial_current_input_v4(x.source_input)
    x.input_hash==canonical_hash(x.source_input)&&x.state_hash==x.source_input.state_hash&&
        x.case_id==x.source_input.case_id&&x.candidate_hash==x.source_input.candidate_hash&&
        x.context_hash==x.source_input.context_hash || throw(ArgumentError("spatial engineering current identity mismatch"))
    x.executed&&x.transfer_exit_code in (0,1)&&x.circuit_exit_code in (0,1)&&
        x.transfer_exit_code==x.transfer.solver_exit_code&&
        x.circuit_exit_code==max(x.conditional.nominal.solver_exit_code,x.conditional.readout_short.solver_exit_code)&&
        x.solver_exit_code==max(x.transfer_exit_code,x.circuit_exit_code)&&
        x.status in (:fail,:unsupported)&&(x.solver_exit_code==0||x.status===:fail)&&
        x.input_identity_valid&&!x.physical_upstream_valid&&
        x.upstream_valid==x.physical_upstream_valid&&x.applicability_status===:unsupported&&
        x.static.induced_emf_V==0.0 && !x.static.total_external_field || throw(ArgumentError("spatial engineering claim exceeds computed contribution"))
    x.upstream_status==x.source_input.status &&
        (x.source_input.status!==:fail||x.status===:fail) || throw(ArgumentError("spatial upstream failure not propagated"))
    (x.conditional.nominal.fault,x.conditional.readout_short.fault)==(:none,:load_short) ||
        throw(ArgumentError("conditional fault sequence differs from declaration"))
    foreach(validate_spatial_artifact_v4,x.artifacts)
    h=canonical_hash(semantic_view(x));h==x.case_hash||throw(ArgumentError("spatial engineering case hash mismatch"));h
end

struct SpatialPickupEngineeringResultV4
    candidate_hash::Digest256
    context_hash::Digest256
    declaration_hash::Digest256
    physics_hash::Digest256
    cases::Tuple{Vararg{SpatialPickupCaseResultV4}}
    executed::Bool
    transfer_exit_code::Int
    circuit_exit_code::Int
    solver_exit_code::Int
    status::Symbol
    source_artifact::SpatialArtifactV4
    physical_validation::Symbol
    engineering_qualified::Bool
    result_hash::Digest256
end
semantic_view(x::SpatialPickupEngineeringResultV4)=_spe_body(x)
function canonical_hash(x::SpatialPickupEngineeringResultV4)
    x.executed&&x.transfer_exit_code in (0,1)&&x.circuit_exit_code in (0,1)&&
        x.solver_exit_code==max(x.transfer_exit_code,x.circuit_exit_code)&&
        x.status in (:fail,:unsupported)&&(x.solver_exit_code==0||x.status===:fail)&&
        x.physical_validation===:unsupported&&!x.engineering_qualified || throw(ArgumentError("invalid spatial engineering authority"))
    Tuple(c.case_id for c in x.cases)==spatial_engineering_declaration_v4().case_ids ||
        throw(ArgumentError("spatial engineering requires every declared case in order"))
    all(c->c.candidate_hash==x.candidate_hash&&c.context_hash==x.context_hash,x.cases) ||
        throw(ArgumentError("spatial engineering combines candidate revisions"))
    foreach(canonical_hash,x.cases);validate_spatial_artifact_v4(x.source_artifact)
    x.transfer_exit_code==maximum(c.transfer_exit_code for c in x.cases)&&
        x.circuit_exit_code==maximum(c.circuit_exit_code for c in x.cases)&&
        x.solver_exit_code==maximum(c.solver_exit_code for c in x.cases) ||
        throw(ArgumentError("spatial engineering aggregate exit differs from cases"))
    h=canonical_hash(semantic_view(x));h==x.result_hash||throw(ArgumentError("spatial engineering result hash mismatch"));h
end

function _spe_owned_declaration(context)
    validate_spatial_candidate_v4(context)
    owned=Tuple(x for x in context.candidate.realization_control_genome_ref.realization if x isa SpatialPickupEngineeringDeclarationV4)
    length(owned)==1 || throw(ArgumentError("one G3 spatial pickup declaration required"))
    d=only(owned);canonical_hash(d)==canonical_hash(spatial_engineering_declaration_v4()) ||
        throw(ArgumentError("unsupported spatial engineering declaration"));d
end

function _spe_geometry_v4(bound,positions,declaration;provider_enclosure=nothing)
    p=_spe_parameters(declaration);radius_bound=Float64(bound.R_upper_m)
    isfinite(radius_bound)&&radius_bound>0 || throw(ArgumentError("positive analytic geometry radius bound required"))
    p.center_offset_m>p.radius_m || throw(ArgumentError("pickup aperture intersects analytic geometry enclosure"))
    sample_enclosed=all(x->hypot(x[1],x[2])<=radius_bound+1e-10*max(1.,radius_bound),positions)
    center=(radius_bound+p.center_offset_m,0.,0.)
    sample_clearance=minimum(sqrt(x[3]^2+max(hypot(x[1]-center[1],x[2])-p.radius_m,0.)^2) for x in positions)
    sample_clearance>0 || throw(ArgumentError("current quadrature intersects pickup aperture"))
    provider_supported=false
    if provider_enclosure!==nothing
        if hasproperty(provider_enclosure,:artifact)
            validate_spatial_artifact_v4(provider_enclosure.artifact)
        elseif provider_enclosure.supported
            throw(ArgumentError("supported provider enclosure requires its bound artifact"))
        end
        provider_supported=provider_enclosure.supported&&isfinite(provider_enclosure.R_upper_m)&&
            0<provider_enclosure.R_upper_m<=radius_bound
    end
    (center_xyz_m=center,normal_xyz=declaration.geometry.normal_xyz,
        radius_m=p.radius_m,analytic_clearance_lower_bound_m=p.center_offset_m-p.radius_m,
        declared_map_clearance_proved=true,actual_sample_enclosure_verified=sample_enclosed,
        actual_sample_to_aperture_clearance_m=sample_clearance,
        continuous_solved_interior_enclosure=provider_supported ? :proved : :unsupported,
        provider_enclosure=provider_enclosure,bound=bound,
        scope=:ideal_aperture_enclosure_not_complete_hardware_envelope)
end

function _spe_case_computation(context,case,bound,declaration)
    input=case.engineering_input
    input.candidate_hash==context.candidate_hash&&input.context_hash==context.context_hash&&
        input.state_hash==case.state_hash&&input.case_id==case.case_id&&
        input.status==case.status&&input.solver_exit_code==case.solver_exit_code ||
        throw(ArgumentError("spatial current files belong to a different physical case"))
    parsed=spatial_current_sources_v4(input)
    provider_enclosure=hasproperty(input.current_closure,:provider_geometry_enclosure) ?
        input.current_closure.provider_geometry_enclosure : nothing
    geometry=_spe_geometry_v4(bound,parsed.positions,declaration;provider_enclosure)
    transfer=spatial_pickup_transfer_v4(parsed.sources,geometry.center_xyz_m;declaration)
    flux=transfer.biot_savart_flux_Wb
    conditional=(nominal=spatial_pickup_exact_response_v4(flux;declaration,fault=:none),
        readout_short=spatial_pickup_exact_response_v4(flux;declaration,fault=:load_short))
    transfer_exit=transfer.solver_exit_code
    circuit_exit=max(conditional.nominal.solver_exit_code,conditional.readout_short.solver_exit_code)
    status=input.status===:fail||transfer.status===:fail||circuit_exit!=0 ? :fail : :unsupported
    (candidate_hash=context.candidate_hash,context_hash=context.context_hash,
        case_id=String(case.case_id),state_hash=case.state_hash,input_hash=canonical_hash(input),
        source_input=input,executed=true,transfer_exit_code=transfer_exit,circuit_exit_code=circuit_exit,
        solver_exit_code=max(transfer_exit,circuit_exit),status=status,
        upstream_status=input.status,input_identity_valid=true,physical_upstream_valid=false,
        upstream_valid=false,applicability_status=:unsupported,
        geometry=geometry,
        static=(flux_linkage_Wb=flux,induced_emf_V=0.,coil_motion=:stationary,
            field_time_dependence=:static,scope=:plasma_current_contribution_only,
            total_external_field=false,physical_validation=:unsupported),
        transfer=transfer,conditional=conditional,current_closure=parsed.diagnostics)
end

function _spe_table_text(rows,header)
    io=IOBuffer();println(io,header)
    for row in rows;println(io,join(string.(values(row)),','));end
    String(take!(io))
end

function _spe_case_tables(body)
    disk=Tuple((x_m=s.position_xyz_m[1],y_m=s.position_xyz_m[2],z_m=s.position_xyz_m[3],
        dA_m2=s.area_weight_m2,Bx_T=s.B_xyz_T[1],By_T=s.B_xyz_T[2],Bz_T=s.B_xyz_T[3]) for s in body.transfer.disk_samples)
    rows=(disk,body.conditional.nominal.trajectory,body.conditional.readout_short.trajectory,
        body.conditional.nominal.events,body.conditional.readout_short.events)
    header_events="time_s,kind,event_phase,current_left_A,current_right_A,branch_voltage_left_V,branch_voltage_right_V,branch_resistance_left_ohm,branch_resistance_right_ohm,readout_connected_left,readout_connected_right"
    headers=(join(string.(keys(first(disk))),','),
        join(string.(keys(first(rows[2]))),','),join(string.(keys(first(rows[3]))),','),
        header_events,header_events)
    names=("finite_disk_field.csv","conditional_nominal.csv","conditional_short.csv",
        "nominal_events.csv","short_events.csv")
    Tuple((name=names[i],text=_spe_table_text(rows[i],headers[i]),rows=length(rows[i])) for i in 1:5)
end

function execute_spatial_engineering_v4(context,physics,run_dir;kwargs...)
    isempty(kwargs)||throw(ArgumentError("spatial engineering controls are candidate-owned"))
    declaration=_spe_owned_declaration(context)
    validate_spatial_result_v4(context,physics)
    Tuple(String(c.case_id) for c in physics.cases)==declaration.case_ids ||
        throw(ArgumentError("all spatial physical cases must execute in declared order"))
    physics.candidate_hash==context.candidate_hash&&physics.context_hash==context.context_hash ||
        throw(ArgumentError("foreign spatial physics result"))
    bound=spatial_candidate_geometry_bound_v4(context)
    cases=Tuple(begin
        body=_spe_case_computation(context,c,bound,declaration)
        dir=abspath(joinpath(run_dir,c.case_id));mkpath(dir)
        tables=_spe_case_tables(body)
        artifacts=Tuple(begin
            path=joinpath(dir,t.name);write(path,t.text)
            SpatialArtifactV4(path,_spe_sha(path),"spatial-pickup-"*t.name,t.rows)
        end for t in tables)
        payload=(body...,artifacts=artifacts)
        SpatialPickupCaseResultV4(values(payload)...,canonical_hash(payload))
    end for c in physics.cases)
    body=(candidate_hash=context.candidate_hash,context_hash=context.context_hash,
        declaration_hash=canonical_hash(declaration),physics_hash=canonical_hash(physics),cases=cases,
        executed=true,transfer_exit_code=maximum(c.transfer_exit_code for c in cases),
        circuit_exit_code=maximum(c.circuit_exit_code for c in cases),
        solver_exit_code=maximum(c.solver_exit_code for c in cases),
        status=any(c->c.status===:fail,cases) ? :fail : :unsupported,
        source_artifact=SpatialArtifactV4(_SPE_SOURCE,_spe_sha(_SPE_SOURCE),"julia-spatial-pickup-source-v1",0),
        physical_validation=:unsupported,engineering_qualified=false)
    result=SpatialPickupEngineeringResultV4(values(body)...,canonical_hash(body));canonical_hash(result);result
end

function validate_spatial_engineering_result_v4(context,physics,result::SpatialPickupEngineeringResultV4)
    declaration=_spe_owned_declaration(context);validate_spatial_result_v4(context,physics)
    result.candidate_hash==context.candidate_hash&&result.context_hash==context.context_hash&&
        result.declaration_hash==canonical_hash(declaration)&&result.physics_hash==canonical_hash(physics) ||
        throw(ArgumentError("spatial engineering input identity differs"))
    result.source_artifact.path==_SPE_SOURCE&&result.source_artifact.sha256==_spe_sha(_SPE_SOURCE) ||
        throw(ArgumentError("spatial engineering source differs from executing implementation"))
    canonical_hash(result)
    bound=spatial_candidate_geometry_bound_v4(context)
    for (physical,executed) in zip(physics.cases,result.cases)
        body=_spe_case_computation(context,physical,bound,declaration)
        all(k->getproperty(executed,k)==getproperty(body,k),keys(body)) ||
            throw(ArgumentError("actual-current to spatial pickup replay differs"))
        tables=_spe_case_tables(body)
        length(executed.artifacts)==length(tables) || throw(ArgumentError("missing spatial engineering output table"))
        for (a,t) in zip(executed.artifacts,tables)
            a.row_count==t.rows&&read(a.path,String)==t.text || throw(ArgumentError("spatial pickup output bytes differ from current replay"))
        end
    end
    result
end
