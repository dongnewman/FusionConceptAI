from pathlib import Path
import hashlib, json
from datetime import datetime, timezone
arc=Path(__file__).parent
def fhash(p):
    b=p.read_bytes()
    return {"bytes":len(b),"sha256":hashlib.sha256(b).hexdigest()}
files={}
for p in sorted(arc.rglob("*")):
    if p.is_file() and p.name not in ("manifest.json","final_hashes.json"):
        files[str(p.relative_to(arc))]=fhash(p)
manifest={
 "record_kind":"UP2-00E0-R1-independent-review-manifest",
 "created_at":datetime.now(timezone.utc).isoformat(),
 "reviewer":"different Luna from E0 author",
 "verdict":"changes_requested",
 "scope":"static independent review of author r7 snapshot",
 "input_snapshot":"input_hashes.json",
 "author_r7_hashes":{
  "source":"25621a87a005ea37502686ff2f1e5419b8c71fa3cd877ca875f0e6dd397ec321",
  "test":"b82c2a5deabc098253302ef589541dc2627db77d8ba0f3d1fa2745f19311104b",
  "fixture":"5de4cc133087f4d09bbc8b0334c50486b5f2ba1f479366a81f07c4822597731a",
  "runner":"08a6235e37e7c8fc538bf94dc2ef080492610538961b57cfca22c288fb3be92a"
 },
 "blocking_finding":{
  "code":"unexpected_exception_misclassified",
  "location":"src/GenomeV5/UP2/UP2CandidatePhysicalBindingV1.jl:187-198 in author r7 snapshot",
  "historical_counterexample":"RealizationControlGenomeV5 has no field version_axes",
  "historical_receipt":"focused_r2.exit=1; focused_r2.stdout.log preserved",
  "required_classification":"program_exception",
  "incorrect_classification":"status=:fail_closed",
  "minimum_repair":"Separate known source contradictions (fail_closed) from unexpected inspection exceptions (program_exception or propagated runner exception), with a typed negative control."
 },
 "static_adversarial_review":{
  "actual_factory_join":"factory invokes source checker before constructing envelope",
  "package_overload":"checks candidate/ref/component hashes and four axes against actual package",
  "bound_input_hash":"includes binding_hash",
  "low_level_caveat":"binding-only validator is self-consistency; source overload is required for authoritative source join"
 },
 "runtime":{
   "independent_julia":"not_executed",
   "reason":"blocking finding made author r7 run non-actionable; precheck.json recorded zero Julia/DESC"
 },
 "history":{
   "r1":"changes_requested; author r7 source bytes were untracked and later overwritten, so historical_source_excerpt.txt is retained as non-replayable excerpt",
   "post_r1":"taxonomy_fix is superseded_after_changes_requested and requires fresh R2 freeze/review; it is not R1 pass evidence"
 },
 "qa":{
   "json_parse_exit":0,
   "control_scan_exit":0,
   "git_diff_check_exit":0,
   "qa_record":"qa.json",
   "git_diff_check_record":"git_diff_check.exit"
 },
 "claim_ceiling":{
   "contract_only":False,"B00":False,"B04":False,"provider":False,"mesh":False,
   "engineering":False,"physical":False,"R01_R10":False
 },
 "archive_files":files
}
(arc/"manifest.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
allfiles={}
for p in sorted(arc.rglob("*")):
    if p.is_file() and p.name != "final_hashes.json":
        allfiles[str(p.relative_to(arc))]=fhash(p)
(arc/"final_hashes.json").write_text(json.dumps({"record_kind":"UP2-00E0-R1-final-hashes","files":allfiles},ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
print("manifest_sha256",fhash(arc/"manifest.json")["sha256"])
print("final_hashes_sha256",fhash(arc/"final_hashes.json")["sha256"])
print(json.dumps({"archive_file_count":len(allfiles)},ensure_ascii=False))
