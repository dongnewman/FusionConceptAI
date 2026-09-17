# M5-C Performance R2 repair-scope contract (R4)

This is a contract-only delta repair over R3/independent review 06. `implementation_authorized=false`, `status=review_pending`,
`not_implemented=true`, `formal_credit=none`, and the claim ceiling is
`synthetic_egraph_equality/screen_only`. No Julia, solver, DESC, S3, mesh, search or
physical process is run. The only write root is this R4 directory.

## Machine closure

The R4 delta closes the two concrete schema gaps reported by
`reviews/06-repair-scope-independent-review-r1/judgment.md`: when `required_all_met=true`,
every required positional condition must carry `fact_status=met` and `fact_value=true`; cache
entries structurally inherit top-level derivation/product ownership, so an injected owner field
is rejected by `additionalProperties:false`. The baseline negative is now bound to the real
`baseline_capture_contract_schema.json`, which enforces typed-absent/null run and receipt fields.
The validator is only an evidence checker; it is not implementation.

* Conditions are exactly eight positional kinds. `required_all_met`, aggregate, reason,
  precedence, and every required fact are branch-consistent; duplicate or reordered kinds are rejected.
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
  their hashes. Ownership is inherited from the cache envelope (no duplicated per-entry owner
  fields); entry count and cross-derivation/product/escape/mutation flags are checked by the validator.

## Baseline gate

`baseline_capture_contract.json` remains `contract_only_not_captured` with
`typed_status=typed_absent`, `source_run_id=null`, and no receipt path/hash. This is
intentional: no run is authorized and no performance comparison may be claimed until a
fresh unrepaired sealed baseline is captured and independently reviewed. `typed_absent`
is not a numeric zero and cannot be promoted to `measured`, `pass`, or `run_authorized`.

## Evidence and raw policy

`negative_vectors/` contains field-specific hostile vectors. `self_tests/` validates every
schema and relation, including all three repaired negatives, and writes only R4 raw output.
`freeze_receipt.json` and `raw/freeze_hashes.stdout.raw` are a fresh read-only SHA-256/byte
recount of all ten current frozen inputs, including `ManufacturedAutoCompositionV1.jl`;
`raw/current_path_closure.json` records the exact ten-path closure and `raw/dirty_inventory.json`
records the pre-existing dirty checkout boundary. Existing R2, review-06, source, test, oracle,
probe, and historical raw files are read-only inputs and are not copied or modified.
