# UP1 external blocker closure R4 — authoritative intake independent test

## Verdict

`fail_limited`. This is an offline local software test only: `formal_credit=none`,
`authority_credit=false`, and `no_publish=true`. No network, message API,
external acknowledgement, credential, AD/S3, candidate promotion, or authority
claim was used. The frozen implementation under
`tools/up1_external_closure_r4/authoritative_intake/` was not modified; its
`intake.py` SHA-256 stayed
`d6cb0a479872dc9a72c47798c90518530ce87c7b2adde46d2ea835f4c704fe8b` before
and after both runs.

## Serial focused rerun

Command:

    python -B -m unittest discover -s test/up1_external_closure_r4/authoritative_intake -p test_*.py -v

Two serial processes both exited `1`, each ran 14 tests, with 2 failures and
2 privilege-limited skips. Run 1 PID `49520` ran from
`2026-09-17T01:31:05.6546772Z` to `2026-09-17T01:31:06.6921316Z`; stdout
SHA-256 is the empty-stream digest
`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`, and
stderr SHA-256 is
`74be8c14fa1084574a43f310fccc5cb9a41367bd2bcce20dfb030e1963c2ebba`.
Run 2 PID `62552` ran from `2026-09-17T01:31:06.7080219Z` to
`2026-09-17T01:31:07.7281275Z`; stdout has the same empty-stream digest and
stderr SHA-256 is
`99b151638ef416313d90809f267933d1b54c1eaec8b7d0397421c38e00ffa2bc`.
Raw streams and process receipts are in `raw/`.

## Coverage and observed result

The suite covers channel identity/policy mismatch, request-channel mismatch,
`typed_absent`, `typed_unverified` even after a local verifier returns true,
exact original-byte hash/size/locator binding, different-byte collision,
equal-byte idempotence, hardlink aliases, reparse/symlink components, lexical
path traversal, all-or-reject packet-set acknowledgement, and no external
send/authority claim. The independent JSON probe recorded 8/10 passing
records (PID `18200`, exit `1`, UTC
`2026-09-17T01:31:20.6718200Z`–`2026-09-17T01:31:21.6945524Z`, stdout SHA-256
`461407049f848176e9566cdc316c634a0b3dddc084604ebae7088ccb4e8ad133`).

Two security-boundary failures remain:

1. A pre-existing digest-named hardlink to a separately mutable inode is
   accepted as an idempotent replay. `_atomic_create` checks only bytes and
   does not reject `st_nlink > 1` (implementation lines 241–247 and 261–263).
   This violates the claimed immutable-object boundary.
2. `_ensure_regular_parent` accepts a lexical `root/../escape` path because
   `Path.absolute()` is checked lexically rather than after component
   normalization/resolution. The probe observed `accepted` and created the
   sibling directory; the expected fail-closed result is `path_escape`
   (implementation lines 214–227).

The Windows host denied symlink creation with WinError 1314, so the two
symlink/reparse probes are recorded as skips rather than evidence of safety.
The implementation's static `lstat` checks were not promoted into a runtime
claim. These failures and skips keep the result `fail_limited`; no external or
formal conclusion follows.

Independent probe JSON: `raw/probe.stdout.json`; probe stderr is empty. The
test and probe source files are outside the frozen implementation directory.
