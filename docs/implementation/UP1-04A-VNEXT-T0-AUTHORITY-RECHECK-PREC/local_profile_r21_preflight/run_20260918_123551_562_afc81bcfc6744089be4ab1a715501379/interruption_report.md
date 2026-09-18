# T0 R21 interrupted receipt (supplemental)

This is a supplemental interruption receipt for the one-shot R21 runner. It
does not replace the runner's missing runtime receipt and does not claim a
completed test, postflight, or acceptance result.

## Interruption and cleanup

- Runner PID: `56812`.
- Child Julia PID: `60096`.
- Outer runner start: `2026-09-18 20:35:50.284 +08:00`.
- Outer runner end: `2026-09-18 20:36:29.709 +08:00`.
- Outer exit: `-1073741510` (`0xC000013A`, interrupted).
- Child cleanup: owned child PID `60096` was terminated at
  `2026-09-18 20:38:40.660 +08:00` under the owned-PID safety boundary.
- Current read-only process inspection: `0` Julia/DESC processes.
- The durable `runtime.lock` is intentionally preserved; it was not deleted.

The run was interrupted before the runner could drain streams or execute its
`finally` block. Therefore the run directory contains only the runner-written
`processes_before.json` and `owned_hashes_before.json`, plus this supplemental
receipt. The following are absent by observation, not fabricated as empty
results: `stdout.raw`, `stderr.raw`, `owned_hashes_after.json`,
`owned_hash_changes.json`, `processes_after_first.json`,
`processes_after_second.json`, `thread.json`, `run_metadata.json`, and
`capture_failure.json`. Runner postflight did not complete.

## Runtime evidence boundary

No Julia/DESC retry was performed. The testset did not emit a `Test Summary`;
positive, typed-absence, mutation, and label/status observations are not
available. Runtime negative evidence is `0/25` negative dispatches reached and
`0/100` negative-object snapshots observed. These are interruption counters,
not pass/fail assertions.

`accepted=false`; claim ceiling remains `contract_only`. No checked-present
authority, T0/T1/T2 credit, or physical/readiness credit is granted. The
one-shot R21 receipt is incomplete/interrupted and is not retried.

## Protected-file hash check

The six before hashes in `owned_hashes_before.json` were compared read-only
with a current hash observation at `2026-09-18` after cleanup. All six are
unchanged. This is a current integrity check, not a runner postflight file:

| protected path | before SHA-256 | current SHA-256 | result |
|---|---|---|---|
| `src/GenomeV5/Integration/VNextDeclarationAuthorityRecheckLocalV1.jl` | `1933f9faf918999170db794639f3f94c66dc6dfd4e3a125eb9fc65ab63bdf0a9` | `1933f9faf918999170db794639f3f94c66dc6dfd4e3a125eb9fc65ab63bdf0a9` | unchanged |
| `test/GenomeV5/Integration/vnext_declaration_authority_recheck_local_v1_tests.jl` | `e8b2f8d10ba18752d540553495dd732412a7ede7fa2ea78926a0acfa7ff399b0` | `e8b2f8d10ba18752d540553495dd732412a7ede7fa2ea78926a0acfa7ff399b0` | unchanged |
| `test/GenomeV5/Integration/static_qa_vnext_declaration_authority_recheck_local_v1.py` | `f4541787d4f6d13245a76aa565f5db93b6b3b9190cea950725a0d5b374239716` | `f4541787d4f6d13245a76aa565f5db93b6b3b9190cea950725a0d5b374239716` | unchanged |
| `test/GenomeV5/Integration/vnext_declaration_authority_recheck_local_v1_fixture.json` | `296a660dd4e907c4d733cfb4d1dc3e6cd4c59949a5128bfdec8409631ff42afc` | `296a660dd4e907c4d733cfb4d1dc3e6cd4c59949a5128bfdec8409631ff42afc` | unchanged |
| `test/GenomeV5/Integration/vnext_declaration_transport_local_v1_tests.jl` | `b1c355c94467c2469fff724c4d02134e9a17ac245b9cc674358393a31864814b` | `b1c355c94467c2469fff724c4d02134e9a17ac245b9cc674358393a31864814b` | unchanged |
| `src/GenomeV5/Integration/VNextDeclarationTransportLocalV1.jl` | `3f3446ec7b641470d1bb45cefed814463aca1af424a858945e09cbb1330ffcaa` | `3f3446ec7b641470d1bb45cefed814463aca1af424a858945e09cbb1330ffcaa` | unchanged |
