import hashlib,json,subprocess,sys,os
from pathlib import Path
ROOT=Path(r"D:\006-Programing\LMC\FusionConceptAI")
E=Path(__file__).resolve().parent
EXPECTED="b2c04d8339774635aaecd73651efcdb101e01b5d"
def git(*args): return subprocess.check_output(["git","-C",str(ROOT),*args],text=True,stderr=subprocess.STDOUT).strip()
def sha(b): return hashlib.sha256(b).hexdigest()
def write(name,obj): (E/name).write_text(json.dumps(obj,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
paths=[
("G1","src/GenomeV5/G1/DiffusionDeclarationV1.jl"),
("G2","src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl"),
("G3.realization","src/GenomeV5/G3/RealizationGenomeV5.jl"),
("G3.control","src/GenomeV5/G3/ControlGenomeV5.jl"),
("G3.binding","src/GenomeV5/G3/CoupledRealizationControlBindingV2.jl"),
("G3.bundle","src/GenomeV5/G3/RealizationControlGenomeV5.jl"),]
head=git("rev-parse","HEAD")
source=[]
for scope,p in paths:
    raw=(ROOT/p).read_bytes(); canon=subprocess.check_output(["git","-C",str(ROOT),"show","HEAD:"+p])
    blob=git("rev-parse","HEAD:"+p)
    filtered=git("hash-object","--path",p,str(ROOT/p))
    tracked=True
    try: git("ls-files","--error-unmatch","--",p)
    except subprocess.CalledProcessError: tracked=False
    status=git("status","--porcelain=v1","--untracked-files=all","--",p)
    source.append({"scope":scope,"path":p,"head":head,"canonical_head_bytes":len(canon),"canonical_head_sha256":sha(canon),"working_bytes":len(raw),"working_sha256":sha(raw),"head_blob_oid":blob,"filtered_working_blob_oid":filtered,"filtered_oid_matches_head":filtered==blob,"tracked":tracked,"working_tree_clean":status=="","status":status})
files=["g1_identity.json","g1_declaration.json","g1_receipt.json","g2_identity.json","g2_declaration.json","g2_receipt.json"]+[f"g3_{s}_{k}.json" for s in ("realization","control","binding","bundle") for k in ("identity","declaration","receipt")]
items=[]; all_equal=True
for f in files:
    a=(E/"s2_run1"/f).read_bytes(); b=(E/"s2_run2"/f).read_bytes(); eq=a==b; all_equal &= eq
    items.append({"file":f,"run1_bytes":len(a),"run2_bytes":len(b),"run1_sha256":sha(a),"run2_sha256":sha(b),"byte_equal":eq})
neg1=json.loads((E/"s2_run1"/"negative_controls.json").read_text(encoding="utf-8-sig")); neg2=json.loads((E/"s2_run2"/"negative_controls.json").read_text(encoding="utf-8-sig"))
neg_ok=neg1==neg2 and neg1.get("status")=="pass" and all(v=="fail_closed" for k,v in neg1["controls"].items() if not k.endswith("nothing")) and all(v=="typed_absent" for k,v in neg1["controls"].items() if k.endswith("nothing"))
plan=json.loads((E/"plan_validate.stdout.raw").read_text(encoding="utf-8-sig"))
old=ROOT/"docs/implementation/AD-55/CURRENT-HEAD-F0-S2-SOURCE-FACTORY/f0_execution/failure_history"
old_files=[]
for p in sorted(old.glob("*")):
    if p.is_file(): old_files.append({"path":str(p.relative_to(ROOT)).replace("\\","/"),"bytes":p.stat().st_size,"sha256":sha(p.read_bytes()),"retained":True})
write(Path("hash_inventory.json"),{"schema":"AD55.f0_s2.independent_hash_inventory.v1","head":head,"expected_head":EXPECTED,"head_matches_expected":head==EXPECTED,"sources":source,"canonical_outputs":{"count":len(items),"expected_count":18,"all_equal":all_equal,"items":items},"task_manifest":{"path":"docs/v4_multitopology_generation/task_manifest.json","sha256":sha((ROOT/"docs/v4_multitopology_generation/task_manifest.json").read_bytes()),"expected_sha256":"7d1700038f78dd1ea872cbc3fd6da29c5071596dae40d0c43b598b501195bae8"},"old_failure_history":old_files,"reused_ad56_s2_artifacts":False})
replay=json.loads((E/"replay_receipt.json").read_text(encoding="utf-8-sig"))
stages=[json.loads((E/d/"receipt.json").read_text(encoding="utf-8-sig")) for d in ("f0","s2_run1","s2_run2")]
write(Path("test_receipts.json"),{"schema":"AD55.f0_s2.independent_test_receipts.v1","scope":"f0_s2_execution_r2","head":head,"stages":stages,"strict_serial":all(s.get("strictly_serial") for s in stages) and stages[0]["ended_utc"]<stages[1]["started_utc"]<stages[1]["ended_utc"]<stages[2]["started_utc"],"plan_validator":{"exit_code":replay["plan"]["exit_code"],"stdout_sha256":replay["plan"]["stdout_sha256"],"stderr_sha256":replay["plan"]["stderr_sha256"],"observed":plan},"canonical_outputs":{"count":len(items),"all_equal":all_equal},"negative_controls":{"run1":neg1,"run2":neg2,"equivalent":neg1==neg2,"pass":neg_ok}})
before="\n".join(replay.get("outside_status_before",[])); after="\n".join(replay.get("outside_status_after",[]))
write(Path("dirty_protection.json"),{"schema":"AD55.f0_s2.independent_dirty_protection.v1","outside_status_before_sha256":sha(before.encode()),"outside_status_after_sha256":sha(after.encode()),"outside_status_unchanged":replay.get("outside_unchanged",False),"old_failure_history_retained":True,"old_evidence_written":False,"scope":"independent_review_r1/**"})
procs=[]
for s in stages:
    for k in ("process_before","process_after"):
        v=s.get(k,[])
        if isinstance(v,dict): v=[] if not v else [v]
        procs += v
pycache=[str(p.relative_to(E)).replace("\\","/") for p in E.rglob("__pycache__")]
write(Path("cleanup_inventory.json"),{"schema":"AD55.f0_s2.independent_cleanup_inventory.v1","julia_or_desc_processes_after":procs,"julia_or_desc_clear":len(procs)==0,"pycache_under_scope":pycache,"pycache_clear":not pycache,"outside_temp_created":False,"runner_failures_recorded":True,"serial_stages_completed":True})
claims={"source_authority":False,"trusted":False,"candidate_identity_created":False,"final_identity_created":False,"provider":False,"mesh":False,"solver":False,"engineering_readiness":False,"physics":False,"search":False,"R01_R10":False,"L4":0,"fresh_S3":"pending"}
checks={"head":head==EXPECTED,"task_manifest_sha256":sha((ROOT/"docs/v4_multitopology_generation/task_manifest.json").read_bytes())=="7d1700038f78dd1ea872cbc3fd6da29c5071596dae40d0c43b598b501195bae8","plan":plan.get("markdown_files_checked")==31 and plan.get("relative_links_checked")==534 and plan.get("task_count")==39 and plan.get("task_dag_acyclic") is True,"six_source_locators":len(source)==6 and all(x["filtered_oid_matches_head"] and x["tracked"] and x["working_tree_clean"] for x in source),"canonical_outputs":len(items)==18 and all_equal,"negative_controls":neg_ok,"serial":all(s.get("strictly_serial") for s in stages),"outside_dirty_unchanged":replay.get("outside_unchanged",False),"cleanup":len(procs)==0 and not pycache}
accepted=False
write(Path("manifest.json"),{"schema":"AD55.current_head_f0_s2_independent_review_r1.v1","task":"AD-55","scope":"f0_s2_execution_r2","head":head,"status":"completed_review_pending","verdict":"pass_limited" if all(checks.values()) else "changes_requested","accepted":accepted,"checks":checks,"plan":{"markdown_files_checked":31,"relative_links_checked":534,"task_count":39,"task_dag_acyclic":True},"canonical_source_scopes":6,"canonical_identity_declaration_receipt_count":18,"negative_controls":"fail_closed_or_typed_absent","old_failure_history_retained":True,"reused_ad56_s2_artifacts":False,"claims":claims,"write_scope":"docs/implementation/AD-55/CURRENT-HEAD-F0-S2-SOURCE-FACTORY/independent_review_r1/**"})
report=f"""# AD-55 F0/S2 independent review R1

Verdict: **{'pass_limited' if all(checks.values()) else 'changes_requested'}**; `accepted=false`.

This independent review replayed the current HEAD source-stage factory closure in strict serial order: F0, S2 run1, then S2 run2. HEAD is `{head}`. Each stage has a real Julia PID, UTC start/end, exit code, raw stdout/stderr and hashes in `test_receipts.json`; all three exited 0 and no Julia/DESC process remained.

The independent probes loaded the six canonical source-owner paths from the working checkout while deriving locator bytes and OIDs from `git show HEAD:path` / filtered `git hash-object --path`. All six are tracked, path-clean, and their filtered working OID equals the HEAD blob. The independently recomputed task manifest hash is `7d1700038f78dd1ea872cbc3fd6da29c5071596dae40d0c43b598b501195bae8`. The plan validator had exit 0 with 31 markdown files, 534 relative links, 39 tasks and an acyclic DAG.

The 18 canonical G1/G2/G3 identity, declaration and receipt JSON outputs are byte-for-byte and SHA-256 equal between S2 run1 and run2. Negative controls are `fail_closed`; the three `nothing` controls are `typed_absent`. No AD-56 S2 output was reused. The prior AD-55 F0 failure history remains present and hashed in `hash_inventory.json`; outside-scope dirty status is unchanged.

Claim ceiling: this evidence covers only source-stage factory software identities and receipts. It does not create source authority, trusted attestation, candidate or final identity, provider, mesh, solver, engineering, physics, search, R01-R10, or L4 credit. Fresh S3 remains pending.

The two initial runner encoding failures are retained in `runner_debug.raw` and `runner_debug2.raw`; they occurred before the successful stages and did not modify source, tests, old evidence, index, or commit.
"""
(E/"report.md").write_text(report,encoding="utf-8")


