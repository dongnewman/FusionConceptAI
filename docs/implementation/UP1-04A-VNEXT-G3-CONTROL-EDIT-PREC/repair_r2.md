# Repair R2 after focused test receipt R1

R1 was executed with the authorized command and exited `1`. Its raw files
remain immutable at `test_r1.stdout`, `test_r1.stderr`, `test_r1.exit`, and
`test_r1.receipt.json`. The failure occurred before the contract assertions:
the test included the additive source in `Main`, while `canonical_hash` and
the repository's canonical `semantic_view` generic are owned by the
`FusionConceptAI` module. The resulting `MethodError` for
`semantic_view(::G3ControlProvenanceSlotV1)` is a test loading-boundary error.

The minimal repair changes only the test loader to
`Base.include(FusionConceptAI, ...)`, so the additive type methods extend the
existing canonical namespace without editing `src/FusionConceptAI.jl` or any
shared registry. Before R2, the source hash remained
`bf5d2b398798c72847364832be610fc1639882fdaf7258f9e73c04bf8e4409a6`; the
repaired test hash is
`0e516864a6523c1c849f8003a4e484c24acea0eaff30375416375235dec9281d`. The
pre-rerun audit found zero Julia and zero DESC-named processes, `git diff
--check` exit `0`, and 4311 dirty rows. R1 remains a failed raw receipt; R2
must use the same single dedicated command and preserve full raw output.

