# UP4 source/hardware inverse contract R3

R3 replaces the R2 string-prefix exception classifier with the exact typed
`InverseExternalInputError` channel.  Constructor and checked-conversion seams
throw this type; `admit_inverse_realization_request` catches only this exact
type and converts it to `:fail_closed`.  Ordinary `ArgumentError`,
`MethodError`, and `ErrorException` values—including ones with the same text as
the typed error—are rethrown.

This remains additive and `contract_only`: no provider, derivative, hardware,
inverse solver, Julia runtime, or DESC execution was performed.
