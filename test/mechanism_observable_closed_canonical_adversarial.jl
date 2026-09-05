using Test
using FusionConceptAI
using JSON3

const _G1OC_HELPER = joinpath(@__DIR__, "mechanism_observable_closed_canonical_tests.jl")

if get(ENV, "FUSION_G1OC_CHILD", "0") == "1"
    mode = get(ENV, "FUSION_G1OC_MODE", "A_PRINT")
    helper_source = read(_G1OC_HELPER, String)
    include_string(Main, first(split(helper_source, "@testset")), _G1OC_HELPER)
    observable = _g1oc_observable()
    payload = _g1oc_payload(observable)
    const G1OC_HITS = Set{Symbol}()
    _g1oc_hit!(name::Symbol) = push!(G1OC_HITS, name)
    baseline_bytes = FusionConceptAI._g1_observable_canonical_bytes(observable)
    baseline_hash = getfield(FusionConceptAI._g1_observable_canonical_hash(observable), :value)
    sampling_program = getfield(observable, :sampling_program)
    root_ref = getfield(observable, :expression_root)
    qualified_ref = getfield(observable, :intervention_ref)
    observable_ref = getfield(observable, :observable_ref)
    noise_quantity = getfield(observable, :noise_floor)
    effect_interval = getfield(observable, :expected_effect_interval)
    finite_interval = getfield(effect_interval, :interval)
    physical_type = getfield(root_ref, :declared_type)
    _g1oc_same(a::String, b::String) = invoke(Base.:(==), Tuple{String,String}, a, b)
    function _g1oc_check_private()
        bytes = try FusionConceptAI._g1_observable_canonical_bytes(observable) catch; return false end
        digest = try getfield(FusionConceptAI._g1_observable_canonical_hash(observable), :value) catch; return false end
        _g1oc_same(bytes, baseline_bytes) && _g1oc_same(digest, baseline_hash)
    end
    function _g1oc_action(name::Symbol, action)
        try action() catch; end
        @assert name in G1OC_HITS
        @assert _g1oc_check_private()
    end

    if startswith(mode, "A_")
        selector = mode[3:end]
        if selector == "PRINT"
            @eval Base print(::IOBuffer, ::String) = (Main._g1oc_hit!(:print); nothing)
            _g1oc_action(:print, () -> Base.print(IOBuffer(), "x"))
        elseif selector == "STRING_INT64"
            @eval Base string(::Int64) = (Main._g1oc_hit!(:string_int64); "poison")
            _g1oc_action(:string_int64, () -> string(Int64(7)))
        elseif selector == "STRING_UINT32_BASE16"
            @eval Base string(::UInt32; base=10, pad=1) = (Main._g1oc_hit!(:string_uint32_base16); "poison")
            _g1oc_action(:string_uint32_base16, () -> string(UInt32(255); base=16))
        elseif selector == "JOIN"
            @eval Base join(::Vector{String}, ::AbstractString) = (Main._g1oc_hit!(:join); "poison")
            _g1oc_action(:join, () -> join(String["x"], String(",")))
        elseif selector == "SORT"
            @eval Base sort(::Vector{String}) = (Main._g1oc_hit!(:sort); String[])
            _g1oc_action(:sort, () -> sort(String["b", "a"]))
        elseif selector == "ISLESS"
            @eval Base isless(::String, ::String) = (Main._g1oc_hit!(:isless); false)
            _g1oc_action(:isless, () -> isless("x", "x"))
        elseif selector == "REPR"
            @eval Base repr(::String) = (Main._g1oc_hit!(:repr); "poison")
            _g1oc_action(:repr, () -> repr("x"))
        elseif selector == "GETINDEX"
            @eval Base getindex(::String, ::Int) = (Main._g1oc_hit!(:getindex); '\0')
            _g1oc_action(:getindex, () -> "x"[1])
        elseif selector == "ITERATE_STRING"
            @eval Base iterate(::String, ::Int) = (Main._g1oc_hit!(:iterate_string); nothing)
            _g1oc_action(:iterate_string, () -> iterate("x", 1))
        elseif selector == "SETINDEX"
            @eval Base setindex!(::Vector{String}, ::String, ::Int) = (Main._g1oc_hit!(:setindex); nothing)
            _g1oc_action(:setindex, () -> setindex!(String["x"], "y", 1))
        elseif selector == "PUSH"
            @eval Base push!(::Vector{String}, ::String) = (Main._g1oc_hit!(:push); String[])
            _g1oc_action(:push, () -> push!(String["x"], "y"))
        elseif selector == "CODEUNITS"
            @eval Base codeunits(::String) = (Main._g1oc_hit!(:codeunits); UInt8[])
            _g1oc_action(:codeunits, () -> codeunits("x"))
        elseif selector == "NCODEUNITS"
            @eval Base ncodeunits(::String) = (Main._g1oc_hit!(:ncodeunits); 0)
            _g1oc_action(:ncodeunits, () -> ncodeunits("x"))
        elseif selector == "BYTES2HEX"
            @eval Base bytes2hex(::Vector{UInt8}) = (Main._g1oc_hit!(:bytes2hex); "poison")
            _g1oc_action(:bytes2hex, () -> bytes2hex(UInt8[1]))
        elseif selector == "STRING_CTOR"
            @eval Base String(::String) = (Main._g1oc_hit!(:string_ctor); "poison")
            _g1oc_action(:string_ctor, () -> String("x"))
        elseif selector == "SHA"
            @eval SHA sha256(::Vector{UInt8}) = (Main._g1oc_hit!(:sha256); UInt8[])
            _g1oc_action(:sha256, () -> SHA.sha256(UInt8[1]))
        elseif selector == "DIGEST"
            @eval FusionConceptAI Digest256(::String) = (Main._g1oc_hit!(:digest); error("Digest poison"))
            _g1oc_action(:digest, () -> try FusionConceptAI.Digest256("0"^64) catch; nothing end)
        elseif selector == "CANONICAL_JSON_ANY"
            @eval FusionConceptAI canonical_json(::Any) = (Main._g1oc_hit!(:canonical_json_any); "poison")
            _g1oc_action(:canonical_json_any, () -> canonical_json(nothing))
        elseif selector == "CANONICAL_HASH_ANY"
            @eval FusionConceptAI canonical_hash(::Any) = (Main._g1oc_hit!(:canonical_hash_any); error("canonical hash poison"))
            _g1oc_action(:canonical_hash_any, () -> try canonical_hash(nothing) catch; nothing end)
        elseif selector == "SEMANTIC_ANY"
            @eval FusionConceptAI semantic_view(::Any) = (Main._g1oc_hit!(:semantic_any); nothing)
            _g1oc_action(:semantic_any, () -> semantic_view(nothing))
        elseif selector == "OLD_HASH"
            @eval FusionConceptAI _g1_hash_bytes(::String) = (Main._g1oc_hit!(:old_hash); error("old hash poison"))
            _g1oc_action(:old_hash, () -> try FusionConceptAI._g1_hash_bytes("x") catch; nothing end)
        elseif selector == "GETPROPERTY_QUALIFIED"
            @eval Base getproperty(::Main.FusionConceptAI.QualifiedRefV1, ::Symbol) = (Main._g1oc_hit!(:getproperty_qualified); error("getproperty poison"))
            _g1oc_action(:getproperty_qualified, () -> try getproperty(qualified_ref, :id) catch; nothing end)
        elseif selector == "GETPROPERTY_QUANTITY"
            @eval Base getproperty(::Main.FusionConceptAI.NonnegativeQuantityV1, ::Symbol) = (Main._g1oc_hit!(:getproperty_quantity); error("getproperty poison"))
            _g1oc_action(:getproperty_quantity, () -> try getproperty(noise_quantity, :value) catch; nothing end)
        elseif selector == "GETPROPERTY_ROOT"
            @eval Base getproperty(::Main.FusionConceptAI.ProgramRootRefV1, ::Symbol) = (Main._g1oc_hit!(:getproperty_root); error("getproperty poison"))
            _g1oc_action(:getproperty_root, () -> try getproperty(root_ref, :root_position) catch; nothing end)
        elseif selector == "GETPROPERTY_TYPE"
            @eval Base getproperty(::Main.FusionConceptAI.PhysicalType, ::Symbol) = (Main._g1oc_hit!(:getproperty_type); error("getproperty poison"))
            _g1oc_action(:getproperty_type, () -> try getproperty(physical_type, :value_kind) catch; nothing end)
        elseif selector == "GETPROPERTY_DIGEST"
            digest = FusionConceptAI.Digest256("0"^64)
            @eval Base getproperty(::Main.FusionConceptAI.Digest256, ::Symbol) = (Main._g1oc_hit!(:getproperty_digest); error("getproperty poison"))
            _g1oc_action(:getproperty_digest, () -> try getproperty(digest, :value) catch; nothing end)
        elseif selector == "NESTED_TYPED_AST"
            @eval FusionConceptAI canonical_json(::TypedASTProgramV1) = (Main._g1oc_hit!(:nested_typed_ast); "poison")
            _g1oc_action(:nested_typed_ast, () -> canonical_json(sampling_program))
        elseif selector == "NESTED_HASH_TYPED_AST"
            @eval FusionConceptAI canonical_hash(::TypedASTProgramV1) = (Main._g1oc_hit!(:nested_hash_typed_ast); error("nested hash poison"))
            _g1oc_action(:nested_hash_typed_ast, () -> try canonical_hash(sampling_program) catch; nothing end)
        elseif selector == "NESTED_ROOT"
            @eval FusionConceptAI canonical_json(::ProgramRootRefV1) = (Main._g1oc_hit!(:nested_root); "poison")
            _g1oc_action(:nested_root, () -> canonical_json(root_ref))
        elseif selector == "NESTED_HASH_ROOT"
            @eval FusionConceptAI canonical_hash(::ProgramRootRefV1) = (Main._g1oc_hit!(:nested_hash_root); error("nested hash poison"))
            _g1oc_action(:nested_hash_root, () -> try canonical_hash(root_ref) catch; nothing end)
        elseif selector == "NESTED_QUALIFIED"
            @eval FusionConceptAI canonical_json(::QualifiedRefV1) = (Main._g1oc_hit!(:nested_qualified); "poison")
            _g1oc_action(:nested_qualified, () -> canonical_json(qualified_ref))
        elseif selector == "NESTED_HASH_QUALIFIED"
            @eval FusionConceptAI canonical_hash(::QualifiedRefV1) = (Main._g1oc_hit!(:nested_hash_qualified); error("nested hash poison"))
            _g1oc_action(:nested_hash_qualified, () -> try canonical_hash(qualified_ref) catch; nothing end)
        elseif selector == "NESTED_OBSERVABLE_REF"
            @eval FusionConceptAI canonical_json(::ObservableRefV1) = (Main._g1oc_hit!(:nested_observable_ref); "poison")
            _g1oc_action(:nested_observable_ref, () -> canonical_json(observable_ref))
        elseif selector == "NESTED_HASH_OBSERVABLE_REF"
            @eval FusionConceptAI canonical_hash(::ObservableRefV1) = (Main._g1oc_hit!(:nested_hash_observable_ref); error("nested hash poison"))
            _g1oc_action(:nested_hash_observable_ref, () -> try canonical_hash(observable_ref) catch; nothing end)
        elseif selector == "NESTED_QUANTITY"
            @eval FusionConceptAI canonical_json(::NonnegativeQuantityV1) = (Main._g1oc_hit!(:nested_quantity); "poison")
            _g1oc_action(:nested_quantity, () -> canonical_json(noise_quantity))
        elseif selector == "NESTED_HASH_QUANTITY"
            @eval FusionConceptAI canonical_hash(::NonnegativeQuantityV1) = (Main._g1oc_hit!(:nested_hash_quantity); error("nested hash poison"))
            _g1oc_action(:nested_hash_quantity, () -> try canonical_hash(noise_quantity) catch; nothing end)
        elseif selector == "NESTED_INTERVAL"
            @eval FusionConceptAI canonical_json(::QuantityIntervalV1) = (Main._g1oc_hit!(:nested_interval); "poison")
            _g1oc_action(:nested_interval, () -> canonical_json(effect_interval))
        elseif selector == "NESTED_HASH_INTERVAL"
            @eval FusionConceptAI canonical_hash(::QuantityIntervalV1) = (Main._g1oc_hit!(:nested_hash_interval); error("nested hash poison"))
            _g1oc_action(:nested_hash_interval, () -> try canonical_hash(effect_interval) catch; nothing end)
        elseif selector == "NESTED_FINITE_INTERVAL"
            @eval FusionConceptAI canonical_json(::ExactFiniteIntervalV1) = (Main._g1oc_hit!(:nested_finite_interval); "poison")
            _g1oc_action(:nested_finite_interval, () -> canonical_json(finite_interval))
        elseif selector == "NESTED_HASH_FINITE_INTERVAL"
            @eval FusionConceptAI canonical_hash(::ExactFiniteIntervalV1) = (Main._g1oc_hit!(:nested_hash_finite_interval); error("nested hash poison"))
            _g1oc_action(:nested_hash_finite_interval, () -> try canonical_hash(finite_interval) catch; nothing end)
        elseif selector == "NESTED_PHYSICAL_TYPE"
            @eval FusionConceptAI canonical_json(::PhysicalType) = (Main._g1oc_hit!(:nested_physical_type); "poison")
            _g1oc_action(:nested_physical_type, () -> canonical_json(physical_type))
        elseif selector == "NESTED_HASH_PHYSICAL_TYPE"
            @eval FusionConceptAI canonical_hash(::PhysicalType) = (Main._g1oc_hit!(:nested_hash_physical_type); error("nested hash poison"))
            _g1oc_action(:nested_hash_physical_type, () -> try canonical_hash(physical_type) catch; nothing end)
        else
            error("unknown G1 Observable poison selector")
        end
        Base.write(stdout, UInt8[0x47,0x31,0x4f,0x43,0x5f,0x41,0x5f,0x50,0x41,0x53,0x53,0x0a])
    elseif mode == "B"
        wire = FusionConceptAI._g1_payload_wire(payload)
        digest = getfield(FusionConceptAI._g1_hash_bytes(wire), :value)
        text_hash = FusionConceptAI._g1_payload_hash_text(observable)
        @eval FusionConceptAI begin
            canonical_json(::ObservableGeneV1) = (Main._g1oc_hit!(:canonical_json_observable); error("Observable authority poison"))
            canonical_hash(::ObservableGeneV1) = (Main._g1oc_hit!(:canonical_hash_observable); error("Observable authority poison"))
            semantic_view(::ObservableGeneV1) = (Main._g1oc_hit!(:semantic_observable); error("Observable authority poison"))
        end
        _g1oc_action(:canonical_json_observable, () -> try canonical_json(observable) catch; nothing end)
        _g1oc_action(:canonical_hash_observable, () -> try canonical_hash(observable) catch; nothing end)
        _g1oc_action(:semantic_observable, () -> try semantic_view(observable) catch; nothing end)
        @assert wire == FusionConceptAI._g1_payload_wire(payload)
        @assert digest == getfield(FusionConceptAI._g1_hash_bytes(FusionConceptAI._g1_payload_wire(payload)), :value)
        @assert text_hash == FusionConceptAI._g1_payload_hash_text(observable)
        Base.write(stdout, UInt8[0x47,0x31,0x4f,0x43,0x5f,0x42,0x5f,0x50,0x41,0x53,0x53,0x0a])
    elseif mode == "C"
        wire = FusionConceptAI._g1_migration_gene_wire(observable)
        @eval FusionConceptAI begin
            canonical_json(::ObservableGeneV1) = (Main._g1oc_hit!(:canonical_json_observable); error("Observable authority poison"))
            canonical_hash(::ObservableGeneV1) = (Main._g1oc_hit!(:canonical_hash_observable); error("Observable authority poison"))
            semantic_view(::ObservableGeneV1) = (Main._g1oc_hit!(:semantic_observable); error("Observable authority poison"))
            _g1_hash_bytes(::String) = (Main._g1oc_hit!(:old_hash); error("old hash poison"))
        end
        _g1oc_action(:canonical_json_observable, () -> try canonical_json(observable) catch; nothing end)
        _g1oc_action(:canonical_hash_observable, () -> try canonical_hash(observable) catch; nothing end)
        _g1oc_action(:semantic_observable, () -> try semantic_view(observable) catch; nothing end)
        _g1oc_action(:old_hash, () -> try FusionConceptAI._g1_hash_bytes("x") catch; nothing end)
        @assert wire === FusionConceptAI._g1_migration_gene_wire(observable)
        Base.write(stdout, UInt8[0x47,0x31,0x4f,0x43,0x5f,0x43,0x5f,0x50,0x41,0x53,0x53,0x0a])
    elseif mode == "D"
        context = MechanismCanonicalizationContextV1(g1_occurrence_ownership_contract_ref("urn:fusion:g1oc"), CanonicalizationProfileV1("g1oc", "1", CanonicalizationBudgetV1(500_000, 50_000, 512, 8_000_000)))
        layers = mechanism_hash_layers(payload, context)
        record = only(JSON3.read(line, Dict{String,Any}) for line in eachline(joinpath(@__DIR__, "fixtures", "g1_observable_closed_r2.jsonl")) if !isempty(strip(line)) && JSON3.read(line, Dict{String,Any})["name"] == "mechanism_layers_r2")
        expected_layers = Tuple(String.(record["layer_hashes"]))
        @assert Tuple(getfield(layers, i).value for i in 1:8) == expected_layers
        source = LegacyMechanismGenomeV4(UInt64(1), context.contract_ref, payload.operator_graph, payload.invariants, payload.observables)
        edge = payload.operator_graph.hyperedges[1]
        completion = G1LegacyEdgeCompletionV1(edge.edge_id, edge.account_effects, edge.interface_flux_pairs)
        declaration = G1LegacyMigrationDeclarationV1(QualifiedRefV1("mapping", "v1"), exact7_recanonicalize, context.contract_ref, canonical_hash(source), context.contract_ref, payload.states, payload.invariants, (), (), payload.observables, (), (completion,))
        result = migrate_legacy_g1(source, declaration, context, edge.registry)
        @assert result.resolution === resolved && result.reason === migration_lossless
        @assert getfield(result.source_mechanism_hash, :value) == String(record["source_canonical_hash"])
        @assert getfield(result.declaration_content_hash, :value) == String(record["declaration_content_hash"])
        @assert getfield(result.mapping_hash, :value) == String(record["mapping_hash"])
        @eval FusionConceptAI begin
            canonical_json(::ObservableGeneV1) = (Main._g1oc_hit!(:d_canonical_json_observable); error("Observable authority poison"))
            canonical_hash(::ObservableGeneV1) = (Main._g1oc_hit!(:d_canonical_hash_observable); error("Observable authority poison"))
            semantic_view(::ObservableGeneV1) = (Main._g1oc_hit!(:d_semantic_observable); error("Observable authority poison"))
        end
        _g1oc_action(:d_canonical_json_observable, () -> try canonical_json(observable) catch; nothing end)
        _g1oc_action(:d_canonical_hash_observable, () -> try canonical_hash(observable) catch; nothing end)
        _g1oc_action(:d_semantic_observable, () -> try semantic_view(observable) catch; nothing end)
        poisoned_layers = mechanism_hash_layers(payload, context)
        @assert Tuple(getfield(poisoned_layers, i).value for i in 1:8) == expected_layers
        Base.write(stdout, UInt8[0x47,0x31,0x4f,0x43,0x5f,0x44,0x5f,0x50,0x41,0x53,0x53,0x0a])
    else
        error("unknown G1 Observable adversarial mode")
    end
else
    function _g1oc_run_child(mode)
        script = "using FusionConceptAI; using SHA; include($(repr(joinpath(@__DIR__, "mechanism_observable_closed_canonical_adversarial.jl"))))"
        command = setenv(`$(Base.julia_cmd()) --startup-file=no --project=$(Base.active_project()) -e $script`, "FUSION_G1OC_CHILD" => "1", "FUSION_G1OC_MODE" => mode)
        read(pipeline(command, stderr=stdout), String)
    end
    @testset "G1 Observable isolated fresh poison" begin
        selectors = ("PRINT", "STRING_INT64", "STRING_UINT32_BASE16", "JOIN", "SORT", "ISLESS", "REPR", "GETINDEX", "ITERATE_STRING", "SETINDEX", "PUSH", "CODEUNITS", "NCODEUNITS", "BYTES2HEX", "STRING_CTOR", "SHA", "DIGEST", "CANONICAL_JSON_ANY", "CANONICAL_HASH_ANY", "SEMANTIC_ANY", "OLD_HASH", "GETPROPERTY_QUALIFIED", "GETPROPERTY_QUANTITY", "GETPROPERTY_ROOT", "GETPROPERTY_TYPE", "GETPROPERTY_DIGEST", "NESTED_TYPED_AST", "NESTED_HASH_TYPED_AST", "NESTED_ROOT", "NESTED_HASH_ROOT", "NESTED_QUALIFIED", "NESTED_HASH_QUALIFIED", "NESTED_OBSERVABLE_REF", "NESTED_HASH_OBSERVABLE_REF", "NESTED_QUANTITY", "NESTED_HASH_QUANTITY", "NESTED_INTERVAL", "NESTED_HASH_INTERVAL", "NESTED_FINITE_INTERVAL", "NESTED_HASH_FINITE_INTERVAL", "NESTED_PHYSICAL_TYPE", "NESTED_HASH_PHYSICAL_TYPE")
        for selector in selectors
            output = _g1oc_run_child("A_" * selector)
            @test occursin("G1OC_A_PASS", output)
            occursin("G1OC_A_PASS", output) || println("selector ", selector, ": ", output)
        end
        for mode in ("B", "C", "D")
            output = _g1oc_run_child(mode)
            @test occursin("G1OC_" * mode * "_PASS", output)
            occursin("G1OC_" * mode * "_PASS", output) || println("mode ", mode, ": ", output)
        end
    end
end
