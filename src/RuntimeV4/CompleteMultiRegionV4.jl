# Candidate-owned, four-DOF reduced static-MHD execution. This is not a full MHD PDE solver.
using FusionConceptAI
using LinearAlgebra
using SHA
import FusionConceptAI: Digest256, canonical_hash, semantic_view, screen_only

const _CMR_MU0 = 1.25663706127e-6
const _CMR_SOURCE = abspath(@__FILE__)
const _CMR_SAMPLER = normpath(joinpath(@__DIR__, "..", "..", "scripts", "complete_multiregion_desc_sample.py"))
_cmr_sha(p) = Digest256(bytes2hex(SHA.sha256(read(p))))
_cmr_rows(A) = Tuple(Tuple(Float64(A[i,j]) for j in axes(A,2)) for i in axes(A,1))
_cmr_matrix(t) = reduce(vcat, (reshape(collect(r),1,:) for r in t))

struct MultiRegionParameterV4
    name::Symbol; value::Float64; unit::String; interval::Tuple{Float64,Float64}
    source::String; applicability::String; epistemic_status::Symbol
end
semantic_view(x::MultiRegionParameterV4) = NamedTuple{fieldnames(typeof(x))}(Tuple(getfield(x,n) for n in fieldnames(typeof(x))))

struct CompleteMultiRegionDeclarationV4
    revision::String; regions::Tuple; interfaces::Tuple; states::Tuple
    test_space::NamedTuple; volume_law::String; source::NamedTuple
    outer_boundary::NamedTuple; axis::NamedTuple; parameters::Tuple
    quadrature::NamedTuple; solver::NamedTuple; applicability::Tuple
end
semantic_view(x::CompleteMultiRegionDeclarationV4) = NamedTuple{fieldnames(typeof(x))}(Tuple(getfield(x,n) for n in fieldnames(typeof(x))))

function multiregion_declaration_v4()
    assumption = "Exploratory reduced-model design assumption, revised execution contract 2026-09-12; not measured"
    params = (
        MultiRegionParameterV4(:mu0,_CMR_MU0,"N A^-2",(_CMR_MU0,_CMR_MU0),"NIST CODATA 2022 nominal vacuum magnetic permeability https://physics.nist.gov/cgi-bin/cuu/Value?mu0","Classical static Maxwell stress; fixed nominal, uncertainty not propagated",:reference_constant),
        MultiRegionParameterV4(:test_reference_length,1.0,"m",(1.0,1.0),assumption,"Dimensionless affine Cartesian tests only",:exploratory),
        MultiRegionParameterV4(:reference_pressure_multiplier,1.0,"1",(0.9,1.1),assumption,"Deterministic constitutive/exterior-traction sensitivity at fixed DESC geometry and B; not equilibrium-profile UQ",:exploratory))
    regions = ((id="plasma_core",rho=(0.0,0.5),owner=:G2,material=:static_ideal_mhd),
               (id="plasma_edge",rho=(0.5,1.0),owner=:G2,material=:static_ideal_mhd))
    states = Tuple((id=Symbol("$(r.id)_$(s)"),region_id=r.id,unit="1",initial=1.0,bounds=(0.5,1.5),
                    meaning=s==:a ? "B=a*B_DESC; J=a*J_DESC within region" : "p=c*pressure_multiplier*p_DESC",source=assumption)
                   for r in regions for s in (:a,:c))
    CompleteMultiRegionDeclarationV4("complete-reduced-multiregion-v1",regions,
        ((id="rho_half",minus="plasma_core",plus="plasma_edge",rho=0.5,
          trace=:exact_same_surface,numerical_flux=:arithmetic_stress,
          conditions=(:traction_continuity,:normal_B_continuity)),),states,
        (basis=(:one,:x_over_L,:y_over_L,:z_over_L),components=(:x,:y,:z),
         region_tests=24,interface_jump_moments=12,total_rows=36,total_state_dofs=4),
        "div(T)=0, T=(B*B' - |B|^2 I/2)/mu0 - p I; weak=-integral(T:grad(v))+boundary(v*T*n)",
        (body_force_xyz_N_m3=(0.0,0.0,0.0),owner=:G2,meaning="No gravity, flow, heating or external volumetric momentum source in this static model",source=assumption),
        (id="rho_one",rho=1.0,type=:prescribed_reference_traction,law="T_DESC(pressure_multiplier)*n",geometry=:fixed_DESC_surface),
        (rho=0.0,condition=:regularity,measure=:zero_surface_measure,theta_zeta=:periodic),
        params,(radial_rule=:gauss_legendre,radial_order=6,theta_count=16,zeta_count=16,torus=:all_field_periods_rotated),
        (method=:bounded_damped_gauss_newton,max_iterations=15,relative_residual_tolerance=1e-6,gradient_tolerance=1e-12),
        (:four_coefficient_ansatz_only,:fixed_geometry,:no_transport_or_energy_evolution,
         :DESC_flux_representation_preserves_interior_divB,:interface_normal_B_checked,
         :pointwise_force_and_jump_are_diagnostics,:physical_validation_unsupported))
end

struct CompleteMultiRegionResultV4
    candidate_hash::Digest256; context_hash::Digest256; status::Symbol
    executed::Bool; solver_exit_code::Int; declaration_hash::Digest256
    declaration::CompleteMultiRegionDeclarationV4; coefficient_matrix::Tuple
    constant_magnetic::Tuple; constant_pressure::Tuple; row_scales::Tuple; row_labels::Tuple
    initial_state::Tuple; final_state::Tuple; residual::Tuple; full_state_jacobian::Tuple
    iterations::Tuple; stopping_reason::Symbol; diagnostics::NamedTuple
    conservation::NamedTuple; engineering_input::NamedTuple; execution::NamedTuple
    physical_validation::Symbol; claim_ceiling::typeof(screen_only); result_hash::Digest256
end
semantic_view(x::CompleteMultiRegionResultV4) = NamedTuple{fieldnames(typeof(x))[1:end-1]}(Tuple(getfield(x,n) for n in fieldnames(typeof(x))[1:end-1]))
function canonical_hash(x::CompleteMultiRegionResultV4)
    h=canonical_hash(semantic_view(x))
    h==x.result_hash || throw(ArgumentError("Multi-region result hash mismatch"))
    x.executed && x.physical_validation==:unsupported && x.claim_ceiling==screen_only || throw(ArgumentError("Multi-region authority mismatch"))
    h
end

function _cmr_declaration(context)
    validate_revised_declarations_v4(context)
    candidates = filter(x->x isa CompleteMultiRegionDeclarationV4, context.candidate.field_geometry_genome_ref.fields)
    length(candidates)==1 || throw(ArgumentError("Exactly one candidate-owned CompleteMultiRegionDeclarationV4 is required in G2 fields"))
    d=only(candidates)
    canonical_hash(d)==canonical_hash(multiregion_declaration_v4()) || throw(ArgumentError("Unsupported multi-region declaration revision"))
    d
end

function _cmr_assert_assembly_v4(p,a,d)
    _cmr_rows(a.coefficient_matrix)==p.coefficient_matrix && Tuple(a.constant_magnetic)==p.constant_magnetic &&
        Tuple(a.constant_pressure)==p.constant_pressure && Tuple(a.row_scales)==p.row_scales && a.row_labels==p.row_labels ||
        throw(ArgumentError("Raw-to-coefficient/scales/row ownership replay mismatch"))
    p.initial_state==Tuple(s.initial for s in d.states) || throw(ArgumentError("Initial state is not the declared initial state"))
    true
end

function _cmr_diagnostic_valid(diag,code)
    code==0 && maximum(diag.strong_force_relative_peak)<1e-3 &&
        diag.pointwise_interface_traction_jump_relative<1e-6 && diag.pointwise_exterior_traction_mismatch_relative<1e-6
end

function _cmr_assert_engineering_metadata_v4(eng,diag,state,code,hdf5_path,hdf5_sha256)
    eng.outer_B_scale==state[3] && eng.B_includes_final_outer_scale===true && eng.upstream_valid===false &&
        eng.reduced_model_diagnostic_valid==_cmr_diagnostic_valid(diag,code) &&
        eng.upstream_status==(code==0 ? :upstream_convergence_unattested : :fail) &&
        eng.reference_hdf5_path==hdf5_path && eng.reference_hdf5_sha256==hdf5_sha256 &&
        eng.pressure_semantics===:plasma_pressure_not_material_stress ||
        throw(ArgumentError("Engineering field scale/validity/source metadata do not follow solved physics"))
    true
end

function _cmr_parse(path)
    lines=readlines(path)
    first(lines)=="kind\tregion\trho\ttheta\tzeta\tx\ty\tz\tBx\tBy\tBz\tp\tJx\tJy\tJz\tgradpx\tgradpy\tgradpz\tnx\tny\tnz\tmeasure" || throw(ArgumentError("Multi-region raw schema mismatch"))
    samples=NamedTuple[]
    for line in lines[2:end]
        z=split(line,'\t'); length(z)==22 || throw(ArgumentError("Bad raw sample row"))
        a=parse.(Float64,z[3:end]); all(isfinite,a) || throw(ArgumentError("Nonfinite raw sample"))
        push!(samples,(kind=Symbol(z[1]),region=parse(Int,z[2]),rho=a[1],theta=a[2],zeta=a[3],
            position_xyz_m=Tuple(a[4:6]),B_xyz_T=Tuple(a[7:9]),p_Pa=a[10],J_xyz_A_m2=Tuple(a[11:13]),
            gradp_xyz_N_m3=Tuple(a[14:16]),normal_xyz=Tuple(a[17:19]),measure=a[20]))
    end
    for s in samples
        s.measure>0 || throw(ArgumentError("Nonpositive integration measure"))
        if s.kind==:volume
            s.region in (1,2) && (s.region-1)/2<s.rho<s.region/2 || throw(ArgumentError("Volume row outside owned region"))
            s.normal_xyz==(0.0,0.0,0.0) || throw(ArgumentError("Volume row cannot claim surface normal"))
        elseif s.kind==:interface
            s.region==1 && s.rho==0.5 || throw(ArgumentError("Interface is not the declared exact surface"))
            abs(norm(collect(s.normal_xyz))-1)<1e-12 || throw(ArgumentError("Invalid interface normal"))
        elseif s.kind==:exterior
            s.region==2 && s.rho==1.0 || throw(ArgumentError("Exterior is not the declared exact surface"))
            abs(norm(collect(s.normal_xyz))-1)<1e-12 || throw(ArgumentError("Invalid exterior normal"))
        else
            throw(ArgumentError("Unknown sample role"))
        end
    end
    samples
end

"""Assemble every owned weak term, including 12 independent jump moments.

Rows 1:12 core, 13:24 edge, 25:36 traction-jump tests. Test order is
phi=(1,x/L,y/L,z/L), component x/y/z. Columns multiply (a1^2,c1,a2^2,c2).
"""
function assemble_multiregion_coefficients_v4(samples; reference_length_m=1.0)
    C=zeros(36,4); dm=zeros(36); dp=zeros(36)
    volume=zeros(36,4); interface=zeros(36,4); jump=zeros(36,4)
    for s in samples
        B=collect(s.B_xyz_T); n=collect(s.normal_xyz)
        M=(B*B'-dot(B,B)*Matrix{Float64}(I,3,3)/2)/_CMR_MU0
        P=-s.p_Pa*Matrix{Float64}(I,3,3)
        phi=(1.0,(v/reference_length_m for v in s.position_xyz_m)...)
        if s.kind==:volume
            r=s.region; r in (1,2) || throw(ArgumentError("Unknown volume owner"))
            for t in 2:4, k in 1:3
                row=12*(r-1)+3*(t-1)+k
                volume[row,2r-1] -= s.measure*M[k,t-1]/reference_length_m
                volume[row,2r] -= s.measure*P[k,t-1]/reference_length_m
            end
        elseif s.kind==:interface
            mn=M*n; pn=P*n
            for t in 1:4,k in 1:3
                q=3*(t-1)+k; w=s.measure*phi[t]
                for r in 1:2
                    orient=r==1 ? 1.0 : -1.0
                    for owner in 1:2
                        interface[12*(r-1)+q,2owner-1] += orient*w*mn[k]/2
                        interface[12*(r-1)+q,2owner] += orient*w*pn[k]/2
                    end
                    jump[24+q,2r-1] += orient*w*mn[k]
                    jump[24+q,2r] += orient*w*pn[k]
                end
            end
        elseif s.kind==:exterior
            mn=M*n;pn=P*n
            for t in 1:4,k in 1:3
                row=12+3*(t-1)+k; w=s.measure*phi[t]
                dm[row] += w*mn[k];dp[row] += w*pn[k]
            end
        else
            throw(ArgumentError("Unknown integration term $(s.kind)"))
        end
    end
    C .= volume .+ interface .+ jump
    scales=max.(vec(sum(abs.(C);dims=2)).+abs.(dm).+abs.(dp),1.0)
    labels=Tuple("$(r):phi$(t):$(c)" for r in ("plasma_core","plasma_edge","rho_half_jump") for t in 0:3 for c in ("x","y","z"))
    (coefficient_matrix=C,constant_magnetic=dm,constant_pressure=dp,row_scales=scales,row_labels=labels,
        volume_coefficients=volume,interface_coefficients=interface,jump_coefficients=jump)
end

function _cmr_residual(C,dm,dp,x,pressure_multiplier)
    u=[x[1]^2,pressure_multiplier*x[2],x[3]^2,pressure_multiplier*x[4]]
    C*u+dm+pressure_multiplier*dp
end
function _cmr_jacobian(C,x,q)
    C*Diagonal([2x[1],q,2x[3],q])
end
function evaluate_multiregion_residual_v4(p::CompleteMultiRegionResultV4,x;pressure_multiplier=1.0)
    _cmr_residual(_cmr_matrix(p.coefficient_matrix),collect(p.constant_magnetic),collect(p.constant_pressure),collect(x),pressure_multiplier)
end

"""Real nonlinear update with analytic derivatives of ALL four declared states.
Exit 0 means reduced weak residual tolerance reached; 2 stationary/nonzero,
3 bounded line-search failure, 4 iteration limit. It is not physical validation.
"""
function solve_multiregion_state_v4(C,dm,dp,scales;pressure_multiplier=1.0,initial_state=ones(4),max_iterations=15,tolerance=1e-6)
    C=C isa Matrix ? C : _cmr_matrix(C);dm=collect(dm);dp=collect(dp);scales=collect(scales)
    0.9 <= pressure_multiplier <= 1.1 || throw(ArgumentError("Pressure scenario outside candidate range"))
    x=collect(Float64,initial_state);length(x)==4 && all(isfinite,x) || throw(ArgumentError("Invalid four-DOF initial state"))
    hist=NamedTuple[];code=4;stop=:iteration_limit
    for it in 0:max_iterations
        r=_cmr_residual(C,dm,dp,x,pressure_multiplier);J=_cmr_jacobian(C,x,pressure_multiplier)
        rn=r./scales;Jn=J./scales; nr=norm(rn);g=Jn'*rn
        push!(hist,(iteration=it,state=Tuple(x),residual_norm_N=norm(r),scaled_residual_norm=nr,
            scaled_residual_max=maximum(abs,rn),normal_equation_gradient_norm=norm(g)))
        if maximum(abs,rn)<=tolerance
            code=0;stop=:reduced_weak_tolerance;break
        elseif it==max_iterations
            break
        elseif norm(g)<=1e-12
            code=2;stop=:stationary_nonzero_residual;break
        end
        step=-(Jn'Jn+1e-12*Matrix{Float64}(I,4,4))\g
        accepted=false
        for power in 0:20
            trial=clamp.(x.+(0.5^power).*step,0.5,1.5)
            if norm(_cmr_residual(C,dm,dp,trial,pressure_multiplier)./scales)<nr*(1-1e-12)
                x=trial;accepted=true;break
            end
        end
        if !accepted
            code=3;stop=:bounded_line_search_failed;break
        end
    end
    r=_cmr_residual(C,dm,dp,x,pressure_multiplier)
    (final_state=Tuple(x),residual=Tuple(r),jacobian=_cmr_rows(_cmr_jacobian(C,x,pressure_multiplier)),iterations=Tuple(hist),
     solver_exit_code=code,stopping_reason=stop,status=code==0 ? :reduced_solved : :fail,
     pressure_multiplier=Float64(pressure_multiplier))
end

function solve_multiregion_state_v4(p::CompleteMultiRegionResultV4;kwargs...)
    solve_multiregion_state_v4(p.coefficient_matrix,p.constant_magnetic,p.constant_pressure,p.row_scales;kwargs...)
end

function _cmr_diagnostics(samples,x,C,dm,dp,scales)
    strong=zeros(2,3);natural=zeros(2,3);external=zeros(3);prescribed=zeros(3)
    volume=zeros(2);l2=zeros(2);peak=zeros(2);force_scale=zeros(2);jump_peak=0.0;jump_scale=0.0;bn_peak=0.0;bn_jump=0.0
    exterior_peak=0.0;exterior_scale=0.0
    for s in samples
        B=collect(s.B_xyz_T);P=s.p_Pa;J=collect(s.J_xyz_A_m2);gp=collect(s.gradp_xyz_N_m3);n=collect(s.normal_xyz)
        M=(B*B'-dot(B,B)*Matrix{Float64}(I,3,3)/2)/_CMR_MU0
        stress(r)=x[2r-1]^2*M-x[2r]*P*Matrix{Float64}(I,3,3)
        if s.kind==:volume
            r=s.region;F=x[2r-1]^2*cross(J,B)-x[2r]*gp
            strong[r,:].+=s.measure.*F;volume[r]+=s.measure;l2[r]+=s.measure*dot(F,F);peak[r]=max(peak[r],norm(F))
            force_scale[r]=max(force_scale[r],norm(x[2r-1]^2*cross(J,B))+norm(x[2r]*gp))
        elseif s.kind==:interface
            tm=stress(1)*n;tp=stress(2)*n
            natural[1,:].+=s.measure.*tm;natural[2,:].-=s.measure.*tp
            jump_peak=max(jump_peak,norm(tm-tp));jump_scale=max(jump_scale,norm(tm)+norm(tp))
            bn_peak=max(bn_peak,abs(dot(B,n)));bn_jump=max(bn_jump,abs((x[1]-x[3])*dot(B,n)))
        else
            traction=stress(2)*n;ref=(M-P*Matrix{Float64}(I,3,3))*n
            natural[2,:].+=s.measure.*traction;external.+=s.measure.*traction;prescribed.+=s.measure.*ref
            exterior_peak=max(exterior_peak,norm(traction-ref));exterior_scale=max(exterior_scale,norm(traction)+norm(ref))
            bn_peak=max(bn_peak,abs(dot(B,n)))
        end
    end
    weak=_cmr_residual(C,dm,dp,x,1.0);defect=strong-natural
    diagnostics=(regional_volume_m3=Tuple(volume),strong_force_rms_N_m3=Tuple(sqrt.(l2./volume)),
        strong_force_peak_N_m3=Tuple(peak),strong_force_relative_peak=Tuple(peak./max.(force_scale,1.0)),
        pointwise_interface_traction_jump_peak_Pa=jump_peak,pointwise_interface_traction_jump_relative=jump_peak/max(jump_scale,1.0),
        pointwise_exterior_traction_mismatch_peak_Pa=exterior_peak,pointwise_exterior_traction_mismatch_relative=exterior_peak/max(exterior_scale,1.0),
        reference_flux_surface_Bnormal_peak_T=bn_peak,interface_normal_B_jump_peak_T=bn_jump,
        interior_divB=:analytic_flux_representation_scaled_constant_per_region,
        weak_scaled_max=maximum(abs,weak./scales),test_space_sufficiency=:unsupported_four_dof_affine_tests_only,
        upstream_equilibrium_convergence=:unsupported_not_attested_by_provider_receipt)
    conservation=(body_source_xyz_N=(0.0,0.0,0.0),regional_integrated_strong_force_N=_cmr_rows(strong),
        regional_natural_boundary_flux_N=_cmr_rows(natural),regional_divergence_theorem_defect_N=_cmr_rows(defect),
        global_integrated_strong_force_N=Tuple(vec(sum(strong;dims=1))),
        global_actual_exterior_flux_N=Tuple(external),global_prescribed_exterior_flux_N=Tuple(prescribed),
        global_interface_jump_flux_N=Tuple(vec(sum(natural;dims=1))-external),
        global_divergence_theorem_defect_N=Tuple(vec(sum(defect;dims=1))),
        interface_numerical_flux_cancels_by_construction=true,
        conservation_certified=false,reason=:independent_flux_and_volume_defect_and_local_force_required)
    diagnostics,conservation
end

function _cmr_surface_samples(samples,x)
    Tuple((position_xyz_m=s.position_xyz_m,B_xyz_T=Tuple(x[3].*collect(s.B_xyz_T)),normal_xyz=s.normal_xyz,
        area_weight_m2=s.measure,rho=s.rho,theta=s.theta,zeta=s.zeta,region_id="plasma_edge") for s in samples if s.kind==:exterior)
end
function _cmr_surface_text(out,x)
    array(a)="["*join(string.(a),",")*"]"
    io=IOBuffer()
        print(io,"{\"schema\":\"complete-multiregion-surface-v1\",\"B_includes_final_outer_scale\":true,\"outer_B_scale\":",x[3],",\"samples\":[")
        for (i,s) in enumerate(out)
            i>1&&print(io,",")
            print(io,"{\"position_xyz_m\":",array(s.position_xyz_m),",\"B_xyz_T\":",array(s.B_xyz_T),",\"normal_xyz\":",array(s.normal_xyz),",\"area_weight_m2\":",s.area_weight_m2,",\"rho\":",s.rho,",\"theta\":",s.theta,",\"zeta\":",s.zeta,"}")
        end
        print(io,"]}\n")
    String(take!(io))
end
function _cmr_write_surface(path,samples,x)
    out=_cmr_surface_samples(samples,x)
    write(path,_cmr_surface_text(out,x))
    out
end

function execute_multiregion_v4(context,upstream::NamedTuple,run_dir;kwargs...)
    isempty(kwargs)||throw(ArgumentError("Execution controls are frozen in the candidate declaration"))
    validate_forward_chain_context(context);d=_cmr_declaration(context)
    validate_desc_geometry_compatibility(context,upstream.bridge,upstream.geometry,upstream.proof)
    for obj in (upstream.request,upstream.result,upstream.proof);canonical_hash(obj);end
    upstream.request.candidate_hash==context.candidate_hash==upstream.result.candidate_hash &&
        upstream.request.context_hash==context.context_hash==upstream.result.context_hash &&
        upstream.result.request_hash==canonical_hash(upstream.request) || throw(ArgumentError("Foreign upstream candidate/revision"))
    receipt=upstream.result.receipt;receipt===nothing&&throw(ArgumentError("Real DESC HDF5 receipt required"))
    validate_desc_provider_receipt(receipt)
    upstream.request.compatibility_certificate_hash==canonical_hash(upstream.proof.certificate)==upstream.result.compatibility_certificate_hash ||
        throw(ArgumentError("Foreign geometry certificate"))
    upstream.result.provider_executed && upstream.result.result_schema_validated || throw(ArgumentError("Upstream provider did not execute"))
    read(receipt.input_path,String)==_dgrpe_line_payload(upstream.request.runner_payload) &&
        read(receipt.adapter_path,String)==_DGRPE_ADAPTER_SOURCE && read(receipt.inspector_path,String)==_DGRPE_INSPECTOR_SOURCE ||
        throw(ArgumentError("Upstream actual input/source bytes do not match bound provider"))
    dir=abspath(run_dir);mkpath(dir);request_path=joinpath(dir,"sample_request.tsv");raw_path=joinpath(dir,"raw_samples.tsv")
    metadata_path=joinpath(dir,"sample_metadata.tsv");stdout_path=joinpath(dir,"sampler.stdout.txt");stderr_path=joinpath(dir,"sampler.stderr.txt")
    write(request_path,join(["candidate_hash\t$(context.candidate_hash)","context_hash\t$(context.context_hash)",
        "declaration_hash\t$(canonical_hash(d))","hdf5_sha256\t$(receipt.output_sha256)",
        "radial_order\t$(d.quadrature.radial_order)","theta_count\t$(d.quadrature.theta_count)","zeta_count\t$(d.quadrature.zeta_count)"],"\n")*"\n")
    cmd=Cmd([receipt.python_executable,_CMR_SAMPLER,receipt.output_path,request_path,raw_path,metadata_path,receipt.desc_module_path])
    proc=open(stdout_path,"w") do o
        open(stderr_path,"w") do e
            run(pipeline(ignorestatus(cmd),stdout=o,stderr=e))
        end
    end
    write(joinpath(dir,"sampler.exitcode"),string(proc.exitcode)*"\n")
    proc.exitcode==0 || throw(ArgumentError("Multi-region DESC sampler failed with exit $(proc.exitcode), see $stderr_path"))
    samples=_cmr_parse(raw_path)
    nfp=upstream.request.runner_payload.nfp;face_count=nfp*d.quadrature.theta_count*d.quadrature.zeta_count
    count(s->s.kind==:volume,samples)==2*d.quadrature.radial_order*face_count &&
        count(s->s.kind==:interface,samples)==count(s->s.kind==:exterior,samples)==face_count ||
        throw(ArgumentError("Quadrature coverage mismatch"))
    meta=Dict(Tuple(split(line,'\t';limit=2)) for line in readlines(metadata_path))
    meta["candidate_hash"]==string(context.candidate_hash) && meta["context_hash"]==string(context.context_hash) &&
        meta["declaration_hash"]==string(canonical_hash(d)) && meta["output_sha256"]==string(_cmr_sha(raw_path)) &&
        meta["hdf5_sha256"]==string(receipt.output_sha256) && meta["finite_offsets"]=="false" ||
        throw(ArgumentError("Sampler output metadata does not match current request/bytes"))
    assembled=assemble_multiregion_coefficients_v4(samples)
    solve=solve_multiregion_state_v4(assembled.coefficient_matrix,assembled.constant_magnetic,assembled.constant_pressure,assembled.row_scales;
        max_iterations=d.solver.max_iterations,tolerance=d.solver.relative_residual_tolerance)
    diagnostics,conservation=_cmr_diagnostics(samples,collect(solve.final_state),assembled.coefficient_matrix,
        assembled.constant_magnetic,assembled.constant_pressure,assembled.row_scales)
    surface_path=joinpath(dir,"final_boundary_field.json");surface=_cmr_write_surface(surface_path,samples,solve.final_state)
    coefficients_path=joinpath(dir,"coefficients.tsv");iteration_path=joinpath(dir,"iterations.tsv")
    open(coefficients_path,"w") do io
        println(io,"row\tlabel\tC_a1_squared\tC_c1\tC_a2_squared\tC_c2\td_magnetic\td_pressure\tscale_N\tresidual_N")
        for i in 1:36
            println(io,join((i,assembled.row_labels[i],assembled.coefficient_matrix[i,:]...,assembled.constant_magnetic[i],assembled.constant_pressure[i],assembled.row_scales[i],solve.residual[i]),'\t'))
        end
    end
    open(iteration_path,"w") do io
        println(io,"iteration\ta1\tc1\ta2\tc2\tresidual_norm_N\tscaled_residual_norm\tscaled_residual_max\tgradient_norm")
        for it in solve.iterations
            println(io,join((it.iteration,it.state...,it.residual_norm_N,it.scaled_residual_norm,it.scaled_residual_max,it.normal_equation_gradient_norm),'\t'))
        end
    end
    valid=_cmr_diagnostic_valid(diagnostics,solve.solver_exit_code)
    # Provider execution receipts do not attest equilibrium convergence; this flag cannot grant qualification.
    eng=(surface_samples=surface,sample_artifact_path=surface_path,sample_artifact_sha256=_cmr_sha(surface_path),
        outer_B_scale=solve.final_state[3],B_includes_final_outer_scale=true,upstream_valid=false,
        reduced_model_diagnostic_valid=valid,upstream_status=solve.solver_exit_code==0 ? :upstream_convergence_unattested : :fail,
        reference_hdf5_path=receipt.output_path,reference_hdf5_sha256=receipt.output_sha256,
        pressure_semantics=:plasma_pressure_not_material_stress)
    execution=(command=string(cmd),sampler_exit_code=proc.exitcode,solver_exit_code=solve.solver_exit_code,
        julia_version=string(VERSION),blas_config=string(BLAS.get_config()),
        request_path=request_path,request_sha256=_cmr_sha(request_path),raw_samples_path=raw_path,raw_samples_sha256=_cmr_sha(raw_path),
        metadata_path=metadata_path,metadata_sha256=_cmr_sha(metadata_path),source_path=_CMR_SOURCE,source_sha256=_cmr_sha(_CMR_SOURCE),
        coefficients_path=coefficients_path,coefficients_sha256=_cmr_sha(coefficients_path),iteration_path=iteration_path,iteration_sha256=_cmr_sha(iteration_path),
        sampler_path=_CMR_SAMPLER,sampler_sha256=_cmr_sha(_CMR_SAMPLER),python_path=receipt.python_executable,
        python_sha256=receipt.python_executable_sha256,desc_module_path=receipt.desc_module_path,desc_module_sha256=receipt.desc_module_sha256,
        hdf5_path=receipt.output_path,hdf5_sha256=receipt.output_sha256,upstream_request_hash=canonical_hash(upstream.request),upstream_result_hash=canonical_hash(upstream.result),
        upstream_receipt_hash=canonical_hash(receipt),sample_count=length(samples))
    body=(candidate_hash=context.candidate_hash,context_hash=context.context_hash,status=solve.status,executed=true,
        solver_exit_code=solve.solver_exit_code,declaration_hash=canonical_hash(d),declaration=d,
        coefficient_matrix=_cmr_rows(assembled.coefficient_matrix),constant_magnetic=Tuple(assembled.constant_magnetic),
        constant_pressure=Tuple(assembled.constant_pressure),row_scales=Tuple(assembled.row_scales),row_labels=assembled.row_labels,
        initial_state=Tuple(s.initial for s in d.states),final_state=solve.final_state,residual=solve.residual,full_state_jacobian=solve.jacobian,
        iterations=solve.iterations,stopping_reason=solve.stopping_reason,diagnostics=diagnostics,conservation=conservation,
        engineering_input=eng,execution=execution,physical_validation=:unsupported,claim_ceiling=screen_only)
    result=CompleteMultiRegionResultV4(values(body)...,canonical_hash(body))
    open(joinpath(dir,"result.txt"),"w") do io;show(io,MIME("text/plain"),semantic_view(result));end
    write(joinpath(dir,"solver.exitcode"),string(solve.solver_exit_code)*"\n")
    validate_multiregion_result_v4(context,result);result
end

function validate_multiregion_result_v4(context,p::CompleteMultiRegionResultV4)
    validate_forward_chain_context(context)
    p.candidate_hash==context.candidate_hash && p.context_hash==context.context_hash || throw(ArgumentError("Multi-region context mismatch"))
    p.declaration_hash==canonical_hash(_cmr_declaration(context))==canonical_hash(p.declaration) || throw(ArgumentError("G2 declaration mismatch"))
    canonical_hash(semantic_view(p))==p.result_hash || throw(ArgumentError("Multi-region result tamper"))
    for (path,h) in ((p.execution.raw_samples_path,p.execution.raw_samples_sha256),(p.execution.request_path,p.execution.request_sha256),
                    (p.execution.metadata_path,p.execution.metadata_sha256),(p.execution.source_path,p.execution.source_sha256),
                    (p.execution.sampler_path,p.execution.sampler_sha256),(p.execution.hdf5_path,p.execution.hdf5_sha256),
                    (p.execution.coefficients_path,p.execution.coefficients_sha256),(p.execution.iteration_path,p.execution.iteration_sha256),
                    (p.engineering_input.sample_artifact_path,p.engineering_input.sample_artifact_sha256))
        isfile(path)&&_cmr_sha(path)==h || throw(ArgumentError("Multi-region artifact changed: $path"))
    end
    raw=_cmr_parse(p.execution.raw_samples_path);a=assemble_multiregion_coefficients_v4(raw)
    _cmr_assert_assembly_v4(p,a,p.declaration)
    Tuple(evaluate_multiregion_residual_v4(p,p.final_state))==p.residual || throw(ArgumentError("Residual replay mismatch"))
    surface=_cmr_surface_samples(raw,p.final_state)
    surface==p.engineering_input.surface_samples && read(p.engineering_input.sample_artifact_path,String)==_cmr_surface_text(surface,p.final_state) ||
        throw(ArgumentError("Raw-to-updated boundary field replay mismatch"))
    replay=solve_multiregion_state_v4(p;max_iterations=p.declaration.solver.max_iterations,tolerance=p.declaration.solver.relative_residual_tolerance)
    replay.final_state==p.final_state && replay.iterations==p.iterations && replay.jacobian==p.full_state_jacobian &&
        replay.solver_exit_code==p.solver_exit_code && replay.stopping_reason==p.stopping_reason && replay.status==p.status ||
        throw(ArgumentError("Nonlinear solve replay mismatch"))
    diag,cons=_cmr_diagnostics(raw,collect(p.final_state),a.coefficient_matrix,a.constant_magnetic,a.constant_pressure,a.row_scales)
    diag==p.diagnostics && cons==p.conservation || throw(ArgumentError("Physical diagnostics replay mismatch"))
    _cmr_assert_engineering_metadata_v4(p.engineering_input,diag,p.final_state,p.solver_exit_code,p.execution.hdf5_path,p.execution.hdf5_sha256)
    p.executed&&p.physical_validation==:unsupported&&p.claim_ceiling==screen_only || throw(ArgumentError("Multi-region authority mismatch"))
    p.result_hash
end
