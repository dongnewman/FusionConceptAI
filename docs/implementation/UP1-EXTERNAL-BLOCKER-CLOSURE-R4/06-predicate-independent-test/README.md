# Predicate-independent test R4

This slice changes only the independent test harness. The production bundle
implementation is frozen and its SHA-256 is unchanged in
`source_hash_freeze.json`.

The two `focused_serial_0{1,2}.stdout.raw.json` files each contain 26/26
machine receipts. Their vector rows are byte-for-byte equal; each has a PID,
UTC launch observation, exit-code file, and separate stderr capture. The
runtime `called_function` field is produced by transparent instrumentation.

`call_instrumentation_adversarial_probe.stdout.raw.json` wraps all nine newly
owned predicate dispatches (R02-R07, R24, R25, D01), delegates to the original
function, and requires one trap invocation per target. It records no authority
or publication credit.

R01/R23 remain on public `validate_bundle`; R08/R15/R17/R22 remain on their
existing production paths. R22 retains the direct-wire self-referential raw
digest limitation. The repair suite records a real symlink/reparse skip when
Windows symlink privilege is unavailable; this host produced that skip.
