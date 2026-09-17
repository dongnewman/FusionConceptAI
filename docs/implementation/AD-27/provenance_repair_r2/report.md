# AD-27 provenance repair R2

## Verdict

`changes_requested`; `status=review_pending`; `accepted=false`. This is an append-only provenance repair record. It does not modify AD-27 R1, the three core files, source, tests, runs, or prior archives, and it does not run Julia/DESC.

The R1 decision manifest supplies the protected before hashes. The current after bytes match the final hashes reported for the AD-27 author change. A read-only verifier performs exact byte splices and checks that the reconstructed bytes match the R1 before hashes:

| file | current after bytes / SHA256 | removed byte range `[start,end)` | reconstructed before SHA256 | result |
|---|---:|---:|---:|---|
| `README.md` | 20,977 / `E208D32ED2FEBD635DD416DC221ECB01992B67F363287CAF8EE11485EE03D8C0` | `[20300,20977)` | `66681D071A4124CBA0E8E635011FEC8CBFFE0AF1B93A453782D63E251D613A46` | pass |
| `16_execution_work_orders.md` | 58,474 / `9C1DC8107FFB299F423084410B12E84A7EE58450DA7262C18BD34F0BD8B12C63` | `[57674,58472)`; preserves final CRLF bytes | `12484C7C88E48B36358EB1CF308A414F9EA7A11E869B813BF391B0638BE0C829` | pass |
| `18_sources_and_architecture_decisions.md` | 43,825 / `9D5D32FEDA8320DB05BD2B9B7ECC3FCB5D82C0A832EC27D2A39222DA0960CEAD` | `[40362,43825)` | `A7BFFC313DFEF35C7E302DD251709491A4A91E15D37A275D92FD6FE9D5ACA28C` | pass |

The splice start is the original EOF boundary for each file. The splice end preserves the two trailing CRLF bytes in core16, which is necessary to reproduce its before bytes exactly. Marker offsets and all hashes are independently recomputed by `verify_append.py`; the verifier writes no files.

## Scope and remaining review gate

The reversibility check establishes append provenance only. It does not accept AD-27, H0/H1, a dimensioned G1→G2→G3 law, B00/B04, provider, mesh, engineering, physical, or R01–R10 evidence. AD-27 remains proposal/review_pending until a different Luna reviews the decision and provenance record and Sol adjudicates.

The dirty worktree was protected at HEAD `4b69f55f7f80240147a65a22809dc1207824dde2`; the pre-edit status inventory was 290 lines with SHA256 `A7DDFA270908670436014147A9449FA5C01EB0EEA098B397BDAF240072161585`. Current core after hashes above are the author-reported final bytes; no claim is made about unrelated dirty changes.
