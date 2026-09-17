# UP1 R4 freshness/replay external-input recheck

## Verdict

`UNCHANGED_TYPED_ABSENT` at fixed HEAD
`b2c04d8339774635aaecd73651efcdb101e01b5d`. The read-only audit found no
new usable OCSP/CRL response, trusted timestamp, nonce/challenge authority
response, authenticated external replay ledger, verifier policy/root, or
authoritative response. The prior external snapshot remains `26/26
typed_absent`, `usable_external_inputs=0`.

Therefore `new_ad=false`, `s3_rerun=false`, and `formal_credit=none`. No
authority response was generated, no source or test implementation was
modified, and no Julia/DESC/S3/network operation was run. Raw scan metadata,
PID, UTC, exit, and hashes are in `raw/scan.json`, `raw/{pid,utc,exit}.txt`.

## Scan boundary and observations

Both workspace roots (`D:/006-Programing/LMC` and
`D:/006-Programing/LMC/FusionConceptAI`) were checked read-only at the seven
contracted intake locations (`local_spool`, `response`, `anchors`,
`local_receipts`, `incoming`, `intake`, including `local_spool/incoming`).
All 14 root/path pairs were absent. No expected external payload basename
(`ehp01..04`, chain/leaf, trust anchor, revocation, trusted-time, replay
policy/ledger, or source snapshot) existed anywhere in the workspace.

The R4 freshness implementation and independent test/runner are byte-identical
to the frozen R4 freshness receipt:

| file | bytes | SHA-256 |
|---|---:|---|
| `tools/up1_external_closure_r4/freshness/core.py` | 33786 | `972f4d8aaa886af4942d9c0aadafc4eab9150327e473132399b6a5300cd5ad8c` |
| `test/up1_external_closure_r4/freshness/test_freshness_independent.py` | 17569 | `46a3f230117e1003ac5d0ecb92021d217be0617e56978b90b755c482d18fb5a9` |
| `test/up1_external_closure_r4/freshness/run_independent.py` | 2462 | `a7ebbf3fe54899f5ee64553880d8e329b20ca3391e6a73a768cdbd5740f0045c` |

## Evidence classification

`usable=0`: no bytes from an external owner/channel were found. The expected
R4 intake paths and all external material IDs remain absent.

`untrusted`: the R4 positive payloads are in-memory test fixtures and the
freshness implementation only consumes caller-supplied receipt-shaped data;
historical/local AD-49 source-authority records are local artifacts and
explicitly carry `status=typed_absent`, `terminal_deferred=true`, and false
external-attestation-chain fields. These are useful structural/negative
evidence only, not external authority.

`typed_absent`: all 26 external requirements in the frozen R4 inventory,
including `revocation_source`, `trusted_time`, `replay_policy`, `verifier`,
`trust_root`, `signed_receipt`, and `authoritative_channel`, remain typed
absent. The absence is bounded to the checked local paths; remote/unlisted
channels were not queried.

## Freshness/replay implementation boundary

The implementation is an offline fail-closed prototype (`core.py:1-6`). It
validates receipt structure, canonical digest, caller-provided signature
booleans, trusted-time digest/nonce/challenge/interval fields, injected OCSP/
CRL-shaped fields, and a durable HMAC/CAS/lock replay state
(`core.py:173-279`, `290-466`). It has no network client and returns
`formal_credit=none` and `no_publish=true` even on a local positive result.

The implementation does not itself establish a production PKI/TSA trust root,
cryptographically verify external OCSP/CRL/TSA bytes, prove an external key
provenance/ACL, or obtain a channel ACK. The local tests therefore remain
untrusted software evidence. A local replay ledger commit is not an external
replay-authority receipt, and a caller-supplied `signature_valid=true` is not
an authority signature.

## External responsibility and recovery

| Missing input | Responsible external owner | Required recovery |
|---|---|---|
| signed OCSP/CRL plus issuer/serial/window and verification receipt | CA/attestor PKI owner | deliver fresh raw response bytes, issuer binding, signature/chain/revocation result, trusted-time binding, and retained raw hash |
| signed RFC3161/equivalent token | independent TSA/time-policy owner | deliver token, policy/chain, exact message imprint, nonce/challenge, validity interval, and independent verification receipt |
| nonce/challenge/sequence/idempotency policy and authenticated ledger | protocol/replay-ledger owner | issue an authorized fresh request and retain durable ledger/ACL/key-provenance plus acceptance/rejection and replay receipts |
| pinned verifier/profile/trust root and authoritative ACK | project PKI/verifier/channel owners | publish versioned hash-pinned policy/root, complete chain, and fresh signed channel ACK over exact bytes |

After all mutually bound external packets arrive, an independent reviewer must
recompute raw-byte hashes and replay the verifier/revocation/time/ledger checks
against the exact candidate/source scope. Until then retain `terminal_deferred`,
do not promote local passes, do not issue a new AD, and do not rerun S3.

## Recheck steps

1. Re-scan only the contracted intake paths and record raw files, owner/channel
   identity, byte hashes, signatures, trusted-time and revocation receipts.
2. Reject local fixtures, system stores, historical receipts, URI-only claims,
   or caller-supplied booleans as external evidence.
3. Verify the complete candidate/source/sequence/nonce/challenge tuple and
   durable ledger CAS/replay result with a fresh request; any missing packet
   remains typed absent and any contradiction fails closed.
4. Repeat the independent freshness and trust-chain checks, preserve raw
   stdout/stderr/PID/UTC/exit/hash receipts, then request a separately
   authorized root decision. Only that decision can alter the external gate.
