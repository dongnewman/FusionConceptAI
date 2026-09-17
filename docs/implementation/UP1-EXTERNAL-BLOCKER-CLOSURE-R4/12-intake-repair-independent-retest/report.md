# UP1 external blocker closure R4 — intake repair independent retest

## Verdict

The repaired local intake boundary passes the focused contract suite twice and
passes a repair-specific independent boundary oracle. This remains
`formal_credit=none`, `authority_credit=false`, and `no_publish=true`: all
activity was offline/local, with no external send, acknowledgement, network
message, credential, AD/S3 operation, or authority claim.

The authoritative implementation and the existing 04 test/probe inputs were
frozen before execution and re-hashed after execution. The six frozen files
are byte-identical before/after; the implementation's current
`intake.py` SHA-256 is
`d8034a069a2607510689eeb88483c3a9727c6c4fd9495554f0bd78e028182280`.
The before/after freeze receipts are in `raw/frozen_before.json` and
`raw/frozen_after.json`.

## Serial focused suite

Command:

    python -B -m unittest discover -s test/up1_external_closure_r4/authoritative_intake -p test_*.py -v

Both serial processes exited `0`, ran 14 tests, and reported `OK
(skipped=2)`.

| run | PID | UTC interval | exit | stdout SHA-256 | stderr SHA-256 |
| --- | ---: | --- | ---: | --- | --- |
| 1 | 104164 | 2026-09-17T01:42:24.8578831Z → 2026-09-17T01:42:25.6611453Z | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | `9e23ffa433527bbe7cfb6902c8c9201092dd48a61ceede995fc5719c1c107689` |
| 2 | 91336 | 2026-09-17T01:42:38.4142377Z → 2026-09-17T01:42:39.1886151Z | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | `0614b963a6b53010a6e718f598d687f8d8c951be33dadb46e2b50b36059a9ea3` |

The two skipped cases are the symlink/reparse creation probes. Windows denied
creating the links with WinError 1314 (“required privilege is not held”);
this is recorded as an environment-limited skip, not evidence that symlink or
reparse attacks are safe.

Raw streams and process receipts are in `raw/retest_run_01.*` and
`raw/retest_run_02.*`.

## Adversarial probes

The existing frozen 04 probe ran at PID `49984` from
`2026-09-17T01:42:52.8811708Z` to `2026-09-17T01:42:53.6325906Z`, exited
`1`, and emitted `9/10` records. Its only red row was
`hardlink_digest_alias_rejected`: the repaired implementation observed
`immutable_alias`, while that older probe accepts only
`immutable_collision` or `reparse_path`. The hardlink was in fact rejected;
the new error code is the explicit repair code. The probe's stdout SHA-256 is
`e37b4ccec354c5702cc827e8b89b15d6c63da3c90a2e32ac45286a91857dd36b` and its
stderr is empty. This compatibility mismatch is retained rather than hidden.

A repair-specific oracle, written only under this 12 directory, then checked
the repaired predicates with their current error codes. It exited `0` with
`2/2` records (PID `108460`, UTC
`2026-09-17T01:43:53.3461555Z`–`2026-09-17T01:43:54.0537361Z`):

- A pre-existing digest-named hardlink was rejected as `immutable_alias`;
  the source and destination remained the same inode and destination bytes
  were unchanged.
- `root/../escape` was rejected as `path_escape`; rejection happened before
  mkdir, `outside_created=false`, and the spool had no children.

The repair oracle stdout SHA-256 is
`f842be15b35b07c0e4c689e6b6e9274fe99b26fd7223475903a477742deddbc6`.

Across the focused suite and probes, `typed_absent` and `typed_unverified`
remain explicit; local signature verification does not become external
verification. The packet-set contract remains all-or-reject with no partial
authority acknowledgement. The no-network probe observed
`authority_claim=false`, `external_ack=false`, and
`no_network_or_message_sent=true`.

## Scope boundary

No files under `tools/` or `test/` were edited by this retest. New evidence is
confined to this directory. The result is a local software-boundary repair
confirmation only; it is not external authority, real-channel delivery, or
physical/engineering evidence.
