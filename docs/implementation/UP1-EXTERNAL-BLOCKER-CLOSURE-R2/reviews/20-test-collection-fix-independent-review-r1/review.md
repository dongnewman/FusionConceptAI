# Independent review: UP1 R2 test collection fix R1

## Decision

`pass_limited` for the narrowly declared pytest collection-infrastructure
slice. No P1/P2 finding was identified within this review scope. This review
does not grant production authority, publishability, UP1/R01-R10 credit, or
physical/engineering readiness.

## Scope and source boundary

The claimed repair is limited to
`test/up1_external_closure_r2/witness_authority/test_witness_authority.py`.
The current source uses the unique production namespace
`tools.up1_external_closure_r2.witness_authority.validator`; the preceding
short import is reproduced in the retained pre-fix raw failure, where pytest's
`test/` path caused the test package `up1_external_closure_r2` to shadow the
production package and collection raised
`ModuleNotFoundError: No module named 'up1_external_closure_r2.witness_authority.validator'`.
The surrounding test body and production validator are unchanged in the
reviewed source boundary; the production validator hash also matches the
previous independent witness R3 source record.

The correction is test-only: it changes import resolution and adds explanatory
commentary, with no production implementation or authority/publish semantics.

## Independent execution

Serial fresh runs of the exact acceptance command, with empty `PYTHONPATH` and
`PYTEST_ADDOPTS`, both passed:

```text
python -B -m pytest -q test/up1_external_closure_r2
```

- independent R1: exit 0, 148 passed, 3 skipped
- independent R2: exit 0, 148 passed, 3 skipped

The two process receipts and stdout/stderr streams are retained under `raw/`.

## Matrix and skip boundary

The supplied ten-component matrix has all exit codes zero and sums to 148
passed and 3 skipped. The independent `-rs` check reproduced all three skip
reasons: two authority-intake Windows junction/symlink capability boundaries
and one revocation symlink capability boundary. These are explicitly
`test_scope_deferred` conditions, not promoted passes.

## Historical failure and manifest

The two pre-fix exit-2 collection failures remain retained as
`raw/prior_failure_fresh_r1.*` and `raw/prior_failure_fresh_r2.*`; their output
contains the short-import `ModuleNotFoundError`. The reviewed 20-slice manifest
has 47 declared files, and an independent exact-set and bytes/SHA-256 check
returned 47/47 with no missing, extra, or mismatched file. The declared source
file is 15,909 bytes with SHA-256
`eafc0914e4fed0f23561f4c3ff3e7120c3e6f174530ab3725b80224531f57e29`, matching
the current file.

## Limitations

This is a collection/test-infrastructure review only. The workspace contains
pre-existing broad dirty/untracked work, so repository-wide cleanliness is not
used as an acceptance condition. No heavy lane, network, Julia, S3, DESC,
solver, external authority, installation, or production mutation was used.
