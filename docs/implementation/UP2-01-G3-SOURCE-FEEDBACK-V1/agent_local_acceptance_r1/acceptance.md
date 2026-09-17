# UP2-01-G3-SOURCE-FEEDBACK-V1 agent-local acceptance R1

- task: `UP2-01-G3-SOURCE-FEEDBACK-V1`
- current product HEAD: `8dbbb68b065c3ccd9a9f0f97a879aae8665eb2e9`
- status: `accepted`
- scope_status: `accepted_local_contract`
- resolution: `accepted_local_contract`
- claim_ceiling: `contract_only`
- acceptance record: this directory

## Accepted evidence

The versioned G3 same-candidate source/feedback declaration contract is
accepted for local software scope. G1/G2 namespace and candidate binding,
source metadata co-presence, complete authority contract hashing, half-pair
rejection, status/body consistency, duplicate/pairing rejection and typed
terminal-deferred behavior are covered. The R2 receipt reports static QA exit
0 and focused Julia exit 0 with `9/9 + 9/9 + 27/27 + 18/18 = 63/63`.

The different-Luna R2 review verdict was `pass_with_findings`. Its remaining
findings are explicit boundaries rather than blockers: this slice does not
open the source locator/recompute source bytes, and dedicated source-ID or
source-metadata mismatch assertions remain a later test-refresh item. The
independent agent-local wrapper R3 exited 0 and independently parsed `63/63`.

## Wrapper provenance

The wrapper input baseline was
`cfc745939a02fd023854dd04e9bb6d04ccadf9ee`; current product HEAD is recorded
separately because the policy checkpoint advanced HEAD without changing these
four product hashes.

| input | bytes | SHA-256 |
|---|---:|---|
| `src/GenomeV5/G3/G3SourceFeedbackLawV1.jl` | 34374 | `616bda1a3f8f32a60e8175f9d8cbb44261e803fd9e392bf75c7a5593d26ed8e7` |
| `test/GenomeV5/G3/up2_g3_source_feedback_v1_tests.jl` | 17422 | `2569086821d04a2a1a77584cf07fbc27a06278e3eef37a31591c5f34fcea9f31` |
| `test/GenomeV5/G3/up2_g3_source_feedback_v1_fixture.json` | 2332 | `7a09ec15949e148c87c2772319e6c018d767d23bacf131147c34b3e6ce63fc40` |
| `docs/implementation/UP2-01-G3-SOURCE-FEEDBACK-V1/static_qa.py` | 7127 | `9e6ba50e0fdeded00abcb2f13a46a7e0c835227e6b7b87cc6054519015554875` |

The wrapper output `stdout.txt` is 516 bytes,
`49e44ef89e869be23666f05715cb6ca455e54dd251b8f72749fe41c0fc892b82`, and
`stderr.txt` is empty with SHA-256
`e3b0c44298fc1c149af4c8996fb92427ae41e4649b934ca495991b7852b855`.
The wrapper's policy/task input hashes are
`4c148ca007b30431856ddf6fd5217eea23071ed80f8920742eea18b362dc4015` and
`3223f122e90385568997b3057fad7122fc7daafb86fc2fa2440e00dd2a33f2de`.

## Claim boundary and next gate

This acceptance is only the G3 declaration schema plus candidate/source
metadata contract and local software replay. The actual source bytes are not
read here: source authority and checked-present status remain
`terminal_deferred` until T0/recheck opens the local locator, recomputes byte
count/SHA, and joins the same candidate. It grants no compiler, mesh,
provider, solver, numerical, physical, engineering, search, B00, B04,
UP2-01-total, or R01--R10 credit. T0 remains `planned` and unaccepted; no
downstream status is changed by this record.
