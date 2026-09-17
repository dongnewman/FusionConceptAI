# G-I1B source envelope independent static precheck R9

Verdict: `pass_limited`; serial `focused_r5` readiness: `ready_for_serial_focused`;
`accepted=false`; review runtime: `not_run`.

This read-only review covers the R9 test-only repair. The sole changed test
assertion now checks the semantic invariant that every N06
`authority_gap` is non-empty:

```julia
@test all(s -> !isempty(strip(s.authority_gap)),
    (s for s in G.GI1B_ROW_SPECS_V1 if s.group === :N06))
```

The old undeclared free-text requirement
`occursin("authority", lowercase(s.authority_gap))` is absent. The typed
N06 behavior remains present: N06 rows resolve as
`(:terminal_deferred, :authority_gap)`, bindings remain `:typed_absent`, and
runtime gaps retain the N06 marker. The actual-A E1-present and both-absent
factory paths, 50-row independent expected manifests, aggregate taxonomy and
schema matrix testsets remain statically present.

The production source, fixture, and runner hashes match the R9 protected
values. The test before/after pair matches the R9 owned-hash record. The
focused-R4 exit-1 raw evidence and receipts remain unchanged; no focused-R5
run was started by this review.

## Hash audit

| path | bytes | current SHA-256 | R9 expected |
|---|---:|---|---|
| `src/GenomeV5/UP2/GI1BSourceMutationEnvelopeV1.jl` | 43037 | `58e5f3aa24da64e4ca9c843fc35bba79d8089206a6b49fd56966784051a31e12` | unchanged/protected |
| `test/GenomeV5/UP2/gi1b_source_envelope_tests.jl` | 25685 | `2de750b05cfea77ad7fc2dac0d0c8f8862c60028bba38e95b887e23a4bcc0299` | R9 after |
| `test/GenomeV5/UP2/gi1b_source_envelope_fixtures.json` | 23906 | `23794ed2e7958ccd21b26418428e06279150d380e4710c77050bf8b4fe3da1c6` | unchanged/protected |
| `test/GenomeV5/UP2/run_gi1b_source_envelope.jl` | 408 | `54132f1415faba369807857c1175c317757339b1f3451af902a5f525b0f067b5` | unchanged/protected |

The test before hash was
`45948253ba490bb4bf7e163bbdc272ed8f2a4d1eb0dd098002a7c90db308ce37`
with 25712 bytes; the R9 after hash is the current 25685-byte value above.
The R9 owned-hash, repair note and static-QA records were read and remain
historical inputs.

## Focused-R4 protection

The preserved focused-R4 run remains exit `1` with `2051/2052` GI1B
assertions, one production-boundary lexical failure at line 407, and no
rerun. Its raw and receipt hashes remain:

| focused-R4 file | bytes | SHA-256 |
|---|---:|---|
| `command_receipts.json` | 1433 | `24284bb63cf5057a73f3ad5c08b5ecc7001796905f59705b443433a039b6ecab` |
| `input_manifest.json` | 1101 | `eb71931bc2c22b9fa35738a03bfa8842d53acbdcb08aa0db2a28a41a7b204bbf` |
| `preflight.json` | 1078 | `d085cfadfa28d0383974df7012015d4d54470724ee4bcdba463c05ea83051cb4` |
| `protected_before_after.json` | 1622 | `498a74c8b1450b5c5f92e9be3449df034492c029ea235ec6b5b0f1a307c6bac2` |
| `qa.json` | 2401 | `7389d37ce4139fca6465fcf0ca5ac7d2b12068db103644b4b676bb2878702e6c` |
| `stdout.txt` | 3517 | `8d0409a26d78e8b65a94cad060bfefb41d972f2ab34d6568356be0d9ae494d9c` |
| `stderr.txt` | 312 | `25fec85128abe7b380aecdfe1988bbf15e3268ff5dcec1af2bd437eb1c2ac453` |

No focused-R4 file was changed or overwritten, and no Julia/DESC command was
run during this review.

## Static checks and claim ceiling

The Python static audit exited `0` with `static_qa=pass`. JSON parsing and
SHA-256 assertions exited `0`. Checks covered the removed lexical assertion,
semantic N06 gap assertion, typed terminal-deferred/authority-gap behavior,
factory paths, 50-row matrix, taxonomy, schema, and all protected hashes.

This is a software static gate only. It grants no B00, B04, provider, mesh,
engineering, physical, or parent-goal credit. The next permitted action is one
serial focused-R5 run in a new receipt directory, subject to its own run
receipt and independent postrun review.
