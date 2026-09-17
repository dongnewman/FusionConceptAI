# AD-30 T0 R4 repair record

## Decision

`conditional_go` for another independent static precheck only. The T0 slice
remains contract-only and terminal-deferred where external receipts are
missing. It is not T0 acceptance, runtime proof, provider evidence, mesh
evidence, or physical evidence.

## R3 findings addressed

- G3 upstream and feedback authorities with `status=:stale` now produce
  explicit `fail_closed` errors, alongside contradictory authority handling.
- The production path checks every locally verifiable G2 mapping field:
  source reference, source version, source candidate reference, joined
  candidate reference, source-record hash, source hash, canonical mapping field
  path, attestation, and the required verification status. Tests exercise each
  mismatch using the transport entry point.
- A present axis with a correct identity recipe and `attestation=:trusted_receipt`
  is explicitly asserted to remain `resolution=:terminal_deferred` with
  `axis_external_receipt_verification_pending`.

The `evidence_ref` remains an opaque external reference. There is no locally
available readable receipt against which it can be compared, so T0 retains it
as typed data and keeps `external_verification_pending`; no digest is treated
as proof of external provenance.

## Negative controls and evidence

The tests cover G2 source ref/version/candidate/hash/path/attestation mismatches,
candidate mismatch, stale mapping record hash, axis identity and candidate
mismatches, synthetic axis deferral, trusted-but-pending axis deferral, G3
ledger/feedback/authority edits with stale declaration hash, stale authorities,
contradictory upstream/feedback authorities, unattested actual authority, and
the retained G1/G2 source edit hash chain.

Only these gates ran:

```text
python docs/implementation/UP1-04A-VNEXT-T0/static_qa.py
exit=0
status=pass
julia_executed=false
desc_executed=false
python -m json.tool docs/implementation/UP1-04A-VNEXT-T0/repair_r4/evidence_manifest.json
exit=0
git diff --check
exit=0
```

No Julia, DESC, focused, T1, provider, mesh, or physical execution occurred.

## File boundary

R4 touched only the T0 transport source, T0 test, static QA, and the new
`repair_r4/` records. G1/G2/G3 source, legacy V5/package/shared entry/registry,
core documents, and prior receipts were not edited.

## Hashes

| file | SHA-256 |
|---|---|
| `src/GenomeV5/Integration/VNextDeclarationTransportV1.jl` | `30406b183ba45f740fa8c41dd5ceb1c5d2fd390b19da1c978fcff9e11501504e` |
| `test/GenomeV5/Integration/vnext_declaration_transport_v1_tests.jl` | `d0463fab22450199e9a84f58753fe1255bdda70962f766da751d85e54c4ddbf7` |
| `docs/implementation/UP1-04A-VNEXT-T0/static_qa.py` | `cd57913db629333d8a000834a2153a779393f2a1cea0ba67c7dd5699f7d97e78` |

