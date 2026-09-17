# M5-A auto-composition integration R1

Fresh execution was performed in one serialized lane from
`D:\\006-Programing\\LMC\\FusionConceptAI`: Python oracle, Julia tests,
Python oracle, Julia tests. Both Python invocations exited 0 and produced
identical raw stdout bytes and identical canonical/permuted canonical hash
`a0823a76ddac17bd193a03c8ed86945d06c4637649611f248a53383dd0d6f6fe`.

Both Julia invocations exited 0 and semantically reported `110 passed / 110
total` plus `M5-A-TESTS PASS manufactured_auto_composition/screen_only`.
The test-summary duration is intentionally variable (`43.1s`, `36.1s`), so
the Julia raw stream hashes differ while semantic results agree.

The integration recomputation confirms a `TypedASTProgramV1` with 8 nodes,
roots `(5,6,7,8)`, and input ports `(1,2,3)`; a
`TypedOperatorHypergraphV1` with 7 nodes and 4 edges in `M5-A,M5-B,M5-C,M5-D`
order; seven typed ports in the frozen order; four stage identities; and
three owner/interface hash joins. The independent oracle also confirms all
five typed rejection classes and provider-drop `terminal_deferred` with no
provider constructed.

The M5 source (`e6262a11...`), frozen A-D sources, test (`42562f...`), and
oracle (`e9f13f...`) match the scope freeze. No source, test, oracle, shared
entry, registry, candidate, provider, solver, or evidence authority was
changed. The ceiling remains `manufactured_auto_composition/screen_only`;
this is not UP3-01 and grants no formal credit.

R1/R2 `not_recorded` process-time history remains preserved in the earlier
test-execution package. R3 wrapper failures remain preserved under their
explicit attempt directories. Two transient integration wrapper issues are
also disclosed in `validation_receipt.json`; neither is used as authoritative
evidence.
