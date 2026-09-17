# G-I1A R2 repair note

R1 was `changes_requested` by the independent Luna review.  The bounded R2
repair remains within the original G-I1A source/test/fixture/runner boundary.

Implemented changes:

1. `GI1AuthorityContextV1` now stores explicit `context_version`,
   `schema_hash`, `canonicalization_hash`, and
   `compatibility_profile_hash`; these fields are part of the canonical
   context identity body.
2. Every E1/E2 slot stores both `profile_hash` and the explicit
   `compatibility_profile_hash` mapping.  Slot positions are checked as E1/E2
   at the context boundary.  A typed `GI1N06PresentAuthoritySlotV1` is
   available for a future source-valid N06 mapping; current A remains E2
   absent/deferred.
3. AD-26 admission values are used.  The schema-only validator is named
   `gi1_validate_authority_context_schema`; the trusted overload accepts actual
   package/E0 and typed E1/E2 inputs, rebuilds expected context through source
   validators, and rejects self-consistent foreign/stale contexts.  Unexpected
   faults remain `program_exception` in the trusted result.
4. Fixture consumption now covers metadata, slot swap, component hash, axis,
   and typed E2-present control IDs in addition to the A/E0 E1-present,
   E1-absent/E2-absent, and stale/foreign controls.

The current A package has no valid dimensioned N06 mapping, so no E2-present
positive case is claimed.  No Julia/DESC was run; R1 evidence remains
immutable and R2 remains `review_pending` pending independent static review.
