# Isolated test-only continuation for revalidating an already saved MMS result.
# This entrypoint must not call a provider writer or nonlinear solver.
using SHA, JSON3, Serialization, FusionConceptAI

const ROOT = normpath(joinpath(@__DIR__, "..", "..", ".."))
const PROTOCOL = joinpath(ROOT, "docs", "implementation", "UP2-04-CLOSURE-REPAIR-PREC",
    "archive", "replay_only_continuation_r4", "replay_protocol_v4.json")
const HELPER = joinpath(ROOT, "test", "RuntimeV4", "UP2ClosureRepairV1", "manufactured_candidate_v1_tests.jl")
include(HELPER)
const M = ManufacturedCandidateV1Tests
const S = M.S

sha256_file(path) = bytes2hex(SHA.sha256(read(path)))
new_json(path, value) = (ispath(path) && error("preserve existing replay evidence: $path");
    mkpath(dirname(path)); write(path, canonical_json(value) * "\n"); path)
require_exact_file(path, expected) = (read(path, String) == expected || error("pinned wire mismatch: $path"); path)

function protocol_value(expected_sha)
    isfile(PROTOCOL) || error("frozen replay protocol missing")
    sha256_file(PROTOCOL) == expected_sha || error("replay protocol SHA mismatch")
    JSON3.read(read(PROTOCOL, String))
end

function expected_hash(protocol, key)
    hasproperty(protocol.replay_inputs, key) || error("protocol missing replay input $key")
    String(getproperty(protocol.replay_inputs, key).sha256)
end

function bind_context_from_saved_parent!(out, source_root)
    preflight = joinpath(out, "context_rebuild")
    mkpath(preflight)
    x = S.spatial_n1_manufactured_input_v1()
    d = S.spatial_n1_manufactured_declaration_v1(x)
    S.validate_spatial_manufactured_input_v1(x)
    S.validate_spatial_n1_manufactured_declaration_v1(d)

    saved_input = joinpath(source_root, "preflight", "canonical_input.json")
    saved_declaration = joinpath(source_root, "preflight", "canonical_declaration.json")
    require_exact_file(saved_input, canonical_json(x) * "\n")
    require_exact_file(saved_declaration, canonical_json(d) * "\n")

    parent_dir = joinpath(preflight, "parent")
    mkpath(parent_dir)
    parent = M.build_manufactured_parent(x, parent_dir)
    for name in ("parent_candidate.json", "parent_context.json", "parent_identity.json")
        require_exact_file(joinpath(source_root, name),
            read(joinpath(parent_dir, name), String))
    end

    child = S.build_spatial_candidate_v4(parent.context, parent.physical_input; physical_declaration=d)
    context = child.context
    S.validate_spatial_candidate_v4(context)
    S.validate_forward_chain_context(context)
    context_wire = canonical_json(context) * "\n"
    require_exact_file(joinpath(source_root, "context.json"), context_wire)
    require_exact_file(joinpath(source_root, "candidate.json"), canonical_json(context.candidate) * "\n")
    identity = (candidate_hash=context.candidate_hash, context_hash=context.context_hash,
        declaration_hash=canonical_hash(d), input_hash=canonical_hash(x), parent_hash=child.parent_hash,
        changes=child.changes, provenance=child.provenance, subject_hash=canonical_hash(context.subject),
        authority=:no_publish)
    require_exact_file(joinpath(source_root, "candidate_identity.json"), canonical_json(identity) * "\n")
    context
end

function hydration_checkpoint!(out, phase, result_hash=nothing)
    path = joinpath(out, "hydration_phases", "$(phase).json")
    new_json(path, (schema="mms-replay-only-hydration-phase-v4", classification="test_only_continuation",
        phase=String(phase), completed=true, result_hash=result_hash === nothing ? nothing : string(result_hash)))
end

function result_from_saved_wire(wire, expected_result_hash, out, active_phase)
    # Typed JSON hydration is deliberately strict. A parser/type mismatch is an
    # unsupported continuation; it is never replaced by regenerated solver state.
    active_phase[] = "canonical_body_parse"
    body = S._smr_read_canonical_json_v1(wire)
    hydration_checkpoint!(out, "canonical_body_parse")
    active_phase[] = "semantic_hash_recompute"
    result_hash = canonical_hash(body)
    hydration_checkpoint!(out, "semantic_hash_recompute", result_hash)
    # canonical_json(SpatialManufacturedNumericalResultV1) emits its semantic
    # body and omits the stored result_hash field. Recompute that digest from the
    # exact retained canonical body, then inject a positional one-field NamedTuple.
    # The explicit `(; ...)` syntax is required here: without it, a parenthesized
    # singleton assignment is parsed as a keyword argument to merge.
    active_phase[] = "result_digest_injection"
    typed_body = merge(body, (; result_hash=(value=string(result_hash),)))
    hydration_checkpoint!(out, "result_digest_injection", result_hash)
    active_phase[] = "typed_wire_encoding"
    typed_wire = canonical_json(typed_body) * "\n"
    hydration_checkpoint!(out, "typed_wire_encoding", result_hash)
    active_phase[] = "json3_typed_parse"
    result = JSON3.read(typed_wire, S.SpatialManufacturedNumericalResultV1)
    hydration_checkpoint!(out, "json3_typed_parse", result_hash)
    active_phase[] = "concrete_type_check"
    result isa S.SpatialManufacturedNumericalResultV1 || error("hydrated result has wrong concrete type")
    hydration_checkpoint!(out, "concrete_type_check", result_hash)
    active_phase[] = "canonical_result_hash_check"
    canonical_hash(result) == result_hash || error("typed result hash differs from exact saved canonical body")
    hydration_checkpoint!(out, "canonical_result_hash_check", result_hash)
    active_phase[] = "protocol_result_hash_check"
    string(result.result_hash) == expected_result_hash || error("typed result hash differs from frozen protocol identity")
    hydration_checkpoint!(out, "protocol_result_hash_check", result_hash)
    active_phase[] = "canonical_wire_roundtrip"
    canonical_json(result) * "\n" == wire || error("typed result does not round-trip to exact canonical wire")
    hydration_checkpoint!(out, "canonical_wire_roundtrip", result_hash)
    result
end

function producer(args)
    length(args) == 6 || error("expected producer OUT SAVED_NUMERICAL_ROOT PROTOCOL_SHA NOT_APPLICABLE NOT_APPLICABLE")
    _, out_arg, source_arg, protocol_sha, carrier_arg, binding_arg = args
    carrier_arg == "not_applicable" && binding_arg == "not_applicable" || error("producer cannot accept consumer seals")
    out = abspath(out_arg)
    source_root = abspath(source_arg)
    ispath(out) && error("preserve existing replay producer output")
    mkpath(out)
    protocol = protocol_value(protocol_sha)
    protocol.classification == "test_only_continuation" || error("protocol is not test_only_continuation")
    expected_source = normpath(joinpath(ROOT, "docs", "implementation", "UP2-04-CLOSURE-REPAIR-PREC",
        "agent_r2_n1_20260922", "runtime_manufactured_staged_r1", "producer_process", "numerical"))
    normpath(source_root) == expected_source || error("foreign saved numerical root")

    saved_result = joinpath(source_root, "production", "numerical_result.json")
    sha256_file(saved_result) == expected_hash(protocol, :numerical_result) || error("saved numerical_result SHA mismatch")
    exit_file = joinpath(source_root, "production", "n1_q1_2", "solver.exitcode")
    strip(read(exit_file, String)) == "2" || error("saved solver exit code mismatch")

    context = try
        bind_context_from_saved_parent!(out, source_root)
    catch err
        new_json(joinpath(out, "producer_failure.json"), (schema="mms-replay-only-failure-v1",
            classification="context_rebuild_failed", phase="context_rebuild",
            error=sprint(showerror, err), solver_exit_code=2, numerical_status="fail", authority="no_publish"))
        println(stderr, "MMS_REPLAY_ONLY_FAIL classification=context_rebuild_failed error=",
            sprint(showerror, err)); flush(stderr)
        Base.exit(71)
    end
    hydration_phase = Ref("not_started")
    result = try
        result_from_saved_wire(read(saved_result, String), String(protocol.preserved_identity.result_hash), out,
            hydration_phase)
    catch err
        new_json(joinpath(out, "producer_failure.json"), (schema="mms-replay-only-failure-v1",
            classification="replay_hydration_unsupported", phase="typed_result_hydration",
            hydration_stage=hydration_phase[], error=sprint(showerror, err), solver_exit_code=2,
            numerical_status="fail", authority="no_publish"))
        println(stderr, "MMS_REPLAY_ONLY_FAIL classification=replay_hydration_unsupported error=",
            sprint(showerror, err)); flush(stderr)
        Base.exit(72)
    end
    c = only(result.cases)
    result.candidate_hash == context.candidate_hash && result.context_hash == context.context_hash || error("saved result context binding mismatch")
    string(result.candidate_hash) == String(protocol.preserved_identity.candidate_hash) || error("saved result candidate hash differs from protocol")
    string(result.context_hash) == String(protocol.preserved_identity.context_hash) || error("saved result context hash differs from protocol")
    string(c.state_hash) == String(protocol.preserved_identity.state_after_hash) || error("saved result state hash differs from protocol")
    string(canonical_hash(result.declaration)) == String(protocol.preserved_identity.declaration_sha256) ||
        error("saved result declaration hash differs from protocol")
    result.primary_case_id == "n1_q1_2" && c.status == :fail && c.stopping_reason == :stationary_nonzero_residual &&
        c.solver_exit_code == 2 && result.solver_exit_code == 2 && result.status == :fail ||
        error("saved numerical_fail/exit-2 semantics changed")
    result.physical_validation == :unsupported && result.execution.authority == :no_publish ||
        error("saved result exceeds test-only authority scope")

    phase_path = joinpath(out, "producer_full_validator.json")
    start = time()
    new_json(joinpath(out, "producer_validator_started.json"), (schema="mms-replay-only-runtime-hit-v1",
        classification="test_only_continuation", validator="validate_spatial_manufactured_result_v1",
        runtime_hit=true, candidate_hash=string(context.candidate_hash), context_hash=string(context.context_hash),
        result_hash=string(result.result_hash), solver_exit_code=2))
    validator_hash = S.validate_spatial_manufactured_result_v1(context, result)
    validator_hash == result.result_hash || error("public validator returned a different result identity")
    new_json(joinpath(out, "producer_validator_completed.json"), (schema="mms-replay-only-runtime-hit-v1",
        classification="test_only_continuation", validator="validate_spatial_manufactured_result_v1",
        runtime_hit=true, exit_code=0, validator_hash=string(validator_hash)))
    new_json(phase_path, (schema="mms-replay-only-validator-v1", classification="test_only_continuation",
        validator="validate_spatial_manufactured_result_v1", validator_hash=string(validator_hash),
        candidate_hash=string(context.candidate_hash), context_hash=string(context.context_hash),
        result_hash=string(result.result_hash), elapsed_seconds=time()-start, result_status=string(result.status),
        stopping_reason=string(c.stopping_reason), solver_exit_code=c.solver_exit_code,
        physical_validation=string(result.physical_validation), authority=string(result.execution.authority)))

    carrier = joinpath(out, "replay_carrier.bin")
    serialize(carrier, (schema="mms-replay-only-carrier-v1", context=context, result=result))
    carrier_sha = sha256_file(carrier)
    binding = (schema="mms-replay-only-carrier-binding-v1", protocol_sha256=protocol_sha,
        source_result_sha256=sha256_file(saved_result), carrier_path=realpath(carrier),
        carrier_sha256=carrier_sha, carrier_bytes=filesize(carrier), candidate_hash=string(context.candidate_hash),
        context_hash=string(context.context_hash), result_hash=string(result.result_hash), solver_exit_code=2,
        numerical_status="fail", stopping_reason="stationary_nonzero_residual", authority="no_publish",
        scope="test_only_continuation_transport_no_solver")
    binding_path = joinpath(out, "replay_carrier_binding.json")
    new_json(binding_path, binding)
    new_json(joinpath(out, "producer_complete.json"), (schema="mms-replay-only-producer-complete-v1",
        classification="test_only_continuation", software_stage="passed", full_validator_replays=1,
        nonlinear_solves=0, positive_result_replays=1, carrier_sha256=carrier_sha,
        carrier_binding_sha256=sha256_file(binding_path), candidate_hash=string(context.candidate_hash),
        context_hash=string(context.context_hash), result_hash=string(result.result_hash),
        numerical_status="fail", solver_exit_code=2, stopping_reason="stationary_nonzero_residual",
        physical_validation="unsupported", authority="no_publish", formal_candidate_credit=false))
    println("MMS_REPLAY_ONLY_COMPLETE stage=producer software=passed numerical=fail solver_exit=2"); flush(stdout)
end

function consumer(args)
    length(args) == 6 || error("expected consumer OUT PRODUCER_OUTPUT PROTOCOL_SHA CARRIER_SHA BINDING_SHA")
    _, out_arg, producer_arg, protocol_sha, expected_carrier_sha, expected_binding_sha = args
    out = abspath(out_arg); producer_root = abspath(producer_arg)
    ispath(out) && error("preserve existing replay consumer output")
    mkpath(out)
    protocol = protocol_value(protocol_sha)
    protocol.classification == "test_only_continuation" || error("protocol is not test_only_continuation")
    carrier = joinpath(producer_root, "replay_carrier.bin")
    binding_path = joinpath(producer_root, "replay_carrier_binding.json")
    sha256_file(carrier) == expected_carrier_sha || error("replay carrier differs from independent producer seal")
    sha256_file(binding_path) == expected_binding_sha || error("replay carrier binding differs from independent producer seal")
    binding = JSON3.read(read(binding_path, String))
    binding.protocol_sha256 == protocol_sha && binding.carrier_sha256 == expected_carrier_sha &&
        binding.scope == "test_only_continuation_transport_no_solver" || error("foreign replay carrier binding")
    payload = deserialize(carrier)
    payload.schema == "mms-replay-only-carrier-v1" || error("foreign replay carrier schema")
    context = payload.context; result = payload.result; c = only(result.cases)
    S.validate_forward_chain_context(context)
    canonical_hash(result) == result.result_hash || error("replay-carrier result hash mismatch")
    result.solver_exit_code == 2 && result.status == :fail && c.stopping_reason == :stationary_nonzero_residual ||
        error("consumer would alter solver failure semantics")
    start = time()
    new_json(joinpath(out, "consumer_suite_started.json"), (schema="mms-replay-only-runtime-hit-v1",
        classification="test_only_continuation", suite="ManufacturedCandidateV1Tests.result_tests",
        runtime_hit=true, candidate_hash=string(context.candidate_hash), context_hash=string(context.context_hash),
        result_hash=string(result.result_hash), solver_exit_code=2))
    M.result_tests(context, result, out)
    new_json(joinpath(out, "consumer_suite_completed.json"), (schema="mms-replay-only-runtime-hit-v1",
        classification="test_only_continuation", suite="ManufacturedCandidateV1Tests.result_tests",
        runtime_hit=true, exit_code=0))
    new_json(joinpath(out, "consumer_complete.json"), (schema="mms-replay-only-consumer-complete-v1",
        classification="test_only_continuation", software_stage="passed", original_consumer_suite="passed",
        full_validator_replays=1, negative_scope_cases="all original result/public scope cases",
        nonlinear_solves=0, positive_result_replays=1, candidate_hash=string(context.candidate_hash),
        context_hash=string(context.context_hash), result_hash=string(result.result_hash),
        numerical_status="fail", solver_exit_code=2, stopping_reason="stationary_nonzero_residual",
        elapsed_seconds=time()-start, physical_validation="unsupported", authority="no_publish",
        formal_candidate_credit=false))
    println("MMS_REPLAY_ONLY_COMPLETE stage=consumer software=passed numerical=fail solver_exit=2"); flush(stdout)
end

function main(args)
    length(args) == 6 || error("expected MODE OUTPUT SOURCE_OR_PRODUCER PROTOCOL_SHA EXPECTED_CARRIER_SHA EXPECTED_BINDING_SHA")
    mode = args[1]
    println("MMS_REPLAY_ONLY mode=", mode, " julia=", VERSION, " pid=", getpid()); flush(stdout)
    VERSION == v"1.10.5" || error("replay continuation is pinned to Julia 1.10.5")
    mode == "producer" ? producer(args) : mode == "consumer" ? consumer(args) : error("unknown replay-only mode")
end

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
    main(ARGS)
end
