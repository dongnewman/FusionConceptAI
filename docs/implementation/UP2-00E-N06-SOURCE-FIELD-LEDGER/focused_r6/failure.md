# Focused R6 failure receipt

The single authorized R6 run used the frozen source, fixture, test, and
runner hashes recorded in `input_hashes.txt`.

- Main Julia PID: `78304`
- UTC interval: `2026-09-14T05:02:07.3987208Z` to
  `2026-09-14T05:03:24.9311913Z`
- Exit: `1`
- Classification: `program_exception`
- Test summary: `10 passed, 1 error`
- stdout SHA256: `6b630c1639f315f4e246fb5b8b081b5f0f648bd3ca85d3dd9eb77dca1a0d63b7`
- stderr SHA256: `c4347365a73a884ebfbbf37d4c83e4e11f45fc81b3a1cf4a781e65ecfc65f2ff`

The typed-key repair progressed past the R5 `String(tuple)` exception, but
the positive actual-A projection now fails at
`N06SourceFieldLedgerMappingV1.jl:329` with
`ArgumentError: N06 G1 authored governing occurrence has no source match`.
The authored `_n06_selector_key` currently returns a named tuple, while the
actual occurrence identity and typed index use the anonymous tuple
`(String, String, Symbol, Int64)`. These values are structurally equivalent
in meaning but do not compare equal in this selector predicate. The minimal
next repair is to make selector normalization return the exact anonymous
tuple type (or compare its four fields explicitly), while preserving the
typed-key duplicate guard.

R1–R5 and all R6 raw process/log/exit artifacts are preserved. The postflight
sweep found no Julia/DESC processes and protected dirty-file hashes were
unchanged. No retry occurred. This is an implementation exception and gives
no B04, provider, engineering, physical, or R01–R10 credit.
