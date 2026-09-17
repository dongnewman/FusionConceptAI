# M4-D coupled-solve control test execution R1

Status: `execution_complete_review_pending`. This is a manufactured, exact,
screen-only slice. It does not authorize UP2, B00, B04, R01-R10, L4, provider,
candidate, engineering, physical, or parent closure.

The independent Python Fraction oracle ran first (PID 93372, exit 0). It
computed the frozen block determinant `3`, exact solution `(2/3, 1/3)`, zero
residual, and checked all eight identity-mapped cells of the 2x2x2 interface.
The raw combined stream is retained at
`raw/python_oracle.combined.raw` with SHA256
`94B4F5A43A37C6FAB2BCAFEEC25BAB744BE2F359180849F299D59DFAEC318615`.

The authoritative Julia run followed serially (PID 24296, UTC
2026-09-16T08:47:32.8353270Z--08:47:52.9055452Z, exit 0): `111/111`, stderr
empty. It isolated A/B/C/D includes and covered build, solve, validation,
deterministic payload, all eight cells, and typed controls for foreign C/grid,
non-bijective mapping, singular and non-SPD blocks, malformed RHS, unit,
equation/source/owner/conservation/provenance, and nonzero residuals. The raw
combined stream is retained at `raw/julia_tests_r4.combined.raw` with SHA256
`A98CB0648A2D3F052C1A8B939A0ACBFFC3E934BA05F82875466BDF89FABE0CD8`.

One intermediate passing run (PID 63524) was superseded only by this
test-file hash update; its raw is retained. Two earlier failed attempts are
retained in `archive/raw/`: the first was a
test-harness macro syntax failure; the second exposed four test-only
expectation issues. They were corrected only in the assigned test file. No
M4-D source, A/B/C source, shared entry, registry, Project, or Manifest file
was changed by this work order. No iterative/PDE/production/provider API was
executed.

Independent review and Sol/root limited acceptance are still required.
