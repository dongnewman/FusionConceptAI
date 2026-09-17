# Aggregate gate independent review R3

Verdict: `pass_limited`.

R3 reran the R1/R2 attack matrix and exercised the new software-bookkeeping
ledger from fresh Python `-B` processes. The focused suite passed `22/22`.
Candidate/source/input mismatch, unknown fields, typed absence, authority
false at all layers, exact responsibility set, duplicate keys/IDs, malformed
fingerprints/domains, direct aggregate, sequence jumps, canonical map
permutation, changed input/no-AD, forged prior, ledger tamper, rollback,
input/package overlay, and concurrent compare-and-swap all failed closed or
matched their contract outcomes.

The ledger is local software bookkeeping only: its schema, code version,
sequence, previous hash, state hash, input fingerprint and record hash were
independently inspected. `transition` without a ledger returns
`typed_absence/ledger_required/terminal_deferred/no_publish=true`; it never
trusts a caller-provided prior in that mode. Two independent child processes
produced equal semantic baseline and attack outputs. No P1/P2 finding remains.

`aggregate_document` remains a pure lower-level classifier used for contract
tests; the production transition boundary is the ledger-backed `transition`
API. This review grants no external authority, AD, T0/T1/T2/B00/B04/L4/parent
credit and does not constitute physical, engineering, provider, mesh, solver,
or R01-R10 evidence.

