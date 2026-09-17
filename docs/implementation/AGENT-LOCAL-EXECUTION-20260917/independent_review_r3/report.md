# Independent review r3 — agent_local execution status gate

## Verdict

**pass**. The sole r2 P1 is fixed: a new dispatch is authorized only for
`planned` or `ready`. Explicit CLI selection of `accepted`, `running`,
`review_pending`, `changes_requested`, or `blocked_external` returns
`status=non_dispatchable_task_status` and exit code 2. The default ready list
also excludes all five states.

The wrapper is formally allowed for `agent_local` → Julia independent replay
as a dispatch/integrity boundary. This is not Julia execution or scientific
acceptance: each work order still needs its actual candidate/input bytes,
semantic/numerical/engineering checks, receipts, and separate R01–R10
evidence. No Julia, DESC, or mesh command was run in this review.

## Reproduction evidence

Base and current `HEAD` both equal
`cfc745939a02fd023854dd04e9bb6d04ccadf9ee`; no commit was made.

| Check | Result | Exit | Combined SHA-256 |
|---|---:|---:|---|
| `python -B -m unittest discover -s test -p test_agent_local_execution.py` | 22 OK, 1 symlink-permission skip | 0 | `ab9a9447577f56f20753bde49af2f93389ce6839a615429c086549424a17dd3e` |
| `python -B docs/v4_multitopology_generation/validate_plan.py` | 39 tasks, acyclic, 370 links, 0 errors | 0 | `42a380a52a674113ed66da4c504098aef8950691452c1f0db13d4d1740aa9c65` |
| `python -B tools/agent_local_execution.py` | `ready`; four planned/ready tasks; no external certification | 0 | `2410b2ad661b2b3dbb577f9884f36245056a986723e45261b9172d91e8c3d432` |
| `git diff --check` | clean; only existing LF/CRLF warnings | 0 | `99c9f3882d5fa817d4190fd85c710eaaeeccaa3ba94f806ec25011d730572670` |

The independent CLI status matrix used a temporary manifest and policy:

| Task status | Expected / observed exit | Reported status |
|---|---:|---|
| `planned` | 0 / 0 | `ready` |
| `ready` | 0 / 0 | `ready` |
| `accepted` | 2 / 2 | `non_dispatchable_task_status` |
| `running` | 2 / 2 | `non_dispatchable_task_status` |
| `review_pending` | 2 / 2 | `non_dispatchable_task_status` |
| `changes_requested` | 2 / 2 | `non_dispatchable_task_status` |
| `blocked_external` | 2 / 2 | `non_dispatchable_task_status` |

The canonical status-matrix result SHA-256 is
`8e5af2872472b3e345f82b170a0885d73c2ff4734c878c04fe9c0b7c46ebd442`.

## Boundary and synchronization checks

- `DISPATCHABLE_TASK_STATUSES` is exactly `{planned, ready}`; the legal status
  set remains closed and illegal statuses fail closed.
- The 39 manifest IDs and 39 dispatch-table IDs have identical sets. The
  manifest and table use a different local ordering for the VNEXT precursor
  block, but `validate_plan` confirms the actual dependency DAG is acyclic
  and complete.
- The policy keeps `external_approval_required=false` and
  `external_certification_blocks_execution=false`, while retaining local
  source/input hashes, typed closure/applicability, numerical checks,
  engineering constraints, reproducible receipts, and `R01`–`R10`.
- G3 wording is local and agent-owned (`agent-owned local source/declaration
  records`); it does not turn a local record into external authority.
- An additional temporary-root probe returned `invalid` for parent and
  absolute input paths, an acceptance-record parent escape, and an unknown
  policy field; the 22-test suite also covers external symlink containment,
  cycles, missing/duplicate dependencies, illegal status, and closed policy
  schema. Probe exit was 0.
- The 533-entry protected inventory was independently recomputed: zero
  changed and zero missing. Canonical result SHA-256:
  `af775d6f375b91503c8c5ba489c3e1677c22d77ef9074f5dd301408ed2c9a10f`.

## Reviewed implementation hashes

At review time:

- `tools/agent_local_execution.py` —
  `8f68f125a43b9ad19d1165485b8e3a10495203b53cfadbecaeb0c773e2d99eb3`
- `test/test_agent_local_execution.py` —
  `5adfdef4b8953155949eae61a15fc713aac14731c63390d031ad4831a368ce6c`
- `docs/v4_multitopology_generation/execution_policy.json` —
  `4c148ca007b30431856ddf6fd5217eea23071ed80f8920742eea18b362dc4015`
- `docs/v4_multitopology_generation/task_manifest.json` —
  `3223f122e90385568997b3057fad7122fc7daafb86fc2fa2440e00dd2a33f2de`

No findings remain for the r3 scope. Commit is intentionally left to the
parent agent; this review writes only this report and its manifest. The
reviewed implementation batch is eligible for selective commit, subject to
the parent agent preserving unrelated dirty work.
