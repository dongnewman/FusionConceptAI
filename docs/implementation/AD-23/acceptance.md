# AD-23 UP2 N10 identity and receipt mutation boundary

Status: `accepted_limited`  
Accepted: `true`  
Scope: architecture and schema consistency/provenance only

AD-23 records the Sol decision that the existing UP2 N10-01..05 rows are provisional before formal schema freeze. Historical rows, attempts, and failures remain preserved. Any corrected locator, source type, classification, or mutation recipe requires a new versioned schema, fixture, and hash.

The audit confirmed the actual fresh CandidateStatePackageV5 fields and their limits. G1/G2 component identity ref entries and the G3 child binding identity are five-field identity NamedTuples produced by the integration helper; the authoritative typed G3 child ref remains package.g3.binding.contract_binding.contract_ref. The existing N10-03 locator/type therefore requires a versioned correction and an exact comparison between the typed child ref and its identity projection. CandidateStatePackageV5.candidate_hash is canonicalized from the package identity, axes, and migration receipt. Fresh migration receipts have status pending and no records; integration rebuilds candidate_identity_after from the actual identity hash.

AD-19 and AD-21 require an available actual-A foreign or stale ref/hash/identity/receipt value mismatch to be derived as invalid_type plus fail_closed. terminal_deferred remains for missing mapping, authority, or provenance, especially an actual V4 legacy migration receipt. The old N10-02, N10-03, and N10-05 expected terminal_deferred labels are retained only as historical provisional rows and must be corrected in a new schema before formal B04 freeze.

A future additive N10 projection may source N10-01, N10-02, and N10-04 from the actual package, and may test a fresh receipt candidate_identity_after mismatch for N10-05. That fresh mutation is not evidence of legacy migration. Legacy receipt coverage requires complete non-placeholder V4 before/after refs and hashes, axes, field mapping, identity rebuild, algorithm revision, and provenance. Every attempted constructor rejection must retain the baseline package and attempted typed value in its receipt record.

The AD-23 change is append-only in 18_sources_and_architecture_decisions.md. The protected before snapshot is the current AD-22 file; the after snapshot and bounded diff are byte-verifiable. validate_plan.py exited 0 with checks pass; the scoped git diff --check exited 0; the bounded no-index diff exited 1 because the before and after files differ as intended. No Julia, DESC, provider, solver, mesh, source, test, task-manifest, README, or run files were changed by the architecture decision.

The independent Luna review is [`independent_review/report.md`](independent_review/report.md), with SHA-256 `0f5b681f006faeab7d8c6d5aeddaefff7d9abdeeb487dbb9697fc82222dc229a`; its manifest is [`independent_review/manifest.json`](independent_review/manifest.json), with SHA-256 `dcb8ca7095e89e45f059e869af871e94e5a3b49df5e87331f8afd3c18e495d46`. The review verdict is `pass_limited`. Sol accepts only the architecture/schema consistency and provenance boundary recorded here.

This is an architecture decision archive only. It grants no UP2 implementation acceptance, N10 execution, B00/B04, provider, mesh, engineering, physical, or R01-R10 credit. UP2-00 remains incomplete and formal B04 still requires a fresh schema/hash freeze, candidate-bound receipts, checker, and independent replay review.
