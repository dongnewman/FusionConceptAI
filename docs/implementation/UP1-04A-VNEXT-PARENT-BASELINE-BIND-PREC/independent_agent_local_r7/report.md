# UP1-04A-VNEXT-PARENT-BASELINE-BIND-PREC — independent agent_local R7 review

Date: 2026-09-17 (Asia/Shanghai)
Reviewer: different Luna, high
Reviewed HEAD: `cfc745939a02fd023854dd04e9bb6d04ccadf9ee`
Verdict: **PASS_WITH_FINDING**; one focused-Julia wrapper rerun is permitted only after the wording correction below
Claim ceiling: `prepare_only_runtime_input_adapter`, `accepted=false`, `present_authority=false`.

## Scope and boundary

R7 is reviewed as a minimal constructor-guard repair after the R6 wrapper
receipt failed with `0 passed / 0 failed / 1 error`. I checked the two required
factory identity/version guard directions, empty identity/version fail-closed
tests, fixture/static-QA controls, all remaining required-field guards, the
R6 raw failure receipt, and R1–R6 archive protection. I did not run Julia,
DESC, provider, mesh, solver, or full regression, and did not modify product
files, `runs/`, the task manifest, public entry, or R1–R6 evidence.

## R6 failure receipt remains unchanged

The original focused wrapper directory
`runs/agent_local_up1_04a_parent_r6_focused_julia_20260917` remains the exact
failed development replay: exit `1`, test summary `0 passed, 0 failed, 1
errored`, `ArgumentError: factory identity required` at source line 184 and
test line 88. Recomputed hashes remain:

- `manifest.json`: `d62c012e3943a80ca5c82dbcf2b9cd2ba4e2d838393445ed25e58876e01c9f6e`
- `report.md`: `07866aeb914775d979e06936feae6d84f80cb6d278e9753a0490b870b91e0392`
- `run.json`: `ea53f121f0f6a8ff7eb564476c7d29646045cf1e56f7a1b486c93fe85276cfb2`
- `stdout.txt`: `d20838342bd317a924b29bdd1ffe91d4b15c06bb912f6eb4a740f03a4bd0241c`
- `stderr.txt`: `10bf605ee7454e1f5dd6d093071d294440e09863b293dc1bded6ab3cabe20959`

This is failed local development evidence only; it grants no authority or
acceptance.

## Guard and negative-control review

R7 changes the two inverted constructor guards at source lines 184–185 to:

```julia
!isempty(String(factory_identity)) || throw(ArgumentError("factory identity required"))
!isempty(String(factory_version)) || throw(ArgumentError("factory version required"))
```

This is the correct positive-required-field form: nonempty values proceed and
empty values throw. The focused test adds direct `@test_throws ArgumentError`
controls for both empty factory identity and empty factory version. The fixture
records `empty_factory_identity` and `empty_factory_version`, and static QA
requires both source guard regexes, both test tokens, and both fixture negative
controls.

The full required-guard scan found no remaining inverted `isempty(...) ||
throw` form. The only valid required-field guard matches are the aggregate
source-locator `all(!isempty(...)) || throw` and the two corrected factory
guards. Other constructors retain the appropriate `isempty(...) && throw`
reject-empty form for candidate IDs/versions, qualified refs, review version/
reviewer ref, and operation ID. No unrelated required guard was relaxed.

Fresh static QA, rerun by this reviewer:

```text
python -B test/GenomeV5/Integration/static_qa_vnext_parent_baseline_binding_local_v1.py
```

Result: exit `0`, `129/129`, Python
`D:\Users\Newman\anaconda3\python.exe`; no Julia/DESC was invoked.

## R7 product and archive checks

Reviewer-recomputed R7 product hashes match the worker evidence:

| path | bytes | SHA-256 |
|---|---:|---|
| `src/GenomeV5/Integration/VNextParentBaselineBindingLocalV1.jl` | 40072 | `e70b30588f95d76c0c840fe73f2363e174c992f521dba875d255a3b862a5bf60` |
| `test/GenomeV5/Integration/vnext_parent_baseline_binding_local_v1_tests.jl` | 24123 | `14b156e7ec1bc59cf3e233841caa118b681c7623cddcd5580f05cf0cd4b037d0` |
| `test/GenomeV5/Integration/vnext_parent_baseline_binding_local_v1_fixture.json` | 2344 | `73b5f76bcab418147bd380abd05ecfe9d306b6d5c986090f30410d14ac5a2882` |
| `test/GenomeV5/Integration/static_qa_vnext_parent_baseline_binding_local_v1.py` | 8373 | `85eab84deda0d4f40ef737c8ea1aa0044e2011faf3944b32c0e9e3ca0e592432` |

R1–R6 worker and independent manifests parse as valid JSON and remain
preserved. The public entry and task manifest remain outside this repair. The
R6 illegal interpolation evidence remains unchanged; no `${` pattern is
present in the R7 test. No hard-coded upstream hash was added.

## Required report wording correction

The R7 worker report currently says:

> current G1/G2 declarations remain pending formal acceptance.

That wording incorrectly downgrades the current project status. The current
execution contract and `status_sync_g123_r1` record accept the three V1
declaration schemas and candidate/source metadata contracts at
`accepted_local_contract` (with measured G1/G2/G3 local software evidence;
G3 source bytes/authority remains `terminal_deferred`). What is still pending
for this parent node is not schema-contract acceptance: it is actual
source-backed G1/G2 parent present authority, factory/declaration receipts,
fresh same-candidate review, and this node's own verification. The report must
be corrected to wording equivalent to:

> G1/G2 V1 schemas and candidate/source metadata contracts are accepted at
> `accepted_local_contract`; actual source-backed parent present authority
> remains pending this node's verification. `accepted=false` and
> `present_authority=false` remain the claim ceiling.

This is a documentation/status-boundary finding, not a product-code defect,
but it must be corrected before the R7 evidence is treated as a clean handoff.

## One-time focused wrapper rerun (after wording correction)

After the worker report wording is corrected, one wrapper rerun is permitted
with exactly these inputs and a new output directory:

```powershell
python -B tools/agent_local_execution.py `
  --task UP1-04A-VNEXT-PARENT-BASELINE-BIND-PREC `
  --input src/GenomeV5/Integration/VNextParentBaselineBindingLocalV1.jl `
  --input test/GenomeV5/Integration/vnext_parent_baseline_binding_local_v1_tests.jl `
  --input test/GenomeV5/Integration/vnext_parent_baseline_binding_local_v1_fixture.json `
  --input test/GenomeV5/Integration/static_qa_vnext_parent_baseline_binding_local_v1.py `
  --output runs/agent_local_up1_04a_parent_r7_focused_julia_20260917 `
  --timeout 300 `
  --run C:\Users\Newman\AppData\Local\Programs\Julia-1.10.5\bin\julia.exe `
    --startup-file=no --project=. `
    test/GenomeV5/Integration/vnext_parent_baseline_binding_local_v1_tests.jl
```

Expected result after the correction: exit `0`, all focused tests pass, and
the existing markers remain
`VNEXT_LOCAL_PBB_R3_STATUS=contract_tests_defined`,
`VNEXT_LOCAL_PBB_R3_RUNTIME_INPUT_ONLY=true`, and
`VNEXT_LOCAL_PBB_R3_PHYSICAL_CREDIT=false`. Preserve `prepare_only`,
`accepted=false`, `present_authority=false`, and no T0/T1/T2, UP2, provider,
mesh, engineering, physical, search, B00/B04, or R01–R10 credit.

## Decision

The two inverted guards are correctly repaired, empty factory identity/version
now fail closed, remaining required guards are intact, static QA is `129/129`,
and the original R6 `0/0/1` receipt is immutable. **PASS_WITH_FINDING**: fix
the R7 status wording so it preserves `accepted_local_contract` while stating
that actual source-backed parent present authority remains pending. Once that
wording is corrected, the single focused agent_local wrapper rerun above is
permitted. No commit was created.
