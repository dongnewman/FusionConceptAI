# UP2-01-G1-DIFFUSION-V1 agent_local R3 receipt erratum

Status: `changes_requested`; `review_pending=true`; `accepted=false`.
Evidence class remains `contract_only` / `software_test_only`. This is an
append-only correction to the R2 receipt metadata. The four historical R2
files, source, tests, fixture, static QA and task state were not modified.

## Disposition

The independent R2 review found one provenance defect: the empty-file
SHA-256 was stored as a 62-character value in four R2 record files. The raw
files are authoritative and are unchanged. Appending this erratum is
sufficient because it gives a sealed replacement field and preserves the
original records for audit; rewriting them would destroy the evidence of the
original receipt defect.

Old value (62 characters):

`e3b0c44298fc1c149af4c8996fb92427ae41e4649b934ca495991b7852b855`

New value (the SHA-256 of the empty byte string, 64 characters):

`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`

## Exact historical record locations

The following four files remain byte-for-byte untouched. Line numbers are
the current line numbers in the preserved files; JSON pointers identify the
semantic fields.

| preserved record | exact location(s) | old value | replacement value |
|---|---|---|---|
| `agent_local_r2/report.json` | line 12, `commands[0].stderr.sha256`; line 13, `commands[1].stderr.sha256` | short value above | new value above |
| `agent_local_r2/evidence_manifest.json` | line 16, `raw_outputs.static_qa_stderr.txt.sha256`; line 18, `raw_outputs.focused_stderr.txt.sha256` | short value above | new value above |
| `agent_local_r2/report.md` | lines 48 and 50, raw-output hash table rows for `static_qa_stderr.txt` and `focused_stderr.txt` | short value above | new value above |
| `agent_local_r2/cleanup_inventory.json` | line 29, `entries[path=.../focused_stderr.txt].after.sha256`; line 33, `entries[path=.../static_qa_stderr.txt].after.sha256` | short value above | new value above |

The four records therefore contain eight historical occurrences in total.
The short value is not used in this erratum as an accepted digest.

## Original record file hashes

These hashes were calculated before writing this erratum and identify the
preserved historical bytes:

| file | bytes | SHA-256 |
|---|---:|---|
| `agent_local_r2/report.json` | 3421 | `b3ddbf2864690133d0740b07f49f0509e25a167fcba6130c97c820e6d46151eb` |
| `agent_local_r2/evidence_manifest.json` | 1907 | `03fd4a723ea4798a35cfb85f32ed5218d5df2ab0692890846721f7ade6e7a939` |
| `agent_local_r2/report.md` | 3871 | `a9e1cad884bfd68b897727bd4bf25469b0077a024b1b8b9be4f00ae2f4e6b3d5` |
| `agent_local_r2/cleanup_inventory.json` | 5945 | `1923ff5e75d495af3082763c073cd140533b90c77be4d73701ac54b592b12a52` |

## Raw files and recomputation

The two empty stderr files were read as raw bytes and recomputed without
running Julia or DESC:

```text
PowerShell:
$f = Resolve-Path docs/implementation/UP2-01-G1-DIFFUSION-V1/agent_local_r2/focused_stderr.txt
(Get-Item $f).Length
(Get-FileHash $f -Algorithm SHA256).Hash.ToLowerInvariant()
$f = Resolve-Path docs/implementation/UP2-01-G1-DIFFUSION-V1/agent_local_r2/static_qa_stderr.txt
(Get-Item $f).Length
(Get-FileHash $f -Algorithm SHA256).Hash.ToLowerInvariant()
```

Observed recomputation exit: `0`.

| raw path | bytes | SHA-256 | raw representation |
|---|---:|---|---|
| `agent_local_r2/focused_stderr.txt` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | empty byte string / Base64 `""` |
| `agent_local_r2/static_qa_stderr.txt` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | empty byte string / Base64 `""` |

The original R2 commands and exits are preserved as follows:

```text
python -B test/GenomeV5/G1/static_qa_diffusion_v1.py
PID 34528; exit 0; stderr bytes 0; stderr SHA-256 = new value above

julia --startup-file=no --project=. test/GenomeV5/G1/diffusion_v1_contract_tests.jl
PID 41440; Julia 1.10.5; exit 0; stderr bytes 0; stderr SHA-256 = new value above
```

The focused raw stdout remains 454 bytes with SHA-256
`ddce1ee8d42db5871173d20fef7e760b3d1406d638a39b5eb0bb1a2cc30d5d29` and
the recorded component result remains `41/41 + 42/42 + 5/5 = 88/88`.
This erratum does not rerun the focused lane.

## Evidence boundary

This correction seals receipt provenance only. It does not change the R2
implementation result or grant compiler/provider/mesh/solver/numerical/
physical/engineering/current-A/B00/B04 evidence, UP2 execution credit, or
R01-R10 credit. A different Luna must review this additive receipt before
agent_local wrapper replay. `accepted=false` remains mandatory.
