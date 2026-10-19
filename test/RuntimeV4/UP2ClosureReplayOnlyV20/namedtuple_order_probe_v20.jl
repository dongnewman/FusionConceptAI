# Lightweight Julia 1.10.5 semantic probe for NamedTuple-key order container equality.
# This script does not load project modules, read replay inputs, invoke a solver, or run a consumer.
schema_names = (:value,)
@assert VERSION == v"1.10.5"
declared_order = String.(schema_names)
exact_value = (value="candidate_hash",)

v19_canonical_order = sort!(collect(declared_order))
exact_order = String.(keys(exact_value))
@assert v19_canonical_order isa Vector{String}
@assert exact_order isa Tuple{String}
@assert exact_order != v19_canonical_order

v20_canonical_order = Tuple(sort!(collect(declared_order)))
@assert v20_canonical_order isa Tuple{String}
@assert exact_order == v20_canonical_order

println("V20_NAMEDTUPLE_ORDER_PROBE_PASS julia_version=$(VERSION) v19_canonical=$(typeof(v19_canonical_order)) exact=$(typeof(exact_order)) v19_equal=$(exact_order == v19_canonical_order) v20_canonical=$(typeof(v20_canonical_order)) v20_equal=$(exact_order == v20_canonical_order)")
