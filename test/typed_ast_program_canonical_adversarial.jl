using Test
using FusionConceptAI
using SHA
using JSON3
using Serialization

# Independent reference for the pre-pruning exhaustive search: every node
# order builds and serializes its complete candidate before choosing the
# lexicographic minimum.
function _tac_test_legacy_exhaustive_text(program::TypedASTProgramV1)
    node_count = length(program.nodes)
    permutations = FusionConceptAI._tac_permutations(node_count)
    best_text = nothing
    for order in permutations
        candidate, _ = FusionConceptAI._tac_candidate_for_order(program, order)
        text = FusionConceptAI._tac_value_string(candidate)
        if best_text === nothing || FusionConceptAI._tac_string_less(text, best_text)
            best_text = text
        end
    end
    best_text::String
end

function _tac_test_matches_legacy_exhaustive(program::TypedASTProgramV1)
    expected_text = _tac_test_legacy_exhaustive_text(program)
    expected_hash = Digest256(bytes2hex(SHA.sha256(
        Vector{UInt8}(codeunits(expected_text)))))
    @test canonical_json(program) == expected_text
    @test canonical_hash(program) == expected_hash
    nothing
end

@testset "TypedASTProgramV1 closed canonical identity" begin
    registry = default_operator_registry()
    unit = UnitSignature()
    scalar = PhysicalType(:scalar_field, 0, 3, TemporalTypeV1(static_time), unit)
    input = ASTInputV1(1, scalar)
    apply = ASTApplyV1(OperatorRefV1("IDENTITY", "v1"), (1,), (;);
        registry=registry, input_types=(scalar,))
    program = TypedASTProgramV1((input, apply), (2,), (1,); registry=registry)
    json_before = canonical_json(program)
    hash_before = canonical_hash(program)
    @test hash_before isa Digest256
    @test length(json_before) > 0

    @testset "manifest bindings are derived" begin
        @test length(program.used_manifest_bindings) == 1
        @test program.used_manifest_bindings[1][1].qualified.id == "IDENTITY"
        @test_throws ArgumentError TypedASTProgramV1((input, apply), (2,), (1,);
            registry=registry, used_manifest_bindings=program.used_manifest_bindings)
        identity_manifest = operator_manifest(registry, QualifiedRefV1("IDENTITY", "v1"))
        altered_identity = OperatorManifestV1(identity_manifest.operator_ref, identity_manifest.input_arity,
            identity_manifest.output_arity, identity_manifest.input_type_rule, identity_manifest.output_type_rule;
            allowed_roles=(identity_manifest.allowed_roles..., :boundary),
            parameter_schema=identity_manifest.parameter_schema, locality=identity_manifest.locality,
            max_derivative_contribution=identity_manifest.max_derivative_contribution,
            pure=identity_manifest.pure, stateful=identity_manifest.stateful,
            stochastic=identity_manifest.stochastic, event=identity_manifest.event,
            commutative_input_groups=identity_manifest.commutative_input_groups,
            cse_allowed=identity_manifest.cse_allowed,
            allowed_conservation_effects=identity_manifest.allowed_conservation_effects,
            forbidden_conservation_effects=identity_manifest.forbidden_conservation_effects)
        variant_ops = tuple(altered_identity, (m for m in registry.operators
            if m.operator_ref != identity_manifest.operator_ref)...)
        variant_registry = OperatorRegistryV1(variant_ops)
        variant_apply = ASTApplyV1(OperatorRefV1("IDENTITY", "v1"), (1,), (;);
            registry=variant_registry, input_types=(scalar,))
        variant_program = TypedASTProgramV1((input, variant_apply), (2,), (1,); registry=variant_registry)
        @test variant_program.used_manifest_bindings[1][2] != program.used_manifest_bindings[1][2]
        @test canonical_hash(variant_program) != canonical_hash(program)
    end

    @testset "HEAD golden complex multi-root program" begin
        input_g = ASTInputV1(1, scalar, (label="Ω\0",))
        parameter_g = ASTParameterV1(Symbol("gainΩ"), scalar, (note="组合", ratio=3//7))
        constant_g = ASTConstantV1(:offset, Int64(-17), scalar, (text="quote\\slash",))
        apply_g = ASTApplyV1(OperatorRefV1("IDENTITY", "v1"), (1,), (;);
            registry=registry, input_types=(scalar,))
        complex = TypedASTProgramV1((input_g, parameter_g, constant_g, apply_g), (4, 2, 3), (1,);
            registry=registry)
        golden = "{\"input_ports\":[{\"node\":1,\"port\":1}],\"nodes\":[{\"kind\":\"input\",\"output_type\":{\"spatial_dimension\":3,\"temporal_type\":{\"clock_ref\":null,\"derivative_order\":0,\"kind\":\"static_time\"},\"tensor_rank\":0,\"units\":{\"exponents\":[{\"denominator\":1,\"numerator\":0},{\"denominator\":1,\"numerator\":0},{\"denominator\":1,\"numerator\":0},{\"denominator\":1,\"numerator\":0},{\"denominator\":1,\"numerator\":0},{\"denominator\":1,\"numerator\":0},{\"denominator\":1,\"numerator\":0}]},\"value_kind\":\"scalar_field\"},\"parameters\":{\"label\":\"Ω\\u0000\"},\"port\":1},{\"inputs\":[1],\"kind\":\"apply\",\"operator_ref\":{\"qualified\":{\"id\":\"IDENTITY\",\"version\":\"v1\"}},\"output_type\":{\"spatial_dimension\":3,\"temporal_type\":{\"clock_ref\":null,\"derivative_order\":0,\"kind\":\"static_time\"},\"tensor_rank\":0,\"units\":{\"exponents\":[{\"denominator\":1,\"numerator\":0},{\"denominator\":1,\"numerator\":0},{\"denominator\":1,\"numerator\":0},{\"denominator\":1,\"numerator\":0},{\"denominator\":1,\"numerator\":0},{\"denominator\":1,\"numerator\":0},{\"denominator\":1,\"numerator\":0}]},\"value_kind\":\"scalar_field\"},\"parameters\":{}},{\"kind\":\"constant\",\"output_type\":{\"spatial_dimension\":3,\"temporal_type\":{\"clock_ref\":null,\"derivative_order\":0,\"kind\":\"static_time\"},\"tensor_rank\":0,\"units\":{\"exponents\":[{\"denominator\":1,\"numerator\":0},{\"denominator\":1,\"numerator\":0},{\"denominator\":1,\"numerator\":0},{\"denominator\":1,\"numerator\":0},{\"denominator\":1,\"numerator\":0},{\"denominator\":1,\"numerator\":0},{\"denominator\":1,\"numerator\":0}]},\"value_kind\":\"scalar_field\"},\"parameters\":{\"text\":\"quote\\\\slash\"},\"value\":-17},{\"kind\":\"parameter\",\"output_type\":{\"spatial_dimension\":3,\"temporal_type\":{\"clock_ref\":null,\"derivative_order\":0,\"kind\":\"static_time\"},\"tensor_rank\":0,\"units\":{\"exponents\":[{\"denominator\":1,\"numerator\":0},{\"denominator\":1,\"numerator\":0},{\"denominator\":1,\"numerator\":0},{\"denominator\":1,\"numerator\":0},{\"denominator\":1,\"numerator\":0},{\"denominator\":1,\"numerator\":0},{\"denominator\":1,\"numerator\":0}]},\"value_kind\":\"scalar_field\"},\"parameters\":{\"note\":\"组合\",\"ratio\":{\"denominator\":7,\"numerator\":3}}}],\"roots\":[2,4,3],\"used_manifest_bindings\":[[{\"qualified\":{\"id\":\"IDENTITY\",\"version\":\"v1\"}},{\"value\":\"6b2e8e860b9b279bcea6d018db148d43cbc6e7d135961da9d281a8847521d7cf\"}]]}"
        @test canonical_json(complex) == golden
        @test canonical_hash(complex).value == "053fbc497e60f44b173374bf9246430161be63141276d5be67a4d8e06edf1c0a"
        @test canonical_hash(complex) == Digest256(bytes2hex(SHA.sha256(Vector{UInt8}(codeunits(golden)))))
    end

    @testset "normalization, identity, and permutation" begin
        add_a = ASTApplyV1(OperatorRefV1("ADD", "v1"), (1, 2), (;);
            registry=registry, input_types=(scalar, scalar))
        add_b = ASTApplyV1(OperatorRefV1("ADD", "v1"), (2, 1), (;);
            registry=registry, input_types=(scalar, scalar))
        p_add_a = TypedASTProgramV1((ASTInputV1(1, scalar), ASTInputV1(2, scalar), add_a), (3,), (1, 2); registry=registry)
        p_add_b = TypedASTProgramV1((ASTInputV1(1, scalar), ASTInputV1(2, scalar), add_b), (3,), (1, 2); registry=registry)
        @test canonical_hash(p_add_a) == canonical_hash(p_add_b)

        id1 = ASTApplyV1(OperatorRefV1("IDENTITY", "v1"), (1,), (;); registry=registry, input_types=(scalar,))
        id2 = ASTApplyV1(OperatorRefV1("IDENTITY", "v1"), (1,), (;); registry=registry, input_types=(scalar,))
        add = ASTApplyV1(OperatorRefV1("ADD", "v1"), (2, 3), (;); registry=registry, input_types=(scalar, scalar))
        merged = TypedASTProgramV1((ASTInputV1(1, scalar), id1, id2, add), (4,), (1,); registry=registry)
        one = ASTApplyV1(OperatorRefV1("ADD", "v1"), (2, 2), (;); registry=registry, input_types=(scalar, scalar))
        single = TypedASTProgramV1((ASTInputV1(1, scalar), id1, one), (3,), (1,); registry=registry)
        @test length(merged.nodes) == 3
        @test canonical_hash(merged) == canonical_hash(single)

        differential = PhysicalType(:scalar_field, 0, 3, TemporalTypeV1(differential_time), unit)
        delay1 = ASTApplyV1(OperatorRefV1("DELAY", "v1"), (1,), (delay_seconds=0.0,); registry=registry, input_types=(differential,))
        delay2 = ASTApplyV1(OperatorRefV1("DELAY", "v1"), (1,), (delay_seconds=0.0,); registry=registry, input_types=(differential,))
        delayed = TypedASTProgramV1((ASTInputV1(1, differential), delay1, delay2), (2, 3), (1,); registry=registry)
        @test length(delayed.nodes) == 3
        single_delay = TypedASTProgramV1((ASTInputV1(1, differential), delay1), (2,), (1,); registry=registry)
        @test length(single_delay.nodes) == 2
        @test canonical_hash(delayed) != canonical_hash(single_delay)

        fixed_program = TypedASTProgramV1((ASTInputV1(1, scalar), ASTParameterV1(:fixed, scalar),
            ASTApplyV1(OperatorRefV1("IDENTITY", "v1"), (1,), (;); registry=registry, input_types=(scalar,))),
            (3, 2), (1,); registry=registry)
        fixed_candidate, fixed_refs = FusionConceptAI._tac_candidate_for_order(fixed_program, (2, 3, 1))
        @test fixed_refs == [3, 1, 2]
        @test fixed_candidate.nodes[2].inputs == (3,)
        @test fixed_candidate.roots == (2, 1)
        @test fixed_candidate.input_ports[1].node == 3
        fixed_helper_ports = FusionConceptAI._tac_input_ports_for_order(
            fixed_program, (2, 3, 1))
        @test Vector{UInt8}(codeunits(FusionConceptAI._tac_value_string(
            fixed_helper_ports))) == Vector{UInt8}(codeunits(
                FusionConceptAI._tac_value_string(fixed_candidate.input_ports)))

        input_c = ASTInputV1(1, scalar, (label="Ω\0",))
        parameter_c = ASTParameterV1(Symbol("gainΩ"), scalar, (note="组合", ratio=3//7))
        constant_c = ASTConstantV1(:offset, Int64(-17), scalar, (text="quote\\slash",))
        apply_c = ASTApplyV1(OperatorRefV1("IDENTITY", "v1"), (1,), (;); registry=registry, input_types=(scalar,))
        p_cycle_a = TypedASTProgramV1((input_c, parameter_c, constant_c, apply_c), (4, 2, 3), (1,); registry=registry)
        apply_cycle = ASTApplyV1(OperatorRefV1("IDENTITY", "v1"), (3,), (;); registry=registry, input_types=(scalar,))
        p_cycle_b = TypedASTProgramV1((parameter_c, constant_c, input_c, apply_cycle), (4, 1, 2), (3,); registry=registry)
        @test canonical_hash(p_cycle_a) == canonical_hash(p_cycle_b)
    end

    @testset "semantic changes alter identity" begin
        changed_operator = ASTApplyV1(OperatorRefV1("NEG", "v1"), (1,), (;); registry=registry, input_types=(scalar,))
        op_program = TypedASTProgramV1((input, changed_operator), (2,), (1,); registry=registry)
        changed_parameters = TypedASTProgramV1((ASTInputV1(1, scalar, (marker=1,)), apply), (2,), (1,); registry=registry)
        changed_type = PhysicalType(:different_scalar, 0, 3, TemporalTypeV1(static_time), unit)
        changed_input = ASTInputV1(1, changed_type)
        changed_apply = ASTApplyV1(OperatorRefV1("IDENTITY", "v1"), (1,), (;); registry=registry, input_types=(changed_type,))
        type_program = TypedASTProgramV1((changed_input, changed_apply), (2,), (1,); registry=registry)
        @test length(Set((canonical_hash(program), canonical_hash(op_program), canonical_hash(changed_parameters), canonical_hash(type_program)))) == 4
        input_r = ASTInputV1(1, scalar, (label="Ω\0",))
        parameter_r = ASTParameterV1(Symbol("gainΩ"), scalar, (note="组合", ratio=3//7))
        constant_r = ASTConstantV1(:offset, Int64(-17), scalar, (text="quote\\slash",))
        apply_r = ASTApplyV1(OperatorRefV1("IDENTITY", "v1"), (1,), (;); registry=registry, input_types=(scalar,))
        root_changed = TypedASTProgramV1((input_r, parameter_r, constant_r, apply_r), (4, 3, 2), (1,); registry=registry)
        root_original = TypedASTProgramV1((input_r, parameter_r, constant_r, apply_r), (4, 2, 3), (1,); registry=registry)
        @test canonical_hash(root_original) != canonical_hash(root_changed)
        port_program = TypedASTProgramV1((ASTInputV1(2, scalar), apply), (2,), (1,); registry=registry)
        @test canonical_hash(program) != canonical_hash(port_program)
    end

    @testset "all safe integer extrema" begin
        extrema = ((Int8(typemin(Int8)), Int8(typemax(Int8))), (Int16(typemin(Int16)), Int16(typemax(Int16))),
            (Int32(typemin(Int32)), Int32(typemax(Int32))), (Int64(typemin(Int64)), Int64(typemax(Int64))),
            (Int128(typemin(Int128)), Int128(typemax(Int128))), (UInt8(0), UInt8(typemax(UInt8))),
            (UInt16(0), UInt16(typemax(UInt16))), (UInt32(0), UInt32(typemax(UInt32))),
            (UInt64(0), UInt64(typemax(UInt64))), (UInt128(0), UInt128(typemax(UInt128))))
        for pair in extrema
            @test FusionConceptAI._tac_value_string((value=pair[1],)) == "{\"value\":" * string(pair[1]) * "}"
            @test FusionConceptAI._tac_value_string((value=pair[2],)) == "{\"value\":" * string(pair[2]) * "}"
        end
    end

    @testset "closed float golden values" begin
        @test FusionConceptAI._tac_value_string((value=Float16(0.0),)) == "{\"value\":0.0}"
        @test FusionConceptAI._tac_value_string((value=Float16(-0.0),)) == "{\"value\":0.0}"
        @test FusionConceptAI._tac_value_string((value=nextfloat(Float16(0)),)) == "{\"value\":5.960464477539063e-8}"
        @test FusionConceptAI._tac_value_string((value=floatmax(Float16),)) == "{\"value\":65504.0}"
        @test FusionConceptAI._tac_value_string((value=Float32(0.0),)) == "{\"value\":0.0}"
        @test FusionConceptAI._tac_value_string((value=Float32(-0.0),)) == "{\"value\":0.0}"
        @test FusionConceptAI._tac_value_string((value=nextfloat(Float32(0)),)) == "{\"value\":1.401298464324817e-45}"
        @test FusionConceptAI._tac_value_string((value=floatmax(Float32),)) == "{\"value\":3.4028234663852886e38}"
        @test FusionConceptAI._tac_value_string((value=Float64(0.0),)) == "{\"value\":0.0}"
        @test FusionConceptAI._tac_value_string((value=Float64(-0.0),)) == "{\"value\":0.0}"
        @test FusionConceptAI._tac_value_string((value=nextfloat(0.0),)) == "{\"value\":5.0e-324}"
        @test FusionConceptAI._tac_value_string((value=floatmax(Float64),)) == "{\"value\":1.7976931348623157e308}"
    end

    @testset "eight-node boundary and deferred ninth node" begin
        nodes = AbstractTypedASTNodeV1[input]
        i = 1
        while i <= 7
            previous = length(nodes)
            push!(nodes, ASTApplyV1(OperatorRefV1("IDENTITY", "v1"), (previous,), (;);
                registry=registry, input_types=(scalar,)))
            i += 1
        end
        eight = TypedASTProgramV1(Tuple(nodes), (8,), (1,); registry=registry)
        @test canonical_json(eight) isa String
        @test canonical_hash(eight) isa Digest256
        # Exercise the 8! search boundary once against the complete old path.
        _tac_test_matches_legacy_exhaustive(eight)
        push!(nodes, ASTApplyV1(OperatorRefV1("IDENTITY", "v1"), (8,), (;);
            registry=registry, input_types=(scalar,)))
        nine = TypedASTProgramV1(Tuple(nodes), (9,), (1,); registry=registry)
        @test_throws CanonicalizationDeferred canonical_json(nine)
    end

    @testset "input-port prefix pruning matches exhaustive canonical bytes" begin
        # Two differently ordered declarations and node tuples must retain the
        # same canonical result; ports are ordered by their declared numbers.
        port_nine = ASTInputV1(9, scalar)
        port_two = ASTInputV1(2, scalar)
        sum_ports = ASTApplyV1(OperatorRefV1("ADD", "v1"), (1, 2), (;);
            registry=registry, input_types=(scalar, scalar))
        ports_a = TypedASTProgramV1((port_nine, port_two, sum_ports), (3,), (1, 2);
            registry=registry)
        ports_b = TypedASTProgramV1((port_two, port_nine, sum_ports), (3,), (2, 1);
            registry=registry)
        _tac_test_matches_legacy_exhaustive(ports_a)
        _tac_test_matches_legacy_exhaustive(ports_b)
        for order in FusionConceptAI._tac_permutations(length(ports_a.nodes))
            candidate, _ = FusionConceptAI._tac_candidate_for_order(ports_a, order)
            helper_ports = FusionConceptAI._tac_input_ports_for_order(ports_a, order)
            @test Vector{UInt8}(codeunits(FusionConceptAI._tac_value_string(
                helper_ports))) == Vector{UInt8}(codeunits(
                    FusionConceptAI._tac_value_string(candidate.input_ports)))
        end
        @test canonical_json(ports_a) == canonical_json(ports_b)
        @test canonical_hash(ports_a) == canonical_hash(ports_b)

        # Empty input-port prefixes still use the original whole-payload
        # minimum, including ordered multiple roots.
        constant_a = ASTConstantV1(:left, Int64(3), scalar)
        constant_b = ASTConstantV1(:right, Int64(5), scalar)
        no_ports = TypedASTProgramV1((constant_a, constant_b), (2, 1), ();
            registry=registry)
        @test no_ports.input_ports == ()
        _tac_test_matches_legacy_exhaustive(no_ports)

        # These two full candidates have identical input_ports and node
        # payloads; only the mapped roots differ. The first must win by the
        # original full-string comparison after an equal prefix.
        repeated_a = ASTConstantV1(:same_a, Int64(1), scalar)
        repeated_b = ASTConstantV1(:same_b, Int64(1), scalar)
        root_apply = ASTApplyV1(OperatorRefV1("IDENTITY", "v1"), (1,), (;);
            registry=registry, input_types=(scalar,))
        root_tie = TypedASTProgramV1((input, repeated_a, repeated_b, root_apply),
            (4, 2, 3), (1,); registry=registry)
        order_a = (1, 4, 2, 3)
        order_b = (1, 4, 3, 2)
        candidate_a, _ = FusionConceptAI._tac_candidate_for_order(root_tie, order_a)
        candidate_b, _ = FusionConceptAI._tac_candidate_for_order(root_tie, order_b)
        @test candidate_a.input_ports == candidate_b.input_ports
        @test candidate_a.nodes == candidate_b.nodes
        @test candidate_a.roots != candidate_b.roots
        text_a = FusionConceptAI._tac_value_string(candidate_a)
        text_b = FusionConceptAI._tac_value_string(candidate_b)
        @test FusionConceptAI._tac_string_less(text_a, text_b)
        @test _tac_test_legacy_exhaustive_text(root_tie) == text_a
        _tac_test_matches_legacy_exhaustive(root_tie)

        # Malformed field declarations remain constructor errors; the
        # optimization is only defined for valid TypedASTProgramV1 values.
        @test_throws ArgumentError TypedASTProgramV1((input, apply), (3,), (1,);
            registry=registry)
        @test_throws ArgumentError TypedASTProgramV1((input, apply), (2,), (3,);
            registry=registry)
        duplicate_port_a = ASTInputV1(1, scalar)
        duplicate_port_b = ASTInputV1(1, scalar)
        duplicate_sum = ASTApplyV1(OperatorRefV1("ADD", "v1"), (1, 2), (;);
            registry=registry, input_types=(scalar, scalar))
        @test_throws ArgumentError TypedASTProgramV1(
            (duplicate_port_a, duplicate_port_b, duplicate_sum), (3,), (1, 2);
            registry=registry)
    end

    @testset "fresh process dispatch pollution" begin
        function _tac_probe(definition, trigger)
            script = """
            using FusionConceptAI
            using SHA
            @enum ConcreteKind alpha beta
            const HIT = Ref(false)
            r = default_operator_registry()
            u = UnitSignature()
            t = PhysicalType(:scalar_field, 0, 3, TemporalTypeV1(static_time), u)
            i = ASTInputV1(1, t, (kind=alpha,))
            a = ASTApplyV1(OperatorRefV1(\"IDENTITY\", \"v1\"), (1,), (;); registry=r, input_types=(t,))
            p = TypedASTProgramV1((i, a), (2,), (1,); registry=r)
            iv = (Int8(typemin(Int8)), Int8(typemax(Int8)), Int16(typemin(Int16)), Int16(typemax(Int16)),
                Int32(typemin(Int32)), Int32(typemax(Int32)), Int64(typemin(Int64)), Int64(typemax(Int64)),
                Int128(typemin(Int128)), Int128(typemax(Int128)), UInt8(0), UInt8(typemax(UInt8)),
                UInt16(0), UInt16(typemax(UInt16)), UInt32(0), UInt32(typemax(UInt32)),
                UInt64(0), UInt64(typemax(UInt64)), UInt128(0), UInt128(typemax(UInt128)))
            ip = TypedASTProgramV1((ASTConstantV1(:integer_extrema, iv, t),), (1,), (); registry=r)
            cse_left = ASTApplyV1(OperatorRefV1("IDENTITY", "v1"), (1,), (;); registry=r, input_types=(t,))
            cse_right = ASTApplyV1(OperatorRefV1("IDENTITY", "v1"), (1,), (;); registry=r, input_types=(t,))
            cse_apply = ASTApplyV1(OperatorRefV1("ADD", "v1"), (2, 3), (;); registry=r, input_types=(t, t))
            cse_before_program = TypedASTProgramV1((i, cse_left, cse_right, cse_apply), (4,), (1,); registry=r)
            cse_before_nodes = fieldcount(typeof(cse_before_program.nodes))
            cse_before_json = canonical_json(cse_before_program)
            cse_before_hash = canonical_hash(cse_before_program).value
            baseline = (canonical_json(p), canonical_hash(p).value, canonical_json(ip), canonical_hash(ip).value)
            $definition
            $trigger
            @assert HIT[]
            @assert baseline[1] === canonical_json(p)
            @assert baseline[2] === canonical_hash(p).value
            @assert baseline[3] === canonical_json(ip)
            @assert baseline[4] === canonical_hash(ip).value
            exit(0)
            """
            result = success(Cmd(`$(Base.julia_cmd()) --startup-file=no --project=$(Base.active_project()) -e $script`; windows_hide=true))
            result || println(stderr, "FAILED AST poison probe: ", definition)
            result
        end
        probes = (
            ("@eval Base.print(::IOBuffer, ::String) = (HIT[] = true; nothing)", "Base.print(IOBuffer(), \"x\")"),
            ("@eval Base.:*(::String, ::String) = (HIT[] = true; \"poison\")", "Base.:*(\"a\", \"b\")"),
            ("@eval Base.:*(::String, ::String, ::String...) = (HIT[] = true; \"poison\")", "Base.:*(\"a\", \"b\", \"c\")"),
            ("@eval Base.string(::Int8) = (HIT[] = true; \"poison\"); @eval Base.string(::Int16) = (HIT[] = true; \"poison\"); @eval Base.string(::Int32) = (HIT[] = true; \"poison\"); @eval Base.string(::Int64) = (HIT[] = true; \"poison\"); @eval Base.string(::Int128) = (HIT[] = true; \"poison\"); @eval Base.string(::UInt8) = (HIT[] = true; \"poison\"); @eval Base.string(::UInt16) = (HIT[] = true; \"poison\"); @eval Base.string(::UInt32) = (HIT[] = true; \"poison\"); @eval Base.string(::UInt64) = (HIT[] = true; \"poison\"); @eval Base.string(::UInt128) = (HIT[] = true; \"poison\")", "string(Int8(1)); string(Int16(1)); string(Int32(1)); string(Int64(1)); string(Int128(1)); string(UInt8(1)); string(UInt16(1)); string(UInt32(1)); string(UInt64(1)); string(UInt128(1))"),
            ("@eval Base.codeunits(::String) = (HIT[] = true; UInt8[]) ", "Base.codeunits(\"x\")"),
            ("@eval Base.ncodeunits(::String) = (HIT[] = true; 0)", "Base.ncodeunits(\"x\")"),
            ("@eval Base.getindex(::String, ::Int) = (HIT[] = true; error(\"poison\"))", "try \"x\"[1] catch; end"),
            ("@eval Base.firstindex(::String) = (HIT[] = true; 1)", "Base.firstindex(\"x\")"),
            ("@eval Base.nextind(::String, ::Int) = (HIT[] = true; 1)", "Base.nextind(\"x\", 1)"),
            ("@eval Base.iterate(::Tuple, ::Int) = (HIT[] = true; nothing)", "Base.iterate((1,), 1)"),
            ("@eval Base.iterate(::Vector{Int}, ::Int) = (HIT[] = true; nothing)", "Base.iterate(Int[1], 1)"),
            ("@eval Base.getindex(::Vector{Int}, ::Int) = (HIT[] = true; 0)", "Int[1][1]"),
            ("@eval Base.join(::Tuple, ::AbstractString) = (HIT[] = true; \"poison\")", "Base.join((1, 2), \",\")"),
            ("@eval Base.bytes2hex(::Vector{UInt8}) = (HIT[] = true; \"poison\")", "Base.bytes2hex(UInt8[1])"),
            ("@eval SHA.sha256(::Base.CodeUnits{UInt8,String}) = (HIT[] = true; UInt8[]) ", "using SHA; SHA.sha256(codeunits(\"x\"))"),
            ("@eval FusionConceptAI.canonical_json(::Any) = (HIT[] = true; \"poison\")", "FusionConceptAI.canonical_json(1)"),
            ("@eval FusionConceptAI.canonical_hash(::Any) = (HIT[] = true; Digest256(repeat(\"a\", 64)))", "FusionConceptAI.canonical_hash(1)"),
            ("@eval FusionConceptAI.semantic_view(::Any) = (HIT[] = true; \"poison\")", "FusionConceptAI.semantic_view(1)"),
            ("@eval Base.hash(::String, ::UInt) = (HIT[] = true; UInt(0))", "Base.hash(\"x\", UInt(0))"),
            ("@eval Base.Symbol(::ConcreteKind) = (HIT[] = true; :poison)", "Base.Symbol(alpha)"),
        )
        for (definition, trigger) in probes
            if occursin("Base.hash(::String", definition)
                trigger = trigger * "; dup_left = ASTApplyV1(OperatorRefV1(\"IDENTITY\", \"v1\"), (1,), (;); registry=r, input_types=(t,)); dup_right = ASTApplyV1(OperatorRefV1(\"IDENTITY\", \"v1\"), (1,), (;); registry=r, input_types=(t,)); dup_apply = ASTApplyV1(OperatorRefV1(\"ADD\", \"v1\"), (2, 3), (;); registry=r, input_types=(t, t)); cse_after_program = TypedASTProgramV1((i, dup_left, dup_right, dup_apply), (4,), (1,); registry=r); @assert fieldcount(typeof(cse_after_program.nodes)) == cse_before_nodes; @assert cse_before_json === canonical_json(cse_after_program); @assert cse_before_hash === canonical_hash(cse_after_program).value"
            end
            @test _tac_probe(definition, trigger)
        end
    end
end

struct _TACUntrustedSmallInteger <: Integer end
Base.:<(::_TACUntrustedSmallInteger, other::Integer) = 7 < other
Base.:<(other::Integer, ::_TACUntrustedSmallInteger) = other < 7
Base.:(==)(::_TACUntrustedSmallInteger, other::Integer) = 7 == other
Base.:(==)(other::Integer, ::_TACUntrustedSmallInteger) = other == 7
Base.convert(::Type{Int}, ::_TACUntrustedSmallInteger) = 7

const _TAC_N10_T1_A = get(ENV, "UP2_N10_STREAMING_T1_A", "")
const _TAC_N10_T1_B = get(ENV, "UP2_N10_STREAMING_T1_B", "")

@testset "UP2 N10 streaming canonical bytes match legacy normalizer" begin
    G = FusionConceptAI
    G.load_genome_v5_up2_components!()
    G.load_vnext_t2_components_v2!()

    function assert_n10_byte_parity(raw)
        legacy = canonical_json(G._up2_n10_json_semantic(raw))
        streamed = G._up2_n10_canonical_json(raw)
        @test Vector{UInt8}(codeunits(streamed)) ==
            Vector{UInt8}(codeunits(legacy))
        streamed
    end

    # Compare any UInt8 fast method with the pre-fast-path generic fallback.
    for byte in UInt8(0):typemax(UInt8)
        @test G._canonical(byte) == invoke(G._canonical, Tuple{Any}, byte)
    end

    nested_a = JSON3.read("""{"z":[{"b":2,"a":1},null,true],"a":{"Ω":"line\\nquote\\\"slash\\\\","zero":-0.0}}""")
    nested_b = JSON3.read("""{"a":{"zero":0.0,"Ω":"line\\nquote\\\"slash\\\\"},"z":[{"a":1,"b":2},null,true]}""")
    nested_bytes = assert_n10_byte_parity(nested_a)
    @test nested_a.a.zero isa Int64
    @test nested_bytes == """{"a":{"zero":0,"Ω":"line\\nquote\\\"slash\\\\"},"z":[{"a":1,"b":2},null,true]}"""
    @test assert_n10_byte_parity(nested_b) == nested_bytes

    duplicate_keys = JSON3.read(raw"""{"same":1,"nested":{"same":3,"same":4},"same":2}""")
    duplicate_result = assert_n10_byte_parity(duplicate_keys)
    @test duplicate_result == raw"""{"nested":{"same":4},"same":2}"""

    scalar_edges = JSON3.read(raw"""{"byte0":0,"byte1":1,"byte255":255,"byte_over":256,"negative":-1,"int_min":-9223372036854775808,"int_max":9223372036854775807,"large":18446744073709551616,"float":1.25,"exponent":1.25E+5,"negative_zero":-0.0,"null":null,"false":false,"true":true}""")
    scalar_bytes = assert_n10_byte_parity(scalar_edges)
    @test scalar_edges.negative_zero isa Int64
    @test assert_n10_byte_parity(-0.0) == "0.0"
    @test occursin("\"byte255\":255", scalar_bytes)
    @test occursin("\"byte_over\":256", scalar_bytes)
    @test occursin("\"negative_zero\":0", scalar_bytes)
    @test occursin("\"null\":null", scalar_bytes)
    @test occursin("\"false\":false", scalar_bytes)
    @test occursin("\"true\":true", scalar_bytes)

    rational_wire = JSON3.read(raw"""{"unit":{"exponents":[{"denominator":1,"numerator":0},{"denominator":7,"numerator":3}]},"ratio":{"denominator":7,"numerator":3}}""")
    @test assert_n10_byte_parity(rational_wire) ==
        raw"""{"ratio":{"denominator":7,"numerator":3},"unit":{"exponents":[{"denominator":1,"numerator":0},{"denominator":7,"numerator":3}]}}"""
    @test assert_n10_byte_parity((ratio=3 // 7,)) ==
        raw"""{"ratio":{"denominator":7,"numerator":3}}"""
    @test_throws ArgumentError G._up2_n10_canonical_json((value=BigInt(2)^200,))
    @test_throws ArgumentError canonical_json(_TACUntrustedSmallInteger())
    @test_throws ArgumentError G._up2_n10_canonical_json(_TACUntrustedSmallInteger())

    if !isempty(_TAC_N10_T1_A) || !isempty(_TAC_N10_T1_B)
        @test !isempty(_TAC_N10_T1_A) && !isempty(_TAC_N10_T1_B)
        function check_actual_t1(path)
            artifact_bytes = read(path)
            admission = Serialization.deserialize(IOBuffer(artifact_bytes))
            @test admission isa G.VNextT1AdmissionResultV2
            @test admission.package isa G.CandidateStatePackageV5NextV2
            package = admission.package
            @test package.status === :prepared_not_executed
            @test package.accepted === false
            t0_wire_bytes = G.copy_bytes(package.wire)
            @test G.Digest256(bytes2hex(SHA.sha256(t0_wire_bytes))) ==
                package.wire.sha256
            t0_wire = JSON3.read(String(t0_wire_bytes))
            for declaration in package.declarations
                receipt_bytes = G.copy_bytes(declaration.factory_receipt_bytes)
                @test G.Digest256(bytes2hex(SHA.sha256(receipt_bytes))) ==
                    declaration.factory_receipt_bytes.sha256
                rows = filter(row -> String(row.layer) == String(declaration.layer),
                    t0_wire.declarations)
                @test length(rows) == 1
                wire_result = only(rows).factory_receipt.factory_result
                @test wire_result !== nothing
                legacy = canonical_json(G._up2_n10_json_semantic(wire_result))
                streamed = G._up2_n10_canonical_json(wire_result)
                @test Vector{UInt8}(codeunits(streamed)) ==
                    Vector{UInt8}(codeunits(legacy))
                @test Vector{UInt8}(codeunits(streamed)) == receipt_bytes
            end
            (; package_hash=package.package_hash, wire_sha256=package.wire.sha256)
        end
        actual_a = check_actual_t1(_TAC_N10_T1_A)
        actual_b = check_actual_t1(_TAC_N10_T1_B)
        @test actual_a.package_hash == actual_b.package_hash
        @test actual_a.wire_sha256 == actual_b.wire_sha256
    end
end
