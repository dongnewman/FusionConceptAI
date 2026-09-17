# H0-A repair R13: restored typed-absence assertion and corrected bind diagnostic

Status: diagnostic_completed_changes_requested; accepted=false; review_pending=true.

R13 restores the unconditional regression assertion:

    @test result.declaration isa G.N06H0ATypedAbsentV1

The dependent gap-code, binding-hash, and declaration-validation checks remain guarded by the same typed-absent predicate, so a nothing declaration cannot cause secondary field-access errors while the primary type contract remains enforced. The status and compile/provider/solver counter assertions remain unconditional.

The corrected minimal diagnostic loaded G.load_genome_v5_up2_components!(), included N06DimensionedLedgerLawV1.jl, reused the actual-A fixture and constructor path, and invoked only n06_h0a_bind_actual_a. It ran once with PID 28760, exit 0, from 2026-09-14T22:03:02.2801838Z through 2026-09-14T22:04:06.6561040Z. It reported:

- status=program_exception
- errors contains N06 H0-A program exception [source_projection_exception]: bind_actual_a: MethodError: no method matching first(generator, ::Nothing)
- gaps=()
- declaration_type=Nothing
- declaration_is_nothing=true
- compile_calls=0, provider_calls=0, solver_calls=0

The wrapped error is a real source-projection failure: first(generator, ::Nothing) in the bind path. It is not an authority gap, and there is no evidence permitting conversion to terminal_deferred. No production source repair is made in R13; another Luna must review this exact reason before a narrow source repair is selected. The focused/full runner was not run.

## Hash audit

| artifact | before bytes | before SHA-256 | after bytes | after SHA-256 |
|---|---:|---|---:|---|
| src/GenomeV5/UP2/N06DimensionedLedgerLawV1.jl | 57046 | f40e626bcdb8c981bb9355dbde49dc7f9302f5db558a0e758fdcc5b98681b251 | 57046 | f40e626bcdb8c981bb9355dbde49dc7f9302f5db558a0e758fdcc5b98681b251 |
| test/GenomeV5/UP2/n06_dimensioned_law_tests.jl | 38512 | 809a745ab0af4add6ba8f33d7f273f4573fe8bbc98ce64e9400d9edf113d667d | 38567 | b262eb32818666abf1a5a070ddd543d47078fadb7763b29e5f1b16659192a144 |

Protected fixture and runner remain unchanged:

- fixture: 1451 bytes, 779e29bac0a71c5072896301e24e74c9686c293609b89e250d0b0aff5bf0cc99
- runner: 299 bytes, da4c41517badd8c99f5f10e55c9219e2450afb223798eb7f7b4db2048ce293dc

The diagnostic raw stdout is 2024 bytes, SHA-256 70488f6bbfe529f5b1573bde273613afb1d37d1dcfe7a7eb02bc3fbca8e434a1; stderr is empty, SHA-256 e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855. Dirty rows were 303 to 303; Julia/DESC process count was 0 to 0. Static JSON/fixture/hash checks pass. Acceptance remains false and no B00/B04, physical, provider, engineering, or R credit is granted.
