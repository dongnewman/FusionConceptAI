"""Run one complete independent R26 formal pass in fresh serialized children."""

from __future__ import annotations
from pathlib import Path
import argparse, hashlib, json, subprocess, sys

ROOT = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parent
PROTOCOL = HERE / "protocol_r26_v9.json"
RUNNER = HERE / "run_recorded_r26.py"
MERGER = HERE / "merge_r26.py"
EVIDENCE = ROOT / "docs/implementation/UP1-04A-VNEXT-T1/independent_formal_r26_20260922"

def digest(path: Path) -> tuple[int, str]:
    data = path.read_bytes()
    return len(data), hashlib.sha256(data).hexdigest().upper()

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--run", required=True,
        choices=("primary_r8", "replay_r8"))
    parser.add_argument("--julia", default="julia")
    args = parser.parse_args()
    protocol = json.loads(PROTOCOL.read_text(encoding="utf-8"))
    if protocol["schema"] != "vnext_t1_independent_formal_r26_protocol_v9":
        raise RuntimeError("protocol schema mismatch")
    run_root = EVIDENCE / args.run
    if run_root.exists():
        raise RuntimeError(f"run evidence already exists: {run_root}")
    inputs = [row["path"] for row in protocol["dependencies"]]
    protocol_rel = PROTOCOL.relative_to(ROOT).as_posix()
    if protocol_rel in inputs:
        raise RuntimeError("self-referential protocol dependency")
    common = [sys.executable, str(RUNNER), "--owner", "independent_formal_r26",
        "--timeout", str(protocol["resources"]["fresh_process_wall_seconds"]),
        "--max-rss-bytes", str(protocol["resources"]["process_tree_rss_bytes"])]
    for rel in inputs + [protocol_rel]:
        common += ["--input", rel]
    julia_common = [args.julia, "--project=.", "--startup-file=no",
        "--history-file=no"]
    stages: list[tuple[str, list[str]]] = []
    v1 = HERE / "v1_shard_r26.jl"
    for shard in protocol["v1"]["shards"]:
        name = "v1_" + shard["name"]
        ledger = (Path("docs/implementation/UP1-04A-VNEXT-T1/independent_formal_r26_20260922") /
            args.run / name / "ledger.json").as_posix()
        stages.append((name, julia_common + [str(v1), "--shard", shard["name"],
            "--ledger", ledger]))
    for name, script in (("v2_formal", HERE / "v2_formal_r26.jl"),
            ("binding_formal", HERE / "binding_missing_wire_formal_r26.jl")):
        ledger = (Path("docs/implementation/UP1-04A-VNEXT-T1/independent_formal_r26_20260922") /
            args.run / name / "ledger.json").as_posix()
        stages.append((name, julia_common + [str(script), "--ledger", ledger]))

    for name, child in stages:
        out = (Path("docs/implementation/UP1-04A-VNEXT-T1/independent_formal_r26_20260922") /
            args.run / name).as_posix()
        command = common + ["--out", out, "--env", "JULIA_NUM_THREADS=1", "--"] + child
        print("R26_CONTROLLER_COMMAND=" + json.dumps(command), flush=True)
        completed = subprocess.run(command, cwd=ROOT)
        if completed.returncode != 0:
            print(f"R26_CONTROLLER_STOP stage={name} exit={completed.returncode}", flush=True)
            return completed.returncode

    merge_command = [sys.executable, str(MERGER), "--mode", "single",
        "--run", args.run]
    print("R26_CONTROLLER_MERGE=" + json.dumps(merge_command), flush=True)
    return subprocess.run(merge_command, cwd=ROOT).returncode

if __name__ == "__main__":
    raise SystemExit(main())
