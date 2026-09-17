# UP2-00G-I1B-SOURCE-ENVELOPE independent acceptance R2

Verdict: `changes_requested`; `accepted=false`; `review_pending=true`.

The structured evidence supports the narrow software result, but the R6
erratum's Markdown report is malformed and cannot be treated as a reliable
human-readable receipt. The structured hash fields themselves are correct.

## Receipt and hash audit

Direct raw-byte calculation confirms:

| raw file | bytes | direct SHA-256 |
|---|---:|---|
| `focused_r5/stdout.txt` | 2806 | `22f5b6723c74b3b502100cba753a9b567c09896722f3373ae28d45b579976121` |
| `focused_r5/stderr.txt` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |

All three focused-R5 structured receipts carry the correct 64-character
stderr hash: `output_hashes.json`, `command_receipts.json`, and `report.json`.
The two independent-postrun-R5 JSON records intentionally preserve the old
62-character value (`e3b0...af4c...`) as historical affected fields; this is
the discrepancy R6 was meant to replace. R6's structured replacement field
contains the correct 64-character value and zero bytes, and its recorded
archive hashes for `report.md` and `command_receipts.json` match their files.

The R6 `report.md` itself contains control characters, unexpanded PowerShell
placeholders such as `$stdoutHash`/`$stderrHash`, and an unexpanded length
expression. Its archive hash is internally consistent, but the text is not a
reviewable rendering of the direct calculation. This is the remaining narrow
correction request; old R6 and R5 evidence was not modified by this review.

## Frozen focused facts and boundaries

- Focused R5: PID `14796`, exit `0`, `2653/2653`; these remain observed facts.
- R9 remains a test-only semantic repair, and independent postrun R5 remains
  `pass_limited`.
- The four protected inputs match the current recorded bytes and SHA-256.
- Focused R4 exit `1`, `2051/2052`, and its raw stdout/stderr evidence remain
  preserved with `overwritten=false`.
- `acceptance.md` and the owner evidence manifest are correctly held at
  `review_pending=true`, `accepted=false` while R6 awaits this independent R2.
- Implementation and core README entries retain the `2653/2653` observation
  and do not claim formal task completion. They preserve the actual-A
  source-envelope-only scope and exclude N06 actual authority, UP2 total,
  B00/B04, provider, mesh, physical, engineering, and R01–R10 credit.

`validate_plan.py --delivery-protection`, JSON parsing, relative-link checks,
four-input hash/byte checks, and focused-R4 protection checks pass. No
Julia/DESC command was run by this reviewer. After the R6 report text is
reissued cleanly, the root may accept only the bounded
`accepted_limited` actual-A source-envelope software scope; no broader credit
follows.
