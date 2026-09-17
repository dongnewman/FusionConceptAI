module UP2ModuleEntryFailureProbe

const entry_path = abspath(ARGS[1])

# Keep the published layer order but inject a no-op component loader. The first
# counter definition is then included, while the next contract definition
# fails because its real base types are absent. This observes a genuine partial
# include and tests that the failure is terminal for this process.
genome_v5_component_layer_order() = (:G1, :G2, :G3)
load_genome_v5_components!() = nothing

Base.include(@__MODULE__, entry_path)
first_error = try
    load_genome_v5_up2_components!()
    nothing
catch err
    err
end
first_error === nothing && error("first failure was not raised")
isdefined(@__MODULE__, :UP2InvocationCounterV1) ||
    error("controlled failure did not occur after a partial UP2 include")
up2_module_load_state() == :failed || error("failed state was not terminal")

second_error = try
    load_genome_v5_up2_components!()
    nothing
catch err
    err
end
second_error === nothing && error("failed-state retry was not rejected")
occursin("previously failed", sprint(showerror, second_error)) ||
    error("failed-state retry did not require a fresh process")

end
