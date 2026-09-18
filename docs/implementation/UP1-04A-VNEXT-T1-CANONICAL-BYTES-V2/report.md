# V2 slice report

## Scope delivered

- Added `VNextT1CanonicalBytesV2` as a non-parameterized, definition-only
  contract slice.
- Added exact byte helpers and an explicit base64 semantic view.
- Added fixed cases at 0/1/63/64/65/1024 bytes, invalid UTF-8 bytes, mutation
  isolation, and an 8,269,445-byte `Vector{UInt8}` replay specification.
- Froze Base64 goldens for all four 63/64/65/1024 boundary cases, exact
  canonical JSON, and nested NamedTuple/Tuple canonical JSON.
- Added caller-mutation and returned-copy isolation for invalid UTF-8 bytes.
- Froze SHA-256 and size for `CandidateStatePackageV5Next.jl` and
  `src/FusionConceptAI.jl`; neither production boundary is modified here.
- Added a stable single-line replay record for a later second Julia process.
- Added an independent Python oracle using only `hashlib` and `base64`.

## Checks

The intended commands for this batch are:

```text
python -B test/GenomeV5/Integration/VNextT1CanonicalBytesV2/static_qa_vnext_t1_canonical_bytes_v2.py
python -B test/GenomeV5/Integration/VNextT1CanonicalBytesV2/independent_oracle_vnext_t1_canonical_bytes_v2.py
```

Julia execution is intentionally deferred. No runtime receipt is present and
no production module, registry, or T1 admission path was changed.

## Remaining gap

The source and Julia test require a serialized Julia run before this slice can
be used as runtime evidence. That run must verify invalid-byte construction,
ownership isolation, boundary byte access, the full large Vector digest, and a
second-process semantic replay. Until then, the claim ceiling remains
`contract_only` / `not_accepted_limited`.
