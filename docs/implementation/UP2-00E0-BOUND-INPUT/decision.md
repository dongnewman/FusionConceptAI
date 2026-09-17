# UP2-00E0 bound-input scaffold

This additive scaffold implements the AD-24 envelope boundary for an actual `CandidateStatePackageV5`. It binds the candidate reference, the three public five-field outer `GenomeContractRef` values, three component hashes, the package's four version axes, and the original package hash into a new bound-input identity.

The original `CandidateStatePackageV5.candidate_hash` is copied as `package_hash` and is never rewritten. The new `binding_hash` is content-derived from the envelope and participates in `bound_input_hash`. N05 and N06 are represented only by separate typed abstract extension contracts. With no declaration, the envelope records independent `terminal_deferred` gaps. A later E1/E2 version must hash the full typed declaration content into the bound identity; presence flags in this E0 version are not declaration completion or physical authority.

The source-backed factory accepts only an actual `CandidateStatePackageV5`, recomputes its package identity, checks component identities and axes against their concrete G1/G2/G3 objects, and fails closed on mismatch. It never calls a compiler, provider, solver, mesh, or physics routine. The typed expected-identity checker exists only for negative controls and does not grant source authority.

Scope is `schema_validation_only`, `review_pending`, `accepted=false`. This work carries no UP2 total, B00/B04, provider, mesh, engineering, physical, or R01–R10 credit. Independent Luna review is required.
