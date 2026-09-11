# Candidate-bound basis bridge for DESC equilibrium field samples.
#
# DESC evaluates `B` and `F` at (rho, theta, zeta) points, but their three
# returned components live in the embedded orthonormal cylindrical (R, phi, Z)
# basis. This bridge requests the laboratory toroidal angle `phi` and position
# from a fresh DESC process, cross-checks the upstream values, and performs the
# explicit cylindrical-to-Cartesian rotation. It is not a region partition,
# interface trace, solver-convergence, or physical-validation result.
using FusionConceptAI
using SHA
using LinearAlgebra
import FusionConceptAI: canonical_hash, semantic_view

const _DFB_REVISION = "runtime-v4-desc-field-basis-bridge-v1"
const _DFB_SCHEMA = "fusionconceptai:runtime-v4-desc-field-basis-bridge"
const _DFB_OUTPUT_SCHEMA =
    "fusionconceptai:runtime-v4-desc-field-basis-bridge-output"
const _DFB_SOURCE_BASIS = :desc_embedded_orthonormal_cylindrical_R_phi_Z
const _DFB_TARGET_BASIS = :laboratory_cartesian_x_y_z
const _DFB_PHI_FRAME = :desc_laboratory_toroidal_angle
const _DFB_PROVIDER_KEYS = ("R", "phi", "Z", "B", "F", "sqrt(g)")
const _DFB_UNITS = ("m", "rad", "m", "T", raw"N \cdot m^{-3}", "m^{3}")
mutable struct _DFBPrivateToken end
const _DFB_TOKEN = _DFBPrivateToken()

_dfb_sha256(path::AbstractString) =
    Digest256(bytes2hex(SHA.sha256(read(path))))

function _dfb_owner_function(value, name::Symbol)
    owner = parentmodule(typeof(value))
    isdefined(owner, name) ||
        throw(ArgumentError("authoritative $(name) is unavailable for input type"))
    getfield(owner, name)
end

function _dfb_validate_upstream(context, geometry_bridge, geometry_evaluation,
        geometry_proof, execution_request, execution_result,
        execution_receipt, field_request, field_result)
    _dfb_owner_function(context, :validate_forward_chain_context)(context)
    _dfb_owner_function(geometry_proof,
        :validate_desc_geometry_compatibility)(context, geometry_bridge,
        geometry_evaluation, geometry_proof)
    geometry_proof.status === :proved &&
        geometry_proof.geometric_compatibility_proved &&
        geometry_proof.certificate !== nothing ||
        throw(ArgumentError("DESC geometry compatibility is not proved"))
    certificate = geometry_proof.certificate
    canonical_hash(certificate)
    execution_request.compatibility_certificate_hash ==
        canonical_hash(certificate) ||
        throw(ArgumentError("DESC execution request uses a foreign geometry proof"))
    _dfb_owner_function(field_result, :validate_desc_field_provider_result)(
        context, execution_request, execution_result, execution_receipt,
        field_request, field_result)
    canonical_hash(field_request)
    canonical_hash(field_result)
    field_result.context_hash == context.context_hash &&
        field_result.candidate_hash == context.candidate_hash ||
        throw(ArgumentError("DESC field result is foreign to context"))
    field_result.field_request_hash == canonical_hash(field_request) ||
        throw(ArgumentError("DESC field request/result mismatch"))
    field_result.provider_executed && field_result.result_schema_validated ||
        throw(ArgumentError("DESC field provider did not execute successfully"))
    field_result.receipt.exit_code == 0 &&
        field_result.receipt.output_schema_validated ||
        throw(ArgumentError("DESC field receipt is not successful"))
    field_result.claim_ceiling == screen_only ||
        throw(ArgumentError("DESC field result exceeds screen-only authority"))
    all(point -> point.rho > 0.0, field_request.points) ||
        throw(ArgumentError("basis bridge excludes the coordinate-singular magnetic axis"))
    true
end

struct DESCFieldBasisBridgeRequestV4
    context_hash::Digest256
    candidate_hash::Digest256
    execution_request_hash::Digest256
    execution_result_hash::Digest256
    execution_receipt_hash::Digest256
    compatibility_resolution_hash::Digest256
    compatibility_certificate_hash::Digest256
    compiled_prefix_hash::Digest256
    physical_subject_hash::Digest256
    physical_declaration_hash::Digest256
    physical_support_hash::Digest256
    coordinate_chart_hash::Digest256
    geometry_graph_binding_hash::Digest256
    coordinate_program_hash::Digest256
    metric_program_hash::Digest256
    geometry_payload_hash::Digest256
    field_request_hash::Digest256
    field_result_hash::Digest256
    field_receipt_hash::Digest256
    equilibrium_output_sha256::Digest256
    point_hashes::Tuple{Vararg{Digest256}}
    provider_quantities::Tuple{Vararg{String}}
    units::Tuple{Vararg{String}}
    source_basis::Symbol
    target_basis::Symbol
    phi_frame::Symbol
    request_hash::Digest256
    function DESCFieldBasisBridgeRequestV4(token::_DFBPrivateToken, fields...)
        token === _DFB_TOKEN ||
            throw(ArgumentError("private DESC field basis request constructor"))
        new(fields...)
    end
end

semantic_view(x::DESCFieldBasisBridgeRequestV4) = (
    context_hash=x.context_hash, candidate_hash=x.candidate_hash,
    execution_request_hash=x.execution_request_hash,
    execution_result_hash=x.execution_result_hash,
    execution_receipt_hash=x.execution_receipt_hash,
    compatibility_resolution_hash=x.compatibility_resolution_hash,
    compatibility_certificate_hash=x.compatibility_certificate_hash,
    compiled_prefix_hash=x.compiled_prefix_hash,
    physical_subject_hash=x.physical_subject_hash,
    physical_declaration_hash=x.physical_declaration_hash,
    physical_support_hash=x.physical_support_hash,
    coordinate_chart_hash=x.coordinate_chart_hash,
    geometry_graph_binding_hash=x.geometry_graph_binding_hash,
    coordinate_program_hash=x.coordinate_program_hash,
    metric_program_hash=x.metric_program_hash,
    geometry_payload_hash=x.geometry_payload_hash,
    field_request_hash=x.field_request_hash,
    field_result_hash=x.field_result_hash,
    field_receipt_hash=x.field_receipt_hash,
    equilibrium_output_sha256=x.equilibrium_output_sha256,
    point_hashes=x.point_hashes, provider_quantities=x.provider_quantities,
    units=x.units, source_basis=x.source_basis, target_basis=x.target_basis,
    phi_frame=x.phi_frame)

function canonical_hash(x::DESCFieldBasisBridgeRequestV4)
    !isempty(x.point_hashes) &&
        length(unique(x.point_hashes)) == length(x.point_hashes) ||
        throw(ArgumentError("DESC basis request points are empty or duplicated"))
    x.provider_quantities == _DFB_PROVIDER_KEYS && x.units == _DFB_UNITS ||
        throw(ArgumentError("DESC basis request quantity metadata mismatch"))
    x.source_basis === _DFB_SOURCE_BASIS &&
        x.target_basis === _DFB_TARGET_BASIS &&
        x.phi_frame === _DFB_PHI_FRAME ||
        throw(ArgumentError("DESC basis request convention mismatch"))
    expected = canonical_hash(semantic_view(x))
    expected == x.request_hash ||
        throw(ArgumentError("DESC basis request hash mismatch"))
    expected
end

function make_desc_field_basis_bridge_request(context, geometry_bridge,
        geometry_evaluation, geometry_proof, execution_request,
        execution_result, execution_receipt, field_request, field_result)
    _dfb_validate_upstream(context, geometry_bridge, geometry_evaluation,
        geometry_proof, execution_request, execution_result,
        execution_receipt, field_request, field_result)
    certificate = geometry_proof.certificate
    payload = certificate.payload
    body = (context_hash=context.context_hash,
        candidate_hash=context.candidate_hash,
        execution_request_hash=canonical_hash(execution_request),
        execution_result_hash=canonical_hash(execution_result),
        execution_receipt_hash=canonical_hash(execution_receipt),
        compatibility_resolution_hash=canonical_hash(geometry_proof),
        compatibility_certificate_hash=canonical_hash(certificate),
        compiled_prefix_hash=payload.compiled_prefix_hash,
        physical_subject_hash=payload.physical_subject_hash,
        physical_declaration_hash=payload.declaration_hash,
        physical_support_hash=payload.support_hash,
        coordinate_chart_hash=payload.chart_hash,
        geometry_graph_binding_hash=payload.graph_binding_hash,
        coordinate_program_hash=payload.coordinate_program_hash,
        metric_program_hash=payload.metric_program_hash,
        geometry_payload_hash=payload.geometry_payload_hash,
        field_request_hash=canonical_hash(field_request),
        field_result_hash=canonical_hash(field_result),
        field_receipt_hash=canonical_hash(field_result.receipt),
        equilibrium_output_sha256=execution_receipt.output_sha256,
        point_hashes=Tuple(canonical_hash(point) for point in field_request.points),
        provider_quantities=_DFB_PROVIDER_KEYS, units=_DFB_UNITS,
        source_basis=_DFB_SOURCE_BASIS, target_basis=_DFB_TARGET_BASIS,
        phi_frame=_DFB_PHI_FRAME)
    request = DESCFieldBasisBridgeRequestV4(_DFB_TOKEN, body...,
        canonical_hash(body))
    canonical_hash(request)
    request
end

struct DESCFieldCartesianSampleV4
    point_hash::Digest256
    rho::Float64
    theta_rad::Float64
    zeta_rad::Float64
    cylindrical_position_R_phi_Z::NTuple{3,Float64}
    cartesian_position_xyz_m::NTuple{3,Float64}
    B_cylindrical_R_phi_Z_T::NTuple{3,Float64}
    B_cartesian_xyz_T::NTuple{3,Float64}
    F_cylindrical_R_phi_Z_N_m3::NTuple{3,Float64}
    F_cartesian_xyz_N_m3::NTuple{3,Float64}
    sqrt_g_m3::Float64
    sample_hash::Digest256
end

semantic_view(x::DESCFieldCartesianSampleV4) = (
    point_hash=x.point_hash, rho=x.rho, theta_rad=x.theta_rad,
    zeta_rad=x.zeta_rad,
    cylindrical_position_R_phi_Z=x.cylindrical_position_R_phi_Z,
    cartesian_position_xyz_m=x.cartesian_position_xyz_m,
    B_cylindrical_R_phi_Z_T=x.B_cylindrical_R_phi_Z_T,
    B_cartesian_xyz_T=x.B_cartesian_xyz_T,
    F_cylindrical_R_phi_Z_N_m3=x.F_cylindrical_R_phi_Z_N_m3,
    F_cartesian_xyz_N_m3=x.F_cartesian_xyz_N_m3,
    sqrt_g_m3=x.sqrt_g_m3)

function canonical_hash(x::DESCFieldCartesianSampleV4)
    values = (x.rho, x.theta_rad, x.zeta_rad,
        x.cylindrical_position_R_phi_Z...,
        x.cartesian_position_xyz_m..., x.B_cylindrical_R_phi_Z_T...,
        x.B_cartesian_xyz_T..., x.F_cylindrical_R_phi_Z_N_m3...,
        x.F_cartesian_xyz_N_m3..., x.sqrt_g_m3)
    all(isfinite, values) ||
        throw(ArgumentError("DESC Cartesian sample is nonfinite"))
    R, phi, Z = x.cylindrical_position_R_phi_Z
    R >= 0.0 && x.sqrt_g_m3 > 0.0 ||
        throw(ArgumentError("DESC Cartesian sample violates scalar range"))
    position = (R * cos(phi), R * sin(phi), Z)
    all(isapprox.(x.cartesian_position_xyz_m, position;
        rtol=1e-12, atol=1e-12)) ||
        throw(ArgumentError("DESC Cartesian position transform mismatch"))
    for (source, target, label) in (
            (x.B_cylindrical_R_phi_Z_T, x.B_cartesian_xyz_T, "B"),
            (x.F_cylindrical_R_phi_Z_N_m3,
                x.F_cartesian_xyz_N_m3, "F"))
        expected = (source[1] * cos(phi) - source[2] * sin(phi),
            source[1] * sin(phi) + source[2] * cos(phi), source[3])
        all(isapprox.(target, expected; rtol=1e-12, atol=1e-12)) ||
            throw(ArgumentError("DESC $(label) basis transform mismatch"))
        isapprox(norm(collect(source)), norm(collect(target));
            rtol=1e-12, atol=1e-12) ||
            throw(ArgumentError("DESC $(label) basis transform changed norm"))
    end
    expected = canonical_hash(semantic_view(x))
    expected == x.sample_hash ||
        throw(ArgumentError("DESC Cartesian sample hash mismatch"))
    expected
end

struct DESCFieldBasisBridgeReceiptV4
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

semantic_view(x::DESCFieldBasisBridgeReceiptV4) = (
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

function _dfb_receipt_process_body(x::DESCFieldBasisBridgeReceiptV4)
    (command=x.command, input_path=x.input_path, output_path=x.output_path,
     adapter_path=x.adapter_path, upstream_hdf5_path=x.upstream_hdf5_path,
     python_executable=x.python_executable, desc_module_path=x.desc_module_path,
     input_sha256=x.input_sha256, output_sha256=x.output_sha256,
     adapter_source_sha256=x.adapter_source_sha256,
     upstream_hdf5_sha256=x.upstream_hdf5_sha256,
     python_executable_sha256=x.python_executable_sha256,
     desc_module_sha256=x.desc_module_sha256, exit_code=x.exit_code,
     stdout=x.stdout, stderr=x.stderr,
     output_schema_validated=x.output_schema_validated)
end

function canonical_hash(x::DESCFieldBasisBridgeReceiptV4)
    canonical_hash(_dfb_receipt_process_body(x)) == x.process_hash ||
        throw(ArgumentError("DESC basis process hash mismatch"))
    expected = canonical_hash(merge(_dfb_receipt_process_body(x),
        (process_hash=x.process_hash,)))
    expected == x.receipt_hash ||
        throw(ArgumentError("DESC basis receipt hash mismatch"))
    expected
end

function _dfb_validate_output_envelope(path::AbstractString)
    lines = readlines(path)
    length(lines) >= 11 ||
        throw(ArgumentError("DESC basis output envelope is too short"))
    split(lines[1], '\t'; keepempty=true) ==
        ["SCHEMA", _DFB_OUTPUT_SCHEMA] ||
        throw(ArgumentError("DESC basis output envelope schema mismatch"))
    labels = ("DESC_VERSION", "NFP", "PSI", "COUNT", "SOURCE_BASIS",
        "TARGET_BASIS", "PHI_FRAME", "UNITS")
    all(split(lines[i + 1], '\t'; keepempty=true)[1] == labels[i]
        for i in eachindex(labels)) ||
        throw(ArgumentError("DESC basis output envelope header mismatch"))
    version = split(lines[2], '\t'; keepempty=true)
    length(version) == 2 && !isempty(version[2]) ||
        throw(ArgumentError("DESC basis output envelope version mismatch"))
    nfp = split(lines[3], '\t'; keepempty=true)
    length(nfp) == 2 && something(tryparse(Int, nfp[2]), 0) > 0 ||
        throw(ArgumentError("DESC basis output envelope NFP mismatch"))
    psi = split(lines[4], '\t'; keepempty=true)
    length(psi) == 2 && tryparse(Float64, psi[2]) !== nothing &&
        isfinite(something(tryparse(Float64, psi[2]))) ||
        throw(ArgumentError("DESC basis output envelope Psi mismatch"))
    count_row = split(lines[5], '\t'; keepempty=true)
    count = length(count_row) == 2 ? tryparse(Int, count_row[2]) : nothing
    count !== nothing && count > 0 && length(lines) == 10 + count ||
        throw(ArgumentError("DESC basis output envelope count mismatch"))
    split(lines[6], '\t'; keepempty=true) ==
        ["SOURCE_BASIS", String(_DFB_SOURCE_BASIS)] &&
        split(lines[7], '\t'; keepempty=true) ==
        ["TARGET_BASIS", String(_DFB_TARGET_BASIS)] &&
        split(lines[8], '\t'; keepempty=true) ==
        ["PHI_FRAME", String(_DFB_PHI_FRAME)] &&
        split(lines[9], '\t'; keepempty=true) == ["UNITS"; collect(_DFB_UNITS)] ||
        throw(ArgumentError("DESC basis output envelope convention mismatch"))
    for index in 1:count
        fields = split(lines[9 + index], '\t'; keepempty=true)
        length(fields) == 15 && fields[1] == "SAMPLE" &&
            tryparse(Int, fields[2]) == index ||
            throw(ArgumentError("DESC basis output envelope sample mismatch"))
        values = Tuple(tryparse(Float64, fields[i]) for i in 3:15)
        all(value -> value !== nothing && isfinite(value), values) ||
            throw(ArgumentError("DESC basis output envelope is nonfinite"))
        values[1] > 0.0 && values[4] >= 0.0 && values[13] > 0.0 ||
            throw(ArgumentError("DESC basis output envelope violates range"))
    end
    split(lines[end], '\t'; keepempty=true) == ["END", "1"] ||
        throw(ArgumentError("DESC basis output envelope terminator mismatch"))
    true
end

function validate_desc_field_basis_bridge_receipt(
        receipt::DESCFieldBasisBridgeReceiptV4)
    canonical_hash(receipt)
    checks = ((receipt.input_path, receipt.input_sha256, "input"),
        (receipt.adapter_path, receipt.adapter_source_sha256, "adapter"),
        (receipt.upstream_hdf5_path, receipt.upstream_hdf5_sha256,
            "upstream HDF5"),
        (receipt.python_executable, receipt.python_executable_sha256, "Python"),
        (receipt.desc_module_path, receipt.desc_module_sha256, "DESC module"))
    for (path, expected, label) in checks
        isfile(path) && _dfb_sha256(path) == expected ||
            throw(ArgumentError("DESC basis $(label) receipt was tampered"))
    end
    if receipt.output_sha256 !== nothing
        isfile(receipt.output_path) &&
            _dfb_sha256(receipt.output_path) == receipt.output_sha256 ||
            throw(ArgumentError("DESC basis output receipt was tampered"))
    end
    receipt.exit_code == 0 && receipt.output_schema_validated ||
        throw(ArgumentError("DESC basis receipt has no validated output"))
    receipt.output_sha256 !== nothing &&
        _dfb_validate_output_envelope(receipt.output_path) ||
        throw(ArgumentError("DESC basis receipt output envelope is invalid"))
    true
end

function _dfb_request_text(request::DESCFieldBasisBridgeRequestV4,
        field_request)
    canonical_hash(request)
    rows = String["SCHEMA\t$(_DFB_SCHEMA)-request",
        "COUNT\t$(length(field_request.points))",
        "QUANTITIES\t" * join(_DFB_PROVIDER_KEYS, '\t'),
        "UNITS\t" * join(_DFB_UNITS, '\t'),
        "SOURCE_BASIS\t$(String(_DFB_SOURCE_BASIS))",
        "TARGET_BASIS\t$(String(_DFB_TARGET_BASIS))",
        "PHI_FRAME\t$(String(_DFB_PHI_FRAME))"]
    for (index, point) in enumerate(field_request.points)
        push!(rows, join(("POINT", index, repr(point.rho),
            repr(point.theta_rad), repr(point.zeta_rad)), '\t'))
    end
    push!(rows, "END\t1")
    join(rows, '\n') * "\n"
end

const _DFB_ADAPTER_SOURCE = raw"""
import math
import sys
import numpy as np
import desc
from desc.compute import data_index
from desc.grid import Grid
from desc.io import load

REQUEST_SCHEMA = "fusionconceptai:runtime-v4-desc-field-basis-bridge-request"
OUTPUT_SCHEMA = "fusionconceptai:runtime-v4-desc-field-basis-bridge-output"
SOURCE_BASIS = "desc_embedded_orthonormal_cylindrical_R_phi_Z"
TARGET_BASIS = "laboratory_cartesian_x_y_z"
PHI_FRAME = "desc_laboratory_toroidal_angle"
QUANTITIES = ["R", "phi", "Z", "B", "F", "sqrt(g)"]
UNITS = ["m", "rad", "m", "T", "N \\cdot m^{-3}", "m^{3}"]

def read_request(path):
    with open(path, encoding="utf-8") as stream:
        lines = [line.rstrip("\n") for line in stream]
    if len(lines) < 9 or lines[0] != "SCHEMA\t" + REQUEST_SCHEMA:
        raise ValueError("basis request schema mismatch")
    count_fields = lines[1].split("\t")
    if len(count_fields) != 2 or count_fields[0] != "COUNT":
        raise ValueError("basis request count row mismatch")
    count = int(count_fields[1])
    if lines[2].split("\t") != ["QUANTITIES", *QUANTITIES]:
        raise ValueError("basis request quantity schema mismatch")
    if lines[3].split("\t") != ["UNITS", *UNITS]:
        raise ValueError("basis request unit schema mismatch")
    if lines[4] != "SOURCE_BASIS\t" + SOURCE_BASIS:
        raise ValueError("basis request source basis mismatch")
    if lines[5] != "TARGET_BASIS\t" + TARGET_BASIS:
        raise ValueError("basis request target basis mismatch")
    if lines[6] != "PHI_FRAME\t" + PHI_FRAME:
        raise ValueError("basis request phi frame mismatch")
    if len(lines) != count + 8 or lines[-1] != "END\t1":
        raise ValueError("basis request line count mismatch")
    points = []
    for expected_index, line in enumerate(lines[7:-1], 1):
        fields = line.split("\t")
        if len(fields) != 5 or fields[0] != "POINT" or int(fields[1]) != expected_index:
            raise ValueError("basis request point row mismatch")
        point = tuple(float(value) for value in fields[2:5])
        if not all(math.isfinite(value) for value in point) or point[0] <= 0:
            raise ValueError("basis request contains invalid point")
        points.append(point)
    return points

def verify_metadata():
    metadata = data_index["desc.equilibrium.equilibrium.Equilibrium"]
    expected = {
        "R": ("m", 1, "rtz"),
        "phi": ("rad", 1, "rtz"),
        "Z": ("m", 1, "rtz"),
        "B": ("T", 3, "rtz"),
        "F": ("N \\cdot m^{-3}", 3, "rtz"),
        "sqrt(g)": ("m^{3}", 1, "rtz"),
    }
    for quantity, signature in expected.items():
        actual = metadata[quantity]
        if (actual.get("units"), actual.get("dim"), actual.get("coordinates")) != signature:
            raise ValueError("DESC basis quantity metadata mismatch: " + quantity)

points = read_request(sys.argv[2])
verify_metadata()
eq = load(sys.argv[1])
grid = Grid(np.asarray(points, dtype=float), coordinates="rtz",
    NFP=int(eq.NFP), sort=False)
data = eq.compute(QUANTITIES, grid=grid)
count = len(points)
scalars = {key: np.asarray(data[key], dtype=float).reshape(-1)
    for key in ("R", "phi", "Z", "sqrt(g)")}
vectors = {key: np.asarray(data[key], dtype=float) for key in ("B", "F")}
if any(value.shape != (count,) for value in scalars.values()):
    raise ValueError("DESC basis scalar output shape mismatch")
if any(value.shape != (count, 3) for value in vectors.values()):
    raise ValueError("DESC basis vector output shape mismatch")
if not all(np.all(np.isfinite(value)) for value in (*scalars.values(), *vectors.values())):
    raise ValueError("DESC basis output is nonfinite")
if np.any(scalars["R"] < 0) or np.any(scalars["sqrt(g)"] <= 0):
    raise ValueError("DESC basis output violates scalar range")

metadata = data_index["desc.equilibrium.equilibrium.Equilibrium"]
rows = ["SCHEMA\t" + OUTPUT_SCHEMA, "DESC_VERSION\t" + desc.__version__,
    "NFP\t" + str(int(eq.NFP)), "PSI\t" + repr(float(eq.Psi)),
    "COUNT\t" + str(count), "SOURCE_BASIS\t" + SOURCE_BASIS,
    "TARGET_BASIS\t" + TARGET_BASIS, "PHI_FRAME\t" + PHI_FRAME,
    "UNITS\t" + "\t".join(metadata[key]["units"] for key in QUANTITIES)]
for index, point in enumerate(points):
    values = (*point, scalars["R"][index], scalars["phi"][index],
        scalars["Z"][index], *vectors["B"][index], *vectors["F"][index],
        scalars["sqrt(g)"][index])
    rows.append("\t".join(("SAMPLE", str(index + 1),
        *(repr(float(value)) for value in values))))
rows.append("END\t1")
with open(sys.argv[3], "w", encoding="utf-8", newline="\n") as stream:
    stream.write("\n".join(rows) + "\n")
print("DESC_FIELD_BASIS_BRIDGE_EXECUTED=1")
print("DESC_VERSION=" + desc.__version__)
"""

function _dfb_parse_float(text, label)
    value = tryparse(Float64, text)
    value !== nothing && isfinite(value) ||
        throw(ArgumentError("DESC basis output has invalid $(label)"))
    value
end

_dfb_close_tuple(a, b) = length(a) == length(b) &&
    all(isapprox.(a, b; rtol=1e-12, atol=1e-12))

function _dfb_parse_output(path::AbstractString,
        request::DESCFieldBasisBridgeRequestV4, field_request, field_result,
        execution_request, expected_desc_version::String)
    length(field_result.samples) == length(field_request.points) ||
        throw(ArgumentError("DESC field request/result sample count mismatch"))
    lines = readlines(path)
    length(lines) == 10 + length(field_request.points) ||
        throw(ArgumentError("DESC basis output line count mismatch"))
    split(lines[1], '\t'; keepempty=true) ==
        ["SCHEMA", _DFB_OUTPUT_SCHEMA] ||
        throw(ArgumentError("DESC basis output schema mismatch"))
    version = split(lines[2], '\t'; keepempty=true)
    length(version) == 2 && version[1] == "DESC_VERSION" &&
        version[2] == expected_desc_version ||
        throw(ArgumentError("DESC basis output version mismatch"))
    nfp_row = split(lines[3], '\t'; keepempty=true)
    length(nfp_row) == 2 && nfp_row[1] == "NFP" &&
        tryparse(Int, nfp_row[2]) == execution_request.runner_payload.nfp ||
        throw(ArgumentError("DESC basis output NFP mismatch"))
    psi_row = split(lines[4], '\t'; keepempty=true)
    length(psi_row) == 2 && psi_row[1] == "PSI" &&
        _dfb_parse_float(psi_row[2], "Psi") ==
            execution_request.runner_payload.psi ||
        throw(ArgumentError("DESC basis output Psi mismatch"))
    count_row = split(lines[5], '\t'; keepempty=true)
    length(count_row) == 2 && count_row[1] == "COUNT" &&
        tryparse(Int, count_row[2]) == length(field_request.points) ||
        throw(ArgumentError("DESC basis output count mismatch"))
    split(lines[6], '\t'; keepempty=true) ==
        ["SOURCE_BASIS", String(_DFB_SOURCE_BASIS)] ||
        throw(ArgumentError("DESC basis output source basis mismatch"))
    split(lines[7], '\t'; keepempty=true) ==
        ["TARGET_BASIS", String(_DFB_TARGET_BASIS)] ||
        throw(ArgumentError("DESC basis output target basis mismatch"))
    split(lines[8], '\t'; keepempty=true) ==
        ["PHI_FRAME", String(_DFB_PHI_FRAME)] ||
        throw(ArgumentError("DESC basis output phi frame mismatch"))
    split(lines[9], '\t'; keepempty=true) == ["UNITS"; collect(_DFB_UNITS)] ||
        throw(ArgumentError("DESC basis output unit schema mismatch"))

    samples = DESCFieldCartesianSampleV4[]
    for (index, point) in enumerate(field_request.points)
        upstream = field_result.samples[index]
        fields = split(lines[9 + index], '\t'; keepempty=true)
        length(fields) == 15 && fields[1] == "SAMPLE" &&
            tryparse(Int, fields[2]) == index ||
            throw(ArgumentError("DESC basis output sample row mismatch"))
        values = Tuple(_dfb_parse_float(fields[i], "sample value") for i in 3:15)
        _dfb_close_tuple(values[1:3],
            (point.rho, point.theta_rad, point.zeta_rad)) ||
            throw(ArgumentError("DESC basis output point mismatch"))
        cylindrical_position = (values[4], values[5], values[6])
        B_cylindrical = (values[7], values[8], values[9])
        F_cylindrical = (values[10], values[11], values[12])
        sqrt_g = values[13]
        _dfb_close_tuple(B_cylindrical, upstream.B_desc_native_T) &&
            _dfb_close_tuple(F_cylindrical,
                upstream.force_balance_error_desc_native_N_m3) &&
            isapprox(sqrt_g, upstream.sqrt_g_m3;
                rtol=1e-12, atol=1e-12) ||
            throw(ArgumentError("fresh DESC basis output differs from field result"))
        R, phi, Z = cylindrical_position
        position = (R * cos(phi), R * sin(phi), Z)
        B_cartesian = (B_cylindrical[1] * cos(phi) -
                B_cylindrical[2] * sin(phi),
            B_cylindrical[1] * sin(phi) + B_cylindrical[2] * cos(phi),
            B_cylindrical[3])
        F_cartesian = (F_cylindrical[1] * cos(phi) -
                F_cylindrical[2] * sin(phi),
            F_cylindrical[1] * sin(phi) + F_cylindrical[2] * cos(phi),
            F_cylindrical[3])
        body = (point_hash=canonical_hash(point), rho=point.rho,
            theta_rad=point.theta_rad, zeta_rad=point.zeta_rad,
            cylindrical_position_R_phi_Z=cylindrical_position,
            cartesian_position_xyz_m=position,
            B_cylindrical_R_phi_Z_T=B_cylindrical,
            B_cartesian_xyz_T=B_cartesian,
            F_cylindrical_R_phi_Z_N_m3=F_cylindrical,
            F_cartesian_xyz_N_m3=F_cartesian, sqrt_g_m3=sqrt_g)
        sample = DESCFieldCartesianSampleV4(body..., canonical_hash(body))
        canonical_hash(sample)
        push!(samples, sample)
    end
    split(lines[end], '\t'; keepempty=true) == ["END", "1"] ||
        throw(ArgumentError("DESC basis output terminator mismatch"))
    (desc_version=expected_desc_version, samples=Tuple(samples))
end

function _dfb_process(execution_receipt,
        request::DESCFieldBasisBridgeRequestV4, field_request, run_dir;
        adapter_source=_DFB_ADAPTER_SOURCE)
    directory = String(run_dir)
    mkpath(directory)
    input_path = joinpath(directory, "field_basis_request.tsv")
    output_path = joinpath(directory, "field_basis_result.tsv")
    adapter_path = joinpath(directory, "desc_field_basis_adapter.py")
    isfile(output_path) && rm(output_path; force=true)
    open(input_path, "w") do io
        write(io, _dfb_request_text(request, field_request))
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
     input_sha256=_dfb_sha256(input_path),
     output_sha256=isfile(output_path) ? _dfb_sha256(output_path) : nothing,
     adapter_source_sha256=_dfb_sha256(adapter_path),
     upstream_hdf5_sha256=_dfb_sha256(hdf5_path),
     python_executable_sha256=_dfb_sha256(executable),
     desc_module_sha256=_dfb_sha256(module_path), exit_code=process.exitcode,
     stdout=String(take!(stdout_buffer)), stderr=String(take!(stderr_buffer)))
end

function _dfb_receipt(process, output_schema_validated::Bool)
    process_body = merge(process,
        (output_schema_validated=output_schema_validated,))
    body = merge(process_body,
        (process_hash=canonical_hash(process_body),))
    DESCFieldBasisBridgeReceiptV4(body..., canonical_hash(body))
end

function _dfb_rebuild_request(context, geometry_bridge, geometry_evaluation,
        geometry_proof, execution_request, execution_result,
        execution_receipt, field_request, field_result,
        request::DESCFieldBasisBridgeRequestV4)
    rebuilt = make_desc_field_basis_bridge_request(context, geometry_bridge,
        geometry_evaluation, geometry_proof, execution_request,
        execution_result, execution_receipt, field_request, field_result)
    canonical_hash(rebuilt) == request.request_hash &&
        semantic_view(rebuilt) == semantic_view(request) ||
        throw(ArgumentError("DESC basis request is not the current reconstruction"))
    rebuilt
end

struct DESCFieldBasisBridgeResultV4
    status::Symbol
    context_hash::Digest256
    candidate_hash::Digest256
    basis_request_hash::Digest256
    field_request_hash::Digest256
    field_result_hash::Digest256
    field_receipt_hash::Digest256
    desc_version::String
    source_basis::Symbol
    target_basis::Symbol
    phi_frame::Symbol
    samples::Tuple{Vararg{DESCFieldCartesianSampleV4}}
    provider_selected::Bool
    provider_executed::Bool
    result_schema_validated::Bool
    field_values_cross_checked::Bool
    position_basis_mapped::Bool
    vector_basis_mapped::Bool
    solver_convergence_validated::Bool
    region_partition_validated::Bool
    interface_trace_validated::Bool
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
    receipt::DESCFieldBasisBridgeReceiptV4
    result_hash::Digest256
end

semantic_view(x::DESCFieldBasisBridgeResultV4) = (
    revision=_DFB_REVISION, schema=_DFB_SCHEMA, status=x.status,
    context_hash=x.context_hash, candidate_hash=x.candidate_hash,
    basis_request_hash=x.basis_request_hash,
    field_request_hash=x.field_request_hash,
    field_result_hash=x.field_result_hash,
    field_receipt_hash=x.field_receipt_hash,
    desc_version=x.desc_version, source_basis=x.source_basis,
    target_basis=x.target_basis, phi_frame=x.phi_frame, samples=x.samples,
    provider_selected=x.provider_selected, provider_executed=x.provider_executed,
    result_schema_validated=x.result_schema_validated,
    field_values_cross_checked=x.field_values_cross_checked,
    position_basis_mapped=x.position_basis_mapped,
    vector_basis_mapped=x.vector_basis_mapped,
    solver_convergence_validated=x.solver_convergence_validated,
    region_partition_validated=x.region_partition_validated,
    interface_trace_validated=x.interface_trace_validated,
    multiregion_closure=x.multiregion_closure,
    physical_validation=x.physical_validation,
    engineering_validation=x.engineering_validation,
    emits_evidence=x.emits_evidence, grants_pass=x.grants_pass,
    promotion_authority=x.promotion_authority, p5_ready=x.p5_ready,
    terminal_authority=x.terminal_authority,
    credible_physical_device_count=x.credible_physical_device_count,
    claim_ceiling=x.claim_ceiling, receipt_hash=canonical_hash(x.receipt))

function canonical_hash(x::DESCFieldBasisBridgeResultV4)
    canonical_hash(x.receipt)
    foreach(canonical_hash, x.samples)
    x.status === :basis_mapped && x.source_basis === _DFB_SOURCE_BASIS &&
        x.target_basis === _DFB_TARGET_BASIS &&
        x.phi_frame === _DFB_PHI_FRAME && x.provider_selected &&
        x.provider_executed && x.result_schema_validated &&
        x.field_values_cross_checked && x.position_basis_mapped &&
        x.vector_basis_mapped && !x.solver_convergence_validated &&
        !x.region_partition_validated && !x.interface_trace_validated &&
        !x.multiregion_closure && !x.physical_validation &&
        !x.engineering_validation && !x.emits_evidence && !x.grants_pass &&
        !x.promotion_authority && !x.p5_ready && !x.terminal_authority &&
        x.credible_physical_device_count == 0 && x.claim_ceiling == screen_only ||
        throw(ArgumentError("DESC basis result authority ceiling was exceeded"))
    expected = canonical_hash(semantic_view(x))
    expected == x.result_hash ||
        throw(ArgumentError("DESC basis result hash mismatch"))
    expected
end

function validate_desc_field_basis_bridge_result(context, geometry_bridge,
        geometry_evaluation, geometry_proof, execution_request,
        execution_result, execution_receipt, field_request, field_result,
        request::DESCFieldBasisBridgeRequestV4,
        result::DESCFieldBasisBridgeResultV4)
    _dfb_rebuild_request(context, geometry_bridge, geometry_evaluation,
        geometry_proof, execution_request, execution_result,
        execution_receipt, field_request, field_result, request)
    canonical_hash(result)
    validate_desc_field_basis_bridge_receipt(result.receipt)
    parsed = _dfb_parse_output(result.receipt.output_path, request,
        field_request, field_result, execution_request, result.desc_version)
    result.context_hash == context.context_hash &&
        result.candidate_hash == context.candidate_hash ||
        throw(ArgumentError("DESC basis result is foreign to context"))
    result.basis_request_hash == request.request_hash &&
        result.field_request_hash == canonical_hash(field_request) &&
        result.field_result_hash == canonical_hash(field_result) &&
        result.field_receipt_hash == canonical_hash(field_result.receipt) ||
        throw(ArgumentError("DESC basis result upstream identity mismatch"))
    parsed.desc_version == result.desc_version &&
        parsed.samples == result.samples ||
        throw(ArgumentError("DESC basis result differs from replayed output"))
    result.result_hash
end

function execute_desc_field_basis_bridge(context, geometry_bridge,
        geometry_evaluation, geometry_proof, execution_request,
        execution_result, execution_receipt, field_request, field_result,
        request::DESCFieldBasisBridgeRequestV4; run_dir)
    _dfb_rebuild_request(context, geometry_bridge, geometry_evaluation,
        geometry_proof, execution_request, execution_result,
        execution_receipt, field_request, field_result, request)
    process = _dfb_process(execution_receipt, request, field_request, run_dir)
    parsed = nothing
    parse_error = nothing
    if process.exit_code == 0 && process.output_sha256 !== nothing
        try
            parsed = _dfb_parse_output(process.output_path, request,
                field_request, field_result, execution_request,
                field_result.desc_version)
        catch error
            parse_error = error
        end
    end
    receipt = _dfb_receipt(process, parsed !== nothing)
    process.exit_code == 0 ||
        throw(ArgumentError("DESC field basis bridge exited $(process.exit_code): $(process.stderr)"))
    parse_error === nothing || throw(parse_error)
    validate_desc_field_basis_bridge_receipt(receipt)
    body = (status=:basis_mapped, context_hash=context.context_hash,
        candidate_hash=context.candidate_hash,
        basis_request_hash=request.request_hash,
        field_request_hash=canonical_hash(field_request),
        field_result_hash=canonical_hash(field_result),
        field_receipt_hash=canonical_hash(field_result.receipt),
        desc_version=parsed.desc_version, source_basis=_DFB_SOURCE_BASIS,
        target_basis=_DFB_TARGET_BASIS, phi_frame=_DFB_PHI_FRAME,
        samples=parsed.samples, provider_selected=true, provider_executed=true,
        result_schema_validated=true, field_values_cross_checked=true,
        position_basis_mapped=true, vector_basis_mapped=true,
        solver_convergence_validated=false, region_partition_validated=false,
        interface_trace_validated=false, multiregion_closure=false,
        physical_validation=false, engineering_validation=false,
        emits_evidence=false, grants_pass=false, promotion_authority=false,
        p5_ready=false, terminal_authority=false,
        credible_physical_device_count=0, claim_ceiling=screen_only,
        receipt=receipt)
    result = DESCFieldBasisBridgeResultV4(body...,
        canonical_hash(merge((revision=_DFB_REVISION, schema=_DFB_SCHEMA),
            Base.structdiff(body, NamedTuple{(:receipt,)}),
            (receipt_hash=canonical_hash(receipt),))))
    validate_desc_field_basis_bridge_result(context, geometry_bridge,
        geometry_evaluation, geometry_proof, execution_request,
        execution_result, execution_receipt, field_request, field_result,
        request, result)
    result
end

desc_field_basis_bridge_manifest() = (
    schema=_DFB_SCHEMA, revision=_DFB_REVISION,
    provider_quantities=_DFB_PROVIDER_KEYS, units=_DFB_UNITS,
    source_basis=_DFB_SOURCE_BASIS, target_basis=_DFB_TARGET_BASIS,
    phi_frame=_DFB_PHI_FRAME, provider_selected=true,
    provider_executed=true, result_schema_validated=true,
    field_values_cross_checked=true, position_basis_mapped=true,
    vector_basis_mapped=true, solver_convergence_validated=false,
    region_partition_validated=false, interface_trace_validated=false,
    multiregion_closure=false, physical_validation=false,
    engineering_validation=false, emits_evidence=false, grants_pass=false,
    promotion_authority=false, p5_ready=false, terminal_authority=false,
    credible_physical_device_count=0, claim_ceiling=screen_only)
