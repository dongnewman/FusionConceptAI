using Test, FusionConceptAI, LinearAlgebra, SparseArrays
module SpatialPhysicsFocused
    include(joinpath(@__DIR__,"..","src","RuntimeV4","SpatialExecutionTypesV4.jl"))
    include(joinpath(@__DIR__,"..","src","RuntimeV4","SpatialMultiRegionV4.jl"))
end
const SPF=SpatialPhysicsFocused

# Analytic circular torus is a manufactured software fixture only. It is never
# emitted as a candidate/provider artifact or accepted by production replay.
function manufactured_spatial_fixture(level=:coarse;nfp=1)
    d=SPF.spatial_multiregion_declaration_v4(flux_Wb=pi);mesh=SPF.build_spatial_mesh_v4(d,level,nfp)
    function sample(entity,qp,q,qw,axis)
        rho,theta,zeta=q;R=3+rho*cos(theta);phi=zeta
        E=[cos(theta) -rho*sin(theta) 0.;0. 0. R;sin(theta) rho*cos(theta) 0.]
        invE=rho==0 ? zeros(3,3) : inv(E);rot=SPF._smr_rot(phi);normal=zeros(3)
        weight=qw*abs(det(E))
        if axis!=0
            dual=invE[axis,:];normal=rot*dual/norm(dual);other=filter(!=(axis),1:3)
            weight=qw*norm(cross(E[:,other[1]],E[:,other[2]]))
        end
        (entity_id=entity,qp_id=qp,q=Tuple(q),xyz=(R*cos(phi),R*sin(phi),rho*sin(theta)),R=R,phi=phi,
         weight=weight,detE=det(E),normal=Tuple(normal),E=E,Einv=invE,B_reference_cyl=(0.,1.,.2),p_reference=1.e5)
    end
    roots=(-sqrt(3/5),0.,sqrt(3/5));weights=(5/9,8/9,5/9)
    vol=NamedTuple[];faces=NamedTuple[];nodes=[sample(i,1,mesh.nodes_q[:,i],0.,0) for i in axes(mesh.nodes_q,2)]
    for (cell,b) in enumerate(mesh.cell_bounds)
        qp=0
        for iz in 1:3,it in 1:3,ir in 1:3
            ix=(ir,it,iz);q=ntuple(a->sum(b[a])/2+roots[ix[a]]*(b[a][2]-b[a][1])/2,3)
            w=prod(weights[ix[a]]*(b[a][2]-b[a][1])/2 for a in 1:3);qp+=1
            push!(vol,sample(cell,qp,q,w,0))
        end
    end
    for (fid,f) in enumerate(mesh.faces)
        b=mesh.cell_bounds[f.right_cell==0 ? f.left_cell : f.right_cell];other=filter(!=(f.axis),1:3);qp=0
        for j in 1:3,i in 1:3
            q=zeros(3);q[f.axis]=f.fixed;qw=1.
            for (a,ix) in zip(other,(i,j));q[a]=sum(b[a])/2+roots[ix]*(b[a][2]-b[a][1])/2;qw*=weights[ix]*(b[a][2]-b[a][1])/2;end
            qp+=1;push!(faces,sample(fid,qp,q,qw,f.axis))
        end
    end
    x=Float64[];for s in nodes;append!(x,s.B_reference_cyl);push!(x,s.p_reference);end
    d,(mesh=mesh,nodes=nodes,volume=vol,face_quadrature=faces,initial_state=x,raw_artifacts=(manufactured_test_only=true,))
end

@testset "spatial state ownership and axis regularity" begin
    d=SPF.spatial_multiregion_declaration_v4(flux_Wb=1.)
    coarse=SPF.build_spatial_mesh_v4(d,:coarse,5);fine=SPF.build_spatial_mesh_v4(d,:fine,5)
    @test (4size(coarse.nodes_q,2),length(coarse.row_blocks))==(360,2881)
    @test (4size(fine.nodes_q,2),length(fine.row_blocks))==(2640,21761)
    @test count(ids->length(ids)==6,coarse.cell_nodes)==40
    @test count(ids->length(ids)==6,fine.cell_nodes)==160
    @test all(issorted(s)&&allunique(s) for s in coarse.row_supports[end:end])
    for cell in (1,5),q in ((.25,pi/4,pi/10),(.25,pi/8,pi/20))
        cell==5&&continue
        b=SPF.spatial_basis_v4(coarse,cell,q)
        @test sum(b.N)≈1.
        @test vec(sum(b.dN_dq;dims=2))≈zeros(3) atol=1e-13
    end
    # Axis-adjacent basis gradients do not retain the forbidden 1/rho term.
    b=SPF.spatial_basis_v4(coarse,1,(1e-12,pi/4,pi/10))
    @test maximum(abs,b.dN_dq[2,:])<1e-10
end

@testset "current-field calculus and full-support derivatives" begin
    d,data=manufactured_spatial_fixture();x=copy(data.initial_state)
    @test all(s->s.detE<0,data.volume)
    # A constant axial field is representable exactly; curl/div must use that
    # current nodal state rather than any supplied reference current.
    for i in 1:div(length(x),4);x[4i-3:4i].=[0.,0.,2.,1.e5];end
    f=SPF.spatial_field_v4(data,1,first(data.volume),Tuple(x))
    @test norm(f.J_xyz)<1e-8
    @test abs(f.divB)<1e-13
    @test norm(f.gradp_xyz)<1e-8
    # Test all field kinds including pressure and a periodic-seam node. The
    # actual production audit separately covers every column on both grids.
    x=copy(data.initial_state);x.+=repeat([.1,.05,-.04,100.],div(length(x),4))
    a=SPF.assemble_spatial_system_v4(d,data,x)
    @test a.jacobian isa SparseMatrixCSC
    @test size(a.jacobian)==(length(data.mesh.row_blocks),length(x))
    for col in (1,2,3,4,20,length(x))
        h=col%4==0 ? .1 : 1e-5;xp=copy(x);xm=copy(x);xp[col]+=h;xm[col]-=h
        fd=(SPF.assemble_spatial_system_v4(d,data,xp;jacobian=false).residual-
            SPF.assemble_spatial_system_v4(d,data,xm;jacobian=false).residual)/(2h)
        @test norm(a.jacobian[:,col]-fd)/max(norm(fd),1.)<1e-7
    end
    traces_ok=true
    for s in data.face_quadrature
        face=data.mesh.faces[s.entity_id];face.right_cell==0&&continue
        l=SPF.spatial_field_v4(data,face.left_cell,s,x);r=SPF.spatial_field_v4(data,face.right_cell,s,x)
        traces_ok &= isapprox(l.B_xyz,r.B_xyz;atol=1e-13)&&isapprox(l.p,r.p;atol=1e-8)
    end
    @test traces_ok
    support_ok=true
    for col in axes(a.jacobian,2),ptr in nzrange(a.jacobian,col)
        row=rowvals(a.jacobian)[ptr];value=nonzeros(a.jacobian)[ptr]
        support_ok &= abs(value)<1e-9 || col in a.row_supports[row]
    end
    @test support_ok
    @test_throws ArgumentError SPF.solve_spatial_state_v4(d,data,x;flux_Wb=1.2*d.flux.nominal_Wb,limits=(max_iterations=1,seconds=60.))
    solve=SPF.solve_spatial_state_v4(d,data,x;limits=(max_iterations=1,seconds=60.))
    @test solve.solver_exit_code in (0,2,3,4,5,6)
    @test solve.solver_exit_code!=5 # Exercise the actual installed sparse-QR API.
    @test length(solve.iterations)>=1
    @test solve.rank_diagnostics.columns==length(x)
    @test solve.final_assembly.jacobian isa SparseMatrixCSC
    @test solve.accepted_update_count==length(solve.iterations)-1
    @test solve.attempt_count==length(solve.attempts)
    @test solve.accepted_update_count==count(t->t.accepted,solve.attempts)
    if solve.attempt_count>0
        @test solve.last_attempt==last(solve.attempts)
        @test all(t->t.line_search_trial_count==length(t.trials)&&t.line_search_evaluation_count==count(z->z.evaluated,t.trials),solve.attempts)
        @test all(t->t.linear_executed,solve.attempts)
    end
    budget=SPF.solve_spatial_state_v4(d,data,x;limits=(max_iterations=0,seconds=0.))
    @test budget.solver_exit_code==4
    @test budget.attempt_count==budget.accepted_update_count==0
    @test !budget.last_attempt.executed
    @test budget.final_state==Tuple(x)
    # Deterministic test-only hooks cover failure records that otherwise depend
    # on SuiteSparse/numerical behavior. Default production execution never
    # supplies these hooks and continues to use sparse QR plus Armijo.
    qr_failure=SPF.solve_spatial_state_v4(d,data,x;limits=(max_iterations=1,seconds=60.),
        _test_qr_factorization=(A,tol)->error("forced QR failure for ledger replay"))
    @test qr_failure.solver_exit_code==5
    @test qr_failure.stopping_reason==:sparse_QR_failure
    @test qr_failure.attempt_count==1
    @test qr_failure.accepted_update_count==0
    @test length(qr_failure.state_history)==length(qr_failure.iterations)==1
    @test qr_failure.final_state==Tuple(first(qr_failure.state_history))==Tuple(x)
    @test qr_failure.last_attempt==only(qr_failure.attempts)
    @test qr_failure.last_attempt.linear_exit_code==1
    @test qr_failure.last_attempt.linear_error_stage==:factorization
    @test occursin("forced QR failure",qr_failure.last_attempt.linear_error)
    @test !qr_failure.last_attempt.accepted
    @test qr_failure.last_attempt.state_before_hash==qr_failure.last_attempt.state_after_hash==canonical_hash(Tuple(x))
    line_failure=SPF.solve_spatial_state_v4(d,data,x;limits=(max_iterations=1,seconds=60.),
        _test_line_search_acceptance=trial->false)
    @test line_failure.solver_exit_code==3
    @test line_failure.stopping_reason==:feasible_line_search_failed
    @test line_failure.attempt_count==1
    @test line_failure.accepted_update_count==0
    @test length(line_failure.state_history)==length(line_failure.iterations)==1
    @test line_failure.final_state==Tuple(first(line_failure.state_history))==Tuple(x)
    @test line_failure.last_attempt==only(line_failure.attempts)
    @test line_failure.last_attempt.linear_exit_code==0
    @test line_failure.last_attempt.line_search_trial_count==length(line_failure.last_attempt.trials)
    @test line_failure.last_attempt.line_search_evaluation_count==count(t->t.evaluated,line_failure.last_attempt.trials)
    @test all(t->!t.accepted,line_failure.last_attempt.trials)
    @test line_failure.last_attempt.state_before_hash==line_failure.last_attempt.state_after_hash==canonical_hash(Tuple(x))
    text=SPF._smr_current_texts(data,solve.final_state)
    @test startswith(text.volume,SPF.SPATIAL_VOLUME_HEADER_V4)
    @test text.current_closure.outer_K==:unknown
    @test text.current_closure.external_current_closure==:unsupported
end
