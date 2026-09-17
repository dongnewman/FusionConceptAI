# UP2-01-G1-DIFFUSION-V1 repair R2

Status: `review_pending` / `accepted=false`.

This narrow repair responds to independent static precheck R1
`changes_requested`. The prior implementation accepted any already-formed
`Digest256` as `source_hash` and represented `K(x)` only through a spatial
flag, Boolean positive-definite declaration and bounds. R2 adds a
candidate-owned, content-addressable source payload and one deliberately
limited executable coefficient profile:

`K(x) = diag(b_i + s_i x_i)` on a declared bounded 3-D box.

The profile stores exact rational domain/base/slope data, evaluates a diagonal
3x3 field at an in-domain point, and computes exact diagonal lower/upper
enclosures. Construction requires at least one nonzero slope and a strictly
positive lower enclosure, so the current profile is non-constant and
conservative positive definite over its declared box. Other coefficient
expressions remain outside this version's applicability profile.

The declaration now requires `G1DiffusionSourcePayloadV1`; `source_hash` must
equal `g1_diffusion_source_hash_v1(payload)`, which hashes the source ref,
version, typed `u/K/f` payload, scalar source expressions and K expression.
An arbitrary valid `Digest256` therefore fails closed. Editing `u`, `K` or `f`
rebuilds the payload and changes both source and declaration identity.

The typed residual remains `-DIV(K*GRAD(u))=f` with `residual_sign=-1`.
Missing external authority remains `terminal_deferred`; this is still a
contract/schema slice and supplies no compiler, provider, mesh, solver,
physical, engineering, B00, B04 or R01–R10 credit.

## Scope and protection

- HEAD observed: `4b69f55f7f80240147a65a22809dc1207824dde2`.
- Only the original new G1 source, test, fixture and static QA were extended;
  this `repair_r2` directory is the only new archive directory.
- No old G1 V2, shared entry, G2/G3, UP2, core document, old evidence or
  runtime output was modified.
- Julia/DESC were not run. The focused test remains prepared for the unique
  serial lane after different-Luna R2 review.

## Before/after hashes

| path | R1 before SHA-256 | R2 after SHA-256 |
|---|---|---|
| `src/GenomeV5/G1/DiffusionDeclarationV1.jl` | `63acb50cd9cc37eeebdef2d3f0c715408de0a494a9694edb6f27285f5e6f1ab1` | `a37ff22489086aa55ad2fe7d75f8b5c2e6eb5a633bd60eed8c4947d230e45b1a` |
| `test/GenomeV5/G1/diffusion_v1_contract_tests.jl` | `8c72c481f91e346cfb8911321cb7a0e8aa5d77ef593ce672d62e30b971251a2a` | `719c238f0af997ab0cec954f0c05c06e3b27d3b5d43cb95fb6da108f696e2f80` |
| `test/GenomeV5/G1/diffusion_v1_fixture.json` | `71ad5e2bc9ca6c1737d73fb254312b44224fd30402e53a3da91ebf50044de261` | `debfe9ffb3cc1b85fe084369f5dda554d9e64397799755930ff38b16b6dedfed` |
| `test/GenomeV5/G1/static_qa_diffusion_v1.py` | `c8d55d9880d3bdb2435fa484b84834f593ae4b01d3e0c67e3a314b61f26c45e6` | `fcb948cc86249962b12952bc9765b6f6bba1e621023305a2dabfcaf8bdfa06a8` |

## Static QA

Command:

```text
python test/GenomeV5/G1/static_qa_diffusion_v1.py
```

Observed: `static_qa=pass`, exit `0`, `julia_or_desc_executed=false`.
The scan now requires source payload, source hash recomputation, K evaluation,
exact enclosure and the typed `residual_sign=-1` token. JSON fixture parsing
also passed with exit `0`.

Independent R2 review should inspect the source hash equality guard, forged
hash negative control, non-constant K evaluation, out-of-domain rejection,
exact enclosure and edited source rehash. Review remains static and limited.
