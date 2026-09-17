# UP2-00D N04 acceptance

Status: `accepted_limited`
Accepted: `true`
Accepted scope: `actual_a_five_ledger_fields_local_authority_with_deferred_cross_layer_join`
Claim ceiling: `contract_only`

Sol accepts this bounded slice after an independent Luna/high r3 review returned `pass_limited`. The accepted evidence is limited to five actual-A ledger fields from CandidateStatePackageV5: account owner, closure account IDs, entry account ID, entry component ID, and the entry coefficient. Four mutations are locally source-backed: duplicate closure IDs, wrong entry account association, passive component as source, and capacity-exceeding coefficient. The shared-owner mutation remains `terminal_deferred` because shared owners are legal under the current contract; no owner uniqueness rule is invented.

The exact candidate-bound G1 occurrence to G3 account/energy-boundary mapping is absent and remains an independent authority gap. It is not relabeled as invalid closure. Each accepted result carries source locator/type, original and mutated typed values, projection hash, derived classification/path, and zero compile/provider/solver counters; expected_error cannot drive classification.

The independent r3 run used `julia --startup-file=no --project=. test/GenomeV5/UP2/run_n04_ledger_authority.jl`, PID 51672, exit `0`, and no remaining Julia/DESC process. It reports actual-A projection 46/46 and owner/classification 4/4. Stdout is 2474 bytes with SHA256 `e981eea6e43cbbfc4b094e1be9df6493d37db9fe0e9556610bcfc876ecf06eca`; stderr is empty with SHA256 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`. The author r1 failed archive assertion and r2 overlap run remain preserved; r3 is the serial-only evidence.

B00, B04, provider resolution, mesh, engineering, physical, cross-layer conservation, and R01-R10 claims remain false. This record does not accept UP2-00 as a whole.

Acceptance record: `docs/implementation/UP2-00D-N04/acceptance.md`
Evidence manifest: `docs/implementation/UP2-00D-N04/evidence_manifest.json`
Independent review: `docs/implementation/UP2-00D-N04/independent_review_r3/report.md`
