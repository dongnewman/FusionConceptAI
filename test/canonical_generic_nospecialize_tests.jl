using Test
using FusionConceptAI
using SHA

@testset "canonical streaming dictionary and array legacy parity" begin
    legacy_canonical = value -> invoke(FusionConceptAI._canonical,
        Tuple{Any}, value)
    legacy_sha256 = wire -> bytes2hex(SHA.sha256(
        Vector{UInt8}(codeunits(wire))))

    dictionary = Dict("z" => [2, 1], "a" => "源🙂")
    dictionary_wire = "{\"a\":\"源🙂\",\"z\":{\"shape\":[2],\"values\":[2,1]}}"
    dictionary_sha256 = "2644bcc6711bc5ae3705a7908a6cf1cd582a399dd2c7b68c073fd86e21068b45"
    @test legacy_canonical(dictionary) == dictionary_wire
    @test canonical_json(dictionary) == dictionary_wire
    @test canonical_hash(dictionary).value == dictionary_sha256
    @test canonical_hash(dictionary).value == legacy_sha256(legacy_canonical(dictionary))

    nested = (z=Dict("b" => 2, "a" => 1), a=[1 3; 2 4])
    nested_wire = "{\"a\":{\"shape\":[2,2],\"values\":[1,2,3,4]},\"z\":{\"a\":1,\"b\":2}}"
    nested_sha256 = "d360bdc6a0334b1838dba0213a99e6c74ed31b2a6b21e828e008fd43dcb9eec3"
    @test legacy_canonical(nested) == nested_wire
    @test canonical_json(nested) == nested_wire
    @test canonical_hash(nested).value == nested_sha256
    @test canonical_hash(nested).value == legacy_sha256(legacy_canonical(nested))

    # Re-encoding a mutable matrix must observe current column-major contents.
    mutable_nested = (z=Dict("b" => 2, "a" => 1), a=[1 3; 2 4])
    before = canonical_json(mutable_nested)
    mutable_nested.a[2, 1] = 9
    after_wire = "{\"a\":{\"shape\":[2,2],\"values\":[1,9,3,4]},\"z\":{\"a\":1,\"b\":2}}"
    after_sha256 = "b0eaab34d90485f34c7c5b3a044ee95d06326edd372fdbf6000ca1af023f90f2"
    @test before == nested_wire
    @test canonical_json(mutable_nested) == after_wire
    @test canonical_hash(mutable_nested).value == after_sha256
    @test canonical_hash(mutable_nested).value == legacy_sha256(legacy_canonical(mutable_nested))
end

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
    @test canonical_json(Float32(-0.0)) == "0.0"
    @test canonical_json(1.25) == "1.25"
    # Exercise the generic Float64 writer against the previous Base formatter.
    float64_cases = (0.1, prevfloat(1.0), nextfloat(1.0),
        floatmax(Float64), floatmin(Float64), prevfloat(floatmin(Float64)),
        nextfloat(0.0), 1.0e-6, nextfloat(1.0e20))
    for value in float64_cases
        @test canonical_json(value) == Base.repr(value)
    end
    float32_cases = (Float32(0.1), nextfloat(Float32(0)),
        floatmin(Float32), prevfloat(floatmin(Float32)), floatmax(Float32),
        prevfloat(Float32(1)), nextfloat(Float32(1)))
    for value in float32_cases
        @test canonical_json(value) == Base.repr(Float64(value))
    end
    # Fixed random-bit corpus, generated offline with seed 20261004.
    random_float64_bits = UInt64[0x0ddce92c2cb31a1d, 0x4d82c616c12ba2e7,
        0x4640aba06491d4ce, 0x30d2e06e85ed1b46, 0xbe466ae1d3efbbac,
        0xabe25052b4a7d8f0, 0x79db88a92072874b, 0xf20f7fbd25154b6e]
    for bits in random_float64_bits
        value = reinterpret(Float64, bits)
        @test canonical_json(value) == Base.repr(value)
    end
    @test_throws ArgumentError canonical_json(NaN)
    @test_throws ArgumentError canonical_json(Inf)
    @test canonical_json(1 // 2) == "{\"denominator\":2,\"numerator\":1}"
    zero_unit_wire = "{\"exponents\":[{\"denominator\":1,\"numerator\":0},{\"denominator\":1,\"numerator\":0},{\"denominator\":1,\"numerator\":0},{\"denominator\":1,\"numerator\":0},{\"denominator\":1,\"numerator\":0},{\"denominator\":1,\"numerator\":0},{\"denominator\":1,\"numerator\":0}]}"
    zero_unit_semantic = (exponents=ntuple(_ -> 0 // 1, 7),)
    zero_unit_hash = "5dbea18cf4a46e8d295a05f4d4ae5c142e9351686002b7057d4c575d407a2e3c"
    @test canonical_json(zero_unit_semantic) == zero_unit_wire
    @test canonical_hash(zero_unit_semantic).value == zero_unit_hash
    @test canonical_json(UnitSignature()) == zero_unit_wire
    @test canonical_hash(UnitSignature()).value == zero_unit_hash
    d = digest256_text(repeat("0", 64))
    @test canonical_hash(d).value == canonical_hash(semantic_view(d)).value
end

@testset "UInt8 vector canonical serialization matches the old generic path" begin
    legacy_canonical = value -> invoke(FusionConceptAI._canonical,
        Tuple{Any}, value)
    legacy_sha256 = wire -> bytes2hex(SHA.sha256(
        Vector{UInt8}(codeunits(wire))))

    all_bytes = collect(UInt8(0):UInt8(255))
    cases = Vector{Pair{String,Vector{UInt8}}}()
    push!(cases, "empty" => UInt8[])
    push!(cases, "all_256" => all_bytes)
    for n in (1, 2, 7, 8, 15, 16, 31, 32, 63, 64, 127, 128,
            255, 256, 257)
        bytes = UInt8[mod((i - 1) * 73 + 19, 256) for i in 1:n]
        push!(cases, "boundary_$(n)" => bytes)
    end
    for (label, source_text) in (("unicode_supplementary", "λ😺𠜎"),
            ("unicode_combining", "e\u0301\u03bb"),
            ("unicode_nul", "left\0右"))
        push!(cases, label => Vector{UInt8}(codeunits(source_text)))
    end

    for (label, bytes) in cases
        old_wire = legacy_canonical(bytes)
        @test FusionConceptAI._canonical(bytes) == old_wire
        @test canonical_json(bytes) == old_wire
        @test canonical_hash(bytes).value == legacy_sha256(old_wire)
        @test label isa String
    end

    # This test-only projection reconstructs only the old generic Vector shape
    # while leaving the canonical tuple/NamedTuple serializer in charge of the
    # enclosing values. It verifies byte vectors nested in source/package and
    # context records without adding a second general serializer.
    function legacy_vector_tree(value)
        if value isa Vector{UInt8}
            return (shape=Tuple(size(value)), values=Tuple(value))
        elseif value isa NamedTuple
            names = keys(value)
            return NamedTuple{names}(Tuple(legacy_vector_tree(getfield(value, name))
                for name in names))
        elseif value isa Tuple
            return map(legacy_vector_tree, value)
        end
        value
    end

    nested_bytes = UInt8[0x00, 0x7f, 0x80, 0xff]
    source_package_context = (
        context=(schema="source-package-context-v1", generation=UInt32(2),
            byte_evidence=nested_bytes),
        source_packages=(
            g1=(candidate="candidate-a", source=(bytes=nested_bytes,
                marker=:g1_source)),
            g2=(candidate="candidate-b", declaration=(
                payload_bytes=UInt8[0x41, 0x00, 0xfe], marker=:g2_declaration))),
        child_sources=((kind=:t0, bytes=UInt8[]),
            (kind=:t1, bytes=Vector{UInt8}(codeunits("源🙂")))))
    nested_wire = canonical_json(source_package_context)
    old_nested_wire = canonical_json(legacy_vector_tree(source_package_context))
    @test nested_wire == old_nested_wire
    @test canonical_hash(source_package_context).value == legacy_sha256(old_nested_wire)
    @test occursin("\"shape\":[4],\"values\":[0,127,128,255]", nested_wire)

    # A Vector-only method must not change scalar byte/integer/float encoding.
    numeric_context = (u8=UInt8(255), u16=UInt16(256), signed=Int64(-7),
        finite=1.25, negative_zero=-0.0)
    @test canonical_json(numeric_context) ==
        "{\"finite\":1.25,\"negative_zero\":0.0,\"signed\":-7,\"u16\":256,\"u8\":255}"

    mutable_bytes = UInt8[0x00, 0x7f, 0xff]
    before_mutation = canonical_json(mutable_bytes)
    mutable_bytes[2] = 0x80
    after_mutation = legacy_canonical(mutable_bytes)
    @test canonical_json(mutable_bytes) == after_mutation
    @test canonical_hash(mutable_bytes).value == legacy_sha256(after_mutation)
    @test after_mutation != before_mutation
end

@testset "canonical JSON memo exact-target nested scope" begin
    with_memo = FusionConceptAI._with_canonical_json_memo
    memoized = FusionConceptAI._canonical_json_memoized
    target = (values=(1, 2, 3),)
    foreign_target = (values=(4, 5, 6),)
    target_evaluations = Ref(0)
    foreign_evaluations = Ref(0)

    outer_value = with_memo(target) do
        first = memoized(target) do
            target_evaluations[] += 1
            canonical_json(target)
        end
        nested_value = with_memo(target) do
            memoized(target) do
                target_evaluations[] += 1
                canonical_json(target)
            end
        end
        @test nested_value == first

        foreign_values = with_memo(foreign_target) do
            foreign_first = memoized(foreign_target) do
                foreign_evaluations[] += 1
                canonical_json(foreign_target)
            end
            foreign_second = memoized(foreign_target) do
                foreign_evaluations[] += 1
                canonical_json(foreign_target)
            end
            shadowed_outer = memoized(target) do
                target_evaluations[] += 1
                canonical_json(target)
            end
            @test foreign_first == foreign_second
            @test shadowed_outer == first
            (foreign_first, foreign_second)
        end
        restored_outer = memoized(target) do
            target_evaluations[] += 1
            canonical_json(target)
        end
        @test restored_outer == first
        @test target_evaluations[] == 2
        @test foreign_evaluations[] == 1
        (first, foreign_values)
    end

    @test target_evaluations[] == 2
    @test foreign_evaluations[] == 1
    after_outer_exit = memoized(target) do
        target_evaluations[] += 1
        canonical_json(target)
    end
    @test after_outer_exit == outer_value[1]
    @test target_evaluations[] == 3

    mutable_target = (values=[1, 2, 3],)
    mutable_evaluations = Ref(0)
    with_memo(mutable_target) do
        first = memoized(mutable_target) do
            mutable_evaluations[] += 1
            canonical_json(mutable_target)
        end
        second = memoized(mutable_target) do
            mutable_evaluations[] += 1
            canonical_json(mutable_target)
        end
        @test first == second
    end
    @test mutable_evaluations[] == 2

    throw_target = (value=7,)
    throw_evaluations = Ref(0)
    sentinel = ErrorException("canonical memo scope sentinel")
    caught = try
        with_memo(throw_target) do
            memoized(throw_target) do
                throw_evaluations[] += 1
                canonical_json(throw_target)
            end
            throw(sentinel)
        end
    catch err
        err
    end
    @test caught === sentinel
    after_throw = memoized(throw_target) do
        throw_evaluations[] += 1
        canonical_json(throw_target)
    end
    @test after_throw == "{\"value\":7}"
    @test throw_evaluations[] == 2
end

@testset "canonical TypedAST payload memo scope" begin
    parameter_spec = OperatorParameterSpecV1(:delay, :finite_nonnegative_real, true)
    @test FusionConceptAI._tac_value_string(parameter_spec) ==
        "{\"name\":\"delay\",\"required\":true,\"type_tag\":\"finite_nonnegative_real\"}"

    registry = default_operator_registry()
    scalar = PhysicalType(:scalar_field, 0, 3,
        TemporalTypeV1(static_time), UnitSignature())
    input = ASTInputV1(1, scalar)
    identity = ASTApplyV1(OperatorRefV1("IDENTITY", "v1"), (1,), (;);
        registry=registry, input_types=(scalar,))
    program = TypedASTProgramV1((input, identity), (2,), (1,); registry=registry)
    negation = ASTApplyV1(OperatorRefV1("NEG", "v1"), (1,), (;);
        registry=registry, input_types=(scalar,))
    foreign_program = TypedASTProgramV1((input, negation), (2,), (1,); registry=registry)

    golden = "{\"input_ports\":[{\"node\":1,\"port\":1}],\"nodes\":[{\"kind\":\"input\",\"output_type\":{\"spatial_dimension\":3,\"temporal_type\":{\"clock_ref\":null,\"derivative_order\":0,\"kind\":\"static_time\"},\"tensor_rank\":0,\"units\":{\"exponents\":[{\"denominator\":1,\"numerator\":0},{\"denominator\":1,\"numerator\":0},{\"denominator\":1,\"numerator\":0},{\"denominator\":1,\"numerator\":0},{\"denominator\":1,\"numerator\":0},{\"denominator\":1,\"numerator\":0},{\"denominator\":1,\"numerator\":0}]},\"value_kind\":\"scalar_field\"},\"parameters\":{},\"port\":1},{\"inputs\":[1],\"kind\":\"apply\",\"operator_ref\":{\"qualified\":{\"id\":\"IDENTITY\",\"version\":\"v1\"}},\"output_type\":{\"spatial_dimension\":3,\"temporal_type\":{\"clock_ref\":null,\"derivative_order\":0,\"kind\":\"static_time\"},\"tensor_rank\":0,\"units\":{\"exponents\":[{\"denominator\":1,\"numerator\":0},{\"denominator\":1,\"numerator\":0},{\"denominator\":1,\"numerator\":0},{\"denominator\":1,\"numerator\":0},{\"denominator\":1,\"numerator\":0},{\"denominator\":1,\"numerator\":0},{\"denominator\":1,\"numerator\":0}]},\"value_kind\":\"scalar_field\"},\"parameters\":{}}],\"roots\":[2],\"used_manifest_bindings\":[[{\"qualified\":{\"id\":\"IDENTITY\",\"version\":\"v1\"}},{\"value\":\"6b2e8e860b9b279bcea6d018db148d43cbc6e7d135961da9d281a8847521d7cf\"}]]}"
    @test canonical_json(program) == golden
    @test canonical_hash(program).value == "f7c255b351b2e589a2a9d6da76d9cda3d216734a38d3d42715164a86c5887732"

    with_memo = FusionConceptAI._with_canonical_json_memo
    payload_memoized = FusionConceptAI._canonical_payload_memoized
    counter = FusionConceptAI._tac_test_payload_counter_start()
    try
        first_scope = with_memo(program; payload_targets=(program,)) do
            first_json = canonical_json(program)
            first_hash = canonical_hash(program)
            second_json = canonical_json(program)
            second_hash = canonical_hash(program)
            @test first_json == golden
            @test second_json == first_json
            @test second_hash == first_hash
            @test counter[] == 1

            nested_same = with_memo(program) do
                (canonical_json(program), canonical_hash(program))
            end
            @test nested_same == (first_json, first_hash)
            @test counter[] == 1

            # A program outside the explicit payload target set always takes
            # the projection path, even when called repeatedly in this scope.
            foreign_json_a = canonical_json(foreign_program)
            foreign_json_b = canonical_json(foreign_program)
            @test foreign_json_a == foreign_json_b
            @test counter[] == 3

            # A nested scope may cache its own listed program and must restore
            # the outer program's still-live payload afterward.
            with_memo(foreign_program; payload_targets=(foreign_program,)) do
                canonical_json(foreign_program)
                canonical_json(foreign_program)
            end
            @test counter[] == 4
            @test canonical_hash(program) == first_hash
            @test counter[] == 4
            (first_json, first_hash)
        end
        @test first_scope[1] == golden
        @test first_scope[2].value == "f7c255b351b2e589a2a9d6da76d9cda3d216734a38d3d42715164a86c5887732"
        @test counter[] == 4
        @test canonical_json(program) == golden
        @test counter[] == 5
    finally
        FusionConceptAI._tac_test_payload_counter_stop!()
    end

    scoped_target = (scope=:payload_test,)
    throw_target = (target=:throwing_projection,)
    throw_calls = Ref(0)
    with_memo(scoped_target; payload_targets=(throw_target,)) do
        thrown = try
            payload_memoized(throw_target) do
                throw_calls[] += 1
                error("projection sentinel")
            end
        catch err
            err
        end
        @test thrown isa ErrorException
        successful_payload = payload_memoized(throw_target) do
            throw_calls[] += 1
            (value=(1, 2),)
        end
        repeated_payload = payload_memoized(throw_target) do
            throw_calls[] += 1
            (value=(3, 4),)
        end
        @test repeated_payload == successful_payload
    end
    @test throw_calls[] == 2

    mutable_payload_target = (target=:mutable_payload,)
    mutable_payload_calls = Ref(0)
    with_memo(scoped_target; payload_targets=(mutable_payload_target,)) do
        first_payload = payload_memoized(mutable_payload_target) do
            mutable_payload_calls[] += 1
            [1, 2]
        end
        second_payload = payload_memoized(mutable_payload_target) do
            mutable_payload_calls[] += 1
            [1, 2]
        end
        @test first_payload == second_payload
        @test first_payload !== second_payload
    end
    @test mutable_payload_calls[] == 2

    mutable_target = [1, 2]
    mutable_target_calls = Ref(0)
    with_memo(scoped_target; payload_targets=(mutable_target,)) do
        payload_memoized(mutable_target) do
            mutable_target_calls[] += 1
            Tuple(mutable_target)
        end
        payload_memoized(mutable_target) do
            mutable_target_calls[] += 1
            Tuple(mutable_target)
        end
    end
    @test mutable_target_calls[] == 2
end

@testset "canonical native tree fallback preserves wire and error order" begin
    bytes = UInt8[0x00, 0x7f, 0xff]
    value = (
        a_ref=QualifiedRefV1("candidate-a", "v1"),
        payload=(bytes=bytes, nested=((UInt8[0x41, 0x00, 0xfe], "λ🙂"),)))
    original_wire = "{\"a_ref\":{\"id\":\"candidate-a\",\"version\":\"v1\"},\"payload\":{\"bytes\":{\"shape\":[3],\"values\":[0,127,255]},\"nested\":[[{\"shape\":[3],\"values\":[65,0,254]},\"λ🙂\"]]}}"
    original_sha256 = "551698ab3facfabaa08de17f0236336ccfefbf7b4b7f9f38df73532f19dfff24"
    @test canonical_json(value) == original_wire
    @test canonical_hash(value).value == original_sha256

    # Re-encoding must observe current bytes even when the enclosing value
    # takes the unsupported-leaf fallback path.
    bytes[2] = 0x80
    mutated_wire = "{\"a_ref\":{\"id\":\"candidate-a\",\"version\":\"v1\"},\"payload\":{\"bytes\":{\"shape\":[3],\"values\":[0,128,255]},\"nested\":[[{\"shape\":[3],\"values\":[65,0,254]},\"λ🙂\"]]}}"
    mutated_sha256 = "c407619165ee5af207be0b117e3091b229fe084adfbbc35445b0c83e36e5049a"
    @test canonical_json(value) == mutated_wire
    @test canonical_hash(value).value == mutated_sha256
    @test mutated_sha256 != original_sha256

    canonical_error = f -> try
        f()
        nothing
    catch err
        err
    end
    invalid_utf8 = String(UInt8[0xff])
    ref_before_invalid = (
        a_ref=QualifiedRefV1("candidate-a", "v1"), z_invalid=invalid_utf8)
    invalid_error = canonical_error(() -> canonical_json(ref_before_invalid))
    @test invalid_error isa ArgumentError
    @test sprint(showerror, invalid_error) ==
        "ArgumentError: invalid UTF-8 or surrogate string is not canonical"

    # The ref makes the native-tree size probe reject the value; canonical
    # traversal must still report the earlier non-finite field before UTF-8.
    nan_before_invalid = (
        a_ref=QualifiedRefV1("candidate-a", "v1"),
        b_nonfinite=NaN, z_invalid=invalid_utf8)
    order_error = canonical_error(() -> canonical_json(nan_before_invalid))
    @test order_error isa ArgumentError
    @test sprint(showerror, order_error) ==
        "ArgumentError: non-finite values are not canonical"
end

@testset "Float64 array writer matches generic canonical oracle" begin
    # Force the unchanged top-level generic Array method as the independent
    # reference; the wrapped NamedTuple drives the writer under test.
    legacy_array = value -> invoke(FusionConceptAI._canonical, Tuple{Any}, value)
    legacy_sha256 = wire -> bytes2hex(SHA.sha256(Vector{UInt8}(codeunits(wire))))
    oracle_object = array -> "{\"a\":" * legacy_array(array) * "}"
    arrays = (
        Float64[],
        zeros(0, 3),
        fill(2.75),
        reshape(Float64[1.0, -0.0, prevfloat(floatmin(Float64)), floatmax(Float64)], 2, 2),
        reshape(Float64[0.1, -0.0, nextfloat(0.0), floatmin(Float64),
            -1.25, 3.5, prevfloat(1.0), floatmax(Float64)], 2, 2, 2))
    for array in arrays
        expected_wire = oracle_object(array)
        expected_hash = legacy_sha256(expected_wire)
        @test canonical_json((a=array,)) == expected_wire
        @test canonical_hash((a=array,)).value == expected_hash
    end

    mutable_matrix = [1.0 3.0; 2.0 4.0]
    before_object = (a=mutable_matrix,)
    before_wire = oracle_object(mutable_matrix)
    before_hash = legacy_sha256(before_wire)
    @test canonical_json(before_object) == before_wire
    @test canonical_hash(before_object).value == before_hash
    mutable_matrix[2, 1] = 9.0
    after_object = (a=mutable_matrix,)
    after_wire = oracle_object(mutable_matrix)
    after_hash = legacy_sha256(after_wire)
    @test after_wire != before_wire
    @test after_hash != before_hash
    @test canonical_json(after_object) == after_wire
    @test canonical_hash(after_object).value == after_hash

    canonical_error = f -> try
        f()
        nothing
    catch err
        err
    end
    for value in (NaN, Inf, -Inf)
        array = Float64[value]
        legacy_error = canonical_error(() -> legacy_array(array))
        @test legacy_error isa ArgumentError
        @test sprint(showerror, legacy_error) ==
            "ArgumentError: non-finite values are not canonical"
        object = (a=array,)
        for f in (() -> canonical_json(object), () -> canonical_hash(object))
            writer_error = canonical_error(f)
            @test writer_error isa ArgumentError
            @test sprint(showerror, writer_error) == sprint(showerror, legacy_error)
        end
    end

    invalid_utf8 = String(UInt8[0xff])
    array_before_invalid = (a_array=Float64[NaN], z_invalid=invalid_utf8)
    ordered_error = canonical_error(() -> canonical_json(array_before_invalid))
    legacy_array_error = canonical_error(() -> legacy_array(array_before_invalid.a_array))
    @test ordered_error isa ArgumentError
    @test sprint(showerror, ordered_error) == sprint(showerror, legacy_array_error)
    @test sprint(showerror, ordered_error) ==
        "ArgumentError: non-finite values are not canonical"
end
