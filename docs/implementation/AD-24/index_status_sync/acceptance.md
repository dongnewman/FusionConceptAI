# AD-24 index status synchronization

This narrow documentation update synchronizes the AD-24 status sentence in the core architecture record with its already accepted limited architecture/provenance archive. The only core change is the final AD-24 sentence: the architecture/provenance boundary is `accepted_limited`; E0/E1/E2 implementation and physical work remain pending. The AD-24 decision text, scope, dependency boundaries, and no-credit claims are retained.

The before snapshot and hash are in `before/18_sources_and_architecture_decisions.md` and `before_hashes.json`; the after snapshot is in `after/18_sources_and_architecture_decisions.md` and `after_hashes.json`. The prior AD-24 acceptance and independent review are immutable inputs. No source, test, task manifest, run, queue, README, work-order, or historical receipt was modified.

Validation: `validate_plan.py` and scoped `git diff --check` are documentation checks only. No Julia/DESC was run. This update grants no N05/N06 implementation, E0/E1/E2 execution, UP2 total, B00/B04, provider, mesh, engineering, physical, or R01-R10 credit.
