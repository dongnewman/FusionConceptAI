# UP1-04A-VNEXT-PARENT-BASELINE-BIND-PREC — independent agent_local R6 review

Date: 2026-09-17 (Asia/Shanghai)
Reviewer: different Luna, high
Reviewed HEAD: `cfc745939a02fd023854dd04e9bb6d04ccadf9ee`
Verdict: **PASS**; one agent_local wrapper focused-Julia rerun is permitted
Claim ceiling: `prepare_only_runtime_input_adapter`, `accepted=false`, `present_authority=false`.

## Scope and boundary

R6 is limited to the three Julia interpolation repairs in the focused test:
`${prefix}` → `$(prefix)`. This review did not run Julia/DESC/provider/mesh/
solver or any full regression. It did not edit product files, the task
manifest, public entry, `runs/`, or R1–R5 evidence. Only this independent R6
report and manifest are new.

## Checks and receipts

Fresh reviewer static command:

```text
python -B test/GenomeV5/Integration/static_qa_vnext_parent_baseline_binding_local_v1.py
```

Result: exit `0`, `124/124`, Python
`D:\Users\Newman\anaconda3\python.exe`. The R6 worker receipt independently
records exit `0`, raw stdout 554 bytes / SHA-256
`729502a9e1919d83ffee3d1784ea42f61fdaa112d57cc56035c904edb3f220db`, and
empty stderr SHA-256
`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.

The retained `independent_agent_local_r6_wrapper` failure receipt is valid and
appropriately bounded: exit `1`, Julia parse error at test line 67, no parsed
test groups, empty stdout SHA-256
`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`, and
stderr SHA-256
`fe6009d987bed400ac78cae61eeb427f8f179b747a59d40a3fa0d336b1382a4f`. It is a
preserved failed development replay and grants no authority or acceptance.

## Exact interpolation-only proof

The current test contains exactly three legal interpolations:

```text
test line 67: "$(prefix)DeclarationV1", "$(prefix)FactoryV1"
test line 72: "$(prefix)FactoryV1"
```

The full-text search for the illegal literal `${` returned zero matches (the
expected `rg` no-match exit `1`). There are exactly three `$(prefix)` matches.
As a byte-level semantic check, replacing only those three `$(prefix)` tokens
back to `${prefix}` produces SHA-256
`d510577bee27f6d89ede8bdfcac6960c89d88a166fbb6241bc94764eb32d0252`, exactly
the R5 focused-test hash. This proves R6 changed only the three delimiter bytes
and did not alter test semantics or surrounding text.

## Product and archive hashes

Current R6 product hashes are:

| path | bytes | SHA-256 | comparison |
|---|---:|---|---|
| `src/GenomeV5/Integration/VNextParentBaselineBindingLocalV1.jl` | 40070 | `a7292894315f450df5db94e436e764773e34b900e36ff80abb751a41c7aecf2e` | identical to R5 |
| `test/GenomeV5/Integration/vnext_parent_baseline_binding_local_v1_tests.jl` | 23338 | `b38cdb35a29da144d93d5e8407bcab75e47a0779b3d850194679241971f211dc` | R5 plus exactly 3 interpolation fixes |
| `test/GenomeV5/Integration/vnext_parent_baseline_binding_local_v1_fixture.json` | 2285 | `3d3237ff339885a7fe7c770342e2df676c15e369a31c29e8cb5c1364ebc2a547` | identical to R5 |
| `test/GenomeV5/Integration/static_qa_vnext_parent_baseline_binding_local_v1.py` | 7586 | `9dfbe705d646b8264328a50f12f56435f844c8f342d3cc3153b81e667f0b4a80` | identical to R5 |

The old R1 four-file hashes remain unchanged: source
`feaa25406350f76c785fa02094af8744397874a94cfbd694360f310df41cb232`, test
`6b90804eb7e973995291fe56c7419af6a52697cea54d66b347a7ea3beeedeb0a`, fixture
`59aef733a1e140c9906a123cebe96fce1790418d6b17ee33de4b7db6d45d115b`, and
static QA `81141251e7f5780776a1b2fd87ad77287de824d28871d0089df00b9317979aac`.
R1–R5 worker and independent manifests parse as valid JSON and remain
preserved. Historical R2–R5 product hash values are retained in manifests;
older product-byte snapshots are not duplicated in the work-order tree.

The source still has no hard-coded 64-hex upstream hash and the public entry
does not import the adapter. No R01–R10, T0/T1/T2, UP2, provider, mesh,
engineering, physical or search credit is changed.

## Permitted one-time wrapper rerun

One wrapper rerun is permitted using exactly these four inputs and a fresh
output directory; this review itself did not execute it:

```powershell
python -B tools/agent_local_execution.py `
  --task UP1-04A-VNEXT-PARENT-BASELINE-BIND-PREC `
  --input src/GenomeV5/Integration/VNextParentBaselineBindingLocalV1.jl `
  --input test/GenomeV5/Integration/vnext_parent_baseline_binding_local_v1_tests.jl `
  --input test/GenomeV5/Integration/vnext_parent_baseline_binding_local_v1_fixture.json `
  --input test/GenomeV5/Integration/static_qa_vnext_parent_baseline_binding_local_v1.py `
  --output runs/agent_local_up1_04a_parent_r6_focused_julia_20260917 `
  --timeout 300 `
  --run C:\Users\Newman\AppData\Local\Programs\Julia-1.10.5\bin\julia.exe `
    --startup-file=no --project=. `
    test/GenomeV5/Integration/vnext_parent_baseline_binding_local_v1_tests.jl
```

Expected result: exit `0`, all focused tests pass, and the existing markers
remain `VNEXT_LOCAL_PBB_R3_STATUS=contract_tests_defined`,
`VNEXT_LOCAL_PBB_R3_RUNTIME_INPUT_ONLY=true`, and
`VNEXT_LOCAL_PBB_R3_PHYSICAL_CREDIT=false`. Preserve
`prepare_only`/`accepted=false`/`present_authority=false`; no promotion or
downstream scientific credit is implied.

## Decision

R6 is a minimal legal Julia interpolation repair only. The illegal syntax is
absent, exactly three legal substitutions are present, the reverse-byte hash
matches R5, static QA remains `124/124`, failure evidence is preserved, and
R1–R5/archive protections hold. **PASS; allow one agent_local wrapper focused
Julia rerun.** No commit was created.
