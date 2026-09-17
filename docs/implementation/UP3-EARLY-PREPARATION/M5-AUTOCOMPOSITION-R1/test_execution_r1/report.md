# M5-A auto-composition test execution R1 / evidence repair R2

The existing execution artifacts were preserved and copied byte-for-byte into
`repair_r2/archive/raw/`. No Python or Julia command was rerun during R2, and
no source, test, or oracle file was changed.

The Python standard-library oracle has exit code 0 and reports equal canonical
and permutation-normalized hashes:
`a0823a76ddac17bd193a03c8ed86945d06c4637649611f248a53383dd0d6f6fe`.
It covers the four-stage manifest, seven typed ports, three owner/interface
joins, frozen A-D identities, and typed unit/port/owner/hash/identity and
provider-drop controls.

The Julia isolated test raw output reports `110 passed / 110 total` and
`M5-A-TESTS PASS manufactured_auto_composition/screen_only`, with exit code 0.
The test artifact declares typed controls for invalid A/B/C/D and foreign
inputs, unit/rank/port/domain/owner/interface, foreign hash/identity, provider
drop, missing capability, and label/order mismatch. Provider drop is
`terminal_deferred` with no provider constructed. The claim ceiling is
`manufactured_auto_composition/screen_only`; no formal credit is claimed.

R2 can verify the recorded PIDs, exit files, raw byte counts, SHA-256 values,
frozen A-D source/test/oracle hashes, and archive copies. The original process
start/end UTC timestamps were not persisted as independently verifiable data;
R2 records them as `not_recorded` and records file timestamps only as observed
file times. Therefore a fresh replay is required if exact process-time fields
are mandatory for the final receipt.

See `repair_r2/observed_artifacts.json`, `manifest.json`, and
`validation_receipt.json` for machine-readable details.
