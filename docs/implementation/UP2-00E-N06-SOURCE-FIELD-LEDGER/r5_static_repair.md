# E2-N06 R5 static repair evidence

Status: `review_pending`; no Julia/DESC run in this repair.

The public mutation API is now
`n06_validate_mutation(package, e0, projection, spec)`. It first rebuilds the
projection from the actual `CandidateStatePackageV5` and source-validated E0
binding, then compares candidate, component refs, E0 hash, G1 occurrence
keys, G1 closure, G2 region/boundary, selected G3 flow-link identity, typed
network fields, authority gaps, and projection hash. Detached projections and
foreign E0 bindings are rejected before mutation or receipt construction.

Mutation routing finds the unique field by the exact projection
`field_path`, validates its source locator and typed source type/value against
the actual package, and dispatches by the registered path/source shape plus
`mutation_kind`. The mutation id is retained only as a receipt label.
Fixture-backed controls cover relabeled ids, detached projection, foreign E0,
foreign-valid link, detached G1 occurrence, forged locator/type, and wrong
kind. The E0/N06 authority and all provider/compile/solver/physics claims
remain unchanged and unverified.

Frozen source/test/fixture/runner hashes are recorded in
`evidence_manifest.json`; R1-R4 historical receipts and independent
precheck archives are preserved. Static JSON parsing, plan validation,
owned-hash verification, and diff checking are required before the next
independent precheck. A serial focused run remains pending Sol release.
