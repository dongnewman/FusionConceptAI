# M5 inverse-feedback R2 scope contract repair R4

This additive package closes only P1-R3-01, P1-R3-02 and P1-R3-03 from
`reviews/05-scope-contract-independent-review-r1/report.md` without
authorising implementation.  Its only write scope is this directory.  Source,
tests, the 03/04 packages, registries outside this package, providers and
hardware are read-only or forbidden.

The contract remains `review_pending`, `not_implemented`, `not_executed`,
`screen_only`, and `formal_credit=none`.  `valid_screen` is a derived result,
never a caller-selected label: it requires a complete canonical identity join,
all digest/CAS/authority checks, fresh freeze, and two serial replays.  Any
unknown external authority is `typed_absent` and cannot promote the result.

Files under `schemas/` are closed Draft 2020-12 schemas.  `checker_contract.json`
enumerates the cross-object pointer, canonical-bytes, history, CAS and dirty
closure implications that JSON Schema cannot express.  `failure_taxonomy.json`
is the concrete one-row-per-code mapping and is validated by
`schemas/failure_taxonomy_schema.json`.  The package freezes the 17 dependency
entries, seven local URNs and 33 failure mappings from R3 plus review 05.
