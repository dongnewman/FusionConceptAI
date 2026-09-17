# UP1 External Blocker Closure R2 — independent external-facts review R2

Verdict: `pass_limited`.

The two prior review observations are closed: the environment dirty-patch
receipt now hashes exact raw bytes with `normalization=none`, and the AD-56
locator is an exact file with bytes/SHA while remaining
`bookkeeping_only_not_authority`. No P1/P2 finding remains and no false
authority admission was found.

## Scope and independent verification

This was a read-only review of `09-local-discovery`, `10-environment-capture`,
`11-source-capture`, and `12-system-trust-inventory`. Only this review
directory was written. Fresh `python -B` checks used in-memory JSON/path/hash
validation; no network, AD/S3, installation, store mutation, credential or
private-key access was performed.

- 09 has 26/26 unique crosswalk rows, all `typed_absent` with production
  usable count 0. The 5468 scan records are all `nonusable`; no content was
  emitted and no sensitive path was opened. `new_real_inputs=[]`,
  `changed_inputs=false`, `no_new_ad=true`, and `no_s3_rerun=true` hold.
- 10 exact-set and artifact hashes pass. All four binary hashes and all four
  lock-file hashes match independently. The dirty patch is
  `3665717b31dbd8224f29185a86446997c9c500ef406df0e4288fd57a4e60ecc1`; the
  cached diff is separately empty SHA-256
  `e3b0c44298fc1c149af4c8996fb92427ae41e4649b934ca495991b7852b855`; the
  normalized digest is null and normalization is `none`.
- 11 HEAD/tree and all six source working hashes pass. The corrected AD-56
  file locator and all 12 related declaration/factory files match recorded
  bytes/SHA. AD-56 remains bookkeeping-only; no issuer, signature, trusted
  time, G2 mapping, candidate identity or receipt is inferred.
- 12 accounts for 301 unique certificates and 590 store entries, with
  `candidate_count=0` and `decision=all_nonusable`. Missing project policy,
  OID/EKU, name constraints, pinned root, authorized scope, signed receipt
  and chain remain typed absent. Windows system roots and generic user
  certificates are not project authority.

## Disposition

The external trust-root/source-closure blocker remains open. Local hashes,
Authenticode, Windows store membership, AD command help, and bookkeeping
locators do not satisfy project authority. No UP1, provider, mesh, solver,
engineering, physical, B00/B04, or R01–R10 credit is claimed.

Fresh output and hash evidence are in `raw/`; machine-readable results are in
`findings.json` and `verification_receipt.json`.
