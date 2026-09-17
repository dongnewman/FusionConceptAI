from pathlib import Path
import hashlib,json
from datetime import datetime,timezone
arc=Path(__file__).parent
def fh(p):
 b=p.read_bytes()
 return {"bytes":len(b),"sha256":hashlib.sha256(b).hexdigest()}
files={}
for p in sorted(arc.rglob("*")):
 if p.is_file() and p.name not in ("manifest.json","final_hashes.json"):
  files[str(p.relative_to(arc))]=fh(p)
manifest={
 "record_kind":"UP2-00E0-R3-independent-review-manifest",
 "created_at":datetime.now(timezone.utc).isoformat(),
 "reviewer":"different Luna from W24 E0 author",
 "verdict":"pass_limited",
 "accepted_scope":"actual_A_candidate_state_package_source_binding_and_failure_taxonomy_software_contract",
 "static_control":"adversarial_control.json",
 "dynamic_receipt":{
   "process":"focused_independent_r1.process.json",
   "environment":"focused_independent_r1.environment.json",
   "exit":"focused_independent_r1.exit",
   "stdout":"focused_independent_r1.stdout.log",
   "stderr":"focused_independent_r1.stderr.log",
   "real_exit":0,
   "counts":"45/45 + 9/9 + 19/19 + 3/3",
   "post_processes":[]
 },
 "author_r10_reference":"../taxonomy_fix_r3/evidence_manifest.json",
 "history":{
   "r1":"changes_requested preserved in ../independent_review_r1",
   "r8_precheck":"preserved in ../independent_review_r2; no_julia; not a pass",
   "r3_first_static_false":"preserved as adversarial_control_precheck_false.json; script slicing error, no source defect",
   "r3_first_capture":"partial stdout preserved; live run later completed and receipt sealed"
 },
 "qa":{"json_parse_exit":0,"control_scan_exit":0,"git_diff_check_exit":0},
 "claim_ceiling":{"N05_N06":False,"B00":False,"B04":False,"provider":False,"mesh":False,"engineering":False,"physical":False,"R01_R10":False},
 "archive_files":files
}
(arc/"manifest.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
allf={}
for p in sorted(arc.rglob("*")):
 if p.is_file() and p.name!="final_hashes.json": allf[str(p.relative_to(arc))]=fh(p)
(arc/"final_hashes.json").write_text(json.dumps({"record_kind":"UP2-00E0-R3-final-hashes","files":allf},ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
print("manifest",fh(arc/"manifest.json")["sha256"])
print("final_hashes",fh(arc/"final_hashes.json")["sha256"])
