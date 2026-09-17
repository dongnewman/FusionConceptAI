# M5 core performance R3 repair R9

R9 corrects a focused-test expectation exposed by the R8 diagnostic.  The
cache-aware rule-set writer intentionally re-canonicalizes each current rule
and does not read `cache.rule_bytes`; therefore a forged rule hint in that map
must be unused and receipt bytes must remain identical to a clean receipt.

The test now uses the artifact-owned rule object for the forged unused hint and
asserts clean/hot attempt byte identity.  It also inserts a forged hint under
an equal-by-canonical-bytes but non-identical external rule object and asserts
the same `IdDict` isolation.  The earlier direct `_ceg_cached_rule_bytes`
forged-entry negatives remain the authority-rejection coverage when the hint
is actually read.

No product code was changed for this repair.  Julia/DESC is not run in this
lane.  Status remains `screen_only / performance implementation pending
runtime`; factorial root cause remains unresolved.
