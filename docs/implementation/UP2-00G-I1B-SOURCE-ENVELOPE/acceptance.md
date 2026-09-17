# UP2-00G-I1B source-envelope precursor

Status: `accepted_limited`; `accepted=true`; `review_pending=false`.

Following the focused-R5 raw-byte recomputation, clean R7 correction, and
different-Luna independent acceptance R3 `pass_limited`, this record accepts
only the G-I1B local precursor's actual-A source-envelope
software behavior: the factory paths, typed source access, mutation row
schema, taxonomy, and typed authority-gap handling. The focused R5 receipt
completed once with exit `0` and `2653/2653` assertions. A different Luna's
independent postrun R5 review is `pass_limited` and verified the raw outputs,
PID/exit metadata, four input hashes, and preservation of the older focused-R4
failure evidence; R3 independently rechecked the raw bytes, structured
receipts, protected-file hashes, and R7 text integrity.

The accepted slice includes the actual-A E1-present and both-absent factory
paths (`2024/2024`), the aggregate taxonomy (`8/8`), frozen source-envelope
matrix (`14/14`), production boundary (`6/6`), fixture oracle-only checks
(`3/3`), and the complete repeated UP1 groups (`299/299`). The R9 test repair
is semantic: it checks that each N06 `authority_gap` is non-empty while
retaining typed `terminal_deferred`, `error_code=:authority_gap`,
`binding.authority=:typed_absent`, and the N06 runtime gap marker. Production
source, fixture, and runner bytes were unchanged by R9.

The focused R5 command was:

```text
julia --startup-file=no --project=. test/GenomeV5/UP2/run_gi1b_source_envelope.jl
```

It ran as PID `14796`, exited `0`, and left dirty rows at `301 -> 301` with
matching Julia/DESC process counts `0 -> 0`. Raw stdout is 2806 bytes with
SHA-256 `22f5b6723c74b3b502100cba753a9b567c09896722f3373ae28d45b579976121`;
raw stderr is empty with SHA-256
`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.

The four protected inputs are recorded in `evidence_manifest.json` and the
focused/postrun manifests. The immutable focused-R4 evidence remains the
historical exit-1 result (`2051/2052`, one line-407 lexical assertion) and is
not replaced by R5.

This acceptance does not accept N06 actual dimensioned authority, UP2 total,
formal B00/B04, compiler, provider, mesh, solver, engineering, physical,
current-A readiness, or R01-R10. The local fixture remains oracle-only;
missing authority remains `terminal_deferred`, and contradictions remain
`fail_closed`. The parent UP2-00 and UP1-04/UP2-01 gates remain separate.

The historical correction chain is preserved in [postrun erratum R6](postrun_erratum_r6/report.md)
and the clean-text [postrun erratum R7](postrun_erratum_r7/report.md).

Evidence:

- [focused R5 receipt](focused_r5/report.md)
- [independent postrun R5](independent_postrun_r5/report.md)
- [R9 independent static precheck](independent_precheck_r9/report.md)
- [independent acceptance R3](independent_acceptance_r3/report.md)
- [R7 evidence manifest](postrun_erratum_r7/evidence_manifest.json)
- [current evidence manifest](evidence_manifest.json)



