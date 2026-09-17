# UP1-04A-VNEXT-G3-REALIZATION-EDIT-PREC focused R3 independent postrun review

Date: 2026-09-15  
Repository: `D:\\006-Programing\\LMC\\FusionConceptAI`  
HEAD observed: `4b69f55f7f80240147a65a22809dc1207824dde2`  
Reviewer: different `gpt-5.6-luna` / high

## Verdict

`changes_requested`; `accepted=false`; `review_pending=true`.

The third serial focused run used the R5 source and exited `1` at PID `39296`.
It ran from `2026-09-15T02:04:55.8584542Z` to
`2026-09-15T02:05:05.7119433Z`. The test summary is 35 passed, 1 failed, 1
errored, 0 broken and 37 total. Both a stale test expectation and a new
production runtime defect must be separated before the next repair.

## Raw receipt verification

The preserved streams match the run manifest:

- `stdout.raw`: 3491 bytes,
  `4d1a3b7bb992fecfa7e863beaa0e126d2246892e54efcf623c90d646d672fcd5`.
- `stderr.raw`: 214 bytes,
  `c63f6a16360622eb4863bfbc6d5f7b433d39dc544a5198d378b82692c4d8be6f`.

All 12 entries in `focused_r3/input_hashes.json` recompute exactly. Dirty
before and after both contain 306 status rows; both process snapshots are the
empty JSON array. No retry, source mutation or test mutation was made. The
focused_r1 and focused_r2 receipts remain preserved and unchanged.

## Separate classifications

### Test line 83: stale expectation, not a source defect

The failing expression is:

```julia
state.initial_state_hash == state.state_hash
```

The source computes the two hashes with different domain tags. The initial
identity uses `g3-realization-initial-state-v1`, frozen initial source content,
zero operation hash and empty history. The current state identity uses
`g3-realization-state-v1`, current source content, current operation hash and
ordered history. Even for the initial state, these are distinct contracts, and
the run printed distinct digests. The next test should assert inequality (or
remove this stale equality assertion) while retaining the explicit canonical
initial-hash recipe assertion on lines 84-89. This is a test-only repair.

### Source line 429: production zero-match runtime defect

The source currently evaluates:

```julia
pair = first((x for x in reasons if x isa Pair && Symbol(first(x)) === kind), nothing)
```

Julia 1.10 has no `first(::Generator, ::Nothing)` overload. The empty
`absence_reasons` tuple used by the valid typed-absent fixture therefore raises
the observed `MethodError` before the default reason can be selected. This is
a production defect, independent of the stale line-83 assertion.

The intended exact-match classification must be explicit:

- zero matching entries: return `nothing`, then use the deterministic default
  reason `missing $kind provenance`;
- exactly one matching entry: use that entry's reason;
- more than one matching entry: reject the source record with a
  fail-closed/constructor error rather than silently selecting the first.

The repair should use a supported collection operation and validate duplicate
slot reasons. The current code's “first match” intent is insufficient for the
multiple-match case.

## Minimal repair R6 and exit gate

The narrow repair owns:

- `src/GenomeV5/G3/G3RealizationChildEditabilityV1.jl`: replace the
  `first(generator, nothing)` expression with explicit zero/one/multiple
  classification, preserving typed absence, deterministic default reasons and
  all R3-R5 identity/status/physical boundaries;
- `test/GenomeV5/G3/g3_realization_child_editability_v1_tests.jl`: correct line
  83 to match the distinct initial/current hash domains and add narrow
  zero/one/multiple `absence_reasons` coverage;
- `docs/implementation/UP1-04A-VNEXT-G3-REALIZATION-EDIT-PREC/repair_r6/`:
  repair receipt and manifest only.

R6 must preserve focused_r1, focused_r2 and focused_r3 raw receipts, old G3
V1/V5, T0, package/registry, control/binding/feedback and provider/mesh/
engineering/physical paths. Before another serial run, recompute all source,
test and input hashes and pass JSON, plan/link, UTF-8/control-byte and scoped
diff checks. Then run exactly one authorized focused Julia command, require
exit `0` with zero failed assertions and zero errors, preserve raw streams and
the assertion summary, and obtain a fresh independent postrun. The node stays
`accepted=false`; no T0/T1/T2, provider, mesh, engineering, physical, search,
B00/B04 or R01-R10 credit is granted.

