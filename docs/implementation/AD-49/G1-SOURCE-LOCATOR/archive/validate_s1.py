from __future__ import annotations

import hashlib
import json
import platform
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path.cwd().resolve()
BASE = ROOT / "docs/implementation/AD-49"
G1 = BASE / "G1-SOURCE-LOCATOR"
G2 = BASE / "G2-SOURCE-LOCATOR"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def canonical(value: object) -> bytes:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")


def artifact(path: Path) -> dict:
    data = path.read_bytes()
    return {"path": path.relative_to(ROOT).as_posix(), "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}


def main() -> int:
    started = datetime.now(timezone.utc).isoformat(timespec="microseconds").replace("+00:00", "Z")
    errors: list[str] = []
    expected = {
        "G1": (G1 / "g1_source_locator_v1.json", G1 / "g1_source_locator_receipt.json", "src/GenomeV5/G1/DiffusionDeclarationV1.jl", 31743, "14d26ee556029bd1fcf2477f3dbe9599622d37a3f5704d1c0bb1dd9ea31dbf1a"),
        "G2": (G2 / "g2_source_locator_v1.json", G2 / "g2_source_locator_receipt.json", "src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl", 30773, "261516671151647bccb71f2fefd5f71cd2ed444f5eeba0bf90b29687d3a78f61"),
    }
    products: list[dict] = []
    for layer, (record_path, receipt_path, source_path, source_bytes, source_sha) in expected.items():
        try:
            record_bytes = record_path.read_bytes()
            receipt_bytes = receipt_path.read_bytes()
            record = json.loads(record_bytes)
            receipt = json.loads(receipt_bytes)
        except Exception as exc:
            errors.append(f"{layer}: unreadable product: {exc}")
            continue
        if record_bytes != canonical(record):
            errors.append(f"{layer}: record is not canonical compact JSON")
        if receipt_bytes != canonical(receipt):
            errors.append(f"{layer}: receipt is not canonical compact JSON")
        for token in ("GG1", "GG2"):
            if token in record_path.read_text(encoding="utf-8") or token in receipt_path.read_text(encoding="utf-8"):
                errors.append(f"{layer}: malformed union token {token}")
        if record.get("result") != f"Absent{layer}IndependentSourceLocatorV1":
            errors.append(f"{layer}: result is not typed absence")
        if record.get("record_kind") != f"Absent{layer}IndependentSourceLocatorV1":
            errors.append(f"{layer}: record kind mismatch")
        if record.get("status") != "typed_absent" or record.get("contract_admission") != "terminal_deferred":
            errors.append(f"{layer}: absence closure mismatch")
        snapshot = record.get("source_snapshot", {})
        worktree = snapshot.get("working_tree", {})
        head = snapshot.get("head", {})
        if snapshot.get("path") != source_path or worktree.get("bytes") != source_bytes or worktree.get("sha256") != source_sha:
            errors.append(f"{layer}: live source byte closure mismatch")
        if snapshot.get("observed_head") != "4b69f55f7f80240147a65a22809dc1207824dde2":
            errors.append(f"{layer}: HEAD closure mismatch")
        if head.get("present") is not False or head.get("blob_sha256") is not None or snapshot.get("git", {}).get("ls_files_present") is not False:
            errors.append(f"{layer}: missing HEAD closure not typed absent")
        if record.get("locator") is not None:
            errors.append(f"{layer}: locator must be null on absence")
        for name, control in record.get("negative_controls", {}).items():
            expected_result = f"Absent{layer}IndependentSourceLocatorV1" if name == "tracked_vs_untracked_confusion" else f"Failed{layer}IndependentSourceLocatorV1"
            if control.get("expected_result") != expected_result or control.get("observed_result") != expected_result:
                errors.append(f"{layer}: negative control {name} union mismatch")
        if receipt.get("record") != artifact(record_path):
            errors.append(f"{layer}: receipt record hash mismatch")
        products.extend([artifact(record_path), artifact(receipt_path)])
    result = {
        "schema_version": "AD49-S1-direct-validation-v1",
        "record_kind": "source_locator_direct_validation",
        "task_id": "AD49-S1-INDEPENDENT-G1-G2-SOURCE-LOCATORS",
        "python": sys.executable,
        "python_version": platform.python_version(),
        "pid": __import__("os").getpid(),
        "utc_start": started,
        "utc_end": datetime.now(timezone.utc).isoformat(timespec="microseconds").replace("+00:00", "Z"),
        "exit_code": 0 if not errors else 1,
        "checks": {"products": products, "canonical_json": not errors, "head_absence": not errors, "union_tokens": not errors, "negative_controls": not errors},
        "errors": errors,
        "no_heavy_runtime": True,
        "self_hash_excluded": True,
    }
    destination = G1 / "archive/direct_validation.json"
    destination.write_bytes(canonical(result))
    print(json.dumps(result, ensure_ascii=False, sort_keys=True, separators=(",", ":")))
    return result["exit_code"]


if __name__ == "__main__":
    raise SystemExit(main())
