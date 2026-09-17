# E1-N05 focused R3 classification repair

R3 is preserved as a real `exit=1` receipt. Its actual authored declaration joins passed 22/22; only two endpoint-reference mutation oracle comparisons failed because the classifier used a broad `contains("unit")` test and returned `invalid_type` for secondary unit provenance errors.

The repair classifies the observed error set with explicit precedence. Endpoint reference, port, sign, interface, and region contradictions are closure errors and return `invalid_closure` even when a changed reference causes secondary unit-source diagnostics. Unit provenance or unit dimension contradictions return `invalid_type`. An unknown error set raises a program exception rather than being assigned by fixture label or mutation id. The test now explicitly rechecks one foreign endpoint reference and one genuine unit mutation.

This is source/test contract classification only. No Julia rerun follows this repair until independent static R5 review; no B04, provider, mesh, engineering, physical, or R01-R10 credit is claimed.
