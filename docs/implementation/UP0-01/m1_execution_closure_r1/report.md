# M1 exact execution-input closure r3

Status: review_pending; claim ceiling is execution_input_reproducibility_preparation. Actual worker: gpt-5.6-luna / high. R3 is a point repair responding to independent review; R1/R2 and reviewer files remain untouched.

## Provenance and frozen inputs

AD55 is absorbed by reference only. HEAD is b2c04d8339774635aaecd73651efcdb101e01b5d on main with index SHA256 6fb570961008194812a3c260d0c2be840800271fe82a1820d7760459bfddb8e0. Six HEAD-bound source owners are recorded with canonical bytes, canonical SHA256, HEAD blob OID, and filtered working OID in the execution manifest and R2 owner raw. The three G1/G2/G3 SourceAuthorityFactoryV1 files are separately recorded as dirty AD56 execution inputs; their working SHA256 and filtered OIDs are not substituted for HEAD provenance.

## R3 receipts

The six historical R2 commands are mirrored without changing raw files in `archive/repair_r3/command_receipts_r3.json`, with exact command/cwd, exit_code, UTC bounds, raw paths/hashes, input/output/artifact hashes. A new read-only command_07 proves the exact M1 probe path is absent and untracked; its stdout/combined SHA256 is c3be601b1b0d1b32c6d72f0cc803e6f4d57175d918d79f124fc0fb939c0629ed and stderr SHA256 is e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855.

The historical AD55 F0/S2 conclusions and S2 run2 PID 83504, exit 0, stdout SHA256 81036d5a60f5c15455c9e80915b0a11c432000e91d2ee07875f67b93aa16a14d, stderr SHA256 e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855 are retained by reference. Current R2 cannot backfill the historical pre-run input proof and creates no fresh S3 evidence.

## Static closure and environment

The bounded closure is the AD55 S2 probe/harness, six owners, three dirty factories, and the statically named G1/G2/G3 loader components. Static scan found probe imports SHA/JSON3/Dates/FusionConceptAI, five explicit Base.include targets, twelve loader component paths, 47 enclosing-module include directives, and zero factory include directives. Runtime package resolution, Julia method dispatch, and external binary/dependency provenance remain unknown_deferred.

PowerShell 7.5.5, Python 3.13.5 and Julia 1.10.5 paths/version/file hashes are recorded. Julia was not executed because of the M1 scoped work-order/review prohibition; this is not a user-level blanket prohibition. No Julia/DESC process was started.

## Checkout, claims, and handoff

At capture, git status reported 27 tracked modified paths and 7090 untracked paths; pre-existing dirty paths are protected and no outside file was modified, staged, reverted, committed, deleted, or cleaned. The task-owned probe scratch file is absent.

Fresh S3 trust-root/source closure is not present: record typed_absence/terminal_deferred, named external input/owner/recovery conditions, and do not regenerate AD evidence while inputs are unchanged. T0 → recheck → T1 → T2, B00/B04, all R01–R10, source authority, provider, candidate, mesh, solver, engineering, physical, search, and L4 credit remain open/zero. A different Luna must independently review R2 before any gate.

Products and exact ownership are listed in cleanup_inventory.json; R1/R2 and independent_review_r1/independent_review_r2 files are reviewer-owned read-only references and are not in the implementer cleanup set.
