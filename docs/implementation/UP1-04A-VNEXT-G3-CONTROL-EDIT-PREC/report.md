# UP1-04A-VNEXT-G3-CONTROL-EDIT-PREC implementation receipt

Date: 2026-09-15

The finite control-only slice is implemented in the two exclusively assigned
source/test paths. It defines closed typed signal, initial-state, event,
controller, fault and plan records; exact candidate/parent/child identity;
derived parent binding, source-record ref and source-payload ref; four typed
provenance slots; immutable source payload/content; editable state; separate
contract admission and physical resolution; and independent source-record,
source-content, initial/current-state and operation hashes.

The only edit operation is the historical
`replace_fault_source_payload` name. It changes exactly one existing
`fault.mode` while preserving source payload, source record, four axes, child
key, parent binding, child contract identity and source content hash. The
closed operation record enforces global operation-ID uniqueness, derived refs,
full prior/replacement editable-body hashes, previous-state chaining,
`last_operation_hash`, and an acyclic current-state hash recipe. Typed absent
states use explicit absence hashes and `terminal_deferred`; physical status is
never promoted by local contract evidence. Failed calls return the original
state object and canonical bytes.

The final focused command was:

```text
julia --startup-file=no --project=. test/GenomeV5/G3/g3_control_child_editability_v1_tests.jl
```

R9 passed `167/167`, exit `0`, with zero stderr. The final receipt is
[test_r9.receipt.json](test_r9.receipt.json); raw R1–R9 stdout, stderr, exit,
and receipt files are retained. R1–R4 failed during iterative contract repair
and are preserved with repair reports; R5–R7 passed. R8 retained its failed
raw receipt after exposing a test-helper byte ownership issue; R9 repaired the
helper and passed the expanded provenance, carried-fault, terminal-hash, and
failure-atomicity coverage.

The implementation node remains `planned`, `scope_status=proposal`,
`accepted=false`, `resolution=review_pending`. Different-Luna independent
review is pending and is not written by this task. Actual control authority,
source-backed T1 mapping, realization, binding, feedback, T0/T1 completion,
provider, mesh, engineering, physical, search, B00, B04 and R01–R10 credit all
remain false.
