# Candidate-bound fresh-process extraction of stable DESC equilibrium fields.
#
# This edge samples an already executed and replay-validated DESC HDF5 result.
# It is a field-evaluation screen only: it does not prove solver convergence,
# multi-region constitutive/interface closure, or physical validation.
using FusionConceptAI
using SHA
using LinearAlgebra
import FusionConceptAI: canonical_hash, semantic_view

const _DFP_REVISION = "runtime-v4-desc-field-provider-v2"
const _DFP_SCHEMA = "fusionconceptai:runtime-v4-desc-field-provider"
const _DFP_OUTPUT_SCHEMA = "fusionconceptai:runtime-v4-desc-field-provider-output"
const _DFP_QUANTITIES = (:B_desc_native, :B_norm, :pressure, :iota,
    :sqrt_g, :force_balance_error_desc_native)
const _DFP_PROVIDER_KEYS = ("B", "|B|", "p", "iota", "sqrt(g)", "F")
const _DFP_UNITS = ("T", "T", "Pa", "~", "m^{3}",
    raw"N \cdot m^{-3}")
mutable struct _DFPPrivateToken end
const _DFP_TOKEN = _DFPPrivateToken()

_dfp_sha256(path::AbstractString) = Digest256(bytes2hex(SHA.sha256(read(path))))

function _dfp_owner_function(value, name::Symbol)
    owner = parentmodule(typeof(value))
    isdefined(owner, name) ||
        throw(ArgumentError("authoritative $(name) is unavailable for input type"))
    getfield(owner, name)
end

struct DESCFieldSamplePointV4
    rho::Float64
    theta_rad::Float64
    zeta_rad::Float64
    point_hash::Digest256
    function DESCFieldSamplePointV4(rho, theta_rad, zeta_rad)
        values = Float64.((rho, theta_rad, zeta_rad))
        all(isfinite, values) || throw(ArgumentError("DESC sample point must be finite"))
        0.0 <= values[1] <= 1.0 || throw(ArgumentError("DESC rho must be in [0,1]"))
        0.0 <= values[2] <= 2pi ||
            throw(ArgumentError("DESC theta must be in [0,2pi] radians"))
        values[3] >= 0.0 || throw(ArgumentError("DESC zeta must be nonnegative"))
        body = (rho=values[1], theta_rad=values[2], zeta_rad=values[3])
        new(values..., canonical_hash(body))
    end
end
semantic_view(x::DESCFieldSamplePointV4) = (rho=x.rho,
    theta_rad=x.theta_rad, zeta_rad=x.zeta_rad)
function canonical_hash(x::DESCFieldSamplePointV4)
    expected = canonical_hash(semantic_view(x))
    expected == x.point_hash || throw(ArgumentError("DESC sample point hash mismatch"))
    expected
end

struct DESCFieldProviderRequestV4
    context_hash::Digest256
    candidate_hash::Digest256
    execution_request_hash::Digest256
    execution_result_hash::Digest256
    execution_receipt_hash::Digest256
    equilibrium_output_sha256::Digest256
    points::Tuple{Vararg{DESCFieldSamplePointV4}}
    quantities::Tuple{Vararg{Symbol}}
    units::Tuple{Vararg{String}}
    request_hash::Digest256
    function DESCFieldProviderRequestV4(token::_DFPPrivateToken, fields...)
        token === _DFP_TOKEN || throw(ArgumentError("private DESC field request constructor"))
        new(fields...)
    end
end
semantic_view(x::DESCFieldProviderRequestV4) = (
    context_hash=x.context_hash, candidate_hash=x.candidate_hash,
    execution_request_hash=x.execution_request_hash,
    execution_result_hash=x.execution_result_hash,
    execution_receipt_hash=x.execution_receipt_hash,
    equilibrium_output_sha256=x.equilibrium_output_sha256,
    points=x.points, quantities=x.quantities, units=x.units)
function canonical_hash(x::DESCFieldProviderRequestV4)
    !isempty(x.points) && length(x.points) <= 4096 ||
        throw(ArgumentError("DESC field request point count is outside 1:4096"))
    length(unique(canonical_hash.(x.points))) == length(x.points) ||
        throw(ArgumentError("DESC field request contains duplicate points"))
    x.quantities == _DFP_QUANTITIES && x.units == _DFP_UNITS ||
        throw(ArgumentError("DESC field quantity schema mismatch"))
    expected = canonical_hash(semantic_view(x))
    expected == x.request_hash || throw(ArgumentError("DESC field request hash mismatch"))
    expected
end

function _dfp_validate_upstream(context, execution_request, execution_result,
        execution_receipt)
    _dfp_owner_function(context, :validate_forward_chain_context)(context)
    canonical_hash(execution_request)
    canonical_hash(execution_result)
    canonical_hash(execution_receipt)
    _dfp_owner_function(execution_receipt,
        :validate_desc_provider_receipt)(execution_receipt)
    execution_request.context_hash == context.context_hash &&
        execution_request.candidate_hash == context.candidate_hash ||
        throw(ArgumentError("DESC execution request is foreign to context"))
    execution_result.context_hash == context.context_hash &&
        execution_result.candidate_hash == context.candidate_hash ||
        throw(ArgumentError("DESC execution result is foreign to context"))
    execution_result.request_hash == execution_request.request_hash ||
        throw(ArgumentError("DESC execution request/result mismatch"))
    execution_result.receipt !== nothing &&
        canonical_hash(execution_result.receipt) == canonical_hash(execution_receipt) ||
        throw(ArgumentError("DESC execution result/receipt mismatch"))
    execution_result.provider_executed && execution_result.solver_executed &&
        execution_result.result_schema_validated ||
        throw(ArgumentError("DESC upstream result was not successfully executed"))
    execution_receipt.exit_code == 0 &&
        execution_receipt.inspection_exit_code == 0 &&
        execution_receipt.output_schema_validated ||
        throw(ArgumentError("DESC upstream receipt was not successfully inspected"))
    execution_receipt.output_sha256 === nothing &&
        throw(ArgumentError("DESC upstream receipt has no output identity"))
    true
end

function make_desc_field_provider_request(context, execution_request,
        execution_result, execution_receipt,
        points::Tuple{Vararg{DESCFieldSamplePointV4}})
    _dfp_validate_upstream(context, execution_request, execution_result,
        execution_receipt)
    nfp = execution_request.runner_payload.nfp
    all(point -> point.zeta_rad <= 2pi / nfp, points) ||
        throw(ArgumentError("DESC zeta exceeds one field period"))
    body = (context_hash=context.context_hash,
        candidate_hash=context.candidate_hash,
        execution_request_hash=canonical_hash(execution_request),
        execution_result_hash=canonical_hash(execution_result),
        execution_receipt_hash=canonical_hash(execution_receipt),
        equilibrium_output_sha256=execution_receipt.output_sha256,
        points=points, quantities=_DFP_QUANTITIES, units=_DFP_UNITS)
    request = DESCFieldProviderRequestV4(_DFP_TOKEN, body...,
        canonical_hash(body))
    canonical_hash(request)
    request
end

struct DESCFieldSampleV4
    point::DESCFieldSamplePointV4
    B_desc_native_T::NTuple{3,Float64}
    B_norm_T::Float64
    pressure_Pa::Float64
    iota::Float64
    sqrt_g_m3::Float64
    force_balance_error_desc_native_N_m3::NTuple{3,Float64}
    sample_hash::Digest256
end
semantic_view(x::DESCFieldSampleV4) = (point=x.point,
    B_desc_native_T=x.B_desc_native_T, B_norm_T=x.B_norm_T,
    pressure_Pa=x.pressure_Pa, iota=x.iota, sqrt_g_m3=x.sqrt_g_m3,
    force_balance_error_desc_native_N_m3=
        x.force_balance_error_desc_native_N_m3)
function canonical_hash(x::DESCFieldSampleV4)
    canonical_hash(x.point)
    values = (x.B_desc_native_T..., x.B_norm_T, x.pressure_Pa, x.iota,
        x.sqrt_g_m3, x.force_balance_error_desc_native_N_m3...)
    all(isfinite, values) || throw(ArgumentError("DESC field sample is nonfinite"))
    x.B_norm_T >= 0 && x.pressure_Pa >= 0 && x.sqrt_g_m3 > 0 ||
        throw(ArgumentError("DESC field sample violates scalar range"))
    isapprox(norm(collect(x.B_desc_native_T)), x.B_norm_T;
        rtol=1e-10, atol=1e-12) ||
        throw(ArgumentError("DESC B vector and norm disagree"))
    expected = canonical_hash(semantic_view(x))
    expected == x.sample_hash || throw(ArgumentError("DESC field sample hash mismatch"))
    expected
end

struct DESCFieldProviderReceiptV4
    command::String
    input_path::String
    output_path::String
    adapter_path::String
    upstream_hdf5_path::String
    python_executable::String
    desc_module_path::String
    input_sha256::Digest256
    output_sha256::Union{Nothing,Digest256}
    adapter_source_sha256::Digest256
    upstream_hdf5_sha256::Digest256
    python_executable_sha256::Digest256
    desc_module_sha256::Digest256
    exit_code::Int
    stdout::String
    stderr::String
    output_schema_validated::Bool
    process_hash::Digest256
    receipt_hash::Digest256
end
semantic_view(x::DESCFieldProviderReceiptV4) = (
    command=x.command, input_path=x.input_path, output_path=x.output_path,
    adapter_path=x.adapter_path, upstream_hdf5_path=x.upstream_hdf5_path,
    python_executable=x.python_executable, desc_module_path=x.desc_module_path,
    input_sha256=x.input_sha256, output_sha256=x.output_sha256,
    adapter_source_sha256=x.adapter_source_sha256,
    upstream_hdf5_sha256=x.upstream_hdf5_sha256,
    python_executable_sha256=x.python_executable_sha256,
    desc_module_sha256=x.desc_module_sha256, exit_code=x.exit_code,
    stdout=x.stdout, stderr=x.stderr,
    output_schema_validated=x.output_schema_validated,
    process_hash=x.process_hash)
function canonical_hash(x::DESCFieldProviderReceiptV4)
    expected = canonical_hash(semantic_view(x))
    expected == x.receipt_hash || throw(ArgumentError("DESC field receipt hash mismatch"))
    expected
end

function validate_desc_field_provider_receipt(receipt::DESCFieldProviderReceiptV4)
    canonical_hash(receipt)
    checks = ((receipt.input_path, receipt.input_sha256, "input"),
        (receipt.adapter_path, receipt.adapter_source_sha256, "adapter"),
        (receipt.upstream_hdf5_path, receipt.upstream_hdf5_sha256,
            "upstream HDF5"),
        (receipt.python_executable, receipt.python_executable_sha256, "Python"),
        (receipt.desc_module_path, receipt.desc_module_sha256, "DESC module"))
    for (path, expected, label) in checks
        isfile(path) && _dfp_sha256(path) == expected ||
            throw(ArgumentError("DESC field $(label) receipt was tampered"))
    end
    if receipt.output_sha256 !== nothing
        isfile(receipt.output_path) &&
            _dfp_sha256(receipt.output_path) == receipt.output_sha256 ||
            throw(ArgumentError("DESC field output receipt was tampered"))
    end
    receipt.exit_code == 0 && receipt.output_schema_validated ||
        throw(ArgumentError("DESC field receipt does not contain a validated output"))
    true
end

function _dfp_parse_float(text, label)
    value = tryparse(Float64, text)
    value !== nothing && isfinite(value) ||
        throw(ArgumentError("DESC field output has invalid $(label)"))
    value
end

function _dfp_parse_output(path::AbstractString,
        request::DESCFieldProviderRequestV4, execution_request,
        expected_desc_version::String)
    lines = readlines(path)
    length(lines) == 7 + length(request.points) ||
        throw(ArgumentError("DESC field output line count mismatch"))
    header = split(lines[1], '\t'; keepempty=true)
    header == ["SCHEMA", _DFP_OUTPUT_SCHEMA] ||
        throw(ArgumentError("DESC field output schema mismatch"))
    version = split(lines[2], '\t'; keepempty=true)
    length(version) == 2 && version[1] == "DESC_VERSION" &&
        version[2] == expected_desc_version ||
        throw(ArgumentError("DESC field output version mismatch"))
    nfp_row = split(lines[3], '\t'; keepempty=true)
    length(nfp_row) == 2 && nfp_row[1] == "NFP" &&
        tryparse(Int, nfp_row[2]) == execution_request.runner_payload.nfp ||
        throw(ArgumentError("DESC field output NFP mismatch"))
    psi_row = split(lines[4], '\t'; keepempty=true)
    length(psi_row) == 2 && psi_row[1] == "PSI" &&
        _dfp_parse_float(psi_row[2], "Psi") ==
            execution_request.runner_payload.psi ||
        throw(ArgumentError("DESC field output Psi mismatch"))
    count_row = split(lines[5], '\t'; keepempty=true)
    length(count_row) == 2 && count_row[1] == "COUNT" &&
        tryparse(Int, count_row[2]) == length(request.points) ||
        throw(ArgumentError("DESC field output count mismatch"))
    split(lines[6], '\t'; keepempty=true) == ["UNITS"; collect(_DFP_UNITS)] ||
        throw(ArgumentError("DESC field output unit schema mismatch"))
    samples = DESCFieldSampleV4[]
    for (index, point) in enumerate(request.points)
        fields = split(lines[6 + index], '\t'; keepempty=true)
        length(fields) == 15 && fields[1] == "SAMPLE" &&
            tryparse(Int, fields[2]) == index ||
            throw(ArgumentError("DESC field output sample row mismatch"))
        values = Tuple(_dfp_parse_float(fields[i], "sample value") for i in 3:15)
        values[1:3] == (point.rho, point.theta_rad, point.zeta_rad) ||
            throw(ArgumentError("DESC field output point mismatch"))
        body = (point=point,
            B_desc_native_T=(values[4], values[5], values[6]),
            B_norm_T=values[7], pressure_Pa=values[8], iota=values[9],
            sqrt_g_m3=values[10],
            force_balance_error_desc_native_N_m3=
                (values[11], values[12], values[13]))
        sample = DESCFieldSampleV4(body..., canonical_hash(body))
        canonical_hash(sample)
        push!(samples, sample)
    end
    split(lines[end], '\t'; keepempty=true) == ["END", "1"] ||
        throw(ArgumentError("DESC field output terminator mismatch"))
    (desc_version=expected_desc_version,
     nfp=execution_request.runner_payload.nfp,
     psi=execution_request.runner_payload.psi,
     samples=Tuple(samples))
end

struct DESCFieldProviderResultV4
    status::Symbol
    context_hash::Digest256
    candidate_hash::Digest256
    field_request_hash::Digest256
    execution_request_hash::Digest256
    execution_result_hash::Digest256
    execution_receipt_hash::Digest256
    desc_version::String
    nfp::Int
    psi::Float64
    samples::Tuple{Vararg{DESCFieldSampleV4}}
    provider_selected::Bool
    provider_executed::Bool
    result_schema_validated::Bool
    solver_convergence_validated::Bool
    multiregion_closure::Bool
    physical_validation::Bool
    engineering_validation::Bool
    emits_evidence::Bool
    grants_pass::Bool
    promotion_authority::Bool
    p5_ready::Bool
    terminal_authority::Bool
    credible_physical_device_count::Int
    claim_ceiling::ClaimCeiling
    receipt::DESCFieldProviderReceiptV4
    result_hash::Digest256
end
semantic_view(x::DESCFieldProviderResultV4) = (
    revision=_DFP_REVISION, schema=_DFP_SCHEMA, status=x.status,
    context_hash=x.context_hash, candidate_hash=x.candidate_hash,
    field_request_hash=x.field_request_hash,
    execution_request_hash=x.execution_request_hash,
    execution_result_hash=x.execution_result_hash,
    execution_receipt_hash=x.execution_receipt_hash,
    desc_version=x.desc_version, nfp=x.nfp, psi=x.psi, samples=x.samples,
    provider_selected=x.provider_selected, provider_executed=x.provider_executed,
    result_schema_validated=x.result_schema_validated,
    solver_convergence_validated=x.solver_convergence_validated,
    multiregion_closure=x.multiregion_closure,
    physical_validation=x.physical_validation,
    engineering_validation=x.engineering_validation,
    emits_evidence=x.emits_evidence, grants_pass=x.grants_pass,
    promotion_authority=x.promotion_authority, p5_ready=x.p5_ready,
    terminal_authority=x.terminal_authority,
    credible_physical_device_count=x.credible_physical_device_count,
    claim_ceiling=x.claim_ceiling, receipt_hash=canonical_hash(x.receipt))
function canonical_hash(x::DESCFieldProviderResultV4)
    canonical_hash(x.receipt)
    foreach(canonical_hash, x.samples)
    x.status === :field_sampled && x.provider_selected && x.provider_executed &&
        x.result_schema_validated && !x.solver_convergence_validated &&
        !x.multiregion_closure && !x.physical_validation &&
        !x.engineering_validation && !x.emits_evidence && !x.grants_pass &&
        !x.promotion_authority && !x.p5_ready && !x.terminal_authority &&
        x.credible_physical_device_count == 0 && x.claim_ceiling == screen_only ||
        throw(ArgumentError("DESC field result authority ceiling was exceeded"))
    expected = canonical_hash(semantic_view(x))
    expected == x.result_hash || throw(ArgumentError("DESC field result hash mismatch"))
    expected
end

function _dfp_request_text(request::DESCFieldProviderRequestV4)
    canonical_hash(request)
    rows = String["SCHEMA\t$(_DFP_SCHEMA)-request",
        "COUNT\t$(length(request.points))",
        "QUANTITIES\t" * join(_DFP_PROVIDER_KEYS, '\t'),
        "UNITS\t" * join(_DFP_UNITS, '\t')]
    for (index, point) in enumerate(request.points)
        push!(rows, join(("POINT", index, repr(point.rho),
            repr(point.theta_rad), repr(point.zeta_rad)), '\t'))
    end
    push!(rows, "END\t1")
    join(rows, '\n') * "\n"
end

const _DFP_ADAPTER_SOURCE = raw"""
import math
import sys
import numpy as np
import desc
from desc.compute import data_index
from desc.grid import Grid
from desc.io import load

REQUEST_SCHEMA = "fusionconceptai:runtime-v4-desc-field-provider-request"
OUTPUT_SCHEMA = "fusionconceptai:runtime-v4-desc-field-provider-output"

def read_request(path):
    with open(path, encoding="utf-8") as stream:
        lines = [line.rstrip("\n") for line in stream]
    if len(lines) < 6 or lines[0] != "SCHEMA\t" + REQUEST_SCHEMA:
        raise ValueError("field request schema mismatch")
    count_fields = lines[1].split("\t")
    if len(count_fields) != 2 or count_fields[0] != "COUNT":
        raise ValueError("field request count row mismatch")
    count = int(count_fields[1])
    if lines[2].split("\t") != ["QUANTITIES", "B", "|B|", "p", "iota", "sqrt(g)", "F"]:
        raise ValueError("field request quantity schema mismatch")
    if lines[3].split("\t") != ["UNITS", "T", "T", "Pa", "~", "m^{3}", "N \\cdot m^{-3}"]:
        raise ValueError("field request unit schema mismatch")
    if len(lines) != count + 5 or lines[-1] != "END\t1":
        raise ValueError("field request line count mismatch")
    points = []
    for expected_index, line in enumerate(lines[4:-1], 1):
        fields = line.split("\t")
        if len(fields) != 5 or fields[0] != "POINT" or int(fields[1]) != expected_index:
            raise ValueError("field request point row mismatch")
        point = tuple(float(value) for value in fields[2:5])
        if not all(math.isfinite(value) for value in point):
            raise ValueError("field request contains nonfinite point")
        points.append(point)
    return points

def verify_metadata():
    metadata = data_index["desc.equilibrium.equilibrium.Equilibrium"]
    expected = {
        "B": ("T", 3, "rtz"),
        "|B|": ("T", 1, "rtz"),
        "p": ("Pa", 1, "r"),
        "iota": ("~", 1, "r"),
        "sqrt(g)": ("m^{3}", 1, "rtz"),
        "F": ("N \\cdot m^{-3}", 3, "rtz"),
    }
    for quantity, signature in expected.items():
        actual = metadata[quantity]
        if (actual.get("units"), actual.get("dim"), actual.get("coordinates")) != signature:
            raise ValueError("DESC quantity metadata mismatch: " + quantity)

points = read_request(sys.argv[2])
verify_metadata()
eq = load(sys.argv[1])
grid = Grid(np.asarray(points, dtype=float), coordinates="rtz",
    NFP=int(eq.NFP), sort=False)
data = eq.compute(["B", "|B|", "p", "iota", "sqrt(g)", "F"], grid=grid)
count = len(points)
vectors = {key: np.asarray(data[key], dtype=float) for key in ("B", "F")}
scalars = {key: np.asarray(data[key], dtype=float).reshape(-1)
    for key in ("|B|", "p", "iota", "sqrt(g)")}
if any(value.shape != (count, 3) for value in vectors.values()):
    raise ValueError("DESC vector output shape mismatch")
if any(value.shape != (count,) for value in scalars.values()):
    raise ValueError("DESC scalar output shape mismatch")
if not all(np.all(np.isfinite(value)) for value in (*vectors.values(), *scalars.values())):
    raise ValueError("DESC field output is nonfinite")

rows = ["SCHEMA\t" + OUTPUT_SCHEMA, "DESC_VERSION\t" + desc.__version__,
    "NFP\t" + str(int(eq.NFP)), "PSI\t" + repr(float(eq.Psi)),
    "COUNT\t" + str(count), "UNITS\t" + "\t".join(
        data_index["desc.equilibrium.equilibrium.Equilibrium"][key]["units"]
        for key in ("B", "|B|", "p", "iota", "sqrt(g)", "F"))]
for index, point in enumerate(points):
    values = (*point, *vectors["B"][index], scalars["|B|"][index],
        scalars["p"][index], scalars["iota"][index],
        scalars["sqrt(g)"][index], *vectors["F"][index])
    rows.append("\t".join(("SAMPLE", str(index + 1),
        *(repr(float(value)) for value in values))))
rows.append("END\t1")
with open(sys.argv[3], "w", encoding="utf-8", newline="\n") as stream:
    stream.write("\n".join(rows) + "\n")
print("DESC_FIELD_PROVIDER_EXECUTED=1")
print("DESC_VERSION=" + desc.__version__)
"""

function _dfp_execution_version(execution_receipt)
    matches = collect(eachmatch(r"DESC_VERSION=([^\r\n]+)",
        execution_receipt.stdout))
    length(matches) == 1 ||
        throw(ArgumentError("DESC upstream receipt has ambiguous version"))
    String(only(matches).captures[1])
end

function _dfp_process(execution_receipt, request::DESCFieldProviderRequestV4,
        run_dir; adapter_source=_DFP_ADAPTER_SOURCE)
    directory = String(run_dir)
    mkpath(directory)
    input_path = joinpath(directory, "field_sample_request.tsv")
    output_path = joinpath(directory, "field_sample_result.tsv")
    adapter_path = joinpath(directory, "desc_field_adapter.py")
    isfile(output_path) && rm(output_path; force=true)
    open(input_path, "w") do io
        write(io, _dfp_request_text(request))
    end
    open(adapter_path, "w") do io
        write(io, adapter_source)
    end
    executable = String(execution_receipt.python_executable)
    hdf5_path = String(execution_receipt.output_path)
    module_path = String(execution_receipt.desc_module_path)
    command = `$executable $adapter_path $hdf5_path $input_path $output_path`
    stdout_buffer = IOBuffer()
    stderr_buffer = IOBuffer()
    process = run(pipeline(ignorestatus(command), stdout=stdout_buffer,
        stderr=stderr_buffer))
    (command=string(command), input_path=input_path, output_path=output_path,
     adapter_path=adapter_path, upstream_hdf5_path=hdf5_path,
     python_executable=executable, desc_module_path=module_path,
     input_sha256=_dfp_sha256(input_path),
     output_sha256=isfile(output_path) ? _dfp_sha256(output_path) : nothing,
     adapter_source_sha256=_dfp_sha256(adapter_path),
     upstream_hdf5_sha256=_dfp_sha256(hdf5_path),
     python_executable_sha256=_dfp_sha256(executable),
     desc_module_sha256=_dfp_sha256(module_path), exit_code=process.exitcode,
     stdout=String(take!(stdout_buffer)), stderr=String(take!(stderr_buffer)))
end

function _dfp_receipt(process, output_schema_validated::Bool)
    process_body = merge(process,
        (output_schema_validated=output_schema_validated,))
    body = merge(process_body,
        (process_hash=canonical_hash(process_body),))
    DESCFieldProviderReceiptV4(body..., canonical_hash(body))
end

function _dfp_rebuild_request(context, execution_request, execution_result,
        execution_receipt, request::DESCFieldProviderRequestV4)
    rebuilt = make_desc_field_provider_request(context, execution_request,
        execution_result, execution_receipt, request.points)
    canonical_hash(rebuilt) == request.request_hash &&
        semantic_view(rebuilt) == semantic_view(request) ||
        throw(ArgumentError("DESC field request is not the current upstream reconstruction"))
    rebuilt
end

function validate_desc_field_provider_result(context, execution_request,
        execution_result, execution_receipt,
        request::DESCFieldProviderRequestV4,
        result::DESCFieldProviderResultV4)
    _dfp_rebuild_request(context, execution_request, execution_result,
        execution_receipt, request)
    canonical_hash(result)
    validate_desc_field_provider_receipt(result.receipt)
    parsed = _dfp_parse_output(result.receipt.output_path, request,
        execution_request, result.desc_version)
    result.context_hash == context.context_hash &&
        result.candidate_hash == context.candidate_hash ||
        throw(ArgumentError("DESC field result is foreign to context"))
    result.field_request_hash == request.request_hash &&
        result.execution_request_hash == canonical_hash(execution_request) &&
        result.execution_result_hash == canonical_hash(execution_result) &&
        result.execution_receipt_hash == canonical_hash(execution_receipt) ||
        throw(ArgumentError("DESC field result upstream identity mismatch"))
    parsed.desc_version == result.desc_version && parsed.nfp == result.nfp &&
        parsed.psi == result.psi && parsed.samples == result.samples ||
        throw(ArgumentError("DESC field result differs from replayed output"))
    result.result_hash
end

function execute_desc_field_provider(context, execution_request,
        execution_result, execution_receipt,
        request::DESCFieldProviderRequestV4; run_dir)
    _dfp_rebuild_request(context, execution_request, execution_result,
        execution_receipt, request)
    process = _dfp_process(execution_receipt, request, run_dir)
    version = _dfp_execution_version(execution_receipt)
    parsed = nothing
    parse_error = nothing
    if process.exit_code == 0 && process.output_sha256 !== nothing
        try
            parsed = _dfp_parse_output(process.output_path, request,
                execution_request, version)
        catch error
            parse_error = error
        end
    end
    validated = parsed !== nothing
    receipt = _dfp_receipt(process, validated)
    process.exit_code == 0 ||
        throw(ArgumentError("DESC field provider exited $(process.exit_code): $(process.stderr)"))
    parse_error === nothing || throw(parse_error)
    validate_desc_field_provider_receipt(receipt)
    body = (status=:field_sampled, context_hash=context.context_hash,
        candidate_hash=context.candidate_hash,
        field_request_hash=request.request_hash,
        execution_request_hash=canonical_hash(execution_request),
        execution_result_hash=canonical_hash(execution_result),
        execution_receipt_hash=canonical_hash(execution_receipt),
        desc_version=parsed.desc_version, nfp=parsed.nfp, psi=parsed.psi,
        samples=parsed.samples, provider_selected=true, provider_executed=true,
        result_schema_validated=true, solver_convergence_validated=false,
        multiregion_closure=false, physical_validation=false,
        engineering_validation=false, emits_evidence=false, grants_pass=false,
        promotion_authority=false, p5_ready=false, terminal_authority=false,
        credible_physical_device_count=0, claim_ceiling=screen_only,
        receipt=receipt)
    result = DESCFieldProviderResultV4(body...,
        canonical_hash(merge((revision=_DFP_REVISION, schema=_DFP_SCHEMA),
            Base.structdiff(body, NamedTuple{(:receipt,)}),
            (receipt_hash=canonical_hash(receipt),))))
    validate_desc_field_provider_result(context, execution_request,
        execution_result, execution_receipt, request, result)
    result
end

desc_field_provider_manifest() = (
    schema=_DFP_SCHEMA, revision=_DFP_REVISION,
    quantities=_DFP_QUANTITIES, units=_DFP_UNITS,
    coordinate_convention=:desc_native_rho_theta_zeta_and_vector_components,
    provider_selected=true, provider_executed=true,
    result_schema_validated=true, solver_convergence_validated=false,
    multiregion_closure=false, physical_validation=false,
    engineering_validation=false, emits_evidence=false, grants_pass=false,
    promotion_authority=false, p5_ready=false, terminal_authority=false,
    credible_physical_device_count=0, claim_ceiling=screen_only)
