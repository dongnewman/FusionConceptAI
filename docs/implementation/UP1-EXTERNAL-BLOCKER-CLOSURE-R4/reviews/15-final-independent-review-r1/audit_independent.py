"""Small, offline, independent R4 final-review probes.

Writes only sibling raw evidence; never writes tools/ or tests.
"""
from __future__ import annotations
import ast, hashlib, json, os, sys, tempfile, traceback
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[4]  # FusionConceptAI checkout
RAW = HERE / "raw"
RAW.mkdir(parents=True, exist_ok=True)
sys.path.insert(0, str(REPO))

def sha(b: bytes) -> str: return hashlib.sha256(b).hexdigest()
def dump(name: str, obj):
    raw = json.dumps(obj, ensure_ascii=False, sort_keys=True, indent=2, default=str).encode()
    (RAW / name).write_bytes(raw)
    (RAW / (name + ".sha256")).write_text(sha(raw) + "  " + name + "\n", encoding="utf-8")

def main():
    out = {"utc_observation_note": "runtime timestamps are in child receipts; offline only"}
    impl = REPO / "tools" / "up1_external_closure_r4"
    # Frozen production source hashes and manifest verification.
    files = {}
    for p in sorted(impl.rglob("*.py")):
        if "__pycache__" in p.parts: continue
        b = p.read_bytes(); files[str(p.relative_to(REPO)).replace("\\", "/")] = {"bytes": len(b), "sha256": sha(b)}
    out["production_hashes"] = files
    mf = REPO / "docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R4/02-integration-contract/file-hash-manifest.json"
    manifest = json.loads(mf.read_text(encoding="utf-8"))
    out["manifest_check"] = [{"path": x["path"], "manifest_sha256": x["sha256"], "actual": files.get(x["path"], {}).get("sha256"), "match": files.get(x["path"], {}).get("sha256") == x["sha256"]} for x in manifest["files"] if x["path"].startswith("tools/")]
    # Frozen external absence state.
    inv = json.loads((REPO / "docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R4/00-external-delta-scan/external_material_inventory.json").read_text(encoding="utf-8"))
    scan = (REPO / "docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R4/00-external-delta-scan/scan_summary.md").read_text(encoding="utf-8")
    out["external_state"] = {"count": inv.get("count"), "typed_absent_count": inv.get("typed_absent_count"), "usable_count": inv.get("usable_count"), "scan_has_no_fresh_delta": "no fresh external response material" in scan, "new_ad_false": ("new_ad=false" in scan.lower() or "new-ad=false" in scan.lower()), "s3_rerun_false": "s3_rerun=false" in scan.lower(), "r22_direct_wire_limit": "R22 remains" in (HERE.parent.parent / "reviews/06-predicate-independent-review-r1/report.md").read_text(encoding="utf-8")}
    # Static production dispatch/order and known environment path behavior.
    orchp = impl / "integration/orchestrator.py"
    tree = ast.parse(orchp.read_text(encoding="utf-8"))
    order = None
    for n in ast.walk(tree):
        if isinstance(n, ast.Assign) and any(isinstance(t, ast.Name) and t.id == "STAGE_ORDER" for t in n.targets):
            order = [e.value for e in n.value.elts]
    text = orchp.read_text(encoding="utf-8")
    envtxt = (impl / "environment_closure/collector.py").read_text(encoding="utf-8")
    out["static_contract"] = {"stage_order": order, "required_order": ["atomic_bundle","authoritative_intake","source_axis_binding","g2_mapping","environment_closure","trust_chain","freshness"], "production_calls": all(x in text for x in ["validate_atomic_bundle", "AuthorityIntake", "validate_source_axis", "evaluate_g2", "collect_closure", "verify_request", "validate_freshness"]), "env_resolve_strict_false": "resolve(strict=False)" in envtxt, "env_reparse_check_after_resolve": envtxt.find("resolved = path.expanduser().resolve(strict=False)") < envtxt.find("_is_reparse(target)")}
    # Runtime probes only use temp directories and in-memory adapters.
    from tools.up1_external_closure_r4.integration.orchestrator import OfflineIntegrationOrchestrator, merge_stage_results
    from tools.up1_external_closure_r4.authoritative_intake import intake as intake_mod
    from tools.up1_external_closure_r4.environment_closure.collector import collect_closure
    from tools.up1_external_closure_r4.freshness import core as freshness
    from tools.up1_external_closure_r4.g2_mapping.validator import evaluate as evaluate_g2
    runtime = {}
    runtime["empty_request"] = OfflineIntegrationOrchestrator().run({})
    # Direct merge with conflicting identity must be hard-fail under G3; record actual result.
    conflict = {s: {"status":"typed_absent", "candidate_id":"A" if s == "atomic_bundle" else "B", "formal_credit":"none", "authority_credit":False, "no_publish":True} for s in ("atomic_bundle","authoritative_intake")}
    runtime["cross_binding_conflict_merge"] = merge_stage_results(conflict, request={})
    # Publication-lock attempt through the real orchestrator normalization seam.
    locked = OfflineIntegrationOrchestrator(adapters={"trust_chain": lambda section: {"status":"terminal_deferred", "formal_credit":"granted", "no_publish":False, "authority_credit":True}}).run({"trust_chain": {}})
    runtime["publication_lock"] = locked
    runtime["g2_unknown_status"] = evaluate_g2({"status":"not-a-profile"})
    with tempfile.TemporaryDirectory(prefix="up1-r4-final-") as td:
        root = Path(td) / "spool"
        root.mkdir(parents=True)
        env = collect_closure(root, probe_versions=False)
        runtime["environment_missing_provenance"] = {"status": env.get("status"), "missing_or_unverified": env.get("missing_or_unverified"), "claim_ceiling": env.get("claim_ceiling"), "network_used": env.get("command_policy", {}).get("network_used")}
        # CAS hardlink alias and lexical escape checks.
        raw = b"final-review-cas"
        q = root / "quarantine"; q.mkdir(parents=True)
        target = q / (sha(raw) + ".bin"); donor = root / "donor.bin"; donor.write_bytes(raw); os.link(donor, target)
        try: intake_mod.atomic_quarantine(raw, root)
        except Exception as exc: runtime["cas_hardlink"] = {"type": type(exc).__name__, "error": getattr(exc, "code", str(exc))}
        try: intake_mod._ensure_regular_parent(root / ".." / "escape", root)
        except Exception as exc: runtime["path_escape"] = {"type": type(exc).__name__, "error": getattr(exc, "code", str(exc))}
        try:
            os.symlink(root, root / "reparse-link", target_is_directory=True)
            runtime["windows_reparse_capability"] = {"created": True}
        except OSError as exc:
            runtime["windows_reparse_capability"] = {"created": False, "skip": f"{type(exc).__name__}:{exc}"}
    runtime["trusted_time_missing"] = {"result": freshness._validate_trusted_time(None, "", {}, 0)}
    out["runtime"] = runtime
    dump("final_independent_probe.json", out)
    print(json.dumps(out, ensure_ascii=False, sort_keys=True, indent=2, default=str))
if __name__ == "__main__":
    try: main()
    except Exception:
        traceback.print_exc(); raise
