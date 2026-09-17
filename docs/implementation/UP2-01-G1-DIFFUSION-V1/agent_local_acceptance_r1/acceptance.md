# UP2-01-G1-DIFFUSION-V1 agent-local acceptance R1

- task: `UP2-01-G1-DIFFUSION-V1`
- current product HEAD: `8dbbb68b065c3ccd9a9f0f97a879aae8665eb2e9`
- status: `accepted`
- scope_status: `accepted_local_contract`
- resolution: `accepted_local_contract`
- claim_ceiling: `contract_only`
- acceptance record: this directory

## Accepted evidence

The versioned G1 declaration contract is accepted for local software scope:
candidate/source metadata is explicit and bound, operator and full typed
PhysicalType checks are closed, the V1 closure/applicability profile is
hash-bound, and receipt counters/gaps are tested. The implementation receipt
ran `python -B test/GenomeV5/G1/static_qa_diffusion_v1.py` (exit 0) and the
focused Julia contract command (exit 0, positive `41/41`, fail-closed
negative `42/42`, source-edit identity `5/5`, total `88/88`).

The different-Luna receipt review was `pass_with_findings`: the only blocking
scope issue was closed, and the remaining wording issue is an erratum label
(`path_ledger` called `entries`) with no digest or replay impact. The
independent agent-local wrapper replay R4 exited 0 and independently parsed
`41/41 + 42/42 + 5/5 = 88/88`.

## Wrapper provenance

The wrapper was run against the product inputs below at the recorded baseline
`cfc745939a02fd023854dd04e9bb6d04ccadf9ee`; the present product HEAD is
recorded separately because the policy checkpoint advanced HEAD without
changing these four product hashes.

| input | bytes | SHA-256 |
|---|---:|---|
| `src/GenomeV5/G1/DiffusionDeclarationV1.jl` | 37919 | `8bf9e1b428c98d144aa46ad7d09403680a7d4b44f7bd687dd4a6f68611f1a756` |
| `test/GenomeV5/G1/diffusion_v1_contract_tests.jl` | 12037 | `51ce669cd1c9d6c4d2dd6e3f48f742755c23501ce65801695df4c3247f82cd8b` |
| `test/GenomeV5/G1/diffusion_v1_fixture.json` | 2011 | `47eab33a4d360bc8577aa55be5694840982561e29bd4dfbe1f42efcf85afba19` |
| `test/GenomeV5/G1/static_qa_diffusion_v1.py` | 5284 | `4677ac7f9ba353594e7ca14bd1a2ccc2135ace1435e1685a3731fee098072790` |

Wrapper input policy/task records were respectively
`4c148ca007b30431856ddf6fd5217eea23071ed80f8920742eea18b362dc4015` and
`3223f122e90385568997b3057fad7122fc7daafb86fc2fa2440e00dd2a33f2de`.
Wrapper output `stdout.txt` is 454 bytes,
`d42a20cb648a8ea55d58d59e1b55044efde2103b9faccc63e0504c8d37e71ca1`, and
`stderr.txt` is empty with SHA-256
`e3b0c44298fc1c149af4c8996fb92427ae41e4649b934ca495991b7852b855`.

## Claim boundary and next gate

This acceptance is only the G1 declaration schema plus candidate/source
metadata contract and local software replay. It does not establish actual
source authority or a checked-present source record; T0/recheck must read and
recompute local bytes and receipts. It grants no compiler, mesh, provider,
solver, numerical, physical, engineering, search, B00, B04, UP2-01-total, or
R01--R10 credit. T0 remains `planned` and unaccepted; no downstream status is
changed by this record.
