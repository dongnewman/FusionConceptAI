# UP1 R3 atomic prototype repair R1

This additive repair closes the five independent-review P1/P2 classes within
the bounded local prototype.  It does not alter the frozen 03/04 contracts or
the 05/06 review history, and it grants no formal or external authority.

The repaired boundary is deliberately fail-limited:

- when `rfc8785` is unavailable, every float/exponent value is typed-rejected
  (`CANONICAL_NUMBER_UNSUPPORTED`); no decimal normalisation fallback exists;
- quarantine uses a contained CAS root, rejects symlink/junction/reparse
  components, never overwrites an existing object, and independently checks
  exact bytes, size, digest, transaction ID, locator, receipt preimage/digest,
  and a pinned TEST_ONLY Ed25519 receiver signature;
- schema failures short-circuit all cross-field predicates and always return a
  typed result with `no_publish=true`;
- preimages use path-scoped exclusions and payload objects are opaque;
- EHP-03 graph/row/authority references and EHP-04 runtime/SBOM/binary/fixture
  identities are recomputed where material is present;
- TEST_ONLY key/profile material is marked `non_evidence` and cannot produce an
  acceptance result.

The concrete 26-vector execution is in `test_atomic_bundle_repair.py`; its
inventory covers R01-R25 and D01.  Two serial runs were completed on the
supported Windows host with `python -B`; raw command metadata is recorded in
`execution-receipts.json`.  These are prototype software receipts only.
