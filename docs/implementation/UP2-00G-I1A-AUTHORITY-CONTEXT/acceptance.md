# UP2-00G-I1A additive authority context

Status: `accepted_limited`; `accepted=true` (local actual-A authority-context software contract only).

This bounded implementation adds `GI1AuthorityContextV1` and two typed slot
forms.  The factory consumes an actual `CandidateStatePackageV5` and a
source-validated `UP2CandidatePhysicalBindingV1`.  It copies and rechecks the
three outer five-field `GenomeContractRef` values, component hashes, four
version axes, package state, and the complete E0 binding.  The context identity
hash includes those values and both extension slots.

The context now carries explicit `context_version`, context schema,
canonicalization, and compatibility-profile hashes.  Every E1/E2 slot carries
both its source `profile_hash` and explicit `compatibility_profile_hash` and
binds them equal in its independent content hash.  Slot position is checked
(`E1` then `E2`), and a typed `GI1N06PresentAuthoritySlotV1` exists for a
future independently validated N06 mapping; the current A package still
produces only E2 absent/deferred.

An E1 slot is present only after `up2n05_validate` succeeds against the same
package and E0 binding.  E2 absent is derived from
`n06_mapping_admission(package, e0)`: its projection hash and authority gaps
are retained, with N06 schema/canonical/profile hashes.  The current A package
does not provide an authoritative dimensioned G1-to-G3 law, so E2 remains
`terminal_deferred`.  No E0 v1 field is mutated and the original package hash
is never rewritten.

`contract_admission` uses the AD-26 values `declared_consistent`,
`fail_closed`, `terminal_deferred`, and `program_exception`; it is separate
from `physical_resolution`, which remains `terminal_deferred`.  The trusted
validator accepts actual package/E0/N05/N06 inputs and rebuilds the expected
context; the one-argument validator is explicitly schema-only.  Foreign or
stale E0/N05 identity, altered slot content, and a forged context hash are
fail-closed, while unexpected checker faults remain program exceptions.  The
fixture names are used only to ensure every control is exercised; runtime
status is derived from source validation and identity checks rather than labels.

The serialized `focused_r2` run exited 0 with GI1A 79/79, and independent
`independent_postrun_r2` review passed limited scope. This record accepts only
the source-bound E1-present/E2-absent, both-absent, typed E2 synthetic
schema/admission, taxonomy, tamper and zero-downstream-counter software
contract evidence. It does not accept a real dimensioned E2 source law,
unified N01–N10/50-row, G-I2, formal B04, provider, mesh, engineering,
physical, or R01–R10 credit.
