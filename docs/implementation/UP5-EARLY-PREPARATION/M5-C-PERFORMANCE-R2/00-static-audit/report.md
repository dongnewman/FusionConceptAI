# M5-C ConditionalEGraph static performance audit R2

## Result and boundary

This is a read-only static audit of the M5-C manufactured adapter and its
test driver. No Julia, DESC, S3, or solver process was started. The result is
an engineering performance risk assessment only; it carries
`manufactured_conditional_egraph/screen_only` as its ceiling and no formal
UP5, semantic, physical, provider, search, or R01-R10 credit.

The current checkout is dirty and the audited files are untracked. The audit
does not clean, stage, or modify them. The exact capture metadata and input
hashes are in `manifest.json` beside this report.

## Existing evidence consumed

Before this audit, no prior `M5-C*` directory name existed under
`docs/implementation/UP5-EARLY-PREPARATION`; this directory is the new audit
record. The applicable prior records are:

* `M5-EGRAPH-SCOPE-DECISION-R1/report.md`: one isolated manufactured adapter,
  eight typed conditions, deterministic replay, bounded deferred status, and
  `screen_only` only; the existing ConditionalEGraph engine is protected.
* `M5-EGRAPH-R1/repair_r1/report.md`: the adapter parse/ include repair passed,
  but no formal M5-C tests were claimed.
* `M5-EGRAPH-R1/test_execution_r1/report.md`: the Julia test exited 1 at the
  pre-repair parse error.
* `M5-EGRAPH-R1/test_execution_r3/report.md`: Julia exited 1 before CEG
  assertions at `build_inverse` because of
  `canonical_hash(::NamedTuple)`; this is not CEG performance evidence.
* `test/RuntimeV4/M4Isolated/manufactured_conditional_egraph_v1_tests.jl:83-86`:
  the historical default budget is explicitly recorded as exceeding the
  20-minute test-only ceiling, while the test uses the bounded budget
  `8/16/4/8`.

The scope record lists older M5-A/M5-B source identities (`e626...` and
`0445...`). The current adapter and current M5-A/M5-B source files instead
hash to `284094...` and `477b5a...` and hard-code those identities at
`ManufacturedConditionalEGraphV1.jl:43-49`. Per the scope decision, this is a
changed-input/re-freeze issue, not a reason to silently merge historical and
current evidence.

## Static complexity model

Let `n` be the number of AST nodes, `R` the rule count, `M` the retained
e-class members, `Q` the proposals in one round, and `L` the trace length.
For this adapter, `n=8` is constructed by `_m5ceg_rhs` and `R=2` by
`_m5ceg_rewrite_set` (`ManufacturedConditionalEGraphV1.jl:233-272`). The
typed-AST canonicalizer enumerates all `n!` orders
(`src/Canonical/TypedASTProgramCanonical.jl:335-378`), so one
`_typed_ast_program_json` call is approximately
`T(n)=Theta(n! * n^2 * serialized-node-size)`. At `n=8`, the enumeration alone
is 40,320 candidates. The canonicalization profile's search/refinement/vertex
budgets do not short-circuit this factorial typed-AST path; only the hard
eight-node boundary and later byte checks apply.

### Findings

| Priority | Path and evidence | Static cost / explosion mode | Minimum repair candidate |
|---|---|---|---|
| P0 | Build and derivation: `ManufacturedConditionalEGraphV1.jl:275-333`; `ConditionalEGraphTypes.jl:40-50, 228-245` | A build validates both upstream products, constructs two rules, computes request identity, runs saturation, then validates the result. Rule construction and CEG canonical bytes repeatedly call typed-AST JSON. The historical default is `64/4096/32/256` (`ConditionalEGraphTypes.jl:81-87`), so count caps do not make the factorial canonicalization cheap. | Add a per-derivation immutable cache for program bytes/hashes and rule bytes; use the cached values in request hashing, proposal keys, trace creation, and receipt encoding. Until that exists, make the adapter's default explicitly bounded to the existing `8/16/4/8` lane or require a caller-supplied bounded budget. Preserve `terminal_deferred` on refusal. |
| P0 | Saturation inner loop: `src/IR/ConditionalEGraphSaturation.jl:151-225` | Each round examines `2*A*R` orientations (`A` active members). For every pair it recomputes member/lhs/rhs AST bytes (`:178-186`), then proposal keys recompute full rule bytes (`:192-203`). Candidate provenance is serialized for every proposal before deduplication (`:193-201`), even proposals later discarded. Worst-case work is at least `Theta(sum(AR*T(n)) + sum(Q^2*K))`, with `K` including rule/provenance serialization. | Precompute `lhs_bytes`, `rhs_bytes`, `rule_bytes`, and condition bytes once per immutable rule/condition tuple. Add a cheap projected-cost guard before entering a round; do not wait for `max_bytes` checks after canonicalization. |
| P1 | Saturation deduplication: `ConditionalEGraphSaturation.jl:191-220` | Proposal sorting uses insertion sort (`Q^2`), best-candidate grouping scans `best` linearly (`Q^2`), and visited membership scans all prior keys (`M^2`). The bounds (`M<=64`, `R<=32`, attempts<=4096) make memory finite but permit a large amount of repeated string comparison and allocation. | Replace only the internal lookup portions with deterministic maps keyed by the already-sealed member/proposal key, retaining a sorted final emission order. Keep the existing deterministic tie-break witness. |
| P1 | Canonical receipt checks: `ConditionalEGraphTypes.jl:226-245`; `ConditionalEGraphCanonical.jl:28-66` | Derivation serializes equivalence and attempt receipts and checks their byte limits. Those writers recursively re-emit every member, rule, program, and provenance; member/provenance writers re-enter typed-AST JSON. `max_bytes` is a post-build check, not a pre-build work limit. | Cache receipt fragments by immutable object/hash during one derivation; perform a conservative size estimate before full receipt construction and return `terminal_deferred` when the estimate exceeds budget. |
| P1 | Query: adapter `ManufacturedConditionalEGraphV1.jl:365-371`; engine `ConditionalEGraphTypes.jl:202-224` | The target and source are canonicalized, then members are linearly scanned and each member program is canonicalized until a match. A single query is `O((M+1)*T(n))`; there is no member-key index. | Build a deterministic `Dict{sealed_member_key => member}` index once when the e-class is finalized, or at least cache each member's sealed program bytes. |
| P1 | Replay: adapter `:347-363`; engine `ConditionalEGraphSaturation.jl:236-265` | Every replay validates all rules, recomputes source/target bytes and hashes, then for each trace step scans rules and re-canonicalizes current/expected/next programs. Cost is approximately `O(R + L*(R + T(n) + condition-merge))`. The two-argument adapter overload first queries, so it performs query plus replay. | Cache rule lookup by `(rule_ref, rule_hash)` and carry sealed bytes/hashes through the replay state. Keep the full provenance/condition checks; the optimization must not weaken fail-closed behavior. |
| P2 | Validate and payload/hash: `ManufacturedConditionalEGraphV1.jl:373-441` | Validation itself is mostly linear over eight conditions and checks one source/graph hash, but `payload` serializes source, rules, derivation, and graph. `manufactured_conditional_egraph_hash` calls payload again; the test repeats payload/hash and validation (`:105-119`). This can turn a cheap-looking assertion block into several factorial canonicalization passes. | Cache one validated receipt and one payload/hash per immutable product within a test/build scope, or make callers retain and reuse the first result. Do not turn caching into a global mutable registry. |
| P2 | Saturate wrapper: `ManufacturedConditionalEGraphV1.jl:335-345` | Saturating an already-built product is an O(1) identity-preserving view, but the `(a_input,b_input)` overload calls `build...` again. A caller that treats it as an in-place continuation silently pays for a full rebuild. | Document the rebuild overload as such or require an explicit `rebuild=true`-style API in a later additive revision; retain the O(1) product overload. |
| P2 | Test amplification: `manufactured_conditional_egraph_v1_tests.jl:65-214` | The fixture builds upstream products, then exercises two positive CEG builds, three zero-budget/round/trace builds, repeated payload/hash/validate calls, one query per replayable member, two replays per queried member, and tamper cases. Aggregate query/replay cost is `O(M^2*T(n))` plus replay costs. The invalid catalog/identity cases fail before derivation and are comparatively cheap. | Keep the bounded budget and test coverage, but make the member loop use one indexed query and one explicit replay assertion per member; retain a separate deterministic payload/hash test. Any reduction must not remove the zero-merge, deferred, tamper, or screen-only checks. |

## Budget and stop-loss proposal

These are implementation candidates, not executed results.

1. Keep the current positive-lane budget as the conservative smoke budget:
   `max_programs=8`, `max_rewrite_attempts=16`, `max_rounds=4`,
   `max_trace_steps=8`. With `R=2`, the attempt precheck allows only a small
   number of active-member/rule pairs before returning a typed deferred state.
2. For a still smaller CI smoke case, use `4/12/2/4` (source plus a small
   number of whole-program alternatives). Treat any `terminal_deferred` as an
   explicit bounded outcome, not equality success.
3. Do not exercise the historical `64/4096/32/256` default in an audited lane
   until canonical bytes/hashes are cached and a fresh, firmware-independent
   timing/alloc receipt is produced. The cap is finite, but it is not a
   performance guarantee.
4. Add a preflight estimate based on `n!`, rule count, projected members, and
   canonical byte size. Refuse/defer before saturation when the estimate is
   above the lane budget; the existing `max_bytes` check must remain a second
   receipt-level guard.
5. Use a supervisory wall-clock stop-loss outside the adapter: 60 s for CI
   smoke, 300 s for a bounded audit, and an absolute 20 min ceiling matching
   the historical test-only limit. Preserve stdout/stderr, PID, UTC, exit, and
   input/output hashes on timeout; classify a timeout as deferred/not-executed,
   never as valid.
6. Stop immediately on any increase beyond the frozen `n=8`, `R=2`, or
   `screen_only` contract, on non-finite/oversized canonical payloads, or on
   any failed condition/identity/trace check. Such changes require a new
   input freeze and independent review.

## Claim status

The audit establishes only static complexity findings and repair candidates.
It does not establish that the current Julia test passes, that the current
M5-A/M5-B identity mismatch is accepted, or that any saturation/query/replay
path completed in this checkout. The parent M5 lane remains
`manufactured_conditional_egraph/screen_only`; no formal gate credit is
closed by this record.
