using SHA
using Dates
using FusionConceptAI

const _R5_ROOT = normpath(joinpath(@__DIR__, "..", "..", "..", ".."))
const _R5_REPO = realpath(_R5_ROOT)
const A = FusionConceptAI

const _R5_MODES = (:bundle_hash_recompute, :canonical_json_transport,
    :prior_bytes_compare, :v1_ntuple_materialize)

function _r5_gc_value(name::Symbol)
    isdefined(Base, name) || return nothing
    try
        getfield(Base, name)()
    catch exception
        nothing
    end
end

function _r5_rss()
    Sys.iswindows() || return nothing
    try
        text = read(`powershell.exe -NoProfile -NonInteractive -Command "(Get-Process -Id $(getpid())).WorkingSet64"`, String)
        parse(Int, strip(text))
    catch exception
        nothing
    end
end

function _r5_observe(mode::Symbol, stage::Symbol, edge::Symbol;
        input_length::Int=0, input_digest::AbstractString="none",
        output_length::Int=0, output_digest::AbstractString="none")
    utc = string(Dates.now(Dates.UTC))
    live = _r5_gc_value(:gc_live_bytes)
    rss = _r5_rss()
    println("R5_STAGE mode=$(mode) stage=$(stage) edge=$(edge) " *
        "utc=$(utc) pid=$(getpid()) rss_bytes=$(rss === nothing ? :unavailable : rss) " *
        "gc_live_bytes=$(live === nothing ? :unavailable : live) " *
        "input_length=$(input_length) input_digest=$(input_digest) " *
        "output_length=$(output_length) output_digest=$(output_digest)")
    flush(stdout)
    nothing
end

function _r5_backtrace_hash(frames)
    A.canonical_hash(Tuple(string(frame) for frame in frames))
end

function _r5_stage_run(mode::Symbol, stage::Symbol, thunk::Function;
        input_length::Int=0, input_digest::AbstractString="none")
    _r5_observe(mode, stage, :before; input_length=input_length,
        input_digest=input_digest)
    started = time()
    result = try
        thunk()
    catch exception
        message = sprint(showerror, exception)
        println("R5_STAGE_FAILURE mode=$(mode) stage=$(stage) " *
            "exception_type=$(nameof(typeof(exception))) " *
            "exception_message_hash=$(A.canonical_hash(message).value) " *
            "backtrace_hash=$(_r5_backtrace_hash(catch_backtrace()).value) " *
            "input_digest=$(input_digest)")
        flush(stdout)
        rethrow()
    end
    elapsed = time() - started
    result
end

function _r5_input_digest(input)
    transport = input.transport
    declarations = transport.declarations
    A.canonical_hash((candidate_ref=input.candidate_ref,
        bundle_hash=transport.bundle_hash,
        prior_bundle_sha256=input.t0_recheck.prior_bundle_sha256,
        declaration_hashes=Tuple(d isa A.VNextT0LocalPresentDeclarationV1 ?
            d.declaration_bytes.sha256 : nothing for d in declarations),
        child_kinds=Tuple(child.kind for child in transport.children),
        feedback_ids=Tuple(item.target_id for item in transport.feedback)))
end

function _r5_build_input()
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
        A.VNextT0LocalFeedbackV1(id, layer, candidate, target, body,
            A.canonical_hash(body))
    end, 2)
    transport_admission = A.vnext_declaration_transport_local_v1(
        candidate, declarations, children, feedback)
    transport_admission.status === :valid ||
        error("R5 source-backed transport failed: $(transport_admission.errors)")
    recheck = A.vnext_declaration_authority_recheck_local_v1(
        A.VNextAuthorityRecheckLocalInputV1(candidate,
            transport_admission.transport, declarations))
    A.VNextT1AdmissionInputV1(candidate, recheck,
        transport_admission.transport, nothing)
end

mode = length(ARGS) == 1 ? Symbol(ARGS[1]) :
    error("exactly one mode required: $(join(string.(collect(_R5_MODES)), ", "))")
mode in _R5_MODES || error("unsupported mode: $(mode)")

_r5_observe(mode, :include_load, :before)
A.load_genome_v5_components!()
Base.include(Main, joinpath(_R5_ROOT, "test", "GenomeV5", "Integration",
    "vnext_declaration_transport_local_v1_tests.jl"))
Base.include(A, joinpath(_R5_ROOT, "src", "GenomeV5", "Integration",
    "VNextDeclarationAuthorityRecheckLocalV1.jl"))
Base.include(A, joinpath(_R5_ROOT, "src", "Contracts",
    "CandidateStatePackageV5Next.jl"))
Base.include(A, joinpath(_R5_ROOT, "src", "GenomeV5", "Integration",
    "VNextGenomeV5Integration.jl"))
_r5_observe(mode, :include_load, :after)

_r5_observe(mode, :input_build, :before)
input = _r5_build_input()
input_digest = _r5_input_digest(input)
input_length = length(input.t0_recheck.prior_bundle_bytes)
_r5_observe(mode, :input_build, :after; input_length=input_length,
    input_digest=input_digest.value)

result = nothing
output_length = 0
output_digest = "none"
elapsed = 0.0
try
    started = time()
    _r5_observe(mode, mode, :before; input_length=input_length,
        input_digest=input_digest.value)
    result = if mode === :bundle_hash_recompute
        A.vnext_t0_local_bundle_hash_recompute_v1(input.transport)
    elseif mode === :canonical_json_transport
        Vector{UInt8}(codeunits(A.canonical_json(input.transport)))
    elseif mode === :prior_bytes_compare
        bytes = Vector{UInt8}(codeunits(A.canonical_json(input.transport)))
        Tuple(bytes) == input.t0_recheck.prior_bundle_bytes ||
            throw(ArgumentError("canonical prior bundle bytes mismatch"))
        bytes
    else
        text = A.canonical_json(input.transport)
        canonical_tuple = Tuple(Vector{UInt8}(codeunits(text)))
        A.VNextT1CanonicalBytesV1(canonical_tuple)
    end
    elapsed = time() - started
    if result isa A.Digest256
        output_length = length(result.value)
        output_digest = result.value
    elseif result isa A.VNextT1CanonicalBytesV1
        output_length = length(result.bytes)
        output_digest = result.sha256.value
    else
        output_length = length(result)
        output_digest = bytes2hex(SHA.sha256(result))
    end
    _r5_observe(mode, mode, :after; input_length=input_length,
        input_digest=input_digest.value, output_length=output_length,
        output_digest=output_digest)
    println("R5_RESULT mode=$(mode) status=completed elapsed_seconds=$(elapsed) " *
        "input_length=$(input_length) input_digest=$(input_digest.value) " *
        "output_length=$(output_length) output_digest=$(output_digest)")
    flush(stdout)
catch exception
    message = sprint(showerror, exception)
    println("R5_RESULT mode=$(mode) status=failed elapsed_seconds=$(elapsed) " *
        "exception_type=$(nameof(typeof(exception))) " *
        "exception_message_hash=$(A.canonical_hash(message).value) " *
        "backtrace_hash=$(_r5_backtrace_hash(catch_backtrace()).value) " *
        "input_length=$(input_length) input_digest=$(input_digest.value)")
    flush(stdout)
    rethrow()
end
