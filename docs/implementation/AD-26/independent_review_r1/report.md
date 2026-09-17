# AD-26 independent static review R1

- Verdict: changes_requested
- Scope: architecture-document and evidence-protocol review only.
- Reviewer: independent Luna/high; no Julia/DESC started; no source, core, prior archive, run, or status-index files edited.

## Blocking finding

AD-26 requires the future G-I1 authority-context identity to bind complete same-candidate A/E0 refs and hashes, E1/E2 extension hashes, and typed absent markers. The present text explicitly attaches schema/canonical/profile hashes to the typed absent-marker branch, but does not explicitly require those hashes (or an extension payload hash that is defined to include them) for the present E1/E2 extension branch. The final sentence says that schema/canonical/profile changes rebuild identity, but it does not define the auditable context fields that make such changes identity inputs. This is a narrow protocol ambiguity: the G-I1 work order should state that both present extension records and typed-absent records carry schema_hash, canonicalization_hash and compatibility_profile_hash in the context payload; extension content hashes remain separate inputs. Until clarified, the context identity contract is changes_requested.

## Checks that passed

- The AD-26 archive is review_pending, accepted=false, architecture-only, and explicitly claims no implementation, Julia/DESC, UP2 total, B00/B04, provider, mesh, engineering, physical, or R01-R10 credit.
- Only the three named core documents are targeted. Each has one AD-26 marker, and independent byte reconstruction by removing the appended tail recovers the recorded before length/SHA: 18 (37859, a01c9c65a3bed8ed0b2f887ba3cfaac1d3941cc09bb08cd7717f6a59106de713), README (19536, 5973a415e59eaeee3dee4c641ec1a68032e845f77c0758bc53db73c7cdd3b963), and 16 (56459, d756c7cd2f4456d6a14f02cc698bfef6958057a4828b7121d70eecffebf3114d).
- Current after bytes/SHA match the AD-26 after snapshot: 18 40098/8eef18b3a9c56681dae317109aa19089fd76097c951072ee4a73118bf94bbc9f, README 20065/ed3080e9c164f20d8d67af5a886d3b473d4a578048aaccbbfa17dee07a8c9f75, 16 56910/b0620c8b7fb6ee71f06e6c8fe4f8251a0ae924a7c19eb4fee08bdbe800189e33.
- validate_plan.py exits 0, reports an acyclic DAG and all relative links checked; scoped git diff check exits 0 with only the repository existing CRLF warning.
- AD-24 source boundary is preserved: actual A lacks authoritative N05/N06 cross-layer physical joins; E0 is limited to source-bound identity and keeps N05/N06 as exact terminal-deferred gaps. Current E1 and E2 archives remain review_pending/accepted=false; their content hashes and candidate-bound source contracts are additive.
- The E0 source still carries the original package hash as input and keeps n05/n06 absent; E0 binding_hash and bound_input_hash are downstream envelope identities. E1/E2 source files define their own versioned schema/canonical/profile material and remain separate implementation slices.
- AD-26 preserves the independent contract_admission versus physical_resolution axes, keeps physical status unknown/deferred until provider/mesh/solver/independent physical/engineering evidence, and keeps local rows out of the formal 50-row B04 gate.
- The documented DAG remains UP1-04A -> UP2-00 -> UP1-04B -> UP1-04 -> UP2-01; UP1-04B remains planned and owns fresh 50 receipts, checker, and two-process replay. No R01-R10 or formal B00/B04 obligation is reduced.

## Runtime and archive boundary

This review did not run Julia or DESC. The AD-26 author archive records two pre-existing Julia PIDs during its own sweep and explicitly says the AD-26 task did not start or terminate them; the independent review current process sweep observed no Julia/DESC process. validate_plan and documentation checks are planning/static evidence only.

AD-25 is represented by the core AD-25 section and the separate G-I0 implementation archive; no standalone docs/implementation/AD-25/ directory was present. This does not alter the finding above.

## Restricted conclusion

After the one context-schema clarification, the reviewed architecture can be reconsidered for pass_limited. Even then, the result is architecture/protocol evidence only. It cannot accept G-I1 implementation, E1/E2 implementation, UP2 total, B00/B04, provider, mesh, engineering, physical, or R01-R10 evidence.
