using SHA

const NG12_R30_ADDITIONAL_SOURCE_PATHS = [
    "src/GenomeV5/Integration/ManagedExternalProcessV1.jl",
    "src/GenomeV5/Integration/NativeGitReadCompatibilityV1.jl",
]
const NG12_R30_SOURCE_REBINDING_PATHS = [
    "src/GenomeV5/G1/G1SourceAuthorityFactoryV1.jl",
    "src/GenomeV5/G2/G2SourceAuthorityFactoryV1.jl",
    "src/GenomeV5/G3/G3SourceAuthorityFactoryV1.jl",
    "test/GenomeV5/Integration/vnext_declaration_transport_local_v1_tests.jl",
]
const NG12_R30_PRESERVED_ORIGINAL_PATHS = Dict(
    relative => "runs/e/lifecycle_systemic_repair_20260927_r1/" *
                "live_foundation_integration/preimages/" * relative
    for relative in NG12_R30_SOURCE_REBINDING_PATHS
)

function ng12_r30_parse_issue(x)
    x isa Expr || return nothing
    x.head in (:error, :incomplete) && return x.head
    for child in x.args
        issue = ng12_r30_parse_issue(child)
        issue === nothing || return issue
    end
    return nothing
end

function ng12_r30_checked_repo_file(root::String, relative::String)
    occursin('\\', relative) && error("R30 source path is not canonical POSIX")
    parts = split(relative, '/')
    isempty(relative) && error("R30 source path is empty")
    any(part -> part in ("", ".", ".."), parts) &&
        error("R30 source path contains a noncanonical component")
    root_abs = abspath(root)
    islink(root_abs) && error("R30 source root must not be a symlink")
    isdir(root_abs) || error("R30 source root is not a directory")
    path = normpath(joinpath(root_abs, parts...))
    relative_check = replace(relpath(path, root_abs), '\\' => '/')
    relative_check == relative || error("R30 source path escaped repository root")
    current = root_abs
    for part in parts
        current = joinpath(current, part)
        islink(current) && error("R30 source path contains a symlink: " * relative)
    end
    isfile(path) || error("R30 source file is absent: " * relative)
    return path
end

function ng12_r30_parse_manifest_stdin(expected_bytes::Int, expected_sha256::String,
                                       expected_entries::Int, root::String,
                                       additional_sources::Vector{Tuple{String,Int,String}},
                                       source_rebindings::Vector{Tuple{String,Int,String,Int,String}})
    expected_entries == 108 || error("R30 original ZIP manifest must remain 108 entries")
    manifest_bytes = read(stdin)
    length(manifest_bytes) == expected_bytes || error("R30 manifest stdin byte count mismatch")
    bytes2hex(SHA.sha256(manifest_bytes)) == expected_sha256 ||
        error("R30 manifest stdin SHA-256 mismatch")

    [row[1] for row in source_rebindings] == NG12_R30_SOURCE_REBINDING_PATHS ||
        error("R30 source rebindings differ from the fixed four-path order")
    rebindings_by_path = Dict(row[1] => row for row in source_rebindings)
    length(rebindings_by_path) == 4 || error("R30 source rebindings contain duplicate paths")

    count = 0
    manifest_sha_by_path = Dict{String,String}()
    rebound_current_parsed = Set{String}()
    manifest = IOBuffer(manifest_bytes)
    for line in eachline(manifest)
        expected, relative = split(line, "\t"; limit=2)
        occursin('\\', relative) && error("manifest path is not canonical POSIX: " * relative)
        parts = split(relative, '/')
        any(part -> part in ("", ".", ".."), parts) &&
            error("manifest path is not canonical: " * relative)
        haskey(manifest_sha_by_path, relative) &&
            error("R30 manifest contains duplicate source path: " * relative)
        manifest_sha_by_path[relative] = expected
        if haskey(rebindings_by_path, relative)
            _, original_bytes, original_sha256, current_bytes, current_sha256 =
                rebindings_by_path[relative]
            expected == original_sha256 ||
                error("R30 original manifest SHA differs from rebound source identity: " * relative)
            preserved_relative = get(NG12_R30_PRESERVED_ORIGINAL_PATHS, relative, "")
            isempty(preserved_relative) &&
                error("R30 preserved original source path is not allowlisted: " * relative)
            preserved_path = ng12_r30_checked_repo_file(root, preserved_relative)
            preserved_bytes = read(preserved_path)
            length(preserved_bytes) == original_bytes ||
                error("R30 preserved original source byte count mismatch: " * relative)
            bytes2hex(SHA.sha256(preserved_bytes)) == original_sha256 ||
                error("R30 preserved original source SHA-256 mismatch: " * relative)

            current_path = ng12_r30_checked_repo_file(root, relative)
            current_source_bytes = read(current_path)
            length(current_source_bytes) == current_bytes ||
                error("R30 current rebound source byte count mismatch: " * relative)
            bytes2hex(SHA.sha256(current_source_bytes)) == current_sha256 ||
                error("R30 current rebound source SHA-256 mismatch: " * relative)
            parsed = Meta.parseall(String(current_source_bytes))
            issue = ng12_r30_parse_issue(parsed)
            issue === nothing || error("parse tree " * String(issue) * ": " * relative)
            push!(rebound_current_parsed, relative)
        else
            path = ng12_r30_checked_repo_file(root, relative)
            bytes = read(path)
            bytes2hex(SHA.sha256(bytes)) == expected ||
                error("parse pin mismatch: " * relative)
            parsed = Meta.parseall(String(bytes))
            issue = ng12_r30_parse_issue(parsed)
            issue === nothing || error("parse tree " * String(issue) * ": " * relative)
        end
        count += 1
    end
    count == expected_entries || error("R30 manifest entry count mismatch")
    for (relative, original_bytes, original_sha256, _, _) in source_rebindings
        get(manifest_sha_by_path, relative, nothing) == original_sha256 ||
            error("R30 source rebinding is not bound to one original manifest row: " * relative)
        original_bytes > 0 || error("R30 original source byte count must be positive: " * relative)
    end
    length(rebound_current_parsed) == 4 ||
        error("R30 current rebound source parse count mismatch")
    manifest_count = count
    length(additional_sources) == 2 || error("R30 additional Julia source count mismatch")
    [row[1] for row in additional_sources] == NG12_R30_ADDITIONAL_SOURCE_PATHS ||
        error("R30 additional Julia source path set/order mismatch")
    additional_count = 0
    root_abs = abspath(root)
    for (relative, expected_source_bytes, expected_source_sha256) in additional_sources
        occursin('\\', relative) && error("R30 additional source path is not canonical POSIX")
        parts = split(relative, '/')
        any(part -> part in ("", ".", ".."), parts) &&
            error("R30 additional source path is not canonical")
        path = normpath(joinpath(root_abs, parts...))
        relative_check = replace(relpath(path, root_abs), '\\' => '/')
        relative_check == relative || error("R30 additional source escaped repository root")
        isfile(path) || error("R30 additional Julia source is absent: " * relative)
        source_bytes = read(path)
        length(source_bytes) == expected_source_bytes ||
            error("R30 additional Julia source byte count mismatch: " * relative)
        bytes2hex(SHA.sha256(source_bytes)) == expected_source_sha256 ||
            error("R30 additional Julia source SHA-256 mismatch: " * relative)
        parsed = Meta.parseall(String(source_bytes))
        issue = ng12_r30_parse_issue(parsed)
        issue === nothing || error("parse tree " * String(issue) * ": " * relative)
        additional_count += 1
    end
    total_count = manifest_count + additional_count
    total_count == expected_entries + length(additional_sources) ||
        error("R30 total Julia parse count mismatch")
    println("NG12_PARSE status=pass files=", manifest_count)
    println("NG12_PARSE_ADDITIONAL status=pass manifest_files=", manifest_count,
            " additional_files=", additional_count, " total_files=", total_count)
    println("NG12_PARSE_REBINDING status=pass manifest_entries=", manifest_count,
            " original_bytes_verified=", length(source_rebindings),
            " original_sources_parsed=0 current_sources_parsed=",
            length(rebound_current_parsed), " total_files=", total_count)
    return nothing
end

length(ARGS) == 36 ||
    error("R30 parse_all expects the original manifest contract, two pinned extra sources, and four source rebindings")
additional_sources = Tuple{String,Int,String}[]
for group_start in (5, 9)
    ARGS[group_start] == "--extra-source" || error("R30 extra source marker is missing")
    push!(additional_sources,
          (ARGS[group_start + 1], parse(Int, ARGS[group_start + 2]),
           ARGS[group_start + 3]))
end
source_rebindings = Tuple{String,Int,String,Int,String}[]
for group_start in (13, 19, 25, 31)
    ARGS[group_start] == "--source-rebinding" ||
        error("R30 source rebinding marker is missing")
    push!(source_rebindings,
          (ARGS[group_start + 1], parse(Int, ARGS[group_start + 2]),
           ARGS[group_start + 3], parse(Int, ARGS[group_start + 4]),
           ARGS[group_start + 5]))
end
ng12_r30_parse_manifest_stdin(parse(Int, ARGS[1]), ARGS[2], parse(Int, ARGS[3]),
                              ARGS[4], additional_sources, source_rebindings)
