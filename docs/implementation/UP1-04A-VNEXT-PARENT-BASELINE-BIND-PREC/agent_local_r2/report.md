# UP1-04A parent-baseline binding PREC — agent_local R2

Date: 2026-09-17 (Asia/Shanghai), evidence captured in UTC.

## Scope and authority boundary

This round adds an additive, standalone runtime-input adapter. It does not
modify the old `VNextParentBaselineBindingV1.jl` scaffold, its tests/fixture,
the public entry, manifests, T0/T1/T2 sources, old archives, or `runs/`. The
adapter is not included by `src/FusionConceptAI.jl`; it receives actual local
G1/G2 declaration records at runtime and does not embed a current upstream
hash. The JSON fixture is a contract description only and is not authority.

The current upstream state remains `G1/G2 repairs pending`; the three V1
declarations have not been formally accepted and no current source-backed
runtime records were available in this round. Therefore this package is
`prepare_only_runtime_input_adapter` and cannot final-freeze the parent
baseline. Present is conditional on both runtime records passing all checks.

## Implemented R2 contract

`PresentLocalParentBaselineBindingV1` retains actual source, declaration, and
semantic bytes with recomputed SHA-256, source locator, factory receipt bytes
and hash, exact candidate identity, layer/child identity, four axes, source
ref, declaration ref, and a derived parent-binding hash. Missing or
unreviewed material produces `AbsentLocalParentBaselineBindingV1` with
`typed_absent` / `terminal_deferred`; contradictory, duplicate, foreign,
stale, or tampered material returns `fail_closed` and no bundle. The closed
union is explicit in the source.

CAS replacement checks expected prior source-content and state hashes, then
revalidates the complete canonical state and replacement bytes before
publishing. Rejected operations return copied prior canonical bytes, hashes,
and history with `published=false` and `history_advanced=false`. Promotion
from absent to present is explicitly forbidden.

## Static execution receipt

Command:

`D:\Users\Newman\anaconda3\python.exe test/GenomeV5/Integration/static_qa_vnext_parent_baseline_binding_local_v1.py`

- UTC start: `2026-09-17T11:47:29.5181888Z`
- UTC end: `2026-09-17T11:47:29.5867967Z`
- PID: `5616`
- exit: `0`
- raw stdout: `552` bytes, SHA-256 `6e723db2fa75329b4f1b5bfbd245102bbfe939f4e24f9c7b66ab51405b08042b`
- raw stderr: `0` bytes, SHA-256 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`
- result: `checks=pass`, `check_count=78`, `passed=78`, `errors=[]`

Raw output is retained in `static_qa.stdout` and `static_qa.stderr`; the
receipt records the process-level raw hashes. No Julia, DESC, provider, mesh,
solver, or full regression command was invoked for R2.

Corrected final evidence JSON/trailing-whitespace/old-R1-hash validation was
run with PowerShell from the repository root at UTC
`2026-09-17T11:49:07.9213706Z`–`2026-09-17T11:49:07.9428570Z`, PID `42208`,
exit `0`; all three JSON files parsed, all scoped files had no trailing
whitespace, old R1 hashes were unchanged, and temporary files removed was
`0`.

## Product and preservation hashes

R2 product hashes (SHA-256):

- `src/GenomeV5/Integration/VNextParentBaselineBindingLocalV1.jl` — `55d2f60242af013b9b8f2ebb9874019f5d87906a01d0dd28fa03f1294fda2b98`
- `test/GenomeV5/Integration/vnext_parent_baseline_binding_local_v1_tests.jl` — `85c14a10cf89805806a7c1d11551a32012a61fb357ffbc910121af9fce4d1753`
- `test/GenomeV5/Integration/vnext_parent_baseline_binding_local_v1_fixture.json` — `61a169d8456c3d3437d62b1f633dcd25c7c43ffdec5cd094f26ed954689c51c3`
- `test/GenomeV5/Integration/static_qa_vnext_parent_baseline_binding_local_v1.py` — `b88c4e842ab0e9af234a567b6a277d56df0e378120646f156e7c5186cc35cc61`

The old R1 paths were read-only checked and remained at their prior hashes:
`feaa25406350f76c785fa02094af8744397874a94cfbd694360f310df41cb232`,
`6b90804eb7e973995291fe56c7419af6a52697cea54d66b347a7ea3beeedeb0a`,
`59aef733a1e140c9906a123cebe96fce1790418d6b17ee33de4b7db6d45d115b`, and
`81141251e7f5780776a1b2fd87ad77287de824d28871d0089df00b9317979aac`
(display spaces are not part of the hashes; see `evidence_manifest.json` for
the exact values).

## Cleanup and handoff

Created only `agent_local_r2/` evidence files; removed temporary files: `0`.
No process was left running. No commit was created. This work is ready for
parent review and later focused Julia execution only after the mainline
explicitly releases that gate and provides current runtime inputs.
