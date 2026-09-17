# H0-A repair R15: zero-match port gaps

Status: `repair_static_complete`; `accepted=false`; `review_pending=true`.

R14 identified one narrow classification defect: a source-shaped port lookup
with zero matches was appended to `errors` at both the role-port and
source-direction-port joins. That made a missing authority/mapping look like
a contradiction and could force `fail_closed`. R15 changes only those two
zero-match branches to append their existing typed tokens to `gaps`:

- `role_port_missing:<role>` now remains a terminal-deferred gap;
- `law_direction_source_port_missing` now remains a terminal-deferred gap;
- ambiguous matches remain `errors` and therefore remain fail-closed;
- single matches still provide only the source-derived port used by the
  direction checks.

The tests now build a source-shaped G3 entry with no corresponding port and
assert both missing tokens are in `gaps` and absent from `errors`. The same
control exercises the source-direction and role-port callers. A separate
unexpected `ErrorException` translation control asserts a typed
`N06H0AProgramError`, `:program_exception`, and the explicit
`:source_projection_exception` code; it cannot be relabeled as a missing
source gap. Existing ambiguous and typed known-gap controls remain in place.

No fixture, runner, upstream module, old receipt, focused run, Julia run, or
DESC run was changed or executed. Actual A still has no authoritative
candidate-owned coefficient/calibration/law/feedback evidence and remains
deferred; synthetic present fixtures remain schema-only. This repair grants no
physical, provider, mesh, engineering, B00, B04, or R credit.

## Hash audit

| artifact | before bytes | before SHA-256 | after bytes | after SHA-256 |
|---|---:|---|---:|---|
| `src/GenomeV5/UP2/N06DimensionedLedgerLawV1.jl` | 57924 | `2d38d9fc7ae42c8bf7a77bea7ad99557e390a321e26f5d918be1996443a629ff` | 57920 | `5b6e23508d7facd3b50802214dfdd0087d63de7252b32ebf4dd4bc4b2142904a` |
| `test/GenomeV5/UP2/n06_dimensioned_law_tests.jl` | 39270 | `b0e626d73c7246c9308c1ff8b315866e9c95dea4dd50aba796959d4092b31756` | 40742 | `9c5ecf8f2f212b2298eff5a8129a618114185867c21b83dcd4e3ff1982b36599` |

Protected inputs remain unchanged:

- fixture: 1451 bytes, SHA-256
  `779e29bac0a71c5072896301e24e74c9686c293609b89e250d0b0aff5bf0cc99`;
- runner: 299 bytes, SHA-256
  `da4c41517badd8c99f5f10e55c9219e2450af223798eb7f7b4db2048ce293dc`.

Static QA checked the four live file hashes, fixture JSON parsing, R15 JSON
parsing (receipt in `static_qa.json`), absence of the removed `first(generator, nothing)` pattern, the two
zero-match source branches, the source-shaped negative controls, and the
unexpected-exception control. No Julia/DESC/focused process was started.

The result is ready only for a different Luna R15 independent precheck. The
next focused run, if separately authorized after review, must use a fresh
process/dirty snapshot and the live four-file hashes above. `accepted=false`
and `review_pending=true` remain mandatory.
