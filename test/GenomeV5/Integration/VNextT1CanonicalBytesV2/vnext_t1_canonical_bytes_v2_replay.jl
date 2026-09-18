using Test
using SHA
using Base64
using FusionConceptAI

const _V2_REPLAY_ROOT = joinpath(@__DIR__, "..", "..", "..", "..")
const _V2_REPLAY_G = FusionConceptAI

# Independent process loading: V2 remains definition-only and is not connected
# to the package include/export or production T1 admission boundary.
Base.include(_V2_REPLAY_G, joinpath(_V2_REPLAY_ROOT, "src", "Contracts",
    "VNextT1CanonicalBytesV2.jl"))

function _v2_replay_pattern(n::Int, multiplier::Int, offset::Int)
    bytes = Vector{UInt8}(undef, n)
    for i in eachindex(bytes)
        bytes[i] = UInt8(mod((i - 1) * multiplier + offset, 256))
    end
    bytes
end

@testset "VNextT1CanonicalBytesV2 independent replay" begin
    small = _V2_REPLAY_G.VNextT1CanonicalBytesV2(UInt8[0x00])
    @test small.sha256.value == "6e340b9cffb37a989ca544e6bb780a2c78901d3fb33738768511a30617afa01d"
    @test _V2_REPLAY_G.semantic_view(small).base64 == "AA=="

    invalid = _V2_REPLAY_G.VNextT1CanonicalBytesV2(UInt8[0xff, 0xfe, 0xc3, 0x28])
    expected_json = "{\"base64\":\"//7DKA==\",\"encoding\":\"base64\",\"length\":4,\"schema\":\"GenomeV5/Contracts/VNextT1CanonicalBytes\",\"sha256\":{\"value\":\"33dcc67f14832821b0ea5ff6a8e488c5032470a94422e5836015be475b123943\"},\"version\":\"v2\"}"
    @test invalid.sha256.value == "33dcc67f14832821b0ea5ff6a8e488c5032470a94422e5836015be475b123943"
    @test _V2_REPLAY_G.copy_bytes(invalid) == UInt8[0xff, 0xfe, 0xc3, 0x28]
    @test _V2_REPLAY_G.canonical_json(invalid) == expected_json
    nested = (z=(invalid, :tail), a=(carrier=invalid, enabled=true))
    nested_expected = "{\"a\":{\"carrier\":" * expected_json * ",\"enabled\":true},\"z\":[" * expected_json * ",\"tail\"]}"
    @test _V2_REPLAY_G.canonical_json(nested) == nested_expected

    # The full payload is reconstructed in this second Julia process as a
    # Vector. No giant NTuple or length-parameterized type is formed.
    bytes = _v2_replay_pattern(8_269_445, 37, 11)
    large = _V2_REPLAY_G.VNextT1CanonicalBytesV2(bytes)
    view = _V2_REPLAY_G.semantic_view(large)
    base64_sha256 = bytes2hex(SHA.sha256(
        Vector{UInt8}(codeunits(view.base64))))
    @test view.schema == "GenomeV5/Contracts/VNextT1CanonicalBytes"
    @test view.version == "v2"
    @test view.encoding == :base64
    @test view.length == 8_269_445
    @test view.sha256.value == "23c9ceea243a80d1a4dfda9b355038ac2352e144c6dff8fd40d9f3904fa2484c"
    @test base64_sha256 == "1bd44c97ae64c380363e1fb4ddfe5ffa44d2e1422d8b78ad5f601c9fb9869e0b"
    @test _V2_REPLAY_G.byte_at(large, 1) == 0x0b
    @test _V2_REPLAY_G.byte_at(large, 8_269_445) ==
        UInt8(mod((8_269_445 - 1) * 37 + 11, 256))

    println("VNEXT_T1_CANONICAL_BYTES_V2_INDEPENDENT_REPLAY schema=$(view.schema) version=$(view.version) encoding=$(view.encoding) length=$(view.length) sha256=$(view.sha256.value) base64_sha256=$base64_sha256")
end
