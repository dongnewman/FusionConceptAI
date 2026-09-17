# M5 inverse-feedback R1 independent review

## Verdict

`changes_requested`; claim ceiling remains `manufactured_inverse_feedback/screen_only`.
This review is independent of implementation, test/oracle, integration, and
delivery records. It grants no UP4-01/UP4-02, B07/B08, R, candidate, provider,
solver, physical, engineering, or formal credit.

The independent Fraction oracle and the current isolated Julia test both pass
the frozen example. The exact result is target `(2/3,1/3)`, recovered
`(alpha,beta)=(2,1)`, `det(A)=3`, eigenvalues `(1,3)`, margin proxy `1/3`,
round-trip `(0,0)`, seeds `[0,1,2]`, and beta/interface deletion response
`(1/2,0)` with delta `(1/6,1/3)`. Julia reports `103/103`.

## Independent execution

The only authoritative run in this review is strictly serial from
`D:\\006-Programing\\LMC\\FusionConceptAI`: Python oracle first, then Julia
current tests after Python exit 0. Complete process metadata and raw streams
are in `run_1/`.

| step | command | PID | UTC start -> end | exit | semantic | stdout / stderr / combined SHA256 |
|---|---|---:|---|---:|---|---|
| Python | `python test/RuntimeV4/M4Isolated/oracles/inverse_feedback_oracle_v1.py` | 40608 | 2026-09-16T12:25:02.1935120Z -> 2026-09-16T12:25:02.3714401Z | 0 | pass | `183b4eec66a36292d4ca14cc4904bd7b4d93f8ccf5905d83cdf0a2d960200647` / `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` / `183b4eec66a36292d4ca14cc4904bd7b4d93f8ccf5905d83cdf0a2d960200647` |
| Julia | `julia --startup-file=no --history-file=no test/RuntimeV4/M4Isolated/manufactured_inverse_feedback_v1_tests.jl` | 30956 | 2026-09-16T12:25:22.9243647Z -> 2026-09-16T12:25:58.8984529Z | 0 | 103/103 | `47a6ff98fe647fba06ff0812e63a1af1985009b05a372ac17c53299c40a8bac8` / `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` / `47a6ff98fe647fba06ff0812e63a1af1985009b05a372ac17c53299c40a8bac8` |

The Julia stdout duration is run-dependent; its semantic line is the raw
`103/103` result retained in `run_1/raw/julia_tests.stdout.raw`.

## Findings

1. **P1 — inverse product is not internally recomputed during validation.**
   `validate_inverse` checks positivity of `recovered_alpha/beta`, a stored
   determinant/eigen pair, and a stored zero residual, but never recomputes
   `det(recovered)`, eigenvalues, `forward.matrix`, `forward.response`, or
   `forward.rhs` from the recovered values and target (source lines 302–309).
   Thus a cloned product can replace recovered parameters or forward fields
   while retaining the independently stored `(3,(1,3),0)` fields and still be
   accepted. This weakens target-to-parameter identifiability and means the
   claimed round-trip is not an integrity check. Add exact recomputation and
   typed `roundtrip`/`non_spd` failures; add corruption controls for recovered,
   matrix, response, determinant, and rhs fields.

2. **P1 — upstream composition hash and ledger bindings are not enforced.**
   `_m5i_build` records `manufactured_auto_composition_hash(a)` (lines
   232–245), but `validate_inverse` never compares `m5a_composition_hash` to
   the frozen M5-A canonical identity or recomputes it. `validate_inverse`
   also checks only equality among owner fields and only the two outer
   provenance symbols (lines 325–334); it does not verify owner/provenance
   ledger entries against the consumed M4-D/M5-A values. A coherent foreign
   owner/provenance mutation can therefore survive closure checks. Bind the
   full ledger to frozen upstream values and add joint foreign-owner,
   foreign-provenance, and composition-hash corruption controls.

The existing negative tests are useful but do not exercise these mutations:
they corrupt `roundtrip_residual`, seed metadata, deletion fields, one-sided
owner/hash/provenance inputs, and target-domain controls. They therefore cannot
close the two findings above.

## Scope, hashes, and receipts

Recomputed current frozen inputs match the delivery values:

* M5 source, 21,336 bytes: `70b01aed3cde22a54ec0b24e121c52874662214f06c1a38b6ddc18546cc7ac68`.
* M5 test, 9,359 bytes: `7e636254ef5b82ef05d9ba90dc23303933cffef2008ce202e0944972573f4a26`.
* Python oracle, 5,811 bytes: `6e13536aabb62f039bffe6c286e11323347b86b4d3c146270f38e8bf8129d0ab`.
* Frozen M4-D source/test/oracle: `ec7e82e282f1d1292ddd4b7902e4ced641d926af82119298267011d304a55785`, `1eb0e26e79b9899cc5a3cb2742545cbaa811fa6683fdcfa1ee4dd31dff081686`, `9ca3c1c012690c7c06579d0ab5ffd274666e340c900c59e49f7a93408a0fcbe3`.
* Frozen M5-A source/test/oracle: `e6262a11ca47f527dfa67f08974febfd69a0334e1c64baeec7657249f0e1945a`, `42562f02370f8f2e32c8e0254e0f480d69e598be747aae9898c3fc4d013b2a08`, `e9f13fc57a59efa78dd131dfc3fde7433c21d6172dc2d81f03c034c4be13084c`.
* Shared `src/FusionConceptAI.jl`, `src/Canonical/CanonicalJSON.jl`,
  `Project.toml`, and `Manifest.toml` hashes match the integration record:
  `e3fa8638ed9c5c5f468ae9a8f797416f2bec19b432cc10a9c1aea81ec3460783`,
  `612edaeb822c1beeff44f7134497426fd0c8ff1eea9c16a651421e2c63f8ab93`,
  `923b78938e12c27e836b269d71a539ae7bb292c9fe9f8cb92f9f9a8cea1370e2`, and
  `85074b7a5bd543c0b4155f44db0733d21d53cfd0bf4c2de6704dc858357717e7`.

The current checkout HEAD observed during review is
`b2c04d8339774635aaecd73651efcdb101e01b5d`. No product, shared entry,
registry, project, manifest, candidate, provider, solver, or evidence file was
changed by this review; only this review directory was written.

The prior integration's wrong-sequence/pre-capture PIDs remain
non-authoritative, including PID 56012's capture timeout with no observed
exit/raw. This review also preserves its own first capture (PID field was
incorrect due to a PowerShell reserved-variable collision) under
`non_authoritative/python_pid_capture_error/`; it is not counted. Only PID
40608 followed by PID 30956 is authoritative here.

Role metadata in delivery is only five declarative labels (source, test/oracle,
integration, documentation, independent review); no actor IDs are recorded, so
pairwise-distinct human/agent ownership cannot be independently proven from
the artifacts. The review role itself is distinct from the prior delivery role.
