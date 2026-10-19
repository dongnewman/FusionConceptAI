using SHA
using Dates
using FusionConceptAI

const _PERF_ROOT = normpath(joinpath(@__DIR__, "..", "..", "..", ".."))
const _PERF_G = FusionConceptAI
const FROZEN_LENGTH = 8_269_571
const FROZEN_RAW_SHA256 = "1abdd43b057c6f6ba7dc020cf3c4a9239823cc2081f00583a405f7d0d91645f8"
const R5_INPUT_IDENTITY = "c86c43d67a1df9619aaf941ac44ffceedd621aa1d2957a7f73251465c654f41f"

function _perf_snapshot()
    try
        command = "(Get-Process -Id $(getpid())).WorkingSet64; (Get-Process -Id $(getpid())).CPU"
        lines = split(strip(read(`powershell.exe -NoProfile -NonInteractive -Command $command`, String)), '\n')
        (rss=Int(parse(Int, strip(lines[1]))), cpu=parse(Float64, strip(lines[2])))
    catch
        (rss=nothing, cpu=nothing)
    end
end

function _perf_monitor_start()
    samples = Vector{NamedTuple{(:utc,:rss,:cpu),Tuple{String,Any,Any}}}()
    stop = Ref(false)
    initial = _perf_snapshot()
    push!(samples, (utc=string(Dates.now(Dates.UTC)), rss=initial.rss, cpu=initial.cpu))
    task = @async begin
        while !stop[]
            snap = _perf_snapshot()
            push!(samples, (utc=string(Dates.now(Dates.UTC)), rss=snap.rss, cpu=snap.cpu))
            sleep(0.1)
        end
    end
    (samples=samples, stop=stop, task=task)
end

function _perf_monitor_stop(monitor)
    final = _perf_snapshot()
    push!(monitor.samples, (utc=string(Dates.now(Dates.UTC)), rss=final.rss, cpu=final.cpu))
    monitor.stop[] = true
    wait(monitor.task)
    valid = filter(x -> x.rss isa Integer, monitor.samples)
    peak = isempty(valid) ? nothing : maximum(x.rss for x in valid)
    peak_utc = isempty(valid) ? nothing : first(x.utc for x in valid if x.rss == peak)
    last = isempty(valid) ? nothing : valid[end]
    println("PERF_RSS_SAMPLE_COUNT=", length(valid))
    println("PERF_RSS_PEAK_BYTES=", peak === nothing ? "unavailable" : peak)
    println("PERF_RSS_PEAK_UTC=", peak_utc === nothing ? "unavailable" : peak_utc)
    println("PERF_RSS_LAST_BYTES=", last === nothing ? "unavailable" : last.rss)
    println("PERF_CPU_LAST_SECONDS=", last === nothing ? "unavailable" : last.cpu)
    for sample in valid
        println("PERF_RSS_SAMPLE_UTC=", sample.utc, " BYTES=", sample.rss,
            " CPU_SECONDS=", sample.cpu)
    end
    peak
end

function _perf_build_source_backed_transport()
    candidate = Main._T0L_CANDIDATE
    g1, g2, g3 = Main._t0l_g1(), Main._t0l_g2(), Main._t0l_g3()
    declarations = (Main._t0l_present(:G1, g1),
        Main._t0l_present(:G2, g2), Main._t0l_present(:G3, g3))
    children = (Main._t0l_child(:realization), Main._t0l_child(:control),
        Main._t0l_child(:binding))
    feedback = ntuple(i -> begin
        id = i == 1 ? "g1-residual" : "g2-thermal"
        target = i == 1 ? declarations[1].declaration_ref :
            declarations[2].declaration_ref
        layer = i == 1 ? :G1 : :G2
        raw_target = only(filter(x -> x.target_id == id, g3.feedback_targets))
        body = (candidate_ref=candidate,
            source_ref=(i == 1 ? declarations[1].source_ref :
                declarations[2].source_ref),
            declaration_ref=(i == 1 ? declarations[1].declaration_ref :
                declarations[2].declaration_ref), target_ref=target,
            feedback_targets=(raw_target,))
        _PERF_G.VNextT0LocalFeedbackV1(id, layer, candidate, target, body,
            _PERF_G.canonical_hash(body))
    end, 2)
    admission = _PERF_G.vnext_declaration_transport_local_v1(
        candidate, declarations, children, feedback)
    admission.status === :valid ||
        error("source-backed T0 transport failed: $(admission.errors)")
    admission.transport
end

println("PERF_PID=", getpid())
println("PERF_START_UTC=", Dates.now(Dates.UTC))
include_started = time_ns()
Base.include(Main, joinpath(_PERF_ROOT, "test", "GenomeV5", "Integration",
    "vnext_declaration_transport_local_v1_tests.jl"))
Base.include(_PERF_G, joinpath(_PERF_ROOT, "src", "Contracts",
    "VNextT1CanonicalBytesV2.jl"))
include_seconds = (time_ns() - include_started) / 1e9
println("PERF_INCLUDE_LOAD_SECONDS=", include_seconds)

fixture_started = time_ns()
transport = _perf_build_source_backed_transport()
fixture_seconds = (time_ns() - fixture_started) / 1e9
canonical_started = time_ns()
payload = Vector{UInt8}(codeunits(_PERF_G.canonical_json(transport)))
canonical_seconds = (time_ns() - canonical_started) / 1e9
actual_sha = bytes2hex(SHA.sha256(copy(payload)))
println("PERF_FIXTURE_TRANSPORT_SECONDS=", fixture_seconds)
println("PERF_CANONICAL_JSON_SECONDS=", canonical_seconds)
println("PERF_INPUT_LENGTH=", length(payload))
println("PERF_EXPECTED_LENGTH=", FROZEN_LENGTH)
println("PERF_EXPECTED_RAW_SHA256=", FROZEN_RAW_SHA256)
println("PERF_ACTUAL_RAW_SHA256=", actual_sha)
println("PERF_R5_INPUT_IDENTITY_DIGEST=", R5_INPUT_IDENTITY)
length(payload) == FROZEN_LENGTH || error("source-backed payload length mismatch")
lowercase(actual_sha) == FROZEN_RAW_SHA256 || error("source-backed payload SHA mismatch")

monitor = _perf_monitor_start()
GC.gc()
cold_started = time_ns()
cold = _PERF_G.VNextT1CanonicalBytesV2(payload)
cold_seconds = (time_ns() - cold_started) / 1e9
@assert cold.sha256.value == actual_sha
warm_seconds = Float64[]
for i in 1:2
    started = time_ns()
    warm = _PERF_G.VNextT1CanonicalBytesV2(payload)
    push!(warm_seconds, (time_ns() - started) / 1e9)
    @assert warm.sha256 == cold.sha256
    @assert _PERF_G.copy_bytes(warm) == payload
end
peak_rss = _perf_monitor_stop(monitor)
warm_median = sum(warm_seconds) / length(warm_seconds)
println("PERF_CARRIER_COLD_SECONDS=", cold_seconds)
println("PERF_CARRIER_WARM_SECONDS=", join(warm_seconds, ","))
println("PERF_CARRIER_WARM_MEDIAN_METHOD=arithmetic_median_for_two_samples")
println("PERF_CARRIER_WARM_MEDIAN_SECONDS=", warm_median)
println("PERF_CARRIER_LENGTH=", _PERF_G.byte_length(cold))
println("PERF_CARRIER_SHA256=", cold.sha256.value)
println("PERF_CARRIER_GATE=", cold_seconds <= 10.0 &&
    (peak_rss === nothing || peak_rss <= 2 * 1024^3) ? "PASS" : "FAIL_RESOURCE_LIMIT")
println("PERF_SCOPE=source_backed_t0_transport_before_authority_recheck")
println("PERF_END_UTC=", Dates.now(Dates.UTC))
