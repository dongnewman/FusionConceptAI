# M5-C Performance R2 repair-scope contract (R3)

This is a contract-only repair. `implementation_authorized=false`, `status=review_pending`,
`not_implemented=true`, `formal_credit=none`, and the claim ceiling is
`synthetic_egraph_equality/screen_only`. No Julia, solver, DESC, S3, mesh, search or
physical process is run. The only write root is this R3 directory.

## Machine closure

The schemas in `schemas/` are draft 2020-12 and close the review-04 gaps with fixed
tuples, `additionalProperties:false`, exact path-set `contains` clauses, and explicit
`if/then` branches. Equality of bytes, hashes, IDs, counts, and parent/child PIDs is
checked by `self_tests/validate_contract.py` because JSON Schema cannot express arbitrary
value equality. The validator is only an evidence checker; it is not implementation.

* Conditions are exactly eight positional kinds. `required_all_met`, aggregate, reason,
  and precedence are branch-consistent; duplicate or reordered kinds are rejected.
* Binding is exactly nine positional layers, with each layer's expected field set,
  field-level presence/bytes/hash/owner/object relation, artifact/graph relation, and
  fail-closed branch.
* Preflight has complete `R` and `limits`, UInt128 saturation fields, no-writer guards,
  and admit/defer branches. Budget has a sealed/equal/mismatch/over-limit relation with
  the fixed priority ranks; mismatch wins before over-limit.
* Collision injection is deterministic `M5CTestDigestV1`; payload bytes and hashes,
  full-key hashes, bucket, all three domain outcomes/emitted IDs, and a hostile-process
  receipt are mandatory. Full bytes are authority; digest collision is fail-closed.
* Supervisor requires wall/exit/termination/timeout/raw sidecars and forces
  `post_process_count=0`; inconsistent status/termination/exit branches are rejected.
* Cache entries contain full immutable-key, payload, canonical, and validation bytes plus
  their hashes. Entry count, owner, and cross-derivation/product/escape/mutation flags
  are checked by the validator.

## Baseline gate

`baseline_capture_contract.json` remains `contract_only_not_captured` with
`typed_status=typed_absent`, `source_run_id=null`, and no receipt path/hash. This is
intentional: no run is authorized and no performance comparison may be claimed until a
fresh unrepaired sealed baseline is captured and independently reviewed. `typed_absent`
is not a numeric zero and cannot be promoted to `measured`, `pass`, or `run_authorized`.

## Evidence and raw policy

`negative_vectors/` contains field-specific hostile vectors. `self_tests/` validates every
schema and relation, and writes only R3 raw output. `hash_manifest.json` hashes every R3
artifact after validation. Existing R2, review, source, test, oracle, probe, and historical
raw files are read-only inputs and are not copied or modified.
