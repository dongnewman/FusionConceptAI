# B00 F0–F5 entry audit R1 independent static review

## Verdict

`changes_requested`; `ready_for_focused=false`; `status=review_pending`; `accepted=false`.

The reviewed `entry_audit_r1` is substantively correct about the B00 boundary and missing evidence, but its frozen snapshot is stale in two protected core inputs and in the dirty-inventory count. The original audit must not be reused as a current freeze until those drifts are recorded in a new audit revision. No Julia/DESC process was started and no original audit, source, test, core document, run, or prior evidence was modified.

## Snapshot and provenance findings

Current HEAD remains `4b69f55f7f80240147a65a22809dc1207824dde2`. The current status has 292 non-empty lines and UTF-8 SHA256 `39E9106701D4AE5A6148BB2AD31E8739C7B03BA59FD7A02EE0E9C6966CDB5017`, whereas the reviewed audit captured 3,253 lines with SHA256 `fd017b618bf62f8080b9cb5b50a8f70dfed83148f15f5deca2c1dd6a4b195124`. This is a snapshot drift, not evidence that dirty files were clean.

The reviewed frozen inputs that drifted are:

* `docs/v4_multitopology_generation/README.md`: reviewed 20,300 bytes / `66681d071a...d613a46`; current 20,977 bytes / `e208d32e...03d8c0`, due to later AD-27 indexing.
* `docs/v4_multitopology_generation/16_execution_work_orders.md`: reviewed 57,676 bytes / `12484c7c...be0c829`; current 58,474 bytes / `9c1dc810...b12c63`, due to later AD-27 indexing.

The remaining reviewed frozen input hashes, including actual A/E0/G-I1A/UP2 sources, UP1-04A evidence and the prior G-I2 audit, matched at this review time. Current G-I1A acceptance is still `review_pending`/`accepted=false`; its source hash is `d84db10e...f5718fd9`. No current G-I1A independent gate exists.

## F0–F5 source and evidence review

The R1 inventory correctly maps the protocol to current entry points. `CandidateStatePackageV5` carries candidate/package identity, component identity, axes, migration receipt, structural status, gaps and candidate hash. E0 derives a candidate-bound binding and bound-input hash without rewriting the original package. G-I1A carries context and E1/E2 slot hashes with separate contract and physical axes. `UP2ModuleEntryV1` only performs ordered definition loading and has no formal B00 receipt or replay path.

Against `up0_02_protocol.json`, the required gates are:

* **F0:** complete three-layer payload, mission/bounds, four axes, full refs, environment and attempt ID in a hashed input manifest;
* **F1:** frozen canonicalization and byte-identical canonical package plus package/layer/bundle hashes from two processes;
* **F2:** same frozen input and route with distinct attempt receipts and complete commands, environment and exits;
* **F3:** display/family/name/benchmark erasure and permitted ordering permutations with zero route/hash/applicability/decision/claim-ceiling diff;
* **F4:** candidate-owned route, provider signatures and explicit ECF mapping, with no wildcard/default-registry route;
* **F5:** complete F0–F4 envelope, independent checker, artifact paths/hashes, reproducible commands and claim ceiling.

The reviewed audit correctly finds each formal artifact absent. Existing UP1-04A `45/45` evidence is accepted-limited structural same-candidate package/join evidence and explicitly leaves B00/B04 false. The 50-row `test/GenomeV5/UP2/fixtures.json` is marked `schema_validation_only`; it is not an F0–F5 envelope. Existing local N03–N10 and N05 receipt assets are slice evidence only. The only discovered checker is the local N05 checker; its trusted path reuses exporter `_n05e_row`, so it cannot satisfy the independent-checker gate. No formal B00 receipt directory, independent checker process, label-erasure diff artifact, route/ECF receipt, or two-fresh-process canonical comparison was found.

## B00 versus B04 and exit boundary

B00 is the package/input/route/replay/label-erasure envelope. B04 is the separate N01–N10 set of 50 fresh candidate-bound mutation receipts. A 50-row fixture, local mutation count, A-layer test, runner exit, or AD-27 architecture text cannot substitute for either. UP1-04B remains the owner of the first frozen B00 F0–F5 and formal B04 suite, independent checker, and two-process replay.

The exact exit gate remains: all F0–F5 artifacts, 50 fresh B04 rows, an independently implemented checker, and two fresh-process replay must agree on candidate/package/context/route/decision and all canonical row fields while retaining distinct attempt/PID/log metadata. Missing any item keeps B00, B04, UP2 total and UP1-04 total unaccepted. Provider, mesh, engineering, physical and R01–R10 claims remain false.

## QA

At the current review time, JSON parsing passed, current `validate_plan.py` exited `0` with checks pass and an acyclic DAG (`332` links), current `git diff --check` exited `0` with line-ending warnings only, and the Julia/DESC process sweep was empty. These current checks do not retroactively repair the stale R1 snapshot; a new audit revision must freeze the current inputs before scheduling B00.
