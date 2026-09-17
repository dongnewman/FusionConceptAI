# Repair R2 failure history

R2 preserved all prior r0-r4 evidence and introduced no failed implementation
run. The R2 independent review's direct constructor probe was retained as the
reason for this repair: the old public `PresentChildBindingV1` constructor
accepted fabricated values. The repair replaces that generated constructor
with a rejecting inner constructor. The owned Julia regression and independent
same-shape direct probe now both require
`binding_authority_typed_absent`.

The first receipt-wrapper probe and two quoting retries were retained as raw
program-exception evidence; the successful direct probe output is preserved in
`independent_present_constructor_probe_direct.stdout`. The direct command ran
without a temporary launcher; its desktop exec wrapper did not expose a child
PID, so that field is recorded as unavailable in the final receipt.

No physical, engineering, provider, mesh, T0/T1/T2, B00/B04, search or R01-R10
claim is made.
