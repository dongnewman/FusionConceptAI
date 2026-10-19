#!/usr/bin/env julia

# Syntax-only lane preflight.  It deliberately does not include or execute any
# target file.  Meta.parseall can embed Expr(:error), so inspect the full tree
# instead of accepting a returned expression at face value.

using SHA

function parse_errors!(found, value)
    if value isa Expr
        value.head === :error && push!(found, sprint(show, value))
        for argument in value.args
            parse_errors!(found, argument)
        end
    elseif value isa AbstractArray || value isa Tuple
        for item in value
            parse_errors!(found, item)
        end
    end
    found
end

isempty(ARGS) && error("at least one Julia source is required")
for argument in ARGS
    path = abspath(argument)
    isfile(path) || error("missing syntax-preflight source: $path")
    expression = Meta.parseall(read(path, String); filename=path)
    errors = parse_errors!(String[], expression)
    isempty(errors) || error("syntax errors in $path: $(join(errors, ';'))")
    println("UP2_BOUNDED_PARSE_PASS path=", path,
        " sha256=", bytes2hex(SHA.sha256(read(path))))
end
println("UP2_BOUNDED_PARSE_COUNT=", length(ARGS))
println("UP2_BOUNDED_PARSE_EXIT_CODE=0")
