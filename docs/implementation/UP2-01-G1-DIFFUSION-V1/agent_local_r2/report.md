# UP2-01-G1-DIFFUSION-V1 agent_local R2

Status: `review_pending`; `accepted=false`.

R2 is a narrow repair of the independent R1 findings. It ran at HEAD
`cfc745939a02fd023854dd04e9bb6d04ccadf9ee` with the two unrelated phase5
processes (PIDs 8636 and 36512) protected. The old R1 directory and reviewer
directory were not modified. No shared entry, task manifest, G2/G3 file or
`runs/` path was changed.

## Implementation changes

- `G1DiffusionSourcePayloadV1` now carries an explicit `candidate_ref`; the
  declaration constructor and validator require exact candidate/source binding.
  The legacy unbound constructor fails closed. Typed source edits preserve the
  candidate binding.
- GRAD, K_APPLY and DIV require their fixed v1 operator IDs. Their constructors
  require the expected static value kinds and temporal types, and the
  declaration constructor checks full PhysicalType equality at every endpoint
  (value kind, rank, dimension, temporal type and units).
- Closure/applicability refs are pinned to the V1 diffusion IDs and profile
  version. Closure hash and applicability hash are included in the profile
  hash and derived declaration canonical body.
- Focused tests add cross-candidate payload rejection, wrong operator IDs,
  wrong temporal/value kinds, foreign closure/applicability refs, and direct
  receipt counter/gap/schema/canonical/profile hash assertions.

## Commands and results

| command | PID | UTC interval | exit | result |
|---|---:|---|---:|---|
| `python -B test/GenomeV5/G1/static_qa_diffusion_v1.py` | 34528 | 2026-09-17T11:24:14.3965842Z – 2026-09-17T11:24:14.9474884Z | 0 | `static_qa=pass` |
| `julia --startup-file=no --project=. test/GenomeV5/G1/diffusion_v1_contract_tests.jl` | 41440 | 2026-09-17T11:24:24.4849481Z – 2026-09-17T11:24:33.6836451Z | 0 | 88/88 |

Julia summaries are positive `41/41`, fail-closed negatives `42/42`, and
source-edit identity `5/5`. Python was 3.13.5 and Julia was 1.10.5. No DESC,
mesh, provider, compiler, solver, or package-wide regression was run.

## Final input and raw output hashes

| artifact | bytes | SHA-256 |
|---|---:|---|
| `src/GenomeV5/G1/DiffusionDeclarationV1.jl` | 37919 | `8bf9e1b428c98d144aa46ad7d09403680a7d4b44f7bd687dd4a6f68611f1a756` |
| `test/GenomeV5/G1/diffusion_v1_contract_tests.jl` | 12037 | `51ce669cd1c9d6c4d2dd6e3f48f742755c23501ce65801695df4c3247f82cd8b` |
| `test/GenomeV5/G1/diffusion_v1_fixture.json` | 2011 | `47eab33a4d360bc8577aa55be5694840982561e29bd4dfbe1f42efcf85afba19` |
| `test/GenomeV5/G1/static_qa_diffusion_v1.py` | 5284 | `4677ac7f9ba353594e7ca14bd1a2ccc2135ace1435e1685a3731fee098072790` |
| `static_qa_stdout.txt` | 285 | `2ef998093ca5a8d5217e32d3c259d31c115b93e5b1cc55127500d4b5c0494931` |
| `static_qa_stderr.txt` | 0 | `e3b0c44298fc1c149af4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `focused_stdout.txt` | 454 | `ddce1ee8d42db5871173d20fef7e760b3d1406d638a39b5eb0bb1a2cc30d5d29` |
| `focused_stderr.txt` | 0 | `e3b0c44298fc1c149af4c8996fb92427ae41e4649b934ca495991b7852b855` |

The final dirty status snapshot had 139 rows and SHA-256
`ab755ed62c051abf5d3b64d03d7668311fda180bcea4af440cf1ecd043d702a9`.
The full pre-run status hash was not serialized before the new evidence
directory was created, so it is recorded as unavailable rather than inferred.
Target input hashes above were captured before the final commands. No Julia
process remained; protected PIDs 8636 and 36512 remained untouched.

## Evidence boundary

This remains contract/software evidence only. It does not establish source
authority, compiler/provider execution, mesh, solver, numerical or physical
validity, engineering readiness, current-A, B00/B04, UP2 execution, or
R01-R10 credit. No accepted status was changed. A different Luna must
independently inspect the modified source/tests and replay the focused lane;
Sol must make the final decision.
