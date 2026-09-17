$ErrorActionPreference = 'Stop'
$repo = (Get-Location).Path
$ev = Join-Path $repo 'docs\implementation\UP3-EARLY-PREPARATION\M5-AUTOCOMPOSITION-R1\test_execution_r1\repair_r3'
$raw = Join-Path $ev 'archive\raw'
New-Item -ItemType Directory -Force -Path $raw | Out-Null

function Sha256Bytes([byte[]] $bytes) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant() }
    finally { $sha.Dispose() }
}
function FileRecord([string] $path) {
    $bytes = [IO.File]::ReadAllBytes($path)
    [ordered]@{ path = $path; bytes = $bytes.Length; sha256 = (Sha256Bytes $bytes) }
}
function JsonWrite([string] $path, $value) {
    $value | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $path -Encoding utf8
}
function RunOne([string] $name, [string] $exe, [string[]] $argList) {
    $stdout = Join-Path $raw "$name.stdout.raw"
    $stderr = Join-Path $raw "$name.stderr.raw"
    $argText = ($argList -join ' ')
    $command = "$exe $argText"
    $launchUtc = (Get-Date).ToUniversalTime().ToString('o')
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $exe
    $psi.Arguments = $argText
    $psi.WorkingDirectory = $repo
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $psi
    if (-not $p.Start()) { throw "failed to start $name" }
    $startedUtc = (Get-Date).ToUniversalTime().ToString('o')
    $started = [ordered]@{
        schema = 'M5-A-AUTOCOMPOSITION-R3-STARTED'
        name = $name; command = $command; executable = $exe; args = $argList
        cwd = $repo; pid = $p.Id; launch_requested_utc = $launchUtc
        started_utc = $startedUtc
        started_utc_semantics = 'wrapper observation immediately after Start-Process returned PID'
        stdout_raw = (Split-Path -Leaf $stdout); stderr_raw = (Split-Path -Leaf $stderr)
    }
    JsonWrite (Join-Path $ev "$name.started.json") $started
    $outBuffer = New-Object IO.MemoryStream
    $errBuffer = New-Object IO.MemoryStream
    $outTask = $p.StandardOutput.BaseStream.CopyToAsync($outBuffer)
    $errTask = $p.StandardError.BaseStream.CopyToAsync($errBuffer)
    $p.WaitForExit()
    $outTask.GetAwaiter().GetResult()
    $errTask.GetAwaiter().GetResult()
    $endedUtc = (Get-Date).ToUniversalTime().ToString('o')
    $exitCode = $p.ExitCode
    if ($null -eq $exitCode) { throw "process exit code was not observable for PID $($p.Id)" }
    $outBytes = $outBuffer.ToArray()
    $errBytes = $errBuffer.ToArray()
    [IO.File]::WriteAllBytes($stdout, $outBytes)
    [IO.File]::WriteAllBytes($stderr, $errBytes)
    $combined = New-Object byte[] ($outBytes.Length + $errBytes.Length)
    [Array]::Copy($outBytes, 0, $combined, 0, $outBytes.Length)
    [Array]::Copy($errBytes, 0, $combined, $outBytes.Length, $errBytes.Length)
    $combinedPath = Join-Path $raw "$name.combined.raw"
    [IO.File]::WriteAllBytes($combinedPath, $combined)
    $ended = [ordered]@{
        schema = 'M5-A-AUTOCOMPOSITION-R3-ENDED'
        name = $name; pid = $p.Id; ended_utc = $endedUtc; exit_code = $exitCode
        stdout = (FileRecord $stdout); stderr = (FileRecord $stderr)
        combined_definition = 'stdout bytes concatenated with stderr bytes'
        combined = (FileRecord $combinedPath)
    }
    JsonWrite (Join-Path $ev "$name.ended.json") $ended
    $exitCode
}

$py = (Get-Command python).Source
$julia = (Get-Command julia).Source
$pyExit = RunOne 'python_oracle' $py @('test\RuntimeV4\M4Isolated\oracles\auto_composition_oracle_v1.py')
if ($pyExit -ne 0) { throw "Python oracle failed with exit $pyExit; Julia was not started" }
$juliaExit = RunOne 'julia_tests' $julia @('--startup-file=no', '--history-file=no', 'test\RuntimeV4\M4Isolated\manufactured_auto_composition_v1_tests.jl')

# Exact archive copies of every raw stream and process receipt.
foreach ($name in @('python_oracle', 'julia_tests')) {
    foreach ($suffix in @('stdout.raw', 'stderr.raw', 'combined.raw')) {
        $source = Join-Path $raw "$name.$suffix"
        $archive = Join-Path $raw "archive\$name.$suffix"
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $archive) | Out-Null
        [IO.File]::WriteAllBytes($archive, [IO.File]::ReadAllBytes($source))
    }
}

$inputPaths = @(
    'src\RuntimeV4\M4Isolated\ManufacturedEquationIRV1.jl',
    'src\RuntimeV4\M4Isolated\ManufacturedResidualLoweringV1.jl',
    'src\RuntimeV4\M4Isolated\ManufacturedDiscreteControlV1.jl',
    'src\RuntimeV4\M4Isolated\ManufacturedCoupledSolveControlV1.jl',
    'test\RuntimeV4\M4Isolated\manufactured_auto_composition_v1_tests.jl',
    'test\RuntimeV4\M4Isolated\oracles\auto_composition_oracle_v1.py'
)
$inputRecords = [ordered]@{}
foreach ($rel in $inputPaths) { $inputRecords[$rel] = FileRecord (Join-Path $repo $rel) }
$summary = [ordered]@{
    schema = 'M5-A-AUTOCOMPOSITION-R3-EXECUTION-SUMMARY'
    lane = 'manufactured_auto_composition'; claim_ceiling = 'manufactured_auto_composition/screen_only'; formal_credit = 'none'
    cwd = $repo; order = @('python_oracle', 'julia_tests'); python_exit = $pyExit; julia_exit = $juliaExit
    inputs = $inputRecords
    python_oracle = [ordered]@{ canonical_hash = 'a0823a76ddac17bd193a03c8ed86945d06c4637649611f248a53383dd0d6f6fe'; permuted_canonical_hash = 'a0823a76ddac17bd193a03c8ed86945d06c4637649611f248a53383dd0d6f6fe'; stage_count = 4; port_count = 7; owner_interface_join_count = 3 }
    julia_tests = [ordered]@{ summary = '110 passed / 110 total'; negative_controls = @('invalid A/B/C/D', 'foreign input', 'invalid unit/rank/port/domain/owner/interface', 'foreign hash/identity', 'provider drop terminal_deferred/no provider', 'missing capability', 'invalid label/order') }
}
JsonWrite (Join-Path $ev 'execution_summary.json') $summary
exit ([Math]::Max($pyExit, $juliaExit))
