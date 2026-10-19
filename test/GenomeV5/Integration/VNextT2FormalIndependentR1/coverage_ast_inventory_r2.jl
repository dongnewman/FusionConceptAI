using JSON3
using SHA

const T2_AST_ROOT = normpath(joinpath(@__DIR__, "..", "..", "..", ".."))

t2_ast_sha256(bytes) = bytes2hex(SHA.sha256(bytes))
t2_ast_expr_hash(value) =
    t2_ast_sha256(Vector{UInt8}(codeunits(sprint(show, value))))

function t2_ast_semantic(value)
    value isa LineNumberNode && return nothing
    value isa Expr || return value
    Expr(value.head, map(t2_ast_semantic, value.args)...)
end

t2_ast_semantic_hash(value) = t2_ast_expr_hash(t2_ast_semantic(value))
t2_ast_test_macro(value) = value isa Expr && value.head === :macrocall &&
    string(value.args[1]) in ("@test", "@test_throws")

function t2_ast_parse_checked(path)
    expression = Meta.parseall(read(path, String))
    function check(value)
        value isa Expr || return
        value.head in (:error, :incomplete) &&
            error((:t2_ast_inventory_parse_error, path, value.head))
        foreach(check, value.args)
    end
    check(expression)
    expression
end

function t2_ast_testset_label(value)
    labels = filter(item -> item isa String, value.args[3:end])
    isempty(labels) ? sprint(show, value.args[3]) : String(first(labels))
end

function t2_ast_function_label(value)
    if value.head === :function
        return sprint(show, value.args[1])
    end
    if value.head === :(=) && !isempty(value.args) &&
            value.args[1] isa Expr && value.args[1].head === :call
        return sprint(show, value.args[1])
    end
    nothing
end

function t2_ast_collect_tests(value, rows=Any[];
        testsets=String[], functions=String[], controls=Any[], ast_path=Int[])
    value isa Expr || return rows
    if t2_ast_test_macro(value)
        line = value.args[2] isa LineNumberNode ? value.args[2].line : 0
        push!(rows, (
            line=line,
            macro_name=string(value.args[1]),
            expression_hash=t2_ast_expr_hash(value),
            semantic_expression_hash=t2_ast_semantic_hash(value),
            testset_path=copy(testsets),
            function_path=copy(functions),
            control_context=copy(controls),
            site_ast_path=copy(ast_path),
        ))
    end

    child_testsets = testsets
    child_functions = functions
    child_controls = controls
    if value.head === :macrocall && string(value.args[1]) == "@testset"
        child_testsets = [testsets; t2_ast_testset_label(value)]
    end
    function_label = t2_ast_function_label(value)
    function_label === nothing ||
        (child_functions = [functions; function_label])
    if value.head in (:for, :while, :if, :try, :let)
        child_controls = [controls; (
            head=string(value.head),
            ast_path=copy(ast_path),
            child_index=isempty(ast_path) ? 0 : last(ast_path),
            raw_context_hash=t2_ast_expr_hash(value),
            semantic_context_hash=t2_ast_semantic_hash(value),
        )]
    end
    for (child_index, argument) in enumerate(value.args)
        t2_ast_collect_tests(argument, rows;
            testsets=child_testsets,
            functions=child_functions,
            controls=child_controls,
            ast_path=[ast_path; child_index])
    end
    rows
end

function t2_ast_file_receipt(relative)
    path = normpath(joinpath(T2_AST_ROOT, relative))
    relative_path = relpath(path, T2_AST_ROOT)
    startswith(relative_path, "..") &&
        error((:t2_ast_inventory_path_escape, relative))
    bytes = read(path)
    (path=replace(relative_path, '\\' => '/'), bytes=length(bytes),
        sha256=t2_ast_sha256(bytes))
end

function t2_ast_write_new(path, value)
    (ispath(path) || islink(path)) &&
        error((:t2_ast_inventory_output_exists, path))
    isdir(dirname(path)) ||
        error((:t2_ast_inventory_output_parent_absent, dirname(path)))
    temp_path, io = mktemp(dirname(path); cleanup=false)
    try
        JSON3.write(io, value)
        write(io, '\n')
        flush(io)
        close(io)
        mv(temp_path, path; force=false)
    catch
        isopen(io) && close(io)
        ispath(temp_path) && rm(temp_path; force=true)
        rethrow()
    end
end

function t2_ast_expected_rows(coverage, role)
    if role == "old_focused"
        return coverage["old_assertion_sites"]
    elseif role == "successor"
        return coverage["successor_assertion_sites"]
    elseif role == "projection_regression"
        return coverage["versioned_product_repair_regression"][
            "assertion_sites"]
    end
    error((:t2_ast_inventory_unknown_role, role))
end

function main(args)
    length(args) == 2 || error(
        "usage: coverage_ast_inventory_r2.jl <coverage-map.json> <receipt.json>")
    coverage_path = normpath(abspath(args[1]))
    output_path = normpath(abspath(args[2]))
    coverage = JSON3.read(read(coverage_path, String), Dict{String,Any})
    plan = coverage["ast_inventory_plan"]
    plan["schema"] == "vnext-t2-independent-negative-ast-plan-r2" ||
        error(:t2_ast_inventory_plan_schema_mismatch)

    all_rows = Any[]
    source_receipts = Any[]
    for source in plan["sources"]
        role = String(source["role"])
        relative = String(source["path"])
        actual_source = t2_ast_file_receipt(relative)
        actual_source.bytes == source["bytes"] ||
            error((:t2_ast_inventory_source_bytes_mismatch, role))
        actual_source.sha256 == source["sha256"] ||
            error((:t2_ast_inventory_source_hash_mismatch, role))
        expected = [row for row in t2_ast_expected_rows(coverage, role)
                    if get(row, "path", relative) == relative]
        parsed = t2_ast_collect_tests(t2_ast_parse_checked(
            joinpath(T2_AST_ROOT, relative)))
        length(parsed) == length(expected) == source["assertion_site_count"] ||
            error((:t2_ast_inventory_site_count_mismatch, role,
                length(parsed), length(expected)))
        for (index, (actual, frozen)) in enumerate(zip(parsed, expected))
            actual.line == frozen["line"] ||
                error((:t2_ast_inventory_line_mismatch, role, index,
                    actual.line, frozen["line"]))
            actual.macro_name == frozen["macro_name"] ||
                error((:t2_ast_inventory_macro_mismatch, role, index))
            push!(all_rows, (
                role=role,
                source_path=relative,
                site_id=String(frozen["id"]),
                line=actual.line,
                macro_name=actual.macro_name,
                source_text_sha256=String(frozen["source_text_sha256"]),
                expression_hash=actual.expression_hash,
                semantic_expression_hash=actual.semantic_expression_hash,
                testset_path=actual.testset_path,
                function_path=actual.function_path,
                control_context=actual.control_context,
                site_ast_path=actual.site_ast_path,
            ))
        end
        push!(source_receipts, merge((role=role,), actual_source,
            (assertion_site_count=length(parsed),)))
    end

    length(all_rows) == plan["total_assertion_site_count"] ||
        error(:t2_ast_inventory_total_mismatch)
    length(Set(row.site_id for row in all_rows)) == length(all_rows) ||
        error(:t2_ast_inventory_duplicate_site_id)
    receipt = (
        schema="vnext-t2-independent-negative-ast-inventory-r2",
        status="pass",
        coverage_map=t2_ast_file_receipt(relpath(
            coverage_path, T2_AST_ROOT)),
        plan_schema=String(plan["schema"]),
        source_count=length(source_receipts),
        total_assertion_site_count=length(all_rows),
        old_assertion_site_count=count(row -> row.role == "old_focused", all_rows),
        successor_assertion_site_count=count(row -> row.role == "successor", all_rows),
        projection_assertion_site_count=count(
            row -> row.role == "projection_regression", all_rows),
        source_receipts=source_receipts,
        rows=all_rows,
        line_number_nodes_removed_only_from_semantic_hash=true,
        context_fields=("testset_path", "function_path", "control_context",
            "site_ast_path"),
        formal_t2_accepted=false,
        actual_model_attestation="unavailable",
    )
    t2_ast_write_new(output_path, receipt)
    println("VNEXT_T2_AST_INVENTORY=PASS sites=", length(all_rows),
        " sources=", length(source_receipts),
        " formal_t2_accepted=false")
    flush(stdout)
    0
end

exit(main(ARGS))
