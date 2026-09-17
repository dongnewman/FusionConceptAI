# AD-30 T0 R3 repair record

## Decision

`conditional_go` for a different Luna independent static precheck only. This
slice remains a contract-only proposal. It is not T0 acceptance, runtime proof,
provider evidence, mesh evidence, or physical evidence.

## R2 findings addressed

- `vnext_axis_identity_hash_v1` defines and recomputes a canonical identity
  recipe containing schema/version, candidate ref, layer, axis, value, source
  URI/path, source-record hash, and attestation. Any identity mismatch is
  `fail_closed`.
- G2 mapping receipts now carry an explicit
  `verification_status=:external_verification_pending`; the constructor only
  permits that value. A mapped envelope therefore remains terminal-deferred
  until an independently readable external receipt is verified.
- Source-bound axes carry the same explicit verification status. A trusted
  attestation marker does not turn a self-reported record into verified source,
  and the external verification gap is retained in the production result.
- G3 contradictory upstream and feedback authorities are explicitly
  `fail_closed`, in addition to stale declaration/body hash checks.

## Production-path negative controls

The T0 test now exercises mapping candidate mismatch and stale source-record
hash, axis identity mismatch and candidate mismatch, synthetic-oracle
deferral, stale G3 ledger/feedback/authority edits, contradictory upstream and
feedback authorities, unattested actual authority, stale declaration hashes,
and the retained G1/G2 source-edit source/body/declaration/bundle hash checks.

## Evidence boundary

No current G2 candidate mapping evidence ref or applicability/evidence axis
record is independently readable and verifiable. The implementation therefore
uses typed receipt fields plus `external_verification_pending` and preserves
`terminal_deferred`; it does not manufacture a receipt or claim `resolved`.
G3 source-content hash and realization/control/binding child identities remain
typed absent.

Only these gates ran:

```text
python docs/implementation/UP1-04A-VNEXT-T0/static_qa.py
exit=0
status=pass
julia_executed=false
desc_executed=false
python -m json.tool docs/implementation/UP1-04A-VNEXT-T0/repair_r3/evidence_manifest.json
exit=0
git diff --check
exit=0
```

No Julia, DESC, focused, T1, provider, mesh, or physical execution occurred.

## File boundary

R3 touched only the T0 transport source, T0 test, static QA, and the new
`repair_r3/` records. G1/G2/G3 source, legacy V5/package/shared entry/registry,
core documents, and prior receipts were not edited.

## Hashes

| file | SHA-256 |
|---|---|
| `src/GenomeV5/Integration/VNextDeclarationTransportV1.jl` | `f4d0992fecd0c145734eadf50625789d8bdb6298fa1ffdd38a5b3a4624c53fcf` |
| `test/GenomeV5/Integration/vnext_declaration_transport_v1_tests.jl` | `015b7117f9c541edd3a4fc79982835b0ba6fc7ca10f5113525891f9acbf801f7` |
| `docs/implementation/UP1-04A-VNEXT-T0/static_qa.py` | `381682b1fbc525df042257a3e1733a54e5d803210a90e7de1e47d9e58d669c2f` |

