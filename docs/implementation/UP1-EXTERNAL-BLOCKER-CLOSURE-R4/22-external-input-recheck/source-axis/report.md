# UP1 R4 source-axis external-input recheck

## Scope and result

This is a read-only recheck at the fixed checkout `b2c04d8339774635aaecd73651efcdb101e01b5d`.
It did not run Julia, DESC, S3, intake, network access, or signature generation. The
observation snapshot was taken before this report directory was written; the generated
files are outside the captured source closure.

The result is:

| class | result |
|---|---|
| `found_usable` | `[]` |
| `found_untrusted` | local dirty source observations and local `TEST_ONLY` R4 prototype/fixtures only; no external authority |
| `typed_absent` | external source closure, four-axis set, candidate lineage/G2 binding, trust/signature/time/revocation/independent-review inputs |
| `new_ad` | `false` |
| `s3_rerun` | `false` |
| `formal_credit` | `none` |

No complete, signed, same-candidate source-plus-four-axis input was observed. The four
frozen axis names are exactly:

1. `payload_schema_version`
2. `canonicalization_profile_version`
3. `applicability_profile_version`
4. `evidence_receipt_version`

All four expected EHP-03 response locations were absent, and all 14 frozen offline
root/path pairs were absent. This is bounded to the two roots and seven paths recorded in
`raw/scan.raw.json`; remote and unlisted channels were not queried.

## Source version and dirty closure

`HEAD` equals the fixed commit and its tree is
`e28da2ff057201c2257f6b879d3860b7a49cb428`. The fixed commit is
`feat: publish Genome V5 source closure`, parent
`4b69f55f7f80240147a65a22809dc1207824dde2`, committed at
`2026-09-16T06:29:02+08:00`.

The current worktree is not a trusted clean source closure: 10,694 porcelain lines,
10,667 untracked entries and 27 modified entries were observed. The status, unstaged
diff, staged diff and untracked-path digests are retained in the raw receipt. The three
AD56 source-authority factory working OIDs do not equal their fixed-HEAD blob OIDs:

| source | working OID | fixed-HEAD blob OID |
|---|---|---|
| `src/GenomeV5/G1/G1SourceAuthorityFactoryV1.jl` | `9fab079f8c60a088653ef5bdde03e2ac2205029d` | `0a78e7c279b394345b8b6923b225bf3eb7fbc6d4` |
| `src/GenomeV5/G2/G2SourceAuthorityFactoryV1.jl` | `8edc6c3233c99873a68190b6a159449dd75dae84` | `50a9135a77fd4fbad450755abfe761a296386ec8` |
| `src/GenomeV5/G3/G3SourceAuthorityFactoryV1.jl` | `85e15aaa7c21854f64f71e7b4d34dfefd3de7266` | `84a4b5e264dc77c81d88d704028dc12a490f6454` |

The three declaration source paths have working filtered OIDs equal to their HEAD
blobs, but the repository remains dirty; that does not establish an externally signed
source closure. Local R4 source-axis code and synthetic complete axis fixtures are
explicitly `TEST_ONLY`/local software material and cannot supply authority, signatures,
trusted time, revocation, or independent review.

## Four-axis binding verdict

`four_axis_materials` is `typed_absent`, not a three-of-four or inferred set. No axis
material bytes, material digests, candidate ID, source identity digest, reverse edges,
namespace/version/issuer/issued-at fields, per-axis signature references, set receipt,
trusted-time receipt, or revocation receipt were present in the checked intake scope.
Consequently there is no exact candidate/source/axis join to validate and no new
candidate identity or G2 mapping to rebuild.

The responsible parties and exact recovery conditions are:

| gap | responsible party | exact recovery condition |
|---|---|---|
| `EXT-SOURCE-CLOSURE` / `source_version_binding` | source authority plus independent attestor | Supply fresh candidate-bound source bytes, HEAD/tree, dirty/untracked/submodule closure, exact G1/G2/G3 refs and versions, source-owner and independent-attestor signatures, and fresh inventory/hash receipts. Any source drift rebuilds candidate/axis/G2/receipt identities. |
| `four_axis_materials` | G1/G2/G3 axis owners plus independent authority | Supply all four named axis objects as one externally issued set, with exact bytes/digests, same candidate/source reverse edges, namespace/version/issuer/issued-at, per-axis signatures, per-axis trusted-time/revocation receipts, and a set receipt. One missing axis keeps the set `typed_absent`. |
| `EXT-CANDIDATE-LINEAGE` / `g2_authoritative_mapping` | candidate/source authority and G2 mapping authority/attestor | Supply a fresh same-candidate forward/reverse lineage and complete bidirectional G2 mapping, with issuer/profile/trusted-time/revocation/replay evidence and fresh authority receipts. |
| trust/signature/verifier/freshness inputs | project PKI, attestor, verifier/policy, TSA and replay owners | Provide externally pinned root/profile, complete chain, leaf signature, verifier release/lock, signed trusted-time and revocation responses, and fresh nonce/sequence/replay receipts. Local hashes, OS time, stores, tests and prior receipts are forbidden substitutes. |

## Recheck command contract

When a real external bundle is supplied, preserve its exact received bytes and run one
fresh, read-only recheck from `D:\006-Programing\LMC\FusionConceptAI`:

```powershell
git rev-parse HEAD
git rev-parse HEAD^{tree}
git status --porcelain=v1 -uall
git diff --no-ext-diff --binary
git diff --cached --no-ext-diff --binary
git hash-object --path <each of the six frozen source paths>
git rev-parse HEAD:<each of the six frozen source paths>
Get-ChildItem -Force -File -Recurse D:\006-Programing\LMC\local_spool,D:\006-Programing\LMC\response,D:\006-Programing\LMC\anchors,D:\006-Programing\LMC\local_receipts,D:\006-Programing\LMC\incoming,D:\006-Programing\LMC\intake
Get-ChildItem -Force -File -Recurse D:\006-Programing\LMC\FusionConceptAI\local_spool,D:\006-Programing\LMC\FusionConceptAI\response,D:\006-Programing\LMC\FusionConceptAI\anchors,D:\006-Programing\LMC\FusionConceptAI\local_receipts,D:\006-Programing\LMC\FusionConceptAI\incoming,D:\006-Programing\LMC\FusionConceptAI\intake
```

Then validate exact canonical bytes and the complete ordered EHP-01..EHP-04 bundle with
the pinned R4 structural validator, followed by the external authority adapter. The
adapter must independently establish pinned trust, chain, signature, trusted time,
revocation, freshness/replay, G2 mapping, and independent review. Only after every
required input is fresh and same-candidate bound may one authority recheck rebuild the
identity tuple. Until then the disposition remains `typed_absent -> terminal_deferred ->
no_publish`; no S3 rerun is authorized.

Raw observations, PID/UTC/exit and hashes are in `raw/scan.raw.json` and
`raw/scan_command.raw.txt`; the file hash manifest is `hash_manifest.json`.
