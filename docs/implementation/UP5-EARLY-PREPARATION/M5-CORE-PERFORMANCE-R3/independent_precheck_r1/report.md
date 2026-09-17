# M5-CORE-PERFORMANCE-R3 independent precheck R1

## Decision

`pass_with_findings` for the bounded implementation scope; `NO-GO` for a
runtime/performance or semantic acceptance claim.  The four core files and the
new focused test are statically coherent enough to enter the parent-owned
serialized Julia lane, but the required canonical/query/replay and cache
properties are not established by this review.  The claim ceiling remains
`synthetic_egraph_equality / screen_only`; this review grants no UP5, search,
provider, physical, engineering, L4, or R01-R10 credit.

No Julia process was started, no M4 adapter/probe was changed, and no existing
core/test/task-manifest/run file was modified.  `git diff --check` passed for
the reviewed paths.

## Scope and inputs

Base requested by the work order: `cfc745939a02fd023854dd04e9bb6d04ccadf9ee`.
The checkout is dirty; unrelated dirty files, including the M4 adapter/probe,
were treated as protected.  Reviewed implementation files:

* `src/Canonical/TypedASTProgramCanonical.jl`
* `src/IR/ConditionalEGraphTypes.jl`
* `src/IR/ConditionalEGraphSaturation.jl`
* `src/Canonical/ConditionalEGraphCanonical.jl`
* `test/RuntimeV4/M4Isolated/m5_core_perf_r3_tests.jl`
* the R3 `README.md`, `acceptance.md`, and `evidence_manifest.json`

The applicable R2 profile/static audit and R4 contract require preservation of
canonical bytes/hash/order, query/replay behavior, full-byte key authority,
cache ownership/isolation, collision fail-closed behavior, and explicit
`not_measured` status until the parent lane executes.

## Positive static checks

1. Cache-aware receipt writers keep the historical field order and use the
   cached AST bytes only as a replacement for the old AST writer.  The normal
   one-argument canonical writers remain present.
2. `_CEGMemberKeyV1` and `_CEGProposalKeyV1` compare all sealed fields, include
   orientation in proposal identity, and use a length-delimited projection for
   the new key-byte helper.  `Dict` indexes are used only for lookup/insert;
   final member/proposal emission still uses the existing deterministic sorted
   vectors and witness tie-break.
3. Cache instances are created per derivation/request/replay/receipt path; no
   global cache or cross-derivation registry was found.
4. `git diff --check` passed.  The R3 evidence manifest honestly records runtime
   and frozen canonical/hash comparisons as pending rather than as zero or pass.

## Findings

### [P1] Sealed program hashes and cached bytes are not actually sealed

`src/IR/ConditionalEGraphTypes.jl:157-175` adds a four-argument
`ConditionalProgramENodeV1` constructor that accepts `_CEGSealedProgramHashV1`
and assigns its `value` directly to `program_hash`; it does not recompute or
cross-check that digest from `program`.  The marker is an internal naming
convention, not an unforgeable capability.  The cache backing it is also a
`mutable struct` with writable `IdDict` fields
(`src/Canonical/TypedASTProgramCanonical.jl:643-665` and
`src/Canonical/ConditionalEGraphCanonical.jl:20-31`), while cache hits return
stored bytes/hashes without validation.  A caller that can reach these
internal symbols can insert a stale/spoofed byte or hash and then construct a
node whose identity fields disagree with its immutable program.  The later
cache-aware member writer detects some such cases at
`ConditionalEGraphCanonical.jl:124-127`, but `ConditionalEClassV1`, query, and
other intermediate operations can observe the forged member before that
receipt boundary.

Required closure: make the sealed constructor validate the supplied digest
against the canonical bytes (or use an internal token that cannot be supplied
by a caller), and add a negative test that mutates/preloads a cache entry and
attempts a forged node.  The test must show fail-closed behavior rather than
just checking that output strings are immutable.

### [P1] The main factorial hot path still bypasses the new cache

`ConditionalRewriteTraceStepV1` still calls `_typed_ast_program_json` for both
source and target at `src/IR/ConditionalEGraphTypes.jl:98-115`.  Every proposal
that reaches `_ceg_candidate_provenance` at
`src/IR/ConditionalEGraphSaturation.jl:242-246` constructs that trace, before
the best-candidate grouping and tie-break at lines 311-325.  Thus repeated
proposal canonicalization remains in the saturation hot loop; the new cache
does not cover it.  This is directly at odds with the R2 profile's dominant
factorial canonicalization finding and means a performance pass cannot be
inferred from the cache seam.

Required closure: add a cache-aware trace/provenance construction path that
uses the already sealed program bytes/hashes, or otherwise prove the same
canonicalization is not repeated.  Preserve all existing orientation,
condition, step, and replay checks.

### [P1] The focused R3 test does not cover the requested semantic/cache matrix

`test/RuntimeV4/M4Isolated/m5_core_perf_r3_tests.jl:30-60` verifies one repeated
read of the same source object, equality of one cached hash to the legacy hash,
one cached rule read, a NUL separator example, and one forward proposal key.
It does **not** exercise:

* cold-cache versus hot-cache equality of rule-set/member/equivalence/attempt
  receipt bytes and hashes;
* graph construction followed by query and replay equivalence;
* mutation/preload isolation of `IdDict` cache state;
* a forced digest collision with full-byte fail-closed handling;
* cross-derivation or cross-product cache separation;
* deterministic fresh-process saturation/query output with the new `Dict`
  indexes.

The NUL split-key case is useful for delimiter ambiguity, but it is not a
digest-collision injection and does not establish the R4 collision contract.
The parent lane must add or invoke focused controls for each item before
accepting this implementation.  Existing P1 tests remain useful regression
inputs but do not substitute for the new cache mutation/collision controls.

### [P2] Runtime and byte/hash evidence remain intentionally absent

The R3 `acceptance.md` and `evidence_manifest.json` explicitly say that Julia,
canonical/hash frozen comparisons, query/replay regression, and profile
measurements are pending.  Therefore this precheck cannot verify that the
cache-aware writers are byte-identical to the legacy writers on a real graph,
or that the `Dict` replacement preserves fresh-process ordering.  This is an
honest boundary, not a defect in the documentation, but it prevents a plain
`pass` disposition.

## Minimum parent-owned Julia lane

The smallest permitted smoke command is:

```powershell
julia --project=. --startup-file=no --history-file=no test/RuntimeV4/M4Isolated/m5_core_perf_r3_tests.jl
```

That command only covers the current focused seam and is not sufficient to
close the findings.  Before any acceptance decision, the parent should run it
serially together with the existing core/query/replay regression commands and
an additive fresh-process harness that compares cold/hot canonical bytes and
hashes, performs cache-mutation/forged-hash negatives, injects the R4 forced
digest collision, and checks query/replay equivalence.  Any timeout, Julia
exception, byte/hash mismatch, stale-key observation, or non-deterministic
`Dict` result is `terminal_deferred`/`fail_closed`, never a performance pass.

## Boundary

All conclusions are `screen_only`.  This record does not modify, stage, or
commit source; it does not authorize a heavy Julia/DESC/mesh lane and does not
change the M4 adapter/probe, task manifest, or existing run evidence.
