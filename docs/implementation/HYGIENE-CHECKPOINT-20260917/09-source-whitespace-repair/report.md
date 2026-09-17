# Source/document EOF whitespace repair — 2026-09-17

## Scope and contract

This checkpoint covers only the following 13 already-staged files. The repair
removed superfluous blank lines at EOF while preserving the first existing
line ending and all preceding file bytes. No Julia command was run. No file
was staged or committed by this worker.

- `src/GenomeV5/UP2/GI1BSourceMutationEnvelopeV1.jl`
- `src/GenomeV5/UP2/PrecompilerInvocationCounterV1.jl`
- `src/RuntimeV4/M4Isolated/ManufacturedEquationIRV1.jl`
- `test/GenomeV5/UP2/run_up2_00_contract.jl`
- `test/GenomeV5/UP2/run_up2_module_entry.jl`
- `test/up1_external_closure_r4/integration/run_cross_binding_retest.py`
- `tools/up1_external_closure_r4/__init__.py`
- `tools/up1_external_closure_r4/environment_closure/__init__.py`
- `tools/up1_external_closure_r4/environment_closure/cli.py`
- `docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R4/22-external-input-recheck/authoritative-channel/report.md`
- `docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R4/22-external-input-recheck/environment-binary/report.md`
- `docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R4/22-external-input-recheck/trust-chain/report.md`
- `docs/implementation/UP5-EARLY-PREPARATION/M5-C-PERFORMANCE-R2/reviews/07-repair-scope-independent-review-r1/judgment.md`

## Byte-level repair receipt

The raw working-tree byte counts before and after the suffix-only operation,
and the current index byte count, are recorded below. `raw_removed` is the
number of bytes removed from the working-tree file; the two files with mixed
line endings necessarily remove the CRLF bytes belonging to their blank EOF
lines. `index_suffix_lf` is the number of normalized trailing LF bytes that
remain in the index beyond the repaired working-tree content.

| path | worktree before → after | index bytes | raw removed | index suffix LF | after SHA-256 |
|---|---:|---:|---:|---:|---|
| `src/GenomeV5/UP2/GI1BSourceMutationEnvelopeV1.jl` | 43037 → 43033 | 42985 | 4 | 2 | `e8a3ebaa3c5a2a2f2c0b6739554e099e331cdbf8fc02500017fabef9c5662d7a` |
| `src/GenomeV5/UP2/PrecompilerInvocationCounterV1.jl` | 739 → 738 | 739 | 1 | 1 | `a600e68b8236146192ce31f5b3ced3e3f2ce10203305201db4769d77bca7d9da` |
| `src/RuntimeV4/M4Isolated/ManufacturedEquationIRV1.jl` | 15965 → 15964 | 15965 | 1 | 1 | `5c0471e159952b28435acf296e52288525c4d32e2c24b8008ba5a7b68028e990` |
| `test/GenomeV5/UP2/run_up2_00_contract.jl` | 486 → 485 | 486 | 1 | 1 | `177ac3dd08268295e9042a012d4e72cae498cb3c336cea7ac1a1a10ebf31ae` |
| `test/GenomeV5/UP2/run_up2_module_entry.jl` | 1487 → 1485 | 1486 | 2 | 1 | `f3ff1e840a1af14f0eb8e33053524f40726e4c104dbda3c174a5f7bd7f0f7561` |
| `test/up1_external_closure_r4/integration/run_cross_binding_retest.py` | 4001 → 4000 | 4001 | 1 | 1 | `585e86338ae92f96fcfcbed2ee022062a88883d6b8c76443739053ba8dfa25bf` |
| `tools/up1_external_closure_r4/__init__.py` | 303 → 302 | 303 | 1 | 1 | `f4f3a9dacfddfb9a3aa9dd36b1a0d8d31d8b1d670873ea4250a8aaf66a84da1c` |
| `tools/up1_external_closure_r4/environment_closure/__init__.py` | 435 → 434 | 435 | 1 | 1 | `52f1f592ede74fcc09310574f43ce4ecaa2bae05731891d84b851b6168d6f40` |
| `tools/up1_external_closure_r4/environment_closure/cli.py` | 3323 → 3322 | 3323 | 1 | 1 | `6fd54a8def97a772d6641f2a5bc406db9524e12cff5382d71c7570fb6639694c` |
| `docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R4/22-external-input-recheck/authoritative-channel/report.md` | 5886 → 5885 | 5886 | 1 | 1 | `c80fa88047349b8eacced26062ca797c35d0f13015c895d76e79bf954e3af384` |
| `docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R4/22-external-input-recheck/environment-binary/report.md` | 5205 → 5204 | 5205 | 1 | 1 | `1fa6a10f9802a9744a23e9fa058c204599c751fca1985fdde8a3fe83c055ee95` |
| `docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R4/22-external-input-recheck/trust-chain/report.md` | 5853 → 5852 | 5853 | 1 | 1 | `077c91c23800c03b41c9b8a0d27169bd0b4d91518dab71714361b580f2c8eb8f` |
| `docs/implementation/UP5-EARLY-PREPARATION/M5-C-PERFORMANCE-R2/reviews/07-repair-scope-independent-review-r1/judgment.md` | 4586 → 4585 | 4586 | 1 | 1 | `ae5f2fd69614cccf1b602a9809e4fe7ab2955edd0b89c5aae5c9f75e6859ee41` |

The staged blob for `GI1BSourceMutationEnvelopeV1.jl` contains two normalized
EOF LF bytes beyond the repaired worktree content; its worktree also retains
pre-existing interior CR bytes under the repository's `core.autocrlf=true`
normalization. Those interior bytes were not rewritten. The other 12 paths
have one normalized staged EOF LF beyond the repaired worktree content.

## Verification

- `git diff --check -- <all 13 paths>`: exit `0`.
- Path-scoped `git diff -- <all 13 paths>`: every hunk removes only final
  blank-line rows; no non-EOF content changes are present.
- Normalized byte-prefix audit: the repaired working-tree content is the
  exact prefix of each staged blob after CRLF→LF normalization, with only the
  reported trailing LF suffix remaining in the index.
- No Julia invocation was run.
- No `git add`, `git commit`, or other staging operation was run.

The report itself is intentionally left unstaged for the parent integrator to
review and stage/commit together with the approved hygiene scope.
