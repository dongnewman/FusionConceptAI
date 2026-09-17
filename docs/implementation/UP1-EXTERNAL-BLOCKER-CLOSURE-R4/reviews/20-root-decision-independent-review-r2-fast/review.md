# UP1 external-blocker closure R4 — root-decision draft fast independent rereview R2

Review date: 2026-09-17. This is a read-only rereview of
`20-root-decision-draft`; only this fast-review directory is written. The
draft files were not modified.

## Decision

**`accept_draft`**.

The R1 documentation finding is closed. The Markdown finding table now has
exactly two P2 rows, `P2-001` and `P2-002`, with `count=1` on each row. The
JSON has `counts.p2=2` and exactly two `p2_items`, with the same IDs. The two
representations agree.

## Required checks

- Markdown P2 rows: `2`; row counts: `1, 1`; total: `2`.
- JSON: `p2=2`; `p2_items` length `2`; IDs `P2-001`, `P2-002`; both remain
  `test_scope_deferred`.
- `hash_manifest.json` lists exactly `decision_draft.md` and
  `decision_draft.json`. Both recorded byte lengths and SHA-256 values match
  the current files: Markdown `10218` bytes,
  `5dae64db6ac2f569df4bda6cf439993609b845b011393346b4ab9fe5cf20c303`;
  JSON `8598` bytes,
  `969ca171e7ba2219f5315a09f10bee204f78fed78899b2652bb0f103516283ce`.
- The draft remains `decision_draft_pending_root_acceptance`, with software
  `PASS_LIMITED / ACCEPT_FOR_LOCAL_INTEGRATION` and formal/external
  `BLOCKED_NO_CREDIT`.

## Boundary check

The conclusion boundary is unchanged: the external snapshot remains `26/26`
typed absent with `usable_external_inputs=0`, no fresh delta, `new_ad=false`,
and `s3_rerun=false`. P2-001 Windows reparse runtime and P2-002 R22
direct-wire acceptance remain deferred. Formal credit, authority credit,
publication, T0/T1/T2, network/Julia/DESC/heavy-lane execution, new AD, S3,
DAG/R01–R10 changes, and parent-goal closure remain disallowed or false.
No further documentation change is requested before root acceptance.

