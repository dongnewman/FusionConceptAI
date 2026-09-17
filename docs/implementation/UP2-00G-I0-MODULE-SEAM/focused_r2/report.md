# G-I0 focused R2 preflight hold

Verdict: `hold_dependency_drift`. The frozen G-I0 runner was **not started**.

The independent static R4 frozen dependency set was reconciled read-only. E1/N05 source, test, fixture, and runner; E2/N06 source, test, fixture, and runner; G-I0 entry, test, corrected runner, failure probe; `src/FusionConceptAI.jl`; and `src/GenomeV5/Integration/GenomeV5Integration.jl` all match their frozen SHA-256 values. The AD-26 core dependency
`docs/v4_multitopology_generation/18_sources_and_architecture_decisions.md`
does not: frozen SHA `a01c9c65a3bed8ed0b2f887ba3cfaac1d3941cc09bb08cd7717f6a59106de713` (37,859 bytes) versus current SHA
`a7bffc313dfef35c7e302dd251709491a4a91e15d37a275d92fd6fe9d5aca28c` (40,362 bytes).

The preflight Julia/DESC process sweep exited 0 and observed no process. Because the core dependency drifted, the runtime gate required a hold; no main PID, child PID, runtime stdout/stderr, exit code, or after snapshot exists. Protected dirty files were recorded before the hold with SHA and mtime; no files outside this new `focused_r2/` evidence scope were modified. Existing focused R1 failure and independent R4 evidence remain untouched.

No UP2-total, B00/B04, provider, mesh, engineering, physical, or R01-R10 credit is granted. Runtime may proceed only after AD-26 core18 reconciliation and a fresh independent static freeze.
