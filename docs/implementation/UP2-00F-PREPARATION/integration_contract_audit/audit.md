# UP2-00F integration contract audit

## Scope and verdict

This is a read-only integration audit captured at HEAD `4b69f55f7f80240147a65a22809dc1207824dde2`. The frozen input inventory is in `input_hashes.json`; it covers the UP2 core contract/validator, all separate N03/N04/N07-N08/N09/N10 source-test-runner sets, actual-A package/integration sources, current work-order documents, and AD-21 through AD-24 evidence. `dirty_snapshot.txt` records 277 pre-existing status entries at capture. No source, test, core document, run, or queue file was modified, and no Julia/DESC process was started.

Verdict: `pass_limited` for integration-contract feasibility and ownership planning. This audit does not accept UP2-00, B00, B04, provider execution, mesh, engineering, physical evidence, or R01-R10 credit. The machine-readable 50-row matrix is `coverage_matrix.json`; the same rows are rendered in `coverage_matrix.md`.

## Current source and inclusion boundary

`src/FusionConceptAI.jl:44-46,122` includes the V4 contracts and the V5 integration module, exports `load_genome_v5_components!` and `integrate_genome_v5`, but does not include UP2 projection modules. `src/GenomeV5/Integration/GenomeV5Integration.jl:15-26` loads G1/G2/G3 V5 files by `Base.include` in dependency order. A future unified UP2 entrypoint therefore needs an additive, explicit include/loader; it cannot assume that separate UP2 files are available from the normal module path.

`src/Contracts/CandidateStatePackageV5.jl:159-226` is the package boundary: it carries candidate ref, three public component refs, G2 binding, G3 package/binding/child refs, four version axes, migration receipt, component identity, status/error/gap fields, candidate hash and claim ceiling. `src/GenomeV5/Integration/GenomeV5Integration.jl:146-185` performs exact package identity/ref/axis/binding/child/feedback checks. A unified validator must enter through this actual-A package boundary and rebuild identity; low-level UP2 constructors are not equivalent input evidence.

`src/GenomeV5/UP2/TypedPrecompilerValidatorV1.jl:105-154` derives N01/N02 values from an actual package, but still emits synthetic N05 `pending-port:left/right` values and `port_source=:unverified`, while other rows remain typed pending values. `TypedPrecompilerContractV1.jl:80-115` permits a low-level `UP2FluxPairV1` with string ports and a synthetic default interface ref. This seam is useful for unit tests and explicitly insufficient for a B04-admissible package. The separate N03-N10 modules now have stronger source projections, but they are not one admission or one receipt protocol.

## Matrix result

The matrix has exactly 50 rows, five per N01-N10:

- 35 `accepted_limited` local contract rows: N01, N02, N03, N04, N07, N08, N09.
- 10 `missing_authority` rows: N05 and N06. Their registered fields are provisional or lack an authoritative cross-layer accessor.
- 5 `review_pending` rows: N10 at this audit's input-freeze time. A later Sol limited decision based on independent r1 is not retroactively applied to this frozen matrix; its docs integration remains a separate pending action.

The accepted local groups retain their documented boundaries. N01/N02 are actual-A rank/dimension/shape/unit projections. N03 is local G1 temporal/derivative and G3 event enum/nonnegative-time checking; the candidate-bound G1-to-G3 event time-basis policy is absent and remains `terminal_deferred`. N04 checks local closure/ref/balance invariants; shared owner is legal, and the exact G1 occurrence-to-G3 account/entry/energy boundary join is absent. N07/N08 cover only the current admitted G2 topology/schema envelope, including the documented global-envelope/regions[1], required-face, and `:none_declared` limitations; they do not prove general geometry or mesh execution. N09 covers five actual-A provider declarations and eleven mutations that actually change the declaration; it does not resolve providers. The five N10 rows are `review_pending` at this audit's input freeze; independent r1 later passed limited review and Sol accepted that limited scope, but the matrix is an immutable snapshot and the separate docs integration remains pending. Legacy V4 provenance and stale/foreign receipt boundaries remain deferred.

Every row has an exact source locator/type and frozen source-file SHA in the matrix. The `source_ref` column names the actual-A package/component binding or the explicitly provisional UP2 seam. Candidate component value hashes are not invented: a formal receipt must carry the runtime package-bound refs/hashes, axes, and candidate identity produced by the same admission.

## What is missing for one unified formal gate

The separate slices currently lack a single candidate-bound factory that consumes the actual A package once, invokes N01-N10 declarations through one schema registry, checks all public refs/schema/canonical/profile hashes and four axes, and binds every mutation to the same candidate identity. They also lack one source-derived classifier that enforces the following distinctions:

- present contradictory structure or identity: `fail_closed` with a precise path/detail;
- missing authority or unavailable policy: `terminal_deferred` with an explicit gap;
- provider capability gap: `terminal_deferred`, with no provider resolution;
- compile-before-provider structural gate: zero compile/provider/solver calls, measured by an invocation seam rather than asserted metadata.

The formal gate must then freeze 50 fresh candidate-bound mutation envelopes (five each N01-N10), each with before/after full refs and hashes, four axes, candidate binding, source locator/type, preregistered error class, actual classifier output, and zero-counter evidence where applicable. A checker must independently validate receipts, and two separate processes must replay the same frozen inputs and compare outputs. Existing local pass counts and runner exit codes do not substitute for these artifacts.

N05 is blocked until AD-24 E1 supplies an additive typed endpoint/law/unit/sign declaration from actual candidate refs. Pending ports, normals, or equation input units cannot be treated as flux authority. N06 is blocked until E2 supplies typed source-field-return-heat/ledger/owner-scope mapping; local G3 network/closure fields do not establish that cross-layer physical mapping. E0 must first provide a new candidate-owned bound-input identity that includes the binding hash while preserving the original package hash. N10 must additionally resolve the fresh-versus-legacy receipt and stale/foreign receipt boundary. N07/N08 geometry rows remain limited to their admitted topology, and N09 remains provider-gap classification only.

## Proposed bounded ownership and gates

1. **E0 candidate-bound identity (new files only).** The assigned Luna worker owns `src/GenomeV5/UP2/UP2CandidatePhysicalBindingV1.jl`, its fixture/test/runner, and `docs/implementation/UP2-00E0-BOUND-INPUT/`. Input is an actual accepted A package plus AD-24. Output is a new bound-input identity, exact component refs/hashes/axes/candidate binding, original package hash unchanged, and explicit authority gaps. Exit gate: fixture-driven identity changes under edit, foreign ref/axis/binding rejected, zero execution calls; independent review required.
2. **E1 and E2 authority slices (separate new file sets).** E1 owns `E1N05InterfaceLawProjectionV1.jl` and isolated tests/archive; E2 owns `E2N06SourceFieldLedgerProjectionV1.jl` and isolated tests/archive. Both depend on E0 and actual-A fields. E1 must classify missing authority as deferred and present conflict as fail-closed. E2 must preserve local G3 checks while requiring an explicit cross-layer mapping. Neither may claim physical semantics or B04.
3. **Unified UP2 contract validator (new files only).** After N01-N10 schemas and E0-E2 stabilize, a separate integrator owns a new `UnifiedPrecompilerValidatorV2.jl`, one fixture/runner, formal checker, receipts, and archive. It may add an explicit UP2 loader/entrypoint but must not silently alter V4 or the default operator registry. Exit gate: all 50 fresh candidate-bound rows, source-derived classifications, exact identity/axes, zero-counter measurement, immutable receipt hashes, checker pass, and two-process replay with no drift.
4. **UP1-04B formal freeze and replay.** UP1-04B remains the owner of freezing the formal B00 F0-F5 and B04 N01-N10 suite before first execution, with all 50 receipts, checker, and two-process replay. It depends on the unified UP2 schema/validator and its independent review. The complete UP1-04 gate then depends on UP1-04B completion and independent review, preserving the acyclic order. No local UP2 accepted_limited slice unlocks or replaces this gate.

The proposed order is E0 -> (E1,E2 in separate non-heavy lanes) -> unified validator/schema freeze and independent review -> UP1-04B formal freeze/replay -> complete UP1-04 gate and independent review -> UP2-01. N01-N04, N07-N09 local archives remain immutable evidence inputs, not rewritten into formal B04 receipts. No task-manifest or DAG change is proposed by this audit.

## Evidence and claim ceiling

Inspected runtime evidence includes the recorded author/independent archives: UP2 r18 actual-A N01/N02, N03 r3, N04 r3, N07/N08 r3, N09 r2, and N10 r1. These are reported with their archived paths and hashes in `input_hashes.json`; no new runtime was executed. The result is a contract coverage and integration readiness assessment. It provides no B00/B04, provider resolution, mesh, engineering, physical, or R01-R10 credit, and does not alter the parent objective.
