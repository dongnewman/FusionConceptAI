# G-I1B N01–N10 source inventory R1

## Verdict and evidence ceiling

This is a read-only source inventory frozen on 2026-09-14. It writes only this `source_matrix_r1/` directory, runs no Julia/DESC, and does not change source, tests, core documents, or the existing local archives. The complete field-level inventory is `source_matrix.json`; it has 50 rows, five for each N01–N10.

The matrix is dispatch information, not acceptance. It separates source-backed typed values from authored extensions and synthetic placeholders. Existing local slices remain contract-only and retain their prior ceilings. No row is a formal B04 receipt, provider result, mesh result, engineering result, physical result, or R01–R10 credit.

Literal `Digest256` values are not recomputed by this audit. Every row records the exact production expression that must supply the ref/owner and component/content hash. A future implementation must serialize and independently recompute those values from the same candidate; a source expression or a fixture label cannot be used as a hash substitute.

## Source matrix findings

### N01 and N02: actual typed projection, narrow local ceiling

The current UP2 precompiler projection takes N01 values from the actual A package: equation input/output ranks, the state selected by `eq.input_state_refs[1]`, G2 embedding dimension, and G2 field-space shape. The current fixture gives ranks `0`, ambient dimension `3`, and shape `scalar`. N02 takes G1 equation units (all dimensionless in the fixture), the G2 field-space unit string `"1"`, and actual G3 effort-port/entry units `(1,2,-3,-1,0,0,0)`. These are real typed values, with refs/hashes recorded in the matrix.

The old precompiler path still contains provisional synthetic pending values for classes outside its first source projection, and its N01/N02 validator is a local schema/value slice. In particular, equality of G1 dimensionless units with G3 effort/power units is not a physical conversion law. G-I1B may consume these rows only as local contract rows after source-bound projection and exact mutation checks; it must not call them a complete lowering or physics bridge.

Citations: `src/GenomeV5/UP2/TypedPrecompilerValidatorV1.jl:105-154,196-217`; `src/GenomeV5/UP2/TypedPrecompilerContractV1.jl:265-291`; `test/GenomeV5/G1/fixtures.json`; `test/GenomeV5/G2/fixtures.json`; `test/GenomeV5/G3/fixtures.json`.

### N03: five actual time values with a G3 time-basis gap

N03 source-binds equation temporal kind, derivative order, matched operator temporal kinds, and the first G3 controller event trigger/time. Current fixture values are `static_time`, `0`, `(:static_time,)`, `initial`, and `0/1`. The first three have local G1 authority. The G3 event rows remain `terminal_deferred` under `missing_candidate_bound_g3_event_time_basis_policy`; a legal scheduled event is not relabeled invalid merely because the cross-layer policy is absent. Ref/hash source expressions are the actual G1 outer ref/hash or G3 control ref/hash.

Citation: `src/GenomeV5/UP2/N03TimeAuthorityProjectionV1.jl:128-170`; N03 acceptance is limited to actual-A five-field local authority.

### N04: five actual G3 ledger values, two explicit gaps

N04 reads the actual G3 network after package binding checks. The current fields are account owner `source_owner`, first closure IDs `("source_effort",)`, first entry account `source_effort`, first entry component `source`, and second entry coefficient `10/1` for the source entry in the current fixture. Four local mutations have source-derived closure/capacity classifications. The owner mutation remains `terminal_deferred`: shared owners are legal and owner-string equality is not a double-count rule. The independent G1 occurrence → G3 account/energy-boundary join is also always a gap, even if strings coincide.

Citation: `src/GenomeV5/UP2/N04LedgerAuthorityProjectionV1.jl:87-138`; N04 acceptance and G3 fixture construction.

### N05: authored declaration over an A absence

Actual A supplies a G1 occurrence and G2 interface context, but no authoritative flux/traction/current endpoint, sign, law, or dimensioned flux-unit source. The E1 authored branch adds a typed law expression/ref/hash, left/right endpoint refs/signs, authored UnitSignature provenance, G1 occurrence locators, and the G2 interface child ref. The matrix records those authored values and their exact owner/hash expressions. The present authored branch can reach only local `contract_ready`/`fail_closed` classification; the absent branch must emit five distinct `terminal_deferred` authority gaps without fabricating a mutated value.

The local E1 result is `accepted_limited` for actual-A/E0 source-bound serialization and seven forged/omitted file-read controls. The full gate remains `changes_requested` because an independent checker not sharing `_n05e_row` and formal two-process replay are not complete. G2 normal, `pending-port`, and G1 `eq.input_units` remain non-authoritative for flux.

Citations: `src/GenomeV5/UP2/N05FluxAuthorityProjectionV1.jl:1-27,54-215,292-296,428-429`; `test/GenomeV5/UP2/n05_flux_authority_tests.jl:60-128`; E1 acceptance.

Repair R2 correction: source row `N05-05` uses the authored endpoint-unit provenance hash `declaration.right_endpoint.unit.source.source_hash`, which production derives as `canonical_hash((endpoint_ref=endpoint_ref, unit=unit))`. It does not use `declaration.law.law_hash`; the unit provenance is an independent content hash.

### N06: actual G3 selected fields, no dimensioned cross-layer law

N06 selects the actual G1 governing occurrence by the four-field key `(ledger_id,equation_id,port_side,port_index)`, the actual G2 interface-left region and face patch, then the unique G3 effort port, its entry/closure, the unique flow link, and five G3 fields. Current source values are the selected effort port ID/kind, its account ID, selected flow link port ID, effort closure expected balance `1/1`, and `:effort`. The matrix uses dynamic selected indices because the implementation derives them by unique typed identity rather than a fixed fixture index.

The actual A package has no authoritative dimensioned conversion from the dimensionless G1 occurrence to G3 effort/flow/power/return/heat roles. `eq.input_units`, a coincident `energy` string, G2 interface normal, or local G3 balance cannot supply that law. N06 therefore retains `terminal_deferred` for missing source→field→return/heat/ledger/owner mapping; present typed contradictions can be `fail_closed`. The local N06 slice is accepted only for five source-derived mutations and the unit contradiction boundary.

Citations: `src/GenomeV5/UP2/N06SourceFieldLedgerMappingV1.jl:315-446`; N06 acceptance; G1/G3 fixtures.

### N07/N08: actual G2 structural values only

The actual-A factory verifies G2 candidate binding, component hash and package hash before projecting. Current G2 fixture values are region lower `(0,0,0)`, upper `(1,1,1)`, six required faces, first patch lower `(0,0)` under face-aware tangent mapping, boundary condition `mixed`, chart axes `(:x,:y,:z)`, map `identity`, mesh cells `(2,2,2)`, basis `linear`, and the actual interface ref tuple. Mutations classify against the current G2 admitted structural rules as `invalid_boundary/fail_closed` with zero downstream calls.

The supplemental `n07_n08_projection_from_g2(g2,candidate_ref,package_hash)` constructor is synthetic and excluded from candidate-bound acceptance. Only `n07_n08_projection_from_a(package)` is source-backed. The current `regions-1` interface condition is a limited G2 admission rule, not a universal topology theorem; no geometry proof, mesh execution, provider, or physical credit follows.

Citation: `src/GenomeV5/UP2/N07N08GeometryProjectionV1.jl:98-148,177-224`; N07/N08 acceptance.

### N09: five actual provider-match declarations, no provider resolution

N09 reads five actual fields: G1 operator `unique_match`, G2 grammar `unique_match`, G2 exterior `unique_match`, G3 realization `no_match`, and G3 control `no_match`. Each row carries the actual layer ref and component hash expression and a stable source locator/type. Mutations are provider capability gap values (`no_match`, `out_of_domain`, `invalid_signature`) and remain `terminal_deferred`; compile/provider/solver calls stay zero. The no-match values are not provider execution or resolution evidence.

Citation: `src/GenomeV5/UP2/N09ProviderGapProjectionV1.jl:120-194`; N09 acceptance.

### N10: fresh identity/receipt checks, legacy provenance absent

N10 source-binds G1 schema hash, G2 canonicalization hash, the actual typed G3 child `package.g3.binding.contract_binding.contract_ref` with exact five-field comparison, package candidate hash recomputation, and fresh `migration_receipt.candidate_identity_after` recomputation. The fixture records expected package hash `67bf32d7d55b06eac1f495a50fcb1620babd48d9ebbce14867f854f32b3064a5` and fresh identity-after `31f3390f62193e274b781c5e61d15ffd7c6097e5fab160000f36af47106542b0`; production source derives and verifies these rather than trusting labels.

Foreign/stale present ref/hash/identity/receipt values are `invalid_type + fail_closed`. The fresh receipt is pending/empty, so N10-05 is a fresh mismatch check only. Actual V4 legacy receipt references, mappings, identity rebuild and provenance are absent and remain an independent `terminal_deferred` gap. Low-level synthetic constructors are not candidate authority.

Citation: `src/GenomeV5/UP2/N10IdentityReceiptProjectionV1.jl:238-310`; N10 acceptance.

## Synthetic and authority classification

The following are explicitly excluded from a source-backed G-I1B row: TypedPrecompiler pending values (`pending`, `pending-port`, and the old `UP2FluxPairV1` convenience constructor); the isolated G2 N07/N08 constructor that accepts arbitrary candidate/hash arguments; low-level UP2/E0 constructors without an actual A witness; any fixture `expected_error`, expected hash, or row ID used as a production decision; G1/G2 textual coincidence used as a cross-layer law; and the G3 feedback/source strings whose refs have `external_ref_required` or null schema/canonical/profile fields.

`terminal_deferred` is reserved for absent authority/provenance/mapping. A typed value that is present but contradicts a source-bound ref, hash, axis, type, closure, boundary, or declared law is `fail_closed`. An unexpected implementation/checker exception remains `program_exception`. These three states must not be collapsed by G-I1B.

## Minimal G-I1B implementation boundary

Inputs must be frozen from an actual UP1-04A `CandidateStatePackageV5`, a source-validated E0 binding, the current accepted-limited E1/E2 source contracts, all three actual outer five-field refs, component hashes, four version axes, package hash, and explicit E1/E2 present or typed-absent markers. The factory must reject foreign/stale packages, E0 bindings, refs, component hashes, axes, child refs, and extension swaps before creating rows.

Outputs are a new candidate-bound G-I1B context and 50 immutable local rows. Every row must carry exact field path, source type, source ref/owner, component/content hash, original and attempted typed values, input/mutated hashes, derived error code/path/resolution, and zero compile/provider/solver counters. The context hash must include both extension content hashes or typed absent marker content hashes plus independent schema/canonical/profile hashes; original A package and E0 hashes remain unchanged.

The G-I1B exit gate is source-backed factory construction, 50 unique rows, actual typed mutation for every non-deferred row, independent hash/source recheck, and separate observations of `fail_closed`, `terminal_deferred`, and `program_exception`. A missing N05/N06 authority may remain deferred; it cannot be filled with a synthetic declaration. This is still contract admission only.

G-I2/UP1-04B owns the next gate: freeze a new candidate-bound B00 F0–F5 and all 50 fresh formal B04 rows, independently rebuild rows and hashes in a checker that does not share the exporter row helper, then replay the same frozen inputs in two independent processes with distinct receipts and matching canonical identities. Local N01–N10 rows, single-process focused runs, documentation, runner exit, provider gaps, and physical/deferred statuses cannot substitute for that gate. UP2 total, B00/B04, provider, mesh, engineering, physical and R01–R10 remain open.

## Frozen input and QA

`input_hashes.json` records every source, fixture, contract and accepted-limited archive consulted. `protected_dirty_status.txt` records the pre-audit dirty worktree. No Julia or DESC process was running and no Julia/DESC command was started. `qa.json` records JSON/control scans, plan validation, diff check and the final process sweep. This inventory remains `review_pending`; it is not an implementation acceptance.
