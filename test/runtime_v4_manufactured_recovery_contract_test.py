"""Fast static contract checks; deliberately does not import or run Julia."""
from pathlib import Path

source = Path(__file__).parents[1] / "scripts" / "runtime_v4_manufactured_recovery_benchmark.jl"
text = source.read_text(encoding="utf-8")
assert "source=Tuple(-v/(_MU0*R) for v in eR)" in text
assert "SPF._smr_stress(collect(q.B),q.p)*collect(normal)" in text
assert "dot(collect(manufactured_field(xyz).B),collect(normal))" in text
assert "flux_Wb=pi" in text
assert "append!(x,[0.,_BPHI,0.,_P0])" in text
for token in ("(:h05,1", "(:h033,1", "(:h025,1", "rho=(0.,1/3,.5,2/3,1.)",
              "observed_orders", "truth_scaled_residual_max", "stopping_reason",
              "initial_solution_relative_error", "all_accepted_updates_strict",
              "nonconverged_or_invalid_endpoint", "declaration=d,data=",
              "DEFAULT_RESOLUTIONS", "max_iterations=max_iterations",
              "production_source_sha256", "canonical_json"):
    assert token in text, token
print("manufactured recovery contract: PASS")
