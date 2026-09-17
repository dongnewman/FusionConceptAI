# M5 core performance R3 acceptance record

## Scope

Base: `cfc745939a02fd023854dd04e9bb6d04ccadf9ee`.

Owned source/test paths are the four core source files and
`test/RuntimeV4/M4Isolated/m5_core_perf_r3_tests.jl`; this record is the
implementation note under the assigned R3 directory.  No public entry point,
manifest, manufactured adapter, probe, run, or historical evidence was edited.

## Static checks

The implementation was inspected with text-level source checks and the final
worktree diff was checked for whitespace errors.  Julia parse, focused runtime
tests, canonical/hash frozen comparisons, query/replay regression, and profile
measurements are intentionally pending the parent serialized lane.

## Evidence ceiling

`screen_only / performance implementation pending runtime`; no formal UP5,
search, physical, provider, or R01–R10 credit.  Any mismatch discovered by the
parent runtime lane must fail closed and supersede this preparation note.
