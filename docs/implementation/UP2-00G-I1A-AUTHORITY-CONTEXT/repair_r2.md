# G-I1A R2 bounded repair

R1 independent precheck was `changes_requested`.  This repair preserves the
R1 archive and changes only the owned G-I1A source/test/fixture plus this
archive.

The context now has explicit version/schema/canonicalization/compatibility
hashes.  Both slot forms expose `profile_hash` and
`compatibility_profile_hash`; slot position is checked exactly.  A typed E2
present slot is defined for a future source-valid mapping, while the actual A
baseline remains E2 absent/deferred because `n06_mapping_admission` reports
the missing dimensioned G1-to-G3 authority.

`gi1_validate_authority_context_schema` is self-consistency only.  The public
trusted overload takes actual `CandidateStatePackageV5`, E0, and optional typed
E1/E2 authorities, rebuilds the expected context through the source validators,
and rejects self-consistent foreign/stale contexts.  AD-26 admission values
are used; physical resolution and all downstream counters remain deferred/zero.

No Julia/DESC runtime was run.  R2 remains `review_pending` pending a new
independent Luna static precheck and later serialized focused run.
