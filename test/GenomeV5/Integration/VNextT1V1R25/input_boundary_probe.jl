using Test, SHA, JSON3, Dates

const R25_ROOT = normpath(joinpath(@__DIR__, "..", "..", "..", ".."))
const R25_MANIFEST = joinpath(R25_ROOT, "docs/implementation/UP1-04A-VNEXT-T1/agent_local_r23_owned_deepcopy_delta04/selection_static/static_manifest.json")
const R25_PINS = JSON3.read(read(R25_MANIFEST, String)).before_protected
const R25_SOURCE = joinpath(R25_ROOT, "test/GenomeV5/Integration/vnext_t1_candidate_state_package_v5_next_formal_v2_tests.jl")
const R25_TEST_SOURCE = joinpath(Sys.STDLIB, "Test", "src", "Test.jl")
r25_sha(path) = uppercase(bytes2hex(sha256(read(path))))
function r25_pins()
    Dict(String(rel) => (bytes=filesize(joinpath(R25_ROOT, String(rel))),
        sha256=r25_sha(joinpath(R25_ROOT, String(rel)))) for rel in keys(R25_PINS))
end
const R25_BEFORE = r25_pins()
const R25_OWN_SHA = r25_sha(@__FILE__)
const R25_TEST_SHA = r25_sha(R25_TEST_SOURCE)
for (rel, expected) in pairs(R25_PINS)
    observed = R25_BEFORE[String(rel)]
    observed.bytes == expected.bytes && observed.sha256 == expected.sha256 || error("protected source drift: $rel")
end

function r25_parse(path)
    function check(x)
        x isa Expr || return
        x.head in (:error, :incomplete) && error("parse failed: $path")
        foreach(check, x.args)
    end
    check(Meta.parseall(read(path, String)))
end
function r25_mark(stage)
    println("R25_STAGE utc=", Dates.now(Dates.UTC), " stage=", stage)
    flush(stdout)
end
function r25_write(path, object)
    ispath(path) && error("evidence already exists")
    open(path, "w") do io
        JSON3.write(io, object)
    end
end
function r25_out(relative)
    isabspath(relative) && error("absolute evidence path")
    ".." in splitpath(relative) && error("evidence traversal")
    path = normpath(joinpath(R25_ROOT, relative))
    allowed = normpath(joinpath(R25_ROOT, "docs/implementation/UP1-04A-VNEXT-T1"))
    startswith(path, allowed * string(Base.Filesystem.path_separator)) || error("evidence root")
    isdir(path) || error("monitor must create fresh evidence leaf")
    path
end
function r25_unchanged()
    R25_BEFORE == r25_pins() && R25_OWN_SHA == r25_sha(@__FILE__) &&
        R25_TEST_SHA == r25_sha(R25_TEST_SOURCE) || error("source changed")
    true
end

# Standalone mechanism only: load the exact fixture/helper definitions, not
# any formal testset or terminal acceptance println. Never claim coverage.
const R25_DEFINITION_OMISSIONS = Dict("testsets" => 0, "printlns" => 0)
Base.include(Main, R25_SOURCE) do expression
    if expression isa Expr
        if expression.head === :macrocall && string(expression.args[1]) == "@testset"
            R25_DEFINITION_OMISSIONS["testsets"] += 1
            return nothing
        elseif expression.head === :call && expression.args[1] === :println
            R25_DEFINITION_OMISSIONS["printlns"] += 1
            return nothing
        end
    end
    expression
end

function r25_static(directory)
    paths = (@__FILE__, R25_SOURCE,
        joinpath(R25_ROOT, "src/GenomeV5/Integration/VNextGenomeV5Integration.jl"),
        joinpath(R25_ROOT, "test/GenomeV5/Integration/VNextT1V1R18/formal_contract_v2_checks.jl"))
    foreach(r25_parse, paths)
    exact_present = G.VNextAuthorityRecheckLocalResultV1{G.VNextAuthorityRecheckLocalCheckedPresentV1}
    exact_absent = G.VNextAuthorityRecheckLocalResultV1{G.VNextAuthorityRecheckLocalTypedAbsentV1}
    allowed = fieldtype(G.VNextT1AdmissionInputV1, :t0_recheck)
    @testset "R25 pinned closed input and parse checks" begin
        @test G.VNextT1ExpectedRecheckV1 === exact_present
        @test allowed === Union{Nothing,exact_present}
        @test !(exact_absent <: allowed)
        @test exact_present <: allowed
        @test Nothing <: allowed
        @test fieldnames(G.VNextT1AdmissionInputV1) ==
            (:candidate_ref, :t0_recheck, :transport, :no_legacy_receipt)
        @test R25_DEFINITION_OMISSIONS["testsets"] == 2
        @test R25_DEFINITION_OMISSIONS["printlns"] == 5
        @test r25_unchanged()
    end
    r25_write(joinpath(directory, "static_and_preregistration.json"),
        (parse_files=length(paths), allowed_recheck_type=string(allowed),
            typed_absent_type=string(exact_absent), absent_subtype_allowed=false,
            definition_only_omissions=R25_DEFINITION_OMISSIONS,
            own_sha256=R25_OWN_SHA, before_protected=R25_BEFORE,
            test_error_source=R25_TEST_SOURCE, test_error_source_sha256=R25_TEST_SHA,
            renderer="Test.Error(:nontest_error, Expr(:tuple), captured_exception, captured_exception_stack, source)",
            renderer_source_lines="Test.jl:220-246; eager show_exception_stack then sprint(show,value,context=:limit=>true)",
            exception_metadata_rule="nameof(typeof(err)), finite function/argument type names and fixed-field canonical digest; no exception value formatting before rendering stage",
            formal_T1=false, diagnostic_only=true, actual_model_attestation="unavailable"))
end

Base.@noinline Base.@nospecializeinfer function r25_positive(@nospecialize(fixture), directory)
    r25_mark("positive_input:before")
    input = _t1_input(fixture)
    checks = (exact_type=typeof(input) === G.VNextT1AdmissionInputV1,
        candidate_same=input.candidate_ref === _T1_CANDIDATE,
        recheck_same=input.t0_recheck === fixture.recheck,
        transport_same=input.transport === fixture.transport,
        no_legacy_same=input.no_legacy_receipt === nothing)
    all(values(checks)) || error("positive input field mismatch")
    r25_write(joinpath(directory, "positive_input.json"), (checks=checks, formal_T1=false))
    r25_mark("positive_input:after")
    nothing
end

Base.@noinline Base.@nospecializeinfer function r25_attempt(
        @nospecialize(fixture), @nospecialize(absent_recheck), directory)
    stage = :kwargs_input_constructor
    started = time_ns()
    admission_calls = 0
    r25_mark("kwargs_input_constructor:before")
    try
        input = _t1_input(fixture; t0=absent_recheck)
        r25_mark("kwargs_input_constructor:after")
        r25_write(joinpath(directory, "constructor_success.json"),
            (input_type=string(typeof(input)), recheck_same=input.t0_recheck === absent_recheck,
                seconds=(time_ns()-started)/1e9, formal_T1=false))
        stage = :admission
        admission_calls += 1
        r25_mark("admission:before")
        admitted = G.vnext_t1_admit_skeleton_v1(input)
        r25_mark("admission:after")
        r25_write(joinpath(directory, "boundary_outcome.json"),
            (outcome=:returned, stage=stage, admission_calls=admission_calls,
                status=admitted.status, resolution=admitted.resolution,
                accepted=admitted.accepted, package_absent=admitted.package === nothing,
                seconds=(time_ns()-started)/1e9, source_unchanged=r25_unchanged(), formal_T1=false))
        return nothing
    catch err
        exception_stack = Base.current_exceptions()
        r25_mark(string(stage) * ":caught")
        exception_type = nameof(typeof(err))
        digest = G.canonical_hash((status=:caught, stage=stage, exception_type=exception_type))
        is_method_error = err isa MethodError
        finite_metadata = (is_method_error=is_method_error,
            function_is_convert=is_method_error && err.f === Base.convert,
            argument_count=is_method_error && err.args isa Tuple ? length(err.args) : 0,
            argument_type_names=is_method_error && err.args isa Tuple ?
                Tuple(string(nameof(typeof(arg))) for arg in err.args) : ())
        r25_write(joinpath(directory, "boundary_outcome.json"),
            (outcome=:caught, stage=stage, exception_type=exception_type,
                fixed_field_digest=digest.value, metadata=finite_metadata,
                admission_calls=admission_calls, seconds=(time_ns()-started)/1e9,
                source_unchanged=r25_unchanged(), full_fixture_retained=true,
                exception_value_formatted=false, formal_T1=false))
        r25_mark("boundary_outcome_saved")
        return (exception=err, stack=exception_stack)
    end
end

Base.@noinline Base.@nospecializeinfer function r25_render(@nospecialize(captured), directory)
    started = time_ns()
    r25_mark("test_error_render:before")
    rendered = Test.Error(:nontest_error, Expr(:tuple), captured.exception,
        captured.stack, LineNumberNode(181, Symbol(R25_SOURCE)))
    r25_mark("test_error_render:after")
    r25_write(joinpath(directory, "render_result.json"),
        (seconds=(time_ns()-started)/1e9, value_bytes=ncodeunits(rendered.value),
            backtrace_bytes=ncodeunits(rendered.backtrace),
            value_sha256=bytes2hex(sha256(codeunits(rendered.value))),
            backtrace_sha256=bytes2hex(sha256(codeunits(rendered.backtrace))), formal_T1=false))
    nothing
end

length(ARGS) == 2 && ARGS[1] in ("--static", "--probe") || error("usage: --static|--probe <new-evidence-dir>")
directory = r25_out(ARGS[2])
r25_static(directory)
if ARGS[1] == "--probe"
    r25_mark("fixture:before")
    fixture = _t1_fixture()
    r25_mark("fixture:after")
    r25_positive(fixture, directory)
    r25_mark("absent_recheck:before")
    absent_g3 = G.VNextT0LocalAbsentDeclarationV1(:G3, _T1_CANDIDATE,
        :missing_material, :terminal_deferred)
    absent_recheck = G.vnext_declaration_authority_recheck_local_v1(
        G.VNextAuthorityRecheckLocalInputV1(_T1_CANDIDATE, fixture.transport,
            (fixture.declarations[1], fixture.declarations[2], absent_g3)))
    r25_mark("absent_recheck:after")
    absent_recheck.status === :typed_absent && absent_recheck.resolution === :terminal_deferred ||
        error("actual fixture did not produce typed absence")
    r25_write(joinpath(directory, "actual_input_types.json"),
        (present_type=string(typeof(fixture.recheck)), absent_type=string(typeof(absent_recheck)),
            allowed_field_type=string(fieldtype(G.VNextT1AdmissionInputV1, :t0_recheck)),
            absent_isa_allowed=isa(absent_recheck, fieldtype(G.VNextT1AdmissionInputV1, :t0_recheck)),
            present_prior_length=length(fixture.recheck.prior_bundle_bytes),
            absent_prior_length=length(absent_recheck.prior_bundle_bytes),
            bundle_hash=fixture.transport.bundle_hash.value,
            absent_prior_bundle_hash=absent_recheck.prior_bundle_sha256.value,
            formal_T1=false))
    captured = r25_attempt(fixture, absent_recheck, directory)
    captured === nothing || r25_render(captured, directory)
    r25_write(joinpath(directory, "complete.json"),
        (source_unchanged=r25_unchanged(), rendering_attempted=captured !== nothing,
            formal_T1=false, diagnostic_only=true, pid=getpid(), utc=string(Dates.now(Dates.UTC))))
    r25_mark("complete_not_formal")
else
    println("R25_STATIC_PASS product_fixture_execution=false"); flush(stdout)
end
