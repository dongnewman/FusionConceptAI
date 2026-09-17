# UP2-01-G1-DIFFUSION-V1 agent_local R1

Status: `review_pending`; `accepted=false`.

This is a fresh local software verification receipt at HEAD
`cfc745939a02fd023854dd04e9bb6d04ccadf9ee`. The four product files were
pre-existing dirty-worktree inputs and were not modified in this round. The
only new files are the raw command outputs and evidence records in this
directory. The two pre-existing `tmp/phase5_remote_session.py` processes
(PIDs 8636 and 36512) were observed and protected.

## Commands and results

| command | PID | UTC interval | exit | result |
|---|---:|---|---:|---|
| `python -B test/GenomeV5/G1/static_qa_diffusion_v1.py` | 29784 | 2026-09-17T11:04:50.4233394Z – 2026-09-17T11:04:51.0856392Z | 0 | `static_qa=pass` |
| `julia --startup-file=no --project=. test/GenomeV5/G1/diffusion_v1_contract_tests.jl` | 41140 | 2026-09-17T11:05:02.2600687Z – 2026-09-17T11:05:06.9064948Z | 0 | 71/71 |

Raw outputs are preserved in `static_qa_stdout.txt`, `static_qa_stderr.txt`,
`focused_stdout.txt`, and `focused_stderr.txt`. Python was 3.13.5 and Julia
was 1.10.5. No DESC, mesh, provider, compiler, solver, or package-wide
regression command was run.

The Julia receipt reports:

- positive declaration and typed receipt: 32/32;
- fail-closed negative controls: 34/34;
- typed source-edit identity/rehash checks: 5/5;
- total: 71/71.

The exercised controls include malformed source hash and declaration hash,
wrong K bounds/domain/probe shape, non-positive or constant K construction,
wrong operator binding, unit/GRAD closure mismatch, positive residual sign,
string-only source edits, missing authority, and the controlled unexpected
fault seam. Valid K enclosure and in-domain evaluation, typed `-1` residual,
candidate ownership, source payload binding, and edits to `u`, `K`, and `f`
are covered by the positive and edit suites.

## Input and output identity

| input artifact | bytes | SHA-256 |
|---|---:|---|
| `src/GenomeV5/G1/DiffusionDeclarationV1.jl` | 31743 | `14d26ee556029bd1fcf2477f3dbe9599622d37a3f5704d1c0bb1dd9ea31dbf1a` |
| `test/GenomeV5/G1/diffusion_v1_contract_tests.jl` | 9655 | `34bfaf76f30d5fe2684035d810b36a5c3bc045a0d8d278e3f0af5dc5b888c4a6` |
| `test/GenomeV5/G1/diffusion_v1_fixture.json` | 1582 | `7b580bf9ad875ed70ffc3aa0ee2e27cbe124c413ec7dad0a8fcd3410c6864641` |
| `test/GenomeV5/G1/static_qa_diffusion_v1.py` | 4499 | `87f511f5402224df06928a9e78c0d3213d2330da5b91021b628acd51d7536066` |

| raw output | bytes | SHA-256 |
|---|---:|---|
| `static_qa_stdout.txt` | 285 | `1f7ffd785a353b032d907da28da79bf502cb52d020bc6e6a69942f994df9f6b3` |
| `static_qa_stderr.txt` | 0 | `e3b0c44298fc1c149af4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `focused_stdout.txt` | 454 | `82f38e560e9b58e58d1a1617491bfea2a476e0746453fcff0b7384f5054615f6` |
| `focused_stderr.txt` | 0 | `e3b0c44298fc1c149af4c8996fb92427ae41e4649b934ca495991b7852b855` |

The pre-run dirty status was captured as UTF-8/LF SHA-256
`7137a51de8bef775e322bd5a4df94135621f78e242a024fa3b1d9a30b6f56524`.
The post-run status snapshot was 114 rows with SHA-256
`74aa61ae49f111b43889ee0e25078f44c761b2e9f358638feb2198fa574a6fa0`;
the additional row is the new evidence directory. After the run no Julia
process remained. The two protected phase5 processes remained present.

## Contract boundary and gaps

This module has no compiler/provider/mesh/solver router and has no
`family`/display-label routing field. Therefore the general requirement that
family/label metadata not affect routing or canonical identity is **not
applicable to this declaration contract**; it must be tested at the shared
compiler/router seam, not fabricated here. `negative_controls` is a typed
declaration field and is intentionally included in this declaration's
canonical identity; it is not a routing label.

The result is software/schema evidence only. It does not establish a physical
solution, source authority, compiler/provider execution, mesh, solver,
engineering readiness, current-A, B00/B04, or R01-R10 credit. No accepted
status was changed. Independent review by a different Luna and Sol decision
remain required.
