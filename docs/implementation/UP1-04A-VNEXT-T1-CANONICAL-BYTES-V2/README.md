# UP1-04A VNext T1 Canonical Bytes V2

This is an additive, definition-only vertical slice for the VNext T1 byte
boundary. It introduces a non-parameterized immutable byte carrier whose
semantic projection is explicit and replayable across processes.

The slice is deliberately not included by `src/FusionConceptAI.jl`, does not
alter `VNextT1CanonicalBytesV1`, does not register a new production contract,
and does not switch T1 admission to V2.

## Contract

`VNextT1CanonicalBytesV2` stores `raw::String`, a SHA-256 digest of the exact
`codeunits(raw)`, and `encoding=:base64`. Construction copies an input
`AbstractVector{UInt8}` before creating the string. `byte_length`, `copy_bytes`,
and `byte_at` expose exact byte semantics without character iteration. The
semantic view includes schema, version, encoding, base64 payload, byte length,
and SHA-256 digest. `canonical_json(V2)` delegates only to that semantic view;
the fixtures freeze both its exact JSON and a nested NamedTuple/Tuple JSON.

The byte carrier intentionally permits arbitrary byte values, including an
invalid UTF-8 sequence. Base64 is transport representation only; the digest
is over the original bytes.

## Evidence boundary

Static QA and an independent Python hashlib/base64 oracle are the only checks
run for this slice in the current batch. Julia was not executed. Therefore this
record grants no T1, UP1, provider, numerical, physical, or engineering credit.
The large 8,269,445-byte case is specified as a `Vector{UInt8}` replay and no
large tuple is constructed.

Static QA also freezes the SHA-256 and byte size of
`CandidateStatePackageV5Next.jl` and `src/FusionConceptAI.jl`, proving that the
current production admission file and module include/export boundary were not
changed by this definition-only slice. The Julia test contains a deterministic
single-line `VNEXT_T1_CANONICAL_BYTES_V2_REPLAY` record for a later independent
second process, but it is not runtime evidence until that process is run.
