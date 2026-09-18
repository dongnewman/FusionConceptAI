using Test
using SHA
using Base64
using FusionConceptAI

const _V2_ROOT = joinpath(@__DIR__, "..", "..", "..", "..")
const _V2_G = FusionConceptAI

# Additive definition-only loading: this test does not register V2 or alter
# the V1 admission path.  It is intentionally not part of the package module.
Base.include(_V2_G, joinpath(_V2_ROOT, "src", "Contracts",
    "VNextT1CanonicalBytesV2.jl"))

const _V2_CASES = (
    ("empty", UInt8[], "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", ""),
    ("one_zero", UInt8[0x00], "6e340b9cffb37a989ca544e6bb780a2c78901d3fb33738768511a30617afa01d", "AA=="),
    ("ascii_abc", Vector{UInt8}(codeunits("abc")), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", "YWJj"),
    ("invalid_utf8", UInt8[0xff, 0xfe, 0xc3, 0x28], "33dcc67f14832821b0ea5ff6a8e488c5032470a94422e5836015be475b123943", "//7DKA=="),
)

const _V2_BOUNDARY_BASE64 = (
    n63="AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8gISIjJCUmJygpKissLS4vMDEyMzQ1Njc4OTo7PD0+",
    n64="AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8gISIjJCUmJygpKissLS4vMDEyMzQ1Njc4OTo7PD0+Pw==",
    n65="AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8gISIjJCUmJygpKissLS4vMDEyMzQ1Njc4OTo7PD0+P0A=",
    n1024="CzBVep/E6Q4zWH2ix+wRNluApcrvFDleg6jN8hc8YYar0PUaP2SJrtP4HUJnjLHW+yBFao+02f4jSG2St9wBJktwlbrfBClOc5i94gcsUXabwOUKL1R5nsPoDTJXfKHG6xA1Wn+kye4TOF2Cp8zxFjtgharP9Bk+Y4it0vccQWaLsNX6H0RpjrPY/SJHbJG22wAlSm+Uud4DKE1yl7zhBitQdZq/5AkuU3idwucMMVZ7oMXqDzRZfqPI7RI3XIGmy/AVOl+Eqc7zGD1ih6zR9htAZYqv1PkeQ2iNstf8IUZrkLXa/yRJbpO43QInTHGWu+AFKk90mb7jCC1Sd5zB5gswVXqfxOkOM1h9osfsETZbgKXK7xQ5XoOozfIXPGGGq9D1Gj9kia7T+B1CZ4yx1vsgRWqPtNn+I0htkrfcASZLcJW63wQpTnOYveIHLFF2m8DlCi9UeZ7D6A0yV3yhxusQNVp/pMnuEzhdgqfM8RY7YIWqz/QZPmOIrdL3HEFmi7DV+h9EaY6z2P0iR2yRttsAJUpvlLneAyhNcpe84QYrUHWav+QJLlN4ncLnDDFWe6DF6g80WX6jyO0SN1yBpsvwFTpfhKnO8xg9Yoes0fYbQGWKr9T5HkNojbLX/CFGa5C12v8kSW6TuN0CJ0xxlrvgBSpPdJm+4wgtUnecweYLMFV6n8TpDjNYfaLH7BE2W4Clyu8UOV6DqM3yFzxhhqvQ9Ro/ZImu0/gdQmeMsdb7IEVqj7TZ/iNIbZK33AEmS3CVut8EKU5zmL3iByxRdpvA5QovVHmew+gNMld8ocbrEDVaf6TJ7hM4XYKnzPEWO2CFqs/0GT5jiK3S9xxBZouw1fofRGmOs9j9IkdskbbbACVKb5S53gMoTXKXvOEGK1B1mr/kCS5TeJ3C5wwxVnugxeoPNFl+o8jtEjdcgabL8BU6X4SpzvMYPWKHrNH2G0Bliq/U+R5DaI2y1/whRmuQtdr/JEluk7jdAidMcZa74AUqT3SZvuMILVJ3nMHmCzBVep/E6Q4zWH2ix+wRNluApcrvFDleg6jN8hc8YYar0PUaP2SJrtP4HUJnjLHW+yBFao+02f4jSG2St9wBJktwlbrfBClOc5i94gcsUXabwOUKL1R5nsPoDTJXfKHG6xA1Wn+kye4TOF2Cp8zxFjtgharP9Bk+Y4it0vccQWaLsNX6H0RpjrPY/SJHbJG22wAlSm+Uud4DKE1yl7zhBitQdZq/5AkuU3idwucMMVZ7oMXqDzRZfqPI7RI3XIGmy/AVOl+Eqc7zGD1ih6zR9htAZYqv1PkeQ2iNstf8IUZrkLXa/yRJbpO43QInTHGWu+AFKk90mb7jCC1Sd5zB5g==",
)

function _v2_pattern(n::Int, multiplier::Int, offset::Int)
    bytes = Vector{UInt8}(undef, n)
    for i in eachindex(bytes)
        bytes[i] = UInt8(mod((i - 1) * multiplier + offset, 256))
    end
    bytes
end

@testset "VNextT1CanonicalBytesV2 fixed payloads" begin
    for (id, bytes, expected_sha, expected_b64) in _V2_CASES
        value = _V2_G.VNextT1CanonicalBytesV2(bytes)
        view = _V2_G.semantic_view(value)
        @test id isa String
        @test value.encoding == :base64
        @test value.sha256.value == expected_sha
        @test _V2_G.byte_length(value) == length(bytes)
        @test _V2_G.copy_bytes(value) == bytes
        @test _V2_G.semantic_view(value).base64 == expected_b64
        @test view.schema == "GenomeV5/Contracts/VNextT1CanonicalBytes"
        @test view.version == "v2"
        @test view.encoding == :base64
        @test view.length == length(bytes)
        for i in eachindex(bytes)
            @test _V2_G.byte_at(value, i) == bytes[i]
        end
    end
end

@testset "VNextT1CanonicalBytesV2 boundary patterns" begin
    expected = (
        (63, "29af2686fd53374a36b0846694cc342177e428d1647515f078784d69cdb9e488"),
        (64, "fdeab9acf3710362bd2658cdc9a29e8f9c757fcf9811603a8c447cd1d9151108"),
        (65, "4bfd2c8b6f1eec7a2afeb48b934ee4b2694182027e6d0fc075074f2fabb31781"),
        (1024, "ffbad8f947474cfdd5b2bb22d7e0bf5ee8ba2b7af859d0c2bb28622db6a4be47"),
    )
    for (length, expected_sha) in expected
        bytes = _v2_pattern(length, 37, 11)
        if length < 1024
            bytes = _v2_pattern(length, 1, 0)
        end
        value = _V2_G.VNextT1CanonicalBytesV2(bytes)
        @test _V2_G.byte_length(value) == length
        @test value.sha256.value == expected_sha
        @test _V2_G.copy_bytes(value) == bytes
        @test _V2_G.semantic_view(value).base64 == getproperty(
            _V2_BOUNDARY_BASE64, Symbol(:n, length))
    end
end

@testset "VNextT1CanonicalBytesV2 canonical JSON projection" begin
    value = _V2_G.VNextT1CanonicalBytesV2(UInt8[0xff, 0xfe, 0xc3, 0x28])
    expected = "{\"base64\":\"//7DKA==\",\"encoding\":\"base64\",\"length\":4,\"schema\":\"GenomeV5/Contracts/VNextT1CanonicalBytes\",\"sha256\":{\"value\":\"33dcc67f14832821b0ea5ff6a8e488c5032470a94422e5836015be475b123943\"},\"version\":\"v2\"}"
    @test _V2_G.canonical_json(value) == expected
    nested = (z=(value, :tail), a=(carrier=value, enabled=true))
    nested_expected = "{\"a\":{\"carrier\":" * expected * ",\"enabled\":true},\"z\":[" * expected * ",\"tail\"]}"
    @test _V2_G.canonical_json(nested) == nested_expected
end

@testset "VNextT1CanonicalBytesV2 ownership and replay" begin
    input = UInt8[0x01, 0x02, 0x03, 0x04]
    value = _V2_G.VNextT1CanonicalBytesV2(input)
    input[1] = 0xff
    detached = _V2_G.copy_bytes(value)
    detached[2] = 0xee
    @test _V2_G.copy_bytes(value) == UInt8[0x01, 0x02, 0x03, 0x04]
    @test _V2_G.byte_at(value, 1) == 0x01
    @test_throws BoundsError _V2_G.byte_at(value, 0)
    @test_throws BoundsError _V2_G.byte_at(value, 5)

    replay = _V2_G.semantic_view(value)
    @test replay == _V2_G.semantic_view(
        _V2_G.VNextT1CanonicalBytesV2(UInt8[0x01, 0x02, 0x03, 0x04]))
end


@testset "VNextT1CanonicalBytesV2 invalid UTF-8 ownership" begin
    input = UInt8[0xff, 0xfe, 0xc3, 0x28]
    value = _V2_G.VNextT1CanonicalBytesV2(input)
    input .= 0x00
    detached = _V2_G.copy_bytes(value)
    detached .= 0x11
    @test _V2_G.copy_bytes(value) == UInt8[0xff, 0xfe, 0xc3, 0x28]
    @test _V2_G.semantic_view(value).base64 == "//7DKA=="
end

@testset "VNextT1CanonicalBytesV2 large Vector" begin
    # Deliberately a Vector allocation; no NTuple or tuple materialization is
    # used for the 8,269,445-byte replay case.
    bytes = _v2_pattern(8_269_445, 37, 11)
    value = _V2_G.VNextT1CanonicalBytesV2(bytes)
    @test _V2_G.byte_length(value) == 8_269_445
    @test value.sha256.value == "23c9ceea243a80d1a4dfda9b355038ac2352e144c6dff8fd40d9f3904fa2484c"
    @test _V2_G.byte_at(value, 1) == 0x0b
    @test _V2_G.byte_at(value, 8_269_445) == UInt8(mod((8_269_445 - 1) * 37 + 11, 256))
    # Stable, single-line output for an independent second Julia process.
    println("VNEXT_T1_CANONICAL_BYTES_V2_REPLAY schema=$(_V2_G.VNEXT_T1_CANONICAL_BYTES_V2_SCHEMA) version=$(_V2_G.VNEXT_T1_CANONICAL_BYTES_V2_VERSION) encoding=base64 length=$(_V2_G.byte_length(value)) sha256=$(value.sha256.value) base64_sha256=$(bytes2hex(SHA.sha256(Vector{UInt8}(codeunits(_V2_G.semantic_view(value).base64)))))")
end
