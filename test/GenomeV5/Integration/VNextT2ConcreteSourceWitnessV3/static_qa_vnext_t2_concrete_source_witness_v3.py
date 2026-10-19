from __future__ import annotations

import hashlib
import json
import pathlib
import re
import sys


ROOT = pathlib.Path(__file__).resolve().parents[4]
STATIC_QA = pathlib.Path(__file__).resolve()
TEST_DIR = STATIC_QA.parent
if str(TEST_DIR) not in sys.path:
    sys.path.insert(0, str(TEST_DIR))

import shard_coverage_tools as shard_coverage  # noqa: E402


SOURCE = ROOT / "src/GenomeV5/Integration/VNextT2ConcreteSourceWitnessV3.jl"
TEST = pathlib.Path(__file__).with_name("vnext_t2_concrete_source_witness_v3_tests.jl")
FIXTURE = pathlib.Path(__file__).with_name("fixture_helpers.jl")
SHARD_HELPER = pathlib.Path(__file__).with_name("shard_test_helpers.jl")
SHARD_DRIVER = pathlib.Path(__file__).with_name(
    "vnext_t2_concrete_source_witness_v3_shard_tests.jl"
)
SHARD_LEDGER = pathlib.Path(__file__).with_name("shard_coverage_ledger.json")
SHARD_TOOLS = pathlib.Path(__file__).with_name("shard_coverage_tools.py")
REPLAY_CHILD = pathlib.Path(__file__).with_name("replay_child.jl")
REPLAY_DRIVER = pathlib.Path(__file__).with_name("fresh_process_replay_driver.jl")
PARSE_GATE = pathlib.Path(__file__).with_name("parse_gate.jl")
RUNNER = pathlib.Path(__file__).with_name("run_recorded_v3.py")
SOURCE_SHA256 = "f381f4ed8e48dba499ddbe877d638838240cf4fcf99d4718ba177c2b5d7b2bd9"
MONOLITH_SHA256 = shard_coverage.MONOLITH_SHA256


def require(text: str, pattern: str, label: str) -> None:
    if re.search(pattern, text, flags=re.MULTILINE | re.DOTALL) is None:
        raise AssertionError(f"missing:{label}")


def main() -> int:
    source = SOURCE.read_text(encoding="utf-8")
    test = TEST.read_text(encoding="utf-8")
    fixture = FIXTURE.read_text(encoding="utf-8")
    shard_helper = SHARD_HELPER.read_text(encoding="utf-8")
    shard_driver = SHARD_DRIVER.read_text(encoding="utf-8")
    shard_tools = SHARD_TOOLS.read_text(encoding="utf-8")
    replay_child = REPLAY_CHILD.read_text(encoding="utf-8")
    replay_driver = REPLAY_DRIVER.read_text(encoding="utf-8")
    parse_gate = PARSE_GATE.read_text(encoding="utf-8")
    runner = RUNNER.read_text(encoding="utf-8")
    compile(runner, str(RUNNER), "exec")
    compile(shard_tools, str(SHARD_TOOLS), "exec")
    if hashlib.sha256(SOURCE.read_bytes()).hexdigest() != SOURCE_SHA256:
        raise AssertionError("source-frozen-sha256")
    if hashlib.sha256(TEST.read_bytes()).hexdigest() != MONOLITH_SHA256:
        raise AssertionError("monolith-frozen-sha256")
    ledger = shard_coverage.load_ledger(SHARD_LEDGER)
    coverage = shard_coverage.validate_static_coverage(ROOT, TEST_DIR, ledger)

    for token in (
        "VNextT2ConcreteSourceWitnessV3",
        "prepare_vnext_t2_concrete_source_witness_v3",
        "validate_vnext_t2_concrete_source_witness_v3",
        "revalidate_vnext_t2_concrete_source_witness_v3",
        "g1_diffusion_declaration_v1",
        "g2mb_declaration_v1",
        "g3_sf_declaration_v1",
        "_g3rce_payload_valid",
        "_g3ce_validate_body",
        "_g3be2_validate_state",
        "VNextT2G3CurrentStateProjectionV3",
        "VNextT2ConcreteG3BridgeV3",
        "vnext_t2_concrete_g3_bridge_v3",
        "_vnext_t2_v3_known_input_errors",
        "_vnext_t2_v3_optional_input_errors",
        "_vnext_t2_v3_validate_realization_intrinsic",
        "_vnext_t2_v3_validate_control_payload_intrinsic",
        "_vnext_t2_v3_validate_control_state_intrinsic",
        "_vnext_t2_v3_validate_control_pair",
        "_vnext_t2_v3_recheck_output_body",
        "G3RealizationSourceStateV1(state.key",
        "realization_full_operation_replay_evidence_not_carried",
        "expected_commitment_hash_mismatch",
        "g3_bridge_projection_candidate_mismatch",
        "g3_bridge_binding_candidate_mismatch",
        "witness_independent_reconstruction_mismatch",
        "_VNEXT_T2_V3_TRACE_ENABLED",
        "VNEXT_T2_SOURCE_WITNESS_TRACE",
        '_vnext_t2_v3_trace("build.begin"',
        '_vnext_t2_v3_trace("build.witness_hash.begin")',
        '_vnext_t2_v3_trace("build.witness_hash.complete")',
        '_vnext_t2_v3_trace("build.complete")',
    ):
        if token not in source:
            raise AssertionError(f"source-token:{token}")

    require(source, r"formal_consumer_counts=x\.formal_consumer_counts", "formal counts carried")
    require(source, r"\(e0=0, gi1a=0, e1=0, e2=0, n10=0\)", "five zero consumers")
    require(source, r"package_hash::Nothing", "formal package typed absence")
    require(source, r"candidate_envelope::VNextT0LocalG2CandidateEnvelopeV1", "G2 envelope")
    require(source, r"control_payload::G3ControlSourcePayloadV1", "full control payload")
    require(source, r"_vnext_t2_v3_canonical_equal\(witness, prepared\.witness\)", "full rebuilt compare")

    forbidden = (
        "CandidateStatePackageV5",
        "up2_candidate_physical_binding_from_a(",
        "gi1_authority_context_from_a(",
        "n10_identity_projection_from_a(",
        "Tuple(Vector{UInt8}",
        "layer_fixture_child.jl",
    )
    for token in forbidden:
        if token in source or token in fixture:
            raise AssertionError(f"forbidden:{token}")

    for token in (
        "g2_variant=true",
        "forged-g2-envelope-source",
        "changed_link",
        "foreign_children",
        "source_axes=changed_axes",
        "formal_node_accepted=true",
        "Serialization.deserialize",
        "g3_source_law_realization_allocation_mismatch",
        "g3_source_law_realization_unit_mismatch",
        "edited_realization=true",
        "realization_full_operation_replay_evidence_not_carried",
        "tampered_transport",
        "t0_bundle_hash_mismatch",
        "v3_serialization_replace_ascii",
        "invalid_admission",
        "invalid_physical",
        "invalid_control",
        "forged-present-absence",
        "absent_with_invalid_state",
        "absent_with_crossed_control",
        "control_payload_ref_mismatch",
        "t0_recheck_output_hash",
        "recheck_projection_mutations",
        "expected_recheck_projection",
        "canonical_json(witness)",
        "vnext_t2_concrete_source_witness_hash_v3(witness)",
        "bridge_contradiction",
        "g3_bridge_binding_candidate_mismatch",
        "foreign_expected",
        "realization_candidate_mismatch",
        'v3_trace("focused.testset.begin")',
        'v3_trace("focused.testset.end")',
        'v3_trace("focused.baseline.complete")',
        'v3_trace("focused.serialization.complete")',
    ):
        if token not in test:
            raise AssertionError(f"test-token:{token}")

    for token in (
        "V3_SHARD_EXECUTED_SITES",
        "V3_SHARD_EXPECTED_SEQUENCE_SHA256",
        "V3_SHARD_EXPECTED_SYNTACTIC_SITES",
        "V3_SHARD_EXPECTED_RUNTIME_ASSERTIONS",
        "v3_site!",
        "v3_finish_shard!",
        "input_pin_sha256=",
    ):
        if token not in shard_helper:
            raise AssertionError(f"shard-helper-token:{token}")
    for scenario in shard_coverage.SCENARIOS:
        for token in (
            f"function v3_scenario_{scenario}()",
            f":{scenario}",
        ):
            if token not in shard_driver:
                raise AssertionError(f"shard-driver-token:{scenario}:{token}")
    for token in (
        'include(joinpath(@__DIR__, "shard_test_helpers.jl"))',
        'for layer in (:g1, :g2, :g3)',
        'runner()',
        'v3_finish_shard!(scenario, driver_path, ledger_path)',
        '@testset "VNext T2 concrete native source witness V3 shard $(scenario)"',
    ):
        if token not in shard_driver:
            raise AssertionError(f"shard-driver-token:{token}")

    if "_vnext_g3_state_info" in fixture:
        raise AssertionError("fixture-uses-initial-only-state-projection")
    for token in (
        "vnext_t2_g3_current_state_projection_v3",
        "vnext_t2_concrete_g3_bridge_v3",
        "g3_realization_replace_source_payload_v1",
        "realization_edit_operation",
        "realization_edit_receipt",
        "V3_TRACE_ENABLED",
        "VNEXT_T2_SOURCE_WITNESS_TRACE",
        'v3_trace("chain.prepare.begin")',
        'v3_trace("chain.prepare.complete")',
        "flush(stdout)",
    ):
        if token not in fixture:
            raise AssertionError(f"fixture-token:{token}")
    for token in ("witness = open(Serialization.deserialize", "chain = v3_chain()"):
        if token not in replay_child:
            raise AssertionError(f"replay-child-token:{token}")
    for forbidden_replay in ("payload.chain", "payload.witness"):
        if forbidden_replay in replay_child:
            raise AssertionError(f"replay-child-trusts-serialized-input:{forbidden_replay}")
    for token in ("v3_chain(g2_variant=true)", "baseline-witness.jls",
                  "foreign-witness.jls", "Serialization.serialize",
                  "ispath(baseline_path)", 'open(baseline_path, "w")'):
        if token not in replay_driver:
            raise AssertionError(f"replay-driver-token:{token}")
    for forbidden_driver in ("Base.julia_cmd", "run(command)", 'open(baseline_path, "x")'):
        if forbidden_driver in replay_driver:
            raise AssertionError(f"replay-driver-spawns-child:{forbidden_driver}")
    for token in (
        "Meta.parseall",
        ":error, :incomplete",
        "readlines(manifest_path)",
        "manifest_sha256_mismatch",
        "parse_manifest=",
        "parse_gate=pass",
        "main(ARGS)",
    ):
        if token not in parse_gate:
            raise AssertionError(f"parse-gate-token:{token}")
    for token in (
        "HARNESS_JULIA_FILES",
        "HARNESS_INCLUDE_CONTRACTS",
        "EXPECTED_RUNTIME_JULIA_FILES = 84",
        "fusion_package_source_paths",
        "assert_explicit_runtime_inventory",
        "runtime_julia_paths",
        "write_parse_manifest",
        "runtime_parse_manifest.tsv",
        "checkpoint_before_assert.json",
        "tree_rss",
        "process_tree_rss_limit_bytes",
        "dependency_receipts",
        "validate_static_coverage",
        "validate_recorded_shard",
        "validate_aggregate_results",
        "shard_runtime_coverage.json",
        "natural_test_summary",
        "fresh_baseline",
        "fresh_foreign",
        "DEFAULT_TIMEOUT_SECONDS = 300.0",
        "DEFAULT_PROCESS_TREE_RSS_BYTES = 2_147_483_648",
        'environment["VNEXT_T2_SOURCE_WITNESS_TRACE"] = "1"',
    ):
        if token not in runner:
            raise AssertionError(f"runner-token:{token}")
    if 'f"shard_{scenario}"' not in runner or "for scenario in SCENARIOS" not in runner:
        raise AssertionError("runner-shard-enumeration")
    main_body = runner.split("def main() -> int:", 1)[1]
    aggregate_position = main_body.index(
        "shard_coverage = validate_aggregate_results("
    )
    producer_position = main_body.index('"artifact_producer"')
    replay_position = main_body.index('"fresh_baseline"')
    if not aggregate_position < producer_position < replay_position:
        raise AssertionError("runner-gate-order")
    if '("focused_tests", [' in runner:
        raise AssertionError("runner-still-executes-monolith")
    if 'rglob("*.jl")' in runner:
        raise AssertionError("runner-freezes-unrelated-source-tree")

    result = {
        "status": "pass",
        "source_sha256": hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
        "test_sha256": hashlib.sha256(TEST.read_bytes()).hexdigest(),
        "fixture_sha256": hashlib.sha256(FIXTURE.read_bytes()).hexdigest(),
        "shard_helper_sha256": hashlib.sha256(SHARD_HELPER.read_bytes()).hexdigest(),
        "shard_driver_sha256": hashlib.sha256(SHARD_DRIVER.read_bytes()).hexdigest(),
        "shard_ledger_sha256": hashlib.sha256(SHARD_LEDGER.read_bytes()).hexdigest(),
        "shard_tools_sha256": hashlib.sha256(SHARD_TOOLS.read_bytes()).hexdigest(),
        "replay_child_sha256": hashlib.sha256(REPLAY_CHILD.read_bytes()).hexdigest(),
        "replay_driver_sha256": hashlib.sha256(REPLAY_DRIVER.read_bytes()).hexdigest(),
        "parse_gate_sha256": hashlib.sha256(PARSE_GATE.read_bytes()).hexdigest(),
        "runner_sha256": hashlib.sha256(RUNNER.read_bytes()).hexdigest(),
        "static_qa_sha256": hashlib.sha256(STATIC_QA.read_bytes()).hexdigest(),
        "source_lines": len(source.splitlines()),
        "test_lines": len(test.splitlines()),
        "fixture_lines": len(fixture.splitlines()),
        "shard_helper_lines": len(shard_helper.splitlines()),
        "shard_driver_lines": len(shard_driver.splitlines()),
        "shard_tools_lines": len(shard_tools.splitlines()),
        "replay_child_lines": len(replay_child.splitlines()),
        "replay_driver_lines": len(replay_driver.splitlines()),
        "parse_gate_lines": len(parse_gate.splitlines()),
        "runner_lines": len(runner.splitlines()),
        "shard_coverage": coverage,
        "shard_scenario_order": list(shard_coverage.SCENARIOS),
        "formal_consumer_count": 0,
        "julia_started": False,
    }
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"STATIC_QA_FAIL:{exc}", file=sys.stderr)
        raise
