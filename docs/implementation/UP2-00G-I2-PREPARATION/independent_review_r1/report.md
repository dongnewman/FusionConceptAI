# G-I2 / B04 entry audit R1 independent review

Verdict: `changes_requested`; `ready_for_focused=false`; `accepted=false`; `status=review_pending`.

This is a read-only static review of `docs/implementation/UP2-00G-I2-PREPARATION/entry_audit_r1/`. No Julia or DESC was started. The review does not grant B00, B04, provider, mesh, engineering, physical, or R01–R10 credit.

## What is substantively correct

The audit correctly separates the frozen B00 F0–F5 gate from the ten-class B04 mutation suite. `up0_02_protocol.json:86-92` and `19_up0_02_contract_freeze.md:44-57` require complete candidate-bound inputs, independent canonical/replay receipts, label-erasure checks, route/compatibility checks, and a closed evidence envelope. `19_up0_02_contract_freeze.md:59-76` also says the N01–N10 five-row templates are illustrative until typed paths, checkers, and receipts are frozen. The audit's requirement for five fresh rows per class (50 total), stable source accessors, mutation values, counters, and candidate/package identity is therefore aligned with the contract.

The audit also correctly requires a checker independent from the exporter expected-row helper. The current N05 checker at `test/GenomeV5/UP2/n05_flux_receipt_checker.jl:97-118` constructs trusted expected rows through `_n05e_row`, while the exporter defines that helper at `test/GenomeV5/UP2/n05_flux_receipt_exporter.jl:36-63`; the checker therefore cannot be evidence for the future independent 50-row gate. The one-argument checker path is envelope self-consistency only. The audit's two fresh processes, disjoint output directories, equal frozen input hashes, distinct attempt receipts, and canonical field-by-field comparison are also the correct replay boundary.

Its dependency reading is accurate: G-I1A remains `review_pending`/`accepted=false`; G-I1B R2 is a source inventory pass_limited and does not provide receipts; UP1-04A is limited to additive structural entry/join; and no current artifact closes B00 F0–F5 or a formal UP1-04B gate. The matrix is not a receipt archive.

## Changes requested

The author's own `entry_audit_r1/evidence_manifest.json` is not reproducible as written. Rechecking every listed input found these four defects:

1. `docs/implementation/UP2-00G-I1A-AUTHORITY-CONTEXT/evidence_manifest.json` is recorded as `F1BA10B4E5192C2F58D95F2E54BE397424F8E0DB3E33441C8EB11F0563F8F5B`, but the current 5545-byte file hashes to `F1BA10B4E5192C2F58D95F2E54BE397424F8E0DB3E33441C8EB11F0563F8F5FB`.
2. `test/GenomeV5/UP2/run_n05_flux_receipt_export.jl` is recorded as `E6C122CE7A0CA410A243C1F2D790FD0D9F0B0DBABB00BEC7D092E7E3FCD9EC`, but the current 577-byte file hashes to `E6C122CE7A0CA410A243C1F2D790FD0D9F0B0DBABB00BECDC7D092E7E3FCD9EC`.
3. `docs/implementation/UP1-04/independent_r12/acceptance.md` does not exist. The existing frozen path is `docs/implementation/UP1-04/independent_review_r12/acceptance.md`, 3840 bytes, SHA256 `08D35ED3C64F3E087279EE7A1110ADD5C44BA504D9A614C4EA86D206C0646C9F`.
4. `docs/implementation/UP1-04/independent_r12/manifest.json` does not exist. The existing frozen path is `docs/implementation/UP1-04/independent_review_r12/evidence_manifest.json`, 4775 bytes, SHA256 `2F584705C46A3066469D8C2F78525B0D8F4379A50D8FA0D444CAC24672C00692`.

These are archive/provenance blockers in the G-I2 audit, not reasons to lower the B00/B04 contract. The author must repair its manifest using the exact current paths and hashes, then rerun its own JSON, control, plan, and diff checks. The substantive conclusion should remain that fresh 50-row receipts, an independent checker, two-process replay, and B00 F0–F5 evidence are absent. A runner exit zero or the existing N05 5+5 local slice cannot open UP1-04B.

## Evidence boundary

The checked repository was HEAD `4b69f55f7f80240147a65a22809dc1207824dde2`; the audit's recorded dirty status digest was preserved for comparison. At the review preflight there were zero `julia` and zero `desc` processes. This review performed JSON/hash/text/static checks only. Until the four manifest defects are repaired and independently reviewed, the G-I2 audit remains `changes_requested` and no focused B04 run is authorized.

