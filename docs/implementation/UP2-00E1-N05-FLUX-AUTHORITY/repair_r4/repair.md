# E1 N05 trusted serialized negative-control repair R4

This bounded repair changes only the E1 receipt checker and its export test.
The checker now has a trusted overload of `n05_check_receipt_file` that reads
the JSON3 envelope from disk and immediately calls the actual-A/E0 five-argument
source-bound checker. The existing one-argument schema-only file check remains
available and is not treated as source-bound evidence.

The positive receipt is now exercised through the trusted file overload. Each
forged or omitted control is written as a separate JSON file, read back by the
same trusted file overload, and checked for a targeted `ArgumentError`: source
hash mismatch reaches actual source recomputation; mutation hash, candidate,
package, E0, declaration and row-count controls have distinct expected
rejection messages. This prevents a format-only rejection from satisfying all
negative controls. The exporter, N05 production source, fixture, runner and
R1-R3 raw archives are unchanged.

The checker and exporter still share `_n05e_row`; independent checker
recomputation remains an explicit formal B04 follow-up and is not claimed
closed here. No Julia/DESC execution was performed. Status remains
`review_pending`; the full receipt-export gate remains `changes_requested`,
with no physical, engineering, provider, mesh, B04 or R01-R10 credit.

