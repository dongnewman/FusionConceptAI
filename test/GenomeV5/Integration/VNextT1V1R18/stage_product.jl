using Dates, SHA

const _R18_SOURCE = normpath(joinpath(@__DIR__, "..", "vnext_t1_candidate_state_package_v5_next_tests.jl"))
bytes2hex(sha256(read(_R18_SOURCE))) == "970976c4122fc6b4f5303d6763c286514b1c9dc653aba36d46e1d003bcbf9669" || error("frozen original changed")
const _R18_FUNCTIONS = Set([
    :_t1_fixture, :_vnext_t1_snapshot, :_vnext_t1_declaration_tuple,
    :_vnext_t1_declaration_record, :_vnext_t1_child_tuple, :_vnext_t1_child_record,
    :_vnext_t1_feedback_tuple, :_vnext_t1_feedback_record,
    :_vnext_t1_output_gate, :_vnext_t1_package, :_vnext_t1_component_identity,
    :vnext_t1_admit_skeleton_v1])

function _r18_trace(label)
    println("R18_PRODUCT_STAGE utc=", Dates.now(Dates.UTC), " label=", label)
    flush(stdout)
    nothing
end

function _r18_function_name(signature)
    if signature isa Expr
        signature.head === :where && return _r18_function_name(signature.args[1])
        signature.head === :call && return signature.args[1]
    end
    nothing
end

function _r18_trace_block(block, name)
    block isa Expr && block.head === :block || return block
    output = Any[]
    line = 0
    for node in block.args
        if node isa LineNumberNode
            line = node.line
            push!(output, node)
        else
            push!(output, :(Main._r18_trace($(string(name) * ":before:" * string(line)))))
            if node isa Expr && node.head === :try
                # Instrument statement boundaries only. Keep branch conditions,
                # calls, operands, catches and implicit function returns intact.
                push!(output, Expr(:try, map(x -> x isa Expr && x.head === :block ?
                    _r18_trace_block(x, name) : x, node.args)...))
            else
                push!(output, node)
            end
        end
    end
    Expr(:block, output...)
end

function _r18_product_map(expression)
    expression isa Expr || return expression
    if expression.head === :function
        name = _r18_function_name(expression.args[1])
        name in _R18_FUNCTIONS || return expression
        return Expr(:function, expression.args[1], _r18_trace_block(expression.args[2], name))
    elseif expression.head === :macrocall
        return Expr(:macrocall, map(_r18_product_map, expression.args)...)
    end
    expression
end

function _r18_original_map(expression)
    expression isa Expr || return expression
    if expression.head === :call && expression.args[1] == :(Base.include) &&
            length(expression.args) == 3 && expression.args[2] === :G
        return Expr(:call, expression.args[1], :(Main._r18_product_map), expression.args[2:end]...)
    end
    if expression.head === :macrocall && string(expression.args[1]) == "@testset"
        _r18_trace("enter_original_testset")
    end
    _r18_product_map(expression)
end

Base.include(_r18_original_map, Main, _R18_SOURCE)
_r18_trace("original_complete")
