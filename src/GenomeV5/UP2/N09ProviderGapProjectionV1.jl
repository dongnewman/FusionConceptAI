"""Contract-only projection of the five registered N09 provider declarations.

The projection consumes provider_match fields already owned by G1, G2 and G3.
It never resolves a provider and it never reuses an evidence receipt.  A missing
source field is recorded as an explicit gap; no synthetic declaration is made.
"""

const _N09_PROVIDER_MATCHES = (:unique_match, :no_match, :ambiguous,
                               :out_of_domain, :invalid_signature)
const _N09_MUTATION_MATCHES = (:no_match, :out_of_domain, :invalid_signature)

_n09_has(x, name::Symbol) = x !== nothing && hasproperty(x, name)
_n09_get(x, name::Symbol, default=nothing) = _n09_has(x, name) ? getproperty(x, name) : default

function _n09_text(value, field::AbstractString)
    value isa AbstractString && !isempty(String(value)) ||
        throw(ArgumentError("$field must be a non-empty string"))
    String(value)
end

function _n09_match(value, field::AbstractString)
    match = value isa Symbol ? value : Symbol(value)
    match in _N09_PROVIDER_MATCHES ||
        throw(ArgumentError("$field is not a registered provider_match"))
    match
end

"""One provider declaration with candidate, public ref and component hash provenance."""
struct N09ProviderDeclarationV1
    layer::Symbol
    field_path::String
    source_locator::String
    candidate_ref::QualifiedRefV1
    genome_ref::GenomeContractRef
    component_hash::Digest256
    provider_match::Symbol
    function N09ProviderDeclarationV1(layer::Any, field_path::Any,
                                      source_locator::Any, candidate_ref::Any,
                                      genome_ref::Any, component_hash::Any,
                                      provider_match::Any)
        role = layer isa Symbol ? layer : Symbol(layer)
        role in (:g1_operator, :g2_grammar, :g2_exterior,
                 :g3_realization, :g3_control) ||
            throw(ArgumentError("N09 layer is not one of the five registered declarations"))
        candidate_ref isa QualifiedRefV1 && candidate_ref.version == "v5" ||
            throw(ArgumentError("N09 candidate_ref must be a v5 QualifiedRefV1"))
        genome_ref isa GenomeContractRef && genome_ref.version == "v5" ||
            throw(ArgumentError("N09 genome_ref must be a public v5 GenomeContractRef"))
        component_hash isa Digest256 ||
            throw(ArgumentError("N09 component_hash must be Digest256"))
        new(role, _n09_text(field_path, "N09 field_path"),
            _n09_text(source_locator, "N09 source_locator"), candidate_ref,
            genome_ref, component_hash, _n09_match(provider_match, "N09 provider_match"))
    end
end

semantic_view(x::N09ProviderDeclarationV1) =
    (layer=x.layer, field_path=x.field_path, source_locator=x.source_locator,
     candidate_ref=x.candidate_ref, genome_ref=x.genome_ref,
     component_hash=x.component_hash, provider_match=x.provider_match)

"""Candidate-bound projection.  `gaps` are authoritative missing-field gaps."""
struct N09ProviderGapProjectionV1
    candidate_ref::QualifiedRefV1
    package_hash::Digest256
    declarations::Tuple{Vararg{N09ProviderDeclarationV1}}
    gaps::Tuple{Vararg{String}}
    projection_hash::Digest256
    function N09ProviderGapProjectionV1(candidate_ref::Any, package_hash::Any,
                                         declarations::Any, gaps::Any)
        candidate_ref isa QualifiedRefV1 && candidate_ref.version == "v5" ||
            throw(ArgumentError("N09 projection requires a v5 candidate ref"))
        package_hash isa Digest256 || throw(ArgumentError("N09 projection requires package hash"))
        declarations isa Tuple || throw(ArgumentError("N09 declarations must be a tuple"))
        all(x -> x isa N09ProviderDeclarationV1 && x.candidate_ref == candidate_ref,
            declarations) || throw(ArgumentError("N09 declaration provenance is not candidate-bound"))
        length(unique(x.layer for x in declarations)) == length(declarations) ||
            throw(ArgumentError("N09 declaration layers must be unique"))
        gap_tuple = Tuple(_n09_text(x, "N09 gap") for x in gaps)
        body = (candidate_ref=candidate_ref, package_hash=package_hash,
                declarations=Tuple(declarations), gaps=gap_tuple)
        new(candidate_ref, package_hash, Tuple(declarations), gap_tuple,
            canonical_hash(body))
    end
end

semantic_view(x::N09ProviderGapProjectionV1) =
    (candidate_ref=x.candidate_ref, package_hash=x.package_hash,
     declarations=x.declarations, gaps=x.gaps, projection_hash=x.projection_hash)

function _n09_contract_ref(x)
    ref = _n09_get(x, :contract_ref)
    ref isa GenomeContractRef && return ref
    binding = _n09_get(x, :contract_binding)
    ref = _n09_get(binding, :contract_ref)
    ref isa GenomeContractRef && return ref
    nothing
end

function _n09_component_hash(x)
    value = _n09_get(x, :candidate_hash)
    value isa Digest256 ? value : nothing
end

function _n09_provider_value(x, path::String, gaps::Vector{String})
    value = _n09_get(x, :provider_match)
    value === nothing && push!(gaps, "missing_authoritative_provider_match:$path")
    value === nothing ? nothing : _n09_match(value, path)
end

"""Extract exactly five declarations from a real CandidateStatePackageV5.

The returned projection is structurally incomplete with explicit gaps when an
authoritative source field is absent.  It does not synthesize a provider status.
"""
function n09_provider_gap_projection(package)
    package isa CandidateStatePackageV5 ||
        throw(ArgumentError("N09 requires a CandidateStatePackageV5 input"))
    candidate = package.candidate_ref
    gaps = String[]
    declarations = N09ProviderDeclarationV1[]
    g1 = package.g1; g2 = package.g2; g3 = package.g3
    g1ref = _n09_contract_ref(g1); g2ref = _n09_contract_ref(g2)
    g3real = _n09_get(g3, :realization); g3control = _n09_get(g3, :control)
    g3realref = _n09_contract_ref(g3real); g3controlref = _n09_contract_ref(g3control)
    g1hash = _n09_component_hash(g1); g2hash = _n09_component_hash(g2)
    g3realhash = _n09_component_hash(g3real); g3controlhash = _n09_component_hash(g3control)

    g1payload = _n09_get(g1, :payload)
    g1profile = _n09_get(g1payload, :grammar_profile)
    g1operators = _n09_get(g1profile, :operators, ())
    if isempty(g1operators)
        push!(gaps, "missing_authoritative_provider_match:/g1/grammar_profile/operators/0/provider_match")
    else
        value = _n09_provider_value(first(g1operators), "/g1/grammar_profile/operators/0/provider_match", gaps)
        if g1ref === nothing
            push!(gaps, "missing_authoritative_genome_ref:/g1/grammar_profile/operators/0/provider_match")
        elseif g1hash === nothing
            push!(gaps, "missing_authoritative_component_hash:/g1/grammar_profile/operators/0/provider_match")
        elseif value !== nothing
            push!(declarations, N09ProviderDeclarationV1(:g1_operator,
                "/g1/grammar_profile/operators/0/provider_match",
                "G1OperatorSpecV2.provider_match::Symbol", candidate, g1ref, g1hash, value))
        end
    end

    g2profile = _n09_get(g2, :grammar_profile)
    value = _n09_provider_value(g2profile, "/g2/grammar_profile/provider_match", gaps)
    if g2ref === nothing
        push!(gaps, "missing_authoritative_genome_ref:/g2/grammar_profile/provider_match")
    elseif g2hash === nothing
        push!(gaps, "missing_authoritative_component_hash:/g2/grammar_profile/provider_match")
    elseif value !== nothing
        push!(declarations, N09ProviderDeclarationV1(:g2_grammar,
            "/g2/grammar_profile/provider_match", "SpatialGrammarProfileV2.provider_match::Symbol",
            candidate, g2ref, g2hash, value))
    end

    g2plan = _n09_get(g2, :plan); g2exterior = _n09_get(g2plan, :exterior)
    value = _n09_provider_value(g2exterior, "/g2/plan/exterior/provider_match", gaps)
    if g2ref === nothing
        push!(gaps, "missing_authoritative_genome_ref:/g2/plan/exterior/provider_match")
    elseif g2hash === nothing
        push!(gaps, "missing_authoritative_component_hash:/g2/plan/exterior/provider_match")
    elseif value !== nothing
        push!(declarations, N09ProviderDeclarationV1(:g2_exterior,
            "/g2/plan/exterior/provider_match", "G2ExteriorPlanV2.provider_match::Symbol",
            candidate, g2ref, g2hash, value))
    end

    value = _n09_provider_value(g3real, "/g3/realization/provider_match", gaps)
    if g3realref === nothing
        push!(gaps, "missing_authoritative_genome_ref:/g3/realization/provider_match")
    elseif g3realhash === nothing
        push!(gaps, "missing_authoritative_component_hash:/g3/realization/provider_match")
    elseif value !== nothing
        push!(declarations, N09ProviderDeclarationV1(:g3_realization,
            "/g3/realization/provider_match", "RealizationGenomeV5.provider_match::Symbol",
            candidate, g3realref, g3realhash, value))
    end

    value = _n09_provider_value(g3control, "/g3/control/provider_match", gaps)
    if g3controlref === nothing
        push!(gaps, "missing_authoritative_genome_ref:/g3/control/provider_match")
    elseif g3controlhash === nothing
        push!(gaps, "missing_authoritative_component_hash:/g3/control/provider_match")
    elseif value !== nothing
        push!(declarations, N09ProviderDeclarationV1(:g3_control,
            "/g3/control/provider_match", "ControlGenomeV5.provider_match::Symbol",
            candidate, g3controlref, g3controlhash, value))
    end
    filter!(x -> !isempty(x), gaps)
    N09ProviderGapProjectionV1(candidate, package.candidate_hash, Tuple(declarations), Tuple(unique(gaps)))
end

n09_projection_complete(x::N09ProviderGapProjectionV1) =
    isempty(x.gaps) && length(x.declarations) == 5 &&
    Set(x.layer for x in x.declarations) == Set((:g1_operator, :g2_grammar,
                                                :g2_exterior, :g3_realization,
                                                :g3_control))

struct N09ProviderMutationSpecV1
    id::String
    field_path::String
    source_locator::String
    baseline_provider_match::Symbol
    mutated_provider_match::Symbol
    expected_error::Symbol
    expected_resolution::Symbol
    expected_provider_calls::Int
    function N09ProviderMutationSpecV1(id::Any, field_path::Any,
                                       source_locator::Any, baseline_provider_match::Any,
                                       mutated_provider_match::Any,
                                       expected_error::Any, expected_resolution::Any,
                                       expected_provider_calls::Any)
        calls = expected_provider_calls isa Integer ? Int(expected_provider_calls) :
            throw(ArgumentError("N09 expected provider calls must be integer"))
        calls == 0 || throw(ArgumentError("N09 provider mutations require zero provider calls"))
        error_code = Symbol(expected_error)
        error_code == :provider_match || throw(ArgumentError("N09 error must be provider_match"))
        resolution = Symbol(expected_resolution)
        resolution == :terminal_deferred || throw(ArgumentError("N09 resolution must be terminal_deferred"))
        baseline = _n09_match(baseline_provider_match, "N09 baseline provider_match")
        match = _n09_match(mutated_provider_match, "N09 mutation provider_match")
        match in _N09_MUTATION_MATCHES ||
            throw(ArgumentError("N09 mutation must be no_match, out_of_domain or invalid_signature"))
        new(_n09_text(id, "N09 mutation id"), _n09_text(field_path, "N09 mutation field_path"),
            _n09_text(source_locator, "N09 mutation source_locator"), baseline, match,
            error_code, resolution, calls)
    end
end

struct N09ProviderGapResultV1
    mutation_id::String
    input_hash::Digest256
    mutated_projection_hash::Digest256
    status::Symbol
    resolution::Symbol
    error_code::Symbol
    error_path::String
    detail::String
    compile_calls::Int
    provider_calls::Int
    solver_calls::Int
    evidence_reused::Bool
end

semantic_view(x::N09ProviderGapResultV1) =
    (mutation_id=x.mutation_id, input_hash=x.input_hash,
     mutated_projection_hash=x.mutated_projection_hash, status=x.status,
     resolution=x.resolution, error_code=x.error_code, error_path=x.error_path,
     detail=x.detail, compile_calls=x.compile_calls, provider_calls=x.provider_calls,
     solver_calls=x.solver_calls, evidence_reused=x.evidence_reused)

function _n09_mutated_projection(projection::N09ProviderGapProjectionV1,
                                 spec::N09ProviderMutationSpecV1)
    index = findfirst(x -> x.field_path == spec.field_path, projection.declarations)
    index === nothing && throw(ArgumentError("N09 mutation field is not an authoritative projection field"))
    declaration = projection.declarations[index]
    declaration.source_locator == spec.source_locator ||
        throw(ArgumentError("N09 mutation source locator mismatch"))
    declaration.provider_match == spec.baseline_provider_match ||
        throw(ArgumentError("N09 mutation baseline provider_match does not match source"))
    declaration.provider_match != spec.mutated_provider_match ||
        throw(ArgumentError("N09 mutation does not change provider_match"))
    rebuilt = ntuple(i -> i == index ? N09ProviderDeclarationV1(
        declaration.layer, declaration.field_path, declaration.source_locator,
        declaration.candidate_ref, declaration.genome_ref, declaration.component_hash,
        spec.mutated_provider_match) : projection.declarations[i], length(projection.declarations))
    N09ProviderGapProjectionV1(projection.candidate_ref, projection.package_hash,
                               rebuilt, projection.gaps)
end

"""Classify a mutated declaration without invoking compile, provider or solver."""
function n09_validate_mutation(projection::N09ProviderGapProjectionV1,
                               spec::N09ProviderMutationSpecV1; counter=nothing)
    n09_projection_complete(projection) ||
        throw(ArgumentError("N09 requires five authoritative provider declarations before mutation"))
    index = findfirst(x -> x.field_path == spec.field_path, projection.declarations)
    index === nothing && throw(ArgumentError("N09 mutation field is not an authoritative projection field"))
    mutated = _n09_mutated_projection(projection, spec)
    counter === nothing || begin
        _n09_has(counter, :compile_calls) || throw(ArgumentError("N09 counter lacks compile_calls"))
        _n09_has(counter, :provider_calls) || throw(ArgumentError("N09 counter lacks provider_calls"))
        _n09_has(counter, :solver_calls) || throw(ArgumentError("N09 counter lacks solver_calls"))
        counter.compile_calls == 0 && counter.provider_calls == 0 && counter.solver_calls == 0 ||
            throw(ArgumentError("N09 requires a fresh zero-call counter"))
    end
    mutated_match = mutated.declarations[index].provider_match
    mutated_match in _N09_MUTATION_MATCHES ||
        throw(ArgumentError("N09 mutated provider_match is not a deferred capability gap"))
    N09ProviderGapResultV1(spec.id, projection.projection_hash, mutated.projection_hash,
        :terminal_deferred, :terminal_deferred, :provider_match, spec.field_path,
        "provider_capability_gap:" * String(mutated_match),
        counter === nothing ? 0 : Int(counter.compile_calls),
        counter === nothing ? 0 : Int(counter.provider_calls),
        counter === nothing ? 0 : Int(counter.solver_calls), false)
end
