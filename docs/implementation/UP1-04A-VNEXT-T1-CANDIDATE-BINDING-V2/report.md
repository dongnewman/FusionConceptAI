# Static implementation report

Implemented a definition-only V2 candidate-binding contract with fixed domain,
schema, and version. The input is explicit and immutable: candidate reference,
candidate digest, source-package hash, and optional V2 canonical wire.

The static matrix covers exact binding, both wire-absence directions, absent
observation, foreign reference, candidate digest mismatch, source-package hash
mismatch, wire tampering, identical duplicates, and conflicting duplicates.
It also covers reference version and case mismatches, cross-field tampering,
path-like alias attempts, id/version cross-splicing,
constructor attempts with altered envelope/reason/count/hash, and fixed
decision precedence. A fixed independent canonical receipt golden locks the
domain-separated hash, while a stable replay line exposes schema, version,
status, candidate digest, wire hash, and receipt hash for a later runner.
The independent Python oracle recomputes the fixture wire SHA-256 and the core
classification matrix without importing Julia.

No Julia or DESC process was started. Production integration, a verified-package
adapter, independent Julia replay, T1 admission, and UP1 credit remain absent.
The claim ceiling is `contract_only`, `accepted=false`.
