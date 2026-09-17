# R7 static selector normalization repair

R6 preserved the typed identity index but exposed a second implementation
exception on the positive actual-A projection. The selected G1 occurrence is
an anonymous typed tuple `(String, String, Symbol, Int64)`, while the authored
selector normalizer returns a NamedTuple. The equality predicate therefore
reported `G1 authored governing occurrence has no source match` at source line
329 even though the four typed fields matched.

The bounded repair constructs the left side of that predicate as the same
four-field NamedTuple shape returned by `_n06_selector_key`. It does not
stringify the tuple or weaken duplicate detection. The owned fixture/test now
also include a real wrong-source-selector control: the actual projection path
must raise the source-match `ArgumentError`, and the selector is restored in a
`finally` block. The existing missing-selector control remains.

Static selector/source review found the current actual identities consistent:
G1 equation `governing-0` and occurrence `(energy, governing-0, output, 1)`;
G1 closure `energy-balance`; G2 interface-left `left`/`right` and boundary
`left/x_min`; G3 effort port `source_effort`, its entry/account/closure,
flow port `source_flow`, and `source-loop` link. G2 interface and G3 kind
selection remain unique-match guards; ambiguity fails closed. This is still a
contract projection only and supplies no cross-layer authority, provider,
engineering, physical, B04, or R01-R10 credit.

No Julia/DESC run was performed after the R6 failure. A different-Luna static
precheck is required before requesting another focused run. Status remains
`review_pending`/`accepted=false`.
