# Acceptance record for additive repair

## Decision

`review_pending`; implementation `not_implemented`; runtime `not_executed`; claim ceiling `manufactured_inverse_feedback/screen_only`; `formal_credit=none`.

This package closes the contract/documentation defects F1–F6 at the schema and evidence-boundary level. It does not accept the current M5/M5-A bytes and does not replay them. Historical R1 `accepted_limited` receipts remain historical-only and are not transitive to the current dirty checkout.

## Static acceptance

* Repair files are additive under this directory. The reviewed `01-scope-contract/**` directory remains untouched.
* Request, result, failure-record and taxonomy documents are executable Draft 2020-12 closed schemas. `additionalProperties=false`, exact-rational strings, fixed enums, array cardinality/order, and transition conditions are explicit.
* The canonical bundle is a hash-joined typed payload with complete G1/G2/G3, parent-baseline, mission, scenario and source identity. Source content/schema/owner/provenance and non-physical applicability are not optional.
* The current-byte gate records source drift and requires all M5/M5-A source/test/oracle/dependency snapshots to be freshly frozen, replayed in the isolated lane and independently reviewed before `ready`.
* Replay identity records canonical serialization, locale/timezone, environment fingerprint, seeds, ordering and attempt IDs. Any input or environment mutation requires a new freeze.
* Feedback operations are immutable-identity/CAS checked and append-only; only the registered deletion operation is admissible, with before/after hashes and owner/direction/UTC.
* Pre-existing dirty work is represented by a baseline digest; scope closure is incremental from that baseline and does not claim the whole worktree is clean.

## Not accepted / pending

No Julia, DESC, S3, mesh, solver, provider, hardware, network, source edit or test edit was performed. Fresh re-freeze, runtime replay, independent review and Sol/root disposition remain pending. No result may be labelled `credible`, `physical_pass`, `engineering_pass`, `provider_pass`, or formal gate closure.
