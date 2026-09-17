# UP2-01-G1-DIFFUSION-V1 first-stage preparation

Status: `review_pending` / `accepted=false`.

This record covers only the first source, test, fixture and static-QA slice of
the candidate-owned variable-coefficient diffusion declaration. It implements
the preparation contract from AD-28; it does not implement UP2-01 execution.

## Baseline and protected scope

- Repository: `D:\006-Programing\LMC\FusionConceptAI`
- Baseline HEAD observed before editing: `4b69f55f7f80240147a65a22809dc1207824dde2`
- Existing dirty work was preserved. No shared entry, old V4/V2 source, old
  evidence, G2/G3, UP1-04A, UP1-04B, `src/FusionConceptAI.jl`, or `runs/`
  path was edited.
- No integration request is needed for this slice because it is intentionally
  loaded only by its dedicated test; the shared entry remains untouched.

## Delivered declaration

`src/GenomeV5/G1/DiffusionDeclarationV1.jl` defines versioned candidate-owned
records for:

- a 3-D scalar `u` and 3-D scalar `f`;
- a spatially dependent symmetric rank-2 `K(x)` with finite ordered positive
  bounds and a positive-definite declaration;
- typed `GRAD`, `K_APPLY`, and `DIV` operators with field bindings and unit
  checks for `-DIV(K*GRAD(u)) = f`; the residual sign is a typed `-1` field
  validated at construction and included in the declaration hash;
- source identity (`source_ref`, source version and source hash), closure and
  applicability references, and an explicit canonical SHA-256 hash recipe;
- a typed preparation receipt that is always `proposal`, `accepted=false`,
  `resolution=terminal_deferred`, `claim_ceiling=contract_only`, with zero
  compiler/provider/mesh/solver calls and `physical_evidence=false`;
- typed source edits for `u`, `K`, and `f`; rebuilding any of these changes the
  declaration hash. String-only edits are rejected.

The declaration itself is candidate-owned schema. It does not manufacture a
field solution and does not turn a manufactured solution into source or
physical authority.

## Tests and fixture

- `test/GenomeV5/G1/diffusion_v1_fixture.json` records the source identity,
  operator identities, claim ceiling and source-derived negative controls.
- `test/GenomeV5/G1/diffusion_v1_contract_tests.jl` prepares positive coverage,
  malformed bounds/unit/binding/string-edit controls, missing-authority
  `terminal_deferred`, hash tamper `fail_closed`, and an edited-`K` identity
  change.
- `test/GenomeV5/G1/static_qa_diffusion_v1.py` checks the source/test/fixture
  surface and emits SHA-256 values without invoking Julia or DESC.

The Julia command is prepared but deliberately not run in this work order:

```text
julia --startup-file=no --project=. test/GenomeV5/G1/diffusion_v1_contract_tests.jl
```

## Static QA receipt

Command executed:

```text
python test/GenomeV5/G1/static_qa_diffusion_v1.py
```

Observed result: `static_qa=pass`, `julia_or_desc_executed=false`.
The static runner used `D:\Users\Newman\anaconda3\python.exe` (Python
3.13.5); the interpreter version command exited `0`. Julia was not invoked.

| file | before | after SHA-256 |
|---|---|---|
| `src/GenomeV5/G1/DiffusionDeclarationV1.jl` | absent | `63acb50cd9cc37eeebdef2d3f0c715408de0a494a9694edb6f27285f5e6f1ab1` |
| `test/GenomeV5/G1/diffusion_v1_contract_tests.jl` | absent | `8c72c481f91e346cfb8911321cb7a0e8aa5d77ef593ce672d62e30b971251a2a` |
| `test/GenomeV5/G1/diffusion_v1_fixture.json` | absent | `71ad5e2bc9ca6c1737d73fb254312b44224fd30402e53a3da91ebf50044de261` |
| `test/GenomeV5/G1/static_qa_diffusion_v1.py` | absent | `c8d55d9880d3bdb2435fa484b84834f593ae4b01d3e0c67e3a314b61f26c45e6` |

No pre-existing file in the permitted scope was modified; the new files have
no parent revision hash and are therefore recorded as `absent` before this
slice.

## Boundary and independent review entry

The independent reviewer should first re-check the three file hashes in the
evidence manifest, then inspect constructor typing, unit closure, source edit
rehashing, typed `residual_sign=-1`, `terminal_deferred`, and `fail_closed` behavior. The reviewer must
keep the verdict limited to static/schema preparation. Julia parsing and the
focused test remain pending by explicit instruction; there is no compiler,
provider, mesh, physical, engineering or R01–R10 credit.
