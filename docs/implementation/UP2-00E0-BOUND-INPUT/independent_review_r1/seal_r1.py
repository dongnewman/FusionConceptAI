from pathlib import Path
import hashlib, json
from datetime import datetime, timezone
root = Path(__file__).parents[4]
arc = Path(__file__).parent
def sha(rel):
    b=(root/rel).read_bytes()
    return {"path":rel,"bytes":len(b),"sha256":hashlib.sha256(b).hexdigest()}
author = {
 "src/GenomeV5/UP2/UP2CandidatePhysicalBindingV1.jl":"25621a87a005ea37502686ff2f1e5419b8c71fa3cd877ca875f0e6dd397ec321",
 "test/GenomeV5/UP2/up2_candidate_physical_binding_tests.jl":"b82c2a5deabc098253302ef589541dc2627db77d8ba0f3d1fa2745f19311104b",
 "test/GenomeV5/UP2/up2_candidate_physical_binding_fixtures.json":"5de4cc133087f4d09bbc8b0334c50486b5f2ba1f479366a81f07c4822597731a",
 "test/GenomeV5/UP2/run_up2_candidate_physical_binding.jl":"08a6235e37e7c8fc538bf94dc2ef080492610538961b57cfca22c288fb3be92a",
}
r2outs = [sha("docs/implementation/UP2-00E0-BOUND-INPUT/focused_r2.stdout.log"), sha("docs/implementation/UP2-00E0-BOUND-INPUT/focused_r2.stderr.log"), sha("docs/implementation/UP2-00E0-BOUND-INPUT/focused_r2.exit"), sha("docs/implementation/UP2-00E0-BOUND-INPUT/focused_r2.environment.txt")]
current = [sha(rel) for rel in author]
source=(root/"src/GenomeV5/UP2/UP2CandidatePhysicalBindingV1.jl").read_text(encoding="utf-8")
def line_of(s):
    for i,line in enumerate(source.splitlines(),1):
        if s in line: return i
    return None
observation={
 "record_kind":"UP2-00E0-R1-post-review-observation",
 "captured_at":datetime.now(timezone.utc).isoformat(),
 "current_files":current,
 "classification_fix_observed": "return up2e0_classify_exception(error)" in source and "status=:program_exception" in source,
 "classification_fix_locations":{"catch_dispatch":line_of("return up2e0_classify_exception(error)"),"program_exception":line_of("status=:program_exception")},
 "interpretation":"Observed bytes are a later taxonomy-fix snapshot after R1 changes_requested; they supersede the R1 input and require a fresh R2 freeze/review."
}
(arc/"post_r1_observation.json").write_text(json.dumps(observation,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
static={
 "record_kind":"UP2-00E0-R1-independent-review",
 "reviewer":"different Luna; static-only due blocking taxonomy defect",
 "verdict":"changes_requested",
 "reviewed_snapshot":{"source_sha256":author["src/GenomeV5/UP2/UP2CandidatePhysicalBindingV1.jl"],"test_sha256":author["test/GenomeV5/UP2/up2_candidate_physical_binding_tests.jl"],"fixture_sha256":author["test/GenomeV5/UP2/up2_candidate_physical_binding_fixtures.json"],"runner_sha256":author["test/GenomeV5/UP2/run_up2_candidate_physical_binding.jl"]},
 "primary_finding":{
   "classification":"program_exception",
   "r2_exit":1,
   "r2_stdout_sha256":r2outs[0]["sha256"],
   "error":"package_source_exception:type RealizationControlGenomeV5 has no field version_axes",
   "frozen_source_location":"UP2CandidatePhysicalBindingV1.jl:187-198 (r7 source)",
   "contract_locations":["docs/v4_multitopology_generation/19_up0_02_contract_freeze.md:76","docs/v4_multitopology_generation/13_acceptance_benchmarks_and_evidence.md:36"],
   "reason":"validator crash/unexpected source exception must remain program_exception; structural fail_closed is reserved for known rejected declarations/contradictions."
 },
 "adversarial_source_join":{
   "factory_source_check":"present in frozen source; factory invokes up2e0_check_package before envelope construction",
   "source_overload":"present; compares candidate/ref/component hashes and version axes against actual package",
   "bound_input_binding_hash":"included",
   "low_level_caveat":"up2e0_validate_binding(binding) is self-consistency only; package overload is required for authoritative source join"
 },
 "timeline":{
   "r1":"changes_requested against author r7 snapshot",
   "post_r1":"taxonomy_fix observed as superseded_after_changes_requested; not used as R1 pass evidence",
   "next":"fresh R2 must freeze repaired source/test and run independently"
 },
 "runtime":{"independent_julia":"not_executed","reason":"static blocker made a run on the superseded r7 snapshot non-actionable; precheck recorded no Julia/DESC"},
 "claim_ceiling":{"contract_only":False,"B00":False,"B04":False,"provider":False,"mesh":False,"engineering":False,"physical":False,"R01_R10":False},
 "preserved_r2_artifacts":r2outs
}
(arc/"report.json").write_text(json.dumps(static,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
report = """# UP2-00E0-R1 independent review

Verdict: changes_requested for the author r7 frozen snapshot. This is a static independent review; no Julia/DESC run was started.

## Blocking finding

The author r7 source at src/GenomeV5/UP2/UP2CandidatePhysicalBindingV1.jl:187-198 caught every exception from _up2e0_identity_errors, emitted package_source_exception:..., and returned status=:fail_closed. The preserved author focused_r2 receipt has exit 1 and the concrete error type RealizationControlGenomeV5 has no field version_axes. The frozen protocol requires a validator crash to be program_exception; known rejected declarations/contradictions alone may be fail_closed (19_up0_02_contract_freeze.md:76, 13_acceptance_benchmarks_and_evidence.md:36).

Minimum repair: preserve known contradiction rejection as fail_closed, route unexpected inspection exceptions to an explicit program_exception result (or propagate for runner classification), and add a negative control for that route. The source factory and package overload also provide the intended actual source join; the low-level binding-only validator is self-consistency and cannot serve as source authority by itself.

## Evidence and boundary

R1 input hashes are recorded in input_hashes.json; the r2 stdout/stderr/exit/environment are copied under r2_observation/ with hashes in report.json. precheck.json records zero Julia/DESC processes and run_started=false. A later taxonomy-fix snapshot was observed after this changes_requested decision; it is recorded in post_r1_observation.json as superseded_after_changes_requested and requires a new R2 freeze/review.

This review grants no contract acceptance, B00/B04, provider, mesh, engineering, physical, or R01-R10 credit.
"""
(arc/"report.md").write_text(report,encoding="utf-8")
