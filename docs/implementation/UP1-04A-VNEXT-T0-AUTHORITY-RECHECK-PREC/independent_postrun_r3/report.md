# UP1-04A-VNEXT-T0-AUTHORITY-RECHECK-PREC independent postrun R3

Date: 2026-09-15  
Reviewer: independent Luna/high (`/root/g2_metric_boundary_v1_author`)  
Decision: `pass_limited`  
Review mode: read-only evidence and static semantic audit; Julia/DESC were not run in this review.

## R7 correction and current seven-file identity

Repair R7 corrected only the extra trailing `f` in the main implementation manifest's fixture digest. The current fixture SHA is exactly 64 hexadecimal characters and now matches the current fixture bytes:

`cdf9095c15dd082c5c374b03742575301087906962617023090ae6b0db4deb59`

All seven current files exist and every artifact record matches current bytes. The current implementation manifest SHA is `d17bc5794678142776f9c2693a1fb696f0ebf85c7a433c07c598154003c5c159` (18,959 bytes); it is treated as the self-excluded manifest identity. R7 before/after evidence shows source, test, fixture, static QA, README, and acceptance bytes unchanged, with only the main manifest digest field corrected and the two R7 archive files added.

The machine node remains `planned` / `proposal` / `review_pending`, `accepted=false`, `launcher=false`, and `claim_ceiling=contract_only`. AD-34 remains an architecture/work-order boundary. This review grants no T0 authority, T1/T2, provider, mesh, engineering, physical, B00/B04, or R01-R10 credit.

## R6 execution evidence and R2 findings

The R6 archive remains intact. Static QA is the direct Python executable `D:\Users\Newman\anaconda3\python.exe`, Python 3.13.5, executable SHA `388fe2cffda8a134e7d7dc4e978f7c478857ece6b69694daecbed25e51ec633a`, PID 67876, exit 0, 20 checks, input SHA `9606d6a5e91d3f2c267b0ee597c83712ab6cad5e10bf7d11af503402fa9b2163`. Its stdout is 34 bytes with SHA `b8e203558bf893cb23e7f83646f35f168c320ce0e826f45606a9871ebdc1f4eb`; stderr is empty with SHA `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.

The focused Julia receipt remains direct Julia 1.10.5 at `C:\Users\Newman\AppData\Local\Programs\Julia-1.10.5\bin\julia.exe`, executable SHA `8e86e2d48c574393c37bbfb6e922ea4176ba8e1a83f956826f3da24948e389ad`, PID 70316, exit 0, 68/68, input SHA `aeae0aea0d2aeba7a211315d9bcaa38ceab1224440e3ca343cc840b6531b2d94`. Its raw stdout is 975 bytes with SHA `e1016ca0503632bde7d44620c275b71d2bca9e6f3c1639f7dc113f0bd7c5dcbd`; stderr is empty with SHA `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`. Both raw streams were rehashed from the archived files and match their receipts exactly.

R6 records dirty rows `317 -> 317`, empty process-before/after, and cleanup final Julia/DESC process counts `0/0`; no current Julia/DESC process was present during this review. R1-R5 failed history remains in the append-only main manifest and was not rewritten. R7 reports no execution, no cleanup deletion, and preservation of all source/test/fixture/static/raw/core/T0/T1 files.

## Semantic and governance checks

The R6 candidate repair remains present in both the public entrypoint and `_vnext_ar_pair`. The foreign declaration negative uses a foreign candidate with matching foreign upstream and target records, and expects deterministic fail-closed with no output and unchanged T0 bytes/SHA. Exactly-one G1/G2 pairing, all upstream and target candidate checks, target-key and target-id duplicate guards, legacy six-field non-promotion, status mapping, typed-absent `actual`, absence digests, synthetic/ref-only/fixture rejection, and failure byte atomicity remain unchanged from the R2-passing audit.

The current AD-34 acceptance, status sync, and independent architecture R5 still keep this node planned/proposal/review_pending/accepted=false and typed-absent only. R6 machine and credit fields remain false. The dependency remains only `UP1-04A-VNEXT-T0`; T1 remains gated on T0 plus this future recheck. No launcher, shared-entry, core, T0/T1, old receipt, or unrelated file was changed.

## Ruling

`pass_limited` is granted only for the local typed-absent software scaffold and its contract/evidence boundary after the R7 digest correction. This does not create machine acceptance, checked-present authority, T0/T1/T2 readiness, or any actual/physical/provider/mesh/engineering/search/B00/B04/R01-R10 credit. Keep `review_pending=true` and `accepted=false` for the machine node and implementation acceptance records.
