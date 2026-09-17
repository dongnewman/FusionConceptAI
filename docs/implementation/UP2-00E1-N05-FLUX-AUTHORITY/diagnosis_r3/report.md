# E1-N05 focused R3 diagnosis

Focused R3 is preserved as a real `exit=1` run. The first two E1 testsets passed (9/9 and 30/30), the authored declaration and exact joins set passed 22/22, and the five typed mutation set reached 57 passes with 2 failures. Both failures were in the fixture oracle comparison for endpoint-reference mutations: the receipt classified them as `invalid_type` while the frozen expected class is `invalid_closure`.

The source classifier used `any(contains(error, "unit") for error in errors)`, so secondary unit-provenance errors caused by changing an endpoint reference overrode the primary mutated-field invariant. The static repair makes classification follow the registered typed mutation target: endpoint references and signs are `invalid_closure`; only the authored unit target is `invalid_type`. This does not read or use the fixture expected label. A new independent static R5 review is required before any further Julia run.

No provider, mesh, solver, engineering, physical, B04, or R01-R10 credit is claimed. R1/R2/R3 focused receipts and independent precheck history remain immutable.
