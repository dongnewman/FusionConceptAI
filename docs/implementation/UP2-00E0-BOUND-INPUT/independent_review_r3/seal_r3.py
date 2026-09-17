from pathlib import Path
import hashlib,json
from datetime import datetime,timezone
root=Path(__file__).parents[4]
arc=Path(__file__).parent
def h(rel):
 b=(root/rel).read_bytes()
 return {"path":rel,"bytes":len(b),"sha256":hashlib.sha256(b).hexdigest()}
src_rel="src/GenomeV5/UP2/UP2CandidatePhysicalBindingV1.jl"
test_rel="test/GenomeV5/UP2/up2_candidate_physical_binding_tests.jl"
fixture_rel="test/GenomeV5/UP2/up2_candidate_physical_binding_fixtures.json"
runner_rel="test/GenomeV5/UP2/run_up2_candidate_physical_binding.jl"
files={x:h(x) for x in [src_rel,test_rel,fixture_rel,runner_rel]}
rout={x:h("docs/implementation/UP2-00E0-BOUND-INPUT/independent_review_r3/"+x) for x in ["focused_independent_r1.stdout.log","focused_independent_r1.stderr.log","focused_independent_r1.exit","focused_independent_r1.process.json","focused_independent_r1.environment.json","adversarial_control.json","input_hashes.json"]}
report={
 "record_kind":"UP2-00E0-R3-independent-review",
 "created_at":datetime.now(timezone.utc).isoformat(),
 "reviewer":"different Luna from W24 E0 author",
 "verdict":"pass_limited",
 "scope":"actual CandidateStatePackageV5 source binding and taxonomy contract only",
 "static_adversarial":{
  "control":"adversarial_control.json",
  "result":"ready_for_focused_run",
  "production_injection":"test lines 189-207 inject an unexpected inspector through the same helper seam used by ordinary checker and source-join helper; expected result program_exception with zero calls",
  "source_join":"private helper lines 392-417 preserves source program_exception and compares candidate/ref/component hashes and axes; public overload lines 419-422 delegates to it",
  "gap_spoof":"factory admits only absent N05/N06 abstract placeholders and records two explicit terminal_deferred gaps; typed content-hashed declarations are deferred",
  "low_level_boundary":"binding-only validation is self-consistency; package overload is required for authoritative source join"
 },
 "dynamic_receipt":{
  "command":"julia --startup-file=no --project=. test/GenomeV5/UP2/run_up2_candidate_physical_binding.jl",
  "pid":74656,
  "start":"2026-09-14T02:29:35.8733357Z",
  "end":"2026-09-14T02:32:53.2185680Z",
  "real_exit":0,
  "stdout_bytes":6000,
  "stdout_sha256":rout["focused_independent_r1.stdout.log"]["sha256"],
  "stderr_bytes":0,
  "stderr_sha256":rout["focused_independent_r1.stderr.log"]["sha256"],
  "process_receipt_sha256":rout["focused_independent_r1.process.json"]["sha256"],
  "environment_receipt_sha256":rout["focused_independent_r1.environment.json"]["sha256"],
  "post_processes":[]
 },
 "counts":{
  "actual_A_envelope":"45/45",
  "reusable_G2_plan_identity":"9/9",
  "fail_closed_identity_mutations":"19/19",
  "typed_extension_boundary":"3/3"
 },
 "input_hashes":files,
 "author_r10_reference":"taxonomy_fix_r3/evidence_manifest.json",
 "history":"R1 changes_requested and r8 precheck/r9 history remain immutable; R3 preserves first-run partial observation and corrected static-control provenance.",
 "claim_ceiling":{"N05_N06":False,"B00":False,"B04":False,"provider":False,"mesh":False,"engineering":False,"physical":False,"R01_R10":False}
}
(arc/"report.json").write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
md="""# UP2-00E0-R3 independent review

Verdict: pass_limited.

The frozen source, test, fixture, runner and author r10 receipt were independently checked. The static adversarial control passed: the ordinary checker uses the inspector seam; the injected unexpected exception is classified as program_exception; the source-join helper preserves that status and checks candidate, outer refs, component hashes and version axes; the public package overload delegates to that helper. The factory preserves program_exception and records absent N05/N06 authority as separate terminal_deferred gaps.

The independent focused command completed in one synchronous process with real PID 74656, exit 0, stdout 6000 bytes, stderr 0 bytes, and no remaining Julia/DESC process. It reported 45/45 actual envelope, 9/9 reusable G2 plan identity, 19/19 fail-closed identity mutations, and 3/3 typed extension boundary checks.

This result is limited to contract and source-binding software behavior. It grants no N05/N06 declaration, provider resolution, B00/B04, mesh, engineering, physical, or R01-R10 credit. R1 and the r8 precheck history remain preserved; no prior evidence was rewritten.
"""
(arc/"report.md").write_text(md,encoding="utf-8")
