# W4 local-input discovery — independent review R2

Conclusion: `rework_required`  
Claim ceiling: `discovery_only/preparation_only`  
Formal credit: none

## Scope and method

This review was read-only over the repository at `D:/006-Programing/LMC/FusionConceptAI`, with `.git` and the discovery output tree excluded from the original scan universe. No home directory, credential store, network, or candidate content was opened. The independent checks parsed the metadata inventories and registers, enumerated repository paths, recomputed file existence, byte length, and SHA-256, and compared the recorded raw/receipt hashes. Suspected-secret detection used path/extension rules only; no sensitive content was read.

## What independently passes

- The original metadata raw has PID `21104`, exit `0`, 2,851 JSONL records, and its recorded SHA-256 matches. The partition is exact: 1,904 candidates + 947 excluded = 2,851 hits.
- Every candidate and excluded path exists, remains inside the repository, and has no duplicate path. All records have the required metadata types; all candidate and excluded promotion flags are false.
- AD-44 (51), AD-45 (61), AD-55 (200), and AD-56 (73) path hits are represented in the candidate inventory; none is omitted from the two-way partition or promoted to authority. Their local/historical nature is preserved by the authority classifications.
- The explicit repository path scan covered 9,074 paths and found zero high-risk secret/key filename or extension hits. Therefore no sensitive path required opening or redaction.
- The W1/W2/W3 crosswalk is lossless and independent: 10 + 11 + 5 = 26 unique source IDs, with matching register counts, source-register hashes, zero duplicate IDs, `changed_inputs=false`, `new_real_inputs=[]`, and `no_upstream_register_mutation=true`.
- The source package manifest has 34 files, and the current source file set matches it exactly. The `archive/pre_repair_r1` set is retained. Existing validator PID `62980` has exit `0`; stdout, stderr, and combined raw hashes match its validation receipt. JSON uniqueness/parse checks passed.

## Blocking finding

Independent hash/byte recomputation found two stale records in the 1,904-entry candidate inventory:

1. `source_g2_environment/manifest.json`: recorded 4,814 bytes / `0ffeb65a...94fb85`; current 5,032 bytes / `0f7d8710...02216f`.
2. `source_g2_environment/static_validator.py`: recorded 9,448 bytes / `5529ac71...e26bef`; current 9,998 bytes / `ff19dba5...072c163`.

Both paths exist and remain non-authoritative, but the inventory contract requires exact metadata. The prior validator’s self-reported pass cannot override this independent mismatch. The discovery package therefore does not yet prove a current, integrity-closed global no-input result.

## Required repair

Refresh the W4 metadata inventory/manifest hashes with a bounded repository-only scan, or explicitly bind the two post-scan changes as typed drift while retaining the old raw. Re-run the independent existence/byte/hash/type/promotion validator and preserve PID/UTC/exit/raw/hash evidence. No source, AD, upstream register, credential, external authority, or new AD should be created.

The result does not grant UP1, T0, B00, B04, R, L4, or parent-goal credit.
