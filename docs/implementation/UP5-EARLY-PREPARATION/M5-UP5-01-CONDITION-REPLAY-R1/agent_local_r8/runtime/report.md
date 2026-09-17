# UP5-01 ConditionEnvelope R8 runtime archive

Date: 2026-09-18 (Asia/Shanghai). This directory archives the already
completed parent runtime receipt. The archive lane itself ran no Julia, DESC,
provider, solver, mesh, or search process, changed no product/test/manifest
state, and created no commit.

## Receipt result

Source: `runs/agent_local_up5_condition_replay_contract_matrix_20260918_r8/`.

- command: Julia 1.10.5 focused isolated contract test;
- HEAD: `a6b9de90143dd46cbfc81243735e1d2ba7eb6bf6`;
- exit code: `0`;
- stdout: `136 pass / 136 total`, `0.7s`;
- stderr: `0` bytes;
- `hashes_unchanged=true`;
- pre/post four-input hash receipts equal;
- current four input bytes equal the R8 receipt (see
  `source_hash_verification.json`).

The raw source artifact SHA-256 values and normalized archive-copy SHA-256
values are recorded individually in `archive_manifest.json`. JSON/head copies
are semantically identical to their source receipts; the byte-count difference
for those files is only the archive's newline/format normalization. `stdout.raw`
and zero-byte `stderr.raw` are byte-identical.

## Failure lineage and boundary

R3 ParseError, R4 Julia 1.10 `@testset` macro failure, R5 direct-generator
`sort` MethodError, and R6 `91/107` stale evaluation-hash failures remain
preserved in their original `runs/` directories. Independent R7 remains a
documented **NO-GO** for the identity-ordering bypass; R8 is the repair lineage
that produced this receipt. Details and paths are in `lineage.json`.

This receipt confirms only the isolated contract suite. It does not publish a
candidate or transfer UP5, solver, numerical, physical, engineering,
conservation, convergence, VVUQ, or R01--R10 credit. The permanent archive
boundary is `contract_only / screen_only / accepted=false / no_publish=true`.
Runtime success is not whole-device acceptance.

## Archive verification

The four current input SHA-256 values are:

| Path | SHA-256 |
|---|---|
| `src/RuntimeV4/M4Isolated/ConditionalEGraphConditionEnvelopeV1.jl` | `6d1076cd2d755932d6ecf0e016e188cc8b4f5471af10f1f6029f36379953586a` |
| `test/RuntimeV4/M4Isolated/conditional_egraph_condition_envelope_v1_tests.jl` | `1468a3b0f1304540e0acc748e3308c777cef960ffb7b8ceec61da70946ccd242` |
| `test/RuntimeV4/M4Isolated/conditional_egraph_condition_envelope_v1_fixture.json` | `245fb79a7f08fb6b509bf32186a56defd1a4f9cfd8be93f47bbbc56a83890a48` |
| `test/RuntimeV4/M4Isolated/static_qa_conditional_egraph_condition_envelope_v1.py` | `c4d5e29dfd60cd0ac7a160f65abb231e3974bcacabf75f11b2fafbd61fec1678` |

No Julia/DESC was started for this archive; the runtime result is referenced
from the parent run only. No UP5 or R01--R10 credit is granted.
