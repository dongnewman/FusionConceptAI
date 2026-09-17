# AD-41 independent review R1 — UP1 remaining gate audit

Date: 2026-09-15  
Reviewer: different Luna/high, read-only static and scheduling review  
Repository: `D:\006-Programing\LMC\FusionConceptAI`  
Observed HEAD: `4b69f55f7f80240147a65a22809dc1207824dde2`

## Decision

`changes_requested`. The audit is otherwise within its declared architecture-only
ceiling: it does not modify core planning files, the task manifest, source, tests,
fixtures, candidates, or historical receipts; it records no provider, mesh, solver,
physical, engineering, or R01–R10 credit. The requested change is narrow and
concerns live scheduling accuracy.

AD-40 has already produced `docs/implementation/AD-40/repository_design_source_authority_architecture/repair_r1/`.
That repair contains the missing stdout/stderr/combined hashes, frozen input and
output hashes, PID/UTC/exit, and scoped rechecks. Its manifest remains
`status=review_pending`, `accepted=false`, pending a different-Luna review. The
AD-41 report still describes W1 as “close the AD-40 receipt defect” and proposes
creating `repair_r2` for that defect. This is stale after repair R1 and would cause
duplicate repair work. W1 must be rewritten as an independent review/acceptance
of AD-40 repair R1, with a new repair round only if that review finds a concrete
defect. The current report should also cite the repair R1 record while preserving
the conclusion that AD-40 cannot yet authorize RSDA products.

## Checks that passed

The current 39-task manifest parsed successfully. A fresh Kahn traversal processed
all 39 nodes with no missing dependency and no cycle. The formal shortest chain is
consistent with the manifest: accepted UP1-01/02/03 feed the three G1/G2/G3
preparation nodes and UP1-04A; those four inputs feed T0; T0 and the authority
recheck feed T1; then T2, the VNEXT aggregate, UP2-00, UP1-04B, and UP1-04.
The parent-baseline, G3 realization, G3 control, and G3 binding slices remain
parallel typed-absence/software preparation and are not hidden T0/T1/T2
dependencies.

The live task states support the audit's ceilings. G1/G2 V1 nodes are
`planned/proposal/accepted=false`; the parent baseline and G3 edit nodes are
machine `planned/proposal/accepted=false` even where local records are
`accepted_limited`; T0, T1, T2, the aggregate, UP1-04B, and UP1-04 remain
unaccepted. UP2-00 retains only its actual-A N01/N02 limited projection. AD-40
repair R1 is the only relevant current state omitted from the proposed W1 wording;
its claims remain false and it creates no machine node.

Direct source inspection agrees with the authority boundary. G1 and G2 files
contain typed declaration/schema/factory definitions and explicit missing-authority
or terminal-deferred branches. The parent binding source contains an absent branch
and rejects source-backed admission when the receipt is unavailable. The authority
recheck source emits typed-absent/terminal-deferred records. These are software
contracts and absence behavior, not candidate-bound source authority or physical
evidence. The four frozen AD-40 source artifact hashes match their current bytes.

The existing AD-41 product and R2 validation sidecar hashes match its manifest.
JSON parsing, control-character, path-scope, current-plan validation, source-hash,
and future-output path checks passed. The two absent AD-40 future paths observed in
the report are declared future products and are therefore allowed to be absent.
All four proposed AD-41 work orders contain the required basic fields, preserve
`candidate_hash_created=false`, and do not add machine nodes or forbidden execution
edges. No Julia, DESC, provider, mesh, solver, or physical command was run by this
review.

## Required repair

Update only the AD-41 audit products in the author-owned directory:

1. cite AD-40 `repair_r1/report.md` and `repair_r1/manifest.json` as the current
   receipt-closure input;
2. change AD41-W1's output and exit gate to a different-Luna review of repair R1
   and acceptance decision, retaining append-only repair R2 only as a conditional
   follow-up if the review identifies a defect;
3. preserve all existing false claim flags, the four-stage AD-41 dependency order,
   and the prohibition on T0/T1/T2, candidate hashes, provider, mesh, solver, and
   physical execution.

After this wording repair, a fresh independent review can decide whether AD-41 is
`pass_limited` as a scheduling audit. Until then, AD-41 remains review-pending and
does not dispatch or unlock any machine task.

## Evidence boundary and cleanup

This review is static scheduling/source inspection only. No process was terminated;
the worktree was already dirty and unrelated changes were preserved. No task-owned
temporary file required removal. Raw stdout, stderr, and the machine-readable
receipt for this review are append-only sidecars under this review directory.
