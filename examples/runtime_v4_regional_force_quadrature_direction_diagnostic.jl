const RFDD_ROOT=get(ENV,"RFDD_RUN_ROOT",mktempdir(prefix="rfdd_"))
include(joinpath(@__DIR__,"runtime_v4_regional_force_observation_q4_comparison.jl"))
Base.include(RFQ4,joinpath(@__DIR__,"..","src","RuntimeV4","RegionalForceQuadratureDirectionDiagnosticV4.jl"))
const rfdd=RFQ4.execute_regional_force_quadrature_direction_diagnostic(q4_execution,q4_comparison,imit_upstream,imit_request,imit_result,drifo_request,drifo_result,drifo_execution,q3_execution;run_dir=RFDD_ROOT)
if abspath(PROGRAM_FILE)==@__FILE__; println("status=",rfdd.status); println("RFDD_EXIT_CODE=0"); end
