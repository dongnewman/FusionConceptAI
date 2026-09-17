# UP1 external-blocker closure R4 — root-decision draft independent review R2

Review date: 2026-09-17. This is a read-only independent rereview of the
repaired `20-root-decision-draft`; only this review directory is written.

## Decision

**`accept_draft`**.

The sole R1 documentation finding is closed. The Markdown finding table now
reports one row for each P2 item (`P2-001` and `P2-002`), while the JSON
reports `p2=2` with exactly those two items. The two representations therefore
agree on the P2 total and item identity.

## Checks

- `decision_draft.md` P2 rows: `2`; each row count: `1`.
- `decision_draft.json`: `counts.p2=2`; `p2_items` length `2`; IDs are
  `P2-001`, `P2-002`; both states remain `test_scope_deferred`.
- Draft hash manifest: both listed files match recorded byte lengths and
  SHA-256: Markdown `10218` bytes,
  `5dae64db6ac2f569df4bda6cf439993609b845b011393346b4ab9fe5cf20c303`;
  JSON `8598` bytes,
  `969ca171e7ba2219f5315a09f10bee204f78fed78899b2652bb0f103516283ce`.
  The manifest is self-excluded and its historical 48-file closure matches
  `19-final-full-regression/hash_comparison.json` (`before=48`, `after=48`,
  unchanged, no added/changed/missing files).
- JSON/Markdown decision tokens agree:
  `decision_draft_pending_root_acceptance`,
  `PASS_LIMITED / ACCEPT_FOR_LOCAL_INTEGRATION`, and
  `BLOCKED_NO_CREDIT`. Both contain 20 UP1 handoff stages with the same
  `UP1-00` through `UP1-19` ID set.
- The closure boundary has not drifted: external snapshot remains `26/26`
  typed absent with `usable_external_inputs=0`, no fresh delta, `new_ad=false`,
  and `s3_rerun=false`; local regression remains R3 `25 + 1 skipped` twice,
  R4 `98 passed + 2 skipped` twice, and static exit `0`.

## Boundary

The draft still grants only the split local-software disposition. It does not
grant external/formal credit, publication permission, T0/T1/T2, AD creation,
S3, network/Julia/DESC/heavy-lane execution, DAG or R01–R10 changes, or
parent-goal closure. P2-001 Windows reparse runtime and P2-002 R22
direct-wire acceptance remain explicitly deferred. No further change is
requested before root acceptance of the draft.

