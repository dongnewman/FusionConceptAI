# UP2-00C N10 source audit

The audit was read-only before implementation. `CandidateStatePackageV5` owns
`candidate_ref`, three concrete components, `g2_binding`, `version_axes`, the
migration receipt, component identity, and `candidate_hash`.

`GenomeV5Integration.jl:80-85` defines the actual five-field identity
projection: URI, version, schema hash, canonicalization hash, and compatibility
profile. `GenomeV5Integration.jl:323-333` constructs the component identity,
rebuilds `candidate_identity_after`, and passes the receipt into the package
canonical hash. `CandidateStatePackageV5.jl:116-120` shows that a fresh receipt
is pending with no records before that rebuild.

The authoritative typed G3 binding child is
`package.g3.binding.contract_binding.contract_ref`. The corresponding
`component_identity.g3_child_refs.binding` is an identity `NamedTuple`, so the
new N10-03 row records both and compares all five fields. Its wrong-child
negative uses the actual sibling
`package.g3.control.contract_binding.contract_ref`, rather than reconstructing a
typed ref from the identity tuple. Package-owned N10-04/N10-05 fields use the
candidate `QualifiedRefV1` as source owner and the package hash as source hash.
The archived UP1-04A
runtime emitted package hash
`67bf32d7d55b06eac1f495a50fcb1620babd48d9ebbce14867f854f32b3064a5` and
receipt-after identity
`31f3390f62193e274b781c5e61d15ffd7c6097e5fab160000f36af47106542b0`.

AD-23 requires new versioned N10 rows and forbids reinterpretation of the old
provisional fixture. AD-19/AD-21 require actual-A foreign/stale value mismatch
to be `invalid_type` plus `fail_closed`, while missing V4 authority remains
`terminal_deferred`. The new archive follows those boundaries and contains no
runtime or physical acceptance claim.
