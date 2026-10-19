#!/usr/bin/env python3
"""Independent Python-only attempt9c postrun receipt verifier; never launches Julia."""
import argparse, copy, hashlib, json, sys
from pathlib import Path, PureWindowsPath

BASE = Path("docs/implementation/UP1-04A-VNEXT-T2")
PROTOCOL = BASE / "archive/r2_protocol_freeze_20260923_t2_protocol_attempt9c_final/protocol.json"
COVERAGE = BASE / "archive/r2_protocol_freeze_20260923_t2_protocol_attempt9c_final/coverage_map_r3.json"
RUN = BASE / "formal_t2_actual_negative_r4_attempt9c_final"
OBSERVATION = BASE / "archive/root_attempt9c_final_dispatch_grant_20260923/observation.json"
PROTO_SHA = "c8c258a73e824824734578b440906c6db69394c33c78ad216917f70efe3dc708"
MAP_SHA = "59442e71116459b9de143d8edcfe451a6c1fbf8ad09187b89ba5fdd3b1a3af27"
DRIVER = "test/GenomeV5/Integration/VNextT2FormalIndependentR1/actual_formal_negative_driver_r3.jl"
SUMMARY_SCHEMA = "vnext-t2-source-site-hit-receipt-r1"
EMPTY_SHA = hashlib.sha256(b"").hexdigest()
checks, negatives = [], []

def sha(b): return hashlib.sha256(b).hexdigest()
def load(p): return json.loads(p.read_text(encoding="utf-8"))
def need(cond, name, detail=None):
    if not cond: raise AssertionError(f"{name}: {detail!r}")
    checks.append({"name": name, "status": "pass", "detail": detail})
def reject(name, fn):
    try: fn()
    except (AssertionError, KeyError, ValueError, TypeError): negatives.append({"name": name, "status": "rejected"})
    else: raise AssertionError(f"negative control accepted: {name}")
def normalized_pins(root, pins):
    out = {}
    for key, pin in pins.items():
        p = str(pin["path"])
        if PureWindowsPath(p).is_absolute() or Path(p).is_absolute():
            p = Path(p).resolve().relative_to(root.resolve()).as_posix()
        else: p = p.replace("\\", "/")
        need(p == key.replace("\\", "/"), "input path canonicalization", {"key": key, "path": p})
        out[p] = (int(pin["bytes"]), pin["sha256"])
    return out
def verify_stream(phase, name, data):
    pin = phase[name]
    need(len(data) == pin["bytes"], phase["name"] + " " + name + " bytes", len(data))
    need(sha(data) == pin["sha256"], phase["name"] + " " + name + " SHA", sha(data))
def verify_timeout(phase, final, timeout, rss_limit):
    need(phase["name"] == "actual_formal_authority", "authority identity", phase["name"])
    need(phase["stop_reason"] == "phase_wall_timeout" and phase["exit_code"] == 15, "authority timeout marker", [phase["stop_reason"], phase["exit_code"]])
    need(phase["seconds"] >= timeout and phase["seconds"] < timeout + 2, "authority wall bound", phase["seconds"])
    need(phase["timeout_seconds"] == timeout, "authority declared timeout", phase["timeout_seconds"])
    need(phase["peak_process_tree_working_set_bytes"] < rss_limit, "authority RSS bound", phase["peak_process_tree_working_set_bytes"])
    need(phase["residual_heavy_processes"] == [], "authority no residual process", phase["residual_heavy_processes"])
    need(final["formal_t2_accepted"] is False and final["status"] == "fail", "run remains unaccepted", [final["status"], final["formal_t2_accepted"]])
    need(final["assertion_site_hit_count_observed"] is None and final["assertion_site_runtime_hits_observed"] is None and final["assertion_site_hit_aggregate"] is None, "no aggregate credited", None)
    need(final["failure"]["type"] == "RuntimeError" and "phase_wall_timeout" in final["failure"]["message"], "controller reports timeout interruption", final["failure"]["message"])
    return "resource_interruption"

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo-root", type=Path, required=True)
    ap.add_argument("--evidence-dir", type=Path, required=True)
    a = ap.parse_args()
    root = a.repo_root.resolve()
    dest = a.evidence_dir if a.evidence_dir.is_absolute() else root / a.evidence_dir
    dest = dest.resolve()
    if dest.exists() and any(dest.iterdir()): raise SystemExit("evidence leaf is nonempty: " + str(dest))
    dest.mkdir(parents=True, exist_ok=True)

    pbytes, mbytes = (root / PROTOCOL).read_bytes(), (root / COVERAGE).read_bytes()
    sbytes, fbytes = (root / RUN / "pipeline_start.json").read_bytes(), (root / RUN / "pipeline_final.json").read_bytes()
    protocol, coverage = json.loads(pbytes), json.loads(mbytes)
    start, final, observation = json.loads(sbytes), json.loads(fbytes), load(root / OBSERVATION)
    need(sha(pbytes) == PROTO_SHA, "frozen protocol SHA", sha(pbytes))
    need(sha(mbytes) == MAP_SHA == protocol["coverage_map"]["sha256"], "frozen coverage map SHA", sha(mbytes))
    need(start["protocol"]["sha256"] == PROTO_SHA, "pipeline protocol pin", start["protocol"])
    need(sha(sbytes) == observation["pipeline_start_sha256"] and sha(fbytes) == observation["pipeline_final_sha256"], "root pipeline hashes", [sha(sbytes), sha(fbytes)])
    need(observation["controller_shell_exit_code"] == 1 and observation["classification"] == "resource_interruption" and observation["formal_t2_accepted"] is False, "root terminal classification", observation["classification"])
    need(protocol["input_count"] == 296, "protocol input count", protocol["input_count"])
    p, sb = normalized_pins(root, protocol["inputs"]), normalized_pins(root, start["inputs_before"])
    fb, fa = normalized_pins(root, final["inputs_before"]), normalized_pins(root, final["inputs_after"])
    need(len(p) == 296 and p == sb == fb == fa, "296 protocol/start/final pins unchanged", len(p))
    need(start["repository_head"] == final["repository_head_before"] == final["repository_head_after"], "repository HEAD unchanged", start["repository_head"])

    expected_order = protocol["phase_order"]
    phases = final["phases"]
    names = [x["name"] for x in phases]
    need(start["expected_phase_order"] == expected_order, "pipeline order matches frozen order", len(expected_order))
    need(names == expected_order[:len(names)] == ["parse_gate","coverage_ast_inventory","projection24_cross_run_validation","actual_formal_baseline","actual_formal_preflight","actual_formal_authority"], "observed phase prefix", names)
    remaining = expected_order[len(names):]
    need(len(expected_order) == 30 and len(remaining) == 24, "24 later phases not executed", remaining)
    need(all(not (root / RUN / n).exists() for n in remaining), "no later phase directories", remaining)

    gates = protocol["resource_gates"]
    timeout, rss_limit = int(gates["phase_wall_seconds"]), int(gates["process_tree_working_set_bytes"])
    need(timeout == 480 and rss_limit == 2147483648 and gates["julia_threads"] == 1 and gates["openblas_threads"] == 1, "frozen resource gates", gates)
    by_name = {x["name"]: x for x in phases}
    root_rows = {x["name"]: x for x in observation["phases"]}
    phase_receipts, raw_info = {}, {}
    for name in names:
        path = root / RUN / name
        receipt_bytes = (path / "phase.json").read_bytes()
        receipt = json.loads(receipt_bytes)
        need(receipt == by_name[name], name + " phase receipt equality", sha(receipt_bytes))
        phase_receipts[name] = receipt
        stdout, stderr = (path / "stdout.raw").read_bytes(), (path / "stderr.raw").read_bytes()
        verify_stream(receipt, "stdout", stdout); verify_stream(receipt, "stderr", stderr)
        if name in root_rows:
            row = root_rows[name]
            need(sha(receipt_bytes) == row["phase_receipt_sha256"] and sha(stdout) == row["stdout_sha256"] and sha(stderr) == row["stderr_sha256"], name + " root raw/phase hashes", row)
        if name in ("actual_formal_baseline","actual_formal_preflight","actual_formal_authority"):
            sample = (path / "samples.jsonl").read_bytes()
            rows = [json.loads(line) for line in sample.splitlines() if line.strip()]
            need(bool(rows), name + " JSONL samples parse", len(rows))
            raw_info[name] = {
                "phase_json": {"bytes":len(receipt_bytes),"sha256":sha(receipt_bytes)},
                "stdout": {"bytes":len(stdout),"sha256":sha(stdout)},
                "stderr": {"bytes":len(stderr),"sha256":sha(stderr)},
                "samples_jsonl": {"bytes":len(sample),"sha256":sha(sample),"json_rows":len(rows),"binding":"tester-computed; phase.json does not declare samples hash"},
                "exit_code":receipt["exit_code"],"stop_reason":receipt["stop_reason"],"seconds":receipt["seconds"],
                "peak_rss_bytes":receipt["peak_process_tree_working_set_bytes"],
            }
    for name in ("parse_gate","coverage_ast_inventory","projection24_cross_run_validation","actual_formal_baseline","actual_formal_preflight"):
        r = phase_receipts[name]
        need(r["stop_reason"] == "natural_exit" and r["exit_code"] == 0, name + " natural exit", [r["stop_reason"],r["exit_code"]])
    for name in ("actual_formal_baseline","actual_formal_preflight"):
        r = phase_receipts[name]
        need(r["seconds"] < timeout and r["peak_process_tree_working_set_bytes"] < rss_limit and r["residual_heavy_processes"] == [], name + " within wall/RSS and cleanup", [r["seconds"],r["peak_process_tree_working_set_bytes"]])

    sites = coverage["successor_assertion_sites"]
    driver_sites = [x for x in sites if x["path"] == DRIVER]
    source_pin = next(x for x in coverage["ast_inventory_plan"]["sources"] if x["path"] == DRIVER)
    hit_plan = coverage["successor_assertion_runtime_hit_plan"]
    need(len(sites) == 214 and len(driver_sites) == 175, "site inventory 214/175 driver", [len(sites),len(driver_sites)])
    need(hit_plan["assertion_site_count"] == 214 and hit_plan["expected_runtime_hit_count"] == 622, "planned 214 IDs/622 hits", [hit_plan["assertion_site_count"],hit_plan["expected_runtime_hit_count"]])
    need(sum(sum(v.values()) for v in hit_plan["phase_site_hit_counts"].values()) == 622, "phase plan sums to 622", {k:sum(v.values()) for k,v in hit_plan["phase_site_hit_counts"].items()})

    summaries, totals = [], {}
    for name in ("actual_formal_baseline","actual_formal_preflight"):
        sp = root / RUN / name / "artifacts/summary.json"
        summary = load(sp)
        observed = summary["assertion_site_hit_counts"]
        expected = {x["id"]:int(x.get("expected_phase_hits",{}).get(name,0)) for x in driver_sites}
        need(summary["assertion_site_hit_receipt_schema"] == SUMMARY_SCHEMA and summary["assertion_site_hit_phase"] == name, name + " hit receipt schema/phase", [summary["assertion_site_hit_receipt_schema"],summary["assertion_site_hit_phase"]])
        need(summary["assertion_site_hit_coverage_map_sha256"] == MAP_SHA and summary["assertion_site_hit_source_sha256"] == source_pin["sha256"], name + " map/source SHA pins", [summary["assertion_site_hit_coverage_map_sha256"],summary["assertion_site_hit_source_sha256"]])
        need(summary["assertion_site_hit_source_path"].replace("\\","/").endswith(DRIVER), name + " driver path pin", summary["assertion_site_hit_source_path"])
        need(summary["unmapped_assertion_sources"] == [], name + " unmapped sources empty", summary["unmapped_assertion_sources"])
        need(set(observed) == set(expected) and observed == expected, name + " complete per-site map equals plan", {"sites":len(observed),"actual":sum(observed.values()),"planned":sum(expected.values())})
        total = sum(observed.values())
        need(summary["assertion_site_hit_count_observed"] == total, name + " observed sum", total)
        totals[name] = total; summaries.append(summary)
        raw_info[name]["summary"] = {"path":sp.relative_to(root).as_posix(),"bytes":sp.stat().st_size,"sha256":sha(sp.read_bytes()),"observed_site_hits":total,"completed":True}
    need(final["assertion_site_hit_phase_summaries"] == summaries, "pipeline includes exactly completed summaries", [x["assertion_site_hit_phase"] for x in final["assertion_site_hit_phase_summaries"]])
    need(totals == {"actual_formal_baseline":53,"actual_formal_preflight":203} and sum(totals.values()) == 256, "completed partial site hit evidence", totals)

    authority = phase_receipts["actual_formal_authority"]
    classification = verify_timeout(authority, final, timeout, rss_limit)
    apath = root / RUN / "actual_formal_authority"
    need(not (apath / "artifacts/summary.json").exists(), "authority summary absent", False)
    need([x["assertion_site_hit_phase"] for x in final["assertion_site_hit_phase_summaries"]] == ["actual_formal_baseline","actual_formal_preflight"], "only complete phases contribute site hits", None)
    obsraw = (apath / "artifacts/observations.jsonl").read_bytes()
    observations = [json.loads(line) for line in obsraw.splitlines() if line.strip()]
    need(len(observations) == 1 and observations[0].get("case_id") == "PARENT_STALE" and observations[0].get("status") == "fail_closed" and observations[0].get("committed") is False, "partial authority observation is incomplete", observations)
    trace = (apath / "artifacts/stage_trace.tsv").read_bytes()
    last_marker = next((line.split("\t",1)[0].strip() for line in reversed(trace.decode("utf-8",errors="replace").splitlines()) if line.strip()), "")
    need(last_marker == "attack_group_authority.begin", "authority trace has no completion marker", last_marker)
    authout = (apath / "stdout.raw").read_bytes().decode("utf-8",errors="replace")
    failure_markers = [x for x in ("Test Failed","Error During Test","AssertionError","ERROR:") if x.lower() in authout.lower()]
    need(not failure_markers, "no explicit assertion failure marker in partial stdout", failure_markers)
    raw_info["actual_formal_authority"].update({
        "completed_summary_present":False,
        "site_hits_completed":False,
        "partial_observations":{"bytes":len(obsraw),"sha256":sha(obsraw),"rows":observations},
        "stage_trace":{"bytes":len(trace),"sha256":sha(trace),"last_marker":last_marker},
        "explicit_assertion_failure_markers":failure_markers,
    })

    # Synthetic mutants are in-memory only.
    mutant = copy.deepcopy(authority); mutant["stop_reason"]="natural_exit"; mutant["exit_code"]=0
    reject("timeout rewritten as natural exit",lambda: need(mutant["stop_reason"]=="phase_wall_timeout" and mutant["exit_code"]==15,"mutant timeout",mutant))
    mutant = copy.deepcopy(authority); mutant["stdout"]["sha256"]="0"*64
    reject("stale stdout hash",lambda: verify_stream(mutant,"stdout",(apath/"stdout.raw").read_bytes()))
    reject("stale samples hash",lambda: need(sha((apath/"samples.jsonl").read_bytes())=="0"*64,"mutant sample digest",None))
    mutant = copy.deepcopy(summaries[0]); mutant["assertion_site_hit_counts"].pop(next(iter(mutant["assertion_site_hit_counts"])))
    reject("missing site ID",lambda: need(set(mutant["assertion_site_hit_counts"])=={x["id"] for x in driver_sites},"mutant site domain",None))
    mutant = copy.deepcopy(summaries[1]); sid=next(iter(mutant["assertion_site_hit_counts"])); mutant["assertion_site_hit_counts"][sid]+=1
    reject("wrong site multiplicity",lambda: need(mutant["assertion_site_hit_counts"]=={x["id"]:int(x.get("expected_phase_hits",{}).get("actual_formal_preflight",0)) for x in driver_sites},"mutant count",None))
    reject("phase reorder",lambda: need(["parse_gate","coverage_ast_inventory","actual_formal_baseline"]==expected_order[:3],"mutant order",None))
    reject("fabricated phase after timeout",lambda: need((names+["actual_formal_fault_n10"])[-1]=="actual_formal_authority","mutant post-timeout phase",None))
    need(classification=="resource_interruption","timeout is resource interruption, not assertion failure",classification)

    receipt = {
        "schema":"t2-independent-postrun-timeout-check-r1",
        "result":"pass" if len(negatives)==7 else "fail",
        "classification":classification,
        "formal_t2_accepted":False,
        "julia_started_by_checker":False,
        "scope":"Read-only check of attempt9c phase/raw/sample/site-hit evidence; mutants are in-memory only.",
        "frozen_inputs":{
            "protocol":{"path":PROTOCOL.as_posix(),"bytes":len(pbytes),"sha256":sha(pbytes)},
            "coverage_map":{"path":COVERAGE.as_posix(),"bytes":len(mbytes),"sha256":sha(mbytes)},
            "pipeline_start":{"path":(RUN/"pipeline_start.json").as_posix(),"bytes":len(sbytes),"sha256":sha(sbytes)},
            "pipeline_final":{"path":(RUN/"pipeline_final.json").as_posix(),"bytes":len(fbytes),"sha256":sha(fbytes)},
            "root_observation":{"path":OBSERVATION.as_posix(),"sha256":sha((root/OBSERVATION).read_bytes())},
            "protocol_pin_count":len(p),"input_pins_unchanged":True,"repository_head_unchanged":True,
        },
        "run":{
            "controller_shell_exit_code":observation["controller_shell_exit_code"],
            "expected_phase_count":len(expected_order),"executed_phase_count":len(names),
            "executed_phases":names,"not_executed_phases":remaining,"resource_gates":gates,
            "completed_baseline_preflight_actual_hits":totals,"partial_hit_sum":sum(totals.values()),
            "authority":{"exit_code":authority["exit_code"],"stop_reason":authority["stop_reason"],"seconds":authority["seconds"],"peak_rss_bytes":authority["peak_process_tree_working_set_bytes"],"residual_heavy_processes":authority["residual_heavy_processes"],"classification":classification,"summary_present":False,"actual_site_hits":None,"later_shards_executed":False},
        },
        "site_hit_plan":{"unique_site_ids":hit_plan["assertion_site_count"],"planned_hits":hit_plan["expected_runtime_hit_count"],"driver_ids":len(driver_sites),"per_phase_plan_totals":{k:sum(v.values()) for k,v in hit_plan["phase_site_hit_counts"].items()},"raw_receipts":raw_info},
        "negative_controls":negatives,"checks":checks,
    }
    out=dest/"independent_postrun_timeout_receipt.json"
    out.write_text(json.dumps(receipt,indent=2,sort_keys=True)+"\n",encoding="utf-8")
    argv={"kind":"non_executable_command_data","argv":[sys.executable,"-B",str(Path(__file__).resolve()),"--repo-root",str(root),"--evidence-dir",str(dest)],"exit_code":0 if receipt["result"]=="pass" else 1,"receipt_path":str(out),"receipt_sha256":sha(out.read_bytes())}
    (dest/"command_argv.json").write_text(json.dumps(argv,indent=2,sort_keys=True)+"\n",encoding="utf-8")
    print(f"T2_POSTRUN_TIMEOUT_CHECK={receipt['result'].upper()} checks={len(checks)} negative_controls={len(negatives)} phases={len(names)}/{len(expected_order)}")
    print("receipt="+str(out))
    print("receipt_sha256="+sha(out.read_bytes()))
    return 0 if receipt["result"]=="pass" else 1

if __name__=="__main__":
    try: raise SystemExit(main())
    except Exception as exc:
        print(f"INDEPENDENT_POSTRUN_CHECK=FAIL {type(exc).__name__}: {exc}",file=sys.stderr)
        raise