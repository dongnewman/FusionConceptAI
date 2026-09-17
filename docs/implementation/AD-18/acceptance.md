# AD-18 acceptance record

- task: `AD-18`
- status: `accepted`
- accepted: `true`
- accepted_scope: `current_state_ad18_architecture_boundary_and_before_after_bounded_diff_provenance`
- base HEAD: `4b69f55f7f80240147a65a22809dc1207824dde2`
- owner: `gpt-5.6-luna/high` (documentation maintenance)
- independent reviewer: different Luna, `pass`
- Sol decision: independent review passed; accept only the architecture boundary and the before/after snapshot plus bounded-diff provenance. This does not accept G3 implementation or UP1-04.

## Frozen decision scope

The G3 standalone admission path may check only `feedback.target_contract_ref` target-layer namespace, the `v5` contract revision token, and the basic shape of the public `GenomeContractRef`. A wrong layer, wrong version, missing required shape, or malformed ref is fail-closed. Fixture seeds and synthetic `/feedback-target` refs are structural inputs and never authority.

When same-candidate actual outer G1/G2 public refs are absent, the standalone result must carry an independent `feedback_authority_gap` with `resolution=terminal_deferred`. A provider gap remains an independent status. UP1-04 owns the integrated join: it must exact-compare URI, version, schema, canonical and profile for the full ref, the four version axes, and candidate binding, then rebuild candidate identity; any mismatch is fail-closed.

This is a document-only architecture decision. The accepted scope is limited to the current AD-18 boundary semantics and the recorded before/after snapshots and bounded diff provenance. It does not accept G3 implementation, UP1-04 integration, provider capability, B00, B04, engineering, mesh, physical, or R01–R10 evidence. It does not change AD-17, UP0-02, G1/G2/G3 implementation status, the DAG, or existing evidence.

## Before/after provenance

The three core files were copied byte-for-byte into [`before/`](before/) before modification. The after copies are in [`after/`](after/), and the bounded textual diff is [`ad18_bounded_diff.patch`](ad18_bounded_diff.patch). Hashes and seven-digit local `+08:00` mtimes are recorded in [`evidence_manifest.json`](evidence_manifest.json). The before snapshots make the exact changed scope auditable; no historical evidence was rewritten.

| file | before SHA256 | before mtime (+08:00) | after SHA256 | after mtime (+08:00) |
|---|---|---|---|---|
| `18_sources_and_architecture_decisions.md` | `86aaefe5a8d56eaea0f8b77d7407f5962957916ad741a809aa4c64c9d34b8d1f` | `2026-09-14T04:32:40.4106356+08:00` | `c910cf900011693fc9d7d01d4bf5f6b4f916d93a02c7b996bdb1e73078003a86` | `2026-09-14T04:56:52.7159184+08:00` |
| `16_execution_work_orders.md` | `7c69453f5258cbe428b3ba68de1f334c76c549a9dd270547b82adb218fb01899` | `2026-09-14T04:33:01.4452342+08:00` | `0d01f2711af5c7351fdade0ce72b44946409b06b943d01b41ef1c7178ef209d2` | `2026-09-14T04:56:52.7159184+08:00` |
| `README.md` | `80eb6e54f06b97df3b0c81438e91cab2deba5ca5a87017cd960b6490130ed66c` | `2026-09-14T04:33:49.3354326+08:00` | `fff8c68c08bd2c4bc65530ca2e01649e8120759b65a754b0ed284d2458ee6d69` | `2026-09-14T04:56:52.7169106+08:00` |

Validation commands and exits are recorded in the manifest. Independent review result is `pass` for the limited scope above. No Julia/DESC or physical execution was run for AD-18.
