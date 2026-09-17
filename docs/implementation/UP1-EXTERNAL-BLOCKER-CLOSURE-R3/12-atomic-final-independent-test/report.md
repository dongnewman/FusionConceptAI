# UP1 R3 atomic prototype — final independent test

## Verdict

`fail_limited`. This is an offline, local software/prototype test only:
`formal_credit=none`, `authority_credit=false`, `no_publish=true`. No network,
external send, AD/S3, Julia/DESC, solver, credential, or production lane was
used. The implementation and existing test files were hash-frozen and were not
modified; only this `12-atomic-final-independent-test/` directory was written.

## Focused rerun

Command:

    python -B -m unittest discover -s test/up1_external_closure_r3/atomic_bundle -p test_*.py

Two serial runs exited 0 and each reported `Ran 23 tests ... OK (skipped=1)`.
The skip is the host privilege-limited symlink/reparse creation probe. Raw
stdout/stderr/combined receipts and PID/UTC/hash data are in `raw/` and
`manifest.json`.

## Independent P1 checks

The independent probe (`independent_final_probe.py`, PID 112144, UTC
`2026-09-17T00:49:07.306042Z`, exit 0, stdout SHA-256
`46c5190639a9177f3f8344ec8cd6e10d0be76704d3ce6715457cf74842829164`) produced
12 passing records and one failing record.

- EHP-04 passed for a pinned artifact root: runtime bytes, SBOM bytes, binary
  bytes, and download-receipt bytes were read locally and their SHA-256 values
  recomputed. An outside-root runtime was rejected with
  `EHP04_RUNTIME_ARTIFACT_UNAVAILABLE`; omitting the root rejected claims with
  `EHP04_ARTIFACT_ROOT_REQUIRED` and unavailable-material codes.
- CAS checks passed for an existing hardlink (`CAS_HARDLINK_REJECTED`), a
  different-byte collision (`CAS_COLLISION_FAIL_CLOSED`), and equal-byte replay
  idempotence.
- G2 passed for independent directional row hashes/inverse binding; inverse
  issuer tampering produced `EHP03_G2_REF_MISMATCH`.
- The R3 registry exactly matched `bundle.ERROR_CODES` (82/82) and included
  `DECISION_NOT_BOUND_TO_QUARANTINE`. An unknown internal code was preserved and
  forced `rejected_all` with `no_publish=true`.
- Decision precedence passed: a real predicate error rejected before
  `not_executed` deferral, while a clean `not_executed` result was
  `terminal_deferred`. The TEST_ONLY receiver receipt was classified
  `TEST_ONLY_NON_EVIDENCE`.

## Limiting failure: 26 mutation vectors

All 26 named builders have distinct explicit mutation paths and distinct raw
SHA-256 values. However, replaying each builder through `validate_bundle`
showed that only R01 and R23 hit their intended preparse/schema code. R02–R22,
R24–R25 and D01 all returned `rejected_all` with only `SCHEMA_INVALID`, instead
of their matrix-bound semantic code/decision (including R22/R24 deferral and
R25's internal acceptance-shaped expectation). This is the exact forbidden
uniform-schema outcome, so the mutation-coverage P1 remains open despite the
focused suite passing.

The complete per-vector observed codes, decisions, paths, and raw hashes are in
`raw/independent_final_probe.stdout.raw`; the implementation/test freeze is
in `hash_check.json` and `manifest.json`.

## Boundary

No formal, authority, engineering, physical, external-owner, or publication
claim follows from this result. The next repair must provide a schema-valid
baseline envelope (or direct semantic harness) so each R02–R25/D01 mutation
reaches its own expected predicate and decision, then rerun this independent
test without changing the frozen scope during verification.
