# AD-30 T0 precursor index synchronization independent review R1

- `review_id`: `AD-30-independent-t0-index-review-r1`
- `reviewer`: different Luna/high
- `review_date`: `2026-09-15`
- `verdict`: `pass_limited`
- `scope`: read-only review of the T0 software-precursor additions to the two core indexes and their status/evidence boundaries

## Decision

The T0 precursor index synchronization passes its limited scope. The two
indexes now link the local T0 software-precursor acceptance and its independent
software review, and state the bounded `accepted_limited` scope with the
recorded `79/79` software assertions. The T0 machine task remains
`planned`/`accepted=false`, and T1 remains `no_go` until the real T0 conditions
are independently satisfied.

The synchronization does not promote a fixture or local software receipt into
a fresh candidate. Actual fresh same-candidate exact join, external G2 mapping,
real four-axis receipts, G3 source-content authority, G3 realization/control/
binding children, engineering, physical execution, and all downstream gates
remain false or deferred.

## Index checks

1. `docs/v4_multitopology_generation/README.md:123` links
   `UP1-04A-VNEXT-T0/software_precursor_acceptance.md` and
   `independent_software_acceptance_r1/report.md`. It describes only local
   complete-declaration transport, typed gaps, hash behavior, and the `79/79`
   software contract. It explicitly keeps the T0 main gate false, external
   authority gaps unresolved, T1 no-go, and provider/mesh/engineering/physical/
   search/R01-R10 credit absent.

2. `docs/implementation/README.md:66` adds the same two T0 precursor links to
   the AD-30 row and preserves the distinction between the accepted-limited
   software precursor and the unaccepted T0 machine gate. The row retains the
   actual fresh-candidate, external-authority, downstream, and credit ceilings.

3. The precursor's own acceptance record and independent software review agree
   with the index wording: `79/79` is software execution evidence only; G2
   external candidate mapping/four-axis receipts, G3 source-content hash and
   realization/control/binding children remain deferred; no physical or
   engineering feasibility follows from the test.

## Machine DAG and protected boundaries

The current task manifest was read directly. T0 depends on `UP1-04A` and the
three G1/G2/G3 V1 preparation tasks; T1 depends on T0; T2 depends on T1;
`UP1-04A-VNEXT` depends on T2; and `UP2-00` depends on the aggregate gate.
T0/T1/T2/VNEXT/UP2-00 remain `accepted=false`. The current formal route is

`UP1-04A + {G1, G2, G3} → T0 → T1 → T2 → UP1-04A-VNEXT → UP2-00`.

The hashes of `16_execution_work_orders.md`,
`18_sources_and_architecture_decisions.md`, and `task_manifest.json` match the
R4 repair snapshot. No change to those files, source, tests, old evidence, or
the existing T0 main acceptance record is present in this synchronization.
The complete R01-R10 goal remains unchanged.

## Static verification

The following read-only checks were run independently:

- `python docs/v4_multitopology_generation/validate_plan.py`: exit `0`, 31
  Markdown files, 374 relative links, 34 tasks, acyclic DAG.
- `python -m json.tool docs/v4_multitopology_generation/task_manifest.json`:
  exit `0`.
- `python -m json.tool docs/implementation/AD-30/t0_precursor_index_sync/evidence_manifest.json`:
  exit `0`.
- The two new precursor links and all referenced files resolve; no Julia or
  DESC command was run.

All large gates remain false: implementation promotion, T0 main acceptance,
T1/T2, UP2, B00, B04, provider, mesh, engineering, physical, search, and
R01-R10.

## Recomputed hashes

| path | bytes | SHA-256 |
|---|---:|---|
| `docs/v4_multitopology_generation/README.md` | 28443 | `9e65529da27a7b0a4c7b6412ae34bb7be4b71d9eddef1b7c70c0e1808941e6d9` |
| `docs/implementation/README.md` | 14548 | `2f2c5c8109e2c22d16c026a9eb57d43c8255197822734cf9d88c4a3abc150b97` |
| `docs/v4_multitopology_generation/16_execution_work_orders.md` | 73348 | `011533c4c174feb77636aab3d96d5b3d05457d7eaae26f3d52db08a622809280` |
| `docs/v4_multitopology_generation/18_sources_and_architecture_decisions.md` | 57483 | `f16d5a00a7a0896138398b77c18eba4769b6f1962406d55f11862b4ef5b76e0b` |
| `docs/v4_multitopology_generation/task_manifest.json` | 63912 | `b149ffa8a725c2a8e9c62bcd3c81becbca92bae9e3b49b3eef9360aef4a9fab5` |
| `docs/implementation/UP1-04A-VNEXT-T0/software_precursor_acceptance.md` | 2929 | `eb7a6f2960be4a4e6ba250fe9d3a2cde8eac05a23dc120d23972b143ee52e0ec` |
| `docs/implementation/UP1-04A-VNEXT-T0/software_precursor_evidence_manifest.json` | 2923 | `9350eb4e66bb3a1e80b1b176a19d2562daef3d4ee48ec2ed04d25189bffac065` |
| `docs/implementation/UP1-04A-VNEXT-T0/independent_software_acceptance_r1/report.md` | 3740 | `ffacba3ed66cf5a4692336015420151da48bd6f444287836df42a7411c2d9f59` |
