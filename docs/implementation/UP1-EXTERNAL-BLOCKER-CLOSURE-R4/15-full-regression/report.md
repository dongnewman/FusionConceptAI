# UP1 external-blocker closure R4 — full regression

## Verdict

`software_pass_limited`: the frozen R3 atomic focused suite and the entire
`test/up1_external_closure_r4` tree both passed on two serial runs. This is
offline local software evidence only. `external_authority_fail_limited`:
there is no external owner acknowledgement, trust-root verification,
publication authorization, T0/S3 execution, or parent-goal credit in this
record.

## Frozen scope and commands

The following source-only sets were SHA-256 frozen before execution and
rechecked after execution (45 files total; `__pycache__` excluded):

```text
tools/up1_external_closure_r3/atomic_bundle
test/up1_external_closure_r3/atomic_bundle
tools/up1_external_closure_r4
test/up1_external_closure_r4
```

Commands, run serially twice where applicable:

```text
python -B -m unittest discover -s test/up1_external_closure_r3/atomic_bundle -p test_*.py
python -B -m pytest test/up1_external_closure_r4 -q
python -B docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R4/15-full-regression/static_check.py
```

The static check parsed all 45 Python files, imported 11 implementation
modules, and asserted the offline/no-heavy boundary. No network client was
imported or executed. No Julia, DESC, T0, S3, solver, external channel, or
heavy lane was invoked.

## Serial execution receipts

All raw stdout/stderr, concatenated raw bytes, PID, UTC start/finish, and exit
receipts are under `raw/`; their stored SHA-256 values are recorded in
`run_manifest.json`.

| suite | run | PID | UTC | exit | result | skipped | xfailed | xpassed | stdout SHA-256 | stderr SHA-256 | combined SHA-256 |
|---|---:|---:|---|---:|---|---:|---:|---:|---|---|---|
| R3 atomic | 1 | 54304 | 2026-09-17T02:11:21.0920039Z → 2026-09-17T02:11:22.7835096Z | 0 | 25 tests, OK | 1 | 0 | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | `ccdc6bac8287bde1e9204563223cbae4d2b575a9d0779e5dac54dff42323c6fd` | `ccdc6bac8287bde1e9204563223cbae4d2b575a9d0779e5dac54dff42323c6fd` |
| R3 atomic | 2 | 54620 | 2026-09-17T02:11:49.7392490Z → 2026-09-17T02:11:51.7363286Z | 0 | 25 tests, OK | 1 | 0 | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | `afaa5e5f117314a819b498900c6987fb1570a3fd6501a56b090832ef852dd118` | `afaa5e5f117314a819b498900c6987fb1570a3fd6501a56b090832ef852dd118` |
| R4 full tree | 1 | 46004 | 2026-09-17T02:11:51.7654029Z → 2026-09-17T02:12:05.1985535Z | 0 | 80 passed | 2 | 0 | 0 | `ec6d8abdb7f6802875b49533f5c6c2d06a21626c0e1df07d059058af71f0f882` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | `ec6d8abdb7f6802875b49533f5c6c2d06a21626c0e1df07d059058af71f0f882` |
| R4 full tree | 2 | 62816 | 2026-09-17T02:12:05.2026863Z → 2026-09-17T02:12:17.7831608Z | 0 | 80 passed | 2 | 0 | 0 | `abcf2750617318761fab9024f75da9cd2a42a669750ffdbb37e9fa6b19e065f3` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | `abcf2750617318761fab9024f75da9cd2a42a669750ffdbb37e9fa6b19e065f3` |
| static import/compile | 1 | 15452 | 2026-09-17T02:14:02.0219691Z → 2026-09-17T02:14:02.8349122Z | 0 | 45 AST compile, 11 imports, boundary checks PASS | 0 | 0 | 0 | `4c68f21141bfed7fa3444ed7c90879ab361994881049466b35fc013044a822fe` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | n/a |

The one R3 skip is the known host-privilege-limited Windows symlink/reparse
probe. The two R4 skips are the existing typed host-capability/privilege
cases; neither was converted to a pass. There were no xfail or xpass results.

## Hash closure

`before_hash.json` and `after_hash.json` cover the same 45 source files.
`hash_comparison.json` reports:

```json
{"before_count":45,"after_count":45,"unchanged":true,"changed":[],"missing":[],"added":[]}
```

No tool or test implementation file was changed by this regression. Only this
`15-full-regression/` evidence directory was written.
