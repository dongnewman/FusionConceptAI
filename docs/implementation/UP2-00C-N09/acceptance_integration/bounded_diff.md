# UP2-00C-N09 integration bounded diff

The integration changes only the authorized N09 acceptance/manifest, the implementation index, the core work-order index, and this archive.

- N09 acceptance and manifest move from review_pending/accepted=false to accepted_limited/accepted=true after the independent Luna/high r2 pass.
- The accepted scope is only five actual-A provider_match declarations and eleven mutations whose values changed. The low-level constructor, fixed oracle domain, and missing expected_error reversal control remain outside general classification and B04 credit.
- The implementation and core indexes link the N09 records. The UP2-00 total gate remains open; locally accepted N07/N08/N09 projections do not replace the 50 fresh formal B04 receipts.
- No N09 source, fixture, focused logs, reviewer archive, task manifest, run, provider, mesh, physical, or R01-R10 artifact was changed.

The before file hashes and mtimes are in [before_hashes.json](before_hashes.json). Final hashes and validation exits are in [after_hashes_final.json](after_hashes_final.json).

The first post-edit validator attempt exited 1 because the work-order acceptance strings temporarily diverged from the protected task_manifest.json. The exact failed output and exit are preserved in validate_plan_initial_failed.stdout.log and validate_plan_initial_failed.exit. The acceptance strings were restored verbatim from task_manifest.json, and the final validator then exited 0.
