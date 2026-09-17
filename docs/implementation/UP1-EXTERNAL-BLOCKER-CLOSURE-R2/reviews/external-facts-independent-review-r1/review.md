# UP1 External Blocker Closure R2 — independent external-facts review R1

Verdict: `rework` (limited to the environment dirty-patch receipt; no false authority admission found).

## Scope and boundary

This review is read-only over `09-local-discovery`, `10-environment-capture`,
`11-source-capture`, and `12-system-trust-inventory`. Only this review directory
was written. No network, AD/S3 attempt, installation, store mutation, secret
access, private-key access, or source/test/registry modification was performed.

## Independent results

- `09-local-discovery`: 26/26 crosswalk rows; all rows remain `typed_absent` with production-usable count 0. The scan has 5468 metadata/hash records, all `nonusable`, with no content emitted and no sensitive path opened. `new_real_inputs=[]`, `changed_inputs=false`, `no_new_ad=true`, and `no_s3_rerun=true` are consistent.
- `10-environment-capture`: all four listed binaries and all four lock files independently match recorded bytes and SHA-256. Candidate and authority references remain absent; package/import/artifact closure remains unbound. The local observation and Authenticode fields are explicitly observation-only.
- `11-source-capture`: fresh HEAD and HEAD tree equal the recorded values; all six source working-tree hashes match. G3 realization/control are correctly marked dirty; source objects remain repository design source only. The AD-42/AD-45/AD-56 records are explicitly authoring, temporary-handle, or bookkeeping-only.
- `12-system-trust-inventory`: 301 unique public certificate metadata records and 590 store entries are accounted for; candidate count is 0 and decision is `all_nonusable`. The project policy, OID/EKU, name constraints, pinned root, authorized scope, signed receipt, and chain are absent. System roots and generic user certificates are not promoted.

## Findings

### F1 — environment dirty-patch digest is not bound to its raw receipt (P1)

`10-environment-capture/machine_observation.json` and its manifest record
`e6b42d07d326be263a19509faddeece612f0e42495b8980de0e55f60f282fb99`, while
the SHA-256 of `raw/git_diff_binary.stdout.raw` (and the fresh `git diff
--binary` output, with an empty cached diff) is
`3665717b31dbd8224f29185a86446997c9c500ef406df0e4288fd57a4e60ecc1`.
The 11-source snapshot independently records the latter value. This is a
receipt-integrity defect, not an authority promotion: HEAD/tree and source
hashes remain reproducible and no candidate is admitted. Repair 10 by defining
the digest over exact raw bytes (or explicitly documenting a canonical text
normalization and recording both raw and normalized digests), then regenerate
its dependent receipt hashes.

### F2 — AD-56 axis path is a directory locator (P2 observation)

The 11-source `axis_material_candidates` entry `MAT-AD56-BOOKKEEPING` points
to `.../independent_review_r1/`, not a file and therefore has no bytes/SHA.
It is labeled `bookkeeping_only_not_authority`, and the crosswalk decision
remains non-authoritative, so this is not a false-admission finding. Future
crosswalks should represent the directory as a locator or enumerate exact
files to avoid treating it as material.

## Authority and missing-input conclusion

No usable external issuer, trust root, certificate chain, signed attestation,
trusted time/revocation receipt, authoritative G2 mapping, candidate-bound
four-axis issuance, binary/SBOM provenance, or channel receipt was found.
The 12 public-material hits are CA bundles; the 301 Windows-store certificates
are not project authority. The external blocker remains open and no UP1,
provider, mesh, solver, engineering, physical, B00/B04, or R01–R10 credit is
claimed.

Fresh command/hash evidence is in `raw/`; the machine-readable decision is in
`findings.json` and `verification_receipt.json`.
