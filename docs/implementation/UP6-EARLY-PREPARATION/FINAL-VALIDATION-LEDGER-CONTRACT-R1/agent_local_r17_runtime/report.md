# FinalValidationLedgerContractV1 independent agent-local R17 runtime report

## Result

R17 completed the serialized runtime gate for the FinalValidationLedger
contract-only slice. The parse-only gate exited `0`, so the focused test was
run once to completion in the foreground. It passed `123/123` in `22.1s` with
exit `0`; stderr was empty.

This is contract/runtime evidence only. It does not promote a candidate,
close the frozen parent goal, or create physical, engineering, provider,
solver, telemetry, or L4 evidence.

## Direct foreground commands

Working directory for both commands:

```text
D:\006-Programing\LMC\FusionConceptAI
```

PowerShell 7 direct call-operator invocation was used. `Start-Process`,
background launch, wrapper relaunch, and Julia/DESC provider execution were
not used.

Parse-only command (exact):

```text
& 'C:/Users/Newman/AppData/Local/Programs/Julia-1.10.5/bin/julia.exe' --startup-file=no --history-file=no --project=. -e 'Meta.parseall(read("test/RuntimeV4/final_validation_ledger_contract_v1_tests.jl", String)); println("parse-only-ok")'
```

Parse-only receipt:

```text
LASTEXITCODE=0
stdout: parse-only-ok
stderr: <empty>
```

Focused command (exact):

```text
& 'C:/Users/Newman/AppData/Local/Programs/Julia-1.10.5/bin/julia.exe' --startup-file=no --history-file=no --project=. test/RuntimeV4/final_validation_ledger_contract_v1_tests.jl
```

Focused receipt:

```text
Test Summary:                                | Pass  Total   Time
UP6 final validation ledger contract-only v1 |  123    123  22.1s
LASTEXITCODE=0
stderr: <empty>
```

No `julia`, `dsc`, or `desc` process remained after the run. No provider,
solver, or DESC execution occurred; this was a pure contract test.

## R15 input hashes, rechecked before R17

| Input | SHA-256 |
| --- | --- |
| `src/RuntimeV4/FinalValidationLedgerContractV1.jl` | `25ca4c6f72a026567c5b63345742e5c0a27514610458bf87bd579f2c6691d1d7` |
| `test/RuntimeV4/final_validation_ledger_contract_v1_tests.jl` | `268653e5b8068b1ac2d175aa6cd503d15a769ac60b1237d4ce9e4848d311b90a` |
| `test/RuntimeV4/fixtures/final_validation_ledger_contract_v1.json` | `851ee6c541f64133abfd9628878397d6d96c6e250b44ceefb3b1f3f35071ca4e` |
| `docs/implementation/UP6-EARLY-PREPARATION/FINAL-VALIDATION-LEDGER-CONTRACT-R1/static_qa.py` | `e8592356690d068afa97fea0921f3f3181d96377ec29b646aadf650aba831957` |
| `docs/implementation/UP6-EARLY-PREPARATION/FINAL-VALIDATION-LEDGER-CONTRACT-R1/independent_r5/static_qa.py` | `814bd69fec54718c6e3c121c28cb9acd36308f0f2913fb226f2d90aa23094e4d` |

All five hashes match the R15 manifest exactly.

## Preserved failure lineage

- R13 remains a real `program_exception`, decision `unknown`, with no runtime
  credit.
- R14 remains `120 pass / 1 fail / 0 error`; its one failure was the pending
  ledger missing-identity/evidence case being classified `unknown` instead of
  `terminal_deferred`. It receives no runtime credit.
- R16 remains `parse_only_program_exception`: the malformed invocation quote
  produced parse exit `1`, the focused run was not started, and the receipt is
  not source evidence. Its `no_julia_desc_after=true` disposition is retained.

R17 is the first accepted runtime result for this slice after those preserved
lineage records; it does not rewrite or delete them.

## Strict boundaries

```text
accepted=false
claim_ceiling=contract_only
publish=no_publish
evidence_credit=0
l4_credible_count=0
provider_executed=false
solver_executed=false
desc_executed=false
physical_validation=false
engineering_validation=false
```

Only the two additive R17 evidence files were created. No source or test file
was edited, and no commit was created.
