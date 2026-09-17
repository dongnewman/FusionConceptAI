# R8 static arity repair

The single focused R7 run reached the positive actual-A projection and
exposed an implementation exception at source line 433:
`n06_projection_from_a` destructured the ten-value `_n06_actual_fields`
result while discarding the selected G3 `link`, then dereferenced
`link.link_id`. The minimum repair keeps the selected link in the ninth
binding and retains `fields` in the tenth:
`equation, occurrence, closure, region, patch, _, _, _, link, fields`.

R5, R6, and R7 raw receipts remain immutable. This repair does not change the
selected typed identities, selector predicates, mutation routing, fixture, or
runner. No Julia/DESC run was performed after R7; an independent static
precheck is required before another focused run. Status remains
`review_pending`/`accepted=false`, with no B04/provider/mesh/engineering/
physical/R01-R10 credit.
