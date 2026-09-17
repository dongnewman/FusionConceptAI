$ErrorActionPreference = 'Stop'
$root = 'D:\006-Programing\LMC\FusionConceptAI'
$evidence = $PSScriptRoot
$julia = (Get-Command julia.exe).Source
function HashFile([string]$p) { (Get-FileHash -Algorithm SHA256 -LiteralPath $p).Hash.ToLowerInvariant() }
function ProcSnapshot { @(Get-CimInstance Win32_Process | Where-Object { $_.Name -match '^(julia|desc)(\.exe)?$' } | ForEach-Object { [ordered]@{pid=[int]$_.ProcessId;name=$_.Name;command_line=$_.CommandLine} }) }
function OutsideStatus {
  $all = @(& git -C $root status --porcelain=v1 --untracked-files=all 2>&1 | ForEach-Object { [string]$_ })
  @($all | Where-Object { $_ -and ($_ -notmatch 'independent_review_r1') })
}
function RunStage([string]$label,[string]$probe,[string]$mode,[string]$outdir) {
  $before = ProcSnapshot
  if ($before.Count -gt 0) { throw "Julia/DESC process exists before $label" }
  $started=(Get-Date).ToUniversalTime().ToString('o')
  $stdout=Join-Path $outdir 'stdout.raw'; $stderr=Join-Path $outdir 'stderr.raw'
  $psi=[System.Diagnostics.ProcessStartInfo]::new(); $psi.FileName=$julia; $psi.Arguments='--project="'+$root+'" "'+$probe+'" '+$mode; $psi.WorkingDirectory=$root; $psi.UseShellExecute=$false; $psi.CreateNoWindow=$true; $psi.RedirectStandardOutput=$true; $psi.RedirectStandardError=$true
  $p=[System.Diagnostics.Process]::new(); $p.StartInfo=$psi; [void]$p.Start(); $realPid=$p.Id
  $ot=$p.StandardOutput.ReadToEndAsync(); $et=$p.StandardError.ReadToEndAsync(); $p.WaitForExit(); $out=$ot.Result; $err=$et.Result
  [IO.File]::WriteAllText($stdout,$out,[Text.UTF8Encoding]::new($false)); [IO.File]::WriteAllText($stderr,$err,[Text.UTF8Encoding]::new($false))
  $ended=(Get-Date).ToUniversalTime().ToString('o'); $after=ProcSnapshot
  $receipt=[ordered]@{task='AD-55';stage=$label;mode=$mode;command=($julia+' --project="'+$root+'" "'+$probe+'" '+$mode);cwd=$root;pid=$realPid;started_utc=$started;ended_utc=$ended;exit_code=$p.ExitCode;strictly_serial=($before.Count -eq 0 -and $after.Count -eq 0);stdout=[ordered]@{path=$stdout.Substring($evidence.Length+1);bytes=(Get-Item $stdout).Length;sha256=HashFile $stdout};stderr=[ordered]@{path=$stderr.Substring($evidence.Length+1);bytes=(Get-Item $stderr).Length;sha256=HashFile $stderr};process_before=$before;process_after=$after}
  $receipt | ConvertTo-Json -Depth 15 | Set-Content -LiteralPath (Join-Path $outdir 'receipt.json') -Encoding UTF8
  if($p.ExitCode -ne 0){ throw "$label exited $($p.ExitCode)" }
}
$start=(Get-Date).ToUniversalTime().ToString('o'); $outsideBefore=OutsideStatus
$planOut=Join-Path $evidence 'plan_validate.stdout.raw'; $planErr=Join-Path $evidence 'plan_validate.stderr.raw'
$planP=[System.Diagnostics.Process]::new(); $pi=[System.Diagnostics.ProcessStartInfo]::new(); $pi.FileName=(Get-Command python).Source; $pi.Arguments='docs/v4_multitopology_generation/validate_plan.py'; $pi.WorkingDirectory=$root; $pi.UseShellExecute=$false; $pi.CreateNoWindow=$true; $pi.RedirectStandardOutput=$true; $pi.RedirectStandardError=$true; $planP.StartInfo=$pi; [void]$planP.Start(); $pot=$planP.StandardOutput.ReadToEndAsync(); $pet=$planP.StandardError.ReadToEndAsync(); $planP.WaitForExit(); [IO.File]::WriteAllText($planOut,$pot.Result,[Text.UTF8Encoding]::new($false)); [IO.File]::WriteAllText($planErr,$pet.Result,[Text.UTF8Encoding]::new($false)); if($planP.ExitCode -ne 0){throw "plan validator exited $($planP.ExitCode)"}
RunStage 'f0' (Join-Path $evidence 'f0/f0_probe.jl') 'f0' (Join-Path $evidence 'f0')
RunStage 's2_run1' (Join-Path $evidence 's2_run1/s2_probe.jl') 's2' (Join-Path $evidence 's2_run1')
RunStage 's2_run2' (Join-Path $evidence 's2_run2/s2_probe.jl') 's2' (Join-Path $evidence 's2_run2')
$outsideAfter=OutsideStatus; $end=(Get-Date).ToUniversalTime().ToString('o')
[ordered]@{start_utc=$start;end_utc=$end;root=$root;head=(& git -C $root rev-parse HEAD);outside_status_before=$outsideBefore;outside_status_after=$outsideAfter;outside_unchanged=(($outsideBefore -join "`n") -eq ($outsideAfter -join "`n"));plan=[ordered]@{exit_code=$planP.ExitCode;stdout_sha256=HashFile $planOut;stderr_sha256=HashFile $planErr}} | ConvertTo-Json -Depth 15 | Set-Content -LiteralPath (Join-Path $evidence 'replay_receipt.json') -Encoding UTF8




