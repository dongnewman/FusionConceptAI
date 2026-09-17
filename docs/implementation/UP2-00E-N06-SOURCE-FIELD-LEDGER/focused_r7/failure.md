# Focused R7 failure receipt

The single authorized R7 run used the frozen source, fixture, test, and
runner hashes recorded in `input_hashes.txt`.

- Main Julia PID: `80484`
- UTC interval: `2026-09-14T05:13:30.6238915Z` to
  `2026-09-14T05:14:31.8003433Z`
- Exit: `1`
- Classification: `program_exception`
- Test summary: `10 passed, 1 error`
- stdout SHA256: `f44688f5eb2da94023d968e17216ecdac142a0d087d901dede5689e9e29477f0`
- stderr SHA256: `c4347365a73a884ebfbbf37d4c83e4e11f45fc81b3a1cf4a781e65ecfc65f2ff`

The selector normalization repair passed, but
`n06_projection_from_a` discarded the ninth value returned by
`_n06_actual_fields` and then dereferenced `link.link_id` at source line 433.
Julia raised `UndefVarError: link not defined` before the projection receipt
could be built. The existing test already contains a positive assertion that
`projection.g3_selected_flow_link_id` equals the selected actual link id; the
R8 source repair restores the binding needed to execute that assertion.

R1–R6 and all R7 raw process/log/exit artifacts remain preserved. The
postflight sweep found no Julia/DESC processes and protected dirty-file hashes
were unchanged. No retry occurred. This is an implementation exception and
gives no B04, provider, engineering, physical, or R01–R10 credit.
