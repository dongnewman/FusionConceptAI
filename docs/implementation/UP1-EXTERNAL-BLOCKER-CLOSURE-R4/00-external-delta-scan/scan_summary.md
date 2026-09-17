# UP1 external delta scan R4

## Decision

Within the checked roots and relative paths listed below, the read-only R4
scan at `2026-09-17T01:20:56Z` observed no fresh external response material
relative to the R2/R3 frozen state. This is a bounded observation at that
timestamp, not a claim that every remote, unlisted, or not-yet-known channel
is globally empty. All 26 external absence IDs remain
`typed_absent`; no candidate is usable or `typed_unverified` for promotion.
The disposition is therefore `terminal_deferred -> no_publish`, with
`new_ad=false` and `s3_rerun=false`.

## Frozen checkout and dirty snapshot

- Repository: `D:\006-Programing\LMC\FusionConceptAI`
- HEAD: `b2c04d8339774635aaecd73651efcdb101e01b5d` (same as R3)
- R3 status snapshot: 378 lines, SHA-256
  `0b8c82f42aafa1fedc5c6e3563b8dcce024382ea5ddc4ec42be85b32bf715e78`
- R4 status snapshot: 382 lines, SHA-256
  `cbfe327afe0506327cbf0023179f8b05b9c9cc3675ef368dfc4656d0e7080689`

The four-line porcelain drift is dirty-worktree concurrency, not an external
input delta. All nine R2 frozen project inputs match both their raw SHA-256
and Git blob OID (`changed_count=0`); see `raw/frozen_input_scan.raw.json`.

## External locations and status

The scan scope was exactly these two roots:

- `D:/006-Programing/LMC`
- `D:/006-Programing/LMC/FusionConceptAI`

At each root, only these seven relative paths were checked:
`local_spool`, `local_spool/incoming`, `response`, `anchors`, `local_receipts`,
`incoming` and `intake`. All 14 root/path combinations are absent with zero
files. Paths outside this frozen list and remote channels were not queried and
remain outside the absence claim. Consequently, within this scope, every
expected certificate/trust-root, four-axis, G2, authority-channel, attestation,
and candidate-bound environment path has
`bytes=null`, `sha256=null`, and `status=typed_absent`; the detailed owner and
recovery condition are in `external_material_inventory.json`.

Local historical contracts, TEST_ONLY fixtures, prior receipts, and the R3
local environment inventory were not promoted as external material. They are
bookkeeping or local-observed evidence only.

## Trust and environment observations

The six R2/R3 certificate stores were enumerated read-only: 590 current store
entries and 301 unique thumbprints. The current unique set exactly equals the
R2 public certificate metadata set (`added_thumbprints=[]`,
`removed_thumbprints=[]`). No certificate bytes or private keys were read or
exported. A Windows/user certificate is not a project trust root without a
fresh external anchor and policy receipt; `project_trust_root=typed_absent`.

The four runtime/binary paths and four Julia/Gridap dependency declarations
from the R3 environment inventory all match their prior bytes and SHA-256
(`changed_count=0`). This is local-observed only: candidate-bound environment
closure, publisher signatures, SBOM/license provenance, and Python lock/channel
freeze remain absent.

## Controls and recovery

No network request, intake, source/test edit, certificate-store mutation,
Julia, DESC, solver or S3 run occurred. No AD is warranted and no S3 rerun is
authorized while the frozen inputs and external absence state are unchanged.
The only recovery trigger is a real external owner/channel supplying a fresh,
complete, candidate-bound and independently verifiable response bundle; then
rebuild identities and perform exactly one fresh authority recheck.
