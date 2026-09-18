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

Static QA, an independent Python hashlib/base64 oracle, and the serialized R3
local Julia process pass for this slice. The serialized R1 Julia attempt started once and
ended as `program_exception` / exit 1 after 2.886777 seconds because the package
project had not declared the Base64 standard-library dependency. It changed
none of its 18 protected files and left no Julia/DESC process after either of
the two postflight observations. The evidence is copied without overwrite to
`local_profile_r1_runtime/`; the original preflight runner and receipt remain
in place. R1 grants no T1, UP1, provider, numerical, physical, or engineering
credit.
The large 8,269,445-byte case is specified as a `Vector{UInt8}` replay and no
large tuple is constructed.

Static QA also freezes the SHA-256 and byte size of
`CandidateStatePackageV5Next.jl` and `src/FusionConceptAI.jl`, proving that the
current production admission file and module include/export boundary were not
changed by this definition-only slice. The Julia test contains a deterministic
single-line `VNEXT_T1_CANONICAL_BYTES_V2_REPLAY` record for a later independent
second process, but it is not runtime evidence until that process is run.
`Project.toml` now declares Base64 and the manifest was resolved, but no Julia
test rerun is claimed by this repair.

The subsequent serialized R2 attempt reached the test body but exited 1 after
2.7671703 seconds. Its fixed-payload testset passed 48/48; the boundary testset
recorded 12 passes and 4 errors because an immutable tuple of `Pair` goldens
was incorrectly indexed by payload lengths. R2 used one start, no retry,
changed none of 18 protected files, and left zero Julia/DESC processes in both
postflight observations. The byte-for-byte archive is
`local_profile_r2_runtime/`; it grants no runtime or T1 credit. The test-only
repair replaces that lookup with an immutable NamedTuple and explicit
`n<length>` property resolution. No Julia rerun is claimed after this repair.

The serialized R3 process then passed all 77/77 assertions with exit 0 after
155.2198949 seconds. It started once without retry, changed none of 18
protected files, and left zero Julia/DESC processes in both postflight
observations. Its lock and run receipt are archived byte-for-byte in
`local_profile_r3_runtime/`. This is local definition-only runtime evidence:
V2 remains disconnected from production admission, and R3 grants no T1 or
UP1 completion credit. An independent second-process replay is prepared but
not run in `local_profile_r4_replay_preflight/`.
