# UP2-01-G3-SOURCE-FEEDBACK-V1 agent-local R1

Disposition: `static_pass`; `status=proposal`; `review_pending=true`; `accepted=false`.
Claim ceiling remains `contract_only`. Julia, DESC, mesh, and package/full
regression execution were intentionally not run.

## Scope and audit

The audit started at HEAD `cfc745939a02fd023854dd04e9bb6d04ccadf9ee` with the
existing unrelated dirty worktree preserved. The two live
`phase5_remote_session.py` processes (PowerShell PID `8636`, Python PID
`36512`) were observed and not started, stopped, or modified. No Julia or DESC
process was launched. The only product changes are the four work-order files
and this new `agent_local_r1/` evidence directory.

The source repair closes contract-level rejection gaps without adding an
execution backend:

- source/field/return/heat/ledger endpoint role closure is required;
- output endpoint direction, duplicate ledger-closure IDs, and unpaired
  authority ref/hash values are rejected;
- upstream G1/G2 authority layers must be present exactly once;
- feedback target IDs and canonical target keys must be unique;
- each feedback target authority must exactly match the same-layer upstream
  authority record.

Existing exact-rational source/return/heat evaluation, owner-scope checks,
declaration-hash tamper rejection, `terminal_deferred` for missing authority,
`fail_closed` for typed contradictions, and `program_exception` for the
internal fault seam remain intact. No physical, engineering, provider, mesh,
solver, or R01-R10 credit is claimed.

## Static evidence

The explicit command below ran once on `2026-09-17` UTC, process PID `1040`,
and exited `0`:

```text
D:\Users\Newman\anaconda3\python.exe -B docs/implementation/UP2-01-G3-SOURCE-FEEDBACK-V1/static_qa.py
```

The JSON result reported every check `true`, including exact 120/90/15/15
ledger arithmetic, candidate-owned fixture identity, hash/tamper gates,
duplicate rejection token coverage, authority pairing coverage, and
`manifest_hashes_match=true`. The UTF-8 output SHA-256 was
`5c4d976c2952d6fda6a5e94194d47c58aeff621c1714cfbf818f24842f65fd52`.

Python AST parsing of `static_qa.py` also exited `0`. After the root released
the serial lane, the exact focused command below was run once (and only once)
by a Julia child PID `38376`:

```text
julia --startup-file=no --project=. test/GenomeV5/G3/up2_g3_source_feedback_v1_tests.jl
```

It ran from `2026-09-17T11:10:57.060428+00:00` through
`2026-09-17T11:11:02.053030+00:00`, exited `0`, and completed four testsets
with `54/54` assertions: `9/9`, `9/9`, `27/27`, and the new duplicate/pairing
rejection set `9/9`. Raw stdout was 516 bytes with SHA-256
`d86ac7607390b2c7e0544cf6195bde674118ca0f68c3304e9576ddf6f9475d85`; stderr
was empty with SHA-256
`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.

The post-run exact process sweep reported `julia_count=0` and `desc_count=0`.
This focused software run does not establish compiler/provider/mesh/solver,
engineering, physical, current-A, B00/B04, or R01-R10 evidence.

## Current file hashes

| path | bytes | SHA-256 |
|---|---:|---|
| `src/GenomeV5/G3/G3SourceFeedbackLawV1.jl` | 30019 | `2ad8fdfe3a61db908d219ea91ac54140dc9f2b070949aa6acd1cb40a432ed9ae` |
| `test/GenomeV5/G3/up2_g3_source_feedback_v1_fixture.json` | 2332 | `7a09ec15949e148c87c2772319e6c018d767d23bacf131147c34b3e6ce63fc40` |
| `test/GenomeV5/G3/up2_g3_source_feedback_v1_tests.jl` | 11881 | `4b8497dd8c74933aed3a2befc10d71aa7ca88eaaca482354f08466db90aab8bb` |
| `docs/implementation/UP2-01-G3-SOURCE-FEEDBACK-V1/static_qa.py` | 6174 | `7c8ca2910f1dfcab707505981e6c8b75d4336e9d7424111ddefeede4000e09c2` |

## Cleanup inventory

No scratch, launcher, cache, run, or evidence files outside the new
`agent_local_r1/` directory were created. No cleanup was required. Existing
dirty files and the two protected phase-5 processes remain untouched.
