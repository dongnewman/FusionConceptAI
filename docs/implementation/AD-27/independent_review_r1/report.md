# AD-27 independent static review r1

Verdict: **changes_requested**. The architecture boundary is otherwise pass-limited, but the archive does not yet make the claimed append-only core change independently reproducible: `decision_manifest.json` and `evidence_manifest.json` record only `*_before` hashes for README/core16/core18 and no after hashes or bounded before-to-after diff. The current bytes and index placement were recorded below, but a reviewer cannot cryptographically establish the append-only claim from the author archive alone.

## Frozen inputs and current bytes

| input | current SHA-256 |
|---|---|
| `docs/v4_multitopology_generation/18_sources_and_architecture_decisions.md` | `9d5d32feda8320db05bd2b9b7ecc3fcb5d82c0a832ec27d2a39222da0960cead` |
| `docs/v4_multitopology_generation/README.md` | `e208d32ed2febd635dd416dc221ecb01992b67f363287caf8ee11485ee03d8c0` |
| `docs/v4_multitopology_generation/16_execution_work_orders.md` | `9c1dc8107ffb299f423084410b12e84a7ee58450da7262c18bd34f0bd8b12c63` |
| `docs/implementation/AD-27/decision.md` | `c02340a8850844d6f1d3b0f0cea162300b3d03edffd990ca38345949f32a9fe8` |
| `docs/implementation/AD-27/decision_manifest.json` | `4f70969a4e4aae5689df24d6c7254323717f41c77d911d186efdd11b19e3d171` |
| `docs/implementation/AD-27/evidence_manifest.json` | `0134fcbc6d09deaeeb4cb151320db7a840c70d20045c50658ddb723c3cb8b042` |
| N06 author unit-gap audit report | `4580b9f7d612fb1d449b3621b29664207d2b9dc3be9eb9f0f3589a88a3cf534c` |
| N06 independent audit report | `d56bcc325d41524745ec0a5563277bf04b066aaa5b916d9499fa1017da63fb4c` |
| AD-24 decision | `ade7ca5923cfd2ce9cda5e8b7563fdf760a2e123f10f195ec9ac13cc8d66773c` |
| AD-26 decision | `a3564e3fcfafe557373990ceb526d351a83f2848c74e441a7b02158fbb49b9a5` |
| `src/Contracts/CandidateStatePackageV5.jl` | `c5c70e8798e0e12fa63ecbfc766079266e770735216c0e2724012d4c9527e620` |
| `src/GenomeV5/UP2/UP2CandidatePhysicalBindingV1.jl` | `804cf2cb3522eceefe37664737934bcffdad15ba2d5d2a28c0a70bcf1fca1f6d` |
| `src/GenomeV5/UP2/N06SourceFieldLedgerMappingV1.jl` | `69bd82f040f405e55768e52af64b9b9b6d97272a2ec3988b66b7bdf21ec1128c` |

The AD-27 section is at the end of core18 (lines 230–240), after AD-26. README line 97 and work-order line 756 link the same `#ad-27` anchor and archive path. Those index links are accurate and preserve proposal/review_pending status.

## Contract findings

1. H0 correctly requires candidate ownership, editability, versioning, an independent content hash, actual CandidateStatePackageV5/E0 input, all four axes, complete public refs/component hashes, and exact G1 occurrence/equation/operator, G2 region/interface/boundary, and G3 port/account/entry/closure/link/feedback endpoints. It also requires units, equation variables, scale/efficiency/calibration provenance, direction/sign, conservation and owner scope.
2. The E1 branch is correctly typed-absent rather than silently omitted: core18 AD-27 requires `schema_hash`, `canonicalization_hash`, `compatibility_profile_hash`, and an absence-content hash. AD-26 independently requires the same fields for every absent marker and keeps E0 v1 `n05`/`n06` as `nothing`.
3. The N06 evidence is represented correctly. Actual G1 occurrences are dimensionless while G3 effort/flow/load/return/heat values use V/A/W-like signatures. `_n06_conversion_law_hash` is only a versioned rule-token digest; AD-27 correctly excludes it, local G3 balance, synthetic examples, pending-port tokens and disconnected URIs from physical authority. Missing dimensioned conversion/provenance remains typed absent/`terminal_deferred`.
4. H1 is sufficiently bounded at architecture level: it must independently parse frozen actual A/E0/source payload, recompute endpoint/unit/sign/provenance/conservation/hash identity, reject foreign/stale/wrong-axis/wrong-endpoint/wrong-unit/duplicate/omitted rows, and avoid H0 expected-row/classification helpers. Formal exit remains downstream B00 F0–F5, fifty fresh B04 receipts, an independent checker and two fresh processes.
5. Status and credit boundaries are preserved. AD-27 remains proposal/review_pending, runtime not run, `contract_admission` proposal-only, `physical_resolution` unknown, and all B00/B04/provider/mesh/engineering/physical/R01–R10 credits false. No UP0–UP6 DAG or parent obligation is reduced.

## Required minimum correction

Add current after hashes for the three core/index files and AD-27 decision files, plus a bounded before-to-after diff or equivalent append-only receipt tied to the recorded before hashes. The correction must not change the AD-27 contract text or promote its status. Until that receipt exists, this review remains `changes_requested` for archive reproducibility, while the architecture itself is accepted only in the limited proposal sense above.

No Julia/DESC process was started. This review grants no implementation, provider, engineering, physical, B00/B04, or R01–R10 credit.
