# T0 authority-recheck local harness R12

R12 was the sole serialized runtime lane replacing the R11 orphaned
`program_interruption`. Preflight found no Julia/DESC process and all R10
reviewed input hashes matched. The run used Julia 1.10.5, `JULIA_NUM_THREADS=1`,
one direct foreground invocation, and native stdout/stderr redirection.

## Runtime receipt

- UTC start: `2026-09-18T04:36:29.9050708Z`
- UTC end: `2026-09-18T05:36:57.3738250Z`
- exit: `LASTEXITCODE=-1`
- classification: `performance_gate_timeout / program_interruption`
- post-run Julia/DESC processes: none
- stderr: empty (`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`)

The declared 60-minute performance gate terminated PID `37620`; this is not
classified as a test pass or fail. No relaunch, source edit, or other Julia or
DESC command was performed.

## Flushed evidence and exact failure

The raw stdout flushed only:

```text
VNEXT_T0_LOCAL_STATIC_TEST_DEFINED=true
VNEXT_T0_LOCAL_JULIA_OR_DESC_EXECUTED=false
```

The positive authority fixture was entered, then the typed-absence case reached
its first failing assertion at line 167:

```text
Expression: absent.output.reasons === (:g3_feedback_material_absent,)
Evaluated: (:missing_material, :g3_feedback_material_absent) === (:g3_feedback_material_absent,)
```

The source declares 25 negative-dispatch cases, but no negative-dispatch loop
summary was flushed: `25 declared / 0 executed / 25 remaining`. The final
status/accepted/credit print lines were not flushed. The run therefore grants
no T0/T1/T2, authority, R01-R10, physical, or parent credit.

## Raw streams and input preservation

`julia.stdout.raw` is 1324 bytes with SHA-256
`9332750aacc5f0bbeeff432117c7e406d277dfd444acdda89c8f2bc06db66957`.
`julia.stderr.raw` is empty with SHA-256
`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.

The five R10-reviewed inputs are byte-for-byte unchanged pre/post; exact hashes
and sizes are recorded in `manifest.json`. R5, R9, and R11 interruption
lineages remain preserved, and the claim ceiling remains `contract_only`.

## Corrected working-tree SHA-256

The exact hashes are also recorded under `input_hashes` in `manifest.json`:

| path | SHA-256 |
|---|---|
| `src/GenomeV5/Integration/VNextDeclarationAuthorityRecheckLocalV1.jl` | `1933f9faf918999170db794639f3f94c66dc6dfd4e3a125eb9fc65ab63bdf0a9` |
| `test/GenomeV5/Integration/vnext_declaration_authority_recheck_local_v1_tests.jl` | `17d355493effafdfc3fb2418468a0b36c60a0bce1c4e25d88ac310f7ea1dfd16` |
| `test/GenomeV5/Integration/vnext_declaration_transport_local_v1_tests.jl` | `b1c355c94467c2469fff724c4d02134e9a17ac245b9cc674358393a31864814b` |
| `test/GenomeV5/Integration/static_qa_vnext_declaration_authority_recheck_local_v1.py` | `968d03044c2395211e836966163efe06953fdfb4be0ff5fabc506dcc194e78e9` |
| `test/GenomeV5/Integration/vnext_declaration_authority_recheck_local_v1_fixture.json` | `296a660dd4e907c4d733cfb4d1dc3e6cd4c59949a5128bfdec8409631ff42afc` |
