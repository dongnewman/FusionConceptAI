# Static handoff report (R3)

Date: 2026-09-18 (Asia/Shanghai)

## Scope and status

| Item | Result |
| --- | --- |
| T0 runtime | unresolved dependency; not run |
| T1 | `prepared_not_executed` |
| Claim ceiling | `contract_only` |
| Package/runtime credit | none |
| Existing dirty worktree | preserved; no unrelated paths edited |
| Commit | none |

Only the two additive source declarations, this directory's documentation, and
the static-QA script are owned by this handoff. The files are excluded from the
main module, so this change does not alter current runtime behavior.

## Static evidence

`static_qa.ps1` completed with:

```
STATIC_QA=PASS
STATIC_NEGATIVE_MATRIX=12
SCOPED_TRAILING_WHITESPACE=PASS
RUNTIME=NOT_RUN
T0=UNRESOLVED
T1=PREPARED_NOT_EXECUTED
```

SHA-256 (captured after the final static-QA pass):

| Path | SHA-256 |
| --- | --- |
| `src/Contracts/CandidateStatePackageV5Next.jl` | `9CB2ECF3D301B0DACE4AB043323BE109D36C64B98A35D6699674730CC43A455D` |
| `src/GenomeV5/Integration/VNextGenomeV5Integration.jl` | `A33DE469580EA4B6376BFF00AD827E2F0750B99E06BAC572F7C21193EA7123FC` |
| `README.md` | `8A285E51352262D88CE06D34D1C92042274BF1EF8C4F6EB7006E46B9D4949114` |
| `static_qa.ps1` | `5C76057AF04A70DF38E6FEEB2946B9DD63ECEB7AFD4EAF595DFD1F0754BEF932` |

R3 specifically closes the six independent rejection classes: factory-axis
projection confused with outer axes, package-owned schema/canonical/profile
hash omission, transitive open T0 body/output retention, receipt self-hash
without canonical-envelope reconstruction, incomplete feedback/child joins,
and label-erased identity that dropped absent-child metadata. The matrix is
executable as a static PowerShell assertion set only; it fabricates no runtime
success.

## Review plan

Before any T1 runtime inclusion, independently verify the concrete T0 result
type, its prior bundle bytes/hash and closed output projection, exact G1/G2/G3
and G3 child arity, outer/local versus per-layer factory axes, four-axis order,
source/declaration byte/hash/locator joins, reconstructed receipt envelopes,
feedback body target joins, label-erased semantic identity including absent
metadata, and fresh migration receipt equality. Re-run all 12 negative cases
with no recheck, stale/contradictory gates, mismatched bundle/candidate,
mutated envelopes, and every projection/hash mismatch; every case must return
without a package. Keep T0 unresolved and T1 unexecuted until that review and
fresh runtime evidence exist.
