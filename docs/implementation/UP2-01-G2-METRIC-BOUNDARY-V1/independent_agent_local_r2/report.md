# UP2-01-G2-METRIC-BOUNDARY-V1 independent agent-local R2 review

Verdict: `pass`; `accepted=false`; `claim_ceiling=contract_only`.
`ready_for_independent_replay=true`.

This review is read-only against HEAD
`cfc745939a02fd023854dd04e9bb6d04ccadf9ee`. I did not run Julia, DESC, a
provider, mesh backend, solver, or full regression. I wrote only this report
and `manifest.json` under the authorized R2 review directory.

## Receipt and hash audit

- `python -B test/GenomeV5/G2/static_qa_metric_boundary_v1.py` independently
  exited `0` with `static_qa=pass`, `julia_or_desc_executed=false`,
  `provider_or_mesh_execution=false`, `review_pending=true`,
  `accepted=false`, and `claim_ceiling=contract_only`.
- The four current target hashes exactly match
  `agent_local_r2/evidence_manifest.json`: source
  `a52ea1a60a207027c9f8029f0928af2b8bcc543f0e9ae37b88b87c9767c337b3`, test
  `61602826511df825ca6e3958fd4c42a84193acb0c3f24236cfa67086e8c83636`,
  fixture `c7b417e33819bae64c59f22ac9b70b089d8315c52517eaa7af8fd5f63aa8a3f5`,
  static QA `b329b50fe03d6fc6daee86973399dabf949a9214a02235653bd78024f70dd94b`.
- The archived focused raw output hash and byte count match the manifest:
  `focused_stdout.txt` is 1338 bytes with SHA-256
  `1c9a656d37f8da35d9a1e5d550d6f409278d03364b885dc543cbcf31b17a8093`;
  `focused_stderr.txt` is 0 bytes with the empty-file SHA-256.
  Its seven testsets sum exactly to `20+10+16+5+14+15+5 = 85/85`.
- `git diff --check` exited `0` (only ordinary LF-to-CRLF warnings). The
  final process sweep observed no Julia/DESC/dask/desc process.

## R2 repair verification

The repair closes the R1 canonicalization finding.

- `_g2mb_canonical_faces` now orders every semantic face-owner component:
  `face`, `face_id`, `owner_region_id`, `ownership`, `reference_normal`,
  `value.kind`, `value.value`, and `value.unit.exponents` (source lines
  286-289). This is a deterministic complete key over the typed face value;
  equal keys are semantically identical.
- `G2MBSourceV1` stores `_g2mb_canonical_faces(faces)` rather than the caller's
  tuple (source line 402). Therefore `source.faces`, `semantic_view`, source
  body hashing, declaration hashing and admission traversal all see the same
  canonical order.
- The focused negative control constructs two seven-face malformed tuples with
  the same base face/id/region but different normal and value, in both input
  orders (test lines 157-168). It asserts equal source hashes, equal
  `fail_closed` classification, and equal error tuples. This directly verifies
  hash/classification/error determinism for the former tie case.
- The existing valid reverse-order test still asserts equal source and
  declaration identities. Candidate changes still rehash, and source/declaration
  tampering remains rejected.

The source/test/fixture/static QA scope remains additive and contract-only. The
fixture still records zero compile/provider/mesh/solver calls and no physical
evidence. No mesh/provider/solver credit is implied by the 85/85 receipt.

## Cleanup boundary

The R2 scratch directories are ordinary directories with only stdout/stderr
files and no reparse/link attributes:

- `D:\006-Programing\LMC\FusionConceptAI\tmp\g2mb_agent_local_r2_static\`
  contains static-QA raw output. Its runtime CRLF stdout is 521 bytes,
  SHA-256 `c10e712eab39cd7fc800432966bfa0da8977d804e0056a342ac5ae16993619aa`;
  the archived `agent_local_r2/stdout.txt` is the documented LF-normalized
  509-byte copy. Safe to delete by the creator after the archived receipt is
  accepted; retain if exact runtime line endings are part of the audit.
- `D:\006-Programing\LMC\FusionConceptAI\tmp\g2mb_agent_local_r2_focused\`
  contains the focused raw output. Its stdout/stderr hashes exactly match
  archived `focused_stdout.txt`/`focused_stderr.txt`, so it is safe to delete
  by the creator after the archived evidence is retained.

No scratch deletion was performed by this review.

## Credit and replay gate

Grant `software_static_qa=true` and `focused_julia_contract=true` based on the
agent receipt and raw output audit. Keep `compiler`, `provider`, `mesh`,
`solver`, `engineering`, `physical`, `B00`, `B04` and `R01-R10` false. The
repair is coherent and hash-bound, so this artifact is eligible to enter the
later unified agent-local independent replay. That replay remains necessary;
this review itself does not rerun Julia and does not accept the work order.
