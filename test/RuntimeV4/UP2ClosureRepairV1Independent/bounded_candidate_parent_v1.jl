#!/usr/bin/env julia

# Build the real DGPI parent once and save it for natural candidate-scenario
# shards.  The child loader defines the same nested runtime module without
# replaying the expensive parent construction.  A fresh-process round trip is
# mandatory before any scenario receipt can be accepted.

using JSON3, SHA

const _BCP_REPO = normpath(joinpath(@__DIR__, "..", "..", ".."))
_bcp_sha(path) = bytes2hex(SHA.sha256(read(path)))

function _bcp_existing_repo_file(relative::AbstractString)
    isempty(relative) && error("frozen-input path must not be empty")
    isabspath(relative) && error("absolute frozen-input path refused")
    Sys.iswindows() && occursin(r"^[A-Za-z]:", relative) &&
        error("drive-qualified frozen-input path refused")
    any(==(".."), splitpath(relative)) &&
        error("frozen-input traversal refused")
    root = realpath(_BCP_REPO)
    lexical = normpath(joinpath(root, relative))
    isfile(lexical) || error("missing frozen input: $relative")
    path = realpath(lexical)
    inside = try
        relpath(path, root)
    catch
        error("frozen-input path is on a foreign root")
    end
    isabspath(inside) && error("frozen-input path is on a foreign root")
    parts = splitpath(normpath(inside))
    !isempty(parts) && all(!=(".."), parts) ||
        error("frozen-input path escapes repository")
    path
end

length(ARGS) == 4 || error(
    "usage: bounded_candidate_parent_v1.jl PROTOCOL EXPECTED_PROTOCOL_SHA ARTIFACT RECEIPT")
const _BCP_PROTOCOL_PATH = abspath(ARGS[1])
const _BCP_EXPECTED_PROTOCOL_SHA = lowercase(ARGS[2])
_bcp_sha(_BCP_PROTOCOL_PATH) == _BCP_EXPECTED_PROTOCOL_SHA ||
    error("candidate-shard protocol hash mismatch")
const _BCP_PROTOCOL = JSON3.read(read(_BCP_PROTOCOL_PATH, String))
String(_BCP_PROTOCOL.status) == "frozen_ready" ||
    error("candidate-shard protocol is not frozen_ready")

for group in (_BCP_PROTOCOL.fusion_package_inputs,
        _BCP_PROTOCOL.production_inputs, _BCP_PROTOCOL.harness_inputs)
    for entry in group
        relative = String(entry.path)
        path = _bcp_existing_repo_file(relative)
        _bcp_sha(path) == String(entry.sha256) ||
            error("frozen input hash mismatch: $relative")
        filesize(path) == Int(entry.bytes) ||
            error("frozen input size mismatch: $relative")
    end
end

module UP2BoundedCandidateFixtureV1
using FusionConceptAI, Serialization, SHA, JSON3
import FusionConceptAI: canonical_hash, canonical_json

const REPO = normpath(joinpath(@__DIR__, "..", "..", ".."))
sha(path) = bytes2hex(SHA.sha256(read(path)))

function timed(f, label)
    started = time_ns()
    println("UP2_BOUNDED_PARENT_STAGE_BEGIN=", label); flush(stdout)
    value = f()
    println("UP2_BOUNDED_PARENT_STAGE_END=", label,
        " elapsed_seconds=", (time_ns()-started)/1e9); flush(stdout)
    value
end

# The production process constructs the same real, structurally valid DGPI
# parent used by the earlier independent test.  It is a targeted fixture and
# is not the historical W24 revised-candidate lineage.
timed("real_dgpi_parent") do
    include(joinpath(REPO, "examples",
        "runtime_v4_desc_geometry_program_interpreter.jl"))
end
const SCV = DGPI

timed("production_helper_sources") do
    for source in ("DESCRequestProviderExecutionV4.jl",
                   "CompleteMultiRegionV4.jl",
                   "MagneticEngineeringV4.jl",
                   "ExecutedVerificationUQV4.jl",
                   "RevisedCandidateV4.jl")
        Base.include(SCV, joinpath(REPO, "src", "RuntimeV4", source))
    end
    Base.include(SCV, joinpath(REPO, "src", "RuntimeV4",
        "SpatialRuntimeV4.jl"))
    Base.invokelatest(SCV.load_spatial_runtime_v4!)
end

function source_pins(entries)
    Tuple((path=String(entry.path), sha256=String(entry.sha256),
        bytes=Int(entry.bytes)) for entry in entries)
end

function parent_identity(context, physical_input)
    SCV.validate_forward_chain_context(context)
    inherited = only(filter(x -> x isa SCV.ThreeDPhysicalProviderInputV4,
        context.candidate.field_geometry_genome_ref.fields))
    canonical_hash(inherited) == canonical_hash(physical_input) ||
        error("real parent does not own the frozen physical input")
    (parent_candidate_hash=string(context.candidate_hash),
     parent_candidate_package_hash=string(canonical_hash(context.candidate)),
     parent_context_hash=string(context.context_hash),
     parent_context_canonical_hash=string(canonical_hash(context)),
     parent_subject_hash=string(context.subject.physical_subject_hash),
     physical_input_hash=string(canonical_hash(physical_input)),
     registry_hash=string(context.registry_hash),
     registry_canonical_hash=string(canonical_hash(context.registry)))
end

function write_new(path, bytes)
    ispath(path) && error("refusing to overwrite parent checkpoint output: $path")
    mkpath(dirname(path))
    open(path, "w") do io
        write(io, bytes)
    end
end

function main()
    protocol_path = abspath(ARGS[1])
    expected_protocol_sha = lowercase(ARGS[2])
    artifact_path = abspath(ARGS[3])
    receipt_path = abspath(ARGS[4])
    protocol = JSON3.read(read(protocol_path, String))
    sha(protocol_path) == expected_protocol_sha || error("protocol changed after preflight")

    identity = timed("parent_validation") do
        parent_identity(dgpi_context, dgpi_declaration)
    end
    payload = (schema="up2-04-independent-real-dgpi-parent-v1",
        base_head=String(protocol.base_head),
        parent_context=dgpi_context, physical_input=dgpi_declaration,
        identity=identity)
    timed("parent_serialization") do
        ispath(artifact_path) && error("parent artifact already exists")
        mkpath(dirname(artifact_path))
        open(artifact_path, "w") do io
            serialize(io, payload)
        end
    end

    # Same-process readback catches truncation.  A child must still perform the
    # independent fresh-process module/type round trip.
    probe = timed("same_process_readback") do
        open(deserialize, artifact_path)
    end
    probe.schema == payload.schema || error("parent checkpoint schema mismatch")
    parent_identity(probe.parent_context, probe.physical_input) == identity ||
        error("parent checkpoint identity changed on same-process readback")

    receipt = (schema="up2-04-independent-parent-checkpoint-receipt-v1",
        status="parent_constructed_same_process_readback_only",
        base_head=String(protocol.base_head),
        protocol_sha256=expected_protocol_sha,
        fixture_source_sha256=sha(@__FILE__),
        fusion_package_inputs=source_pins(protocol.fusion_package_inputs),
        production_inputs=source_pins(protocol.production_inputs),
        artifact_path=basename(artifact_path),
        artifact_sha256=sha(artifact_path),
        artifact_bytes=filesize(artifact_path), identity=identity,
        historical_w24_replay=false,
        physical_state="unknown", resolution="terminal_deferred",
        scientific_credit=0)
    write_new(receipt_path, canonical_json(receipt) * "\n")
    println("UP2_BOUNDED_PARENT_ARTIFACT_SHA256=", receipt.artifact_sha256)
    println("UP2_BOUNDED_PARENT_RECEIPT_SHA256=", sha(receipt_path))
    println("UP2_BOUNDED_PARENT_EXIT_CODE=0")
end

end # module

UP2BoundedCandidateFixtureV1.main()
