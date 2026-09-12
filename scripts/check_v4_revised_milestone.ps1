param([Parameter(Mandatory=$true)][string]$LogDirectory)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$logs = [IO.Path]::GetFullPath($LogDirectory)
New-Item -ItemType Directory -Path $logs -Force | Out-Null
Push-Location $repo
try {
    $checks = @(
        @('physics', 'test/runtime_v4_complete_multiregion_tests.jl'),
        @('engineering', 'test/runtime_v4_magnetic_engineering_tests.jl'),
        @('verification', 'test/runtime_v4_executed_verification_uq_tests.jl'),
        @('graphs', 'test/runtime_v4_revised_graph_tests.jl'),
        @('core', 'test/runtime_v4_core_tests.jl'),
        @('spine', 'test/runtime_v4_spine_tests.jl'),
        @('package', 'test/runtests.jl')
    )
    foreach ($check in $checks) {
        $label = $check[0]
        $script = $check[1]
        & julia --startup-file=no --project=. $script *> (Join-Path $logs "$label.log")
        $checkCode = $LASTEXITCODE
        Set-Content -LiteralPath (Join-Path $logs "$label.exit") -Value $checkCode
        Write-Output "$label exit=$checkCode"
        if ($checkCode -ne 0) {
            Get-Content -LiteralPath (Join-Path $logs "$label.log") -Tail 35
            exit $checkCode
        }
    }
    Set-Content -LiteralPath (Join-Path $logs 'queue.exit') -Value 0
} finally {
    Pop-Location
}
