# E1 N05 acceptance

Status: local `accepted_limited` for actual-A/E0 source-bound receipt export plus positive/seven-forged file-read verification; full receipt-export `changes_requested`; `accepted=false` for the full gate.

Source, test, fixture, and runner are prepared in disjoint E1 paths. Focused R1 was executed serially and is preserved as a failed test-harness attempt (`exit=1`, 8 assertions passed, 1 error); the only defect was the test's use of nonexistent `UP2N05AuthorityV1.status` instead of `resolution`, with no source acceptance claim. Acceptance still requires a fresh serial focused run with actual A package construction, fixture-driven five mutation receipts, zero compile/provider/solver calls, immutable stdout/stderr/exit/environment hashes, and independent Luna review.

The intended software ceiling is contract-only: an authored declaration may reach `contract_ready` after exact source joins. The declaration must carry a typed authored law expression/relation and separate N05 flux-unit provenance; G1 occurrence units, G2 normals, and pending-port values are not flux authority. Missing N05 authority remains `terminal_deferred`; typed conflicts are `invalid_closure` or `invalid_type` with `fail_closed`; unexpected checker faults retain `program_exception`. No N05 physical, mesh, provider, engineering, B00/B04, or R01-R10 credit is claimed.

The R2 static repair requires each mutation to validate the unmutated authority against the supplied E0 binding before emitting a receipt; foreign or stale authority/source joins therefore fail without a formal mutation receipt. G1 endpoint locators join actual `G1LedgerOccurrenceV2` values by the unique four-field key `(equation_id, port_side, port_index, ledger_id)`, and the authored locator carries a canonical path including side and ledger. Duplicate keys fail closed.

The five authored mutation receipts are dispatched by registered typed field path and mutation kind, with canonical source path/type checks; receipt labels and expected classes remain test oracles and do not route production classification. The same five rows against an absent declaration produce deferred authority-gap receipts with unchanged placeholder values and zero downstream calls; they do not fabricate authored values.

Focused R2 was executed with the frozen R2 static snapshot and is preserved as a real `exit=1` failure: the authored declaration test recorded 19 passes and 2 failures because both `up2n05_validate` and the authority result were `program_exception` rather than `valid`/`contract_ready`. Static diagnosis identifies the Julia 1.10-incompatible `first(generator, nothing)` interface lookup in `_n05_authority_errors`; the repair replaces it with cardinality-aware lookup and adds a duplicate-interface regression. Side-symbol error formatting is also made fail-closed-safe. A fresh independent static R4 review is required before any further focused run; no R2 result is acceptance evidence.

Focused R3 then closed the interface program exception: baseline was 9/9, absent-authority mutations 30/30, authored exact joins 22/22, and the mutation set reached 57 passes with 2 failures. The two failures were oracle mismatches for foreign endpoint references, which were classified `invalid_type` because secondary `flux_unit_source_*` errors were given priority over the primary endpoint-reference closure contradiction. The static repair now prioritizes observed endpoint-ref/port/sign/interface errors as `invalid_closure` and reserves `invalid_type` for genuine unit contradictions; targeted ref and unit regressions cover both paths. A fresh independent static R5 review is required before another focused run.


Focused R4 completed with the frozen source/test/fixture/runner inputs: real exit 0, all seven listed groups passed (9/9, 30/30, 22/22, 61/61, 7/7, 3/3, 1/1), stderr was empty, and the post-run Julia/DESC sweep was empty. The immutable receipt is `focused_r4/receipt.json`; stdout/stderr hashes and PID/timestamps are recorded there and in `evidence_manifest.json`. This is contract-test execution evidence only; the subsequent independent R3 review leaves the full receipt-export gate `changes_requested` while allowing only the limited local scope recorded below. No provider, mesh, engineering, physical, B00/B04, or R01-R10 credit is granted.

## R3 limited status synchronization

The independent R3 post-run review accepts a limited local scope only:
source-bound serialization positive file-read evidence for the ten-row envelope,
with the recorded `316/316` focused assertions, zero downstream counters, and
protected input receipts. The same review returns `changes_requested` for the
full receipt-export gate because forged and omitted controls were not serialized
to new files and re-read through a file-read trusted checker path; the checker
and exporter also share `_n05e_row`. The local limited record therefore does not
promote the full export gate or formal B04. R1/R2 failures remain immutable,
and the R3 verdict is at
`independent_postrun_r3/verdict.json`. All provider, mesh, engineering,
physical, B00/B04 and R01-R10 claims remain false.

## R5 receipt-export status synchronization

The focused R5 receipt-export run is preserved with real exit `0`, N05 `24/24`, empty stderr, wrapper PID `53928`, Julia PID `56492`, UTC `2026-09-14T06:04:56.2585284Z`–`2026-09-14T06:05:55.3162399Z`, protected before/after equality, and an empty postflight process sweep. The serialized envelope contains five actual-A/E0 source-bound authored typed rows and five absent-authority rows; independent postrun R5 rechecked source refs/hashes/types, typed canonical value and mutation hashes, field/error paths, and deferred/failed-closed classifications.

The local limited scope now includes the seven serialized forged files and their file-read rejection records: source hash, absent mutation hash, candidate ref, package hash, E0 binding hash, declaration hash, and omitted authored row. Their bytes/SHA, single target changes, and targeted errors were independently rechecked. The focused executor artifacts and independent R5 report/manifest are retained under `receipt_export_focused_r5/` and `independent_postrun_r5/`.

The formal/full receipt-export gate remains `changes_requested`. The trusted checker expected-row recomputation still shares exporter helper `_n05e_row`, and no separately audited checker/two-process independence boundary is present. This is the formal B04 independence boundary; it does not remove the local actual-A/E0 source-bound serialization/file-read evidence. Provider, mesh, engineering, physical, B00/B04, and R01-R10 claims remain false.
