"""Windows-safe fresh-process output capture for P1 adversarial tests."""

if !isdefined(Main, :_p1_child_output)
    function _p1_child_output(script::AbstractString)
        stdout_path = tempname()
        stderr_path = tempname()
        try
            cmd = `$(Base.julia_cmd()) --startup-file=no --project=$(Base.active_project()) -e $script`
            process = run(pipeline(ignorestatus(cmd), stdout=stdout_path, stderr=stderr_path))
            output = read(stdout_path, String)
            diagnostics = read(stderr_path, String)
            success(process) || throw(ErrorException(
                "fresh P1 child exited with code $(process.exitcode): $(strip(diagnostics))"))
            output
        finally
            rm(stdout_path; force=true)
            rm(stderr_path; force=true)
        end
    end
end

# Capture a fresh child as pipe-delimited fields without losing file-backed diagnostics.
if !isdefined(Main, :_p1_child_fields)
    _p1_child_fields(script::AbstractString; separator="|") =
        split(strip(_p1_child_output(script)), separator)
end
