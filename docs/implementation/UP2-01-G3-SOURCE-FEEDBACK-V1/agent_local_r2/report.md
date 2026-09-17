# UP2-01-G3-SOURCE-FEEDBACK-V1 agent-local R2

Disposition: `focused_test_passed`; `status=proposal`; `review_pending=true`;
`accepted=false`. No DESC, mesh, provider, solver, or full regression was run.

## Repair scope

The independent R1 review identified three blocking/major contract gaps. This
R2 repair is limited to the existing G3 source, focused test, fixture (not
changed), static QA, and this new evidence directory.

`G3SFAuthorityV1` now carries optional typed source identity metadata:
`source_ref`, non-negative `source_bytes`, and `source_sha256`. Actual
authority requires all source material plus a contract ref/hash pair. The
contract hash is checked against a canonical digest binding the declared
layer, candidate ref, contract ref, source identity, source byte count, and
source SHA-256. Contract and source identities must use the declared
`fusionconceptai://GenomeV5/G1/` or `/G2/` namespace. Wrong-layer URIs and a
source-bound hash mismatch are `fail_closed` validation errors.

Half-pair constructor controls are present for both ref-without-hash and
hash-without-ref. Non-actual statuses carrying authority body material are
rejected as `authority_status_body_mismatch:<layer>`, while the fixture's
empty `missing` authority remains `terminal_deferred`. Existing
same-candidate, exact-rational, owner-scope, duplicate, declaration-hash,
`fail_closed`, and `program_exception` boundaries are preserved.

No source bytes are read or synthesized in this slice. The source metadata
and canonical binding are the strongest closure expressible by the existing
typed contract without importing a provider or source factory; real source
authority and same-candidate joining remain deferred.

## Static commands

The explicit Python static QA ran once at `2026-09-17T11:26:44.0069709Z`
through `2026-09-17T11:26:44.0998926Z`, PID `40888`, exit `0`:

```text
D:\Users\Newman\anaconda3\python.exe -B docs/implementation/UP2-01-G3-SOURCE-FEEDBACK-V1/static_qa.py
```

Every reported check was `true`, including namespace, source-material,
source-bound hash, half-pair, status/body, exact ledger, and manifest checks.
Captured UTF-8 output SHA-256:
`33a24793d850d4e12f702d72fb87aada9d47ae010b987120bf1c80b262619a82`.
The static result records zero compiler/provider/mesh/solver calls and
`julia_run=false`. Python AST parsing of `static_qa.py` also exited `0`.

## Focused Julia evidence

After the G2 lane released the serial slot, the exact focused command ran once
with child PID `35728`:

```text
julia --startup-file=no --project=. test/GenomeV5/G3/up2_g3_source_feedback_v1_tests.jl
```

Start/end UTC were `2026-09-17T11:31:22.314601+00:00` and
`2026-09-17T11:31:27.772258+00:00`; exit code was `0`. Four testsets passed:
`9/9`, `9/9`, `27/27`, and the R2 authority/duplicate set `18/18`, totaling
`63/63`. Raw stdout was 516 bytes with SHA-256
`29077f5762ca1f0994d5d33dc05ca16cbce6c59133cc837cef1e2b5cebb67c38`; stderr
was empty with SHA-256
`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.
The exact raw streams are preserved as `focused_stdout.txt` (516 bytes) and
`focused_stderr.txt` (0 bytes) in this evidence directory.
The post-run exact process sweep reported `julia_count=0` and `desc_count=0`.
This is focused software evidence only and grants no compiler/provider/mesh,
engineering, physical, B00/B04, or R01-R10 credit.

Historical failures remain preserved and were not rewritten: focused R1's
pre-R5 namespace failure and focused R2's launcher failure are retained in
their original archives. The R2 focused run above is a fresh successful run;
there is no new failure artifact.

## Current hashes

| path | bytes | SHA-256 |
|---|---:|---|
| `src/GenomeV5/G3/G3SourceFeedbackLawV1.jl` | 34374 | `616bda1a3f8f32a60e8175f9d8cbb44261e803fd9e392bf75c7a5593d26ed8e7` |
| `test/GenomeV5/G3/up2_g3_source_feedback_v1_fixture.json` | 2332 | `7a09ec15949e148c87c2772319e6c018d767d23bacf131147c34b3e6ce63fc40` |
| `test/GenomeV5/G3/up2_g3_source_feedback_v1_tests.jl` | 17422 | `2569086821d04a2a1a77584cf07fbc27a06278e3eef37a31591c5f34fcea9f31` |
| `docs/implementation/UP2-01-G3-SOURCE-FEEDBACK-V1/static_qa.py` | 7127 | `9e6ba50e0fdeded00abcb2f13a46a7e0c835227e6b7b87cc6054519015554875` |

## Cleanup and protection

Only `agent_local_r2/` was added. No scratch, cache, run, public entry,
manifest, or old evidence path was changed. Existing unrelated dirty files
and protected phase-5 processes were preserved. No Julia/DESC process was
started, and no cleanup was required.
