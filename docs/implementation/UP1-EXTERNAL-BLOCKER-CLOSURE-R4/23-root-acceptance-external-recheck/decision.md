# UP1 external-blocker closure R4 — accepted external-input recheck

## Decision

The root owner accepts `reviews/combined-independent-review-r1/` as a
read-only recheck and archive record. This acceptance does not create a new
external-input decision and does not change the frozen R4 ceiling.

| Item | Accepted state |
|---|---|
| `external_input_delta` | `no` |
| usable external inputs | `0` |
| external snapshot | `26/26 typed_absent` |
| contracted intake roots/paths | `14/14 empty` |
| `new_ad` | `false` |
| `s3_rerun` | `false` |
| software R4 | `PASS_LIMITED / ACCEPT_FOR_LOCAL_INTEGRATION` (unchanged) |
| formal/external | `BLOCKED_NO_CREDIT` (unchanged) |
| T0 / authority recheck / T1 / T2 | not authorized and not executed |
| R01–R10 / 39-node DAG / acceptance gates | unchanged |
| parent goal | `active` |

No local, historical, fixture, repository, certificate-store, binary, or
reviewer artifact is promoted to external authority. The combined review is
accepted only as a bounded negative recheck: no remote or unlisted channel was
queried, and unchanged input does not justify a new AD or repeated S3.

## Evidence basis

The accepted combined review independently parsed all 22 JSON files under the
seven recheck directories, matched all 57 listed recheck-manifest entries, and
matched both `21-root-acceptance` entries. It records zero present files at all
14 frozen root/path pairs, 26/26 typed absent contract items, and zero usable
external inputs. The frozen root decision remains
`root_accepted_scope_limited`; its software/formal split, no-publish boundary,
39-node DAG, R01–R10 state, and active parent goal are unchanged.

The seven areas remain terminal-deferred:

| Recheck area | Result | Boundary |
|---|---|---|
| `witness` | usable `0`; 9 local/untrusted representative records | witness identity, independence, signature, lineage, and four-axis inputs absent |
| `trust-chain` | usable `0` | project root, ordered chain, signed receipt, revocation, and trusted time absent; local policy is not an issued profile |
| `freshness-replay` | usable `0` | OCSP/CRL, trusted timestamp, nonce/replay authority, and external ledger absent |
| `source-axis` | usable `0` | source closure, candidate lineage, authoritative G2, and complete four-axis set absent |
| `g2-mapping` | usable `0` | signed authoritative mapping absent; five malformed probes remained `fail_closed` |
| `authoritative-channel` | usable `0` | owner, endpoint, transport, authentication, ACK, and external response absent |
| `environment-binary` | usable `0` | candidate-bound environment closure and binary provenance absent; local bytes remain untrusted observations |

## Raw process receipts retained

The following process metadata is copied from the seven reports and their raw
receipts. It is retained for auditability; it is not a new execution or gate
authorization.

| Area / raw capture | PID | UTC | exit | raw SHA-256 or boundary |
|---|---:|---|---:|---|
| `witness/raw/path_scan.raw.json` | 104052 | `03:55:57.2597775Z → 03:55:57.3342309Z` | 0 | `43bd7fe4578bbeb4b90ae9533fe54c0a606fd68d73ac11091ae6706f4cc27b55` |
| `witness/raw/r4_baseline.raw.json` | 70584 | `03:56:33.7792410Z → 03:56:33.9186986Z` | 0 | `f38cf8ade35dfb8da0054c2e7f82cd9976d914848df0a08f075f26a45daff3ee` |
| `witness/raw/local_artifact_scan.raw.txt` | 34904 | `03:54:41.7243322Z → 03:54:43.0004732Z` | 0 | `37b9222cda133a6da8acc275a3ca59a53515ceb9abc27b07dae9f0d93ed1baae` |
| `witness/raw/verification.raw.json` | 106424 | `04:07:43.0501987Z → 04:07:43.2165604Z` | 0 | `1f4d766c5ce08e1cebbdea9d976ecc81cefed0cf4916ef966afb8b21e301be10` |
| `authoritative-channel/raw/recheck.stdout.json` | 113236 | `03:56:51.960702Z → 03:56:52.778109Z` | 0 | `af0c53d787c3cf8b16cb561659c2fb3de52e996b9665df865a8ef06fc511a03b` |
| `environment-binary/raw/static_recheck.raw.txt` and companion captures | 94364 | `04:01:35.9384378Z` | 0 | substantive static capture exit `0`; raw hashes `e8af55b8da8b2c723ee38808d2ae6f8df3421f0ecf698b82e6ee93b390ed3241`, `d648de0992834cf99b84cad4b9d09c4207c3e1e8d601a553f593171c25314c5f`, `baacf359747b9b52af2ee9d8b2d106ca3367e8bc0081e63257198e6c2722ce19` |
| `freshness-replay/raw/scan.json` | 31432 | `04:03:49.2975187Z` | 0 | `a769e2dc1ac575810d60ba3977b8425e867fb09856c4cfbf825675a0e3d2e32e` |
| `source-axis/raw/scan.raw.json` | 72928 | `04:01:36.6401025Z → 04:01:38.5214212Z` | 0 | `0a452d3dcf50cce560ff4bb95c592b5798b0c3d1ca504402c54a7e703471d93f` |
| `g2-mapping/raw/g2_adversarial_probe.raw.json` | 109180 (parent 111408) | `04:04:30.249026Z → 04:04:30.249875Z` | 0 | `966D4A2A6C795C1B522F2450E8DFA6C42CAC08B78610ED27C15130793ECAAD8F` |
| `g2-mapping/raw/workspace_paths.raw.txt` | 113104 | `04:09:20.7662371Z → 04:09:20.7734883Z` | 0 | `2063E0BF22A55B976FF7ACE509419DA158D466689DDE2F15FE36AF53E5D3B7CE` |
| `g2-mapping/raw/hash_self_check.raw.txt` | 102928 | `04:18:20.0779717Z → 04:18:20.1174279Z` | 0 | exit `0`; self-check raw hash `BBF082E952F020F98A338C6678B8B16E11B131A043A3BFA3DA7EB3566D3BB7CB` |
| `trust-chain/raw/recheck.raw.json` | 56748 | `04:02:27.5045664Z → 04:02:29.2982589Z` | 0 | `810ce1a3641f2c7c55b39d9e8ef0fe5ffdded4860c97ae88499fd6bfa829a92c` |
| trust-chain certificate-marker scan | 2760 | `04:03:09.7402230Z` | 1 | expected no-match result; no certificate marker matched |
| trust-chain discarded exploratory probe | 56748 | `04:02:27.5045664Z → 04:02:29.2982589Z` | 2 | option-sensitive invocation discarded; no evidentiary effect |

## External responsibility and recovery conditions

The seven responsibility categories below are role labels, not verified
identities. No category currently has a usable input. Recovery is atomic: all
required EHP-01..04 bytes must arrive through an authoritative channel, be
hash/signature/time/replay checked, and then receive one fresh authority
recheck. If inputs remain unchanged, do not create another AD or rerun S3.

| External responsibility party | Required input | Recovery condition |
|---|---|---|
| Authoritative channel owner / intake operator | Signed channel contract: owner identity, endpoint, transport/authentication, pinned protocol/key, ACK/rejection path, retention/quarantine receipt; ordered raw EHP-01..04 bundle and signed receive response | Testable authenticated transport returns a signed ACK or rejection binding request ID, bundle digest, nonce/sequence/idempotency, trusted receive time, and durable quarantine/CAS receipt |
| Witness / governance / attestor | EHP-01 witness identity, qualification/validity, independence/conflict disclosure, exact scope, leaf signature, issuer/reviewer receipts | Distinct qualified witness and governance/reviewer attest the exact canonical scope package under a valid leaf/chain with trusted time and revocation evidence |
| Project PKI / CA / verifier | Pinned project root/profile, ordered root/intermediate/leaf chain, algorithm/EKU/key-use policy, signed receipt, verifier/profile hashes | Fresh bytes and signatures validate under the pinned profile; issuer links, validity, revocation, canonical payload digest, and independent replay receipt all match |
| TSA / trusted-time and replay-ledger owners | Signed trusted-time token, nonce/challenge response, strict sequence/idempotency policy, authenticated persistent replay ledger and acceptance/rejection receipt | Fresh time, nonce, sequence, replay, and CAS evidence binds the exact received bytes and rejects stale, replayed, foreign, or contradictory material |
| Source / candidate / G2 / four-axis authorities | Same-candidate source closure and G1/G2/G3 references; complete forward/reverse G2 mapping; all four axis bytes/digests and signatures; lineage/source receipts | Rebuild candidate/source/G2/axis identities from exact bytes and independently recompute the joins; any source drift forces a full rebuild |
| Environment / SBOM provider and binary publisher | Candidate-bound runtime/import/package/artifact manifest; exact binary hashes; signed origin/build/provenance; reproducible recipe; SBOM/license/platform evidence | Independent provider/publisher receipts bind environment, binaries, origin, recipe, SBOM, license, platform, and candidate identity; local manifests or store observations remain insufficient |
| Independent reviewer | Exact-byte/hash recomputation plus independent trust, time, revocation, replay, source/candidate/G2/axis, environment, and role-separation review | Reviewer issues a fresh receipt over the complete bundle and confirms no partial, foreign, stale, replayed, malformed, or contradictory input was accepted |

## Authorization and frozen-state boundary

This archive accepts the combined review only. It authorizes no T0, no fresh
authority recheck, no T1, and no T2. `formal_credit=none`,
`authority_credit=false`, `publish=false`, `new_ad=false`, and `s3_rerun=false`
remain in force. R01–R10, the 39-node DAG, and all acceptance gates remain
unchanged. The parent goal remains `active`.

## Evidence references

- `21-root-acceptance/decision.md`
- `21-root-acceptance/decision.json`
- `21-root-acceptance/hash_manifest.json`
- `reviews/combined-independent-review-r1/review.md`
- `reviews/combined-independent-review-r1/review.json`
- `reviews/combined-independent-review-r1/hash_manifest.json`
- `22-external-input-recheck/witness/{report.md,receipt.json,hash_manifest.json}`
- `22-external-input-recheck/trust-chain/{report.md,receipt.json,hash_manifest.json}`
- `22-external-input-recheck/freshness-replay/{report.md,receipt.json,hash_manifest.json}`
- `22-external-input-recheck/source-axis/{report.md,receipt.json,hash_manifest.json}`
- `22-external-input-recheck/g2-mapping/{report.md,receipt.json,hash_manifest.json}`
- `22-external-input-recheck/authoritative-channel/{report.md,receipt.json,hash_manifest.json}`
- `22-external-input-recheck/environment-binary/{report.md,receipt.json,hash_manifest.json}`

Only the three files in this directory are written by this archive step.
