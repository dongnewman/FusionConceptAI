$ErrorActionPreference = 'Stop'
$root = 'docs/implementation/UP2-04-CLOSURE-REPAIR-PREC'
$checks = @(
  @{ Rel = "$root/archive/root_replay_only_v6_grant_20260923/grant.json"; Sha = 'b621f9a7d0bfc46ce1923e174d327ac66010ae8c912f37d93b923f107828e517' },
  @{ Rel = "$root/archive/root_replay_only_v6_grant_20260923/observation.json"; Sha = 'd2ccf4d26d9fbfaaac7335c2e02f79b8b9b047690c0bc814eb1bd528e936e699' },
  @{ Rel = "$root/archive/replay_only_continuation_r6/replay_protocol_v6.json"; Sha = '9d28384297942eb3cec2fd788e88ac17fb1868e25b55fc7dbe85d3c97d79fca9' },
  @{ Rel = 'test/RuntimeV4/UP2ClosureReplayOnlyV6/replay_staged_v6.jl'; Sha = '22329280b2e0555d853a68a53a58dd2290fbcba21e8b65fb1b92eebb785183ad' },
  @{ Rel = 'test/RuntimeV4/UP2ClosureReplayOnlyV6/run_replay_staged_v6.py'; Sha = '11c1ebd2d8bf897e8b96dcc87e1f97e11ad42759bc0ab72997e283090040f8c7' },
  @{ Rel = 'test/RuntimeV4/UP2ClosureReplayOnlyV6/test_contract_v6.py'; Sha = 'd694c1d49018c8004e4be0c1c44199b9d38c229ca8c0d862cb71f2cd5c5f5cb9' },
  @{ Rel = "$root/archive/replay_only_continuation_r6/replay_coverage_v6.md"; Sha = '24d07188273dc68a06b0090b467c3dfea422490c5663b9b23212594192d40c51' },
  @{ Rel = "$root/archive/replay_only_continuation_r6/static_contract_check_v6_r1/receipt.json"; Sha = '3d48bad224ad2fab000b68bfcd388b558a95b4e9eff7158b71dcd72d84a998f9' },
  @{ Rel = "$root/agent_r2_n1_20260922/manufactured_candidate_v1/protocol_staged_v10.json"; Sha = 'ff53030155703ee3fcfe3b25ae48fdcc03d411b0da1020cff0cd909388c6aad3' }
)
foreach ($entry in $checks) {
  $actual = (Get-FileHash -LiteralPath $entry.Rel -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($actual -ne $entry.Sha) { throw "SHA mismatch $($entry.Rel): $actual" }
  "FILE $actual $($entry.Rel)"
}
$v10 = "$root/agent_r2_n1_20260922/runtime_manufactured_staged_r1"
$receipts = @(
  @{ Rel = "$v10/final.json"; Sha = '0ac754699e2ec66131abf3835ae0a79b49b2f45519c71bb4d00bf67c549fa6e4'; Bytes = 6987 },
  @{ Rel = "$v10/inputs_before.json"; Sha = '057d32f6bee2b1f771c039a7bc0a085dbdd5adb556a779013104d69267b5247b'; Bytes = 15598 },
  @{ Rel = "$v10/inputs_after.json"; Sha = '057d32f6bee2b1f771c039a7bc0a085dbdd5adb556a779013104d69267b5247b'; Bytes = 15598 },
  @{ Rel = "$v10/producer_process/final.json"; Sha = '5a299f91dec04cd6ea866f7610bc8faf15d9b99cd98bfbbdd987dec8b2f5ebfc'; Bytes = 3659 },
  @{ Rel = "$v10/producer_process/process.json"; Sha = '584b1fe4e11dfb1325121041807dba06cb02371866c87b00fc2b020b3df91d69'; Bytes = 1887 },
  @{ Rel = "$v10/producer_process/stdout.raw"; Sha = '3c8946dcd636cad0244db5f55d691ad66dd6f32e5266159598a5a1e3d0207558'; Bytes = 17132 },
  @{ Rel = "$v10/producer_process/stderr.raw"; Sha = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'; Bytes = 0 },
  @{ Rel = "$v10/protocol_receipt.json"; Sha = 'ee189a2f7ec547f743adf291197185d29c220ef6f25d3e84d31d570701b3f5aa'; Bytes = 1254 }
)
foreach ($entry in $receipts) {
  $file = Get-Item -LiteralPath $entry.Rel
  $actual = (Get-FileHash -LiteralPath $entry.Rel -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($actual -ne $entry.Sha -or $file.Length -ne $entry.Bytes) { throw "Receipt mismatch $($entry.Rel): bytes=$($file.Length) sha=$actual" }
  "RECEIPT $($file.Length) $actual $($entry.Rel)"
}
foreach ($rel in @("$v10/producer_process/final.json", "$v10/producer_process/process.json")) {
  $obj = Get-Content -LiteralPath $rel -Raw | ConvertFrom-Json
  "JSON $rel schema=$($obj.schema) stage=$($obj.stage) stop_reason=$($obj.stop_reason) exit_code=$($obj.exit_code) controller_exit_code=$($obj.controller_exit_code)"
}
$controller = Get-Content -LiteralPath 'test/RuntimeV4/UP2ClosureReplayOnlyV6/run_replay_staged_v6.py'
for ($i = 158; $i -lt [Math]::Min(176, $controller.Length); $i++) { '{0}: {1}' -f ($i + 1), $controller[$i] }
$outputLeaf = "$root/archive/replay_only_continuation_r6/runtime_replay_r6"
if (Test-Path -LiteralPath $outputLeaf) { throw "V6 output leaf exists: $outputLeaf" }
'OUTPUT_LEAF_ABSENT'
