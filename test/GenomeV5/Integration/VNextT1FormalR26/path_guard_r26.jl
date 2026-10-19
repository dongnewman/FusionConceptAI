"""Path containment helpers shared by the independent R26 formal harnesses."""

function r26_guard_relative(value::AbstractString, label::AbstractString)
    isempty(value) && error("$label must not be empty")
    isabspath(value) && error("$label must be repository-relative")
    Sys.iswindows() && occursin(r"^[A-Za-z]:", value) &&
        error("$label must not be drive-qualified")
    any(==(".."), splitpath(value)) && error("$label traversal forbidden")
    value
end

function r26_guard_is_within(root::AbstractString, candidate::AbstractString;
        allow_root::Bool=false)
    root_path = abspath(normpath(root))
    candidate_path = abspath(normpath(candidate))
    relative = try
        relpath(candidate_path, root_path)
    catch
        return false
    end
    isabspath(relative) && return false
    normalized = normpath(relative)
    normalized == "." && return allow_root
    parts = splitpath(normalized)
    !isempty(parts) && all(!=(".."), parts)
end

function r26_guard_existing_repo_file(repo_root::AbstractString,
        value::AbstractString; label::AbstractString="dependency")
    r26_guard_relative(value, label)
    root = realpath(repo_root)
    lexical = normpath(joinpath(root, value))
    isfile(lexical) || error("$label is not an existing file: $value")
    path = realpath(lexical)
    r26_guard_is_within(root, path) || error("$label escapes repository: $value")
    path
end

function r26_guard_new_owned_file(repo_root::AbstractString,
        owned_root::AbstractString, value::AbstractString;
        label::AbstractString="output", require_absent::Bool=true)
    r26_guard_relative(value, label)
    root = realpath(repo_root)
    owned = realpath(owned_root)
    r26_guard_is_within(root, owned; allow_root=true) ||
        error("owned root escapes repository")
    lexical = normpath(joinpath(root, value))
    parent = dirname(lexical)
    isdir(parent) || error("controller must create $label directory")
    canonical_parent = realpath(parent)
    r26_guard_is_within(owned, canonical_parent; allow_root=true) ||
        error("$label outside owned evidence root")
    name = basename(lexical)
    isempty(name) && error("$label filename must not be empty")
    path = joinpath(canonical_parent, name)
    require_absent && ispath(path) && error("$label already exists")
    path
end

function r26_guard_expect_rejection(f, label::AbstractString)
    rejected = false
    try
        f()
    catch
        rejected = true
    end
    rejected || error("path guard negative did not reject: $label")
    label
end

function r26_path_guard_selftest(repo_root::AbstractString,
        owned_root::AbstractString)
    root = realpath(repo_root)
    owned = realpath(owned_root)
    project = r26_guard_existing_repo_file(joinpath(root, ""), "Project.toml";
        label="selftest trailing-root project")
    nested = r26_guard_existing_repo_file(root, "src/FusionConceptAI.jl";
        label="selftest nested source")
    owned_rel = relpath(owned, root)
    ledger_probe = r26_guard_new_owned_file(root, owned,
        joinpath(owned_rel, "r26_path_guard_probe.json");
        label="selftest ledger", require_absent=false)
    dirname(ledger_probe) == owned || error("path guard ledger parent mismatch")
    r26_guard_is_within(root, project) || error("path guard project rejection")
    r26_guard_is_within(root, nested) || error("path guard nested rejection")

    sibling = root * "_other"
    r26_guard_is_within(root, sibling; allow_root=true) &&
        error("path guard admitted repository sibling prefix")
    negatives = String[]
    push!(negatives, r26_guard_expect_rejection(
        () -> r26_guard_existing_repo_file(root, joinpath("..", "Project.toml")),
        "dotdot_escape"))
    push!(negatives, r26_guard_expect_rejection(
        () -> r26_guard_existing_repo_file(root, joinpath(root, "Project.toml")),
        "absolute_path"))
    push!(negatives, "repository_sibling_prefix")
    if Sys.iswindows()
        drive = uppercase(first(root)) == 'Z' ? 'Y' : 'Z'
        foreign = string(drive, ":\\r26-foreign\\Project.toml")
        push!(negatives, r26_guard_expect_rejection(
            () -> r26_guard_existing_repo_file(root, foreign),
            "different_drive"))
    else
        push!(negatives, "different_drive_not_applicable")
    end
    evidence_sibling = owned * "_other"
    r26_guard_is_within(owned, evidence_sibling; allow_root=true) &&
        error("path guard admitted evidence sibling prefix")
    push!(negatives, "evidence_sibling_prefix")
    (schema="vnext_t1_r26_path_guard_selftest_v1",
        positive_cases=("trailing_root_project", "nested_source", "new_ledger_parent"),
        negative_cases=Tuple(negatives), passed=true)
end
