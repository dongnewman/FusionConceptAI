# Isolated test-only continuation for revalidating an already saved MMS result.
# This entrypoint must not call a provider writer or nonlinear solver.
using SHA, JSON3, Serialization, FusionConceptAI

const ROOT = normpath(joinpath(@__DIR__, "..", "..", ".."))
const PROTOCOL = joinpath(ROOT, "docs", "implementation", "UP2-04-CLOSURE-REPAIR-PREC",
    "archive", "replay_only_continuation_r17", "replay_protocol_v17.json")
const HELPER = joinpath(ROOT, "test", "RuntimeV4", "UP2ClosureRepairV1", "manufactured_candidate_v1_tests.jl")
include(HELPER)
const M = ManufacturedCandidateV1Tests
const S = M.S

sha256_file(path) = bytes2hex(SHA.sha256(read(path)))
new_json(path, value) = (ispath(path) && error("preserve existing replay evidence: $path");
    mkpath(dirname(path)); write(path, canonical_json(value) * "\n"); path)
require_exact_file(path, expected) = (read(path, String) == expected || error("pinned wire mismatch: $path"); path)

function protocol_value(expected_sha)
    isfile(PROTOCOL) || error("frozen replay protocol missing")
    sha256_file(PROTOCOL) == expected_sha || error("replay protocol SHA mismatch")
    JSON3.read(read(PROTOCOL, String))
end

function expected_hash(protocol, key)
    hasproperty(protocol.replay_inputs, key) || error("protocol missing replay input $key")
    String(getproperty(protocol.replay_inputs, key).sha256)
end

function bind_context_from_saved_parent!(out, source_root)
    preflight = joinpath(out, "context_rebuild")
    mkpath(preflight)
    x = S.spatial_n1_manufactured_input_v1()
    d = S.spatial_n1_manufactured_declaration_v1(x)
    S.validate_spatial_manufactured_input_v1(x)
    S.validate_spatial_n1_manufactured_declaration_v1(d)

    saved_input = joinpath(source_root, "preflight", "canonical_input.json")
    saved_declaration = joinpath(source_root, "preflight", "canonical_declaration.json")
    require_exact_file(saved_input, canonical_json(x) * "\n")
    require_exact_file(saved_declaration, canonical_json(d) * "\n")

    parent_dir = joinpath(preflight, "parent")
    mkpath(parent_dir)
    parent = M.build_manufactured_parent(x, parent_dir)
    for name in ("parent_candidate.json", "parent_context.json", "parent_identity.json")
        require_exact_file(joinpath(source_root, name),
            read(joinpath(parent_dir, name), String))
    end

    child = S.build_spatial_candidate_v4(parent.context, parent.physical_input; physical_declaration=d)
    context = child.context
    S.validate_spatial_candidate_v4(context)
    S.validate_forward_chain_context(context)
    context_wire = canonical_json(context) * "\n"
    require_exact_file(joinpath(source_root, "context.json"), context_wire)
    require_exact_file(joinpath(source_root, "candidate.json"), canonical_json(context.candidate) * "\n")
    identity = (candidate_hash=context.candidate_hash, context_hash=context.context_hash,
        declaration_hash=canonical_hash(d), input_hash=canonical_hash(x), parent_hash=child.parent_hash,
        changes=child.changes, provenance=child.provenance, subject_hash=canonical_hash(context.subject),
        authority=:no_publish)
    require_exact_file(joinpath(source_root, "candidate_identity.json"), canonical_json(identity) * "\n")
    context
end

function hydration_checkpoint!(out, phase, result_hash=nothing)
    path = joinpath(out, "hydration_phases", "$(phase).json")
    new_json(path, (schema="mms-replay-only-hydration-phase-v17", classification="test_only_continuation",
        phase=String(phase), completed=true, result_hash=result_hash === nothing ? nothing : string(result_hash)))
end

function hydration_canonical_fingerprint(value)
    try
        wire = canonical_json(value)
        return (concrete_type=string(typeof(value)), canonical_sha256=bytes2hex(SHA.sha256(codeunits(wire))),
            canonical_bytes=ncodeunits(wire), error=nothing)
    catch err
        return (concrete_type=string(typeof(value)), canonical_sha256=nothing, canonical_bytes=nothing,
            error=sprint(showerror, err))
    end
end

function hydration_leaf_types!(leaves, path, value)
    if value isa NamedTuple
        for key in keys(value)
            hydration_leaf_types!(leaves, "$(path).$(key)", getproperty(value, key))
        end
    elseif value isa AbstractDict
        for key in sort!(collect(keys(value)); by=string)
            hydration_leaf_types!(leaves, "$(path).$(key)", value[key])
        end
    elseif value isa Tuple || value isa AbstractArray
        for (index, item) in enumerate(value)
            hydration_leaf_types!(leaves, "$(path)[$(index)]", item)
        end
    elseif !(value isa AbstractString) && !(value isa Symbol) && !(value isa Real) &&
            hasmethod(S.semantic_view, Tuple{typeof(value)})
        view = S.semantic_view(value)
        if view !== value && (view isa NamedTuple || view isa AbstractDict || view isa Tuple || view isa AbstractArray)
            hydration_leaf_types!(leaves, path, view)
        else
            push!(leaves, (path=path, concrete_type=string(typeof(value)),
                canonical=hydration_canonical_fingerprint(value)))
        end
    else
        push!(leaves, (path=path, concrete_type=string(typeof(value)),
            canonical=hydration_canonical_fingerprint(value)))
    end
    leaves
end

function hydration_field_observation(body, typed_body, stored_result_hash, phase, body_hash, mismatch_roots,
                                     numeric_type_differences, semantic_differences,
                                     reconstruction_paths=String[]; representation_differences=NamedTuple[])
    body_pairs = hydration_object_pairs(body)
    typed_pairs = hydration_object_pairs(typed_body)
    body_pairs === nothing && error("exact body field observation is unavailable")
    typed_pairs === nothing && error("typed parse field observation is unavailable")
    fields = NamedTuple[]
    leaves = NamedTuple[]
    for key in sort!(collect(union(Set(keys(body_pairs)), Set(keys(typed_pairs)))))
        body_has_field = haskey(body_pairs, key)
        typed_has_field = haskey(typed_pairs, key)
        body_value = body_has_field ? body_pairs[key] : nothing
        typed_value = typed_has_field ? typed_pairs[key] : nothing
        body_fingerprint = body_has_field ? hydration_canonical_fingerprint(body_value) :
            (concrete_type="missing", canonical_sha256=nothing, canonical_bytes=nothing,
             error="field is absent from exact body")
        typed_fingerprint = typed_has_field ? hydration_canonical_fingerprint(typed_value) :
            (concrete_type="missing", canonical_sha256=nothing, canonical_bytes=nothing,
             error="field is absent from typed parse")
        push!(fields, (field=String(key), body=body_fingerprint, typed=typed_fingerprint,
            canonical_equal=body_fingerprint.canonical_sha256 !== nothing &&
                body_fingerprint.canonical_sha256 == typed_fingerprint.canonical_sha256))
        if body_has_field
            try
                hydration_leaf_types!(leaves, String(key) * ".body", body_value)
            catch err
                push!(leaves, (path=String(key) * ".body", concrete_type=string(typeof(body_value)),
                    observation_error=sprint(showerror, err)))
            end
        end
        if typed_has_field
            try
                hydration_leaf_types!(leaves, String(key) * ".typed", typed_value)
            catch err
                push!(leaves, (path=String(key) * ".typed", concrete_type=string(typeof(typed_value)),
                    observation_error=sprint(showerror, err)))
            end
        end
    end
    typed_hash = hydration_canonical_fingerprint(typed_body).canonical_sha256
    (schema="mms-replay-only-hydration-observation-v2", classification="test_only_continuation",
        phase=String(phase), body_sha256=string(body_hash), typed_semantic_sha256=typed_hash,
        stored_result_hash=stored_result_hash, fields=Tuple(fields), leaf_types=Tuple(leaves),
        mismatch_roots=Tuple(String.(mismatch_roots)),
        numeric_type_differences=Tuple(numeric_type_differences),
        semantic_differences=Tuple(String.(semantic_differences)),
        representation_differences=Tuple(representation_differences),
        reconstruction_paths=Tuple(String.(reconstruction_paths)))
end

function hydration_semantic_node(value)
    if value isa Symbol
        return String(value)
    elseif value isa Enum
        return String(Symbol(value))
    elseif !(value isa AbstractString) && !(value isa Real) && !(value isa AbstractArray) &&
            !(value isa Tuple) && !(value isa NamedTuple) && !(value isa AbstractDict) &&
            hasmethod(S.semantic_view, Tuple{typeof(value)})
        view = S.semantic_view(value)
        return view === value ? value : hydration_semantic_node(view)
    end
    value
end

function hydration_object_pairs(value)
    if value isa NamedTuple
        return Dict{String,Any}(String(key) => getproperty(value, key) for key in keys(value))
    elseif value isa AbstractDict
        return Dict{String,Any}(string(key) => value[key] for key in keys(value))
    end
    nothing
end

function hydration_diff!(numeric_type_differences, semantic_differences,
                         representation_differences, parsed, exact, path)
    parsed = hydration_semantic_node(parsed)
    exact = hydration_semantic_node(exact)
    if parsed isa Real && exact isa Real && !(parsed isa Bool) && !(exact isa Bool)
        if parsed == exact
            typeof(parsed) == typeof(exact) || push!(numeric_type_differences,
                (path=path, typed_type=string(typeof(parsed)), body_type=string(typeof(exact)),
                 typed_value=parsed, body_value=exact))
            typeof(parsed) == typeof(exact) && !isequal(parsed, exact) && push!(semantic_differences, path)
        else
            push!(semantic_differences, path)
        end
        return
    end
    if parsed isa AbstractString && exact isa AbstractString
        parsed == exact || push!(semantic_differences, path)
        return
    end
    parsed_pairs = hydration_object_pairs(parsed)
    exact_pairs = hydration_object_pairs(exact)
    if parsed_pairs !== nothing && exact_pairs !== nothing
        parsed_keys = Set(keys(parsed_pairs))
        exact_keys = Set(keys(exact_pairs))
        if parsed_keys != exact_keys
            push!(semantic_differences, path * ".<keys>")
            return
        end
        if parsed isa NamedTuple && exact isa AbstractDict || parsed isa AbstractDict && exact isa NamedTuple
            push!(representation_differences, (path=path, kind="namedtuple_dict"))
        end
        parsed_order = parsed isa NamedTuple ? String.(keys(parsed)) : sort!(collect(keys(parsed_pairs)))
        exact_order = exact isa NamedTuple ? String.(keys(exact)) : sort!(collect(keys(exact_pairs)))
        parsed_order != exact_order && push!(representation_differences,
            (path=path, kind="object_key_order"))
        for key in sort!(collect(exact_keys))
            hydration_diff!(numeric_type_differences, semantic_differences, representation_differences,
                parsed_pairs[key], exact_pairs[key], "$(path).$(key)")
        end
        return
    end
    parsed_sequence = parsed isa Tuple || parsed isa AbstractArray
    exact_sequence = exact isa Tuple || exact isa AbstractArray
    if parsed_sequence && exact_sequence
        length(parsed) == length(exact) || (push!(semantic_differences, path * ".<length>"); return)
        parsed_shape = parsed isa Tuple ? (length(parsed),) : size(parsed)
        exact_shape = exact isa Tuple ? (length(exact),) : size(exact)
        parsed_shape == exact_shape || (push!(semantic_differences, path * ".<shape>"); return)
        (parsed isa Tuple) != (exact isa Tuple) && push!(representation_differences,
            (path=path, kind="tuple_array"))
        for index in 1:length(parsed)
            hydration_diff!(numeric_type_differences, semantic_differences, representation_differences,
                parsed[index], exact[index], "$(path)[$(index)]")
        end
        return
    end
    if canonical_json(parsed) != canonical_json(exact)
        push!(semantic_differences, path)
    end
end

function hydration_path_in_roots(path, roots)
    any(root -> path == root || startswith(path, root * ".") || startswith(path, root * "["), roots)
end

const HYDRATION_SYMBOL_TOKENS = Dict{String,Set{String}}(
    "cases[#].level" => Set(["coarse", "fine"]),
    "cases[#].status" => Set(["fail", "unsupported", "converged"]),
    "cases[#].stopping_reason" => Set(["stationary_nonzero_residual", "full_discrete_residual_converged",
        "wall_time_budget", "bounded_step_wall_time_budget", "bounded_step_program_exception",
        "bounded_step_numerical_failure", "bounded_step_no_representable_descent", "floating_point_no_progress",
        "feasible_line_search_failed"]),
    "cases[#].engineering_input.status" => Set(["fail", "unsupported", "converged"]),
    "cases[#].diagnostics.missing_closure" => Set(["pressure_current_topology_uniqueness_and_exterior_currents"]),
    "cases[#].diagnostics.numerical_status" => Set(["full_discrete_residual_converged", "program_exception", "resource_limit", "numerical_fail"]),
    "cases[#].diagnostics.physical_convergence" => Set(["not_certified"]),
    "cases[#].diagnostics.physical_validation" => Set(["unsupported"]),
    "cases[#].diagnostics.manufactured_loads.quadrature" => Set(["declared_GL3_observation_not_error_bound"]),
    "cases[#].diagnostics.manufactured_loads.external_closure_status" => Set(["terminal_deferred"]),
    "cases[#].diagnostics.manufactured_loads.physical_validation" => Set(["unsupported"]),
    "cases[#].diagnostics.manufactured_loads.authority" => Set(["no_publish"]),
    "cases[#].diagnostics.current_closure.outer_Bout" => Set(["unknown"]),
    "cases[#].diagnostics.current_closure.outer_K" => Set(["unknown"]),
    "cases[#].diagnostics.current_closure.external_current_closure" => Set(["unsupported"]),
    "cases[#].diagnostics.current_closure.provider_geometry_enclosure.method" => Set(["analytic_circular_R0_plus_minor_radius_outward_float"]),
    "cases[#].diagnostics.current_closure.provider_geometry_enclosure.applicability" => Set(["canonical_manufactured_circle_only"]),
    "cases[#].diagnostics.current_closure.provider_geometry_enclosure.desc_spectral_enclosure" => Set(["not_executed"]),
    "cases[#].engineering_input.current_closure.outer_Bout" => Set(["unknown"]),
    "cases[#].engineering_input.current_closure.outer_K" => Set(["unknown"]),
    "cases[#].engineering_input.current_closure.external_current_closure" => Set(["unsupported"]),
    "cases[#].engineering_input.current_closure.provider_geometry_enclosure.method" => Set(["analytic_circular_R0_plus_minor_radius_outward_float"]),
    "cases[#].engineering_input.current_closure.provider_geometry_enclosure.applicability" => Set(["canonical_manufactured_circle_only"]),
    "cases[#].engineering_input.current_closure.provider_geometry_enclosure.desc_spectral_enclosure" => Set(["not_executed"]),
    "cases[#].diagnostics.attempts[#].direction" => Set(["lower_bounded_sparse_QR_active_set_v1", "unavailable"]),
    "cases[#].diagnostics.last_attempt.direction" => Set(["lower_bounded_sparse_QR_active_set_v1", "unavailable"]),
    "cases[#].diagnostics.attempts[#].progress_classification" => Set(["accepted_strict_decrease", "floating_point_no_progress", "line_search_rejected"]),
    "cases[#].diagnostics.last_attempt.progress_classification" => Set(["accepted_strict_decrease", "floating_point_no_progress", "line_search_rejected"]),
    "cases[#].diagnostics.attempts[#].bounded_linear_step.classification" => Set(["linear_model_only", "program_exception", "audit_program_exception", "kkt_converged", "independent_kkt_failed", "invalid_missing_result", "numerical_fail"]),
    "cases[#].diagnostics.last_attempt.bounded_linear_step.classification" => Set(["linear_model_only", "program_exception", "audit_program_exception", "kkt_converged", "independent_kkt_failed", "invalid_missing_result", "numerical_fail"]),
    "cases[#].diagnostics.attempts[#].bounded_linear_step.physical_convergence" => Set(["not_assessed"]),
    "cases[#].diagnostics.last_attempt.bounded_linear_step.physical_convergence" => Set(["not_assessed"]),
    "cases[#].diagnostics.attempts[#].bounded_linear_step.status" => Set(["kkt_converged", "invalid_nonfinite_inputs", "linear_solve_failed"]),
    "cases[#].diagnostics.last_attempt.bounded_linear_step.status" => Set(["kkt_converged", "invalid_nonfinite_inputs", "linear_solve_failed"]),
    "cases[#].diagnostics.rank_diagnostics.method" => Set(["unregularized_sparse_QR_diagonal_rank_estimate"]),
    "cases[#].diagnostics.rank_diagnostics.continuum_uniqueness" => Set(["unsupported"]),
    "cases[#].diagnostics.rank_diagnostics.physical_closure" => Set(["pressure_current_topology_not_fixed"]),
    "cases[#].diagnostics.attempts[#].linear_rank_diagnostics.method" => Set(["not_executed", "sparse_QR_failed"]),
    "cases[#].diagnostics.attempts[#].linear_rank_diagnostics.continuum_uniqueness" => Set(["unsupported"]),
    "cases[#].diagnostics.last_attempt.linear_rank_diagnostics.method" => Set(["not_executed", "sparse_QR_failed"]),
    "cases[#].diagnostics.last_attempt.linear_rank_diagnostics.continuum_uniqueness" => Set(["unsupported"]),
    "execution.desc_execution" => Set(["not_executed"]),
    "execution.engineering_execution" => Set(["not_executed"]),
    "execution.whole_device_validation" => Set(["unsupported"]),
    "execution.physical_validation" => Set(["unsupported"]),
    "execution.authority" => Set(["no_publish"]),
    "execution.scope" => Set(["manufactured_numerical_only"]),
    "result.status" => Set(["fail", "unsupported"]),
    "result.physical_validation" => Set(["unsupported"]),
    "execution.provider_receipt.desc_execution" => Set(["not_executed"]),
    "execution.provider_receipt.physical_validation" => Set(["unsupported"]),
    "execution.provider_receipt.authority" => Set(["no_publish"]),
    "execution.provider_receipt.enclosure.method" => Set(["analytic_circular_R0_plus_minor_radius_outward_float"]),
    "execution.provider_receipt.enclosure.applicability" => Set(["canonical_manufactured_circle_only"]),
    "execution.provider_receipt.enclosure.desc_spectral_enclosure" => Set(["not_executed"]),
)

hydration_normalized_path(path) = replace(path, r"\[\d+\]" => "[#]")

function hydration_digest(value, path)
    hasproperty(value, :value) || error("saved digest wrapper is missing value at $(path)")
    raw = getproperty(value, :value)
    raw isa AbstractString && occursin(r"^[0-9a-f]{64}$", raw) || error("saved digest token is invalid at $(path)")
    S.Digest256(String(raw))
end

function hydration_artifact(value, path)
    Set(String.(keys(value))) == Set(("path", "row_count", "schema", "sha256")) ||
        error("saved artifact field set changed at $(path)")
    value.path isa AbstractString && value.schema isa AbstractString || error("saved artifact text field changed at $(path)")
    value.row_count isa Integer && !(value.row_count isa Bool) || error("saved artifact row_count token changed at $(path)")
    sha = value.sha256
    sha isa NamedTuple && keys(sha) == (:value,) || error("saved artifact digest representation changed at $(path)")
    S.SpatialArtifactV4(String(value.path), hydration_digest(sha, path * ".sha256"),
        String(value.schema), Int(value.row_count))
end

function hydration_symbol(path, value)
    normalized = hydration_normalized_path(path)
    allowed = get(HYDRATION_SYMBOL_TOKENS, normalized, nothing)
    allowed === nothing && return value
    value isa AbstractString && String(value) in allowed || error("saved symbol token is not in the schema allowlist at $(path)")
    Symbol(String(value))
end

function hydration_restore_semantic_tree(value, path, declaration)
    if value isa NamedTuple
        names = keys(value)
        keyset = Set(String.(names))
        if keyset == Set(("path", "row_count", "schema", "sha256"))
            return hydration_artifact(value, path)
        end
        if names == (:value,) && occursin(r"(?:^|\.)(?:[A-Za-z0-9_]*_hash|sha256)$", path)
            return hydration_digest(value, path)
        end
        if endswith(path, ".numerical_algorithm") || occursin(".bounded_linear_step.algorithm", path)
            expected = S._smr_bounded_identity_v1()
            canonical_json(expected) == canonical_json(value) || error("saved bounded algorithm identity differs from loaded V4 source at $(path)")
            return expected
        elseif endswith(path, ".manufactured_loads.provider")
            expected = S.spatial_manufactured_provider_identity_v1()
            canonical_json(expected) == canonical_json(value) || error("saved manufactured provider identity differs from loaded V4 source")
            return expected
        elseif endswith(path, ".provider_geometry_enclosure")
            declaration === nothing && error("provider enclosure reconstruction has no rebuilt declaration")
            expected = S._smm_enclosure_v1(declaration.source.input)
            canonical_json(expected) == canonical_json(value) || error("saved provider enclosure differs from rebuilt input")
            return expected
        end
        restored = Tuple(hydration_restore_semantic_tree(getproperty(value, name), "$(path).$(name)", declaration)
            for name in names)
        return NamedTuple{names}(restored)
    elseif value isa Tuple
        return Tuple(hydration_restore_semantic_tree(item, "$(path)[$(index)]", declaration)
            for (index, item) in enumerate(value))
    elseif value isa AbstractString
        return hydration_symbol(path, value)
    end
    value
end

function hydration_restore_manufactured_input(value, template::S.SpatialManufacturedNumericalInputV1, path)
    value isa NamedTuple || error("saved manufactured input is not a named tuple at $(path)")
    fields = fieldnames(S.SpatialManufacturedNumericalInputV1)
    Set(String.(keys(value))) == Set(String.(fields)) ||
        error("saved manufactured-input field set differs from V4 input schema at $(path)")
    values = Tuple(hydration_restore_from_template(getproperty(value, field), getfield(template, field),
        "$(path).$(field)") for field in fields)
    restored = S.SpatialManufacturedNumericalInputV1(values...)
    S.validate_spatial_manufactured_input_v1(restored) === true ||
        error("rebuilt V4 manufactured input failed its frozen validator at $(path)")
    canonical_json(S.semantic_view(restored)) == canonical_json(value) ||
        error("rebuilt V4 manufactured input differs from exact saved body at $(path)")
    restored
end

function hydration_restore_from_template(value, template, path)
    if template isa S.SpatialManufacturedNumericalInputV1
        return hydration_restore_manufactured_input(value, template, path)
    elseif template isa Digest256
        restored = hydration_digest(value, path)
        restored == template || error("saved digest differs from rebuilt V4 value at $(path)")
        return restored
    elseif template isa NamedTuple
        value isa NamedTuple || error("saved named-tuple token changed at $(path)")
        Set(String.(keys(value))) == Set(String.(keys(template))) ||
            error("saved named-tuple field set differs from rebuilt V4 value at $(path)")
        fields = keys(template)
        return NamedTuple{fields}(Tuple(hydration_restore_from_template(
            getproperty(value, field), getproperty(template, field), "$(path).$(field)") for field in fields))
    elseif template isa Tuple
        value isa Tuple && length(value) == length(template) ||
            error("saved tuple shape differs from rebuilt V4 value at $(path)")
        return Tuple(hydration_restore_from_template(value[index], template[index], "$(path)[$(index)]")
            for index in eachindex(template))
    elseif template isa Symbol
        value isa AbstractString && String(value) == String(template) ||
            error("saved symbol token differs from rebuilt V4 value at $(path)")
        return template
    elseif template isa Bool
        value isa Bool && value == template || error("saved Boolean differs from rebuilt V4 value at $(path)")
        return value
    elseif template isa Integer
        value isa Integer && !(value isa Bool) && typeof(value) == typeof(template) && value == template ||
            error("saved integer token/type differs from rebuilt V4 value at $(path)")
        return value
    elseif template isa AbstractFloat
        value isa AbstractFloat && typeof(value) == typeof(template) && isequal(value, template) ||
            error("saved floating token/type differs from rebuilt V4 value at $(path)")
        return value
    elseif template isa AbstractString
        value isa AbstractString && String(value) == String(template) ||
            error("saved text differs from rebuilt V4 value at $(path)")
        return String(value)
    elseif template === nothing
        value === nothing || error("saved null differs from rebuilt V4 value at $(path)")
        return nothing
    end
    error("unsupported rebuilt V4 declaration schema node at $(path): $(typeof(template))")
end

function hydration_declaration_from_body(body_declaration, expected_declaration)
    names = fieldnames(S.SpatialMultiRegionDeclarationV4)
    Set(String.(keys(body_declaration))) == Set(String.(names)) ||
        error("saved declaration field set differs from SpatialMultiRegionDeclarationV4")
    values = map(names) do field
        hydration_restore_from_template(getproperty(body_declaration, field),
            getfield(expected_declaration, field), "declaration.$(field)")
    end
    declaration = S.SpatialMultiRegionDeclarationV4(values...)
    canonical_json(S.semantic_view(declaration)) == canonical_json(body_declaration) ||
        error("schema-directed declaration does not round-trip to exact saved body")
    declaration
end

function hydration_case_from_body(body_case, index, declaration)
    path = "cases[$(index)]"
    Set(String.(keys(body_case))) == Set(String.(fieldnames(S.SpatialMultiRegionCaseV4)[1:end-1])) ||
        error("saved case field set differs from SpatialMultiRegionCaseV4 at $(path)")
    semantic_names = fieldnames(S.SpatialMultiRegionCaseV4)[1:end-1]
    case_values = map(semantic_names) do key
        field_path = "$(path).$(key)"
        raw = getproperty(body_case, key)
        if key == :case_id
            raw isa AbstractString || error("saved case_id token changed at $(field_path)")
            index <= length(declaration.cases) || error("saved case_id has no matching declaration at $(field_path)")
            expected_case_id = declaration.cases[index].case_id
            raw == expected_case_id || error("saved case_id differs from exact declaration at $(field_path)")
            return String(raw)
        elseif key in (:candidate_hash, :context_hash, :state_hash)
            return hydration_digest(raw, field_path)
        elseif key == :level || key == :status || key == :stopping_reason
            return hydration_symbol(field_path, raw)
        elseif key == :nfp || key == :solver_exit_code
            raw isa Integer && !(raw isa Bool) || error("saved integer token changed at $(field_path)")
            return Int(raw)
        elseif key == :flux_Wb
            raw isa Float64 || error("saved Float64 token changed at $(field_path)")
            return raw
        elseif key == :initial_state || key == :final_state
            raw isa Tuple && all(item -> item isa Float64, raw) || error("saved state tuple/Float64 tokens changed at $(field_path)")
            return raw
        elseif key == :executed
            raw isa Bool || error("saved Boolean token changed at $(field_path)")
            return raw
        elseif key == :iterations || key == :raw_artifacts || key == :artifacts || key == :diagnostics
            return hydration_restore_semantic_tree(raw, field_path, declaration)
        elseif key == :engineering_input
            return hydration_current_input(raw, field_path, declaration)
        end
        error("unsupported SpatialMultiRegionCaseV4 field at $(field_path)")
    end
    case_body = NamedTuple{semantic_names}(Tuple(case_values))
    case_hash = S.canonical_hash(case_body)
    S.SpatialMultiRegionCaseV4(case_values..., case_hash)
end

function hydration_current_input(value, path, declaration)
    names = fieldnames(S.SpatialCurrentInputV4)
    Set(String.(keys(value))) == Set(String.(names)) || error("saved current-input field set changed at $(path)")
    d(key) = hydration_digest(getproperty(value, key), "$(path).$(key)")
    art(key) = hydration_artifact(getproperty(value, key), "$(path).$(key)")
    status = hydration_symbol(path * ".status", value.status)
    value.solver_exit_code isa Integer && !(value.solver_exit_code isa Bool) || error("saved current-input exit token changed")
    value.upstream_valid isa Bool || error("saved current-input upstream flag changed")
    S.SpatialCurrentInputV4(d(:candidate_hash), d(:context_hash), String(value.case_id), d(:state_hash),
        d(:geometry_hash), art(:volume), art(:interfaces), art(:exterior),
        hydration_restore_semantic_tree(value.current_closure, path * ".current_closure", declaration),
        status, Int(value.solver_exit_code), value.upstream_valid, String(value.scope))
end

function hydration_geometry_receipt(value, path, declaration)
    names = fieldnames(S.SpatialManufacturedGeometryReceiptV1)
    Set(String.(keys(value))) == Set(String.(names)) || error("saved geometry-receipt field set changed")
    actual_provider = S.spatial_manufactured_provider_identity_v1()
    canonical_json(actual_provider) == canonical_json(value.provider) || error("saved provider identity differs from loaded V4 source")
    actual_enclosure = S._smm_enclosure_v1(declaration.source.input)
    canonical_json(actual_enclosure) == canonical_json(value.enclosure) || error("saved enclosure differs from rebuilt manufactured input")
    artifacts = hydration_restore_semantic_tree(value.raw_artifacts, path * ".raw_artifacts", declaration)
    provider_source = hydration_artifact(value.provider_source, path * ".provider_source")
    S.SpatialManufacturedGeometryReceiptV1(String(value.schema),
        hydration_digest(value.candidate_hash, path * ".candidate_hash"),
        hydration_digest(value.context_hash, path * ".context_hash"),
        hydration_digest(value.declaration_hash, path * ".declaration_hash"),
        hydration_digest(value.input_hash, path * ".input_hash"), actual_provider, provider_source, artifacts,
        hydration_digest(value.initializer_hash, path * ".initializer_hash"),
        hydration_digest(value.reference_state_hash, path * ".reference_state_hash"), actual_enclosure,
        hydration_symbol(path * ".desc_execution", value.desc_execution),
        hydration_symbol(path * ".physical_validation", value.physical_validation),
        hydration_symbol(path * ".authority", value.authority))
end

function hydration_execution_from_body(value, declaration)
    expected_names = (:schema,:provider_receipt,:provider_record,:source,:provider_source,:bounded_step_source,
        :numerical_algorithm,:input_hash,:julia_version,:blas_config,:phase_seconds,:desc_execution,
        :engineering_execution,:whole_device_validation,:physical_validation,:authority,:scope)
    Set(String.(keys(value))) == Set(String.(expected_names)) || error("saved execution field set differs from V4 validator contract")
    receipt = hydration_geometry_receipt(value.provider_receipt, "execution.provider_receipt", declaration)
    phase = value.phase_seconds
    Set(String.(keys(phase))) == Set(("provider", "load", "writer_including_solver")) || error("saved phase_seconds fields changed")
    all(getproperty(phase, key) isa Float64 for key in keys(phase)) || error("saved phase_seconds Float64 tokens changed")
    algorithm = S._smr_bounded_identity_v1()
    canonical_json(algorithm) == canonical_json(value.numerical_algorithm) || error("execution numerical algorithm differs from loaded V4 source")
    (
        schema=String(value.schema),
        provider_receipt=receipt,
        provider_record=hydration_artifact(value.provider_record, "execution.provider_record"),
        source=hydration_artifact(value.source, "execution.source"),
        provider_source=hydration_artifact(value.provider_source, "execution.provider_source"),
        bounded_step_source=hydration_artifact(value.bounded_step_source, "execution.bounded_step_source"),
        numerical_algorithm=algorithm,
        input_hash=hydration_digest(value.input_hash, "execution.input_hash"),
        julia_version=String(value.julia_version),
        blas_config=String(value.blas_config),
        phase_seconds=(provider=phase.provider, load=phase.load, writer_including_solver=phase.writer_including_solver),
        desc_execution=hydration_symbol("execution.desc_execution", value.desc_execution),
        engineering_execution=hydration_symbol("execution.engineering_execution", value.engineering_execution),
        whole_device_validation=hydration_symbol("execution.whole_device_validation", value.whole_device_validation),
        physical_validation=hydration_symbol("execution.physical_validation", value.physical_validation),
        authority=hydration_symbol("execution.authority", value.authority),
        scope=hydration_symbol("execution.scope", value.scope))
end

function hydration_rebuild_result(body, wire, expected_result_hash, context)
    expected_declaration = S._smr_declaration(context)
    declaration = hydration_declaration_from_body(body.declaration, expected_declaration)
    cases = Tuple(hydration_case_from_body(item, index, declaration) for (index, item) in enumerate(body.cases))
    execution = hydration_execution_from_body(body.execution, declaration)
    body_hash = S.canonical_hash(body)
    string(body_hash) == expected_result_hash || error("saved exact body digest differs from frozen result identity")
    body.executed isa Bool || error("saved result executed token changed")
    body.solver_exit_code isa Integer && !(body.solver_exit_code isa Bool) || error("saved result exit token changed")
    body.claim_ceiling == "screen_only" || error("saved result claim ceiling token changed")
    body.primary_case_id isa AbstractString || error("saved result primary case id changed")
    top = S.SpatialManufacturedNumericalResultV1(
        hydration_digest(body.candidate_hash, "candidate_hash"),
        hydration_digest(body.context_hash, "context_hash"), declaration, cases, String(body.primary_case_id),
        body.executed, hydration_symbol("result.status", body.status), Int(body.solver_exit_code), execution,
        hydration_symbol("result.physical_validation", body.physical_validation), S.screen_only,
        hydration_digest((value=String(expected_result_hash),), "result_hash"))
    canonical_json(S.semantic_view(top)) == canonical_json(body) || error("schema-directed result differs from exact saved semantic body")
    string(S.canonical_hash(top)) == expected_result_hash || error("typed result hash differs from saved canonical body")
    string(top.result_hash) == expected_result_hash || error("typed result hash differs from frozen protocol identity")
    canonical_json(top) * "\n" == wire || error("typed result does not round-trip to exact canonical wire")
    top
end

function hydration_push_declared_representation!(rows, path, kind, declared_type, typed_order, body_order,
                                                   typed_shape=(), body_shape=())
    push!(rows, (path=path, kind=kind, declared_type=string(declared_type),
        typed_field_order=Tuple(String.(typed_order)), canonical_body_key_order=Tuple(String.(body_order)),
        typed_shape=Tuple(typed_shape), body_shape=Tuple(body_shape)))
    rows
end

function hydration_declared_mapping!(rows, declared_type, typed_view, exact_value, path, schema_names)
    typed_view isa NamedTuple || error("declared V4 mapping is not a NamedTuple view at $(path)")
    exact_pairs = hydration_object_pairs(exact_value)
    exact_pairs === nothing && error("exact body mapping is unavailable at $(path)")
    typed_order = String.(keys(typed_view))
    declared_order = String.(schema_names)
    typed_order == declared_order || error("typed field order differs from the declared V4 schema at $(path)")
    Set(keys(exact_pairs)) == Set(declared_order) || error("exact body key set differs from the declared V4 schema at $(path)")
    if exact_value isa AbstractDict
        hydration_push_declared_representation!(rows, path, "namedtuple_dict", declared_type,
            typed_order, sort!(collect(keys(exact_pairs))))
        canonical_body_order = sort!(collect(keys(exact_pairs)))
        if typed_order != canonical_body_order
            hydration_push_declared_representation!(rows, path, "object_key_order", declared_type,
                typed_order, canonical_body_order)
        end
    elseif exact_value isa NamedTuple
        String.(keys(exact_value)) == typed_order ||
            error("noncanonical NamedTuple field order differs from the V4 schema at $(path)")
    else
        error("exact body mapping has an unsupported representation at $(path)")
    end
    for (index, field) in enumerate(schema_names)
        child_type = fieldtype(typeof(typed_view), index)
        hydration_declared_representation_allowlist!(rows, child_type,
            getproperty(typed_view, field), exact_pairs[String(field)], "$(path).$(field)")
    end
    rows
end

function hydration_declared_representation_allowlist!(rows, declared_type, typed_value, exact_value, path)
    declared_type === Any && return rows
    if declared_type isa Union
        members = Base.uniontypes(declared_type)
        matching = filter(member -> typeof(typed_value) <: member, members)
        isempty(matching) && return rows
        declared_type = first(matching)
        declared_type === Any && return rows
    end
    if declared_type === Tuple || declared_type <: Tuple
        typed_value isa Tuple || error("declared Tuple field has a non-Tuple value at $(path)")
        (exact_value isa Tuple || exact_value isa AbstractArray) || error("declared Tuple body is not a sequence at $(path)")
        typed_shape = (length(typed_value),)
        exact_shape = exact_value isa Tuple ? (length(exact_value),) : size(exact_value)
        typed_shape == exact_shape || error("declared Tuple/body shape mismatch at $(path)")
        if typed_value isa Tuple && exact_value isa AbstractArray
            hydration_push_declared_representation!(rows, path, "tuple_array", declared_type,
                (), (), typed_shape, exact_shape)
        end
        for index in eachindex(typed_value)
            child_type = fieldtype(typeof(typed_value), index)
            hydration_declared_representation_allowlist!(rows, child_type, typed_value[index],
                exact_value[index], "$(path)[$(index)]")
        end
        return rows
    elseif declared_type === NamedTuple || declared_type <: NamedTuple
        typed_value isa NamedTuple || error("declared NamedTuple field has a non-NamedTuple value at $(path)")
        schema_names = fieldnames(typeof(typed_value))
        return hydration_declared_mapping!(rows, declared_type, typed_value, exact_value, path, schema_names)
    elseif declared_type isa DataType && isconcretetype(declared_type) && isstructtype(declared_type)
        typed_value isa declared_type || error("typed value differs from its declared V4 struct at $(path)")
        hasmethod(S.semantic_view, Tuple{typeof(typed_value)}) || return rows
        typed_view = S.semantic_view(typed_value)
        typed_view isa NamedTuple || error("declared V4 struct has no NamedTuple semantic view at $(path)")
        declared_fields = fieldnames(declared_type)
        view_names = Tuple(keys(typed_view))
        semantic_fields = if view_names == declared_fields
            declared_fields
        elseif !isempty(declared_fields) && last(declared_fields) == :result_hash &&
                view_names == declared_fields[1:end-1]
            declared_fields[1:end-1]
        else
            error("semantic-view field order differs from the declared V4 struct at $(path)")
        end
        hydration_declared_mapping!(rows, declared_type, typed_view, exact_value, path, semantic_fields)
        exact_pairs = hydration_object_pairs(exact_value)
        for (index, field) in enumerate(semantic_fields)
            child_type = fieldtype(declared_type, index)
            hydration_declared_representation_allowlist!(rows, child_type,
                getfield(typed_value, field), exact_pairs[String(field)], "$(path).$(field)")
        end
        return rows
    elseif declared_type isa DataType && declared_type <: AbstractArray
        typed_value isa AbstractArray && exact_value isa AbstractArray || return rows
        size(typed_value) == size(exact_value) || return rows
        child_type = eltype(declared_type)
        child_type === Any && return rows
        for index in eachindex(typed_value)
            hydration_declared_representation_allowlist!(rows, child_type, typed_value[index],
                exact_value[index], "$(path)[$(index)]")
        end
    end
    rows
end

function result_from_saved_wire(wire, expected_result_hash, out, active_phase, context)
    active_phase[] = "canonical_body_parse"
    body = S._smr_read_canonical_json_v1(wire)
    hydration_checkpoint!(out, "canonical_body_parse")
    active_phase[] = "semantic_hash_recompute"
    result_hash = S.canonical_hash(body)
    hydration_checkpoint!(out, "semantic_hash_recompute", result_hash)
    active_phase[] = "result_digest_injection"
    typed_body = merge(body, (; result_hash=(value=string(result_hash),)))
    hydration_checkpoint!(out, "result_digest_injection", result_hash)
    active_phase[] = "typed_wire_encoding"
    typed_wire = canonical_json(typed_body) * "\n"
    hydration_checkpoint!(out, "typed_wire_encoding", result_hash)
    active_phase[] = "json3_typed_parse"
    observed = JSON3.read(typed_wire, S.SpatialManufacturedNumericalResultV1)
    hydration_checkpoint!(out, "json3_typed_parse", result_hash)

    # Persist actual type/value fingerprints and leaf differences before schema or expected-state checks.
    active_phase[] = "observe_typed_body_before_assertions"
    typed_body = observed isa S.SpatialManufacturedNumericalResultV1 ? S.semantic_view(observed) : observed
    body_pairs = hydration_object_pairs(body)
    typed_pairs = hydration_object_pairs(typed_body)
    body_pairs === nothing && error("exact body fields cannot be observed")
    typed_pairs === nothing && error("typed parse fields cannot be observed")
    mismatch_roots = String[]
    numeric = NamedTuple[]; semantic = String[]; representation = NamedTuple[]
    for key in sort!(collect(union(Set(keys(body_pairs)), Set(keys(typed_pairs)))))
        if !haskey(body_pairs, key) || !haskey(typed_pairs, key)
            push!(mismatch_roots, String(key))
            push!(semantic, String(key) * ".<field_presence>")
        else
            body_fingerprint = hydration_canonical_fingerprint(body_pairs[key])
            typed_fingerprint = hydration_canonical_fingerprint(typed_pairs[key])
            (body_fingerprint.canonical_sha256 !== nothing &&
                body_fingerprint.canonical_sha256 == typed_fingerprint.canonical_sha256) || push!(mismatch_roots, String(key))
            hydration_diff!(numeric, semantic, representation, typed_pairs[key], body_pairs[key], String(key))
        end
    end
    stored_result_hash = hasproperty(observed, :result_hash) ? string(getproperty(observed, :result_hash)) : nothing
    initial = hydration_field_observation(body, typed_body, stored_result_hash,
        "before_expected_assertions", result_hash,
        mismatch_roots, numeric, semantic; representation_differences=representation)
    new_json(joinpath(out, "hydration_observation_initial.json"), initial)
    new_json(joinpath(out, "hydration_observation_differences.json"),
        (schema="mms-replay-only-hydration-difference-analysis-v2", classification="test_only_continuation",
         mismatch_roots=Tuple(mismatch_roots), numeric_type_differences=Tuple(numeric),
         semantic_differences=Tuple(semantic), representation_differences=Tuple(representation),
         expected_reconstruction_roots=("declaration", "cases", "execution")))
    hydration_checkpoint!(out, "observe_typed_body_before_assertions", result_hash)

    observed isa S.SpatialManufacturedNumericalResultV1 || error("observed result has wrong concrete type")

    allowed_roots = ("declaration", "cases", "execution")
    isempty(mismatch_roots) && error("no observed body/typed mismatch; exact-body reconstruction is not authorized")
    all(root -> root in allowed_roots, mismatch_roots) ||
        error("observe-first mismatch root falls outside saved V4 result schema")
    all(item -> hydration_path_in_roots(item.path, allowed_roots), numeric) ||
        error("observe-first numeric token difference falls outside saved V4 result schema")
    all(item -> hydration_path_in_roots(item.path, allowed_roots), representation) ||
        error("observe-first representation difference falls outside saved V4 result schema")
    numeric_ok = all(item -> item.typed_value == item.body_value &&
        Set((item.typed_type, item.body_type)) == Set(("Float64", "Int64")), numeric)
    representation_ok = all(item -> item.kind in ("namedtuple_dict", "object_key_order", "tuple_array"), representation)
    isempty(semantic) && numeric_ok && representation_ok ||
        error("observe-first found an unproven typed/body value, key, or shape difference")
    replacements = String[item.path for item in numeric]
    active_phase[] = "schema_directed_reconstruction"
    result = hydration_rebuild_result(body, wire, expected_result_hash, context)
    after_semantic = String[]; after_numeric = NamedTuple[]; after_representation = NamedTuple[]
    result_body = S.semantic_view(result)
    result_fields = fieldnames(S.SpatialManufacturedNumericalResultV1)[1:end-1]
    Tuple(keys(result_body)) == result_fields || error("typed result field order differs from SpatialManufacturedNumericalResultV1")
    body_pairs_after = hydration_object_pairs(body)
    body_pairs_after === nothing && error("exact result body fields are unavailable after reconstruction")
    Set(keys(body_pairs_after)) == Set(String.(result_fields)) || error("exact result body field set changed after reconstruction")
    for key in result_fields
        hydration_diff!(after_numeric, after_semantic, after_representation,
            getproperty(result_body, key), getproperty(body, key), String(key))
    end
    after_mismatch_roots = String[]
    for key in sort!(collect(String.(result_fields)))
        body_fingerprint = hydration_canonical_fingerprint(body_pairs_after[key])
        typed_fingerprint = hydration_canonical_fingerprint(getproperty(result_body, Symbol(key)))
        (body_fingerprint.canonical_sha256 !== nothing &&
            body_fingerprint.canonical_sha256 == typed_fingerprint.canonical_sha256) || push!(after_mismatch_roots, key)
    end
    after_observation = hydration_field_observation(body, result_body, string(result.result_hash),
        "after_schema_directed_reconstruction_before_allowlist", result_hash, after_mismatch_roots,
        after_numeric, after_semantic, replacements; representation_differences=after_representation)
    new_json(joinpath(out, "hydration_observation_reconstruction.json"), after_observation)

    declared_allowlist = NamedTuple[]
    for (index, key) in enumerate(result_fields)
        hydration_declared_representation_allowlist!(declared_allowlist,
            fieldtype(S.SpatialManufacturedNumericalResultV1, index), getfield(result, key),
            getproperty(body, key), String(key))
    end
    new_json(joinpath(out, "hydration_declared_schema_allowlist.json"),
        (schema="mms-replay-only-declared-schema-representation-allowlist-v1",
         classification="test_only_continuation", result_type=string(typeof(result)),
         declared_result_fields=Tuple(String.(result_fields)), entries=Tuple(declared_allowlist)))
    allowed_pairs = Set((item.path, item.kind) for item in declared_allowlist)
    all(item -> (item.path, item.kind) in allowed_pairs, after_representation) ||
        error("after representation difference is not authorized by an exact declared V4 Tuple/NamedTuple path")
    isempty(after_semantic) && isempty(after_numeric) ||
        error("schema-directed reconstruction retains a semantic or numeric-type difference")
    hydration_checkpoint!(out, "schema_directed_reconstruction", result_hash)
    result
end

function producer(args)
    length(args) == 6 || error("expected producer OUT SAVED_NUMERICAL_ROOT PROTOCOL_SHA NOT_APPLICABLE NOT_APPLICABLE")
    _, out_arg, source_arg, protocol_sha, carrier_arg, binding_arg = args
    carrier_arg == "not_applicable" && binding_arg == "not_applicable" || error("producer cannot accept consumer seals")
    out = abspath(out_arg)
    source_root = abspath(source_arg)
    ispath(out) && error("preserve existing replay producer output")
    mkpath(out)
    protocol = protocol_value(protocol_sha)
    protocol.classification == "test_only_continuation" || error("protocol is not test_only_continuation")
    expected_source = normpath(joinpath(ROOT, "docs", "implementation", "UP2-04-CLOSURE-REPAIR-PREC",
        "agent_r2_n1_20260922", "runtime_manufactured_staged_r1", "producer_process", "numerical"))
    normpath(source_root) == expected_source || error("foreign saved numerical root")

    saved_result = joinpath(source_root, "production", "numerical_result.json")
    sha256_file(saved_result) == expected_hash(protocol, :numerical_result) || error("saved numerical_result SHA mismatch")
    exit_file = joinpath(source_root, "production", "n1_q1_2", "solver.exitcode")
    strip(read(exit_file, String)) == "2" || error("saved solver exit code mismatch")

    context = try
        bind_context_from_saved_parent!(out, source_root)
    catch err
        backtrace = sprint(Base.show_backtrace, catch_backtrace())
        new_json(joinpath(out, "producer_failure.json"), (schema="mms-replay-only-failure-v1",
            classification="context_rebuild_failed", phase="context_rebuild",
            error=sprint(showerror, err), backtrace=backtrace, solver_exit_code=2,
            numerical_status="fail", authority="no_publish"))
        println(stderr, "MMS_REPLAY_ONLY_FAIL classification=context_rebuild_failed error=",
            sprint(showerror, err)); flush(stderr)
        Base.exit(71)
    end
    hydration_phase = Ref("not_started")
    result = try
        result_from_saved_wire(read(saved_result, String), String(protocol.preserved_identity.result_hash), out,
            hydration_phase, context)
    catch err
        backtrace = sprint(Base.show_backtrace, catch_backtrace())
        new_json(joinpath(out, "producer_failure.json"), (schema="mms-replay-only-failure-v1",
            classification="replay_hydration_unsupported", phase="typed_result_hydration",
            hydration_stage=hydration_phase[], error=sprint(showerror, err), backtrace=backtrace,
            solver_exit_code=2,
            numerical_status="fail", authority="no_publish"))
        println(stderr, "MMS_REPLAY_ONLY_FAIL classification=replay_hydration_unsupported error=",
            sprint(showerror, err)); flush(stderr)
        Base.exit(72)
    end
    c = only(result.cases)
    result.candidate_hash == context.candidate_hash && result.context_hash == context.context_hash || error("saved result context binding mismatch")
    string(result.candidate_hash) == String(protocol.preserved_identity.candidate_hash) || error("saved result candidate hash differs from protocol")
    string(result.context_hash) == String(protocol.preserved_identity.context_hash) || error("saved result context hash differs from protocol")
    string(c.state_hash) == String(protocol.preserved_identity.state_after_hash) || error("saved result state hash differs from protocol")
    string(canonical_hash(result.declaration)) == String(protocol.preserved_identity.declaration_sha256) ||
        error("saved result declaration hash differs from protocol")
    result.primary_case_id == "n1_q1_2" && c.status == :fail && c.stopping_reason == :stationary_nonzero_residual &&
        c.solver_exit_code == 2 && result.solver_exit_code == 2 && result.status == :fail ||
        error("saved numerical_fail/exit-2 semantics changed")
    result.physical_validation == :unsupported && result.execution.authority == :no_publish ||
        error("saved result exceeds test-only authority scope")

    phase_path = joinpath(out, "producer_full_validator.json")
    start = time()
    new_json(joinpath(out, "producer_validator_started.json"), (schema="mms-replay-only-runtime-hit-v1",
        classification="test_only_continuation", validator="validate_spatial_manufactured_result_v1",
        runtime_hit=true, candidate_hash=string(context.candidate_hash), context_hash=string(context.context_hash),
        result_hash=string(result.result_hash), solver_exit_code=2))
    validator_hash = S.validate_spatial_manufactured_result_v1(context, result)
    validator_hash == result.result_hash || error("public validator returned a different result identity")
    new_json(joinpath(out, "producer_validator_completed.json"), (schema="mms-replay-only-runtime-hit-v1",
        classification="test_only_continuation", validator="validate_spatial_manufactured_result_v1",
        runtime_hit=true, exit_code=0, validator_hash=string(validator_hash)))
    new_json(phase_path, (schema="mms-replay-only-validator-v1", classification="test_only_continuation",
        validator="validate_spatial_manufactured_result_v1", validator_hash=string(validator_hash),
        candidate_hash=string(context.candidate_hash), context_hash=string(context.context_hash),
        result_hash=string(result.result_hash), elapsed_seconds=time()-start, result_status=string(result.status),
        stopping_reason=string(c.stopping_reason), solver_exit_code=c.solver_exit_code,
        physical_validation=string(result.physical_validation), authority=string(result.execution.authority)))

    carrier = joinpath(out, "replay_carrier.bin")
    serialize(carrier, (schema="mms-replay-only-carrier-v1", context=context, result=result))
    carrier_sha = sha256_file(carrier)
    binding = (schema="mms-replay-only-carrier-binding-v1", protocol_sha256=protocol_sha,
        source_result_sha256=sha256_file(saved_result), carrier_path=realpath(carrier),
        carrier_sha256=carrier_sha, carrier_bytes=filesize(carrier), candidate_hash=string(context.candidate_hash),
        context_hash=string(context.context_hash), result_hash=string(result.result_hash), solver_exit_code=2,
        numerical_status="fail", stopping_reason="stationary_nonzero_residual", authority="no_publish",
        scope="test_only_continuation_transport_no_solver")
    binding_path = joinpath(out, "replay_carrier_binding.json")
    new_json(binding_path, binding)
    new_json(joinpath(out, "producer_complete.json"), (schema="mms-replay-only-producer-complete-v1",
        classification="test_only_continuation", software_stage="passed", full_validator_replays=1,
        nonlinear_solves=0, positive_result_replays=1, carrier_sha256=carrier_sha,
        carrier_binding_sha256=sha256_file(binding_path), candidate_hash=string(context.candidate_hash),
        context_hash=string(context.context_hash), result_hash=string(result.result_hash),
        numerical_status="fail", solver_exit_code=2, stopping_reason="stationary_nonzero_residual",
        physical_validation="unsupported", authority="no_publish", formal_candidate_credit=false))
    println("MMS_REPLAY_ONLY_COMPLETE stage=producer software=passed numerical=fail solver_exit=2"); flush(stdout)
end

function consumer(args)
    length(args) == 6 || error("expected consumer OUT PRODUCER_OUTPUT PROTOCOL_SHA CARRIER_SHA BINDING_SHA")
    _, out_arg, producer_arg, protocol_sha, expected_carrier_sha, expected_binding_sha = args
    out = abspath(out_arg); producer_root = abspath(producer_arg)
    ispath(out) && error("preserve existing replay consumer output")
    mkpath(out)
    protocol = protocol_value(protocol_sha)
    protocol.classification == "test_only_continuation" || error("protocol is not test_only_continuation")
    carrier = joinpath(producer_root, "replay_carrier.bin")
    binding_path = joinpath(producer_root, "replay_carrier_binding.json")
    sha256_file(carrier) == expected_carrier_sha || error("replay carrier differs from independent producer seal")
    sha256_file(binding_path) == expected_binding_sha || error("replay carrier binding differs from independent producer seal")
    binding = JSON3.read(read(binding_path, String))
    binding.protocol_sha256 == protocol_sha && binding.carrier_sha256 == expected_carrier_sha &&
        binding.scope == "test_only_continuation_transport_no_solver" || error("foreign replay carrier binding")
    payload = deserialize(carrier)
    payload.schema == "mms-replay-only-carrier-v1" || error("foreign replay carrier schema")
    context = payload.context; result = payload.result; c = only(result.cases)
    S.validate_forward_chain_context(context)
    canonical_hash(result) == result.result_hash || error("replay-carrier result hash mismatch")
    result.solver_exit_code == 2 && result.status == :fail && c.stopping_reason == :stationary_nonzero_residual ||
        error("consumer would alter solver failure semantics")
    start = time()
    new_json(joinpath(out, "consumer_suite_started.json"), (schema="mms-replay-only-runtime-hit-v1",
        classification="test_only_continuation", suite="ManufacturedCandidateV1Tests.result_tests",
        runtime_hit=true, candidate_hash=string(context.candidate_hash), context_hash=string(context.context_hash),
        result_hash=string(result.result_hash), solver_exit_code=2))
    M.result_tests(context, result, out)
    new_json(joinpath(out, "consumer_suite_completed.json"), (schema="mms-replay-only-runtime-hit-v1",
        classification="test_only_continuation", suite="ManufacturedCandidateV1Tests.result_tests",
        runtime_hit=true, exit_code=0))
    new_json(joinpath(out, "consumer_complete.json"), (schema="mms-replay-only-consumer-complete-v1",
        classification="test_only_continuation", software_stage="passed", original_consumer_suite="passed",
        full_validator_replays=1, negative_scope_cases="all original result/public scope cases",
        nonlinear_solves=0, positive_result_replays=1, candidate_hash=string(context.candidate_hash),
        context_hash=string(context.context_hash), result_hash=string(result.result_hash),
        numerical_status="fail", solver_exit_code=2, stopping_reason="stationary_nonzero_residual",
        elapsed_seconds=time()-start, physical_validation="unsupported", authority="no_publish",
        formal_candidate_credit=false))
    println("MMS_REPLAY_ONLY_COMPLETE stage=consumer software=passed numerical=fail solver_exit=2"); flush(stdout)
end

function main(args)
    length(args) == 6 || error("expected MODE OUTPUT SOURCE_OR_PRODUCER PROTOCOL_SHA EXPECTED_CARRIER_SHA EXPECTED_BINDING_SHA")
    mode = args[1]
    println("MMS_REPLAY_ONLY mode=", mode, " julia=", VERSION, " pid=", getpid()); flush(stdout)
    VERSION == v"1.10.5" || error("replay continuation is pinned to Julia 1.10.5")
    mode == "producer" ? producer(args) : mode == "consumer" ? consumer(args) : error("unknown replay-only mode")
end

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
    main(ARGS)
end
