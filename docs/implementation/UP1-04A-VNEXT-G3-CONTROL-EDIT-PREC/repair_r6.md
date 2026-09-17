# Repair R6 after focused test receipt R5

R5 passed the focused suite (`48/48`, exit `0`) and remains preserved at
`test_r5.stdout`, `test_r5.stderr`, `test_r5.exit`, and
`test_r5.receipt.json`. Before final archival, a contract self-audit found
that payload-ref equality delegated to a nested `NamedTuple` comparison. That
could depend on default object identity for `QualifiedRefV1` rather than the
frozen id/version semantics.

The minimal repair changes only `_g3ce_payload_ref_equal` to compare every
payload-ref field explicitly: candidate/declaration id+version, parent
binding, parent hash, child contract/hash, source-record ref, and source
content hash. This preserves rejection of forged identity/hash values while
accepting an independently constructed ref with the same canonical fields.
The R5 source hash before this repair was
`4a50ade92358a13d1bed6c23099edbdede78e6cd887176f1bbbcc301b8ac5eaa`.
R6 must repeat the same authorized command; no Julia/DESC process is running
before the rerun.

