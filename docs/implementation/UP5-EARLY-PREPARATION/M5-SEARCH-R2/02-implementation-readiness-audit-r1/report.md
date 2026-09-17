# M5-SEARCH-R2 implementation-readiness audit R1

Status: `NO-GO_FOR_IMPLEMENTATION_EXECUTION / READ_ONLY_AUDIT`.

This audit maps the 00 scope contract (and the expected 01 implementation
contract) onto the current checkout. It is not an implementation, search run,
performance result, or capability result. No Julia, search, solver, provider,
mesh, or physical process was started. No source or test file was modified;
the only new files are this audit directory.

The checkout is `D:/006-Programing/LMC/FusionConceptAI`, branch `main`, HEAD
`b2c04d8339774635aaecd73651efcdb101e01b5d`. It has pre-existing dirty and
untracked work. Those bytes remain protected. The exact audit inputs and their
working-tree SHA-256 values are in `source_hashes.json`.

## 1. Readiness verdict

The current code supplies a useful typed conditional whole-program rewrite
kernel, canonical bytes/hashes, a generic candidate proposal envelope and a
candidate queue. It does not supply the R2 search slice. In particular, there
is no R2-owned immutable synthetic bundle, QD archive, MCTS DAG/emitter,
synthetic descriptor schema, shared search budget ledger, deterministic
content-receipt plus operational-envelope split, independent R2 checker, or
M5-C gate join. The 00 contract already records these as missing/unfrozen
inputs; this audit confirms them against the source.

Therefore the implementation package must remain `not_executed`,
`terminal_deferred=true`, `screen_only`, `no_publish=true`, and
`formal_credit=none`. A future implementation may be started only after the
01 contract freezes the file ownership, source fixture/grammar authority,
checker environment, and M5-C gate envelope.

## 2. Existing API audit

| Area | Existing evidence | Reusable seam | R2 gap / consequence |
|---|---|---|---|
| Conditional e-graph types | `src/IR/ConditionalEGraphTypes.jl:31-248` defines typed rewrite/set, `ConditionalEGraphBudgetV1`, e-class/member/provenance, derivation result and query result. | Reuse `TypedASTProgramV1`, `WholeProgramConditionalRewriteV1`, `ConditionalRewriteSetV1`, `DerivedConditionalEGraphV1`, `canonical_hash`, `canonical_json`, and `replay_conditional_rewrite_trace`. | The existing budget is `max_programs<=64`, `max_rewrite_attempts<=4096`, `max_rounds<=32`, `max_trace_steps<=256` (`:81-87`); it has no e-class/e-node counters, no global ledger, no per-seed identity, and no R2 stop envelope. `programs` is not an e-class/e-node count and must not be relabelled. |
| Conditional saturation | `src/IR/ConditionalEGraphSaturation.jl:151-225` enumerates two orientations, sorts proposals and emits a bounded e-class/trace. | Wrap it with a per-seed adapter and preserve the existing deterministic tie-break/replay. | Conditions are stored and accumulated but are not evaluated against a typed condition catalog before a merge (`:181-218`). R2 needs an explicit 9-dimension condition oracle (`type`, `rank`, `domain`, `unit`, `port`, `owner`, `interface`, `conservation`, `applicability`), zero merge on unmet condition, and fail-closed contradiction/identity handling. |
| E-graph canonical/receipt bytes | `src/Canonical/ConditionalEGraphCanonical.jl:28-94` exports canonical attempt/equivalence/trace bytes and hashes. | Use only for the typed graph payload and include its hash in the R2 content receipt. | Existing attempt/equivalence bytes do not contain R2 source/mission/bounds/scenario/emitter identity, shared counters, or operational stream joins. Add an R2 domain-separated wrapper; do not overload existing canonical hashes. |
| Grammar | `src/GenomeV5/G1/GrammarProfileV2.jl:199-317` provides candidate-owned typed operators/closures, profile and grammar/applicability hashes. `src/RuntimeV4/Compiler.jl:102-156` compiles a full candidate and retains unresolved obligations. | Reuse grammar/profile hash derivation and typed compiler rejection semantics. | No immutable synthetic fixture/grammar bundle or R2 production/action enumeration exists. The R2 grammar must be a separate versioned fixture/authority input; do not edit `default_operator_registry()` or infer authority from source presence. |
| Descriptor | `src/RuntimeV4/Compiler.jl:8-13,91-100` has a private structural node descriptor used for normalized declarations. `ProposalEnvelopeV4` has a string `target_behavior_cell`. | Reuse typed graph fields as inputs to a synthetic-only descriptor derivation. | No public descriptor schema, axis order, finite bounds, normalization, cell discretization, unknown handling, or label-erasure contract exists. The private structural tuple is not a behavior descriptor and must not be promoted to one. |
| Proposal API | `src/Contracts/CandidateStatePackage.jl:23-56` defines immutable `ProposalEnvelopeV4`; `src/RuntimeV4/Search.jl:20-135` defines a candidate queue and deterministic priority order. | Emit proposals through an additive adapter; retain proposal/evidence separation and queue identity rules. | `ProposalEnvelopeV4` lacks source/grammar/mission/bounds/scenario hashes, parent-prefix hash, emitter config hash, seed/sequence, descriptor hash, budget snapshot and content receipt hash. Its `proposal_id` is a string and its cell is not schema-bound. It cannot be the R2 authoritative receipt. |
| MCTS | The only current MCTS material is design prose in `docs/v4_multitopology_generation/04_mcts_and_generative_proposal.md:5-19,21-72,146-154`. | Adopt canonical prefix hash nodes, DAG lineage retention, typed action compilation, and no evidence-writing authority. | No tree/DAG node, action, progressive-widening counter, root/depth/expansion budget, deterministic tie-break or replay implementation exists. |
| QD | Design prose in `docs/v4_multitopology_generation/03_open_ended_evolution_and_quality_diversity.md:29-50,80-105,129-137` describes a sparse archive and multi-emitter policy. | Adopt sparse cell map, multiple members per cell, failure-frontier preservation and no family/name routing. | No archive/cell/member type, descriptor cell key, deterministic replacement rule, emitter budget ledger or archive replay exists. |
| Independent checker | `test/RuntimeV4/M4Isolated/oracles/conditional_egraph_oracle_v1.py` is an existing stdlib-only pattern for a small manufactured oracle. | Reuse the independent-process/std-library-only posture and fail-closed checks. | No R2 checker validates source closure, content/envelope separation, QD/MCTS joins, shared counters, replay equality, or the M5-C gate. |

## 3. Minimum additive implementation package and ownership

The following is the smallest coherent future package. These are a file/owner
map, not authorization to create the files in this audit turn. Existing files
above remain read-only unless a later 01 contract explicitly grants a narrow
include/export seam.

| File (new) | Owner | Required responsibility | Must not do |
|---|---|---|---|
| `src/UP5/M5SearchR2Contracts.jl` | Luna implementer; Sol contract owner | Closed types for synthetic source/grammar/mission/bounds/scenario bundle, identity closure, descriptor schema/cell, per-seed/global budget config and counter, status/stop reason, deterministic content receipt, operational envelope, M5-C gate envelope. Domain-separated canonical bytes/hashes only. | No solver/provider/mesh calls; no mutation of old Genome contracts; no random/time/PID bytes in deterministic content. |
| `src/UP5/M5SearchR2Engine.jl` | Luna implementer | Per-seed conditional-e-graph adapter with condition oracle and R2 counters; deterministic QD archive/emitter; deterministic MCTS DAG/emitter; shared proposal/unique-prefix/screen/trace ledger; proposal-to-content-receipt path. | No writing `EvidenceEnvelopeV4`; no hard-gate changes; no physical claims; no bypass of M5-C preflight. |
| `tools/validate_m5_search_r2.py` | Different Luna reviewer (independent checker) | Disk checker in a separate process/runtime. Recompute canonical content bytes, source closure, all hashes/joins, counter monotonicity/caps, trace replay, descriptor/cell rules, QD/MCTS lineage, operational-envelope joins and M5-C gate. | Must not import the Julia implementation or accept runner exit as evidence. |
| `test/m5_search_r2_contract_tests.jl` | Luna implementer | Constructor/schema/identity, canonical ordering, finite-number/duplicate-key rejection, side-condition zero-merge/fail-closed, budget stop semantics, content/envelope separation. | No expensive search and no Julia/DESC/provider execution. |
| `test/m5_search_r2_engine_tests.jl` | Luna implementer | Bounded QD/MCTS counts, same-config deterministic content replay, permutation/label erasure, DAG lineage preservation, archive replacement and shared counter precedence. | No physical/engineering interpretation. |
| `test/m5_search_r2_checker_tests.py` | Different Luna reviewer | Positive package plus tampered fixtures for every checker rejection. Run checker against disk artifacts, not in-process helper state. | Must not reuse implementation's canonicalizer as an oracle. |
| `test/fixtures/m5_search_r2_synthetic_bundle_v1.json` and `test/fixtures/m5_search_r2_grammar_v1.json` | Sol freezes; Luna materializes bytes | Exact synthetic typed programs, rules, condition catalog, grammar productions, descriptor axes/bounds/cells and source-authority receipt. | No physical source, real device, provider or benchmark identity. |
| `docs/implementation/UP5-EARLY-PREPARATION/M5-SEARCH-R2/03-execution-r1/` | Sol acceptance owner; executor writes receipts | Manifest, raw streams, deterministic content receipts, operational envelopes, checker receipt, replay comparison, budget/failure ledgers and cleanup. | Never overwrite this audit or publish a winner/capability increment. |

`src/FusionConceptAI.jl` would need one additive include/export seam for the
two R2 source modules. That seam is owned by the main integrator (Sol) and
must be a separately reviewed minimal diff; this audit does not change it.

## 4. Budget-counter contract

Counters must be typed, monotonic, explicit in every stop record, and checked
both per seed and globally. A counter is incremented at the observation point,
not inferred from output length after the run. Every cap hit is represented by
one stage-specific `stop_reason` and `resolution=terminal_deferred` unless a
more severe fail-closed/program exception precedes it.

| Scope/stage | Counter and hard cap | Increment definition | Stop classification |
|---|---:|---|---|
| Per seed e-graph | `rewrite_applications <= 32` | One attempted typed rule/orientation application, including a condition-unmet observation. | `saturation_incomplete`, `terminal_deferred` |
| Per seed e-graph | `eclasses <= 128` | One distinct canonical member/e-class key admitted; source counts once. | `saturation_incomplete`, `terminal_deferred` |
| Per seed e-graph | `enodes <= 512` | One admitted typed e-node/provenance member; duplicates do not increment. | `saturation_incomplete`, `terminal_deferred` |
| Per seed e-graph | `trace_rows <= 512` | One emitted trace row, including a recorded condition result where the contract requires a non-merge event. | `saturation_incomplete`, `terminal_deferred` |
| QD | `proposals <= 24` | One QD action request before deduplication. | `qd_budget_exhausted`, `terminal_deferred` |
| QD | `archive_cells <= 16` | One occupied synthetic descriptor cell. | `qd_archive_budget_exhausted`, `terminal_deferred` |
| QD | `members_per_cell <= 2` | One retained member in a cell; replacement is not an extra member. | `qd_cell_member_budget_exhausted`, `terminal_deferred` only if the requested action cannot be represented |
| MCTS | `roots <= 4` | One canonical root prefix admitted. | `mcts_root_budget_exhausted`, `terminal_deferred` |
| MCTS | `max_depth <= 3` | Edge count from root; depth-3 leaves are terminal for this slice. | `mcts_depth_limit`, `terminal_deferred` |
| MCTS | `expansions <= 24` | One selected node expansion, before child deduplication. | `mcts_expansion_budget_exhausted`, `terminal_deferred` |
| MCTS | `proposals <= 24` | One MCTS action proposal before global deduplication. | `mcts_proposal_budget_exhausted`, `terminal_deferred` |
| Global | `unique_prefixes <= 64` | One distinct canonical prefix hash across QD and MCTS. | `global_prefix_budget_exhausted`, `terminal_deferred` |
| Global | `screen_evaluations <= 64` | One synthetic closure/type/cost/descriptor screen. Cache hit is a join, not a new evaluation. | `global_screen_budget_exhausted`, `terminal_deferred` |
| Global | `proposal_receipts <= 48` | One content receipt for proposal/rejection/budget stop/replay observation. | `global_receipt_budget_exhausted`, `terminal_deferred` |
| Global | `trace_rows <= 4096` | Sum of all per-seed trace rows and explicitly recorded condition outcomes. | `global_trace_budget_exhausted`, `terminal_deferred` |
| Global safety | solver/provider/mesh/physical executions `= 0` | Any nonzero observation is an immediate scope violation. | `fail_closed`, `no_publish` |

The R2 ledger must also expose `deduplicated_prefixes`,
`deduplicated_proposals`, `not_applicable_conditions`, and
`screen_failures`; these are observations, not hidden budget counters. Global
ordering is QD then MCTS only if frozen in the emitter configuration; otherwise
the canonical sequence key `(emitter_rank, seed, parent_prefix_hash, action_hash)`
must determine admission. Wall time, PID and filesystem order never consume a
deterministic content counter.

## 5. Deterministic content receipt and operational envelope

The 00 contract's requirement for byte-identical receipts conflicts with its
mandatory PID and UTC fields if they are placed in the same canonical bytes.
R2 must use two layers:

1. **Content receipt** — deterministic canonical UTF-8 JSON (sorted keys,
   duplicate keys rejected, explicit nulls, finite numbers only). It contains
   schema/version, source-bundle/grammar/mission/bounds/scenario hashes,
   candidate and parent prefix hashes, emitter/config hash, seed, sequence,
   action/rule/condition hashes, descriptor hash/cell, budget snapshot,
   status/stop reason, failure class, canonical payload hash and raw-stream
   *content references* (path plus SHA-256, with no time/PID). Its ID is
   `sha256(canonical_content_bytes)`; there is no random receipt ID in this
   layer.
2. **Operational envelope** — non-deterministic observation around one content
   receipt: attempt instance, PID, UTC start/end, command, process exit,
   environment/runtime hash, raw stdout/stderr paths and hashes, checker/replay
   relation, and `content_receipt_hash`. It is never compared byte-for-byte
   across fresh processes; the checker validates its join to content and raw
   bytes.

The replay gate compares content receipt and canonical trace byte-for-byte,
then separately checks that each operational envelope is complete and points to
the same content hash. A missing or changed source/config invalidates the
attempt; it cannot reuse a prior content receipt. `attempt_id` may be unique to
an operational run but must not enter content identity.

## 6. Independent checker and M5-C gate seam

`tools/validate_m5_search_r2.py` must reject, rather than repair, a package
with any of the following: path/hash closure mismatch; duplicate JSON keys or
non-finite values; missing identity join; content fields containing PID/time;
counter overflow or non-monotonic counter; duplicate `(seed,sequence)` or
receipt key; trace source/target/provenance mismatch; unmet conditions merged;
descriptor label dependence; QD cell/member overflow; MCTS lineage loss or
order-dependent action admission; envelope/content hash mismatch; nonzero
solver/provider/mesh/physical counters; or absent replay pair.

The M5-C seam is a mandatory preflight, not a post-hoc annotation. The 01
manifest must contain a hashed gate envelope with at least:

`gate_receipt_hash`, `owner`, `independent_reviewer`, `threshold_config_hash`,
`measurement_command`, `environment_hash`, `source_bundle_hash`,
`grammar_hash`, `r2_budget_config_hash`, `variance_policy`, `raw_refs`,
`status`, and `accepted_at`.

`require_m5c_gate(r2_config, gate_envelope)` must require `status=pass`, exact
source/grammar/budget/config joins, fresh raw/checker evidence and an
independent review. Missing, stale, mismatched or historically failed M5-C is
`terminal_deferred/no_publish`; there is no permissive fallback. The existing
M5-C R2 static record is explicitly read-only and does not provide this gate:
it records no fresh measurement/threshold owner freeze and no passing receipt.

## 7. Test matrix before any execution

| ID | Test | Expected result |
|---|---|---|
| C-01 | Canonical bundle/grammar/config ordering under JSON key and tuple permutation | Identical content hash; sequence ordering is unchanged |
| C-02 | Duplicate key, non-finite number, invalid UTF-8, missing/null identity field | Reject/fail closed; no receipt emitted |
| C-03 | Nine condition dimensions: all satisfied, one unmet, contradictory duplicate, foreign contract hash | Satisfied may merge; unmet is zero merge + `not_applicable`; contradiction/foreign identity is fail closed |
| C-04 | E-graph per-seed counters at cap minus one, exactly at cap, and over cap | Exact counts; over-cap attempt not admitted; `saturation_incomplete/terminal_deferred` |
| C-05 | QD archive 16-cell/2-member replacement, duplicate prefix, unknown descriptor axis | Deterministic sparse archive; replacement does not inflate member count; invalid axis rejected |
| C-06 | MCTS root/depth/expansion/proposal caps and two action orders | Same canonical DAG/content trace; no lineage loss; cap stop is explicit |
| C-07 | Shared global 64/64/48/4096 counters with QD/MCTS interleaving | One frozen admission order, no overrun, stage-specific stop reason |
| C-08 | Family/name/benchmark label erasure and node/port permutation | Descriptor, prefix identity, route and decision unchanged where semantically equivalent |
| C-09 | Content receipt vs operational envelope | Two fresh envelopes may differ in PID/time/attempt; content bytes/hash must match |
| C-10 | Resume after complete sequence and after incomplete tail | No duplicate content receipt; incomplete tail is `terminal_deferred` |
| C-11 | Independent Python checker positive fixture and one-at-a-time tamper matrix | Only the untouched package passes; each tamper maps to one deterministic rejection |
| C-12 | M5-C gate absent, failed, stale, wrong source/grammar/budget, correct pass | First four block before search; only exact accepted gate permits a bounded preflight |
| C-13 | Safety counters forced nonzero | Immediate fail closed; no physical/provider interpretation |
| C-14 | Two fresh processes, same immutable bundle/config/seed list | Byte-identical content receipts and traces; distinct valid operational envelopes |

No test in this matrix constitutes physical, engineering, provider, B00/B04,
L4, UP5-01/02/03 or R01-R10 evidence. Any test runner output without the raw
streams, independent checker receipt and input joins remains `not_executed` or
`review_pending`.

## 8. Handoff and non-claims

The next safe action is a Sol-owned 01 contract update that resolves the file
owners and freezes the fixture, grammar authority, descriptor schema, counter
semantics, content/envelope split, checker version/environment and M5-C gate
schema. After a different Luna reviews that contract, implementation may be
created in the additive files above. This audit itself does not authorize that
mutation and does not close any M5-C or UP5 gate.

