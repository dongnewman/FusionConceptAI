using SHA
using Dates
using FusionConceptAI

const _R4_ROOT = normpath(joinpath(@__DIR__, "..", "..", "..", ".."))
const _R4_REPO = realpath(_R4_ROOT)
const A = FusionConceptAI

function _r4_working_set()
    Sys.iswindows() || return nothing
    try
        text = read(`powershell.exe -NoProfile -NonInteractive -Command "(Get-Process -Id $(getpid())).WorkingSet64"`, String)
        parse(Int, strip(text))
    catch exception
        nothing
    end
end

function _r4_gc_value(name::Symbol)
    isdefined(Base, name) || return nothing
    try
        getfield(Base, name)()
    catch exception
        nothing
    end
end

function _r4_stage(stage::Symbol, edge::Symbol)
    utc = string(Dates.now(Dates.UTC))
    live = _r4_gc_value(:gc_live_bytes)
    total = _r4_gc_value(:gc_total_bytes)
    working_set = _r4_working_set()
    println("R4_STAGE stage=$(stage) edge=$(edge) utc=$(utc) " *
        "gc_live_bytes=$(live === nothing ? :unavailable : live) " *
        "gc_total_bytes=$(total === nothing ? :unavailable : total) " *
        "working_set_bytes=$(working_set === nothing ? :unavailable : working_set)")
    flush(stdout)
    nothing
end

function _r4_stage_run(thunk::Function, stage::Symbol)
    _r4_stage(stage, :before)
    result = try
        thunk()
    catch exception
        message = sprint(showerror, exception)
        println("R4_STAGE_FAILURE stage=$(stage) exception_type=$(nameof(typeof(exception))) " *
            "exception_message_hash=$(A.canonical_hash(message).value)")
        flush(stdout)
        rethrow()
    end
    _r4_stage(stage, :after)
    result
end

_r4_stage(:include_load, :before)
A.load_genome_v5_components!()
Base.include(Main, joinpath(_R4_ROOT, "test", "GenomeV5", "Integration",
    "vnext_declaration_transport_local_v1_tests.jl"))
Base.include(A, joinpath(_R4_ROOT, "src", "GenomeV5", "Integration",
    "VNextDeclarationAuthorityRecheckLocalV1.jl"))
Base.include(A, joinpath(_R4_ROOT, "src", "Contracts",
    "CandidateStatePackageV5Next.jl"))
Base.include(A, joinpath(_R4_ROOT, "src", "GenomeV5", "Integration",
    "VNextGenomeV5Integration.jl"))
_r4_stage(:include_load, :after)

valid_input = _r4_stage_run(:input_build) do
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
        error("R4 source-backed transport failed: $(transport_admission.errors)")
    recheck = A.vnext_declaration_authority_recheck_local_v1(
        A.VNextAuthorityRecheckLocalInputV1(candidate,
            transport_admission.transport, declarations))
    A.VNextT1AdmissionInputV1(candidate, recheck,
        transport_admission.transport, nothing)
end

prior = _r4_stage_run(:snapshot) do
    A._vnext_t1_snapshot(valid_input)
end

declarations = ntuple(i -> _r4_stage_run(Symbol("declaration_record_", i)) do
    declaration = valid_input.transport.declarations[i]
    A._vnext_t1_declaration_record(declaration, valid_input.candidate_ref)
end, 3)

children = _r4_stage_run(:children) do
    A._vnext_t1_child_tuple(valid_input.transport, valid_input.candidate_ref)
end

raw_feedback = valid_input.transport.feedback
_r4_stage_run(:feedback_input_validation) do
    A._vnext_t1_validate_feedback_order(raw_feedback)
end
typed_feedback = ntuple(i -> raw_feedback[i]::A.VNextT0LocalFeedbackV1,
    length(raw_feedback))
feedback = _r4_stage_run(:feedback) do
    A._vnext_t1_feedback_tuple(typed_feedback,
        valid_input.transport.declarations, valid_input.candidate_ref)
end

no_legacy = _r4_stage_run(:no_legacy) do
    receipt = A.vnext_t1_no_legacy_receipt_v1(valid_input.candidate_ref)
    A._vnext_t1_validate_no_legacy_receipt(receipt, valid_input.candidate_ref)
    receipt
end

axes = ntuple(i -> declarations[i].axes, 3)
source_hashes = ntuple(i -> declarations[i].source_bytes.sha256, 3)
declaration_hashes = ntuple(i -> declarations[i].declaration_bytes.sha256, 3)

gate = _r4_stage_run(:output_gate) do
    A._vnext_t1_output_gate(valid_input, prior, declarations, children,
        feedback)
end

_r4_stage_run(:package) do
    A._vnext_t1_package(valid_input.candidate_ref, declarations, children,
        axes, feedback, source_hashes, declaration_hashes, gate, no_legacy)
end

println("R4_STAGE_PROBE status=completed last_stage=package")
flush(stdout)
