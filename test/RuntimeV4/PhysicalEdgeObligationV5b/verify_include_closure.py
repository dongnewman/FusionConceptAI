"""Independent Python-only freeze check for the UP5 V5 include closure.

This checker does not execute Julia. It resolves the include roots used by the
V5 test and enumerates static literal includes in the package/runtime entry
trees. Three optional GenomeV5 loader calls are explicitly classified as
call-time (not import-time) and remain outside this test's closure.
"""

from __future__ import annotations

import ast
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
from typing import Iterable


ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
ARCHIVE = ROOT / "docs/implementation/UP5-01/archive/physical_edge_obligation_v5b_include_closure_search_chain_r1_20260925"
PINS_PATH = ARCHIVE / "source_pins.json"
TEST = ROOT / "test/RuntimeV4/PhysicalEdgeObligationV5/physical_edge_obligation_v5_tests.jl"
V5_CHECKER = ROOT / "test/RuntimeV4/PhysicalEdgeObligationV5/verify_static_contract.py"

EXPECTED_ENTRY_COUNTS = {
    "src/FusionConceptAI.jl": 48,
    "src/RuntimeV4/FusionRuntimeV4.jl": 18,
}
PACKAGE_ROOT = "src/FusionConceptAI.jl"
RUNTIME_ROOT = "src/RuntimeV4/FusionRuntimeV4.jl"
TEST_ROOTS = (
    "test/RuntimeV4/PhysicalEdgeObligationV5/physical_edge_obligation_v5_tests.jl",
    "test/RuntimeV4/SearchPhysicalConsumerV4/search_physical_consumer_fixture_v4.jl",
)
OPTIONAL_CALL_TIME_LOADERS = {
    "src/GenomeV5/Integration/GenomeV5Integration.jl": (
        "Base.include(@__MODULE__, joinpath(root, file))",
    ),
    "src/GenomeV5/UP2/UP2ModuleEntryV1.jl": (
        "Base.include(@__MODULE__, joinpath(@__DIR__, file))",
    ),
    "src/GenomeV5/Integration/VNextT2ModuleEntryV2.jl": (
        "Base.include(@__MODULE__, joinpath(source_root, relative_path))",
    ),
}
V5_DYNAMIC_ALIAS = "Base.include(parent, compat_path)"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def rel(path: Path) -> str:
    return path.resolve().relative_to(ROOT.resolve()).as_posix()


def _skip_quoted_or_comment(text: str, start: int) -> int:
    """Return the first index after one Julia string/comment beginning at start."""
    if text.startswith("#=", start):
        depth = 1
        i = start + 2
        while i < len(text) and depth:
            if text.startswith("#=", i):
                depth += 1
                i += 2
            elif text.startswith("=#", i):
                depth -= 1
                i += 2
            else:
                i += 1
        return i
    if text[start] == "#":
        newline = text.find("\n", start + 1)
        return len(text) if newline < 0 else newline + 1
    if text.startswith('"""', start):
        i = start + 3
        while i < len(text):
            if text[i] == "\\":
                i += 2
            elif text.startswith('"""', i):
                return i + 3
            else:
                i += 1
        return len(text)
    if text[start] == '"':
        i = start + 1
        while i < len(text):
            if text[i] == "\\":
                i += 2
            elif text[i] == '"':
                return i + 1
            else:
                i += 1
        return len(text)
    return start


def _matching_paren(text: str, open_index: int) -> int | None:
    depth = 1
    i = open_index + 1
    while i < len(text):
        skipped = _skip_quoted_or_comment(text, i)
        if skipped != i:
            i = skipped
            continue
        if text[i] == "(":
            depth += 1
        elif text[i] == ")":
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return None


def _split_top_level(expression: str) -> list[str]:
    out: list[str] = []
    start = 0
    depth = 0
    i = 0
    while i < len(expression):
        skipped = _skip_quoted_or_comment(expression, i)
        if skipped != i:
            i = skipped
            continue
        char = expression[i]
        if char == "(":
            depth += 1
        elif char == ")":
            depth -= 1
        elif char == "," and depth == 0:
            out.append(expression[start:i].strip())
            start = i + 1
        i += 1
    tail = expression[start:].strip()
    if tail:
        out.append(tail)
    return out


def include_calls(path: Path) -> list[dict[str, object]]:
    text = path.read_text(encoding="utf-8")
    calls: list[dict[str, object]] = []
    i = 0
    while i < len(text):
        skipped = _skip_quoted_or_comment(text, i)
        if skipped != i:
            i = skipped
            continue
        if text.startswith("include", i):
            before = text[i - 1] if i else " "
            after_index = i + len("include")
            after = text[after_index] if after_index < len(text) else " "
            if (before.isalnum() or before == "_") or (after.isalnum() or after == "_"):
                i += len("include")
                continue
            j = after_index
            while j < len(text) and text[j].isspace():
                j += 1
            if j >= len(text) or text[j] != "(":
                i = after_index
                continue
            close = _matching_paren(text, j)
            if close is None:
                calls.append({"line": text.count("\n", 0, i) + 1, "expression": "<unclosed include>", "path_expression": None})
                i = j + 1
                continue
            prefix = text[max(0, i - 5):i]
            base_include = prefix.endswith("Base.")
            arguments = _split_top_level(text[j + 1:close])
            path_expression = arguments[-1] if base_include and arguments else (arguments[0] if arguments else "")
            calls.append({
                "line": text.count("\n", 0, i) + 1,
                "expression": text[i:close + 1],
                "path_expression": path_expression,
                "base_include": base_include,
            })
            i = close + 1
            continue
        i += 1
    return calls


def _strip_parens(expression: str) -> str:
    value = expression.strip()
    while value.startswith("(") and value.endswith(")"):
        close = _matching_paren(value, 0)
        if close != len(value) - 1:
            break
        value = value[1:-1].strip()
    return value


def _string_literal(expression: str) -> str | None:
    value = expression.strip()
    if len(value) < 2 or value[0] != '"' or value[-1] != '"':
        return None
    try:
        decoded = ast.literal_eval(value)
    except (SyntaxError, ValueError):
        return None
    return decoded if isinstance(decoded, str) else None


def resolve_path_expression(expression: str, source: Path) -> Path | None:
    """Resolve the literal path forms used by this fixture/load closure."""
    value = _strip_parens(expression)
    literal = _string_literal(value)
    if literal is not None:
        return Path(literal)
    if value == "@__DIR__":
        return source.parent.resolve()
    if value == "@__FILE__":
        return source.resolve()
    if value in {"ROOT", "F5.ROOT", "F2.ROOT"}:
        return ROOT.resolve()
    for wrapper in ("joinpath", "normpath", "abspath"):
        prefix = wrapper + "("
        if value.startswith(prefix) and value.endswith(")"):
            args = _split_top_level(value[len(prefix):-1])
            if not args:
                return None
            parts = [resolve_path_expression(arg, source) for arg in args]
            if any(part is None for part in parts):
                return None
            first, *rest = parts
            result = first
            for item in rest:
                assert item is not None
                result = result / item
            if wrapper == "abspath":
                return result.resolve()
            return Path(os.path.normpath(str(result))).resolve()
    return None


def _path_for_call(source: Path, call: dict[str, object]) -> tuple[Path | None, str | None]:
    expression = str(call.get("path_expression") or "").strip()
    source_rel = rel(source)
    if source_rel == TEST_ROOTS[0] and expression == "compat_path":
        test_text = source.read_text(encoding="utf-8")
        required = (
            "const V1_COMPAT_PATH_V5 = joinpath(F5.ROOT, \"src\", \"RuntimeV4\",",
            "_load_v1_compat_with_parent_alias_v5!(R5, V1_COMPAT_PATH_V5)",
            V5_DYNAMIC_ALIAS,
        )
        if all(item in test_text for item in required):
            return ROOT / "src/RuntimeV4/PhysicalEdgeObligationV1Compat.jl", "resolved_v5_compat_path_alias"
        return None, "compat_path_alias_proof_missing"
    resolved = resolve_path_expression(expression, source)
    if resolved is not None:
        if not resolved.is_absolute():
            resolved = (source.parent / resolved).resolve()
        return resolved, None
    optional = OPTIONAL_CALL_TIME_LOADERS.get(source_rel, ())
    full_expression = ("Base." if call.get("base_include") else "") + str(call.get("expression"))
    if any(item in full_expression for item in optional):
        return None, "optional_call_time_loader_not_executed_by_import_or_v5_test"
    return None, "unresolved_include_expression"


def _validate_pin_rows(rows: object) -> tuple[list[str], set[str]]:
    errors: list[str] = []
    pinned: set[str] = set()
    if not isinstance(rows, list):
        return ["source_pins_not_list"], pinned
    for row in rows:
        if not isinstance(row, dict):
            errors.append("malformed_pin_row")
            continue
        path_text = row.get("path")
        digest = row.get("sha256")
        byte_count = row.get("bytes")
        if not isinstance(path_text, str) or path_text in pinned:
            errors.append(f"duplicate_or_invalid_pin_path:{path_text}")
            continue
        pinned.add(path_text)
        source = ROOT / Path(path_text)
        if not source.is_file():
            errors.append(f"missing_pin:{path_text}")
            continue
        raw = source.read_bytes()
        if len(raw) != byte_count:
            errors.append(f"pin_byte_drift:{path_text}")
        if sha256(source) != digest:
            errors.append(f"pin_hash_drift:{path_text}")
    return errors, pinned


def _json_pin_errors(pins: dict[str, object]) -> tuple[list[str], set[str]]:
    return _validate_pin_rows(pins.get("source_pins"))


def _closure_pin_errors(reached: set[str], pinned: set[str]) -> list[str]:
    return [f"include_not_pinned:{path}" for path in sorted(reached - pinned)]


def enumerate_closure(roots: Iterable[str]) -> tuple[set[str], list[dict[str, object]], list[str]]:
    reached: set[str] = set()
    edges: list[dict[str, object]] = []
    errors: list[str] = []
    queue = [ROOT / Path(item) for item in roots]
    while queue:
        current = queue.pop(0).resolve()
        try:
            current_rel = rel(current)
        except ValueError:
            errors.append(f"include_outside_repository:{current}")
            continue
        if current_rel in reached:
            continue
        if not current.is_file():
            errors.append(f"missing_include_target:{current_rel}")
            continue
        reached.add(current_rel)
        for call in include_calls(current):
            target, note = _path_for_call(current, call)
            if target is None:
                if note and note.startswith("optional_call_time_loader"):
                    edges.append({
                        "source": current_rel,
                        "line": call["line"],
                        "expression": call["expression"],
                        "target": None,
                        "classification": note,
                    })
                    continue
                errors.append(f"{note}:{current_rel}:{call['line']}:{call['expression']}")
                continue
            try:
                target_rel = rel(target)
            except ValueError:
                errors.append(f"include_outside_repository:{current_rel}:{call['line']}:{target}")
                continue
            edges.append({
                "source": current_rel,
                "line": call["line"],
                "expression": call["expression"],
                "target": target_rel,
                "classification": note or "static_include",
            })
            queue.append(target)
    return reached, edges, errors


def main() -> int:
    errors: list[str] = []
    if not PINS_PATH.is_file():
        print(json.dumps({"schema": "up5-v5b-include-closure-check-r1", "error": "source pin manifest missing", "path": rel(PINS_PATH)}))
        return 2
    pins = json.loads(PINS_PATH.read_text(encoding="utf-8"))
    pin_errors, pinned = _json_pin_errors(pins)
    errors.extend(pin_errors)

    roots = pins.get("include_roots")
    if roots != [PACKAGE_ROOT, TEST_ROOTS[0]]:
        errors.append("unexpected_include_roots")
        roots = [PACKAGE_ROOT, TEST_ROOTS[0]]
    if "using FusionConceptAI" not in TEST.read_text(encoding="utf-8"):
        errors.append("v5_test_no_package_import")
    project = (ROOT / "Project.toml").read_text(encoding="utf-8")
    if not re.search(r'^name\s*=\s*"FusionConceptAI"\s*$', project, re.MULTILINE):
        errors.append("project_package_name_mismatch")
    v5_test_text = TEST.read_text(encoding="utf-8")
    package_text = (ROOT / PACKAGE_ROOT).read_text(encoding="utf-8")
    optional_load_names = (
        "load_genome_v5_components!",
        "load_genome_v5_up2_components!",
        "load_vnext_t2_components_v2!",
    )
    if "__init__(" in package_text:
        errors.append("package_has_unreviewed_init_loader")
    if any(re.search(rf"(?<![A-Za-z0-9_]){re.escape(name)}\s*\(", v5_test_text) for name in optional_load_names):
        errors.append("v5_test_invokes_optional_package_loader")

    # The fixture includes FusionRuntimeV4 and the V5 code paths. Pin and audit
    # the standalone runtime entry too, then merge its recursive closure.
    entry_roots = [*roots, RUNTIME_ROOT]
    reached, edges, closure_errors = enumerate_closure(entry_roots)
    errors.extend(closure_errors)
    errors.extend(_closure_pin_errors(reached, pinned))

    for entry, expected_count in EXPECTED_ENTRY_COUNTS.items():
        path = ROOT / Path(entry)
        count = len(include_calls(path)) if path.is_file() else -1
        if count != expected_count:
            errors.append(f"entry_include_count_mismatch:{entry}:expected={expected_count}:actual={count}")

    expected_closure = set(pins.get("expected_include_closure", ()))
    if reached != expected_closure:
        errors.append("include_closure_set_mismatch")
    recovered_from_v5_review = set(pins.get("recovered_review_unpinned_paths", ()))
    if len(recovered_from_v5_review) != 61:
        errors.append("review_unpinned_path_count_mismatch")
    if not recovered_from_v5_review.issubset(reached):
        errors.append("review_unpinned_path_not_in_include_closure")
    optional_edges = [edge for edge in edges if edge["target"] is None]
    expected_optional = sum(len(rows) for rows in OPTIONAL_CALL_TIME_LOADERS.values())
    if len(optional_edges) != expected_optional:
        errors.append(f"call_time_loader_count_mismatch:expected={expected_optional}:actual={len(optional_edges)}")
    for source, expressions in OPTIONAL_CALL_TIME_LOADERS.items():
        code = (ROOT / Path(source)).read_text(encoding="utf-8")
        for expression in expressions:
            if expression not in code:
                errors.append(f"call_time_loader_signature_changed:{source}:{expression}")

    trusted_example = (ROOT / "examples/runtime_v4_trusted_provider_registry.jl").read_text(encoding="utf-8")
    module_load_tpr_calls = len(re.findall(r"\bexecute_trusted_provider\s*\(", trusted_example))
    if module_load_tpr_calls != 1:
        errors.append(f"tpr_module_load_fixture_call_count_mismatch:{module_load_tpr_calls}")
    if "model_class=\"test_only\"" not in trusted_example or "execution_kind=:repository_fixture" not in (ROOT / "src/RuntimeV4/TrustedProviderRegistryV4.jl").read_text(encoding="utf-8"):
        errors.append("tpr_module_load_call_not_pinned_as_test_only_generic")

    # Re-run the frozen V5 source-only fixture contract, not a Julia test.
    static_run = subprocess.run(
        [sys.executable, "-B", str(V5_CHECKER)],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
    )
    if static_run.returncode != 0:
        errors.append(f"v5_static_checker_exit:{static_run.returncode}")
    try:
        v5_static = json.loads(static_run.stdout.strip().splitlines()[-1])
    except (IndexError, json.JSONDecodeError):
        v5_static = {"parse_error": True, "stdout": static_run.stdout[-1000:]}
        errors.append("v5_static_checker_output_invalid")
    if v5_static.get("passed") != 11 or v5_static.get("total") != 11:
        errors.append("v5_static_contract_not_11_of_11")

    # Local logic negatives: a removed direct pin, a hash mutation, and an
    # unresolved dynamic include must each fail closed before any test credit.
    rows = pins.get("source_pins", [])
    rows_without_direct = [row for row in rows if row.get("path") != "src/IR/PhysicalTypes.jl"]
    removed_errors, removed_pins = _validate_pin_rows(rows_without_direct)
    removed_pin_detected = (
        "src/IR/PhysicalTypes.jl" in reached
        and "src/IR/PhysicalTypes.jl" not in removed_pins
        and "include_not_pinned:src/IR/PhysicalTypes.jl"
        in _closure_pin_errors(reached, removed_pins)
        and not any(error == "source_pins_not_list" for error in removed_errors)
    )
    tampered_rows = [dict(row) for row in rows]
    for row in tampered_rows:
        if row.get("path") == PACKAGE_ROOT:
            row["sha256"] = "0" * 64
    tamper_errors, _ = _validate_pin_rows(tampered_rows)
    bad_hash_detected = f"pin_hash_drift:{PACKAGE_ROOT}" in tamper_errors
    unresolved_negative = resolve_path_expression("joinpath(@__DIR__, runtime_path)", ROOT / "test/RuntimeV4/fake.jl") is None
    local_negatives = {
        "removed_direct_pin_is_detected": removed_pin_detected,
        "bad_hash_pin_is_detected": bad_hash_detected,
        "unresolved_dynamic_path_fails_closed": unresolved_negative,
    }
    for name, passed in local_negatives.items():
        if not passed:
            errors.append(f"local_negative_failed:{name}")

    result = {
        "schema": "up5-v5b-include-closure-check-r1",
        "execution": "python_static_only_no_julia_no_freegs",
        "source_pin_count": len(pinned),
        "include_roots": entry_roots,
        "reached_include_closure_count": len(reached),
        "reached_include_closure": sorted(reached),
        "literal_include_edge_count": len(edges),
        "include_edges": edges,
        "entry_include_counts": {path: len(include_calls(ROOT / Path(path))) for path in EXPECTED_ENTRY_COUNTS},
        "call_time_loader_calls": optional_edges,
        "optional_package_loader_invocations_in_test": [],
        "trusted_provider_module_load_fixture_executor_calls": module_load_tpr_calls,
        "trusted_provider_module_load_fixture_executor_class": "test_only_repository_fixture; source call is top-level; Python static run did not execute it",
        "local_negatives": local_negatives,
        "v5_static_contract": v5_static,
        "failures": errors,
        "passed": not errors,
    }
    print(json.dumps(result, sort_keys=True, separators=(",", ":")))
    return 0 if not errors else 1


if __name__ == "__main__":
    sys.exit(main())
