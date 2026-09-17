from __future__ import annotations

import hashlib
import json
import os
import pathlib
import subprocess
import sys
from datetime import datetime, timezone

ROOT = pathlib.Path(__file__).resolve().parents[4]
OUT = pathlib.Path(__file__).resolve().parent


def now():
    return datetime.now(timezone.utc).isoformat()


def sha256(path: pathlib.Path):
    data = path.read_bytes()
    return hashlib.sha256(data).hexdigest(), len(data)


def run(name, argv, cwd=ROOT):
    started = now()
    p = subprocess.run(argv, cwd=cwd, text=True, encoding="utf-8", errors="replace", capture_output=True)
    finished = now()
    return {
        "name": name,
        "argv": [str(x) for x in argv],
        "started_utc": started,
        "finished_utc": finished,
        "exit": p.returncode,
        "stdout": p.stdout,
        "stderr": p.stderr,
    }


source_paths = [
    "src/RuntimeV4/Compiler.jl",
    "src/RuntimeV4/FieldProgramEvaluation.jl",
    "src/RuntimeV4/FieldResidualPipeline.jl",
    "src/RuntimeV4/SpatialRuntimeV4.jl",
    "src/RuntimeV4/SpatialMultiRegionV4.jl",
    "src/Contracts/CandidateStatePackageV5.jl",
    "src/GenomeV5/G1/MechanismGenomeV5.jl",
    "src/GenomeV5/G1/EquationPlanV2.jl",
    "src/GenomeV5/G1/GrammarProfileV2.jl",
    "src/GenomeV5/G2/FieldGeometryGenomeV5.jl",
    "src/GenomeV5/G2/FieldSpacePlanV2.jl",
    "src/GenomeV5/G2/RegionInterfaceContractV2.jl",
    "src/GenomeV5/G3/RealizationGenomeV5.jl",
    "src/GenomeV5/G3/CoupledRealizationControlBindingV2.jl",
    "src/GenomeV5/G3/ControlGenomeV5.jl",
    "src/FusionConceptAI.jl",
    "docs/v4_multitopology_generation/README.md",
    "docs/v4_multitopology_generation/11_physics_compilation_and_discretization.md",
    "docs/v4_multitopology_generation/16_execution_work_orders.md",
    "docs/implementation/W24-G2-CHILD-R2/acceptance.md",
    "docs/implementation/W24-G2-CHILD-R2/evidence_manifest.json",
    "runs/goal_recovery_20260913_012528_cst/w24_spatial_parent_r1/result.json",
    "runs/goal_recovery_20260913_012528_cst/w24_spatial_g2_child_r2/result.json",
    "runs/goal_recovery_20260913_012528_cst/w24_spatial_g2_child_r2/verification.json",
]

source_hashes = {}
for rel in source_paths:
    p = ROOT / rel
    if p.is_file():
        digest, size = sha256(p)
        source_hashes[rel] = {"bytes": size, "sha256": digest, "exists": True}
    else:
        source_hashes[rel] = {"bytes": None, "sha256": None, "exists": False}

commands = []
commands.append(run("git_head", ["git", "rev-parse", "HEAD"]))
status = run("git_status_porcelain", ["git", "status", "--porcelain=v1"])
commands.append(status)
(OUT / "git_status_porcelain.txt").write_text(status["stdout"], encoding="utf-8")
process = run(
    "julia_desc_process_sweep",
    [
        "powershell",
        "-NoProfile",
        "-Command",
        "Get-CimInstance Win32_Process | Where-Object { $_.Name -match '^(julia|desc)(\\.exe)?$' } | Select-Object ProcessId,ParentProcessId,Name,CommandLine | ConvertTo-Json -Compress",
    ],
)
commands.append(process)
commands.append(
    run(
        "json_parse",
        [
            sys.executable,
            "-c",
            "import json; from pathlib import Path; [json.loads(Path(p).read_text(encoding='utf-8')) for p in ['docs/implementation/W24-G2-CHILD-R2/evidence_manifest.json','runs/goal_recovery_20260913_012528_cst/w24_spatial_parent_r1/result.json','runs/goal_recovery_20260913_012528_cst/w24_spatial_g2_child_r2/result.json','runs/goal_recovery_20260913_012528_cst/w24_spatial_g2_child_r2/verification.json']]",
        ],
    )
)
commands.append(run("validate_plan", [sys.executable, "docs/v4_multitopology_generation/validate_plan.py"]))
commands.append(run("git_diff_check", ["git", "diff", "--check"]))

def load(rel):
    return json.loads((ROOT / rel).read_text(encoding="utf-8"))


child_result = load("runs/goal_recovery_20260913_012528_cst/w24_spatial_g2_child_r2/result.json")
child_verification = load("runs/goal_recovery_20260913_012528_cst/w24_spatial_g2_child_r2/verification.json")
case_summaries = {}
for p in sorted((ROOT / "runs/goal_recovery_20260913_012528_cst/w24_spatial_g2_child_r2/verification").glob("*/summary.json")):
    d = json.loads(p.read_text(encoding="utf-8"))
    case_summaries[d["case_id"]] = {
        "summary_path": str(p.relative_to(ROOT)),
        "summary_sha256": sha256(p)[0],
        "executed": d.get("executed"),
        "exit_code": d.get("exit_code"),
        "physical_validation_credit": d.get("physical_validation_credit"),
        "actual": d.get("actual"),
        "manufactured": d.get("manufactured"),
    }

iterations = {}
for p in sorted((ROOT / "runs/goal_recovery_20260913_012528_cst/w24_spatial_g2_child_r2/physics").glob("*/iterations.csv")):
    import csv
    rows = list(csv.DictReader(p.open(encoding="utf-8")))
    last = rows[-1] if rows else {}
    iterations[p.parent.name] = {
        "path": str(p.relative_to(ROOT)),
        "sha256": sha256(p)[0],
        "rows": len(rows),
        "last": {k: last.get(k) for k in ("iteration", "scaled_norm", "scaled_max", "linear_relative_residual", "step_norm")},
    }

checks = {
    "head": commands[0]["stdout"].strip(),
    "dirty_file_count": len([x for x in status["stdout"].splitlines() if x.strip()]),
    "julia_desc_absent": process["exit"] == 0 and process["stdout"].strip() == "",
    "required_docs_and_sources_present": all(v["exists"] for v in source_hashes.values()),
    "w24_four_cases_present": set(case_summaries) == {"nominal_coarse", "nominal_fine", "flux_low_coarse", "flux_high_coarse"},
    "w24_all_case_artifacts_exit_zero": all(v["executed"] and v["exit_code"] == 0 for v in case_summaries.values()),
    "w24_solver_not_promoted": child_result.get("physical_validation") == "unsupported" and child_result.get("p5_ready") is False and child_result.get("credible_device_count") == 0,
    "w24_physics_failure_preserved": any(x.get("exit_code") == 4 for x in [child_result.get("stages", [])[2]] if isinstance(x, dict)) if child_result.get("stages") else False,
    "w24_verification_physical_credit_zero": child_verification.get("physical_validation", {}).get("physical_validation_credit") == 0,
    "w24_raw_case_mms_only": all((v.get("manufactured") or {}).get("interpretation", "").startswith("Analytic weak/strong discrepancy") for v in case_summaries.values() if v.get("manufactured")),
}

path_audit = {
    "source_to_equation_ir": {
        "status": "missing",
        "verified": ["G1 V5 typed equation/state/profile records exist in EquationPlanV2 and GrammarProfileV2"],
        "missing": ["No EquationIRV4 module or compile_equation_ir entry; Compiler.compile_candidate is typed CandidateStatePackageV4-only and emits CompiledCandidatePrefixV4 obligations"],
        "evidence": ["src/RuntimeV4/Compiler.jl:102-156", "docs/v4_multitopology_generation/11_physics_compilation_and_discretization.md:29-33,119-123"],
    },
    "equation_ir_to_solver_input": {
        "status": "missing",
        "verified": ["FieldResidualPipeline can build SolverInputV4 for one exact manufactured V4 field residual"],
        "missing": ["No V5 package-bound lowering of variable-coefficient/an-isotropic/time/multifield terms into solver input; FieldResidualPipeline is hard-coded to manufactured LAPLACE(u)-2f and screen_only"],
        "evidence": ["src/RuntimeV4/FieldResidualPipeline.jl:1-5,334-420,436-536", "docs/v4_multitopology_generation/11_physics_compilation_and_discretization.md:39-43"],
    },
    "solver_input_to_spatial_residual": {
        "status": "missing",
        "verified": ["SpatialMultiRegionV4 has a standalone two-region static-MHD assembly and four-case runner artifacts"],
        "missing": ["SpatialRuntimeV4.jl is only a once-only source loader; no V5 CandidateStatePackageV5 -> equation/mesh/assembly bridge; SpatialMultiRegionV4 uses fixed declaration/model guards and is not a general backend"],
        "evidence": ["src/RuntimeV4/SpatialRuntimeV4.jl:1-35", "src/RuntimeV4/SpatialMultiRegionV4.jl:22-111,667-735", "docs/v4_multitopology_generation/11_physics_compilation_and_discretization.md:45-51"],
    },
    "spatial_residual_to_feedback": {
        "status": "missing",
        "verified": ["G3 V5 schema contains typed feedback channels and candidate-bound structural admission"],
        "missing": ["No runtime spatial SolverPlan/residual receipt is joined to G3 feedback target/source_id with candidate identity, physical subject hash, residual/defect units, and an accepted feedback authority receipt; existing AlgebraicScopedResolutionV4 is V4 screen feedback"],
        "evidence": ["src/GenomeV5/G3/RealizationGenomeV5.jl:95-122,227-252", "src/RuntimeV4/AlgebraicGenerationV4.jl:20-31", "docs/v4_multitopology_generation/12_composition_and_inverse_realization.md:214-223"],
    },
}

minimal_slice = {
    "candidate": [
        "actual CandidateStatePackageV5 with candidate_ref/version v5, exact G1/G2/G3 refs, component hashes, version axes, migration receipt, and resolution=terminal_deferred until authority exists",
        "one G1 scalar state u, one positive scalar coefficient K(x) or typed SPD tensor, one source f, one region, one chart/metric/function space, and one explicit Dirichlet or Neumann boundary",
        "all state/coefficient/source/flux/time/residual units and source/region/boundary ownership from candidate fields; no family/name/fixture routing",
    ],
    "equation_ir": [
        "typed term ids and upstream G1 refs for -div(K grad u)=f (or explicit time variant), operator/closure capability, strong form, units, temporal semantics, region and conservation account",
        "deferred if chart, metric, function space, boundary, closure, coefficient domain, or operator capability is absent",
    ],
    "weak_residual": [
        "test function/function space, integration region, integration-by-parts sign, natural and essential boundary ownership, source/sink sign, and interface trace policy",
        "explicit nullspace/gauge/pinning record; no silently removed equation",
    ],
    "discrete_and_solver_input": [
        "mesh/basis/quadrature, DOF ordering, element-local blocks, global assembly map, face orientation, conservative flux map, residual units/scales, Jacobian sparsity and discrete nullspace",
        "SolverInputV4-like typed input bound to candidate/prefix/equation/weak/discrete hashes, provider manifest, boundary/material data, tolerances, stop/iteration-limit taxonomy, and deterministic numerical configuration",
    ],
    "verification_and_feedback": [
        "positive coefficient diffusion MMS with known analytic u and f: relative L2/Linf solution error, residual norm, boundary error, integral/source balance, and mesh refinement ratio under frozen thresholds",
        "G3 feedback receipt must carry same candidate/ref/component hashes, physical subject and solver input hashes, residual/defect units, source path, status and failure taxonomy; feedback remains screen/contract evidence until physical authority is supplied",
    ],
}

w24 = {
    "child_result_identity": {k: child_result.get(k) for k in ("candidate_hash", "context_hash", "status", "physical_validation", "p5_ready", "credible_device_count")},
    "four_case_summaries": case_summaries,
    "iteration_logs": iterations,
    "known_archive_limits": [
        "physics solver exit 4 with stopping_reason=iteration_limit in raw result; final norms remain nonzero",
        "W24 acceptance comparability_status=changes_requested: immutable parent has 433 source records vs fresh child 449 and verifier hash differs",
        "post-run manifest audit preserved five source/test byte mismatches caused by shared worktree changes after sealing",
        "MMS analytic/interpolant values are explicitly a quadrature/interpolant diagnostic and do not establish a solution convergence order",
        "runner/process exit and four-case artifact completion do not provide physical validation or B01/B02/B04 credit",
    ],
}

negative_controls = [
    {"mutation": "remove boundary declaration", "expected": "terminal_deferred; no solver input"},
    {"mutation": "negative or non-SPD coefficient", "expected": "typed compile rejection, not numerical acceptance"},
    {"mutation": "source unit/dimension mismatch", "expected": "fail_closed with exact field path"},
    {"mutation": "duplicate/conflicting boundary or interface ownership", "expected": "fail_closed"},
    {"mutation": "rename family/label or reorder unrelated shards", "expected": "no routing/hash/threshold change"},
    {"mutation": "detached G2 mesh or foreign candidate package", "expected": "candidate/source hash mismatch and no solver call"},
    {"mutation": "G3 feedback target without actual same-candidate authority", "expected": "feedback_authority_gap + terminal_deferred"},
    {"mutation": "solver iteration_limit or nonfinite residual", "expected": "scientific fail/unknown receipt preserved; never pass"},
]

gates = {
    "UP1_04A": "accepted_limited contract-only identity wiring; not full UP1-04",
    "UP1_04B": "planned/pending; B00 F0-F5, 50 fresh B04 receipts, checker and two-process replay absent",
    "UP1_04": "planned; total migration/package join cannot close before UP1-04B",
    "B01": "not passed by this audit; W24 MMS is not a generic candidate-bound diffusion MMS gate",
    "B04": "not passed; formal 50 receipts remain pending",
    "physical": "false/unsupported",
    "claim_ceiling": "preparation_static_audit_no_Julia_DESC_no_implementation_no_recomputation",
}

checks["required_static_commands_zero"] = all(x["exit"] == 0 for x in commands)
verdict = "audit_complete" if checks["required_static_commands_zero"] else "evidence_gap_with_exact_missing_path"
# The audit itself completes, but the requested physics path has exact implementation gaps.
verdict = "evidence_gap_with_exact_missing_path"

report = {
    "review_id": "UP2-01-entry-audit-r1",
    "reviewer": "different-Luna/high independent static reviewer",
    "checked_at_utc": now(),
    "verdict": verdict,
    "claim_ceiling": gates["claim_ceiling"],
    "head": checks["head"],
    "dirty_file_count": checks["dirty_file_count"],
    "julia_desc_invoked": False,
    "source_hashes": source_hashes,
    "checks": checks,
    "path_audit": path_audit,
    "minimal_variable_coefficient_diffusion_slice": minimal_slice,
    "w24_raw_evidence": w24,
    "independent_negative_controls": negative_controls,
    "dependency_recommendation": [
        "Do not schedule UP2-01 runtime work as accepted physical work until UP1-04B B00/B04 receipts/checker/two-process replay and UP1-04 total join are independently closed.",
        "Freeze a new UP2-01 focused contract for the minimal candidate-bound variable-coefficient diffusion slice, then implement typed EquationIR/WeakResidualIR/DiscreteResidual/SolverPlan modules and source-bound tests.",
        "After UP2-01 static review, run only the minimal positive/negative software slice; schedule UP2-02 mesh/assembly only after the equation IR and solver-input hashes are stable.",
        "Keep W24 as historical domain-specific MHD diagnostics and failure evidence; do not reuse its candidate, solver, MMS, or feedback artifacts as B01/physical proof.",
    ],
    "command_receipts": commands,
}

(OUT / "report.json").write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
md = f"""# UP2-01 physical compilation entry audit R1

Verdict: **{verdict}**.

This is a read-only preparation audit at HEAD `{checks['head']}` with {checks['dirty_file_count']} dirty/untracked status rows captured before the audit artifacts were written. Julia and DESC were not started. The claim ceiling is `{gates['claim_ceiling']}`.

## Source and path result

G1 V5 typed state/equation/profile records, G2 V5 chart/field-space/region contracts, G3 V5 resource/control/feedback records, and the additive `CandidateStatePackageV5` are present and hashed in `report.json`. The executable chain is incomplete: `Compiler.jl` still accepts `CandidateStatePackageV4` and emits `CompiledCandidatePrefixV4` structural obligations; no `EquationIRV4`, `WeakResidualIRV4`, `DiscreteResidualV4`, or `SolverPlanV4` entry exists. `FieldResidualPipeline.jl` is a V4 manufactured `LAPLACE(u)-2f` screen with `screen_only` authority. `SpatialRuntimeV4.jl` is a once-only loader, while `SpatialMultiRegionV4.jl` is a fixed two-region static-MHD slice. G3 feedback is typed structural contract data; no runtime spatial residual receipt is joined back to an authoritative same-candidate feedback channel.

The exact node-by-node verified/missing table is in `report.json.path_audit`:

1. source → equation IR: **missing** (`Compiler.jl:102-156`); typed G1 declarations exist, but no V5 equation lowering.
2. equation IR → solver input: **missing**; only the fixed manufactured V4 field residual produces `SolverInputV4`.
3. solver input → spatial residual: **missing**; the spatial module is not a V5 candidate-bound general backend.
4. spatial residual → feedback: **missing**; G3 feedback has no execution receipt/source/subject/hash closure.

## Minimal legal slice required before runtime scheduling

Use one actual V5 package with one scalar state `u`, positive scalar or SPD coefficient `K(x)`, source `f`, region/chart/metric/function space, and explicit Dirichlet or Neumann ownership. Lower `-div(K grad u)=f` into typed strong and weak records, then a discrete record with mesh/basis/quadrature, DOF and face orientation, conservative flux, Jacobian sparsity and nullspace. The solver input must bind candidate, prefix, equation, weak and discrete hashes, provider manifest, material/boundary data, numerical configuration and failure taxonomy. The positive MMS gate needs analytic solution/source, relative L2/Linf error, residual, boundary error, source/integral balance and mesh-refinement thresholds. G3 feedback must carry same-candidate identity, source and units and remain below physical authority.

## W24 evidence and non-reuse decision

W24 child R2 contains the four named cases and independently hashed raw summaries, but the spatial solver raw exit is `4` with `iteration_limit`; final nonzero residual norms remain in the iteration logs. The archive explicitly records `physical_validation=unsupported`, `p5_ready=false`, `credible_device_count=0`, and zero physical-validation credit. Its MMS fields are an analytic weak/strong quadrature diagnostic and interpolant diagnostic without an established solution convergence order. Pair comparability is `changes_requested` because the immutable parent had 433 source records versus the child’s 449 and the verifier hash changed; a later manifest audit also found shared-worktree source/test byte mismatches. These artifacts cannot be reused for the UP2-01 candidate-bound diffusion slice or B01/physical credit.

## Dependencies and independent negative controls

UP1-04A remains limited contract-only wiring; UP1-04B still owns pending B00/B04 receipts, checker and two-process replay; UP1-04 total migration remains planned. Schedule UP2-01 only after those gates, then UP2-02 after stable equation/solver-input hashes. Required negative controls are recorded in `report.json`: missing boundary, negative/non-SPD coefficient, wrong source unit, duplicate boundary, label/family rewrite, foreign candidate/mesh, missing G3 authority, and iteration-limit/nonfinite residual.

JSON parsing, `validate_plan.py`, `git diff --check`, HEAD/dirty capture and a read-only Julia/DESC process sweep are recorded with real timestamps, exit codes, stdout and stderr in `command_receipts.json`. No implementation, test, core document or prior evidence file was modified.
"""
(OUT / "report.md").write_text(md, encoding="utf-8")

manifest = {
    "review_id": report["review_id"],
    "verdict": verdict,
    "claim_ceiling": report["claim_ceiling"],
    "head": checks["head"],
    "julia_desc_invoked": False,
    "evidence_files": {},
    "source_hashes": source_hashes,
    "command_exits": {x["name"]: x["exit"] for x in commands},
}
for name in ("report.json", "report.md", "run_audit.py", "git_status_porcelain.txt"):
    p = OUT / name
    manifest["evidence_files"][name] = {"sha256": sha256(p)[0], "bytes": p.stat().st_size} if p.exists() else None
(OUT / "command_receipts.json").write_text(json.dumps(commands, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
manifest["evidence_files"]["command_receipts.json"] = {"sha256": sha256(OUT / "command_receipts.json")[0], "bytes": (OUT / "command_receipts.json").stat().st_size}
(OUT / "evidence_manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
