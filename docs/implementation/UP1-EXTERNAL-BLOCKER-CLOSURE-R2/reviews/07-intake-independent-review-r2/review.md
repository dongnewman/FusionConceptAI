# UP1 R2 authority_intake independent attack review

Decision: **rework** (`P1_reparse_toc_tou_remains`). This review is software
only and retains the claim ceiling `software_bookkeeping_only`; it does not
claim an external endpoint, authority, signature, trust root, or UP1/T0/T1/T2
credit.

## Validation and artifact integrity

Fresh focused validation:

```text
python -B -m unittest discover -s test/up1_external_closure_r2/authority_intake -p 'test_*.py' -v
```

Exit 0: 15 test cases ran, 14 passed, and 1 symlink test skipped because normal
Windows symlink creation is unavailable. The executable Windows Junction/reparse
substitute passed for the pre-use case. All 13 entries in the author manifest
match current byte counts and SHA-256 values; both retained raw stream files
match the raw record exactly, with raw exit code 0. Independent attack output
is preserved in `raw/attack_matrix.json`.

## P1 finding

### P1-1 — reparse/Junction replacement remains possible between validation and use

The returned source and CAS paths are checked, then used in later operations
without an atomic directory-handle/no-follow guarantee:

- Input: `adapter.py:236-267` calls
  `_assert_no_symlink_components(candidate_absolute, ...)`, then calls
  `candidate_absolute.resolve(strict=True)`. A fresh deterministic TOCTOU
  harness inserted `incoming -> outside` Junction after the guard and before
  resolve; intake returned `accepted_local` for the outside envelope.
- CAS: `adapter.py:462-467` checks `cas_path`, then calls
  `_atomic_cas`. A harness replaced `root/cas` with an external Junction
  between those operations; intake returned `accepted_local` and wrote one
  CAS JSON under the external target.

The pre-existing Junction checks are now effective: creating Junctions for
`incoming`, `quarantine`, `receipts`, `state`, or `cas` before adapter
initialization yields `spool_reparse`. The remaining race is nevertheless a
boundary bypass and output escape under an attacker who can mutate the spool
during intake, so it blocks `pass_limited`. Fix by using OS primitives that
bind the validated directory/file handles and no-follow semantics across the
entire operation, or revalidate authoritative file identities after each
operation under an exclusive spool lock that also covers path-component
replacement. Apply the same treatment to receipt/quarantine/ledger writes.

## R1 regression matrix

All previously reported R1 issues were rechecked:

- Absolute input path: rejected as `absolute_path`; `..` traversal rejected.
- Hardlink: feasible and accepted as a regular alias with the same inode;
  no pathname escape was observed and this is not a traversal finding.
- CAS wrong-digest replacement: structured `cas_collision` quarantine and
  receipt.
- Missing CAS on duplicate: structured `cas_missing` quarantine; no
  duplicate result.
- Oversize: explicit receipt with `raw_unavailable=true`,
  `quarantine_copy=not_attempted`, bounded source-size details.
- Cross-process concurrency: different channels retain both entries; same
  idempotency yields one acceptance plus one duplicate; sequences 1 and 2
  retain both entries. Same-sequence replay has one acceptance and one
  `sequence_replay`.
- External signature input cannot masquerade as authority:
  `signature=null`, `external_signature_state=not_verified`,
  `external_endpoint_state=typed_absence`,
  `external_authority_claim=false`, and
  `local_bookkeeping_only=true`.

## Acceptance gate

Status remains `rework`, not `pass_limited`, solely because P1-1 is
reproduced. Re-run the fresh matrix after closing the reparse TOCTOU window;
require all 13 manifest/hash/raw checks to remain exact and preserve the
external claim ceiling.
