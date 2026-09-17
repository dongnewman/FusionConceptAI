# UP2-01-G2-METRIC-BOUNDARY-V1 independent agent-local R1 review

Verdict: `pass_with_findings`; `accepted=false`; `claim_ceiling=contract_only`.

This is a read-only independent review of the current dirty checkout at
`cfc745939a02fd023854dd04e9bb6d04ccadf9ee`. I did not run Julia, DESC, a mesh
backend, a provider, a solver, or a full-package regression, and I did not
modify any source, test, fixture, task manifest, shared entrypoint, `runs/`, or
old evidence. The only files written by this review are this report and its
manifest.

## Checks performed

- `python -B test/GenomeV5/G2/static_qa_metric_boundary_v1.py` exited `0`.
  It reported `julia_or_desc_executed=false`, `provider_or_mesh_execution=false`,
  `review_pending=true`, `accepted=false`, and `claim_ceiling=contract_only`.
- The four current target hashes exactly match
  `agent_local_r1/evidence_manifest.json`:
  `MetricBoundaryDeclarationV1.jl` `bdce1d86...e71b9e`, focused test
  `24b1143e...ddbabf`, fixture `dc11803b...0937`, and static QA
  `8be7ba7d...1882` (full values are in `manifest.json`).
- The archived raw stdout has seven passing testsets with totals
  `20+10+13+5+14+15+5 = 82/82`; archived stderr is empty. The recorded
  focused rerun receipt is therefore internally consistent. No matching
  Julia/DESC process remained after the static QA check.
- `git diff --check` on the four target artifacts exited `0` (only Git's
  normal LF-to-CRLF warnings were printed).

## Technical review

The positive evidence is sound within the contract-only boundary.

- `g2mb_chart_map`, `g2mb_chart_jacobian`, `g2mb_metric`, determinant and
  exact oriented-area/volume measures are implemented over exact rationals.
  The fixture/test uses the diagonal Jacobian `diag(2,3,4)`, evaluates a
  chart point, checks `JᵀJ = diag(4,9,16)`, `det(J)=24`, positive orientation,
  oriented area and volume units.
- Mesh declaration admission rejects unsupported basis, out-of-reference-cell
  quadrature points, arity mismatch and non-positive weights; source admission
  binds mesh `chart_ref` to the chart and includes mesh/basis/quadrature in the
  candidate-bound source hash.
- Face declarations retain `face_id`, face kind, owner region, reference normal,
  candidate ownership and typed Dirichlet/Neumann values. Admission checks six
  closed axis faces, unique IDs, unique face slots, expected orientation and
  kind-to-unit binding. Singular charts are rejected at construction and
  orientation-reversing charts fail closed at admission.
- Changing the candidate reference changes `source_hash`; bad source and
  declaration hashes are rejected; missing/no-match authority remains
  `terminal_deferred`; the controlled exception path remains a separate
  `program_exception`.
- The fixture correctly exposes zero compile/provider/mesh/solver calls and no
  physical evidence. It does not claim mesh or provider execution.

## Finding F1: incomplete tie-break for lexical face canonicalization (P2)

`src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl:282-288` sorts by only
`(String(face), face_id, owner_region_id)`. This makes the valid six-face
fixture and ordinary permutations invariant because each face slot is unique,
but it is not a complete canonical order over the typed semantic face value.
Two malformed entries can share all three sort keys while differing in
`reference_normal` or `value`; their source hash then depends on the input
tuple order (subject to sort stability). Those entries are eventually rejected
by admission, so this is not a current accepted-fixture or physical-credit
failure, but it violates the broad “permutation cannot create an identity”
claim at the invalid-input boundary. The focused test only reverses a valid
tuple (`metric_boundary_v1_contract_tests.jl:105-111`) and does not exercise
this tie case.

Recommended follow-up: either sort by a complete canonical semantic-face key
(for example append the canonical encodings of owner/value/normal), or reject
duplicate identity keys before producing any source hash. Add a negative test
that permutes two tied-key malformed entries and verifies deterministic
fail-closed handling.

## Coverage note (non-blocking)

The fixture lists duplicate face ID, duplicate owner/slot, missing face,
singular chart and related negative controls, while the focused lane directly
executes only a subset (including mesh guards and one orientation/closure
contradiction). The source admission logic for the listed controls is present,
but static QA's marker checks do not themselves prove every listed negative
case. This should be expanded when this proposal is promoted beyond
`contract_only`.

## Scratch-path disposition

The exact paths are ordinary, non-reparse directories:

- `D:\006-Programing\LMC\FusionConceptAI\tmp\g2mb_agent_local_r1_runtime\`
  contains the unique failed-attempt raw `stdout.txt` (1269 bytes,
  SHA-256 `d992590810ac2f8ce4ae837c2d7d9465f93eb5554113a9628bfba84bc03748de`)
  and `stderr.txt` (207 bytes,
  `060239d1e9fc11f8964ae26997eb9ef16933a4c4d8af3f5dafcbc26d84b9af75`).
  It is safe for the creator to delete only if retaining the failed raw output
  is no longer required; it is not duplicated in the archived evidence.
- `D:\006-Programing\LMC\FusionConceptAI\tmp\g2mb_agent_local_r1_runtime_r2\`
  contains the passing rerun raw files. Its stdout/stderr hashes exactly match
  the archived `agent_local_r1/stdout.txt` and `stderr.txt`, so the creator may
  safely delete this scratch directory after preserving the archived receipt.

## Credit ceiling

Grant only `software_contract_test=true` (focused 82/82 receipt plus static
source/fixture QA). Grant `false` for compiler, provider, mesh, solver,
engineering, physical, B00, B04 and R01-R10. This review does not change the
work-order state: `review_pending=true`, `accepted=false`.
