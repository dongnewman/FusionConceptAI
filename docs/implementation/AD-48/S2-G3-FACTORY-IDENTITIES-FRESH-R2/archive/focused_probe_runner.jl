using Dates
const started = Dates.now(Dates.UTC)
const root = normpath(joinpath(@__DIR__, "..", "..", "..", "..", ".."))
const test_path = joinpath(root, "test", "GenomeV5", "G3", "g3_source_authority_factory_v1_tests.jl")
status = "pass"
try
    Base.include(Main, test_path)
catch err
    status = "failed:" * sprint(showerror, err)
end
println("focused_status=$(status)")
println("focused_pid=$(getpid())")
println("focused_utc_start=$(started)")
println("focused_utc_end=$(Dates.now(Dates.UTC))")
status == "pass" || exit(1)
