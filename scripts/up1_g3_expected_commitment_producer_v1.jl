#!/usr/bin/env julia

# Independent local producer for the UP4-R2 G3 child commitment receipt.
# This is candidate-design software evidence only. It creates no physics,
# engineering, measurement, trusted-authority, or final-candidate credit.
#
# Bounded invocation (after freezing inputs and producing the T0 receipt):
#   julia --project=<snapshot>/runtime_project <snapshot>/scripts/up1_g3_expected_commitment_producer_v1.jl
# Required environment: UP1_FROZEN_SNAPSHOT_ROOT, UP1_FROZEN_RECEIPT_PATH,
# UP1_FROZEN_RECEIPT_SHA256, UP1_T0_RECEIPT_PATH, UP1_T0_RECEIPT_SHA256,
# UP1_G3_EXPECTED_RECEIPT_OUT.

using SHA
using TOML

const _INITIAL_SNAPSHOT_ROOT = get(ENV, "UP1_FROZEN_SNAPSHOT_ROOT", "")
isempty(_INITIAL_SNAPSHOT_ROOT) && error("UP1_FROZEN_SNAPSHOT_ROOT is required")
const _EXPECTED_RUNTIME_PROJECT = normpath(joinpath(abspath(_INITIAL_SNAPSHOT_ROOT),
    "runtime_project", "Project.toml"))
Base.active_project() == _EXPECTED_RUNTIME_PROJECT ||
    error("start Julia with --project=<frozen snapshot>/runtime_project")

using JSON3

const CANDIDATE_DIR = "benchmarks/candidate_designs/local-authored-up4-g123-20260928-r2"
const CANDIDATE_ID = "local-authored-up4-g123-20260928-r2"
const CANDIDATE_REF_ID = "fusionconceptai://candidate-design/local-authored-up4-g123-20260928-r2"
const SCENARIO_ID = "scenario-local-authored-up4-g123-20260928-r2"
const CHILD_PATH = CANDIDATE_DIR * "/g3_child_design_source.jl"
const BUILDER_PATH = CANDIDATE_DIR * "/g3_source.jl"
const G1_BUILDER_PATH = CANDIDATE_DIR * "/g1_source.jl"
const G2_BUILDER_PATH = CANDIDATE_DIR * "/g2_source.jl"
const G1G2_EXPRESSION_PATH = CANDIDATE_DIR * "/native_mms_source_expressions.json"
const IDENTITY_PATH = CANDIDATE_DIR * "/identity.jl"
const DESIGN_IDENTITY_PATH = CANDIDATE_DIR * "/design_identity.json"
const SCENARIO_PATH = CANDIDATE_DIR * "/scenario.json"
const REALIZATION_SCHEMA_PATH = "src/GenomeV5/G3/G3RealizationChildEditabilityV1.jl"
const CONTROL_SCHEMA_PATH = "src/GenomeV5/G3/G3ControlChildEditabilityV1.jl"
const G1_SCHEMA_PATH = "src/GenomeV5/G1/DiffusionDeclarationV1.jl"
const G2_SCHEMA_PATH = "src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl"
const PRODUCER_PATH = "scripts/up1_g3_expected_commitment_producer_v1.jl"

_sha(raw) = bytes2hex(SHA.sha256(raw))
_hex64(s, field) = occursin(r"^[0-9a-f]{64}$", lowercase(String(s))) ||
    error("invalid SHA-256 field: " * field)
_normpath(s) = normpath(abspath(String(s)))

function _read_single_file(path::String)
    islink(path) && error("refusing symlink/reparse file: " * path)
    isfile(path) || error("missing file: " * path)
    realpath(path) == path || error("noncanonical path: " * path)
    info = stat(path)
    hasproperty(info, :nlink) && getproperty(info, :nlink) == 1 ||
        error("file must have one hard link: " * path)
    read(path)
end

function _parse_json(raw::Vector{UInt8}, label::String)
    try
        JSON3.read(String(copy(raw)))
    catch err
        error("invalid JSON in " * label * ": " * string(typeof(err)))
    end
end

function _verified_snapshot()
    root_text = get(ENV, "UP1_FROZEN_SNAPSHOT_ROOT", "")
    isempty(root_text) && error("UP1_FROZEN_SNAPSHOT_ROOT is required")
    root = _normpath(root_text)
    isdir(root) && realpath(root) == root || error("snapshot root is missing or noncanonical")
    running_script = _normpath(@__FILE__)
    frozen_script = _normpath(joinpath(root, split(PRODUCER_PATH, '/')...))
    running_script == frozen_script || error("producer must execute from its frozen snapshot copy")

    freeze_path = get(ENV, "UP1_FROZEN_RECEIPT_PATH", "")
    isempty(freeze_path) && error("UP1_FROZEN_RECEIPT_PATH is required")
    freeze_raw = _read_single_file(_normpath(freeze_path))
    freeze_sha = _sha(freeze_raw)
    expected_freeze_sha = lowercase(get(ENV, "UP1_FROZEN_RECEIPT_SHA256", ""))
    _hex64(expected_freeze_sha, "UP1_FROZEN_RECEIPT_SHA256")
    freeze_sha == expected_freeze_sha || error("freeze receipt SHA-256 mismatch")
    freeze = _parse_json(freeze_raw, "freeze receipt")
    String(freeze.schema) == "up1-candidate-freeze-receipt-v1" ||
        error("freeze receipt schema mismatch")
    String(freeze.snapshot_root) == root || error("freeze receipt snapshot root mismatch")
    String(freeze.candidate_ref) == CANDIDATE_REF_ID || error("freeze receipt candidate mismatch")
    String(freeze.scenario_id) == SCENARIO_ID || error("freeze receipt scenario mismatch")
    freeze.source_pins_unchanged === true && freeze.snapshot_copy_verified === true ||
        error("freeze receipt does not attest its local copy checks")
    freeze.formal_acceptance === false && String(freeze.physical_validation) == "not_assessed" ||
        error("freeze receipt has an unexpected credit scope")

    freeze_rows = Dict{String,NamedTuple{(:role,:bytes,:sha256),Tuple{String,Int,String}}}()
    for row in freeze.entries
        path = String(row.logical_path)
        haskey(freeze_rows, path) && error("duplicate freeze receipt path: " * path)
        digest = lowercase(String(row.sha256))
        _hex64(digest, "freeze entry " * path)
        freeze_rows[path] = (role=String(row.role), bytes=Int(row.bytes), sha256=digest)
    end
    isempty(freeze_rows) && error("freeze receipt has no source pins")

    manifest_path = joinpath(root, "manifest.toml")
    manifest_raw = _read_single_file(manifest_path)
    manifest_sha = _sha(manifest_raw)
    lowercase(String(freeze.manifest_sha256)) == manifest_sha ||
        error("freeze receipt manifest SHA-256 mismatch")
    parsed = try TOML.parse(String(copy(manifest_raw))) catch err
        error("invalid frozen manifest: " * string(typeof(err)))
    end
    Set(String.(keys(parsed))) == Set(("snapshot", "entries")) ||
        error("unexpected frozen manifest top-level fields")
    header = parsed["snapshot"]
    Set(String.(keys(header))) == Set(("schema", "snapshot_id", "candidate_ref", "scenario_id", "entry_count")) ||
        error("unexpected frozen manifest header fields")
    String(header["schema"]) == "fusion-up1-04a-vnext-frozen-source-v1" ||
        error("frozen manifest schema mismatch")
    snapshot_id = String(header["snapshot_id"])
    String(freeze.snapshot_id) == snapshot_id || error("freeze receipt snapshot id mismatch")
    String(header["candidate_ref"]) == CANDIDATE_REF_ID || error("frozen manifest candidate mismatch")
    String(header["scenario_id"]) == SCENARIO_ID || error("frozen manifest scenario mismatch")

    manifest_rows = Dict{String,NamedTuple{(:role,:bytes,:sha256),Tuple{String,Int,String}}}()
    for row in parsed["entries"]
        path = String(row["logical_path"])
        haskey(manifest_rows, path) && error("duplicate manifest path: " * path)
        digest = lowercase(String(row["sha256"]))
        _hex64(digest, "manifest entry " * path)
        manifest_rows[path] = (role=String(row["role"]), bytes=Int(row["bytes"]), sha256=digest)
    end
    Int(header["entry_count"]) == length(manifest_rows) || error("manifest entry count mismatch")
    manifest_rows == freeze_rows || error("freeze receipt pins differ from frozen manifest")

    actual = Set{String}()
    for (dir, dirs, files) in walkdir(root; follow_symlinks=false)
        for name in dirs
            p = joinpath(dir, name)
            islink(p) && error("snapshot contains symlink/reparse directory")
            isdir(p) || error("snapshot contains non-directory member")
        end
        for name in files
            p = joinpath(dir, name)
            islink(p) && error("snapshot contains symlink/reparse file")
            isfile(p) || error("snapshot contains non-file member")
            relative = replace(relpath(p, root), '\\' => '/')
            relative == "manifest.toml" && continue
            push!(actual, relative)
        end
    end
    actual == Set(keys(manifest_rows)) || error("snapshot membership differs from manifest")

    for (path, pin) in manifest_rows
        raw = _read_single_file(joinpath(root, split(path, '/')...))
        length(raw) == pin.bytes || error("frozen byte count mismatch: " * path)
        _sha(raw) == pin.sha256 || error("frozen content SHA mismatch: " * path)
    end
    for path in (CHILD_PATH, BUILDER_PATH, G1_BUILDER_PATH, G2_BUILDER_PATH,
            G1G2_EXPRESSION_PATH, IDENTITY_PATH, DESIGN_IDENTITY_PATH, SCENARIO_PATH,
            G1_SCHEMA_PATH, G2_SCHEMA_PATH, REALIZATION_SCHEMA_PATH, CONTROL_SCHEMA_PATH,
            "scripts/freeze_up1_candidate_inputs.py", PRODUCER_PATH,
            CANDIDATE_DIR * "/manifest.json", CANDIDATE_DIR * "/identity.jl")
        haskey(manifest_rows, path) || error("required producer source is not frozen: " * path)
    end
    _sha(_read_single_file(frozen_script)) == manifest_rows[PRODUCER_PATH].sha256 ||
        error("executed producer bytes differ from their frozen source pin")
    for (path, pin) in manifest_rows
        if startswith(path, "src/") && endswith(path, ".jl")
            mirror_path = "runtime_project/" * path
            haskey(manifest_rows, mirror_path) || error("runtime source mirror is missing: " * path)
            mirror_pin = manifest_rows[mirror_path]
            pin.role == "production_source" && mirror_pin.role == "runtime_source" ||
                error("runtime source mirror roles differ: " * path)
            pin.bytes == mirror_pin.bytes && pin.sha256 == mirror_pin.sha256 ||
                error("runtime source mirror content pin differs: " * path)
        elseif startswith(path, "runtime_project/src/") && endswith(path, ".jl")
            source_path = path[length("runtime_project/") + 1:end]
            haskey(manifest_rows, source_path) || error("runtime source has no parallel source pin: " * path)
            source_pin = manifest_rows[source_path]
            source_pin.role == "production_source" && pin.role == "runtime_source" ||
                error("production/runtime source roles differ: " * path)
            source_pin.bytes == pin.bytes && source_pin.sha256 == pin.sha256 ||
                error("production/runtime source content pins differ: " * path)
        end
    end
    for path in ("runtime_project/Project.toml", "runtime_project/Manifest.toml")
        haskey(manifest_rows, path) || error("frozen runtime configuration is missing: " * path)
    end
    for path in (REALIZATION_SCHEMA_PATH, CONTROL_SCHEMA_PATH)
        _sha(_read_single_file(joinpath(root, split(path, '/')...))) ==
            _sha(_read_single_file(joinpath(root, "runtime_project", split(path, '/')...))) ||
            error("runtime schema mirror differs from the source pin: " * path)
    end

    candidate_manifest = _parse_json(_read_single_file(joinpath(root, split(CANDIDATE_DIR * "/manifest.json", '/')...)),
        "candidate manifest")
    String(candidate_manifest.candidate_id) == CANDIDATE_ID || error("candidate manifest id mismatch")
    String(candidate_manifest.scenario_id) == SCENARIO_ID || error("candidate manifest scenario mismatch")
    String(candidate_manifest.design_status) == "unvalidated_design_input" ||
        error("candidate design status mismatch")
    String(candidate_manifest.candidate_ref.id) == CANDIDATE_REF_ID &&
        String(candidate_manifest.candidate_ref.version) == "v5" ||
        error("candidate manifest reference mismatch")
    candidate_rows = Dict{String,Any}()
    for row in candidate_manifest.files
        path = String(row.path)
        haskey(candidate_rows, path) && error("duplicate candidate manifest path")
        candidate_rows[path] = row
    end
    for path in ("g1_source.jl", "g2_source.jl", "native_mms_source_expressions.json",
            "g3_source.jl", "g3_child_design_source.jl", "identity.jl",
            "design_identity.json", "scenario.json")
        haskey(candidate_rows, path) || error("candidate manifest omits " * path)
        full = CANDIDATE_DIR * "/" * path
        pin = manifest_rows[full]
        row = candidate_rows[path]
        Int(row.bytes) == pin.bytes && lowercase(String(row.sha256)) == pin.sha256 ||
            error("candidate manifest pin mismatch: " * path)
    end
    (root=root, snapshot_id=snapshot_id, manifest_sha256=manifest_sha,
     freeze_receipt_sha256=freeze_sha, pins=manifest_rows)
end

function _verified_t0(snapshot)
    path = get(ENV, "UP1_T0_RECEIPT_PATH", "")
    isempty(path) && error("UP1_T0_RECEIPT_PATH is required")
    raw = _read_single_file(_normpath(path))
    sha = _sha(raw)
    expected = lowercase(get(ENV, "UP1_T0_RECEIPT_SHA256", ""))
    _hex64(expected, "UP1_T0_RECEIPT_SHA256")
    sha == expected || error("T0 receipt SHA-256 mismatch")
    t0 = _parse_json(raw, "T0 receipt")
    String(t0.schema) == "up1-up4-r2-t0-recheck-receipt-v1" || error("T0 receipt schema mismatch")
    String(t0.snapshot_id) == snapshot.snapshot_id || error("T0 receipt snapshot mismatch")
    lowercase(String(t0.manifest_sha256)) == snapshot.manifest_sha256 ||
        error("T0 receipt manifest mismatch")
    String(t0.candidate_ref.id) == CANDIDATE_REF_ID && String(t0.candidate_ref.version) == "v5" ||
        error("T0 receipt candidate mismatch")
    String(t0.status) == "valid" && String(t0.resolution) == "local_contract_ready" ||
        error("T0 receipt is not the expected local contract-ready admission")
    _hex64(String(t0.bundle_hash), "T0 bundle hash")
    String(t0.g3_declaration_ref.version) == "v1" || error("T0 G3 declaration ref version mismatch")
    startswith(String(t0.g3_declaration_ref.id), "local://up4-r2/G3/declaration/") ||
        error("T0 G3 declaration ref namespace mismatch")
    _hex64(String(t0.g3_declaration_identity_hash), "T0 G3 declaration identity")
    (raw_sha256=sha, receipt=t0)
end

function _include_frozen_schema!(G, snapshot, path)
    raw = _read_single_file(joinpath(snapshot.root, split(path, '/')...))
    Base.include_string(G, String(copy(raw)), path)
    _sha(raw)
end

function _child_projection(kind::Symbol, candidate, parent_ref, parent_hash, key,
        child_ref, contract, source_ref, source_record_hash, source_content_hash,
        identity_hash, state_hash)
    (child_kind=kind, candidate_ref=candidate,
     parent_g3_declaration_ref=parent_ref, parent_g3_declaration_hash=parent_hash,
     child_ref=child_ref, contract_ref=contract, source_record_ref=source_ref,
     source_record_hash=source_record_hash, source_content_hash=source_content_hash,
     child_identity_hash=identity_hash, state_hash=state_hash)
end

function _json_ref(ref)
    (id=ref.id, version=ref.version)
end
function _json_contract(contract)
    (uri=contract.uri, version=contract.version,
     schema_hash=contract.schema_hash.value,
     canonicalization_hash=contract.canonicalization_hash.value,
     compatibility_profile=contract.compatibility_profile)
end
function _json_child(x)
    (child_kind=String(x.child_kind), candidate_ref=_json_ref(x.candidate_ref),
     parent_g3_declaration_ref=_json_ref(x.parent_g3_declaration_ref),
     parent_g3_declaration_hash=x.parent_g3_declaration_hash.value,
     child_ref=_json_ref(x.child_ref), contract_ref=_json_contract(x.contract_ref),
     source_record_ref=_json_ref(x.source_record_ref),
     source_record_hash=x.source_record_hash.value,
     source_content_hash=x.source_content_hash.value,
     child_identity_hash=x.child_identity_hash.value, state_hash=x.state_hash.value)
end

function _derive_g1g2_local_source_binding(G, snapshot, t0)
    # Build the same candidate-owned declarations from their frozen source bytes.
    # This establishes local source/declaration identity only; each public layer
    # admission remains deferred where provider, metric, mesh or boundary authority
    # is absent, and neither layer receives physical credit here.
    G.load_genome_v5_components!()
    for (symbol, path) in ((:G1DiffusionSourcePayloadV1, G1_SCHEMA_PATH),
            (:G2MBSourceV1, G2_SCHEMA_PATH))
        if !isdefined(G, symbol)
            raw = _read_single_file(joinpath(snapshot.root, split(path, '/')...))
            _sha(raw) == snapshot.pins[path].sha256 || error("layer schema source pin mismatch: " * path)
            Base.include_string(G, String(copy(raw)), path)
        end
    end
    identity_raw = _read_single_file(joinpath(snapshot.root, split(IDENTITY_PATH, '/')...))
    design_identity = _parse_json(_read_single_file(joinpath(snapshot.root,
        split(DESIGN_IDENTITY_PATH, '/')...)), "candidate design identity")
    scenario = _parse_json(_read_single_file(joinpath(snapshot.root,
        split(SCENARIO_PATH, '/')...)), "candidate scenario")
    expression_raw = _read_single_file(joinpath(snapshot.root,
        split(G1G2_EXPRESSION_PATH, '/')...))
    g1_raw = _read_single_file(joinpath(snapshot.root, split(G1_BUILDER_PATH, '/')...))
    g2_raw = _read_single_file(joinpath(snapshot.root, split(G2_BUILDER_PATH, '/')...))
    for (path, raw) in ((IDENTITY_PATH, identity_raw),
            (DESIGN_IDENTITY_PATH, read(joinpath(snapshot.root, split(DESIGN_IDENTITY_PATH, '/')...))),
            (SCENARIO_PATH, read(joinpath(snapshot.root, split(SCENARIO_PATH, '/')...))),
            (G1G2_EXPRESSION_PATH, expression_raw), (G1_BUILDER_PATH, g1_raw),
            (G2_BUILDER_PATH, g2_raw))
        _sha(raw) == snapshot.pins[path].sha256 || error("G1/G2 frozen input pin mismatch: " * path)
    end
    String(design_identity.candidate_id) == CANDIDATE_ID &&
        String(scenario.candidate_id) == CANDIDATE_ID &&
        String(design_identity.scenario_id) == SCENARIO_ID &&
        String(scenario.scenario_id) == SCENARIO_ID ||
        error("G1/G2 design identity or scenario mismatch")
    String(design_identity.candidate_ref.id) == CANDIDATE_REF_ID &&
        String(scenario.candidate_ref.id) == CANDIDATE_REF_ID ||
        error("G1/G2 design candidate reference mismatch")

    isdefined(G, :UP4_R2_IDENTITY) && error("fresh producer module already defines UP4_R2_IDENTITY")
    Base.include_string(G, String(copy(identity_raw)), IDENTITY_PATH)
    G.UP4_R2_IDENTITY.candidate_id == CANDIDATE_ID &&
        G.UP4_R2_IDENTITY.scenario_id == SCENARIO_ID &&
        G.UP4_R2_IDENTITY.candidate_ref.id == CANDIDATE_REF_ID ||
        error("loaded candidate identity differs from T0 identity")
    isdefined(G, :up4_r2_build_g1_design) && error("fresh producer already defines G1 builder")
    isdefined(G, :up4_r2_build_g2_design) && error("fresh producer already defines G2 builder")
    Base.include_string(G, String(copy(g1_raw)), G1_BUILDER_PATH)
    Base.include_string(G, String(copy(g2_raw)), G2_BUILDER_PATH)

    expressions = _parse_json(expression_raw, "native G1/G2 expression projection")
    expressions.schema == "up4-r2-native-mms-source-expressions-v1" &&
        expressions.status == "candidate_design_projection_only" &&
        expressions.design_scope == "candidate_design_only" &&
        expressions.candidate_id == CANDIDATE_ID && expressions.scenario_id == SCENARIO_ID &&
        expressions.candidate_ref == CANDIDATE_REF_ID ||
        error("G1/G2 expression input scope or identity mismatch")
    for (field, digest_field) in ((:unknown_source_expression, :unknown_source_expression_sha256),
            (:source_expression, :source_expression_sha256))
        value = String(getproperty(expressions, field))
        expected = lowercase(String(getproperty(expressions, digest_field)))
        _hex64(expected, "G1/G2 expression " * String(digest_field))
        _sha(Vector{UInt8}(codeunits(value))) == expected ||
            error("G1/G2 source-expression bytes differ from their declared hash: " * String(field))
    end
    g1 = Base.invokelatest(G.up4_r2_build_g1_design, expressions)
    g2 = Base.invokelatest(G.up4_r2_build_g2_design, expressions)
    g1.candidate_ref == G.UP4_R2_IDENTITY.candidate_ref &&
        g2.candidate_ref == G.UP4_R2_IDENTITY.candidate_ref ||
        error("G1/G2 source builders returned a different candidate")
    g1.candidate_id == CANDIDATE_ID && g2.candidate_id == CANDIDATE_ID &&
        g1.scenario_id == SCENARIO_ID && g2.scenario_id == SCENARIO_ID ||
        error("G1/G2 source builder candidate/scenario identity mismatch")
    g1.admission.status === :terminal_deferred &&
        g1.admission.error_code === :missing_external_authority ||
        error("G1 declaration did not preserve its missing external authority state")
    g2.admission.status === :terminal_deferred ||
        error("G2 declaration did not preserve its missing authority state")

    tr = t0.receipt
    candidate = G.QualifiedRefV1(String(tr.candidate_ref.id), String(tr.candidate_ref.version))
    function layer_binding(layer, builder_path, builder_raw, declaration, source_ref,
            payload_hash, admission)
        builder_sha = _sha(builder_raw)
        declaration_json = Base.invokelatest(G.canonical_json, declaration)
        declaration_raw = Vector{UInt8}(codeunits(declaration_json))
        declaration_sha = _sha(declaration_raw)
        declaration_ref = "local://up4-r2/" * String(layer) * "/declaration/" * declaration_sha
        source_identity = Base.invokelatest(G.canonical_hash,
            (candidate_ref=candidate, layer=layer,
            source_path=builder_path, source_sha256=G.Digest256(builder_sha),
            expression_path=G1G2_EXPRESSION_PATH,
            expression_sha256=G.Digest256(_sha(expression_raw)),
            declaration_ref=declaration_ref,
            declaration_bytes_sha256=G.Digest256(declaration_sha),
            declaration_hash=declaration.declaration_hash,
            source_ref=source_ref, payload_source_hash=payload_hash))
        (source_binding="local_source_and_declaration_bound",
         candidate_ref=(id=candidate.id, version=candidate.version),
         scenario_id=SCENARIO_ID, builder_source_path=builder_path,
         builder_source_bytes=length(builder_raw), builder_source_sha256=builder_sha,
         expression_source_path=G1G2_EXPRESSION_PATH,
         expression_source_bytes=length(expression_raw),
         expression_source_sha256=_sha(expression_raw),
         source_ref=(id=source_ref.id, version=source_ref.version),
         declaration_ref=(id=declaration_ref, version="v1"),
         declaration_bytes_sha256=declaration_sha,
         payload_source_hash=payload_hash.value,
         declaration_hash=declaration.declaration_hash.value,
         local_binding_identity_hash=source_identity.value,
         admission_status=String(admission.status),
         admission_reason=String(admission.error_code), physical_authority="missing")
    end
    g1_binding = layer_binding(:G1, G1_BUILDER_PATH, g1_raw, g1.declaration,
        g1.declaration.source_ref, g1.declaration.source_hash, g1.admission)
    g2_binding = layer_binding(:G2, G2_BUILDER_PATH, g2_raw, g2.declaration,
        g2.declaration.source.source_ref, g2.declaration.source.source_hash, g2.admission)
    (G1=g1_binding, G2=g2_binding,
     schema_source_pins=(G1=(path=G1_SCHEMA_PATH, sha256=snapshot.pins[G1_SCHEMA_PATH].sha256),
                         G2=(path=G2_SCHEMA_PATH, sha256=snapshot.pins[G2_SCHEMA_PATH].sha256)),
     physical_validation=false, measurement_authority=false, engineering_validation=false)
end

function _derive(G, snapshot, t0)
    G.load_genome_v5_components!()
    realization_schema_sha = _include_frozen_schema!(G, snapshot, REALIZATION_SCHEMA_PATH)
    control_schema_sha = _include_frozen_schema!(G, snapshot, CONTROL_SCHEMA_PATH)
    # Schema inclusion defines fresh constructors and methods. Enter the
    # post-include derivation at the newest world so dispatch sees those APIs.
    Base.invokelatest(_derive_after_schema, G, snapshot, t0,
        realization_schema_sha, control_schema_sha)
end

function _derive_after_schema(G, snapshot, t0, realization_schema_sha, control_schema_sha)
    child_raw = _read_single_file(joinpath(snapshot.root, split(CHILD_PATH, '/')...))
    child_sha = _sha(child_raw)
    child_sha == snapshot.pins[CHILD_PATH].sha256 || error("G3 child source pin mismatch")
    builder_sha = snapshot.pins[BUILDER_PATH].sha256
    script_sha = snapshot.pins[PRODUCER_PATH].sha256
    g1g2_binding = _derive_g1g2_local_source_binding(G, snapshot, t0)

    isdefined(G, :up4_r2_g3_child_design_source_v1) &&
        error("fresh producer module unexpectedly already defines candidate child source")
    Base.include_string(G, String(copy(child_raw)), CHILD_PATH)
    source = Base.invokelatest(getfield(G, :up4_r2_g3_child_design_source_v1))
    source.schema == "up4-r2-g3-child-design-source-v1" || error("child source schema mismatch")
    source.design_scope == "candidate_design_only" || error("child source scope mismatch")
    source.candidate_id == CANDIDATE_ID && source.scenario_id == SCENARIO_ID ||
        error("child source candidate/scenario mismatch")
    source.source_path == CHILD_PATH || error("child source path mismatch")
    source.physical_validation === false && source.engineering_validation === false &&
        source.measurement_authority === false || error("child source contains forbidden authority")
    source.upstream_G1_authority === :missing && source.upstream_G2_authority === :missing ||
        error("child source promotes G1/G2 authority")
    occursin("no validated transfer function, plant model, or G1/G2 coupling",
        source.control_design.applicability) || error("control design exceeds its declared scope")

    tr = t0.receipt
    candidate = G.QualifiedRefV1(String(tr.candidate_ref.id), String(tr.candidate_ref.version))
    parent_ref = G.QualifiedRefV1(String(tr.g3_declaration_ref.id),
        String(tr.g3_declaration_ref.version))
    parent_hash = G.Digest256(String(tr.g3_declaration_identity_hash))
    raw_child_hash = G.Digest256(child_sha)

    # This independently assembles schema records and initial hashes from the
    # frozen raw design. It intentionally never calls up4_r2_build_g3_design,
    # the bridge state-inspection helper, or any consumer-created child state.
    realization_body = source.realization
    realization_key = G.G3RealizationChildKeyV1(candidate, parent_hash,
        G.G3_REALIZATION_CHILD_EDIT_KIND_V1, realization_body.source_id)
    realization_record = G.g3_realization_source_record_v1(candidate;
        source_uri="fusionconceptai://GenomeV5/G3/local-authored-realization-source",
        source_version="candidate-design-v1",
        schema_ref=G.QualifiedRefV1("fusionconceptai://GenomeV5/G3/realization-child-schema", "v1"),
        schema_hash=G.g3_realization_child_edit_schema_hash_v1(),
        canonicalization_ref=G.QualifiedRefV1("fusionconceptai://GenomeV5/G3/realization-child-canonicalization", "v1"),
        canonicalization_hash=G.g3_realization_child_edit_canonicalization_hash_v1(),
        profile_ref=G.QualifiedRefV1("fusionconceptai://GenomeV5/G3/realization-child-profile", "v1"),
        profile_hash=G.g3_realization_child_edit_profile_hash_v1(),
        evidence_receipt_ref=G.QualifiedRefV1(
            "fusionconceptai://candidate-design/local-authored-up4-g123-20260928-r2/g3-child-design-source", "v1"),
        evidence_receipt_hash=raw_child_hash)
    realization_payload = G.g3_realization_source_payload_v1(realization_key,
        parent_ref, realization_body, realization_record)
    realization_state = G.g3_realization_initial_state_v1(realization_key, realization_payload)
    realization_state.state_status === :present || error("independent realization source did not admit")
    realization_source_ref = G.QualifiedRefV1(realization_record.source_uri,
        realization_record.source_version)
    realization = _child_projection(:realization, candidate, parent_ref, parent_hash,
        realization_key, G.QualifiedRefV1("local://GenomeV5/G3/realization:" *
            realization_key.child_id, "v1"), realization_payload.child_contract_ref,
        realization_source_ref, realization_record.source_record_hash,
        realization_payload.source_content_hash,
        realization_payload.child_contract_identity_hash, realization_state.state_hash)

    control_body = source.control
    control_key = G.G3ControlChildKeyV1(candidate, parent_hash,
        G.G3_CONTROL_CHILD_EDIT_KIND_V1, control_body.source_id)
    control_contract = G.GenomeContractRef(G.G3_CONTROL_CHILD_EDIT_CONTRACT_URI_V1,
        G.G3_CONTROL_CHILD_EDIT_VERSION_V1, G.g3_control_child_edit_schema_hash_v1(),
        G.g3_control_child_edit_canonicalization_hash_v1(), G.G3_CONTROL_CHILD_EDIT_PROFILE_V1)
    control_path = String(source.source_path)
    slot(kind, suffix, digest) = G.G3ControlProvenanceSlotV1(kind, :present,
        G.QualifiedRefV1("fusionconceptai://GenomeV5/G3/control-child/" * suffix, "v1"),
        control_path, digest, candidate, nothing, nothing)
    control_slots = (
        slot(:payload_schema_version, "schema", G.g3_control_child_edit_schema_hash_v1()),
        slot(:canonicalization_profile_version, "canonicalization", G.g3_control_child_edit_canonicalization_hash_v1()),
        slot(:applicability_profile_version, "profile", G.g3_control_child_edit_profile_hash_v1()),
        slot(:evidence_receipt_version, "candidate-source", raw_child_hash))
    control_record_body = (record_uri=G.G3_CONTROL_CHILD_EDIT_SOURCE_URI_V1,
        record_version=G.G3_CONTROL_CHILD_EDIT_SOURCE_VERSION_V1,
        payload_schema_version=control_slots[1],
        canonicalization_profile_version=control_slots[2],
        applicability_profile_version=control_slots[3], evidence_receipt_version=control_slots[4])
    control_record = G.G3ControlSourceRecordV1(control_record_body.record_uri,
        control_record_body.record_version, control_slots[1], control_slots[2],
        control_slots[3], control_slots[4], G.canonical_hash(control_record_body))
    control_state = G.g3_control_admit_source_v1(control_key, parent_ref,
        control_body, control_contract, control_record)
    control_state.state_status === :present || error("independent control source did not admit")
    control_payload_ref = control_state.source_payload_ref
    control_source_ref = G.QualifiedRefV1(control_record.record_uri, control_record.record_version)
    control = _child_projection(:control, candidate, parent_ref, parent_hash,
        control_key, G.QualifiedRefV1("local://GenomeV5/G3/control:" * control_key.child_id, "v1"),
        control_contract, control_source_ref, control_record.source_record_hash,
        control_payload_ref.source_content_hash,
        control_payload_ref.child_contract_identity_hash, control_state.current_state_hash)

    # Hash the public bridge commitment shape from the independently rebuilt
    # projections, not from bridge or T1 consumer state objects.
    commitment_body = (domain="vnext-g3-binding-authority-commitment-v1",
        candidate_ref=candidate, bundle_hash=G.Digest256(String(tr.bundle_hash)),
        g3_declaration_ref=parent_ref, g3_declaration_identity_hash=parent_hash,
        realization=realization, control=control)
    commitment_hash = G.canonical_hash(commitment_body)

    receipt = (schema="up1-up4-r2-g3-expected-commitment-v1",
        t0_receipt_sha256=t0.raw_sha256,
        snapshot_id=snapshot.snapshot_id, manifest_sha256=snapshot.manifest_sha256,
        candidate_ref=(id=candidate.id, version=candidate.version),
        bundle_hash=String(tr.bundle_hash),
        g3_declaration_ref=(id=parent_ref.id, version=parent_ref.version),
        g3_declaration_identity_hash=parent_hash.value,
        realization=_json_child(realization), control=_json_child(control),
        commitment_hash=commitment_hash.value,
        source_pins=(freeze_receipt_sha256=snapshot.freeze_receipt_sha256,
            g3_child_design_source_path=CHILD_PATH,
            g3_child_design_source_sha256=child_sha,
            g3_builder_source_path=BUILDER_PATH,
            g3_builder_source_sha256=builder_sha,
            realization_schema_source_path=REALIZATION_SCHEMA_PATH,
            realization_schema_source_sha256=realization_schema_sha,
            control_schema_source_path=CONTROL_SCHEMA_PATH,
            control_schema_source_sha256=control_schema_sha,
            g1_builder_source_path=G1_BUILDER_PATH,
            g1_builder_source_sha256=g1g2_binding.G1.builder_source_sha256,
            g2_builder_source_path=G2_BUILDER_PATH,
            g2_builder_source_sha256=g1g2_binding.G2.builder_source_sha256,
            g1g2_expression_source_path=G1G2_EXPRESSION_PATH,
            g1g2_expression_source_sha256=g1g2_binding.G1.expression_source_sha256,
            g1_schema_source_path=G1_SCHEMA_PATH,
            g1_schema_source_sha256=g1g2_binding.schema_source_pins.G1.sha256,
            g2_schema_source_path=G2_SCHEMA_PATH,
            g2_schema_source_sha256=g1g2_binding.schema_source_pins.G2.sha256,
            producer_source_path=PRODUCER_PATH, producer_source_sha256=script_sha),
        scope=(design_scope="candidate_design_only", physical_validation=false,
            engineering_validation=false, measurement_authority=false,
            upstream_G1_authority="local_source_bound",
            upstream_G2_authority="local_source_bound",
            upstream_G1_physical_authority="missing",
            upstream_G2_physical_authority="missing",
            upstream_G1_G2_local_binding=g1g2_binding))
    (receipt=receipt, commitment_hash=commitment_hash.value)
end

function _write_new(path::String, bytes::Vector{UInt8})
    ispath(path) && error("refusing to overwrite immutable G3 expected receipt: " * path)
    parent = dirname(path)
    isdir(parent) || error("output directory must already exist: " * parent)
    lockdir = path * ".producer-lock"
    mkdir(lockdir) # exclusive creation; a competing or stale writer fails closed
    try
        ispath(path) && error("refusing to overwrite immutable G3 expected receipt: " * path)
        open(path, "w") do io
            write(io, bytes)
            flush(io)
        end
        _read_single_file(path) == bytes || error("written G3 expected receipt changed")
    finally
        rm(lockdir; force=false)
    end
    _sha(bytes)
end

function main()
    snapshot = _verified_snapshot()
    t0 = _verified_t0(snapshot)
    output_path = get(ENV, "UP1_G3_EXPECTED_RECEIPT_OUT", "")
    isempty(output_path) && error("UP1_G3_EXPECTED_RECEIPT_OUT is required")
    output = _normpath(output_path)
    relative_output = relpath(output, snapshot.root)
    first(splitpath(relative_output)) == ".." ||
        error("expected receipt output must be outside the frozen snapshot")
    ispath(output) && error("refusing to overwrite existing G3 expected receipt")
    G = Base.require(@__MODULE__, :FusionConceptAI)
    result = Base.invokelatest(_derive, G, snapshot, t0)
    bytes = Vector{UInt8}(codeunits(JSON3.write(result.receipt)))
    receipt_sha = _write_new(output, bytes)
    println("UP1_G3_EXPECTED_RECEIPT_WRITTEN\t", output, "\t", receipt_sha,
        "\tcommitment=", result.commitment_hash)
    nothing
end

main()
