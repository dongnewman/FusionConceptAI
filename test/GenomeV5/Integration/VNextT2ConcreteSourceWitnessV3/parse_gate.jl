using SHA

function reject_parse_nodes(value, path)
    value isa Expr || return
    value.head in (:error, :incomplete) &&
        error("parse error in $(path): $(value)")
    foreach(child -> reject_parse_nodes(child, path), value.args)
end

function main(args)
    length(args) == 1 || error("usage: parse_gate.jl SHA256_TAB_PATH_MANIFEST")
    println("julia_version=", VERSION)
    manifest_path = only(args)
    manifest_lines = readlines(manifest_path)
    isempty(manifest_lines) && error("parse manifest is empty")
    seen = Set{String}()
    parsed_count = 0
    for (line_number, line) in enumerate(manifest_lines)
        isempty(line) && continue
        columns = split(line, '\t'; limit=2)
        length(columns) == 2 || error(
            "parse manifest line $(line_number) must be SHA256<TAB>PATH")
        expected_sha256, relative_path = columns
        occursin(r"^[0-9a-f]{64}$", expected_sha256) ||
            error("parse manifest line $(line_number) has invalid SHA-256")
        isabspath(relative_path) && error(
            "parse manifest line $(line_number) has an absolute path")
        normalized = normpath(relative_path)
        (normalized == ".." || first(splitpath(normalized)) == "..") &&
            error("parse manifest line $(line_number) escapes the repository")
        normalized in seen && error("duplicate parse manifest path: $(normalized)")
        push!(seen, normalized)
        path = normalized
        bytes = read(path)
        actual_sha256 = bytes2hex(SHA.sha256(bytes))
        actual_sha256 == expected_sha256 || error(
            "manifest_sha256_mismatch: $(relative_path)")
        expression = Meta.parseall(String(copy(bytes)))
        reject_parse_nodes(expression, path)
        println("parsed=", path,
            " bytes=", length(bytes),
            " sha256=", actual_sha256)
        parsed_count += 1
    end

    parsed_count == length(seen) || error("parse manifest accounting mismatch")
    println("parse_manifest=", manifest_path, " entries=", parsed_count)
    println("parse_gate=pass")
end

main(ARGS)
