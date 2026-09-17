# UP2-01-G1-DIFFUSION-V1 independent R3 receipt-erratum review

Verdict: `pass_with_findings`; receipt repair is sufficient to release the
unified `agent_local -> Julia` replay lane.  The underlying task remains
`accepted=false`, `review_pending=true`, and `contract_only`.

This review inspected only the append-only
`agent_local_r3_receipt_erratum/` package and preserved R2 artifacts.  Julia
was not run, source/tests/fixture and all historical R2 files were not
modified, and only this review directory was written.

## Raw stderr recomputation

Both referenced raw files were read directly and independently hashed:

| raw path | bytes | independently computed SHA-256 |
|---|---:|---|
| `agent_local_r2/focused_stderr.txt` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `agent_local_r2/static_qa_stderr.txt` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |

Both are empty byte strings.  The erratum's `new_sha256` and both
`raw_files_recomputed` entries match this 64-character digest; its old value
is correctly recorded as the 62-character malformed digest.  The erratum
records `occurrence_count=8`, which matches an independent scan: two
occurrences each in R2 `report.json`, `evidence_manifest.json`, `report.md`,
and `cleanup_inventory.json`.

## Preserved R2 evidence

The four historical files remain byte-for-byte unchanged and their current
hashes match the erratum manifest:

| preserved file | bytes | current SHA-256 | erratum claim |
|---|---:|---|---|
| `agent_local_r2/report.json` | 3421 | `b3ddbf2864690133d0740b07f49f0509e25a167fcba6130c97c820e6d46151eb` | match |
| `agent_local_r2/evidence_manifest.json` | 1907 | `03fd4a723ea4798a35cfb85f32ed5218d5df2ab0692890846721f7ade6e7a939` | match |
| `agent_local_r2/report.md` | 3871 | `a9e1cad884bfd68b897727bd4bf25469b0077a024b1b8b9be4f00ae2f4e6b3d5` | match |
| `agent_local_r2/cleanup_inventory.json` | 5945 | `1923ff5e75d495af3082763c073cd140533b90c77be4d73701ac54b592b12a52` | match |

The eight historical locations are correct by line and path.  The only
non-material wording issue is that the report table calls the cleanup
location `entries[path=...]`; the actual JSON array is named `path_ledger`.
The line numbers and file/path values are correct, and the erratum manifest
does not rely on that incorrect array label for its digest replacement.

## Erratum contract and boundary

The erratum manifest parses as JSON and independently reports:

- `status=changes_requested`, `review_pending=true`, `accepted=false`;
- `evidence_class=contract_only`, `software_test_only=true`;
- `julia_rerun_for_erratum=false` and `desc_rerun_for_erratum=false`;
- scope limited to `docs/implementation/UP2-01-G1-DIFFUSION-V1/agent_local_r3_receipt_erratum/`;
- `raw_bytes=0`, old digest length `62`, replacement digest length `64`;
- `receipt_match_after_replacement=true` and `self_hash_excluded=true`.

The report and manifest preserve the original R2 Julia PID/exit and the
`41/41 + 42/42 + 5/5 = 88/88` result without claiming a rerun.  The explicit
credit boundary keeps compiler/provider/mesh/solver/numerical/physical/
engineering/current-A/B00/B04/UP2 execution/R01-R10 all false.

## Disposition

The provenance defect is correctly repaired additively: the old R2 records
remain immutable, the raw files are unchanged, and the replacement digest is
the actual digest of each raw stderr.  This review therefore releases the
unified `agent_local -> Julia` replay lane.  The replay must still create a
fresh output directory, retain raw/PID/exit/hash evidence, and remain
`accepted=false` pending its own independent postrun review and Sol decision.

Credit ceiling remains contract/software-test only; no physical, numerical,
engineering, B00/B04, UP2 execution or R01-R10 credit is granted by this
receipt review.
