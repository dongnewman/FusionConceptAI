"""Contract-only N07/N08 geometry projection.

This file reads the already constructed G2 V5 object.  It does not execute a
mesh or provider and does not replace G2 admission.  The ten mutations cover
the frozen boundary and chart/mesh declarations; each result is bounded by
the concrete G2 region, exterior, chart, mesh, and interface relationships.
"""

abstract type N07N08TypedValueV1 end
struct N07N08Rational3V1 <: N07N08TypedValueV1; value::NTuple{3,Rational{Int64}}; end
struct N07N08Rational2V1 <: N07N08TypedValueV1; value::NTuple{2,Rational{Int64}}; end
struct N07N08SymbolTupleV1 <: N07N08TypedValueV1; value::Tuple{Vararg{Symbol}}; end
struct N07N08SymbolValueV1 <: N07N08TypedValueV1; value::Symbol; end
struct N07N08Int3V1 <: N07N08TypedValueV1; value::NTuple{3,Int}; end
struct N07N08InterfaceRefsV1 <: N07N08TypedValueV1; value::Tuple{Vararg{QualifiedRefV1}}; end
struct N07N08InterfaceV1
    ref::QualifiedRefV1
    left_region::String
    right_region::String
end

struct N07N08FieldV1
    id::String
    field_path::String
    source_locator::String
    source_type::Symbol
    value::N07N08TypedValueV1
end

struct N07N08RegionV1
    id::String
    lower::NTuple{3,Rational{Int64}}
    upper::NTuple{3,Rational{Int64}}
end

struct N07N08ProjectionV1
    candidate_ref::QualifiedRefV1
    package_hash::Digest256
    regions::Tuple{Vararg{N07N08RegionV1}}
    required_faces::Tuple{Vararg{Symbol}}
    patch_face::Symbol
    patch_region::String
    patch_upper::NTuple{2,Rational{Int64}}
    interfaces::Tuple{Vararg{N07N08InterfaceV1}}
    fields::Tuple{Vararg{N07N08FieldV1}}
    projection_hash::Digest256
end

semantic_view(x::N07N08Rational3V1) = (kind=:rational3, value=x.value)
semantic_view(x::N07N08Rational2V1) = (kind=:rational2, value=x.value)
semantic_view(x::N07N08SymbolTupleV1) = (kind=:symbol_tuple, value=x.value)
semantic_view(x::N07N08SymbolValueV1) = (kind=:symbol, value=x.value)
semantic_view(x::N07N08Int3V1) = (kind=:int3, value=x.value)
semantic_view(x::N07N08InterfaceRefsV1) = (kind=:interface_refs, value=x.value)
semantic_view(x::N07N08FieldV1) = (id=x.id, field_path=x.field_path,
    source_locator=x.source_locator, source_type=x.source_type, value=x.value)
semantic_view(x::N07N08RegionV1) = (id=x.id, lower=x.lower, upper=x.upper)
semantic_view(x::N07N08InterfaceV1) = (ref=x.ref, left_region=x.left_region, right_region=x.right_region)
semantic_view(x::N07N08ProjectionV1) = (candidate_ref=x.candidate_ref,
    package_hash=x.package_hash, regions=x.regions, required_faces=x.required_faces,
    patch_face=x.patch_face, patch_region=x.patch_region, patch_upper=x.patch_upper,
    interfaces=x.interfaces, fields=x.fields)

struct N07N08MutationSpecV1
    id::String
    class_id::Symbol
    field_path::String
    source_locator::String
    source_type::Symbol
    mutation_kind::Symbol
    expected_error::Symbol
    expected_resolution::ResolutionStatus
    expected_provider_calls::Int
end

struct N07N08InvocationCounterV1
    compile_calls::Int
    provider_calls::Int
    solver_calls::Int
end
N07N08InvocationCounterV1() = N07N08InvocationCounterV1(0, 0, 0)

struct N07N08ValidationResultV1
    mutation_id::String
    input_hash::Digest256
    mutated_input_hash::Digest256
    status::Symbol
    error_code::Symbol
    error_path::String
    compile_calls::Int
    provider_calls::Int
    solver_calls::Int
    result_hash::Digest256
end

_n07n08_field(p, id) = first(x for x in p.fields if x.id == id)

function n07_n08_projection_from_g2(g2::FieldGeometryGenomeV5,
        candidate_ref::QualifiedRefV1, package_hash::Digest256)
    # Supplemental constructor for isolated G2 contract fixtures.  Production
    # acceptance must use n07_n08_projection_from_a below.
    candidate_ref.version == "v5" || throw(ArgumentError("N07/N08 candidate ref must be v5"))
    startswith(g2.contract_ref.uri, "fusionconceptai://GenomeV5/G2/") ||
        throw(ArgumentError("N07/N08 requires the public G2 URI namespace"))
    g2.admission.structural_status == :valid && g2.admission.geometry_status == :valid ||
        throw(ArgumentError("N07/N08 requires an actually admitted G2 structural/geometry component"))
    rs = Tuple(N07N08RegionV1(r.region_id, r.lower, r.upper) for r in g2.region_interface.regions)
    ex = g2.plan.exterior
    faces = Tuple(ex.boundary_faces)
    patch = first(ex.boundary_patches)
    interfaces = Tuple(N07N08InterfaceV1(i.interface_ref, i.left_region_id, i.right_region_id)
        for i in g2.region_interface.interfaces)
    irefs = Tuple(i.ref for i in interfaces)
    fields = (
        N07N08FieldV1("N07-01", "/g2/contract/regions/0/lower", "G2RegionV2.lower::NTuple{3,Rational{Int64}}", :rational3, N07N08Rational3V1(rs[1].lower)),
        N07N08FieldV1("N07-02", "/g2/contract/regions/0/upper", "G2RegionV2.upper::NTuple{3,Rational{Int64}}", :rational3, N07N08Rational3V1(rs[1].upper)),
        N07N08FieldV1("N07-03", "/g2/plan/exterior/boundary_faces", "G2ExteriorPlanV2.boundary_faces::Tuple[Symbol]", :symbol_tuple, N07N08SymbolTupleV1(faces)),
        N07N08FieldV1("N07-04", "/g2/plan/exterior/boundary_patches/0/lower", "G2BoundaryFacePatchV2.lower::NTuple{2,Rational{Int64}}", :rational2, N07N08Rational2V1(ex.boundary_patches[1].lower)),
        N07N08FieldV1("N07-05", "/g2/plan/exterior/boundary_condition", "G2ExteriorPlanV2.boundary_condition::Symbol", :symbol, N07N08SymbolValueV1(ex.boundary_condition)),
        N07N08FieldV1("N08-01", "/g2/plan/chart/axes", "G2ChartPlanV2.axes::NTuple{3,Symbol}", :symbol_tuple, N07N08SymbolTupleV1(g2.plan.chart.axes)),
        N07N08FieldV1("N08-02", "/g2/plan/chart/map_kind", "G2ChartPlanV2.map_kind::Symbol", :symbol, N07N08SymbolValueV1(g2.plan.chart.map_kind)),
        N07N08FieldV1("N08-03", "/g2/plan/mesh/cells_per_region", "G2MeshPlanV2.cells_per_region::NTuple{3,Int}", :int3, N07N08Int3V1(g2.plan.mesh.cells_per_region)),
        N07N08FieldV1("N08-04", "/g2/plan/mesh/basis", "G2MeshPlanV2.basis::Symbol", :symbol, N07N08SymbolValueV1(g2.plan.mesh.basis)),
        N07N08FieldV1("N08-05", "/g2/contract/interfaces", "RegionInterfaceContractV2.interfaces::Tuple", :interface_refs, N07N08InterfaceRefsV1(irefs)))
    N07N08ProjectionV1(candidate_ref, package_hash, rs, faces, patch.face,
        patch.region_id, patch.upper, interfaces, fields,
        canonical_hash((candidate_ref=candidate_ref, package_hash=package_hash,
            regions=rs, required_faces=faces, patch_face=patch.face,
            patch_region=patch.region_id, patch_upper=patch.upper,
            interfaces=interfaces, fields=fields)))
end

function n07_n08_projection_from_a(package::CandidateStatePackageV5)
    package.structural_status == :valid || throw(ArgumentError("N07/N08 requires a valid A package"))
    package.g2 isa FieldGeometryGenomeV5 || throw(ArgumentError("A package G2 component is not FieldGeometryGenomeV5"))
    package.g2_binding.candidate_ref == package.candidate_ref ||
        throw(ArgumentError("A package G2 candidate binding does not match package candidate"))
    package.g2_binding.genome_hash == package.g2.candidate_hash ||
        throw(ArgumentError("A package G2 binding hash does not match the actual G2 component"))
    package.component_identity.g2_genome_hash == package.g2.candidate_hash ||
        throw(ArgumentError("A package component identity does not match the actual G2 component"))
    expected_package_hash = canonical_hash((package_version="v5",
        candidate_ref=package.candidate_ref, component_identity=package.component_identity,
        version_axes=package.version_axes, migration_receipt=package.migration_receipt))
    package.candidate_hash == expected_package_hash ||
        throw(ArgumentError("A package candidate hash is not derived from its identity and receipt"))
    n07_n08_projection_from_g2(package.g2, package.candidate_ref, package.candidate_hash)
end

function _n07n08_copy(p, id, value)
    old = _n07n08_field(p, id)
    fields = Tuple(x.id == id ? N07N08FieldV1(x.id, x.field_path,
        x.source_locator, x.source_type, value) : x for x in p.fields)
    N07N08ProjectionV1(p.candidate_ref, p.package_hash, p.regions,
        p.required_faces, p.patch_face, p.patch_region, p.patch_upper,
        p.interfaces, fields, canonical_hash((candidate_ref=p.candidate_ref,
            package_hash=p.package_hash, regions=p.regions,
            required_faces=p.required_faces, patch_face=p.patch_face,
            patch_region=p.patch_region, patch_upper=p.patch_upper,
            interfaces=p.interfaces, fields=fields)))
end

function _n07n08_mutate(p, spec::N07N08MutationSpecV1)
    spec.mutation_kind === :lower_out_of_domain && return _n07n08_copy(p, spec.id, N07N08Rational3V1((-1 // 1, 0 // 1, 0 // 1)))
    spec.mutation_kind === :upper_out_of_domain && return _n07n08_copy(p, spec.id, N07N08Rational3V1((3 // 1, 1 // 1, 1 // 1)))
    spec.mutation_kind === :drop_face && return _n07n08_copy(p, spec.id, N07N08SymbolTupleV1(Tuple(x for x in p.required_faces if x !== :x_min)))
    spec.mutation_kind === :patch_out_of_domain && return _n07n08_copy(p, spec.id, N07N08Rational2V1((-1 // 1, 0 // 1)))
    spec.mutation_kind === :none_condition && return _n07n08_copy(p, spec.id, N07N08SymbolValueV1(:none_declared))
    spec.mutation_kind === :axes_invalid && return _n07n08_copy(p, spec.id, N07N08SymbolTupleV1((:x, :y, :q)))
    spec.mutation_kind === :map_invalid && return _n07n08_copy(p, spec.id, N07N08SymbolValueV1(:invalid_map))
    spec.mutation_kind === :cells_nonpositive && return _n07n08_copy(p, spec.id, N07N08Int3V1((0, 2, 2)))
    spec.mutation_kind === :basis_invalid && return _n07n08_copy(p, spec.id, N07N08SymbolValueV1(:spectral))
    spec.mutation_kind === :duplicate_interface && return _n07n08_copy(p, spec.id, N07N08InterfaceRefsV1((first(_n07n08_field(p, "N08-05").value.value), first(_n07n08_field(p, "N08-05").value.value))))
    throw(ArgumentError("unknown N07/N08 mutation $(spec.id)"))
end

function _n07n08_bounds_valid(p, lower, upper)
    global_lower = ntuple(i -> minimum(r.lower[i] for r in p.regions), 3)
    global_upper = ntuple(i -> maximum(r.upper[i] for r in p.regions), 3)
    all(lower[i] < upper[i] && global_lower[i] <= lower[i] <= global_upper[i] &&
        global_lower[i] <= upper[i] <= global_upper[i] for i in 1:3)
end

_n07n08_tangent_axes(face::Symbol) = face === :x_min || face === :x_max ? (2, 3) :
    face === :y_min || face === :y_max ? (1, 3) :
    face === :z_min || face === :z_max ? (1, 2) : throw(ArgumentError("unknown boundary face"))

function _n07n08_classify(p, q, spec)
    v = _n07n08_field(q, spec.id).value
    if spec.id === "N07-01"
        v isa N07N08Rational3V1 && _n07n08_bounds_valid(p, v.value, p.regions[1].upper) && return nothing
        return (:invalid_boundary, :fail_closed)
    elseif spec.id === "N07-02"
        v isa N07N08Rational3V1 && _n07n08_bounds_valid(p, p.regions[1].lower, v.value) && return nothing
        return (:invalid_boundary, :fail_closed)
    elseif spec.id === "N07-03"
        v isa N07N08SymbolTupleV1 && all(x -> x in v.value, p.required_faces) && return nothing
        return (:invalid_boundary, :fail_closed)
    elseif spec.id === "N07-04"
        region = first(r for r in p.regions if r.id == p.patch_region)
        axes = _n07n08_tangent_axes(p.patch_face)
        v isa N07N08Rational2V1 && all(region.lower[axes[i]] <= v.value[i] <= region.upper[axes[i]] for i in 1:2) && return nothing
        return (:invalid_boundary, :fail_closed)
    elseif spec.id === "N07-05"
        v isa N07N08SymbolValueV1 && v.value !== :none_declared && return nothing
        return (:invalid_boundary, :fail_closed)
    elseif spec.id === "N08-01"
        v isa N07N08SymbolTupleV1 && v.value === (:x, :y, :z) && return nothing
        return (:invalid_boundary, :fail_closed)
    elseif spec.id === "N08-02"
        v isa N07N08SymbolValueV1 && v.value in (:identity, :declared_map) && return nothing
        return (:invalid_boundary, :fail_closed)
    elseif spec.id === "N08-03"
        v isa N07N08Int3V1 && all(x -> x >= 1, v.value) && return nothing
        return (:invalid_boundary, :fail_closed)
    elseif spec.id === "N08-04"
        v isa N07N08SymbolValueV1 && v.value in (:linear, :quadratic) && return nothing
        return (:invalid_boundary, :fail_closed)
    elseif spec.id === "N08-05"
        v isa N07N08InterfaceRefsV1 && length(v.value) == length(p.interfaces) &&
            length(unique(v.value)) == length(v.value) &&
            all(i -> i.ref in v.value, p.interfaces) && return nothing
        return (:invalid_boundary, :fail_closed)
    end
    nothing
end

function n07_n08_validate_mutation(p::N07N08ProjectionV1, spec::N07N08MutationSpecV1;
        counter=N07N08InvocationCounterV1())
    field = _n07n08_field(p, spec.id)
    field.field_path == spec.field_path && field.source_locator == spec.source_locator &&
        field.source_type == spec.source_type ||
        throw(ArgumentError("N07/N08 mutation metadata does not bind to the projected field"))
    q = _n07n08_mutate(p, spec)
    classified = _n07n08_classify(p, q, spec)
    classified === nothing && throw(ArgumentError("N07/N08 mutation did not violate its typed invariant"))
    code, status = classified
    result_hash = canonical_hash((mutation_id=spec.id, input_hash=p.projection_hash,
        mutated_input_hash=q.projection_hash, error_code=code, error_path=spec.field_path,
        compile_calls=counter.compile_calls, provider_calls=counter.provider_calls,
        solver_calls=counter.solver_calls, scope=:schema_validation_only))
    N07N08ValidationResultV1(spec.id, p.projection_hash, q.projection_hash,
        status, code, spec.field_path, counter.compile_calls, counter.provider_calls,
        counter.solver_calls, result_hash)
end
