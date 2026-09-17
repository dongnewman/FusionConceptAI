# AD-24 independent review

Verdict: `pass_limited` for the architecture boundary and source-provenance audit. This review does not accept an N05/N06 implementation, UP2 total, B00/B04, provider, mesh, engineering, physical, or R01-R10 result.

## Scope and protected evidence

The AD-24 decision, author acceptance/manifest, immutable N05/N06 source audit, frozen contracts, and actual G1/G2/G3/UP2 source were read at the current HEAD. Their current SHA256, byte counts, and mtimes are recorded in `input_hashes.json`; the AD-24 manifest's decision and audit artifact hashes match the current bytes. No Julia/DESC command was run. Only this independent_review directory is writable for this task.

## Decision-to-source checks

The decision in `docs/v4_multitopology_generation/18_sources_and_architecture_decisions.md:188-204` matches the inspected source and the audit:

- `G2InterfaceV2` at `src/GenomeV5/G2/RegionInterfaceContractV2.jl:54-84` has a `QualifiedRefV1`, two region IDs, axis, coordinate, geometric normal, continuity, and transfer kind. It has no flux/traction/current endpoint, flux sign, or flux unit. The normal constraint at lines 70-73 is a geometric structural check, so the decision correctly prohibits using it as physical flux sign.
- `G1EquationV2` at `src/GenomeV5/G1/EquationPlanV2.jl:120-170` supplies equation units, temporal/derivative values, typed occurrences, and closure reference. Those fields are not an authored interface endpoint or dimensioned source-to-field law. The decision correctly treats equation input units as insufficient flux-unit authority.
- `G3ResourcePortV2`, `G3LedgerAccountV2`, `G3LedgerEntryV2`, and `G3LedgerClosureV2` at `src/GenomeV5/G3/RealizationGenomeV5.jl:254-269` and `:402-449` provide typed local resource/ledger data. `g3_validate_resource_network` at `:504-569` checks local references, units, capacity, required kinds, closure membership, domains, and balances, but does not establish the G1 occurrence to G3 account/entry/energy-boundary mapping.
- The existing G3 contract text lists owner uniqueness, but the actual test explicitly permits multiple accounts with a shared owner at `test/GenomeV5/G3/up1_g3_contract_tests.jl:245-252`. AD-24 correctly keeps shared owner legal and requires an explicit account/closure owner scope before classifying double count.
- The old UP2 wrapper at `src/GenomeV5/UP2/TypedPrecompilerValidatorV1.jl:105-154` projects `pending-port:left/right`, `normal/-normal`, and `eq.input_units[1]`; `UP2FluxPairV1` at `src/GenomeV5/UP2/TypedPrecompilerContractV1.jl:80-115` permits those synthetic values. AD-24 explicitly rejects these as authority and requires a new additive binding, so the old wrapper is not silently upgraded.
- `CandidateStatePackageV5` at `src/Contracts/CandidateStatePackageV5.jl:159-226` computes its existing candidate hash from package identity and receipt. AD-24's new binding hash participates in a new bound-input identity without rewriting this package hash, which preserves the V5 boundary. The integration identity checks at `src/GenomeV5/Integration/GenomeV5Integration.jl:146-185` support exact public refs, component hashes, axes, child refs, and feedback checks; they do not supply the missing N05/N06 physical law.

## Boundary and failure semantics

The decision keeps UP0-02 N05/N06 provisional rows as historical registrations and does not shrink their obligations. It distinguishes missing endpoint/sign/unit/conversion/owner-scope authority (`terminal_deferred`) from a present typed declaration that violates a declared ref, candidate, direction, sign, unit, capacity, closure, or mapping invariant (`fail_closed`). This agrees with the frozen N05/N06 obligation rows in `19_up0_02_contract_freeze.md:61-76` and the explicit AD-24 text at core 18 lines 196-204.

The proposed `UP2CandidatePhysicalBindingV1` is additive, editable, candidate-owned, versioned, and content-hashed. The decision requires complete public five-field refs, component hashes, four axes, package candidate/hash binding, and its own schema/canonical/profile/binding hashes. It permits G2 `QualifiedRefV1` only as an internal child locator. It requires authored N05 laws with endpoint/sign/unit provenance and authored N06 source-field-return-heat/ledger owner-scope mappings; self-consistency remains contract authority only. These conditions match AD-20/AD-22 and do not imply provider, mesh, or physical execution.

## Verdict and ceiling

No material semantic contradiction was found. The only open items are intentional authority gaps documented by AD-24: actual N05 endpoint/sign/unit provenance, actual N06 dimensioned cross-layer mapping, and owner-scope/join policy. The correct state is `pass_limited` for architecture/provenance only. All 50 formal B04 receipts, checker and two-process replay remain pending; no implementation, provider, mesh, engineering, physical, or R01-R10 credit is available.

Verification commands and exact exits are recorded in `manifest.json` and the corresponding log files. No source, test, core document, author archive, task manifest, or run was changed.
