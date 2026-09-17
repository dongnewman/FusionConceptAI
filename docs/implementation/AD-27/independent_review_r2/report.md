# AD-27 provenance repair R2 independent static review

## Verdict

`pass_limited`; `accepted=false`; `status=review_pending`. This review accepts only the provenance repair as statically reproducible. It does not accept AD-27, H0/H1 implementation, B00/B04, provider, mesh, engineering, physical, or R01–R10 evidence. Sol remains the authority for any later AD-27 acceptance decision.

No Julia or DESC was started by this review. A separate Julia lane was occupied at preflight by external PIDs 88464 and 88056; it was neither interrupted nor treated as evidence for this review.

## Exact before-to-after verification

The author repair's `verify_append.py` exited 0 for all three cases. I independently repeated the byte reconstruction from the current after bytes and the protected before hashes, without relying on the verifier's reconstructed output. Removing only the recorded half-open byte ranges reproduced each protected before hash:

| file | current after bytes / SHA256 | splice `[start,end)` | rebuilt bytes / before SHA256 | result |
|---|---:|---:|---:|---|
| README | 20,977 / `E208D32ED2FEBD635DD416DC221ECB01992B67F363287CAF8EE11485EE03D8C0` | `[20300,20977)` | 20,300 / `66681D071A4124CBA0E8E635011FEC8CBFFE0AF1B93A453782D63E251D613A46` | pass |
| core16 | 58,474 / `9C1DC8107FFB299F423084410B12E84A7EE58450DA7262C18BD34F0BD8B12C63` | `[57674,58472)` | 57,676 / `12484C7C88E48B36358EB1CF308A414F9EA7A11E869B813BF391B0638BE0C829` | pass |
| core18 | 43,825 / `9D5D32FEDA8320DB05BD2B9B7ECC3FCB5D82C0A832EC27D2A39222DA0960CEAD` | `[40362,43825)` | 40,362 / `A7BFFC313DFEF35C7E302DD251709491A4A91E15D37A275D92FD6FE9D5ACA28C` | pass |

The reconstruction compares the entire resulting byte sequence to each protected before SHA, so arbitrary edits outside the removed append cannot be hidden by the splice. Core16's two trailing CRLF bytes are retained by the `[57674,58472)` range, as required.

## AD-27 semantics and index boundary

R1's architecture findings remain `pass_limited`: H0/H1 is a proposal-only candidate-owned dimensioned-law boundary; typed absence, `terminal_deferred`, `fail_closed`, and `program_exception` remain distinct; N06 unit observations and rule-token hashes do not become physical authority; formal exit still requires B00 F0–F5, 50 fresh B04 receipts, an independent checker, and two fresh processes.

The repair did not change the AD-27 decision files. Current hashes remain exactly the R1 values: `decision.md` `C02340A8850844D6F1D3B0F0CEA162300B3D03EDFFD990CA38345949F32A9FE8`, `decision_manifest.json` `4F70969A4E4AAE5689DF24D6C7254323717F41C77D911D186EFDD11B19E3D171`, and `evidence_manifest.json` `0134FCBC6D09DEAEEB4CB151320DB7A840C70D20045C50658DDB723C3CB8B042`. Their status remains `proposal`/`review_pending`, `accepted=false`, runtime `not_run`.

The README `#ad-27` index, core16 work-order `#ad-27` reference, and core18 AD-27 anchor remain present. The repair therefore proves append provenance only; it does not promote the decision or alter the index semantics.

## Frozen state and QA

HEAD is `4b69f55f7f80240147a65a22809dc1207824dde2`; prewrite dirty status was 292 lines with UTF-8 SHA256 `39e9106701d4ae5a6148bb2ad31e8739c7b03ba59fd7a02ee0e9c6966cdb5017`. JSON parsing, control scan, `validate_plan.py`, independent reconstruction, author verifier, and `git diff --check` are recorded in `command_receipts.json`. The latter emitted only pre-existing LF/CRLF warnings. The archive contains only this review's four files.
