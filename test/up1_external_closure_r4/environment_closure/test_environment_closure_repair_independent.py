"""Independent repair retest for the frozen R4 environment collector.

The implementation under test is imported as-is.  This module only creates
temporary fixtures, performs static source inspection, and emits a bounded
local result.  It does not edit ``tools/up1_external_closure_r4``.
"""
from __future__ import annotations

import ast
import hashlib
import json
import os
import stat
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from types import SimpleNamespace
from typing import Any, Callable
from unittest.mock import patch

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
TOOLS_ROOT = ROOT / "tools" / "up1_external_closure_r4" / "environment_closure"
COLLECTOR_SOURCE = TOOLS_ROOT / "collector.py"
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(HERE))

from tools.up1_external_closure_r4.environment_closure import (  # noqa: E402
    CollectorError,
    FAIL_CLOSED,
    LOCAL_OBSERVED,
    collect_file_observation,
    file_sha256,
)
from tools.up1_external_closure_r4.environment_closure import collector  # noqa: E402


def _utc() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="milliseconds").replace("+00:00", "Z")


def _digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _fixture() -> tuple[tempfile.TemporaryDirectory[str], Path, Path]:
    holder = tempfile.TemporaryDirectory(prefix="up1-r4-repair-retest-")
    root = Path(holder.name)
    target = root / "regular.txt"
    target.write_bytes(b"frozen regular fixture\n")
    return holder, root, target


def check_static_lexical_lstat_before_resolve() -> dict[str, Any]:
    source = COLLECTOR_SOURCE.read_text(encoding="utf-8")
    tree = ast.parse(source, filename=str(COLLECTOR_SOURCE))
    safe_path = next(node for node in tree.body if isinstance(node, ast.FunctionDef) and node.name == "_safe_path")
    lstat_function = next(node for node in tree.body if isinstance(node, ast.FunctionDef) and node.name == "_lstat")
    lexical_calls = [
        node.lineno
        for node in ast.walk(safe_path)
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Name) and node.func.id == "_inspect_lexical_components"
    ]
    resolve_calls = [
        node.lineno
        for node in ast.walk(safe_path)
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute) and node.func.attr == "resolve"
    ]
    oserror_fail_closed = any(
        isinstance(handler.type, ast.Name)
        and handler.type.id == "OSError"
        and any(
            isinstance(node, ast.Raise)
            and isinstance(node.exc, ast.Call)
            and isinstance(node.exc.func, ast.Name)
            and node.exc.func.id == "CollectorError"
            for node in ast.walk(handler)
        )
        for handler in ast.walk(lstat_function)
        if isinstance(handler, ast.ExceptHandler)
    )
    lexical_before_resolve = bool(lexical_calls and resolve_calls) and max(lexical_calls) < min(resolve_calls)
    ok = lexical_before_resolve and oserror_fail_closed
    return {
        "ok": ok,
        "detail": {
            "lexical_lstat_line_numbers": sorted(lexical_calls),
            "resolve_line_numbers": sorted(resolve_calls),
            "lexical_lstat_before_resolve": lexical_before_resolve,
            "lstat_oserror_raises_collector_error": oserror_fail_closed,
            "collector_sha256": _digest(COLLECTOR_SOURCE),
        },
    }


def check_oserror_fail_closed() -> dict[str, Any]:
    holder, root, target = _fixture()
    try:
        with patch.object(Path, "lstat", side_effect=PermissionError("simulated-lstat-denied")):
            observed = collect_file_observation(target, name="simulated", role="fixture")
        ok = observed.get("status") == FAIL_CLOSED and str(observed.get("reason", "")).startswith("path_inspection_failed:")
        return {"ok": ok, "detail": {"status": observed.get("status"), "reason": observed.get("reason")}}
    finally:
        holder.cleanup()


def check_root_escape_rejected() -> dict[str, Any]:
    holder, root, _ = _fixture()
    outside = root.parent / f"{root.name}-outside.txt"
    outside.write_bytes(b"outside-root\n")
    try:
        observed = collect_file_observation(outside, name="escape", role="fixture", root=root)
        ok = observed.get("status") == FAIL_CLOSED and observed.get("reason") == "path_escapes_root"
        return {"ok": ok, "detail": {"status": observed.get("status"), "reason": observed.get("reason")}}
    finally:
        outside.unlink(missing_ok=True)
        holder.cleanup()


def check_symlink_if_permitted() -> dict[str, Any]:
    holder, root, target = _fixture()
    link = root / "link.txt"
    try:
        try:
            os.symlink(target, link)
        except (OSError, NotImplementedError) as exc:
            return {
                "ok": True,
                "deferred": True,
                "detail": {"status": "test_scope_deferred", "reason": "symlink_creation_unavailable", "error": type(exc).__name__},
            }
        observed = collect_file_observation(link, name="reparse", role="fixture")
        rejected = False
        try:
            file_sha256(link)
        except CollectorError:
            rejected = True
        ok = observed.get("status") == "typed_unverified" and observed.get("reason") == "reparse_point_not_read" and rejected
        return {"ok": ok, "detail": {"status": observed.get("status"), "reason": observed.get("reason"), "hash_rejected": rejected}}
    finally:
        holder.cleanup()


def _stat_view(raw: os.stat_result, **changes: int) -> SimpleNamespace:
    values = {
        "st_dev": raw.st_dev,
        "st_ino": raw.st_ino,
        "st_mode": raw.st_mode,
        "st_size": raw.st_size,
        "st_mtime_ns": raw.st_mtime_ns,
    }
    values.update(changes)
    return SimpleNamespace(**values)


def _hash_rejects_mutation(path: Path, mutation: str) -> bool:
    real_fstat = os.fstat
    calls = 0

    def fake_fstat(fd: int) -> SimpleNamespace:
        nonlocal calls
        calls += 1
        raw = real_fstat(fd)
        if mutation == "identity" and calls == 1:
            return _stat_view(raw, st_ino=raw.st_ino + 1)
        if mutation == "size" and calls == 2:
            return _stat_view(raw, st_size=raw.st_size + 1)
        if mutation == "mtime" and calls == 2:
            return _stat_view(raw, st_mtime_ns=raw.st_mtime_ns + 1)
        return _stat_view(raw)

    with patch.object(collector.os, "fstat", side_effect=fake_fstat):
        try:
            file_sha256(path)
        except CollectorError as exc:
            return str(exc) == "path_identity_changed"
    return False


def check_regular_hash_and_toctou() -> dict[str, Any]:
    holder, root, target = _fixture()
    try:
        expected = _digest(target)
        observed = collect_file_observation(target, name="regular", role="fixture")
        regular_ok = file_sha256(target) == expected and observed.get("status") == LOCAL_OBSERVED and observed.get("sha256") == expected
        mutations = {name: _hash_rejects_mutation(target, name) for name in ("identity", "size", "mtime")}
        ok = regular_ok and all(mutations.values())
        return {"ok": ok, "detail": {"regular_hash_match": regular_ok, "mutations_rejected": mutations, "sha256": expected}}
    finally:
        holder.cleanup()


def check_existing_eight_regressions() -> dict[str, Any]:
    import test_environment_closure_independent as legacy  # noqa: WPS433

    payload = legacy.run_checks()
    hard_failed: list[str] = []
    deferred: list[str] = []
    for name, result in payload.get("checks", {}).items():
        if result.get("ok"):
            continue
        detail = result.get("detail", {})
        if detail.get("blocked") == "symlink_creation_unavailable":
            deferred.append(name)
        else:
            hard_failed.append(name)
    return {
        "ok": not hard_failed,
        "deferred": bool(deferred),
        "detail": {
            "legacy_status": payload.get("status"),
            "legacy_passed": payload.get("passed", []),
            "legacy_failed": payload.get("failed", []),
            "deferred": deferred,
            "hard_failed": hard_failed,
        },
    }


CHECKS: tuple[tuple[str, Callable[[], dict[str, Any]]], ...] = (
    ("static_lexical_lstat_before_resolve", check_static_lexical_lstat_before_resolve),
    ("oserror_fail_closed", check_oserror_fail_closed),
    ("root_escape_rejected", check_root_escape_rejected),
    ("symlink_if_permitted", check_symlink_if_permitted),
    ("regular_hash_and_toctou_identity_size_mtime", check_regular_hash_and_toctou),
    ("existing_eight_regressions", check_existing_eight_regressions),
)


def run_retest() -> dict[str, Any]:
    started = _utc()
    results: dict[str, Any] = {}
    for name, function in CHECKS:
        try:
            results[name] = function()
        except Exception as exc:  # independent harness fails closed
            results[name] = {"ok": False, "detail": {"unexpected": type(exc).__name__, "message": str(exc)}}
    failed = [name for name, result in results.items() if not result.get("ok")]
    deferred = [name for name, result in results.items() if result.get("deferred") or result.get("detail", {}).get("deferred")]
    payload = {
        "record_kind": "up1_external_environment_closure_r4_repair_independent_retest",
        "schema": "UP1.external-environment-closure-r4-repair-independent-retest.v1",
        "pid": os.getpid(),
        "started_utc": started,
        "ended_utc": _utc(),
        "status": "pass_limited" if not failed else "fail_limited",
        "test_scope_deferred": deferred,
        "failed": failed,
        "checks": results,
        "authority": {"authoritative": False, "status": "local_test_only"},
        "claim_ceiling": "independent local behavior evidence only; no external authority, no reproducible closure, and no formal UP1 gate",
        "implementation_frozen": {"path": str(COLLECTOR_SOURCE.relative_to(ROOT)), "sha256": _digest(COLLECTOR_SOURCE)},
    }
    return payload


if __name__ == "__main__":
    payload = run_retest()
    print(json.dumps(payload, ensure_ascii=False, sort_keys=True, indent=2))
    raise SystemExit(0 if payload["status"] == "pass_limited" else 1)
