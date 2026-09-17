# UP1 external-blocker closure R4 — final full regression

## Verdict

`software_pass_limited`: the frozen R3 atomic focused suite and the entire
`test/up1_external_closure_r4` tree passed on two serial runs each; the static
compile/import boundary check also passed. `external_authority_fail_limited`:
this is offline local software evidence only. No external owner acknowledgement,
trust-root verification, publication authorization, T0/S3 execution, or parent-goal
credit is established here.

## Frozen scope and commands

Before execution, SHA-256 and byte-length receipts were captured for all 48
Python files under these source/test sets, excluding `__pycache__`:

```text
tools/up1_external_closure_r3/atomic_bundle
test/up1_external_closure_r3/atomic_bundle
tools/up1_external_closure_r4
test/up1_external_closure_r4
```

The commands below were executed serially in the listed order; each suite ran
twice, followed by one static/import run:

```text
python -B -m unittest discover -s test/up1_external_closure_r3/atomic_bundle -p test_*.py
python -B -m pytest test/up1_external_closure_r4 -q
python -B docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R4/19-final-full-regression/static_check.py
```

The machine-readable command, PID, UTC, exit, output hashes, and count records
are in `run_manifest.json`; all raw stdout/stderr/combined streams are under
`raw/`. `before_hash.json`, `after_hash.json`, and `hash_comparison.json` are
the source freeze closure.

## Serial receipts

| suite | run | PID | UTC start → finish | exit | result | skipped | xfailed | xpassed | stdout SHA-256 | stderr SHA-256 |
|---|---:|---:|---|---:|---|---:|---:|---:|---|---|
| R3 atomic focused | 1 | 80576 | 2026-09-17T02:43:52.784043Z → 2026-09-17T02:43:53.955417Z | 0 | 25 tests, OK | 1 | 0 | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | `c03aabb20defc7a2ab2dde3f09a9908d9e7e00bf0c5ac044b4ae8a79ce9c12a0` |
| R3 atomic focused | 2 | 90660 | 2026-09-17T02:43:53.958121Z → 2026-09-17T02:43:55.122907Z | 0 | 25 tests, OK | 1 | 0 | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | `f9619b0ab67e8aac672400f61c6d9cc7833c1f3fe52d853e71832e7706bd075f` |
| R4 full tree | 1 | 83196 | 2026-09-17T02:43:55.126361Z → 2026-09-17T02:44:07.648571Z | 0 | 98 passed | 2 | 0 | 0 | `2b73f6475bc34230e74fb5d99a3f4d7fcf05c9ad9ac42301c5c0663c8c59537f` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| R4 full tree | 2 | 63240 | 2026-09-17T02:44:07.653134Z → 2026-09-17T02:44:17.902529Z | 0 | 98 passed | 2 | 0 | 0 | `3acd97faff53390014001e7c96f9c27377176a3ebc787531574181c4e3bce88f` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| static compile/import | 1 | 14812 | 2026-09-17T02:44:17.906917Z → 2026-09-17T02:44:18.340718Z | 0 | 48 AST compile, 11 imports, boundary PASS | 0 | 0 | 0 | `a56b14c360275da898633815487bfeb23f468659d41a9189c540207ccfd74175` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |

The R3 skip is the host-privilege-limited Windows symlink/reparse or hardlink
probe. The two R4 skips are the existing symlink/reparse host-capability cases
in authoritative intake. These remain recorded skips, not converted passes.
There were no xfails or xpasses.

The static check compiled all 48 files, imported 11 implementation modules, and
reported `NO_NETWORK_IMPORT_EXECUTION=PASS` and
`NO_HEAVY_LANE_EXECUTION=PASS`. No network client was imported or executed; no
Julia, DESC, T0, S3, solver, external channel, or heavy lane was invoked.

## Hash closure and boundary

`hash_comparison.json` reports `before_count=48`, `after_count=48`,
`unchanged=true`, with empty `changed`, `missing`, and `added` lists. No file
under `tools/` or `test/` changed during the regression. Only this
`19-final-full-regression/` evidence directory was written. This closure does
not claim external authority or physical/engineering execution.
