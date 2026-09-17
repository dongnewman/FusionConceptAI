# UP1 external-blocker closure R4 — combined independent review R1

## Independent decision

This is a read-only, static independent review of all seven
`22-external-input-recheck` subdirectories, using `21-root-acceptance` and
`19-final-full-regression` as the frozen baseline. The bounded evidence supports:

```text
external_input_delta = no
new_ad = no
s3_rerun = no
T0_authorized = no
formal_credit = none (BLOCKED_NO_CREDIT)
usable_external_inputs = 0
external_snapshot = 26/26 typed_absent
```

No real fresh external input was observed in the checked workspace. The result
is `terminal_deferred` for the external gate and does not change the accepted
local ceiling `PASS_LIMITED / ACCEPT_FOR_LOCAL_INTEGRATION`. It does not grant
authority, publication, T0/T1/T2, AD/S3, R01–R10, or parent-goal credit.

## Frozen baseline and independent checks

- Repository: `D:/006-Programing/LMC/FusionConceptAI`.
- Fixed and current `HEAD`: `b2c04d8339774635aaecd73651efcdb101e01b5d`.
- Fixed `HEAD^{tree}`: `e28da2ff057201c2257f6b879d3860b7a49cb428`.
- The worktree is dirty, as explicitly recorded by the source-axis and
  authoritative-channel captures. Dirty local source, historical documents,
  generated receipts, and test fixtures were not interpreted as fixed-HEAD or
  external authority.
- `21-root-acceptance/decision.json` remains `root_accepted_scope_limited`:
  26/26 typed absent, usable count 0, no new AD, no S3 rerun, formal credit
  false, T0/authority/T1/T2 false, DAG 39 and R01–R10 unchanged.
- `19-final-full-regression` remains offline software evidence only: R3 atomic
  `25 tests + 1 skipped` twice, R4 full `98 passed + 2 skipped` twice, static
  compile/import exit 0, and unchanged 48-file source/test closure.
- All 22 JSON files under the seven recheck directories parsed successfully.
  Every listed entry in the seven manifests was independently rehashed: 57/57
  entries matched both recorded byte count and SHA-256. The two files listed by
  the 21-root-acceptance manifest also match.
- The 14 frozen intake pairs (two roots × seven paths: `local_spool`,
  `local_spool/incoming`, `response`, `anchors`, `local_receipts`, `incoming`,
  `intake`) are absent, with zero files. Remote and unlisted channels were not
  queried, so this is a bounded negative observation rather than a global claim.

## Seven-subdirectory review

| subdirectory | independent result | usable | local/untrusted material | external conclusion |
|---|---|---:|---|---|
| `witness` | `found_usable=0`, 9 representative local records | 0 | AD/local declarations, local receipt, source proof code | EHP-01 witness identity, independence, signature, lineage and four-axis inputs remain typed absent |
| `trust-chain` | no trust root, chain, signed attestation or production profile | 0 | local verifier policy, generated-fixture tests, generic store metadata | trust root/chain/signature/revocation/time remain typed absent; local policy is not an issued trust profile |
| `freshness-replay` | no OCSP/CRL, TSA token, nonce response, external ledger or authoritative response | 0 | in-memory fixtures and offline fail-closed implementation | freshness/replay authority remains typed absent; caller booleans and local CAS/HMAC are not external proof |
| `source-axis` | no EHP-03 source or four-axis response; all four axis objects absent | 0 | dirty local source and `TEST_ONLY` prototype/fixtures | source closure, candidate lineage, G2 and four-axis binding remain typed absent |
| `g2-mapping` | no signed authoritative bidirectional G2 mapping | 0 | local factory, validator, historical records and synthetic fixtures | G2 mapping remains typed absent; five adversarial cases correctly remained `fail_closed` |
| `authoritative-channel` | channel owner/endpoint/transport/auth/ACK all absent | 0 | local adapter and test literals only | no authoritative channel or signed ACK exists; `real_channel` is descriptive/test-only |
| `environment-binary` | no candidate-bound environment closure or binary provenance | 0 | local manifests and executable hashes | local bytes are untrusted observations; publisher/build/SBOM/license/origin authority remains absent |

No row promotes local or historical material to authority. In particular,
`local-only://r4`, `offline-spool`, `real_channel=true`, local test passes,
repository hashes, installed binaries, Windows certificate-store metadata,
local receipts, and synthetic positive payloads are explicitly non-authoritative.

## Raw process receipts, hashes, and failures

The following preserves the raw/PID/UTC/exit/hash boundary. Hashes are the raw
capture hashes recorded by the subdirectory manifests or raw records.

| area | PID and UTC | exit | raw/hash evidence | failure or boundary |
|---|---|---:|---|---|
| witness path scan | 104052, `03:55:57.2597775Z → 03:55:57.3342309Z` | 0 | `path_scan.raw.json` SHA-256 `43bd7fe4578bbeb4b90ae9533fe54c0a606fd68d73ac11091ae6706f4cc27b55` | all 14 pairs empty |
| witness baseline parse | 70584, `03:56:33.7792410Z → 03:56:33.9186986Z` | 0 | `r4_baseline.raw.json` SHA-256 `f38cf8ade35dfb8da0054c2e7f82cd9976d914848df0a08f075f26a45daff3ee` | 26/26 typed absent |
| witness manifest verification | 106424, `04:07:43.0501987Z → 04:07:43.2165604Z` | 0 | `verification.raw.json`; all hashes and JSON parse OK | scoped evidence only |
| trust-chain bounded scan | 56748, `04:02:27.5045664Z → 04:02:29.2982589Z` | 0 | `recheck.raw.json` SHA-256 `810ce1a3641f2c7c55b39d9e8ef0fe5ffdded4860c97ae88499fd6bfa829a92c` | 14 pairs absent; no certificate-like files |
| trust-chain marker scan | 2760, `04:03:09.7402230Z` | 1 | no-match exit; no marker matched | exit 1 is expected negative result |
| trust-chain exploratory probe | 56748, `04:02:27.5045664Z → 04:02:29.2982589Z` | 2 | retained in `recheck.raw.json` | discarded option-sensitive `rg` invocation; no evidentiary effect |
| freshness/replay scan | 31432, `04:03:49.2975187Z` | 0 | `scan.json` SHA-256 `a769e2dc1ac575810d60ba3977b8425e867fb09856c4cfbf825675a0e3d2e32e` | no expected payload names or external freshness bytes |
| source-axis scan | 72928, `04:01:36.6401025Z → 04:01:38.5214212Z` | 0 | `scan.raw.json` SHA-256 `0a452d3dcf50cce560ff4bb95c592b5798b0c3d1ca504402c54a7e703471d93f` | four expected EHP-03 locations absent; dirty worktree recorded |
| G2 adversarial probe | 109180 (parent 111408), `04:04:30.249026Z → 04:04:30.249875Z` | 0 | raw SHA-256 `966D4A2A6C795C1B522F2450E8DFA6C42CAC08B78610ED27C15130793ECAAD8F` | all five malformed cases `fail_closed`; software-only |
| G2 path scan | 113104, `04:09:20.7662371Z → 04:09:20.7734883Z` | 0 | raw SHA-256 `2063E0BF22A55B976FF7ACE509419DA158D466689DDE2F15FE36AF53E5D3B7CE` | all 14 pairs absent |
| G2 hash self-check | 102928, `04:18:20.0779717Z → 04:18:20.1174279Z` | 0 | `hash_self_check.raw.txt`, JSON parse and listed hashes exit 0 | no source/runtime execution |
| authoritative-channel scan | 113236, `03:56:51.960702Z → 03:56:52.778109Z` | 0 | `recheck.stdout.json` SHA-256 `af0c53d787c3cf8b16cb561659c2fb3de52e996b9665df865a8ef06fc511a03b` | external ACK 0; signed-ack pattern hits are historical/test files |
| environment/binary static capture | 94364, `04:01:35.9384378Z` | 0 | raw hashes `e8af55b8da8b2c723ee38808d2ae6f8df3421f0ecf698b82e6ee93b390ed3241`, `d648de0992834cf99b84cad4b9d09c4207c3e1e8d601a553f593171c25314c5f`, `baacf359747b9b52af2ee9d8b2d106ca3367e8bc0081e63257198e6c2722ce19` | initial PowerShell draft parser error was corrected; substantive static capture exit 0 |

All seven areas record no network, Julia, DESC, S3, solver, test-suite,
credential, installation, signature-generation, or external-request action.

## 26-requirement conclusion

The R4 contract has exactly 26 items. The independent recheck and baseline
agree that every item is currently `typed_absent`, including:

- EHP-01 witness identity/independence, signed attestation, channel and
  independent scope;
- EHP-02 trust root, intermediate/leaf chain, signature profile, signed
  receipt, verifier, revocation, trusted time and replay policy;
- EHP-03 source closure/version binding, candidate lineage, source-candidate
  graph, authoritative G2 mapping and the complete four-axis set; and
- EHP-04 candidate environment closure and binary provenance.

The local environment manifests and executable hashes are useful observations
only. They do not establish publisher identity, download origin, build recipe,
SBOM/license closure, candidate binding, or external review.

## External responsibility and recovery conditions

| responsibility | required recovery before any authority recheck |
|---|---|
| channel owner/intake operator | signed channel contract, owner identity, endpoint/transport/authentication pin, testable signed ACK/rejection path, durable receive/quarantine receipt |
| witness/governance/attestor | fresh EHP-01 identity, independence/conflict disclosure, exact scope, leaf signature and reviewer separation |
| project PKI/CA/verifier | pinned root/profile, ordered chain, algorithm/EKU/key-use policy, signed receipt, fresh CRL/OCSP and independent replay receipt |
| TSA/time and replay-ledger owners | signed trusted-time token, nonce/challenge/sequence/idempotency policy, authenticated persistent ledger and fresh acceptance/rejection evidence |
| source/candidate/G2/axis authorities | exact same-candidate source closure, G1/G2/G3 references, complete forward/reverse G2 mapping, all four axis bytes/digests and signatures |
| environment/SBOM provider and binary publisher | candidate-bound runtime/import/artifact closure, exact binary hashes, signed origin/build/provenance, reproducible recipe, SBOM/license/platform evidence |
| independent reviewer | recompute exact raw-byte hashes and candidate/source/axis/G2 joins; independently verify trust, time, revocation, replay, and role separation |

Recovery is atomic: receive EHP-01..04 through the authoritative channel,
preserve exact bytes and hashes, reject partial/foreign/stale/replayed or
contradictory material, rebuild candidate/source/G2/axis identities after any
source or policy drift, then run one fresh authority recheck. Until every gate
is met, retain `typed_absent -> terminal_deferred`, `formal_credit=none`,
`new_ad=false`, `s3_rerun=false`, `T0_authorized=false`, and no publication.

## Scope and write boundary

This review was produced without changing source, tests, historical reports,
or the seven recheck directories. The only intended writes are the files under
`reviews/combined-independent-review-r1/`.
