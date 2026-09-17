# UP2-01-G2-METRIC-BOUNDARY-V1 agent-local R2

Status: `review_pending`; `accepted=false`; `claim_ceiling=contract_only`.

This R2 addresses the independent review P2 finding only. The previous R1
runtime, failure receipt, focused pass, and review directories remain
unchanged. No Julia/DESC/mesh/provider command was started in this R2 because
the G1 lane was occupying the serialized Julia resource during the audit.

## Narrow repair

`_g2mb_canonical_faces` now sorts on the complete semantic owner key:

`face`, `face_id`, `owner_region_id`, `ownership`, `reference_normal`,
`value.kind`, `value.value`, and `value.unit.exponents`.

`G2MBSourceV1` also stores the canonical tuple rather than the caller's input
tuple. Therefore both source/declaration bytes and admission error ordering are
independent of input order, including malformed duplicate owners that share
the same face/id/region but differ in normal or value. The duplicate-key
negative control constructs exactly that case in both orders and requires equal
source hashes, equal `fail_closed` classification, and equal error tuples.

The fixture and static QA now record and require the new negative controls and
the complete sorting-key tokens. No public entrypoint, manifest, run artifact,
old evidence, G1/G3 file, or shared file was modified.

## Static verification only

Python static QA was run with PID `41712`, UTC
`2026-09-17T11:24:24.4345137Z`–`2026-09-17T11:24:24.5206518Z`, and exited `0`.
It reported `julia_or_desc_executed=false`,
`provider_or_mesh_execution=false`, `review_pending=true`, and
`accepted=false`. The pre-check observed one Julia/DESC-named process from the
parallel G1 lane; this worker did not launch or terminate it. The post-check
was empty. No focused Julia rerun is claimed by R2.

`git diff --check` exited `0`. After the lane was released, the single
authorized focused command ran as PID `37828` from UTC
`2026-09-17T11:29:31.5512660Z`–`2026-09-17T11:29:40.8961200Z` and exited `0`.
All seven testsets passed for `85/85` assertions; stderr was empty and no
Julia/DESC process remained. This is software/contract evidence only and
grants no mesh, provider, solver, engineering, physical, B00, B04 or R01–R10
credit.
