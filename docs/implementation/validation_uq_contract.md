# Runtime V4 validation/UQ contract

`ValidationUQContracts.jl` is an additive integration hook. Its binding is
derived from a real `CandidateStatePackageV4` and `ExecutablePhysicalSubjectV4`;
there is deliberately no hash-only binding constructor. Provenance and an
evaluated applicability envelope are mandatory.

Calibration records and held-out records are distinct typed records; duplicate
record IDs are rejected. A closure decision requires held-out data,
measurement uncertainty, a candidate-bound prediction artifact, an explicit
comparison protocol/result, all four uncertainty classes (numerical, model,
measurement, transfer), parameter distributions, and in-domain applicability.
Correlations are retained as typed triples. Missing distributions or data are
recoverable `:unknown` gaps. Out-of-domain evidence is `:out_of_domain`.

Manufactured controls and cross-code comparisons are retained for their proper
screen/numerical roles but receive zero physical-validation credit. This module
does not promote candidates, mutate the authority layer, or imply engineering
readiness. The intended integration point is `Base.include(FusionRuntimeV4,
"src/RuntimeV4/ValidationUQContracts.jl")` after the runtime aggregator loads.
