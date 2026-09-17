# repair_r6: declaration candidate provenance gate

Independent R1 found that pairing did not reject a declaration whose own candidate reference was foreign while its upstream and target projections were internally consistent. This repair adds a deterministic `declaration_candidate_mismatch` error before any pairing, including before the fresh-authority branch. `_vnext_ar_pair` repeats the same guard for direct/internal callers; upstream authority and target authority candidate references remain checked against the input candidate.

The focused negative constructs a foreign declaration with a self-consistent G3 declaration hash and matching foreign G1/G2 upstream and target authority records. It must fail closed, return no output, and preserve the input T0 bundle bytes and SHA-256. The fixture and all core/T0/T1/AD-34 evidence remain unchanged.

R6 verification used the direct outer PowerShell process path. Static QA passed 20 checks. The direct focused Julia test passed 68/68, with raw stdout/stderr and machine receipts retained beside this proposal. The machine node remains `accepted=false`, all authority/credit flags remain false, and a different Luna/high review is still required.
