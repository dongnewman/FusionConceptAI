# GI1B independent postrun review R4

Verdict: `changes_requested` for the focused test assertion only.

This is a read-only third-party review of `focused_r4` at frozen HEAD `4b69f55f7f80240147a65a22809dc1207824dde2`. No Julia or DESC command was run by this review. The captured run is exit `1`, with no postflight Julia/DESC process. Its reconstructed receipt states that the wrapper's initial receipt was null, then the receipt was rebuilt from the immutable preflight, raw output metadata, hashes, and observed PIDs; it also records zero reruns.

The runtime evidence is otherwise strong: upstream tests are `299/299`, the actual-A E1-present/both-absent factory is `2024/2024`, aggregate taxonomy is `8/8`, the schema/frozen matrix is `14/14`, and GI1B itself is `2051/2052` with one failure and zero errors. The production-boundary test is `5/6`; the sole failure is `test/GenomeV5/UP2/gi1b_source_envelope_tests.jl:407`.

The line-407 assertion is a lexical mismatch in the test, not a deeper source failure:

```julia
all(occursin("authority", lowercase(s.authority_gap)) || s.group === :N09
    for s in G.GI1B_ROW_SPECS_V1 if s.group === :N06)
```

The `if s.group === :N06` filter makes the `:N09` alternative unreachable. All five N06 `GI1BRowSpecV1.authority_gap` strings are nonempty semantic descriptions, but several deliberately say “join missing”, “law absent”, or “mapping absent” without using the word `authority`. The constructor accepts the field as free text (`GI1BSourceMutationEnvelopeV1.jl:39-49`) and imposes no keyword contract. The fixture carries the same descriptions, so there is no source/fixture drift here.

The production classification is correct and already independently asserted. For absent E2, `_gi1b_read` returns `authority=:typed_absent` with a runtime gap containing “N06 ... authority ... absent” (`GI1BSourceMutationEnvelopeV1.jl:436-447`). `_gi1b_status` maps that authority to `resolution=:terminal_deferred` and `error_code=:authority_gap` (`:505-512`), and `_gi1b_row` preserves the runtime gap in the binding (`:560-579`). The passed factory assertions at `gi1b_source_envelope_tests.jl:295-298` check every N06 row for `terminal_deferred`, `authority_gap`, `typed_absent`, and an N06 runtime gap. Thus the N06 typed terminal-deferred/authority-gap substance is present; the failed line checks only a free-text spelling convention.

The narrow repair is to replace line 407 with a nonempty metadata check, while retaining the existing runtime assertions, for example:

```julia
@test all(s -> !isempty(strip(s.authority_gap)),
    (s for s in G.GI1B_ROW_SPECS_V1 if s.group === :N06))
```

Do not simply delete the check, and do not rewrite all five source/fixture descriptions merely to insert the word “authority”. If a future contract requires that exact lexical token, it must be declared as a field invariant and updated in source and fixture together; the current code does not declare such an invariant. This review does not authorize a repair or rerun.

The exit-1 result remains a software-test failure only. It grants no B00, B04, physical, engineering, provider, mesh, or parent-goal credit.

## Frozen evidence

- HEAD/branch: `4b69f55f7f80240147a65a22809dc1207824dde2` / `main`.
- Current pre-write worktree: 297 porcelain entries; status SHA-256 is recorded in `command_receipts.json`; no matching `julia`, `julia-debug`, or `desc` process observed.
- focused_r4 PID `50860`; observed Julia PIDs `[50860, 46356]`; exit `1`; end UTC `2026-09-14T19:33:42.0000000Z`; postflight verified UTC `2026-09-14T19:36:15.5534311Z`.
- focused stdout SHA-256 `8d0409a26d78e8b65a94cad060bfefb41d972f2ab34d6568356be0d9ae494d9c`; stderr SHA-256 `25fec85128abe7b380aecdfe1988bbf15e3268ff5dcec1af2bd437eb1c2ac453`.
- protected source/test/fixture/runner inputs match before and after; their hashes are listed in `evidence_manifest.json`.

