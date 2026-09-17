# UP1 root architecture adjudication R1

## Decision

Sol/root records the four work-package outcomes as follows:

| package | decision | ceiling | accepted meaning |
|---|---|---|---|
| W1 witness authority | `accepted_limited` | `preparation_only` | contract, typed-absence and evidence bookkeeping only |
| W2 trust chain | `accepted_limited` | `preparation_only` | trust-path contract and typed-absence bookkeeping only |
| W3 source/G2 environment | `accepted_limited` | `preparation_only` | exact-set, environment and validator bookkeeping only |
| W4 local input discovery | `accepted_limited` | `discovery_only/preparation_only` | repository-local discovery/crosswalk bookkeeping only |

None of these decisions accepts an external fact, source authority, trust
attestation, provider, candidate, mesh, solver, physics, engineering result,
or formal evidence. Usable external inputs remain exactly `0`. The absence
state is unchanged: if no external material changes, no new AD and no S3
rerun may be created. A fresh S3 G1/G2/G3 attempt remains
`typed_absent → terminal_deferred → no_publish` until a real trust root,
attestation basis, verifier and source closure arrive.

AD55 archive material is historical context and is not trust. AD56 dirty
factories are software-only, accepted-limited bookkeeping and do not supply
trust or evidence. The exact fresh formal route remains
`T0 → recheck → T1 → T2 → aggregate → UP2-00 → UP1-04B → UP1-04 → UP2-01`.

The 39-node DAG, B00/B04, R01–R10, L4, parent goal, and all upstream gates
remain open/unchanged. No formal gate is closed by this adjudication.

## Review basis

The latest read-only review records are:

- W1: `reviews/W1-witness-authority-independent-review-r7/`, PID 34140,
  exit 0, validator stdout SHA
  `9387c01857f379725bd609273ad1fea15998407952105b14807eca128b11d208`,
  validation receipt SHA `cf2254b4959406f94908fd0c9fce99270ce9c416023093b1b6a103263f901980`;
  actual/owned exact set 51/51.
- W2: `reviews/W2-trust-chain-independent-review-r3/`, independent checker
  PID 23572, exit 0, raw SHA
  `042937c39dfc5598bbc2bc94ab6fea8446e5b23ce13ba4b4dc564204ea3aff0d`,
  actual exact set 9 and seven non-self hashes matched.
- W3: `reviews/W3-source-g2-environment-independent-review-r4/`, source
  validator PID 102332, exit 0, stdout SHA
  `0eeb69ef33a978b0886cbd129269525a0033860453697ee4d286dce52b081271`,
  manifest current SHA `8438062fbb561e5fdf4eb2a81c63e322543ccda9f0c80d7565ca13e079dc7ca9`;
  actual/allowed/input exact set 47/47/47.
- W4: `reviews/W4-local-input-discovery-independent-review-r3/`, metadata
  scan PID 103592 and validator PID 46848, both exit 0; scan SHA
  `e4da31030c88f3c9490687dd2650bae6d820dbf68524b77feef9741b57835a07`,
  validator combined SHA
  `e79c6120b533aef46404e2121943d82d6852d7ed5c046133a94bbd5480918787`,
  lossless crosswalk digest
  `1418e81174f6f598ce06b9dbfb48481d3881f36d0e3c5c2d78f8a5376b5fa6aa`.

All review artifacts and prior failures remain retained. This root record is
documentation only; it executes no Julia, S3, DESC, mesh, solver, or external
operation.

