# AD49-F0 G1/G2 source-authority factories

Scope: additive source-stage typed factories and focused tests only. The
current repository locator for each declaration is untracked, so a real
repository call returns `typed_absent`/`terminal_deferred`. Present-path tests
use an isolated temporary git repository with a real tracked HEAD closure and
are explicitly `synthetic_test_only`; they provide no authority credit.

Both factories require the exact AD45 `QualifiedRefV1/v5` common handle and
9612-byte envelope SHA-256
`17901aa6e1be326b95e56fbbbd5148bd02b7c3ea43bd0c451336cd297e2950dc`, the exact
public five-field layer `GenomeContractRef`, typed four-axis contract, typed
source payload, and a typed wrapper around the real declaration constructor.
They verify current repository HEAD, tracked path, clean status, current byte
length/SHA-256, and committed path existence before construction. G1 preserves
its declaration's `QualifiedRefV1` candidate field while separately storing the
public contract. G2 preserves `GenomeContractRef` in both source and
declaration. Each Present result embeds a source-stage binding with the
temporary-handle role, and hashes binding, provenance, source content and
local declaration into replayable result/receipt records. No registry, old
declaration schema, module entrypoint, mapping, CandidateIdentity or final hash
is changed or created.

Validation was serialized because Julia is a shared heavy lane:

| check | result | Julia PID | UTC | exit |
|---|---:|---:|---|---:|
| G1 focused | 26/26 | 81992 | 2026-09-15T16:19:27.9897329Z–2026-09-15T16:19:37.7685593Z | 0 |
| G2 focused | 26/26 | 95196 | 2026-09-15T16:19:58.9039658Z–2026-09-15T16:20:08.7958895Z | 0 |
| existing G1 V2 regression | 47/47 + 21/21 | 59409 | 2026-09-15 (serial run) | 0 |
| existing G2 V5 regression | 57/57 + 59/59 + 8/8 | 40910 | 2026-09-15 (serial run) | 0 |

Focused raw streams are retained under `raw/`. These tests are software
contract checks only; source authority, trusted attestation, mapping,
provider, mesh, solver, engineering, physics, search and R01–R10 remain
closed.

The Python scoped probe is recorded in `raw/python_static_validation.json`; it
found all four owned products, unchanged protected source/registry hashes and
no forbidden symbols. A fresh independent S2 review is required before any
downstream AD49 edge.
