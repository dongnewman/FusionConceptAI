# UP1 external blocker closure R2 — environment and provenance

This package is an offline validator using the already-installed
`cryptography` Ed25519 verifier. It performs no installation and no download.
It separates three evidence classes:

* `local_observation` records what this host reports (OS, architecture,
  runtime paths and byte hashes); it is not an authority statement.
* `reproducible_declaration` binds a candidate to Julia/Python runtimes,
  `Project.toml` + `Manifest.toml`, binary hashes, recipe hashes and SBOM
  document hashes.
* `authority_proof` is a real signed-receipt plus outer-envelope chain. Both
  signatures are verified over canonical JSON and bind algorithm, key ID,
  issuer, trust root, profile, candidate and declaration hashes. Without the
  project anchor or signature material the result is only `typed_absent`;
  forged or contradictory material is `fail_closed`.

The caller-supplied independent `expected_context` anchor binds candidate
reference, source revision, frozen root, profile, and exact lock/binary
identities. The caller also supplies a fixed trust anchor containing the
Ed25519 public key, key ID, issuer, trust root, and policy. Both JSON objects
are checked against caller-frozen SHA-256 values. They are hashed/bound into
the signed receipt; changing paths, versions, hashes, or keys—even when all
bundle fields are synchronously rewritten—therefore fails closed. A bundle
`expected_context` is rejected and can never replace the external anchor.

The authenticated closure also covers authority identity and verification time,
each download receipt origin and retrieval time, every binary license, and
each SBOM component supplier/license. This exact object is present in the
declaration, external context, signed-receipt payload, and therefore the outer
envelope signature; changing any one field without the caller's frozen context
and authority key fails closed.

The closure requires Julia and Python, both lock files, every binary's path,
SHA-256, version, publisher, signature, signed download receipt, container or
build recipe, SBOM reference and license. The SBOM must contain non-empty
components and dependency edges that only refer to known components. Existing
files are hashed when `--root` is supplied; a mismatch is `fail_closed`.

For a production signed closure `--root` is mandatory: all paths must be
relative, canonicalized beneath that root, existing regular files, and
byte-hash matching. Runtime-path entries are typed and must match runtime
identity. Duplicate lock/binary identities, version drift, SBOM orphans,
missing coverage, unknown edges and dependency cycles are rejected. Publisher,
signature, download receipt and build recipe carry the same binary subject
identity; receipt/recipe digests are recomputed offline and binary signatures
are verified with Ed25519. SBOM purls use the closed
`pkg:generic/<name>@<version>` form, every binary has an exact unique ref set,
and every component has exactly one dependency-edge entry; orphan, empty,
unknown, duplicate, and cyclic graphs are rejected.

`TEST_ONLY` is always returned as `non_evidence`, including a fully-shaped and
signed synthetic document. Malformed/unknown fields, duplicate JSON keys,
invalid declarations, stale hashes and unverified signatures are
`fail_closed`. A typed absence must include an absence code, owner,
authoritative source and recovery condition.

The result is preparation-only and grants no candidate, source authority,
solver, engineering, physical, B00, B04, UP1 or parent-goal credit.
