using SHA, JSON3, Dates

const _R19_ROOT = normpath(joinpath(@__DIR__, "..", "..", "..", ".."))
const _R19_SOURCE_REL = "test/GenomeV5/Integration/vnext_t1_candidate_state_package_v5_next_formal_v2_tests.jl"
const _R19_SOURCE = joinpath(_R19_ROOT, _R19_SOURCE_REL)
const _R19_EXPECTED = (
    (_R19_SOURCE_REL, 13248, "A1D590ED3BF7A125C3A90A36F509ED24D4A653BD74F7371FDBF36ABA3CFACE72"),
    ("test/GenomeV5/Integration/vnext_t1_candidate_state_package_v5_next_tests.jl", 12975, "970976C4122FC6B4F5303D6763C286514B1C9DC653ABA36D46E1D003BCBF9669"),
    ("test/GenomeV5/Integration/VNextT1V1R18/formal_contract_v2_checks.jl", 3327, "4AFB1D1225CC209ED896B824E442C5344D06934BEE43180645F1BFA7C3D214C2"),
    ("src/Contracts/CandidateStatePackageV5Next.jl", 54870, "3FB79DCB4EF81D30FA299AE2D24165F9CD77C220CCB831B79796B0E6E3CAF95C"))
const _R19_PROTECTED = (
    (row[1] for row in _R19_EXPECTED)...,
    "test/GenomeV5/Integration/vnext_declaration_transport_local_v1_tests.jl",
    "test/GenomeV5/Integration/vnext_t1_projection_diagnostic_v1.jl",
    "src/GenomeV5/Integration/VNextDeclarationAuthorityRecheckLocalV1.jl",
    "src/GenomeV5/Integration/VNextGenomeV5Integration.jl",
    "src/Contracts/VNextT1PackageBindingAdapterV1.jl",
    "src/Contracts/VNextT1CandidateBindingV2.jl",
    "src/FusionConceptAI.jl", "src/Contracts/GenomeContractRegistry.jl",
    "src/IR/OperatorRegistry.jl", "src/Canonical/CanonicalJSON.jl",
    "test/GenomeV5/Integration/VNextT1V1R19/static_selection_harness.jl",
    "test/GenomeV5/Integration/VNextT1V1R19/r19_controller.py",
    "test/GenomeV5/Integration/VNextT1V1R18/run_recorded.py")

_r19_sha(bytes) = uppercase(bytes2hex(sha256(bytes)))
_r19_expr_hash(x) = _r19_sha(codeunits(sprint(show, x)))
_r19_macro(x) = x isa Expr && x.head === :macrocall &&
    string(x.args[1]) in ("@test", "@test_throws")
_r19_id(index) = "r19-" * lpad(string(index), 3, '0')
function _r19_collect(x, rows=Any[])
    if x isa Expr
        _r19_macro(x) && push!(rows, (id=_r19_id(length(rows) + 1),
            line=x.args[2].line, macro_name=string(x.args[1]),
            expression_hash=_r19_expr_hash(x)))
        foreach(child -> _r19_collect(child, rows), x.args)
    end
    rows
end
function _r19_target(selection, rows)
    isempty(selection) && error("zero target selection")
    length(unique(selection)) == length(selection) || error("duplicate target selection")
    length(selection) == 1 || error("exactly one target is required")
    id = only(selection)
    count(row -> row.id == id, rows) == 1 || error("unknown or duplicate target id")
    id
end
function _r19_transform(x, target, cursor)
    if x isa Expr
        if _r19_macro(x)
            cursor[] += 1
            id = _r19_id(cursor[])
            id == target || return nothing
            # Insert the original macro object without rewriting any operand.
            return Expr(:block, Expr(:call, :__r19_record, QuoteNode(id)), x)
        end
        return Expr(x.head, map(arg -> _r19_transform(arg, target, cursor), x.args)...)
    end
    x
end
function _r19_erase_assertions_and_records(x)
    _r19_macro(x) && return nothing
    if x isa Expr
        # Erase only the exact injected record+original-macro wrapper.
        if x.head === :block && length(x.args) == 2 &&
                x.args[1] isa Expr && x.args[1].head === :call &&
                x.args[1].args[1] === :__r19_record && _r19_macro(x.args[2])
            return nothing
        end
        return Expr(x.head, map(_r19_erase_assertions_and_records, x.args)...)
    end
    x
end
function _r19_parse(path)
    expression = Meta.parseall(read(path, String))
    function check(x)
        x isa Expr || return
        x.head in (:error, :incomplete) && error("parse error in $path: $x")
        foreach(check, x.args)
    end
    check(expression)
    expression
end
function _r19_inputs()
    for (rel, size, digest) in _R19_EXPECTED
        bytes = read(joinpath(_R19_ROOT, rel))
        length(bytes) == size && _r19_sha(bytes) == digest || error("frozen input drift: $rel")
    end
    source = read(_R19_SOURCE, String)
    occursin("__r19_record", source) && error("reserved instrumentation symbol collision")
    ast = _r19_parse(_R19_SOURCE)
    rows = _r19_collect(ast)
    length(rows) == 63 || error("source assertion count drift")
    length(unique(row.id for row in rows)) == 63 || error("duplicate source target IDs")
    length(unique(row.expression_hash for row in rows)) == 63 || error("duplicate expression hashes")
    count(row -> row.macro_name == "@test", rows) == 62 || error("test count drift")
    count(row -> row.macro_name == "@test_throws", rows) == 1 || error("test_throws count drift")
    ast, rows
end
function _r19_protected()
    Dict(rel => (bytes=filesize(joinpath(_R19_ROOT, rel)),
        sha256=_r19_sha(read(joinpath(_R19_ROOT, rel)))) for rel in _R19_PROTECTED)
end
function _r19_proof(ast, rows, target)
    _r19_target([target], rows)
    cursor = Ref(0)
    transformed = _r19_transform(ast, target, cursor)
    cursor[] == 63 || error("traversal did not visit 63 targets")
    selected = _r19_collect(transformed)
    length(selected) == 1 || error("selected macro count is not exactly one")
    original = only(filter(row -> row.id == target, rows))
    only(selected).expression_hash == original.expression_hash || error("selected macro changed")
    before = _r19_erase_assertions_and_records(ast)
    after = _r19_erase_assertions_and_records(transformed)
    isequal(before, after) || error("nonassertion AST changed")
    (target_id=target, source_macro=original, selected_count=1,
        selected_expression_hash=only(selected).expression_hash,
        context_ast_equal=true, context_hash=_r19_expr_hash(before))
end
function _r19_rejects(f, message)
    err = try f(); nothing catch caught; caught end
    err isa ErrorException && occursin(message, err.msg) || error("negative self-test failed: $message")
    true
end
function _r19_static(relative_output)
    before = _r19_protected()
    ast, rows = _r19_inputs()
    proofs = [_r19_proof(ast, rows, row.id) for row in rows]
    negatives = (
        zero=_r19_rejects(() -> _r19_target(String[], rows), "zero"),
        duplicate=_r19_rejects(() -> _r19_target(["r19-001", "r19-001"], rows), "duplicate"),
        unknown=_r19_rejects(() -> _r19_target(["r19-064"], rows), "unknown"),
        multiple=_r19_rejects(() -> _r19_target(["r19-001", "r19-002"], rows), "exactly one"),
        duplicate_rows=_r19_rejects(() -> _r19_target(["r19-001"], [rows[1], rows[1]]), "duplicate"))
    _r19_parse(@__FILE__)
    _r19_parse(joinpath(_R19_ROOT, _R19_EXPECTED[3][1]))
    after = _r19_protected()
    before == after || error("protected input changed during static proof")
    isabspath(relative_output) && error("absolute evidence path forbidden")
    ".." in splitpath(relative_output) && error("evidence traversal forbidden")
    directory = normpath(joinpath(_R19_ROOT, relative_output))
    allowed = normpath(joinpath(_R19_ROOT, "docs/implementation/UP1-04A-VNEXT-T1"))
    startswith(directory, allowed * string(Base.Filesystem.path_separator)) || error("evidence outside owner root")
    isdir(directory) || error("controller must create new evidence directory first")
    file = joinpath(directory, "static_manifest.json")
    ispath(file) && error("evidence already exists")
    manifest = (schema="r19_static_selection_preexecution", verdict="static_only",
        formal_T1=false, product_execution=false, source=_R19_SOURCE_REL,
        source_sha256=_R19_EXPECTED[1][3], source_bytes=_R19_EXPECTED[1][2],
        static_targets=rows, proofs=proofs, negative_selftests=negatives,
        nonassertion_markers_preserved=true, legal_runtime_repeated_hits=true,
        before_protected=before, after_protected=after, protected_unchanged=true,
        actual_model_attestation="unavailable")
    open(file, "w") do io
        JSON3.write(io, manifest)
    end
    println("R19_STATIC_PASS targets=63 selected_macro_hashes=63 context_ast_equal=63 selector_negative_tests=5 product_execution=false")
end

const __R19_RUNTIME_IDS = String[]
const __R19_TARGET = Ref("")
function __r19_record(id)
    id == __R19_TARGET[] || error("foreign runtime assertion ID")
    push!(__R19_RUNTIME_IDS, id)
    println("R19_ASSERTION_HIT id=$id invocation=$(length(__R19_RUNTIME_IDS))")
    flush(stdout)
    nothing
end
function _r19_child(selection)
    before = _r19_protected()
    ast, rows = _r19_inputs()
    target = _r19_target(selection, rows)
    proof = _r19_proof(ast, rows, target)
    __R19_TARGET[] = target
    empty!(__R19_RUNTIME_IDS)
    println("R19_SCOPE=single_target_not_formal_acceptance target=$target")
    flush(stdout)
    cursor = Ref(0)
    Base.include(x -> _r19_transform(x, target, cursor), Main, _R19_SOURCE)
    cursor[] == 63 || error("runtime traversal drift")
    !isempty(__R19_RUNTIME_IDS) || error("zero runtime hits")
    all(==(target), __R19_RUNTIME_IDS) || error("foreign runtime IDs")
    after = _r19_protected()
    before == after || error("protected source changed during child")
    _r19_inputs()
    receipt = (schema="r19_single_target_runtime", target_id=target,
        source_sha256=_R19_EXPECTED[1][3], selected_expression_hash=proof.selected_expression_hash,
        runtime_assertion_ids=copy(__R19_RUNTIME_IDS), hit_count=length(__R19_RUNTIME_IDS),
        expected_multiplicity_status="typed_unknown", runtime_context_completed=true,
        context_ast_equal=proof.context_ast_equal, context_hash=proof.context_hash,
        source_and_protected_unchanged=true, before_protected=before, after_protected=after,
        full_formal_acceptance=false, pid=getpid(), utc=string(Dates.now(Dates.UTC)))
    println("R19_CHILD_LEDGER=", JSON3.write(receipt)); flush(stdout)
end

if length(ARGS) == 2 && ARGS[1] == "--static"
    _r19_static(ARGS[2])
elseif !isempty(ARGS) && ARGS[1] == "--child"
    _r19_child(ARGS[2:end])
else
    error("usage: --static <new-controller-evidence-dir> OR --child <one-target>")
end
