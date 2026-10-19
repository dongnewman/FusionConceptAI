using SHA

global const R15_RUNTIME_IDS = String[]
global const R15_TARGET_ID = "r15-001"

function r15_record(id)
    push!(R15_RUNTIME_IDS, id)
    nothing
end

function r15_assert(_)
    nothing
end

function r15_transform(x, target_id, cursor)
    if x isa Expr
        if x.head === :call && !isempty(x.args) && x.args[1] === :r15_assert
            cursor[] += 1
            id = "r15-" * lpad(string(cursor[]), 3, '0')
            literal = QuoteNode(id)
            return Expr(:if,
                Expr(:call, :(==), :R15_TARGET_ID, literal),
                Expr(:block,
                    Expr(:call, :r15_record, literal),
                    x),
                nothing)
        end
        return Expr(x.head, map(arg -> r15_transform(arg, target_id, cursor), x.args)...)
    end
    x
end

synthetic = """
const R15_SYNTHETIC_SOURCE_PATH = @__FILE__
const R15_SYNTHETIC_SOURCE_DIR = @__DIR__
function r15_target_function()
    r15_assert(\"selected target\")
end
function r15_other_function()
    r15_assert(\"non-target\")
end
r15_target_function()
r15_target_function()
r15_other_function()
"""

path, io = mktemp()
write(io, synthetic)
close(io)
try
    bytes = read(path)
    source = String(copy(bytes))
    bytes[1] = bytes[1] == UInt8('c') ? UInt8('d') : UInt8('c')
    source == read(path, String) || error("R15 probe source copy changed after byte-vector mutation")
    length(source) == length(read(path)) || error("R15 probe source copy length changed")

    ast = Meta.parseall(source)
    dry_cursor = Ref(0)
    dry = r15_transform(ast, R15_TARGET_ID, dry_cursor)
    dry_cursor[] == 2 || error("R15 probe dry cursor expected 2, got $(dry_cursor[])")
    runtime_cursor = Ref(0)
    mapexpr = expression -> r15_transform(expression, R15_TARGET_ID, runtime_cursor)
    Base.include(mapexpr, Main, path)
    runtime_cursor[] == 2 || error("R15 probe executable cursor expected 2, got $(runtime_cursor[])")
    R15_RUNTIME_IDS == ["r15-001", "r15-001"] ||
        error("R15 probe runtime IDs mismatch: $(R15_RUNTIME_IDS)")
    R15_SYNTHETIC_SOURCE_PATH == path || error("R15 probe @__FILE__ path was not preserved")
    R15_SYNTHETIC_SOURCE_DIR == dirname(path) || error("R15 probe @__DIR__ was not preserved")
    println("R15_AST_PROBE_PASS runtime_ids=$(join(R15_RUNTIME_IDS, ',')) dry_cursor=$(dry_cursor[]) executable_cursor=$(runtime_cursor[]) source_path_preserved=true source_dir_preserved=true vector_string_copy=true")
finally
    rm(path; force=true)
end
