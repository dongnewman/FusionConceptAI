# Repair R4 after focused test receipt R3

R3 was executed with the authorized command and exited `1`. Its raw files
remain immutable at `test_r3.stdout`, `test_r3.stderr`, `test_r3.exit`, and
`test_r3.receipt.json`. The setup failed because the implementation added an
unfrozen extra condition requiring the parent declaration URI/id to equal the
candidate URI/id. R7 derives `parent_binding.candidate_ref` from the child
key and separately stores the parent declaration ref/hash; it requires the
declaration ref version `v1`, not equal URI strings.

The minimal repair removes only that over-constraint. Candidate version, child
kind/id, parent hash/key equality, derived parent binding hash, and all source
payload identity checks remain hard invariants. Before R4, the source hash was
`5bcdc4cc89ee2ee3cd5b2647282fe8486b28ee6220f29ecb53fc46ca5270b6ba`; the
test hash remains
`c6a23a5c2b9b8e75c4fd53d345809d956d4ea33441532f533aed04cfd4132f42`. The
pre-rerun audit found zero Julia and zero DESC-named processes and preserves
R1--R3 receipts.

