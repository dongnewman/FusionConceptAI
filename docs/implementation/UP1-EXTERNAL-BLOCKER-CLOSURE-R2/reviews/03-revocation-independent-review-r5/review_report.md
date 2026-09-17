# UP1 R2 revocation/time/replay independent review R5

- verdict: `pass_limited_with_test_scope_deferred`
- scope: latest ACL provider/fixture repair plus regression of real Windows restricted/broad ACL and Junction paths
- claim ceiling: `TEST_ONLY non_evidence`; no production trust, UP1, B00/B04, engineering, physical, provider or R01-R10 credit
- execution: fresh Python `-B`, Windows 11, Python 3.13.5, pytest 8.3.4, no network

## Results

The focused suite completed `13 passed, 1 skipped` (the existing symlink fixture skip at test line 160). Compilation of all module Python files returned `compile_ok`/exit 0. The independent R5 ACL harness was a separate `python -B` process and used disposable temporary files only.

Pure ACL-provider checks passed with the expected classifications:

- foreign owner SDDL (`S-1-5-20` Network Service) -> `trusted_key_acl_invalid` / fail-closed;
- malformed provider shape/SID -> `trusted_key_acl_invalid` / fail-closed;
- provider absent or raising unsupported -> `trusted_key_acl_unsupported` / typed absence;
- restricted owner/DACL -> accepted;
- broad Everyone Allow -> `trusted_key_acl_invalid` / fail-closed.

Real Windows checks also passed: a restricted key was valid; Everyone, Users, and Authenticated Users ACEs were rejected; key-parent and ledger/lock-parent Junction paths were rejected as `ledger_corrupt`. This independently exercises the PowerShell ACL provider and `_reject_reparse` path checks. The focused tests additionally cover the injected malformed/unsupported provider paths.

## Test-scope decision

`test/up1_external_closure_r2/revocation_time_replay/privileged_acl_fixture.ps1` parses successfully via `pwsh -NoProfile -NonInteractive` (`parse_ok`). Static review confirms it only consumes an already-held `SeRestorePrivilege`; it contains no `runas`, `Start-Process -Verb RunAs`, `sudo`, or other elevation operation. It was not invoked to mutate a key. The prior `icacls /setowner` attempt returned Windows error 1307, so the foreign-owner dynamic mutation is explicitly `not_executed` / `test_scope_deferred`, not a claimed pass. The pure SDDL negative is the current software proof.

Under the requested “test-only execution first” decision, this deferred privileged dynamic case does not block the software component's limited fixture verdict and no P1/P2 implementation issue remains. The deferred condition must be resolved before treating the owner result as dynamic Windows-environment evidence.

## Evidence and boundaries

The main 03 manifest's source and `repair_r2` raw hashes recompute successfully and its repair raw closure includes the deferred fixture receipt. Its metadata still names the repair revision `repair-r3...` while the contract is `implemented_fixture_only_repair_r4`; this is recorded as a label inconsistency only—the referenced receipt/path and hashes are closed to repair_r2. R5 artifacts contain source/raw hashes, exact command outcomes, the `not_executed/test_scope_deferred` classification, and cleanup inventory. No implementation, test, or main evidence file was modified.

This is offline fixture-only software evidence. It does not establish production CA/OCSP/CRL/TSA authority, real trusted time, external attestor identity, or any parent UP1/B00/B04/engineering/physical gate.
