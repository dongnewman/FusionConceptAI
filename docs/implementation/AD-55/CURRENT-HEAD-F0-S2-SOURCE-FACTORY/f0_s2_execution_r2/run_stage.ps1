param([Parameter(Mandatory=$true)][string]$Stage, [Parameter(Mandatory=$true)][string]$Probe, [Parameter(Mandatory=$true)][string]$Receipt)
$ErrorActionPreference='Stop'
$repo='D:\006-Programing\LMC\FusionConceptAI'
$ev=Join-Path $repo 'docs\implementation\AD-55\CURRENT-HEAD-F0-S2-SOURCE-FACTORY\f0_s2_execution_r2'
Set-Location $repo
$expected='b2c04d8339774635aaecd73651efcdb101e01b5d'
$head=((& git rev-parse HEAD)|Out-String).Trim(); if($head -ne $expected){throw "HEAD mismatch: $head"}
$stamp=(Get-Date).ToUniversalTime().ToString('o')
$before=(& git status --porcelain=v1 --untracked-files=all | Out-String)
Set-Content -LiteralPath (Join-Path $ev ($Stage+'_dirty_before.txt')) -Value $before -Encoding utf8
$out=Join-Path $ev ($Stage+'.stdout.raw'); $err=Join-Path $ev ($Stage+'.stderr.raw')
Remove-Item -LiteralPath $out,$err -Force -ErrorAction SilentlyContinue
$cmd="julia --project=. docs/implementation/AD-55/CURRENT-HEAD-F0-S2-SOURCE-FACTORY/f0_s2_execution_r2/$Probe"
$p=Start-Process -FilePath 'julia' -ArgumentList '--project=.',"docs/implementation/AD-55/CURRENT-HEAD-F0-S2-SOURCE-FACTORY/f0_s2_execution_r2/$Probe" -WorkingDirectory $repo -RedirectStandardOutput $out -RedirectStandardError $err -PassThru
$juliaPid=$p.Id; Wait-Process -Id $juliaPid; $exit=$p.ExitCode; $end=(Get-Date).ToUniversalTime().ToString('o')
$after=(& git status --porcelain=v1 --untracked-files=all | Out-String)
Set-Content -LiteralPath (Join-Path $ev ($Stage+'_dirty_after.txt')) -Value $after -Encoding utf8
$shaOut=(Get-FileHash -Algorithm SHA256 $out).Hash.ToLower(); $shaErr=(Get-FileHash -Algorithm SHA256 $err).Hash.ToLower()
$rec=[ordered]@{task='AD-55';stage=$Stage;status=$(if($exit -eq 0){'completed_review_pending'}else{'failed'});accepted=$false;command=$cmd;cwd=$repo;pid=$juliaPid;started_utc=$stamp;ended_utc=$end;exit_code=$exit;stdout_path=([IO.Path]::GetFileName($out));stderr_path=([IO.Path]::GetFileName($err));stdout_sha256=$shaOut;stderr_sha256=$shaErr;head=$head;dirty_before_sha256=(Get-FileHash -Algorithm SHA256 (Join-Path $ev ($Stage+'_dirty_before.txt'))).Hash.ToLower();dirty_after_sha256=(Get-FileHash -Algorithm SHA256 (Join-Path $ev ($Stage+'_dirty_after.txt'))).Hash.ToLower();claims=[ordered]@{source_authority=$false;trusted=$false;candidate_identity_created=$false;final_identity_created=$false;provider=$false;mesh=$false;solver=$false;engineering_readiness=$false;physics=$false;search=$false;R01_R10=$false;L4=0}}
$rec|ConvertTo-Json -Depth 10|Set-Content -LiteralPath (Join-Path $ev $Receipt) -Encoding utf8
Write-Output "STAGE=$Stage PID=$juliaPid EXIT=$exit STDOUT_SHA256=$shaOut STDERR_SHA256=$shaErr"
if($exit -ne 0){Get-Content -Raw $err; exit $exit}
