#= Independent spatial numerical verification and executed flux sensitivity.
The primary result is always nominal_coarse. Manufactured fields are isolated
software benchmarks and cannot replace any accepted spatial state or current.
=#
using FusionConceptAI, LinearAlgebra, SparseArrays, SHA, Serialization
import FusionConceptAI: semantic_view, canonical_hash

const _SVQ_REVISION = "spatial-verification-uq-v1"
const _SVQ_SOURCE = abspath(@__FILE__)
const _SVQ_ORACLE = normpath(joinpath(@__DIR__,"..","..","scripts","spatial_verification_oracle_v4.py"))
_svq_sha(path)=Digest256(bytes2hex(SHA.sha256(read(path))))
_svq_body(x)=NamedTuple{fieldnames(typeof(x))[1:end-1]}(ntuple(i->getfield(x,i),fieldcount(typeof(x))-1))

struct SpatialVerificationDeclarationV4
    revision::String
    independent_formulation::NamedTuple
    jacobian::NamedTuple
    manufactured_solution::NamedTuple
    propagation::NamedTuple
    validation::NamedTuple
end
semantic_view(x::SpatialVerificationDeclarationV4)=NamedTuple{fieldnames(typeof(x))}(Tuple(getfield(x,k) for k in fieldnames(typeof(x))))

function spatial_verification_declaration_v4()
    SpatialVerificationDeclarationV4(_SVQ_REVISION,
        (implementation=:independent_python_Q1_cylindrical_geometry,
         momentum_identity="div(T)=curl(B)/mu0 cross B + B*div(B)/mu0 - grad(p)",
         oracle_relative_tolerance=1e-8,oracle_absolute_scaled_tolerance=1e-8,
         circuit_absolute_current_A=1e-12,circuit_absolute_energy_J=1e-15,
         circuit_absolute_flux_Wb=1e-15,circuit_absolute_voltage_V=1e-12,
         circuit_relative_tolerance=1e-9,
         interpretation=:same_raw_geometry_independent_field_and_assembly_not_physical_validation),
        (method=:full_local_structural_coloring_and_independent_linear_flux_row,
         relative_column_tolerance=1e-6,absolute_scaled_column_tolerance=1e-8,
         magnetic_state_reference_T=1.0,pressure_state_reference_Pa=1000.0,
         step_rule=:cbrt_eps_times_max_abs_state_or_declared_unit_reference,
         scope=:every_state_column_and_each_physical_row_block,
         scale_source="Declared numerical conditioning scales, not physical uncertainties"),
        (field=:affine_cartesian_solenoidal_B_and_affine_pressure,
         B0_T=(0.2,-0.1,0.3),cross_slopes_T_m=(0.02,-0.015,0.01),
         pressure_offset_Pa=500.0,pressure_gradient_Pa_m=(4.0,-3.0,2.0),
         source=:analytic_divergence_of_maxwell_cauchy_stress,
         boundary=:analytic_traction_and_normal_field,
         levels=(:coarse,:fine),physical_validation_credit=0,
         uniqueness_or_solution_convergence_claim=false),
        (parameter=:toroidal_flux_Wb,interval_owner=:G2_spatial_declaration,
         cases=("nominal_coarse","flux_low_coarse","flux_high_coarse"),
         method=:actual_spatial_solves_and_actual_current_to_engineering_outputs,
         distribution=:none,confidence_interval=:unsupported,
         failed_endpoint_interpretation=:conditional_failed_state_range_only),
        (status=:unsupported,experimental_dataset_count=0,
         independent_physical_solver=false,model_discrepancy_basis=false,
         recovery="Applicable independent observations or an independent physical solver, uncertainty and discrepancy evidence; software benchmarks cannot supply them."))
end

"""Greedy coloring of complete declared row supports, including numerical zeros."""
function spatial_jacobian_coloring_v4(row_supports,ncolumns)
    rows_for_column=[Int[] for _ in 1:ncolumns]
    normalized=[sort!(unique(Int.(collect(s)))) for s in row_supports]
    for (row,support) in enumerate(normalized), column in support
        1<=column<=ncolumns || throw(ArgumentError("Jacobian support outside declared state"))
        push!(rows_for_column[column],row)
    end
    colors=zeros(Int,ncolumns)
    ordering=sortperm(1:ncolumns;by=c->-length(rows_for_column[c]))
    for column in ordering
        forbidden=Set{Int}()
        for row in rows_for_column[column], neighbor in normalized[row]
            colors[neighbor]>0 && push!(forbidden,colors[neighbor])
        end
        color=1
        while color in forbidden;color+=1;end
        colors[column]=color
    end
    for support in normalized
        length(unique(colors[support]))==length(support) || throw(ArgumentError("invalid derivative coloring overlap"))
    end
    (colors=colors,row_supports=normalized,rows_for_column=rows_for_column,
     color_count=maximum(colors;init=0),empty_columns=Tuple(findall(isempty,rows_for_column)))
end

"""Finite differences reconstruct every structural entry and gate each column/block.

Residual rows must be scaled by their declared physical-block units. Column
scales convert B and pressure perturbations to dimensionless comparisons.
The production residual callback is independent of its analytic Jacobian.
"""
function verify_spatial_jacobian_v4(residual_function,state,jacobian,row_scales,row_blocks,row_supports;
        declaration=spatial_verification_declaration_v4(),independent_linear_rows=Dict{Int,Vector{Float64}}())
    x=Float64.(collect(state)); n=length(x); m=length(row_scales)
    J=sparse(jacobian); size(J)==(m,n) || throw(ArgumentError("full spatial Jacobian dimensions mismatch"))
    length(row_blocks)==m && length(row_supports)==m || throw(ArgumentError("row block/support ledger incomplete"))
    scales=Float64.(collect(row_scales)); all(s->isfinite(s)&&s>0,scales) || throw(ArgumentError("invalid row scales"))
    independent_rows=sort!(collect(keys(independent_linear_rows)))
    all(row->1<=row<=m && length(independent_linear_rows[row])==n,independent_rows) || throw(ArgumentError("incomplete independent linear row"))
    local_supports=[row in independent_rows ? Int[] : collect(row_supports[row]) for row in 1:m]
    coloring=spatial_jacobian_coloring_v4(local_supports,n)
    units=Float64[mod1(j,4)==4 ? declaration.jacobian.pressure_state_reference_Pa :
        declaration.jacobian.magnetic_state_reference_T for j in 1:n]
    steps=cbrt(eps(Float64)).*max.(abs.(x),units)
    r0=Float64.(residual_function(x));length(r0)==m || throw(ArgumentError("residual does not contain every row"))
    entries_i=Int[];entries_j=Int[];entries_v=Float64[]
    unowned_change=0.0
    for color in 1:coloring.color_count
        columns=findall(==(color),coloring.colors)
        plus=copy(x);minus=copy(x)
        for j in columns;plus[j]+=steps[j];minus[j]-=steps[j];end
        difference=(Float64.(residual_function(plus))-Float64.(residual_function(minus)))./2
        touched=falses(m);touched[independent_rows].=true
        for j in columns, row in coloring.rows_for_column[j]
            push!(entries_i,row);push!(entries_j,j);push!(entries_v,difference[row]/steps[j]);touched[row]=true
        end
        any(.!touched) && (unowned_change=max(unowned_change,maximum(abs,difference[.!touched]./scales[.!touched];init=0.0)))
    end
    for row in independent_rows,j in 1:n
        push!(entries_i,row);push!(entries_j,j);push!(entries_v,independent_linear_rows[row][j])
    end
    fd=sparse(entries_i,entries_j,entries_v,m,n)
    ir,jc,vals=findnz(J)
    all(k->iszero(vals[k]) || jc[k] in row_supports[ir[k]],eachindex(vals)) ||
        throw(ArgumentError("analytic Jacobian entry outside declared structural support"))
    block_symbols=Symbol.(row_blocks);blocks=unique(block_symbols)
    block_indices=Dict(block=>findall(==(block),block_symbols) for block in blocks)
    column_records=NamedTuple[]
    absolute_tol=declaration.jacobian.absolute_scaled_column_tolerance
    relative_tol=declaration.jacobian.relative_column_tolerance
    for j in 1:n
        reference=Vector(J[:,j])./scales.*units[j]
        observed=Vector(fd[:,j])./scales.*units[j]
        errors=observed-reference; baseline=norm(reference);absolute=norm(errors)
        details=Tuple(begin
            selected=block_indices[block]; refnorm=norm(reference[selected]); errnorm=norm(errors[selected])
            (block=block,reference_norm=refnorm,error_norm=errnorm,
             relative_error=refnorm>0 ? errnorm/refnorm : nothing,
             status=errnorm<=absolute_tol+relative_tol*refnorm ? :pass : :fail)
        end for block in blocks)
        push!(column_records,(column=j,node=cld(j,4),component=mod1(j,4),step=steps[j],
            reference_norm=baseline,absolute_error=absolute,
            relative_error=baseline>0 ? absolute/baseline : nothing,
            status=absolute<=absolute_tol+relative_tol*baseline && all(d->d.status===:pass,details) ? :pass : :fail,
            blocks=details))
    end
    passed=all(r->r.status===:pass,column_records) && unowned_change<=absolute_tol
    (executed=true,status=passed ? :pass : :fail,columns=n,rows=m,
     color_count=coloring.color_count,residual_evaluations=1+2coloring.color_count,
     all_columns_covered=true,empty_structural_columns=coloring.empty_columns,
     independent_linear_rows=Tuple(independent_rows),
     column_records=Tuple(column_records),relative_column_tolerance=relative_tol,
     absolute_scaled_column_tolerance=absolute_tol,unowned_scaled_change=unowned_change,
     sparse_finite_difference=fd,pattern_hash=canonical_hash(Tuple(Tuple(s) for s in row_supports)),
     physical_validation_credit=0)
end

_svq_artifact(path,schema,rows)=SpatialArtifactV4(abspath(path),_svq_sha(path),schema,rows)
function _svq_owned_declaration(context)
    validate_spatial_candidate_v4(context)
    declarations=Tuple(x for x in context.candidate.realization_control_genome_ref.control if x isa SpatialVerificationDeclarationV4)
    length(declarations)==1 || throw(ArgumentError("one G3 spatial verification declaration required"))
    d=only(declarations)
    canonical_hash(d)==canonical_hash(spatial_verification_declaration_v4()) || throw(ArgumentError("unsupported spatial verification declaration"))
    d
end

function _svq_oracle_request(context,c,data,a,d,mu0)
    mesh=data.mesh
    (schema="spatial_oracle_input_v1",candidate_hash=string(context.candidate_hash),
     context_hash=string(context.context_hash),case_id=c.case_id,state_hash=string(c.state_hash),
     raw_artifacts=c.raw_artifacts,state=c.final_state,flux_Wb=c.flux_Wb,mu0=mu0,
     row_blocks=Tuple(a.row_blocks),row_scales=Tuple(a.row_scales),manufactured=d.manufactured_solution,
     execute_manufactured=c.case_id in ("nominal_coarse","nominal_fine"),
     mesh=(cell_nodes=Tuple(Tuple(v) for v in mesh.cell_nodes),
           corner_to_local=Tuple(Tuple(v) for v in mesh.corner_to_local),cell_bounds=Tuple(mesh.cell_bounds),
           cell_row_start=Tuple(mesh.cell_row_start),faces=Tuple(mesh.faces),
           exterior_row_start=Tuple((face=k,row=mesh.exterior_row_start[k]) for k in sort!(collect(keys(mesh.exterior_row_start))))))
end

function _svq_csv(path,header)
    lines=readlines(path);!isempty(lines)&&first(lines)==header || throw(ArgumentError("independent oracle schema mismatch"))
    split.(lines[2:end],',')
end

function _svq_mms_columns(rows,row_blocks)
    length(rows)==length(row_blocks) && all(length(z)==6&&parse(Int,z[1])==i&&z[2]==string(row_blocks[i]) for (i,z) in enumerate(rows)) ||
        error("MMS oracle row/column coverage mismatch")
    parsed=NamedTuple{(:interpolated_weak,:interpolated_strong,:analytic_weak,:analytic_strong)}(
        Tuple(parse.(Float64,getindex.(rows,column)) for column in 3:6))
    all(column_values->all(isfinite,column_values),values(parsed)) || error("MMS oracle contains nonfinite residual values")
    parsed
end

function _svq_mms_source_status(metrics)
    key="manufactured.analytic.source_weighted_l2_N_per_m3_sqrt_m3"
    haskey(metrics,key) || error("independent MMS source norm missing")
    source_norm=metrics[key]
    isfinite(source_norm)&&source_norm>=0 || error("independent MMS source norm invalid")
    (norm=source_norm,nonzero=source_norm>0)
end

function _svq_validate_oracle_request(artifact,expected)
    validate_spatial_artifact_v4(artifact)
    read(artifact.path,String)==FusionConceptAI.canonical_json(expected)*"\n" ||
        throw(ArgumentError("independent oracle request was not bound to actual physical state/geometry"))
    true
end

function _svq_compare_residual(production,independent,scales,blocks,d)
    length(production)==length(independent)==length(scales)==length(blocks) || throw(ArgumentError("independent residual row coverage mismatch"))
    all(isfinite,independent) || throw(ArgumentError("nonfinite independent residual"))
    records=Tuple(begin
        ids=findall(==(block),blocks);difference=(independent[ids]-production[ids])./scales[ids]
        reference=production[ids]./scales[ids]
        absnorm=norm(difference);refnorm=norm(reference)
        limit=d.independent_formulation.oracle_absolute_scaled_tolerance+d.independent_formulation.oracle_relative_tolerance*refnorm
        (block=block,unit=endswith(string(block),"_N") ? "N" : "Wb",row_count=length(ids),
         absolute_difference_norm=norm(independent[ids]-production[ids]),
         scaled_difference_norm=absnorm,scaled_reference_norm=refnorm,
         maximum_scaled_difference=maximum(abs,difference;init=0.),acceptance_limit=limit,
         status=absnorm<=limit ? :pass : :fail)
    end for block in unique(blocks))
    (executed=true,status=all(x->x.status===:pass,records) ? :pass : :fail,rows=length(production),
     blocks=records,interpretation=:independent_same_geometry_same_quadrature_implementation_check,
     physical_validation_credit=0)
end

function _svq_analytic_mms(x,mu0,m)
    alpha,beta,gamma=m.cross_slopes_T_m
    B=collect(m.B0_T)+[alpha*x[2],beta*x[3],gamma*x[1]]
    p=m.pressure_offset_Pa+dot(collect(m.pressure_gradient_Pa_m),collect(x))
    J=[-beta,-gamma,-alpha]./mu0
    source=cross(J,B)-collect(m.pressure_gradient_Pa_m)
    stress=(B*transpose(B)-dot(B,B)*Matrix{Float64}(I,3,3)/2)./mu0-p.*Matrix{Float64}(I,3,3)
    (B=B,p=p,J=J,source=source,stress=stress)
end

function _svq_case(context,c,physics,d,python,dir)
    println("SPATIAL_VERIFICATION_BEGIN case=$(c.case_id) columns=$(length(c.final_state))");flush(stdout)
    mkpath(dir);data=load_spatial_data_v4(physics.declaration,c)
    a=assemble_spatial_system_v4(physics.declaration,data,c.final_state;flux_Wb=c.flux_Wb)
    mu0=only(filter(x->x.name===:mu0,physics.declaration.parameters)).value
    request=_svq_oracle_request(context,c,data,a,d,mu0)
    inputpath=joinpath(dir,"oracle_input.json");write(inputpath,FusionConceptAI.canonical_json(request)*"\n")
    stdoutpath=joinpath(dir,"oracle.stdout.txt");stderrpath=joinpath(dir,"oracle.stderr.txt")
    cmd=Cmd([python,_SVQ_ORACLE,inputpath,dir])
    process=open(stdoutpath,"w") do out
        open(stderrpath,"w") do err;run(pipeline(ignorestatus(cmd),stdout=out,stderr=err));end
    end
    exitpath=joinpath(dir,"oracle.process.exitcode");write(exitpath,"$(process.exitcode)\n")
    process.exitcode==0 || error("independent spatial oracle exit $(process.exitcode); see $stderrpath")
    parse(Int,strip(read(joinpath(dir,"oracle.exitcode"),String)))==process.exitcode || error("oracle exit artifact mismatch")
    rows=_svq_csv(joinpath(dir,"actual_residual.csv"),"row,block,independent_weak,independent_strong")
    length(rows)==length(a.residual) && all(parse(Int,z[1])==i&&z[2]==string(a.row_blocks[i]) for (i,z) in enumerate(rows)) || error("independent residual ownership mismatch")
    independent=parse.(Float64,getindex.(rows,3));strong=parse.(Float64,getindex.(rows,4))
    comparison=_svq_compare_residual(a.residual,independent,a.row_scales,a.row_blocks,d)
    fluxrows=_svq_csv(joinpath(dir,"flux_jacobian.csv"),"column,derivative_Wb_per_state_unit")
    length(fluxrows)==length(c.final_state)&&all(parse(Int,z[1])==i for (i,z) in enumerate(fluxrows)) || error("independent flux Jacobian columns missing")
    fluxderivative=parse.(Float64,getindex.(fluxrows,2))
    residual(x)=assemble_spatial_system_v4(physics.declaration,data,x;flux_Wb=c.flux_Wb,jacobian=false).residual
    derivative=verify_spatial_jacobian_v4(residual,c.final_state,a.jacobian,a.row_scales,a.row_blocks,a.row_supports;
        declaration=d,independent_linear_rows=Dict(length(a.residual)=>fluxderivative))
    println("SPATIAL_VERIFICATION_DERIVATIVES case=$(c.case_id) columns=$(derivative.columns) colors=$(derivative.color_count) status=$(derivative.status)");flush(stdout)
    fdpath=joinpath(dir,"independent_full_jacobian.csv")
    open(fdpath,"w") do io
        println(io,"row,column,value");ir,jc,v=findnz(derivative.sparse_finite_difference)
        for i in eachindex(v);println(io,"$(ir[i]),$(jc[i]),$(v[i])");end
    end
    kept=Tuple(k for k in keys(derivative) if k!==:sparse_finite_difference)
    derivative_record=NamedTuple{kept}(Tuple(getproperty(derivative,k) for k in kept))
    metrics=Dict(z[1]=>parse(Float64,z[2]) for z in _svq_csv(joinpath(dir,"metrics.csv"),"name,value"))
    strongweak=Tuple(begin
        ids=findall(==(block),a.row_blocks)
        (block=block,unit=endswith(string(block),"_N") ? "N" : "Wb",
         weak_norm=norm(independent[ids]),strong_norm=norm(strong[ids]),
         identity_difference_norm=norm(independent[ids]-strong[ids]),
         scaled_identity_difference_norm=norm((independent[ids]-strong[ids])./a.row_scales[ids]))
    end for block in unique(a.row_blocks))
    manufactured=if request.execute_manufactured
        state_rows=_svq_csv(joinpath(dir,"manufactured_state.csv"),"column,value")
        length(state_rows)==length(c.final_state)&&all(parse(Int,z[1])==i for (i,z) in enumerate(state_rows)) || error("MMS software state coverage incomplete")
        xm=parse.(Float64,getindex.(state_rows,2));flux=metrics["manufactured.flux_Wb"]
        source(x)=_svq_analytic_mms(x,mu0,d.manufactured_solution).source
        traction(x,n)=_svq_analytic_mms(x,mu0,d.manufactured_solution).stress*collect(n)
        normalfield(x,n)=dot(_svq_analytic_mms(x,mu0,d.manufactured_solution).B,collect(n))
        am=assemble_spatial_system_v4(physics.declaration,data,xm;flux_Wb=flux,jacobian=false,
             source_function=source,boundary_function=traction,normal_field_function=normalfield)
        mr=_svq_csv(joinpath(dir,"manufactured_residual.csv"),"row,block,interpolated_weak,interpolated_strong,analytic_weak,analytic_strong")
        columns=_svq_mms_columns(mr,am.row_blocks)
        mc=_svq_compare_residual(am.residual,columns.interpolated_weak,am.row_scales,am.row_blocks,d)
        source_status=_svq_mms_source_status(metrics)
        source_norm=source_status.norm;source_nonzero=source_status.nonzero
        path=joinpath(dir,"manufactured_production_residual.csv")
        open(path,"w") do io
            println(io,"row,block,residual,scale")
            for i in eachindex(am.residual);println(io,"$i,$(am.row_blocks[i]),$(am.residual[i]),$(am.row_scales[i])");end
        end
        (executed=true,status=mc.status===:pass&&source_nonzero ? :pass : :fail,
         solver_exit_code=mc.status===:pass&&source_nonzero ? 0 : 1,level=c.level,
         method=:independent_analytic_source_and_curved_Q1_interpolant,
         implementation_comparison=mc,oracle_residual_columns_complete=true,oracle_residual_columns_finite=true,
         oracle_residual_column_norms=(interpolated_weak=norm(columns.interpolated_weak),
             interpolated_strong=norm(columns.interpolated_strong),analytic_weak=norm(columns.analytic_weak),
             analytic_strong=norm(columns.analytic_strong)),
         independent_source_weighted_l2_N_per_m3_sqrt_m3=source_norm,source_nonzero=source_nonzero,
         independent_metrics=Tuple((name=k,value=metrics[k]) for k in sort!(collect(keys(metrics))) if startswith(k,"manufactured.")),
         state_hash=canonical_hash(Tuple(xm)),flux_Wb=flux,solution_solve_executed=false,
         solution_convergence_order=:unsupported,physical_validation_credit=0,
         interpretation="Two actual curved spaces execute analytic-source weak/strong diagnostics and interpolation checks. MMS data never replace the candidate. No solved MMS convergence order is asserted.")
    else
        (executed=false,status=:not_requested_for_endpoint_cases,recovery="MMS executes on both nominal mesh levels, without duplicate endpoint geometry benchmarks.")
    end
    ok=comparison.status===:pass&&derivative_record.status===:pass&&(!manufactured.executed||manufactured.status===:pass)
    files=sort!(filter(isfile,readdir(dir;join=true)))
    artifacts=Tuple(_svq_artifact(p,"spatial-verification-"*basename(p),countlines(p)) for p in files)
    (case_id=c.case_id,level=c.level,candidate_hash=c.candidate_hash,context_hash=c.context_hash,
     state_hash=c.state_hash,physics_case_hash=canonical_hash(c),executed=true,solver_exit_code=ok ? 0 : 1,
     status=ok ? :pass : :fail,oracle_exit_code=process.exitcode,oracle_command=string(cmd),
     independent_residual=comparison,full_jacobian=derivative_record,
     strong_weak=(executed=true,blocks=strongweak,
          B_divB_term_momentum_norm_N=metrics["actual.B_divB_term_momentum_norm_N"],
          maximum_shared_trace_difference_T=metrics["actual.maximum_shared_trace_difference_T"],
          interpretation="At fixed supplied geometry/quadrature, independent strong and weak implementations include B*divB/mu0 and all numerical boundary corrections. Their difference is a consistency diagnostic; it is not a certified isolated integration error."),
     manufactured=manufactured,physics_status=c.status,physics_solver_exit_code=c.solver_exit_code,
     stopping_reason=c.stopping_reason,solver_diagnostics=c.diagnostics,
     upstream_valid=false,physical_validation_credit=0,artifacts=artifacts)
end

function spatial_flux_propagation_v4(physics,engineering)
    ids=("nominal_coarse","flux_low_coarse","flux_high_coarse")
    physical=Tuple(only(filter(c->c.case_id==id,physics.cases)) for id in ids)
    electrical=Tuple(only(filter(c->c.case_id==id,engineering.cases)) for id in ids)
    rows=Tuple(begin
        p,e=physical[i],electrical[i]
        p.executed&&e.executed&&p.state_hash==e.state_hash&&p.candidate_hash==e.candidate_hash&&
            p.context_hash==e.context_hash&&e.input_hash==canonical_hash(p.engineering_input) || error("flux propagation lacks same-case actual current binding")
        e.conditional.nominal.executed&&e.conditional.readout_short.executed || error("conditional circuits not executed")
        e.static.induced_emf_V==0. || error("static spatial state cannot justify induced emf")
        (case_id=p.case_id,flux_parameter_Wb=p.flux_Wb,state_hash=p.state_hash,
         physics_case_hash=canonical_hash(p),engineering_case_hash=canonical_hash(e),
         physics_executed=p.executed,physics_status=p.status,physics_solver_exit_code=p.solver_exit_code,
         stopping_reason=p.stopping_reason,scaled_residual_norm=p.diagnostics.scaled_norm,
         actual_current_input_hash=e.input_hash,engineering_executed=e.executed,
         engineering_status=e.status,engineering_solver_exit_code=e.solver_exit_code,
         static_flux_linkage_Wb=e.static.flux_linkage_Wb,static_induced_emf_V=e.static.induced_emf_V,
         conditional_nominal=e.conditional.nominal.metrics,conditional_short=e.conditional.readout_short.metrics,
         transfer=e.transfer.status,current_closure=e.current_closure,upstream_valid=false,
         engineering_applicability=:unsupported)
    end for i in eachindex(ids))
    properties=(:current_peak_A,:branch_voltage_peak_V,:induced_emf_peak_V,:flux_change_estimate_Wb,:joule_energy_J)
    ranges=Tuple(begin
        values=Float64[getproperty(row.conditional_nominal,key) for row in rows]
        (observable=key,min=minimum(values),max=maximum(values),
         endpoint_secant=(values[3]-values[2])/(rows[3].flux_parameter_Wb-rows[2].flux_parameter_Wb))
    end for key in properties)
    fluxes=Tuple(row.static_flux_linkage_Wb for row in rows)
    (executed=true,status=:executed_conditional,solver_exit_code=0,parameter=physics.declaration.flux,
     cases=rows,primary_case_id="nominal_coarse",static_flux_range_Wb=(minimum(fluxes),maximum(fluxes)),
     static_flux_endpoint_secant=(fluxes[3]-fluxes[2])/(rows[3].flux_parameter_Wb-rows[2].flux_parameter_Wb),
     conditional_ranges=ranges,distribution=:none,confidence_interval=:unsupported,
     physical_validation_credit=0,upstream_valid=false,
     interpretation="Each declared toroidal-flux endpoint is actually solved and its actual curl(B)/sheet input is propagated through finite-aperture transfer and circuits. Failed states yield only conditional sampled ranges and secants; no probability, certified global bound or robustness claim.")
end

"Independent 256-bit exponential RL and integral replay on every actual scenario."
function verify_spatial_circuit_v4(response,engineering_declaration;declaration=spatial_verification_declaration_v4())
    names=Tuple(p.name for p in engineering_declaration.parameters)
    p=NamedTuple{names}(Tuple(z.value for z in engineering_declaration.parameters))
    setprecision(BigFloat,256) do
        L=BigFloat(p.inductance_H);Rwire=BigFloat(p.resistivity_ohm_m)*2*big(pi)*BigFloat(p.radius_m)*BigFloat(p.turns)/(big(pi)*BigFloat(p.wire_radius_m)^2)
        cadence=p.detection_cadence_s;n=round(Int,p.duration_s/cadence)
        length(response.trajectory)==n+1 || error("circuit oracle requires the complete trajectory")
        emf_ramp=-BigFloat(response.static_flux_linkage_input_Wb)*BigFloat(p.ramp_fraction)/BigFloat(p.ramp_duration_s)
        current=BigFloat(0);energy=BigFloat(0);joule=BigFloat(0);estimate=BigFloat(0)
        maximum_segment_energy_error=BigFloat(0)
        latched=false;trip=nothing;maximum_current_error=0.;maximum_estimate_error=0.;controls_agree=true
        peak_current=BigFloat(0);peak_voltage=BigFloat(0);previous_branch=BigFloat(p.load_resistance_ohm)
        for k in 1:n
            t0=(k-1)*cadence;t1=k*cadence;h=BigFloat(t1-t0)
            shorted=response.fault===:load_short&&t0>=p.short_time_s
            branch=BigFloat(latched ? p.dump_resistance_ohm : (shorted ? p.short_resistance_ohm : p.load_resistance_ohm))
            connected=!latched;R=Rwire+branch;emf=(t0+t1)/2<p.ramp_duration_s ? emf_ramp : BigFloat(0)
            # Direct high-precision antiderivatives differ from the production
            # small-u moment expansions; cancellation is resolved by precision.
            rate=R/L;steady=emf/R;amplitude=current-steady
            decay=exp(-rate*h);next=steady+amplitude*decay
            integral_i=steady*h+amplitude*(1-decay)/rate
            integral_i2=steady^2*h+2*steady*amplitude*(1-decay)/rate+amplitude^2*(1-decay^2)/(2*rate)
            energy+=emf*integral_i;joule+=R*integral_i2
            maximum_segment_energy_error=max(maximum_segment_energy_error,
                abs(emf*integral_i-R*integral_i2-L*(next^2-current^2)/2))
            connected&&(estimate-=branch*integral_i)
            peak_current=max(peak_current,abs(current),abs(next))
            peak_voltage=max(peak_voltage,abs(previous_branch*current),abs(branch*current),abs(branch*next))
            if !latched&&abs(next)>=BigFloat(p.trip_current_A);latched=true;trip=t1;end
            row=response.trajectory[k+1]
            maximum_current_error=max(maximum_current_error,abs(row.current_A-Float64(next)))
            maximum_estimate_error=max(maximum_estimate_error,abs(row.flux_change_estimate_Wb-Float64(estimate)))
            controls_agree&=row.time_s==t1&&row.branch_resistance_ohm==Float64(branch)&&row.readout_connected==connected&&row.relay_latched==latched
            current=next;previous_branch=branch
        end
        stored=L*current^2/2
        metrics=response.metrics
        reference=(input_energy_J=Float64(energy),joule_energy_J=Float64(joule),final_stored_energy_J=Float64(stored),
            current_peak_A=Float64(peak_current),branch_voltage_peak_V=Float64(peak_voltage),
            induced_emf_peak_V=Float64(abs(emf_ramp)),flux_change_estimate_Wb=Float64(estimate),trip_time_s=trip,
            energy_identity_error_J=Float64(energy-joule-stored),
            maximum_segment_energy_identity_error_J=Float64(maximum_segment_energy_error))
        relative=declaration.independent_formulation.circuit_relative_tolerance
        abstol=declaration.independent_formulation.circuit_absolute_current_A
        energytol=declaration.independent_formulation.circuit_absolute_energy_J
        fluxtol=declaration.independent_formulation.circuit_absolute_flux_Wb
        voltagetol=declaration.independent_formulation.circuit_absolute_voltage_V
        energy_errors=Tuple((observable=k,absolute_error=abs(getproperty(metrics,k)-getproperty(reference,k)),
            tolerance=energytol+relative*abs(getproperty(reference,k))) for k in
            (:input_energy_J,:joule_energy_J,:final_stored_energy_J,:energy_identity_error_J,:maximum_segment_energy_identity_error_J))
        pass=controls_agree&&isequal(metrics.trip_time_s,trip)&&maximum_current_error<=abstol+relative*Float64(peak_current)&&
            maximum_estimate_error<=fluxtol+relative*abs(Float64(estimate))&&
            abs(metrics.branch_voltage_peak_V-Float64(peak_voltage))<=voltagetol+relative*Float64(peak_voltage)&&
            abs(metrics.induced_emf_peak_V-Float64(abs(emf_ramp)))<=voltagetol+relative*Float64(abs(emf_ramp))&&
            all(z->z.absolute_error<=z.tolerance,energy_errors)
        (executed=true,status=pass ? :pass : :fail,solver_exit_code=pass ? 0 : 1,
            method=:independent_256_bit_exponential_antiderivatives,trajectory_count=n+1,
            maximum_current_error_A=maximum_current_error,maximum_flux_estimate_error_Wb=maximum_estimate_error,
            controls_agree=controls_agree,energy_errors=energy_errors,independent_metrics=reference,
            event_timing=:fixed_declared_detection_cadence,physical_validation_credit=0)
    end
end

struct SpatialVerificationResultV4
    candidate_hash::Digest256
    context_hash::Digest256
    declaration_hash::Digest256
    upstream_hash::Digest256
    physics_hash::Digest256
    engineering_hash::Digest256
    cases::Tuple
    numerical::NamedTuple
    uncertainty::NamedTuple
    physical_validation::NamedTuple
    executed::Bool
    solver_exit_code::Int
    status::Symbol
    upstream_validity::NamedTuple
    execution::NamedTuple
    result_hash::Digest256
end
semantic_view(x::SpatialVerificationResultV4)=_svq_body(x)
function canonical_hash(x::SpatialVerificationResultV4)
    x.executed&&x.solver_exit_code in (0,1)&&x.status in (:fail,:unsupported)&&
        x.physical_validation.status===:unsupported&&!x.upstream_validity.physical_qualification || error("spatial software verification cannot confer physical qualification")
    all(c->c.candidate_hash==x.candidate_hash&&c.context_hash==x.context_hash&&c.executed,x.cases) || error("spatial verification case identity mismatch")
    h=canonical_hash(semantic_view(x));h==x.result_hash || error("spatial verification result hash mismatch");h
end

function execute_spatial_verification_v4(context,upstream,physics,engineering,run_dir)
    d=_svq_owned_declaration(context)
    validate_spatial_result_v4(context,physics)
    validate_spatial_engineering_result_v4(context,physics,engineering)
    receipt=_smr_upstream(context,upstream)
    dir=abspath(run_dir);mkpath(dir)
    cases=Tuple(_svq_case(context,c,physics,d,receipt.python_executable,joinpath(dir,c.case_id)) for c in physics.cases)
    propagation=spatial_flux_propagation_v4(physics,engineering)
    engineering_declaration=only(filter(x->x isa SpatialPickupEngineeringDeclarationV4,context.candidate.realization_control_genome_ref.realization))
    circuits=Tuple((case_id=c.case_id,state_hash=c.state_hash,
        nominal=verify_spatial_circuit_v4(c.conditional.nominal,engineering_declaration;declaration=d),
        readout_short=verify_spatial_circuit_v4(c.conditional.readout_short,engineering_declaration;declaration=d),
        reciprocity=(executed=c.transfer.executed,status=c.transfer.status,
            absolute_difference_Wb=c.transfer.absolute_difference_Wb,
            relative_difference=c.transfer.relative_difference,
            independent_formulation=engineering_declaration.transfer.reciprocity,
            interpretation=:independent_vector_potential_formulation_at_same_actual_current_quadrature)) for c in engineering.cases)
    coarse=only(filter(c->c.case_id=="nominal_coarse",cases));fine=only(filter(c->c.case_id=="nominal_fine",cases))
    mmsmetrics(c)=Dict(z.name=>z.value for z in c.manufactured.independent_metrics)
    cm,fm=mmsmetrics(coarse),mmsmetrics(fine)
    keyscompare=sort!(intersect(collect(keys(cm)),collect(keys(fm))))
    mesh_differences=Tuple((observable=k,coarse=cm[k],fine=fm[k],fine_minus_coarse=fm[k]-cm[k],
            ratio=cm[k]!=0 ? fm[k]/cm[k] : nothing) for k in keyscompare if !endswith(k,"flux_Wb"))
    engineering_numerics_pass=all(c->c.nominal.status===:pass&&c.readout_short.status===:pass&&c.reciprocity.status===:pass,circuits)
    numerical=(status=all(c->c.status===:pass,cases)&&engineering_numerics_pass ? :pass : :fail,
        implemented=true,executed=true,full_spatial_columns_verified=true,
        engineering=circuits,
        integration=(status=:diagnostic_executed,method=:analytic_curved_MMS_weak_strong_identity,
            isolated_certified_error_bound=:unsupported,interpretation="Both spaces execute fixed-order quadrature on supplied curved metrics. Analytic identity defects diagnose integration/geometry consistency; no q5/q6 sequence or certified bound is claimed."),
        discretization=(status=:two_spaces_executed,manufactured_metrics=mesh_differences,
            solved_solution_error=:unsupported,physical_discretization_order=:unsupported,
            interpretation="Differences of independently interpolated analytic fields and weak moments are not solved-candidate discretization-error estimates. Failed nonlinear states cannot establish a mesh convergence order."),
        solver=(status=:actual_diagnostics_propagated,
            interpretation="Actual residual histories, feasibility, gradient, sparse QR rank estimates and stop codes remain solver diagnostics. No residual floor or optimality is inferred solely from stalled iterations."),
        model=(status=:unsupported,interpretation="No experiment, independent physical solver or discrepancy evidence; neither arithmetic agreement nor MMS grants physical validation."),
        physical_validation_credit=0)
    code=any(c->c.solver_exit_code!=0,cases)||!engineering_numerics_pass ? 1 : 0
    physical=(status=:unsupported,implemented=false,executed=false,experimental_dataset_count=0,
        independent_physical_solver_executed=false,model_discrepancy_implemented=false,
        recovery=d.validation.recovery,physical_validation_credit=0)
    jls=joinpath(dir,"spatial_numerical_and_propagation.jls")
    open(jls,"w") do io;serialize(io,(cases=cases,numerical=numerical,uncertainty=propagation));end
    exitpath=joinpath(dir,"verification.exitcode");write(exitpath,"$code\n")
    execution=(julia_version=string(VERSION),source=_svq_artifact(_SVQ_SOURCE,"julia-source",countlines(_SVQ_SOURCE)),
        oracle_source=_svq_artifact(_SVQ_ORACLE,"independent-python-source",countlines(_SVQ_ORACLE)),
        python_executable=_svq_artifact(receipt.python_executable,"python-executable",1),
        payload=_svq_artifact(jls,"serialized-spatial-numerics-v1",1),
        exit_artifact=_svq_artifact(exitpath,"integer-exit-code",1))
    body=(candidate_hash=context.candidate_hash,context_hash=context.context_hash,declaration_hash=canonical_hash(d),
        upstream_hash=canonical_hash(upstream),physics_hash=canonical_hash(physics),engineering_hash=canonical_hash(engineering),
        cases=cases,numerical=numerical,uncertainty=propagation,physical_validation=physical,
        executed=true,solver_exit_code=code,status=code!=0||physics.status===:fail||engineering.status===:fail ? :fail : :unsupported,
        upstream_validity=(physics_status=physics.status,physics_solver_exit_code=physics.solver_exit_code,
            engineering_status=engineering.status,engineering_solver_exit_code=engineering.solver_exit_code,
            physical_qualification=false),execution=execution)
    result=SpatialVerificationResultV4(values(body)...,canonical_hash(body));canonical_hash(result);result
end

function validate_spatial_verification_result_v4(context,upstream,physics,engineering,result::SpatialVerificationResultV4)
    d=_svq_owned_declaration(context);canonical_hash(result)
    result.candidate_hash==context.candidate_hash&&result.context_hash==context.context_hash&&result.declaration_hash==canonical_hash(d)&&
        result.upstream_hash==canonical_hash(upstream)&&result.physics_hash==canonical_hash(physics)&&result.engineering_hash==canonical_hash(engineering) || error("spatial verification upstream identity changed")
    result.execution.source.path==_SVQ_SOURCE&&result.execution.source.sha256==_svq_sha(_SVQ_SOURCE)&&
        result.execution.oracle_source.path==_SVQ_ORACLE&&result.execution.oracle_source.sha256==_svq_sha(_SVQ_ORACLE) || error("spatial verification source changed")
    for a in values(result.execution);a isa SpatialArtifactV4&&validate_spatial_artifact_v4(a);end
    Tuple(c.case_id for c in result.cases)==Tuple(c.case_id for c in physics.cases) || error("spatial verification case coverage mismatch")
    for (c,p) in zip(result.cases,physics.cases)
        c.state_hash==p.state_hash&&c.physics_case_hash==canonical_hash(p) || error("spatial verification case input mismatch")
        foreach(validate_spatial_artifact_v4,c.artifacts)
        c.full_jacobian.columns==length(p.final_state)&&c.full_jacobian.all_columns_covered || error("incomplete full-column verification")
        # Rebind the exact independently executed request to current physical
        # state/geometry/ownership. This does not rerun the oracle or differences.
        data=load_spatial_data_v4(physics.declaration,p)
        a=(row_blocks=data.mesh.row_blocks,row_scales=_smr_row_scales(physics.declaration,data))
        mu0=only(filter(x->x.name===:mu0,physics.declaration.parameters)).value
        expected=_svq_oracle_request(context,p,data,a,d,mu0)
        input_artifact=only(filter(a->basename(a.path)=="oracle_input.json",c.artifacts))
        _svq_validate_oracle_request(input_artifact,expected)
        c.full_jacobian.rows==length(data.mesh.row_blocks)&&
            c.full_jacobian.pattern_hash==canonical_hash(Tuple(Tuple(s) for s in data.mesh.row_supports)) || error("independent derivative structural ownership changed")
    end
    payload=open(deserialize,result.execution.payload.path)
    payload==(cases=result.cases,numerical=result.numerical,uncertainty=result.uncertainty) || error("spatial verification payload mismatch")
    parse(Int,strip(read(result.execution.exit_artifact.path,String)))==result.solver_exit_code || error("spatial verification exit mismatch")
    result
end
