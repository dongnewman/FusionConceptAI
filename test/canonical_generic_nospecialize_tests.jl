using Test
using FusionConceptAI

@testset "generic canonical nospecialize parity" begin
    nested = (z=(b=2, a=1), a=(2, 1))
    @test canonical_json(nested) == "{\"a\":[2,1],\"z\":{\"a\":1,\"b\":2}}"
    nested_hash = canonical_hash(nested)
    @test nested_hash.value == "3f17d4713da9d7e54dbd2e163000d9880c451a1271888862bbb80bce597be563"
    @test canonical_hash(nested) == nested_hash
    @test canonical_hash((z=(b=3, a=1), a=(2, 1))) != nested_hash
    @test canonical_hash((values=Tuple(fill(1.0, 125)),)).value == "4330e261b5dc6cfdcd3d12d65e7e1f9e2c9a63ee074aa361487c757082ca1c5a"
    @test canonical_hash((values=Tuple(fill(1.0, 729)),)).value == "0226fca5fa78a28a1ec18a877696476633daafdd1f651cd3c9466d28497697f7"
    @test canonical_hash((values=Tuple(fill(1.0, 4913)),)).value == "9419d184839b3220faacdba8ba185b01db74d973e4a85bf0ef35e2195147240f"
    @test canonical_json((b=1, a=2)) == "{\"a\":2,\"b\":1}"
    @test canonical_json((values=(1, 2),)) != canonical_json((values=(2, 1),))
    @test canonical_json(-0.0) == "0.0"
    @test canonical_json(1.25) == "1.25"
    @test_throws ArgumentError canonical_json(NaN)
    @test_throws ArgumentError canonical_json(Inf)
    @test canonical_json(1 // 2) == "{\"denominator\":2,\"numerator\":1}"
    d = digest256_text(repeat("0", 64))
    @test canonical_hash(d).value == canonical_hash(semantic_view(d)).value
end
