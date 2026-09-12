# Shared actual-current artifact contract for spatial physical-to-engineering execution.
using FusionConceptAI, SHA
import FusionConceptAI: semantic_view, canonical_hash

"Exact execution linkage, including same-candidate reruns with different receipts."
function validate_spatial_upstream_link_v4(upstream,physics)
    e=physics.execution;r=upstream.result.receipt
    e.upstream_request_hash==canonical_hash(upstream.request) &&
        e.upstream_result_hash==canonical_hash(upstream.result) &&
        e.upstream_receipt_hash==canonical_hash(r) || error("spatial physics belongs to a different upstream execution")
    e.hdf5.path==r.output_path && e.hdf5.sha256==r.output_sha256 || error("spatial physics HDF5 differs from current receipt")
    true
end

struct SpatialArtifactV4
    path::String
    sha256::Digest256
    schema::String
    row_count::Int
end
semantic_view(x::SpatialArtifactV4)=(path=x.path,sha256=x.sha256,schema=x.schema,row_count=x.row_count)
function validate_spatial_artifact_v4(x::SpatialArtifactV4)
    x.row_count>=0 && isfile(x.path) || throw(ArgumentError("spatial artifact missing or invalid row count"))
    Digest256(bytes2hex(SHA.sha256(read(x.path))))==x.sha256 || throw(ArgumentError("spatial artifact bytes changed"))
    true
end

struct SpatialCurrentInputV4
    candidate_hash::Digest256
    context_hash::Digest256
    case_id::String
    state_hash::Digest256
    geometry_hash::Digest256
    volume::SpatialArtifactV4
    interfaces::SpatialArtifactV4
    exterior::SpatialArtifactV4
    current_closure::NamedTuple
    status::Symbol
    solver_exit_code::Int
    upstream_valid::Bool
    scope::String
end
semantic_view(x::SpatialCurrentInputV4)=NamedTuple{fieldnames(typeof(x))}(Tuple(getfield(x,k) for k in fieldnames(typeof(x))))
function validate_spatial_current_input_v4(x::SpatialCurrentInputV4)
    for a in (x.volume,x.interfaces,x.exterior);validate_spatial_artifact_v4(a);end
    x.status in (:fail,:unsupported,:converged) || throw(ArgumentError("unknown spatial input state"))
    true
end

const SPATIAL_VOLUME_HEADER_V4="cell_id,region_id,x_m,y_m,z_m,dV_m3,Bx_T,By_T,Bz_T,Jx_A_m2,Jy_A_m2,Jz_A_m2,p_Pa,gradpx_Pa_m,gradpy_Pa_m,gradpz_Pa_m,divB_T_m"
const SPATIAL_INTERFACE_HEADER_V4="face_id,minus_region,plus_region,x_m,y_m,z_m,dA_m2,nx,ny,nz,Bx_minus_T,By_minus_T,Bz_minus_T,Bx_plus_T,By_plus_T,Bz_plus_T,Kx_A_m,Ky_A_m,Kz_A_m,Jn_minus_A_m2,Jn_plus_A_m2"
const SPATIAL_EXTERIOR_HEADER_V4="face_id,x_m,y_m,z_m,dA_m2,nx,ny,nz,Bx_T,By_T,Bz_T,Jx_A_m2,Jy_A_m2,Jz_A_m2,p_Pa"
