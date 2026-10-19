# T2 R18 audit-predicate independent test

**Verdict: NO-GO for one bounded formal run under the requested fail-closed receipt contract.** No Julia was started.

The frozen protocol, controller, QA source and map hashes match the handoff. A fresh Python static QA rerun exited 0 (`pass_static_r18_r23_no_julia`, 30 negatives, 5 positives), but the independent receipt matrix found a gap the frozen QA does not cover.

The independent probe ran **49 scenarios at both the baseline and final trust boundaries**. The empty complete audit passed; nonempty process/controller/native/error lists, incomplete flags, missing top-level fields, malformed list fields, and basic snapshot schema/completeness/authority/row-count mutations were rejected. Synthetic process-table controls also passed: an empty table went through both gates; a table containing `julia.exe` was rejected by both.

**Ten malformed snapshot variants were accepted at both boundaries:** missing or wrong `host_identity`; missing or wrong `system_information_class`; missing or invalid `buffer_bytes`; missing or boolean `query_attempts`; and missing or malformed `raw_identity_digest_sha256`. Those are fields emitted by `_r23_snapshot_receipt` for schema `vnext-t2-r23-native-snapshot-receipt-r1`. The shared helper validates only snapshot schema, `complete`, identity authority, and positive integer row count, so the final audit can still report complete for these malformed receipts. R18 therefore needs a versioned repair or an explicit contract narrowing before this tester can grant a one-run GO.

Coverage did not change: the retry7 and R18 protocols pin the same 600,012-byte map (`7cb1c9ed…19db56`). Fresh QA reports 30 phases, 45 formal cases, 60 unique cases, 68 case hits, 214 sites, 622 planned site hits, and 175 relocation rows; authority remains 175 IDs/75 nonzero/118 hits and transport 23 IDs/92 hits. All 580 protocol inputs and 104 positive reuse pins rehashed with zero mismatch. Planned output remains absent and formal acceptance false.

Evidence preserves the initial successful subset probe, the tester-only `ticks` NameError from probe r2, the corrected r3 pass, and the expanded r4 failure. R2 was a test-harness defect; the substantive NO-GO is the r4 fail-open result.