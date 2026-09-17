# E1-N05 focused R2 diagnosis

The frozen focused R2 run is a real `exit=1` and remains immutable under `focused_r2/`. The authored declaration test reached 19 passes and 2 failures: `up2n05_validate` returned `program_exception` and `up2n05_authority_from_a` reported `program_exception` instead of `valid`/`contract_ready`.

The exact source-level cause is the Julia 1.10 call in `_n05_authority_errors` that used `first((i for i in package.g2.region_interface.interfaces if i.interface_ref == declaration.interface_ref), nothing)`. This two-argument generator/default form is the same incompatible lookup pattern recorded by the earlier N06 run. The repair replaces it with `_n05_unique_interface`, which returns the sole match and returns `nothing` for zero or duplicate matches. The new test checks the unique path and a duplicate-interface lookup returns `nothing`; no duplicate interface is injected into a package. All endpoint-side diagnostic concatenations now convert the `Symbol` with `String(endpoint.side)`, preserving fail-closed error classification if any negative branch reports an endpoint side.

No second Julia run was made. A fresh independent static R4 precheck must verify these changes before another focused execution. The current status remains `review_pending`; no implementation, provider, mesh, physical, or R01-R10 credit is claimed.
