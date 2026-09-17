"""Read-only static audit of the serialized UP2 R6 runtime receipt.

This checker intentionally does not import Julia, spawn Julia/DESC, or mutate
repository files.  It verifies the archived receipt, current input bytes, and
retained R3/R4/R5 failure receipts only.
"""

from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[6]
ARCHIVE = ROOT / "docs/implementation/UP2-01/contract_only/agent_local_r6"
RUNTIME = ARCHIVE / "runtime"
RUN = ROOT / "runs/agent_local_up2_tcir_contract_matrix_20260918_r6"


def read_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


checks: list[tuple[str, bool, str]] = []


def check(name: str, condition: bool, detail: str) -> None:
    checks.append((name, condition, detail))


doc_manifest = read_json(ARCHIVE / "manifest.json")
runtime_manifest = read_json(RUNTIME / "archive_manifest.json")
doc_pre = read_json(RUNTIME / "input_hashes_pre.json")
doc_post = read_json(RUNTIME / "input_hashes_post.json")
run_pre = read_json(RUN / "input_hashes_pre.json")
run_post = read_json(RUN / "input_hashes_post.json")
run_meta = read_json(RUN / "run.json")
archive_run_meta = read_json(RUNTIME / "run.json")

check("source_run_exists", RUN.is_dir(), str(RUN))
check("runtime_archive_exists", RUNTIME.is_dir(), str(RUNTIME))
check("head_matches_runtime", (RUNTIME / "head.txt").read_text(encoding="utf-8") == (RUN / "head.txt").read_text(encoding="utf-8"), "head.txt")
check("head_matches_run_json", (RUN / "head.txt").read_text(encoding="utf-8") == run_meta["head"] + "\n", "run.json.head")
check("head_matches_current_head", (RUN / "head.txt").read_text(encoding="utf-8").strip() == __import__("subprocess").check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(), "git HEAD")

expected_paths = [entry["path"] for entry in doc_pre]
check("four_inputs", len(expected_paths) == 4, repr(expected_paths))
check("pre_post_equal_doc", doc_pre == doc_post, "runtime pre/post")
check("pre_post_equal_run", run_pre == run_post, "runs pre/post")
check("doc_run_hashes_equal", doc_pre == run_pre, "archive versus source run")

current = []
for entry in doc_pre:
    path = ROOT / entry["path"]
    actual = sha256(path) if path.is_file() else "missing"
    current.append({"path": entry["path"], "sha256": actual})
    check(f"current_hash:{entry['path']}", actual == entry["sha256"], f"receipt={entry['sha256']} current={actual}")
check("current_hashes_equal_receipt", current == doc_pre, "all four input bytes")

for name in ("head.txt", "input_hashes_pre.json", "input_hashes_post.json", "run.json", "stdout.raw", "stderr.raw"):
    doc_file = RUNTIME / name
    run_file = RUN / name
    check(f"archive_file:{name}", doc_file.is_file(), str(doc_file))
    check(f"source_file:{name}", run_file.is_file(), str(run_file))
    if doc_file.is_file() and run_file.is_file():
        if name in {"head.txt", "stdout.raw", "stderr.raw"}:
            equivalent = doc_file.read_bytes() == run_file.read_bytes() if name != "head.txt" else doc_file.read_text(encoding="utf-8").strip() == run_file.read_text(encoding="utf-8").strip()
        else:
            equivalent = json.loads(doc_file.read_text(encoding="utf-8")) == json.loads(run_file.read_text(encoding="utf-8"))
        check(f"archive_content:{name}", equivalent, "semantic receipt equality")

check("run_exit_zero", run_meta.get("exit_code") == 0, repr(run_meta.get("exit_code")))
check("archive_run_exit_zero", archive_run_meta.get("exit_code") == 0, repr(archive_run_meta.get("exit_code")))
check("run_hashes_unchanged", run_meta.get("hashes_unchanged") is True, repr(run_meta.get("hashes_unchanged")))
check("archive_hashes_unchanged", archive_run_meta.get("hashes_unchanged") is True, repr(archive_run_meta.get("hashes_unchanged")))
check("run_command_is_isolated_contract", "typed_compiler_ir_v1_contract_tests.jl" in run_meta.get("command", ""), run_meta.get("command", ""))
stdout = (RUN / "stdout.raw").read_text(encoding="utf-8")
stderr = (RUN / "stderr.raw").read_bytes()
check("stdout_89_of_89", bool(re.search(r"89\s+89\s+1\.6s", stdout)), repr(stdout))
check("stderr_empty", stderr == b"", f"bytes={len(stderr)}")
check("runtime_timestamps_present", bool(run_meta.get("started_utc")) and bool(run_meta.get("finished_utc")), "start/end")

failure_expectations = {
    "r3": ("runs/agent_local_up2_tcir_contract_matrix_20260917_r3", 1, r"0 passed, 0 failed, 1 errored"),
    "r4": ("runs/agent_local_up2_tcir_contract_matrix_20260917_r4", 1, r"71 passed, 0 failed, 1 errored"),
    "r5": ("runs/agent_local_up2_tcir_contract_matrix_20260917_r5", 1, r"83 passed, 5 failed, 0 errored"),
}
for label, (relative, expected_exit, expected_summary) in failure_expectations.items():
    failure_dir = ROOT / relative
    failure_meta = read_json(failure_dir / "run.json")
    failure_text = (failure_dir / "stdout.raw").read_text(encoding="utf-8") + (failure_dir / "stderr.raw").read_text(encoding="utf-8")
    check(f"{label}_receipt_exists", failure_dir.is_dir(), str(failure_dir))
    check(f"{label}_exit_preserved", failure_meta.get("exit_code") == expected_exit, repr(failure_meta.get("exit_code")))
    check(f"{label}_summary_preserved", bool(re.search(expected_summary, failure_text)), expected_summary)
    check(f"{label}_hashes_unchanged", failure_meta.get("hashes_unchanged") is True, repr(failure_meta.get("hashes_unchanged")))

check("contract_only_ceiling", doc_manifest.get("status") == "contract_only" and doc_manifest.get("accepted") is False, "accepted=false")
check("formal_credit_none", doc_manifest.get("formal_acceptance") is False and doc_manifest["semantic_boundary"].get("formal_credit") == "none", "no formal credit")
check("no_desc_receipt", doc_manifest.get("desc_invoked") is False, "DESC absent")
check("no_formal_up2_credit", doc_manifest["semantic_boundary"].get("up2_t0_r_credit") == "none", "UP2 credit none")

passed = sum(ok for _, ok, _ in checks)
failed = len(checks) - passed
for name, ok, detail in checks:
    print(f"{'PASS' if ok else 'FAIL'} {name}: {detail}")
print(json.dumps({
    "checks": len(checks),
    "passed": passed,
    "failed": failed,
    "verdict": "GO_CONTRACT_ONLY_NO_GO_FORMAL" if failed == 0 else "NO_GO_CONTRACT_ONLY",
    "julia_invoked": False,
    "desc_invoked": False,
    "current_inputs": current,
}, ensure_ascii=False, indent=2))
raise SystemExit(0 if failed == 0 else 1)
