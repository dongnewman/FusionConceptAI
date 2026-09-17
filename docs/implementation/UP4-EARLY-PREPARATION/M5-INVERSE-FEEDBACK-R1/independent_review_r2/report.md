# M5 inverse-feedback R2 independent review

## Verdict and boundary

`pass_limited` for the repaired isolated manufactured fixture. The claim ceiling
is `manufactured_inverse_feedback/screen_only`; this review grants no UP4-01,
UP4-02, B07, B08, R, candidate, provider, solver, physical, engineering, or
formal credit.

The R1 P1 findings are closed by the current repair: nested M4-D/M5-A
snapshots are retained and revalidated; every stored algebraic and feedback
derived field is recomputed from the stored target/rhs; M5-A composition hash
is replayed; and owner/provenance ledgers are compared with canonical
projections of the nested snapshots. No new technical finding was identified.

## Fresh independent execution

From `D:\\006-Programing\\LMC\\FusionConceptAI`, the only authoritative run
sequence for this review was strictly serial: Python oracle first, then Julia
current tests after Python exit 0. Raw streams and process receipts are under
`run_1/`.

| step | command | PID | UTC start -> end | exit | semantic | stdout / stderr / combined SHA256 |
|---|---|---:|---|---:|---|---|
| Python | `python test/RuntimeV4/M4Isolated/oracles/inverse_feedback_oracle_v1.py` | 48708 | 2026-09-16T13:05:53.5202356Z -> 2026-09-16T13:05:53.6760397Z | 0 | pass | `183b4eec66a36292d4ca14cc4904bd7b4d93f8ccf5905d83cdf0a2d960200647` / `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` / `183b4eec66a36292d4ca14cc4904bd7b4d93f8ccf5905d83cdf0a2d960200647` |
| Julia | `julia --startup-file=no --history-file=no test/RuntimeV4/M4Isolated/manufactured_inverse_feedback_v1_tests.jl` | 113636 | 2026-09-16T13:06:14.9854789Z -> 2026-09-16T13:07:33.4576993Z | 0 | 203/203 | `cb2f0cc2005b65d92d317b60ca26f230aef8d22b0ae52e6213fc3ad9f0d009bb` / `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` / `cb2f0cc2005b65d92d317b60ca26f230aef8d22b0ae52e6213fc3ad9f0d009bb` |

The exact Fraction oracle remains independent of Julia/package imports. It
reports target `(2/3,1/3)`, recovered `(alpha,beta)=(2,1)`, determinant `3`,
eigenvalues `(1,3)`, margin `1/3`, round-trip `(0,0)`, seeds `[0,1,2]`, and
feedback deletion response `(1/2,0)` with delta `(1/6,1/3)`. The canonical
oracle payload hash is `0664f4a8d794c32046168f7890ee4b54f48e9b2caa8a3066c5670eb3c38a31a8`.

## Repair and corruption review

Static review of `ManufacturedInverseFeedbackV1.jl` confirms:

* `m4d_upstream` and `m5a_upstream` are typed retained snapshots and each is
  revalidated with exceptions converted to `invalid_upstream`.
* Source/test/oracle identities are checked against frozen constants and the
  nested M4-D/M5-A source hashes/typed D identity.
* `manufactured_auto_composition_hash(m5a_upstream)` is recomputed and compared
  to the stored composition hash.
* Owner and provenance fields are projected from nested snapshots and compared
  as complete canonical ledgers.
* Target-to-parameter recovery, matrix, rhs, response, determinant, eigenvalues,
  margin, residual, seed ledger, deletion response/delta, and response-changed
  flag are all recomputed exactly with `M4RationalV1` and mismatches are typed.

The archived repair probe was independently counted from its raw stdout:
25 `PROBE ... typed_failure` records and zero `PROBE_EXCEPTION` records. It
covers 17 outer stored-derived mutations, four nested M5-A hash/identity/
owner/provenance mutations, two nested M4-D owner/provenance mutations, and
two joint owner/provenance mutations. The probe recomputes the M5-A composition
hash as `722e59e841d6551fe9001e1279266e1aaf5a798ca0d16625d5a4fd81a59ab694`.
The current `203/203` test run contains the same repair regression controls;
the probe raw and archive are retained by integration and were not relabeled.

## Integration, history, hashes, and scope

The current repair integration has two strict Python-oracle then Julia-test
replays. Both Python runs exit 0 with identical raw hash
`183b4eec66a36292d4ca14cc4904bd7b4d93f8ccf5905d83cdf0a2d960200647`; both
Julia runs exit 0 with `203/203`; every stdout/stderr/combined stream has a
byte-identical archive copy. The old R1 `103/103` package remains preserved as
historical context. Parent wrong-sequence attempts and the capture timeout
(including PID 56012 with no observed exit/raw) remain non-authoritative. Repair
probe path-resolution and parse failures are retained as setup failures and are
not promoted; the parse failure occurred before source execution. No failed or
timed-out run is counted as current authority.

Recomputed current frozen input hashes are:

* M5 source, 26,255 bytes: `f0dcf8aa0dc199a4e3404ecec1a4f516b899e1cfd523454d698f9afe91553976`.
* M5 test, 15,357 bytes: `f2279400356a786c83a13ad3f82400af052e64f5bbc8ceefbf0e8119e6903ea2`.
* Python oracle, 5,811 bytes: `6e13536aabb62f039bffe6c286e11323347b86b4d3c146270f38e8bf8129d0ab`.
* Frozen M4-D source/test/oracle: `ec7e82e282f1d1292ddd4b7902e4ced641d926af82119298267011d304a55785`, `1eb0e26e79b9899cc5a3cb2742545cbaa811fa6683fdcfa1ee4dd31dff081686`, `9ca3c1c012690c7c06579d0ab5ffd274666e340c900c59e49f7a93408a0fcbe3`.
* Frozen M5-A source/test/oracle: `e6262a11ca47f527dfa67f08974febfd69a0334e1c64baeec7657249f0e1945a`, `42562f02370f8f2e32c8e0254e0f480d69e598be747aae9898c3fc4d013b2a08`, `e9f13fc57a59efa78dd131dfc3fde7433c21d6172dc2d81f03c034c4be13084c`.
* Shared `src/FusionConceptAI.jl`, `src/Canonical/CanonicalJSON.jl`,
  `Project.toml`, and `Manifest.toml`: `e3fa8638ed9c5c5f468ae9a8f797416f2bec19b432cc10a9c1aea81ec3460783`,
  `612edaeb822c1beeff44f7134497426fd0c8ff1eea9c16a651421e2c63f8ab93`,
  `923b78938e12c27e836b269d71a539ae7bb292c9fe9f8cb92f9f9a8cea1370e2`,
  `85074b7a5bd543c0b4155f44db0733d21d53cfd0bf4c2de6704dc858357717e7`.

Shared entry, default registry, project/manifest, candidate/provider/solver,
and evidence-authority paths were not changed. Static prohibited-scope scan of
the M5 source finds no optimizer, real reference, candidate package, provider,
solver, or engineering-evidence path. Checkout HEAD observed is
`b2c04d8339774635aaecd73651efcdb101e01b5d`.

The delivery role record declares five pairwise-distinct labels (source,
test/oracle, integration, documentation, independent review), but it does not
record actor IDs. Thus role separation is consistent and the review role is
distinct by assignment, while actor-level pairwise identity is documentary
rather than independently cryptographically proven.

