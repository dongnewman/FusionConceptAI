N06 status sync R10 commands:

1. Read existing N06 acceptance/evidence and focused_r10/independent_postrun_r10 receipts.
2. Captured before hashes for N06 acceptance/manifest, core 16, core README and implementation README.
3. Updated only N06 acceptance/manifest and the existing N06 local status sentence in core 16. Core README and implementation README had no direct N06 link and remained byte-identical.
4. Captured after hashes and generated bounded_diff.patch from before/after snapshots.
5. Ran JSON parse/control scan, `python docs/v4_multitopology_generation/validate_plan.py`, `git diff --check`, and Julia/DESC process sweep.

No Julia/DESC was run. Prior N06 source/test/fixture/runner and R1-R9 archives were not edited.
