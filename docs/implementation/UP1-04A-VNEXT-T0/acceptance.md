# UP1-04A-VNEXT-T0 implementation record

- status: `review_pending`
- scope_status: `proposal`
- accepted: `false`
- claim_ceiling: `contract_only`
- physical/provider/mesh evidence: `false`
- R01–R10 credit: `false`
- implementation model: `gpt-5.6-luna/high`
- independent review: pending different Luna

This is the first contract implementation slice for AD-30. It adds an
independent V1 declaration transport file, a focused test file, and static QA.
It does not enter `CandidateStatePackageV5`, edit the old Genome/package/shared
entry/registry, or modify any core planning document.

The transport retains the complete G1/G2/G3 declaration bodies and stored
source/declaration hashes. It requires an explicit G2
`GenomeContractRef`→`QualifiedRefV1` envelope, compares one exact candidate
ref across all three declarations, records all four axis provenance entries,
and returns typed `terminal_deferred` gaps for missing mapping/axes, G3 source
content hash and realization/control/binding children. Candidate or axis
conflicts are classified `fail_closed`. The tests use synthetic/oracle-only
objects and do not claim actual candidate authority.

## File ownership

- `src/GenomeV5/Integration/VNextDeclarationTransportV1.jl`
- `test/GenomeV5/Integration/vnext_declaration_transport_v1_tests.jl`
- `docs/implementation/UP1-04A-VNEXT-T0/static_qa.py`

## Verification performed

The static checker was run from the repository root:

```text
python docs/implementation/UP1-04A-VNEXT-T0/static_qa.py
exit=0
{"desc_executed": false, "forbidden_legacy_edits_in_source": false,
 "julia_executed": false, "required_negative_controls_present": true,
 "status": "pass"}
```

No Julia, DESC, provider, mesh, or physical run was started. The focused Julia
test is deliberately pending different-Luna precheck and must be executed only
after the source review and exact command receipt are frozen.

## Hashes

| file | SHA-256 |
|---|---|
| `src/GenomeV5/Integration/VNextDeclarationTransportV1.jl` | `fa093c4ba87c27ab528fd9c3582c377545193212de8198b19bff976bf3947f2b` |
| `test/GenomeV5/Integration/vnext_declaration_transport_v1_tests.jl` | `01aaf8f14311bd9ec9915dabe99bddcf4882cceaae2c0a2ce946c64fafe12413` |
| `docs/implementation/UP1-04A-VNEXT-T0/static_qa.py` | `b200571dc4b0913a9a40cee51ed31612cd1f4487aeb2f258bfad20fe96706cc5` |

The three upstream V1 source hashes remained unchanged during this slice:

```text
G1 14d26ee556029bd1fcf2477f3dbe9599622d37a3f5704d1c0bb1dd9ea31dbf1a
G2 261516671151647bccb71f2fefd5f71cd2ed444f5eeba0bf90b29687d3a78f61
G3 70b045dd3a1fcbfc60f58e0b742c296507343ffc3736aaefd8c2a40e212750d0
```

This record is not an acceptance of T0. Independent source review, focused
Julia execution with raw stdout/stderr hashes, and an independent different-
Luna review remain required before T1.

