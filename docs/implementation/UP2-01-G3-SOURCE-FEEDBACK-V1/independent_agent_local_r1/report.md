# UP2-01-G3-SOURCE-FEEDBACK-V1 independent agent-local R1

Disposition: `fail` (static, blocking finding); `status=proposal`;
`review_pending=true`; `accepted=false`.  Credit ceiling for this review is
`contract_only_static`.  Julia was not run by this reviewer; the parent lane's
reported `54/54` receipt is treated as imported evidence, not independently
verified here.  No provider, compiler, mesh, solver, engineering, physical, or
R01--R10 credit is granted.

## Scope and checks

The review was read-only except for this new directory.  Baseline was the
requested HEAD `cfc745939a02fd023854dd04e9bb6d04ccadf9ee`; unrelated dirty
worktree entries, old archives, `task_manifest.json`, public entry points, and
`runs/` were not changed.  I read the current G3 source/test/fixture/static-QA,
the work order and normative authority clauses, and the prior `agent_local_r1`
report/manifest/command receipt.  The explicit Python command

```text
python -B docs/implementation/UP2-01-G3-SOURCE-FEEDBACK-V1/static_qa.py
```

returned exit `0`; all reported checks were true and the manifest hashes matched.
The source, test, fixture, and static-QA hashes at review are recorded in
`manifest.json`.  The static result does support the requested local repairs:
exact rational `120 -> 90 + 15 + 15`, endpoint roles counted exactly once,
output direction checks, duplicate upstream/feedback/closure rejection,
same-layer object equality for a target and its upstream record, declaration
hash recomputation, owner/unit checks, and zero downstream call counters in the
contract receipt.  These are software/static observations only.

## Blocking finding

### G3SF-R1-AUTHORITY-LAYER-IDENTITY — wrong-layer authority can pass the pairing gate

`G3SFAuthorityV1` checks that `layer` is `G1` or `G2` and that an actual
`contract_ref` is typed and version `v5` (source lines 72--101), but it never
checks that `contract_ref.uri` belongs to that layer namespace, nor that its
`contract_hash` is bound to the referenced source/contract.  The declaration
validator's new pairing logic (lines 415--449) then compares a feedback
authority to the `Dict` record for the same symbolic layer.  Consequently a
record labelled `layer=:G1` carrying a `fusionconceptai://GenomeV5/G2/...` ref
and arbitrary digest can be copied into the G1 feedback target and pass the
same-layer equality check.  This is not merely a missing external receipt: it is
a typed contradiction that the current standalone validator does not classify
as `fail_closed`.

This conflicts with the current authority contract, which requires a target
pointing at the wrong G1/G2 ref to fail closed before the later same-candidate
join.  It also means the new “same-layer pairing” check proves equality to the
wrong upstream object rather than proving that the object is authoritative for
that layer.  Required repair: enforce the layer namespace/ref shape at this
boundary and add a foreign/wrong-layer negative control; where content binding
cannot be independently recomputed, retain `typed_absent`/`terminal_deferred`
instead of accepting an `actual` record as structurally valid.  A future exact
same-candidate join must still compare the complete ref, four axes, source bytes,
hash and candidate binding; this local fix must not synthesize that evidence.

## Additional findings

1. The constructor does enforce ref/hash co-presence (source lines 93--100),
   but the focused tests and static QA only check the source token.  There is no
   negative test for a half-pair (`ref != nothing`, `hash == nothing`, or the
   reverse), and no test for a wrong-layer URI.  Add both before relying on the
   `authority_ref_hash_pairing_present` check.

2. `status=:missing` (and the other non-actual statuses) may still carry a
   non-null ref/hash pair.  The validator only turns the status into an
   external-authority gap; it does not reject a status/body contradiction.  If
   “missing” means no authority material, this must be `fail_closed`; otherwise
   the status contract should explicitly document why the retained pair is
   legal and test it.  The current fixture's both-null `missing` records remain
   correctly `terminal_deferred`.

3. The current 54 assertion count and imported command receipt do not replace
   an independent runtime check for this review.  The prior
   `agent_local_r1/report.md` says the reviewer did not run Julia while its
   manifest records the parent's focused command as `julia_run=true`, exit `0`,
   `54/54`; this is internally explainable as imported parent-lane evidence,
   but the report should label it that way to avoid attributing runtime
   verification to the static reviewer.

## Boundary and recommendation

The repair is otherwise narrow and preserves the required contract-only
ceiling: no compiler/provider/mesh/solver path is present, and the static QA
reports zero downstream counters.  Do not promote this slice or close the
review gate until the wrong-layer authority negative control and the
ref/hash/status consistency controls are added, then obtain a fresh different-
Luna static review and let the parent run the separately serialized focused
Julia lane.
