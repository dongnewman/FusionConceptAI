# Receipt export focused R1 narrow repair

The immutable focused R1 archive records real exit 1 and a pre-export
`feedback target requires GenomeContractRef` program exception. The only code
repair is in the new receipt-export test fixture builder: its G3 feedback
construction now uses the materialized `g1.contract_ref` outer public ref,
matching the G3 constructor's declared `GenomeContractRef` type. Production
N05 source, receipt exporter/checker, frozen R4 source/test/fixture/runner,
and prior R1/R2/R3 archives were not edited.

This is static preparation only. The R1 failure, no-envelope retention gap,
raw logs, and exit-artifact correction remain immutable. No Julia/DESC rerun
was performed; independent static precheck is required before a new serial
focused attempt.
