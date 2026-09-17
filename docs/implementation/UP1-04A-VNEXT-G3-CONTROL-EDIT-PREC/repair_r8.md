# R8 repair record

R8 applied the smallest implementation and focused-test extension after the
independent postrun review requested changes.

The source now rejects a source payload whose four provenance slots carry a
candidate different from the payload key, and rechecks the derived parent and
child bindings. The edit admission path compares every target fault field
(`fault_id`, `target_id`, `safe_action`, `detection_signal_id`, and `deadline`)
and permits only `mode` to change. State construction independently recomputes
the current hash, validates every previous/resulting chain, and requires the
terminal operation result hash to equal that recomputed current hash. The
current-state recipe remains digest-only over operation history so the result
hash equality is acyclic.

The test adds a hash-recomputed foreign-provenance negative, per-field and
combined carried-fault mutations, zero/insert/delete/rebind negatives, forged
terminal-result rejection, and a common failure helper asserting status,
object identity, canonical bytes, SHA, history, last-operation hash, and
current-state hash. R8 initially exposed a Julia test-helper ownership issue:
`String(::Vector{UInt8})` consumed the captured byte vector. R9 changed only
the helper to hash a copy, preserving the R8 raw receipt and adding the R9
receipt.

No shared entry point, core document, AD-32 artifact, T0 path, old V5 source,
registry, package, realization sibling, or unrelated file was modified.
No Julia/DESC computation beyond the authorized focused test attempts was performed.
