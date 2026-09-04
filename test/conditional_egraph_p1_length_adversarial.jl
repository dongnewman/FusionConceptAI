"""Fresh-process regression for hostile Base.length extensions in P1."""

using Test
include(joinpath(@__DIR__, "conditional_egraph_p1_subprocess_helpers.jl"))

"""Run a child Julia process with an optional more-specific Vector length method.

The child deliberately extends `Base.length(::Vector)` and delegates to the
Array implementation.  Any P1 implementation that accidentally asks dynamic
dispatch for a temporary Vector length will execute the method and set HIT;
the closed implementation must nevertheless produce the same bytes and hashes.
"""
function _p1_run_length_child(poison::Bool)
    poison_code = poison ? raw"""
        const P1_LENGTH_HIT = Ref(false)
        Base.length(v::Vector{T}) where {T} = begin
            P1_LENGTH_HIT[] = true
            invoke(Base.length, Tuple{Array}, v)
        end
    """ : """
        const P1_LENGTH_HIT = Ref(false)
    """
    hit_expression = poison ? "P1_LENGTH_HIT[]" : "false"
    script = """
        using FusionConceptAI
        $poison_code
        function p(op)
            u = UnitSignature()
            t = PhysicalType(:scalar_field, 0, 3, TemporalTypeV1(static_time), u)
            i = ASTInputV1(1, t)
            a = ASTApplyV1(OperatorRefV1(op, \"v1\"), (1,), (;);
                registry=default_operator_registry(), input_types=(t,))
            TypedASTProgramV1((i, a), (2,), (1,); registry=default_operator_registry())
        end
        source = p(\"IDENTITY\")
        target = p(\"NEG\")
        condition = EqualityConditionRequirementV1(
            QualifiedRefV1(\"length-extension-check\", \"v1\"), digest256_text(\"length-contract\"))
        r1 = WholeProgramConditionalRewriteV1(
            QualifiedRefV1(\"identity-to-neg-a\", \"v1\"), source, target, (condition,),
            QualifiedRefV1(\"checker\", \"v1\"), digest256_text(\"checker-contract\");
            registry=default_operator_registry())
        r2 = WholeProgramConditionalRewriteV1(
            QualifiedRefV1(\"identity-to-neg-b\", \"v1\"), source, target, (condition,),
            QualifiedRefV1(\"checker\", \"v1\"), digest256_text(\"checker-contract\");
            registry=default_operator_registry())
        registry = default_operator_registry()
        set_a = ConditionalRewriteSetV1((r1, r2))
        set_b = ConditionalRewriteSetV1((r2, r1))
        budget = ConditionalEGraphBudgetV1(64, 4096, 32, 256)
        da = derive_conditional_program_egraph(source, set_a, registry;
            saturation_budget=budget)
        db = derive_conditional_program_egraph(source, set_b, registry;
            saturation_budget=budget)
        a = da.artifact
        b = db.artifact
        qa = query_conditional_equality(a, target)
        qb = query_conditional_equality(b, target)
        replay_a = replay_conditional_rewrite_trace(source, target, set_a, registry, qa.provenance)
        replay_b = replay_conditional_rewrite_trace(source, target, set_b, registry, qb.provenance)
        println(\"EXIT_OK|\", $hit_expression, \"|\",
            canonical_json(set_a) == canonical_json(set_b), \"|\",
            canonical_hash(set_a) == canonical_hash(set_b), \"|\",
            canonical_json(a) == canonical_json(b), \"|\",
            canonical_hash(a) == canonical_hash(b), \"|\",
            saturation_attempt_hash(a) == saturation_attempt_hash(b), \"|\",
            qa.status, \"|\", qb.status, \"|\", replay_a, \"|\", replay_b)
    """
    _p1_child_output(script)
end

@testset "P1 hostile Vector length is fresh-process invariant" begin
    baseline = strip(_p1_run_length_child(false))
    poisoned = strip(_p1_run_length_child(true))
    baseline_fields = split(baseline, "|")
    poisoned_fields = split(poisoned, "|")
    @test baseline_fields[1] == "EXIT_OK"
    @test poisoned_fields[1] == "EXIT_OK"
    @test baseline_fields[2] == "false"
    @test poisoned_fields[2] == "true"  # prove the more-specific extension executed
    @test baseline_fields[3:end] == poisoned_fields[3:end]
    @test poisoned_fields[3:end] == ["true", "true", "true", "true", "true",
        "conditional_equal", "conditional_equal", "true", "true"]
end

@testset "P1 production avoids authority-sensitive array and Vector operations" begin
    p1_files = (
        joinpath(@__DIR__, "..", "src", "IR", "ConditionalEGraphTypes.jl"),
        joinpath(@__DIR__, "..", "src", "IR", "ConditionalEGraphSaturation.jl"),
        joinpath(@__DIR__, "..", "src", "Canonical", "ConditionalEGraphCanonical.jl"),
    )
    for path in p1_files
        body = read(path, String)
        @test !occursin("Core.arrayref(false", body)
        @test !occursin("Core.arrayset(false", body)
        # Simple local names in these P1 files denote temporary Vectors when
        # used in loops. Tuple/profile fields are intentionally not rejected.
        for match in eachmatch(r"\blength\(\s*([A-Za-z_][A-Za-z0-9_]*)\s*\)", body)
            @test match.captures[1] in ("av", "bv")
        end
    end
end
