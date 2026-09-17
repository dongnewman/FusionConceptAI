# E2-N06 independent static precheck R1

Verdict: `changes_requested`.

This is a read-only static review by a Luna different from the implementation author. Julia and DESC were not run by this review. The frozen author inputs are recorded in `input_hashes.json`; the current four implementation hashes match the author R3 freeze supplied by Sol.

## Blocking findings

1. `src/GenomeV5/UP2/N06SourceFieldLedgerMappingV1.jl:225-263` selects every source object with `first(...)` and emits hard-coded `/0/` paths. The projection fields are five G3 values only (`resource_ports[0]`, `entries[0]`, `links[0]`, `closures[0]`); the G1 occurrence and G2 region/patch are returned from the helper but are not represented as source fields in the projection. A reordered or multi-object actual A package can therefore be mapped to the wrong object while the hash remains internally consistent. `test/GenomeV5/UP2/n06_source_field_ledger_mapping_tests.jl:84-112` repeats first/index selection when constructing joins, so the test does not independently establish exact source authority.

2. `src/GenomeV5/UP2/N06SourceFieldLedgerMappingV1.jl:315-334` uses `eq_candidates[1]`, `occurrence_candidates[1]`, `first` closure/region selection, and `findfirst` boundary selection. `:305-308` builds Dicts keyed by IDs without first rejecting duplicate IDs. This is an ambiguity path: duplicate or multiple matching objects can be silently reduced to one chosen object instead of fail-closed. The local G3 contract makes many IDs unique for normal packages, but N06 does not explicitly enforce the ambiguity boundary and its exact locator claims are therefore incomplete.

3. `:409-450` routes mutation classification from `spec.field_path` suffixes and compares against `first(q.network.entries)` or `first(q.network.resource_ports)`. `N06MutationSpecV1` carries source locator and source type, but `n06_validate_mutation` does not compare those fields to the actual projection field before mutating/classifying. A spec with a valid ID and forged locator/type, or a reordered network, can be classified against a different object. The fixture is read and its expected status/error is asserted at `test/.../n06_source_field_ledger_mapping_tests.jl:152-169`, but that test does not prove source-locator/type binding; the expected error remains an oracle only.

4. The conversion constructor at `:59-69` validates law token, nonzero scale, a small enum, and nonempty provenance. The join checks at `:354-359` compare endpoint units and offset policy, but do not prove that `:same_dimension` has equal dimensions, that the law is source-backed/content-hashed, or that `:power_from_effort_flow` is dimensionally valid. A present malformed conversion can pass the constructor and reach a locally plausible join. Until the dimensioned law authority is typed and exact, this must remain an explicit deferred boundary; it cannot be treated as a source-to-energy proof.

5. `:282-290` correctly preserves three cross-layer gaps, and `n06_mapping_admission` returns `terminal_deferred` at `:500-505`. That is the correct ceiling for missing G1 occurrence to G2 boundary, G1 source/field to G3 return/heat/ledger, and owner-scope authority. The implementation must not promote the authored four-role join or G3 local balance into conservation evidence. Shared owner remains legal under AD-22; owner string equality alone is not duplicate accounting.

## Classification and historical evidence

Current source text includes `semantic_view(::N06InvocationCounterV1)` at `:183-185`, but the author R3 receipt records the earlier missing-method `program_exception`; no fresh run is available in this review, so the static method cannot replace a new execution receipt. R1, R2, and R3 author attempts remain separate historical `exit=1` program exceptions: unsupported first-generator default, invalid owner/conversion sample, and missing counter semantic view. They are not physical failures and do not become pass evidence.

E0 source validation is checked separately at `:274-279`: an E0 `program_exception` is rethrown as an exception and a nonvalid structural result is rejected. This preserves the three-state distinction at the call boundary, but the N06 mapping API does not itself emit a typed program-exception result or an invocation receipt.

## Required repair before focused review

Use explicit candidate-bound locators with cardinality-one checks (or an explicit ambiguity error) for every selected G1/G2/G3 object; bind each mutation to the projection's actual locator and type, not only a fixture path suffix; reject duplicate IDs before Dict construction; add dimension compatibility and content-hashed law/source checks or leave the conversion and cross-layer join terminal_deferred. Keep missing authority as `terminal_deferred`, present typed contradiction as `fail_closed`, and unexpected exceptions as `program_exception`. Then provide a new frozen source/test/fixture/runner manifest and a separate focused receipt.

Claim ceiling: `contract_only` static precheck; no formal B04, provider, mesh, engineering, physical, or R01-R10 credit.
