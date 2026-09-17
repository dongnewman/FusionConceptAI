$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path
$cp = Join-Path $repo 'docs\implementation\HYGIENE-CHECKPOINT-20260917'
$qbase = 'D:\006-Programing\LMC\.codex_trash\FusionConceptAI-hygiene-20260917-20260917T054858Z'
$j = Get-Content (Join-Path $cp '04-cleanup-execution\cleanup-execution-20260917T054858Z.json') -Raw | ConvertFrom-Json
$results = @($j.results)
$exact = @(Get-Content (Join-Path $cp '03-deletion-risk-review\exact_delete_paths.txt') | Where-Object { $_ -and -not $_.StartsWith('#') })
$repoMissing = @($results | Where-Object { Test-Path -LiteralPath (Join-Path $repo $_.relative_path) })
$qMissing = @($results | Where-Object { -not (Test-Path -LiteralPath $_.quarantine_path) })
$statusBad = @($results | Where-Object { $_.status -ne 'moved' -or $null -ne $_.error })
$fileChecks = @()
$dirChecks = @()
foreach ($r in $results) {
    $qp = $r.quarantine_path
    if ($r.kind -eq 'file') {
        $len = (Get-Item -LiteralPath $qp).Length
        $sha = (Get-FileHash -LiteralPath $qp -Algorithm SHA256).Hash.ToUpperInvariant()
        $expected = $r.before.sha256.ToUpperInvariant()
        $fileChecks += [pscustomobject]@{ path=$r.relative_path; bytes=$len; expected_bytes=$r.before.bytes; sha=$sha; expected_sha=$expected; pass=($len -eq $r.before.bytes -and $sha -eq $expected) }
    } else {
        $children = @(Get-ChildItem -LiteralPath $qp -Recurse -Force)
        $files = @($children | Where-Object { -not $_.PSIsContainer })
        $dirs = @($children | Where-Object { $_.PSIsContainer })
        $bytes = [int64](($files | Measure-Object Length -Sum).Sum)
        $lines = @()
        foreach ($e in ($children | Sort-Object FullName)) {
            $rel = $e.FullName.Substring($qp.Length + 1).Replace('\','/')
            if ($e.PSIsContainer) { $lines += "D|$rel" }
            else { $h=(Get-FileHash -LiteralPath $e.FullName -Algorithm SHA256).Hash.ToUpperInvariant(); $lines += "F|$rel|$($e.Length)|$h" }
        }
        $enc=[Text.Encoding]::UTF8.GetBytes(($lines -join "`n"))
        $recursiveSha=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($enc))
        $pass = $bytes -eq $r.after.bytes -and $children.Count -eq $r.after.item_count -and $files.Count -eq $r.after.file_count -and $dirs.Count -eq $r.after.directory_count -and $r.before.bytes -eq $r.after.bytes -and $r.before.sha256 -eq $r.after.sha256
        $dirChecks += [pscustomobject]@{ path=$r.relative_path; bytes=$bytes; expected_bytes=$r.after.bytes; items=$children.Count; expected_items=$r.after.item_count; files=$files.Count; expected_files=$r.after.file_count; dirs=$dirs.Count; expected_dirs=$r.after.directory_count; recursive_sha256=$recursiveSha; expected_entry_manifest=$r.after.sha256; pass=$pass }
    }
}
$keep = @(Get-Content (Join-Path $cp '03-deletion-risk-review\keep_paths.txt') | Where-Object { $_ -and -not $_.StartsWith('#') } | ForEach-Object { if ($_ -match '^(.*?)\s+\(') { $Matches[1] } else { $_ } })
$inv = @(Import-Csv (Join-Path $cp '00-temp-file-inventory\inventory.tsv') -Delimiter "`t")
$keepChecks = @()
foreach ($p in $keep) {
    $fp = Join-Path $repo $p
    if (Test-Path -LiteralPath $fp) {
        $it = Get-Item -LiteralPath $fp
        if (-not $it.PSIsContainer) {
            $sha=(Get-FileHash -LiteralPath $fp -Algorithm SHA256).Hash.ToLowerInvariant(); $row=$inv | Where-Object relative_path -eq $p
            $keepChecks += [pscustomobject]@{path=$p; exists=$true; kind='file'; bytes=$it.Length; expected_bytes=[int64]$row.bytes; sha=$sha; expected_sha=$row.sha256; unchanged=($it.Length -eq [int64]$row.bytes -and $sha -eq $row.sha256)}
        } else {
            $ch=@(Get-ChildItem -LiteralPath $fp -Recurse -Force); $keepChecks += [pscustomobject]@{path=$p; exists=$true; kind='directory'; bytes=[int64](($ch | Where-Object {-not $_.PSIsContainer} | Measure-Object Length -Sum).Sum); items=$ch.Count; unchanged='not_baseline_hashed'}
        }
    } else { $keepChecks += [pscustomobject]@{path=$p; exists=$false; kind='missing'; unchanged=($p -eq 'tmp/phase5_remote_session.py')} }
}
$test = @(Get-ChildItem (Join-Path $repo 'test') -Recurse -File -Force | Where-Object { $_.FullName -notmatch '\\__pycache__\\' -and $_.Extension -in '.jl','.py','.json' })
$head=(git -C $repo rev-parse HEAD).Trim(); $branch=(git -C $repo branch --show-current).Trim()
$status=@(git -C $repo -c core.quotePath=false status --porcelain=v1 --untracked-files=all); $statusText=($status -join "`n"); $statusHash=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($statusText)))
$deleted=@(git -C $repo -c core.quotePath=false status --porcelain=v1 --untracked-files=all | Where-Object { $_ -match '^\s*D|^D' })
$proc=Get-CimInstance Win32_Process -Filter 'ProcessId = 85880' -ErrorAction SilentlyContinue
$out=[ordered]@{utc=(Get-Date).ToUniversalTime().ToString('o'); repo=$repo; quarantine=$qbase; results=$results.Count; exact_unique=@($exact|Select-Object -Unique).Count; repo_absent=$results.Count-$repoMissing.Count; quarantine_present=$results.Count-$qMissing.Count; status_ok=$results.Count-$statusBad.Count; file_hash_match=@($fileChecks|Where-Object pass).Count; file_total=$fileChecks.Count; dir_recursive_summary_match=@($dirChecks|Where-Object pass).Count; dir_total=$dirChecks.Count; keep_total=$keep.Count; keep_exists=@($keepChecks|Where-Object exists).Count; keep_file_unchanged=@($keepChecks|Where-Object {$_.kind -eq 'file' -and $_.unchanged}).Count; keep_missing=@($keepChecks|Where-Object {-not $_.exists}|ForEach-Object path); formal_test_count=$test.Count; formal_test_expected=270; tracked_deletion_count=$deleted.Count; branch=$branch; head=$head; checkpoint_head='b2c04d8339774635aaecd73651efcdb101e01b5d'; head_unchanged=($head -eq 'b2c04d8339774635aaecd73651efcdb101e01b5d'); status_rows=$status.Count; status_sha256=$statusHash; pid_85880_present=($null -ne $proc); pid_85880_command=if($proc){$proc.CommandLine}else{$null}; pid_85880_executable=if($proc){$proc.ExecutablePath}else{$null}; pid_target_exists=(Test-Path -LiteralPath (Join-Path $repo 'tmp/phase5_remote_session.py')); file_checks=$fileChecks; dir_checks=$dirChecks; keep_checks=$keepChecks}
$out | ConvertTo-Json -Depth 8
