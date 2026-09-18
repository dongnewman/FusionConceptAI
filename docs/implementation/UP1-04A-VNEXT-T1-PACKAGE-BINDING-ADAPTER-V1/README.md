# VNext T1 package-binding adapter V1

This is a definition-only, additive slice.  It rechecks the closed
`CandidateStatePackageV5Next` joins needed to map
`candidate_ref`, `semantic_identity`, and `package_hash` into an explicit
`VNextT1CandidateBindingInputV2`; an optional `VNextT1CanonicalBytesV2` wire
is carried without changing the V2 contract.

The adapter is not connected to `FusionConceptAI.jl`, the registry, UP2, V4,
or any runtime/provider.  A valid mapping retains
`prepared_not_executed`/`terminal_deferred`, remains `accepted=false` and
`contract_only`, and is not execution or physical evidence.  A G3
`typed_absent` child produces `terminal_deferred` with no binding input.  Any
candidate, component, semantic-identity, or package-hash conflict is
`fail_closed`.

Validation is static only in this handoff.  Julia was deliberately not run.
