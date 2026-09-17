"""Provider-call accounting for the UP2 contract-only precompiler gate."""

mutable struct UP2InvocationCounterV1
    compile_calls::Int
    solver_calls::Int
    provider_calls::Int
    function UP2InvocationCounterV1()
        new(0, 0, 0)
    end
end

function up2_compile!(counter::UP2InvocationCounterV1, f::Function)
    counter.compile_calls += 1
    f()
end

up2_provider_calls(counter::UP2InvocationCounterV1) = counter.provider_calls
up2_solver_calls(counter::UP2InvocationCounterV1) = counter.solver_calls

"""UP2 deliberately has no provider dispatch; this method is a hard stop."""
function up2_provider!(::UP2InvocationCounterV1, args...)
    throw(ArgumentError("UP2-00 is contract-only and cannot invoke a provider"))
end
