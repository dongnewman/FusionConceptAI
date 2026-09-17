# UP1 R3 atomic response bundle contract independent review R1

## Decision

`fail_limited`; the additive contract is not an implemented acceptance gate.
The directory remains `review_pending`, `implementation_status=not_implemented`,
and `formal_credit=none`. No authority, T0, UP1, B00, B04, R, parent credit or
publishability is granted by this review.

The contract is materially stronger than the R3 collection-readiness proposal:
it names four ordered packets, closed payload schemas, JCS/domain-separated
preimages, owner/set/review signatures, security outcomes, recovery identity,
quarantine prose, and the `not_executed` deferred boundary. However, several
central guarantees remain verifier-prose-only or have cross-field gaps. Thus no
P1/P2 item receives an unrestricted `pass`; statuses below are bounded
`pass_limited` or `fail_limited` for the contract draft only.

## Frozen scope and independent checks

Reviewed only:

- `03-atomic-response-bundle-contract/{README.md,verifier-contract.md,test-matrix.md,manifest.json}`;
- `bundle.schema.json` and `ehp-01.schema.json` through `ehp-04.schema.json`;
- R3 `01-collection-readiness-audit/{audit.md,field_matrix.json,manifest.json}`.

The five schemas parse and pass `Draft202012Validator.check_schema`. Fixed packet
and digest arrays are each cardinality four with the prefix
`EHP-01,EHP-02,EHP-03,EHP-04`; all payload-schema object definitions are closed.
The static audit also found four packet-position `allOf` property fragments in
`bundle.schema.json` without their own `additionalProperties=false` (the base
schema still blocks unknown packet keys when composed). The set-receipt schema
does not itself express equality of its `bundle_id` or `request_id` to the
top-level values. EHP-03 closure forces `present=true`; EHP-04 runtime/import
maps and SBOM dependency edges lack several item-level identity/uniqueness
constraints.

The contract's own recorded validation is integrity evidence only:
`raw/contract_schema.*` and `raw/final_validation.*` report exit `0`; it is not
execution of `validate_bundle` and not evidence of external authority.

## P1/P2 closure matrix

| Finding | Status | Independent judgment |
| --- | --- | --- |
| P1-01 atomic acceptance computability | `pass_limited` | Fixed four positions/cardinality, derived completeness, JCS UTF-8-SHA256, domain labels, and exclusions are specified (`README.md:7-57`, `verifier-contract.md:20-30,50-66`). Limited because duplicate/non-finite/UTF-8 handling is prose-only, the four position fragments are not individually closed, and aliases `signature_digest`/`payload_digest` do not match the actual `signature_sha256`/`payload_sha256` names (`README.md:46-50`; `verifier-contract.md:70-93`). No executable implementation exists. |
| P1-02 packet authority/signature coverage | `fail_limited` | Packet owner objects/signatures and repeated binding exist (`bundle.schema.json:41-43`; `README.md:59-77`). But role-to-packet, signature-key-to-owner, payload/packet/set digest equality, and set/review exclusion relationships are semantic obligations only. The set receipt's `bundle_id`/`request_id` are merely UUIDs with no schema equality to the envelope; the verifier algorithm does not state those exact ID equalities (`bundle.schema.json:49-50`; `verifier-contract.md:45-49`). |
| P1-03 `not_executed` boundary | `pass_limited` | EHP-04 has a closed `not_executed` alternative and the prose/test matrix explicitly forces `terminal_deferred`, `no_publish`, and `formal_credit=none` (`ehp-04.schema.json:14,17`; `README.md:99-103`; `test-matrix.md:20`). Limited because these are not fields in a closed validation-result schema and the implication is not schema-enforced; it depends on an unimplemented verifier. |
| P2-01 fresh recovery identity | `pass_limited` | Recovery prose requires fresh request/bundle UUIDs, nonce, valid next sequence, fresh idempotency key for changed bytes, and a `recovery_of_bundle_id` link (`README.md:105-116`; `verifier-contract.md:95-101`). Limited because schema only types the optional link and `sequence>=0`; freshness, ledger CAS/strict increase, and old-set preservation are not machine-enforced here. |
| P2-02 independent review receipt | `pass_limited` | Closed review object carries identity/separation, verifier ref, recomputed four digests, bundle/set hashes, trust/time/revocation/replay outcomes, derived decision, raw refs and a review signature (`bundle.schema.json:50-53`; `verifier-contract.md:45-49,85-88`). Limited because distinctness, recomputation, and decision consistency are prose/verifier obligations; the raw refs are digest references, not proof that bytes were actually retained. |
| P2-03 atomic receiver/quarantine | `fail_limited` | An ordered state-machine narrative exists and requires quarantine before verification and one set decision (`README.md:79-97`; `verifier-contract.md:20,95-101`). But the wire contract has no state enum/transition receipt, durable-retention evidence beyond one digest, raw-set reference, or explicit no-promotion transaction token. Atomicity remains unimplemented prose. |
| P2-04 enforceable packet closure | `fail_limited` | EHP-01..04 schemas now contain substantial closed structures (witness, PKI/verifier/time/revocation/replay, source graph, environment/SBOM) and static schema checks pass (`ehp-01.schema.json:5-16`; `ehp-02.schema.json:5-19`; `ehp-03.schema.json:5-16`; `ehp-04.schema.json:5-17`). Cross-field candidate/axis/graph equality, forward/reverse graph identity, certificate semantics, binary-to-SBOM coverage, runtime Julia+Python presence, and unknown-key preparse rules remain verifier prose; several item-level constraints are absent. No implementation/tests are claimed (`README.md:118-135`; `test-matrix.md:1-4`). |
| P2-05 minimal source identity | `pass_limited` | The proposed duplication is minimized: shared binding carries one source identity reference/digest and only EHP-03 carries the full source closure (`README.md:3-5,61-68`; `ehp-03.schema.json:9`). Limited because exact equality between the EHP-03 object and shared digest is only an algorithm assertion, not a schema relation, and the EHP-03 closure shape is forced-present rather than modeling clean absence (`ehp-03.schema.json:16`). |

## Blocking details

1. The schema-level closedness claim is slightly overstated. The four packet
   `allOf` fragments under `bundle.schema.json:17-20` have `properties` but no
   `additionalProperties=false`. Composition with `packet_base` currently
   supplies the practical guard, but the recorded static output's blanket
   `additional_properties_false=true` is not literally reproducible.
2. The canonicalization text has non-normative aliases. `signature_digest` and
   `payload_digest` appear in `README.md:46-50`, while schemas and the explicit
   preimage algorithm use `signature_sha256` and `payload_sha256`
   (`verifier-contract.md:70-80`). A future implementation must freeze one
   exact field-removal/recomputation table before accepting signatures.
3. The `set_receipt` object has UUID fields but no structural equality links to
   envelope IDs, and no schema can enforce equality of all repeated
   `shared_binding` objects, packet digest arrays, owner roles, or review
   outcomes. The prose can guide a verifier, but the verifier does not exist.
4. EHP-04's `identity_map` has only name/version/locator/hash, without a
   candidate/source binding; its SBOM dependency edge list has no `uniqueItems`
   or endpoint existence constraint. EHP-03's four axes and mapping/edge
   relationships likewise rely on semantic checks. These are closure risks,
   not merely formatting preferences.
5. Quarantine durability is represented by
   `durable_quarantine_sha256` (`bundle.schema.json:49`) but not by a raw-byte
   reference, retention/commit receipt, or atomic state-transition record. A
   digest alone cannot independently prove that the exact bytes were retained
   before the decision.

## Acceptance boundary

The contract is useful as an additive design draft and preserves the important
no-send/no-credit boundary. It does not close the unchanged parent goal and
does not authorize an external request, AD/S3 run, Julia/DESC/solver run, or
production test. Required next closure is an independently reviewed,
deterministic verifier implementation plus negative tests for every matrix row,
with the cross-field equalities and canonical exclusion table made explicit.

## Execution receipt

- Repository: `D:\006-Programing\LMC\FusionConceptAI`
- Reviewed HEAD: `b2c04d8339774635aaecd73651efcdb101e01b5d`
- Independent command: `python -B -` (stdlib hashing/JSON plus installed
  `jsonschema` Draft 2020-12 meta-schema checks; no package installation)
- PID: `88100`
- UTC: `2026-09-16T22:27:26.712956Z`
- Exit: `0`
- Raw stdout: `raw/independent_static.stdout.raw`
- Raw PID/UTC/exit: `raw/independent_static.pid.txt`,
  `raw/independent_static.utc.txt`, `raw/independent_static.exit.txt`
- Network/external send: not run; AD/S3/Julia/DESC/solver: not run;
  production tests: not run; source/test mutation: false.

