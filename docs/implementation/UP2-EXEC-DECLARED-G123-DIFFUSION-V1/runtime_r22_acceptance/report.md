# UP2-EXEC-DECLARED-G123-DIFFUSION-V1 — R22 runtime acceptance

## Result

The existing R22 nested runtime receipt is complete.  Its captured focused
Julia lane reports **39/39** for `declared G123 R21 executes every product
stage` and **13/13** for `declared G123 R21 observed negative result set`.
The nested receipt has exit code `0`, one start, `JULIA_NUM_THREADS=1`, no
timeout, empty stderr, two postflight zero-process observations, and
`ownedFilesUnchanged=true`.

The authoritative runtime evidence is:

`docs/implementation/UP2-EXEC-DECLARED-G123-DIFFUSION-V1/agent_local_r22_preflight/run_20260918_124138_348_920a0af9f1174f45a6e7407e81f6bf3f/`

The package-level
`docs/implementation/UP2-EXEC-DECLARED-G123-DIFFUSION-V1/agent_local_r22_preflight/manifest.json`
is intentionally still `status=preflight_only` with
`execution_performed_for_this_receipt=false`.  That package manifest is
preflight metadata; the nested `run_metadata.json`, captured stdout/stderr,
exit code, process snapshots, and hash receipts are authoritative for this
R22 runtime acceptance record.

## Numeric contract observed by the executed focused lane

The positive assertions are bound to the frozen R22 six-file set:

- transfer: old state `[0.25, 0.75]`, overlap `[0.5, 2.5]`, weights
  `[1.0, 1.0]`, new state `[0.25, 0.75]`, conservation residual `0.0`;
- face coefficients `k_faces=[2.0, 2.05, 2.1]`;
- matrix `[[9.1125, -4.6125], [-4.6125, 9.3375]]`;
- RHS `[1.1666666666666667, 2.666666666666667]`;
- solution `[0.36346540908222763, 0.4651299454948799]`;
- residual norm `8.005932084973442e-16`, tolerance `1e-13`;
- source/field/return/heat power `[120.0, 90.0, 15.0, 15.0]`, energy
  residual `0.0`, ledger residual `0.0`;
- provider calls `0`, mesh calls `0`, solver calls `1`;
- numerical status `ready`; composition and aggregate status
  `terminal_deferred`.

The ten negative vectors covered by the 13/13 assertion group are:

| Vector | Status / code |
|---|---|
| `candidate_mismatch` | `fail_closed / candidate_mismatch` |
| `body_hash_mismatch` | `fail_closed / bundle_body_hash_mismatch` |
| `bundle_hash_mismatch` | `fail_closed / bundle_hash_mismatch` |
| `unsupported_expression_subset` | `terminal_deferred / unsupported_expression_subset` |
| `missing_mesh_authority` | `terminal_deferred / g2_admission_terminal_deferred` |
| `missing_feedback_authority` | `terminal_deferred / g3_admission_terminal_deferred` |
| `invalid_overlap` | `terminal_deferred / invalid_overlap` |
| `singular_sparse_system` | `numerical_fail / singular_or_nonfinite_sparse_system` |
| `nonfinite_derived` | `numerical_fail / singular_or_nonfinite_sparse_system` |
| `ledger_contradiction` | `fail_closed / ledger_contradiction` |

The acceptance ceiling is `screen_only`.  This record has
`accepted=false`; aggregate/composition remain `terminal_deferred`; and it
grants no formal UP credit, no formal R credit, and no physical credit.  It is
a local software/numerical receipt only: no provider, mesh-authority,
engineering, candidate, whole-device, or physical validation claim is made.

## Frozen six-file integrity

The nested receipt has `hashesComparable=true`,
`ownedFilesUnchanged=true`, and an empty `owned_hash_changes.json`.  The six
before/after SHA-256 values are identical:

| Protected file | SHA-256 |
|---|---|
| `src/RuntimeV4/DeclaredG123DiffusionExecutionV1.jl` | `45e9fee04bebe7a62ee07456acee42834da7b8c9a8ca5bce95fdf2fe90013bef` |
| `test/RuntimeV4/DeclaredG123DiffusionExecution/fixture.jl` | `e57e3d1060b1ea3e86c7d9ff6b2ae73f41ce9275f105c0e10482703095029eda` |
| `test/RuntimeV4/DeclaredG123DiffusionExecution/focused_tests.jl` | `b68c39a986beb21187bc737cbae02f97d7ee52b73b536fc53431bdf664aa90f3` |
| `test/RuntimeV4/DeclaredG123DiffusionExecution/fixture.json` | `bcb56c536e90f0643fb7e7abdfd3441110e573327ec993421b022211a7cb9d2e` |
| `test/RuntimeV4/DeclaredG123DiffusionExecution/independent_oracle.py` | `eb1f17556b4fd664391e1fb3f2cac06295c167b1be47a8f7447c63434c9134cf` |
| `test/RuntimeV4/DeclaredG123DiffusionExecution/static_qa.py` | `4135b46d46fe9b12c590f6ad2637981b5124f08c5886e4be1d49471b0ed16e2e` |

No Julia or DESC command was run while creating this acceptance record.  No
other file was edited and no commit was created.
