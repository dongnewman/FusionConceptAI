# E2-N06 independent static precheck R10

Verdict: `ready_for_focused_r8`. This is a static precheck only; it is not runtime acceptance and does not grant B04/provider/mesh/engineering/physical/R01-R10 credit.

Frozen inputs are the requested source `69bd82f040f405e55768e52af64b9b9b6d97272a2ec3988b66b7bdf21ec1128c`, test `dac8c62e4ba20b45930a119649468659931eca2236cb9c5181aba101392a66ce`, fixture `361a1777a765ed6784a1f37c02febc24c2ba5f6eed3c6a15b99333af596736b2`, and runner `9410e2edbb7afc70599e183f30a2ef9836b7e84a1834296e27d96b881b1f86af`. `_n06_actual_fields` has the exact ten-value return tuple with selected G3 `link` ninth and `fields` tenth. `n06_projection_from_a` retains `link` and consumes `link.link_id` in the projection and canonical hash; it consumes the returned `fields` in the projection and hash. The adjacent join helper also destructures ten values. The positive source-bound test compares `projection.g3_selected_flow_link_id` with `_n06_actual_fields(package)[9].link_id` and checks five fields.

The R5 typed occurrence identity repair and R6 authored-selector controls remain present. R7 exit-1 raw stdout/stderr and receipt are preserved and hash-consistent; R8 metadata records no rerun. Focused R1-R7 raw directories, R1-R9 independent history, and the protected dirty after-hashes remain present/current. Static JSON parse, `validate_plan.py`, `git diff --check`, scoped protected status, and Julia/DESC process sweep were recorded in `command_receipts.json`.

No Julia/DESC process was started by this review. The next permitted action is one serial focused R8 runtime run after lane authorization.
