using SHA, JSON3
const ROOT = normpath(joinpath(@__DIR__, "..", "..", "..", ".."))
const OLD = joinpath(@__DIR__, "..", "vnext_t1_candidate_state_package_v5_next_tests.jl")
const NEW = joinpath(@__DIR__, "..", "vnext_t1_candidate_state_package_v5_next_formal_v2_tests.jl")
const HELPER = joinpath(@__DIR__, "formal_contract_v2_checks.jl")
hexsha(bytes) = uppercase(bytes2hex(sha256(bytes)))
function collect_assertions(x, rows=Any[])
    if x isa Expr
        if x.head === :macrocall && string(x.args[1]) in ("@test", "@test_throws")
            push!(rows, (index=length(rows) + 1, line=x.args[2].line,
                macro_name=string(x.args[1]), expression_hash=hexsha(codeunits(sprint(show, x)))))
        end
        for child in x.args
            collect_assertions(child, rows)
        end
    end
    rows
end
function parse_checked(path)
    expression = Meta.parseall(read(path, String))
    function check(x)
        x isa Expr || return
        x.head in (:error, :incomplete) && error("parse failure in $path: $x")
        foreach(check, x.args)
    end
    check(expression)
    println("PARSE_OK ", relpath(path, ROOT))
    expression
end

old_bytes, new_bytes = read(OLD), read(NEW)
length(old_bytes) == 12975 || error("frozen byte count changed")
hexsha(old_bytes) == "970976C4122FC6B4F5303D6763C286514B1C9DC653ABA36D46E1D003BCBF9669" || error("frozen hash changed")
old_rows, new_rows = collect_assertions(parse_checked(OLD)), collect_assertions(parse_checked(NEW))
helper_ast = parse_checked(HELPER)
parse_checked(joinpath(ROOT, "src/Contracts/CandidateStatePackageV5Next.jl"))
length(old_rows) == length(new_rows) == 63 || error("lexical coverage changed")
count(r -> r.macro_name == "@test", new_rows) == 62 || error("@test count changed")
count(r -> r.macro_name == "@test_throws", new_rows) == 1 || error("@test_throws count changed")
isempty(collect_assertions(helper_ast)) || error("helper adds untracked assertion macros")
changed = [i for i in 1:63 if old_rows[i].expression_hash != new_rows[i].expression_hash]
changed == [13, 36] || error("unauthorized assertion changes: $changed")
all(old_rows[i].line == new_rows[i].line for i in 1:63) || error("assertion line drift")
old_lines = split(replace(String(copy(old_bytes)), "\r\n" => "\n"), '\n')
new_lines = split(replace(String(copy(new_bytes)), "\r\n" => "\n"), '\n')
length(old_lines) == length(new_lines) || error("line layout changed")
changed_lines = [i for i in eachindex(old_lines) if old_lines[i] != new_lines[i]]
changed_lines == [1, 19, 115, 151, 152] || error("nonassertion source drift: $changed_lines")
occursin("8_269_445", join(new_lines, '\n')) || error("large input missing")

file_receipt(path) = (path=replace(relpath(path, ROOT), '\\' => '/'),
    bytes=filesize(path), sha256=hexsha(read(path)))
rows = [(target_id="r18v2-" * lpad(string(i), 3, '0'),
    supersedes_target="r12-" * lpad(string(i), 3, '0'),
    unchanged_expression=i ∉ changed,
    old=old_rows[i], successor=new_rows[i]) for i in 1:63]
manifest = (schema="r18_formal_test_contract_v2_lineage",
    verdict="static_parse_lineage_pass_only", formal_T1=false,
    original=file_receipt(OLD), successor=file_receipt(NEW), helper=file_receipt(HELPER),
    product=file_receipt(joinpath(ROOT, "src/Contracts/CandidateStatePackageV5Next.jl")),
    lexical_targets=63, unchanged_expression_hashes=61,
    superseded_targets=["r12-013", "r12-036"], changed_lines=changed_lines,
    all_nonassertion_statements_preserved=true,
    added_nonassertion_statement="definition-only versioned check helper include on old blank line 19",
    changed_scope=(diagnostic="valid full tuple plus existing typed-absence diagnostic full tuple",
        factory="external T0/closed T1 contract, byte, hash, reference and independent projection joins"),
    large_input_bytes=8269445, runtime_coverage="not_executed", rows=rows,
    actual_model_attestation="unavailable")
target = joinpath(ROOT, ARGS[1], "lineage_manifest.json")
ispath(target) && error("lineage evidence exists")
open(target, "w") do io
    JSON3.write(io, manifest)
end
println("R18_V2_LINEAGE_PASS lexical_targets=63 unchanged_expression_hashes=61 changed_targets=13,36 large_input_bytes=8269445")
