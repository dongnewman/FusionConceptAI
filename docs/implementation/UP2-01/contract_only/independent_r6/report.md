# UP2 pre-T0 TypedCompilerIR/Lowering R6 independent review

Date: 2026-09-17 (Asia/Shanghai). This is a read-only independent static
review of the R6 validator-consistency repair. No product or test file was
modified, no Julia/DESC/compiler/provider/mesh/solver command was run, and no
commit was created.

## Verdict and status ceiling

**GO for contract-only/prepared; NO-GO for formal UP2 acceptance.** The
constructor and validator now use the same two-way source-kind/synthetic
invariant, the four quadrants are represented by actual test cases, and local
source deferred/ready paths remain explicit. Lowering has no residual old
guard. The ceiling remains `contract_only / not_measured / accepted=false`;
no T0/T1/T2, numerical, physical, engineering, or R01--R10 credit is granted.

## Static QA

Command executed:

```text
python -B test/RuntimeV4/UP2PreT0/static_qa_typed_compiler_ir_v1.py
exit=0; checks=108; passed=108; errors=[]
```

The checker is text/hash-only and does not invoke Julia, DESC, a compiler,
provider, mesh, or solver.

## Focused checks

### Constructor and validator are symmetric

The sealed `TypedCompilerIRV1` inner constructor enforces at source lines
244--245:

```julia
synthetic == (source_kind === :synthetic) || throw(...)
```

The validator independently repeats the same equality at lines 418--420 and
emits `:synthetic_scope_mismatch` if a value is inconsistent. This closes the
R5 residual one-way guard and makes the constructor/validator rule identical.

The validator's `source_kind == :local_source` branch remains separate from
the boolean invariant: missing or `typed_absent` authority is
`:terminal_deferred`, while a checked-present authority must match schema,
revision, status, receipt, all cross-layer refs, and both units exactly.
Contradictory authority remains `:fail_closed`.

### Four quadrants and local authority paths

The isolated test has actual construction assertions for all four pairs:

| `source_kind` | `synthetic` | Expected result |
|---|---:|---|
| `:synthetic` | `true` | construct and validate `:ready` |
| `:synthetic` | `false` | constructor `ArgumentError` |
| `:local_source` | `true` | constructor `ArgumentError` |
| `:local_source` | `false` | construct; no authority `:terminal_deferred` |

The same test then attaches a checked-present authority to the last valid
quadrant and verifies `:ready`; the downstream lowering path also returns
`:ready`. The dedicated local-source test repeats missing-authority
`:terminal_deferred`, checked-present `:ready`, and foreign/unchecked
authority `:fail_closed` (`typed_compiler_ir_v1_contract_tests.jl:137--199`).

### Lowering audit

`TypedCompilerLoweringV1.jl` contains no `source_kind` or `synthetic` guard.
It only validates the already-validated IR, propagates status/failure
receipts, keeps `contract_only/not_measured/measured=false`, and rejects a
changed failure receipt. No old one-way implication remains in lowering.

## R5 failure receipt and current hashes

The R5 failure receipt remains preserved at
`runs/agent_local_up2_tcir_contract_matrix_20260917_r5/` and in
`docs/implementation/UP2-01/contract_only/agent_local_r6/manifest.json`.
Its metadata records `exit_code=1`, `83 pass / 5 fail`,
`hashes_unchanged=true`; the root cause was the validator retaining
`ir.synthetic && ir.source_kind == :synthetic` after the constructor had been
repaired. R6 does not overwrite that historical receipt.

The following values were recomputed and match `agent_local_r6/manifest.json`:

| Artifact | Bytes | SHA-256 |
|---|---:|---|
| `src/RuntimeV4/TypedCompilerIRV1.jl` | 25152 | `ff05ba2d3d81c5170f83c36dfddb9cd307b6ceec849cc0e7ecff440853197d3c` |
| `src/RuntimeV4/TypedCompilerLoweringV1.jl` | 3932 | `452758e71f6bb8d50257dad77e39fd3ec1e2aea81830d838fa93cb144b0f427c` |
| `test/RuntimeV4/UP2PreT0/typed_compiler_ir_v1_contract_tests.jl` | 12876 | `0c5d79d0b259d1efa1b863db90ff64fca0a4c12b9fb9381b320daac15a3ff732` |
| `test/RuntimeV4/UP2PreT0/static_qa_typed_compiler_ir_v1.py` | 5502 | `0e1b40e116e5bb6e38aff0c978b8c339ca4e475261322374ece730ac4e12e09d` |

This review remains a structural contract review only. A serialized parent
lane must still run the isolated Julia contract test once before any later
gate; no runtime or formal UP2 evidence is inferred here.
