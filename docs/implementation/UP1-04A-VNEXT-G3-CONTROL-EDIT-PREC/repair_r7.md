# Repair R7 after focused test receipt R6

R6 passed `48/48` with exit `0` and remains preserved at the R6 receipt and
raw streams. Before independent review, the focused test was strengthened to
make the work-order negative coverage explicit for stale source content hash,
foreign parent identity, and foreign child identity. Existing controls already
covered stale state hash, forged child contract identity, forged source-record
ref, foreign candidate, duplicate IDs, history order, dynamic/source/plan
mutation, multi-fault edit, typed absence, and illegal status promotion.

This repair changes only the focused test. The implementation source remains
unchanged from the R6 passing source hash
`7a11562caf25e138e6e8ae0adac79d4e384577c936e8fb7f29dcb8c8256b4882`.
R7 must rerun the same single authorized command and retain a new raw receipt;
R1--R6 remain immutable.

