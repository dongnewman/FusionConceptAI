# M5-CORE-PERFORMANCE-R3 repair R11 — independent static precheck R1

## Decision

**PASS — GO for one diagnostic-only, serial focused Julia invocation.**

This is a screen-only static verdict. No Julia or DESC process was started by
this review, no product/test file was edited, and no performance, fresh-process,
formal-candidate, or R01–R10 credit is granted. The public factorial canonical
authority remains deliberately unresolved; R11 removes repeated cache-entry
re-entry only.

## Scope and frozen references

Reviewed the frozen R11 source/test snapshot, with the R11 README and evidence
manifest, and the corrected R10 raw diagnostic reference:

- `repair_r10/diagnostic_julia_r8/run.json`: exit 0, 57 passed, 0 failed,
  0 errored.
- `repair_r10/failure_receipt.md`: historical 58/1/0 failure retained as
  history, not replaced by a claim of new runtime evidence.
- `repair_r11/README.md` and `repair_r11/evidence_manifest.json`: correctly
  retain `screen_only`, `runtime_evidence=pending_serial_parent_lane`,
  `fresh_process_determinism=pending_serial_parent_lane`,
  `timing_evidence=pending_serial_parent_lane`, `formal_credit=none`, and
  `factorial_root_cause` unresolved.

The review write scope is limited to this report and its sibling manifest.
The dirty M4 adapter/probe, task manifest, and all `runs/` material were not
touched. No commit was created.

## Static findings

### 1. Stored-order witness is outside the factorial path

`_tac_program_fingerprint` uses `_tac_stored_structural_payload`, whose nodes,
roots, input ports, and manifest bindings are emitted in stored order. Its
implementation does not call `_tac_program_payload`, candidate generation, or
`_tac_permutations`. The permutation search remains in the public
`_typed_ast_program_json` path. Thus the witness is cheap and deterministic,
but it does not silently redefine public canonical bytes/hash/order.

### 2. Cold/hit and authority counters have the intended semantics

The R11 test counter asserts one payload call on a cold ordinary-cache read and
zero on subsequent ordinary reads; it separately asserts one call on an
authority cold miss and zero on a verified authority hit. An injected
unverified entry is forced through one current canonicalization before it is
rejected. This is the correct fail-closed distinction. The direct counter seam
does not by itself prove a whole saturation run's aggregate count; that remains
for the allowed serial runtime lane.

### 3. Verified-token binding is complete

`_TACVerifiedCanonicalTokenV1` and `_TACCanonicalEntryV1` are guard-constructed
and bind cache owner, exact program identity, entry nonce, exact bytes, digest,
and structural witness. `_tac_validate_verified_token` additionally requires
entry/token identity in both the entry and `verified_tokens` IdDict and
rechecks the digest. The R11 negatives cover token deletion, entry replacement,
foreign-owner transplant, wrong program, wrong hash, and wrong witness. A
same-digest/different-bytes forged entry is also rejected.

### 4. Ordinary cache does not grant authority

Ordinary derivation/cache construction and replay helpers use the validated
hint path. Current receipt/provenance program bytes use
`_tac_authoritative_program_bytes`; an unverified or inconsistent entry is
recanonicalized and compared, while a verified hit is accepted only after the
full binding checks above. Rule-byte production first recomputes the current
rule authority and then validates any stored entry. `_CEGTraceFragmentsV1`
recomputes source/target/rule digests from the sealed bytes before accepting
the hash fields, so the trace owner, rule bytes/ref/hash, and source/target
hashes cannot be supplied independently by an ordinary-cache hint. The
condition-chain checks remain explicit and current.

### 5. Saturation reuses sealed fragments without changing winner semantics

`_ceg_saturate_components` keeps `best_index::Dict` and its explicit sealed
member/proposal keys for deterministic dedup/sort/winner selection. Its
`provenance_cache::IdDict` is derivation-local and only avoids rebuilding the
same candidate provenance. `_ceg_candidate_provenance` and `_ceg_new_trace`
take current authoritative source/target/expected program bytes, while rule
bytes are produced through the authority-aware rule writer. The final receipt
path consequently reuses already sealed fragments rather than calling
`_typed_ast_program_json` for every repeat of the same proposal. This is a
performance reuse, not a new canonical authority.

### 6. Test coverage is materially present

The frozen R11 test statically contains:

- cold/hot ordinary and authority counter assertions;
- verified-token deletion/replacement, foreign owner, wrong program/hash/
  witness, and unverified forged bytes;
- n=1..8 baseline byte/hash equality against both cache paths;
- length-delimited key separation, Dict indexing, equal-digest distinct-byte
  collision handling, and insertion-order-independent sealed projections;
- ordinary cache entry mutation/deletion, condition/rule/member/proposal cache
  mutation, sealed-owner validation, forged rule/winner hints, and mixed-owner
  provenance rejection;
- legacy trace versus cache-aware trace byte equality.

The test does not make a runtime claim here, and its direct counter checks do
not replace the parent lane's eventual cold/hot/query/replay/fresh-process
measurement. That is a residual evidence boundary, not a static blocker.

## Allowed next command

The parent lane may run this **once, serially, diagnostic-only**:

```text
julia --project=. --startup-file=no --history-file=no test/RuntimeV4/M4Isolated/m5_core_perf_r3_tests.jl
```

The result must remain screen-only. Keep two-process determinism, timing, and
any broader performance/factorial conclusion pending their separately planned
lanes.
