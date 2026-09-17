# Acceptance integration record

This directory records the documentation-only integration after the independent Luna/high `pass_limited` review. The author archive remains content-addressed through its original r1/r2/r3 logs; this integration changes only acceptance status, manifest scope, and navigation links.

Accepted scope is the ten actual-A/current-admitted-G2 frozen schema mutations: N07-01..05 and N08-01..05. The current implementation limits are retained verbatim in the acceptance and manifest: global-envelope/`regions[1]` bounds, required-face inclusion without duplicate/extra-face proof, and `:none_declared` as a current admitted-G2 rule. Supplemental topology rows are excluded. UP2 total, B00, B04, mesh, provider, engineering, physical, and R01-R10 remain false.

The before hashes and after hashes are in `before_hashes.json` and `after_hashes.json`. No source, test, fixture, old run, reviewer archive, core architecture file, or task manifest was modified.

Validation command outputs and exit files are preserved in this directory. `validate_plan.py` is a planning/schema check only and cannot establish geometry, solver, or physical evidence.
