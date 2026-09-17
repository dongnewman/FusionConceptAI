# AD-30 T0 R5 repair record

## Decision

`conditional_go` for another independent static precheck only. T0 remains
`accepted=false`, contract-only, and terminal-deferred where external receipts
are unavailable. No runtime, provider, mesh, or physical claim is made.

## R4 finding addressed

The G2 source-hash negative control now uses the same valid G2 source, source
candidate, candidate envelope, evidence reference, field path, source-record
hash, and trusted attestation. Only `receipt.source_hash` is changed to a stale
digest. The production transport path is asserted to return exactly
`("G2_mapping_source_hash_mismatch",)`, proving this mismatch is independently
detected rather than being coupled to a changed source-candidate variant.

All R4 stale/contradictory authority, axis pending, mapping field, and source
edit hash controls remain in place. T0 source, static QA, all V1 sources, and
legacy V5/package/registry files were not changed in R5.

## Evidence boundary and gates

The external `evidence_ref` is still opaque and cannot be locally verified.
This remains an external receipt gap; no opaque digest is used as source proof.

Only these gates ran:

```text
python docs/implementation/UP1-04A-VNEXT-T0/static_qa.py
exit=0
status=pass
julia_executed=false
desc_executed=false
python -m json.tool docs/implementation/UP1-04A-VNEXT-T0/repair_r5/evidence_manifest.json
exit=0
git diff --check
exit=0
```

Julia, DESC, focused tests, T1, provider, mesh, and physical runs were not
executed.

## Hashes

| file | SHA-256 |
|---|---|
| `test/GenomeV5/Integration/vnext_declaration_transport_v1_tests.jl` | `333ff3a2976736e13809b603cdcab61524658b7fb20d1b6506ccf188dea3b063` |
| `src/GenomeV5/Integration/VNextDeclarationTransportV1.jl` (unchanged) | `30406b183ba45f740fa8c41dd5ceb1c5d2fd390b19da1c978fcff9e11501504e` |
| `docs/implementation/UP1-04A-VNEXT-T0/static_qa.py` (unchanged) | `cd57913db629333d8a000834a2153a779393f2a1cea0ba67c7dd5699f7d97e78` |

