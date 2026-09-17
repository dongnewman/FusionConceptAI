# UP1 R3 atomic contract repair independent review R1

## Decision

`fail_limited`. The R1 repair is a useful additive schema/predicate draft, but
it is not sufficient to authorize an acceptance-capable additive verifier
implementation. A bounded offline, non-authoritative prototype may be
continued only with the existing `review_pending`, `implementation_status=not_implemented`,
and `formal_credit=none` ceiling. This review grants no authority, T0, UP1,
B00, B04, R, parent credit, delivery, publication, or external-material
credit.

The R1 changes do close the literal packet-position `allOf` boundary, make the
set envelope ID/packet-digest/shared-binding comparisons executable, and add
useful EHP-03/EHP-04 checks. They do not close the acceptance semantics claimed
in the contract prose: digest/preimage recomputation is stubbed, the canonical
preimage table is not a wire/verifier input, quarantine evidence is only
field/timestamp checked, and several EHP-03/EHP-04 relations and result
consistency checks remain absent.

## Scope and safety boundary

Reviewed read-only:

- `04-atomic-contract-repair-r1/{README.md,verifier-contract.md,test-matrix.md,manifest.json}`;
- the five R1 schemas, `verifier-predicates.json`, `verifier.py`, and
  `static_validate.py`;
- the prior `reviews/03-atomic-contract-independent-review-r1/review.md` and
  the R1 source-contract manifest.

No network or external send was used. AD/S3, Julia/DESC, solver, credentials,
production tests, and production-source/test mutation were not used.

## Independent checks

| Check | Result | Boundary |
| --- | --- | --- |
| `python -B static_validate.py` | exit `0` | Shape/static inventory only; it does not execute R01--R25. |
| `python -B verifier.py --self-test` | exit `0` | Three pre-parse cases only: duplicate key, `NaN`, invalid UTF-8. |
| Draft 2020-12 schema checks plus offline relative `$ref` resolution | pass; 48 refs, 0 unresolved | Reference integrity only, not instance acceptance. |
| Direct EHP-03 duplicate-edge probe | no error returned | Two identical edge identities in both directions pass `_check_ehp03`; this contradicts R15's duplicate-edge rejection requirement. |

The exact receipts are in `raw/`; the independent probe output is
`raw/independent_static.stdout.raw`.

## P1/P2 closure matrix

| Finding | Status | Independent judgment |
| --- | --- | --- |
| P1-01 packet-position closedness (`allOf` + `unevaluatedProperties`) | `pass_limited` | Each of the four `packets.prefixItems` wrappers has two `allOf` members and `unevaluatedProperties:false` (`bundle.schema.json:10-15`), and all five schemas pass `Draft202012Validator.check_schema`. The static check only inspects the wrapper shape (`static_validate.py:31-34`); no R01 unknown-key instance vector is executed, so this is not an acceptance-test pass. |
| P1-02 bundle/set receipt ID and digest predicates | `pass_limited` | `verifier.py:113-120` compares set `bundle_id`, `request_id`, packet digests, and shared binding to the envelope with the named mismatch codes. This closes the specific R3-03 omission at predicate level. It still does not bind the set signature or receipt digest cryptographically, nor validate independent-review decision consistency. |
| P1-03 canonical exclusion spelling | `fail_limited` | The exact eight-item array is checked (`verifier.py:87-90`; `bundle.schema.json:26`), but the advertised preimage table is Markdown only (`verifier-contract.md:31-42`). There is no schema field or verifier parser for a preimage table, no alias mutation can be supplied to `validate_bundle`, and no owner/set/review/bundle preimage is recomputed. R03 therefore cannot be an executable negative vector. |
| P1-04 atomic digest/acceptance computability | `fail_limited` | `_packet_digest` is an explicit no-op (`verifier.py:81-82`). The packet loop only compares submitted `payload_sha256` and signature digest fields (`verifier.py:94-105`); it does not hash payload bytes or signature bytes and does not recompute owner preimage, set preimage, review preimage, set receipt, review, or bundle canonical digests. The contract's “recompute” claim (`verifier-contract.md:14-16,35-38`) is therefore not implemented. |
| P2-03 quarantine raw/CAS/durable transaction and receiver signature | `fail_limited` | The repaired schema requires raw object/blob hashes, size, immutable locator, CAS transaction, timestamps, receiver signature, state, and receipt digest (`bundle.schema.json:12,25`). The code checks presence, `quarantine_raw`, raw object hash against the entire input, timestamp order, and nonempty receiver signature fields (`verifier.py:123-139`). It does not check `raw_size_bytes == len(raw_utf8)`, raw blob/object equality, locator/receipt/CAS contents, receiver signature digest/preimage, or a durable transaction/state-transition receipt. `durable_commit_utc <= verification_started_utc <= decision_utc` is only a claim in submitted fields, not independent durable-before-verify evidence. |
| P2-04 EHP-03 candidate/source/axis/G2/graph cross-fields | `fail_limited` | Candidate/source checks cover only selected locations (`verifier.py:156-167`); axes compare IDs, not the complete shared refs (`verifier.py:168-172`); G2 checks only `ambiguity_decision == none` and nonempty forward/reverse rows (`verifier.py:180-182`). The graph comparison uses equal `Counter` values (`verifier.py:173-179`) but never rejects a duplicate identity when the same duplicate appears on both sides; the independent probe returned `[]`. It also does not establish reverse row inversion, mapping namespace/version/issuer closure, or graph/authority digest recomputation. |
| P2-05 EHP-04 context/runtime/identity/SBOM/binary/fixture cross-fields | `fail_limited` | Context, exact Julia/Python names, tuple duplicate checks, SBOM endpoint membership, binary candidate/subject checks, and fixture-status shape are present (`verifier.py:185-217`). Missing are runtime version/path/hash binding, SBOM document/component/binary reference closure, dependency-edge identity/hash checks, import/lock source-context binding, executed-fixture exit/receipt closure, and consistency with the submitted set/review decisions. The schema's `uniqueItems` checks exact JSON objects, not the semantic identity tuples claimed by every relation. |
| P2-06 predicate/error-code index and test-vector evidence | `fail_limited` | `verifier-predicates.json` indexes `EHP04_SBOM_EDGE_ENDPOINT_MISSING` but not the implementation's `EHP04_SBOM_COMPONENT_DUPLICATE` (`verifier.py:205-211`), while R20 names both outcomes (`test-matrix.md:28`). Several emitted baseline/quarantine codes are likewise not represented by the closure index. R01--R25 are explicitly future vectors (`test-matrix.md:35-38`); the self-test has only three pre-parse cases (`verifier.py:241-252`). Thus code coverage and negative-vector coverage are not established. |
| P2-07 derived decision and receipt consistency | `fail_limited` | `validate_bundle` derives `accepted_all` from “no collected errors + `security_ok=True`” (`verifier.py:229-237`). It does not compare `set_receipt.decision`, `independent_review.derived_decision`, or their digest/signature bindings to the derived result. A future acceptance-capable implementation could therefore accept a structurally passing bundle whose submitted set/review decisions disagree. |
| P2-08 Draft 2020-12 refs and verifier self-test | `pass_limited` | Independent offline resolution found 44 refs in `bundle.schema.json` and one in each EHP wrapper, all resolving locally; all schemas pass the meta-schema. The self-test exits zero, but only covers pre-parse rejection and does not exercise refs through instance validation or any R-series predicate. |

## Required closure before any acceptance-verifier authorization

1. Make canonical preimage definitions machine-readable, freeze the exact
   exclusion set per preimage, and implement deterministic payload/signature/
   owner/set/review/bundle recomputation with stable failure codes.
2. Add a durable quarantine transaction/receipt model whose raw bytes, size,
   CAS transaction, locator, receiver signature, and receipt digest are
   independently bound; verify the durable-before-verify event rather than
   trusting timestamps supplied in the bundle.
3. Complete EHP-03 mapping inverse and graph identity/duplicate predicates and
   EHP-04 runtime, SBOM, binary, and fixture decision relations; register every
   emitted code in the machine predicate index.
4. Supply concrete offline fixtures and negative tests for R01--R25, including
   set/review decision disagreement and duplicate graph identities. Keep all
   tests non-authoritative and external-material-free.

## Acceptance boundary

The schemas and local references are structurally usable as an additive design
draft. The contract is **not** closed enough to authorize an acceptance-capable
additive verifier implementation. Nothing in this review changes the frozen
parent goal or authorizes real external material, external authority, AD/S3,
Julia/DESC/solver, production tests, UP1, B00, B04, R, T0, publication, or
formal credit.

## Execution receipt

- Repository: `D:\006-Programing\LMC\FusionConceptAI`
- Reviewed HEAD: `b2c04d8339774635aaecd73651efcdb101e01b5d`
- Prior review SHA-256: `04cf208a560cb57fd134d2db1aadf580fe06964ee9208b73a35167e3234114f6`
- Source contract manifest SHA-256: `49d3bbfbf8dc12168a069172aa73f450979f02c064637fb913d92aa7562a2357`
- Independent static command: `python -B -` (stdlib JSON/hash plus installed `jsonschema`; offline only)
- PID: `48724`
- UTC: `2026-09-16T22:48:22.835585Z`
- Exit: `0`
- Raw stdout: `raw/independent_static.stdout.raw`
- Raw PID/UTC/exit: `raw/independent_static.pid.txt`, `raw/independent_static.utc.txt`, `raw/independent_static.exit.txt`
- Additional receipts: `raw/static_validate.*`, `raw/verifier_self_test.*`
- Network/external send: not run; AD/S3/Julia/DESC/solver: not run; production tests: not run; source/test mutation: false.
