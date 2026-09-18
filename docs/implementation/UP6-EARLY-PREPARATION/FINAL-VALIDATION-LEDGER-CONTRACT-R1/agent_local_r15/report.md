# FinalValidationLedgerContractV1 agent-local R15 report

## R13/R14 archived lineage

R13's focused result is preserved as a real `program_exception` classified as
`unknown`; it is not rewritten as a deferred capability gap.  R14 then
reached `120 pass / 1 fail / 0 error`.  Its only failure was the pending
ledger case at test line 242: the expected `terminal_deferred` decision was
returned as `unknown` because missing evidence was treated as a terminal
artifact absence even while identity and ledger state were incomplete.

## Semantic repair

The test expectation was not weakened.  The normative contract already says
missing identity/evidence remains `terminal_deferred`, while incomplete or
conflicted execution/evidence is `unknown`.  The product validator now emits
`terminal_artifact_missing` as `unknown` only when the row is
`process_completed`, the ledger is not pending, and both ledger and row
identities are complete.  Otherwise empty evidence emits
`evidence_missing` as `terminal_deferred`.  Thus the R14 pending case is
deferred for the correct structural reason, while the existing
`exit_zero_missing_terminal_artifact` and unknown execution precedence remain
unchanged.

The test adds explicit `identity_pending` and `evidence_missing` reason
assertions.  No status vocabulary was broadened, no negative dispatch was
removed, and no authority or runtime path was wired.

## Static verification

Both current read-only checkers passed with exit `0`.  They perform lexical,
fixture, and source-contract checks only; Julia, DESC, provider, solver, and
runtime processes were not started.  No commit was created.

## Preserved boundaries

`accepted=false`, `claim_ceiling=contract_only`, `publish=no_publish`,
`evidence_credit=0`, and `l4_credible_count=0` remain fixed.
`FinalWholeDeviceAuthorityV4` remains a reserved string only.

## Next independent serial Julia command

Run from the repository root.  Capture PID, exit, stdout, stderr, and hashes;
execute the second command only if parse-only exits `0`:

```text
C:/Users/Newman/AppData/Local/Programs/Julia-1.10.5/bin/julia.exe --startup-file=no --history-file=no --project=. -e "Meta.parseall(read(\"test/RuntimeV4/final_validation_ledger_contract_v1_tests.jl\", String)); println(\"parse-only-ok\")"
C:/Users/Newman/AppData/Local/Programs/Julia-1.10.5/bin/julia.exe --startup-file=no --history-file=no --project=. test/RuntimeV4/final_validation_ledger_contract_v1_tests.jl
```

## Input hashes

| Input | SHA-256 |
| --- | --- |
| `src/RuntimeV4/FinalValidationLedgerContractV1.jl` | `25ca4c6f72a026567c5b63345742e5c0a27514610458bf87bd579f2c6691d1d7` |
| `test/RuntimeV4/final_validation_ledger_contract_v1_tests.jl` | `268653e5b8068b1ac2d175aa6cd503d15a769ac60b1237d4ce9e4848d311b90a` |
| `test/RuntimeV4/fixtures/final_validation_ledger_contract_v1.json` | `851ee6c541f64133abfd9628878397d6d96c6e250b44ceefb3b1f3f35071ca4e` |
| `static_qa.py` | `e8592356690d068afa97fea0921f3f3181d96377ec29b646aadf650aba831957` |
| `independent_r5/static_qa.py` | `814bd69fec54718c6e3c121c28cb9acd36308f0f2913fb226f2d90aa23094e4d` |

R15 is static-repair complete only; it grants no UP6, R01-R10, physical,
engineering, telemetry, or L4 credit.
