ENV["FUSION_FREEGS_AUTHORED_SOURCES"] = "1"
include(joinpath(@__DIR__, "..", "..", "examples", "runtime_v4_freegs_axisymmetric_execution.jl"))

using JSON3, SHA
const F = FreeGSAxisymmetricRuntime
const legacy_input = F.freegs_axisymmetric_solver_input(freegs_context)
@assert !hasproperty(legacy_input.solver_input, :state_sample_time_s)
const bad_timestamp_rejected = try
    F.freegs_axisymmetric_solver_input(freegs_context; state_sample_time_s=NaN)
    false
catch err
    err isa ArgumentError
end
@assert bad_timestamp_rejected
const repo_root = normpath(joinpath(@__DIR__, "..", ".."))
function requested_results_directory(args)
    length(args)==2 && args[1]=="--results-directory" ||
        error("usage: julia --project=. test/UP4ReferenceActualConsumerV1/shot30421_magpr_raw_residual_shortcheck.jl --results-directory runs/e/<fresh-leaf>")
    e_root=abspath(joinpath(repo_root,"runs","e"))
    raw_path=args[2]
    target=abspath(isabspath(raw_path) ? raw_path : joinpath(repo_root,raw_path))
    relative=relpath(target,e_root)
    (relative!="." && !startswith(relative,"..") && !isabspath(relative)) ||
        error("results directory must be a child of repo runs/e")
    isdir(dirname(target)) || error("results directory parent must be prepared before launch")
    mkdir(target) # exclusive: fails closed if the requested evidence leaf already exists
    target
end
const output_dir = requested_results_directory(ARGS)
const existing_results_rejected = try
    requested_results_directory(ARGS)
    false
catch
    true
end
@assert existing_results_rejected
const package_root = joinpath(repo_root, "tmp", "resume_20261009_up4_source_owned",
    "shot30421_magpr_raw_acq_r1")
const acquisition = JSON3.read(read(joinpath(package_root, "acquisition.json"), String))
@assert acquisition[:shot] == 30421
@assert acquisition[:status] == "success"
@assert acquisition[:likelihood_ready] === false
@assert acquisition[:scientific_acceptance] === false
const by_path = Dict(String(row[:resolved_path]) => row for row in acquisition[:arrays])
const wanted = ("efm/time", "efm/mag_probe_n", "efm/magpr_x", "efm/magpr_r",
    "efm/magpr_z", "efm/magpr_ang", "efm/magpr_len")
@assert Set(keys(by_path)) == Set(wanted)
for path in wanted
    @assert by_path[path][:status] == "acquired_raw_values_no_uncertainty_interpretation"
end
function source_vector(path)
    field = replace(path, "/" => "__")
    bytes = read(joinpath(package_root, "fields", field, "assembled.raw"))
    @assert bytes2hex(SHA.sha256(bytes)) == String(by_path[path][:assembled_raw_sha256])
    @assert length(bytes) == Int(by_path[path][:assembled_raw_bytes])
    Float64.(collect(reinterpret(Float32, bytes)))
end
function source_field_metadata(path)
    field = replace(path, "/" => "__")
    JSON3.read(read(joinpath(package_root, "fields", field, "field_metadata.json"), String))
end
const times = source_vector("efm/time")
const slots = source_vector("efm/mag_probe_n")
const raw_x = source_vector("efm/magpr_x")
const R = source_vector("efm/magpr_r")
const Z = source_vector("efm/magpr_z")
const angle = source_vector("efm/magpr_ang")
const len = source_vector("efm/magpr_len")
@assert Tuple(Int.(by_path["efm/magpr_x"][:shape])) == (120, 78)
@assert by_path["efm/magpr_x"][:dimensions] == ["time", "mag_probe_n"]
@assert by_path["efm/time"][:dimensions] == ["time"]
for path in ("efm/mag_probe_n", "efm/magpr_r", "efm/magpr_z", "efm/magpr_ang", "efm/magpr_len")
    @assert by_path[path][:dimensions] == ["mag_probe_n"]
    @assert Tuple(Int.(by_path[path][:shape])) == (78,)
    @assert by_path[path][:attributes][:quality] == "Not Checked"
end
@assert by_path["efm/time"][:attributes][:units] == "S"
@assert by_path["efm/mag_probe_n"][:attributes][:units] == ""
@assert by_path["efm/magpr_x"][:attributes][:units] == "T"
@assert by_path["efm/magpr_r"][:attributes][:units] == "m"
@assert by_path["efm/magpr_z"][:attributes][:units] == "m"
@assert by_path["efm/magpr_ang"][:attributes][:units] == "deg"
@assert by_path["efm/magpr_len"][:attributes][:units] == "m"
@assert by_path["efm/magpr_x"][:attributes][:quality] == "Not Checked"
@assert by_path["efm/magpr_r"][:attributes][:quality] == "Not Checked"
const observed = Matrix(reshape(raw_x, 78, 120)')
const hashes = (
    efm_time=String(by_path["efm/time"][:assembled_raw_sha256]),
    efm_mag_probe_n=String(by_path["efm/mag_probe_n"][:assembled_raw_sha256]),
    efm_magpr_x=String(by_path["efm/magpr_x"][:assembled_raw_sha256]),
    efm_magpr_r=String(by_path["efm/magpr_r"][:assembled_raw_sha256]),
    efm_magpr_z=String(by_path["efm/magpr_z"][:assembled_raw_sha256]),
    efm_magpr_ang=String(by_path["efm/magpr_ang"][:assembled_raw_sha256]),
    efm_magpr_len=String(by_path["efm/magpr_len"][:assembled_raw_sha256]))
const observation = F.freegs_mast_magpr_observation_v1(
    shot=30421, channel_names=F._FREEGS_MAST_MAGPR_CHANNELS, mag_probe_n=slots,
    time_s=times, observed_T=observed, R_m=R, Z_m=Z, angle_deg=angle, length_m=len,
    units=(time="S", channel="", observed="T", R="m", Z="m",
        angle="deg", length="m"), quality="Not Checked", source_hashes=hashes,
    source_ref="https://s3.echo.stfc.ac.uk/mast/level1/shots/30421.zarr/efm/magpr_x/",
    mapping_ref="https://raw.githubusercontent.com/ukaea/fair-mast-ingestion/main/mappings/level2/mast.yml#L585-L629")
const subulp_tamper = copy(observed)
subulp_tamper[1,1] = nextfloat(subulp_tamper[1,1])
const subulp_tamper_rejected = try
    F.freegs_mast_magpr_observation_v1(
        shot=30421, channel_names=F._FREEGS_MAST_MAGPR_CHANNELS, mag_probe_n=slots,
        time_s=times, observed_T=subulp_tamper, R_m=R, Z_m=Z,
        angle_deg=angle, length_m=len,
        units=(time="S", channel="", observed="T", R="m", Z="m",
            angle="deg", length="m"), quality="Not Checked", source_hashes=hashes,
        source_ref="https://s3.echo.stfc.ac.uk/mast/level1/shots/30421.zarr/efm/magpr_x/",
        mapping_ref="https://raw.githubusercontent.com/ukaea/fair-mast-ingestion/main/mappings/level2/mast.yml#L585-L629")
    false
catch err
    err isa ArgumentError
end
@assert subulp_tamper_rejected
const time_index = searchsortedfirst(observation.time_s, 0.1)
@assert 1 <= time_index <= length(observation.time_s)
const sample_points = Tuple((observation.R_m[j], observation.Z_m[j])
    for j in eachindex(observation.channels))
# This is a candidate-side screen at one exact source timestamp. Its state/current
# is not claimed to be the MAST shot state; the consumer preserves that provenance gap.
const artifacts = F.execute_freegs_axisymmetric_screen(freegs_context;
    sample_points_rz_m=sample_points,
    state_sample_time_s=observation.time_s[time_index])
const screen = F.freegs_mast_magpr_raw_residual_v1(freegs_context, artifacts,
    observation; time_index=time_index)
@assert screen.status === :raw_residual_screen
@assert screen.claim_ceiling === :screen_only
@assert screen.residual_units == "T"
@assert length(screen.residual_T) == 78
@assert screen.forward_authority === false
@assert screen.G1_PF_current_mapping === :typed_absent
@assert screen.G3_MAST_current_provenance === :typed_absent
@assert screen.candidate_state_time_label === :input_output_receipt_echo
@assert screen.G2_same_time_machine_state_provenance === :typed_absent
@assert screen.probe_calibration === :typed_absent
@assert screen.probe_correction === :typed_absent
@assert screen.finite_length_response === :typed_absent
@assert screen.uncertainty === :typed_absent
@assert screen.likelihood === :typed_absent
@assert screen.inverse === :typed_absent
stored_screen = merge(screen, (result_hash=string(screen.result_hash),))
write(joinpath(output_dir, "result.json"), JSON3.write(stored_screen) * "\n")
const summary = (schema="mast-magpr-actual-source-shortcheck-v1", status="screen_only",
    shot=30421, time_index=time_index, state_sample_time_s=screen.candidate_state_time_s,
    acquisition_manifest_sha256=String(acquisition[:selection_sha256]),
    magpr_x_sha256=hashes.efm_magpr_x, candidate_input_sha256=screen.candidate_input_hash,
    candidate_output_sha256=screen.candidate_output_hash, result_sha256=string(screen.result_hash),
    forward_authority=false, likelihood=:typed_absent, inverse=:typed_absent)
write(joinpath(output_dir, "summary.json"), JSON3.write(summary) * "\n")
println(JSON3.write(summary))
