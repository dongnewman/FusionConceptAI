# UP1-04A-VNEXT-PARENT-BASELINE-BIND-PREC independent postrun R1

## Verdict

`changes_requested` for the limited software acceptance record. The typed-absent implementation and final focused result are acceptable as a local scaffold, but the append-only cleanup evidence no longer covers the current archive manifest: `cleanup_inventory_after_final.json` records `manifest.json` as 5433 bytes with SHA-256 `f37753ed901c9729047fbfe14637c18b8b640b073192ee73a45a71f173b19bee`, while the current file is 5774 bytes with SHA-256 `736772df282fad2cf88a166426789efa72d017615e2b4fedeb222415d362e78a`. Its current UTC write time is later than the final cleanup receipt. A fresh manifest-stable cleanup inventory is required before limited acceptance can be independently closed.

This is an evidence/provenance blocker. It does not change the observed R5 software result. No Julia or DESC process was running during this review, and no Julia/DESC command was launched by this review.

## Reviewed inputs and recomputed hashes

The delivery files were rehashed with SHA-256 and match `cleanup_inventory_before.json` and the manifest for the four implementation inputs:

| path | bytes | SHA-256 |
|---|---:|---|
| `src/GenomeV5/Integration/VNextParentBaselineBindingV1.jl` | 26420 | `feaa25406350f76c785fa02094af8744397874a94cfbd694360f310df41cb232` |
| `test/GenomeV5/Integration/vnext_parent_baseline_binding_v1_tests.jl` | 6430 | `6b90804eb7e973995291fe56c7419af6a52697cea54d66b347a7ea3beeedeb0a` |
| `test/GenomeV5/Integration/vnext_parent_baseline_binding_v1_fixture.json` | 781 | `59aef733a1e140c9906a123cebe96fce1790418d6b17ee33de4b7db6d45d115b` |
| `test/GenomeV5/Integration/static_qa_vnext_parent_baseline_binding_v1.py` | 3703 | `81141251e7f5780776a1b2fd87ad77287de824d28871d0089df00b9317979aac` |

The reviewed archive README and acceptance hashes also match their recorded values. The current archive manifest is valid JSON and retains `accepted=false`, `acceptance_state=review_pending`, `local_scaffold_status=accepted_limited`, `present_authority=unavailable`, and all provider/mesh/physical/actual/search/R01-R10 credits false.

## Static QA and Python receipt audit

All three embedded static QA receipts report exit 0, `checks=pass`, and `38/38` checks with an empty error list. Recomputed UTF-8 output hashes and byte counts match every receipt:

- `static_qa_run_r1.json`: PID 39160, UTC `2026-09-15T04:13:21.0060531Z`, stdout 760 bytes / `38a5ce768d42aee4c0138bcaef17502d0ab729524a7194d2d52cc5aba282e930`, stderr 0 bytes / `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.
- `static_qa_run_r2.json`: PID 71172, UTC `2026-09-15T04:18:02.0482553Z`, same verified output hashes and byte counts.
- `static_qa_run_r3_final.json`: PID 72248, UTC `2026-09-15T04:20:19.3617781Z`, same verified output hashes and byte counts.

The receipt interpreter is `D:\Users\Newman\anaconda3\python.exe`, recorded as Python 3.13.5. The executable exists; its recomputed SHA-256 is `388fe2cffda8a134e7d7dc4e978f7c478857ece6b69694daecbed25e51ec633a`, matching all three receipts. The receipts carry the input scope, but no separate raw stdout/stderr files or per-receipt input hash fields exist; the embedded streams and their hashes were checked directly.

## Julia receipt audit

No Julia command was run for this review. Every existing receipt embeds stdout/stderr and hashes; recomputation from the embedded UTF-8 streams matched all eight recorded stream hashes.

| receipt | PID | exit | observed result | stdout bytes / SHA-256 | stderr bytes / SHA-256 |
|---|---:|---:|---|---:|---|
| `julia_test_run_r1.json` | 49248 | 1 | 49 pass, 3 fail; absent-state canonical SHA and failure prior SHA were wrong | 2639 / `cbef9c24fbf946d8415d5b56d10acec45140fd3fc3462f4caa71178b526f2c56` | 220 / `9994231ded0afe9b4056805009924ce11726d7cfeb43d48592411daee5eca4e9` |
| `julia_test_run_r2.json` | 65812 | 1 | Same 3 failures, retained | 2639 / `dfd4d0fcd643851b6c19366387902a121e64868a50797774a885ad5ebde28e00` | 220 / `9994231ded0afe9b4056805009924ce11726d7cfeb43d48592411daee5eca4e9` |
| `julia_test_run_r3_debug.json` | 69716 | 1 | Same failures with debug showing stored canonical SHA length 0 | 2871 / `3d88f357299ecf6a3f4c77a3b178c2e7c4de1273f3079192cad4a2e6ed747d4f` | 220 / `9994231ded0afe9b4056805009924ce11726d7cfeb43d48592411daee5eca4e9` |
| `julia_test_run_r4.json` | 56696 | 1 | Same 3 failures, retained | 2639 / `bda29678debcbe21fe1b6e454c631ce156d517db73592644d103caf7f9bfce86` | 220 / `9994231ded0afe9b4056805009924ce11726d7cfeb43d48592411daee5eca4e9` |
| `julia_test_run_r5.json` | 69656 | 0 | `52 pass, 52 total`; typed-absent scaffold pass | 235 / `8ae4ef04b4763ac690ae5a7d007966e5f8509f941fd7dab4cfa45011d6c0c3ff` | 0 / `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |

The Julia interpreter is consistently recorded as Julia 1.10.5 at `C:\Users\Newman\AppData\Local\Programs\Julia-1.10.5\bin\julia.exe`, SHA-256 `8e86e2d48c574393c37bbfb6e922ea4176ba8e1a83f956826f3da24948e389ad`. Each receipt's process snapshot is empty after completion. The four failing receipts remain append-only evidence and were not overwritten.

## Static semantic review

The source is additive and excluded from `src/FusionConceptAI.jl`; the static receipt confirms the shared entry was not changed. The public constructors currently produce only `AbsentParentBaselineBindingV1`, `AbsentChildKeyV1`, `TypedAbsentSourcePayloadV1`, `terminal_deferred`, and an empty operation history. Absent records contain requested candidate/public contract identity, layer, reason, and domain-tagged digests, while omitting actual parent refs, parent declaration/baseline hashes, source locators, factory receipts, and present binding hashes.

The source recomputes the child contract identity, parent absence digest, child-key digest, canonical bytes SHA, state hash, and source-content absence digest using explicit domain strings. `verify_absent_parent`, `verify_absent_child`, and `verify_absent_state` rederive these values. The focused tests cover G1 and G2, G2 public-contract equality, wrong-layer/foreign-candidate rejection, fixture/ref-only/synthetic/foreign present-admission rejection, and the unavailable source-backed receipt path.

`replace_source_payload` returns a rejected `baseline_authority_absent` receipt for the absent state. The R5 tests verify no publication, no history advance, unchanged canonical bytes and SHA, unchanged state hash, and unchanged history. `promote_absent_to_present` is explicitly forbidden. The failure receipt carries the prior canonical bytes and digest. No mesh, provider, boundary, solver, physical, or engineering execution is present.

A private source-backed receipt and present binding type exist as future seams, but the public admission overload remains unavailable and no real source-backed V1 declaration instance or factory receipt is present. Therefore present G1/G2 child publication remains blocked; this implementation cannot be credited as a present child, machine acceptance, T0/T1/T2, or any physical/R result.

## Process, dirty-worktree, and cleanup audit

The archived process receipt says PID 66044 was already absent, so no termination was issued; protected PIDs 65224 and 58068 were listed, and the final Julia/DESC snapshot was empty. The before/after inventories report no attributable temporary files, no removals, and preservation of historical failure receipts. Existing unrelated dirty/cache paths were explicitly left untouched. The current implementation inputs still match the before inventory.

The remaining cleanup defect is the manifest drift described at the start: the final inventory covers an older manifest hash/length, while the current manifest has a later write time and a different hash/length. The exact owned set therefore cannot be independently certified for the current archive state. Minimum repair is a new cleanup inventory after the manifest is stable, including the current manifest hash/length and the same protected-process/no-temporary-file evidence. No Julia/DESC rerun is needed.

## State boundary

This independent review leaves `review_pending=true` and `accepted=false` for the machine node. Even after the cleanup receipt is repaired, any acceptance is limited to the local typed-absent software scaffold. Present authority, present G1/G2 children, T0/T1/T2, provider, mesh, physical, engineering, search, and R01-R10 credits remain false.
