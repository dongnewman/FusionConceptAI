import datetime as dt
import hashlib
import json
import os
import shutil
import subprocess
from pathlib import Path

S3 = Path(__file__).resolve().parent
ROOT = S3.parents[3]
RAW = S3 / "archive" / "raw"
STAGING = S3 / "archive" / "generator_staging_v4"
BACKUPS = S3 / "archive" / "atomic_backups_v4"
GENERATOR = S3 / "generate_absence.py"
FILES = (
    "G1/g1_trusted_source_identity_v1.json",
    "G1/g1_trusted_source_identity_receipt.json",
    "G2/g2_trusted_source_identity_v1.json",
    "G2/g2_trusted_source_identity_receipt.json",
)
DEST_ROOT = ROOT / "docs" / "implementation" / "AD-49"
DEST_DIRS = {
    "G1": DEST_ROOT / "G1-TRUSTED-SOURCE-IDENTITY",
    "G2": DEST_ROOT / "G2-TRUSTED-SOURCE-IDENTITY",
}

def now():
    return dt.datetime.now(dt.timezone.utc).isoformat().replace("+00:00", "Z")

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    if STAGING.exists():
        shutil.rmtree(STAGING)
    if BACKUPS.exists():
        shutil.rmtree(BACKUPS)
    RAW.mkdir(parents=True, exist_ok=True)
    STAGING.mkdir(parents=True)
    BACKUPS.mkdir(parents=True)
    runs = []
    for attempt in (1, 2):
        out = STAGING / f"replay_{attempt}"
        out.mkdir()
        stdout = RAW / f"replay_{attempt}_v4_stdout.txt"
        stderr = RAW / f"replay_{attempt}_v4_stderr.txt"
        started = now()
        with stdout.open("w", encoding="utf-8", newline="") as so, stderr.open("w", encoding="utf-8", newline="") as se:
            proc = subprocess.Popen(["python", str(GENERATOR), str(out)], cwd=ROOT, stdout=so, stderr=se)
            pid = proc.pid
            code = proc.wait()
        rec = {"attempt": attempt, "pid": pid, "started_utc": started, "finished_utc": now(), "exit_code": code,
               "stdout": str(stdout), "stderr": str(stderr), "output_dir": str(out)}
        (RAW / f"replay_{attempt}_v4_process.json").write_text(json.dumps(rec, indent=2) + "\n", encoding="utf-8")
        runs.append(rec)
        if code != 0:
            raise SystemExit(code)
    compare = []
    for rel in FILES:
        a = sha(STAGING / "replay_1" / rel)
        b = sha(STAGING / "replay_2" / rel)
        compare.append({"file": rel, "replay_1_sha256": a, "replay_2_sha256": b, "byte_identical": a == b})
    (RAW / "replay_v4_compare.json").write_text(json.dumps(compare, indent=2) + "\n", encoding="utf-8")
    published = []
    for rel in FILES:
        src = STAGING / "replay_1" / rel
        layer = rel.split("/", 1)[0]
        dest = DEST_DIRS[layer] / rel.split("/", 1)[1]
        backup = BACKUPS / (rel.replace("/", "_") + ".bak")
        os.replace(dest, backup)
        os.replace(src, dest)
        published.append({"file": rel, "source": str(src), "destination": str(dest), "backup": str(backup), "atomic_replace": True})
    (RAW / "atomic_publish_v4.json").write_text(json.dumps(published, indent=2) + "\n", encoding="utf-8")
    shutil.rmtree(STAGING)
    for backup in BACKUPS.iterdir():
        backup.unlink()
    BACKUPS.rmdir()
    print(json.dumps({"runs": runs, "compare": compare, "published": published,
                      "staging_removed": not STAGING.exists(), "backup_removed": not BACKUPS.exists()}, indent=2))

if __name__ == "__main__":
    main()
