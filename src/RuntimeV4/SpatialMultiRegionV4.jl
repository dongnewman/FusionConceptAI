# Full spatial Q1 static-MHD state execution on fresh DESC curved geometry.
using FusionConceptAI, LinearAlgebra, SparseArrays, SHA, Printf, JSON3
import FusionConceptAI: semantic_view, canonical_hash
include("SpatialBoundedLinearStepV1.jl")

const _SMR_SOURCE=abspath(@__FILE__)
const _SMR_LOADED_SOURCE_SHA=bytes2hex(SHA.sha256(read(_SMR_SOURCE)))
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
include("SpatialManufacturedInputV1.jl")

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

# This additive revision changes only explicitly declared, state-independent
# loads.  It does not select a pressure/current topology or provide an exterior
# field, sheet current, or return-current model.
const _SMR_DECLARED_LOAD_REVISION_V1="spatial-q1-static-mhd-declared-loads-v1"
const _SMR_BOUNDED_REVISION_V1="spatial-q1-static-mhd-bounded-step-v1"
const _SMR_LOAD_BOUNDED_REVISION_V1="spatial-q1-static-mhd-declared-loads-bounded-step-v1"
const _SMR_BOUNDED_SOURCE=joinpath(@__DIR__,"SpatialBoundedLinearStepV1.jl")
const _SMR_BOUNDED_SHA_V1=SpatialBoundedLinearStepV1.SOURCE_SHA256
_smr_has_loads(d)=d.revision in (_SMR_DECLARED_LOAD_REVISION_V1,_SMR_LOAD_BOUNDED_REVISION_V1)
_smr_has_bounded_step(d)=d.revision in (_SMR_BOUNDED_REVISION_V1,_SMR_LOAD_BOUNDED_REVISION_V1,_SMR_MANUFACTURED_REVISION_V1)

function _smr_bounded_identity_v1()
    identity=SpatialBoundedLinearStepV1.bounded_linear_step_identity_v1()
    identity.implementation_sha256==_SMR_BOUNDED_SHA_V1==string(_smr_sha(_SMR_BOUNDED_SOURCE)) ||
        throw(ArgumentError("bounded-step implementation source differs from frozen v1"))
    identity
end

# Construction is deliberately from an already canonical old declaration.
# A numerical method does not add any physical closure assumption.
function spatial_multiregion_bounded_step_v1(base::SpatialMultiRegionDeclarationV4)
    base.revision in ("spatial-q1-static-mhd-v1",_SMR_DECLARED_LOAD_REVISION_V1) ||
        throw(ArgumentError("bounded step requires a supported unchanged baseline"))
    validate_spatial_multiregion_declaration_v4(base)
    identity=_smr_bounded_identity_v1()
    revision=_smr_has_loads(base) ? _SMR_LOAD_BOUNDED_REVISION_V1 : _SMR_BOUNDED_REVISION_V1
    SpatialMultiRegionDeclarationV4(revision,base.regions,base.states,base.interfaces,base.source,base.boundary,
        base.spaces,base.flux,base.cases,base.parameters,base.quadrature,base.scaling,
        merge(base.solver,(method=identity.method,bounded_linear_step=identity)),base.applicability)
end

function _smr_check_bounded_method_v1(d)
    bounded=_smr_has_bounded_step(d)
    if bounded
        string(_smr_sha(_SMR_SOURCE))==_SMR_LOADED_SOURCE_SHA || throw(ArgumentError("spatial source changed after loading"))
        identity=_smr_bounded_identity_v1()
        d.solver.method==identity.method && hasproperty(d.solver,:bounded_linear_step) &&
            d.solver.bounded_linear_step==identity || throw(ArgumentError("invalid bounded-step solver identity"))
    else
        d.solver.method==:feasible_sparse_QR_gauss_newton && !hasproperty(d.solver,:bounded_linear_step) ||
            throw(ArgumentError("numerical method requires its explicit declaration revision"))
    end
    bounded
end

function _smr_load_scalar_v1(value,name)
    value isa Real && !(value isa Bool) || throw(ArgumentError("$name must be a real scalar"))
    result=try Float64(value) catch; throw(ArgumentError("$name must be representable in Float64"));end
    isfinite(result) || throw(ArgumentError("$name must be finite"))
    result
end
function _smr_load_vector_v1(value,name)
    (value isa Tuple || value isa AbstractVector) && length(value)==3 ||
        throw(ArgumentError("$name must have exactly three Cartesian components"))
    ntuple(i->_smr_load_scalar_v1(value[i],"$name[$i]"),3)
end
function _smr_load_provenance_v1(value,name)
    value isa AbstractString && !isempty(strip(value)) ||
        throw(ArgumentError("$name requires explicit nonempty provenance"))
    String(value)
end

"Create the narrow declared-load revision from an unchanged v1 baseline."
function spatial_multiregion_declared_loads_v1(base::SpatialMultiRegionDeclarationV4;
        source_xyz_N_m3,normal_B_T,source_provenance,boundary_provenance,
        source_unit="N m^-3",normal_field_unit="T")
    canonical_hash(base)==canonical_hash(spatial_multiregion_declaration_v4(flux_Wb=base.flux.nominal_Wb)) ||
        throw(ArgumentError("declared loads require the exact v1 baseline"))
    source_unit=="N m^-3" && normal_field_unit=="T" ||
        throw(ArgumentError("declared load units must be N m^-3 and T"))
    source=_smr_load_vector_v1(source_xyz_N_m3,"source_xyz_N_m3")
    normal=_smr_load_scalar_v1(normal_B_T,"normal_B_T")
    # This revision supports a constant normal field on a closed toroidal
    # boundary.  Its integrated flux is zero only for the explicit zero value.
    normal==0.0 || throw(ArgumentError("invalid_boundary: constant nonzero normal_B_T violates closed-boundary magnetic flux compatibility"))
    sp=_smr_load_provenance_v1(source_provenance,"source_provenance")
    bp=_smr_load_provenance_v1(boundary_provenance,"boundary_provenance")
    SpatialMultiRegionDeclarationV4(_SMR_DECLARED_LOAD_REVISION_V1,base.regions,base.states,base.interfaces,
        merge(base.source,(value_xyz_N_m3=source,source=sp,unit="N m^-3")),
        merge(base.boundary,(normal_B_T=normal,source=bp,normal_B_unit="T")),
        base.spaces,base.flux,base.cases,base.parameters,base.quadrature,base.scaling,base.solver,base.applicability)
end

function _smr_declared_load_values_v1(d::SpatialMultiRegionDeclarationV4)
    hasproperty(d.source,:equation) && d.source.equation=="div(T)=source" ||
        throw(ArgumentError("unsupported spatial source equation"))
    hasproperty(d.source,:value_xyz_N_m3) && hasproperty(d.source,:source) ||
        throw(ArgumentError("declared spatial source or provenance is absent"))
    hasproperty(d.boundary,:normal_B_T) && hasproperty(d.boundary,:source) ||
        throw(ArgumentError("declared normal field or provenance is absent"))
    source=_smr_load_vector_v1(d.source.value_xyz_N_m3,"source.value_xyz_N_m3")
    normal=_smr_load_scalar_v1(d.boundary.normal_B_T,"boundary.normal_B_T")
    _smr_load_provenance_v1(d.source.source,"source.source")
    _smr_load_provenance_v1(d.boundary.source,"boundary.source")
    # Legacy field names carry their fixed SI units.  Explicit unit fields,
    # when present, must agree; absence is not inferred for the new revision.
    (!hasproperty(d.source,:unit) || d.source.unit=="N m^-3") || throw(ArgumentError("invalid source unit"))
    (!hasproperty(d.boundary,:normal_B_unit) || d.boundary.normal_B_unit=="T") || throw(ArgumentError("invalid normal field unit"))
    if _smr_has_loads(d)
        hasproperty(d.source,:unit) && hasproperty(d.boundary,:normal_B_unit) ||
            throw(ArgumentError("declared-load revision requires explicit units"))
    end
    (source_xyz_N_m3=source,normal_B_T=normal)
end

"Authoritative production guard; numerical fixtures may use the low-level kernel."
function validate_spatial_multiregion_declaration_v4(d::SpatialMultiRegionDeclarationV4;
        flux_Wb=d.flux.nominal_Wb)
    if _smm_is_declaration_v1(d)
        validate_spatial_n1_manufactured_declaration_v1(d)
        flux_Wb==d.source.input.flux.nominal_Wb || throw(ArgumentError("manufactured flux identity mismatch"))
        return true
    end
    base=spatial_multiregion_declaration_v4(;flux_Wb)
    expected=if d.revision==base.revision
        base
    elseif _smm_is_g2_three_region_source_v1(d)
        validate_spatial_g2_three_region_source_declaration_v1(d)
        return true
    elseif _smr_has_loads(d)
        loads=_smr_declared_load_values_v1(d)
        loaded=spatial_multiregion_declared_loads_v1(base;source_xyz_N_m3=loads.source_xyz_N_m3,
            normal_B_T=loads.normal_B_T,source_provenance=d.source.source,boundary_provenance=d.boundary.source)
        _smr_has_bounded_step(d) ? spatial_multiregion_bounded_step_v1(loaded) : loaded
    elseif d.revision==_SMR_BOUNDED_REVISION_V1
        spatial_multiregion_bounded_step_v1(base)
    else
        throw(ArgumentError("spatial declaration revision not implemented"))
    end
    canonical_hash(d)==canonical_hash(expected) || throw(ArgumentError("spatial declaration differs from the supported version"))
    true
end

struct SpatialMeshV4
    level::Symbol; nfp::Int; nodes_q::Matrix{Float64}; cell_nodes::Vector{Vector{Int}}
    corner_to_local::Vector{Vector{Int}}; cell_bounds::Vector{NTuple{3,Tuple{Float64,Float64}}}
    cell_regions::Vector{Int}; faces::Vector{NamedTuple}; cell_row_start::Vector{Int}
    exterior_row_start::Dict{Int,Int}; row_blocks::Vector{Symbol}; row_supports::Vector{Vector{Int}}
end

function build_spatial_mesh_v4(d::SpatialMultiRegionDeclarationV4,level::Symbol,nfp::Int)
    s=only(filter(s->s.level==level,d.spaces));rhos=collect(s.rho);nt=s.theta_count;nz=s.zeta_per_period*nfp;nr=length(rhos)-1
    region_intervals=Tuple(region.rho for region in d.regions)
    isempty(region_intervals) && throw(ArgumentError("mesh declaration requires at least one radial region"))
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
        cell_rho=(rhos[ir+1],rhos[ir+2])
        region=findfirst(interval->interval[1]<=cell_rho[1] && cell_rho[2]<=interval[2],region_intervals)
        region===nothing && throw(ArgumentError("radial mesh cell crosses or lies outside declared region boundaries"))
        push!(cells,ids);push!(maps,cm);push!(bounds,(cell_rho,(it*2pi/nt,(it+1)*2pi/nt),(iz*2pi/nz,(iz+1)*2pi/nz)))
        push!(regions,region);cid[(ir,it,iz)]=length(cells)
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

"""Apply a candidate-bound G2 region declaration to matching source geometry.

The face artifact carries coordinates and quadrature for every mesh face; its
rows do not encode region ownership. Rebuilding the mesh from `d` therefore
changes only the declared cell/face partition while reusing byte-identical
geometry samples on the same Q1_4 grid.
"""
function spatial_g2_three_region_source_mesh_v1(data,d::SpatialMultiRegionDeclarationV4)
    validate_spatial_g2_three_region_source_declaration_v1(d)
    hasproperty(data,:mesh) && hasproperty(data,:face_quadrature) &&
        hasproperty(data,:raw_artifacts) || throw(ArgumentError("G2 source geometry requires loaded source mesh data"))
    x=d.source.input
    data.mesh.level==x.mesh.level && data.mesh.nfp==x.mesh.nfp ||
        throw(ArgumentError("G2 region declaration and source mesh level/nfp differ"))
    mesh=build_spatial_mesh_v4(d,x.mesh.level,x.mesh.nfp)
    mesh.nodes_q==data.mesh.nodes_q && mesh.cell_nodes==data.mesh.cell_nodes &&
        mesh.corner_to_local==data.mesh.corner_to_local && mesh.cell_bounds==data.mesh.cell_bounds &&
        length(mesh.faces)==length(data.mesh.faces) ||
        throw(ArgumentError("G2 region partition changed the source geometry grid or face ordering"))
    all(i->begin
        a=mesh.faces[i];b=data.mesh.faces[i]
        a.axis==b.axis && a.left_cell==b.left_cell && a.right_cell==b.right_cell && a.fixed==b.fixed
    end,eachindex(mesh.faces)) || throw(ArgumentError("G2 face ownership is not on the original source mesh"))
    region_ids=Tuple(sort!(unique(mesh.cell_regions)))
    region_ids==(1,2,3) || throw(ArgumentError("G2 source mesh did not produce exactly three nonempty regions"))
    interface_pairs=Set((mesh.cell_regions[f.left_cell],mesh.cell_regions[f.right_cell])
        for f in mesh.faces if f.role===:interface && f.right_cell>0)
    interface_pairs==Set(((1,2),(2,3))) || throw(ArgumentError("G2 source mesh must produce the two declared interfaces"))
    Tuple((sample.entity_id,sample.qp_id) for sample in data.face_quadrature)==
        Tuple((face_id,qp_id) for face_id in eachindex(mesh.faces)
            for qp_id in 1:d.quadrature.order^2) ||
        throw(ArgumentError("source face quadrature does not cover the complete G2 mesh face ordering"))
    merge(data,(mesh=mesh,g2_source_identity=(declaration_hash=canonical_hash(d),
        source_face_sha256=data.raw_artifacts.faces.sha256,scope=:g2_three_region_source_mesh_only,
        physical_validation=:unsupported,authority=:no_publish)))
end

function spatial_basis_v4(mesh::SpatialMeshV4,cell::Int,q)
    bounds=mesh.cell_bounds[cell];h=[b[2]-b[1] for b in bounds];u=collect(q).-first.(bounds)
    for a in 2:3;u[a]<-1e-10 && (u[a]+=2pi);end
    u./=h;all(t->-1e-8<=t<=1+1e-8,u) || throw(ArgumentError("quadrature outside local cell"))
    for a in 1:3
        abs(u[a])<1e-12 && (u[a]=0.);abs(u[a]-1)<1e-12 && (u[a]=1.)
    end
    ids=mesh.cell_nodes[cell];N=zeros(length(ids));D=zeros(3,length(ids));v=similar(u)
    for k in 0:7
        bits=(k%2,div(k,2)%2,div(k,4))
        for a in 1:3;v[a]=bits[a]==0 ? 1-u[a] : u[a];end
        j=mesh.corner_to_local[cell][k+1]
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

# Only the case writer creates this sink. References in receipts are relative;
# every read/write also checks the resolved directory, including junctions.
function _smr_bounded_sink_v1(case_dir,binding)
    root=realpath(case_dir);dir=joinpath(root,"bounded_steps");mkpath(dir)
    realpath(dir)==dir || throw(ArgumentError("bounded evidence directory escapes its case"))
    (case_dir=root,directory=dir,binding=binding)
end
function _smr_bounded_path_v1(case_dir,relative_path)
    relative_path isa AbstractString && occursin(r"^bounded_steps/step_[0-9]{4,}_(input|result|outer)\.json$",relative_path) ||
        throw(ArgumentError("invalid bounded evidence relative path"))
    root=realpath(case_dir);dir=joinpath(root,"bounded_steps")
    realpath(dir)==dir || throw(ArgumentError("bounded evidence directory escapes its case"))
    path=joinpath(root,split(relative_path,'/')...)
    (ispath(path) || islink(path)) && realpath(path)!=path && throw(ArgumentError("bounded evidence file escapes its case"))
    path
end
function _smr_bounded_write_v1(sink,index,kind,payload)
    sink===nothing && return nothing
    relative="bounded_steps/step_$(lpad(string(index),4,'0'))_$(kind).json"
    path=_smr_bounded_path_v1(sink.case_dir,relative)
    (ispath(path) || islink(path)) && throw(ArgumentError("bounded evidence must not overwrite an existing attempt"))
    write(path,canonical_json(payload)*"\n")
    (relative_path=relative,sha256=_smr_sha(path),schema=payload.schema)
end
_smr_bounded_outer_limits_v1(d,data,limits)=limits===nothing ?
    (max_iterations=data.mesh.level==:coarse ? d.solver.coarse_iterations : d.solver.fine_iterations,
        seconds=data.mesh.level==:coarse ? d.solver.coarse_seconds : d.solver.fine_seconds) :
    (max_iterations=limits.max_iterations,seconds=limits.seconds)
function _smr_bounded_input_v1(d,data,x,a,A,rs,cols,lower,flux_Wb,binding,callbacks;outer_limits=nothing)
    ii,jj,vv=findnz(a.jacobian)
    callback_ids=NamedTuple{(:source,:traction,:normal_field)}(Tuple(f===nothing ?
        (mode=:declared_production_input,callable=nothing) :
        (mode=:numerical_callback,callable=string(typeof(f))) for f in callbacks))
    (schema="spatial-bounded-production-input-v1",binding=binding,
        declaration_hash=canonical_hash(d),declaration=semantic_view(d),state_hash=canonical_hash(Tuple(x)),state=Tuple(x),
        flux_Wb=flux_Wb,level=data.mesh.level,nfp=data.mesh.nfp,outer_limits=_smr_bounded_outer_limits_v1(d,data,outer_limits),
        operator=(assembly="$(nameof(@__MODULE__)).assemble_spatial_system_v4",source_sha256=_smr_sha(_SMR_SOURCE),
            algorithm=_smr_bounded_identity_v1(),callbacks=callback_ids,
            geometry_hash=hasproperty(data,:raw_artifacts) ? canonical_hash(data.raw_artifacts) : nothing,
            source=d.source,boundary=d.boundary),
        column_scales=Tuple(cols),row_scales=Tuple(a.row_scales),row_blocks=Tuple(a.row_blocks),
        row_supports=Tuple(Tuple(v) for v in a.row_supports),
        raw_residual=Tuple(a.residual),raw_jacobian=(format=:coordinate,index_base=1,rows=size(a.jacobian,1),
            columns=size(a.jacobian,2),row_indices=Tuple(ii),column_indices=Tuple(jj),values=Tuple(vv)),
        input=SpatialBoundedLinearStepV1.bounded_linear_step_snapshot_v1(A,rs,lower))
end

# Recompute the model conditions from actual A/r/l and the returned step. The
# absolute gate is not enlarged by a matrix-size or floating-point floor.
function _smr_bounded_audit_v1(A,r,lower,step,active_indices)
    n=size(A,2);s=Float64.(collect(step));active=Int[active_indices...]
    length(s)==n && length(unique(active))==length(active) && all(i->1<=i<=n && isfinite(lower[i]),active) ||
        throw(ArgumentError("invalid bounded result dimensions/working set"))
    free=setdiff(collect(1:n),active);model=A*s+r;g=transpose(A)*model
    finite=all(isfinite,s) && all(isfinite,g) && all(isfinite,model)
    tol(i)=8eps(Float64)*max(1.0,abs(s[i]),abs(lower[i]))
    bounded=findall(isfinite,lower)
    primal=finite && all(i->s[i]>=lower[i]-tol(i),bounded)
    binding=finite && all(i->abs(s[i]-lower[i])<=tol(i),active)
    stationarity=maximum(abs,g[free];init=0.0)
    dual=maximum((max(0.0,-g[i]) for i in active);init=0.0)
    complementarity=maximum((abs((s[i]-lower[i])*g[i])/max(1.0,abs(s[i]-lower[i])) for i in bounded);init=0.0)
    objective=dot(model,model)/2
    passed=finite && isfinite(objective) && primal && binding && stationarity<=1.0e-10 && dual<=1.0e-10 && complementarity<=1.0e-10
    (passed=passed,finite=finite,primal_feasible=primal,working_bounds_satisfied=binding,
        free_stationarity=_smr_finite_metric(stationarity),lower_dual_violation=_smr_finite_metric(dual),
        scaled_complementarity=_smr_finite_metric(complementarity),objective=_smr_finite_metric(objective),tolerance=1.0e-10)
end

# Audit execution metadata and working-set ownership without repeating QR.
# Intermediate candidate vectors are retained evidence, not a replayed solve.
function _smr_bounded_history_guard_v1(result,lower)
    n=length(lower);policy=SpatialBoundedLinearStepV1.bounded_linear_step_policy_v1()
    limit=policy.inner_iteration_factor*n+policy.inner_iteration_offset
    result.inner_iteration_limit==limit && result.inner_iterations==length(result.history)<=limit ||
        error("bounded inner iteration metadata mismatch")
    active=findall(==(0.0),lower)
    for (j,h) in enumerate(result.history)
        event=Symbol(h.event)
        h.iteration==j && Tuple(h.active_before)==Tuple(active) &&
            Tuple(h.free_columns)==Tuple(setdiff(collect(1:n),active)) || error("bounded inner working-set history mismatch")
        j<length(result.history) && !(event in (:bind,:release)) && error("bounded history continued after a terminal event")
        added=Int[h.added...];released=Int[h.released...]
        if event==:bind
            !isempty(added) && isempty(released) && length(unique(added))==length(added) &&
                all(i->1<=i<=n && isfinite(lower[i]) && !(i in active),added) || error("invalid bounded bind history")
            active=sort!(vcat(active,added))
        elseif event==:release
            isempty(added) && length(released)==1 && only(released) in active || error("invalid bounded release history")
            active=setdiff(active,released)
        else
            isempty(added) && isempty(released) || error("terminal bounded event changed working set")
        end
    end
    Tuple(result.active_indices)==Tuple(active) && Tuple(result.free_indices)==Tuple(setdiff(collect(1:n),active)) ||
        error("bounded final working set differs from history")
    status=Symbol(result.status);terminal=isempty(result.history) ? nothing : Symbol(last(result.history).event)
    if status==:wall_time_budget
        result.exit_code==1 && terminal in (nothing,:bind,:release,:wall_time_budget) &&
            result.seconds_budget!==nothing && result.seconds_budget>=0.0 && result.elapsed_seconds>=result.seconds_budget ||
            error("bounded wall-time terminal metadata mismatch")
    elseif status==:inner_iteration_limit
        result.exit_code==1 && result.inner_iterations==limit && terminal in (:bind,:release) ||
            error("bounded iteration-limit terminal metadata mismatch")
    else
        expected_code=status==:kkt_converged ? 0 : (status==:free_QR_failure ? 2 :
            (status in (:nonfinite_free_solution,:invalid_feasible_segment,:infeasible_segment_roundoff,:nonfinite_model_audit) ? 3 :
                (status in (:precision_limit,:free_stationarity_failed,:kkt_audit_failed) ? 4 : -1)))
        expected_code>=0 && result.exit_code==expected_code && terminal==status || error("bounded terminal status/event mismatch")
    end
    result.converged==(status==:kkt_converged && result.kkt.passed) &&
        Symbol(result.physical_convergence)==:not_assessed || error("bounded convergence metadata mismatch")
    true
end

function _smr_bounded_attempt_v1(d,data,x,a,A,rs,cols,flux_Wb,index,seconds,sink,callbacks;outer_limits=nothing)
    started=time()
    lower=fill(-Inf,length(x));lower[4:4:end].=-x[4:4:end]./cols[4:4:end]
    binding=sink===nothing ? nothing : sink.binding
    payload=_smr_bounded_input_v1(d,data,x,a,A,rs,cols,lower,flux_Wb,binding,callbacks;outer_limits)
    input_ref=_smr_bounded_write_v1(sink,index,:input,payload)
    result=nothing;exception=nothing
    try
        result=SpatialBoundedLinearStepV1.solve_lower_bounded_step_v1(A,rs,lower;seconds=max(0.0,seconds-(time()-started)))
    catch err
        exception=(classification=:program_exception,error=sprint(showerror,err))
    end
    # The primary helper result is retained before any optional audit can fail.
    output=(schema="spatial-bounded-production-result-v1",input_hash=canonical_hash(payload),
        input_artifact=input_ref,algorithm=_smr_bounded_identity_v1(),result=result,exception=exception)
    result_ref=_smr_bounded_write_v1(sink,index,:result,output)
    audit=nothing;audit_error=nothing
    if result!==nothing
        try
            _smr_bounded_history_guard_v1(result,lower)
            audit=_smr_bounded_audit_v1(A,rs,lower,result.step,result.active_indices)
        catch err
            audit_error=sprint(showerror,err)
        end
    end
    success=result!==nothing && result.converged && result.exit_code==0 && result.status==:kkt_converged &&
        audit!==nothing && audit.passed && result.algorithm==_smr_bounded_identity_v1()
    status=exception!==nothing ? :program_exception : (audit_error!==nothing ? :audit_program_exception :
        (success ? :kkt_converged : (result.converged ? :independent_kkt_failed : result.status)))
    summary=(algorithm=_smr_bounded_identity_v1(),status=status,converged=success,
        classification=exception!==nothing || audit_error!==nothing ? :program_exception :
            (success ? :linear_model_only : (status==:wall_time_budget ? :resource_limit : :numerical_fail)),
        input_artifact=input_ref,result_artifact=result_ref,input_hash=canonical_hash(payload),
        artifact_replay_available=sink!==nothing,inner_exit_code=result===nothing ? nothing : result.exit_code,
        inner_iterations=result===nothing ? 0 : result.inner_iterations,active_indices=result===nothing ? () : result.active_indices,
        initial_model_objective=dot(rs,rs)/2,final_model_objective=audit===nothing ? nothing : audit.objective,
        audit=audit,exception=exception,audit_error=audit_error,physical_convergence=:not_assessed)
    (success=success,result=result,summary=summary)
end


# The new numerical revision checkpoints completed outer attempts immediately.
# Inner model convergence and nonlinear full-residual acceptance stay separate.
function _smr_outer_payload_v1(d,binding,t,x)
    names=Tuple(k for k in keys(t) if k!=:outer_artifact)
    attempt=NamedTuple{names}(Tuple(getproperty(t,k) for k in names))
    (schema="spatial-bounded-production-outer-v1",binding=binding,declaration_hash=canonical_hash(d),
        source_sha256=_smr_sha(_SMR_SOURCE),algorithm=_smr_bounded_identity_v1(),attempt=attempt,
        state_after=Tuple(x),state_after_hash=canonical_hash(Tuple(x)),solver_exit_code=nothing,
        scope=:completed_outer_attempt_not_final_solver_exit)
end
function _smr_checkpoint_outer_v1!(attempts,d,x,sink)
    (!_smm_is_declaration_v1(d) || sink===nothing) && return nothing
    t=last(attempts);payload=_smr_outer_payload_v1(d,sink.binding,t,x)
    reference=_smr_bounded_write_v1(sink,t.attempt_index,:outer,payload)
    attempts[end]=merge(t,(outer_artifact=reference,))
    reference
end
function _smr_primary_payload_v1(d,binding,sol)
    a=sol.final_assembly;ii,jj,vv=findnz(a.jacobian)
    (schema="spatial-manufactured-solver-primary-v1",binding=binding,declaration_hash=canonical_hash(d),
        source_sha256=_smr_sha(_SMR_SOURCE),algorithm=_smr_bounded_identity_v1(),
        initial_state=sol.initial_state,final_state=sol.final_state,
        state_history=Tuple(Tuple(x) for x in sol.state_history),iterations=sol.iterations,
        solver_exit_code=sol.solver_exit_code,stopping_reason=sol.stopping_reason,status=sol.status,
        rank_diagnostics=sol.rank_diagnostics,attempt_count=sol.attempt_count,
        accepted_update_count=sol.accepted_update_count,attempts=sol.attempts,last_attempt=sol.last_attempt,
        elapsed_seconds=sol.elapsed_seconds,raw_residual=Tuple(a.residual),row_scales=Tuple(a.row_scales),
        row_blocks=Tuple(a.row_blocks),row_supports=Tuple(Tuple(v) for v in a.row_supports),
        raw_jacobian=(rows=size(a.jacobian,1),columns=size(a.jacobian,2),
            row_indices=Tuple(ii),column_indices=Tuple(jj),values=Tuple(vv)),
        physical_validation=:unsupported,authority=:no_publish)
end

function solve_spatial_state_v4(d,data,initial;flux_Wb=d.flux.nominal_Wb,limits=nothing,
        _test_qr_factorization=nothing,_test_line_search_acceptance=nothing,
        source_function=nothing,boundary_function=nothing,normal_field_function=nothing,_bounded_evidence_sink=nothing)
    bounded=_smr_check_bounded_method_v1(d)
    if _smm_is_declaration_v1(d)
        validate_spatial_n1_manufactured_declaration_v1(d)
        limits===nothing && all(isnothing,(source_function,boundary_function,normal_field_function)) ||
            throw(ArgumentError("manufactured solve requires its complete frozen declaration without overrides"))
    end
    bounded && (_test_qr_factorization!==nothing || _test_line_search_acceptance!==nothing) &&
        throw(ArgumentError("legacy failure hooks are not a bounded production method"))
    !bounded && _bounded_evidence_sink!==nothing && throw(ArgumentError("bounded evidence requires the bounded method"))
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
        inner=nothing
        if bounded
            inner=_smr_bounded_attempt_v1(d,data,x,a,A,rs,cols,flux_Wb,attempt_index,seconds-(time()-start),
                _bounded_evidence_sink,(source_function,boundary_function,normal_field_function);
                outer_limits=(max_iterations=maxit,seconds=seconds))
            if !inner.success
                code=inner.summary.classification==:program_exception ? 5 : (inner.summary.classification==:resource_limit ? 4 : 7)
                reason=inner.summary.classification==:program_exception ? :bounded_step_program_exception :
                    (inner.summary.classification==:resource_limit ? :bounded_step_wall_time_budget : :bounded_step_numerical_failure)
                push!(attempts,(attempt_index=attempt_index,iteration=iteration,state_before_hash=before_hash,
                    linear_executed=true,linear_exit_code=inner.summary.inner_exit_code,linear_error_stage=:bounded_linear_model,
                    linear_error=inner.summary.status,linear_solution_finite=false,linear_relative_residual=nothing,
                    searched_direction_relative_residual=nothing,linear_rank_diagnostics=rankaudit,free_columns=(),
                    direction=:unavailable,proposed_scaled_step=(),proposed_step_norm=nothing,nonfinite_step_columns=(),
                    line_search_trial_count=0,line_search_evaluation_count=0,trials=(),accepted=false,accepted_alpha=nothing,
                    state_after_hash=before_hash,elapsed_seconds=time()-start,bounded_linear_step=inner.summary))
                _smr_checkpoint_outer_v1!(attempts,d,x,_bounded_evidence_sink)
                break
            end
            step.=inner.result.step
            free=Int[inner.result.free_indices...]
        else
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
        alpha=bounded ? 1.0 : feasible_alpha(step)
        direction=bounded ? :lower_bounded_sparse_QR_active_set_v1 : :sparse_QR_gauss_newton
        if bounded && (dot(g,step)>=0.0 || !representable_trial(step,alpha))
            code=3;reason=:bounded_step_no_representable_descent
            push!(attempts,(attempt_index=attempt_index,iteration=iteration,state_before_hash=before_hash,
                linear_executed=true,linear_exit_code=0,linear_error_stage=nothing,linear_error=nothing,
                linear_solution_finite=qr_step_finite,linear_relative_residual=qr_linear_residual,
                searched_direction_relative_residual=qr_linear_residual,linear_rank_diagnostics=rankaudit,free_columns=Tuple(free),
                direction=direction,proposed_scaled_step=Tuple(step),proposed_step_norm=norm(step),nonfinite_step_columns=(),
                line_search_trial_count=0,line_search_evaluation_count=0,trials=(),accepted=false,accepted_alpha=nothing,
                state_after_hash=before_hash,elapsed_seconds=time()-start,bounded_linear_step=inner.summary))
            _smr_checkpoint_outer_v1!(attempts,d,x,_bounded_evidence_sink)
            break
        end
        if !bounded && (!all(isfinite,step) || dot(g,step) >= 0.0 || alpha == 0.0 || !representable_trial(step,alpha))
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
        bounded && (attempts[end]=merge(attempts[end],(bounded_linear_step=inner.summary,)))
        _smr_checkpoint_outer_v1!(attempts,d,x,_bounded_evidence_sink)
        if !accepted;code=3;reason=no_progress ? :floating_point_no_progress : :feasible_line_search_failed;break;end
    end
    final=assemble_spatial_system_v4(d,data,x;flux_Wb,source_function,boundary_function,normal_field_function)
    Afinal=spdiagm(0=>1 ./final.row_scales)*final.jacobian*spdiagm(0=>cols)
    final_rank_audit=try
        _smr_rank_audit(Afinal,qr(Afinal;tol=d.solver.rank_relative_tolerance),d.solver.rank_relative_tolerance)
    catch err
        (method=:final_sparse_QR_failed,error=sprint(showerror,err),rank_estimate=-1,columns=nd,nullity_estimate=-1,null_modes=(),continuum_uniqueness=:unsupported)
    end
    result=(initial_state=Tuple(initial),final_state=Tuple(x),iterations=Tuple(history),state_history=states,
     solver_exit_code=code,stopping_reason=reason,status=code==0 ? :converged : :fail,
     final_assembly=final,rank_diagnostics=final_rank_audit,attempt_count=length(attempts),accepted_update_count=accepted_count,
     attempts=Tuple(attempts),last_attempt=isempty(attempts) ? (executed=false,reason=reason) : last(attempts),elapsed_seconds=time()-start)
    bounded ? merge(result,(numerical_algorithm=_smr_bounded_identity_v1(),
        artifact_replay_available=_bounded_evidence_sink!==nothing,)) : result
end

function _smr_current_texts(data,x;declaration=nothing)
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
            tref=declaration!==nothing && _smm_is_declaration_v1(declaration) ?
                _smm_traction_v1(declaration.source.input,s.xyz,s.normal) : _smr_stress(l.rotation*collect(s.B_reference_cyl),s.p_reference)*n
            outerTjump=max(outerTjump,norm(l.T_xyz*n-tref))
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
    if declaration!==nothing && _smr_has_loads(declaration)
        loads=_smr_declared_load_values_v1(declaration);source=collect(loads.source_xyz_N_m3)
        residual2=zeros(2);residualpeak=zeros(2);imposed=zeros(3);area=0.;normal_mismatch=0.
        for s in data.volume
            c=s.entity_id;r=mesh.cell_regions[c];f=spatial_field_v4(data,c,s,x)
            load_defect=cross(f.J_xyz,f.B_xyz)-f.gradp_xyz+f.B_xyz.*(f.divB/_SMR_MU0)-source
            residual2[r]+=s.weight*dot(load_defect,load_defect);residualpeak[r]=max(residualpeak[r],norm(load_defect))
        end
        for s in data.face_quadrature
            face=mesh.faces[s.entity_id];face.role==:exterior || continue
            f=spatial_field_v4(data,face.left_cell,s,x);n=collect(s.normal);area+=s.weight
            imposed.+=s.weight.*(_smr_stress(f.rotation*collect(s.B_reference_cyl),s.p_reference)*n)
            normal_mismatch=max(normal_mismatch,abs(dot(f.B_xyz,n)-loads.normal_B_T))
        end
        diagnostics=merge(diagnostics,(declared_loads=(declaration_hash=canonical_hash(declaration),
            source_xyz_N_m3=loads.source_xyz_N_m3,source_unit="N m^-3",normal_B_T=loads.normal_B_T,normal_B_unit="T",
            divT_minus_source_rms_N_m3=Tuple(sqrt.(residual2./volume)),divT_minus_source_peak_N_m3=Tuple(residualpeak),
            imposed_traction_minus_source_integral_N=Tuple(imposed-sum(volume).*source),
            state_traction_minus_source_integral_N=Tuple(vec(sum(cell_surface;dims=2))-sum(volume).*source),
            prescribed_outer_normal_flux_Wb=area*loads.normal_B_T,outer_normal_field_mismatch_peak_T=normal_mismatch,
            compatibility_certified=false,external_closure_status=:terminal_deferred),))
    end

    if declaration!==nothing && _smm_is_declaration_v1(declaration)
        validate_spatial_n1_manufactured_declaration_v1(declaration);input=declaration.source.input
        residual2=zeros(2);residualpeak=zeros(2);source_integral=zeros(3);imposed=zeros(3)
        prescribed_flux=0.0;normal_mismatch=0.0
        normal_law=input.geometry.model===:m1n1_ripple_torus ? declaration.boundary.normal_law : nothing
        normal_law===nothing || _smm_validate_m1n1_normal_law_v1(input,normal_law;bind_input=true)
        for s in data.volume
            c=s.entity_id;r=mesh.cell_regions[c];f=spatial_field_v4(data,c,s,x)
            source=collect(_smm_source_v1(input,s.xyz));source_integral.+=s.weight.*source
            load_defect=cross(f.J_xyz,f.B_xyz)-f.gradp_xyz+f.B_xyz.*(f.divB/_SMR_MU0)-source
            residual2[r]+=s.weight*dot(load_defect,load_defect);residualpeak[r]=max(residualpeak[r],norm(load_defect))
        end
        for s in data.face_quadrature
            face=mesh.faces[s.entity_id];face.role==:exterior || continue
            f=spatial_field_v4(data,face.left_cell,s,x);n=collect(s.normal)
            imposed.+=s.weight.*_smm_traction_v1(input,s.xyz,s.normal)
            bn=input.geometry.model===:m1n1_ripple_torus ?
                _smm_m1n1_normal_value_validated_v1(input,s.q,s.R) :
                _smm_normal_v1(input,s.xyz,s.normal)
            prescribed_flux+=s.weight*bn
            normal_mismatch=max(normal_mismatch,abs(dot(f.B_xyz,n)-bn))
        end
        diagnostics=merge(diagnostics,(manufactured_loads=(declaration_hash=canonical_hash(declaration),
            input_hash=canonical_hash(input),provider=spatial_manufactured_provider_identity_v1(),
            source_unit="N m^-3",source_integral_N=Tuple(source_integral),
            divT_minus_source_rms_N_m3=Tuple(sqrt.(residual2./volume)),divT_minus_source_peak_N_m3=Tuple(residualpeak),
            imposed_traction_minus_source_integral_N=Tuple(imposed-source_integral),
            state_traction_minus_source_integral_N=Tuple(vec(sum(cell_surface;dims=2))-source_integral),
            prescribed_outer_normal_flux_Wb=prescribed_flux,outer_normal_field_mismatch_peak_T=normal_mismatch,
            quadrature=:declared_GL3_observation_not_error_bound,compatibility_certified=false,
            external_closure_status=:terminal_deferred,physical_validation=:unsupported,authority=:no_publish),))
    end
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
struct SpatialManufacturedNumericalResultV1
    candidate_hash::Digest256;context_hash::Digest256;declaration::SpatialMultiRegionDeclarationV4;cases::Tuple
    primary_case_id::String;executed::Bool;status::Symbol;solver_exit_code::Int;execution::NamedTuple
    physical_validation::Symbol;claim_ceiling::typeof(screen_only);result_hash::Digest256
end
semantic_view(x::SpatialManufacturedNumericalResultV1)=NamedTuple{fieldnames(typeof(x))[1:end-1]}(Tuple(getfield(x,k) for k in fieldnames(typeof(x))[1:end-1]))
function canonical_hash(x::Union{SpatialMultiRegionCaseV4,SpatialMultiRegionResultV4,SpatialManufacturedNumericalResultV1})
    canonical_hash(semantic_view(x))==x.result_hash||throw(ArgumentError("spatial result hash mismatch"));x.result_hash
end

function _smr_declaration(context)
    validate_spatial_candidate_v4(context)
    d=only(filter(x->x isa SpatialMultiRegionDeclarationV4,context.candidate.field_geometry_genome_ref.fields))
    validate_spatial_multiregion_declaration_v4(d)
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
    mkpath(dir)
    bounded=_smr_has_bounded_step(d)
    sink=bounded ? _smr_bounded_sink_v1(dir,(candidate_hash=context.candidate_hash,context_hash=context.context_hash,
        case_id=case.case_id,scope=:production_declared_inputs)) : nothing
    sol=if _smm_is_declaration_v1(d)
        _smr_manufactured_phase_v1(dir,"solver_call") do
            solve_spatial_state_v4(d,data,data.initial_state;flux_Wb=case.flux_Wb,_bounded_evidence_sink=sink)
        end
    else
        solve_spatial_state_v4(d,data,data.initial_state;flux_Wb=case.flux_Wb,_bounded_evidence_sink=sink)
    end
    primary_artifact=nothing
    if _smm_is_declaration_v1(d)
        primary_path=joinpath(dir,"solver_primary.json")
        (ispath(primary_path) || islink(primary_path)) && error("preserve prior manufactured solver primary")
        write(primary_path,canonical_json(_smr_primary_payload_v1(d,sink.binding,sol))*"\n")
        primary_artifact=_smr_artifact(primary_path,"spatial-manufactured-solver-primary-v1",1)
    end
    statehash=canonical_hash((candidate_hash=context.candidate_hash,context_hash=context.context_hash,case_id=case.case_id,level=case.level,flux_Wb=case.flux_Wb,state=sol.final_state))
    texts=_smr_current_texts(data,sol.final_state;declaration=d)
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
    if primary_artifact!==nothing;artifacts=merge(artifacts,(solver_primary=primary_artifact,));end
    if bounded
        for (j,t) in enumerate(sol.attempts),kind in (_smm_is_declaration_v1(d) ? (:input,:result,:outer) : (:input,:result))
            ref=kind==:outer ? t.outer_artifact : getproperty(t.bounded_linear_step,Symbol(kind,"_artifact"))
            path=_smr_bounded_path_v1(dir,ref.relative_path)
            artifact=_smr_artifact(path,ref.schema,1)
            artifact.sha256==ref.sha256 || error("bounded attempt changed before case receipt")
            artifacts=merge(artifacts,NamedTuple{(Symbol("bounded_",kind,"_",j),)}((artifact,)))
        end
    end
    diag=merge(texts.diagnostics,(blocks=_smr_block_norms(a),scaled_norm=norm(a.residual./a.row_scales),
        scaled_max=maximum(abs,a.residual./a.row_scales),jacobian_rows=size(a.jacobian,1),jacobian_columns=size(a.jacobian,2),
        jacobian_nnz=nnz(a.jacobian),rank_diagnostics=sol.rank_diagnostics,elapsed_seconds=sol.elapsed_seconds,
        attempt_count=sol.attempt_count,accepted_update_count=sol.accepted_update_count,last_attempt=sol.last_attempt,attempts=sol.attempts,
        missing_closure=:pressure_current_topology_uniqueness_and_exterior_currents))
    if bounded
        diag=merge(diag,(numerical_algorithm=sol.numerical_algorithm,artifact_replay_available=sol.artifact_replay_available,
            numerical_status=sol.solver_exit_code==0 ? :full_discrete_residual_converged :
                (sol.solver_exit_code==5 ? :program_exception :
                    (sol.stopping_reason in (:wall_time_budget,:bounded_step_wall_time_budget) ? :resource_limit : :numerical_fail)),
            physical_convergence=:not_certified))
    end
    body=(candidate_hash=context.candidate_hash,context_hash=context.context_hash,case_id=case.case_id,level=case.level,nfp=data.mesh.nfp,flux_Wb=case.flux_Wb,
          initial_state=sol.initial_state,final_state=sol.final_state,state_hash=statehash,executed=true,status=sol.status,solver_exit_code=sol.solver_exit_code,
          stopping_reason=sol.stopping_reason,iterations=sol.iterations,raw_artifacts=data.raw_artifacts,engineering_input=eng,artifacts=artifacts,diagnostics=diag)
    SpatialMultiRegionCaseV4(values(body)...,canonical_hash(body))
end

function execute_spatial_multiregion_v4(context,upstream,run_dir)
    d=_smr_declaration(context)
    _smm_is_declaration_v1(d) && throw(ArgumentError("manufactured candidate cannot execute the DESC spatial entry"))
    receipt=_smr_upstream(context,upstream);dir=abspath(run_dir);mkpath(dir)
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
    if _smr_has_bounded_step(d)
        execution=merge(execution,(numerical_algorithm=_smr_bounded_identity_v1(),
            bounded_step_source=_smr_artifact(_SMR_BOUNDED_SOURCE,"julia_source",countlines(_SMR_BOUNDED_SOURCE))))
    end
    body=(candidate_hash=context.candidate_hash,context_hash=context.context_hash,declaration=d,cases=cases,primary_case_id="nominal_coarse",executed=true,
          status=code==0 ? :unsupported : :fail,solver_exit_code=code,execution=execution,physical_validation=:unsupported,claim_ceiling=screen_only)
    result=SpatialMultiRegionResultV4(values(body)...,canonical_hash(body))
    validate_spatial_result_v4(context,result);result
end

# JSON arrays here encode tuples, never the canonical shaped-array envelope.
_smr_json_native_v1(x::JSON3.Object)=NamedTuple{Tuple(Symbol.(collect(keys(x))))}(Tuple(_smr_json_native_v1(v) for v in values(x)))
_smr_json_native_v1(x::JSON3.Array)=Tuple(_smr_json_native_v1(v) for v in x)
_smr_json_native_v1(x)=x
_smr_same_json_v1(a,b)=canonical_json(a)==canonical_json(b)

# JSON3's default reader converts integral Float64 tokens to Int64. Restore
# only the numeric token types from this canonical artifact's own wire; never
# infer them from expected data or change the global canonical encoding.
function _smr_restore_wire_numbers_v1(value,tokens)
    if value isa JSON3.Object
        entries=collect(pairs(value))
        return NamedTuple{Tuple(Symbol(first(p)) for p in entries)}(
            Tuple(_smr_restore_wire_numbers_v1(last(p),tokens) for p in entries))
    elseif value isa JSON3.Array
        return Tuple(_smr_restore_wire_numbers_v1(v,tokens) for v in value)
    elseif value isa Real && !(value isa Bool)
        isempty(tokens) && error("canonical artifact numeric token missing")
        token=popfirst!(tokens)
        return occursin(r"[.eE]",token) ? parse(Float64,token) : parse(Int64,token)
    end
    value
end
function _smr_read_canonical_json_v1(wire::AbstractString)
    tree=JSON3.read(wire)
    # Quoted keys/values, including escaped quotes and digits, consume no
    # numeric token. JSON3 validates the complete JSON structure first.
    pattern=r"\"(?:\\.|[^\"\\])*\"|(-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?)"
    tokens=Iterators.Stateful(m.captures[1] for m in eachmatch(pattern,wire) if m.captures[1]!==nothing)
    value=_smr_restore_wire_numbers_v1(tree,tokens)
    isempty(tokens) || error("canonical artifact has unconsumed numeric tokens")
    canonical_json(value)*"\n"==wire || error("bounded artifact is not the exact canonical wire representation")
    value
end

function _smr_read_bounded_artifact_v1(case_dir,artifacts,index,kind,reference;expected_wire=nothing)
    relative="bounded_steps/step_$(lpad(string(index),4,'0'))_$(kind).json"
    reference!==nothing && reference.relative_path==relative || error("missing or foreign bounded attempt artifact")
    path=_smr_bounded_path_v1(case_dir,relative)
    artifact=getproperty(artifacts,Symbol("bounded_",kind,"_",index))
    reference.schema=="spatial-bounded-production-$(kind)-v1" &&
        artifact.path==path && string(artifact.sha256)==string(reference.sha256)==string(_smr_sha(path)) &&
        artifact.schema==reference.schema && artifact.row_count==1 || error("bounded artifact binding mismatch")
    wire=read(path,String)
    expected_wire===nothing || wire==expected_wire || error("bounded rebuilt input differs from exact persisted wire")
    _smr_read_canonical_json_v1(wire)
end

function _smr_replay_bounded_attempt_v1(d,data,before,t,binding,case_dir,artifacts;flux_Wb,
        source_function=nothing,boundary_function=nothing,normal_field_function=nothing,limits=nothing)
    info=t.bounded_linear_step
    info.artifact_replay_available && _smr_same_json_v1(info.algorithm,_smr_bounded_identity_v1()) ||
        error("bounded attempt has no supported replay identity")
    x=collect(before);n=length(x);cols=repeat([d.scaling.B_T,d.scaling.B_T,d.scaling.B_T,d.scaling.p_Pa],div(n,4))
    a=assemble_spatial_system_v4(d,data,x;flux_Wb,source_function,boundary_function,normal_field_function)
    rs=a.residual./a.row_scales;A=spdiagm(0=>1 ./a.row_scales)*a.jacobian*spdiagm(0=>cols)
    lower=fill(-Inf,n);lower[4:4:end].=-x[4:4:end]./cols[4:4:end]
    outer_limits=_smr_bounded_outer_limits_v1(d,data,limits)
    g0=transpose(A)*rs;z0=x./cols;btol=_smr_scaled_bound_tolerance(z0);pg=copy(g0)
    for i in 4:4:n;z0[i]<=btol[i] && g0[i]>0.0 && (pg[i]=0.0);end
    all(isfinite,rs) && all(i->_smr_pressure_feasible(x[i],cols[i]),4:4:n) &&
        maximum(abs,rs)>d.solver.residual_tolerance && norm(pg)>d.solver.gradient_tolerance &&
        0<=t.iteration<outer_limits.max_iterations || error("bounded attempt bypassed an outer stopping gate")
    expected=_smr_bounded_input_v1(d,data,x,a,A,rs,cols,lower,flux_Wb,binding,
        (source_function,boundary_function,normal_field_function);outer_limits)
    input=_smr_read_bounded_artifact_v1(case_dir,artifacts,t.attempt_index,:input,info.input_artifact;
        expected_wire=canonical_json(expected)*"\n")
    _smr_same_json_v1(input,expected) && string(info.input_hash)==string(canonical_hash(expected)) ||
        error("bounded actual input/state/source/operator replay mismatch")
    output=_smr_read_bounded_artifact_v1(case_dir,artifacts,t.attempt_index,:result,info.result_artifact)
    output.schema=="spatial-bounded-production-result-v1" && _smr_same_json_v1(output.input_hash,info.input_hash) &&
        _smr_same_json_v1(output.input_artifact,info.input_artifact) && _smr_same_json_v1(output.algorithm,info.algorithm) ||
        error("bounded result input/algorithm mismatch")
    result=output.result;audit=nothing;audit_error=nothing
    if result!==nothing
        _smr_same_json_v1(result.algorithm,info.algorithm) || error("foreign bounded helper result")
        try
            _smr_bounded_history_guard_v1(result,lower)
            audit=_smr_bounded_audit_v1(A,rs,lower,result.step,result.active_indices)
        catch err
            audit_error=sprint(showerror,err)
        end
        if audit_error===nothing
            fullaudit=SpatialBoundedLinearStepV1.bounded_step_kkt_v1(A,rs,lower,collect(result.step),Int[result.active_indices...])
            _smr_same_json_v1(fullaudit,result.kkt) || error("helper KKT report differs from actual model")
        end
    end
    output.exception===nothing || result===nothing || error("ambiguous helper exception and result")
    success=output.exception===nothing && result!==nothing && result.converged && result.exit_code==0 &&
        Symbol(result.status)==:kkt_converged && audit!==nothing && audit.passed
    status=output.exception!==nothing ? :program_exception : (audit_error!==nothing ? :audit_program_exception :
        (success ? :kkt_converged : (result!==nothing && result.converged ? :independent_kkt_failed :
            (result===nothing ? :invalid_missing_result : Symbol(result.status)))))
    classification=output.exception!==nothing || audit_error!==nothing ? :program_exception :
        (success ? :linear_model_only : (status==:wall_time_budget ? :resource_limit : :numerical_fail))
    info.converged==success && Symbol(info.status)==status && Symbol(info.classification)==classification &&
        info.inner_exit_code==(result===nothing ? nothing : result.exit_code) &&
        info.inner_iterations==(result===nothing ? 0 : result.inner_iterations) &&
        _smr_same_json_v1(info.active_indices,result===nothing ? () : result.active_indices) &&
        info.initial_model_objective==dot(rs,rs)/2 && info.final_model_objective==(audit===nothing ? nothing : audit.objective) &&
        _smr_same_json_v1(info.audit,audit) && _smr_same_json_v1(info.exception,output.exception) &&
        info.audit_error==audit_error && Symbol(info.physical_convergence)==:not_assessed || error("bounded summary replay mismatch")
    if !success
        !t.accepted && isempty(t.trials) && isempty(t.proposed_scaled_step) && t.direction==:unavailable &&
            t.linear_exit_code==info.inner_exit_code || error("failed inner solve fabricated an outer attempt")
        return true
    end
    t.direction==:lower_bounded_sparse_QR_active_set_v1 && t.linear_exit_code==0 &&
        _smr_same_json_v1(t.proposed_scaled_step,result.step) &&
        Tuple(setdiff(collect(1:n),Int[result.active_indices...]))==Tuple(result.free_indices)==t.free_columns ||
        error("outer direction or working set differs from bounded result")
    step=collect(result.step);g=transpose(A)*rs;phi=dot(rs,rs)
    if isempty(t.trials)
        !t.accepted && (dot(g,step)>=0.0 || !_smr_scaled_state_change(x,x.+cols.*step,cols)) ||
            error("bounded step omitted its required outer line search")
        return true
    end
    dot(g,step)<0.0 || error("bounded line search did not use a descent direction")
    accepted=false;accepted_phi=phi;accepted_alpha=nothing
    for (j,z) in enumerate(t.trials)
        z.trial_index==j-1 && j<=d.solver.line_search_steps+1 && z.alpha==2.0^(-(j-1)) && !accepted ||
            error("bounded outer line search order or alpha mismatch")
        trial=x.+z.alpha.*cols.*step
        for k in 4:4:n;_smr_pressure_feasible(trial[k],cols[k]) && trial[k]<0.0 && (trial[k]=0.0);end
        feasible=all(k->_smr_pressure_feasible(trial[k],cols[k]),4:4:n)
        changed=trial!=x;scaled_change=_smr_scaled_state_change(x,trial,cols)
        evaluated=feasible && changed && scaled_change
        z.feasible==feasible && z.changed_state==changed && z.scaled_state_change==scaled_change && z.evaluated==evaluated &&
            z.objective_before==phi || error("bounded outer trial state mismatch")
        if evaluated
            actual=assemble_spatial_system_v4(d,data,trial;flux_Wb,jacobian=false,source_function,boundary_function,normal_field_function)
            rr=actual.residual./actual.row_scales;finite=all(isfinite,rr);after=finite ? dot(rr,rr) : Inf
            strict=finite && after<phi;armijo=finite && after<=phi+2e-4*z.alpha*dot(g,step)
            accepted=armijo && strict
            z.finite_residual==finite && z.scaled_norm==(finite ? norm(rr) : nothing) &&
                z.scaled_max==(finite ? maximum(abs,rr) : nothing) && z.objective_after==(finite ? after : nothing) &&
                z.objective_decrease==(finite ? phi-after : nothing) && z.strict_objective_decrease==strict &&
                z.armijo_accepted==armijo && z.accepted==accepted || error("bounded full residual/Armijo replay mismatch")
            if accepted;accepted_phi=after;accepted_alpha=z.alpha;end
        else
            !z.accepted && !z.armijo_accepted && !z.strict_objective_decrease && z.objective_after===nothing ||
                error("unevaluated bounded trial claimed progress")
        end
    end
    t.accepted==accepted && t.accepted_alpha==accepted_alpha && t.objective_before==phi && t.objective_after==accepted_phi &&
        t.objective_decrease==phi-accepted_phi && t.strict_objective_decrease==accepted && t.scaled_state_change==accepted ||
        error("bounded outer acceptance summary mismatch")
    accepted || length(t.trials)==d.solver.line_search_steps+1 || error("bounded line search stopped before its declared budget")
    no_progress=!accepted && any(z->z.feasible,t.trials) &&
        (!any(z->z.feasible && z.scaled_state_change,t.trials) || !any(z->z.strict_objective_decrease,t.trials))
    t.progress_classification==(accepted ? :accepted_strict_decrease :
        (no_progress ? :floating_point_no_progress : :line_search_rejected)) || error("bounded progress classification mismatch")
    true
end


function _smr_replay_case_geometry_v1(context,d,c,meta::AbstractDict)
    for (k,art) in pairs(c.raw_artifacts)
        validate_spatial_artifact_v4(art);string(art.sha256)==meta["$(c.level)_$(k)_sha256"]||error("unbound raw geometry")
    end
    data=load_spatial_data_v4(d,c);Tuple(data.initial_state)==c.initial_state||error("initializer not actual DESC nodal field")
    data
end
function _smr_replay_case_geometry_v1(context,d,c,receipt::SpatialManufacturedGeometryReceiptV1)
    _smm_is_declaration_v1(d) || error("manufactured geometry requires its numerical declaration")
    validate_spatial_manufactured_geometry_v1(context,d.source.input,receipt)
    canonical_json(c.raw_artifacts)==canonical_json(receipt.raw_artifacts) || error("manufactured case/provider raw artifacts differ")
    data=load_spatial_data_v4(d,c)
    Tuple(data.initial_state)==c.initial_state || error("initializer differs from canonical manufactured reference plus perturbation")
    data
end
function _smr_replay_manufactured_primary_v1(context,d,c,data,state_lines,a)
    _smm_is_declaration_v1(d) || return true
    c.diagnostics.scaled_max==maximum(abs,a.residual./a.row_scales) || error("manufactured peak residual diagnostic differs from actual residual")
    nnode=div(length(c.final_state),4)
    history=Tuple(Tuple(v for z in state_lines[j*nnode+1:(j+1)*nnode] for v in parse.(Float64,z[3:6]))
        for j in 0:length(c.iterations)-1)
    sol=(initial_state=c.initial_state,final_state=c.final_state,state_history=history,iterations=c.iterations,
        solver_exit_code=c.solver_exit_code,stopping_reason=c.stopping_reason,status=c.status,
        rank_diagnostics=c.diagnostics.rank_diagnostics,attempt_count=c.diagnostics.attempt_count,
        accepted_update_count=c.diagnostics.accepted_update_count,attempts=c.diagnostics.attempts,
        last_attempt=c.diagnostics.last_attempt,elapsed_seconds=c.diagnostics.elapsed_seconds,final_assembly=a)
    binding=(candidate_hash=context.candidate_hash,context_hash=context.context_hash,case_id=c.case_id,scope=:production_declared_inputs)
    expected=_smr_primary_payload_v1(d,binding,sol);artifact=c.artifacts.solver_primary
    artifact.path==joinpath(realpath(dirname(c.artifacts.attempts.path)),"solver_primary.json") &&
        artifact.schema==expected.schema && artifact.row_count==1 &&
        read(artifact.path,String)==canonical_json(expected)*"\n" || error("manufactured final primary differs from replay")
    true
end

function _smr_validate_cases_v1(context,p,d,geometry)
    for (spec,c) in zip(d.cases,p.cases)
        canonical_hash(c);c.candidate_hash==context.candidate_hash&&c.context_hash==context.context_hash&&
            c.case_id==spec.case_id&&c.level==spec.level&&c.flux_Wb==spec.flux_Wb&&c.executed||error("spatial realization mismatch")
        data=_smr_replay_case_geometry_v1(context,d,c,geometry)
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
        if _smr_has_bounded_step(d)
            diag.numerical_algorithm==_smr_bounded_identity_v1() && diag.artifact_replay_available &&
                diag.physical_convergence==:not_certified && diag.numerical_status==(c.solver_exit_code==0 ? :full_discrete_residual_converged :
                    (c.solver_exit_code==5 ? :program_exception :
                        (c.stopping_reason in (:wall_time_budget,:bounded_step_wall_time_budget) ? :resource_limit : :numerical_fail))) ||
                        error("bounded case identity or evidence missing")
        end
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
            if _smr_has_bounded_step(d)
                _smr_replay_bounded_attempt_v1(d,data,before,t,(candidate_hash=context.candidate_hash,context_hash=context.context_hash,
                    case_id=c.case_id,scope=:production_declared_inputs),dirname(c.artifacts.attempts.path),c.artifacts;flux_Wb=c.flux_Wb)
            end
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
            if _smm_is_declaration_v1(d)
                binding=(candidate_hash=context.candidate_hash,context_hash=context.context_hash,case_id=c.case_id,scope=:production_declared_inputs)
                actual_after=t.accepted ? after : before
                expected=_smr_outer_payload_v1(d,binding,t,actual_after)
                _smr_read_bounded_artifact_v1(dirname(c.artifacts.attempts.path),c.artifacts,j,:outer,t.outer_artifact;
                    expected_wire=canonical_json(expected)*"\n")
            end
        end
        a=assemble_spatial_system_v4(d,data,c.final_state;flux_Wb=c.flux_Wb)
        rows=split.(readlines(c.artifacts.residual_rows.path)[2:end],',')
        length(rows)==length(a.residual)&&all(parse(Int,z[1])==i&&parse(Float64,z[3])==a.residual[i]&&parse(Float64,z[4])==a.row_scales[i]&&z[2]==string(a.row_blocks[i]) for (i,z) in enumerate(rows))||error("state residual replay mismatch")
        supportlines=split.(readlines(c.artifacts.row_supports.path)[2:end],',')
        length(supportlines)==length(a.row_supports)&&all(parse(Int,z[1])==i&&z[2]==string(a.row_blocks[i])&&parse.(Int,split(z[3],';'))==a.row_supports[i] for (i,z) in enumerate(supportlines))||error("row support ownership mismatch")
        jrows=split.(readlines(c.artifacts.jacobian.path)[2:end],',');rr,cc,vv=findnz(a.jacobian)
        length(jrows)==length(vv)&&all(parse(Int,z[1])==rr[i]&&parse(Int,z[2])==cc[i]&&parse(Float64,z[3])==vv[i] for (i,z) in enumerate(jrows))||error("full state Jacobian replay mismatch")
        texts=_smr_current_texts(data,c.final_state;declaration=d);eng=c.engineering_input;validate_spatial_current_input_v4(eng)
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
        _smr_replay_manufactured_primary_v1(context,d,c,data,state_lines,a)
        if _smr_has_bounded_step(d) && !isempty(diag.attempts)
            last_attempt=last(diag.attempts);inner=last_attempt.bounded_linear_step
            if !inner.converged
                program=inner.classification==:program_exception
                resource=inner.classification==:resource_limit
                c.solver_exit_code==(program ? 5 : (resource ? 4 : 7)) &&
                    c.stopping_reason==(program ? :bounded_step_program_exception :
                        (resource ? :bounded_step_wall_time_budget : :bounded_step_numerical_failure)) ||
                    error("bounded inner failure was relabelled as another outer exit")
            elseif !last_attempt.accepted
                expected_reason=isempty(last_attempt.trials) ? :bounded_step_no_representable_descent :
                    (last_attempt.progress_classification==:floating_point_no_progress ? :floating_point_no_progress : :feasible_line_search_failed)
                c.solver_exit_code==3 && c.stopping_reason==expected_reason || error("bounded outer rejection exit mismatch")
            end
        end
    end
    true
end

function validate_spatial_result_v4(context,p::SpatialMultiRegionResultV4)
    d=_smr_declaration(context)
    _smm_is_declaration_v1(d) && throw(ArgumentError("manufactured numerical candidate is not a DESC spatial result"))
    canonical_hash(p)
    p.candidate_hash==context.candidate_hash&&p.context_hash==context.context_hash&&canonical_hash(p.declaration)==canonical_hash(d)||error("foreign spatial result")
    p.primary_case_id=="nominal_coarse"&&length(p.cases)==length(d.cases)&&p.executed&&p.physical_validation==:unsupported&&p.claim_ceiling==screen_only||error("spatial result authority mismatch")
    p.execution.source.path==_SMR_SOURCE&&p.execution.source.sha256==_smr_sha(_SMR_SOURCE)&&
        p.execution.sampler_source.path==_SMR_SAMPLER&&p.execution.sampler_source.sha256==_smr_sha(_SMR_SAMPLER)||error("spatial producer source mismatch")
    for v in values(p.execution);v isa SpatialArtifactV4&&validate_spatial_artifact_v4(v);end
    if _smr_has_bounded_step(d)
        _smr_check_bounded_method_v1(d)
        p.execution.numerical_algorithm==_smr_bounded_identity_v1() &&
            p.execution.bounded_step_source.path==_SMR_BOUNDED_SOURCE &&
            p.execution.bounded_step_source.sha256==_smr_sha(_SMR_BOUNDED_SOURCE) || error("bounded producer identity mismatch")
    end
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
    _smr_validate_cases_v1(context,p,d,meta)
    p.solver_exit_code==(all(c->c.solver_exit_code==0,p.cases) ? 0 : maximum(c.solver_exit_code for c in p.cases))||error("whole spatial exit mismatch")
    p.status==(p.solver_exit_code==0 ? :unsupported : :fail)||error("whole spatial status mismatch")
    p.result_hash
end


# This entry is numerical verification only. It does not accept a DESC receipt,
# invent upstream authority, or replace the unchanged DESC executor/validator.
function _smr_manufactured_phase_v1(f,dir,label)
    start_ns=time_ns()
    function record(status;details=(;))
        path=joinpath(dir,"phase_$(label)_$(status).json")
        (ispath(path)||islink(path)) && error("preserve manufactured phase evidence")
        write(path,canonical_json((schema="spatial-manufactured-operation-observation-v1",phase=label,
            status=status,pid=getpid(),observed_unix=time(),elapsed_seconds=(time_ns()-start_ns)/1.0e9,
            details=details))*"\n")
        println("MMS_OPERATION=",label," status=",status);flush(stdout)
    end
    record(:started)
    try
        value=f();record(:completed);value
    catch err
        record(:exception;details=(classification=:program_exception,error=sprint(showerror,err),
            trace=sprint(Base.show_backtrace,catch_backtrace())))
        rethrow()
    end
end

function execute_spatial_manufactured_numerical_v1(context,run_dir)
    dir=abspath(run_dir)
    ispath(dir) && !isempty(readdir(dir)) && throw(ArgumentError("preserve existing manufactured numerical evidence"))
    mkpath(dir)
    d=_smr_manufactured_phase_v1(dir,"candidate_admission") do
        declared=_smr_declaration(context)
        _smm_is_declaration_v1(declared) || throw(ArgumentError("manufactured numerical declaration required"))
        declared
    end
    input=d.source.input
    binding=(candidate_hash=context.candidate_hash,context_hash=context.context_hash)
    write(joinpath(dir,"candidate_admission.json"),canonical_json((schema="spatial-manufactured-admission-v1",
        binding=binding,declaration_hash=canonical_hash(d),input_hash=canonical_hash(input),
        status=:complete_fresh_candidate_validation,scope=:this_public_invocation_only))*"\n")
    start=time()
    # This public invocation just admitted this exact context, declaration, and
    # input. Reuse that conclusion only here; the separately callable provider
    # keeps its own full guard and delegates to this same canonical raw producer.
    receipt=_smr_manufactured_phase_v1(dir,"provider_materialization") do
        _smm_materialize_geometry_v1(input,d,binding,joinpath(dir,"geometry"))
    end
    provider_seconds=time()-start
    record_path=joinpath(dirname(receipt.raw_artifacts.nodes.path),"manufactured_provider.json")
    read(record_path,String)==canonical_json(receipt)*"\n" || error("manufactured provider primary changed")
    data=_smr_manufactured_phase_v1(dir,"provider_file_load") do
        load_spatial_data_v4(d,(level=input.mesh.level,nfp=input.mesh.nfp,flux_Wb=input.flux.nominal_Wb,raw_artifacts=receipt.raw_artifacts))
    end
    load_seconds=time()-start-provider_seconds;case_start=time()
    cases=_smr_manufactured_phase_v1(dir,"writer_full_solver") do
        Tuple(_smr_write_case(context,d,data,spec,joinpath(dir,spec.case_id)) for spec in d.cases)
    end
    writer_seconds=time()-case_start
    code=all(c->c.solver_exit_code==0,cases) ? 0 : maximum(c.solver_exit_code for c in cases)
    execution=(schema="spatial-manufactured-numerical-execution-v1",provider_receipt=receipt,
        provider_record=_smr_artifact(record_path,"spatial-manufactured-geometry-receipt-v1",1),
        source=_smr_artifact(_SMR_SOURCE,"julia_source",countlines(_SMR_SOURCE)),
        provider_source=_smr_artifact(_SMM_SOURCE_V1,"julia_source",countlines(_SMM_SOURCE_V1)),
        bounded_step_source=_smr_artifact(_SMR_BOUNDED_SOURCE,"julia_source",countlines(_SMR_BOUNDED_SOURCE)),
        numerical_algorithm=_smr_bounded_identity_v1(),input_hash=canonical_hash(input),
        julia_version=string(VERSION),blas_config=string(BLAS.get_config()),
        phase_seconds=(provider=provider_seconds,load=load_seconds,writer_including_solver=writer_seconds),
        desc_execution=:not_executed,engineering_execution=:not_executed,whole_device_validation=:unsupported,
        physical_validation=:unsupported,authority=:no_publish,scope=:manufactured_numerical_only)
    body=(candidate_hash=context.candidate_hash,context_hash=context.context_hash,declaration=d,cases=cases,
        primary_case_id=only(d.cases).case_id,executed=true,status=code==0 ? :unsupported : :fail,solver_exit_code=code,
        execution=execution,physical_validation=:unsupported,claim_ceiling=screen_only)
    result=SpatialManufacturedNumericalResultV1(values(body)...,canonical_hash(body))
    # Preserve the complete producer primary even if replay later raises.
    write(joinpath(dir,"numerical_result.json"),canonical_json(result)*"\n")
    _smr_manufactured_phase_v1(dir,"producer_result_replay") do
        validate_spatial_manufactured_result_v1(context,result)
    end
    result
end

validate_spatial_result_v4(context,p::SpatialManufacturedNumericalResultV1)=
    throw(ArgumentError("manufactured numerical result is not a DESC spatial/engineering/whole-device result"))
execute_spatial_engineering_v4(context,physics::SpatialManufacturedNumericalResultV1,run_dir;kwargs...)=
    throw(ArgumentError("manufactured numerical result cannot enter spatial engineering execution"))
assess_spatial_whole_device_v4(context,upstream,physics::SpatialManufacturedNumericalResultV1,engineering,verification)=
    throw(ArgumentError("manufactured numerical result cannot enter whole-device assessment"))
function validate_spatial_manufactured_result_v1(context,p::SpatialManufacturedNumericalResultV1)
    d=_smr_declaration(context);_smm_is_declaration_v1(d) || error("manufactured result requires numerical candidate")
    canonical_hash(p)
    p.candidate_hash==context.candidate_hash && p.context_hash==context.context_hash &&
        canonical_hash(p.declaration)==canonical_hash(d) || error("foreign manufactured numerical result")
    p.primary_case_id==only(d.cases).case_id && length(p.cases)==length(d.cases) && p.executed &&
        p.physical_validation==:unsupported && p.claim_ceiling==screen_only || error("manufactured result scope mismatch")
    e=p.execution
    e.schema=="spatial-manufactured-numerical-execution-v1" && e.scope==:manufactured_numerical_only &&
        e.authority==:no_publish && e.desc_execution==:not_executed && e.engineering_execution==:not_executed &&
        e.whole_device_validation==:unsupported && e.physical_validation==:unsupported &&
        e.input_hash==canonical_hash(d.source.input) || error("manufactured result cannot acquire DESC/physical authority")
    keys(e)==(:schema,:provider_receipt,:provider_record,:source,:provider_source,:bounded_step_source,
        :numerical_algorithm,:input_hash,:julia_version,:blas_config,:phase_seconds,:desc_execution,
        :engineering_execution,:whole_device_validation,:physical_validation,:authority,:scope) || error("manufactured execution schema mismatch")
    e.source.path==_SMR_SOURCE && e.source.sha256==_smr_sha(_SMR_SOURCE) &&
        e.provider_source.path==_SMM_SOURCE_V1 && e.provider_source.sha256==_smr_sha(_SMM_SOURCE_V1) &&
        e.bounded_step_source.path==_SMR_BOUNDED_SOURCE && e.bounded_step_source.sha256==_smr_sha(_SMR_BOUNDED_SOURCE) &&
        e.numerical_algorithm==_smr_bounded_identity_v1() || error("manufactured producer/source identity mismatch")
    for value in values(e);value isa SpatialArtifactV4 && validate_spatial_artifact_v4(value);end
    validate_spatial_manufactured_geometry_v1(context,d.source.input,e.provider_receipt)
    e.provider_record.path==joinpath(realpath(dirname(e.provider_receipt.raw_artifacts.nodes.path)),"manufactured_provider.json") &&
        e.provider_record.schema=="spatial-manufactured-geometry-receipt-v1" && e.provider_record.row_count==1 &&
        read(e.provider_record.path,String)==canonical_json(e.provider_receipt)*"\n" || error("manufactured provider receipt wire mismatch")
    keys(e.phase_seconds)==(:provider,:load,:writer_including_solver) && all(v->isfinite(v) && v>=0.0,values(e.phase_seconds)) ||
        error("manufactured execution phase measurements missing")
    _smr_validate_cases_v1(context,p,d,e.provider_receipt)
    p.solver_exit_code==(all(c->c.solver_exit_code==0,p.cases) ? 0 : maximum(c.solver_exit_code for c in p.cases)) || error("manufactured whole exit mismatch")
    p.status==(p.solver_exit_code==0 ? :unsupported : :fail) || error("manufactured whole status mismatch")
    p.result_hash
end

const _SMR_RAW_HEADER="entity_id,qp_id,rho,theta,zeta,x_m,y_m,z_m,R_m,phi_rad,weight,detE,nx,ny,nz,"*
    join(("E$i$j" for i in 1:3 for j in 1:3),",")*","*join(("I$i$j" for i in 1:3 for j in 1:3),",")*",BR_T,Bphi_T,BZ_T,p_Pa"
function _smr_matrix_rows_v1(A)
    size(A) == (3, 3) || throw(ArgumentError("interface metric must be 3 by 3"))
    Tuple(Tuple(Float64(A[i, j]) for j in 1:3) for i in 1:3)
end

"""Build ordered per-edge geometry contexts from validated SpatialMeshV4 data.

`mesh_region_to_model_region` explicitly maps integer mesh region IDs to the
model's string IDs. `region_node_local_dofs` supplies each model region's four
field DOF indices at every mesh node (or `nothing` off that region). The
returned conormal is oriented from each edge's minus region to its plus region.
"""
function spatial_multiregion_interface_geometry_contexts_v1(data, interface_edges;
        mesh_region_to_model_region, region_node_local_dofs)
    hasproperty(data, :mesh) && hasproperty(data, :face_quadrature) &&
        hasproperty(data, :raw_artifacts) ||
        throw(ArgumentError("interface geometry requires loaded source-backed spatial data"))
    mesh = data.mesh
    mesh isa SpatialMeshV4 || throw(ArgumentError("interface geometry requires SpatialMeshV4"))
    edges = Tuple(interface_edges)
    isempty(edges) && throw(ArgumentError("at least one ordered interface edge is required"))

    region_map = Tuple(mesh_region_to_model_region)
    all(x -> x isa NamedTuple && keys(x) == (:mesh_region_id, :model_region_id) &&
        x.mesh_region_id isa Integer && !(x.mesh_region_id isa Bool) && x.mesh_region_id > 0 &&
        x.model_region_id isa AbstractString && !isempty(strip(x.model_region_id)), region_map) ||
        throw(ArgumentError("mesh-to-model region mapping is malformed"))
    length(unique(x.mesh_region_id for x in region_map)) == length(region_map) &&
        length(unique(x.model_region_id for x in region_map)) == length(region_map) ||
        throw(ArgumentError("mesh-to-model region mapping must be one-to-one"))
    mapped_region(mesh_region_id) = begin
        item = findfirst(x -> x.mesh_region_id == mesh_region_id, region_map)
        item === nothing && throw(ArgumentError("interface mesh region has no explicit model mapping"))
        String(region_map[item].model_region_id)
    end

    node_maps = Tuple(region_node_local_dofs)
    all(x -> x isa NamedTuple && keys(x) == (:region_id, :node_dofs) &&
        x.region_id isa AbstractString && x.node_dofs isa Tuple &&
        length(x.node_dofs) == size(mesh.nodes_q, 2), node_maps) ||
        throw(ArgumentError("region node-to-local-DOF maps must cover every spatial mesh node"))
    length(unique(x.region_id for x in node_maps)) == length(node_maps) ||
        throw(ArgumentError("region node-to-local-DOF maps must have unique region IDs"))
    endpoint_map(region_id) = begin
        item = findfirst(x -> x.region_id == region_id, node_maps)
        item === nothing && throw(ArgumentError("interface model region has no node-to-DOF map"))
        node_maps[item].node_dofs
    end

    all(edge -> edge isa NamedTuple && all(k -> hasproperty(edge, k),
        (:edge_id, :minus_region_id, :plus_region_id)), edges) ||
        throw(ArgumentError("interface edges must carry ordered edge and endpoint identities"))
    length(unique(edge.edge_id for edge in edges)) == length(edges) ||
        throw(ArgumentError("interface edge IDs must be unique"))
    raw_interface_faces = Tuple((face_id=fid, face=mesh.faces[fid])
        for fid in eachindex(mesh.faces)
        if mesh.faces[fid].role == :interface && mesh.faces[fid].right_cell > 0)
    isempty(raw_interface_faces) && throw(ArgumentError("loaded spatial mesh has no two-sided interface faces"))
    face_artifact = data.raw_artifacts.faces
    validate_spatial_artifact_v4(face_artifact)
    source_geometry = (face_sha256=string(face_artifact.sha256),
        face_schema=face_artifact.schema, face_row_count=face_artifact.row_count)

    contexts = Tuple(begin
        edge_id = String(edge.edge_id)
        minus_id = String(edge.minus_region_id)
        plus_id = String(edge.plus_region_id)
        matching = Tuple(begin
            face = item.face
            left_id = mapped_region(mesh.cell_regions[face.left_cell])
            right_id = mapped_region(mesh.cell_regions[face.right_cell])
            if (left_id, right_id) == (minus_id, plus_id)
                (face_id=item.face_id, face=face, minus_cell=face.left_cell,
                    plus_cell=face.right_cell, normal_sign=1.0)
            elseif (left_id, right_id) == (plus_id, minus_id)
                (face_id=item.face_id, face=face, minus_cell=face.right_cell,
                    plus_cell=face.left_cell, normal_sign=-1.0)
            else
                nothing
            end
        end for item in raw_interface_faces)
        selected = Tuple(item for item in matching if item !== nothing)
        isempty(selected) && throw(ArgumentError("interface edge has no matching source mesh faces"))
        samples = Tuple(Iterators.flatten(Tuple(begin
            face_samples = Tuple(s for s in data.face_quadrature if s.entity_id == item.face_id)
            isempty(face_samples) && throw(ArgumentError("interface face lacks source quadrature samples"))
            minus_map = endpoint_map(minus_id)
            plus_map = endpoint_map(plus_id)
            Tuple(begin
                bminus = spatial_basis_v4(mesh, item.minus_cell, s.q)
                bplus = spatial_basis_v4(mesh, item.plus_cell, s.q)
                minus = (region_id=minus_id, cell_id=item.minus_cell, node_ids=Tuple(bminus.ids),
                    local_dofs=Tuple(begin
                        dofs = minus_map[node]
                        dofs isa Tuple && length(dofs) == 4 &&
                            all(i -> i isa Integer && !(i isa Bool) && i > 0, dofs) ||
                            throw(ArgumentError("minus interface node lacks four explicit local field DOFs"))
                        Tuple(Int.(dofs))
                    end for node in bminus.ids),
                    basis_values=Tuple(bminus.N),
                    basis_chart_gradients=Tuple(Tuple(bminus.dN_dq[a, j] for a in 1:3)
                        for j in eachindex(bminus.ids)))
                plus = (region_id=plus_id, cell_id=item.plus_cell, node_ids=Tuple(bplus.ids),
                    local_dofs=Tuple(begin
                        dofs = plus_map[node]
                        dofs isa Tuple && length(dofs) == 4 &&
                            all(i -> i isa Integer && !(i isa Bool) && i > 0, dofs) ||
                            throw(ArgumentError("plus interface node lacks four explicit local field DOFs"))
                        Tuple(Int.(dofs))
                    end for node in bplus.ids),
                    basis_values=Tuple(bplus.N),
                    basis_chart_gradients=Tuple(Tuple(bplus.dN_dq[a, j] for a in 1:3)
                        for j in eachindex(bplus.ids)))
                (face_id=item.face_id, quadrature_id=s.qp_id, chart_q=Tuple(s.q),
                    xyz=Tuple(s.xyz), weight=s.weight,
                    normal=Tuple(item.normal_sign .* collect(s.normal)),
                    E=_smr_matrix_rows_v1(s.E), Einv=_smr_matrix_rows_v1(s.Einv),
                    minus=minus, plus=plus)
            end for s in face_samples)
        end for item in selected)))
        (edge_id=edge_id, orientation=:minus_to_plus,
            source_geometry=source_geometry, samples=samples)
    end for edge in edges)
    assigned_face_count = sum(length(unique(sample.face_id for sample in context.samples))
        for context in contexts)
    assigned_face_count == length(raw_interface_faces) &&
        length(unique(sample.face_id for context in contexts for sample in context.samples)) ==
            length(raw_interface_faces) ||
        throw(ArgumentError("every source mesh interface face must map to exactly one declared edge"))
    contexts
end

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
    (_smm_is_declaration_v1(d) || _smm_is_g2_three_region_source_v1(d)) &&
        return load_spatial_manufactured_data_v1(d,c)
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
    manufactured=_smm_is_declaration_v1(d)
    normal_law=nothing
    if manufactured
        validate_spatial_n1_manufactured_declaration_v1(d)
        all(isnothing,(source_function,boundary_function,normal_field_function)) ||
            throw(ArgumentError("manufactured declaration forbids callback overrides"))
        mesh.nfp==d.source.input.mesh.nfp && mesh.level==d.source.input.mesh.level &&
            flux_Wb==d.source.input.flux.nominal_Wb || throw(ArgumentError("manufactured assembly mesh/flux mismatch"))
        if d.source.input.geometry.model===:m1n1_ripple_torus
            hasproperty(d.boundary,:normal_law) && d.boundary.normal_B_T===nothing ||
                throw(ArgumentError("mapped manufactured boundary must declare its spatial normal law without a constant scalar"))
            _smm_validate_m1n1_normal_law_v1(d.source.input,d.boundary.normal_law;bind_input=true)
            normal_law=d.boundary.normal_law
        end
    end
    loads=manufactured ? nothing : _smr_declared_load_values_v1(d)
    r=zeros(length(mesh.row_blocks));ii=Int[];jj=Int[];vv=Float64[]
    add(row,col,value)=if jacobian;push!(ii,row);push!(jj,col);push!(vv,value);end
    # Stress directional derivative, contracted against an arbitrary vector g.
    function dtg(f,Ntrial,c,g)
        if c==4;return -Ntrial.*g;end
        u=Ntrial.*view(f.rotation,:,c);B=f.B_xyz
        (u.*dot(B,g)+B.*dot(u,g)-g.*dot(B,u))./_SMR_MU0
    end
    for s in data.volume
        cell=s.entity_id;f=spatial_field_v4(data,cell,s,x)
        source=manufactured ? collect(_smm_source_v1(d.source.input,s.xyz)) :
            (source_function===nothing ? collect(loads.source_xyz_N_m3) : collect(_smr_load_vector_v1(source_function(s.xyz),"source_function output")))
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
        t_ref=outer ? (manufactured ? _smm_traction_v1(d.source.input,s.xyz,s.normal) :
            (boundary_function===nothing ? _smr_stress(fl.rotation*collect(s.B_reference_cyl),s.p_reference)*n : collect(_smr_load_vector_v1(boundary_function(s.xyz,s.normal),"boundary_function output")))) : fl.T_xyz*n
        bn_ref=outer ? (manufactured ? (normal_law===nothing ?
            _smm_normal_v1(d.source.input,s.xyz,s.normal) :
            _smm_m1n1_normal_value_validated_v1(d.source.input,s.q,s.R)) :
            (normal_field_function===nothing ? loads.normal_B_T : _smr_load_scalar_v1(normal_field_function(s.xyz,s.normal),"normal_field_function output"))) : dot(fl.B_xyz,n)
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
