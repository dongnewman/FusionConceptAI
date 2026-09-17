# UP2-00E0-R1 independent review

Verdict: changes_requested for the author r7 frozen snapshot. This is a static independent review; no Julia/DESC run was started.

## Blocking finding

The author r7 source at src/GenomeV5/UP2/UP2CandidatePhysicalBindingV1.jl:187-198 caught every exception from _up2e0_identity_errors, emitted package_source_exception:..., and returned status=:fail_closed. The preserved author focused_r2 receipt has exit 1 and the concrete error type RealizationControlGenomeV5 has no field version_axes. The frozen protocol requires a validator crash to be program_exception; known rejected declarations/contradictions alone may be fail_closed (19_up0_02_contract_freeze.md:76, 13_acceptance_benchmarks_and_evidence.md:36).

Minimum repair: preserve known contradiction rejection as fail_closed, route unexpected inspection exceptions to an explicit program_exception result (or propagate for runner classification), and add a negative control for that route. The source factory and package overload also provide the intended actual source join; the low-level binding-only validator is self-consistency and cannot serve as source authority by itself.

## Evidence and boundary

R1 input hashes are recorded in input_hashes.json; the r2 stdout/stderr/exit/environment are copied under r2_observation/ with hashes in report.json. precheck.json records zero Julia/DESC processes and run_started=false. A later taxonomy-fix snapshot was observed after this changes_requested decision; it is recorded in post_r1_observation.json as superseded_after_changes_requested and requires a new R2 freeze/review.

This review grants no contract acceptance, B00/B04, provider, mesh, engineering, physical, or R01-R10 credit.
