# UP3 CompositionMatcher R7 independent postrun review

Date: 2026-09-18 (Asia/Shanghai). This review is read-only. No Julia/DESC
command was run by this reviewer, no product/test file was modified, and no
commit was created.

## Verdict and ceiling

**GO for the isolated R7 postrun contract receipt; NO-GO for formal UP3.**
The serialized R7 runtime receipt is internally consistent and independently
reproducible as an artifact: 49/49 tests, exit `0`, 21.5 seconds, empty
stderr, unchanged inputs, and matching source/archive hashes. The result
remains `contract_only / prepared`, `accepted=false`, `formal_acceptance=false`.
It grants no provider, solver, mesh, conservation, convergence, physical,
engineering, B01/B02/B04/B08, UP3, or R01--R10 credit.

## Runtime receipt checks

The source run is
`runs/agent_local_up3_composition_matcher_contract_matrix_20260918_r7/` and
the copied archive is
`docs/implementation/UP3-EARLY-PREPARATION/COMPOSITION-MATCHER-CONTRACT-R1/agent_local_r7/runtime/`.

- `run.json` reports the focused Julia command, HEAD
  `70cded1ca1b64496bbee44ac0025659f446364ea`, exit `0`, and
  `hashes_unchanged=true`.
- `head.txt` exactly equals `70cded1ca1b64496bbee44ac0025659f446364ea`.
- `stdout.raw` is the expected summary: `composition matcher contract v1 R7 |
  49 | 49 | 21.5s`.
- `stderr.raw` is empty (`0` bytes; SHA-256
  `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`).
- `input_hashes_pre.json` and `input_hashes_post.json` are byte-identical and
  JSON-identical.
- Every copied runtime file (`head`, pre/post hashes, run, stdout, stderr)
  independently matches the source-run SHA-256 and byte count recorded in
  `runtime/archive_manifest.json`.
- Current product bytes and SHA-256 exactly match the R7 input hashes:

```text
src/RuntimeV4/CompositionMatcherContractV1.jl
21260 bytes  aeea3652ac1783ba2acbc8f36d644f3351c3368ae7eabfe5be65ad31af07a867
test/RuntimeV4/composition_matcher_contract_v1_tests.jl
10734 bytes  1f91105831eb865626023410eb74761d110ef3ae5459b3a2651175ed0e6d56f1
test/RuntimeV4/composition_matcher_contract_v1_fixture.json
649 bytes    62ffa652ff0ec098837fb84015ffcfa581bd04f353e27287eb24252e92357edf
test/RuntimeV4/static_qa_composition_matcher_contract_v1.py
6938 bytes   8528f31a9a28cf93d520876c12d0701a761dfbf64cd6e55b2ba88b7fed8beb2b
```

`git rev-parse HEAD` independently returns the same
`70cded1ca1b64496bbee44ac0025659f446364ea`; targeted `git diff --check`
returns exit `0`.

## Prior failure preservation

The R7 archive still points to and preserves all prior failure receipts:

- R3: exit `1`, `CapabilitySignatureV4` undefined;
- R4: exit `1`, invalid package-root import still left the capability type
  undefined;
- R5: exit `1`, padded digest was not a legal 64-character digest;
- R6: exit `1`, 36 passed/7 failed due implicit input-schema mismatch and
  stored-plan hash mismatch.

Each prior receipt reports `hashes_unchanged=true`; R7 did not overwrite or
reinterpret those failures. The R7 repair report and manifest retain the
R6 parent-failure reference.

## Boundary decision

This is an isolated contract test only. `CompositionMatcherContractV1` remains
additive and does not prove automatic numerical composition, provider
authority, solver execution, mesh/discrete closure, conservation, convergence,
or physical/engineering validity. Keep the status at
`contract_only / prepared / accepted=false`; a later formal UP3 gate requires
the declared execution matrix and independent numerical/engineering evidence.
