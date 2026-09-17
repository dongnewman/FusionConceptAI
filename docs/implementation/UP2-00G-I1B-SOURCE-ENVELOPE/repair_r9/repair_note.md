# G-I1B source envelope repair R9

Status: `review_pending`; `accepted=false`; runtime: `not_run`.

The preserved focused-R4 run exited 1 with 2051/2052 GI1B assertions and a
single production-boundary failure at
`test/GenomeV5/UP2/gi1b_source_envelope_tests.jl:407`. Independent postrun R4
confirmed that the failure was a test-only lexical assumption: it required the
free-text `GI1BRowSpecV1.authority_gap` field to contain the literal substring
`authority`, although the source contract declares no such lexical invariant.
The N09 alternative was also unreachable after filtering to N06.

The sole owned change replaces that assertion with a semantic non-empty check:

```julia
@test all(s -> !isempty(strip(s.authority_gap)),
    (s for s in G.GI1B_ROW_SPECS_V1 if s.group === :N06))
```

Existing typed runtime assertions are preserved: N06 rows remain
`terminal_deferred` with `authority_gap`, their bindings remain
`typed_absent`, and runtime gaps still contain `N06`. The actual-A E1-present
and both-absent factory paths, 50-row independent manifests, taxonomy and
schema tests remain in the test file. Source, fixture, runner, core, and all
focused/postrun/previous-repair evidence are unchanged.

## Static QA

- old lexical `occursin("authority", lowercase(s.authority_gap))` assertion: absent;
- semantic non-empty assertion: present;
- typed N06 runtime assertions: present;
- actual-A factory call paths: present;
- taxonomy and schema testsets: present;
- fixture JSON parses and retains 50 rows;
- Julia/DESC not run.

The change is limited to one test line. It does not change production
classification or promote any authority. A different Luna should statically
review this repair before any focused rerun.

## Before/after hashes

| path | before SHA-256 | after SHA-256 | after bytes |
|---|---|---|---:|
| `test/GenomeV5/UP2/gi1b_source_envelope_tests.jl` | `45948253ba490bb4bf7e163bbdc272ed8f2a4d1eb0dd098002a7c90db308ce37` | `2de750b05cfea77ad7fc2dac0d0c8f8862c60028bba38e95b887e23a4bcc0299` | 25685 |
| `src/GenomeV5/UP2/GI1BSourceMutationEnvelopeV1.jl` | unchanged | `58e5f3aa24da64e4ca9c843fc35bba79d8089206a6b49fd56966784051a31e12` | 43037 |
| `test/GenomeV5/UP2/gi1b_source_envelope_fixtures.json` | unchanged | `23794ed2e7958ccd21b26418428e06279150d380e4710c77050bf8b4fe3da1c6` | 23906 |
| `test/GenomeV5/UP2/run_gi1b_source_envelope.jl` | unchanged | `54132f1415faba369807857c1175c317757339b1f3451af902a5f525b0f067b5` | 408 |

Focused-R4 raw stdout/stderr, input manifest, and postrun diagnosis remain
protected. No B00/B04, physical, engineering, provider, mesh, or parent-goal
credit is claimed.

