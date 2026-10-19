using Test, SHA, JSON3

const R23_ROOT = normpath(joinpath(@__DIR__, "..", "..", "..", ".."))
length(ARGS) == 2 || error("usage: <new-static-manifest> <new-evidence-dir>")
const R23_MANIFEST = joinpath(R23_ROOT, ARGS[1])
const R23_CLOSURE = joinpath(R23_ROOT, "test/GenomeV5/Integration/VNextT1V1R22/immutable_package_closure.jl")
uppercase(bytes2hex(sha256(read(R23_CLOSURE)))) ==
    "BE3F9038951B4379FF196EBE8E8C1D333ADB8EF25CBF6625CE566EF8D2DF0144" || error("reviewed closure checker drift")
function checked_parse(path)
    function check(x)
        x isa Expr || return
        x.head in (:error, :incomplete) && error("parse error: $path")
        foreach(check, x.args)
    end
    check(Meta.parseall(read(path, String)))
end
checked_parse(joinpath(R23_ROOT, "src/Contracts/CandidateStatePackageV5Next.jl"))
checked_parse(@__FILE__)
checked_parse(R23_CLOSURE)
const R23_PIN_SUBSTITUTIONS = Ref(0)
Base.include(Main, R23_CLOSURE) do expression
    if expression isa Expr && expression.head === :const && length(expression.args) == 1
        assignment = only(expression.args)
        if assignment isa Expr && assignment.head === :(=) && assignment.args[1] === :R22_PINS_PATH
            R23_PIN_SUBSTITUTIONS[] += 1
            return :(const R22_PINS_PATH = $R23_MANIFEST)
        end
    end
    expression
end
R23_PIN_SUBSTITUTIONS[] == 1 || error("closure pin-path substitution not exact")
rows = r22_static()
@testset "R23 exact installed owned deepcopy method" begin
    method = which(Base.deepcopy_internal, Tuple{G.CandidateStatePackageV5Next,IdDict})
    @test method.module === G
    @test method.sig == Tuple{typeof(Base.deepcopy_internal),G.CandidateStatePackageV5Next,IdDict}
    @test occursin("CandidateStatePackageV5Next.jl", string(method.file))
    @test method.nargs == 3
    @test R22_BEFORE == r22_pins()
end
directory = r22_out(ARGS[2])
r22_write(joinpath(directory, "post_delta04_checks.json"),
    (parse_files=3, generic_closure_rows=rows, pin_path_substitutions=1,
        installed_method="Base.deepcopy_internal(::CandidateStatePackageV5Next,::IdDict)",
        before_protected=R22_BEFORE, after_protected=r22_pins(), formal_T1=false))
println("R23_POST_DELTA04_STATIC_CLOSURE_PASS"); flush(stdout)
