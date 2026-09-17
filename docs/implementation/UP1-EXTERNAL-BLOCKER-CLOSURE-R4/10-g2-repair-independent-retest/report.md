# UP1 external-blocker closure R4 — G2 repair independent retest

## Decision

**Repair verdict: `pass_limited`.**  The frozen repaired implementation
passed two complete serial lanes.  Each lane ran the existing unit suite
(`15 tests`, exit `0`) followed by the existing adversarial probe (exit `0`).
All five previously observed fail-closed gaps now returned
`decision=fail_closed`, with `resolution=fail_closed`, `finding=false`,
`no_publish=true`, and `formal_credit=none`:

1. duplicate graph endpoint pair with a different `issued_at`;
2. duplicate mapping endpoint pair with a different `issued_at`;
3. unknown profile status token;
4. conflicting R3 `g2_mapping` / standalone `mapping` aliases; and
5. forged top-level `source_identity_sha256`.

**External-closure verdict: `fail_limited`.**  This is local structural
evidence only.  The R3-compatible positive fixture remains
`accepted=false`, `decision=terminal_deferred`, `resolution=terminal_deferred`,
`authority_verified=false`, `no_publish=true`, and `formal_credit=none`.
No external issuer, signature, trust root, trusted time, revocation service,
or publication authority was inferred.

## Reproducibility evidence

The complete machine-readable record is
[capture_manifest.json](capture_manifest.json).  It records capture and
child PIDs, UTC windows, exit codes, stdout/stderr/raw SHA-256 values, and
per-run adversarial JSON.  The two raw combined hashes differ only because
the runner embeds PIDs, UTC timestamps, and timing; `semantic_pass=true`
asserts the stable acceptance facts rather than requiring byte-identical
run logs.

The raw artifacts are:

- [run_1.raw.txt](raw/run_1.raw.txt) and its `.stdout.raw.txt`,
  `.stderr.raw.txt`, `.pid.txt`, `.utc.txt`, `.exit.txt`, and `.sha256.txt`
  companions;
- [run_2.raw.txt](raw/run_2.raw.txt) and the same receipt companions.

## Frozen inputs and boundary

[freeze_manifest.json](freeze_manifest.json) records SHA-256 hashes for the
three G2 implementation files, the three existing test/probe runner files,
and the prior 07 report/raw evidence.  The capture script writes only this
directory.  It does not modify `tools/`, `test/`, the R3 implementation, or
the prior 07 evidence.

The result closes the five repaired local predicates with bounded,
independent evidence.  It does not grant external authority, production
admission, formal credit, or any wider UP1/R01–R10 closure.
