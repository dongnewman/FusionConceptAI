using SHA

const SPATIAL_RUNTIME_V4_SOURCE_ORDER_V1 = (
    "SpatialExecutionTypesV4.jl",
    "SpatialMultiRegionV4.jl",
    "SpatialPickupEngineeringV4.jl",
    "SpatialVerificationUQV4.jl",
    "SpatialCandidateV4.jl",
    "SpatialWholeDeviceV4.jl",
)
const SPATIAL_RUNTIME_V4_LOAD_STATE = Ref(:unloaded)
const SPATIAL_RUNTIME_V4_SOURCE_ROOT = @__DIR__
const SPATIAL_RUNTIME_V4_SOURCE_HASHES_V1 = Tuple(
    (source, bytes2hex(SHA.sha256(read(joinpath(SPATIAL_RUNTIME_V4_SOURCE_ROOT, source)))))
    for source in SPATIAL_RUNTIME_V4_SOURCE_ORDER_V1
)

"""Load all spatial RuntimeV4 definitions exactly once, in the recorded order.

The state is set to `:loading` before the first child include. An exception
therefore leaves the loader fail-closed: a retry is refused instead of silently
redefining a partially loaded type graph. `include_file` is injectable only so
the state machine and order can be tested without constructing the full parent
candidate.
"""
function load_spatial_runtime_v4!(;
        target_module::Module=@__MODULE__,
        source_root::AbstractString=SPATIAL_RUNTIME_V4_SOURCE_ROOT,
        include_file::Function=(mod, path)->Base.include(mod, path))
    SPATIAL_RUNTIME_V4_LOAD_STATE[] === :unloaded ||
        error("SpatialRuntimeV4 V1 was already attempted in this target module; refusing duplicate or partial load")
    SPATIAL_RUNTIME_V4_LOAD_STATE[] = :loading
    for source in SPATIAL_RUNTIME_V4_SOURCE_ORDER_V1
        path = joinpath(source_root, source)
        isfile(path) || error("missing required spatial RuntimeV4 source: $source")
        include_file(target_module, path)
    end
    SPATIAL_RUNTIME_V4_LOAD_STATE[] = :loaded
    return SPATIAL_RUNTIME_V4_SOURCE_HASHES_V1
end
