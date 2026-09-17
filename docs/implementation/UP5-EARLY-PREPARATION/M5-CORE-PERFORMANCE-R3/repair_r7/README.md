# M5 core performance R3 repair R7

R7 repairs the authority and receipt-path defects exposed by the R6
diagnostic.  A fresh receipt cache is not treated as the original derivation
owner: provenance validation now accepts legacy all-`nothing` owners and
sealed all-same owners, while rejecting mixed or differing owners.  Current
source/target/rule bytes, hashes, orientation, conditions, and chain checks
remain authoritative.

The cache-aware equivalence and saturation-attempt writers now pass the same
domain tags as their legacy writers, preserving byte identity.  Focused tests
cover legacy validation, mixed-owner rejection, cold/hot byte identity, and
the derived artifact/query/replay path.  Julia/DESC is not run in this lane.

Status remains `screen_only / performance implementation pending runtime`; the
factorial canonicalization root cause is unresolved.
