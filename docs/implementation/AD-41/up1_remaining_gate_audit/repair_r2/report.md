# AD-41 UP1 remaining gate audit — repair R2

Date: 2026-09-15  
Repair round: `repair_r2`  
Scope: current-state synchronization of the main AD-41 audit products only  
Independent finding: `docs/implementation/AD-41/up1_remaining_gate_audit/independent_review_r2/report.md`

## Applied correction

The independent R2 review found that the main AD-41 report still contained
the pre-repair W1 wording even though `repair_r1/revised_report.md` had already
corrected it. This repair makes the main products self-consistent.

The main report now explicitly marks its original text as superseded by
`repair_r1/revised_report.md` and this repair. Its W1 now reads as an
independent different-Luna review of AD-40 `repair_r1` followed by an explicit
Sol acceptance or rejection decision. AD-40 `repair_r2` is an append-only,
conditional follow-up only when that review identifies a concrete new defect.

The main manifest now points to this repair, records the pre-repair bytes and
SHA-256 values, and synchronizes its current W1 stage. W2, W3 and W4 remain
the same finite sequence and keep their original dependencies and forbidden
edges. The 39-task DAG is unchanged.

## Preserved boundary

AD-40 `repair_r1` remains `review_pending`/`accepted=false` until a different
Luna reviews it and Sol decides. This repair does not accept AD-40, publish
G1/G2 source authority, create a candidate hash, create a machine node, or
unlock T0/T1/T2. G1/G2 authority remains absent; present, provider, mesh,
solver, engineering, physical and R01–R10 remain false; L4 credible count
remains zero. The local typed-absence and software precursor records retain
their prior ceilings.

## Main product before/after receipt

| product | before repair R2 | after repair R2 |
|---|---|---|
| `report.md` | 12,587 bytes; SHA256 `77ea4ec9e8bf04e6ed2a6ea73dc5ecdf959f0325a5418037745dc2ab25d7521d` | 12,938 bytes; SHA256 `0e46aea26abe471ba936ab1b70a92074a1078783b1a8abc801516f6eacee37cb` |
| `manifest.json` | 4,014 bytes; SHA256 `ac7d9322f0b70aec4c07b2d543c5af051ad36e1053c15b93af3ffa2f89a3731b` | recorded in the repair manifest after current synchronization; self hash excluded |

The old products, R1 repair, R1/R2 independent reviews, failed attempts and
all historical raw receipts remain append-only. No source, test, core plan,
task manifest, run artifact or unrelated dirty file was modified. No Julia,
DESC, provider, mesh, solver or physical command was run.
