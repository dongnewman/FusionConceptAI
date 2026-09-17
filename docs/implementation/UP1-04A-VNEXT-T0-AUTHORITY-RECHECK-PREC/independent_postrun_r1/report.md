# UP1-04A-VNEXT-T0-AUTHORITY-RECHECK-PREC independent postrun R1

Date: 2026-09-15  
Reviewer: independent Luna/high (`/root/g2_metric_boundary_v1_author`)  
Decision: `changes_requested`  
Review mode: read-only evidence and static semantic audit; Julia/DESC were not run in this review.

## Boundary

The seven-file implementation scope is present and matches the task manifest. The current machine node remains `planned` / `proposal` / `review_pending` with `accepted=false`, `launcher=false`, `claim_ceiling=contract_only`. AD-34 remains an architecture/work-order acceptance only. This review does not accept a T0 authority, T1/T2, provider, mesh, engineering, physical, B00/B04, or R01-R10 credit.

## Current seven-file identity

All seven paths exist. The six non-self artifact records in the implementation manifest match the current bytes; the implementation manifest is also recorded below and is self-hash excluded from its own input set.

| path | bytes | SHA-256 |
|---|---:|---|
| `src/GenomeV5/Integration/VNextDeclarationAuthorityRecheckV1.jl` | 14402 | `f321301f54021d778352049a1d6e2c3167d71ad9c701a2ddbaee6dcdf73cc8b6` |
| `test/GenomeV5/Integration/vnext_declaration_authority_recheck_v1_tests.jl` | 10477 | `02f2e1d318716ddbaec3b2194cd1fe166e0d13823cf04f65461d0a855586cfe4` |
| `test/GenomeV5/Integration/vnext_declaration_authority_recheck_v1_fixture.json` | 1953 | `cdf9095c15dd082c5c374b03742575301087906962617023090ae6b0db4deb59f` |
| `test/GenomeV5/Integration/static_qa_vnext_declaration_authority_recheck_v1.py` | 1946 | `9d18ad1297caad2d5eb8d254bf0a8f1b6781d349c2d2490e4993a2af1fdad51d` |
| `docs/implementation/UP1-04A-VNEXT-T0-AUTHORITY-RECHECK-PREC/README.md` | 2579 | `6bc4e8ffb56787745bfc4368e7e9b3af7958906c8fcd00aeb42cbb7e16194e0e` |
| `docs/implementation/UP1-04A-VNEXT-T0-AUTHORITY-RECHECK-PREC/acceptance.md` | 2112 | `be294fdaed57fa335a9918d3a5c3b04edb3aa743fa003f604328b36afa01cdd8` |
| `docs/implementation/UP1-04A-VNEXT-T0-AUTHORITY-RECHECK-PREC/manifest.json` | 16924 | `291c9918a42ed2e8ee5cc47fe8817328df008732e60d2ebff596800b1110e1ee` |

Observed repository HEAD was `4b69f55f7f80240147a65a22809dc1207824dde2`; the checkout was already broadly dirty. No existing dirty or historical file was changed by this review.

## Execution receipt audit

The append-only manifest contains five static attempts and five focused Julia attempts. Static R1-R5 all record exit 0 and `AD34_T0_STATIC_QA=pass checks=19`; the Python executable is `D:\Users\Newman\anaconda3\python.exe`, Python 3.13.5, SHA-256 `388fe2cffda8a134e7d7dc4e978f7c478857ece6b69694daecbed25e51ec633a`. The executable was reidentified at review time with the same path, version, and SHA.

Focused history is preserved in order: R1 exit 1 (`owner_scope` missing), R2 exit 1 (`contract_hash` type), R3 exit 1 (untyped G3 law/closure), R4 exit 1 (tuple snapshot `copy`), and R5 exit 0. The Julia executable is `C:\Users\Newman\AppData\Local\Programs\Julia-1.10.5\bin\julia.exe`, Julia 1.10.5, SHA-256 `8e86e2d48c574393c37bbfb6e922ea4176ba8e1a83f956826f3da24948e389ad`. The final receipt states `12/12, 15/15, 14/14, 12/12, 6/6, 4/4`, total 63/63, typed-absent-or-fail-closed, present false, actual credit false, exit 0, PID 75668. No current Julia or DESC process was present during this review.

The receipt evidence is not independently admissible as raw-byte evidence. There are no standalone stdout/stderr raw files or run metadata under this work-order directory. The static R1 field can be hashed as recorded, but static R2-R5 store a literal escaped `\\r\\n` representation while retaining the hash of CRLF bytes. Every focused R1-R4 stdout field and failed stderr field fails SHA recomputation from both the parsed field and its escaped-newline decoding; focused R5 stdout likewise fails recomputation, while its empty stderr hash is reproducible. Therefore the recorded PID/UTC/exit facts are observable claims, but the focused raw SHA/byte claims cannot be independently rechecked from the archived evidence. This is a receipt-completeness blocker, not a claim of rerunning the test.

The cleanup inventory records empty task-owned scratch/cache and removed paths, protection of preexisting dirty/historical paths, and protection of remote PIDs. The implementation directory itself has no separate raw, repair, process, or cleanup receipt files beyond the manifest fields, so those claims remain manifest-only.

## Static semantic audit

The implementation correctly expresses exactly one upstream authority for each required layer G1/G2, rejects duplicate/missing/unknown layers, checks target-layer and target-authority candidate consistency, derives the eight-field target key, rejects duplicate keys and duplicate target IDs, and compares the six-field legacy projection only for contradiction. Equality does not promote authority. `actual`, `missing`, and `historical_absent` map to typed absence with terminal-deferred reasons; stale, contradictory, and unmapped statuses fail closed. Absence digests include candidate, layer, reason, and T0 bundle hash. The immutable tuple snapshot preserves prior bytes and SHA on failure. Synthetic, ref-only, fixture, incomplete, candidate-mismatched, and declaration-hash-mismatched fresh records are rejected by the public function; no five-field declaration identity is synthesized. The current fixture has no fresh authority and the expected current state is typed absent only.

A semantic blocker remains in `_vnext_ar_pair`: it validates `candidate_ref` against every upstream authority and target authority, but never compares `declaration.candidate_ref` with the input candidate. A declaration object with a foreign candidate field and otherwise matching G1/G2 records can therefore pass the pairing gate and reach typed absence. The contract explicitly requires foreign-candidate rejection, and the focused negative tests cover a foreign target authority but do not cover a foreign declaration candidate. Add the declaration-level candidate equality check and a focused negative control before acceptance.

The source also contains an unreachable fresh-record layer guard because the constructor already restricts fresh layers to G1/G2; this is harmless but does not replace the missing declaration candidate check. The current test set does not independently exercise unknown legacy status or a fresh declaration-hash tamper, although the corresponding source branches are present.

## Required disposition

Keep the machine node `planned` / `proposal` / `review_pending` / `accepted=false`. Repair the declaration-level candidate gate and add its negative test. Preserve the existing five focused attempts, the final 63/63 observation, the raw receipt mismatch facts, and the cleanup inventory; do not rewrite historical receipts. Re-run the authorized static/focused evidence serially only after the source/test repair, with standalone raw stdout/stderr and run metadata so the hashes and byte lengths are independently reproducible. Until then, this node is `changes_requested`; the actual/physical/engineering/provider/mesh/T0/T1/T2/B00/B04/R01-R10 credits remain false.
