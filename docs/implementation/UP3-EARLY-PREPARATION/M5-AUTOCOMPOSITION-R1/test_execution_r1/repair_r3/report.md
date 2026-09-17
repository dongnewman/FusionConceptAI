# M5-A fresh replay R3

Fresh replay completed strictly serially: Python oracle first, then Julia
tests. Python PID 100208 exited 0 at 2026-09-16T10:47:31.7545334Z after the
wrapper recorded start observation 2026-09-16T10:47:31.6812383Z. Julia PID
93044 started at 2026-09-16T10:47:31.7865318Z and exited 0 at
2026-09-16T10:48:13.1727911Z.

Python reports canonical/permuted hash equality
(`a0823a76ddac17bd193a03c8ed86945d06c4637649611f248a53383dd0d6f6fe`), four
stages, seven ports, and three owner/interface joins. Julia reports
`110 passed / 110 total`. The claim ceiling remains
`manufactured_auto_composition/screen_only` with no formal credit.

Raw stdout, stderr, and true `stdout||stderr` combined streams are hashed and
archived under `archive/raw/`. Wrapper-only technical failures before the
valid replay remain under the explicit `attempt1_*`, `attempt2_*`, and
`attempt3_*` directories and are not mixed into the authoritative run.
