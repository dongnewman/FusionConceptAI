# M5-SEARCH-R2 bounded synthetic enlarged search scope contract

Status: `authorized_not_started`; scope status: `contract_only`; claim ceiling:
`screen_only`; `no_publish=true`; formal credit: `none`.

This record defines one small, synthetic, replayable search slice combining
conditional e-graph canonicalization with QD and MCTS proposal emitters. It is
an implementation contract, not a campaign result. No Julia, DESC, S3, solver,
provider, mesh, physical, engineering, B00/B04, B00 F0-F5, 50-receipt, L4 or
R01-R10 result is produced by this record. Existing dirty files are protected;
the only writable scope is this directory.

## 1. Admissible input and identity

The executor must consume an immutable, synthetic typed-program fixture and a
versioned grammar bundle. The exact observed baseline and SHA-256 input list
are in `HEAD.txt` and `input_hashes.json`. The listed source files are
read-only references; their presence or local hash is not source authority.

Every proposal and receipt is bound to all of:

`source_bundle_hash`, `grammar_hash`, `mission_hash`, `bounds_hash`,
`scenario_hash`, `candidate_prefix_hash`, `parent_prefix_hash` (or explicit
null for a root), `emitter_config_hash`, `seed`, `sequence`, and
`canonical_descriptor_hash`.

`source_bundle_hash` is computed from an exact ordered path/hash set. A changed
source byte, grammar rule, bound, mission or scenario invalidates the attempt;
it does not reuse an old receipt. Candidate IDs are content-derived and never
come from family/name/benchmark/display labels. Label erasure and permutation
tests are mandatory for the later implementation, but are not claimed here.

The e-graph is allowed to merge only when the rule's typed side conditions
(type, rank, domain, unit, port, owner, interface, conservation and declared
applicability) are true. A failed condition performs zero merge and records a
non-authoritative `not_applicable` event. Contradictory conditions or malformed
canonical input fail closed. A proposal emitter may request an action only;
it cannot write evidence, alter a hard gate, or create a physical subject.

## 2. Bounded pipeline

The planned pipeline is deterministic and count-bounded:

1. Admit and hash the exact source/grammar/mission/bounds/scenario closure.
2. Canonicalize the synthetic typed prefix and derive the root prefix hash.
3. Apply conditional e-graph rewrites in canonical rule order. Stop at the
   first per-seed or global cap and emit `saturation_incomplete` with
   `resolution=terminal_deferred`; never silently truncate a trace.
4. Send only admissible prefixes to two independent proposal channels: QD
   (descriptor-cell exploration) and MCTS (typed multi-step action proposals).
5. Deduplicate by canonical prefix/descriptor hashes, retain a bounded archive,
   and run a pure synthetic screen of grammar closure, typed validity, cost and
   descriptor occupancy. This screen has no physical equations, provider, mesh,
   or solver call.
6. Write one immutable receipt per observed proposal, rejection, budget stop,
   and replay check. The final package remains `screen_only/no_publish`.

The initial contract caps are deliberately small and must be frozen before any
future execution:

| resource | hard cap |
|---|---:|
| deterministic root seeds | 8 (`11,23,37,41,53,67,79,97`) |
| e-graph rewrite applications per seed | 32 |
| e-graph e-classes / e-nodes per seed | 128 / 512 |
| e-graph trace rows per seed | 512 |
| QD proposals / archive cells / members per cell | 24 / 16 / 2 |
| MCTS roots / max depth / expansions / proposals | 4 / 3 / 24 / 24 |
| global unique prefixes / screen evaluations | 64 / 64 |
| global proposal receipts / trace rows | 48 / 4096 |
| solver/provider/mesh/physical executions | 0 |

The global proposal cap is shared by QD and MCTS; the first canonical sequence
under the frozen emitter order wins a slot. An optional wall-time watchdog is
only a safety interruption and cannot be used as a performance result. A cap
hit is a normal bounded outcome (`saturation_incomplete` or
`terminal_deferred`), not evidence that the grammar is exhausted or invalid.

## 3. Determinism and receipt protocol

Canonical JSON is UTF-8 with duplicate-key rejection, sorted object keys,
explicit nulls, finite numeric values only, and a declared number encoding.
Rule, action, parent and child ordering is lexicographic on canonical bytes.
The PRNG algorithm/version, seed list, emitter order, rule order and all caps
are inputs to the configuration hash; PID, wall clock, filesystem order and
thread scheduling are not inputs. A resume starts from the last complete
sequence and must not re-emit a receipt with the same attempt/sequence key.

Each receipt must contain, at minimum: `attempt_id`, `receipt_id`, UTC start/end,
PID observation, command and exit, source/grammar/mission/bounds/scenario and
prefix hashes, parent/action/rule hashes, emitter and seed, budget counters,
canonical payload hash, status, failure classification, raw stdout/stderr
references and their SHA-256 hashes. An independent checker recomputes the
canonical bytes and all joins. Same configuration in two fresh processes must
produce byte-identical canonical receipts and trace replay; cache hits are not
independent evidence.

## 4. Failure and authority semantics

The implementation must preserve layers rather than collapse them:

| observation | required classification |
|---|---|
| parser, schema, duplicate key, identity mismatch or contradictory rule | `program_exception` or `fail_closed` |
| unmet typed applicability condition | `not_applicable` with zero merge |
| cap reached before closure | `saturation_incomplete` + `terminal_deferred` |
| synthetic arithmetic/non-finite screen failure | `numerical_fail` |
| missing provider/backend/authority input | `provider_match=no_match\|out_of_domain\|invalid_signature`, `terminal_deferred` |
| interrupted or absent run | `human_interruption\|not_executed\|unknown` |
| physical or engineering judgment | not applicable; no such result may be emitted |

`physical_fail`, physical pass, provider evidence, semantic equivalence beyond
the declared rewrite theory, originality, feasibility and final authority are
outside this slice. A failed synthetic member may enter a candidate-local
failure frontier, dormant set or revival queue; it may not delete a grammar,
Genome type or topology family. No pruning certificate is issued unless a
separate proof authority and replayable proof contract are later supplied.

## 5. M5-C performance gate dependency

R2 may not execute until the M5-C owner freezes a performance gate and an
independent reviewer accepts a fresh, candidate/source-bound receipt for it.
The gate must cover at least rewrite throughput under the declared caps, peak
e-class/e-node and trace memory, receipt-write completeness, and replay
overhead. Thresholds, hardware/environment identity, measurement command and
acceptable variance must be frozen before observing R2 results; this contract
does not invent or backfill those values.

The existing M5-C record referenced in `input_hashes.json` is a historical
manufactured e-graph screen with a Julia fixture/integration failure and is not
a passing performance gate. Therefore this R2 scope is presently
`not_executed`; missing, failed, stale or unbound M5-C performance evidence
forces `terminal_deferred=true` and `no_publish=true`. A passing M5-C
performance gate would authorize only this bounded synthetic software screen;
it would not grant UP5-01/02/03, B00/B04, B00 F0-F5, 50 formal receipts,
physical/provider/engineering evidence, L4 or R01-R10 credit.

## 6. Exit and handoff

The future executor may report `screen_pass`, `screen_fail`,
`saturation_incomplete`, `terminal_deferred`, or an execution failure only
with complete raw streams, PID/UTC/exit, input/config hashes and receipt
joins. The authoritative package must include a manifest, independent checker
receipt, replay comparison, budget report, failure ledger and cleanup record.
Any missing item leaves the package `not_executed` or `review_pending`; it may
not be published as a campaign, winner, capability increment or L4 candidate.

Current static-audit metadata is retained in `execution_receipt.json` and
`raw/`. It records the read-only audit process only, not a search execution.
