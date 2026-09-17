# UP4 source/hardware inverse contract R2

This additive repair closes the R1 independent-review blocker at the external
request-admission seam.  Malformed conversion and type-dispatch inputs are
checked in narrow helpers and become a typed `:fail_closed` result without
provider calls.  The accepted error class is limited to the contract's tagged
`inverse_input:` constructor boundary; validation and identity checks execute
outside the catch and therefore still expose real internal defects.

The static vectors cover malformed Float64, Symbol/MethodError, Int/InexactError,
Int/OverflowError, and TypeError conversion paths, plus explicit internal
`ErrorException` and untagged `ArgumentError` non-swallowing cases.

This remains `contract_only`: no provider resolution, derivative, hardware
construction, inverse solve, Julia runtime, or DESC execution was performed.
