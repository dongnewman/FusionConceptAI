using Dates, SHA

const _R18_ORIGINAL = normpath(joinpath(@__DIR__, "..", "vnext_t1_candidate_state_package_v5_next_tests.jl"))
const _R18_ORIGINAL_SHA = "970976c4122fc6b4f5303d6763c286514b1c9dc653aba36d46e1d003bcbf9669"
bytes2hex(sha256(read(_R18_ORIGINAL))) == _R18_ORIGINAL_SHA || error("frozen original changed")

function _r18_marker(label)
    println("R18_ORIGINAL_STAGE utc=", Dates.now(Dates.UTC), " label=", label)
    flush(stdout)
    nothing
end

function _r18_testset_body(block)
    block isa Expr && block.head === :block || return block
    line = 0
    result = Any[]
    for node in block.args
        if node isa LineNumberNode
            line = node.line
            push!(result, node)
        else
            push!(result, :(_r18_marker($("before_line_" * string(line)))))
            push!(result, _r18_nested_testset(node))
            push!(result, :(_r18_marker($("after_line_" * string(line)))))
        end
    end
    Expr(:block, result...)
end

function _r18_nested_testset(node)
    if node isa Expr && node.head === :macrocall && string(node.args[1]) == "@testset"
        return Expr(:macrocall, node.args[1:end-1]..., _r18_testset_body(node.args[end]))
    end
    node
end

counter = Ref(0)
mapexpr = expression -> begin
    counter[] += 1
    _r18_marker("top_level_$(counter[])")
    _r18_nested_testset(expression)
end
Base.include(mapexpr, Main, _R18_ORIGINAL)
_r18_marker("original_complete")
