using Test, Serialization, SHA, JSON3, Dates

include(joinpath(@__DIR__, "path_guard_r26.jl"))

const R26_V2_ROOT = realpath(joinpath(@__DIR__, "..", "..", "..", ".."))
const R26_V2_PROTOCOL_PATH = joinpath(@__DIR__, "protocol_r26_v9.json")
const R26_V2_SOURCE = normpath(joinpath(R26_V2_ROOT,
    "test/GenomeV5/Integration/VNextT1V2/vnext_t1_v2_same_chain_tests.jl"))
const R26_V2_TESTSETS = Expr[]
const R26_V2_LOAD_COUNTS = Dict(:testsets => 0, :final_printlns => 0,
    :fixture_assignments => 0)
const R26_V2_INSTRUMENT_COUNTS = Dict(:carrier => 0, :admission => 0)
const R26_V2_CARRIER_SECONDS = Ref(Inf)
const R26_V2_CARRIER_BYTES = Ref(0)
const R26_V2_CARRIER_SHA256 = Ref("")
const R26_V2_PACKAGE_SECONDS = Ref(Inf)

function r26_v2_timed_recheck(input)
    started = time_ns()
    result = G_V2.vnext_declaration_authority_recheck_local_v2(input)
    R26_V2_CARRIER_SECONDS[] = (time_ns() - started) / 1.0e9
    R26_V2_CARRIER_BYTES[] = length(G_V2.copy_bytes(result.prior_bundle_bytes))
    R26_V2_CARRIER_SHA256[] = result.prior_bundle_bytes.sha256.value
    result
end

function r26_v2_timed_admission(input)
    started = time_ns()
    result = G_V2.vnext_t1_admit_v2(input)
    R26_V2_PACKAGE_SECONDS[] = (time_ns() - started) / 1.0e9
    result
end

r26_v2_sha(bytes) = uppercase(bytes2hex(sha256(bytes)))
r26_v2_expr_hash(x) = r26_v2_sha(codeunits(sprint(show, x)))
r26_v2_digest(path) = begin
    bytes = read(path); (bytes=length(bytes), sha256=r26_v2_sha(bytes))
end
r26_v2_testset(x) = x isa Expr && x.head === :macrocall &&
    string(x.args[1]) == "@testset"

function r26_v2_title(x)
    r26_v2_testset(x) || return nothing
    for arg in x.args[3:end]
        arg isa String && return arg
    end
    nothing
end

function r26_v2_top_testsets(ast)
    expressions = ast isa Expr && ast.head === :toplevel ? ast.args : Any[ast]
    Expr[expression for expression in expressions if r26_v2_testset(expression)]
end

function r26_v2_line_files(x, files=String[])
    if x isa LineNumberNode
        push!(files, string(x.file))
    elseif x isa Expr
        foreach(arg -> r26_v2_line_files(arg, files), x.args)
    elseif x isa QuoteNode
        r26_v2_line_files(x.value, files)
    end
    files
end

function r26_v2_distinct_line_files(x)
    files = r26_v2_line_files(x)
    unique!(files)
    sort!(files)
end

function r26_v2_defines_fixture(x)
    x isa Expr || return false
    x.head === :(=) && !isempty(x.args) && x.args[1] === :_V2_FIXTURE && return true
    x.head === :const && any(r26_v2_defines_fixture, x.args) && return true
    false
end

function r26_v2_load_filter(expression)
    if r26_v2_testset(expression)
        push!(R26_V2_TESTSETS, expression)
        R26_V2_LOAD_COUNTS[:testsets] += 1
        return nothing
    elseif r26_v2_defines_fixture(expression)
        R26_V2_LOAD_COUNTS[:fixture_assignments] += 1
        return nothing
    elseif expression isa Expr && expression.head === :call &&
            !isempty(expression.args) && expression.args[1] === :println
        R26_V2_LOAD_COUNTS[:final_printlns] += 1
        return nothing
    end
    r26_v2_instrument_fixture(expression)
end

function r26_v2_instrument_fixture(x)
    x isa Expr || return x
    if x.head === :(=) && length(x.args) == 2 && x.args[1] === :recheck &&
            r26_v2_has_call(x.args[2], :vnext_declaration_authority_recheck_local_v2)
        R26_V2_INSTRUMENT_COUNTS[:carrier] += 1
        return Expr(:(=), :recheck,
            Expr(:call, :r26_v2_timed_recheck, x.args[2].args[2:end]...))
    elseif x.head === :(=) && length(x.args) == 2 && x.args[1] === :admission &&
            r26_v2_has_call(x.args[2], :vnext_t1_admit_v2)
        R26_V2_INSTRUMENT_COUNTS[:admission] += 1
        return Expr(:(=), :admission,
            Expr(:call, :r26_v2_timed_admission, x.args[2].args[2:end]...))
    end
    Expr(x.head, map(r26_v2_instrument_fixture, x.args)...)
end

function r26_v2_has_call(x, name::Symbol)
    x isa Expr || return false
    if x.head === :call && !isempty(x.args)
        callee = x.args[1]
        callee === name && return true
        callee isa Expr && callee.head === :. && !isempty(callee.args) &&
            callee.args[end] isa QuoteNode && callee.args[end].value === name && return true
    end
    any(arg -> r26_v2_has_call(arg, name), x.args)
end

function r26_v2_contains_string(x, value::String)
    x == value && return true
    x isa Expr || return false
    any(arg -> r26_v2_contains_string(arg, value), x.args)
end

function r26_v2_suppress_historical_writer(x, count)
    x isa Expr || return x
    if x.head === :|| && r26_v2_has_call(x, :mkpath)
        count[] += 1
        return nothing
    elseif x.head === :do && r26_v2_contains_string(x,
            "candidate_state_package_v5_next_v2_r11.serialized")
        count[] += 1
        return nothing
    end
    Expr(x.head, map(arg -> r26_v2_suppress_historical_writer(arg, count), x.args)...)
end

function r26_v2_verify_dependencies(protocol)
    actual = Dict{String,Any}()
    for row in protocol.dependencies
        rel = String(row.path)
        path = r26_guard_existing_repo_file(R26_V2_ROOT, rel;
            label="frozen dependency")
        got = r26_v2_digest(path)
        got.bytes == Int(row.bytes) && got.sha256 == String(row.sha256) ||
            error("frozen dependency drift: $rel")
        actual[rel] = got
    end
    actual
end

function r26_v2_arg(name)
    index = findfirst(==(name), ARGS)
    index === nothing && error("missing argument $name")
    index < length(ARGS) || error("missing value for $name")
    ARGS[index + 1]
end

function r26_v2_ledger_path(value)
    allowed = joinpath(R26_V2_ROOT,
        "docs/implementation/UP1-04A-VNEXT-T1/independent_formal_r26_20260922")
    r26_guard_new_owned_file(R26_V2_ROOT, allowed, value; label="ledger")
end

const R26_V2_PROTOCOL = JSON3.read(read(R26_V2_PROTOCOL_PATH, String))
R26_V2_PROTOCOL.schema == "vnext_t1_independent_formal_r26_protocol_v9" ||
    error("protocol schema mismatch")
const R26_V2_DEPENDENCIES_BEFORE = r26_v2_verify_dependencies(R26_V2_PROTOCOL)
const R26_V2_SOURCE_TEXT = read(R26_V2_SOURCE, String)
const R26_V2_DEFAULT_TESTSETS = r26_v2_top_testsets(
    Meta.parseall(R26_V2_SOURCE_TEXT))
const R26_V2_CONTEXT_TESTSETS = r26_v2_top_testsets(
    Meta.parseall(R26_V2_SOURCE_TEXT; filename=R26_V2_SOURCE))
length(R26_V2_PROTOCOL.v2.legacy_testsets) == 7 ||
    error("protocol V2 testset inventory drift")
length(R26_V2_DEFAULT_TESTSETS) == length(R26_V2_CONTEXT_TESTSETS) == 7 ||
    error("V2 two-context source testset inventory drift")
for (default_expression, frozen) in zip(R26_V2_DEFAULT_TESTSETS,
        R26_V2_PROTOCOL.v2.legacy_testsets)
    frozen_title = String(frozen.title)
    r26_v2_title(default_expression) == frozen_title ||
        error("V2 default-source testset title drift: $frozen_title")
    r26_v2_expr_hash(default_expression) == String(frozen.ast_sha256) ||
        error("V2 default-source AST drift: $frozen_title")
end

# Import the frozen producer and mutation helpers, while capturing all seven
# historical testsets and withholding their old evidence writer.
Base.include(r26_v2_load_filter, Main, R26_V2_SOURCE)
R26_V2_LOAD_COUNTS == Dict(:testsets => 7, :final_printlns => 1,
    :fixture_assignments => 1) || error("V2 top-level inventory drift")
R26_V2_INSTRUMENT_COUNTS == Dict(:carrier => 1, :admission => 1) ||
    error("V2 core timing instrumentation drift")

length(R26_V2_TESTSETS) == 7 || error("V2 captured testset inventory drift")
ast_context_rows = Any[]
for (default_expression, context_expression, captured_expression, frozen) in zip(
        R26_V2_DEFAULT_TESTSETS, R26_V2_CONTEXT_TESTSETS, R26_V2_TESTSETS,
        R26_V2_PROTOCOL.v2.legacy_testsets)
    frozen_title = String(frozen.title)
    default_title = r26_v2_title(default_expression)
    context_title = r26_v2_title(context_expression)
    captured_title = r26_v2_title(captured_expression)
    default_title == context_title == captured_title == frozen_title ||
        error("V2 two-context testset title drift: $frozen_title")
    default_hash = r26_v2_expr_hash(default_expression)
    context_hash = r26_v2_expr_hash(context_expression)
    captured_hash = r26_v2_expr_hash(captured_expression)
    default_hash == String(frozen.ast_sha256) ||
        error("V2 default-source AST drift: $frozen_title")
    context_hash == captured_hash ||
        error("V2 include-context AST drift: $frozen_title")
    default_files = r26_v2_distinct_line_files(default_expression)
    context_files = r26_v2_distinct_line_files(context_expression)
    captured_files = r26_v2_distinct_line_files(captured_expression)
    context_files == captured_files ||
        error("V2 include-context line metadata drift: $frozen_title")
    push!(ast_context_rows, (title=frozen_title,
        ast_sha256=String(frozen.ast_sha256),
        default_source_ast_sha256=default_hash,
        filename_context_ast_sha256=context_hash,
        captured_ast_sha256=captured_hash,
        context_match=true,
        default_source_line_files=default_files,
        filename_context_line_files=context_files,
        captured_line_files=captured_files))
end

fixture_ref = Ref{Any}()
const R26_V2_FIXTURE_SETUP_SECONDS = @elapsed fixture_ref[] = _v2_chain_fixture()
const _V2_FIXTURE = fixture_ref[]
const R26_V2_PACKAGE_LIMIT = Float64(R26_V2_PROTOCOL.resources.package_integrator_seconds)
const R26_V2_CARRIER_LIMIT = Float64(R26_V2_PROTOCOL.resources.carrier_seconds)
const R26_V2_CARRIER_EXPECTED_BYTES = Int(
    R26_V2_PROTOCOL.v2.carrier_fixture.expected_bytes)
const R26_V2_CARRIER_EXPECTED_SHA256 = String(
    R26_V2_PROTOCOL.v2.carrier_fixture.wire_sha256)
String(R26_V2_PROTOCOL.v2.carrier_fixture.fixture_source) ==
        String(R26_V2_PROTOCOL.v2.source.path) ||
    error("V2 carrier fixture source path mismatch")
String(R26_V2_PROTOCOL.v2.carrier_fixture.fixture_source_sha256) ==
        String(R26_V2_PROTOCOL.v2.source.sha256) ||
    error("V2 carrier fixture source hash mismatch")

function r26_v2_result_with(r; status=r.status, resolution=r.resolution,
        accepted=r.accepted, claim_ceiling=r.claim_ceiling, output=r.output,
        errors=r.errors, reasons=r.reasons,
        prior_bundle_bytes=r.prior_bundle_bytes,
        prior_bundle_sha256=r.prior_bundle_sha256)
    G_V2.VNextAuthorityRecheckLocalV2Result(status, resolution, accepted,
        claim_ceiling, output, Tuple(errors), Tuple(reasons),
        prior_bundle_bytes, prior_bundle_sha256)
end

function r26_v2_input(f, transport, recheck)
    G_V2.VNextT1AdmissionInputV2(f.input.candidate_ref, transport, recheck,
        f.input.parent_commitments, f.input.g3_expected_commitment,
        f.input.g3_authority)
end

function r26_v2_absent_transport(t; candidate=Main._T0L_CANDIDATE,
        reason=:missing_material, status=:terminal_deferred)
    absent = G_V2.VNextT0LocalAbsentDeclarationV1(:G3, candidate, reason, status)
    _v2_rebuild_transport(t;
        declarations=(t.declarations[1], t.declarations[2], absent))
end

function r26_v2_checked_with(output; candidate_ref=output.candidate_ref,
        bundle_hash=output.bundle_hash, declarations=output.declarations,
        children=output.children, feedback=output.feedback,
        g3_children_deferred=output.g3_children_deferred)
    G_V2.VNextAuthorityRecheckLocalV2Checked(candidate_ref, bundle_hash,
        Tuple(declarations), Tuple(children), Tuple(feedback), g3_children_deferred)
end

function r26_v2_exception(f)
    try
        f()
        (thrown=false, exception_type="none")
    catch err
        (thrown=true, exception_type=string(nameof(typeof(err))))
    end
end

r26_v2_result_metadata(r) = (status=String(r.status),
    resolution=String(r.resolution), accepted=r.accepted,
    claim_ceiling=String(r.claim_ceiling), package_absent=r.package === nothing,
    errors=String.(collect(r.errors)), gaps=String.(collect(r.gaps)),
    trace=String.(collect(r.trace)))
r26_v2_recheck_metadata(r) = (status=String(r.status),
    resolution=String(r.resolution), accepted=r.accepted,
    claim_ceiling=String(r.claim_ceiling), output_type=r.output === nothing ?
        "Nothing" : string(nameof(typeof(r.output))),
    errors=String.(collect(r.errors)), reasons=String.(collect(r.reasons)),
    prior_bundle_sha256=r.prior_bundle_sha256.value,
    wire_sha256=r.prior_bundle_bytes.sha256.value,
    wire_bytes=length(G_V2.copy_bytes(r.prior_bundle_bytes)))

const R26_V2_INPUT_BEFORE = (transport=G_V2.canonical_hash(_V2_FIXTURE.transport),
    recheck_wire=_V2_FIXTURE.recheck.prior_bundle_bytes.sha256,
    package_hash=_V2_FIXTURE.admission.package.package_hash)

f = _V2_FIXTURE
t = f.transport
absent_t = r26_v2_absent_transport(t)
absent_r = G_V2.vnext_declaration_authority_recheck_local_v2(
    G_V2.VNextAuthorityRecheckLocalV2Input(Main._T0L_CANDIDATE, absent_t))
absent_admission = G_V2.vnext_t1_admit_v2(r26_v2_input(f, absent_t, absent_r))
forward_mismatch = G_V2.vnext_t1_admit_v2(r26_v2_input(f, t, absent_r))
reverse_mismatch = G_V2.vnext_t1_admit_v2(r26_v2_input(f, absent_t, f.recheck))
absence_constructor = r26_v2_exception(() -> G_V2.CandidateStatePackageV5NextV2(
    f.input.candidate_ref, absent_t, absent_r, f.input.parent_commitments,
    f.input.g3_authority, f.input.g3_expected_commitment))

missing_transport_recheck = G_V2.vnext_declaration_authority_recheck_local_v2(
    G_V2.VNextAuthorityRecheckLocalV2Input(Main._T0L_CANDIDATE, nothing))
present_with_missing = G_V2.vnext_t1_admit_v2(
    r26_v2_input(f, t, missing_transport_recheck))

foreign = G_V2.QualifiedRefV1("local://r26-formal-foreign", "v5")
malformed_transports = (
    (name=:candidate, transport=r26_v2_absent_transport(t; candidate=foreign),
        error=:candidate_mismatch),
    (name=:status, transport=r26_v2_absent_transport(t; status=:present),
        error=:absence_status_invalid),
    (name=:reason, transport=r26_v2_absent_transport(t; reason=:invented),
        error=:absence_reason_invalid),
)
malformed_actual = map(malformed_transports) do row
    bad_r = G_V2.vnext_declaration_authority_recheck_local_v2(
        G_V2.VNextAuthorityRecheckLocalV2Input(Main._T0L_CANDIDATE, row.transport))
    direct = G_V2.vnext_t1_admit_v2(r26_v2_input(f, row.transport, bad_r))
    reasons = G_V2._vnext_ar_v2_absence_reasons(row.transport.declarations)
    forged_output = G_V2.VNextAuthorityRecheckLocalV2TypedAbsent(
        Main._T0L_CANDIDATE, row.transport.bundle_hash, reasons, true)
    forged = G_V2.VNextAuthorityRecheckLocalV2Result(:typed_absent,
        :terminal_deferred, false, :contract_only, forged_output, (), reasons,
        bad_r.prior_bundle_bytes, bad_r.prior_bundle_sha256)
    laundered = G_V2.vnext_t1_admit_v2(r26_v2_input(f, row.transport, forged))
    (name=row.name, expected=row.error, recheck=bad_r, direct=direct,
        laundered=laundered)
end

detached_io = IOBuffer()
Serialization.serialize(detached_io, f.recheck)
detached_recheck = Serialization.deserialize(IOBuffer(take!(detached_io)))
detached_admission = G_V2.vnext_t1_admit_v2(r26_v2_input(f, t, detached_recheck))
detached_direct = G_V2.CandidateStatePackageV5NextV2(f.input.candidate_ref,
    t, detached_recheck, f.input.parent_commitments, f.input.g3_authority,
    f.input.g3_expected_commitment)
failed_recheck_constructor = r26_v2_exception(() ->
    G_V2.CandidateStatePackageV5NextV2(f.input.candidate_ref,
        malformed_transports[1].transport, malformed_actual[1].recheck,
        f.input.parent_commitments, f.input.g3_authority,
        f.input.g3_expected_commitment))

checked_absent_output = G_V2.VNextAuthorityRecheckLocalV2Checked(
    Main._T0L_CANDIDATE, absent_t.bundle_hash, absent_t.declarations,
    absent_t.children, absent_t.feedback, true)
checked_absent_envelope = r26_v2_result_with(absent_r;
    status=:local_checked_present, resolution=:resolved,
    output=checked_absent_output, errors=(), reasons=())
checked_absent_constructor = r26_v2_exception(() ->
    G_V2.CandidateStatePackageV5NextV2(f.input.candidate_ref, absent_t,
        checked_absent_envelope, f.input.parent_commitments,
        f.input.g3_authority, f.input.g3_expected_commitment))
checked_absent_admission = G_V2.vnext_t1_admit_v2(
    r26_v2_input(f, absent_t, checked_absent_envelope))

children_output = r26_v2_checked_with(f.recheck.output;
    children=reverse(f.recheck.output.children))
children_envelope = r26_v2_result_with(f.recheck; output=children_output)
children_rejected = G_V2.vnext_t1_admit_v2(r26_v2_input(f, t, children_envelope))
feedback_output = r26_v2_checked_with(f.recheck.output;
    feedback=reverse(f.recheck.output.feedback))
feedback_envelope = r26_v2_result_with(f.recheck; output=feedback_output)
feedback_rejected = G_V2.vnext_t1_admit_v2(r26_v2_input(f, t, feedback_envelope))

contradictory_cases = (
    (name=:output_nothing, result=r26_v2_result_with(f.recheck; output=nothing),
        error=:t0_recheck_output_invalid),
    (name=:output_absent, result=r26_v2_result_with(f.recheck; output=absent_r.output),
        error=:t0_recheck_output_invalid),
    (name=:accepted, result=r26_v2_result_with(f.recheck; accepted=true),
        error=:t0_recheck_accepted_invalid),
    (name=:ceiling, result=r26_v2_result_with(f.recheck; claim_ceiling=:physical),
        error=:t0_recheck_claim_ceiling_invalid),
    (name=:errors, result=r26_v2_result_with(f.recheck; errors=(:forged,)),
        error=:t0_recheck_errors_invalid),
    (name=:reasons, result=r26_v2_result_with(f.recheck; reasons=(:forged,)),
        error=:t0_recheck_reasons_invalid),
)
contradictory_actual = map(contradictory_cases) do row
    (name=row.name, expected=row.error,
        admission=G_V2.vnext_t1_admit_v2(r26_v2_input(f, t, row.result)))
end

reload_package = Ref{Any}()
reload_adapter = Ref{Any}()
reload_binding = Ref{Any}()
serialized_size = Ref(0)
const R26_V2_RELOAD_SECONDS = @elapsed begin
    io = IOBuffer()
    Serialization.serialize(io, f.admission.package)
    bytes = take!(io)
    serialized_size[] = length(bytes)
    reload_package[] = Serialization.deserialize(IOBuffer(bytes))
    reload_adapter[] = G_V2.vnext_t1_package_binding_adapter_v2(reload_package[])
    reload_binding[] = G_V2.vnext_t1_candidate_binding_v2(
        reload_adapter[].input, (reload_adapter[].input,))
end
const R26_V2_RELOAD_LIMIT = Float64(R26_V2_PROTOCOL.resources.reload_adapter_seconds)

actual = (schema="vnext_t1_v2_actual_before_assert_r26_v1",
    fixture_setup_seconds=R26_V2_FIXTURE_SETUP_SECONDS,
    carrier_seconds=R26_V2_CARRIER_SECONDS[],
    carrier_bytes=R26_V2_CARRIER_BYTES[],
    carrier_wire_sha256=R26_V2_CARRIER_SHA256[],
    package_integrator_seconds=R26_V2_PACKAGE_SECONDS[],
    reload_adapter_seconds=R26_V2_RELOAD_SECONDS,
    present_recheck=r26_v2_recheck_metadata(f.recheck),
    honest_absence=r26_v2_recheck_metadata(absent_r),
    honest_absence_admission=r26_v2_result_metadata(absent_admission),
    forward_mismatch=r26_v2_result_metadata(forward_mismatch),
    reverse_mismatch=r26_v2_result_metadata(reverse_mismatch),
    present_with_missing_transport_recheck=r26_v2_result_metadata(present_with_missing),
    malformed=map(row -> (name=String(row.name), expected=String(row.expected),
        recheck=r26_v2_recheck_metadata(row.recheck),
        direct=r26_v2_result_metadata(row.direct),
        laundered=r26_v2_result_metadata(row.laundered)), malformed_actual),
    detached_admission=r26_v2_result_metadata(detached_admission),
    checked_absent_admission=r26_v2_result_metadata(checked_absent_admission),
    children_rejected=r26_v2_result_metadata(children_rejected),
    feedback_rejected=r26_v2_result_metadata(feedback_rejected),
    absence_constructor=absence_constructor,
    checked_absent_constructor=checked_absent_constructor,
    failed_recheck_constructor=failed_recheck_constructor,
    serialized_package_bytes=serialized_size[],
    reloaded_semantic_identity=reload_package[].semantic_identity.value,
    reloaded_package_hash=reload_package[].package_hash.value,
    binding_status=String(reload_binding[].status),
    binding_reason=String(reload_binding[].reason))
println("R26_V2_ACTUAL_BEFORE_ASSERT=", JSON3.write(actual)); flush(stdout)

@testset "R26 V2 honest absence, mismatch, and envelope separation" begin
    @test absent_r.status === :typed_absent
    @test absent_r.resolution === :terminal_deferred
    @test absent_r.accepted === false
    @test absent_r.claim_ceiling === :contract_only
    @test absent_r.errors === ()
    @test absent_r.reasons == (:missing_material, :g3_feedback_material_absent)
    @test absent_r.output isa G_V2.VNextAuthorityRecheckLocalV2TypedAbsent
    @test absent_r.output.candidate_ref == Main._T0L_CANDIDATE
    @test absent_r.output.bundle_hash == absent_t.bundle_hash
    @test absent_r.output.g3_children_deferred
    @test absent_admission.status === :terminal_deferred
    @test absent_admission.resolution === :terminal_deferred
    @test absent_admission.errors === ()
    @test absent_admission.gaps == (:t0_recheck_typed_absent,)
    @test absent_admission.package === nothing
    @test absent_admission.trace == (:entry, :recheck, :typed_absence)
    @test absence_constructor == (thrown=true, exception_type="ArgumentError")
    @test forward_mismatch.status === :fail_closed
    @test forward_mismatch.errors == (:t0_bundle_recheck_mismatch,)
    @test forward_mismatch.package === nothing
    @test reverse_mismatch.status === :fail_closed
    @test reverse_mismatch.errors == (:t0_bundle_recheck_mismatch,)
    @test reverse_mismatch.package === nothing
    @test present_with_missing.status === :fail_closed
    @test present_with_missing.errors == (:t0_bundle_recheck_mismatch,)
    @test present_with_missing.package === nothing
end

@testset "R26 V2 malformed absence cannot be laundered" begin
    for row in malformed_actual
        @test row.recheck.status === :fail_closed
        @test row.recheck.errors == (row.expected,)
        @test row.direct.status === :fail_closed
        @test row.direct.errors == (row.expected,)
        @test row.direct.package === nothing
        @test row.laundered.status === :fail_closed
        @test row.laundered.errors == (row.expected,)
        @test row.laundered.package === nothing
    end
    @test malformed_actual[1].direct.trace ==
        (:entry, :recheck, :upstream_fail_closed)
end

@testset "R26 V2 detached content joins and constructor closure" begin
    @test detached_recheck !== f.recheck
    @test detached_recheck.output !== f.recheck.output
    @test detached_admission.status === :prepared_not_executed
    @test detached_admission.package isa G_V2.CandidateStatePackageV5NextV2
    @test detached_direct isa G_V2.CandidateStatePackageV5NextV2
    @test failed_recheck_constructor == (thrown=true, exception_type="ArgumentError")
    @test checked_absent_constructor == (thrown=true, exception_type="ArgumentError")
    @test checked_absent_admission.status === :fail_closed
    @test checked_absent_admission.errors == (:t0_recheck_presence_mismatch,)
    @test checked_absent_admission.package === nothing
    @test children_rejected.status === :fail_closed
    @test children_rejected.errors == (:t0_recheck_output_children_mismatch,)
    @test children_rejected.package === nothing
    @test feedback_rejected.status === :fail_closed
    @test feedback_rejected.errors == (:t0_recheck_output_feedback_mismatch,)
    @test feedback_rejected.package === nothing
    for row in contradictory_actual
        @test row.admission.status === :fail_closed
        @test row.admission.errors == (row.expected,)
        @test row.admission.package === nothing
    end
end

@testset "R26 V2 reload adapter binding and resource gates" begin
    @test f.admission.status === :prepared_not_executed
    @test reload_package[] isa G_V2.CandidateStatePackageV5NextV2
    @test G_V2.vnext_t1_package_v2_validate(reload_package[]) === nothing
    @test reload_adapter[].status === :prepared_not_executed
    @test reload_adapter[].input !== nothing
    @test reload_binding[].status === :bound
    @test reload_binding[].reason === :exact_explicit_binding
    @test reload_package[].semantic_identity == f.admission.package.semantic_identity
    @test reload_package[].package_hash == f.admission.package.package_hash
    @test R26_V2_CARRIER_BYTES[] == R26_V2_CARRIER_EXPECTED_BYTES
    @test R26_V2_CARRIER_SHA256[] == R26_V2_CARRIER_EXPECTED_SHA256
    @test R26_V2_CARRIER_SECONDS[] <= R26_V2_CARRIER_LIMIT
    @test R26_V2_PACKAGE_SECONDS[] <= R26_V2_PACKAGE_LIMIT
    @test R26_V2_RELOAD_SECONDS <= R26_V2_RELOAD_LIMIT
end

legacy_execution = Any[]
writer_suppressions = 0
for (index, (expression, frozen)) in enumerate(zip(R26_V2_TESTSETS,
        R26_V2_PROTOCOL.v2.legacy_testsets))
    count = Ref(0)
    transformed = r26_v2_suppress_historical_writer(expression, count)
    global writer_suppressions += count[]
    println("R26_V2_LEGACY_TESTSET_START title=", frozen.title); flush(stdout)
    Core.eval(Main, transformed)
    push!(legacy_execution, merge(ast_context_rows[index],
        (status="pass", writer_suppressions=count[])))
    println("R26_V2_LEGACY_TESTSET_DONE title=", frozen.title); flush(stdout)
end
writer_suppressions == 2 || error("historical writer suppression count drift")

input_after = (transport=G_V2.canonical_hash(f.transport),
    recheck_wire=f.recheck.prior_bundle_bytes.sha256,
    package_hash=f.admission.package.package_hash)
R26_V2_INPUT_BEFORE == input_after || error("V2 fixture mutated")
dependencies_after = r26_v2_verify_dependencies(R26_V2_PROTOCOL)
R26_V2_DEPENDENCIES_BEFORE == dependencies_after || error("dependency changed during V2 run")

ledger_path = r26_v2_ledger_path(r26_v2_arg("--ledger"))
ledger = (schema="vnext_t1_v2_formal_r26_ledger_v3",
    protocol_sha256=r26_v2_digest(R26_V2_PROTOCOL_PATH).sha256,
    source=relpath(R26_V2_SOURCE, R26_V2_ROOT),
    source_sha256=r26_v2_digest(R26_V2_SOURCE).sha256,
    legacy_testsets=legacy_execution, legacy_testset_count=length(legacy_execution),
    historical_writer_suppressions=writer_suppressions,
    fixture_setup_seconds=R26_V2_FIXTURE_SETUP_SECONDS,
    carrier_seconds=R26_V2_CARRIER_SECONDS[],
    carrier_limit_seconds=R26_V2_CARRIER_LIMIT,
    carrier_expected_bytes=R26_V2_CARRIER_EXPECTED_BYTES,
    carrier_expected_sha256=R26_V2_CARRIER_EXPECTED_SHA256,
    carrier_gate_pass=R26_V2_CARRIER_BYTES[] == R26_V2_CARRIER_EXPECTED_BYTES &&
        R26_V2_CARRIER_SHA256[] == R26_V2_CARRIER_EXPECTED_SHA256 &&
        R26_V2_CARRIER_SECONDS[] <= R26_V2_CARRIER_LIMIT,
    package_integrator_seconds=R26_V2_PACKAGE_SECONDS[],
    package_integrator_limit_seconds=R26_V2_PACKAGE_LIMIT,
    package_integrator_gate_pass=R26_V2_PACKAGE_SECONDS[] <= R26_V2_PACKAGE_LIMIT,
    reload_adapter_seconds=R26_V2_RELOAD_SECONDS,
    reload_adapter_limit_seconds=R26_V2_RELOAD_LIMIT,
    reload_adapter_gate_pass=R26_V2_RELOAD_SECONDS <= R26_V2_RELOAD_LIMIT,
    wire_bytes=length(G_V2.copy_bytes(f.recheck.prior_bundle_bytes)),
    wire_sha256=f.recheck.prior_bundle_bytes.sha256.value,
    bundle_hash=f.transport.bundle_hash.value,
    semantic_identity=reload_package[].semantic_identity.value,
    package_hash=reload_package[].package_hash.value,
    serialized_package_bytes=serialized_size[], inputs_unchanged=true,
    dependencies_before=R26_V2_DEPENDENCIES_BEFORE,
    dependencies_after=dependencies_after, dependencies_unchanged=true,
    pid=getpid(), utc=string(Dates.now(Dates.UTC)), formal_T1=false,
    scientific_acceptance=false, actual_model_attestation="unavailable")
open(ledger_path, "w") do io
    JSON3.write(io, ledger); flush(io)
end
println("R26_V2_FORMAL_LEDGER=", JSON3.write(ledger)); flush(stdout)
