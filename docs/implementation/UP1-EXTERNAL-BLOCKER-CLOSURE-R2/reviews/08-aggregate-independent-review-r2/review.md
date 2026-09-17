# Aggregate gate independent review R2

Verdict: `rework`.

R1's seven attack classes were rerun from a fresh Python `-B` process after
返工, and all seven now fail closed or become deterministic as required:
fingerprint mismatch, unknown fields, authority false, exact responsibility
set, sequence/direct aggregate, duplicate JSON key, fingerprint format/domain,
and canonical map permutation. The focused suite passes `17/17`.

One P1 defect remains. `transition` treats caller-supplied `prior_state` as
trusted state without authenticating or validating its receipt/package lineage.
A fabricated prior with the same input fingerprint and
`state.phase=validated, sequence=3` lets an `event=aggregate, sequence=4`
input return `aggregated/verified/no_publish=false`. A fabricated same-input
prior with `status=verified, resolution=eligible_for_authority_recheck,
no_publish=false` returns `deterministic_noop` with empty packages and the same
publishable status. Two independent child processes reproduced these results.

Therefore the component remains `rework`; the claim ceiling is unchanged and
no AD, T0/T1/T2/B00/B04/L4/parent credit is granted. No Julia/DESC/solver/mesh/
provider/heavy or external operation was run.

