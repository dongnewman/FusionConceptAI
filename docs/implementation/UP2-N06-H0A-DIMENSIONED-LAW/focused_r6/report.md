# H0-A focused R6 runtime receipt

Status: `executed_failure`; `accepted=false`; `review_pending=true`.

The R15 independent precheck was `pass_limited`. The four input files were
recomputed from disk immediately before launch and matched the R15 manifest.
No Julia/DESC process was present at preflight. The command below was launched
exactly once with raw stdout/stderr redirection:

```text
julia --startup-file=no --project=. test/GenomeV5/UP2/run_n06_dimensioned_law.jl
```

The process PID was `48048`, UTC interval
`2026-09-14T22:34:23.8569218Z` to `2026-09-14T22:38:10.8831794Z`, and the
real exit code was `1`. The test runner spawned short-lived Julia children for
its component suites; all Julia/DESC processes were gone in the post snapshot.
The raw files are preserved as `stdout.raw` and `stderr.raw`.

The first real H0-A failure is in
`test/GenomeV5/UP2/n06_dimensioned_law_tests.jl:286`:

```text
Expression: trusted.status == :terminal_deferred
Evaluated: fail_closed == terminal_deferred
```

The same test group then reports a secondary failure at line 291 because the
`admitted.gaps` assertion does not observe `external_ref_required` or a
calibration gap. The raw stderr records the terminal runner summary:
`17 passed, 2 failed, 0 errored, 0 broken`. No source or test repair was made
after the failure and the run was not repeated.

## Runtime receipt

| artifact | bytes | SHA-256 |
|---|---:|---|
| `stdout.raw` | 8091 | `7607f6d7200b30e2018e1d349e514a3c25e332a727b88c7f06bb2fe5d8131c2b` |
| `stderr.raw` | 311 | `71eddcba500bf2c1b4dfe1bf9dfe53461f13e51faced6547744fdcae54d4d565` |

Input hashes at launch:

- source: 57920 bytes, `5b6e23508d7facd3b50802214dfdd0087d63de7252b32ebf4dd4bc4b2142904a`;
- tests: 40742 bytes, `9c5ecf8f2f212b2298eff5a8129a618114185867c21b83dcd4e3ff1982b36599`;
- fixture: 1451 bytes, `779e29bac0a71c5072896301e24e74c9686c293609b89e250d0b0aff5bf0cc99`;
- runner: 299 bytes, `da4c41517badd8c99f5f10e55c9219e2450afb223798eb7f7b4db2048ce293dc`.

Dirty status contained 304 non-empty porcelain rows before and after the run.
The complete snapshots are `pre_dirty.txt` and `post_dirty.txt`; process
snapshots are recorded in `receipt.json` and both were empty after the run.

The receipt is software-only. It does not establish actual-A authority,
UP2-total readiness, H0-A acceptance, B00/B04, provider, mesh, physical,
engineering, or R01–R10 credit. A different Luna must perform the postrun
review before any further action.
