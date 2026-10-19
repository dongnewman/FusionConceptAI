using SHA

const _THERMAL_SOURCE_VARIANT_REQUIRED_PATHS_V1 = (
    "identity.jl", "design_identity.json", "scenario.json", "g1_source.jl",
    "g2_source.jl", "g3_source.jl", "g3_child_design_source.jl",
    "native_mms_source_expressions.json")

function _thermal_source_variant_replace_once_v1(text::String, old::String,
        new::String, label::AbstractString)
    if occursin("\r\n", text)
        old = replace(old, "\r\n" => "\n")
        new = replace(new, "\r\n" => "\n")
        old = replace(old, "\n" => "\r\n")
        new = replace(new, "\n" => "\r\n")
    end
    first_match = findfirst(old, text)
    first_match === nothing && throw(ArgumentError("source variant token missing: $label"))
    findnext(old, text, last(first_match) + 1) === nothing ||
        throw(ArgumentError("source variant token is ambiguous: $label"))
    prefix = first(first_match) == firstindex(text) ? "" :
        text[firstindex(text):prevind(text, first(first_match))]
    next_char = nextind(text, last(first_match))
    suffix = next_char > lastindex(text) ? "" : text[next_char:end]
    prefix * new * suffix
end

function _thermal_source_variant_manifest_pin_v1(text::String, path::String,
        bytes::Vector{UInt8})
    escaped_path = replace(path, "." => "\\.")
    pattern = Regex("(\\\"path\\\"\\s*:\\s*\\\"" * escaped_path *
        "\\\"\\s*,\\s*\\\"bytes\\\"\\s*:\\s*)\\d+(\\s*,\\s*\\\"sha256\\\"\\s*:\\s*\\\")[0-9a-fA-F]{64}(\\\")")
    matches = collect(eachmatch(pattern, text))
    length(matches) == 1 || throw(ArgumentError("manifest source pin missing or ambiguous: $path"))
    matched = only(matches)
    replacement = String(matched.captures[1]) * string(length(bytes)) *
        String(matched.captures[2]) * bytes2hex(SHA.sha256(bytes)) *
        String(matched.captures[3])
    _thermal_source_variant_replace_once_v1(text, String(matched.match), replacement,
        "manifest pin for $path")
end

"""Materialize stable test-only candidate bytes for the existing current-source T0/T1 path.

Supported variants are `:base_no_law`, `:feedback_edge_removed`, and
`:k22_feedback_heldout`, `:up2_02_refinement` (8 cells by default; pass
`refinement_cells=16` for a separately identified 16-cell candidate), `:up2_02_holdout`,
`:up3_review_holdout_r14`, and `:up2_01_variable_kxx_affine`. The K22 variant derives real G1/G2 inputs from the existing K22 fixture,
adds the existing candidate-authored temperature law to its matching G3 controller, and generates
a new candidate identity. The deterministic `tmp/` path keeps absolute repository roots and
logical source locators equal across A/B processes. Existing materializations are reused only if
every expected file is byte-identical and no extra files/directories are present; otherwise this
fails closed without changing the materialization. Returns `(source_root, candidate_directory,
candidate_id, scenario_id)`.
"""
function _thermal_up2_01_source_ast_json_v1(role::Symbol, mode::Symbol)
    schema = "fusionconceptai:genome-v5:g1-source-expression-ast-v1"
    if role === :u
        value = mode === :up2_01_holdout_quadratic_f ? 310 : 300
        return "{\"nodes\":[{\"kind\":\"constant\",\"role\":\"u\",\"value\":" *
            string(value) * "}],\"role\":\"u\",\"root\":1,\"schema\":\"" *
            schema * "\"}"
    end
    if mode in (:up2_01_legal_constant_f, :up2_01_transient_si,
            :up2_01_transverse_bc_negative,
            :up2_01_flux_unit_negative, :up2_01_variable_kxx_affine)
        return "{\"nodes\":[{\"kind\":\"constant\",\"role\":\"f\",\"value\":1}],\"role\":\"f\",\"root\":1,\"schema\":\"" * schema * "\"}"
    end
    xi_nodes = "{\"kind\":\"input\",\"port\":1},{\"kind\":\"constant\",\"role\":\"chart_x_axis\",\"value\":[1,0,0]},{\"inputs\":[1,2],\"kind\":\"apply\",\"operator\":\"DOT\"}"
    if mode === :up2_01_legal_affine_f
        nodes = "[" * xi_nodes * ",{\"kind\":\"constant\",\"role\":\"f\",\"value\":0.5},{\"inputs\":[3,4],\"kind\":\"apply\",\"operator\":\"SCALAR_MUL\"},{\"kind\":\"constant\",\"role\":\"f\",\"value\":1},{\"inputs\":[6,5],\"kind\":\"apply\",\"operator\":\"ADD\"}]"
        root = 7
    elseif mode === :up2_01_holdout_quadratic_f
        nodes = "[" * xi_nodes * ",{\"inputs\":[3,3],\"kind\":\"apply\",\"operator\":\"SCALAR_MUL\"},{\"kind\":\"constant\",\"role\":\"f\",\"value\":0.5},{\"inputs\":[4,5],\"kind\":\"apply\",\"operator\":\"SCALAR_MUL\"},{\"kind\":\"constant\",\"role\":\"f\",\"value\":1},{\"inputs\":[7,6],\"kind\":\"apply\",\"operator\":\"ADD\"}]"
        root = 8
    else
        throw(ArgumentError("unsupported UP2-01 f AST mode"))
    end
    "{\"nodes\":" * nodes * ",\"role\":\"f\",\"root\":" *
        string(root) * ",\"schema\":\"" * schema * "\"}"
end

function _thermal_up2_01_replace_json_string_v1(text::String, key::String, old::String, value::String)
    escaped_old = replace(old, "\\" => "\\\\", "\"" => "\\\"")
    escaped_new = replace(value, "\\" => "\\\\", "\"" => "\\\"")
    old_token = "\"" * key * "\": \"" * escaped_old * "\""
    new_token = "\"" * key * "\": \"" * escaped_new * "\""
    _thermal_source_variant_replace_once_v1(text, old_token, new_token,
        "UP2-01 source expression $key")
end

function _thermal_materialize_source_variant_v1(source_root::AbstractString,
        base_candidate_directory::AbstractString, variant::Symbol;
        refinement_cells::Integer=8)
    variant === :up2_02_refinement && !(refinement_cells in (8, 16)) &&
        throw(ArgumentError("UP2-02 refinement supports only the authored 8- or 16-cell levels"))
    variant !== :up2_02_refinement && refinement_cells != 8 &&
        throw(ArgumentError("refinement_cells applies only to :up2_02_refinement"))
    variant in (:base_no_law, :feedback_edge_removed, :k22_feedback_heldout,
        :up2_02_refinement, :up2_02_holdout, :up2_02_nonunit_yz,
        :up3_review_holdout_r14,
        :up2_01_legal_constant_f,
        :up2_01_legal_affine_f, :up2_01_holdout_quadratic_f,
        :up2_01_transient_si,
        :up2_01_transverse_bc_negative, :up2_01_flux_unit_negative,
        :up2_01_variable_kxx_affine) ||
        throw(ArgumentError("unsupported thermal source variant"))
    source_root = realpath(String(source_root))
    base_relative = replace(String(base_candidate_directory), '\\' => '/')
    (isabspath(base_relative) || any(part -> part in ("", ".", ".."),
        split(base_relative, '/'))) &&
        throw(ArgumentError("thermal source variant base path must be repository-relative"))
    k22_heldout = variant === :k22_feedback_heldout
    up2_02_source_variant = variant in (:up2_02_refinement, :up2_02_holdout,
        :up2_02_nonunit_yz, :up3_review_holdout_r14)
    up2_01_source_variant = variant in (:up2_01_legal_constant_f,
        :up2_01_legal_affine_f, :up2_01_holdout_quadratic_f,
        :up2_01_transverse_bc_negative, :up2_01_flux_unit_negative,
        :up2_01_variable_kxx_affine, :up2_01_transient_si)
    old_slug = k22_heldout ? "thermal-slab-up4-v5-20261001-k22" :
        "thermal-slab-up4-v5-20261001"
    last(split(base_relative, '/')) == old_slug ||
        throw(ArgumentError("thermal source variant base fixture does not match its variant"))
    suffix = variant === :up3_review_holdout_r14 ?
        "up3-review-holdout-r14-k3-scale15-b298-306-6x1x1" :
        variant === :up2_01_legal_constant_f ? "up2-01-legal-constant-f" :
        variant === :up2_01_legal_affine_f ? "up2-01-legal-affine-f" :
        variant === :up2_01_holdout_quadratic_f ? "up2-01-holdout-quadratic-f" :
        variant === :up2_01_transient_si ? "up2-01-transient-si-capacity" :
        variant === :up2_01_transverse_bc_negative ? "up2-01-transverse-bc-negative" :
        variant === :up2_01_flux_unit_negative ? "up2-01-flux-unit-negative" :
        variant === :up2_01_variable_kxx_affine ? "up2-01-variable-kxx-affine" :
        variant === :base_no_law ? "base-no-law" :
        variant === :feedback_edge_removed ? "feedback-edge-removed" :
        variant === :k22_feedback_heldout ? "feedback-heldout" :
        variant === :up2_02_nonunit_yz ? "up2-02-nonunit-yz-1over2-1over4" :
        variant === :up2_02_refinement ? "up2-02-refinement-$(refinement_cells)x1x1" :
        "up2-02-holdout-k3-scale15-t310-6x1x1"
    output_slug = k22_heldout ? "k22-feedback-heldout" :
        variant === :up2_02_refinement ? "up2-02-refinement-$(refinement_cells)x1x1" :
        variant === :up2_02_holdout ? "up2-02-holdout-k3-scale15-t310-6x1x1" : suffix
    new_slug = old_slug * "-" * suffix
    output_parent = up2_02_source_variant ? "tmp/up2_02_source_variants" :
        up2_01_source_variant ? "tmp/up2_01_source_variants" :
        "tmp/up3_thermal_source_variants"
    candidate_relative = output_parent * "/" * output_slug
    target = joinpath(source_root, split(candidate_relative, '/')...)
    base = joinpath(source_root, split(base_relative, '/')...)
    for directory in (joinpath(source_root, "tmp"),
            joinpath(source_root, "tmp", "up3_thermal_source_variants"),
            joinpath(source_root, "tmp", "up2_02_source_variants"),
            joinpath(source_root, "tmp", "up2_01_source_variants"))
        if ispath(directory)
            isdir(directory) && !islink(directory) ||
                throw(ArgumentError("thermal source variant parent is not a plain directory"))
        else
            mkpath(directory)
        end
    end

    generated = Dict{String,Vector{UInt8}}()
    for relative_path in _THERMAL_SOURCE_VARIANT_REQUIRED_PATHS_V1
        source_path = joinpath(base, split(relative_path, '/')...)
        isfile(source_path) || throw(ArgumentError("thermal source variant input missing: $relative_path"))
        text = String(copy(read(source_path)))
        text = replace(text, old_slug => new_slug)
        text = replace(text, "scenario-" * new_slug => "scenario-" * old_slug)
        text = replace(text, "fusionconceptai://scenario-design/" * new_slug =>
            "fusionconceptai://scenario-design/" * old_slug)
        generated[relative_path] = collect(codeunits(text))
    end

    child = String(generated["g3_child_design_source.jl"])
    slug_rewritten_base = replace(base_relative, old_slug => new_slug)
    old_logical_child_path = slug_rewritten_base * "/g3_child_design_source.jl"
    new_logical_child_path = candidate_relative * "/g3_child_design_source.jl"
    child = _thermal_source_variant_replace_once_v1(child, old_logical_child_path,
        new_logical_child_path, "child source path")
    if k22_heldout
        base_law_path = joinpath(source_root, "test", "fixtures", "thermal_slab",
            "thermal-slab-up4-v5-20261001", "g3_child_design_source.jl")
        base_law_source = read(base_law_path, String)
        law_pattern = r"(?ms)^            temperature_source_feedback=\(schema=.*?parameter_id=\"thermal_slab_temperature_feedback_q_v1\"\),\r?\n"
        laws = collect(eachmatch(law_pattern, base_law_source))
        length(laws) == 1 ||
            throw(ArgumentError("held-out source feedback law missing or ambiguous"))
        law = only(laws).match
        child = _thermal_source_variant_replace_once_v1(child,
            "    temperature_unit = UnitSignature((0, 0, 0, 0, 1, 0, 0)) # K\n",
            "    temperature_unit = UnitSignature((0, 0, 0, 0, 1, 0, 0)) # K\n" *
            "    source_density_unit = UnitSignature((-1, 1, -3, 0, 0, 0, 0)) # W/m^3 in source basis\n",
            "held-out source-density unit")
        child = _thermal_source_variant_replace_once_v1(child,
            "        control_design=(law=\"candidate thermostat with 10 K deadband\",\n",
            "        control_design=(law=\"candidate thermostat with 10 K deadband\",\n" * law,
            "bind held-out source law to K22 controller")
    elseif variant === :base_no_law
        law_pattern = Regex("(?s)            temperature_source_feedback=\\(schema=.*?" *
            "parameter_id=\"thermal_slab_temperature_feedback_q_v1\"\\),\\r?\\n")
        length(collect(eachmatch(law_pattern, child))) == 1 ||
            throw(ArgumentError("temperature feedback profile field missing or ambiguous"))
        child = replace(child, law_pattern => "")
    elseif variant === :feedback_edge_removed
        child = _thermal_source_variant_replace_once_v1(child,
            "        G3ControlSignalV1(\"core_temperature\", :sensor, :in, temperature_unit, \"temperature_account\"),\n        G3ControlSignalV1(\"source_fraction_command\",",
            "        G3ControlSignalV1(\"core_temperature\", :sensor, :in, temperature_unit, \"temperature_account\"),\n        G3ControlSignalV1(\"queue_unbound_feedback_temperature\", :sensor, :in, temperature_unit, \"temperature_account\"),\n        G3ControlSignalV1(\"source_fraction_command\",",
            "add controller-owned non-feedback sensor")
        child = _thermal_source_variant_replace_once_v1(child,
            "G3ControlControllerV1(controller_id, (\"core_temperature\",),",
            "G3ControlControllerV1(controller_id, (\"queue_unbound_feedback_temperature\",),",
            "controller sensor ownership")
        child = _thermal_source_variant_replace_once_v1(child,
            "G3ControlFaultV1(fault_id, controller_id, :overtemperature, :trip,\n        \"core_temperature\", 1//10)",
            "G3ControlFaultV1(fault_id, controller_id, :overtemperature, :trip,\n        \"queue_unbound_feedback_temperature\", 1//10)",
            "fault detection sensor ownership")
        child = _thermal_source_variant_replace_once_v1(child,
            "(\"core_temperature\", \"source_fraction_command\", \"source_power_resource\"),",
            "(\"core_temperature\", \"queue_unbound_feedback_temperature\", \"source_fraction_command\", \"source_power_resource\"),",
            "control plan signal membership")
        child = _thermal_source_variant_replace_once_v1(child,
            "\"thermal_supervisor_source_supply_current\", controller_id,\n        \"core_temperature\", \"source_fraction_command\", \"source_supply_current\",",
            "\"thermal_supervisor_source_supply_current\", controller_id,\n        \"queue_unbound_feedback_temperature\", \"source_fraction_command\", \"source_supply_current\",",
            "remove the law-matching resource edge")
    end
    if variant in (:up2_02_refinement, :up2_02_holdout, :up2_02_nonunit_yz,
            :up3_review_holdout_r14,
            :up2_01_legal_affine_f, :up2_01_holdout_quadratic_f)
        g2_source = String(generated["g2_source.jl"])
        old_cells = "G2MBMeshPlanV1(mesh_ref, chart_ref, (4,1,1), :Q1,"
        new_cells = variant === :up2_02_refinement ?
            "G2MBMeshPlanV1(mesh_ref, chart_ref, ($(refinement_cells),1,1), :Q1," :
            variant === :up2_01_legal_affine_f ?
            "G2MBMeshPlanV1(mesh_ref, chart_ref, (8,1,1), :Q1," :
            variant === :up2_02_nonunit_yz ?
                "G2MBMeshPlanV1(mesh_ref, chart_ref, (4,1,1), :Q1," :
                "G2MBMeshPlanV1(mesh_ref, chart_ref, (6,1,1), :Q1,"
        g2_source = _thermal_source_variant_replace_once_v1(g2_source,
            old_cells, new_cells, "UP2-02 source-authored mesh cells")
        if variant in (:up2_02_holdout, :up2_01_holdout_quadratic_f,
                :up3_review_holdout_r14)
            g2_source = _thermal_source_variant_replace_once_v1(g2_source,
                "((2//1,0//1,0//1),(0//1,1//1,0//1),(0//1,0//1,1//1)),",
                "((3//2,0//1,0//1),(0//1,1//1,0//1),(0//1,0//1,1//1)),",
                "UP2-02 held-out x chart scale")
            g2_source = _thermal_source_variant_replace_once_v1(g2_source,
                "G2MBFaceOwnerV1(\"thermal_x_min\", :x_min, \"thermal_slab\", (-1,0,0), dirichlet(300//1)),",
                "G2MBFaceOwnerV1(\"thermal_x_min\", :x_min, \"thermal_slab\", (-1,0,0), dirichlet(310//1)),",
                "UP2-02 held-out x_min temperature")
            g2_source = _thermal_source_variant_replace_once_v1(g2_source,
                "G2MBFaceOwnerV1(\"thermal_x_max\", :x_max, \"thermal_slab\", (1,0,0), dirichlet(300//1)),",
                "G2MBFaceOwnerV1(\"thermal_x_max\", :x_max, \"thermal_slab\", (1,0,0), dirichlet(310//1)),",
                "UP2-02 held-out x_max temperature")
            g1_source = String(generated["g1_source.jl"])
            g1_source = _thermal_source_variant_replace_once_v1(g1_source,
                "base_diag=(2//1, 3//1, 4//1),",
                "base_diag=(3//1, 3//1, 4//1),",
                "UP2-02 held-out Kxx")
            g1_source = _thermal_source_variant_replace_once_v1(g1_source,
                "domain_min=(0//1, 0//1, 0//1), domain_max=(2//1, 1//1, 1//1),",
                "domain_min=(0//1, 0//1, 0//1), domain_max=(3//2, 1//1, 1//1),",
                "UP2-02 held-out K profile x interval")
            generated["g1_source.jl"] = collect(codeunits(g1_source))
            if variant === :up3_review_holdout_r14
                g2_source = _thermal_source_variant_replace_once_v1(g2_source,
                    "G2MBFaceOwnerV1(\"thermal_x_min\", :x_min, \"thermal_slab\", (-1,0,0), dirichlet(310//1)),",
                    "G2MBFaceOwnerV1(\"thermal_x_min\", :x_min, \"thermal_slab_review\", (-1,0,0), dirichlet(298//1)),",
                    "UP3 review holdout x_min temperature and region")
                g2_source = _thermal_source_variant_replace_once_v1(g2_source,
                    "G2MBFaceOwnerV1(\"thermal_x_max\", :x_max, \"thermal_slab\", (1,0,0), dirichlet(310//1)),",
                    "G2MBFaceOwnerV1(\"thermal_x_max\", :x_max, \"thermal_slab_review\", (1,0,0), dirichlet(306//1)),",
                    "UP3 review holdout x_max temperature and region")
                for face_line in (
                        "G2MBFaceOwnerV1(\"thermal_y_min\", :y_min, \"thermal_slab\", (0,-1,0), neumann_zero),",
                        "G2MBFaceOwnerV1(\"thermal_y_max\", :y_max, \"thermal_slab\", (0,1,0), neumann_zero),",
                        "G2MBFaceOwnerV1(\"thermal_z_min\", :z_min, \"thermal_slab\", (0,0,-1), neumann_zero),",
                        "G2MBFaceOwnerV1(\"thermal_z_max\", :z_max, \"thermal_slab\", (0,0,1), neumann_zero),")
                    g2_source = _thermal_source_variant_replace_once_v1(g2_source,
                        face_line, replace(face_line, "\"thermal_slab\"" =>
                            "\"thermal_slab_review\""),
                        "UP3 review holdout consistent face owner region")
                end
                generated["g2_source.jl"] = collect(codeunits(g2_source))
            end
        elseif variant === :up2_02_nonunit_yz
            g2_source = _thermal_source_variant_replace_once_v1(g2_source,
                "((2//1,0//1,0//1),(0//1,1//1,0//1),(0//1,0//1,1//1)),",
                "((2//1,0//1,0//1),(0//1,1//2,0//1),(0//1,0//1,1//4)),",
                "UP2-02 non-unit Y/Z physical chart scales")
            generated["g2_source.jl"] = collect(codeunits(g2_source))
            g1_source = String(generated["g1_source.jl"])
            g1_source = _thermal_source_variant_replace_once_v1(g1_source,
                "domain_min=(0//1, 0//1, 0//1), domain_max=(2//1, 1//1, 1//1),",
                "domain_min=(0//1, 0//1, 0//1), domain_max=(2//1, 1//2, 1//4),",
                "UP2-02 G1 K domain matches non-unit Y/Z chart scales")
            generated["g1_source.jl"] = collect(codeunits(g1_source))
        end
        generated["g2_source.jl"] = collect(codeunits(g2_source))
    end
    if up2_01_source_variant
        g1_source = String(generated["g1_source.jl"])
        old_contract = join((
            "    source_expressions.formula == \"steady_planar_quadratic_diffusion_v1\" &&",
            "        source_expressions.unknown_source_expression == \"u_candidate_steady_planar_quadratic_diffusion_v1\" &&",
            "        source_expressions.source_expression == \"f(x)=1\" ||",
            "        throw(ArgumentError(\"thermal slab G1 expression contract mismatch\"))"), "\n")
        typed_contract = join((
            "    function source_expression_ast(expression, role)",
            "        expression isa AbstractString && startswith(strip(String(expression)), \"{\") &&",
            "            occursin(\"\\\"schema\\\":\\\"fusionconceptai:genome-v5:g1-source-expression-ast-v1\\\"\", expression) &&",
            "            occursin(\"\\\"role\\\":\\\"\" * role * \"\\\"\", expression)",
            "    end",
            "    source_expression_ast(source_expressions.unknown_source_expression, \"u\") &&",
            "        source_expression_ast(source_expressions.source_expression, \"f\") ||",
            "        throw(ArgumentError(\"thermal slab G1 typed source AST contract mismatch\"))"), "\n")
        g1_source = _thermal_source_variant_replace_once_v1(g1_source,
            old_contract, typed_contract, "UP2-01 generated candidate AST source validator")
        generated["g1_source.jl"] = collect(codeunits(g1_source))
        if variant === :up2_01_transient_si
            g1_source = String(generated["g1_source.jl"])
            g1_source = _thermal_source_variant_replace_once_v1(g1_source,
                "fusionconceptai://GenomeV5/G1/source/thermal-slab-up4-v5-20261001",
                "fusionconceptai://GenomeV5/G1/source/thermal-slab-up4-v5-20261001-transient-si",
                "UP2-01 transient G1 source identity")
            g1_source = _thermal_source_variant_replace_once_v1(g1_source,
                "    static = TemporalTypeV1(static_time)",
                "    transient_clock = QualifiedRefV1(\"thermal-slab-up4-v5-20261001-transient-clock\", \"v1\")\n" *
                "    static = TemporalTypeV1(discrete_time, 0, transient_clock)",
                "UP2-01 transient G1 field temporal type")
            g1_source = replace(g1_source, "(static_time,)" => "(discrete_time,)")
            g1_source = _thermal_source_variant_replace_once_v1(g1_source,
                "u, K, f; unknown_state_binding=binding, operator_temporal_support=support)",
                "u, K, f; unknown_state_binding=binding, operator_temporal_support=support,\n" *
                "        transient_capacity=G1DiffusionTransientCapacityV1(4.0e6,\n" *
                "            UnitSignature((-1, 1, -2, 0, -1, 0, 0)), source_ref;\n" *
                "            applicable_domain=:transient_thermal_diffusion, closed=true))",
                "UP2-01 explicitly authored transient SI capacity")
            g1_source = replace(g1_source,
                "candidate-only steady SI thermal slab; typed source evaluation is not physical validation" =>
                "candidate-only transient SI thermal slab; typed source evaluation is not physical validation")
            generated["g1_source.jl"] = collect(codeunits(g1_source))
        end
    end
    if up2_01_source_variant
        expr_path = "native_mms_source_expressions.json"
        expr_text = String(generated[expr_path])
        u_ast = _thermal_up2_01_source_ast_json_v1(:u, variant)
        f_ast = _thermal_up2_01_source_ast_json_v1(:f, variant)
        expr_text = _thermal_up2_01_replace_json_string_v1(expr_text,
            "unknown_source_expression", "u_candidate_steady_planar_quadratic_diffusion_v1", u_ast)
        expr_text = _thermal_up2_01_replace_json_string_v1(expr_text,
            "source_expression", "f(x)=1", f_ast)
        generated[expr_path] = collect(codeunits(expr_text))
        if variant === :up2_01_variable_kxx_affine
            g1_source = String(generated["g1_source.jl"])
            g1_source = _thermal_source_variant_replace_once_v1(g1_source,
                "base_diag=(2//1, 3//1, 4//1), slope_diag=(0//1, 1//10, 0//1))",
                "base_diag=(2//1, 3//1, 4//1), slope_diag=(1//5, 1//10, 0//1))",
                "UP2-01 source-authored variable Kxx slope")
            generated["g1_source.jl"] = collect(codeunits(g1_source))
        end
        if variant === :up2_01_transverse_bc_negative
            g2_source = String(generated["g2_source.jl"])
            g2_source = _thermal_source_variant_replace_once_v1(g2_source,
                "G2MBFaceOwnerV1(\"thermal_y_min\", :y_min, \"thermal_slab\", (0,-1,0), neumann_zero),",
                "G2MBFaceOwnerV1(\"thermal_y_min\", :y_min, \"thermal_slab\", (0,-1,0), G2MBFaceValueV1(:neumann, 1//1, conormal)),",
                "UP2-01 nonzero transverse Neumann face")
            generated["g2_source.jl"] = collect(codeunits(g2_source))
        elseif variant === :up2_01_flux_unit_negative
            g2_source = String(generated["g2_source.jl"])
            g2_source = _thermal_source_variant_replace_once_v1(g2_source,
                "conormal = UnitSignature((0,1,-3,0,0,0,0))",
                "conormal = UnitSignature((0,1,-2,0,0,0,0))",
                "UP2-01 mismatched G2 flux-value unit")
            generated["g2_source.jl"] = collect(codeunits(g2_source))
        end
    end
    generated["g3_child_design_source.jl"] = collect(codeunits(child))

    g3_source = String(generated["g3_source.jl"])
    g3_source = _thermal_source_variant_replace_once_v1(g3_source,
        old_logical_child_path, new_logical_child_path, "G3 child source path check")
    generated["g3_source.jl"] = collect(codeunits(g3_source))

    manifest_path = joinpath(base, "manifest.json")
    manifest = replace(read(manifest_path, String), old_slug => new_slug)
    manifest = replace(manifest, "scenario-" * new_slug => "scenario-" * old_slug)
    manifest = replace(manifest, "fusionconceptai://scenario-design/" * new_slug =>
        "fusionconceptai://scenario-design/" * old_slug)
    for relative_path in _THERMAL_SOURCE_VARIANT_REQUIRED_PATHS_V1
        manifest = _thermal_source_variant_manifest_pin_v1(manifest, relative_path,
            generated[relative_path])
    end
    generated["manifest.json"] = collect(codeunits(manifest))

    if ispath(target)
        isdir(target) && !islink(target) ||
            throw(ArgumentError("thermal source variant target is not a plain directory"))
        actual_files = Set{String}()
        for (directory, directories, files) in walkdir(target)
            isempty(directories) || throw(ArgumentError("thermal source variant has unexpected subdirectories"))
            for name in files
                path = joinpath(directory, name)
                islink(path) && throw(ArgumentError("thermal source variant contains a link"))
                push!(actual_files, replace(relpath(path, target), '\\' => '/'))
            end
        end
        actual_files == Set(keys(generated)) ||
            throw(ArgumentError("thermal source variant existing file set differs"))
        for (relative_path, expected) in generated
            read(joinpath(target, split(relative_path, '/')...)) == expected ||
                throw(ArgumentError("thermal source variant existing bytes differ: $relative_path"))
        end
    else
        mkpath(target)
        for (relative_path, bytes) in generated
            write(joinpath(target, split(relative_path, '/')...), bytes)
        end
    end
    identity_text = read(joinpath(base, "identity.jl"), String)
    scenario_matches = collect(eachmatch(r"(?m)^\s*scenario_id\s*=\s*\"([^\"]+)\"", identity_text))
    length(scenario_matches) == 1 ||
        throw(ArgumentError("thermal source variant scenario identity missing or ambiguous"))
    (source_root=source_root, candidate_directory=candidate_relative,
        candidate_id=new_slug, scenario_id=only(scenario_matches).captures[1])
end
