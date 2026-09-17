# H0-A independent postrun review R2

Verdict: `changes_requested`.

This is a read-only third-party postrun review of `focused_r2` at frozen HEAD `4b69f55f7f80240147a65a22809dc1207824dde2`. No Julia or DESC command was run by this review. The focused lane's preserved result is exit `1`: the first testset recorded five passes and one error, with no child process left at postflight. The focused evidence and protected input hashes are internally consistent, and the four protected H0-A inputs remained unchanged.

The exposed failure is exactly the test helper call `_h0a_digest("z")` at `test/GenomeV5/UP2/n06_dimensioned_law_tests.jl:15`, reached while expanding the first testset at line 147. The helper at line 9 is:

```julia
_h0a_digest(ch) = G.Digest256(repeat(ch, 64))
```

`Digest256` intentionally accepts only exactly 64 lowercase hexadecimal characters (`src/IR/PhysicalTypes.jl:12-26`). Repeating `"z"` yields 64 characters but `z` is outside `0-9a-f`, so the reported `ArgumentError` is the direct and sufficient root cause. This is a test-fixture construction error; no production H0-A source defect is implicated by the captured stack.

`"z"` is the first exposed invalid literal, not the only one. The same helper is called with `"foreign-schema"` (lines 119, 207, 546), `"foreign-canonical"` (lines 119, 207, 546), `"stale"` (line 229), and `"stale-g3"` (line 245). These values are either non-hex or multi-character, so the helper would fail on them too if execution reached those paths. The single-character literals `"a"` through `"f"` and `"1"` through `"3"` are valid under the current helper and are not the cause of this run's error. A repository scan found no second H0-A helper of the same form; unrelated tests use explicit zero/hex placeholders or the canonical text-hash API.

The narrow repair is test-only: replace the helper body with `G.digest256_text(String(ch))` (or an equivalent canonical SHA-256 text digest), preserving distinct deterministic values for all existing labels. Do not relax `Digest256` validation and do not alter the production H0-A implementation. After that test-only repair, rerun the required serial focused lane under the existing gate; retain exit `1` and all claim ceilings until the rerun passes and the independent postrun evidence is refreshed.

The focused failure carries no positive H0-A, dimensioned-law, B00, B04, physical, engineering, provider, mesh, or R credit. The R8 static precheck's `ready_for_serial_focused` disposition did not inspect this helper contract and therefore does not close this postrun finding.

## Frozen evidence

- HEAD/branch: `4b69f55f7f80240147a65a22809dc1207824dde2` / `main`.
- Current pre-write worktree: 297 porcelain entries; status SHA-256 recorded in `command_receipts.json`; no matching `julia`, `julia-debug`, or `desc` process observed.
- focused_r2 receipt: PID `45976`, end UTC `2026-09-14T19:17:39.0484304Z`, exit `1`, stdout SHA-256 `d5a7aa93f0dc73a3374cdd7f86e0eda6568d6fe4c06cfae3d9744a1028a01748`, stderr SHA-256 `a64e6d35d8d86249f2a54bdce3dc19890943cbc320899aa1ce2a73dcb15f1225`.
- H0-A source/test/fixture/runner hashes are listed in `evidence_manifest.json`; the focused protected-before/after record reports all four inputs matched.

