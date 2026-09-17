# M4-A equation IR independent Luna review R1

Status: `pass_limited`

Reviewer: independent review Luna `m4a_review` (`gpt-5.6-luna`, high)
Frozen HEAD: `b2c04d8339774635aaecd73651efcdb101e01b5d`

## Verdict

The frozen M4-A declaration, test harness, and independent Fraction oracle
pass this review at the bounded ceiling `manufactured_control` /
`screen_only`. The review is independent of the source implementer,
test/oracle owner, and integration/documentation owner. No product was
modified by this review. The result is not Sol acceptance and grants no
formal task or evidence credit.

## API and logic review

The standalone source exposes the declared M4-A types and API, uses no
imports/includes, and is loaded only through the isolated test harness. The
validator returns typed failures for `unknown_operator`, unit closure,
nonpositive coefficient, non-SPD coefficient, duplicate conservation owner,
missing boundary closure, foreign source reference, and non-deferred time or
multifield scope. The tests exercise every required control and the explicit
absence guards for `CandidateStatePackageV5`, `ForwardChainContextV4`, and
`RuntimeEvidenceV4` pass.

The validator correctly freezes the domain, field, operator name/version,
residual sign, coefficient terms and lower bounds, source value, six-face
closure, single conservation owner, and manufactured/screen-only provenance.
One bounded API observation is retained for later hardening: `source.owner`
is required to be nonempty but is not required to equal the conservation
owner. This does not invalidate the current A declaration because ownership
is explicit and the conservation owner is separately checked across all IR
declarations; it must not be interpreted as provider or authority evidence.

## Independent mathematics

The fresh Python oracle process uses only `fractions` and standard-library
code. Recalculation is exact:

`div(K grad(u)) = 1/10 + 1/20 + 1/30 = 11/60`;

`R = -11/60 - (-11/60) = 0`.

The emitted float residual is `0.0`, within `1e-12`. The oracle does not call
production IR, lowering, discretization, or a solver.

## Fresh serial execution

Two new child processes were invoked strictly serially in this review: Python
oracle first, then Julia test. The execution records use the PowerShell host
PID as the explicit process marker because direct invocation does not expose
the child PID; each command nevertheless launched a separate Python/Julia
executable process. All exits were zero and stderr was empty.

1. Python oracle: host marker PID `76476`,
   `2026-09-16T06:56:19.5154317Z`–`2026-09-16T06:56:19.6405836Z`, exit `0`,
   result `11/60`, exact residual `0`.
2. Julia test: host marker PID `60256`,
   `2026-09-16T06:56:40.0845595Z`–`2026-09-16T06:56:42.2353627Z`, exit `0`,
   result `42/42`.

Raw stdout, stderr, and combined output, plus their SHA-256 values, are
indexed in `manifest.json` and `validation_receipt.json`.

## Isolation, ownership, and parent gates

The source, test, and oracle hashes match the delivery, integration, and test
execution records. The four upstream roles are pairwise distinct. No shared
RuntimeV4 entrypoint, registry, Project, Manifest, candidate manifest, or
shared entry file was changed by this slice; existing unrelated dirty work is
protected and was not staged or cleaned.

This review accepts only the declaration/IR control. It is not residual
lowering, discrete assembly, topology transfer, coupling, solving, candidate,
provider, engineering, physics, B00, B04, R01-R10, or L4 evidence. B, C, and D
remain unauthorized. The formal route remains
`T0 -> authority recheck -> T1 -> T2 -> aggregate -> UP2-00 -> UP1-04B ->
UP1-04 -> UP2-01`; the 39-node DAG and all parent gates remain open.

## Recheck conditions

No external trust root, provider identity, candidate identity, or authority
was inferred. If frozen inputs change, this review is stale and requires a
new freeze and independent review. If inputs remain unchanged, do not repeat
S3 or create a new AD. Sol/root must issue a separate `accepted_limited`
decision before any B discussion; C and D require a new scope decision and
formal prerequisites.

