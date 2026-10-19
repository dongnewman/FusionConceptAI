# R22b authorized one-shot replay; retains R22 runtime checks and substitutes
# the pinned exact canonical hash formula on saved complete canonical Strings.
include(joinpath(@__DIR__, "immutable_package_closure.jl"))

Base.@noinline Base.@nospecializeinfer function r22_inventory!(@nospecialize(x), path::String, rows)
    T = typeof(x)
    if x isa String || x isa Symbol
        push!(rows, (path=path, type=string(T), classification="language_immutable_special",
            internal_mutable_flag=ismutable(x)))
    elseif isbitstype(T)
        push!(rows, (path=path, type=string(T), classification="isbits_value_subtree"))
    else
        ismutable(x) && error("actual mutable object in package: $path")
        push!(rows, (path=path, type=string(T), classification="immutable_composite",
            field_count=nfields(x)))
        for index in 1:nfields(x)
            isdefined(x, index) || error("undefined legal-package field: $path")
            r22_inventory!(getfield(x, index), path * "." * string(fieldname(T, index)), rows)
        end
    end
end
Base.@noinline Base.@nospecializeinfer function r22_field_parity!(@nospecialize(original), @nospecialize(native), path::String, rows)
    T = typeof(original)
    T === typeof(native) || error("native type differs: $path")
    if original isa String || original isa Symbol || isbitstype(T)
        original === native || error("immutable value differs: $path")
        if original isa String
            original == native && hash(original) == hash(native) || error("String value/hash differs: $path")
        end
        push!(rows, (path=path, type=string(T), check="complete_leaf_or_isbits_value_equal", passed=true))
    else
        !ismutable(original) && !ismutable(native) || error("mutable value found: $path")
        nfields(original) == nfields(native) || error("field count differs")
        push!(rows, (path=path, type=string(T), check="all_fields_recursive", passed=true,
            field_count=nfields(original)))
        for index in 1:nfields(original)
            r22_field_parity!(getfield(original, index), getfield(native, index),
                path * "." * string(fieldname(T, index)), rows)
        end
    end
end
Base.@noinline Base.@nospecializeinfer r22_identical(@nospecialize(a), @nospecialize(b)) = a === b

length(ARGS) == 1 || error("usage: <new-runtime-evidence-dir>")
directory = r22_out(ARGS[1])
# Pin the exact existing formulas before building the fixture. These formulas
# define hashes over complete canonical bytes, not the separate package domain.
hash_source = read(joinpath(R22_ROOT, "src/Canonical/Hashes.jl"), String)
types_source = read(joinpath(R22_ROOT, "src/IR/PhysicalTypes.jl"), String)
hash_lines = split(replace(hash_source, "\r\n" => "\n"), '\n')
types_lines = split(replace(types_source, "\r\n" => "\n"), '\n')
hash_line = only(findall(==("function canonical_hash(x)"), hash_lines))
hash_formula = join(hash_lines[hash_line:hash_line+3], "\n")
expected_hash_formula = "function canonical_hash(x)\n    Base.@nospecialize x\n    Digest256(bytes2hex(SHA.sha256(Vector{UInt8}(codeunits(canonical_json(x))))))\nend"
hash_formula == expected_hash_formula || error("canonical_hash formula drift")
digest_line = only(findall(line -> startswith(line, "digest256_text(s::AbstractString) ="), types_lines))
digest_formula = types_lines[digest_line]
digest_formula == "digest256_text(s::AbstractString) = Digest256(bytes2hex(SHA.sha256(Vector{UInt8}(codeunits(String(s))))))" ||
    error("digest256_text formula drift")
formula_rows = ((file="src/Canonical/Hashes.jl", line=hash_line,
        formula=hash_formula, formula_sha256=bytes2hex(sha256(codeunits(hash_formula))),
        source_sha256=bytes2hex(sha256(codeunits(hash_source)))),
    (file="src/IR/PhysicalTypes.jl", line=digest_line,
        formula=digest_formula, formula_sha256=bytes2hex(sha256(codeunits(digest_formula))),
        source_sha256=bytes2hex(sha256(codeunits(types_source)))))
r22_write(joinpath(directory, "hash_formula_preregistration.json"),
    (formulas=formula_rows,
        evaluation="Digest256(bytes2hex(SHA.sha256(Vector{UInt8}(codeunits(already_generated_canonical_String))))))",
        different_domain_note="Complete object canonical digest is not package.package_hash; package hash is checked only against unchanged native/original/candidate package fields.",
        generic_object_hash_api_not_executed=true, formal_T1=false))
closure_rows = r22_static()
r22_write(joinpath(directory, "closure_before_runtime.json"),
    (rows=closure_rows, generic_closure=true, before_protected=R22_BEFORE, formal_T1=false))

r22_mark("fixture:before")
fixture = _t1_fixture()
r22_mark("fixture:after")
r22_mark("public_admission:before")
admitted = G.vnext_t1_admit_skeleton_v1(_t1_input(fixture))
admitted.status === :prepared_not_executed && admitted.package isa G.CandidateStatePackageV5Next ||
    error("public admission failed")
package = admitted.package
r22_mark("public_admission:after")
inventory_rows = Any[]
r22_inventory!(package, "package", inventory_rows)
r22_write(joinpath(directory, "actual_inventory.json"),
    (package_type=string(typeof(package)), rows=inventory_rows, legally_mutable_values=0,
        prior_length=length(package.t0_gate.prior_bundle.canonical_bytes.bytes),
        output_length=length(package.t0_gate.output_bytes.bytes), formal_T1=false))
package_hash_before = package.package_hash
GC.gc()
r22_mark("native_copy:before")
native_start = time_ns()
native_copy = deepcopy(package)
native_seconds = (time_ns() - native_start) / 1e9
r22_mark("native_copy:after")

# This is an in-process standalone candidate only. No product source is edited.
# The generic type closure above is a required precondition for installing it.
Base.@noinline Base.@nospecializeinfer function Base.deepcopy_internal(
        @nospecialize(x::G.CandidateStatePackageV5Next), stackdict::IdDict)
    x
end
r22_mark("identity_candidate_copy:before")
candidate_start = time_ns()
candidate_copy = deepcopy(package)
candidate_seconds = (time_ns() - candidate_start) / 1e9
r22_mark("identity_candidate_copy:after")
field_rows = Any[]
r22_field_parity!(candidate_copy, native_copy, "package", field_rows)
r22_mark("field_parity:after")

@testset "R22 immutable package identity and mutable outer graph" begin
    @test typeof(candidate_copy) === typeof(native_copy) === typeof(package)
    @test r22_identical(candidate_copy, native_copy)
    @test r22_identical(candidate_copy, package)
    @test objectid(candidate_copy) == objectid(native_copy) == objectid(package)
    @test hash(candidate_copy) == hash(native_copy) == hash(package)
    @test candidate_copy.package_hash == native_copy.package_hash == package_hash_before
    # Actual mutable containers still use Base copying, including their cycles.
    outer = Any[package, package]
    push!(outer, outer)
    copied_outer = deepcopy(outer)
    @test copied_outer !== outer
    @test copied_outer[1] === copied_outer[2] === package
    @test copied_outer[3] === copied_outer
    copied_outer[1] = :changed_outer_copy
    @test outer[1] === package
    # The package method does not clobber unrelated existing copy mappings.
    key = Any[:existing]
    value = Any[:copied_existing]
    stack = IdDict(key => value)
    @test Base.deepcopy_internal(package, stack) === package
    @test length(stack) == 1 && stack[key] === value
    larger = Any[key, package, key]
    copied_larger = Base.deepcopy_internal(larger, stack)
    @test copied_larger !== larger
    @test copied_larger[1] === value && copied_larger[3] === value
    @test copied_larger[2] === package
    @test stack[key] === value && stack[larger] === copied_larger
end
r22_mark("identity_stackdict_checks:after")
R22_BEFORE == r22_pins() || error("protected inputs changed")
r22_write(joinpath(directory, "copy_field_identity_result.json"),
    (verdict="copy_and_value_semantics_only_canonical_pending", formal_T1=false,
        native_seconds=native_seconds, candidate_seconds=candidate_seconds,
        root_field_count=nfields(package), all_recursive_field_rows=field_rows,
        legally_mutable_values=0, value_identity_unchanged=true, outer_mutable_graph_preserved=true,
        before_protected=R22_BEFORE, after_protected=r22_pins(),
        physical_pointer_equivalence_claimed=false,
        stackdict_scope="preserve existing legitimate outer mutable mappings and cycles",
        package_hash_equal=true, complete_canonical_equal="not_executed"))

# Keep the complete public canonical calls; a timeout is not a parity result.
r22_mark("native_complete_canonical:before")
native_canonical = G.canonical_json(native_copy)
r22_mark("native_complete_canonical:after")
r22_mark("candidate_complete_canonical:before")
candidate_canonical = G.canonical_json(candidate_copy)
r22_mark("candidate_complete_canonical:after")
native_canonical == candidate_canonical || error("complete canonical bytes changed")
r22_mark("canonical_bytes_equal:after")
# This is the pinned Hashes.jl formula after substituting the already computed
# canonical String for canonical_json(x); no product/hash method is rewritten.
r22_digest(canonical::String) = G.Digest256(bytes2hex(SHA.sha256(Vector{UInt8}(codeunits(canonical)))))
r22_mark("canonical_digest_formula:before")
native_digest = r22_digest(native_canonical)
candidate_digest = r22_digest(candidate_canonical)
native_digest == candidate_digest || error("complete canonical hash changed")
native_copy.package_hash == candidate_copy.package_hash == package_hash_before ||
    error("package-domain hash changed")
r22_mark("canonical_digest_formula:after")
for (name, canonical) in (("native.canonical.json", native_canonical), ("candidate.canonical.json", candidate_canonical))
    file = joinpath(directory, name)
    ispath(file) && error("existing complete canonical artifact")
    written = open(io -> write(io, canonical), file, "w")
    written == sizeof(canonical) || error("partial canonical artifact")
end
read(joinpath(R22_ROOT, "src/Canonical/Hashes.jl"), String) == hash_source || error("hash source changed")
read(joinpath(R22_ROOT, "src/IR/PhysicalTypes.jl"), String) == types_source || error("digest source changed")
r22_mark("complete_canonical_artifacts:after")
R22_BEFORE == r22_pins() || error("protected inputs changed")
r22_write(joinpath(directory, "complete_semantic_result.json"),
    (verdict="standalone_semantic_candidate_only_requires_independent_review", formal_T1=false,
        complete_canonical_equal=true, complete_canonical_hash_equal=true,
        canonical_length=sizeof(native_canonical),
        canonical_sha256=string(native_digest),
        native_canonical_file="native.canonical.json", candidate_canonical_file="candidate.canonical.json",
        hash_formulas=formula_rows, hash_scope="exact current formula over saved complete canonical bytes",
        generic_object_hash_api_not_executed=true, separate_package_hash_unchanged=true,
        native_copy_seconds=native_seconds, candidate_copy_seconds=candidate_seconds,
        before_protected=R22_BEFORE, after_protected=r22_pins(),
        actual_model_attestation="unavailable"))
println("R22_COMPLETE_SEMANTIC_PARITY_NOT_FORMAL"); flush(stdout)
