# AD48-S2 independent review R1

## Verdict

`changes_requested`. The four scopes are substantively absent and terminal-deferred, and the Julia/static probes confirm that no G3 source-authority factory exists. One bundle source hash closure is inconsistent, so this review cannot grant the `AbsentG3FactoryIdentityV1` acceptance needed to trigger F0.

## Scope and inputs

Reviewed the eight frozen S2 products under `realization/`, `control/`, `binding/`, and `bundle/`, the archived final snapshot and execution metadata, the accepted AD48 S1 source locators, AD47 W1 records, the AD48 topology/acceptance records, the v4 common contract and active work-order/manifest rules, and the G3 source/module/constructor/helper and registry files. The review wrote only this `independent_review_r1/` directory.

The eight product bytes and hashes exactly match `archive/final_snapshot.json`: realization identity `2240/b3a765c1a404dc1921c53c118a9374fc4d849349c340bb0a673c7e563f192bc9`, receipt `2011/f284e87f56655ed0c00ca20c67bcda4cf44eaa1ad46ef833ca79c89e58a027e5`; control identity `2150/ce0b11841577db201af16489ffa706b43dd8da4e291fa6a836a501c9118929f4`, receipt `1939/d5a6b099da324b9fa27873cdb5b4e02c046d24176772b36655c0c4ee47dbaccb`; binding identity `2233/9171e18bf44a398e45b7202e3a67c4e9e976e070b1efa6b2ee60c77311bf70ef`, receipt `1991/51efad2ccbbbfb697bf8b958e611d20707af4b02dc6c02b2f203215f678bc1ed`; bundle identity `2987/9a2a80ba5e74d59029cf80e8b75dc7d62e23b48d7c4f4625a50f72fb9672e796`, receipt `2743/2a502305e57a9472bc94fb7f6814d154380ce6aad785a6972a1e139cfc2938dd`.

## Contract checks

All eight JSON products parse, have a canonical compact body after removing their terminal LF, and have 64-character product SHA-256 values. Every scope reports `AbsentG3FactoryIdentityV1` and `AbsentG3FactoryConstructionReceiptV1`, `terminal_deferred`, `no_publish=true`, `candidate_identity_created=false`, and no declaration or factory identity hash. Each S2 product points to the exact accepted S1 locator.

The source locator closures for all four main G3 sources are exact. The S2 source closures are exact except for one field in `bundle/factory_identity_v1.json`: its `module_identity.source_sha256` and corresponding `source_closure` declare

`8e9d4f1505098b745048a5f741e0cb1edccdcf70a395c212f0a8649a73d62a4`

while the current 6704-byte `src/GenomeV5/G3/RealizationControlGenomeV5.jl` bytes independently hash to

`8e9d4f1505098b745048a5f741e0cb1edcccdcf70a395c212f0a8649a73d62a4`.

The same correct value appears in `bundle/factory_construction_receipt.json`, so the identity and receipt disagree. This is a source-evidence closure error, not a formatting difference. The frozen product hash remains unchanged in this review; the producer must regenerate the affected identity/receipt closure and obtain a fresh independent review.

## Factory and registry probes

The independent Julia 1.10.5 probe parsed all five G3 source modules and confirmed their observed byte counts and hashes. `G3SourceAuthorityFactoryV1`, `g3_source_authority_factory`, `SourceLocatorV1`, `FactoryConstructionReceiptV1`, and `default_operator_registry` are absent from the G3 modules. The required capability triple—consume an independent locator, construct a candidate-bound source declaration, and emit a trusted construction receipt—is absent. Static `rg` finds the generic `SourceLocatorV1` and `FactoryConstructionReceiptV1` only in the parent typed-absence scaffold, which is explicitly not a G3 adapter. No G3 factory registration or registry edit is present; the registry source observed during review is `src/IR/OperatorRegistry.jl`, 64932 bytes, SHA-256 `4c2f4383140527613782288749283d268497846ec915df158164875125677f45`.

Existing candidate hashes, fixture/seed values, URI values, W2R1 values, bundle hashes, own hashes, runner exits, and test exits were rejected as authority or candidate identity derivations. No source, test, fixture, registry, candidate identity, declaration, T0/T1/T2, provider, mesh, solver, engineering, physical, search, R01–R10, or L4 credit is granted.

## Independent execution evidence

The direct Python 3.13.5 validation ran with `D:\Users\Newman\anaconda3\python.exe`, PID `17532`, UTC `2026-09-15T13:32:37.111541+00:00`, process exit `0`; its logical result is `changes_requested` because of the three bundle closure failures recorded in `review/direct_validation_r1.json`. The serial Julia 1.10.5 probe ran with PID `87576`, UTC `2026-09-15T13:32:54.009Z`, process exit `0`. The snapshot replay passed with Python PID `89288`. Planning validation passed with 31 markdown files, 526 links, 39 tasks, and an acyclic DAG. Scoped `git diff --check` exited `0`. These software checks do not constitute physical evidence.

## Required repair gate

Regenerate the bundle factory identity using the actual source bytes, update every affected internal closure/receipt and final snapshot, preserve this failed review as append-only history, then obtain a different Luna independent review. Only a fresh `pass_limited` review may permit the conditional F0 probe; after F0, S2 must be regenerated fresh before S3 and later W1/W2 work.
