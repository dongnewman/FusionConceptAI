"""Opt-in numerical-only N1 recovery benchmark.

This file does not run on import.  Call `run_manufactured_recovery_benchmark()`
explicitly from a Julia session.  It uses the production residual/Jacobian and
bound-constrained solver, but its toroidal-field/source pair is manufactured;
the result grants no physical or evidence authority.
"""
module RuntimeV4ManufacturedRecoveryBenchmark
using LinearAlgebra, SHA
include(joinpath(@__DIR__,"..","src","RuntimeV4","SpatialExecutionTypesV4.jl"))
include(joinpath(@__DIR__,"..","src","RuntimeV4","SpatialMultiRegionV4.jl"))
const SPF=RuntimeV4ManufacturedRecoveryBenchmark

const _BPHI=1.0
const _P0=1.0e5
const _MU0=SPF._SMR_MU0
const DEFAULT_RESOLUTIONS=((:h05,1,
        ((level=:h05,rho=(0.,.5,1.),theta_count=4,zeta_per_period=2),),.5),
    (:h033,1,((level=:h033,rho=(0.,1/3,.5,2/3,1.),theta_count=6,zeta_per_period=3),),1/3),
    (:h025,1,((level=:h025,rho=(0.,.25,.5,.75,1.),theta_count=8,zeta_per_period=4),),.25))
const DEFAULT_PERTURBATIONS=((0.11,-0.07,0.05,2.0e3),
    (-0.23,0.13,-0.09,-3.0e3),(0.37,0.19,0.17,7.0e3))

"Analytic nonzero-source field: B=e_phi, p=p0, div(T)=source."
function manufactured_field(xyz)
    X,Y,_=xyz;R=hypot(X,Y);eR=(X/R,Y/R,0.);eφ=(-Y/R,X/R,0.)
    B=Tuple(_BPHI*v for v in eφ);source=Tuple(-v/(_MU0*R) for v in eR)
    (B=B,p=_P0,source=source)
end
function manufactured_traction(xyz,normal)
    q=manufactured_field(xyz);SPF._smr_stress(collect(q.B),q.p)*collect(normal)
end
manufactured_normal(xyz,normal)=dot(collect(manufactured_field(xyz).B),collect(normal))

"Builds the same legitimate curved-Q1 quadrature data shape used in production."
function custom_declaration(spaces)
    d=SPF.spatial_multiregion_declaration_v4(flux_Wb=pi)
    SPF.SpatialMultiRegionDeclarationV4(d.revision,d.regions,d.states,d.interfaces,d.source,d.boundary,spaces,d.flux,d.cases,d.parameters,d.quadrature,d.scaling,d.solver,d.applicability)
end
function benchmark_data(spec)
    level,nfp,spaces,h=spec;d=custom_declaration(spaces);mesh=SPF.build_spatial_mesh_v4(d,level,nfp)
    roots=(-sqrt(3/5),0.,sqrt(3/5));weights=(5/9,8/9,5/9)
    sample(entity,qp,q,qw,axis)=begin
        rho,theta,zeta=q;R=3+rho*cos(theta);phi=zeta
        E=[cos(theta) -rho*sin(theta) 0.;0. 0. R;sin(theta) rho*cos(theta) 0.]
        invE=rho==0 ? zeros(3,3) : inv(E);rot=SPF._smr_rot(phi);normal=zeros(3);weight=qw*abs(det(E))
        if axis!=0
            dual=invE[axis,:];normal=rot*dual/norm(dual);other=filter(!=(axis),1:3)
            weight=qw*norm(cross(E[:,other[1]],E[:,other[2]]))
        end
        (entity_id=entity,qp_id=qp,q=Tuple(q),xyz=(R*cos(phi),R*sin(phi),rho*sin(theta)),R=R,phi=phi,
         weight=weight,detE=det(E),normal=Tuple(normal),E=E,Einv=invE,
         B_reference_cyl=(0.,_BPHI,0.),p_reference=_P0)
    end
    nodes=[sample(i,1,mesh.nodes_q[:,i],0.,0) for i in axes(mesh.nodes_q,2)]
    vol=NamedTuple[];faces=NamedTuple[]
    for (cell,b) in enumerate(mesh.cell_bounds),iz in 1:3,it in 1:3,ir in 1:3
        ix=(ir,it,iz);q=ntuple(a->sum(b[a])/2+roots[ix[a]]*(b[a][2]-b[a][1])/2,3)
        push!(vol,sample(cell,(iz-1)*9+(it-1)*3+ir,q,prod(weights[ix[a]]*(b[a][2]-b[a][1])/2 for a in 1:3),0))
    end
    for (fid,f) in enumerate(mesh.faces)
        b=mesh.cell_bounds[f.right_cell==0 ? f.left_cell : f.right_cell];other=filter(!=(f.axis),1:3);qp=0
        for j in 1:3,i in 1:3
            q=zeros(3);q[f.axis]=f.fixed;qw=1.
            for (a,ix) in zip(other,(i,j));q[a]=sum(b[a])/2+roots[ix]*(b[a][2]-b[a][1])/2;qw*=weights[ix]*(b[a][2]-b[a][1])/2;end
            qp+=1;push!(faces,sample(fid,qp,q,qw,f.axis))
        end
    end
    x=Float64[]
    for s in nodes
        # Solver state is cylindrical (B_R, B_phi, B_Z, p).  The production
        # field evaluator owns the rotation to Cartesian components.
        append!(x,[0.,_BPHI,0.,_P0])
    end
    (declaration=d,data=(mesh=mesh,nodes=nodes,volume=vol,face_quadrature=faces,
     initial_state=x,raw_artifacts=(manufactured_numerical_only=true,)))
end

function run_manufactured_recovery_benchmark(;resolutions=DEFAULT_RESOLUTIONS,
        perturbations=DEFAULT_PERTURBATIONS,max_iterations=12,
        benchmark_id=:runtime_v4_manufactured_recovery_n1_v2)
    max_iterations isa Int&&max_iterations>=0 || throw(ArgumentError("nonnegative integer iteration budget required"))
    results=NamedTuple[]
    for spec in resolutions
        level,nfp,_,h=spec;bundle=benchmark_data(spec);d=bundle.declaration;data=bundle.data;truth=data.initial_state
        truth_assembly=SPF.assemble_spatial_system_v4(d,data,truth;flux_Wb=pi,
            source_function=xyz->manufactured_field(xyz).source,
            boundary_function=manufactured_traction,normal_field_function=manufactured_normal)
        truth_scaled_max=maximum(abs,truth_assembly.residual./truth_assembly.row_scales)
        for δ in perturbations
            initial=truth.+repeat(collect(δ),div(length(truth),4))
            sol=SPF.solve_spatial_state_v4(d,data,initial;flux_Wb=pi,limits=(max_iterations=max_iterations,seconds=600.),
                source_function=xyz->manufactured_field(xyz).source,
                boundary_function=manufactured_traction,normal_field_function=manufactured_normal)
            initial_err=norm(initial.-truth)/max(norm(truth),1.)
            err=norm(collect(sol.final_state).-truth)/max(norm(truth),1.)
            push!(results,(level=level,h=h,nfp=nfp,
                perturbation_index=length(results)%length(perturbations)+1,
                perturbation=δ,status=sol.status,solver_exit_code=sol.solver_exit_code,
                stopping_reason=sol.stopping_reason,attempt_count=sol.attempt_count,
                accepted_update_count=sol.accepted_update_count,
                all_accepted_updates_strict=all(a->!a.accepted ||
                    (a.strict_objective_decrease && a.scaled_state_change),sol.attempts),
                truth_scaled_residual_max=truth_scaled_max,solution_relative_error=err,
                initial_solution_relative_error=initial_err,
                scaled_residual_max=maximum(abs,sol.final_assembly.residual./sol.final_assembly.row_scales)))
        end
    end
    orders=NamedTuple[]
    for j in 1:length(perturbations), k in 2:length(resolutions)
        hi=resolutions[k-1][4];hj=resolutions[k][4]
        left=results[(k-2)*length(perturbations)+j]
        right=results[(k-1)*length(perturbations)+j]
        ei=left.solution_relative_error;ej=right.solution_relative_error
        applicable=left.solver_exit_code==0&&right.solver_exit_code==0&&
            isfinite(ei)&&isfinite(ej)&&ei>0&&ej>0
        order=applicable ? log(ei/ej)/log(hi/hj) : nothing
        reason=applicable ? :two_converged_endpoints : :nonconverged_or_invalid_endpoint
        push!(orders,(perturbation_index=j,from_h=hi,to_h=hj,
            from_solver_exit_code=left.solver_exit_code,to_solver_exit_code=right.solver_exit_code,
            applicable=applicable,reason=reason,observed_order=order))
    end
    source_path=abspath(@__FILE__)
    production_source=abspath(joinpath(@__DIR__,"..","src","RuntimeV4","SpatialMultiRegionV4.jl"))
    (benchmark=benchmark_id,max_iterations=max_iterations,
     julia_version=string(VERSION),source_path=source_path,
     source_sha256=bytes2hex(SHA.sha256(read(source_path))),
     production_source_path=production_source,
     production_source_sha256=bytes2hex(SHA.sha256(read(production_source))),
     resolutions=Tuple((level=s[1],h=s[4],nfp=s[2],unknowns=4size(benchmark_data(s).data.mesh.nodes_q,2)) for s in resolutions),
     results=Tuple(results),observed_orders=Tuple(orders),numerical_only=true,
     physical_validation=:unsupported,evidence_authority=:none)
end
end

if abspath(PROGRAM_FILE)==abspath(@__FILE__)
    result=RuntimeV4ManufacturedRecoveryBenchmark.run_manufactured_recovery_benchmark()
    text=RuntimeV4ManufacturedRecoveryBenchmark.SPF.canonical_json(result)*"\n"
    if isempty(ARGS)
        print(text)
    else
        output=abspath(first(ARGS));mkpath(dirname(output));write(output,text)
        println("N1_MANUFACTURED_RECOVERY_OUTPUT=",output)
    end
end
