# H0-A R12 independent static precheck

- **Verdict:** `changes_requested`
- **Acceptance:** `accepted=false`; `review_pending=true`
- **Scope:** read-only review of the R12 source/test/fixture/runner identities, the preserved R12 diagnostic receipt, and focused-R5 evidence. No Julia, DESC, compiler, provider, mesh, solver, or physical execution was performed by this review.

## Frozen workspace and identity

The review is at HEAD `4b69f55f7f80240147a65a22809dc1207824dde2`. The current
porcelain snapshot has 303 rows and SHA-256
`759bd0d086c01bcd60968df018fc053d4af2999e9f1ef81f4e0e40db1187f46b` when
encoded as UTF-8 with LF line endings. No `julia`, `julia-debug`, or `desc`
process was present. The snapshot remains a workspace guard; unrelated dirty
work is outside this review's ownership.

The live target identities match the R12 report for the source, fixture, and
runner. The test has the reported R12 after identity. The R12 source is byte
identical to its R11 after identity, so R12 did not modify production source.

| path | bytes | live SHA-256 | R12 interpretation |
|---|---:|---|---|
| `src/GenomeV5/UP2/N06DimensionedLedgerLawV1.jl` | 57046 | `f40e626bcdb8c981bb9355dbde49dc7f9302f5db558a0e758fdcc5b98681b251` | unchanged from R11 after; R12 source unchanged |
| `test/GenomeV5/UP2/n06_dimensioned_law_tests.jl` | 38512 | `809a745ab0af4add6ba8f33d7f273f4573fe8bbc98ce64e9400d9edf113d667d` | R12 test after |
| `test/GenomeV5/UP2/n06_dimensioned_law_fixtures.json` | 1451 | `779e29bac0a71c5072896301e24e74c9686c293609b89e250d0b0aff5bf0cc99` | protected, unchanged |
| `test/GenomeV5/UP2/run_n06_dimensioned_law.jl` | 299 | `da4c41517badd8c99f5f10e55c9219e2450afb223798eb7f7b4db2048ce293dc` | protected, unchanged |

## R12 test guard review

The primary status assertion remains unconditional at test line 201:

```julia
@test result.status == :terminal_deferred
```

The counter assertion also remains unconditional, so R12 does not hide a
`program_exception` status or nonzero compile/provider/solver calls.

However, the R11 focused receipt recorded a separate required assertion that
`result.declaration isa G.N06H0ATypedAbsentV1`. R12 changed that assertion into
an `if result.declaration isa G.N06H0ATypedAbsentV1` guard and placed the
gap-code, binding-hash, and `n06_h0a_validate` checks inside it. There is no
remaining unconditional type assertion or failing `else` branch. Therefore a
result with `status == :terminal_deferred` and `declaration == nothing` (or an
incorrect declaration type) can pass this testset's status and counter checks.
That is a coverage weakening, not merely a cascade guard.

The required narrow repair is to retain the type assertion before the guard:

```julia
@test result.declaration isa G.N06H0ATypedAbsentV1
if result.declaration isa G.N06H0ATypedAbsentV1
    @test result.declaration.gap_code in (:external_ref_required, :dimensioned_law_missing)
    @test result.declaration.binding.package_hash == package.candidate_hash
    @test result.declaration.binding.e0_bound_input_hash == e0.bound_input_hash
    @test G.n06_h0a_validate(result.declaration).status == :terminal_deferred
end
```

This preserves the primary status and typed-absence contract while preventing
the dependent field accesses from producing four secondary errors. It does
not change production code, classification, or the protected fixture/runner.

## Diagnostic harness finding

The preserved R12 diagnostic receipt is internally consistent: one run, PID
23916, exit `1`, dirty rows `303 -> 303`, no Julia/DESC process left behind,
stdout 272 bytes (`58ec17309e64723b09d28749543d3a78c526c853b2677cf88aa207c199f03d4e`),
and stderr 2455 bytes (`d34d59ba7298d335f3141247a2038ce6c9ac461dfa79dcdc88097b7376d8240e`).
The error is `UndefVarError: MechanismGenomeV5 not defined` during
`Serialization.deserialize`, before `_diag_actual_package` calls
`n06_h0a_bind_actual_a`.

This is a diagnostic harness failure. It does not establish an H0-A authority
gap, a production `program_exception`, or a `terminal_deferred` result. The
cause is confirmed by comparing the diagnostic with the protected runner: the
diagnostic starts with `using FusionConceptAI` but omits the runner's
`G.load_genome_v5_up2_components!()` call before deserializing child fixtures.
It also omits the runner's explicit `Base.include` of
`N06DimensionedLedgerLawV1.jl`; that include is required before calling the
H0-A functions because the UP2 loader registers the source-field mapping, not
this standalone dimensioned-law implementation.

The corrected one-shot diagnostic setup, extracted from the runner, is:

```julia
using Serialization
using FusionConceptAI
const G = FusionConceptAI
G.load_genome_v5_up2_components!()
const _H0A_SOURCE = normpath(joinpath(@__DIR__, "..", "..", "..", "..",
    "src", "GenomeV5", "UP2", "N06DimensionedLedgerLawV1.jl"))
Base.include(G, _H0A_SOURCE)
# define _diag_child_fixture/_diag_actual_g1/_diag_actual_g2/_diag_actual_g3
# and _diag_actual_package exactly as in diagnostic_r12.jl
package = _diag_actual_package()
e0 = G.up2_candidate_physical_binding_from_a(package)
result = G.n06_h0a_bind_actual_a(package, e0)
println("status=", result.status)
println("errors=", repr(result.errors))
println("gaps=", repr(result.gaps))
println("declaration_type=", typeof(result.declaration))
println("declaration_is_nothing=", result.declaration === nothing)
println("compile_calls=", result.compile_calls)
println("provider_calls=", result.provider_calls)
println("solver_calls=", result.solver_calls)
```

The next diagnostic must print at least `status`, `errors`, `gaps`, and the
declaration type before any typed-absence field access. If the declaration is
typed absent, it may then print `gap_code`, `binding.package_hash`,
`binding.e0_bound_input_hash`, and the declaration validation status. A
launcher exit code alone is insufficient to classify the H0-A result.

## Evidence ceiling and gate

R12 is not accepted. The focused-R5 exit `1` remains a real prior software
failure: it observed `program_exception` with `declaration=nothing` and must
not be rewritten as a physical or authority result. This review grants no
H0-A acceptance, B00/B04 credit, provider/mesh/engineering/physical credit, or
R01-R10 credit.

The next gate is sequential: first restore the unconditional typed-absence
assertion in the test, then obtain a different static precheck, then run one
corrected diagnostic with the loader and standalone H0-A source include. A
focused suite rerun remains a separate later authorization and must retain its
full receipt.
