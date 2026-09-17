# G-I1B-A narrow repair R6

Status remains `review_pending`; `accepted=false`. The preserved
`focused_r1/` evidence records the serial Julia exit-1 parse failure at
`GI1BSourceMutationEnvelopeV1.jl:293`, before the runner reached any testset.
This repair is limited to the owned G-I1B source/tests and this `repair_r6/`
directory. No Julia/DESC run was started during R6, and the failed-run
evidence was not modified.

The invalid one-line conditional-return expression in `_gi1b_root_for` was
replaced by an explicit `if head == "n05"` branch. E1-present returns the
authored declaration and the remaining locator; E1-absent returns typed root
absence with the same remaining locator. The focused tests now directly cover
both branches in addition to the existing E1-present/E2-absent and
E1/E2-absent factory assertions. A source-only scan found no other
`? return` form; the remaining ternaries are value expressions with valid
Julia syntax and no return in either arm.

The R6 pre-edit source/test/core hashes and current dirty count are recorded
in `owned_hashes.json`. All R1-R5 review/failure evidence remains unchanged.
