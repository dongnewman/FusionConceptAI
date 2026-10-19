using Test, SHA, Dates
using FusionConceptAI
const G = FusionConceptAI
const ROOT = normpath(joinpath(@__DIR__, "..", "..", "..", ".."))
const ORIGINAL = joinpath(@__DIR__, "..", "vnext_t1_candidate_state_package_v5_next_tests.jl")
bytes2hex(sha256(read(ORIGINAL))) == "970976c4122fc6b4f5303d6763c286514b1c9dc653aba36d46e1d003bcbf9669" || error("frozen test changed")

# Load exact fixture/helper definitions. This isolated mechanism probe makes no
# assertion-coverage claim and never emits the original regression markers.
fixture_definitions = expression -> begin
    if expression isa Expr
        expression.head === :macrocall && string(expression.args[1]) == "@testset" && return nothing
        expression.head === :call && expression.args[1] === :println && return nothing
    end
    expression
end
Base.include(fixture_definitions, Main, ORIGINAL)

source = read(joinpath(ROOT, "src/Contracts/CandidateStatePackageV5Next.jl"), String)
start = first(findfirst("struct VNextT1T0GateV1{", source))
stop = first(findnext("\n\"\"\"Candidate-bound, non-executed T1 package", source, start))
original_gate = source[start:prevind(source, stop)]
candidate = replace(original_gate, "VNextT1T0GateV1" => "VNextT1T0GateR18Probe")
rewrites = (
    "function VNextT1T0GateR18Probe(prior_bundle::VNextT1PriorBundleSnapshotV1{B}," =>
        "@noinline Base.@nospecializeinfer function VNextT1T0GateR18Probe(@nospecialize(prior_bundle::VNextT1PriorBundleSnapshotV1),",
    "output_bytes::VNextT1CanonicalBytesV1{O}," => "@nospecialize(output_bytes::VNextT1CanonicalBytesV1),",
    "where {B,O,F}" => "where {F}",
    "new{B,O,F}(" => "new{length(prior_bundle.canonical_bytes.bytes),length(output_bytes.bytes),F}(")
for (old, new) in rewrites
    length(findall(old, candidate)) == 1 || error("unexpected constructor shape: $old")
    global candidate = replace(candidate, old => new)
end
# These are the only substitutions. All field declarations and validation
# statements (including their order) are copied directly from current source.
Base.include_string(G, candidate, "r18_gate_candidate_from_current_source.jl")
println("R18_GATE_CANDIDATE_DEFINED source_sha256=", bytes2hex(sha256(Vector{UInt8}(codeunits(original_gate))))); flush(stdout)

fixture = Main._t1_fixture()
input = Main._t1_input(fixture)
prior = G._vnext_t1_snapshot(input)
declarations = G._vnext_t1_declaration_tuple(input.transport, input.candidate_ref)
children = G._vnext_t1_child_tuple(input.transport, input.candidate_ref)
raw_declarations = ntuple(i -> input.transport.declarations[i]::G.VNextT0LocalPresentDeclarationV1, 3)
feedback = G._vnext_t1_feedback_tuple(Tuple(input.transport.feedback), raw_declarations, input.candidate_ref)
F = length(feedback)
projection = G.VNextT1T0OutputProjectionV1{F}(input.candidate_ref, input.transport.bundle_hash, declarations, children, feedback)
projection_text = G.canonical_json(projection)
owned = G.VNextT1CanonicalBytesV1(Vector{UInt8}(codeunits(projection_text)))
output_hash = G.canonical_hash(projection)
child_hashes = ntuple(i -> children[i] isa G.VNextT1PresentChildRecordV1 ?
    children[i].child_identity_hash : children[i].factory_receipt_hash, 3)
identity = G.VNextT1T0OutputIdentityV1{F}(input.candidate_ref, input.transport.bundle_hash,
    ntuple(i -> declarations[i].declaration_identity_hash, 3), child_hashes,
    ntuple(i -> G.canonical_hash(feedback[i]), F), output_hash)
args = Any[prior, input.candidate_ref, :local_checked_present, :resolved, false,
    :contract_only, projection, owned, identity, output_hash]
println("R18_GATE_INPUT_READY B=$(length(prior.canonical_bytes.bytes)) O=$(length(owned.bytes)) F=$F"); flush(stdout)

@testset "R18 isolated gate constructor exact fields and checks" begin
    started = time_ns()
    gate = G.VNextT1T0GateR18Probe(args...)
    println("R18_GATE_POSITIVE_SECONDS=", (time_ns() - started) / 1e9); flush(stdout)
    @test Tuple(typeof(gate).parameters) == (length(prior.canonical_bytes.bytes), length(owned.bytes), F)
    @test all(getfield(gate, i) === args[i] for i in eachindex(args))
    @test G.canonical_json(gate.output_projection) == projection_text
    @test gate.output_bytes.sha256 == G._vnext_t1_sha(Vector{UInt8}(codeunits(projection_text)))
    @test gate.output_hash == output_hash
    original_field_projection = NamedTuple{fieldnames(typeof(gate))}(Tuple(args))
    @test G.canonical_json(gate) == G.canonical_json(original_field_projection)
    @test G.canonical_hash(gate) == G.canonical_hash(original_field_projection)

    wrong_hash = G.digest256_text("r18-gate-wrong-hash")
    corrupt_sha = ccall(:jl_new_struct, Any, (Any, Any, Any), typeof(owned), owned.bytes, wrong_hash)
    wrong_identity = typeof(identity)(identity.candidate_ref, identity.bundle_hash,
        identity.declaration_identity_hashes, identity.child_identity_hashes,
        identity.feedback_hashes, wrong_hash)
    tiny = G.VNextT1CanonicalBytesV1(UInt8[0xff])
    mutations = (
        (1, a -> (a[2] = G.QualifiedRefV1(input.candidate_ref.id, "wrong")), "T1 gate candidate must carry v5 version"),
        (2, a -> (a[3] = :invalid), "T1 requires local_checked_present"),
        (3, a -> (a[4] = :none), "T1 requires resolved T0 recheck"),
        (4, a -> (a[5] = true), "T0 accepted=true is not a T1 input"),
        (5, a -> (a[6] = :physical), "T0 claim ceiling must be contract_only"),
        (6, a -> (a[10] = wrong_hash), "T0 output identity/hash mismatch"),
        (7, a -> (a[8] = tiny), "T0 output projection bytes mismatch"),
        (8, a -> (a[8] = corrupt_sha), "T0 output bytes/hash mismatch"),
        (9, a -> (a[9] = wrong_identity; a[10] = wrong_hash), "T0 output projection hash mismatch"))
    for (index, mutate, message) in mutations
        @test occursin("throw(ArgumentError(\"" * message * "\"))", original_gate)
        altered = copy(args); mutate(altered)
        err = try G.VNextT1T0GateR18Probe(altered...); nothing catch e; e end
        @test err isa ArgumentError
        @test err.msg == message
        println("R18_GATE_NEGATIVE index=$index message=$message"); flush(stdout)
        GC.gc()
    end
    # Simultaneous early errors verify the unchanged first-error ordering.
    for index in 1:5
        altered = copy(args)
        mutations[index][2](altered); mutations[index + 1][2](altered)
        err = try G.VNextT1T0GateR18Probe(altered...); nothing catch e; e end
        @test err isa ArgumentError
        @test err.msg == mutations[index][3]
    end
    @test G.canonical_json(projection) == projection_text
    @test owned.sha256 == G._vnext_t1_sha(Vector{UInt8}(codeunits(projection_text)))
end
println("R18_GATE_CONSTRUCTOR_PROBE_PASS"); flush(stdout)
