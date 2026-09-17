# Implementation record

The new `G3SourceFeedbackLawV1` contract stores all source/field/return/heat endpoints
with `UnitSignature`, direction, sign, and owner scope. Its law stores exact rational
efficiency and heat fraction, while the ledger closure stores the explicit source plus
three signed output entries. `g3_sf_evaluate_v1` evaluates a candidate declaration at
an exact rational source power and returns both energy and ledger residuals.

Feedback targets carry a G1 or G2 layer, target path, quantity, unit, direction, sign,
source ID, owner scope, and a typed authority record. Authority records include the
same candidate ref, optional external contract ref/hash, and status. Missing authority
is a typed gap. Actual authority requires a v5 ref and a digest; future binding must
also check that the ref/hash belongs to the same freshly rebuilt candidate.

The fixture evaluates `120 W` as `90 W` field output, `15 W` return, and `15 W` heat,
with both residuals equal to zero. Editing efficiency to `7/8` changes the evaluated
field output to `105 W` and changes the declaration content hash. The fixture's G1/G2
authority is explicitly missing, so no physical source authority is asserted.

The exit state is `scope_status=proposal`, `review_pending=true`, `accepted=false`.
No compiler/provider/mesh/solver/engineering/physical or R01-R10 credit is claimed.

