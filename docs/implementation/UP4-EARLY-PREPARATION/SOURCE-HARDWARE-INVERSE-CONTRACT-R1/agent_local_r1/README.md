# UP4 source/hardware inverse contract R1

This is an additive contract-only slice for a future inverse realization
request.  It does not resolve a provider, call a derivative, construct
hardware, run an inverse solver, invoke DESC, modify the optimizer or change
the provider registry.

The request is candidate-bound at the contract identity level and explicitly
declares target, source, return, units, function spaces, domains, finite
bounds, electrical power/current/voltage, EMF policy, material and geometry.
Provider capability is a typed declaration only.  Contradictory target,
return, unit, function-space, domain or EMF declarations are `fail_closed`.
Missing provider capability, derivative capability or return port is
`terminal_deferred`.  A complete positive declaration reaches at most
`prepared` with `claim_ceiling=:contract_only` and `provider_calls=0`.

Julia/DESC was not run in this package.  `static_qa.py` is the only QA
runner; its output is a static boundary check, not runtime evidence.
