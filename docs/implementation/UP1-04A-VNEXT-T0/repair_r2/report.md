# AD-30 T0 R2 repair record

## Decision

`conditional_go` for an independent static precheck only. This is a contract-only
T0 proposal and is not T0 acceptance, runtime proof, mapping proof, provider
evidence, mesh evidence, or physical evidence. The current V1 inputs still do
not provide an independently verifiable G2 candidate mapping receipt or
applicability/evidence axis receipt, so the production path remains
`terminal_deferred` whenever those records are absent.

## R1 changes addressed

- A G2 `:mapped` envelope now requires `VNextG2CandidateMappingReceiptV1`.
  The receipt binds source reference/version, source candidate reference, joined
  candidate reference, complete G2 source-body hash, stored source hash,
  evidence reference, field path, and attestation. An arbitrary digest, URI, or
  path cannot create a mapped candidate.
- A source-bound axis now requires both a source-record hash and identity hash.
  It also carries and checks the candidate reference. T0 recomputes the
  declaration body hash for the corresponding layer and rejects stale hashes.
  A trusted marker still leaves an external receipt verification gap; it does
  not create provider or physical evidence.
- G3 upstream and feedback `status=:actual` with any attestation other than
  `:trusted_receipt` are `fail_closed`. Trusted authority remains subject to an
  external verification gap and does not raise the claim ceiling.
- The production-path tests now cover fake/stale mapping receipts, forged axis
  receipts, synthetic-oracle axes, bare actual feedback, upstream actual
  authority, stale declaration hashes, candidate/axis contradictions, and G1
  and G2 source edits changing source, declaration/body, and bundle hashes.

## Static evidence

The only executed gate was:

```text
python docs/implementation/UP1-04A-VNEXT-T0/static_qa.py
exit=0
status=pass
julia_executed=false
desc_executed=false
```

No Julia, DESC, focused test, T1, provider, mesh, or physical run was executed
by this repair. A different Luna must independently precheck the new source,
tests, and this record before root decides whether to run the focused Julia
gate.

## File boundary

R2 touched only the T0 transport source, its T0 test, static QA, and this new
`repair_r2/` record. G1/G2/G3 source, legacy V5/package/shared entry/registry,
core documents, and old receipts were not edited by this repair.

## Hashes

| file | SHA-256 |
|---|---|
| `src/GenomeV5/Integration/VNextDeclarationTransportV1.jl` | `30031df3aaf59165ece5e3b667cb93b30c31af1c84bbc9a0be9c39f8bb42838b` |
| `test/GenomeV5/Integration/vnext_declaration_transport_v1_tests.jl` | `350bee3b0dbf31785e8adf8ef6e90219a2487ffef443a8a982509324af87f04a` |
| `docs/implementation/UP1-04A-VNEXT-T0/static_qa.py` | `3249587e2f9fbdfdff66981e1736e5e0a72fc1abbf075345d9f859f09907d80e` |

The pre-R2 hashes are retained in `evidence_manifest.json`. The existing
`acceptance.md` and prior T0 evidence manifest were not rewritten.
