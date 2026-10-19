include(joinpath(@__DIR__, "fixture_helpers.jl"))

chain = v3_chain()
println("prepare_status=", chain.built.status)
println("prepare_errors=", chain.built.errors)
println("prepare_gaps=", chain.built.gaps)

checked = V3_G._vnext_t2_v3_validate_inputs(chain.transport, chain.recheck,
    chain.parent, chain.expected, chain.bridge, chain.realization_state,
    chain.control_payload, chain.control_state, chain.binding_key)
println("validate_kind=", checked.kind)
println("validate_errors=", checked.errors)
println("validate_gaps=", checked.gaps)

try
    witness = V3_G._vnext_t2_v3_build(chain.transport, chain.recheck,
        chain.parent, chain.expected, chain.bridge, chain.realization_state,
        chain.control_payload, chain.control_state, checked.material)
    println("diagnostic_unexpected_build_success=", witness.witness_hash.value)
    exit(2)
catch err
    println("diagnostic_exception_type=", typeof(err))
    println("diagnostic_exception_captured=true")
    println(stderr, sprint(showerror, err, catch_backtrace()))
end
