# Full spatial Q1 static-MHD state execution on fresh DESC curved geometry.
using FusionConceptAI, LinearAlgebra, SparseArrays, SHA, Printf
import FusionConceptAI: semantic_view, canonical_hash

const _SMR_SOURCE=abspath(@__FILE__)
const _SMR_SAMPLER=normpath(joinpath(@__DIR__,"..","..","scripts","spatial_multiregion_desc_sample.py"))
const _SMR_MU0=1.25663706127e-6
_smr_sha(p)=Digest256(bytes2hex(SHA.sha256(read(p))))
_smr_view(x)=NamedTuple{fieldnames(typeof(x))}(Tuple(getfield(x,k) for k in fieldnames(typeof(x))))
_smr_artifact(p,schema,n)=SpatialArtifactV4(abspath(p),_smr_sha(p),schema,n)
_smr_finite_metric(v)=isfinite(v) ? v : nothing
_smr_rot(phi)=[cos(phi) -sin(phi) 0.;sin(phi) cos(phi) 0.;0. 0. 1.]
_smr_stress(B,p)=(B*transpose(B)-dot(B,B)*Matrix{Float64}(I,3,3)/2)/_SMR_MU0-p*Matrix{Float64}(I,3,3)

struct SpatialMultiRegionDeclarationV4
    revision::String; regions::Tuple; states::Tuple; interfaces::Tuple; source::NamedTuple
    boundary::NamedTuple; spaces::Tuple; flux::NamedTuple; cases::Tuple; parameters::Tuple
    quadrature::NamedTuple; scaling::NamedTuple; solver::NamedTuple; applicability::Tuple
end
semantic_view(x::SpatialMultiRegionDeclarationV4)=_smr_view(x)

function spatial_multiregion_declaration_v4(;flux_Wb)
    f=Float64(flux_Wb);isfinite(f)&&f>0 || throw(ArgumentError("positive inherited toroidal flux required"))
    source="Exploratory spatial static-MHD design/numerical assumption; not measured data"
    SpatialMultiRegionDeclarationV4("spatial-q1-static-mhd-v1",
      ((id="plasma_core",rho=(0.,.5),material=:static_ideal_mhd,owner=:G2),
       (id="plasma_edge",rho=(.5,1.),material=:static_ideal_mhd,owner=:G2)),
      ((id=:B_R,unit="T",initial_source=:fresh_DESC_nodes,applicability=:full_torus_Q1),
       (id=:B_phi,unit="T",initial_source=:fresh_DESC_nodes,applicability=:full_torus_Q1),
       (id=:B_Z,unit="T",initial_source=:fresh_DESC_nodes,applicability=:full_torus_Q1),
       (id=:p,unit="Pa",initial_source=:fresh_DESC_nodes,applicability=:full_torus_Q1_nonnegative)),
      ((rho=.5,law=:continuous_same_material_trace,current_sheet=:none,ownership=:shared_nodes),),
      (equation="div(T)=source",value_xyz_N_m3=(0.,0.,0.),source=source),
      (rho=1.,traction=:fresh_DESC_reference,normal_B_T=0.,axis=:merged_trial_and_test_nodes,
       angular=:full_torus_periodic_independent_field_periods,source=source),
      ((level=:coarse,rho=(0.,.5,1.),theta_count=4,zeta_per_period=2),
       (level=:fine,rho=(0.,.25,.5,.75,1.),theta_count=8,zeta_per_period=4)),
      (nominal_Wb=f,interval_Wb=(.95*f,1.05*f),unit="Wb",source="Inherited candidate toroidal flux; endpoints are exploratory +/-5% design interval",cut=:zeta_zero),
      ((case_id="nominal_coarse",level=:coarse,flux_Wb=f),(case_id="nominal_fine",level=:fine,flux_Wb=f),
       (case_id="flux_low_coarse",level=:coarse,flux_Wb=.95*f),(case_id="flux_high_coarse",level=:coarse,flux_Wb=1.05*f)),
      ((name=:mu0,value=_SMR_MU0,unit="N A^-2",interval=(_SMR_MU0,_SMR_MU0),
        source="NIST CODATA 2022 nominal https://physics.nist.gov/cuu/pdf/all.pdf",applicability="Fixed classical Maxwell nominal; not exact uncertainty assertion"),
       (name=:state_B_scale,value=5.,unit="T",interval=(5.,5.),source=source,applicability="Numerical column/row scale only, not observed B"),
       (name=:state_p_scale,value=1.e5,unit="Pa",interval=(1.e5,1.e5),source=source,applicability="Numerical pressure column/stress row scale only"),
       (name=:reference_length,value=1.,unit="m",interval=(1.,1.),source=source,applicability="Numerical reference; row areas use actual metric")),
      (rule=:tensor_gauss_legendre,order=3,exact_faces=true),
      (B_T=5.,p_Pa=1.e5,length_m=1.,row_rule=:physical_cell_area_or_face_area,source=source),
      (method=:feasible_sparse_QR_gauss_newton,coarse_iterations=12,fine_iterations=4,
       coarse_seconds=600.,fine_seconds=900.,residual_tolerance=1.e-6,gradient_tolerance=1.e-10,
       rank_relative_tolerance=1.e-10,line_search_steps=20,pressure_lower_Pa=0.,source=source),
      (:fixed_geometry,:static_no_flow,:pressure_iota_initialization_only,:no_hidden_profile_anchor,
       :possible_pressure_current_topology_nonuniqueness,:continuous_plasma_interface_only,
       :external_currents_and_outer_sheet_unknown,:physical_validation_unsupported))
end

struct SpatialMeshV4
    level::Symbol; nfp::Int; nodes_q::Matrix{Float64}; cell_nodes::Vector{Vector{Int}}
    corner_to_local::Vector{Vector{Int}}; cell_bounds::Vector{NTuple{3,Tuple{Float64,Float64}}}
    cell_regions::Vector{Int}; faces::Vector{NamedTuple}; cell_row_start::Vector{Int}
    exterior_row_start::Dict{Int,Int}; row_blocks::Vector{Symbol}; row_supports::Vector{Vector{Int}}
end

function build_spatial_mesh_v4(d::SpatialMultiRegionDeclarationV4,level::Symbol,nfp::Int)
    s=only(filter(s->s.level==level,d.spaces));rhos=collect(s.rho);nt=s.theta_count;nz=s.zeta_per_period*nfp;nr=length(rhos)-1
    nodes=NTuple{3,Float64}[];nd=Dict{Tuple{Int,Int,Int},Int}()
    for iz in 0:nz-1,ir in 0:nr,it in 0:(ir==0 ? 0 : nt-1)
        push!(nodes,(rhos[ir+1],it*2pi/nt,iz*2pi/nz));nd[(ir,it,iz)]=length(nodes)
    end
    cells=Vector{Int}[];maps=Vector{Int}[];bounds=NTuple{3,Tuple{Float64,Float64}}[];regions=Int[];cid=Dict{Tuple{Int,Int,Int},Int}()
    for iz in 0:nz-1,ir in 0:nr-1,it in 0:nt-1
        ids=Int[];cm=Int[]
        for k in 0:7
            br=k%2;bt=div(k,2)%2;bz=div(k,4);rr=ir+br
            id=nd[(rr,rr==0 ? 0 : mod(it+bt,nt),mod(iz+bz,nz))]
            pos=findfirst(==(id),ids);if pos===nothing;push!(ids,id);pos=length(ids);end
            push!(cm,pos)
        end
        push!(cells,ids);push!(maps,cm);push!(bounds,((rhos[ir+1],rhos[ir+2]),(it*2pi/nt,(it+1)*2pi/nt),(iz*2pi/nz,(iz+1)*2pi/nz)))
        push!(regions,rhos[ir+2]<=.5 ? 1 : 2);cid[(ir,it,iz)]=length(cells)
    end
    faces=NamedTuple[]
    for iz in 0:nz-1,ir in 1:nr,it in 0:nt-1
        l=cid[(ir-1,it,iz)];r=ir<nr ? cid[(ir,it,iz)] : 0
        role=r==0 ? :exterior : (regions[l]!=regions[r] ? :interface : :interior)
        push!(faces,(axis=1,left_cell=l,right_cell=r,role=role,fixed=rhos[ir+1]))
    end
    for iz in 0:nz-1,ir in 0:nr-1,it in 0:nt-1
        push!(faces,(axis=2,left_cell=cid[(ir,mod(it-1,nt),iz)],right_cell=cid[(ir,it,iz)],role=:interior,fixed=it*2pi/nt))
    end
    for iz in 0:nz-1,ir in 0:nr-1,it in 0:nt-1
        push!(faces,(axis=3,left_cell=cid[(ir,it,mod(iz-1,nz))],right_cell=cid[(ir,it,iz)],role=:interior,fixed=iz*2pi/nz))
    end
    starts=Int[];blocks=Symbol[];supports=Vector{Int}[];ext=Dict{Int,Int}()
    dofs(ids)=[4*(n-1)+c for n in ids for c in 1:4]
    for ids in cells
        push!(starts,length(blocks)+1)
        for a in ids,k in 1:4;push!(blocks,k==4 ? :divB_Wb : :momentum_N);push!(supports,dofs(ids));end
    end
    for (fid,f) in enumerate(faces)
        f.role==:exterior || continue
        ext[fid]=length(blocks)+1
        ids=filter(n->nodes[n][1]==1.,cells[f.left_cell]);length(ids)==4 || error("outer Q1 basis mismatch")
        for a in ids,k in 1:4;push!(blocks,k==4 ? :normal_B_Wb : :traction_N);push!(supports,dofs(ids));end
    end
    cutnodes=findall(q->q[3]==0.,nodes)
    push!(blocks,:total_flux_Wb);push!(supports,[4*(n-1)+c for n in cutnodes for c in 1:3])
    mesh=SpatialMeshV4(level,nfp,reduce(hcat,collect.(nodes)),cells,maps,bounds,regions,faces,starts,ext,blocks,supports)
    if nfp==5
        (size(mesh.nodes_q,2)*4,length(blocks))==(level==:coarse ? (360,2881) : (2640,21761)) || error("spatial ownership count mismatch")
    end
    mesh
end

function spatial_basis_v4(mesh::SpatialMeshV4,cell::Int,q)
    bounds=mesh.cell_bounds[cell];h=[b[2]-b[1] for b in bounds];u=collect(q).-first.(bounds)
    for a in 2:3;u[a]<-1e-10 && (u[a]+=2pi);end
    u./=h;all(t->-1e-8<=t<=1+1e-8,u) || throw(ArgumentError("quadrature outside local cell"))
    for a in 1:3
        abs(u[a])<1e-12 && (u[a]=0.);abs(u[a]-1)<1e-12 && (u[a]=1.)
    end
    ids=mesh.cell_nodes[cell];N=zeros(length(ids));D=zeros(3,length(ids))
    for k in 0:7
        bits=(k%2,div(k,2)%2,div(k,4));v=[bits[a]==0 ? 1-u[a] : u[a] for a in 1:3];j=mesh.corner_to_local[cell][k+1]
        N[j]+=prod(v)
        for a in 1:3;D[a,j]+=(bits[a]==0 ? -1. : 1.)/h[a]*prod(v[b] for b in 1:3 if b!=a);end
    end
    (ids=ids,N=N,dN_dq=D)
end

function _smr_block_norms(a)
    names=(:momentum_N,:divB_Wb,:traction_N,:normal_B_Wb,:total_flux_Wb)
    NamedTuple{names}(Tuple(norm(a.residual[findall(==(k),a.row_blocks)]) for k in names))
end

function _smr_rank_audit(A,F,tolerance)
    R=F.R;di=abs.(diag(R));threshold=tolerance*max(maximum(di;init=0.),1.)
    rk=count(>(threshold),di);m,n=size(A);modes=NamedTuple[]
    # QR rank is a numerical estimate at the declared scaled threshold. A
    # reported null direction must independently satisfy the unregularized J.
    if rk<n && rk>0 && all(di[1:rk].>threshold)
        perm=Vector{Int}(F.pcol);isempty(perm)&&(perm=collect(1:n))
        for j in rk+1:min(n,rk+3)
            v=zeros(n);v[j]=1.;v[1:rk].=-(UpperTriangular(R[1:rk,1:rk])\Vector(R[1:rk,j]));u=zeros(n);u[perm]=v;u./=norm(u)
            push!(modes,(vector=Tuple(u),normalized_Jv=norm(A*u)/max(norm(A),eps())))
        end
    end
    (method=:unregularized_sparse_QR_diagonal_rank_estimate,rows=m,columns=n,rank_estimate=rk,
     relative_tolerance=tolerance,absolute_threshold=threshold,diagonal_min=minimum(di;init=Inf),
     diagonal_max=maximum(di;init=0.),nullity_estimate=n-rk,null_modes=Tuple(modes),
     continuum_uniqueness=:unsupported,physical_closure=:pressure_current_topology_not_fixed)
end

# Floating-point tolerances are expressed in scaled coordinates z=x./cols;
# they describe representability only and are not physical pressure tolerances.
_smr_scaled_bound_tolerance(z)=8eps(Float64).*max.(1.0,abs.(z))
_smr_pressure_bound_tolerance(p,scale)=8eps(Float64)*max(1.0,abs(p/scale))*scale
_smr_pressure_feasible(p,scale)=isfinite(p) && p >= -_smr_pressure_bound_tolerance(p,scale)
function _smr_scaled_state_change(x,y,cols)
    all(isfinite,y) || return false
    zx=x./cols;zy=y./cols
    any(abs.(zy.-zx) .> 8eps(Float64).*max.(1.0,max.(abs.(zx),abs.(zy))))
end

function solve_spatial_state_v4(d,data,initial;flux_Wb=d.flux.nominal_Wb,limits=nothing,
        _test_qr_factorization=nothing,_test_line_search_acceptance=nothing,
        source_function=nothing,boundary_function=nothing,normal_field_function=nothing)
    d.flux.interval_Wb[1]<=flux_Wb<=d.flux.interval_Wb[2] || throw(ArgumentError("undeclared flux realization"))
    x=Float64.(initial);nd=length(x);cols=repeat([d.scaling.B_T,d.scaling.B_T,d.scaling.B_T,d.scaling.p_Pa],div(nd,4))
    maxit=data.mesh.level==:coarse ? d.solver.coarse_iterations : d.solver.fine_iterations
    seconds=data.mesh.level==:coarse ? d.solver.coarse_seconds : d.solver.fine_seconds
    if limits!==nothing;maxit=limits.max_iterations;seconds=limits.seconds;end
    history=NamedTuple[];states=Vector{Float64}[];attempts=NamedTuple[];accepted_count=0
    code=4;reason=:iteration_limit;last_linear=0.;last_step=0.;start=time()
    rankaudit=(method=:not_executed,rank_estimate=-1,columns=nd,nullity_estimate=-1,null_modes=(),continuum_uniqueness=:unsupported)
    for iteration in 0:maxit
        # Canonicalize only representationally negative pressure; materially
        # infeasible states remain failures and are never passed to residuals.
        for i in 4:4:nd
            _smr_pressure_feasible(x[i],cols[i]) && x[i]<0.0 && (x[i]=0.0)
        end
        a=assemble_spatial_system_v4(d,data,x;flux_Wb,source_function,boundary_function,normal_field_function);rs=a.residual./a.row_scales
        A=spdiagm(0=>1 ./a.row_scales)*a.jacobian*spdiagm(0=>cols);g=transpose(A)*rs
        z=x./cols
        bound_tol=_smr_scaled_bound_tolerance(z)
        active=[i for i in 4:4:nd if z[i] <= bound_tol[i] && g[i] > 0.0];free=setdiff(collect(1:nd),active)
        pg=copy(g);pg[active].=0.
        push!(history,(iteration=iteration,scaled_norm=norm(rs),scaled_max=maximum(abs,rs),blocks=_smr_block_norms(a),
                       projected_gradient_norm=norm(pg),step_norm=last_step,linear_relative_residual=last_linear,linear_solve_executed=iteration>0,
                       elapsed_seconds=time()-start));push!(states,copy(x))
        if !all(isfinite,rs)||any(i->_smr_pressure_feasible(x[i],cols[i])==false,4:4:nd);code=6;reason=:nonfinite_or_infeasible_state;break;end
        if maximum(abs,rs)<=d.solver.residual_tolerance;code=0;reason=:all_scaled_residuals_converged;break;end
        if norm(pg)<=d.solver.gradient_tolerance;code=2;reason=:stationary_nonzero_residual;break;end
        if iteration==maxit;code=4;reason=:iteration_limit;break;end
        if time()-start>=seconds;code=4;reason=:wall_time_budget;break;end
        step=zeros(nd);linear_phase=:factorization
        before_hash=canonical_hash(Tuple(x));attempt_index=length(attempts)+1
        try
            F=_test_qr_factorization===nothing ? qr(A[:,free];tol=d.solver.rank_relative_tolerance) :
                _test_qr_factorization(A[:,free],d.solver.rank_relative_tolerance)
            linear_phase=:back_substitution
            step[free]=F\(-rs)
            linear_phase=:rank_diagnostic
            rankaudit=_smr_rank_audit(A[:,free],F,d.solver.rank_relative_tolerance)
        catch err
            code=5;reason=:sparse_QR_failure
            rankaudit=(method=:sparse_QR_failed,error=sprint(showerror,err),rank_estimate=-1,columns=nd,nullity_estimate=-1,null_modes=(),continuum_uniqueness=:unsupported)
            step_available=linear_phase==:rank_diagnostic && all(isfinite,step)
            computed_linear=step_available ? _smr_finite_metric(norm(A*step+rs)/max(norm(rs),eps())) : nothing
            push!(attempts,(attempt_index=attempt_index,iteration=iteration,state_before_hash=before_hash,
                linear_executed=true,linear_exit_code=1,linear_error_stage=linear_phase,linear_error=sprint(showerror,err),linear_solution_finite=step_available,
                linear_relative_residual=computed_linear,searched_direction_relative_residual=nothing,linear_rank_diagnostics=rankaudit,free_columns=Tuple(free),
                direction=step_available ? :sparse_QR_gauss_newton : :unavailable,proposed_scaled_step=step_available ? Tuple(step) : (),
                proposed_step_norm=step_available ? _smr_finite_metric(norm(step)) : nothing,nonfinite_step_columns=Tuple(findall(v->!isfinite(v),step)),line_search_trial_count=0,
                line_search_evaluation_count=0,trials=(),accepted=false,accepted_alpha=nothing,
                state_after_hash=before_hash,elapsed_seconds=time()-start))
            break
        end
        function feasible_alpha(v)
            alpha=1.
            for i in 4:4:nd;v[i]<0&&(alpha=min(alpha,-x[i]/(cols[i]*v[i])));end
            max(alpha,0.)
        end
        function representable_trial(v,alpha_try)
            trial=x.+alpha_try.*cols.*v
            _smr_scaled_state_change(x,trial,cols) && all(isfinite,trial)
        end
        qr_step_finite=all(isfinite,step);qr_linear_residual=_smr_finite_metric(norm(A*step+rs)/max(norm(rs),eps()))
        alpha=feasible_alpha(step);direction=:sparse_QR_gauss_newton
        if !all(isfinite,step) || dot(g,step) >= 0.0 || alpha == 0.0 || !representable_trial(step,alpha)
            # A projected descent direction is an actual feasible fallback,
            # not clipping an infeasible Newton step into an unchanged state.
            step=-pg/max(norm(pg),1.);alpha=feasible_alpha(step);direction=:projected_gradient_fallback
        end
        last_linear=norm(A*step+rs)/max(norm(rs),eps());accepted=false;accepted_alpha=nothing
        trials=NamedTuple[];evaluation_count=0;phi_before=dot(rs,rs);accepted_phi=phi_before;accepted_scaled_change=false
        feasible_trial_seen=false;representable_trial_seen=false;strict_decrease_seen=false
        for ls in 0:d.solver.line_search_steps
            alpha_try=alpha*2.0^(-ls);trial=x.+alpha_try.*cols.*step
            for i in 4:4:nd;_smr_pressure_feasible(trial[i],cols[i]) && trial[i]<0. && (trial[i]=0.);end
            feasible=all(i->_smr_pressure_feasible(trial[i],cols[i]),4:4:nd)
            changed=trial!=x;scaled_change=_smr_scaled_state_change(x,trial,cols)
            feasible_trial_seen |= feasible
            representable_trial_seen |= feasible && scaled_change
            if !feasible||!changed||!scaled_change
                push!(trials,(trial_index=ls,alpha=alpha_try,evaluated=false,feasible=feasible,changed_state=changed,
                    scaled_state_change=scaled_change,finite_residual=nothing,scaled_norm=nothing,scaled_max=nothing,
                    objective_before=phi_before,objective_after=nothing,objective_decrease=nothing,armijo_accepted=false,
                    strict_objective_decrease=false,accepted=false))
                continue
            end
            ar=assemble_spatial_system_v4(d,data,trial;flux_Wb,jacobian=false,source_function,boundary_function,normal_field_function);rr=ar.residual./ar.row_scales
            evaluation_count+=1;finite=all(isfinite,rr)
            phi_after=finite ? dot(rr,rr) : Inf
            strict_decrease=finite && phi_after < phi_before
            strict_decrease_seen |= strict_decrease
            armijo_accepted=finite&&phi_after<=phi_before+2e-4*alpha_try*dot(g,step)
            # These hooks exist only to exercise otherwise nondeterministic
            # failure bookkeeping. Production callers leave both as `nothing`.
            trial_accepted=_test_line_search_acceptance===nothing ? armijo_accepted :
                Bool(_test_line_search_acceptance((iteration=iteration,trial_index=ls,alpha=alpha_try,
                    finite=finite,armijo_accepted=armijo_accepted,scaled_norm=finite ? norm(rr) : nothing)))
            trial_accepted=trial_accepted && strict_decrease
            push!(trials,(trial_index=ls,alpha=alpha_try,evaluated=true,feasible=true,changed_state=true,
                scaled_state_change=true,finite_residual=finite,scaled_norm=finite ? norm(rr) : nothing,
                scaled_max=finite ? maximum(abs,rr) : nothing,objective_before=phi_before,objective_after=finite ? phi_after : nothing,
                objective_decrease=finite ? phi_before-phi_after : nothing,armijo_accepted=armijo_accepted,
                strict_objective_decrease=strict_decrease,accepted=trial_accepted))
            if trial_accepted
                last_step=norm((trial.-x)./cols);accepted_scaled_change=scaled_change;accepted_phi=phi_after
                x=trial;accepted=true;accepted_alpha=alpha_try;accepted_count+=1;break
            end
        end
        no_progress=!accepted && feasible_trial_seen && (!representable_trial_seen || !strict_decrease_seen)
        push!(attempts,(attempt_index=attempt_index,iteration=iteration,state_before_hash=before_hash,
            linear_executed=true,linear_exit_code=0,linear_error_stage=nothing,linear_error=nothing,linear_solution_finite=qr_step_finite,
            linear_relative_residual=qr_linear_residual,searched_direction_relative_residual=_smr_finite_metric(last_linear),linear_rank_diagnostics=rankaudit,free_columns=Tuple(free),
            direction=direction,proposed_scaled_step=Tuple(_smr_finite_metric(v) for v in step),proposed_step_norm=_smr_finite_metric(norm(step)),
            nonfinite_step_columns=Tuple(findall(v->!isfinite(v),step)),
            line_search_trial_count=length(trials),line_search_evaluation_count=evaluation_count,trials=Tuple(trials),
            accepted=accepted,accepted_alpha=accepted_alpha,objective_before=phi_before,
            objective_after=accepted_phi,objective_decrease=phi_before-accepted_phi,
            strict_objective_decrease=accepted && accepted_phi<phi_before,scaled_state_change=accepted_scaled_change,
            bound_active_indices=Tuple(active),bound_tolerance=maximum(bound_tol),progress_classification=accepted ? :accepted_strict_decrease :
                (no_progress ? :floating_point_no_progress : :line_search_rejected),state_after_hash=canonical_hash(Tuple(x)),elapsed_seconds=time()-start))
        if !accepted;code=3;reason=no_progress ? :floating_point_no_progress : :feasible_line_search_failed;break;end
    end
    final=assemble_spatial_system_v4(d,data,x;flux_Wb,source_function,boundary_function,normal_field_function)
    Afinal=spdiagm(0=>1 ./final.row_scales)*final.jacobian*spdiagm(0=>cols)
    final_rank_audit=try
        _smr_rank_audit(Afinal,qr(Afinal;tol=d.solver.rank_relative_tolerance),d.solver.rank_relative_tolerance)
    catch err
        (method=:final_sparse_QR_failed,error=sprint(showerror,err),rank_estimate=-1,columns=nd,nullity_estimate=-1,null_modes=(),continuum_uniqueness=:unsupported)
    end
    (initial_state=Tuple(initial),final_state=Tuple(x),iterations=Tuple(history),state_history=states,
     solver_exit_code=code,stopping_reason=reason,status=code==0 ? :converged : :fail,
     final_assembly=final,rank_diagnostics=final_rank_audit,attempt_count=length(attempts),accepted_update_count=accepted_count,
     attempts=Tuple(attempts),last_attempt=isempty(attempts) ? (executed=false,reason=reason) : last(attempts),elapsed_seconds=time()-start)
end

function _smr_current_texts(data,x)
    volumes=IOBuffer();interfaces=IOBuffer();exterior=IOBuffer()
    println(volumes,SPATIAL_VOLUME_HEADER_V4);println(interfaces,SPATIAL_INTERFACE_HEADER_V4);println(exterior,SPATIAL_EXTERIOR_HEADER_V4)
    mesh=data.mesh;nv=0;ni=0;ne=0;volume=zeros(2);force2=zeros(2);div2=zeros(2);forcepeak=zeros(2)
    cell_force=zeros(3,length(mesh.cell_nodes));cell_surface=zeros(size(cell_force));cell_current=zeros(length(mesh.cell_nodes))
    interfacejump=0.;outerpeak=0.;outernet=0.;interfaceBjump=0.;interfaceTjump=0.;outerTjump=0.;outerBn=0.
    for s in data.volume
        c=s.entity_id;r=mesh.cell_regions[c];f=spatial_field_v4(data,c,s,x);force=cross(f.J_xyz,f.B_xyz)-f.gradp_xyz
        divT=force+f.B_xyz.*(f.divB/_SMR_MU0);cell_force[:,c].+=s.weight.*divT
        volume[r]+=s.weight;force2[r]+=s.weight*dot(force,force);div2[r]+=s.weight*f.divB^2;forcepeak[r]=max(forcepeak[r],norm(force))
        println(volumes,join((c,r,s.xyz...,s.weight,f.B_xyz...,f.J_xyz...,f.p,f.gradp_xyz...,f.divB),','));nv+=1
    end
    for s in data.face_quadrature
        face=mesh.faces[s.entity_id];n=collect(s.normal);l=spatial_field_v4(data,face.left_cell,s,x)
        for (c,sign) in ((face.left_cell,1.),(face.right_cell,-1.))
            c==0&&continue;f=c==face.left_cell ? l : spatial_field_v4(data,c,s,x)
            cell_surface[:,c].+=sign*s.weight.*(f.T_xyz*n);cell_current[c]+=sign*s.weight*dot(f.J_xyz,n)
        end
        if face.role==:interface
            r=spatial_field_v4(data,face.right_cell,s,x);K=cross(n,r.B_xyz-l.B_xyz)/_SMR_MU0
            jminus=dot(l.J_xyz,n);jplus=dot(r.J_xyz,n)
            interfacejump=max(interfacejump,abs(jplus-jminus));interfaceBjump=max(interfaceBjump,norm(r.B_xyz-l.B_xyz))
            interfaceTjump=max(interfaceTjump,norm((r.T_xyz-l.T_xyz)*n))
            println(interfaces,join((s.entity_id,mesh.cell_regions[face.left_cell],mesh.cell_regions[face.right_cell],s.xyz...,s.weight,n...,
                                     l.B_xyz...,r.B_xyz...,K...,jminus,jplus),','));ni+=1
        elseif face.role==:exterior
            jn=dot(l.J_xyz,n);outerpeak=max(outerpeak,abs(jn));outernet+=s.weight*jn;outerBn=max(outerBn,abs(dot(l.B_xyz,n)))
            tref=_smr_stress(l.rotation*collect(s.B_reference_cyl),s.p_reference)*n;outerTjump=max(outerTjump,norm(l.T_xyz*n-tref))
            println(exterior,join((s.entity_id,s.xyz...,s.weight,n...,l.B_xyz...,l.J_xyz...,l.p),','));ne+=1
        end
    end
    defect=cell_surface-cell_force
    enclosure=hasproperty(data,:continuous_enclosure) ? data.continuous_enclosure : (supported=false,source=:manufactured_test_only)
    closure=(cell_current_flux_peak_A=maximum(abs,cell_current),cell_current_flux_abs_sum_A=sum(abs,cell_current),
             interface_normal_current_jump_peak_A_m2=interfacejump,outer_normal_current_peak_A_m2=outerpeak,outer_net_current_A=outernet,
             outer_Bout=:unknown,outer_K=:unknown,external_current_closure=:unsupported,provider_geometry_enclosure=enclosure)
    diagnostics=(region_volume_m3=Tuple(volume),strong_force_rms_N_m3=Tuple(sqrt.(force2./volume)),strong_force_peak_N_m3=Tuple(forcepeak),
                 divB_rms_T_m=Tuple(sqrt.(div2./volume)),interface_B_jump_peak_T=interfaceBjump,interface_traction_jump_peak_Pa=interfaceTjump,
                 outer_traction_mismatch_peak_Pa=outerTjump,outer_Bn_peak_T=outerBn,
                 cell_divergence_theorem_defect_peak_N=maximum(norm(view(defect,:,i)) for i in axes(defect,2)),
                 global_divergence_theorem_defect_N=Tuple(vec(sum(defect;dims=2))),
                 strong_weak_identity="divT = J cross B - gradp + B divB/mu0",conservation_certified=false,
                 current_closure=closure,physical_validation=:unsupported)
    (volume=String(take!(volumes)),interfaces=String(take!(interfaces)),exterior=String(take!(exterior)),
     counts=(volume=nv,interfaces=ni,exterior=ne),diagnostics=diagnostics,current_closure=closure)
end

struct SpatialMultiRegionCaseV4
    candidate_hash::Digest256;context_hash::Digest256;case_id::String;level::Symbol;nfp::Int;flux_Wb::Float64
    initial_state::Tuple;final_state::Tuple;state_hash::Digest256;executed::Bool;status::Symbol;solver_exit_code::Int
    stopping_reason::Symbol;iterations::Tuple;raw_artifacts::NamedTuple;engineering_input::SpatialCurrentInputV4
    artifacts::NamedTuple;diagnostics::NamedTuple;result_hash::Digest256
end
semantic_view(x::SpatialMultiRegionCaseV4)=NamedTuple{fieldnames(typeof(x))[1:end-1]}(Tuple(getfield(x,k) for k in fieldnames(typeof(x))[1:end-1]))
struct SpatialMultiRegionResultV4
    candidate_hash::Digest256;context_hash::Digest256;declaration::SpatialMultiRegionDeclarationV4;cases::Tuple
    primary_case_id::String;executed::Bool;status::Symbol;solver_exit_code::Int;execution::NamedTuple
    physical_validation::Symbol;claim_ceiling::typeof(screen_only);result_hash::Digest256
end
semantic_view(x::SpatialMultiRegionResultV4)=NamedTuple{fieldnames(typeof(x))[1:end-1]}(Tuple(getfield(x,k) for k in fieldnames(typeof(x))[1:end-1]))
function canonical_hash(x::Union{SpatialMultiRegionCaseV4,SpatialMultiRegionResultV4})
    canonical_hash(semantic_view(x))==x.result_hash||throw(ArgumentError("spatial result hash mismatch"));x.result_hash
end

function _smr_declaration(context)
    validate_spatial_candidate_v4(context)
    d=only(filter(x->x isa SpatialMultiRegionDeclarationV4,context.candidate.field_geometry_genome_ref.fields))
    canonical_hash(d)==canonical_hash(spatial_multiregion_declaration_v4(flux_Wb=d.flux.nominal_Wb)) || throw(ArgumentError("spatial declaration not implemented"))
    d
end

function _smr_upstream(context,upstream)
    validate_desc_geometry_compatibility(context,upstream.bridge,upstream.geometry,upstream.proof)
    for o in (upstream.request,upstream.result,upstream.proof);canonical_hash(o);end
    upstream.request.candidate_hash==context.candidate_hash==upstream.result.candidate_hash&&
        upstream.request.context_hash==context.context_hash==upstream.result.context_hash&&
        upstream.result.request_hash==canonical_hash(upstream.request)||error("foreign spatial initializer")
    receipt=upstream.result.receipt;receipt===nothing&&error("real DESC receipt required")
    validate_desc_provider_receipt(receipt)
    upstream.request.compatibility_certificate_hash==canonical_hash(upstream.proof.certificate)==upstream.result.compatibility_certificate_hash || error("foreign geometry certificate")
    upstream.result.provider_executed&&upstream.result.result_schema_validated || error("DESC not executed")
    read(receipt.input_path,String)==_dgrpe_line_payload(upstream.request.runner_payload)&&
        read(receipt.adapter_path,String)==_DGRPE_ADAPTER_SOURCE&&read(receipt.inspector_path,String)==_DGRPE_INSPECTOR_SOURCE || error("upstream input/source mismatch")
    receipt
end

function _smr_write_case(context,d,data,case,dir)
    mkpath(dir);sol=solve_spatial_state_v4(d,data,data.initial_state;flux_Wb=case.flux_Wb)
    statehash=canonical_hash((candidate_hash=context.candidate_hash,context_hash=context.context_hash,case_id=case.case_id,level=case.level,flux_Wb=case.flux_Wb,state=sol.final_state))
    texts=_smr_current_texts(data,sol.final_state)
    current=Dict{Symbol,SpatialArtifactV4}()
    for name in (:volume,:interfaces,:exterior)
        path=joinpath(dir,"current_$(name).csv");write(path,getproperty(texts,name));current[name]=_smr_artifact(path,"spatial_current_$(name)_v1",getproperty(texts.counts,name))
    end
    statepath=joinpath(dir,"state_history.csv")
    open(statepath,"w") do io
        println(io,"iteration,node_id,BR_T,Bphi_T,BZ_T,p_Pa")
        for (it,x) in enumerate(sol.state_history),node in 1:div(length(x),4);println(io,join((it-1,node,x[4node-3:4node]...),','));end
    end
    rowpath=joinpath(dir,"residual_rows.csv");a=sol.final_assembly
    open(rowpath,"w") do io
        println(io,"row,block,residual,declared_scale")
        for i in eachindex(a.residual);println(io,join((i,a.row_blocks[i],a.residual[i],a.row_scales[i]),','));end
    end
    jacpath=joinpath(dir,"full_jacobian.csv")
    open(jacpath,"w") do io
        println(io,"row,column,value")
        rr,cc,vv=findnz(a.jacobian)
        for i in eachindex(vv);println(io,join((rr[i],cc[i],vv[i]),','));end
    end
    ownershippath=joinpath(dir,"row_supports.csv")
    open(ownershippath,"w") do io
        println(io,"row,block,columns_semicolon")
        for i in eachindex(a.row_blocks);println(io,"$(i),$(a.row_blocks[i]),$(join(a.row_supports[i],';'))");end
    end
    iterpath=joinpath(dir,"iterations.csv")
    open(iterpath,"w") do io
        println(io,"iteration,scaled_norm,scaled_max,momentum_N,divB_Wb,traction_N,normal_B_Wb,total_flux_Wb,projected_gradient_norm,step_norm,linear_relative_residual,elapsed_seconds")
        for h in sol.iterations;println(io,join((h.iteration,h.scaled_norm,h.scaled_max,values(h.blocks)...,h.projected_gradient_norm,h.step_norm,h.linear_relative_residual,h.elapsed_seconds),','));end
    end
    attemptpath=joinpath(dir,"solver_attempts.json")
    attempt_record=(attempt_count=sol.attempt_count,accepted_update_count=sol.accepted_update_count,last_attempt=sol.last_attempt,attempts=sol.attempts)
    write(attemptpath,canonical_json(attempt_record)*"\n")
    exitpath=joinpath(dir,"solver.exitcode");write(exitpath,"$(sol.solver_exit_code)\n")
    geometryhash=canonical_hash(data.raw_artifacts)
    eng=SpatialCurrentInputV4(context.candidate_hash,context.context_hash,case.case_id,statehash,geometryhash,
        current[:volume],current[:interfaces],current[:exterior],texts.current_closure,sol.status,sol.solver_exit_code,false,
        "Actual current curl(B) and trace-derived internal sheet; plasma-current contribution only; external closure unknown")
    artifacts=(state_history=_smr_artifact(statepath,"spatial_state_history_v1",length(sol.state_history)*div(length(sol.final_state),4)),
        residual_rows=_smr_artifact(rowpath,"spatial_residual_rows_v1",length(a.residual)),
        jacobian=_smr_artifact(jacpath,"spatial_full_jacobian_v1",nnz(a.jacobian)),
        row_supports=_smr_artifact(ownershippath,"spatial_row_supports_v1",length(a.row_blocks)),
        attempts=_smr_artifact(attemptpath,"spatial_solver_attempts_v1",sol.attempt_count),
        iterations=_smr_artifact(iterpath,"spatial_iterations_v1",length(sol.iterations)),solver_exit=_smr_artifact(exitpath,"integer_exitcode",1))
    diag=merge(texts.diagnostics,(blocks=_smr_block_norms(a),scaled_norm=norm(a.residual./a.row_scales),
        scaled_max=maximum(abs,a.residual./a.row_scales),jacobian_rows=size(a.jacobian,1),jacobian_columns=size(a.jacobian,2),
        jacobian_nnz=nnz(a.jacobian),rank_diagnostics=sol.rank_diagnostics,elapsed_seconds=sol.elapsed_seconds,
        attempt_count=sol.attempt_count,accepted_update_count=sol.accepted_update_count,last_attempt=sol.last_attempt,attempts=sol.attempts,
        missing_closure=:pressure_current_topology_uniqueness_and_exterior_currents))
    body=(candidate_hash=context.candidate_hash,context_hash=context.context_hash,case_id=case.case_id,level=case.level,nfp=data.mesh.nfp,flux_Wb=case.flux_Wb,
          initial_state=sol.initial_state,final_state=sol.final_state,state_hash=statehash,executed=true,status=sol.status,solver_exit_code=sol.solver_exit_code,
          stopping_reason=sol.stopping_reason,iterations=sol.iterations,raw_artifacts=data.raw_artifacts,engineering_input=eng,artifacts=artifacts,diagnostics=diag)
    SpatialMultiRegionCaseV4(values(body)...,canonical_hash(body))
end

function execute_spatial_multiregion_v4(context,upstream,run_dir)
    d=_smr_declaration(context);receipt=_smr_upstream(context,upstream);dir=abspath(run_dir);mkpath(dir)
    rawdir=joinpath(dir,"geometry");mkpath(rawdir);request=joinpath(rawdir,"request.tsv")
    nfp=upstream.request.runner_payload.nfp
    write(request,join(("candidate_hash\t$(context.candidate_hash)","context_hash\t$(context.context_hash)",
        "declaration_hash\t$(canonical_hash(d))","hdf5_sha256\t$(receipt.output_sha256)","nfp\t$nfp","quadrature_order\t$(d.quadrature.order)"),"\n")*"\n")
    cmd=Cmd([receipt.python_executable,_SMR_SAMPLER,receipt.output_path,request,rawdir,receipt.desc_module_path])
    out=joinpath(rawdir,"sampler.stdout.txt");err=joinpath(rawdir,"sampler.stderr.txt")
    proc=open(out,"w") do o;open(err,"w") do e;run(pipeline(ignorestatus(cmd),stdout=o,stderr=e));end;end
    exitpath=joinpath(rawdir,"sampler.exitcode");write(exitpath,"$(proc.exitcode)\n")
    proc.exitcode==0 || error("spatial DESC sampler exit $(proc.exitcode); see $err")
    metapath=joinpath(rawdir,"metadata.tsv");meta=Dict(Tuple(split(line,'\t';limit=2)) for line in readlines(metapath))
    meta["candidate_hash"]==string(context.candidate_hash)&&meta["context_hash"]==string(context.context_hash)&&
        meta["declaration_hash"]==string(canonical_hash(d))&&meta["hdf5_sha256"]==string(receipt.output_sha256) || error("spatial raw metadata binding mismatch")
    required_environment=("python_executable","python_implementation","platform","machine","processor",
        "logical_cpu_count","thread_environment_json","jax_backend","jax_enable_x64","jax_devices_json",
        "desc_distribution_name","desc_distribution_version","desc_distribution_metadata_path",
        "desc_distribution_metadata_sha256","desc_distribution_record_path","desc_distribution_record_sha256")
    all(k->haskey(meta,k)&&!isempty(meta[k]),required_environment) || error("incomplete Python/DESC environment metadata")
    data=Dict{Symbol,Any}()
    for level in (:coarse,:fine)
        names=(:nodes,:volume,:faces,:radial_bound)
        arts=NamedTuple{names}(Tuple(_smr_artifact(joinpath(rawdir,k==:radial_bound ? "continuous_R_bound.csv" : "$(level)_$(k).csv"),
            k==:radial_bound ? "spatial_continuous_R_bound_v1" : "spatial_geometry_v1",parse(Int,meta["$(level)_$(k)_count"])) for k in names))
        for k in names;string(getproperty(arts,k).sha256)==meta["$(level)_$(k)_sha256"]||error("raw file hash mismatch");end
        data[level]=load_spatial_data_v4(d,(level=level,nfp=nfp,raw_artifacts=arts))
        data[level].continuous_enclosure.R_upper_m==parse(Float64,meta["continuous_R_upper_m"])||error("continuous R bound replay mismatch")
    end
    cases=Tuple(_smr_write_case(context,d,data[c.level],c,joinpath(dir,c.case_id)) for c in d.cases)
    code=all(c->c.solver_exit_code==0,cases) ? 0 : maximum(c.solver_exit_code for c in cases)
    descmetadata=_smr_artifact(meta["desc_distribution_metadata_path"],"python_distribution_METADATA",countlines(meta["desc_distribution_metadata_path"]))
    descrecord=_smr_artifact(meta["desc_distribution_record_path"],"python_distribution_RECORD",countlines(meta["desc_distribution_record_path"]))
    string(descmetadata.sha256)==meta["desc_distribution_metadata_sha256"]&&
        string(descrecord.sha256)==meta["desc_distribution_record_sha256"] || error("DESC distribution record hash mismatch")
    python_environment=(python_executable=meta["python_executable"],python_implementation=meta["python_implementation"],
        python_version=meta["python_version"],platform=meta["platform"],machine=meta["machine"],processor=meta["processor"],
        logical_cpu_count=parse(Int,meta["logical_cpu_count"]),thread_environment_json=meta["thread_environment_json"],
        numpy_version=meta["numpy_version"],jax_version=meta["jax_version"],jaxlib_version=meta["jaxlib_version"],
        jax_backend=meta["jax_backend"],jax_enable_x64=meta["jax_enable_x64"],jax_devices_json=meta["jax_devices_json"],
        desc_distribution_name=meta["desc_distribution_name"],desc_distribution_version=meta["desc_distribution_version"])
    execution=(command=string(cmd),sampler_exit_code=proc.exitcode,julia_version=string(VERSION),blas_config=string(BLAS.get_config()),
       python_environment=python_environment,desc_distribution_metadata=descmetadata,desc_distribution_record=descrecord,
       request=_smr_artifact(request,"spatial_request_v1",6),metadata=_smr_artifact(metapath,"spatial_metadata_v1",length(meta)),
       sampler_stdout=_smr_artifact(out,"process_stdout",countlines(out)),sampler_stderr=_smr_artifact(err,"process_stderr",countlines(err)),
       sampler_exit=_smr_artifact(exitpath,"integer_exitcode",1),source=_smr_artifact(_SMR_SOURCE,"julia_source",countlines(_SMR_SOURCE)),
       sampler_source=_smr_artifact(_SMR_SAMPLER,"python_source",countlines(_SMR_SAMPLER)),
       hdf5=_smr_artifact(receipt.output_path,"DESC_hdf5",1),python_executable=_smr_artifact(receipt.python_executable,"python_executable",1),
       desc_module=_smr_artifact(receipt.desc_module_path,"DESC_module",countlines(receipt.desc_module_path)),
       upstream_input=_smr_artifact(receipt.input_path,"DESC_input",countlines(receipt.input_path)),
       upstream_adapter=_smr_artifact(receipt.adapter_path,"DESC_adapter_source",countlines(receipt.adapter_path)),
       upstream_inspector=_smr_artifact(receipt.inspector_path,"DESC_inspector_source",countlines(receipt.inspector_path)),
       upstream_receipt_hash=canonical_hash(receipt),upstream_request_hash=canonical_hash(upstream.request),upstream_result_hash=canonical_hash(upstream.result))
    body=(candidate_hash=context.candidate_hash,context_hash=context.context_hash,declaration=d,cases=cases,primary_case_id="nominal_coarse",executed=true,
          status=code==0 ? :unsupported : :fail,solver_exit_code=code,execution=execution,physical_validation=:unsupported,claim_ceiling=screen_only)
    result=SpatialMultiRegionResultV4(values(body)...,canonical_hash(body))
    validate_spatial_result_v4(context,result);result
end

function validate_spatial_result_v4(context,p::SpatialMultiRegionResultV4)
    d=_smr_declaration(context);canonical_hash(p)
    p.candidate_hash==context.candidate_hash&&p.context_hash==context.context_hash&&canonical_hash(p.declaration)==canonical_hash(d)||error("foreign spatial result")
    p.primary_case_id=="nominal_coarse"&&length(p.cases)==length(d.cases)&&p.executed&&p.physical_validation==:unsupported&&p.claim_ceiling==screen_only||error("spatial result authority mismatch")
    p.execution.source.path==_SMR_SOURCE&&p.execution.source.sha256==_smr_sha(_SMR_SOURCE)&&
        p.execution.sampler_source.path==_SMR_SAMPLER&&p.execution.sampler_source.sha256==_smr_sha(_SMR_SAMPLER)||error("spatial producer source mismatch")
    for v in values(p.execution);v isa SpatialArtifactV4&&validate_spatial_artifact_v4(v);end
    meta=Dict(Tuple(split(line,'\t';limit=2)) for line in readlines(p.execution.metadata.path))
    meta["candidate_hash"]==string(context.candidate_hash)&&meta["context_hash"]==string(context.context_hash)&&
        meta["declaration_hash"]==string(canonical_hash(d))&&meta["hdf5_sha256"]==string(p.execution.hdf5.sha256)||error("geometry metadata candidate mismatch")
    p.execution.desc_distribution_metadata.path==abspath(meta["desc_distribution_metadata_path"])&&
        string(p.execution.desc_distribution_metadata.sha256)==meta["desc_distribution_metadata_sha256"]&&
        p.execution.desc_distribution_record.path==abspath(meta["desc_distribution_record_path"])&&
        string(p.execution.desc_distribution_record.sha256)==meta["desc_distribution_record_sha256"]||error("DESC distribution metadata replay mismatch")
    env=p.execution.python_environment
    env.python_executable==meta["python_executable"]&&env.python_implementation==meta["python_implementation"]&&
        env.python_version==meta["python_version"]&&env.platform==meta["platform"]&&env.machine==meta["machine"]&&
        env.processor==meta["processor"]&&env.logical_cpu_count==parse(Int,meta["logical_cpu_count"])&&
        env.thread_environment_json==meta["thread_environment_json"]&&env.numpy_version==meta["numpy_version"]&&
        env.jax_version==meta["jax_version"]&&env.jaxlib_version==meta["jaxlib_version"]&&
        env.jax_backend==meta["jax_backend"]&&env.jax_enable_x64==meta["jax_enable_x64"]&&
        env.jax_devices_json==meta["jax_devices_json"]&&env.desc_distribution_name==meta["desc_distribution_name"]&&
        env.desc_distribution_version==meta["desc_distribution_version"]||error("Python/JAX environment replay mismatch")
    for (spec,c) in zip(d.cases,p.cases)
        canonical_hash(c);c.candidate_hash==context.candidate_hash&&c.context_hash==context.context_hash&&
            c.case_id==spec.case_id&&c.level==spec.level&&c.flux_Wb==spec.flux_Wb&&c.executed||error("spatial realization mismatch")
        for (k,art) in pairs(c.raw_artifacts)
            validate_spatial_artifact_v4(art);string(art.sha256)==meta["$(c.level)_$(k)_sha256"]||error("unbound raw geometry")
        end
        data=load_spatial_data_v4(d,c);Tuple(data.initial_state)==c.initial_state||error("initializer not actual DESC nodal field")
        statehash=canonical_hash((candidate_hash=context.candidate_hash,context_hash=context.context_hash,case_id=c.case_id,level=c.level,flux_Wb=c.flux_Wb,state=c.final_state))
        c.state_hash==statehash||error("spatial solved state mismatch")
        for art in values(c.artifacts);validate_spatial_artifact_v4(art);end
        state_lines=split.(readlines(c.artifacts.state_history.path)[2:end],',');nnode=div(length(c.final_state),4)
        length(state_lines)==length(c.iterations)*nnode||error("state history coverage mismatch")
        for (j,z) in enumerate(state_lines)
            parse(Int,z[1])==div(j-1,nnode)&&parse(Int,z[2])==mod(j-1,nnode)+1||error("state history ownership mismatch")
        end
        initial_read=Tuple(v for z in state_lines[1:nnode] for v in parse.(Float64,z[3:6]))
        final_read=Tuple(v for z in state_lines[end-nnode+1:end] for v in parse.(Float64,z[3:6]))
        initial_read==c.initial_state&&final_read==c.final_state||error("state history does not bind actual endpoints")
        diag=c.diagnostics
        diag.attempt_count==length(diag.attempts)&&diag.accepted_update_count==count(t->t.accepted,diag.attempts)==length(c.iterations)-1||error("solver attempt/update count mismatch")
        diag.last_attempt==(isempty(diag.attempts) ? (executed=false,reason=c.stopping_reason) : last(diag.attempts))||error("last failed attempt was not retained")
        attempt_record=(attempt_count=diag.attempt_count,accepted_update_count=diag.accepted_update_count,last_attempt=diag.last_attempt,attempts=diag.attempts)
        read(c.artifacts.attempts.path,String)==canonical_json(attempt_record)*"\n"&&c.artifacts.attempts.row_count==diag.attempt_count||error("solver attempts artifact mismatch")
        accepted_index=0;columns=repeat([d.scaling.B_T,d.scaling.B_T,d.scaling.B_T,d.scaling.p_Pa],nnode)
        for (j,t) in enumerate(diag.attempts)
            t.attempt_index==j&&t.iteration==accepted_index&&t.linear_executed&&
                t.line_search_trial_count==length(t.trials)&&t.line_search_evaluation_count==count(z->z.evaluated,t.trials)||error("attempt ownership or trial count mismatch")
            before=Tuple(v for z in state_lines[accepted_index*nnode+1:(accepted_index+1)*nnode] for v in parse.(Float64,z[3:6]))
            canonical_hash(before)==t.state_before_hash||error("solver attempt starts from unrecorded state")
            if t.accepted
                length(t.proposed_scaled_step)==length(before)&&t.accepted_alpha!==nothing&&count(z->z.accepted,t.trials)==1||error("accepted step evidence missing")
                trial=collect(before).+t.accepted_alpha.*columns.*collect(t.proposed_scaled_step)
                for k in 4:4:length(trial);_smr_pressure_feasible(trial[k],d.scaling.p_Pa) && trial[k]<0. && (trial[k]=0.);end
                after=Tuple(v for z in state_lines[(accepted_index+1)*nnode+1:(accepted_index+2)*nnode] for v in parse.(Float64,z[3:6]))
                Tuple(trial)==after&&canonical_hash(after)==t.state_after_hash||error("state history update differs from actual attempted step")
                accepted_index+=1
            else
                t.state_after_hash==t.state_before_hash&&all(z->!z.accepted,t.trials)||error("failed attempt changed state")
            end
        end
        a=assemble_spatial_system_v4(d,data,c.final_state;flux_Wb=c.flux_Wb)
        rows=split.(readlines(c.artifacts.residual_rows.path)[2:end],',')
        length(rows)==length(a.residual)&&all(parse(Int,z[1])==i&&parse(Float64,z[3])==a.residual[i]&&parse(Float64,z[4])==a.row_scales[i]&&z[2]==string(a.row_blocks[i]) for (i,z) in enumerate(rows))||error("state residual replay mismatch")
        supportlines=split.(readlines(c.artifacts.row_supports.path)[2:end],',')
        length(supportlines)==length(a.row_supports)&&all(parse(Int,z[1])==i&&z[2]==string(a.row_blocks[i])&&parse.(Int,split(z[3],';'))==a.row_supports[i] for (i,z) in enumerate(supportlines))||error("row support ownership mismatch")
        jrows=split.(readlines(c.artifacts.jacobian.path)[2:end],',');rr,cc,vv=findnz(a.jacobian)
        length(jrows)==length(vv)&&all(parse(Int,z[1])==rr[i]&&parse(Int,z[2])==cc[i]&&parse(Float64,z[3])==vv[i] for (i,z) in enumerate(jrows))||error("full state Jacobian replay mismatch")
        texts=_smr_current_texts(data,c.final_state);eng=c.engineering_input;validate_spatial_current_input_v4(eng)
        eng.candidate_hash==context.candidate_hash&&eng.context_hash==context.context_hash&&eng.case_id==c.case_id&&eng.state_hash==statehash&&
            eng.geometry_hash==canonical_hash(c.raw_artifacts)&&eng.status==c.status&&eng.solver_exit_code==c.solver_exit_code&&
            eng.upstream_valid===false&&eng.current_closure==texts.current_closure||error("engineering provenance or validity mismatch")
        for k in (:volume,:interfaces,:exterior)
            art=getproperty(eng,k);read(art.path,String)==getproperty(texts,k)&&art.row_count==getproperty(texts.counts,k)||error("current artifact not derived from actual state")
        end
        for k in keys(texts.diagnostics);getproperty(c.diagnostics,k)==getproperty(texts.diagnostics,k)||error("physical diagnostic replay mismatch");end
        c.diagnostics.blocks==_smr_block_norms(a)&&c.diagnostics.scaled_norm==norm(a.residual./a.row_scales)||error("solver metric replay mismatch")
        parse(Int,strip(read(c.artifacts.solver_exit.path,String)))==c.solver_exit_code&&c.status==(c.solver_exit_code==0 ? :converged : :fail)||error("solver exit mismatch")
        c.solver_exit_code==0 && maximum(abs,a.residual./a.row_scales)>d.solver.residual_tolerance&&error("false spatial convergence")
    end
    p.solver_exit_code==(all(c->c.solver_exit_code==0,p.cases) ? 0 : maximum(c.solver_exit_code for c in p.cases))||error("whole spatial exit mismatch")
    p.status==(p.solver_exit_code==0 ? :unsupported : :fail)||error("whole spatial status mismatch")
    p.result_hash
end

const _SMR_RAW_HEADER="entity_id,qp_id,rho,theta,zeta,x_m,y_m,z_m,R_m,phi_rad,weight,detE,nx,ny,nz,"*
    join(("E$i$j" for i in 1:3 for j in 1:3),",")*","*join(("I$i$j" for i in 1:3 for j in 1:3),",")*",BR_T,Bphi_T,BZ_T,p_Pa"
function _smr_read_geometry(a::SpatialArtifactV4;nodes=false)
    validate_spatial_artifact_v4(a);lines=readlines(a.path);first(lines)==_SMR_RAW_HEADER || error("spatial geometry schema mismatch")
    length(lines)-1==a.row_count || error("spatial geometry row count mismatch")
    result=NamedTuple[]
    for line in lines[2:end]
        t=split(line,',');length(t)==37 || error("spatial geometry columns mismatch")
        v=parse.(Float64,t);all(isfinite,v)||error("nonfinite geometry")
        E=permutedims(reshape(v[16:24],3,3));Einv=permutedims(reshape(v[25:33],3,3))
        if !nodes
            v[11]>0&&abs(v[12])>1e-14&&norm(E*Einv-I,Inf)<1e-8 || error("invalid signed curved metric")
            isapprox(det(E),v[12];rtol=1e-10,atol=1e-14)||error("metric determinant mismatch")
        end
        push!(result,(entity_id=Int(v[1]),qp_id=Int(v[2]),q=Tuple(v[3:5]),xyz=Tuple(v[6:8]),R=v[9],phi=v[10],weight=v[11],detE=v[12],
                      normal=Tuple(v[13:15]),E=E,Einv=Einv,B_reference_cyl=Tuple(v[34:36]),p_reference=v[37]))
    end
    result
end

function load_spatial_data_v4(d::SpatialMultiRegionDeclarationV4,c)
    mesh=build_spatial_mesh_v4(d,Symbol(c.level),c.nfp)
    nodes=_smr_read_geometry(c.raw_artifacts.nodes;nodes=true);vol=_smr_read_geometry(c.raw_artifacts.volume);faces=_smr_read_geometry(c.raw_artifacts.faces)
    length(nodes)==size(mesh.nodes_q,2) && length(vol)==length(mesh.cell_nodes)*d.quadrature.order^3 && length(faces)==length(mesh.faces)*d.quadrature.order^2 || error("incomplete quadrature coverage")
    for (i,s) in enumerate(nodes)
        s.entity_id==i && norm(collect(s.q)-mesh.nodes_q[:,i])<1e-12 || error("node ownership/order mismatch")
    end
    for (rows,count,nq) in ((vol,length(mesh.cell_nodes),d.quadrature.order^3),(faces,length(mesh.faces),d.quadrature.order^2))
        [(s.entity_id,s.qp_id) for s in rows]==[(i,j) for i in 1:count for j in 1:nq] || error("cell/face quadrature ownership mismatch")
    end
    initial=Float64[];for s in nodes;append!(initial,s.B_reference_cyl);push!(initial,s.p_reference);end
    enclosure=_smr_continuous_enclosure(c.raw_artifacts.radial_bound)
    (mesh=mesh,nodes=nodes,volume=vol,face_quadrature=faces,initial_state=initial,raw_artifacts=c.raw_artifacts,continuous_enclosure=enclosure)
end

function _smr_continuous_enclosure(a)
    validate_spatial_artifact_v4(a);lines=readlines(a.path)
    first(lines)=="l,m,n,R_lmn_m,radial_abs_coefficient_sum"&&length(lines)-1==a.row_count||error("continuous R enclosure schema mismatch")
    total=big(0)//big(1)
    for line in lines[2:end]
        z=split(line,',');l=parse(Int,z[1]);m=abs(parse(Int,z[2]));c=parse(Float64,z[4])
        l>=m&&iseven(l-m)&&isfinite(c)||error("invalid Fourier-Zernike mode")
        radial=sum(factorial(big(l-s))÷(factorial(big(s))*factorial(big(div(l+m,2)-s))*factorial(big(div(l-m,2)-s))) for s in 0:div(l-m,2))
        radial==parse(BigInt,z[5])||error("Zernike monomial bound mismatch")
        total+=abs(rationalize(BigInt,c;tol=0))*radial
    end
    bound=nextfloat(Float64(total))
    (supported=true,R_upper_m=bound,method=:exact_stored_float_Zernike_monomial_triangle,
     applicability="All rho in [0,1], all poloidal/toroidal angles of actual DESC R expansion",artifact=a)
end

function spatial_field_v4(data,cell,s,x)
    b=spatial_basis_v4(data.mesh,cell,s.q);B=zeros(3);D=zeros(3,3);p=0.;dp=zeros(3)
    for (j,n) in enumerate(b.ids)
        q=4*(n-1);Bn=[x[q+1],x[q+2],x[q+3]];B.+=b.N[j].*Bn;p+=b.N[j]*x[q+4]
        for a in 1:3;D[:,a].+=b.dN_dq[a,j].*Bn;dp[a]+=b.dN_dq[a,j]*x[q+4];end
    end
    H=D+[-B[2],B[1],0.]*transpose(s.E[2,:]/s.R);G=H*s.Einv
    divB=tr(G);curl=[G[3,2]-G[2,3],G[1,3]-G[3,1],G[2,1]-G[1,2]]
    rot=_smr_rot(s.phi);Bxyz=rot*B;gradp=rot*transpose(s.Einv)*dp
    (B_cyl=B,B_xyz=Bxyz,J_xyz=rot*curl/_SMR_MU0,gradp_xyz=gradp,p=p,divB=divB,
     T_xyz=_smr_stress(Bxyz,p),gradN_xyz=rot*transpose(s.Einv)*b.dN_dq,N=b.N,ids=b.ids,rotation=rot)
end

function _smr_row_scales(d,data)
    v=zeros(length(data.mesh.cell_nodes));a=zeros(length(data.mesh.faces))
    for s in data.volume;v[s.entity_id]+=s.weight;end
    for s in data.face_quadrature;a[s.entity_id]+=s.weight;end
    stress=d.scaling.B_T^2/_SMR_MU0+d.scaling.p_Pa;scales=zeros(length(data.mesh.row_blocks))
    for (i,ids) in enumerate(data.mesh.cell_nodes),j in eachindex(ids),k in 1:4
        scales[data.mesh.cell_row_start[i]+4*(j-1)+k-1]=(k==4 ? d.scaling.B_T : stress)*v[i]^(2/3)
    end
    for (fid,start) in data.mesh.exterior_row_start,j in 1:4,k in 1:4;scales[start+4*(j-1)+k-1]=(k==4 ? d.scaling.B_T : stress)*a[fid];end
    scales[end]=d.flux.nominal_Wb
    scales
end

function assemble_spatial_system_v4(d,data,x;flux_Wb=d.flux.nominal_Wb,jacobian=true,source_function=nothing,boundary_function=nothing,normal_field_function=nothing)
    mesh=data.mesh;length(x)==4size(mesh.nodes_q,2)&&all(isfinite,x)||throw(ArgumentError("invalid spatial state"))
    r=zeros(length(mesh.row_blocks));ii=Int[];jj=Int[];vv=Float64[]
    add(row,col,value)=if jacobian;push!(ii,row);push!(jj,col);push!(vv,value);end
    # Stress directional derivative, contracted against an arbitrary vector g.
    function dtg(f,Ntrial,c,g)
        if c==4;return -Ntrial.*g;end
        u=Ntrial.*view(f.rotation,:,c);B=f.B_xyz
        (u.*dot(B,g)+B.*dot(u,g)-g.*dot(B,u))./_SMR_MU0
    end
    for s in data.volume
        cell=s.entity_id;f=spatial_field_v4(data,cell,s,x);source=source_function===nothing ? zeros(3) : collect(source_function(s.xyz))
        for a in eachindex(f.ids)
            row=mesh.cell_row_start[cell]+4*(a-1);g=view(f.gradN_xyz,:,a)
            r[row:row+2].-=s.weight.*(f.T_xyz*g+f.N[a].*source);r[row+3]-=s.weight*dot(g,f.B_xyz)
            if jacobian
                for (b,n) in enumerate(f.ids),c in 1:4
                    col=4*(n-1)+c;z=-s.weight.*dtg(f,f.N[b],c,g)
                    for k in 1:3;add(row+k-1,col,z[k]);end
                    add(row+3,col,c==4 ? 0. : -s.weight*f.N[b]*dot(g,view(f.rotation,:,c)))
                end
            end
        end
    end
    for s in data.face_quadrature
        face=mesh.faces[s.entity_id];n=collect(s.normal);fl=spatial_field_v4(data,face.left_cell,s,x)
        outer=face.role==:exterior
        t_ref=outer ? (boundary_function===nothing ? _smr_stress(fl.rotation*collect(s.B_reference_cyl),s.p_reference)*n : collect(boundary_function(s.xyz,s.normal))) : fl.T_xyz*n
        bn_ref=outer ? (normal_field_function===nothing ? 0. : Float64(normal_field_function(s.xyz,s.normal))) : dot(fl.B_xyz,n)
        for (cell,sign) in ((face.left_cell,1.),(face.right_cell,-1.))
            cell==0 && continue
            f=cell==face.left_cell ? fl : spatial_field_v4(data,cell,s,x)
            for a in eachindex(f.ids)
                row=mesh.cell_row_start[cell]+4*(a-1);w=sign*s.weight*f.N[a]
                r[row:row+2].+=w.*t_ref;r[row+3]+=w*bn_ref
                if jacobian&&!outer
                    for (b,node) in enumerate(fl.ids),c in 1:4
                        col=4*(node-1)+c;z=w.*dtg(fl,fl.N[b],c,n)
                        for k in 1:3;add(row+k-1,col,z[k]);end
                        add(row+3,col,c==4 ? 0. : w*fl.N[b]*dot(n,view(fl.rotation,:,c)))
                    end
                end
            end
        end
        if outer
            trace=findall(a->mesh.nodes_q[1,fl.ids[a]]==1.,eachindex(fl.ids));start=mesh.exterior_row_start[s.entity_id]
            for (a,j) in enumerate(trace)
                row=start+4*(a-1);w=s.weight*fl.N[j]
                r[row:row+2].+=w.*(fl.T_xyz*n-t_ref);r[row+3]+=w*(dot(fl.B_xyz,n)-bn_ref)
                if jacobian
                    for b in trace,c in 1:4
                        col=4*(fl.ids[b]-1)+c;z=w.*dtg(fl,fl.N[b],c,n)
                        for k in 1:3;add(row+k-1,col,z[k]);end
                        add(row+3,col,c==4 ? 0. : w*fl.N[b]*dot(n,view(fl.rotation,:,c)))
                    end
                end
            end
        end
        if face.axis==3&&face.fixed==0.
            r[end]+=s.weight*dot(fl.B_xyz,n)
            if jacobian
                for (b,node) in enumerate(fl.ids),c in 1:3;add(length(r),4*(node-1)+c,s.weight*fl.N[b]*dot(n,view(fl.rotation,:,c)));end
            end
        end
    end
    r[end]-=flux_Wb
    (residual=r,row_scales=_smr_row_scales(d,data),row_blocks=mesh.row_blocks,row_supports=mesh.row_supports,
     jacobian=jacobian ? sparse(ii,jj,vv,length(r),length(x)) : spzeros(length(r),length(x)))
end
