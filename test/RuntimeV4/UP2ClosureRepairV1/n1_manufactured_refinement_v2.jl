"""Numerical-only N1 refinement preflight; imports the unchanged production solver.

One bounded solve and a separate interpolation sequence.  Interpolation order
is never promoted to solved mesh order, physical closure, or candidate credit.
"""
module N1ManufacturedRefinementV2
using LinearAlgebra, SparseArrays, SHA
const REPO=normpath(joinpath(@__DIR__,"..","..",".."))
include(joinpath(REPO,"scripts","runtime_v4_manufactured_recovery_benchmark.jl"))
const OLD=RuntimeV4ManufacturedRecoveryBenchmark
const S=OLD.SPF
const INPUTS=(R0_m=3.,minor_radius_m=1.,beta_T_m=1/3,p0_Pa=1.e5,alpha_Pa_m2=1.e4,
    perturbation=(.11,-.07,.05,2.e3),max_iterations=12,solver_seconds=120.,
    residual_tolerance=1.e-6,gradient_tolerance=1.e-10,rank_relative_tolerance=1.e-10,
    source_class=:manufactured_analytic_not_measured,evidence_authority=:none)
const LEVELS=((level=:q1_2,nr=2,nt=2,nz=2,h=.5),
    (level=:q1_4,nr=4,nt=4,nz=4,h=.25),(level=:q1_8,nr=8,nt=8,nz=8,h=.125))
const GAUSS5_ROOTS=(-sqrt(5+2sqrt(10/7))/3,-sqrt(5-2sqrt(10/7))/3,0.,
    sqrt(5-2sqrt(10/7))/3,sqrt(5+2sqrt(10/7))/3)
const GAUSS5_WEIGHTS=((322-13sqrt(70))/900,(322+13sqrt(70))/900,128/225,
    (322+13sqrt(70))/900,(322-13sqrt(70))/900)
sha(path)=bytes2hex(SHA.sha256(read(path)))

function analytic_field_v2(xyz)
    X,Y,Z=xyz;R=hypot(X,Y);R>0 || throw(ArgumentError("manufactured torus excludes R=0"))
    b=INPUTS.beta_T_m;a=INPUTS.alpha_Pa_m2;r0=INPUTS.R0_m
    B=(-b*Y,b*X,0.);p=INPUTS.p0_Pa+a*((R-r0)^2+Z^2)
    radial=-2b^2*R/S._SMR_MU0-2a*(R-r0)
    (B=B,p=p,source=(radial*X/R,radial*Y/R,-2a*Z),
        B_cyl=(0.,b*R,0.),J_xyz=(0.,0.,2b/S._SMR_MU0))
end
source_v2(xyz)=analytic_field_v2(xyz).source
function traction_v2(xyz,normal)
    f=analytic_field_v2(xyz);S._smr_stress(collect(f.B),f.p)*collect(normal)
end
normal_v2(xyz,normal)=dot(collect(analytic_field_v2(xyz).B),collect(normal))
flux_v2()=INPUTS.beta_T_m*INPUTS.R0_m*pi*INPUTS.minor_radius_m^2

function fixture_v2(level)
    rhos=Tuple(range(0.,1.;length=level.nr+1))
    spaces=((level=level.level,rho=rhos,theta_count=level.nt,zeta_per_period=level.nz),)
    old=OLD.benchmark_data((level.level,1,spaces,level.h))
    bind(s)=begin f=analytic_field_v2(s.xyz);merge(s,(B_reference_cyl=f.B_cyl,p_reference=f.p)) end
    nodes=bind.(old.data.nodes);volume=bind.(old.data.volume);faces=bind.(old.data.face_quadrature)
    x=Float64[]
    for s in nodes;append!(x,s.B_reference_cyl);push!(x,s.p_reference);end
    data=merge(old.data,(nodes=nodes,volume=volume,face_quadrature=faces,initial_state=x,
        raw_artifacts=(manufactured_numerical_only=true,revision=:n1_manufactured_refinement_v2,
            analytic_input_hash=S.canonical_hash(INPUTS))))
    # The actual source and traction are explicit callbacks, exactly as in the
    # preserved N1 entry.  The complete input hash below binds their source file.
    (declaration=old.declaration,data=data)
end

"Independent five-point quadrature of the same analytic circular geometry."
function sample5(entity,qp,q,qw,axis)
    rho,theta,zeta=q;R=INPUTS.R0_m+rho*cos(theta);phi=zeta
    E=[cos(theta) -rho*sin(theta) 0.;0. 0. R;sin(theta) rho*cos(theta) 0.]
    invE=inv(E);rot=S._smr_rot(phi);normal=zeros(3);weight=qw*abs(det(E))
    if axis!=0
        dual=invE[axis,:];normal=rot*dual/norm(dual);other=filter(!=(axis),1:3)
        weight=qw*norm(cross(E[:,other[1]],E[:,other[2]]))
    end
    xyz=(R*cos(phi),R*sin(phi),rho*sin(theta));f=analytic_field_v2(xyz)
    (entity_id=entity,qp_id=qp,q=Tuple(q),xyz=xyz,R=R,phi=phi,weight=weight,detE=det(E),
        normal=Tuple(normal),E=E,Einv=invE,B_reference_cyl=f.B_cyl,p_reference=f.p)
end
function quadrature5(data)
    mesh=data.mesh;vol=NamedTuple[];faces=NamedTuple[]
    for (cell,b) in enumerate(mesh.cell_bounds),iz in 1:5,it in 1:5,ir in 1:5
        ix=(ir,it,iz);q=ntuple(a->sum(b[a])/2+GAUSS5_ROOTS[ix[a]]*(b[a][2]-b[a][1])/2,3)
        w=prod(GAUSS5_WEIGHTS[ix[a]]*(b[a][2]-b[a][1])/2 for a in 1:3)
        push!(vol,sample5(cell,(iz-1)*25+(it-1)*5+ir,q,w,0))
    end
    for (fid,f) in enumerate(mesh.faces)
        b=mesh.cell_bounds[f.right_cell==0 ? f.left_cell : f.right_cell];other=filter(!=(f.axis),1:3)
        for j in 1:5,i in 1:5
            q=zeros(3);q[f.axis]=f.fixed;w=1.
            for (a,ix) in zip(other,(i,j))
                q[a]=sum(b[a])/2+GAUSS5_ROOTS[ix]*(b[a][2]-b[a][1])/2
                w*=GAUSS5_WEIGHTS[ix]*(b[a][2]-b[a][1])/2
            end
            push!(faces,sample5(fid,(j-1)*5+i,q,w,f.axis))
        end
    end
    merge(data,(volume=vol,face_quadrature=faces,raw_artifacts=merge(data.raw_artifacts,
        (quadrature_order=5,quadrature_role=:independent_error_and_residual_audit_only))))
end

function field_errors_v2(d,data,x;interpolant=data.initial_state)
    volume=0.;B2=0.;p2=0.;Be2=0.;pe2=0.;Bi2=0.;pi2=0.;Br2=0.;pr2=0.;Bc=0.;pc=0.
    for s in data.volume
        f=S.spatial_field_v4(data,s.entity_id,s,x)
        i=S.spatial_field_v4(data,s.entity_id,s,interpolant);truth=analytic_field_v2(s.xyz)
        eB=f.B_xyz-collect(truth.B);ep=f.p-truth.p
        iB=i.B_xyz-collect(truth.B);ip=i.p-truth.p;rB=f.B_xyz-i.B_xyz;rp=f.p-i.p
        w=s.weight;volume+=w;B2+=w*sum(abs2,truth.B);p2+=w*truth.p^2
        Be2+=w*dot(eB,eB);pe2+=w*ep^2;Bi2+=w*dot(iB,iB);pi2+=w*ip^2
        Br2+=w*dot(rB,rB);pr2+=w*rp^2;Bc+=w*dot(iB,rB);pc+=w*ip*rp
    end
    metrics(b,p)=(B_RMS_T=sqrt(b/volume),p_RMS_Pa=sqrt(p/volume),
        B_relative_L2=sqrt(b/B2),p_relative_L2=sqrt(p/p2),
        B_scaled_RMS=sqrt(b/volume)/d.scaling.B_T,p_scaled_RMS=sqrt(p/volume)/d.scaling.p_Pa)
    (volume_m3=volume,quadrature_order=5,solution_to_continuum=metrics(Be2,pe2),
        interpolation=metrics(Bi2,pi2),recovery_to_interpolant=metrics(Br2,pr2),
        decomposition_squared_error_defect=(B_T2_m3=Be2-(Bi2+Br2+2Bc),p_Pa2_m3=pe2-(pi2+pr2+2pc)),
        recovery_offset_is_algebraic_error=false,
        note="Recovery offset includes discrete solution shift and algebraic error; no certified algebraic bound is inferred.")
end

function analytic_discriminators_v2()
    points=((3.4,0.2,.3),(2.2,-.5,-.1),(0.1,3.7,.2));step=1.e-4
    defects=Float64[]
    for xyz in points
        div=zeros(3)
        for a in 1:3
            xp=collect(xyz);xm=collect(xyz);xp[a]+=step;xm[a]-=step
            fp=analytic_field_v2(xp);fm=analytic_field_v2(xm)
            div.+=(S._smr_stress(collect(fp.B),fp.p)[:,a]-S._smr_stress(collect(fm.B),fm.p)[:,a])/(2step)
        end
        push!(defects,norm(div-collect(source_v2(xyz)))/max(norm(div),1.))
    end
    maximum(defects)<1.e-7 || error("analytic source does not match independent finite-difference div(T)")
    isapprox(flux_v2(),pi;rtol=1.e-15) || error("manufactured toroidal flux mismatch")
    (stress_divergence_relative_defects=Tuple(defects),finite_difference_step_m=step,
        analytic_divB_T_m=0.,analytic_curl_B_z_T_m=2*INPUTS.beta_T_m,
        toroidal_flux_Wb=flux_v2(),normal_magnetic_field_T=0.,
        exterior_normal_current=:nonzero_manufactured_no_return_current_model,
        external_closure_status=:terminal_deferred)
end

function run_preflight_v2(outdir)
    out=abspath(outdir);ispath(out)&&error("refuse to overwrite numerical evidence directory");mkpath(out)
    files=(abspath(@__FILE__),joinpath(REPO,"scripts","runtime_v4_manufactured_recovery_benchmark.jl"),
        joinpath(REPO,"src","RuntimeV4","SpatialMultiRegionV4.jl"),
        joinpath(REPO,"src","RuntimeV4","SpatialExecutionTypesV4.jl"))
    hashes=Tuple((path=p,sha256=sha(p)) for p in files)
    input=(schema=:n1_manufactured_refinement_preflight_v2,inputs=INPUTS,levels=LEVELS,source_hashes=hashes,
        h_definition="max(delta_rho/a,delta_theta/(2pi),delta_zeta/(2pi)); each coordinate spacing halves",
        solver_level=first(LEVELS).level,error_quadrature=5,solver_quadrature=3)
    write(joinpath(out,"input.json"),S.canonical_json(input)*"\n")
    analytic=analytic_discriminators_v2();interpolation=NamedTuple[];firstbundle=nothing;firstdata5=nothing
    for level in LEVELS
        bundle=fixture_v2(level);data5=quadrature5(bundle.data)
        metric=field_errors_v2(bundle.declaration,data5,bundle.data.initial_state)
        push!(interpolation,(level=level.level,h=level.h,unknowns=length(bundle.data.initial_state),
            metrics=metric.interpolation,volume_m3=metric.volume_m3,
            state_hash=S.canonical_hash(Tuple(bundle.data.initial_state))))
        write(joinpath(out,"interpolation_$(level.level).json"),S.canonical_json(last(interpolation))*"\n")
        if level==first(LEVELS);firstbundle=bundle;firstdata5=data5;end
    end
    orders=Tuple((from_level=interpolation[k-1].level,to_level=interpolation[k].level,
        B_order=log(interpolation[k-1].metrics.B_relative_L2/interpolation[k].metrics.B_relative_L2)/log(2.),
        p_order=log(interpolation[k-1].metrics.p_relative_L2/interpolation[k].metrics.p_relative_L2)/log(2.),
        scope=:interpolation_only_not_solver_convergence) for k in 2:length(interpolation))
    d=firstbundle.declaration;data=firstbundle.data;truth=data.initial_state
    d.solver.residual_tolerance==INPUTS.residual_tolerance || error("residual gate changed")
    d.solver.gradient_tolerance==INPUTS.gradient_tolerance || error("gradient gate changed")
    d.solver.rank_relative_tolerance==INPUTS.rank_relative_tolerance || error("rank tolerance changed")
    a3=S.assemble_spatial_system_v4(d,data,truth;flux_Wb=flux_v2(),source_function=source_v2,
        boundary_function=traction_v2,normal_field_function=normal_v2)
    # This is a separate quadrature audit, never used by the production solve.
    d5=S.SpatialMultiRegionDeclarationV4("n1-quadrature-audit-only-v2",d.regions,d.states,d.interfaces,d.source,
        d.boundary,d.spaces,d.flux,d.cases,d.parameters,merge(d.quadrature,(order=5,)),d.scaling,d.solver,d.applicability)
    a5=S.assemble_spatial_system_v4(d5,firstdata5,truth;flux_Wb=flux_v2(),source_function=source_v2,
        boundary_function=traction_v2,normal_field_function=normal_v2)
    quadrature=(interpolant_residual_3pt_scaled_max=maximum(abs,a3.residual./a3.row_scales),
        interpolant_residual_5pt_scaled_max=maximum(abs,a5.residual./a5.row_scales),
        residual_quadrature_difference_scaled_max=maximum(abs,(a3.residual-a5.residual)./a5.row_scales),
        row_count=length(a3.residual),all_blocks_preserved=a3.row_blocks==a5.row_blocks,
        independent_audit_declaration_hash=S.canonical_hash(d5),
        note="Quadrature difference evaluated at the same interpolant; not an algebraic-error bound.")
    write(joinpath(out,"presolve.json"),S.canonical_json((analytic=analytic,interpolation=Tuple(interpolation),
        interpolation_orders=orders,quadrature=quadrature))*"\n")
    initial=truth.+repeat(collect(INPUTS.perturbation),div(length(truth),4))
    solver_input=(declaration=d,mesh_spec=first(LEVELS),analytic_inputs=INPUTS,
        callback_source_sha256=sha(abspath(@__FILE__)),initial_state=Tuple(initial),
        flux_Wb=flux_v2(),scope=:manufactured_numerical_only_not_candidate_package)
    write(joinpath(out,"solver_input.json"),S.canonical_json(solver_input)*"\n")
    sol=S.solve_spatial_state_v4(d,data,initial;flux_Wb=flux_v2(),
        limits=(max_iterations=INPUTS.max_iterations,seconds=INPUTS.solver_seconds),
        source_function=source_v2,boundary_function=traction_v2,normal_field_function=normal_v2)
    a=sol.final_assembly;rs=a.residual./a.row_scales
    primary=(level=first(LEVELS).level,input_hash=S.canonical_hash(solver_input),exit_code=sol.solver_exit_code,
        stopping_reason=sol.stopping_reason,status=sol.status,accepted_update_count=sol.accepted_update_count,
        attempt_count=sol.attempt_count,scaled_residual_max=maximum(abs,rs),blocks=S._smr_block_norms(a),
        state_hash=S.canonical_hash(sol.final_state),rank_diagnostics=sol.rank_diagnostics)
    write(joinpath(out,"solver_primary.json"),S.canonical_json(primary)*"\n")
    open(joinpath(out,"solver_state.csv"),"w") do io
        println(io,"node_id,BR_T,Bphi_T,BZ_T,p_Pa")
        for n in 1:div(length(truth),4);println(io,join((n,sol.final_state[4n-3:4n]...),','));end
    end
    open(joinpath(out,"residual_rows.csv"),"w") do io
        println(io,"row,block,residual,scale")
        for k in eachindex(a.residual);println(io,join((k,a.row_blocks[k],a.residual[k],a.row_scales[k]),','));end
    end
    write(joinpath(out,"iterations.json"),S.canonical_json(sol.iterations)*"\n")
    write(joinpath(out,"attempts.json"),S.canonical_json(sol.attempts)*"\n")
    # Preserve all primary solver evidence before an optional diagnostic can
    # fail.  A post-solve QR/SVD failure is separate from the actual solver exit.
    algebraic=try
        scales=repeat([d.scaling.B_T,d.scaling.B_T,d.scaling.B_T,d.scaling.p_Pa],div(length(truth),4))
        A=spdiagm(0=>1 ./a.row_scales)*a.jacobian*spdiagm(0=>scales)
        singular=svdvals(Matrix(A));correction=qr(A;tol=d.solver.rank_relative_tolerance)\(-rs)
        (execution_state=:completed,scaled_jacobian_sigma_min=minimum(singular),scaled_jacobian_sigma_max=maximum(singular),
            scaled_jacobian_condition=minimum(singular)>0 ? S._smr_finite_metric(maximum(singular)/minimum(singular)) : nothing,
            linearized_correction_scaled_norm=norm(correction),
            linearized_incompatible_residual_norm=norm(A*correction+rs),
            projected_gradient_norm=last(sol.iterations).projected_gradient_norm,
            certified_error_bound=nothing,separation_certified=false,
            note="Local Jacobian/correction diagnostics are not a nonlinear uniqueness or algebraic-error certificate.")
    catch err
        meta=(execution_state=:program_exception,exception_type=string(typeof(err)),
            scaled_jacobian_sigma_min=nothing,scaled_jacobian_sigma_max=nothing,scaled_jacobian_condition=nothing,
            linearized_correction_scaled_norm=nothing,linearized_incompatible_residual_norm=nothing,
            certified_error_bound=nothing,separation_certified=false)
        write(joinpath(out,"algebraic_exception_metadata.json"),S.canonical_json(meta)*"\n")
        meta
    end
    error_metrics=try
        merge(field_errors_v2(d,firstdata5,collect(sol.final_state)),(execution_state=:completed,))
    catch err
        meta=(execution_state=:program_exception,exception_type=string(typeof(err)))
        write(joinpath(out,"error_evaluation_exception_metadata.json"),S.canonical_json(meta)*"\n")
        meta
    end
    program_state=algebraic.execution_state==:completed && error_metrics.execution_state==:completed ? :completed : :program_exception
    output=(schema=:n1_manufactured_refinement_preflight_v2,input_hash=S.canonical_hash(input),
        julia_version=string(VERSION),threads=Threads.nthreads(),source_hashes=hashes,
        analytic=analytic,interpolation=Tuple(interpolation),interpolation_orders=orders,
        quadrature=quadrature,solver=primary,program_state=program_state,
        errors=error_metrics,algebraic=algebraic,
        solved_refinement=(applicable=false,observed_order=nothing,
            reason=:one_solved_endpoint_and_no_certified_algebraic_separation),
        numerical_status=sol.solver_exit_code==0 ? :single_case_residual_pass_refinement_unknown : :numerical_fail,
        physical_status=:unknown,resolution=:terminal_deferred,claim_ceiling=:numerical_only,
        candidate_authority=:none,formal_UP2_04_accepted=false)
    write(joinpath(out,"result.json"),S.canonical_json(output)*"\n")
    all(sha(r.path)==r.sha256 for r in hashes) || error("input source changed during execution")
    println("N1_V2_PREFLIGHT solver_exit=",sol.solver_exit_code," reason=",sol.stopping_reason,
        " residual_max=",maximum(abs,rs)," solved_refinement_applicable=false")
    output
end
end

if abspath(PROGRAM_FILE)==abspath(@__FILE__)
    length(ARGS)==1 || error("usage: julia --startup-file=no --project=. n1_manufactured_refinement_v2.jl NEW_OUTPUT_DIRECTORY")
    result=N1ManufacturedRefinementV2.run_preflight_v2(only(ARGS))
    result.program_state==:completed || exit(2)
end
