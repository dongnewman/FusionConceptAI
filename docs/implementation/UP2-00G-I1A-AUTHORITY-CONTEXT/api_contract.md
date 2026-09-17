# G-I1A API and ownership boundary

Owned source: `src/GenomeV5/UP2/GI1AuthorityContextV1.jl`.

Public entry points are `gi1_authority_context_from_a(package, e0;
n05=nothing, n06=nothing)`, `gi1_validate_authority_context_schema(context)`
and the trusted `gi1_validate_authority_context(context, package, e0;
n05=nothing, n06=nothing)`.  The output is a fixed-order
`GI1AuthorityContextV1` containing the candidate/package state, G1/G2/G3
five-field refs and component hashes, four axes, complete E0 binding, E1 and
E2 typed slots, explicit context version/schema/canonical/profile hashes,
separate contract/physical statuses, gaps, errors, and zero downstream
counters.  Slot content hashes are recomputed from typed semantic bodies.

The schema-only validator checks internal identity and slot invariants.  The
trusted overload rebuilds expected context from actual A/E0 and optional typed
extensions, so a self-consistent forged context cannot receive source-bound
valid status.  Admission values follow AD-26: `declared_consistent`,
`fail_closed`, `terminal_deferred`, and `program_exception`.

`GI1N05PresentAuthoritySlotV1` stores the validated `UP2N05AuthorityV1`, its
package/E0 provenance, and N05 schema/canonical/profile hashes.  
`GI1AbsentAuthoritySlotV1` stores an explicit reason, gap tuple, projection
hash, schema/canonical/profile hashes, and A/E0 provenance.  E2 absence is
constructed from `n06_mapping_admission` and its projection hash; authored URI
or prose cannot manufacture an E2-present slot.  `GI1N06PresentAuthoritySlotV1`
is only a structured future path; the current A/N06 baseline does not produce
it and no physical authority is implied.

The implementation does not edit `UP2CandidatePhysicalBindingV1`, E0 v1,
N05, N06, G-I0, V4, shared loader, core indexes, or existing fixtures/runs.
