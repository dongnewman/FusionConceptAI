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

The serialized R1 Julia attempt executed once and failed before test execution
with a Base64 package-dependency `program_exception`: exit 1 after 2.886777
seconds. Its receipt records 18/18 protected files unchanged, no automatic
retry, and zero Julia/DESC processes in both postflight observations. The
original preflight runner is preserved and the lock/run evidence was copied,
without overwrite, into `local_profile_r1_runtime/`.

The minimal repair adds Base64 UUID
`2a0f44e3-6c83-55bd-87e4-b1978d98bd5f` to `[deps]`, resolves the manifest,
and adds a static dependency assertion. No Julia test or DESC computation was
run after the repair. No production module, registry, or T1 admission path was
changed.

## Remaining gap

R1 is rejected and grants no runtime or T1 credit. A later serialized Julia
run is still required before this slice can be used as runtime evidence. That
run must verify invalid-byte construction,
ownership isolation, boundary byte access, the full large Vector digest, and a
second-process semantic replay. Until then, the claim ceiling remains
`contract_only` / `not_accepted_limited`.
