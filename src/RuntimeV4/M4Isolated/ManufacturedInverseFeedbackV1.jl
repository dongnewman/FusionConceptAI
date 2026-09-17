"""Isolated M5 inverse-realization and engineering-feedback fixture.

This lane is intentionally a pure, exact-rational manufactured example.  It
consumes only the already frozen M4-D and M5-A typed values/identities; it does
not instantiate any external runtime path.  The small response family is

    A(alpha,beta) = [ alpha  -beta; -beta  alpha ], rhs = [1, 0].

All arithmetic in the fixture is performed with ``M4RationalV1``.  A
denominator of zero is retained as a typed invalid value and is never silently
converted to a floating approximation.
"""

using SHA

# Loading this file in the isolated M4 test module must remain independent of
# the package entry point.  M5-A in turn loads the exact M4-A..M4-D sources.
if !isdefined(@__MODULE__, :ManufacturedAutoCompositionV1)
    include(joinpath(@__DIR__, "ManufacturedAutoCompositionV1.jl"))
end

const M5I_SCHEMA_V1 = "M5-INVERSE-FEEDBACK-MANUFACTURED-V1"
const M5I_CLAIM_CEILING_V1 = :manufactured_inverse_feedback
const M5I_EVIDENCE_SCOPE_V1 = :screen_only
const M5I_SEEDS_V1 = (0, 1, 2)
const M5I_TARGET_V1 = (M4RationalV1(2, 3), M4RationalV1(1, 3))
const M5I_HIDDEN_V1 = (alpha=M4RationalV1(2, 1), beta=M4RationalV1(1, 1))
const M5I_RHS_V1 = (M4RationalV1(1, 1), M4RationalV1(0, 1))

# These are frozen input identities from the M5 scope decision.  They are
# values, rather than hashes inferred from a mutable checkout.
const M5I_M4D_SOURCE_SHA256_V1 = Digest256("ec7e82e282f1d1292ddd4b7902e4ced641d926af82119298267011d304a55785")
const M5I_M4D_TEST_SHA256_V1 = Digest256("1eb0e26e79b9899cc5a3cb2742545cbaa811fa6683fdcfa1ee4dd31dff081686")
const M5I_M4D_ORACLE_SHA256_V1 = Digest256("9ca3c1c012690c7c06579d0ab5ffd274666e340c900c59e49f7a93408a0fcbe3")
const M5I_M5A_SOURCE_SHA256_V1 = Digest256("284094e7781f41075915ab0f3b930e17e099e1fa45853218f2f639ea57e1a209")
const M5I_M5A_TEST_SHA256_V1 = Digest256("42562f02370f8f2e32c8e0254e0f480d69e598be747aae9898c3fc4d013b2a08")
const M5I_M5A_ORACLE_SHA256_V1 = Digest256("e9f13fc57a59efa78dd131dfc3fde7433c21d6172dc2d81f03c034c4be13084c")
const M5I_M4D_TYPED_IDENTITY_V1 = digest256_text(string("M5A|D|", M5I_M4D_SOURCE_SHA256_V1.value))

const M5I_ACTIVE_RESPONSE_V1 = (M4RationalV1(2, 3), M4RationalV1(1, 3))
const M5I_DELETED_RESPONSE_V1 = (M4RationalV1(1, 2), M4RationalV1(0, 1))
const M5I_RESPONSE_DELTA_V1 = (M4RationalV1(1, 6), M4RationalV1(1, 3))

struct ManufacturedInverseFeedbackFailureV1
    code::Symbol
    path::String
    detail::String
end

_m5i_failure(code::Symbol, path::AbstractString, detail::AbstractString) =
    ManufacturedInverseFeedbackFailureV1(code, String(path), String(detail))

"""The exact forward response and matrix for one parameter pair."""
struct ManufacturedInverseForwardV1
    alpha::M4RationalV1
    beta::M4RationalV1
    matrix::NTuple{2,NTuple{2,M4RationalV1}}
    rhs::NTuple{2,M4RationalV1}
    response::NTuple{2,M4RationalV1}
    determinant::M4RationalV1
end

"""Immutable manufactured inverse plus the engineering feedback ledger."""
struct ManufacturedInverseFeedbackV1
    schema::String
    target::NTuple{2,M4RationalV1}
    rhs::NTuple{2,M4RationalV1}
    recovered_alpha::M4RationalV1
    recovered_beta::M4RationalV1
    forward::ManufacturedInverseForwardV1
    determinant::M4RationalV1
    eigenvalues::NTuple{2,M4RationalV1}
    eigen_margin_proxy::M4RationalV1
    roundtrip_residual::NTuple{2,M4RationalV1}
    multi_seed::Tuple
    feedback_interface_edge::String
    feedback_active_response::NTuple{2,M4RationalV1}
    deletion_beta::M4RationalV1
    deletion_response::NTuple{2,M4RationalV1}
    feedback_response_delta::NTuple{2,M4RationalV1}
    response_changed::Bool
    m4d_source_sha256::Digest256
    m4d_test_sha256::Digest256
    m4d_oracle_sha256::Digest256
    m4d_typed_identity::Digest256
    m5a_source_sha256::Digest256
    m5a_test_sha256::Digest256
    m5a_oracle_sha256::Digest256
    m5a_typed_identity::Digest256
    m5a_composition_hash::Digest256
    m4d_upstream::ManufacturedCoupledSolveControlV1
    m5a_upstream::ManufacturedAutoCompositionV1
    owner_bindings::NamedTuple
    provenance_bindings::NamedTuple
    claim_ceiling::Symbol
    evidence_scope::Symbol
end

struct ManufacturedInverseFeedbackResultV1
    valid::Bool
    status::Symbol
    inverse::Union{Nothing,ManufacturedInverseFeedbackV1}
    failures::Tuple{Vararg{ManufacturedInverseFeedbackFailureV1}}
    claim_ceiling::Symbol
    evidence_scope::Symbol
end

const ManufacturedInverseFeedbackValidationV1 = ManufacturedInverseFeedbackResultV1

_m5i_failure_tuple(fs) = Tuple(ManufacturedInverseFeedbackFailureV1[f for f in fs])
_m5i_invalid(fs; status::Symbol=:typed_failure) =
    ManufacturedInverseFeedbackResultV1(false, status, nothing, _m5i_failure_tuple(fs),
        M5I_CLAIM_CEILING_V1, M5I_EVIDENCE_SCOPE_V1)

_m5i_rat(x::M4RationalV1) = x
_m5i_rat(x::Integer) = M4RationalV1(Int(x), 1)
_m5i_rat(x) = nothing

function _m5i_norm(n::Integer, d::Integer)
    d == 0 && return M4RationalV1(Int(n), 0)
    nn, dd = Int(n), Int(d)
    dd < 0 && ((nn, dd) = (-nn, -dd))
    g = gcd(abs(nn), dd)
    M4RationalV1(nn ÷ g, dd ÷ g)
end

_m5i_valid(r::M4RationalV1) = r.denominator != 0
_m5i_zero(r::M4RationalV1) = _m5i_valid(r) && r.numerator == 0
_m5i_equal(a::M4RationalV1, b::M4RationalV1) =
    _m5i_valid(a) && _m5i_valid(b) && a.numerator * b.denominator == b.numerator * a.denominator
_m5i_add(a::M4RationalV1, b::M4RationalV1) =
    (!_m5i_valid(a) || !_m5i_valid(b)) ? M4RationalV1(0, 0) :
    _m5i_norm(a.numerator * b.denominator + b.numerator * a.denominator,
              a.denominator * b.denominator)
_m5i_neg(a::M4RationalV1) = _m5i_valid(a) ? M4RationalV1(-a.numerator, a.denominator) : M4RationalV1(0, 0)
_m5i_sub(a::M4RationalV1, b::M4RationalV1) = _m5i_add(a, _m5i_neg(b))
_m5i_mul(a::M4RationalV1, b::M4RationalV1) =
    (!_m5i_valid(a) || !_m5i_valid(b)) ? M4RationalV1(0, 0) :
    _m5i_norm(a.numerator * b.numerator, a.denominator * b.denominator)
_m5i_div(a::M4RationalV1, b::M4RationalV1) =
    (!_m5i_valid(a) || !_m5i_valid(b) || b.numerator == 0) ? M4RationalV1(0, 0) :
    _m5i_norm(a.numerator * b.denominator, a.denominator * b.numerator)
_m5i_abs(a::M4RationalV1) = _m5i_valid(a) ? _m5i_norm(abs(a.numerator), a.denominator) : M4RationalV1(0, 0)
_m5i_positive(a::M4RationalV1) = _m5i_valid(a) && a.denominator > 0 && a.numerator > 0

"""Return the exact symmetric matrix for the manufactured family."""
function forward_matrix(alpha, beta)
    a, b = _m5i_rat(alpha), _m5i_rat(beta)
    (a === nothing || b === nothing) && return ((M4RationalV1(0, 0), M4RationalV1(0, 0)),
        (M4RationalV1(0, 0), M4RationalV1(0, 0)))
    ((a, _m5i_neg(b)), (_m5i_neg(b), a))
end

"""Return ``A(alpha,beta)⁻¹ * rhs`` exactly as a two-entry tuple."""
function forward(alpha, beta; rhs=M5I_RHS_V1)
    a, b = _m5i_rat(alpha), _m5i_rat(beta)
    r = rhs isa Tuple && length(rhs) == 2 ? Tuple(_m5i_rat(x) for x in rhs) : (nothing, nothing)
    if a === nothing || b === nothing || any(x -> x === nothing, r)
        return (M4RationalV1(0, 0), M4RationalV1(0, 0))
    end
    det = _m5i_sub(_m5i_mul(a, a), _m5i_mul(b, b))
    (_m5i_div(_m5i_add(_m5i_mul(a, r[1]), _m5i_mul(b, r[2])), det),
     _m5i_div(_m5i_add(_m5i_mul(b, r[1]), _m5i_mul(a, r[2])), det))
end

manufactured_inverse_forward = forward

function _m5i_target(x)
    if x isa Tuple && length(x) == 2
        a, b = _m5i_rat(x[1]), _m5i_rat(x[2])
        a !== nothing && b !== nothing && return (a, b)
    elseif x isa NamedTuple && ((hasproperty(x, :first) && hasproperty(x, :second)) ||
            (hasproperty(x, :u) && hasproperty(x, :v)))
        a, b = hasproperty(x, :first) ? (_m5i_rat(x.first), _m5i_rat(x.second)) :
            (_m5i_rat(x.u), _m5i_rat(x.v))
        a !== nothing && b !== nothing && return (a, b)
    end
    nothing
end

function _m5i_unwrap_d(x)
    x isa ManufacturedCoupledSolveControlV1 && return x
    x isa ManufacturedCoupledSolveControlResultV1 && x.valid && x.control !== nothing && return x.control
    nothing
end
function _m5i_unwrap_a(x)
    x isa ManufacturedAutoCompositionV1 && return x
    x isa ManufacturedAutoCompositionResultV1 && x.valid && x.composition !== nothing && return x.composition
    nothing
end

function _m5i_check_upstream!(fs, d, a)
    d === nothing && push!(fs, _m5i_failure(:invalid_upstream, "M4-D", "a valid M4-D control is required"))
    a === nothing && push!(fs, _m5i_failure(:invalid_upstream, "M5-A", "a valid M5-A composition is required"))
    d === nothing || begin
        r = validate_manufactured_coupled_solve_control(d)
        r.valid || push!(fs, _m5i_failure(:invalid_upstream, "M4-D", "M4-D validation failed"))
        d.schema == M4D_SCHEMA_V1 || push!(fs, _m5i_failure(:foreign_hash, "M4-D.schema", "M4-D schema is foreign"))
        d.source_owner == d.left.source_owner == d.right.source_owner ||
            push!(fs, _m5i_failure(:foreign_owner, "M4-D.source_owner", "M4-D source owner is not closed"))
        d.provenance == d.left.provenance == d.right.provenance ||
            push!(fs, _m5i_failure(:foreign_provenance, "M4-D.provenance", "M4-D provenance is not closed"))
    end
    a === nothing || begin
        r = validate_manufactured_auto_composition(a)
        r.valid || push!(fs, _m5i_failure(:invalid_upstream, "M5-A", "M5-A validation failed"))
        a.source_hashes == M5A_SOURCE_SHA256_V1 || push!(fs, _m5i_failure(:foreign_hash, "M5-A.source_hashes", "M5-A source hashes are foreign"))
        a.d_test_sha256 == M5A_D_TEST_SHA256_V1 && a.d_oracle_sha256 == M5A_D_ORACLE_SHA256_V1 ||
            push!(fs, _m5i_failure(:foreign_hash, "M5-A.receipts", "M5-A D receipts are foreign"))
        getproperty(a.typed_identities, :D) == M5I_M4D_TYPED_IDENTITY_V1 ||
            push!(fs, _m5i_failure(:foreign_hash, "M5-A.typed_identities.D", "M4-D typed identity is foreign"))
        length(a.provenance) == 4 && all(p -> p.claim_ceiling == M5A_CLAIM_CEILING_V1 && p.evidence_scope == :screen_only, a.provenance) ||
            push!(fs, _m5i_failure(:foreign_provenance, "M5-A.provenance", "M5-A provenance is outside the frozen screen scope"))
    end
    d === nothing || a === nothing || begin
        d.equation_id == a.equation_id && d.source_id == a.source_id && d.source_owner == a.source_owner &&
            d.conservation_owner == a.conservation_owner && d.interface.conservation_owner == a.interface_owner ||
            push!(fs, _m5i_failure(:foreign_owner, "upstream.owner_bindings", "M4-D and M5-A owner joins are foreign"))
    end
end

function _m5i_build(d, a, target)
    det = _m5i_sub(_m5i_mul(target[1], target[1]), _m5i_mul(target[2], target[2]))
    alpha, beta = _m5i_div(target[1], det), _m5i_div(target[2], det)
    f = ManufacturedInverseForwardV1(alpha, beta, forward_matrix(alpha, beta), M5I_RHS_V1,
        forward(alpha, beta), _m5i_sub(_m5i_mul(alpha, alpha), _m5i_mul(beta, beta)))
    active = f.response
    deleted = forward(alpha, M4RationalV1(0, 1))
    owner = _m5i_owner_ledger(d, a)
    provenance = _m5i_provenance_ledger(d, a)
    m5a_hash = try manufactured_auto_composition_hash(a) catch; digest256_text(string(a.source_hashes)) end
    ManufacturedInverseFeedbackV1(M5I_SCHEMA_V1, target, M5I_RHS_V1, alpha, beta, f,
        f.determinant, (_m5i_sub(alpha, beta), _m5i_add(alpha, beta)),
        _m5i_div(_m5i_sub(alpha, beta), _m5i_add(alpha, beta)),
        (_m5i_sub(active[1], target[1]), _m5i_sub(active[2], target[2])),
        Tuple((seed=seed, alpha=alpha, beta=beta, response=active,
               replay=true) for seed in M5I_SEEDS_V1),
        "M5-interface-beta-feedback", active, M4RationalV1(0, 1), deleted,
        (_m5i_sub(active[1], deleted[1]), _m5i_sub(active[2], deleted[2])),
        !_m5i_equal(active[1], deleted[1]) || !_m5i_equal(active[2], deleted[2]),
        M5I_M4D_SOURCE_SHA256_V1, M5I_M4D_TEST_SHA256_V1, M5I_M4D_ORACLE_SHA256_V1,
        M5I_M4D_TYPED_IDENTITY_V1, M5I_M5A_SOURCE_SHA256_V1, M5I_M5A_TEST_SHA256_V1,
        M5I_M5A_ORACLE_SHA256_V1, getproperty(a.typed_identities, :D), m5a_hash,
        d, a,
        owner, provenance, M5I_CLAIM_CEILING_V1, M5I_EVIDENCE_SCOPE_V1)
end

function _m5i_owner_ledger(d::ManufacturedCoupledSolveControlV1,
        a::ManufacturedAutoCompositionV1)
    (m4d_source=d.source_owner, m4d_conservation=d.conservation_owner,
     m4d_interface=d.interface.conservation_owner, m5a_source=a.source_owner,
     m5a_conservation=a.conservation_owner, m5a_interface=a.interface_owner)
end

function _m5i_provenance_ledger(d::ManufacturedCoupledSolveControlV1,
        a::ManufacturedAutoCompositionV1)
    (m4d=d.provenance, m5a=a.provenance,
     source_scope=:manufactured_only, authority_kind=:no_external_authority)
end

_m5i_pair_equal(a, b) = length(a) == 2 && length(b) == 2 &&
    _m5i_equal(a[1], b[1]) && _m5i_equal(a[2], b[2])

function _m5i_matrix_equal(a, b)
    length(a) == 2 && length(b) == 2 &&
        all(length(a[i]) == 2 && length(b[i]) == 2 &&
            _m5i_equal(a[i][j], b[i][j]) for i in 1:2, j in 1:2)
end

function _m5i_seed_equal(actual, expected, alpha, beta, response)
    length(actual) == length(expected) && all(begin
        e = actual[i]
        e.seed == expected[i] && e.replay === true &&
            _m5i_equal(e.alpha, alpha) && _m5i_equal(e.beta, beta) &&
            _m5i_pair_equal(e.response, response)
    end for i in eachindex(expected))
end

function build_inverse(d_input, composition_input, target=M5I_TARGET_V1)
    d, a = _m5i_unwrap_d(d_input), _m5i_unwrap_a(composition_input)
    # Accept the two frozen products in either order without changing their
    # identity: this is only an input-shape convenience, not a routing rule.
    if d === nothing && a === nothing
        d, a = _m5i_unwrap_d(composition_input), _m5i_unwrap_a(d_input)
    end
    fs = ManufacturedInverseFeedbackFailureV1[]
    _m5i_check_upstream!(fs, d, a)
    t = _m5i_target(target)
    t === nothing && push!(fs, _m5i_failure(:nonidentifiable_target, "target", "target must be a two-entry exact-rational tuple"))
    t === nothing || begin
        any(x -> !_m5i_valid(x), t) && push!(fs, _m5i_failure(:nonidentifiable_target, "target.denominator", "target denominator is zero"))
        _m5i_zero(t[1]) && _m5i_zero(t[2]) && push!(fs, _m5i_failure(:nonidentifiable_target, "target", "zero target has no identifiable scale"))
        q = _m5i_sub(_m5i_mul(t[1], t[1]), _m5i_mul(t[2], t[2]))
        _m5i_valid(q) && q.numerator < 0 && push!(fs, _m5i_failure(:impossible_target, "target", "target implies a negative determinant"))
        _m5i_valid(q) && q.numerator == 0 && begin
            push!(fs, _m5i_failure(:nonidentifiable_target, "target", "target is on the singular response cone"))
            push!(fs, _m5i_failure(:singular, "target", "target inversion determinant is zero"))
        end
    end
    isempty(fs) || return _m5i_invalid(fs)
    product = try _m5i_build(d, a, t) catch err
        return _m5i_invalid([_m5i_failure(:invalid_upstream, "construction", sprint(showerror, err))])
    end
    result = validate_inverse(product)
    result.valid ? result : ManufacturedInverseFeedbackResultV1(false, result.status, product,
        result.failures, result.claim_ceiling, result.evidence_scope)
end

function build_inverse(target; d_input=nothing, composition_input=nothing,
        d=nothing, composition=nothing, m5a=nothing)
    build_inverse(d === nothing ? d_input : d,
        composition !== nothing ? composition : (m5a !== nothing ? m5a : composition_input), target)
end
function build_inverse(; d_input=nothing, composition_input=nothing,
        d=nothing, composition=nothing, m5a=nothing, target=M5I_TARGET_V1)
    build_inverse(d === nothing ? d_input : d,
        composition !== nothing ? composition : (m5a !== nothing ? m5a : composition_input), target)
end

function validate_inverse(x::ManufacturedInverseFeedbackV1)
    fs = ManufacturedInverseFeedbackFailureV1[]
    x.schema == M5I_SCHEMA_V1 || push!(fs, _m5i_failure(:foreign_hash, "schema", "inverse schema is foreign"))
    x.claim_ceiling == M5I_CLAIM_CEILING_V1 && x.evidence_scope == M5I_EVIDENCE_SCOPE_V1 ||
        push!(fs, _m5i_failure(:foreign_provenance, "claim_ceiling", "inverse remains manufactured/screen_only"))
    # Revalidate both retained upstream snapshots.  A malformed nested value
    # is converted to a typed failure rather than escaping as an exception.
    d_valid = try
        validate_manufactured_coupled_solve_control(x.m4d_upstream).valid
    catch
        false
    end
    d_valid || push!(fs, _m5i_failure(:invalid_upstream, "m4d_upstream", "nested M4-D validation failed"))
    a_valid = try
        validate_manufactured_auto_composition(x.m5a_upstream).valid
    catch
        false
    end
    a_valid || push!(fs, _m5i_failure(:invalid_upstream, "m5a_upstream", "nested M5-A validation failed"))

    # Frozen source/receipt identities must agree with the nested M4-D/M5-A
    # snapshots, not merely with constants copied into the outer product.
    try
        d = x.m4d_upstream
        a = x.m5a_upstream
        d.schema == M4D_SCHEMA_V1 && x.m4d_source_sha256 == M5I_M4D_SOURCE_SHA256_V1 ||
            push!(fs, _m5i_failure(:foreign_hash, "M4-D.source", "M4-D source identity is foreign"))
        x.m4d_test_sha256 == M5I_M4D_TEST_SHA256_V1 && x.m4d_oracle_sha256 == M5I_M4D_ORACLE_SHA256_V1 ||
            push!(fs, _m5i_failure(:foreign_hash, "M4-D.receipts", "M4-D test/oracle identity is foreign"))
        getproperty(a.source_hashes, :D) == x.m4d_source_sha256 &&
            getproperty(a.typed_identities, :D) == x.m4d_typed_identity &&
            x.m4d_typed_identity == M5I_M4D_TYPED_IDENTITY_V1 ||
            push!(fs, _m5i_failure(:foreign_hash, "M4-D.typed_identity", "nested M4-D identity is foreign"))
        a.source_hashes == M5A_SOURCE_SHA256_V1 && x.m5a_source_sha256 == M5I_M5A_SOURCE_SHA256_V1 ||
            push!(fs, _m5i_failure(:foreign_hash, "M5-A.source", "M5-A source identity is foreign"))
        a.d_test_sha256 == M5A_D_TEST_SHA256_V1 && a.d_oracle_sha256 == M5A_D_ORACLE_SHA256_V1 &&
            x.m5a_test_sha256 == M5I_M5A_TEST_SHA256_V1 && x.m5a_oracle_sha256 == M5I_M5A_ORACLE_SHA256_V1 ||
            push!(fs, _m5i_failure(:foreign_hash, "M5-A.receipts", "M5-A test/oracle identity is foreign"))
        m5a_hash = manufactured_auto_composition_hash(a)
        m5a_hash == x.m5a_composition_hash ||
            push!(fs, _m5i_failure(:foreign_hash, "M5-A.composition_hash", "M5-A composition hash does not replay"))
    catch err
        push!(fs, _m5i_failure(:invalid_upstream, "upstream", sprint(showerror, err)))
    end

    # The owner and provenance ledgers are canonical projections of nested
    # fields.  Equality between outer entries alone is insufficient.
    try
        expected_owners = _m5i_owner_ledger(x.m4d_upstream, x.m5a_upstream)
        x.owner_bindings == expected_owners || push!(fs, _m5i_failure(:foreign_owner,
            "owner_bindings", "owner ledger is not the nested canonical projection"))
        expected_provenance = _m5i_provenance_ledger(x.m4d_upstream, x.m5a_upstream)
        x.provenance_bindings == expected_provenance || push!(fs, _m5i_failure(:foreign_provenance,
            "provenance_bindings", "provenance ledger is not the nested canonical projection"))
    catch err
        push!(fs, _m5i_failure(:foreign_owner, "owner_bindings", sprint(showerror, err)))
    end

    # Recompute the complete algebraic product from the stored target and
    # compare every derived field.  The target/rhs checks are intentionally
    # separate so every corruption remains typed and diagnosable.
    try
        _m5i_pair_equal(x.rhs, M5I_RHS_V1) || push!(fs, _m5i_failure(:roundtrip, "rhs", "rhs must be [1,0]"))
        t = x.target
        q = _m5i_sub(_m5i_mul(t[1], t[1]), _m5i_mul(t[2], t[2]))
        _m5i_valid(q) || push!(fs, _m5i_failure(:nonidentifiable_target, "target", "target denominator is zero"))
        _m5i_valid(q) || throw(ArgumentError("invalid target denominator"))
        expected_alpha = _m5i_div(t[1], q)
        expected_beta = _m5i_div(t[2], q)
        _m5i_equal(x.recovered_alpha, expected_alpha) && _m5i_equal(x.recovered_beta, expected_beta) ||
            push!(fs, _m5i_failure(:impossible_target, "recovered_parameters", "inverse parameters do not derive from target"))
        expected_matrix = forward_matrix(expected_alpha, expected_beta)
        expected_response = forward(expected_alpha, expected_beta; rhs=M5I_RHS_V1)
        expected_det = _m5i_sub(_m5i_mul(expected_alpha, expected_alpha), _m5i_mul(expected_beta, expected_beta))
        expected_eigen = (_m5i_sub(expected_alpha, expected_beta), _m5i_add(expected_alpha, expected_beta))
        expected_margin = _m5i_div(expected_eigen[1], expected_eigen[2])
        expected_residual = (_m5i_sub(expected_response[1], t[1]), _m5i_sub(expected_response[2], t[2]))
        expected_deleted = forward(expected_alpha, M4RationalV1(0, 1); rhs=M5I_RHS_V1)
        expected_delta = (_m5i_sub(expected_response[1], expected_deleted[1]),
            _m5i_sub(expected_response[2], expected_deleted[2]))
        x.forward.alpha == x.recovered_alpha && x.forward.beta == x.recovered_beta &&
            _m5i_matrix_equal(x.forward.matrix, expected_matrix) && _m5i_pair_equal(x.forward.rhs, M5I_RHS_V1) &&
            _m5i_pair_equal(x.forward.response, expected_response) && _m5i_equal(x.forward.determinant, expected_det) ||
            push!(fs, _m5i_failure(:roundtrip, "forward", "stored forward record does not replay"))
        _m5i_equal(x.determinant, expected_det) || push!(fs, _m5i_failure(:singular, "determinant", "determinant does not replay"))
        _m5i_pair_equal(x.eigenvalues, expected_eigen) && _m5i_equal(x.eigen_margin_proxy, expected_margin) ||
            push!(fs, _m5i_failure(:non_spd, "eigen_margin_proxy", "eigen/margin record does not replay"))
        _m5i_pair_equal(x.roundtrip_residual, expected_residual) || push!(fs, _m5i_failure(:roundtrip, "roundtrip_residual", "roundtrip residual does not replay"))
        _m5i_seed_equal(x.multi_seed, Tuple(M5I_SEEDS_V1), expected_alpha, expected_beta, expected_response) ||
            push!(fs, _m5i_failure(:seed, "multi_seed", "seed ledger does not replay"))
        _m5i_pair_equal(x.feedback_active_response, expected_response) &&
            _m5i_equal(x.deletion_beta, M4RationalV1(0, 1)) &&
            _m5i_pair_equal(x.deletion_response, expected_deleted) &&
            _m5i_pair_equal(x.feedback_response_delta, expected_delta) &&
            x.response_changed == (!_m5i_pair_equal(expected_response, expected_deleted)) ||
            push!(fs, _m5i_failure(:feedback_deletion_no_effect, "feedback", "feedback ledger does not replay"))
        x.feedback_interface_edge == "M5-interface-beta-feedback" ||
            push!(fs, _m5i_failure(:foreign_owner, "feedback_interface_edge", "feedback edge identity is foreign"))
        _m5i_positive(expected_alpha) && _m5i_positive(_m5i_abs(expected_beta)) &&
            _m5i_positive(_m5i_sub(expected_alpha, _m5i_abs(expected_beta))) ||
            push!(fs, _m5i_failure(:non_spd, "recovered_parameters", "alpha > abs(beta) > 0 is required"))
    catch err
        push!(fs, _m5i_failure(:roundtrip, "derived_fields", sprint(showerror, err)))
    end
    ManufacturedInverseFeedbackResultV1(isempty(fs), isempty(fs) ? :valid : :typed_failure,
        x, _m5i_failure_tuple(fs), x.claim_ceiling, x.evidence_scope)
end

validate_inverse(x::ManufacturedInverseFeedbackResultV1) = x.inverse === nothing ? x : validate_inverse(x.inverse)
validate_inverse(x) = _m5i_invalid([_m5i_failure(:invalid_upstream, "input", "expected ManufacturedInverseFeedbackV1")])

function inverse_payload(x::ManufacturedInverseFeedbackV1)
    (schema=x.schema, target=x.target, rhs=x.rhs, recovered=(alpha=x.recovered_alpha, beta=x.recovered_beta),
     forward=(matrix=x.forward.matrix, rhs=x.forward.rhs, response=x.forward.response, determinant=x.forward.determinant),
     determinant=x.determinant, eigenvalues=x.eigenvalues, eigen_margin_proxy=x.eigen_margin_proxy,
     roundtrip_residual=x.roundtrip_residual, multi_seed=x.multi_seed,
     feedback=(edge=x.feedback_interface_edge, active=x.feedback_active_response,
               deletion_beta=x.deletion_beta, deletion=x.deletion_response,
               delta=x.feedback_response_delta, changed=x.response_changed),
     upstream=(m4d=(source=x.m4d_source_sha256, test=x.m4d_test_sha256, oracle=x.m4d_oracle_sha256, identity=x.m4d_typed_identity,
                    snapshot=manufactured_coupled_solve_control_payload(x.m4d_upstream)),
               m5a=(source=x.m5a_source_sha256, test=x.m5a_test_sha256, oracle=x.m5a_oracle_sha256, identity=x.m5a_typed_identity, composition=x.m5a_composition_hash,
                    snapshot=manufactured_auto_composition_payload(x.m5a_upstream))),
     owners=x.owner_bindings, provenance=x.provenance_bindings,
     claim_ceiling=x.claim_ceiling, evidence_scope=x.evidence_scope)
end

inverse_payload(x) = (schema=M5I_SCHEMA_V1, status=:typed_failure, input_type=typeof(x))
is_valid_inverse(x::ManufacturedInverseFeedbackV1) = validate_inverse(x).valid
is_valid_inverse(x::ManufacturedInverseFeedbackResultV1) = x.valid
is_valid_inverse(x) = false

const build_manufactured_inverse_feedback = build_inverse
const build_manufactured_inverse_feedback_v1 = build_inverse
const inverse = build_inverse
const validate_manufactured_inverse_feedback = validate_inverse
const validate_manufactured_inverse_feedback_v1 = validate_inverse
const manufactured_inverse_feedback_payload = inverse_payload
const manufactured_inverse_feedback_payload_v1 = inverse_payload
const is_valid_manufactured_inverse_feedback = is_valid_inverse
const is_valid_manufactured_inverse_feedback_v1 = is_valid_inverse
const validate = validate_inverse
const payload = inverse_payload
const is_valid = is_valid_inverse

function manufactured_inverse_feedback_hash(x::ManufacturedInverseFeedbackV1)
    payload = inverse_payload(x)
    digest256_text(string(payload))
end
const manufactured_inverse_feedback_hash_v1 = manufactured_inverse_feedback_hash
