# Repair R5 after focused test receipt R4

R4 was the first run to exercise the positive state path. It exited `1` and
its complete raw files remain immutable at `test_r4.stdout`,
`test_r4.stderr`, `test_r4.exit`, and `test_r4.receipt.json`. The contract
failure was that the implementation used a separate current-state hash
domain for empty history, although the frozen contract requires
`current_state_hash == initial_state_hash` and `last_operation_hash == ZERO`
when history is empty. This also caused the first operation transition to
return `program_exception` while constructing the new state. The test's
reversed-history negative was also accidentally applied to an empty history.

The minimal repair makes `_g3ce_state_hash` return the initial hash for empty
history and applies the reversed-history constructor negative to the second
successful state. The illegal status-promotion negative now uses the state
hash field that actually exists. Before R5, source SHA-256 was
`4a50ade92358a13d1bed6c23099edbdede78e6cd887176f1bbbcc301b8ac5eaa` and test
SHA-256 was
`9884bffce32676240320536592cc9b8796fcc4e8233bbefd02a860bd856be1da`. The
pre-rerun audit found zero Julia/DESC processes, `git diff --check` exit `0`,
and 4326 dirty rows. R1--R4 remain preserved.

