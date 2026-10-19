# Independent review: InHouseG3SpatialAuthorityAdapterV1

## Scope and result

Reviewed the frozen adapter source at SHA-256 `DD45FFB1604FD369B1A4F704B9847B5FA965F72C5B664C739AE655FBF15C7ED9`. The review added only this directory's Python static controls and this report. No Julia parse, load, or numerical execution was performed.

**Static contract disposition: GO for the isolated contract-only boundary. Overall integration/acceptance: NO-GO pending serialized Julia parse/load and a registered consumer check.** Static source checks do not establish compilation, executable behavior, or formal consumer acceptance.

## Independent negative-control coverage

| Attack or missing input | Source guard observed | Static disposition |
|---|---|---|
| Declaration belongs to another candidate | Adapter lines 197–199; upstream candidate equality at 160–161 | `fail_closed` |
| G1/G2 source byte count differs from declaration | Lines 166–167 | `fail_closed` |
| G1/G2 raw-byte SHA-256 differs | Lines 168–169 | `fail_closed` |
| G1/G2 authority content hash was altered | Lines 170–174 | `fail_closed` |
| Projection or expected receipt self-hash was altered | Lines 222–228 | `fail_closed` |
| Expected projection is stale or differs from fresh replay | Lines 229–230 | `fail_closed` |
| G3 declaration is absent | Lines 191–195 | `typed_absent`, `terminal_deferred` |
| Required upstream authority/source bytes or current spatial fields are absent | Lines 147–175 and 236–251 | Gap-bearing `typed_absent` when no contradiction is asserted |
| Projection asserts acceptance, formal credit, discovery/engineering credit, or physical status | Lines 241–245 | `fail_closed` |
| Any path could synthesize a spatial closure or claim physical evidence | Receipt contract at lines 63–80 and 107–131 | Closure is typed `Nothing`; `:contract_only`, `:unknown`, zero calls, and `false` physical evidence |

The test's in-memory source mutations remove one guard at a time and verify the static checker fails that control. These are checker self-controls, not execution-level tests.

## Contract alignment

- G3SF V1 declares `:contract_only`; its validator recomputes the declaration hash and checks the authority-layer set and candidate binding (`src/GenomeV5/G3/G3SourceFeedbackLawV1.jl`, lines 382–384 and 446–458).
- G3MFP V3 declares `:screen_only`. Its receipt records no physical status or solver credit (`src/GenomeV5/G3/G3MaterialFieldProjectionV3.jl`, lines 11–13 and 632–635). A successful projection is `:evaluated_screen_only` / `:screen_only` (lines 849–875).
- The adapter's explicit gaps preserve the absent source density vector, return-current distribution/path, outer-boundary `B_out`, outer-sheet `K_outer`, and full G2 volume/boundary support (`src/RuntimeV4/InHouseG3SpatialAuthorityAdapterV1.jl`, lines 12–19).
- This matches the v4 execution constraints: local source declarations and heat/material projections remain below spatial authority; missing spatial inputs remain typed absent/deferred, without physical credit. This adapter does not close the source/field or device-level physical gate.

## Compile and interface risks

1. **No Julia compilation was authorized in this review.** The Python checks cover source guards and the requested frozen digest only; they cannot detect Julia parse, dispatch, method ambiguity, or load-order errors.
2. **No repository consumer was found.** `src/FusionConceptAI.jl` has no include for this adapter, and a targeted source/test reference search found no call site outside the adapter itself. Its G3SF/G3MFP type dependencies therefore require a correctly ordered external/manual include; that path is not verified as a formal consumer.
3. **The result type is permanently closure-empty in this revision.** `mapped_spatial_closure::Nothing` prevents this revision from returning populated spatial authority even after future contracts add such fields. That is safe for today's typed-absence boundary, but any future capability requires a deliberate interface revision.
4. **Receipt verification remains a consumer responsibility.** The adapter returns a receipt hash and checks the upstream projection receipt/replay; this file defines no separate public adapter-receipt verifier or acceptance consumer.

## Reproduction

From the repository root:

```powershell
python -B test/RuntimeV4/InHouseG3SpatialAuthorityAdapterV1/independent_static_review.py
```

Expected result for the frozen source: 5 tests pass. No Julia command is included or implied.
