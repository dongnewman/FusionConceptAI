# Definition-only diagnostics included in ManufacturedStagedV9Tests.
# No candidate constructor, solver, acceptance shortcut, or production rule change.
const AUDIT_RULES_V9=(
    (order=3,roots=(-sqrt(3/5),0.0,sqrt(3/5)),weights=(5/9,8/9,5/9)),
    (order=5,roots=N.GAUSS5_ROOTS,weights=N.GAUSS5_WEIGHTS),
    (order=7,roots=(-0.9491079123427585,-0.7415311855993945,-0.4058451513773972,0.0,0.4058451513773972,0.7415311855993945,0.9491079123427585),
        weights=(0.12948496616887065,0.2797053914892766,0.3818300505051183,0.41795918367346896,0.3818300505051183,0.2797053914892766,0.12948496616887065)),
    (order=9,roots=(-0.9681602395076261,-0.8360311073266358,-0.6133714327005904,-0.3242534234038089,0.0,0.3242534234038089,0.6133714327005904,0.8360311073266358,0.9681602395076261),
        weights=(0.08127438836157472,0.18064816069485712,0.26061069640293566,0.3123470770400028,0.33023935500125967,0.3123470770400028,0.26061069640293566,0.18064816069485712,0.08127438836157472)))

function audit_data_v9(data,rule)
    rule.order==3 && return data
    mesh=data.mesh;vol=NamedTuple[];faces=NamedTuple[];n=rule.order
    for (cell,b) in enumerate(mesh.cell_bounds),iz in 1:n,it in 1:n,ir in 1:n
        ix=(ir,it,iz);q=ntuple(a->sum(b[a])/2+rule.roots[ix[a]]*(b[a][2]-b[a][1])/2,3)
        w=prod(rule.weights[ix[a]]*(b[a][2]-b[a][1])/2 for a in 1:3)
        push!(vol,N.sample5(cell,(iz-1)*n*n+(it-1)*n+ir,q,w,0))
    end
    for (fid,f) in enumerate(mesh.faces)
        b=mesh.cell_bounds[f.right_cell==0 ? f.left_cell : f.right_cell];other=filter(!=(f.axis),1:3)
        for j in 1:n,i in 1:n
            q=zeros(3);q[f.axis]=f.fixed;w=1.0
            for (a,ix) in zip(other,(i,j))
                q[a]=sum(b[a])/2+rule.roots[ix]*(b[a][2]-b[a][1])/2
                w*=rule.weights[ix]*(b[a][2]-b[a][1])/2
            end
            push!(faces,N.sample5(fid,(j-1)*n+i,q,w,f.axis))
        end
    end
    merge(data,(volume=vol,face_quadrature=faces))
end

function diagnostic_declaration_v9(d,order)
    b=S.spatial_multiregion_declaration_v4(flux_Wb=d.flux.nominal_Wb)
    M.replace_declaration(b;revision="test-only-MMS-weak-integral-audit-v9",spaces=d.spaces,
        quadrature=merge(b.quadrature,(order=order,)))
end

function analytic_weak_rows_v9(data,flux)
    mesh=data.mesh;r=zeros(length(mesh.row_blocks))
    for s in data.volume
        b=S.spatial_basis_v4(mesh,s.entity_id,s.q);rot=S._smr_rot(s.phi)
        grad=rot*transpose(s.Einv)*b.dN_dq;truth=N.analytic_field_v2(s.xyz)
        T=S._smr_stress(collect(truth.B),truth.p)
        for a in eachindex(b.ids)
            row=mesh.cell_row_start[s.entity_id]+4*(a-1);g=view(grad,:,a)
            r[row:row+2].-=s.weight.*(T*g+b.N[a].*collect(truth.source))
            r[row+3]-=s.weight*dot(g,collect(truth.B))
        end
    end
    for s in data.face_quadrature
        face=mesh.faces[s.entity_id];truth=N.analytic_field_v2(s.xyz)
        traction=S._smr_stress(collect(truth.B),truth.p)*collect(s.normal);bn=dot(collect(truth.B),collect(s.normal))
        for (cell,sign) in ((face.left_cell,1.0),(face.right_cell,-1.0))
            cell==0 && continue
            b=S.spatial_basis_v4(mesh,cell,s.q)
            for a in eachindex(b.ids)
                row=mesh.cell_row_start[cell]+4*(a-1);w=sign*s.weight*b.N[a]
                r[row:row+2].+=w.*traction;r[row+3]+=w*bn
            end
        end
        # Analytic field equals its analytic exterior data exactly by definition.
        # Exterior mismatch rows therefore remain zero in this audit only.
        face.axis==3 && face.fixed==0.0 && (r[end]+=s.weight*bn)
    end
    r[end]-=flux
    r
end

function axis_pressure_components_v9(data,p)
    mesh=data.mesh;cell=1;node=first(mesh.cell_nodes[cell]);vol=0.0;surface=0.0;volume=0.0
    for s in data.volume
        s.entity_id==cell || continue
        b=S.spatial_basis_v4(mesh,cell,s.q);a=only(findall(==(node),b.ids))
        grad=S._smr_rot(s.phi)*transpose(s.Einv)*b.dN_dq
        vol+=p*s.weight*grad[3,a];volume+=s.weight
    end
    for s in data.face_quadrature
        face=mesh.faces[s.entity_id]
        for (side,sign) in ((face.left_cell,1.0),(face.right_cell,-1.0))
            side==cell || continue
            b=S.spatial_basis_v4(mesh,cell,s.q);a=only(findall(==(node),b.ids))
            surface-=p*sign*s.weight*b.N[a]*s.normal[3]
        end
    end
    row=mesh.cell_row_start[cell]+2
    (cell=cell,node=node,row=row,block=mesh.row_blocks[row],supports=Tuple(mesh.row_supports[row]),
        volume_m3=volume,volume_contribution_N=vol,boundary_contribution_N=surface,sum_N=vol+surface)
end

function quadrature_audit_v9(context,result,out)
    mkpath(out);c=only(result.cases);d=result.declaration;input=d.source.input
    data=S.load_spatial_data_v4(d,c);samples=S.spatial_manufactured_geometry_samples_v1(input)
    frozen_scales=S._smr_row_scales(d,data)
    primary=S._smr_read_canonical_json_v1(read(c.artifacts.solver_primary.path,String))
    records=NamedTuple[]
    for rule in AUDIT_RULES_V9
        moments=Tuple((degree=k,observed=sum(rule.weights[i]*rule.roots[i]^k for i in eachindex(rule.roots)),
            exact=iseven(k) ? 2.0/(k+1) : 0.0) for k in 0:(2*rule.order-1))
        observed_data=audit_data_v9(data,rule);audit_d=diagnostic_declaration_v9(d,rule.order)
        source=N.source_v2;traction=N.traction_v2;normal=N.normal_v2
        reference=S.assemble_spatial_system_v4(audit_d,observed_data,samples.reference_state;
            flux_Wb=c.flux_Wb,jacobian=false,source_function=source,boundary_function=traction,normal_field_function=normal)
        solved=S.assemble_spatial_system_v4(audit_d,observed_data,collect(c.final_state);
            flux_Wb=c.flux_Wb,jacobian=false,source_function=source,boundary_function=traction,normal_field_function=normal)
        exact=analytic_weak_rows_v9(observed_data,c.flux_Wb)
        pressure=1.0e5;constant=zeros(length(c.final_state));constant[4:4:end].=pressure
        control=S.assemble_spatial_system_v4(audit_d,observed_data,constant;flux_Wb=c.flux_Wb,jacobian=false,
            source_function=xyz->(0.0,0.0,0.0),boundary_function=(xyz,n)->-pressure.*collect(n),
            normal_field_function=(xyz,n)->0.0)
        components=axis_pressure_components_v9(observed_data,pressure)
        qsin=sum(rule.weights[i]*sin(pi*(1+rule.roots[i])/2) for i in eachindex(rule.roots))*pi/2
        prediction=pressure*3.0*0.5*pi/2*(1-qsin/2)
        row=components.row
        record=(schema="test-only-fixed-quadrature-audit-v9",candidate_identity_not_issued=true,
            formal_candidate_credit=false,physics_credit=false,flux_acceptance=false,rule=rule,moments=moments,
            source_sha256=M.sha(S._SMR_SOURCE),provider_sha256=M.sha(S._SMM_SOURCE_V1),
            audit_source_sha256=M.sha(abspath(@__FILE__)),retained_formula_sha256=M.sha(joinpath(@__DIR__,"n1_manufactured_refinement_v2.jl")),
            production_candidate_hash=context.candidate_hash,production_result_hash=canonical_hash(result),
            production_declaration_hash=canonical_hash(d),test_only_declaration=audit_d,
            raw_reference_rows=Tuple(reference.residual),raw_solved_rows=Tuple(solved.residual),
            raw_analytic_continuum_rows=Tuple(exact),raw_constant_pressure_rows=Tuple(control.residual),
            original_GL3_row_scales=Tuple(frozen_scales),rule_row_scales=Tuple(reference.row_scales),
            row_blocks=Tuple(reference.row_blocks),row_supports=Tuple(Tuple(v) for v in reference.row_supports),
            control_axis_components=components,control_predicted_row_N=prediction,
            control_actual_row_N=control.residual[row],control_actual_row_scale_N=control.row_scales[row],
            control_momentum_scaled_max=maximum(abs(control.residual[i]/control.row_scales[i]) for i in eachindex(control.residual) if control.row_blocks[i]==:momentum_N),
            retained_positive_flux_Wb=c.flux_Wb,control_flux_residual_Wb=control.residual[end],
            quadrature_error_bound_certified=false,adaptive_rule_selection=false,production_rule_unchanged=3,
            numerical_threshold_unchanged=1.0e-6,authority=:no_publish,physical_validation=:unsupported)
        write_new_json(joinpath(out,"GL$(rule.order)_primary.json"),record)
        # Every actual primary above is retained before any diagnostic assertion.
        @testset "fixed GL$(rule.order) diagnostic integrity only" begin
            @test all(m->abs(m.observed-m.exact)<=2.0e-14,moments)
            @test all(>(0.0),rule.weights) && length(rule.roots)==rule.order
            @test length(reference.residual)==length(solved.residual)==length(exact)==length(control.residual)==289
            @test reference.row_blocks==solved.row_blocks==control.row_blocks==data.mesh.row_blocks
            @test all(isfinite,vcat(reference.residual,solved.residual,exact,control.residual))
            @test row==3 && components.block==:momentum_N
            @test abs(control.residual[row]-components.sum_N)<=1.0e-7
            @test abs(control.residual[row]-prediction)<=1.0e-7
            @test c.flux_Wb>0.0 && control.residual[end]==-c.flux_Wb
            @test abs(control.residual[end]/control.row_scales[end])==1.0
            if rule.order==3
                @test Tuple(solved.residual)==Tuple(primary.raw_residual)
                @test Tuple(solved.row_scales)==Tuple(primary.row_scales)
                @test abs(control.residual[row]/control.row_scales[row])>d.solver.residual_tolerance
            end
        end
        push!(records,(order=rule.order,artifact_sha256=M.sha(joinpath(out,"GL$(rule.order)_primary.json")),
            reference_scaled_max=maximum(abs,reference.residual./frozen_scales),
            solved_scaled_max=maximum(abs,solved.residual./frozen_scales),
            analytic_continuum_scaled_max=maximum(abs,exact./frozen_scales),
            control_predicted_row_N=prediction,control_actual_row_N=control.residual[row]))
    end
    summary=(schema="test-only-four-fixed-rules-summary-v9",rules=Tuple(records),
        runtime_production_rule=3,selected_replacement_rule=nothing,adaptive_selection=false,
        formal_candidate_credit=false,solved_refinement=:not_executed,authority=:no_publish)
    write_new_json(joinpath(out,"complete.json"),summary)
    summary
end
