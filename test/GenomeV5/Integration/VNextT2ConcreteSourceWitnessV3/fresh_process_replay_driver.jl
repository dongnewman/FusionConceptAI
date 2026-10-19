using Serialization

include(joinpath(@__DIR__, "fixture_helpers.jl"))

length(ARGS) == 1 || error(
    "usage: fresh_process_replay_driver.jl ARTIFACT_DIRECTORY")
artifact_directory = abspath(ARGS[1])
isdir(artifact_directory) || error(:artifact_directory_missing)

baseline = v3_chain()
baseline.built.status === :source_ready || error(:baseline_not_source_ready)

# This is a fully rebuilt, internally valid foreign source witness.  The
# Python controller launches separate fresh Julia processes that reconstruct
# baseline expectations and accept/reject these witness-only artifacts.
foreign = v3_chain(g2_variant=true)
foreign.built.status === :source_ready || error(:foreign_not_source_ready)
foreign.witness.witness_hash != baseline.witness.witness_hash ||
    error(:foreign_witness_not_distinct)

baseline_path = joinpath(artifact_directory, "baseline-witness.jls")
foreign_path = joinpath(artifact_directory, "foreign-witness.jls")
ispath(baseline_path) && error(:baseline_artifact_already_exists)
ispath(foreign_path) && error(:foreign_artifact_already_exists)
open(baseline_path, "w") do io
    Serialization.serialize(io, baseline.witness)
end
open(foreign_path, "w") do io
    Serialization.serialize(io, foreign.witness)
end

println("artifact_producer=pass")
println("baseline_witness_hash=", baseline.witness.witness_hash.value)
println("foreign_witness_hash=", foreign.witness.witness_hash.value)
