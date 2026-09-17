# Engineering/control/fault closure

`EngineeringControlFaultContracts.jl` is a bounded forward module over the
newest three typed Genome contracts: `MechanismGenomeV4`,
`FieldGeometryGenomeV4`, and `RealizationControlGenomeV4`.  The input record
stores all three concrete bindings plus the `GenomeContractRegistryV4`; the
validator rejects a binding mismatch as unresolved rather than routing to a
legacy Genome, authority, family, or candidate preference.

The contract surface is deliberately small:

- `EngineeringLoadV4` records applied/allowable load, units, and an evidence
  reference.  `engineering_margin` computes `allowable / applied - 1`.
- `ObservationDependencyV4` and `ActuationDependencyV4` carry typed G3 channel
  or operator-site references plus content hashes. An unbound required
  capability emits an explicit recoverable `:unsupported` gap.
- `FaultScenarioV4` requires a trigger, safe state, recovery action, and (when
  closed) a fault evidence reference.
- `EvidenceObligationV4` carries an explicit domain (`:physical`,
  `:engineering`, `:control`, `:manufacturing`, or `:fault`) and one of
  `:pass`, `:fail`, `:unknown`, `:unsupported`, or `:deferred`. A `:pass`
  requires a `(Digest256, Digest256)` content/artifact target.

`validate_engineering_control_fault` returns a hash-checked
`EngineeringControlFaultDecisionV4` with independent engineering, control,
and fault statuses, unresolved reasons, unsupported capability reasons, and a
physical-evidence flag.  Engineering/control/manufacturing checks never
substitute for physical evidence.  Unknown obligations therefore keep the
overall decision `:deferred`; overload is `:fail`; unavailable dependencies
remain `:unsupported`.

This is an extract/wrap/validator-only closure layer.  It does not execute a
plant, issue actuation, manufacture a component, or promote a candidate.
Tests include the committed declared fixture and are Base-includable without
changing the RuntimeV4 module aggregator.
