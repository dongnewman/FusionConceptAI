# UP2-01-G1-DIFFUSION-V1 independent agent-local review R1

Verdict: `fail`; `accepted=false`; `review_pending=true`.

This is an independent, read-only review of `agent_local_r1` at HEAD
`cfc745939a02fd023854dd04e9bb6d04ccadf9ee`.  Julia was not run in this
review, as required by the work order.  The permitted Python static QA was
rerun and exited 0.  Only this review directory is new; the G1 source, test,
fixture, shared entry points, task manifest and `runs/` were not modified.

## Evidence authenticity and scope

The four declared inputs match the agent manifest byte-for-byte:

| input | bytes | SHA-256 |
|---|---:|---|
| `src/GenomeV5/G1/DiffusionDeclarationV1.jl` | 31743 | `14d26ee556029bd1fcf2477f3dbe9599622d37a3f5704d1c0bb1dd9ea31dbf1a` |
| `test/GenomeV5/G1/diffusion_v1_contract_tests.jl` | 9655 | `34bfaf76f30d5fe2684035d810b36a5c3bc045a0d8d278e3f0af5dc5b888c4a6` |
| `test/GenomeV5/G1/diffusion_v1_fixture.json` | 1582 | `7b580bf9ad875ed70ffc3aa0ee2e27cbe124c413ec7dad0a8fcd3410c6864641` |
| `test/GenomeV5/G1/static_qa_diffusion_v1.py` | 4499 | `87f511f5402224df06928a9e78c0d3213d2330da5b91021b628acd51d7536066` |

The four raw output files also match the agent manifest: static-QA stdout
`285` bytes, SHA `1f7ffd785a353b032d907da28da79bf502cb52d020bc6e6a69942f994df9f6b3`;
static-QA stderr is empty with SHA
`e3b0c44298fc1c149af4c8996fb92427ae41e4649b934ca495991b7852b855`; focused
stdout `454` bytes, SHA
`82f38e560e9b58e58d1a1617491bfea2a476e0746453fcff0b7384f5054615f6`; and
focused stderr is empty with the same empty-file SHA.  Parsing the preserved
focused stdout gives `32/32 + 34/34 + 5/5 = 71/71`; no literal total line is
needed to establish that arithmetic.  Re-running
`python -B test/GenomeV5/G1/static_qa_diffusion_v1.py` independently produced
`static_qa=pass` with the same three input hashes and
`julia_or_desc_executed=false`.

## Verified implementation properties

- The diagonal-affine K expression is non-constant, uses a bounded
  non-degenerate 3-D domain, and checks a positive diagonal lower enclosure
  (source lines 78-117).  The declaration requires exact reported enclosure
  bounds and `positive_definite=true` (lines 145-163).
- GRAD, K_APPLY and DIV enforce rank/dimension and unit arithmetic in their
  constructors (lines 167-225); declaration construction additionally checks
  field IDs, K coefficient-unit binding and the final unit closure (lines
  308-318).  The residual sign is stored as typed `Int8(-1)` and positive
  values are rejected (lines 252-266).
- The candidate-owned source payload is canonicalized and its supplied hash
  is recomputed and compared (lines 229-250 and 296-305).  Typed edits to `u`,
  `K` and `f` rebuild the payload and declaration (lines 517-546), so the
  agent's 5/5 source-edit receipt is credible.
- Missing source authority is represented as `terminal_deferred`, while
  malformed source/K/operator inputs use typed `fail_closed` paths and the
  controlled fault seam is classified as `program_exception` (lines 378-465).
  The receipt constructor sets all downstream call counters to zero and
  `physical_evidence=false` (lines 467-498); no compiler/provider/mesh/solver
  call path is present in this slice.

## Blocking findings

### F1 — source payload is not explicitly bound to the candidate identity (P1)

`G1DiffusionDeclarationV1` stores `candidate_ref`, but
`G1DiffusionSourcePayloadV1` stores only `source_ref`, `source_version`, `u`,
`K` and `f` (lines 229-243).  The declaration constructor checks only that the
candidate is version `v5`, that payload and declaration share `source_ref` and
`source_version`, and that all field hashes match (lines 292-307).  It never
checks a candidate-to-source relation.  Consequently the same valid payload
and source ref can be attached to a different v5 candidate and still pass
construction/validation; `candidate_owned` is only a symbol, not a binding.
This violates the requested actual-candidate/source binding and permits
foreign-source reuse.  Add an explicit candidate ref to the source payload or
a candidate-bound source identity, enforce equality in construction and
validation, and add a negative cross-candidate test.

### F2 — typed operator identity and full PhysicalType closure are incomplete (P1)

The three typed operator constructors require only `ref.version == "v1"`
(lines 173-181, 194-204 and 216-225); they do not require the expected GRAD,
K_APPLY or DIV reference IDs.  The declaration checks operator field IDs and
units, but not exact `PhysicalType` equality between `u` and GRAD input, GRAD
output and K_APPLY input, K_APPLY output and DIV input, or DIV output and `f`
(lines 308-318).  Thus a `v1` ref with an unrelated ID, or a type with the
same rank/dimension/units but a different `value_kind` or temporal kind, can
be admitted.  The current B04 protocol explicitly includes wrong rank/dim/
unit/time mutation controls.  Pin operator IDs and compare the full typed
endpoints (including value kind, rank, dimension, temporal type and units),
then add negative tests for wrong IDs and wrong temporal/value kinds.

### F3 — closure/applicability references are not pinned to the declared profile (P2)

`closure_ref` and `applicability_ref` are accepted as arbitrary non-empty
`QualifiedRefV1` values (lines 279-281 and 320-325).  The declaration does not
require `applicability_ref` to equal `G1_DIFFUSION_APPLICABILITY_ID_V1` or
require a versioned closure/profile registry match.  A declaration can
therefore carry a foreign applicability/closure ref while still producing the
same contract-only receipt.  Require the frozen refs (or an explicit
versioned registry lookup) and cover mismatched ref/version as fail-closed.

## Evidence/coverage findings

### F4 — cleanup inventory does not satisfy the full AD-35 exact-set schema (P2)

`agent_local_r1/cleanup_inventory.json` records new filenames, temporary-file
absence, process counts and a broad scope-integrity summary, but does not
record per-path owner/category/before-after existence and hashes, action/reason,
or a `final_exact_owned_set`.  The target hashes and no-Julia-process check
are independently clean, but the receipt cannot by itself prove the required
exact cleanup ownership/protection contract.

### F5 — zero downstream counters and receipt hashes are implemented but not
fully asserted by the focused test (P2)

The implementation visibly sets all four counters to zero and binds schema,
canonicalization and profile hashes in `g1_diffusion_receipt_v1`; the focused
suite only checks receipt status/ceiling/physical flag and that the receipt
hash has type `Digest256`.  It does not assert each zero counter, required-gap
tuple, or each receipt hash against the corresponding function.  Keep these
as explicit assertions before treating the software slice as a stronger
receipt contract.

## Cleanup/protection observation and credit ceiling

At review time the four product hashes remained unchanged, HEAD matched the
agent receipt, and no Julia process was present.  The worktree is concurrently
dirty from unrelated tasks (1400 status rows at review; UTF-8/LF status hash
`7f26c894a4a60856786ef070041198272d992bca976278710d1a40b63cbbee9`), so this
review does not attribute unrelated rows to the agent.  The two protected
phase-5 PIDs named by the agent were still present and were not touched.

The `fail` verdict is limited to this G1 software-contract review and the
findings above.  Credit ceiling: `software_test_only` for the independently
verified 71/71 receipt and static QA, with `accepted=false`; no compiler,
provider, mesh, solver, numerical/physical, engineering, current-A, B00,
B04, UP2 execution, or R01-R10 credit.  No Julia/DESC/mesh/solver result is
claimed by this review.
