"""UP2-EXEC-01: an isolated manufactured numerical screen.

This additive vertical slice deliberately owns its complete small execution
path.  It assembles a two-interior-DOF, variable-coefficient 1-D diffusion
stencil, validates an explicit old/new topology transfer, validates a typed
port composition plan, and performs a 2x2 joint linear solve.  The result is
software evidence for a manufactured screen only: it is not a provider, mesh,
DESC, physical, engineering, or candidate acceptance path.

The local transfer and plan records are an execution seam over the committed
SpatialTopologyTransferContractV1 and CompositionSolvePlanV1 contracts; the
shared module and registries remain untouched.
"""

using SHA

const EDC_SCHEMA_V1 = "fusionconceptai:runtime-v4:executable-diffusion-transfer-composition-v1"
const EDC_REVISION_V1 = "up2-exec-01"
const EDC_VERTICAL_SLICE_V1 = "ExecutableDiffusionTransferCompositionV1"
const EDC_CLAIM_CEILING_V1 = :manufactured_numerical_screen
const EDC_EVIDENCE_SCOPE_V1 = :screen_only
const EDC_STATUSES_V1 = (:ready, :fail_closed, :terminal_deferred, :numerical_fail)
const EDC_SOURCE_LAYERS_V1 = (:g1, :g2, :g3)

_edc_hash_text(x) = bytes2hex(SHA.sha256(codeunits(repr(x))))
_edc_text(x, field) = begin
    x isa AbstractString || throw(ArgumentError("$field must be a string"))
    s = strip(String(x)); isempty(s) && throw(ArgumentError("$field cannot be empty")); s
end
_edc_finite(x, field) = begin
    y = Float64(x); isfinite(y) || throw(ArgumentError("$field must be finite")); y
end
_edc_tuple7(xs, field) = begin
    t = Tuple(xs); length(t) == 7 || throw(ArgumentError("$field requires seven exponents"))
    ntuple(i -> Int(t[i]), 7)
end
_edc_digest(x, field) = begin
    s = lowercase(_edc_text(x, field))
    occursin(r"^[0-9a-f]{64}$", s) || throw(ArgumentError("$field must be a SHA-256 digest"))
    s
end

struct ExecutableSourceDeclarationV1
    source_ref::String
    layer::Symbol
    candidate_ref::String
    mission_ref::String
    scenario_ref::String
    content_digest::String
    function ExecutableSourceDeclarationV1(source_ref, layer, candidate_ref,
                                           mission_ref, scenario_ref, content_digest)
        new(_edc_text(source_ref, "source_ref"), layer,
            _edc_text(candidate_ref, "source candidate_ref"), _edc_text(mission_ref, "source mission_ref"),
            _edc_text(scenario_ref, "source scenario_ref"), _edc_text(content_digest, "content_digest"))
    end
end

struct ExecutableCaseBindingV1
    candidate_ref::String
    mission_ref::String
    scenario_ref::String
    source_declarations::Tuple{Vararg{ExecutableSourceDeclarationV1}}
    binding_digest::String
end

_edc_source_key(x::ExecutableSourceDeclarationV1) =
    (x.source_ref, x.layer, x.candidate_ref, x.mission_ref, x.scenario_ref, x.content_digest)

_edc_binding_key(candidate_ref, mission_ref, scenario_ref, declarations) =
    (candidate_ref, mission_ref, scenario_ref,
     Tuple(sort([_edc_source_key(x) for x in declarations], by=string)))

function ExecutableCaseBindingV1(candidate_ref, mission_ref, scenario_ref,
                                 source_declarations; binding_digest=nothing)
    c, m, s = _edc_text(candidate_ref, "candidate_ref"), _edc_text(mission_ref, "mission_ref"),
        _edc_text(scenario_ref, "scenario_ref")
    ds = Tuple(source_declarations)
    all(x -> x isa ExecutableSourceDeclarationV1, ds) ||
        throw(ArgumentError("source declarations must be typed"))
    key = _edc_binding_key(c, m, s, ds)
    digest = binding_digest === nothing ? _edc_hash_text(key) : _edc_text(binding_digest, "binding_digest")
    ExecutableCaseBindingV1(c, m, s, ds, digest)
end

function validate_executable_case_binding(binding::ExecutableCaseBindingV1)
    refs = (binding.candidate_ref, binding.mission_ref, binding.scenario_ref)
    any(x -> isempty(strip(x)), refs) &&
        return _edc_fail(:fail_closed, :binding_malformed, "candidate/mission/scenario reference is empty")
    isempty(binding.source_declarations) &&
        return _edc_fail(:fail_closed, :binding_malformed, "source declaration set is empty")
    layers = Symbol[]
    for d in binding.source_declarations
        d.layer in EDC_SOURCE_LAYERS_V1 ||
            return _edc_fail(:fail_closed, :binding_malformed, "source declaration layer is invalid")
        push!(layers, d.layer)
        try
            _edc_digest(d.content_digest, "content_digest")
        catch
            return _edc_fail(:fail_closed, :binding_malformed, "source declaration digest is malformed")
        end
        (d.candidate_ref == binding.candidate_ref && d.mission_ref == binding.mission_ref &&
         d.scenario_ref == binding.scenario_ref) ||
            return _edc_fail(:fail_closed, :binding_mismatch, "source declaration is not bound to case identity")
    end
    sort(layers) == collect(EDC_SOURCE_LAYERS_V1) && length(unique(layers)) == 3 ||
        return _edc_fail(:fail_closed, :binding_malformed, "exactly one G1/G2/G3 source declaration is required")
    expected = _edc_hash_text(_edc_binding_key(binding.candidate_ref, binding.mission_ref,
        binding.scenario_ref, binding.source_declarations))
    binding.binding_digest == expected ||
        return _edc_fail(:fail_closed, :binding_mismatch, "binding digest does not match declarations")
    ExecutableValidationV1(true, :ready, :valid_case_binding, "case identity and source declarations are digest-bound", 0.0)
end

struct ExecutableDiffusionUnitV1
    quantity::Symbol
    exponents::NTuple{7,Int}
    scale_to_si::Float64
    function ExecutableDiffusionUnitV1(quantity, exponents; scale_to_si=1.0)
        quantity isa Symbol || throw(ArgumentError("unit quantity must be Symbol"))
        quantity in (:field, :source, :flux, :coefficient, :dimensionless) ||
            throw(ArgumentError("unknown typed quantity"))
        scale = _edc_finite(scale_to_si, "unit scale")
        scale > 0.0 || throw(ArgumentError("unit scale must be positive"))
        new(quantity, _edc_tuple7(exponents, "unit exponents"), scale)
    end
end

"Typed equation-level unit bundle; role/exponent closure is checked at dispatch."
struct ExecutableDiffusionEquationUnitsV1
    k_unit::ExecutableDiffusionUnitV1
    source_unit::ExecutableDiffusionUnitV1
    boundary_unit::ExecutableDiffusionUnitV1
    function ExecutableDiffusionEquationUnitsV1(k_unit, source_unit, boundary_unit)
        k_unit isa ExecutableDiffusionUnitV1 && source_unit isa ExecutableDiffusionUnitV1 &&
            boundary_unit isa ExecutableDiffusionUnitV1 || throw(ArgumentError("equation units must be typed"))
        all(isfinite, (k_unit.scale_to_si, source_unit.scale_to_si, boundary_unit.scale_to_si)) &&
            all(x -> x > 0.0, (k_unit.scale_to_si, source_unit.scale_to_si, boundary_unit.scale_to_si)) ||
            throw(ArgumentError("equation unit scales must be finite and positive"))
        new(k_unit, source_unit, boundary_unit)
    end
end

_edc_unit_key(u::ExecutableDiffusionUnitV1) =
    (u.quantity, u.exponents, u.scale_to_si)

"Topology references are explicit, while labels remain diagnostic only."
struct ExecutableTopologyIdentityV1
    topology_ref::String
    space_ref::String
    dof_count::Int
    spacing::Float64
    dof_labels::Tuple{Vararg{String}}
    state_values::NTuple{2,Float64}
    state_semantics::Symbol
    semantic_digest::String
    function ExecutableTopologyIdentityV1(topology_ref, space_ref, dof_count,
                                         spacing, dof_labels; state_values=(0.0, 0.0),
                                         state_semantics=:pre_transfer,
                                         semantic_digest=nothing)
        tr, sr = _edc_text(topology_ref, "topology_ref"), _edc_text(space_ref, "space_ref")
        n = Int(dof_count); n == 2 || throw(ArgumentError("screen requires two interior DOFs"))
        h = _edc_finite(spacing, "spacing"); h > 0.0 || throw(ArgumentError("spacing must be positive"))
        labels = Tuple(_edc_text(x, "dof label") for x in dof_labels)
        length(labels) == n || throw(ArgumentError("dof label count does not match topology"))
        values = Tuple(state_values); length(values) == 2 || throw(ArgumentError("state value count does not match topology"))
        state = (_edc_finite(values[1], "topology state"), _edc_finite(values[2], "topology state"))
        state_semantics in (:pre_transfer, :expected_post_transfer) ||
            throw(ArgumentError("invalid topology state semantics"))
        key = _edc_topology_semantic_key(tr, sr, n, h, state, state_semantics)
        digest = semantic_digest === nothing ? _edc_hash_text(key) : _edc_text(semantic_digest, "topology semantic_digest")
        new(tr, sr, n, h, labels, state, state_semantics, digest)
    end
end

_edc_topology_semantic_key(topology_ref, space_ref, dof_count, spacing,
                           state_values, state_semantics) =
    (topology_ref=topology_ref, space_ref=space_ref, dof_count=dof_count,
     spacing=spacing, state_values=state_values, state_semantics=state_semantics)

_edc_topology_expected_digest(t::ExecutableTopologyIdentityV1) = _edc_hash_text(
    _edc_topology_semantic_key(t.topology_ref, t.space_ref, t.dof_count,
        t.spacing, t.state_values, t.state_semantics))

function validate_executable_topology_identity(t::ExecutableTopologyIdentityV1, side::Symbol)
    side in (:old, :new) || return _edc_fail(:fail_closed, :topology_identity_mismatch, "invalid topology side")
    if isempty(strip(t.topology_ref)) || isempty(strip(t.space_ref)) || t.dof_count != 2
        return _edc_fail(:fail_closed, :topology_identity_mismatch, "topology identity fields are incomplete")
    end
    if !(isfinite(t.spacing) && t.spacing > 0.0 && all(isfinite, t.state_values))
        return _edc_fail(:fail_closed, :nonfinite_derived, "topology spacing/state is nonfinite")
    end
    expected_semantics = side === :old ? :pre_transfer : :expected_post_transfer
    if t.state_semantics !== expected_semantics
        return _edc_fail(:fail_closed, :topology_state_semantics_mismatch,
            "topology state is not declared as the required pre/post-transfer state")
    end
    if t.semantic_digest != _edc_topology_expected_digest(t)
        return _edc_fail(:fail_closed, :topology_identity_mismatch, "topology semantic digest mismatch")
    end
    ExecutableValidationV1(true, :ready, Symbol(:valid_, side, :_topology), "full topology identity is digest-valid", 0.0)
end

struct ExecutableTopologyTransferV1
    old::ExecutableTopologyIdentityV1
    new::ExecutableTopologyIdentityV1
    overlap::NTuple{2,Float64}
    weights::NTuple{2,Float64}
    transfer_ref::String
    # Typed terminal constructor prevents the normalizing outer constructor
    # from redispatching itself when all values are already normalized.
    function ExecutableTopologyTransferV1(old::ExecutableTopologyIdentityV1,
                                          new_topology::ExecutableTopologyIdentityV1,
                                          overlap::NTuple{2,Float64},
                                          weights::NTuple{2,Float64},
                                          transfer_ref::String)
        new(old, new_topology, overlap, weights, transfer_ref)
    end
function ExecutableTopologyTransferV1(old, new_topology, overlap, weights, transfer_ref)
        old isa ExecutableTopologyIdentityV1 && new_topology isa ExecutableTopologyIdentityV1 ||
            throw(ArgumentError("transfer requires typed old/new topology identities"))
        ov, wt = Tuple(overlap), Tuple(weights)
        length(ov) == 2 && length(wt) == 2 || throw(ArgumentError("overlap/weights require two entries"))
        ref = _edc_text(transfer_ref, "transfer_ref")
        new(old, new_topology,
            (_edc_finite(ov[1], "overlap lower"), _edc_finite(ov[2], "overlap upper")),
            (_edc_finite(wt[1], "transfer weight"), _edc_finite(wt[2], "transfer weight")), ref)
    end
end

struct ExecutableTransferReceiptV1
    source_topology_digest::String
    target_topology_digest::String
    old_state::NTuple{2,Float64}
    new_state::NTuple{2,Float64}
    declared_target_state::NTuple{2,Float64}
    overlap::NTuple{2,Float64}
    weights::NTuple{2,Float64}
    receipt_hash::String
end

function apply_old_to_new_state(t::ExecutableTopologyTransferV1)
    w1, w2 = t.weights; x1, x2 = t.old.state_values
    y = (w1*x1 + (1.0-w1)*x2, (1.0-w2)*x1 + w2*x2)
    all(isfinite, y) || throw(ArgumentError("transferred state is nonfinite"))
    t.old.state_semantics === :pre_transfer || throw(ArgumentError("source state is not pre-transfer"))
    t.new.state_semantics === :expected_post_transfer || throw(ArgumentError("target state is not expected post-transfer"))
    all(isapprox(y[i], t.new.state_values[i]; atol=1e-12, rtol=0.0) for i in 1:2) ||
        throw(ArgumentError("transferred state does not equal declared post-transfer target state"))
    key = (source_topology_digest=_edc_topology_expected_digest(t.old),
        target_topology_digest=_edc_topology_expected_digest(t.new), old_state=t.old.state_values,
        new_state=y, declared_target_state=t.new.state_values, overlap=t.overlap, weights=t.weights)
    ExecutableTransferReceiptV1(key.source_topology_digest, key.target_topology_digest,
        t.old.state_values, y, t.new.state_values, t.overlap, t.weights, _edc_hash_text(key))
end

struct ExecutableDiffusionInputsV1
    k_faces::NTuple{3,Float64}
    source::NTuple{2,Float64}
    boundary::NTuple{2,Float64}
    equation_units::ExecutableDiffusionEquationUnitsV1
    function ExecutableDiffusionInputsV1(k_faces, source, boundary; equation_units=(
            k_unit=ExecutableDiffusionUnitV1(:coefficient, (2,0,0,0,0,0,0)),
            source_unit=ExecutableDiffusionUnitV1(:source, (0,0,0,0,0,0,0)),
            boundary_unit=ExecutableDiffusionUnitV1(:field, (0,0,0,0,0,0,0))))
        k, f, b = Tuple(k_faces), Tuple(source), Tuple(boundary)
        length(k) == 3 && length(f) == 2 && length(b) == 2 ||
            throw(ArgumentError("two-DOF screen requires K[3], source[2], boundary[2]"))
        kk = ntuple(i -> begin x = _edc_finite(k[i], "K face"); x > 0.0 || throw(ArgumentError("K must be positive")); x end, 3)
        hasproperty(equation_units, :k_unit) && hasproperty(equation_units, :source_unit) &&
            hasproperty(equation_units, :boundary_unit) || throw(ArgumentError("equation units are incomplete"))
        ku, su, bu = equation_units.k_unit, equation_units.source_unit, equation_units.boundary_unit
        typed_units = ExecutableDiffusionEquationUnitsV1(ku, su, bu)
        new(kk, ntuple(i -> _edc_finite(f[i], "source"), 2),
            ntuple(i -> _edc_finite(b[i], "boundary"), 2),
            typed_units)
    end
end

function validate_diffusion_equation_units(inputs::ExecutableDiffusionInputsV1)
    ku, su, bu = inputs.equation_units.k_unit, inputs.equation_units.source_unit, inputs.equation_units.boundary_unit
    ku.quantity === :coefficient && su.quantity === :source && bu.quantity === :field ||
        return _edc_fail(:fail_closed, :equation_unit_mismatch, "K/source/boundary quantity roles are incompatible")
    ku.exponents[1] == 2 ||
        return _edc_fail(:fail_closed, :equation_unit_mismatch, "coefficient unit must carry the one-dimensional K exponent")
    all(isfinite, (ku.scale_to_si, su.scale_to_si, bu.scale_to_si)) &&
        all(x -> x > 0.0, (ku.scale_to_si, su.scale_to_si, bu.scale_to_si)) ||
        return _edc_fail(:fail_closed, :nonfinite_derived, "equation unit scale is nonfinite or nonpositive")
    expected_source = ntuple(i -> ku.exponents[i] + bu.exponents[i] - (i == 1 ? 2 : 0), 7)
    su.exponents == expected_source ||
        return _edc_fail(:fail_closed, :equation_unit_mismatch, "source unit does not close -div(K grad u)=f")
    ExecutableValidationV1(true, :ready, :valid_equation_units, "equation-level K/source/boundary units close", 0.0)
end

struct ExecutableAccountKeyV1
    account_ref::String
    quantity::Symbol
    unit::ExecutableDiffusionUnitV1
end

struct ExecutableAccountEffectV1
    key::ExecutableAccountKeyV1
    direction::Symbol
    signed_value::Float64
end

struct ExecutableTypedPortV1
    port_ref::String
    direction::Symbol
    unit::ExecutableDiffusionUnitV1
    account_ref::String
    account_key::ExecutableAccountKeyV1
    ledger_sign::Int
    function ExecutableTypedPortV1(port_ref, direction, unit, account_ref, ledger_sign)
        direction in (:input, :output) || throw(ArgumentError("port direction must be input/output"))
        unit isa ExecutableDiffusionUnitV1 || throw(ArgumentError("port unit must be typed"))
        sign = Int(ledger_sign); abs(sign) == 1 || throw(ArgumentError("port ledger sign must be +/-1"))
        direction === :output && sign == 1 || direction === :input && sign == -1 ||
            throw(ArgumentError("port sign must follow output/input direction"))
        account = _edc_text(account_ref, "account_ref")
        key = ExecutableAccountKeyV1(account, unit.quantity, unit)
        new(_edc_text(port_ref, "port_ref"), direction, unit, account, key, sign)
    end
end

_edc_effect(p::ExecutableTypedPortV1) = ExecutableAccountEffectV1(
    ExecutableAccountKeyV1(p.account_ref, p.unit.quantity, p.unit), p.direction, Float64(p.ledger_sign))
_edc_account_key(p::ExecutableTypedPortV1) = p.account_key
_edc_effect_key(e::ExecutableAccountEffectV1) =
    (e.key.account_ref, e.key.quantity, _edc_unit_key(e.key.unit))

struct ExecutableComponentV1
    component_ref::String
    ports::Tuple{Vararg{ExecutableTypedPortV1}}
    function ExecutableComponentV1(component_ref, ports)
        ps = Tuple(ports); all(p -> p isa ExecutableTypedPortV1, ps) ||
            throw(ArgumentError("components require typed ports"))
        new(_edc_text(component_ref, "component_ref"), ps)
    end
end

struct ExecutableCompositionPlanV1
    components::Tuple{Vararg{ExecutableComponentV1}}
    plan_ref::String
    function ExecutableCompositionPlanV1(components, plan_ref)
        cs = Tuple(components); isempty(cs) && throw(ArgumentError("composition plan cannot be empty"))
        all(c -> c isa ExecutableComponentV1, cs) || throw(ArgumentError("plan components must be typed"))
        new(cs, _edc_text(plan_ref, "plan_ref"))
    end
end

struct ExecutableValidationV1
    valid::Bool
    status::Symbol
    code::Symbol
    detail::String
    conservation_residual::Float64
end

struct ExecutableDiffusionAssemblyV1
    matrix::NTuple{2,NTuple{2,Float64}}
    rhs::NTuple{2,Float64}
    initial_state::NTuple{2,Float64}
    transfer_receipt_hash::String
    assembly_hash::String
end

struct ExecutableDiffusionReceiptV1
    binding_digest::String
    old_topology_digest::String
    new_topology_digest::String
    transfer_receipt_hash::String
    assembly_hash::String
    result_hash::String
    status::Symbol
    receipt_hash::String
end

struct ExecutableDiffusionCaseV1
    binding::ExecutableCaseBindingV1
    old_topology::ExecutableTopologyIdentityV1
    new_topology::ExecutableTopologyIdentityV1
    transfer::ExecutableTopologyTransferV1
    inputs::ExecutableDiffusionInputsV1
    plan::ExecutableCompositionPlanV1
end

function ExecutableDiffusionCaseV1(binding, old_topology, new_topology, transfer, inputs, plan)
    binding isa ExecutableCaseBindingV1 && old_topology isa ExecutableTopologyIdentityV1 &&
        new_topology isa ExecutableTopologyIdentityV1 && transfer isa ExecutableTopologyTransferV1 &&
        inputs isa ExecutableDiffusionInputsV1 && plan isa ExecutableCompositionPlanV1 ||
        throw(ArgumentError("screen case fields must be typed"))
    ExecutableDiffusionCaseV1(binding, old_topology, new_topology, transfer, inputs, plan)
end

function _edc_receipt(binding_digest, transfer_receipt, assembly_hash, solution, residual, status)
    old_digest = transfer_receipt === nothing ? "" : transfer_receipt.source_topology_digest
    new_digest = transfer_receipt === nothing ? "" : transfer_receipt.target_topology_digest
    transfer_hash = transfer_receipt === nothing ? "" : transfer_receipt.receipt_hash
    result_hash = _edc_hash_text((solution=solution, residual=residual, status=status))
    key = (binding_digest=binding_digest, old_topology_digest=old_digest,
        new_topology_digest=new_digest, transfer_receipt_hash=transfer_hash,
        assembly_hash=assembly_hash, result_hash=result_hash, status=status)
    ExecutableDiffusionReceiptV1(binding_digest, old_digest, new_digest, transfer_hash,
        assembly_hash, result_hash, status, _edc_hash_text(key))
end

function _edc_invalid_outcome(status, code, detail, binding_digest="")
    receipt = _edc_receipt(binding_digest, nothing, "", nothing, 0.0, status)
    ExecutableDiffusionOutcomeV1(status, code, String(detail), nothing, nothing, 0.0, "", 0, 0, 0,
        EDC_CLAIM_CEILING_V1, EDC_EVIDENCE_SCOPE_V1, false, binding_digest, nothing, receipt)
end

struct ExecutableDiffusionOutcomeV1
    status::Symbol
    code::Symbol
    detail::String
    assembly::Union{Nothing,ExecutableDiffusionAssemblyV1}
    solution::Union{Nothing,NTuple{2,Float64}}
    residual_norm::Float64
    assembly_hash::String
    provider_call_count::Int
    mesh_call_count::Int
    solver_invocation_count::Int
    claim_ceiling::Symbol
    evidence_scope::Symbol
    accepted::Bool
    binding_digest::String
    transfer_receipt::Union{Nothing,ExecutableTransferReceiptV1}
    receipt::ExecutableDiffusionReceiptV1
end

_edc_fail(status, code, detail; conservation_residual=0.0) =
    ExecutableValidationV1(false, status, code, String(detail), Float64(conservation_residual))

function validate_executable_transfer(t::ExecutableTopologyTransferV1)
    old_validation = validate_executable_topology_identity(t.old, :old)
    old_validation.valid || return old_validation
    new_validation = validate_executable_topology_identity(t.new, :new)
    new_validation.valid || return new_validation
    lo, hi = t.overlap
    isfinite(lo) && isfinite(hi) && 0.0 <= lo < hi <= 1.0 ||
        return _edc_fail(:terminal_deferred, :invalid_overlap, "overlap must be a non-empty subset of [0,1]")
    all(isfinite, t.weights) && all(x -> x >= 0.0, t.weights) ||
        return _edc_fail(:fail_closed, :invalid_overlap, "transfer weights must be finite and nonnegative")
    isapprox(sum(t.weights), 1.0; atol=1e-12) ||
        return _edc_fail(:fail_closed, :invalid_overlap, "transfer weights must close to one")
    t.old.space_ref == t.new.space_ref ||
        return _edc_fail(:fail_closed, :topology_space_mismatch, "old/new spaces differ")
    try
        receipt = apply_old_to_new_state(t)
        all(isfinite, receipt.new_state) ||
            return _edc_fail(:fail_closed, :nonfinite_derived, "transferred state is nonfinite")
    catch err
        message = string(err)
        code = occursin("state", lowercase(message)) ? :transfer_state_mismatch : :invalid_overlap
        return _edc_fail(:fail_closed, code, message)
    end
    ExecutableValidationV1(true, :ready, :valid_transfer, "old/new topology overlap and transfer are valid", 0.0)
end

_edc_port_type(p::ExecutableTypedPortV1) = (p.unit.quantity, p.unit.exponents, p.unit.scale_to_si)
_edc_component_key(c::ExecutableComponentV1) = begin
    # component_ref, port_ref, and account_ref are labels; typed fields and
    # ledger signs determine the canonical executable structure.
    ports = sort([(_edc_port_type(p), p.direction, p.ledger_sign) for p in c.ports], by=string)
    Tuple(ports)
end

"Validate typed routing, producer uniqueness, units, and account conservation."
function validate_executable_composition(plan::ExecutableCompositionPlanV1)
    components = plan.components
    outputs = ExecutableTypedPortV1[]; inputs = ExecutableTypedPortV1[]
    for c in components, p in c.ports
        p.direction === :output ? push!(outputs, p) : push!(inputs, p)
    end
    for input in inputs
        same_route = [p for p in outputs if p.account_ref == input.account_ref &&
                      p.unit.quantity == input.unit.quantity]
        compatible = [p for p in same_route if p.unit.exponents == input.unit.exponents &&
                      isequal(p.unit.scale_to_si, input.unit.scale_to_si)]
        length(compatible) > 1 && return _edc_fail(:fail_closed, :duplicate_producer, "more than one typed producer matches an input")
        isempty(compatible) && !isempty(same_route) &&
            return _edc_fail(:fail_closed, :unit_mismatch, "producer/input account quantity unit does not match")
        isempty(compatible) &&
            return _edc_fail(:fail_closed, :missing_closure, "input has no typed producer")
    end
    totals = Dict{Any,Float64}()
    for p in (outputs..., inputs...)
        effect = _edc_effect(p)
        key = _edc_effect_key(effect)
        totals[key] = get(totals, key, 0.0) + effect.signed_value
    end
    residual = sum(abs(v) for v in values(totals))
    isfinite(residual) || return _edc_fail(:fail_closed, :nonfinite_derived, "conservation residual is nonfinite")
    residual == 0.0 ||
        return _edc_fail(:fail_closed, :missing_closure, "typed account ledger does not close";
            conservation_residual=residual)
    ExecutableValidationV1(true, :ready, :valid_composition, "typed ports route uniquely and conserve accounts", residual)
end

"Assemble -div(K grad u)=f with two interior unknowns and Dirichlet boundaries." 
function assemble_variable_coefficient_diffusion(inputs::ExecutableDiffusionInputsV1,
                                                 topology::ExecutableTopologyIdentityV1,
                                                 transfer::ExecutableTopologyTransferV1,
                                                 plan::ExecutableCompositionPlanV1; binding_digest="")
    transfer_admission = validate_executable_transfer(transfer)
    transfer_admission.valid || throw(ArgumentError(string("transfer admission rejected: ",
        transfer_admission.status, ":", transfer_admission.code, ":", transfer_admission.detail)))
    composition_admission = validate_executable_composition(plan)
    composition_admission.valid || throw(ArgumentError(string("composition admission rejected: ",
        composition_admission.status, ":", composition_admission.code, ":", composition_admission.detail)))
    topology_validation = validate_executable_topology_identity(topology, :new)
    topology_validation.valid || throw(ArgumentError(topology_validation.detail))
    transfer_target_validation = validate_executable_topology_identity(transfer.new, :new)
    transfer_target_validation.valid || throw(ArgumentError(transfer_target_validation.detail))
    topology.semantic_digest == transfer.new.semantic_digest ||
        throw(ArgumentError("assembly topology must match transfer.new by full semantic digest"))
    unit_validation = validate_diffusion_equation_units(inputs)
    unit_validation.valid || throw(ArgumentError(unit_validation.detail))
    transfer_receipt = apply_old_to_new_state(transfer)
    h2 = topology.spacing * topology.spacing
    isfinite(h2) && h2 > 0.0 || throw(ArgumentError("derived h² is nonfinite"))
    k1, k2, k3 = inputs.k_faces
    a11, a12 = (k1 + k2) / h2, -k2 / h2
    a21, a22 = -k2 / h2, (k2 + k3) / h2
    b1 = inputs.source[1] + k1 * inputs.boundary[1] / h2
    b2 = inputs.source[2] + k3 * inputs.boundary[2] / h2
    matrix = ((a11, a12), (a21, a22)); rhs = (b1, b2)
    all(isfinite, (a11, a12, a21, a22, b1, b2)) || throw(ArgumentError("derived matrix or RHS is nonfinite"))
    # Include all numerical drivers and typed structure; labels are intentionally erased.
    semantic = string("K=", inputs.k_faces, ";source=", inputs.source,
        ";boundary=", inputs.boundary, ";h=", topology.spacing,
        ";binding=", binding_digest, ";old_topology=", transfer.old.semantic_digest,
        ";new_topology=", transfer.new.semantic_digest,
        ";transfer=", transfer.overlap, ":", transfer.weights,
        ":state=", transfer_receipt.new_state, ":receipt=", transfer_receipt.receipt_hash,
        ";components=", sort([_edc_component_key(c) for c in plan.components], by=string),
        ";A=", matrix, ";b=", rhs)
    ExecutableDiffusionAssemblyV1(matrix, rhs, transfer_receipt.new_state,
        transfer_receipt.receipt_hash, _edc_hash_text(semantic))
end

function solve_joint_linear_screen(assembly::ExecutableDiffusionAssemblyV1)
    a, b = assembly.matrix[1]; c, d = assembly.matrix[2]; r1, r2 = assembly.rhs
    all(isfinite, (a, b, c, d, r1, r2, assembly.initial_state[1], assembly.initial_state[2])) ||
        return nothing, 0.0, :numerical_fail, :nonfinite_derived
    det = a * d - b * c
    isfinite(det) || return nothing, 0.0, :numerical_fail, :nonfinite_derived
    abs(det) <= 1e-14 && return nothing, 0.0, :numerical_fail, :singular_matrix
    q1 = r1 - (a * assembly.initial_state[1] + b * assembly.initial_state[2])
    q2 = r2 - (c * assembly.initial_state[1] + d * assembly.initial_state[2])
    correction = ((q1 * d - b * q2) / det, (a * q2 - q1 * c) / det)
    x = (assembly.initial_state[1] + correction[1], assembly.initial_state[2] + correction[2])
    all(isfinite, x) || return nothing, 0.0, :numerical_fail, :nonfinite_derived
    e1, e2 = a * x[1] + b * x[2] - r1, c * x[1] + d * x[2] - r2
    residual = sqrt(e1 * e1 + e2 * e2)
    isfinite(residual) || return nothing, 0.0, :numerical_fail, :nonfinite_derived
    x, residual, :ready, :joint_linear_solved
end

function execute_executable_diffusion_screen(case)
    case isa ExecutableDiffusionCaseV1 || throw(ArgumentError("screen case must be typed ExecutableDiffusionCaseV1"))
    binding_validation = validate_executable_case_binding(case.binding)
    binding_validation.valid || return _edc_invalid_outcome(binding_validation.status,
        binding_validation.code, binding_validation.detail, case.binding.binding_digest)
    transfer_validation = validate_executable_transfer(case.transfer)
    transfer_validation.valid ||
        return _edc_invalid_outcome(transfer_validation.status, transfer_validation.code,
            transfer_validation.detail, case.binding.binding_digest)
    case.transfer.old.semantic_digest == case.old_topology.semantic_digest &&
        case.transfer.new.semantic_digest == case.new_topology.semantic_digest ||
        return _edc_invalid_outcome(:fail_closed, :topology_identity_mismatch,
            "case topology identities do not match transfer", case.binding.binding_digest)
    unit_validation = validate_diffusion_equation_units(case.inputs)
    unit_validation.valid || return _edc_invalid_outcome(unit_validation.status,
        unit_validation.code, unit_validation.detail, case.binding.binding_digest)
    composition_validation = validate_executable_composition(case.plan)
    composition_validation.valid ||
        return _edc_invalid_outcome(composition_validation.status, composition_validation.code,
            composition_validation.detail, case.binding.binding_digest)
    assembly = assemble_variable_coefficient_diffusion(case.inputs, case.new_topology,
        case.transfer, case.plan; binding_digest=case.binding.binding_digest)
    transfer_receipt = apply_old_to_new_state(case.transfer)
    solution, residual, status, code = solve_joint_linear_screen(assembly)
    receipt = _edc_receipt(case.binding.binding_digest, transfer_receipt,
        assembly.assembly_hash, solution, residual, status)
    ExecutableDiffusionOutcomeV1(status, code, String(code), assembly, solution, residual,
        assembly.assembly_hash, 0, 0, 1, EDC_CLAIM_CEILING_V1,
        EDC_EVIDENCE_SCOPE_V1, false, case.binding.binding_digest, transfer_receipt, receipt)
end

"Manufactured/test-only case constructor: candidate identity is metadata, not acceptance evidence."
function manufactured_executable_diffusion_case(; candidate_ref="candidate:manufactured-up2-exec-01",
        mission_ref="mission:manufactured-screen", scenario_ref="scenario:two-dof-diffusion",
        inputs=ExecutableDiffusionInputsV1((1.0, 2.0, 1.5), (1.0, -0.5), (0.0, 1.0)),
        plan=nothing, transfer=nothing)
    old = ExecutableTopologyIdentityV1("topology:old", "space:manufactured", 2, 1/3,
        ("old-left", "old-right"); state_values=(0.25, 0.75), state_semantics=:pre_transfer)
    new = ExecutableTopologyIdentityV1("topology:new", "space:manufactured", 2, 1/3,
        ("new-left", "new-right"); state_values=(0.625, 0.625), state_semantics=:expected_post_transfer)
    tr = transfer === nothing ? ExecutableTopologyTransferV1(old, new, (0.0, 1.0), (0.25, 0.75), "transfer:old-to-new") : transfer
    unit = ExecutableDiffusionUnitV1(:field, (0,0,0,0,0,0,0))
    p = plan === nothing ? ExecutableCompositionPlanV1((
        ExecutableComponentV1("source-component", (ExecutableTypedPortV1("source-out", :output, unit, "field", 1),)),
        ExecutableComponentV1("diffusion-component", (ExecutableTypedPortV1("field-in", :input, unit, "field", -1),))),
        "plan:manufactured-composition") : plan
    c, m, s = String(candidate_ref), String(mission_ref), String(scenario_ref)
    declarations = (
        ExecutableSourceDeclarationV1("source:g1-manufactured", :g1, c, m, s, _edc_hash_text("g1-manufactured")),
        ExecutableSourceDeclarationV1("source:g2-manufactured", :g2, c, m, s, _edc_hash_text("g2-manufactured")),
        ExecutableSourceDeclarationV1("source:g3-manufactured", :g3, c, m, s, _edc_hash_text("g3-manufactured")))
    binding = ExecutableCaseBindingV1(c, m, s, declarations)
    ExecutableDiffusionCaseV1(binding, old, new, tr, inputs, p)
end
