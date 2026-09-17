"""Run the W4 validator once and seal raw/process/hash evidence."""
from __future__ import annotations

import hashlib
import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parents[1]
REPO = HERE.parents[3]


def utc() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def digest_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def digest(path: Path) -> str:
    return digest_bytes(path.read_bytes())


def write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def all_files() -> list[str]:
    return sorted(path.relative_to(HERE).as_posix() for path in HERE.rglob("*") if path.is_file())


def seal() -> None:
    manifest_path = HERE / "manifest.json"
    cleanup_path = HERE / "cleanup_inventory.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    files = all_files()
    manifest["files"] = files
    manifest["exact_file_set"] = True
    manifest["self_hash_exclusions"] = ["manifest.json", "cleanup_inventory.json"]
    manifest["artifact_hashes"] = {
        name: digest(HERE / name)
        for name in files
        if name not in {"manifest.json", "cleanup_inventory.json"}
    }
    manifest["status"] = "repair_r2_validated"
    write_json(manifest_path, manifest)
    cleanup = {
        "schema": "UP1.W4.local-input-discovery.cleanup-inventory.v2",
        "claim": "discovery_only/preparation_only",
        "repo_root": str(REPO).replace("\\", "/"),
        "owned_root": str(HERE).replace("\\", "/"),
        "final_exact_owned_set": files,
        "self_hash_exclusions": ["manifest.json", "cleanup_inventory.json"],
        "records": [
            {
                "path": name,
                "exists": True,
                "bytes": (HERE / name).stat().st_size,
                "sha256": digest(HERE / name),
                "retention": "retain_as_evidence",
            }
            for name in files
            if name not in {"manifest.json", "cleanup_inventory.json"}
        ],
        "no_unowned_temp_files": True,
        "cleanup_performed": False,
        "note": "All owned artifacts are retained; no temporary deletion was authorized. Self hashes are explicitly excluded.",
    }
    write_json(cleanup_path, cleanup)
    # Manifest is written last so its hash map includes the final cleanup size only by explicit exclusion.
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    manifest["files"] = all_files()
    manifest["artifact_hashes"] = {
        name: digest(HERE / name)
        for name in manifest["files"]
        if name not in {"manifest.json", "cleanup_inventory.json"}
    }
    write_json(manifest_path, manifest)


def main() -> int:
    command = [sys.executable, "-B", "static_discovery_validator.py"]
    start = utc()
    child = subprocess.Popen(command, cwd=HERE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    stdout, stderr = child.communicate()
    end = utc()
    raw_dir = HERE / "repair_r2/raw"
    raw_dir.mkdir(parents=True, exist_ok=True)
    (raw_dir / "static_discovery_validator.stdout.raw").write_bytes(stdout)
    (raw_dir / "static_discovery_validator.stderr.raw").write_bytes(stderr)
    (raw_dir / "static_discovery_validator.combined.raw").write_bytes(stdout + b"\n--- STDERR ---\n" + stderr)
    ledger_path = HERE / "run_ledger.json"
    ledger = json.loads(ledger_path.read_text(encoding="utf-8"))
    command_record = next(item for item in ledger["commands"] if item["id"] == "W4-STATIC-VALIDATOR-R2")
    command_record.update({
        "status": "completed",
        "pid": child.pid,
        "start_utc": start,
        "end_utc": end,
        "exit_code": child.returncode,
        "raw_stdout_sha256": digest(raw_dir / "static_discovery_validator.stdout.raw"),
        "raw_stderr_sha256": digest(raw_dir / "static_discovery_validator.stderr.raw"),
        "combined_raw_sha256": digest(raw_dir / "static_discovery_validator.combined.raw"),
    })
    ledger["status"] = "validator_complete" if child.returncode == 0 else "validator_failed"
    write_json(ledger_path, ledger)
    receipt_path = HERE / "validation_receipt.json"
    receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
    parsed = None
    try:
        parsed = json.loads(stdout.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError):
        pass
    receipt["status"] = "pass" if child.returncode == 0 else "fail"
    receipt["validator"] = {
        "status": "completed",
        "command": "python -B static_discovery_validator.py",
        "pid": child.pid,
        "start_utc": start,
        "end_utc": end,
        "exit_code": child.returncode,
        "raw_stdout": "repair_r2/raw/static_discovery_validator.stdout.raw",
        "raw_stderr": "repair_r2/raw/static_discovery_validator.stderr.raw",
        "combined_raw": "repair_r2/raw/static_discovery_validator.combined.raw",
        "raw_stdout_sha256": digest(raw_dir / "static_discovery_validator.stdout.raw"),
        "raw_stderr_sha256": digest(raw_dir / "static_discovery_validator.stderr.raw"),
        "combined_raw_sha256": digest(raw_dir / "static_discovery_validator.combined.raw"),
        "result": parsed,
    }
    receipt["failures"] = [] if child.returncode == 0 and parsed else (parsed or {"raw_parse": "failed"})
    write_json(receipt_path, receipt)
    seal()
    sys.stdout.buffer.write(stdout)
    sys.stderr.buffer.write(stderr)
    return child.returncode


if __name__ == "__main__":
    raise SystemExit(main())
