# Focused R5 failure receipt

The single authorized R5 focused run used the frozen four inputs recorded in
`focused_r5/input_hashes.txt` and the command recorded in
`focused_r5/command.txt`.

- Main Julia PID: `11624`
- UTC interval: `2026-09-14T04:47:09.5734224Z` to
  `2026-09-14T04:48:27.2260002Z`
- Exit: `1`
- Classification: `program_exception`
- Test summary: `10 passed, 1 error`
- stdout SHA256: `0079487da8a5c73adacb4663b6a11d81fcffcdcba03b520240e15625e3021bfe`
- stderr SHA256: `c4347365a73a884ebfbbf37d4c83e4e11f45fc81b3a1cf4a781e65ecfc65f2ff`

The error is an implementation exception during the actual A projection:
`_n06_unique_index` at source line 271 forces `String(id_of(x))`, while the
selected G1 occurrence identity is the typed tuple
`(ledger_id, equation_id, port_side, port_index)`. Julia raised
`MethodError: no method matching String(::Tuple{String,String,Symbol,Int64})`
before mutation receipts. This is a typed identity handling defect, not a
numerical, physical, provider, engineering, B00/B04, or R01–R10 result.

R1–R4 and all R5 raw process/log/exit artifacts remain preserved. The
postflight sweep found no Julia/DESC processes and the protected dirty-file
hashes were unchanged. No retry was performed in this run. The author archive
remains `review_pending` with `accepted=false`.
