#!/usr/bin/env julia
"""Run the v4 P1 vertical slice from a caller-owned real Genome fixture.

Usage:
    julia --project=. scripts/run_v4_vertical_slice.jl fixture.jl

The fixture must define `candidate` (a CandidateStatePackageV4) and `registry`
(a GenomeContractRegistryV4).  Keeping the fixture explicit prevents this
entrypoint from manufacturing a Genome or silently substituting a mock.
"""

using FusionConceptAI
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "FusionRuntimeV4.jl"))
using .FusionRuntimeV4

function print_manifest(manifest)
    println("schema=", manifest.schema)
    println("version=", manifest.version)
    println("prefix_hash=", manifest.prefix_hash === nothing ? "null" : manifest.prefix_hash)
    println("physical_subject_hash=", manifest.physical_subject_hash === nothing ? "null" : manifest.physical_subject_hash)
    println("claim_ceiling=", manifest.claim_ceiling)
    println("layer_counts=", manifest.layer_counts)
    println("credible_count=", manifest.credible_count)
    println("unsupported_count=", manifest.unsupported_count)
    println("capability_gaps=", manifest.capability_gaps)
end

fixture = isempty(ARGS) ? joinpath(@__DIR__, "..", "examples", "runtime_v4_declared_fixture.jl") : abspath(ARGS[1])
isfile(fixture) || error("fixture file does not exist: $fixture")
include(fixture)
@assert @isdefined(candidate) "fixture must define candidate"
@assert @isdefined(registry) "fixture must define registry"
report = run_v4_vertical_slice(candidate, registry)
println("fixture=", fixture)
print_manifest(vertical_slice_manifest(report))
