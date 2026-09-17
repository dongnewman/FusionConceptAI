# G-I0 repair R3 provenance

A focused R1 review found that the failure probe was never launched: line 28
of `run_up2_module_entry.jl` defined `_FAILURE_PROBE` but interpolated the
undefined `FAILURE_PROBE`. This repair changes exactly that one interpolation
token to `$_FAILURE_PROBE`. No loader source, probe source, core registration,
old receipt, or independent-review file was changed.

The prior R1 runtime exit and raw evidence remain immutable. This repair is
static only because Sol has not authorized a new Julia run. Any current
external Julia processes were observed and were not started or stopped by this
repair. A different Luna must recheck the new runner hash before serial runtime.
The G-I0 claim ceiling remains wiring/contract only; no UP2-total, B00/B04,
provider, mesh, engineering, physical, or R01-R10 credit is claimed.
