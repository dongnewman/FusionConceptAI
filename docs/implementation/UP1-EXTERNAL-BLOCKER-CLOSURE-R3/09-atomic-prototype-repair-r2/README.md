# UP1 R3 atomic prototype repair R2

Status remains `prototype_pass_limited`: `authority_credit=false`,
`formal_credit=none`, `no_publish=true`, and `claim_scope=software_only`.

This additive repair is limited to the R3 atomic-bundle tool and test trees.
It closes the reviewed P1/P2 prototype defects as follows:

- CAS rejects an existing object or receipt with link count other than one;
  Windows handle link-count inspection is used when available and unavailable
  identity is typed `CAS_INSTALL_UNAVAILABLE`, never accepted.
- Every existing root/parent component is checked for symlink/junction/reparse
  state before mkdir; each newly-created component and final containment are
  checked again. The test records a real skip when symlink creation lacks host
  privilege.
- EHP-03 graph and G2 inverse checks include authority references and times;
  forward/reverse row digests are independently recomputed and are not required
  to be equal.
- Decision precedence rejects malformed, digest, binding, TEST_ONLY, and
  other predicate errors before considering fixture deferral. TEST_ONLY
  receiver material is explicitly non-evidence, and public API verification
  requires `trusted_public_keys` rather than caller-selected `public_keys`.
- EHP-04 runtime and binary claims require contained local bytes; executed
  fixtures require local stdout/stderr/receipt files and hash binding. Results
  state the software-only claim scope.
- R01-R25 and D01 each have an independent mutation builder and expected
  decision/code assertion; the focused test executes and records all 26 IDs.

## Focused test receipts

Command (run twice, no network or heavy lanes):

`python -B -m unittest discover -s test/up1_external_closure_r3/atomic_bundle -p 'test_*.py'`

| run | PID | UTC | exit | failed | raw output SHA-256 | raw output |
|---|---:|---|---:|---|---|---|
| 1 | 35220 | 2026-09-17T00:03:32.497760+00:00 | 0 | false | `204f52cfaba27159f04e7d7792e063dc98e2a75384be92018c30953eecf3f0cc` | `Ran 20 tests in 1.225s; OK (skipped=1)` |
| 2 | 16652 | 2026-09-17T00:03:32.497846+00:00 | 0 | false | `204f52cfaba27159f04e7d7792e063dc98e2a75384be92018c30953eecf3f0cc` | `Ran 20 tests in 1.225s; OK (skipped=1)` |

The one skip is the real symlink/reparse probe skip when the host denies link
creation; the junction/symlink behavior is not promoted from a fabricated pass.

Compilation check: `python -B -m py_compile` on `__init__.py`, `bundle.py`, and
`canonical.py` exited 0.
