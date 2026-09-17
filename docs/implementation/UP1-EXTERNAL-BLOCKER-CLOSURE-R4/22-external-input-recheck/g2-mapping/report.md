# UP1 R4 G2 mapping external-input recheck

## Verdict

`typed_absent -> terminal_deferred -> no_publish`.  At the fixed checkout
`b2c04d8339774635aaecd73651efcdb101e01b5d`, no new authoritative G2 mapping,
candidate/source identifier package, versioned signed mapping, or bidirectional
reverse-binding material was found.  `usable=[]`; `untrusted` is limited to
local software, historical bookkeeping and `TEST_ONLY` fixtures; the required
external G2 material remains `typed_absent`.

This is a bounded offline observation.  It does not claim that remote or
unlisted channels are globally empty, and it does not use a heuristic mapping
or local factory output as a substitute for an authoritative input.

## Fixed revision, boundary and controls

- Repository: `D:\006-Programing\LMC\FusionConceptAI`
- Fixed HEAD: `b2c04d8339774635aaecd73651efcdb101e01b5d`
- Recheck observation: `2026-09-17T04:09:20Z` UTC
- Workspace roots checked: `D:\006-Programing\LMC` and
  `D:\006-Programing\LMC\FusionConceptAI`
- Frozen relative paths checked at each root: `local_spool`,
  `local_spool\incoming`, `response`, `anchors`, `local_receipts`, `incoming`,
  `intake` (14 root/path pairs; all absent, zero files)
- No Julia, DESC, S3, network request, intake, credential use, signature
  generation, source edit or test-suite run occurred.  The only executable
  probe was the dependency-free Python R4 adversarial probe, which reads the
  validator and synthetic test payloads without editing them.

The exact path scan is retained in `raw/workspace_paths.raw.txt` (PID `113104`,
exit `0`, raw SHA-256
`2063E0BF22A55B976FF7ACE509419DA158D466689DDE2F15FE36AF53E5D3B7CE`).

## Evidence classification

| Class | Observation |
|---|---|
| `usable` | `[]`; no external EHP-03 response, trust anchor, signed receipt, or candidate-bound bundle exists in the checked intake scope |
| `untrusted` | R4 validator/prototype, local G2 source factory and declaration output, historical AD/R1-R4 records, local receipts, and `TEST_ONLY` positive/adversarial fixtures; these cannot provide external authority |
| `typed_absent` | `g2_authoritative_mapping`, source-version binding, candidate lineage, four-axis set, issuer/profile, trust root/chain, signed mapping, trusted time, revocation, replay and independent-review receipts |

The R4 contract inventory and root acceptance independently record 26/26
external inputs as `typed_absent`, `usable_external_inputs=0`,
`new_ad=false`, and `s3_rerun=false`.  Local files whose names contain G2,
mapping, authority or receipt are historical/software evidence only; filename,
mtime, Git state, test exit, self-attestation, system trust-store presence or
an inferred join is not an authoritative mapping.

## R4 implementation check

The inspected implementation is
`tools/up1_external_closure_r4/g2_mapping/validator.py`, SHA-256
`69079110F66C07CF781D473CCC69B251A7B9A4605DE8870D659016BF83E26D00`.
Compared with the earlier R4 independent report, this local file has a newer
hash and now statically contains fail-closed checks for duplicate graph/mapping
endpoint pairs, unknown status tokens, conflicting aliases and the top-level
source digest binding.  The structural validator still deliberately reports a
present synthetic payload as `terminal_deferred`, with
`authority_verified=false`, `no_publish=true` and `formal_credit=none`; it
does not verify cryptographic signatures, trust roots, trusted time,
revocation or an external issuer.

The local `src/GenomeV5/G2/G2SourceAuthorityFactoryV1.jl` is likewise not an
external mapping source.  Its static contract is a local typed source locator
and declaration path with `trusted=false`,
`candidate_identity_created=false` and
`final_candidate_or_package_hash_created=false`; it has no external signature,
trust-root, trusted-time, revocation or authoritative reverse-mapping input.

The read-only adversarial probe (PID `109180`, parent PID `111408`, UTC
`2026-09-17T04:04:30.249026Z`–`2026-09-17T04:04:30.249875Z`, exit `0`) found
zero gaps: all five malformed cases returned `fail_closed`.  Its exact JSON
output is `raw/g2_adversarial_probe.raw.json`, SHA-256
`966D4A2A6C795C1B522F2450E8DFA6C42CAC08B78610ED27C15130793ECAAD8F`.  This is
software-boundary evidence only and does not alter the external verdict.

## Responsible parties and recovery condition

The missing material is owned by the external G2 mapping authority/attestor,
with source/candidate authority, project PKI/trust administrator, verifier /
policy owner, TSA/time owner, revocation owner, replay-ledger owner and an
independent reviewer responsible for their respective evidence.  Recovery
requires one fresh, same-candidate/source bundle containing:

1. exact forward and reverse mapping rows, candidate/source/G2 identifiers,
   namespace, version and effective interval;
2. mapping digest and an unambiguous decision, with issuer/profile identity;
3. a real external signature and complete pinned trust chain;
4. independently verifiable trusted-time, revocation, freshness/replay and
   authority receipts; and
5. reverse evidence edges bound to the same candidate/source plus the complete
   four-axis set (one missing axis keeps the set absent).

The raw received bytes must be preserved.  Any source, candidate, G1/G2/G3,
axis, policy or trust change requires rebuilding the candidate identity and all
downstream mapping/receipt hashes.  A malformed, conflicting, foreign, stale,
revoked, replayed or digest-mismatched bundle is `fail_closed`; missing bytes
remain `typed_absent`, never repaired by inference.

## Executable follow-up when material arrives

1. Freeze and record `HEAD`, tree, full dirty/untracked status and exact raw
   EHP-01..EHP-04 bytes; rescan the 14 frozen paths and record any new path.
2. Verify candidate/source/G2/four-axis identity and both mapping directions;
   recompute every row, graph and bundle digest with the pinned validator.
3. Independently verify the external trust root, chain, signature, profile,
   trusted time, revocation, freshness/replay and reviewer receipt.  Keep
   `untrusted` separate from `usable` until all gates pass.
4. Rebuild the identity tuple from the fresh bytes and run exactly one fresh
   authority recheck.  Do not run S3 merely because local code or a mapping
   fixture changes; under the unchanged-input observation,
   `new_ad=false`, `s3_rerun=false`, `formal_credit=none`.

Raw static observations and file hashes are listed in
`raw/static_implementation_scan.raw.txt` and `hash_manifest.json`.
