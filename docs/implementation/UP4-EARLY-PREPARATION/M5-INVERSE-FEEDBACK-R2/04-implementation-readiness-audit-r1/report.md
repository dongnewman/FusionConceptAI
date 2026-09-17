# M5 inverse-feedback R2 implementation-readiness audit R1

## Decision

`implementation_not_ready`; `status=review_pending`; `runtime_execution=not_executed`;
`claim_ceiling=manufactured_inverse_feedback/screen_only`; `formal_credit=none`.

This is a read-only readiness audit. It does not implement the R2 slice, accept the
03 contract, replay current bytes, or close UP4-01/02/03/04, B07A/B, B08, provider,
engineering, physical, candidate, or R01--R10 gates. No Julia, DESC, provider,
hardware, solver, mesh, network, or external write was performed.

The current 03 package is not approvable as observed: it is still marked
`review_pending`/`not_implemented`, contains only six files, references files that
are absent (`checker_contract.json`, `manifest.json`, `hash_manifest.json`,
`input_schema.json`, `output_schema.json`, `failure_record_schema.json`,
`failure_taxonomy.json`, and `raw/`), and its resolver registry contains
`PENDING_*_HASH` placeholders. Therefore the file ownership below is conditional:
it is the minimum ownership after a corrected 03 contract is explicitly approved,
not authorization to create the implementation now.

## Frozen checkout and audit boundary

| item | observed value |
|---|---|
| repository | `D:/006-Programing/LMC/FusionConceptAI` |
| branch / HEAD | `main` / `b2c04d8339774635aaecd73651efcdb101e01b5d` |
| review snapshot UTC | `2026-09-17T03:25:24.4512110Z` |
| worktree | dirty; 384 porcelain lines at snapshot; pre-existing changes protected |
| allowed write path | this `04-implementation-readiness-audit-r1/**` directory only |
| runtime | not invoked |

The exact bytes and hashes are in [manifest.json](manifest.json). The current M5
and M5-A source hashes differ from historical R1 accepted receipts; the historical
result is consequently historical-only and cannot authorize current execution.
After the audit snapshot, `03-scope-contract-repair-r2/canonical_bundle_schema.json`
was observed with a different byte count/hash (`5249` /
`248514651a2f4157f086c60ec480aab539f4ac027edcba17424ca4171ab3f0f3`) than the
frozen snapshot (`5280` / `351d954d...d313`). This post-freeze drift is recorded
explicitly in the manifest and makes the 03 package even less suitable as an
implementation input until it is re-frozen and reviewed.

## Current implementation inventory

| area | present now | readiness consequence |
|---|---|---|
| M5 inverse source | `src/RuntimeV4/M4Isolated/ManufacturedInverseFeedbackV1.jl` (`V1`) exposes `forward`, `build_inverse`, `validate_inverse`, payload and hash functions; it stores M4-D/M5-A snapshots, owner/provenance ledgers, and a screen-only ceiling (`:manufactured_inverse_feedback`, `:screen_only`) | useful as a read-only historical/manufactured dependency; it has no candidate/G1/G2/G3/mission/scenario binding, request/result receipt, CAS state, operation history, or schema resolver |
| M5-A and upstream | `ManufacturedAutoCompositionV1.jl` plus M4-A..M4-D manufactured chain are present and source/test/oracle hashes are embedded or checked | only exact manufactured snapshots; no physical subject or external authority |
| M5 test | `manufactured_inverse_feedback_v1_tests.jl` constructs upstream values in `upstream_fixture()`, checks exact inverse/feedback values and typed corruption controls | tests V1 structs directly; no R2 request/result instance, JSON schema validation, resolver, receipt, CAS/history, or two-attempt replay receipt |
| M5 oracle | `inverse_feedback_oracle_v1.py` is an independent Fraction oracle and canonical JSON payload producer | good algebraic oracle boundary, but it has no candidate/source receipt and its `json.dumps(sort_keys=True, separators=...)` path is not by itself proof of the 03 JCS/UTF-8/LF profile; no CAS/history or local resolver |
| V2 implementation | `ManufacturedEngineeringFeedbackSliceV2.jl`, its V2 test, and V2 oracle do not exist | implementation lane has not started |
| R2 schemas | 02 repair schemas exist and are hashed; 03 is intended to supersede them with URN resolver and cross-object checker | 03 is incomplete; 02 external `$ref`/cross-field concerns remain non-authoritative until 03 is complete and independently reviewed |
| R2 fixtures | no M5 R2 request/result JSON fixture or negative-fixture bundle exists; only the Julia inline fixture and broad `inverse_problem_input_template.json` are present | schema/checker and receipt tests cannot be run from a frozen fixture set |

Important source boundary: the current V1 source's retained identity fields are
M4-D/M5-A snapshot identities and owner/provenance projections (source lines
63--97, 340--375). They are not the normative V4 candidate identity tuple
`(G1,G2,G3,parent,mission,scenario,physical_subject,solver_input)`. The source
also declares `authority_kind=:no_external_authority`; this is an explicit ceiling,
not missing evidence that can be promoted.

## 03 contract blockers found before implementation

1. **Package closure is absent.** `03-scope-contract-repair-r2/README.md`,
   `contract.md`, and `test_matrix.md` describe `checker_contract.json`, the
   schemas, manifests and raw audit, but those paths are not present. The package
   cannot be independently resolved, hashed, or accepted.
2. **Resolver registry is not frozen.** `resolver_registry.json` has six entries,
   but the four schema entries use `PENDING_CANONICAL_BUNDLE_HASH`,
   `PENDING_INPUT_HASH`, `PENDING_OUTPUT_HASH`, and
   `PENDING_FAILURE_RECORD_HASH`. A resolver with placeholders cannot prove
   dependency identity or reject registry drift.
3. **The proposed canonical schema needs a machine check before approval.** Its
   base `typed_ref.body` is `additionalProperties=false` with no properties,
   while `genome_ref`, `parent_ref`, `mission_ref`, `scenario_ref`, and
   `source_ref` specialize `body` in `allOf`. Under JSON Schema intersection this
   can reject the specialized body fields; a positive typed-ref fixture and a
   negative foreign-body fixture are required before calling the schema executable.
4. **Cross-object invariants are only described.** The 03 contract correctly calls
   for canonical digest equality, candidate/source joins, replay gates, CAS and
   taxonomy closure, but the referenced checker contract is missing. JSON Schema
   shape validation alone cannot prove those equalities.

## Conditional minimum file ownership after 03 approval

The following is the smallest additive ownership split. Existing V1 files remain
read-only dependencies; no shared package entry point, operator registry,
`Project.toml`/`Manifest.toml`, task manifest, G1/G2/G3 scaffold, or historical
R1 package may be edited.

| owner role | exact minimum path(s) | ownership and boundary |
|---|---|---|
| source implementer | `src/RuntimeV4/M4Isolated/ManufacturedEngineeringFeedbackSliceV2.jl` | V2 typed request/result, pure manufactured mapping, closed failure routing, payload/artifact hash projections; consume V1 snapshots read-only; no provider/solver/physical path |
| test owner | `test/RuntimeV4/M4Isolated/manufactured_engineering_feedback_v2_tests.jl` | positive, typed-negative, cross-object checker, CAS/history, resolver and replay-gate tests; must not edit V1 tests |
| oracle owner | `test/RuntimeV4/M4Isolated/oracles/engineering_feedback_oracle_v2.py` | independent exact-Fraction oracle and canonical output; no Julia/package imports; must emit the same frozen canonical bytes used by the checker |
| contract/checker owner | corrected `03-scope-contract-repair-r2/{canonical_bundle_schema.json,input_schema.json,output_schema.json,failure_record_schema.json,failure_taxonomy.json,checker_contract.json,resolver_registry.json,manifest.json,hash_manifest.json}` | close 03 before implementation; freeze URN registry and dependency hashes; implementation consumes these files read-only |
| fixture owner | `03-scope-contract-repair-r2/fixtures/{request_valid.json,result_expected.json,negative_cases.json}` (or an explicitly approved equivalent under the V2 test fixture directory) | frozen candidate/source/upstream join, feedback edge and operation-history vectors; include foreign join, digest drift, resolver, CAS/history and replay negatives |
| integration owner | `03-scope-contract-repair-r2/raw/**` and named execution sidecars under the same package | serial command receipts, raw stdout/stderr, PID/UTC/exit, input/output/artifact hashes, cleanup and review-start/end dirty closure; no source ownership |
| independent reviewer | separate `reviews/03-implementation-readiness-independent-review-r1/**` chosen by Sol/root | different-role static and runtime review; cannot share the implementer directory or acceptance authority |

No additional production file is justified for the isolated screen-only slice.
The existing V1 source/test/oracle must not be “upgraded in place”; doing so would
erase the R1/current-byte distinction and invalidate the frozen hash boundary.

## Required interface and receipt checks

Before any `valid_screen` result is possible, the V2 test/checker lane must cover:

- **Interface:** request parsing; complete candidate/G1/G2/G3/parent/mission/
  scenario/source join; exact rational encoding; V1 upstream snapshot identity;
  forward/inverse round-trip; feedback-on/off response and typed failure status.
- **Binding receipt:** projection equality between canonical bundle, request,
  result and output receipt; `physical_subject` remains explicitly manufactured
  non-physical; source owner/provenance/applicability and every upstream
  source/test/oracle/composition hash are present and recomputable.
- **Result/artifact receipt:** canonical input bytes/hash, canonical output
  bytes/hash, artifact hash, raw/process references, PID/UTC/exit and claim
  ceiling are all non-empty and mutually joined. A process exit of zero alone is
  not evidence.
- **Failure receipt:** every typed failure has an allowed code/class/resolution,
  stable path/detail, and preserved raw context. Unknown code, resolution mismatch,
  runtime exception, interruption and missing authority must remain typed and
  cannot become `valid_screen`.

## CAS, history, resolver and replay test points

| lane | minimum deterministic controls |
|---|---|
| CAS / edge identity | exact immutable tuple `(candidate, source, owner, edge, parameter, axis, direction)`; `delete_beta_or_interface_feedback` only; expected version equals current and history `before_version`; wrong candidate/source/owner/axis/direction fails closed |
| history | one append-only record with sequence `1`, `after_version=before+1`, unique operation id, canonical before/after byte hashes, actor/owner and UTC `Z`; duplicate, stale, skipped/reversed sequence, non-UTC, dynamic insert and wrong operation are rejected |
| fail atomicity | every rejected CAS/history mutation leaves state bytes, state hash, operation hash and history byte-identical |
| local ref resolver | URN must be an exact key in frozen `resolver_registry.json`; path stays inside 03; bytes and SHA-256 match; unknown URI, URL/network URI, implicit base URI and registry/hash drift fail closed |
| replay | independent Fraction oracle then typed checker, exactly two serial attempts, unique attempt IDs, `[0,0]` exits, same environment/input/dependency hashes, semantic equality and canonical-byte equality; zero/one replay, duplicate attempt, nonzero exit, semantic-vs-byte mismatch and changed input require a new freeze |
| taxonomy | failure record code/class/resolution sets equal the taxonomy exactly and each code maps once; unknown code or resolution mismatch is rejected |

The current V1 test's `sprint(show, payload)` equality and the oracle's local
JSON hash are useful historical controls but do not satisfy these receipt gates.

## External authority and hardware/provider gaps

| missing authority | current classification | required owner/evidence before formal work |
|---|---|---|
| true reference / B07B | `unknown + terminal_deferred` | provenance/license/version/hash, coordinates/units, calibration, noise/missingness, hidden-parameter declaration, candidate-independent calibration/validation/held-out split, identifiability/UQ and independent checker |
| source/hardware / B07A | `unsupported` for this isolated lane; `terminal_deferred` for formal branch | candidate-bound G1/G2/G3 source geometry, finite coil/conductor/return/driver/power domain, current/ramp limits, materials/manufacturing, cooling, structure, protection and universal start/stop/fault/tolerance scenarios |
| forward solver/provider | `not_executed` / `terminal_deferred` | UP3-02 forward-model evidence, UP2-05 applicable provider manifest, solver-input hash, backend revision, independent replay/checker and scope match |
| engineering feedback | `manufactured software relation only` | source-to-field-to-circuit/power-to-thermal/material/structure/control closure; no default zero EMF/loss or ideal support; all ledger and fault scenarios |
| hardware measurement | `not_executed` | real instrument/calibration/uncertainty receipt and firmware/hardware identity; no hardware-in-the-loop claim is possible from this package |

The manufactured pair `(2/3,1/3) -> (2,1)` and beta deletion delta are exact
software controls only. They do not supply B07A hardware realization, B07B true
reference recovery, provider applicability, or UP4 credit.

## Handoff gate

Keep the implementation lane blocked until the 03 package has all referenced
files with real hashes, a passing local resolver positive/negative audit, a
machine-checkable canonical join, and an explicit Sol/root approval. After that,
the conditional file split above may be dispatched. Even then, current source
re-freeze, two strict serial replays, different-role review, and all external
authority gates remain required; the maximum possible result remains
`manufactured_inverse_feedback/screen_only`.
