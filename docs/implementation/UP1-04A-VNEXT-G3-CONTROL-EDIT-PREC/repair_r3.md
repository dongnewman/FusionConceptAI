# Repair R3 after focused test receipt R2

R2 was executed with the authorized command and exited `1`. Its raw files
remain immutable at `test_r2.stdout`, `test_r2.stderr`, `test_r2.exit`, and
`test_r2.receipt.json`. The failure occurred at test setup because the
new additive API was loaded into `FusionConceptAI` after `using .FusionConceptAI`
and therefore its newly declared constants were not imported into the test
scope (`UndefVarError: G3_CONTROL_CHILD_EDIT_CONTRACT_URI_V1`).

The minimal repair adds an explicit export list to the new source file and
moves `using .FusionConceptAI` after the additive include. No shared entry
point was changed. Before R3, the source hash is
`5bcdc4cc89ee2ee3cd5b2647282fe8486b28ee6220f29ecb53fc46ca5270b6ba` and the
test hash is
`c6a23a5c2b9b8e75c4fd53d345809d956d4ea33441532f533aed04cfd4132f42`. The
pre-rerun audit found zero Julia and zero DESC-named processes, `git diff
--check` exit `0`, and 4316 dirty rows. R1 and R2 remain preserved failed
receipts; R3 must again use the same dedicated command.

