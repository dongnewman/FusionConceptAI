# UP1 R2 witness-authority independent review R1

Decision: `rework` (accepted=false). Claim ceiling: contract/software
preparation only; `TEST_ONLY=true`, `non_evidence=true`, `no_publish=true`.

I reviewed only the frozen witness-authority implementation and its focused
tests/fixtures, with the witness contract, frozen interface contracts, threat
acceptance requirements, and review protocol as the independent criteria. No
implementation or pre-existing path was modified. The only writes are this
review directory.

## Fresh runs

- `python -B docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R2/reviews/01-witness-independent-review-r1/adversarial_review.py`: exit 0; PID and UTC metadata are in `raw/adversarial_review.stdout.raw`. Nine probes found five P1 boundary/replay defects and one P2 independence-proof gap. The probe is reviewer-owned and does not import the author's test module or read fixture `expected` fields.
- `python -B -m pytest -q test/up1_external_closure_r2/witness_authority/test_witness_authority.py`: exit 0, 8 passed; raw stdout/stderr and exit are retained. The green author suite does not cover the findings above.
- Fresh CLI duplicate-key attack: exit 2 with `ERR_INVALID_JSON`; raw stdout/stderr and exit are retained. This positive control confirms strict duplicate-key parsing itself works, but does not cure unknown-field acceptance.

## Findings

`WA-R1-001` is an unknown-field downgrade: unversioned root and nested
extensions are silently ignored and can reach `OK_SHAPE_ONLY`. `WA-R1-002`
admits a foreign witness scope by substring. `WA-R1-003` admits wrong-bound
signature/evidence references and malformed scalar signature/ack fields.
`WA-R1-004` leaves typed-absence requests out of the replay ledger, and
`WA-R1-005` cannot distinguish changed request bytes when the candidate object
digest is unchanged. `WA-R1-006` accepts a self-certified independence claim;
the no-publish/typed-absence ceiling prevents external credit but the shape
boundary is too permissive for the stated independence criterion.

The detailed paths, criteria, and required repairs are in `findings.json`.

## Hash and scope audit

The source hashes below were recomputed independently during this review and
match the implementation receipt for the five reviewed source/test files.
The review also hashes all four fixture inputs and the witness contract. The
reviewer did not run network, authority, provider, Julia, DESC, solver, mesh,
or heavy numerical work.

The implementation/test tree was already untracked in the shared dirty
worktree; this review did not infer cleanliness from Git status. All review
artifacts are confined to `reviews/01-witness-independent-review-r1/**`.
