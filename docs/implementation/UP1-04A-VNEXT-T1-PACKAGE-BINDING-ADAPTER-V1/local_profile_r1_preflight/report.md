# local_profile_r1_preflight

This directory is a receipt-free hardened runner package prepared at HEAD
`f7f877afd892bbfe06cac903a00abc06219f0961`.  It is definition/preflight
material only: Julia was not run and no runtime, integration, provider, AST,
or physical evidence is claimed.

The runner uses the exact package-adapter Julia command, `JULIA_NUM_THREADS=1`,
a 300-second bounded wait, one start with no retry, an atomic `CreateNew`
lock, two consecutive postflight zero observations, runner-owned process-tree
termination on timeout, and before/after byte plus SHA-256 protection for the
8-file slice, 6 key dependencies, and 6 pre-existing dirty files.

The source QA contract is static20 and the independent Python oracle contract
is oracle15.  The AST boundary is explicitly source-structure-only; it is not
an AST execution or runtime/provider claim.  The new `schema/` directory holds
the receipt schema and remains separate from any future `runtime.lock` or
`run_*` receipt.  Those outputs must be absent before the single explicit
runner attempt.
