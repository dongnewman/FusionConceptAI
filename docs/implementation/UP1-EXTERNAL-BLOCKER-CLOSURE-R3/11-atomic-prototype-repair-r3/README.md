# UP1 R3 atomic prototype repair R3

Status: `prototype_pass_limited` only. `formal_credit=none`,
`authority_credit=false`, `no_publish=true`, `claim_scope=software_only`.
No external authority, publication, AD/S3, Julia/DESC/solver lane, network,
or external send was used.

This narrow repair addresses the P1 findings from reviews 09 and 10:

- EHP-04 local runtime/import/lock/SBOM/binary/download/fixture material is
  accepted only under a resolved, root-contained artifact path. SBOM and
  download receipts require local bytes plus a declared SHA-256 recomputed at
  check time; missing roots, paths, bytes, or mismatches are typed failures.
- R01-R25 and D01 are explicit named mutation builders with distinct mutation
  paths and byte inputs, and are checked against the frozen matrix rather than
  a uniform `SCHEMA_INVALID` placeholder.
- The implementation-owned error registry now includes all emitted codes,
  including `DECISION_NOT_BOUND_TO_QUARANTINE`. Unknown internal codes retain
  their original value and force `rejected_all`; they are never silently
  rewritten to a generic code.

## Verification receipts

Command (serial, run twice):

`python -B -m unittest discover -s test/up1_external_closure_r3/atomic_bundle -p 'test_*.py'`

| run | PID | UTC | exit | result | raw output SHA-256 |
|---:|---:|---|---:|---|---|
| 1 | 108648 | 2026-09-17T00:39:06.199775+00:00 | 0 | `Ran 23 tests; OK (skipped=1)` | `ffbb8290bb66ac4ed28aae8144ae7f508b5845a8c8f71b710e2008893dc1052f` |
| 2 | 42192 | 2026-09-17T00:39:38.748238+00:00 | 0 | `Ran 23 tests; OK (skipped=1)` | `f30d5b07471f055ae77dd4d454a93e50fb02822ffcbf1dddb0fc609e5eaa32bd` |

The single skip is the existing host privilege-limited symlink/reparse
creation probe; it is not promoted to a demonstrated host pass.

Compilation command covered the three package modules and the explicit vector
test. It exited 0 (PID 57172, UTC `2026-09-17T00:37:27.064655+00:00`, raw
SHA-256 `16dac69579df0535f49950d8322c34c86ebbc0747c44aba19df96fa264074d38`).
Generated `__pycache__` directories under the two allowed package/test trees
were removed after verification; no other cache or workspace path was
modified.

This remains a software/prototype closure and must not be promoted to UP1,
B00/B04, physical, engineering, R01-R10, or publication acceptance.

Raw command outputs are retained in `raw/focused_run_1.combined.raw` and
`raw/focused_run_2.combined.raw`; no failure output was discarded.
