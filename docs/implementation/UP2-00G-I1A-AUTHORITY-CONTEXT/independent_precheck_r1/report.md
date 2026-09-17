# G-I1A independent static precheck R1

Verdict: **changes_requested**.

This is a different-Luna, read-only static precheck. Julia/DESC were not run and no implementation, test, or core document was changed.

## Frozen inputs

- `src/GenomeV5/UP2/GI1AuthorityContextV1.jl` SHA-256 `dc976dedd0f01aab13b7b17bd6a9e17aeacd5d272d2957659b97331b99c2903b`
- `test/GenomeV5/UP2/gi1_authority_context_fixtures.json` SHA-256 `7c0793f42e01feac522c428cad7b7522a9517dc19922e67215dac4ea0dc3bf2c`
- `test/GenomeV5/UP2/gi1_authority_context_tests.jl` SHA-256 `4be356e86a72cbf5f2fd31b6f1da57b1e11c052f31beab788354cd5c94d6d1a8`
- `test/GenomeV5/UP2/run_gi1_authority_context.jl` SHA-256 `20d01f6ee0ceb7a7bf11c160a4257224ceee61c50ff229dca62303efa0658ff6`

## Blocking findings

- **GI1A-01 (context_metadata_explicit)** GI1AuthorityContextV1/_gi1_context_body has no explicit top-level context_version, schema_hash, canonicalization_hash, or compatibility_profile_hash. Nested slots carry schema_hash/canonicalization_hash/profile_hash, but profile_hash is not an explicit GI1 compatibility_profile_hash and does not satisfy the context-level AD-26 field requirement.
  - source evidence line 17: `compile_calls,provider_calls,solver_calls,context_hash`
  - source evidence line 150: `struct GI1AuthorityContextV1`
  - source evidence line 173: `    context_hash::Digest256`
  - source evidence line 189: `                                   solver_calls::Integer, context_hash::Digest256)`
  - source evidence line 211: `            Int(provider_calls), Int(solver_calls), context_hash)`
  - source evidence line 215: `function _gi1_context_body(x::GI1AuthorityContextV1)`
- **GI1A-02 (admission_enum_ad26)** Constructor and factory use :contract_ready/:terminal_deferred/:fail_closed; AD-26 requires declared_consistent/fail_closed/terminal_deferred/program_exception.
  - source evidence line 196: `        contract_admission in (:contract_ready, :terminal_deferred, :fail_closed) ||`
  - source evidence line 255: `    admission = try`
  - source evidence line 295: `    admission = e1 isa GI1N05PresentAuthoritySlotV1 && isempty(e2.gaps) ? :contract_ready : :terminal_deferred`
  - source evidence line 301: `        contract_admission=admission, physical_resolution=terminal_deferred,`
- **GI1A-03 (validator_trusted_actual_binding)** gi1_validate_authority_context accepts only a context and checks self-consistency; it has no trusted package/E0/E1/E2 inputs or source validation, so a forged internally coherent context can pass.
  - source evidence line 229: `function _gi1_validate_context_identity(x::GI1AuthorityContextV1)`
  - source evidence line 310: `    _gi1_validate_context_identity(context)`
  - source evidence line 314: `function gi1_validate_authority_context(context::GI1AuthorityContextV1)`
  - source evidence line 316: `        _gi1_validate_context_identity(context)`
  - source evidence line 320: `        (status=:valid, errors=(), contract_admission=context.contract_admission,`
- **GI1A-04 (positional_e1_e2_slot_binding)** The constructor calls the same checker for e1 and e2, while the absent branch only accepts slot in (:E1,:E2); swapped absent slots are not rejected.
  - source evidence line 144: `        slot.slot in (:E1, :E2) || throw(ArgumentError("GI1 absent slot name invalid"))`
  - source evidence line 202: `        _gi1_check_slot(e1, (candidate_ref=candidate_ref, candidate_hash=package_hash), e0_binding)`
  - source evidence line 203: `        _gi1_check_slot(e2, (candidate_ref=candidate_ref, candidate_hash=package_hash), e0_binding)`
- **GI1A-05 (typed_program_exception_factory)** _gi1_e2_absent converts unknown errors to ErrorException and the factory propagates them; no typed program_exception context/admission is constructed. Validator classification alone cannot repair factory taxonomy.
  - source evidence line 257: `    catch err`
  - source evidence line 258: `        throw(ErrorException("GI1 N06 authority program_exception: " * sprint(showerror, err)))`
  - source evidence line 271: `function gi1_authority_context_from_a(package::CandidateStatePackageV5,`
  - source evidence line 276: `    catch err`
  - source evidence line 277: `        throw(ErrorException("GI1 E0 program_exception: " * sprint(showerror, err)))`
  - source evidence line 323: `    catch err`
- **GI1A-06 (test_matrix_sufficient)** Tests contain 3 testsets and fixture cases ['actual_a_e1_present_e2_absent', 'actual_a_e1_absent_e2_absent', 'foreign_e0_candidate', 'stale_e1_package_hash', 'tampered_context_identity']; they omit systematic candidate/ref/hash/axis/slot/schema/canonical/profile/content mutations and trusted validator binding.
  - source evidence line 97: `@testset "G-I1A typed authority context" begin`
  - source evidence line 123: `    @test G.gi1_validate_authority_context(context).status == :valid`
  - source evidence line 124: `    @test G.gi1_validate_authority_context(context).contract_admission == :terminal_deferred`
  - source evidence line 128: `@testset "G-I1A E1 absent and E2 absent slots" begin`
  - source evidence line 141: `    @test G.gi1_validate_authority_context(context).status == :valid`
  - source evidence line 144: `@testset "G-I1A source-derived tamper controls" begin`
- **GI1A-07 (e2_present_slot_type_or_explicit_scope)** Only GI1N05PresentAuthoritySlotV1 (hard-coded E1) and generic absent slots exist; no typed E2-present slot. Scope must explicitly defer E2-present to a later work order or add the typed slot with independent metadata.
  - source evidence line 41: `struct GI1AbsentAuthoritySlotV1 <: GI1AuthoritySlotV1`
  - source evidence line 53: `struct GI1N05PresentAuthoritySlotV1 <: GI1AuthoritySlotV1`
  - source evidence line 65: `function _gi1_absent_body(x::GI1AbsentAuthoritySlotV1)`
  - source evidence line 78: `_gi1_slot_hash(x::GI1AbsentAuthoritySlotV1) = canonical_hash(_gi1_absent_body(x))`
  - source evidence line 80: `semantic_view(x::GI1AbsentAuthoritySlotV1) = merge(_gi1_absent_body(x), (content_hash=x.content_hash,))`
  - source evidence line 104: `    GI1AbsentAuthoritySlotV1(slot, reason, gs, projection_hash, schema_hash,`

## Boundary

Factory source binding to actual A/E0/E1/E2 paths is present, but the public validator is self-consistency-only. The local typed context is therefore not ready for focused runtime until the blockers are repaired and independently rechecked. No B04, provider, mesh, engineering, physical, UP2-total, or R01-R10 credit is granted.

QA receipts are in `command_receipts.json`; `report.json` and `evidence_manifest.json` carry the re-computable hashes and exits.
