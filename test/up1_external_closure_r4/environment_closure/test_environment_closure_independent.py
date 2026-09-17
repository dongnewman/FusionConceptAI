"""Independent, read-only tests for the frozen R4 environment collector.

This module deliberately imports the implementation as a black box.  It does
not patch or edit files below ``tools/up1_external_closure_r4``.  The checks
return structured observations so the serial evidence runner can preserve raw
stdout, process metadata, and a bounded ``pass_limited``/``fail_limited``
conclusion.  A pass is local test evidence only; it is never external
authority or a formal UP1 gate.
"""
from __future__ import annotations

import ast
import contextlib
import hashlib
import io
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime
from typing import Any, Callable

TOOLS_ROOT = Path(__file__).resolve().parents[3] / "tools" / "up1_external_closure_r4" / "environment_closure"
sys.path.insert(0, str(Path(__file__).resolve().parents[3]))

from tools.up1_external_closure_r4.environment_closure import (  # noqa: E402
    CollectorError,
    FAIL_CLOSED,
    LOCAL_OBSERVED,
    TYPED_ABSENT,
    collect_closure,
    collect_file_observation,
    file_sha256,
)
from tools.up1_external_closure_r4.environment_closure.collector import dump_receipt, TYPED_UNVERIFIED  # noqa: E402


def _utc(value: Any) -> bool:
    if not isinstance(value, str) or not value.endswith("Z"):
        return False
    try:
        datetime.fromisoformat(value[:-1] + "+00:00")
    except ValueError:
        return False
    return True


def _digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _fixture() -> tuple[tempfile.TemporaryDirectory[str], Path, Path]:
    holder = tempfile.TemporaryDirectory(prefix="up1-r4-env-test-")
    root = Path(holder.name)
    (root / "Project.toml").write_text("name = 'independent-fixture'\n", encoding="utf-8")
    lock = root / "requirements.lock"
    lock.write_text("python==3.13.5\n", encoding="utf-8")
    return holder, root, lock


def check_read_only() -> dict[str, Any]:
    holder, root, lock = _fixture()
    try:
        before = {p.name: (_digest(p), p.stat().st_mtime_ns) for p in (root / "Project.toml", lock)}
        receipt = collect_closure(
            root=root,
            python_path=sys.executable,
            binaries=[{"name": "python", "path": sys.executable}],
            manifests=[lock],
            probe_versions=False,
        )
        after = {p.name: (_digest(p), p.stat().st_mtime_ns) for p in (root / "Project.toml", lock)}
        return {"ok": before == after, "detail": {"status": receipt.get("status"), "inputs_unchanged": before == after}}
    finally:
        holder.cleanup()


def check_no_shell_network_install_env() -> dict[str, Any]:
    source = "\n".join(p.read_text(encoding="utf-8") for p in TOOLS_ROOT.glob("*.py"))
    tree = ast.parse(source)
    forbidden_imports = {"socket", "requests", "urllib", "httpx", "pip", "ensurepip"}
    imported = {alias.name.split(".")[0] for node in ast.walk(tree) if isinstance(node, ast.Import) for alias in node.names}
    imported |= {node.module.split(".")[0] for node in ast.walk(tree) if isinstance(node, ast.ImportFrom) and node.module}
    forbidden_calls = []
    for node in ast.walk(tree):
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute):
            dotted = f"{getattr(node.func.value, 'id', '')}.{node.func.attr}"
            if dotted in {"os.system", "os.popen", "os.putenv", "subprocess.run", "subprocess.call"}:
                forbidden_calls.append(dotted)
        if isinstance(node, ast.keyword) and node.arg == "shell" and isinstance(node.value, ast.Constant) and node.value.value is True:
            forbidden_calls.append("shell=True")
    holder, root, lock = _fixture()
    secret = "R4-INDEPENDENT-SECRET-DO-NOT-LEAK"
    old = os.environ.get("UP1_R4_TEST_SECRET")
    os.environ["UP1_R4_TEST_SECRET"] = secret
    try:
        receipt = collect_closure(root=root, python_path=sys.executable, manifests=[lock], probe_versions=True)
        encoded = json.dumps(receipt, sort_keys=True)
        policy = receipt.get("command_policy", {})
        no_leak = secret not in encoded
        ok = not (forbidden_imports & imported) and not forbidden_calls and no_leak and all(policy.get(k) is False for k in ("network_used", "download_performed", "installation_performed", "environment_modified", "environment_variables_captured"))
        return {"ok": ok, "detail": {"forbidden_imports": sorted(forbidden_imports & imported), "forbidden_calls": forbidden_calls, "secret_leaked": not no_leak, "command_policy": policy}}
    finally:
        if old is None:
            os.environ.pop("UP1_R4_TEST_SECRET", None)
        else:
            os.environ["UP1_R4_TEST_SECRET"] = old
        holder.cleanup()


def check_reparse_rejected() -> dict[str, Any]:
    holder, root, _ = _fixture()
    target = root / "target.txt"
    link = root / "link.txt"
    target.write_text("target\n", encoding="utf-8")
    try:
        os.symlink(target, link)
    except (OSError, NotImplementedError) as exc:
        holder.cleanup()
        return {"ok": False, "detail": {"blocked": "symlink_creation_unavailable", "error": type(exc).__name__}}
    try:
        observed = collect_file_observation(link, name="reparse", role="fixture")
        try:
            file_sha256(link)
            hash_rejected = False
        except CollectorError:
            hash_rejected = True
        ok = observed.get("status") == TYPED_UNVERIFIED and observed.get("reason") == "reparse_point_not_read" and hash_rejected
        return {"ok": ok, "detail": {"observation": observed, "hash_rejected": hash_rejected}}
    finally:
        holder.cleanup()


def check_no_overwrite() -> dict[str, Any]:
    holder, root, _ = _fixture()
    output = root / "receipt.json"
    output.write_text("sentinel\n", encoding="utf-8")
    before = _digest(output)
    try:
        try:
            dump_receipt({"status": "would-overwrite"}, output)
            rejected = False
        except CollectorError as exc:
            rejected = str(exc) == "refuse_to_overwrite_receipt"
        return {"ok": rejected and _digest(output) == before, "detail": {"rejected": rejected, "unchanged": _digest(output) == before}}
    finally:
        holder.cleanup()


def check_hash_pid_utc_exit() -> dict[str, Any]:
    holder, root, lock = _fixture()
    try:
        receipt = collect_closure(root=root, python_path=sys.executable, manifests=[lock], probe_versions=True)
        command = receipt["runtimes"][0]["version_command"]
        fields_ok = (
            isinstance(receipt.get("collector", {}).get("pid"), int)
            and receipt["collector"]["pid"] == os.getpid()
            and _utc(receipt.get("observed_utc"))
            and _utc(receipt["collector"].get("started_utc"))
            and _utc(receipt["collector"].get("ended_utc"))
            and isinstance(command.get("pid"), int)
            and isinstance(command.get("exit_code"), int)
            and command.get("exit_code") == 0
            and _utc(command.get("started_utc"))
            and _utc(command.get("ended_utc"))
            and bool(re.fullmatch(r"[0-9a-f]{64}", str(command.get("output_sha256"))))
        )
        return {"ok": fields_ok, "detail": {"collector_pid": receipt["collector"].get("pid"), "probe_pid": command.get("pid"), "exit_code": command.get("exit_code"), "utc_fields": all(_utc(command.get(k)) for k in ("started_utc", "ended_utc"))}}
    finally:
        holder.cleanup()


def check_missing_provenance_typed_absent() -> dict[str, Any]:
    holder, root, lock = _fixture()
    try:
        receipt = collect_closure(root=root, python_path=sys.executable, binaries=[{"name": "python", "path": sys.executable}], manifests=[lock])
        provenance = receipt.get("provenance", {})
        keys = ("source_receipt", "signature", "download_receipt", "sbom", "build_recipe")
        statuses = {key: provenance.get(key, {}).get("status") for key in keys}
        ok = receipt.get("status") == TYPED_ABSENT and all(value == TYPED_ABSENT for value in statuses.values()) and set(keys).issubset(set(receipt.get("missing_or_unverified", [])))
        return {"ok": ok, "detail": {"receipt_status": receipt.get("status"), "provenance_statuses": statuses, "missing": receipt.get("missing_or_unverified")}}
    finally:
        holder.cleanup()


def check_version_not_reproducible_closure() -> dict[str, Any]:
    holder, root, lock = _fixture()
    try:
        receipt = collect_closure(root=root, python_path=sys.executable, manifests=[lock], probe_versions=True)
        ceiling = str(receipt.get("claim_ceiling", ""))
        version = receipt["runtimes"][0].get("version")
        ok = bool(version) and "do not establish reproducible closure" in ceiling and receipt.get("status") != "reproducible"
        return {"ok": ok, "detail": {"version": version, "claim_ceiling": ceiling, "status": receipt.get("status")}}
    finally:
        holder.cleanup()


def check_malicious_paths_and_args() -> dict[str, Any]:
    holder, root, _ = _fixture()
    secret = "SHOULD-NOT-BE-EXPANDED"
    try:
        literal = collect_file_observation(f"%UP1_R4_{secret}%", name="literal", role="fixture")
        nul = collect_file_observation("bad\x00path", name="nul", role="fixture")
        nul_hash_rejected = False
        try:
            file_sha256("bad\x00path")
        except CollectorError:
            nul_hash_rejected = True
        malformed = subprocess.run([sys.executable, "-m", "tools.up1_external_closure_r4.environment_closure", "--binary", "malicious;echo PWNED"], cwd=Path(__file__).resolve().parents[3], capture_output=True, text=True, shell=False)
        output = (malformed.stdout or "") + (malformed.stderr or "")
        ok = literal.get("status") == TYPED_ABSENT and "%UP1_R4_" in str(literal.get("path")) and nul.get("status") == FAIL_CLOSED and nul_hash_rejected and malformed.returncode == 2 and "PWNED" not in output
        return {"ok": ok, "detail": {"literal_path_status": literal.get("status"), "nul_status": nul.get("status"), "nul_hash_rejected": nul_hash_rejected, "malicious_arg_exit": malformed.returncode, "arg_output_contains_payload": "PWNED" in output}}
    finally:
        holder.cleanup()


CHECKS: tuple[tuple[str, Callable[[], dict[str, Any]]], ...] = (
    ("read_only", check_read_only),
    ("no_shell_network_install_env_leak", check_no_shell_network_install_env),
    ("reparse_rejected", check_reparse_rejected),
    ("no_overwrite", check_no_overwrite),
    ("hash_pid_utc_exit", check_hash_pid_utc_exit),
    ("missing_provenance_typed_absent", check_missing_provenance_typed_absent),
    ("version_not_reproducible_closure", check_version_not_reproducible_closure),
    ("malicious_paths_and_args", check_malicious_paths_and_args),
)


def run_checks() -> dict[str, Any]:
    results: dict[str, Any] = {}
    for name, function in CHECKS:
        try:
            results[name] = function()
        except Exception as exc:  # independent harness must fail closed
            results[name] = {"ok": False, "detail": {"unexpected": type(exc).__name__, "message": str(exc)}}
    passed = [name for name, result in results.items() if result.get("ok")]
    failed = [name for name, result in results.items() if not result.get("ok")]
    return {
        "record_kind": "up1_external_environment_closure_r4_independent_test",
        "schema": "UP1.external-environment-closure-r4-independent-test.v1",
        "status": "pass_limited" if not failed else "fail_limited",
        "authority": {"authoritative": False, "status": "local_test_only"},
        "claim_ceiling": "independent local behavior test only; no external authority and no formal UP1 gate",
        "passed": passed,
        "failed": failed,
        "checks": results,
    }


if __name__ == "__main__":
    print(json.dumps(run_checks(), ensure_ascii=False, sort_keys=True, indent=2))
