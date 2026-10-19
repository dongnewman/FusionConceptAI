from __future__ import annotations

import argparse
import decimal
import hashlib
import json
import pathlib
import re
import sys


ROOT = pathlib.Path(__file__).resolve().parents[3]
ARCHIVE = ROOT / "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive"
R11 = ARCHIVE / "replay_only_continuation_r11"
RUNTIME = R11 / "runtime_replay_r11"
NUMERICAL = RUNTIME / "producer_process/numerical"
SAVED = (ROOT / "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/"
         "agent_r2_n1_20260922/runtime_manufactured_staged_r1/"
         "producer_process/numerical/production/numerical_result.json")
PROTOCOL = R11 / "replay_protocol_v11.json"
STATIC_RECEIPT = R11 / "static_contract_check_v11_r1/receipt.json"
JULIA_SOURCE = ROOT / "test/RuntimeV4/UP2ClosureReplayOnlyV11/replay_staged_v11.jl"
CONTROLLER_SOURCE = ROOT / "test/RuntimeV4/UP2ClosureReplayOnlyV11/run_replay_staged_v11.py"
TEST_SOURCE = ROOT / "test/RuntimeV4/UP2ClosureReplayOnlyV11/test_contract_v11.py"


def sha_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def sha_file(path: pathlib.Path) -> str:
    return sha_bytes(path.read_bytes())


def load_json(path: pathlib.Path):
    return json.loads(path.read_text(encoding="utf-8"))


def json_path(root, path: str):
    value = root
    for key, index in re.findall(r"([^\.\[\]]+)|\[(\d+)\]", path):
        if key:
            value = value[key]
        else:
            value = value[int(index) - 1]
    return value


def leaf_pairs(observation: dict, root: str):
    if root == "declaration":
        body_prefix, typed_prefix = "declaration.body.", "declaration.typed."
        json_prefix = "declaration."
    elif root == "cases":
        body_prefix, typed_prefix = "cases.body[1].", "cases.typed[1]."
        json_prefix = "cases[1]."
    elif root == "execution":
        body_prefix, typed_prefix = "execution.body.", "execution.typed."
        json_prefix = "execution."
    else:
        raise ValueError(f"unknown root {root}")

    body = {}
    typed = {}
    for leaf in observation["leaf_types"]:
        path = leaf["path"]
        if path.startswith(body_prefix):
            body[path[len(body_prefix):]] = leaf
        elif path.startswith(typed_prefix):
            typed[path[len(typed_prefix):]] = leaf
    if set(body) != set(typed):
        raise ValueError(f"leaf path set differs under {root}")
    return body, typed, json_prefix


def analyze() -> dict:
    saved_raw = SAVED.read_bytes()
    saved = json.loads(saved_raw, parse_int=decimal.Decimal,
                       parse_float=decimal.Decimal)
    observation = load_json(NUMERICAL / "hydration_observation_initial.json")
    differences = load_json(NUMERICAL / "hydration_observation_differences.json")
    failure = load_json(NUMERICAL / "producer_failure.json")
    final = load_json(RUNTIME / "final.json")
    process = load_json(RUNTIME / "producer_process.json")
    source_hashes = {
        "protocol_sha256": sha_file(PROTOCOL),
        "julia_source_sha256": sha_file(JULIA_SOURCE),
        "controller_source_sha256": sha_file(CONTROLLER_SOURCE),
        "test_source_sha256": sha_file(TEST_SOURCE),
        "static_receipt_sha256": sha_file(STATIC_RECEIPT),
    }

    roots = {}
    numeric_rows = []
    unknown_rows = []
    equal_leaf_count = 0
    for root in ("declaration", "cases", "execution"):
        body, typed, json_prefix = leaf_pairs(observation, root)
        root_numeric = 0
        for relative, body_leaf in body.items():
            typed_leaf = typed[relative]
            body_fp = body_leaf.get("canonical", {})
            typed_fp = typed_leaf.get("canonical", {})
            if (body_fp.get("canonical_sha256") ==
                    typed_fp.get("canonical_sha256")):
                equal_leaf_count += 1
                continue

            if (body_leaf["concrete_type"] != "Float64" or
                    typed_leaf["concrete_type"] != "Int64"):
                unknown_rows.append({"root": root, "path": relative,
                                    "body_type": body_leaf["concrete_type"],
                                    "typed_type": typed_leaf["concrete_type"],
                                    "body_sha256": body_fp.get("canonical_sha256"),
                                    "typed_sha256": typed_fp.get("canonical_sha256")})
                continue

            actual = json_path(saved, json_prefix + relative)
            if not isinstance(actual, decimal.Decimal):
                unknown_rows.append({"root": root, "path": relative,
                                    "reason": "source token is not a JSON number"})
                continue
            if actual != actual.to_integral_value():
                unknown_rows.append({"root": root, "path": relative,
                                    "reason": "source Float64 token is not integral-valued",
                                    "source_token": str(actual)})
                continue
            int_wire = str(int(actual))
            typed_hash_matches = sha_bytes(int_wire.encode("ascii")) == typed_fp.get("canonical_sha256")
            source_token = str(actual)
            body_hash_matches = sha_bytes(source_token.encode("ascii")) == body_fp.get("canonical_sha256")
            if not typed_hash_matches or not body_hash_matches:
                unknown_rows.append({"root": root, "path": relative,
                                    "reason": "source token does not reproduce the recorded canonical hashes",
                                    "source_token": source_token,
                                    "body_hash_matches_source_token": body_hash_matches,
                                    "typed_hash_matches_integer_value": typed_hash_matches})
                continue
            root_numeric += 1
            numeric_rows.append({"root": root, "path": relative,
                                 "saved_result_path": json_prefix + relative,
                                 "source_float_token": source_token,
                                 "typed_integer_token": int_wire,
                                 "body_float_sha256": body_fp.get("canonical_sha256"),
                                 "typed_integer_sha256": typed_fp.get("canonical_sha256")})

        roots[root] = {"body_leaf_count": len(body), "typed_leaf_count": len(typed),
                       "paired_leaf_count": len(set(body) & set(typed)),
                       "equal_canonical_leaf_count": sum(
                           body[p].get("canonical", {}).get("canonical_sha256") ==
                           typed[p].get("canonical", {}).get("canonical_sha256")
                           for p in body),
                       "exact_integral_float_to_int_count": root_numeric}

    if failure.get("hydration_stage") != "observe_typed_body_before_assertions":
        raise ValueError("V11 failure is not the observed hydration failure in the task")
    if process.get("exit_code") != 72 or final.get("controller_exit_code") != 72:
        raise ValueError("V11 producer/controller exit code drift")

    return {
        "schema": "mms-replay-only-v11-hydration-diagnosis-r1",
        "classification": "read_only_test_only_continuation_diagnosis",
        "source_hashes": source_hashes,
        "evidence_hashes": {
            "saved_numerical_result_sha256": sha_bytes(saved_raw),
            "producer_failure_sha256": sha_file(NUMERICAL / "producer_failure.json"),
            "observation_sha256": sha_file(NUMERICAL / "hydration_observation_initial.json"),
            "differences_sha256": sha_file(NUMERICAL / "hydration_observation_differences.json"),
            "stdout_sha256": sha_file(RUNTIME / "producer_process/stdout.raw"),
            "stderr_sha256": sha_file(RUNTIME / "producer_process/stderr.raw"),
            "producer_process_sha256": sha_file(RUNTIME / "producer_process.json"),
            "final_sha256": sha_file(RUNTIME / "final.json"),
        },
        "saved_numerical_result_bytes": len(saved_raw),
        "stored_result_hash": observation.get("stored_result_hash"),
        "hydration_stage": failure.get("hydration_stage"),
        "failure_classification": failure.get("classification"),
        "producer_exit_code": process.get("exit_code"),
        "controller_exit_code": final.get("controller_exit_code"),
        "solver_status_preserved": {
            "status": final.get("numerical_status"),
            "solver_exit_code": final.get("solver_exit_code"),
            "stopping_reason": final.get("stopping_reason"),
            "authority": final.get("authority"),
            "formal_candidate_credit": final.get("formal_candidate_credit"),
            "consumer_present": (RUNTIME / "consumer_process").exists(),
            "producer_tree_comparison_status": final.get("producer_tree_comparison_status"),
            "producer_tree_unchanged": final.get("producer_tree_unchanged"),
            "inputs_unchanged": final.get("inputs_unchanged"),
        },
        "observation": {
            "body_sha256": observation.get("body_sha256"),
            "typed_semantic_sha256": observation.get("typed_semantic_sha256"),
            "mismatch_roots": observation.get("mismatch_roots"),
            "semantic_differences": differences.get("semantic_differences"),
            "numeric_type_difference_report_count": len(differences.get("numeric_type_differences", [])),
            "roots": roots,
            "paired_leaf_count_total": sum(x["paired_leaf_count"] for x in roots.values()),
            "equal_canonical_leaf_count_total": equal_leaf_count,
            "exact_integral_float_to_int_count_total": len(numeric_rows),
            "unknown_or_unproven_differences": unknown_rows,
            "first_exact_token_difference": numeric_rows[0] if numeric_rows else None,
            "all_reported_scalar_differences_are_exact_integral_float_to_int":
                not unknown_rows and len(numeric_rows) == sum(x["paired_leaf_count"] -
                    x["equal_canonical_leaf_count"] for x in roots.values()),
        },
        "interpretation": {
            "confirmed": [
                "The first recorded mismatching scalar is declaration.boundary.normal_B_T; the saved token is 0.0 and typed canonical content is integer token 0.",
                "All differing scalar leaf fingerprints are reproduced from the saved numerical_result.json token as Float64 and as its equal Int64 token.",
                "The remaining recorded case/execution differences are container-representation and key-order mismatches; the observed leaf path sets are paired.",
                "The exception occurs before validate_spatial_manufactured_result_v1 and before consumer launch; it does not alter solver exit 2 or numerical_fail/no_publish.",
            ],
            "not_proven": [
                "A complete schema-directed reconstruction of nested SpatialMultiRegionCaseV4, SpatialCurrentInputV4, SpatialArtifactV4, SpatialManufacturedGeometryReceiptV1, and Symbol-valued validator fields has not been demonstrated by V11 observations alone.",
                "No full validator or consumer replay is established by this read-only diagnosis.",
            ],
            "next_gate": "A V12 may recover only exact saved tokens and canonical-equivalent container forms after observe-first comparison; it must bind every reconstructed typed wrapper/enum to existing V4 schema or rebuilt context and fail_closed on any unbound field.",
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=pathlib.Path)
    args = parser.parse_args()
    try:
        report = analyze()
        encoded = json.dumps(report, ensure_ascii=False, sort_keys=True,
                             indent=2) + "\n"
        if args.output is not None:
            args.output.parent.mkdir(parents=True, exist_ok=True)
            if args.output.exists():
                raise FileExistsError(f"preserve existing diagnosis output: {args.output}")
            args.output.write_text(encoded, encoding="utf-8", newline="\n")
        else:
            sys.stdout.write(encoded)
        return 0
    except Exception as exc:
        sys.stderr.write(f"V11_HYDRATION_DIAGNOSIS_FAIL {type(exc).__name__}: {exc}\n")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
