# UP1-04A-VNEXT-T0-AUTHORITY-RECHECK-PREC independent postrun R2

Date: 2026-09-15  
Reviewer: independent Luna/high (`/root/g2_metric_boundary_v1_author`)  
Decision: `changes_requested`  
Review mode: read-only evidence and static semantic audit; Julia/DESC were not run in this review.

## Boundary and status

The R6 repair is limited to the seven-file authority-recheck scope. The node remains `planned` / `proposal` / `review_pending` with `accepted=false`, `launcher=false`, and `claim_ceiling=contract_only`. AD-34 remains an architecture/work-order boundary. This review grants no T0 authority, T1/T2, provider, mesh, engineering, physical, B00/B04, or R01-R10 credit.

R1-R5 focused history remains present in the implementation manifest. R6 adds only archive receipts under the task directory and leaves source, test, fixture, old receipts, core, and shared entry outside its ownership unchanged.

## R6 source/test behavior

The R6 source now has both required candidate defenses. `vnext_declaration_authority_recheck_v1` rejects `input.declaration.candidate_ref != input.candidate_ref` before the fresh-authority branch, and `_vnext_ar_pair` repeats the same check for direct/internal callers. The pairing gate then validates every upstream authority candidate, exactly one G1 and one G2, every target layer and target authority candidate, eight-field target-key uniqueness, target-id uniqueness, and legacy six-field projection equality without promotion.

The new focused negative is internally self-consistent: `_g3_declaration(candidate=foreign_candidate)` builds the foreign declaration, foreign G1/G2 upstream records, and matching target projections. The test expects `fail_closed`, `:declaration_candidate_mismatch`, no output, and unchanged prior bundle bytes/SHA. The final R6 receipt reports the expanded candidate/authority set as 17/17 and the full focused result as 68/68. Legacy `actual` remains typed absent/terminal deferred; stale, contradictory, and unknown statuses remain fail closed. Synthetic/ref-only/fixture/incomplete fresh records remain rejected, and failure byte stability is retained.

## Seven-file hash audit

Six artifact records match their current bytes. The fixture record is invalid and is the acceptance blocker:

| path | actual bytes | actual SHA-256 | manifest record | result |
|---|---:|---|---|---|
| `src/GenomeV5/Integration/VNextDeclarationAuthorityRecheckV1.jl` | 14684 | `e942e3553b1a5f78eea719a57c8475f5cb72bf81df8f69df7955471fd985f061` | same | pass |
| `test/GenomeV5/Integration/vnext_declaration_authority_recheck_v1_tests.jl` | 11153 | `6e42e5ccc85f22589fdcbdc9a408f902c230bbd8c098c146eb8a7e13ed472aca` | same | pass |
| `test/GenomeV5/Integration/vnext_declaration_authority_recheck_v1_fixture.json` | 1953 | `cdf9095c15dd082c5c374b03742575301087906962617023090ae6b0db4deb59` | `cdf9095c15dd082c5c374b03742575301087906962617023090ae6b0db4deb59f` | **fail: 65-character/nonmatching digest** |
| `test/GenomeV5/Integration/static_qa_vnext_declaration_authority_recheck_v1.py` | 1998 | `e25c6435392b594f9a82937f8b07b034524f191921bdf02700e7de36bda09220` | same | pass |
| `docs/implementation/UP1-04A-VNEXT-T0-AUTHORITY-RECHECK-PREC/README.md` | 2579 | `6bc4e8ffb56787745bfc4368e7e9b3af7958906c8fcd00aeb42cbb7e16194e0e` | same | pass |
| `docs/implementation/UP1-04A-VNEXT-T0-AUTHORITY-RECHECK-PREC/acceptance.md` | 2112 | `be294fdaed57fa335a9918d3a5c3b04edb3aa743fa003f604328b36afa01cdd8` | same | pass |
| `docs/implementation/UP1-04A-VNEXT-T0-AUTHORITY-RECHECK-PREC/manifest.json` | 18960 | `37b5189e5cb5b47aae13805c8267486760ecd38d49adc11bfb073faaf3b76bb2` | self record excluded | observed |

The fixture bytes and source/test behavior are unchanged from the prior accepted artifact identity, but the current manifest record must be corrected to the actual 64-character SHA before acceptance.

## R6 receipt audit

The R6 archive contains proposal, static receipt, focused receipt, four raw output files, and cleanup inventory. All referenced files exist and all recorded raw hashes and byte counts recompute exactly:

- Static QA: direct Python path `D:\Users\Newman\anaconda3\python.exe`, Python 3.13.5, executable SHA `388fe2cffda8a134e7d7dc4e978f7c478857ece6b69694daecbed25e51ec633a`; PID 67876; UTC `2026-09-15T05:35:39.9416656Z` to `2026-09-15T05:35:40.0907133Z`; exit 0; 20 checks; stdout 34 bytes/SHA `b8e203558bf893cb23e7f83646f35f168c320ce0e826f45606a9871ebdc1f4eb`; stderr 0 bytes/SHA `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`; input SHA `9606d6a5e91d3f2c267b0ee597c83712ab6cad5e10bf7d11af503402fa9b2163`.
- Focused Julia: direct executable `C:\Users\Newman\AppData\Local\Programs\Julia-1.10.5\bin\julia.exe`, Julia 1.10.5, executable SHA `8e86e2d48c574393c37bbfb6e922ea4176ba8e1a83f956826f3da24948e389ad`; PID 70316; UTC `2026-09-15T05:36:05.1262521Z` to `2026-09-15T05:36:10.6882588Z`; exit 0; 68/68; stdout 975 bytes/SHA `e1016ca0503632bde7d44620c275b71d2bca9e6f3c1639f7dc113f0bd7c5dcbd`; stderr 0 bytes/SHA `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`; input SHA `aeae0aea0d2aeba7a211315d9bcaa38ceab1224440e3ca343cc840b6531b2d94`.
- Both receipts record dirty rows `317 -> 317`, empty process-before/after, and the cleanup receipt records final Julia/DESC process counts `0/0`.

The R6 raw receipts are materially stronger than the prior embedded-only history: the four raw files are present and byte/hash exact. The prior R1-R5 failed attempts remain append-only in the implementation manifest and were not overwritten.

## Governance and cleanup cross-check

AD-34 acceptance, status sync R1, and independent architecture R5 still describe this node as planned/proposal/review_pending/accepted=false and typed-absent only. The R6 repair manifest retains machine `accepted=false` and all binding, feedback, control, T0, T1, T2, provider, mesh, engineering, physical, B00, B04, and R01-R10 flags false. Cleanup has no task-owned scratch/cache paths or removed paths and explicitly protects pre-existing dirty rows, historical receipts, and remote/unrelated Julia/DESC processes.

## Required disposition

Correct only the fixture SHA field in the implementation manifest to the actual 64-character digest, preserve R1-R5 and R6 raw history, and provide the corrected manifest hash for the next independent review. Keep the node `planned` / `proposal` / `review_pending` / `accepted=false`; no implementation or machine acceptance follows from the 68/68 observation. Until the manifest correction is independently checked, this review is `changes_requested`.
