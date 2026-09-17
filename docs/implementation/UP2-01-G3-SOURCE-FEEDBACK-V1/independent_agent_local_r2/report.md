# UP2-01-G3-SOURCE-FEEDBACK-V1 independent agent-local R2

Disposition: `pass_with_findings`; `status=proposal`; `review_pending=true`;
`accepted=false`.  The package **may enter the separately serialized
independent focused replay**.  This review did not run Julia.  Its credit
ceiling is `contract_only`/software-test evidence only: no source authority,
compiler, provider, mesh, solver, engineering, physical, B00/B04, or R01--R10
credit is granted.

## Scope and independent checks

The requested baseline was HEAD
`cfc745939a02fd023854dd04e9bb6d04ccadf9ee`.  I read the current G3 source,
test, fixture, static QA, work order, prior R1 review, and the complete
`agent_local_r2` report, manifest, command receipt, and raw focused streams.
Only this new review directory is writable; source/test/fixture/static QA,
task manifests, public entry points, old archives, and `runs/` were not
modified.

The following were independently rehashed and match the R2 manifest:

| artifact | bytes | SHA-256 |
|---|---:|---|
| `src/GenomeV5/G3/G3SourceFeedbackLawV1.jl` | 34374 | `616bda1a3f8f32a60e8175f9d8cbb44261e803fd9e392bf75c7a5593d26ed8e7` |
| `test/GenomeV5/G3/up2_g3_source_feedback_v1_fixture.json` | 2332 | `7a09ec15949e148c87c2772319e6c018d767d23bacf131147c34b3e6ce63fc40` |
| `test/GenomeV5/G3/up2_g3_source_feedback_v1_tests.jl` | 17422 | `2569086821d04a2a1a77584cf07fbc27a06278e3eef37a31591c5f34fcea9f31` |
| `docs/implementation/UP2-01-G3-SOURCE-FEEDBACK-V1/static_qa.py` | 7127 | `9e6ba50e0fdeded00abcb2f13a46a7e0c835227e6b7b87cc6054519015554875` |
| `agent_local_r2/focused_stdout.txt` | 516 | `29077f5762ca1f0994d5d33dc05ca16cbce6c59133cc837cef1e2b5cebb67c38` |
| `agent_local_r2/focused_stderr.txt` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |

The raw stdout contains the four expected testsets (`9/9`, `9/9`, `27/27`,
`18/18`) and reports `63/63`; stderr is empty.  This is an independently
checked artifact/hash observation, not a Julia rerun by this reviewer.  The
R2 Python static QA was also rerun read-only and returned exit `0` with all
checks true and manifest hashes matching.

## R1 finding closure

The R1 wrong-layer authority issue is repaired.  Validation now requires the
contract URI prefix `fusionconceptai://GenomeV5/G1/` or `/G2/` according to
the declared layer, and applies the same check to `source_ref`; source refs
also require version `v1` (source lines 446--475).  The focused negative
constructs a G1-labelled authority with G2 contract/source URIs and observes
`fail_closed` with both namespace errors (test lines 182--209).

Ref/hash co-presence is enforced in the constructor (source lines 103--104)
and both half-pairs are negative-tested (test lines 162--169).  Source
identity, byte count, and SHA fields are all-or-none (source lines 105--115),
with non-negative integer byte validation.  A non-actual status carrying any
authority body material is rejected as
`authority_status_body_mismatch:<layer>` (source lines 459--465; test lines
171--180).

The `actual` contract hash is no longer an arbitrary digest: validation
recomputes the canonical binding over declared layer, candidate ref, contract
ref, source ref, source byte count, and source SHA, and rejects a changed hash
with `authority_contract_hash_source_binding_mismatch` (source lines 476--489;
test lines 211--232).  Same-candidate candidate-ref checks, exact target-to-
upstream authority equality, exactly-one G1/G2 upstream records, duplicate and
ambiguous target rejection, missing authority `terminal_deferred`, and typed
contradiction `fail_closed` remain intact.  The focused raw receipt's zero
downstream counters and the source's no-backend scope are consistent with the
contract-only ceiling.

## Findings and boundaries

1. **Source bytes are intentionally not read in this slice.**  The code binds
   `source_ref`, `source_bytes`, and caller-provided `source_sha256` into the
   canonical contract hash, but does not open a source locator and recompute
   the SHA or byte count.  R2 documents this explicitly and keeps real source
   authority/same-candidate joining deferred.  This is acceptable for entering
   independent replay only if the replay preserves the `contract_only` ceiling;
   it must not be described as checked-present source authority or as a
   physical/source receipt.

2. **Coverage finding (non-blocking):** the implementation rejects a feedback
   target's `source_id` mismatch (source line 504), and exact semantic equality
   rejects a target authority whose `source_ref`/bytes/SHA differs from the
   same-layer upstream record (lines 507--510).  The focused tests do not have
   a dedicated source-ID or source-metadata mismatch assertion; they exercise
   wrong namespace and wrong contract hash instead.  Add those controls in a
   later contract-test refresh, but this does not block the requested replay.

3. The content-hash helper is a metadata binding, not a proof that the named
   bytes exist or match `source_sha256`.  That limitation is correctly exposed
   by the R2 report and must remain `terminal_deferred` until a later
   source-backed receipt/factory gate supplies actual bytes and provenance.

## Decision

R2 is materially stronger than R1 and closes the blocking namespace, half-pair,
status-body, and arbitrary contract-hash gaps.  It is ready for the parent to
run the separately serialized independent Julia replay.  Preserve the current
`proposal`/`review_pending`/`accepted=false` state and the contract-only claim
ceiling after that replay; a focused pass cannot promote G3 source authority or
any downstream physical result.
