using Serialization

include(joinpath(@__DIR__, "fixture_helpers.jl"))

length(ARGS) == 2 || error(
    "usage: replay_child.jl SERIALIZED_WITNESS EXPECTED_STATUS")
witness = open(Serialization.deserialize, ARGS[1])
expected_status = Symbol(ARGS[2])

# Rebuild the authorized current source inputs independently in this fresh
# process.  Only the witness under test crosses the Serialization boundary.
chain = v3_chain()
result = v3_validate(chain, witness)
println("status=", result.status)
println("source_ready=", result.source_ready)
println("witness_hash=", witness.witness_hash.value)
expected_ready = expected_status === :source_ready
exit(result.status === expected_status && result.source_ready == expected_ready ? 0 : 1)
