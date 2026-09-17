# UP1 R2 external handoff independent review R1

## Decision

`pass_limited`. The 19-external-handoff package is a preparation-only,
receipt-driven handoff. It does not claim an external party, endpoint,
credential, trust anchor, response, AD, S3 run, or formal UP1 credit.

The four EHP packets cover the R1 register set losslessly: 26/26 absence IDs,
unique in the crosswalk and in packet ownership. Every unknown external owner,
name, endpoint, key, anchor, certificate, receipt, time source, and credential
is represented as `typed_absence` (or an explicit no-secret/not-requested
control). The templates are strict JSON with no duplicate keys/non-finite
values, and the literal scan found no URL, email, credential, private-key, or
secret material.

## Independent checks

* Manifest recomputation: all 20 listed files have matching bytes and
  lower-case SHA-256 values.
* The package's `raw/hash_check.txt`: 19 non-self entries all match; the
  manifest and cleanup inventory are excluded by the declared policy.
* Cleanup exact set: 22/22 declared files present, with no extra or missing
  file under `19-external-handoff`.
* Strict JSON parsing: 11 JSON files parsed with duplicate-key and
  non-finite-value rejection enabled.
* Absence coverage: 26 unique request crosswalk IDs, 26 unique responsibility
  IDs, and 26 unique IDs reconstructed from the three R1 registers; sets are
  equal. Packet assignment is also 26/26 unique.
* All four packet records and five input templates are `typed_absence`; every
  template carries a `not_sent` control (the common template places it under
  `delivery.not_sent`). Packet roles remain typed absence and each packet has
  explicit accept/reject/recovery rules.
* Formal route is identical across overview, responsibility, schedule and
  cleanup records: `T0 -> authority_recheck -> T1 -> T2 -> aggregate ->
  UP2-00 -> UP1-04B -> UP1-04 -> UP2-01`.
* PowerShell parser succeeds. AST command names contain only `Write-Output`;
  the script is print-only and has no network, send, AD, S3, credential, or
  privilege-elevation operation. The script itself was not executed.
* The declared baseline HEAD resolves to
  `b2c04d8339774635aaecd73651efcdb101e01b5d`; unrelated dirty files were not
  changed.

## Boundary and recovery review

The packet contracts require independent role separation and bind request,
candidate/source revision and version, canonical object digest, expected
context, trust anchor, trusted time, nonce, sequence and idempotency. EHP-02
requires externally pinned project PKI/revocation/time/replay evidence; EHP-03
requires same-candidate G1/G2/G3 and four-axis closure; EHP-04 requires full
runtime/import/lock/binary/SBOM/license/origin/recipe closure and keeps the
foreign-owner fixture `not_executed` when unavailable. The responsibility and
recovery matrices preserve owner/channel/anchor/receipt ownership, explicit
typed-absence or fail-closed decisions, no privilege escalation, and repair
conditions after source, environment, policy, or key changes.

The schedule permits parallel packet preparation but preserves the complete
formal sequence. Missing or unverifiable external material remains
`typed_absence/terminal_deferred` or `fail_closed`; local intake, TEST_ONLY,
historical receipts, and packet completion cannot promote authority. The
package remains `pass_preparation_only`, with no external send, network, AD,
S3, credentials, or parent-goal completion.

## Scope and claim ceiling

This is an independent package/document/command audit only. `pass_limited`
does not attest any external identity or authority, does not execute a
handoff, and grants no T0/T1/T2, B00/B04, UP1, R01-R10, or parent credit.
