from pathlib import Path
import hashlib, json, re
root = Path(__file__).parents[4]
source_path = root / "src/GenomeV5/UP2/UP2CandidatePhysicalBindingV1.jl"
source = source_path.read_text(encoding="utf-8")
r2 = (root / "docs/implementation/UP2-00E0-BOUND-INPUT/focused_r2.stdout.log").read_text(encoding="utf-8")
r2_exit = (root / "docs/implementation/UP2-00E0-BOUND-INPUT/focused_r2.exit").read_text(encoding="utf-8").strip()
expected = {
 "src/GenomeV5/UP2/UP2CandidatePhysicalBindingV1.jl":"25621a87a005ea37502686ff2f1e5419b8c71fa3cd877ca875f0e6dd397ec321",
 "test/GenomeV5/UP2/up2_candidate_physical_binding_tests.jl":"b82c2a5deabc098253302ef589541dc2627db77d8ba0f3d1fa2745f19311104b",
 "test/GenomeV5/UP2/up2_candidate_physical_binding_fixtures.json":"5de4cc133087f4d09bbc8b0334c50486b5f2ba1f479366a81f07c4822597731a",
 "test/GenomeV5/UP2/run_up2_candidate_physical_binding.jl":"08a6235e37e7c8fc538bf94dc2ef080492610538961b57cfca22c288fb3be92a",
}
actual = {}
for rel, exp in expected.items():
    got = hashlib.sha256((root / rel).read_bytes()).hexdigest()
    actual[rel] = got
checks = {}
checks["historical_r2_source_exception_exit1"] = "package_source_exception:type RealizationControlGenomeV5 has no field version_axes" in r2 and r2_exit == "1"
checks["current_taxonomy_fix_returns_program_exception"] = "return up2e0_classify_exception(error)" in source and "status=:program_exception" in source
checks["factory_checks_source_checker"] = "check = up2e0_check_package(package)" in source and "check.status == :valid" in source
checks["source_join_checks_refs_hashes_axes"] = all(x in source for x in ("source_G1_ref_mismatch", "source_G2_ref_mismatch", "source_G3_ref_mismatch", "source_G1_component_hash_mismatch", "source_G2_component_hash_mismatch", "source_G3_component_hash_mismatch", "source_version_axes_mismatch"))
checks["bound_input_hash_includes_binding_hash"] = "profile_hash=profile_hash, binding_hash=binding_hash" in source
first_start = source.find("function up2e0_validate_binding(binding::UP2CandidatePhysicalBindingV1)")
second_start = source.find("function up2e0_validate_binding(binding::UP2CandidatePhysicalBindingV1,", first_start + 1)
checks["standalone_validator_is_low_level_only"] = first_start >= 0 and second_start > first_start and "CandidateStatePackageV5" not in source[first_start:second_start]
for rel, exp in expected.items():
    checks["author_snapshot_match:" + rel] = actual[rel] == exp
pre = json.loads((Path(__file__).parent / "precheck.json").read_text(encoding="utf-8"))
checks["no_julia_desc_precheck"] = pre.get("julia_desc_count") == 0 and not pre.get("run_started", True)
result = {
 "record_kind":"UP2-00E0-R1-independent-static-control",
 "verdict":"changes_requested",
 "blockers":[
   "author r7 frozen source/test hashes drifted before independent review; current files are a taxonomy-fix snapshot and are not the author r7 snapshot",
   "historical r2 source exception was misclassified as fail_closed; the current taxonomy fix is unindependently unrun in this review"
 ],
 "source_locations":{
   "historical_catch_all":"author r7 source snapshot; r2 receipt evidence",
   "current_taxonomy_classifier":"src/GenomeV5/UP2/UP2CandidatePhysicalBindingV1.jl:187-214",
   "source_join_overload":"src/GenomeV5/UP2/UP2CandidatePhysicalBindingV1.jl:368-390",
   "standalone_validator":"src/GenomeV5/UP2/UP2CandidatePhysicalBindingV1.jl:332-366"
 },
 "checks":checks,
 "current_hashes":actual,
 "author_frozen_hashes":expected,
 "taxonomy_fix_status":"current static source separates unexpected exception as program_exception; no independent runtime proof in R1",
 "runtime":{"independent_julia_executed":False,"precheck":"no Julia/DESC processes"},
 "r2_evidence":{"exit":1,"stdout_contains_source_exception":checks["historical_r2_source_exception_exit1"]},
 "claim_ceiling":{"contract_only":False,"B00":False,"B04":False,"provider":False,"mesh":False,"engineering":False,"physical":False,"R01_R10":False}
}
(Path(__file__).parent / "static_control.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(json.dumps(result, ensure_ascii=False, indent=2))
