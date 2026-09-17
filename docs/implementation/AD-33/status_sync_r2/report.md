# AD-33 status synchronization R2

Date: 2026-09-15
Decision owner: Sol/root
Decision: accept the local typed-absent source/test/fixture/static-QA software scaffold as `accepted_limited`, based on independent postrun R2 `pass_limited`.

The machine node remains `UP1-04A-VNEXT-PARENT-BASELINE-BIND-PREC` with `planned`/`proposal`/`accepted=false`/`review_pending`. It still depends only on accepted `UP1-01`, `UP1-02` and `UP1-03`; the G1/G2 V1 paths remain read-only inputs. It remains parallel to T0, AD-31 and AD-32 and does not unlock T0, T1 or T2. Task count remains 37 and the DAG is unchanged. AD-34/AD-35 and UP3-01 through UP6-03 are preparation text only and are not added to the DAG.

The accepted local scope is the software contract already implemented under the dedicated work-order path: typed `AbsentParentBaselineBindingV1`/`AbsentChildKeyV1` state with `contract_admission=:terminal_deferred`, canonical and domain-tagged hash behavior, closed negative controls, and failure atomicity. Present G1/G2 parent or child records, source publication, and absent-to-present promotion remain blocked by real source-backed V1 declaration/factory receipts and fresh same-candidate identity review. `replace_source_payload` remains forbidden for absent state; rejected receipts preserve prior canonical bytes, SHA, state and history.

Evidence is bounded to Python static QA `38/38` using `D:\\Users\\Newman\\anaconda3\\python.exe` (SHA-256 `388fe2cffda8a134e7d7dc4e978f7c478857ece6b69694daecbed25e51ec633a`, Python `3.13.5`) and Julia focused R5 `52/52`, exit `0`, using Julia `1.10.5` (executable SHA-256 `8e86e2d48c574393c37bbfb6e922ea4176ba8e1a83f956826f3da24948e389ad`). Julia R1-R4 failed receipts remain preserved and are not rewritten. Stable cleanup inventory reports `20/20` kept entries and zero removals; PID 66044 was already absent and protected PIDs 65224/58068 were not touched.

All actual, present G1/G2, source publication, T0, T1, T2, provider, mesh, engineering, physical, search, B00, B04, B00/B04 and R01-R10 credits remain false. This synchronization does not create G1/G2 edit sibling machine nodes and does not dispatch implementation.

The exact synchronized file set and hashes are recorded in [manifest.json](manifest.json). The machine task manifest remains the 37-task file at `docs/v4_multitopology_generation/task_manifest.json`; its node status is unchanged except for the explicit local scaffold acceptance fields and this R2 status link.
