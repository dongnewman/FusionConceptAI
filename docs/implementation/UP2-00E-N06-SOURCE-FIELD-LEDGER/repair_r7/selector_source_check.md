| Layer | Authored selector / predicate | Actual typed source | Frozen fixture value | Gate |
|---|---|---|---|---|
| G1 equation | `governing_selector.equation_id` | `G1EquationV2.equation_id::String` | `governing-0` | exact unique match |
| G1 occurrence | four-field NamedTuple normalization | `G1LedgerOccurrenceV2` fields: `String,String,Symbol,Int` | `energy/governing-0/output/1` | exact typed match; duplicate key fail-closed |
| G1 closure | `equation.closure_ref` | `G1ClosureRuleV2.closure_id::String` | `energy-balance` | exact unique match |
| G2 interface | authored `interface_side=:left` plus distinct regions | `G2InterfaceV2.left_region_id/right_region_id::String` | `left/right` | unique match; ambiguity fail-closed |
| G2 boundary | `boundary_face=:x_min` and selected region | boundary patch face/region typed values | `left/x_min` | exact unique patch |
| G3 effort | `kind=:effort` | `G3ResourcePortV2.kind::Symbol`, `port_id::String` | `source_effort` | one unique effort port |
| G3 entry/closure | selected port id then account scope | `G3LedgerEntryV2.port_id/account_id::String`, `G3LedgerClosureV2.account_ids` | `effort-entry/source_effort/effort-balance` | exact source join |
| G3 flow/link | `kind=:flow`, link resource id | resource port/link typed String IDs | `source_flow/source-loop` | one unique link |
