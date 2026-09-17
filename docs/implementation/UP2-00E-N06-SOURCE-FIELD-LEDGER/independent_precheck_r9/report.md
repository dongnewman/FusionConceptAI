# E2-N06 independent static precheck R9

Verdict: `ready_for_focused_r7` (static readiness only; no runtime acceptance).

The R7 repair closes the R6 positive-path program exception. At
`src/GenomeV5/UP2/N06SourceFieldLedgerMappingV1.jl:329-333`, the actual
occurrence is normalized to the same four-field NamedTuple shape returned by
`_n06_selector_key`: `ledger_id::String`, `equation_id::String`,
`port_side::Symbol`, and `port_index::Int`. The equality therefore compares
all four typed fields exactly. The source does not stringify the occurrence and
the R5 typed-key `_n06_unique_index` implementation remains intact.

The fixture-backed wrong-source control is real and executable in the current
test at lines 332-353. It replaces the actual `:source` selector with the same
ledger/equation/side but `port_index=99`, invokes `n06_projection_from_a`,
and requires the source-match `ArgumentError`. A `finally` block restores the
original selector at lines 346-347. The existing missing-selector control at
lines 314-331 also deletes the real `:source` key, invokes the production
projection path, asserts the explicit missing-selector error, and restores it.

The R7 selector-source check records the actual source-backed identities and
compares them with the frozen fixture without treating fixture text as physical
authority: G1 `governing-0` and `(energy, governing-0, output, 1)`, G1
`energy-balance`, G2 interface `left/right` and boundary `left/x_min`, and G3
`source_effort`, its entry/account/closure, `source_flow`, and `source-loop`.
The implementation uses unique-match and typed locator guards for these
selectors; ambiguity or absence fails closed. This remains a contract
projection and the cross-layer semantic gap remains deferred.

The R6 real exit-1/raw receipt is preserved as historical evidence of the
anonymous-tuple/NamedTuple mismatch. R1-R6 archives remain present and
immutable. The frozen R7 source, test, fixture, and runner hashes match the
handoff. No Julia/DESC was run, so a new focused R7 receipt is still required.
No formal B04, provider, mesh, engineering, physical, or R01-R10 credit is
available.

## Frozen hashes

- source: `7bf3bfd22e61de7a6414cdb75fd3683379ed22ae2865990b97bdf391dffdf181`
- test: `dac8c62e4ba20b45930a119649468659931eca2236cb9c5181aba101392a66ce`
- fixture: `361a1777a765ed6784a1f37c02febc24c2ba5f6eed3c6a15b99333af596736b2`
- runner: `9410e2edbb7afc70599e183f30a2ef9836b7e84a1834296e27d96b881b1f86af`

Only this independent-precheck directory is writable in this review.

## Final QA boundary

JSON parsing, control scan, and `git diff --check` passed. An initial
validator invocation returned exit 1 because the core documents temporarily
referenced missing `../implementation/AD-26/acceptance.md` links; that failed
attempt is retained in this record. A final rerun returned exit 0 after the
prerequisite links became present. No files in this review scope were changed
to obtain that pass, and no Julia/DESC execution was performed.
