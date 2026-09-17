# UP1-04A r12 independent review

`verdict: pass_limited`. This is an independent Luna/high review of the r12
A-only structural snapshot. The author's UP1-04A record remains
`status: review_pending`, `accepted: false`, and `claim_ceiling: none`.

The current source, test, fixture, author acceptance record, author evidence
manifest, protected dirty manifest, and all 61 manifest output hashes were
checked before execution. Every hash matched the r12 evidence manifest. The
protected `test/runtime_v4_test_manifest.json` remained
`3221a99a3ea135324206e5b2c47ebc23a38514af57f6a51ecd8e8797e8da7f6a`.

The independent run used the exact A-only command below after confirming no
Julia or DESC process was active:

- Command: `julia --startup-file=no --project=. test/GenomeV5/UP1-04/up1_04a_integration_tests.jl`
- Start: `2026-09-14T06:42:30.5850170+08:00`; parent PID `60768`.
- End: `2026-09-14T06:44:14.6429165+08:00`; exit `0`.
- Result: `UP1-04A additive shared entry`, 45/45; stderr was empty.
- Runtime hashes: package `67bf32d7d55b06eac1f495a50fcb1620babd48d9ebbce14867f854f32b3064a5`, receipt `aeae42aee6a3720b0e8434340ff57f199a4d8bd4767d0fd29d314bb426ec19a0`, receipt-after `31f3390f62193e274b781c5e61d15ffd7c6097e5fab160000f36af47106542b0`.
- Raw evidence: [command](fresh_a_focused.command.txt), [stdout](fresh_a_focused.stdout.txt), [stderr](fresh_a_focused.stderr.txt), [exit](fresh_a_focused.exit.txt).

The reviewed controls are supported by the following current source and test
locations:

- `src/Contracts/CandidateStatePackageV5.jl:184-215` rejects resolved packages,
  non-`none` claims, empty fail-closed errors, invalid structural states, and
  invalid identities. A valid package must pass the integration gap checker.
- `src/GenomeV5/Integration/GenomeV5Integration.jl:146-188` verifies the real
  public refs, schema/canonical authority, G2 candidate binding and component
  hash, G1/G3 candidate identity, child refs, axes, feedback target refs, and
  receipt-after identity. Feedback mismatch errors are retained and rejected.
- `src/GenomeV5/Integration/GenomeV5Integration.jl:257-265` derives the gap
  contract and rejects duplicate gaps as well as reordered or unexpected gaps.
- `test/GenomeV5/UP1-04/up1_04a_integration_tests.jl:93-110` constructs two
  candidates from the same child plan and checks distinct candidate-derived G2
  URIs and hashes, then rejects the historical `urn:fusion:g2:*` ref.
- `test/GenomeV5/UP1-04/up1_04a_integration_tests.jl:123-158` exercises forged
  identity, forged child refs, forged feedback, and a wrong feedback target;
  the latter must return `structural_status == :fail_closed` with the fixture
  expected error. `fixtures.json` is parsed at test line 6 and its negative
  cases are consumed at lines 67-69 and 157-158.
- `src/Contracts/CandidateStatePackageV5.jl:128-156` rejects placeholder,
  synthetic, missing-digest, and non-v4 legacy refs while recording ordinary
  typed V4 refs as unverified terminal-deferred records. Test lines 165-180
  cover deferred legacy, placeholder, empty mapping, and stale/foreign receipt.

Historical classifications were preserved: r8 is `program_exception`, exit 1,
caused by the recorded `startswith(::String, ::Tuple{String,String,String})`
construction error at the legacy-ref path; r10 and r11 remain `unknown` because
only stdout/stderr exist and no exit artifact was sealed, even though their
stdout reached 44/44 and 45/45 respectively. The author r12 log and this fresh
run are the first two complete r12 A-only exit-0 records.

The limited pass covers only the additive V5 shared entry and structural,
same-candidate join controls exercised by the A focused fixture. It does not
accept or credit UP1-04B, B00, B04, provider invocation, mesh execution,
engineering validation, physical validation, or R01-R10 progress.
