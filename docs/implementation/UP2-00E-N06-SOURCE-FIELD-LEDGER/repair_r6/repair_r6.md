# R6 static repair: typed N06 identity index

This repair is limited to `_n06_unique_index` in
`src/GenomeV5/UP2/N06SourceFieldLedgerMappingV1.jl`.

The R5 program exception occurred because the helper forced every identity
through `String(id_of(x))`. The actual G1 occurrence identity is a typed
four-tuple `(ledger_id, equation_id, port_side, port_index)`, so Julia raised
`MethodError` before mutation receipts. The helper now retains `id_of(x)` as
its original key type, detects duplicates using typed equality, and builds the
index from those keys. String IDs used by equations, closures, ports, entries,
accounts, and links retain their existing lookup behavior. No tuple is
stringified.

The duplicate check is performed both on the collected typed keys and at
insertion, so repeated typed occurrence keys fail closed rather than being
silently overwritten. Existing R1-R5 receipts remain immutable. This repair
was static only; no Julia/DESC run was performed. A new independent static
precheck is required before any focused rerun. Status remains
`review_pending`/`accepted=false`, with no B04, provider, engineering,
physical, or R01-R10 credit.

The owned focused test now includes a narrow executable guard: two distinct
typed occurrence tuples must remain independently indexable, while two equal
typed occurrence keys must raise `ArgumentError`. This test was added without
running Julia, so its execution remains pending the independent static gate.
