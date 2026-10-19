using Test, SHA, JSON3, Dates

const R22_ROOT = normpath(joinpath(@__DIR__, "..", "..", "..", ".."))
const R22_PINS_PATH = joinpath(R22_ROOT, "docs/implementation/UP1-04A-VNEXT-T1/agent_local_r19_static_selection_harness/ast_static_r2/static_manifest.json")
const R22_PINS = JSON3.read(read(R22_PINS_PATH, String)).before_protected
function r22_pins()
    Dict(String(rel) => (bytes=filesize(joinpath(R22_ROOT, String(rel))),
        sha256=uppercase(bytes2hex(sha256(read(joinpath(R22_ROOT, String(rel))))))) for rel in keys(R22_PINS))
end
const R22_BEFORE = r22_pins()
for (rel, expected) in pairs(R22_PINS)
    observed = R22_BEFORE[String(rel)]
    observed.bytes == expected.bytes && observed.sha256 == expected.sha256 || error("protected drift: $rel")
end
const R22_SOURCE = joinpath(R22_ROOT, "test/GenomeV5/Integration/vnext_t1_candidate_state_package_v5_next_formal_v2_tests.jl")
Base.include(Main, R22_SOURCE) do expression
    if expression isa Expr
        expression.head === :macrocall && string(expression.args[1]) == "@testset" && return nothing
        expression.head === :call && expression.args[1] === :println && return nothing
    end
    expression
end

function r22_mark(stage)
    println("R22_STAGE utc=", Dates.now(Dates.UTC), " stage=", stage)
    flush(stdout)
end
function r22_out(relative)
    isabspath(relative) && error("absolute evidence path")
    ".." in splitpath(relative) && error("evidence traversal")
    directory = normpath(joinpath(R22_ROOT, relative))
    allowed = normpath(joinpath(R22_ROOT, "docs/implementation/UP1-04A-VNEXT-T1"))
    startswith(directory, allowed * string(Base.Filesystem.path_separator)) || error("evidence root")
    isdir(directory) || error("monitor must create evidence directory")
    directory
end
function r22_write(path, object)
    ispath(path) && error("existing evidence")
    open(path, "w") do io
        JSON3.write(io, object)
    end
end

# Prove the generic family, not just one concrete N/M/K. Type variables may
# occur only as tuple lengths, never as the type of an inhabitant/field.
function r22_type_closure(T, path::String, rows=Any[], seen=Set{String}())
    # UnionAll and its free-variable body must not collapse in type-equality
    # based deduplication: the body still requires a complete field audit.
    key = string(typeof(T)) * ":" * sprint(show, T)
    key in seen && return rows
    push!(seen, key)
    if T === String || T === Symbol
        push!(rows, (path=path, type=string(T), rule="language_immutable_special",
            runtime_mutable_flag=ismutabletype(T)))
    elseif T isa TypeVar
        error("open field type variable: $path -> $T")
    elseif T isa Union
        push!(rows, (path=path, type=string(T), rule="finite_union"))
        foreach(member -> r22_type_closure(member, path * ".union", rows, seen), Base.uniontypes(T))
    elseif T isa UnionAll
        push!(rows, (path=path, type=string(T), rule="family_unwrap_all_fields_checked"))
        r22_type_closure(Base.unwrap_unionall(T), path * ".family", rows, seen)
    elseif T isa DataType && T <: Tuple
        push!(rows, (path=path, type=string(T), rule="immutable_tuple_each_element_type_checked"))
        for (index, element) in enumerate(T.parameters)
            if Base.isvarargtype(element)
                isdefined(element, :T) || error("untyped Vararg: $path")
                count = isdefined(element, :N) ? element.N : nothing
                count isa Integer || count isa TypeVar || error("unbounded tuple length: $path")
                count isa Integer && count < 0 && error("negative tuple length")
                push!(rows, (path=path * ".length", type=string(count), rule="length_parameter_only_no_value_payload"))
                r22_type_closure(element.T, path * ".element", rows, seen)
            else
                r22_type_closure(element, path * ".element_" * string(index), rows, seen)
            end
        end
    elseif T isa DataType
        isabstracttype(T) && error("open abstract field: $path -> $T")
        ismutabletype(T) && error("mutable field: $path -> $T")
        if isprimitivetype(T)
            T in (UInt8, Int, Bool) || error("unapproved primitive/opaque field: $path -> $T")
            push!(rows, (path=path, type=string(T), rule="closed_primitive_value"))
        else
            push!(rows, (path=path, type=string(T), rule="immutable_struct_all_declared_fields_checked",
                field_names=String.(fieldnames(T)), field_types=string.(fieldtypes(T))))
            for index in 1:fieldcount(T)
                r22_type_closure(fieldtype(T, index), path * "." * string(fieldname(T, index)), rows, seen)
            end
        end
    else
        error("unhandled/open field type: $path -> $T")
    end
    rows
end

struct R22BadAny
    payload::Any
end
struct R22BadAbstract
    payload::AbstractVector{UInt8}
end
struct R22BadVector
    payload::Vector{UInt8}
end
struct R22BadRef
    payload::Base.RefValue{Int}
end
struct R22BadVariable{T}
    payload::T
end
function r22_static()
    rows = r22_type_closure(G.CandidateStatePackageV5Next, "CandidateStatePackageV5Next")
    @testset "R22 type closure rejects mutable and open payloads" begin
        @test count(row -> row.rule == "immutable_struct_all_declared_fields_checked", rows) >= 10
        @test_throws ErrorException r22_type_closure(R22BadAny, "bad_any")
        @test_throws ErrorException r22_type_closure(R22BadAbstract, "bad_abstract")
        @test_throws ErrorException r22_type_closure(R22BadVector, "bad_vector")
        @test_throws ErrorException r22_type_closure(R22BadRef, "bad_ref")
        @test_throws ErrorException r22_type_closure(R22BadVariable, "bad_variable")
        @test_throws ErrorException r22_type_closure(Dict{String,Int}, "bad_dict")
        @test_throws ErrorException r22_type_closure(Tuple, "untyped_tuple")
    end
    rows
end

if abspath(PROGRAM_FILE) == @__FILE__
    length(ARGS) == 1 || error("usage: <new-static-evidence-dir>")
    directory = r22_out(ARGS[1])
    r22_mark("generic_type_closure:before")
    rows = r22_static()
    r22_mark("generic_type_closure:after")
    R22_BEFORE == r22_pins() || error("source changed")
    r22_write(joinpath(directory, "type_closure.json"), (verdict="static_semantic_immutability_only",
        root="CandidateStatePackageV5Next (all inhabitable length parameters)", rows=rows,
        no_open_or_mutable_payload_types=true, formal_T1=false, product_changed=false,
        before_protected=R22_BEFORE, after_protected=r22_pins(),
        identity_scope="legal Julia value identity, not unsafe mutation or physical pointer-address equality",
        actual_model_attestation="unavailable"))
    println("R22_STATIC_CLOSURE_PASS rows=", length(rows)); flush(stdout)
end
