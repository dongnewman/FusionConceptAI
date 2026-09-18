# T0 authority-recheck local harness R10

## Scope and R9 lineage

R9's seven helper groups (`32/29/34/37/22/15/33`) printed as passing before
the authority phase.  The positive authority case then returned
`fail_closed` instead of `local_checked_present`; typed absence likewise
returned `fail_closed` with `:program_exception`.  The final authority
result was therefore not a valid acceptance.  The raw inner exception was
not available in the current workspace, so this receipt does not invent one.

The source-level regression boundary is the R6 prepared-evidence rewrite:
it replaced the established `_vnl_t0_errors(local_record,
input.candidate_ref)` path with a new prepared validator.  R10 removes that
replacement and restores the exact pre-R6 dispatch, preserving the original
error precedence and exception behavior.  The test-side snapshot
single-serialization optimization remains because it computes bytes once
for an unmutated object and separately proves before/after immutability; it
does not alter product records, canonical formats, or hashes.

## Include/run correction

The authority harness includes the transport helper for definitions.  Its
helper testsets are now enclosed by `_T0L_RUN_TESTSETS`, which is true only
when the helper itself is the direct `PROGRAM_FILE`.  Thus the authority
harness no longer repeats the helper's long test fixture construction while
including it, while `julia .../vnext_declaration_transport_local_v1_tests.jl`
still executes the helper testsets directly.  Definitions used by the
authority harness remain before the guard.

## Complexity and invariants

The R9 waste source was repeated helper testset execution during include,
not evidence that the product adapter had completed.  The guard changes an
include from `O(H)` helper test work to `O(D)` definition loading, where `H`
is helper fixture/test execution and `D` is definition parsing/loading.  The
adapter uses the pre-R6 validator again; no unverified prepared-cache speedup
is claimed.  Canonical bytes, SHA-256 values, input records, public error
ordering, typed-absence semantics, and the no-shared-cache/no-mutable-record
invariants are unchanged.

## Static verification

Command:

`python test/GenomeV5/Integration/static_qa_vnext_declaration_authority_recheck_local_v1.py`

Result: `pass`, 122/122 checks.  Python compilation and fixture JSON parsing
also pass.  The static performance counters are:

| counter | value |
|---|---:|
| restored transport-validator call sites | 1 |
| prepared-evidence definitions | 0 |
| test snapshot object serializers | 1 |

No Julia, DESC, provider, solver, mesh, or heavy runtime command was run.
The R5 timeout remains classified as `program_interruption`, not pass/fail;
R9 remains a failed/incomplete runtime lineage and receives no authority or
T0/T1/T2 credit.

Independent serial review command (not run):

`$env:JULIA_NUM_THREADS='1'; julia --startup-file=no --history-file=no --project=. test/GenomeV5/Integration/vnext_declaration_authority_recheck_local_v1_tests.jl`

## SHA-256

Hashes below are filled from the final R10 working-tree bytes.

| path | SHA-256 |
|---|---|
| `src/GenomeV5/Integration/VNextDeclarationAuthorityRecheckLocalV1.jl` | `1933f9faf918999170db794639f3f94c66dc6dfd4e3a125eb9fc65ab63bdf0a9` |
| `test/GenomeV5/Integration/vnext_declaration_authority_recheck_local_v1_tests.jl` | `d0cebcaf7b3f986051c655efe83f9963e97755eb94be3d6cd769d6a44b4f03fc` |
| `test/GenomeV5/Integration/vnext_declaration_transport_local_v1_tests.jl` | `b1c355c94467c2469fff724c4d02134e9a17ac245b9cc674358393a31864814b` |
| `test/GenomeV5/Integration/static_qa_vnext_declaration_authority_recheck_local_v1.py` | `16cf7911b7ae3ea1506dc70f211600ea211c0d48666689ad00f10cb4d3f0a0e5` |
| `test/GenomeV5/Integration/vnext_declaration_authority_recheck_local_v1_fixture.json` | `0176e257423dae1aae3ad1a3c1e4820a962f86433f78964eebe395b0874053bb` |
