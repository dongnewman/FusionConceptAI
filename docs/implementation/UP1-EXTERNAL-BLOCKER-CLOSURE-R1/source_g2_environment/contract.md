# UP1 external blocker closure — source, G2, environment and binary provenance

## Scope and ceiling

This is a preparation-only, read-only audit at HEAD `b2c04d8339774635aaecd73651efcdb101e01b5d` with the existing dirty worktree preserved. It freezes source/tree/patch observations and defines executable schemas for the missing external closure. It does not create a candidate, authority, provider, mesh, solver, engineering, physical, search, B00, B04, UP1, R, L4, or parent-goal credit. The only claim is `preparation_only` / `screen_only`.

The write boundary is this directory. No source, test, registry, shared document, AD-55, AD-56, or historical receipt is edited.

## Binding contract

Every source/material record has `uri`, `sha256`, `media_type`, `schema_ref`, `owner`, `candidate_ref`, and `evidence_ref`. Unknown input is represented by `status=typed_absent`, `value=null`, a typed `absence_code`, an accountable owner, an authoritative source, and a recovery condition. A record is present only when both source→candidate/evidence and candidate/evidence→source edges agree byte-for-byte. Historical AD-55 evidence is reference-only and does not make a candidate binding present.

The four version axes are the payload schema, canonicalization profile, applicability profile, and evidence-receipt profile. Their names/versions are recorded only where an existing G2 identity already supplies them; the four external material payloads and their owner/evidence binding remain typed absent.

## G2 mapping contract

An authoritative mapping must include namespace, version, effective interval, issuer, signature/key reference, ambiguity and conflict decisions, and revocation/anti-replay state. A missing issuer/signature/trust root, stale or overlapping mapping, foreign owner, or inconsistent candidate/evidence edge is `terminal_deferred` when information is missing and `fail_closed` when contradictory or forged. No local hash, ordinary review, or user instruction substitutes for an external trust root.

## Environment and binary closure

The environment manifest covers OS/architecture, interpreter/runtime paths and hashes, package locks and hashes, artifact/input hashes, environment variables, locale and timezone. Binary provenance additionally requires name/version/path/hash/publisher/signature/download origin/build recipe/SBOM/license. Observed local values are facts of this audit only; unknown provenance fields stay typed absent. A historical environment receipt cannot be promoted to a current candidate-bound receipt.

## Static validation and recovery

`static_validator.py` is a standard-library validator for these contracts and the two fixtures. It checks hash shape, typed absence, exact four-axis inventory, bidirectional binding shape, G2 safety fields, environment/binary field coverage, and negative controls (missing authority, ambiguity, conflict and revocation). It performs no Julia, DESC, mesh or solver work. Re-run only after an external input changes; unchanged inputs do not justify a new AD or repeated acceptance.

Independent review must re-run the validator, compare the recorded HEAD/tree/patch and every artifact hash, verify that all absent records have owner/source/recovery fields, inspect the dirty patch boundary, and confirm the claim ceiling and write scope.
