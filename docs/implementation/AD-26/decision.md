# AD-26 decision record

Decision ID: `AD-26`  
Task IDs: `E1`, `E2`, `G-I1`, `G-I2`, `UP1-04B`  
Date: `2026-09-14`  
Reviewer/authority: `Sol` architecture ruling; implementation/archive owner: `different-Luna/high`

## Why needed

E1 and E2 add authored N05/N06 declarations after actual A and accepted-limited E0 source identity. Without a separate context identity and separate status axes, an extension could mutate or appear to strengthen the original V5/E0 hashes, or a contract-only declaration could be mistaken for physical resolution. The decision also prevents local E1/E2 rows from silently satisfying the formal 50-row B04 gate.

## Fixed ruling

1. E1 typed authored N05 declarations and E2 typed authored N06 mappings are additive, candidate-owned and content-hashed after actual A+E0. E0 v1 `n05`/`n06` remain `nothing`; `CandidateStatePackageV5.candidate_hash`, E0 `binding_hash` and E0 `bound_input_hash` are immutable. G-I1 may compute a separate versioned authority-context hash containing complete same-candidate A/E0 refs and hashes plus E1/E2 extension hashes or typed absent markers, with schema/canonical/profile hashes. Any input change rebuilds context identity.
2. `contract_admission` is limited to sourced typed declaration consistency and uses only `declared_consistent`, `fail_closed`, `terminal_deferred` or `program_exception`. `physical_resolution` is independent and remains `unknown`/`terminal_deferred` until later applicable provider, mesh, solver, independent physical and engineering evidence.
3. Missing law, endpoint, conversion, owner or provenance is `terminal_deferred`. A self-consistent declaration is not physical authority; typed mutation `fail_closed` proves contract rejection only. A G-I1 50-row ledger may record local classifications and gaps but cannot promote provisional rows or local E1/E2 ten rows to formal B04. G-I2/UP1-04B still require fresh 50 receipts, checker and two-process replay.
4. R01–R10, UP0–UP6 DAG, UP2 total, B00/B04, provider, mesh, engineering and physical boundaries are unchanged.

This record is a decision archive, not an implementation or runtime acceptance.
