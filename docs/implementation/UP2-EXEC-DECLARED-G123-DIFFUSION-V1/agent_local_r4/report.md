# UP2-EXEC-DECLARED-G123-DIFFUSION-V1 — agent-local R4

## R4 repairs

R4 closes the remaining mesh-status and receipt-envelope findings:

1. The fixture and focused test use only legal G2 mesh execution statuses
   (`:declared`/`:not_executed`). Missing mesh authority is represented by the
   real G2 admission resolution and gaps; no synthetic `:executed` mesh is
   constructed.
2. G2 and G3 admission are independently dispatched through
   `dgd_admission_dispatch_v1`, so all ten named negative cases call product
   code even when G2 authority defers composition before the G3 gate.
3. Record integrity now requires each factory/declaration receipt byte envelope
   to equal the exact canonical serialized factory-result bytes and hash, and
   requires factory-result source/declaration bytes and hashes to equal the
   bundle record and typed declaration receipt.

## Python-only verification

```text
python -B test/RuntimeV4/DeclaredG123DiffusionExecution/independent_oracle.py
python -B test/RuntimeV4/DeclaredG123DiffusionExecution/static_qa.py
```

Both commands exited `0`. The independent oracle reconstructed
`A=[[9.1125,-4.6125],[-4.6125,9.337500000000002]]`,
`rhs=[1.1666666666666667,2.666666666666667]`, solution
`[0.36346540908222763,0.4651299454948799]`, and overlap transfer
`[0.25,0.75]`. It checks the exact ten-case map. Numerical status remains
`ready`; composition and aggregate remain `terminal_deferred`; provider and
mesh calls are zero.

Julia/DESC were not executed and no commit was created.

Independent Julia command for a future serialized lane:

```text
julia --startup-file=no --project=. test/RuntimeV4/DeclaredG123DiffusionExecution/focused_tests.jl
```

## Owned hashes

| File | SHA-256 |
|---|---|
| `src/RuntimeV4/DeclaredG123DiffusionExecutionV1.jl` | `9cdfe79ece3507ca638a70c6853d618455d92148a92bbef12d1ecd4e52656fdd` |
| `test/RuntimeV4/DeclaredG123DiffusionExecution/fixture.jl` | `f80a70c16df0fcd158bbac0cc29aa545e29d3f3eed90dad573d09d905878a7c6` |
| `test/RuntimeV4/DeclaredG123DiffusionExecution/focused_tests.jl` | `885323e578befa7841ccca03accef6d9fca44781ed3afac6bf462bc92e8333af` |
| `test/RuntimeV4/DeclaredG123DiffusionExecution/fixture.json` | `681a7491e3ab807417e6054ce30ee187073072c370ad9e846e16dd81ec850b44` |
| `test/RuntimeV4/DeclaredG123DiffusionExecution/independent_oracle.py` | `ee79d41b7be160f1bc9372a2cd4147cf69daf9c55406ea620b05710bafc0b361` |
| `test/RuntimeV4/DeclaredG123DiffusionExecution/static_qa.py` | `d0f5fb7826ef89a2eb4922a4fca11df585dce62438b494834c804f6bc3193142` |
