using JSON3
using Serialization
using FusionConceptAI

layer = ARGS[1]
output = ARGS[2]
if layer == "G1"
    include(joinpath(@__DIR__, "..", "G1", "up1_g1_contract_tests.jl"))
    value = _g1_fixture()[1]
elseif layer == "G2"
    include(joinpath(@__DIR__, "..", "G2", "up1_g2_contract_tests.jl"))
    value = _g2_build("split_x_1")[1]
elseif layer == "G3"
    include(joinpath(@__DIR__, "..", "G3", "up1_g3_contract_tests.jl"))
    value = _make_fixture()
else
    error("unknown layer: $layer")
end
open(output, "w") do io
    Serialization.serialize(io, value)
end
