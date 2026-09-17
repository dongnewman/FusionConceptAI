# AD-36 mandatory evidence sidecar scope amendment - independent review R3

Date: 2026-09-15
Verdict: pass_limited
Reviewer: different Luna/high
Review mode: read-only; no reviewed target was modified

## Scope and result

This review covered the v4 README, normative state contract, orchestration rules, execution work orders, architecture decisions, implementation index, 39-task manifest, AD-34 and AD-35 acceptance/manifest records, and every AD-36 acceptance, repair, status-sync and prior independent-review record, including the status-sync R2 raw receipts. The only new files are this report, its manifest and the raw runtime receipt in this directory.

The AD-36 contract is internally consistent. exact_file_count is explicitly limited to product/contract deliverables. The two affected AD-34 work orders enumerate exactly six and seven product/contract files respectively in the work-order and task-manifest records. Their task-owned archive/review/status directories are append-only evidence sidecars and are excluded from those counts. The sidecar policy is evidence-only and includes the six forbidden payload classes: product/contract deliverable, source, test, fixture, staticQA and launcher. The policy is fail-closed on scope_violation, preserves the evidence of the violation, forbids temporary launchers and requires direct commands.

The current AD-36 status-sync R2 directory contains 16 individually listed evidence paths. None has a source, test, fixture, static-QA or launcher-like product filename. The R1 status round, repair R1, independent reviews R1/R2, and all three superseded policy-check attempts remain present and append-only. The root decision remains review_pending/accepted=false; no AD-36 mainline task is created.

## Independent validation

The frozen input hashes in status-sync R2 (16 paths), all four R2 validation command stdout/stderr/combined hashes, all 16 cleanup inventory path hashes and byte counts, and the three superseded attempt raw hashes were recomputed and matched. The status-sync manifest remains self-hash-excluded with its explicit rule; no recursive self hash is treated as a product hash.

The fresh plan validation exited 0 and reported 31 markdown files, 466 relative links, 39 tasks, an acyclic DAG and no errors. Exact-path diff checking in the R2 receipt exited 0; its only stderr is the recorded README LF-to-CRLF warning. The independent runtime receipt is preserved in review_runtime.stdout with PID/in-process identity, UTC interval, exit and recomputed result.

The reviewed records contain no future candidate hash or physical result being promoted by this amendment. The plan and receipts continue to keep provider, mesh, engineering, physical, search, B00, B04 and R01-R10 credit false; runner exit and documentation validation are not used as physical evidence.

## Acceptance ceiling

pass_limited accepts only the static contract and evidence-boundary review. It grants no implementation, binding, feedback, T0/T1/T2, provider, mesh, engineering, physical or search credit, and no B00, B04 or R01-R10 credit. AD-34 binding and authority-recheck machine nodes remain planned/proposal/accepted=false/review_pending; current authority remains typed absent/deferred.

Cleanup for this review was limited to retaining the three files owned by this review. No scratch, cache, debug, unrelated code, launcher or historical evidence was removed; no ambiguous cleanup was deferred.
