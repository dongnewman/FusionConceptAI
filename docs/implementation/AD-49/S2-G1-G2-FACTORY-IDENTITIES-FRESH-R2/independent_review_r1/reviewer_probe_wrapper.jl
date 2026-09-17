using Dates
const REVIEW_ROOT = normpath(joinpath(@__DIR__, "..", "..", "..", "..", ".."))
const SOURCE_SCRIPT = joinpath(REVIEW_ROOT, "docs", "implementation", "AD-49", "S2-G1-G2-FACTORY-IDENTITIES-FRESH-R2", "archive", "run_s2_probe.jl")
const ARCHIVE_FILENAME = SOURCE_SCRIPT
const OUTPUT_REL = length(ARGS) >= 1 ? ARGS[1] : "replay_1_success"
const OUTPUT_DIR = normpath(joinpath(@__DIR__, OUTPUT_REL))
mkpath(OUTPUT_DIR)
source = read(SOURCE_SCRIPT, String)
replacement = "const OUT = raw\"" * replace(OUTPUT_DIR, "\\" => "/") * "\""
patched = replace(source, "const OUT = normpath(joinpath(@__DIR__, \"..\"))" => replacement)
println("parse_and_include_source=", SOURCE_SCRIPT)
println("output_dir=", OUTPUT_DIR)
Base.include_string(Main, patched, ARCHIVE_FILENAME)
