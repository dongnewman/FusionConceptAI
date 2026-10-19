from __future__ import annotations

from collections.abc import Mapping
from pathlib import Path
import hashlib
import json
import re
import textwrap


MONOLITH_SHA256 = (
    "8c52c726c4ce82d8d427f59469dbcb30122d0e0b37063495b97e0be606f3e516"
)
SCENARIOS = (
    "native_baseline_coupling",
    "edited_state_typed_reload",
    "intrinsic_absence_precedence",
    "foreign_authority_joins",
    "recomputed_source_layer",
    "feedback_child_serialization",
)
PIN_PATHS = (
    ("source", "src/GenomeV5/Integration/VNextT2ConcreteSourceWitnessV3.jl"),
    ("fixture", "test/GenomeV5/Integration/VNextT2ConcreteSourceWitnessV3/fixture_helpers.jl"),
    ("monolith", "test/GenomeV5/Integration/VNextT2ConcreteSourceWitnessV3/vnext_t2_concrete_source_witness_v3_tests.jl"),
    ("helper", "test/GenomeV5/Integration/VNextT2ConcreteSourceWitnessV3/shard_test_helpers.jl"),
    ("driver", "test/GenomeV5/Integration/VNextT2ConcreteSourceWitnessV3/vnext_t2_concrete_source_witness_v3_shard_tests.jl"),
    ("ledger", "test/GenomeV5/Integration/VNextT2ConcreteSourceWitnessV3/shard_coverage_ledger.json"),
)
RESULT_PATTERN = re.compile(
    r"^V3_SHARD_RESULT scenario=(?P<scenario>[a-z0-9_]+) "
    r"syntactic_sites=(?P<syntactic>[0-9]+) "
    r"runtime_assertions=(?P<runtime>[0-9]+) "
    r"site_sequence_sha256=(?P<sequence>[0-9a-f]{64}) "
    r"input_pin_sha256=(?P<input_pin>[0-9a-f]{64}) "
    r"site_ids=(?P<site_ids>A[0-9]{3}(?:,A[0-9]{3})*)$",
    flags=re.MULTILINE,
)


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def load_ledger(path: Path) -> dict[str, object]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if value.get("schema") != "vnext_t2_source_witness_v3_shard_coverage_v1":
        raise AssertionError("shard-ledger-schema")
    return value


def _normalized_assertion(lines: list[str]) -> str:
    return textwrap.dedent("\n".join(lines)).strip() + "\n"


def extract_monolith_sites(text: str) -> list[dict[str, object]]:
    lines = text.splitlines()
    sites: list[dict[str, object]] = []
    for start, line in enumerate(lines):
        match = re.match(r"^(\s*)@test(?:_throws)?\b", line)
        if match is None:
            continue
        indent = len(match.group(1))
        end = start
        while end + 1 < len(lines):
            following = lines[end + 1]
            if not following.strip():
                break
            following_indent = len(following) - len(following.lstrip())
            if following_indent <= indent:
                break
            end += 1
        normalized = _normalized_assertion(lines[start:end + 1])
        sites.append({
            "id": f"A{len(sites) + 1:03d}",
            "start_line": start + 1,
            "end_line": end + 1,
            "sha256": sha256_bytes(normalized.encode("utf-8")),
        })
    return sites


def extract_driver_sites(text: str) -> list[dict[str, object]]:
    lines = text.splitlines()
    scenario_starts: list[tuple[int, str]] = []
    for index, line in enumerate(lines):
        match = re.match(r"^function v3_scenario_([a-z0-9_]+)\(\)$", line)
        if match:
            scenario_starts.append((index, match.group(1)))
    if tuple(name for _, name in scenario_starts) != SCENARIOS:
        raise AssertionError("driver-scenario-order")

    def scenario_at(index: int) -> str:
        candidates = [name for start, name in scenario_starts if start < index]
        if not candidates:
            raise AssertionError(f"assertion-outside-scenario:{index + 1}")
        return candidates[-1]

    sites: list[dict[str, object]] = []
    index = 0
    while index < len(lines):
        match = re.match(r"^(\s*)# V3_ASSERTION_BEGIN (A[0-9]{3})$", lines[index])
        if match is None:
            index += 1
            continue
        indent, site_id = match.groups()
        marker = f"{indent}v3_site!(:{site_id})"
        if index + 1 >= len(lines) or lines[index + 1] != marker:
            raise AssertionError(f"site-runtime-marker:{site_id}")
        end_marker = f"{indent}# V3_ASSERTION_END {site_id}"
        try:
            end = lines.index(end_marker, index + 2)
        except ValueError as exc:
            raise AssertionError(f"site-end-marker:{site_id}") from exc
        assertion_lines = lines[index + 2:end]
        if len(re.findall(r"(?m)^\s*@test(?:_throws)?\b", "\n".join(assertion_lines))) != 1:
            raise AssertionError(f"site-test-arity:{site_id}")
        normalized = _normalized_assertion(assertion_lines)
        sites.append({
            "id": site_id,
            "start_line": index + 3,
            "end_line": end,
            "sha256": sha256_bytes(normalized.encode("utf-8")),
            "scenario": scenario_at(index),
        })
        index = end + 1
    return sites


def validate_static_coverage(
    root: Path,
    test_dir: Path,
    ledger: Mapping[str, object],
) -> dict[str, object]:
    monolith_path = root / str(ledger["monolith_path"])
    monolith_text = monolith_path.read_text(encoding="utf-8")
    if sha256_file(monolith_path) != MONOLITH_SHA256:
        raise AssertionError("monolith-sha256")
    if ledger["monolith_sha256"] != MONOLITH_SHA256:
        raise AssertionError("ledger-monolith-sha256")

    original = extract_monolith_sites(monolith_text)
    recorded = list(ledger["sites"])
    if len(original) != 103 or len(recorded) != 103:
        raise AssertionError("syntactic-site-count")
    for observed, frozen in zip(original, recorded, strict=True):
        expected = {
            "id": frozen["id"],
            "start_line": frozen["original_start_line"],
            "end_line": frozen["original_end_line"],
            "sha256": frozen["assertion_sha256"],
        }
        if observed != expected:
            raise AssertionError(f"monolith-site-drift:{frozen['id']}")
    expected_site_ids = [f"A{index:03d}" for index in range(1, 104)]
    if [str(item["id"]) for item in recorded] != expected_site_ids:
        raise AssertionError("ledger-site-order")

    scenario_root = ledger["contexts"]["scenario_root"]
    scenario_header_line = int(scenario_root["original_header_line"])
    scenario_header = monolith_text.splitlines()[scenario_header_line - 1]
    if sha256_bytes(scenario_header.encode("utf-8")) != str(
            scenario_root["original_header_sha256"]):
        raise AssertionError("scenario-root-header-drift")
    if not scenario_header.startswith("@testset "):
        raise AssertionError("scenario-root-kind-drift")
    if int(scenario_root["runtime_iterations"]) != 1:
        raise AssertionError("scenario-root-runtime-iterations")

    driver_path = test_dir / "vnext_t2_concrete_source_witness_v3_shard_tests.jl"
    driver_text = driver_path.read_text(encoding="utf-8")
    driver_sites = extract_driver_sites(driver_text)
    if len(driver_sites) != 103:
        raise AssertionError("driver-site-count")
    frozen_by_id = {str(item["id"]): item for item in recorded}
    if len(frozen_by_id) != 103:
        raise AssertionError("ledger-site-ids-duplicate")
    for observed in driver_sites:
        frozen = frozen_by_id.get(str(observed["id"]))
        if frozen is None:
            raise AssertionError(f"driver-site-foreign:{observed['id']}")
        if observed["sha256"] != frozen["assertion_sha256"]:
            raise AssertionError(f"driver-site-body-drift:{observed['id']}")
        if observed["scenario"] != frozen["scenario"]:
            raise AssertionError(f"driver-site-scenario-drift:{observed['id']}")
    if len({str(item["id"]) for item in driver_sites}) != 103:
        raise AssertionError("driver-site-ids-duplicate")

    unmarked_test_count = len(re.findall(
        r"(?m)^\s*@test(?:_throws)?\b", driver_text
    ))
    if unmarked_test_count != 103:
        raise AssertionError("driver-unmarked-test-site")

    scenarios = ledger["scenarios"]
    for scenario in SCENARIOS:
        observed_ids = [
            str(item["id"]) for item in driver_sites
            if item["scenario"] == scenario
        ]
        if observed_ids != list(scenarios[scenario]["site_ids"]):
            raise AssertionError(f"scenario-site-order:{scenario}")

    loop = ledger["contexts"]["layer_loop_g1_g2_g3"]
    loop_header = str(loop["header"])
    original_loop_line = int(loop["original_start_line"])
    if monolith_text.splitlines()[original_loop_line - 1].strip() != loop_header:
        raise AssertionError("monolith-layer-loop-header-drift")
    if sha256_bytes(loop_header.encode("utf-8")) != str(loop["header_sha256"]):
        raise AssertionError("layer-loop-header-sha256")
    original_loop_end = int(loop["original_end_line"])
    if monolith_text.splitlines()[original_loop_end - 1].strip() != "end":
        raise AssertionError("monolith-layer-loop-end-drift")
    if driver_text.count(loop_header) != 1:
        raise AssertionError("layer-loop-header-count")
    loop_start = driver_text.splitlines().index("    " + loop_header)
    loop_end = driver_text.splitlines().index("    end", loop_start + 1)
    loop_ids = [
        str(item["id"]) for item in driver_sites
        if loop_start < int(item["start_line"]) - 1 < loop_end
    ]
    if loop_ids != list(loop["site_ids"]) or int(loop["runtime_iterations"]) != 3:
        raise AssertionError("layer-loop-context-drift")

    loop_id_set = set(loop_ids)
    derived_sequences: dict[str, list[str]] = {}
    for scenario in SCENARIOS:
        scenario_sites = [
            item for item in driver_sites if item["scenario"] == scenario
        ]
        sequence: list[str] = []
        index = 0
        while index < len(scenario_sites):
            item = scenario_sites[index]
            site_id = str(item["id"])
            frozen = frozen_by_id[site_id]
            in_layer_loop = site_id in loop_id_set
            expected_context = (
                "layer_loop_g1_g2_g3" if in_layer_loop else "scenario_root"
            )
            expected_occurrences = 3 if in_layer_loop else 1
            if str(frozen["context"]) != expected_context:
                raise AssertionError(f"site-context-drift:{site_id}")
            if int(frozen["runtime_occurrences"]) != expected_occurrences:
                raise AssertionError(f"site-runtime-occurrences:{site_id}")
            if in_layer_loop:
                if site_id != loop_ids[0]:
                    raise AssertionError(f"layer-loop-noncontiguous:{site_id}")
                observed_block = [
                    str(value["id"])
                    for value in scenario_sites[index:index + len(loop_ids)]
                ]
                if observed_block != loop_ids:
                    raise AssertionError("layer-loop-site-order")
                for loop_site_id in observed_block:
                    loop_frozen = frozen_by_id[loop_site_id]
                    if str(loop_frozen["context"]) != "layer_loop_g1_g2_g3":
                        raise AssertionError(f"site-context-drift:{loop_site_id}")
                    if int(loop_frozen["runtime_occurrences"]) != 3:
                        raise AssertionError(
                            f"site-runtime-occurrences:{loop_site_id}"
                        )
                sequence.extend(loop_ids * int(loop["runtime_iterations"]))
                index += len(loop_ids)
                continue
            sequence.append(site_id)
            index += 1
        derived_sequences[scenario] = sequence
        expected = scenarios[scenario]
        if sequence != list(expected["expected_runtime_sequence"]):
            raise AssertionError(f"scenario-runtime-sequence:{scenario}")
        if len(sequence) != int(expected["expected_runtime_assertions"]):
            raise AssertionError(f"scenario-runtime-count:{scenario}")
        sequence_hash = sha256_bytes(",".join(sequence).encode("utf-8"))
        if sequence_hash != str(expected["expected_runtime_sequence_sha256"]):
            raise AssertionError(f"scenario-runtime-sequence-sha256:{scenario}")

    testset_header = (
        '@testset "VNext T2 concrete native source witness V3 shard '
        '$(scenario)" begin'
    )
    for token, count in (
        (testset_header, 1),
        ("runner()", 1),
        ("v3_finish_shard!(scenario, driver_path, ledger_path)", 1),
    ):
        if driver_text.count(token) != count:
            raise AssertionError(f"driver-scenario-root:{token}:{count}")

    helper_path = test_dir / "shard_test_helpers.jl"
    helper_text = helper_path.read_text(encoding="utf-8")
    monolith_prefix = "\n".join(monolith_text.splitlines()[:131]) + "\n"
    if not helper_text.startswith(monolith_prefix):
        raise AssertionError("shard-helper-prefix-drift")
    for scenario in SCENARIOS:
        expected = scenarios[scenario]
        for token in (
            str(expected["expected_runtime_sequence_sha256"]),
            f":{scenario} => {expected['syntactic_site_count']},",
            f":{scenario} => {expected['expected_runtime_assertions']},",
        ):
            if token not in helper_text:
                raise AssertionError(f"helper-coverage-token:{scenario}:{token}")

    all_ids = [
        str(site_id)
        for scenario in SCENARIOS
        for site_id in scenarios[scenario]["site_ids"]
    ]
    if len(all_ids) != 103 or len(set(all_ids)) != 103:
        raise AssertionError("aggregate-syntactic-partition")
    expected_runtime = sum(len(derived_sequences[scenario]) for scenario in SCENARIOS)
    if int(ledger["runtime_assertion_count"]) != expected_runtime:
        raise AssertionError("aggregate-runtime-count")
    return {
        "syntactic_site_count": len(all_ids),
        "runtime_assertion_count": expected_runtime,
        "scenario_count": len(SCENARIOS),
        "loop_site_count": len(loop_ids),
        "loop_iterations": int(loop["runtime_iterations"]),
    }


def expected_input_pin_hash(
    dependency_snapshot: Mapping[str, Mapping[str, object]],
) -> str:
    rows = []
    for label, relative in PIN_PATHS:
        try:
            digest = str(dependency_snapshot[relative]["sha256"])
        except KeyError as exc:
            raise AssertionError(f"missing-input-pin:{relative}") from exc
        rows.append(f"{label}={digest}")
    return sha256_bytes("\n".join(rows).encode("utf-8"))


def parse_shard_result(stdout_text: str) -> dict[str, object]:
    matches = list(RESULT_PATTERN.finditer(stdout_text))
    if len(matches) != 1:
        raise AssertionError(f"shard-result-count:{len(matches)}")
    groups = matches[0].groupdict()
    return {
        "scenario": groups["scenario"],
        "syntactic_sites": int(groups["syntactic"]),
        "runtime_assertions": int(groups["runtime"]),
        "site_sequence_sha256": groups["sequence"],
        "input_pin_sha256": groups["input_pin"],
        "site_ids": groups["site_ids"].split(","),
    }


def validate_shard_result(
    observed: Mapping[str, object],
    scenario: str,
    ledger: Mapping[str, object],
    input_pin_hash: str,
) -> None:
    expected = ledger["scenarios"][scenario]
    checks = {
        "scenario": scenario,
        "syntactic_sites": int(expected["syntactic_site_count"]),
        "runtime_assertions": int(expected["expected_runtime_assertions"]),
        "site_sequence_sha256": str(expected["expected_runtime_sequence_sha256"]),
        "input_pin_sha256": input_pin_hash,
        "site_ids": list(expected["site_ids"]),
    }
    if dict(observed) != checks:
        raise AssertionError(
            "shard-result-mismatch:"
            + json.dumps({"scenario": scenario, "expected": checks,
                          "observed": dict(observed)}, sort_keys=True)
        )


def validate_aggregate_results(
    receipts: Mapping[str, Mapping[str, object]],
    ledger: Mapping[str, object],
) -> dict[str, object]:
    if tuple(receipts) != SCENARIOS:
        raise AssertionError("aggregate-scenario-order")
    site_ids: list[str] = []
    runtime_assertions = 0
    for scenario in SCENARIOS:
        site_ids.extend(str(item) for item in receipts[scenario]["site_ids"])
        runtime_assertions += int(receipts[scenario]["runtime_assertions"])
    if len(site_ids) != 103 or len(set(site_ids)) != 103:
        raise AssertionError("aggregate-site-coverage")
    expected_ids = [str(item["id"]) for item in ledger["sites"]]
    if sorted(site_ids) != sorted(expected_ids):
        raise AssertionError("aggregate-site-identity")
    if runtime_assertions != int(ledger["runtime_assertion_count"]):
        raise AssertionError("aggregate-runtime-coverage")
    return {
        "schema": "vnext_t2_source_witness_v3_shard_runtime_coverage_v1",
        "status": "all_six_shards_passed",
        "scenario_order": list(SCENARIOS),
        "syntactic_site_count": len(site_ids),
        "runtime_assertion_count": runtime_assertions,
        "receipts": dict(receipts),
    }
