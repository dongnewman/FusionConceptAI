$ErrorActionPreference = 'Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '../../../../..')).Path
$julia='C:\Users\Newman\AppData\Local\Programs\Julia-1.10.5\bin\julia.exe'
$raw=Join-Path $PSScriptRoot 'raw'
function Invoke-Probe([string]$name,[string]$path){
  $stdout=Join-Path $raw ($name+'_stdout.txt'); $stderr=Join-Path $raw ($name+'_stderr.txt')
  $s=[DateTime]::UtcNow; $p=Start-Process $julia -ArgumentList @('--project=.',$path) -WorkingDirectory $root -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru; $id=$p.Id; $p.WaitForExit(); $e=[DateTime]::UtcNow
  [ordered]@{name=$name;pid=$id;utc_start=$s.ToString('o');utc_end=$e.ToString('o');exit_code=$p.ExitCode;command="$julia --project=. $path";cwd=$root;stdout_path=$stdout;stderr_path=$stderr} | ConvertTo-Json | Set-Content -Encoding utf8 (Join-Path $raw ($name+'_process.json'))
}
Invoke-Probe 'g1_git_closure_probe' 'docs/implementation/AD-49/F0-G1-G2-SOURCE-AUTHORITY-FACTORIES/independent_review_r1/git_closure_probe_g1.jl'
Invoke-Probe 'g2_git_closure_probe' 'docs/implementation/AD-49/F0-G1-G2-SOURCE-AUTHORITY-FACTORIES/independent_review_r1/git_closure_probe_g2.jl'
