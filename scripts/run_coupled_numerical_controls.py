"""Root-owned adapter to the existing bounded Windows Job supervisor."""
import argparse
import hashlib
import importlib.util
import json
import os
import sys
import time
from pathlib import Path

import psutil

REPO = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--output-dir", required=True, type=Path)
args = parser.parse_args()
LEAF = (REPO / args.output_dir).resolve()
LEAF.relative_to((REPO / "runs/InHouseCoupledMHDGlobalSolveV1").resolve())
assert not LEAF.exists(), "preserve prior output"
EXPECTED = {
    "test/RuntimeV4/InHouseG1G2Q1SolverV1/run_serial_acceptance.py": "17c3701bc565fdc54ec0bd324e2bb65d7ee77e91c8d78fd4b6a0231b22ca12f2",
    "src/RuntimeV4/InHouseCoupledMHDGlobalSolveV1.jl": "7c079ca943e869c7b8ef29a9b1084c3234730e25ff4849b524c22276ef8617c3",
    "test/RuntimeV4/InHouseCoupledMHDGlobalSolveV1/coupled_global_fd_oracle_v1.jl": "b2ea7901c559c431061aed17823785bdca6ad86ac464a497fce8b245ff768d8d",
    "test/RuntimeV4/InHouseCoupledMHDGlobalSolveV1/focused_numerical_control_v1.jl": "d5f1ec9ebde626e7b020fe1f83e1b1c34eb93b00b1d5d09bcc35192d69e789a0",
    "src/RuntimeV4/MultiTopologyNonlinearSolveV1.jl": "30db4c5a92c09765fb560f7f1663108394ed5fa83b9649ae02aea5ee3f86cf3b",
    "Project.toml": "fc3b84c18a5703335b8701b4f1bf10f3cde866db135492f0061de2b888799857",
    "Manifest.toml": "133de98e7862bf4486ed39a6f72a14c6a17bf2faf5622f3561f9e907badab91d",
}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path, value):
    with path.open("x", encoding="utf-8", newline="\n") as stream:
        stream.write(json.dumps(value, ensure_ascii=False, indent=2) + "\n")


def source_pins():
    paths = {REPO / name for name in EXPECTED}
    paths.add(Path(__file__).resolve())
    paths.update((REPO / "src").rglob("*.jl"))
    result = {p.relative_to(REPO).as_posix(): {"bytes": p.stat().st_size, "sha256": digest(p)}
              for p in sorted(paths)}
    for name, sha in EXPECTED.items():
        if result[name]["sha256"] != sha:
            raise RuntimeError(f"frozen source drift: {name}")
    return result


assert os.name == "nt"
assert not (LEAF / "summary.json").exists(), "actual output already exists"
active = [{"pid": p.pid, "name": p.info["name"], "cmdline": p.info["cmdline"]}
          for p in psutil.process_iter(["name", "cmdline"])
          if (p.info["name"] or "").lower() in
          ("julia.exe", "julia-debug.exe", "desc.exe", "freegs.exe", "gmsh.exe", "mesh.exe")]
assert not active, active
pins = source_pins()
LEAF.mkdir(parents=True, exist_ok=False)
write(LEAF / "source_pins_before.json", pins)
write(LEAF / "outer_command_argv.json", psutil.Process().cmdline())
spec = importlib.util.spec_from_file_location("root_coupled_control_supervisor", REPO / next(iter(EXPECTED)))
sv = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = sv
spec.loader.exec_module(sv)
assert sv.RSS_LIMIT_BYTES == 2147483648 and sv.POLL_SECONDS == 0.25
assert sv.TOTAL_WALL_TIMEOUT_SECONDS == 240 and sv.JULIA_TIMEOUT_SECONDS == 240
exe = Path(r"C:\Users\Newman\AppData\Local\Programs\Julia-1.10.5\bin\julia.exe")
assert exe.is_file()
executable_before = {"path": str(exe), "bytes": exe.stat().st_size, "sha256": digest(exe)}
assert executable_before["sha256"] == "8e86e2d48c574393c37bbfb6e922ea4176ba8e1a83f956826f3da24948e389ad"
write(LEAF / "julia_executable_pin.json", executable_before)
for name in ("JULIA_NUM_THREADS", "OPENBLAS_NUM_THREADS", "OMP_NUM_THREADS", "MKL_NUM_THREADS"):
    os.environ[name] = "1"
script = REPO / "test/RuntimeV4/InHouseCoupledMHDGlobalSolveV1/focused_numerical_control_v1.jl"
producer = LEAF / "producer" / "observation.json"
replay = LEAF / "fresh_replay" / "observation.json"
cases = [("producer", ["produce", str(producer)], producer, "control=pass"),
         ("fresh_replay", ["replay", str(producer), str(replay)], replay, "fresh_process_replay=exact_bytes")]
results = []
total_started = time.monotonic()
deadline = total_started + 240.0
for name, arguments, artifact, marker in cases:
    assert source_pins() == pins, "source closure changed before dispatch"
    case = LEAF / name
    case.mkdir(exist_ok=False)
    argv = [str(exe), "--startup-file=no", "--history-file=no", "--compile=min",
            "--threads=1", "--heap-size-hint=1G", "--project=.", str(script), *arguments]
    write(case / "command_argv.json", argv)
    receipt = {"schema": "root-coupled-global-software-control-actual-r1", "owner": "/root",
               "preparation": True, "test_only": True, "physical_validation": False,
               "engineering_validation": False, "grants_pass": False,
               "claim_ceiling": "numerical_mechanism_only", "argv": argv,
               "shared_wall_limit_seconds": 240, "job_memory_limit_bytes": 2147483648,
               "process_tree_rss_limit_bytes": 2147483648, "sample_seconds": 0.25,
               "stop_reason": None, "rss_accounting_incomplete": False,
               "peak_sampled_tree_rss_bytes": 0, "peak_job_commit_bytes": 0}
    started = time.monotonic()
    rc, failure = None, None
    job = sv.WindowsJob(2147483648)
    try:
        rc = sv._run_in_job(argv, REPO, case / "stdout.raw", case / "stderr.raw",
                            case / "process_tree_audit.jsonl", job, receipt, "julia", 240, deadline)
        receipt["actual_child_os_exit_code"] = rc
        receipt["job_active_processes_after_run"] = job.active_processes()
        sv._require_no_pending_process_sample_handles(receipt, "root_coupled_post_control")
    except BaseException as error:
        failure = repr(error)
        receipt["exception"] = failure
        if job.active_processes():
            job.terminate(94)
        receipt["job_active_processes_after_failure"] = job.active_processes()
    finally:
        job.close()
    post = source_pins()
    receipt["wall_seconds"] = time.monotonic() - started
    receipt["executable_pin_unchanged"] = digest(exe) == executable_before["sha256"]
    receipt["executable"] = executable_before
    receipt["source_pins_unchanged"] = post == pins
    receipt["raw_files"] = {p.name: {"bytes": p.stat().st_size, "sha256": digest(p)}
                            for p in case.iterdir() if p.is_file()}
    out = (case / "stdout.raw").read_text(encoding="utf-8", errors="replace")
    err = (case / "stderr.raw").read_bytes()
    passed = (rc == 0 and failure is None and receipt["stop_reason"] is None and
              not receipt["rss_accounting_incomplete"] and
              receipt.get("job_active_processes_after_run") == 0 and marker in out and
              not err and post == pins and artifact.is_file() and receipt["executable_pin_unchanged"])
    if name == "fresh_replay":
        passed = passed and artifact.read_bytes() == producer.read_bytes()
    receipt["status"] = "pass_software_control_only" if passed else "fail"
    write(case / "receipt.json", receipt)
    row = {"name": name, "status": receipt["status"], "actual_child_os_exit_code": rc,
           "stop_reason": receipt["stop_reason"], "wall_seconds": receipt["wall_seconds"],
           "peak_job_commit_bytes": receipt["peak_job_commit_bytes"],
           "peak_sampled_tree_rss_bytes": receipt["peak_sampled_tree_rss_bytes"],
           "active_after": receipt.get("job_active_processes_after_run"),
           "receipt_sha256": digest(case / "receipt.json")}
    results.append(row)
    print(json.dumps(row), flush=True)
    if not passed:
        break
post = source_pins()
write(LEAF / "source_pins_after.json", post)
summary = {"schema": "root-coupled-global-software-control-summary-r1", "owner": "/root",
           "status": "pass_two_fresh_processes_test_only" if len(results) == 2 and
           all(r["status"] == "pass_software_control_only" for r in results) else "fail",
           "preparation": True, "test_only": True, "physical_validation": False,
           "engineering_validation": False, "grants_pass": False,
           "claim_ceiling": "numerical_mechanism_only", "results": results,
           "not_executed": [c[0] for c in cases[len(results):]], "source_pin_count": len(pins),
           "source_pins_unchanged": post == pins, "shared_wall_seconds": time.monotonic() - total_started}
write(LEAF / "summary.json", summary)
files = {p.relative_to(LEAF).as_posix(): {"bytes": p.stat().st_size, "sha256": digest(p)}
         for p in LEAF.rglob("*") if p.is_file() and p.name != "manifest.json" and p not in (LEAF / "outer_stdout.raw", LEAF / "outer_stderr.raw")}
write(LEAF / "manifest.json", {"schema": "root-coupled-control-actual-manifest-r1", "files": files})
print(json.dumps(summary), flush=True)
sys.exit(0 if summary["status"] == "pass_two_fresh_processes_test_only" else 1)
