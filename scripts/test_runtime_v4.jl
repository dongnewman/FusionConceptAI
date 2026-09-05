#!/usr/bin/env julia
"""Run RuntimeV4 checks in independent Julia processes.

Usage:
    julia --project=. scripts/test_runtime_v4.jl
    julia --project=. scripts/test_runtime_v4.jl core archive

The selected names are: core, vertical, archive, and spine.  `spine_cli` is
also available when the command-line report is wanted.  The child processes
inherit the active project and write their own test output.  This entrypoint
does not discover or alter worktrees.
"""

const _RUNTIME_TESTS = (
    core=("test/runtime_v4_core_tests.jl", "core standalone tests"),
    vertical=("test/runtime_v4_vertical_slice_tests.jl", "vertical slice tests"),
    archive=("test/runtime_v4_archive_tests.jl", "queue/archive tests"),
    spine=("test/runtime_v4_spine_tests.jl", "spine tests"),
    spine_cli=("scripts/run_v4_spine.jl", "spine CLI"),
)
const _RUNTIME_NAMES = (:core, :vertical, :archive, :spine, :spine_cli)
const _RUNTIME_DEFAULT_NAMES = (:core, :vertical, :archive, :spine)

function _usage_error(message::AbstractString)
    println(stderr, "error: ", message)
    println(stderr, "usage: julia --project=. scripts/test_runtime_v4.jl [core|vertical|archive|spine|spine_cli ...]")
    exit(2)
end

function _selected_names(args)
    isempty(args) && return _RUNTIME_DEFAULT_NAMES
    names = Symbol[]
    for arg in args
        name = Symbol(lowercase(String(arg)))
        name in _RUNTIME_NAMES || _usage_error("unknown RuntimeV4 check '$(arg)'")
        name in names && _usage_error("duplicate RuntimeV4 check '$(arg)'")
        push!(names, name)
    end
    Tuple(names)
end

function _child_command(relative_path::AbstractString)
    project = Base.active_project()
    project === nothing && _usage_error("run this script with an active Julia project, for example --project=.")
    path = normpath(joinpath(@__DIR__, "..", relative_path))
    isfile(path) || _usage_error("missing child entrypoint: $(path)")
    julia = Base.julia_cmd()
    Cmd(vcat(collect(julia.exec), ["--startup-file=no", "--project=$(project)", path]))
end

function _run_one(name::Symbol)
    relative_path, description = getproperty(_RUNTIME_TESTS, name)
    println("\n=== RuntimeV4 ", String(name), ": ", description, " ===")
    command = _child_command(relative_path)
    process = run(pipeline(command, stdout=stdout, stderr=stderr); wait=false)
    wait(process)
    status = process.exitcode
    println("=== RuntimeV4 ", String(name), " exit=", status, " ===")
    status
end

names = _selected_names(ARGS)
statuses = Pair{Symbol,Int}[]
for name in names
    push!(statuses, name => _run_one(name))
end

println("\nRuntimeV4 summary:")
for (name, status) in statuses
    println("  ", name, " exit=", status)
end
failed = filter(pair -> pair.second != 0, statuses)
if !isempty(failed)
    println(stderr, "RuntimeV4 checks failed: ", join([string(pair.first) for pair in failed], ", "))
    exit(1)
end
println("RuntimeV4 checks passed: ", join([string(pair.first) for pair in statuses], ", "))
