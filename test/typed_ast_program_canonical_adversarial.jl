using Test
using FusionConceptAI
using SHA

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
        push!(nodes, ASTApplyV1(OperatorRefV1("IDENTITY", "v1"), (8,), (;);
            registry=registry, input_types=(scalar,)))
        nine = TypedASTProgramV1(Tuple(nodes), (9,), (1,); registry=registry)
        @test_throws CanonicalizationDeferred canonical_json(nine)
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
            result = success(`$(Base.julia_cmd()) --startup-file=no --project=$(Base.active_project()) -e $script`)
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
