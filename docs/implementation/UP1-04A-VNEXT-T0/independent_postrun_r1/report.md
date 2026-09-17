# UP1-04A-VNEXT-T0 focused R1 independent postrun review

## Verdict

`executor_launcher_failed`; `test_not_executed_for_acceptance`; `accepted=false`.

The capture record contains the first real failure verbatim:

```text
WriteError:
Line |
  20 |  $pid = $p.Id
     |  ~~~~~~~~~~~~
     | Cannot overwrite variable PID because it is read-only or constant.
```

`Process.Start()` returned successfully according to the attempt metadata, but
the wrapper failed before it could retain the child PID, wait for completion,
capture stdout/stderr, or record an exit code. Consequently there is no
admissible evidence that the Julia test body completed, and the attempt cannot
be classified as a test pass/failure or as a T0 runtime result. The child was
not rerun under the attempt contract.

## Independent checks

The attempt's six input hashes match the current bytes on disk:

| input | SHA-256 |
|---|---|
| `src/GenomeV5/Integration/VNextDeclarationTransportV1.jl` | `30406b183ba45f740fa8c41dd5ceb1c5d2fd390b19da1c978fcff9e11501504e` |
| `test/GenomeV5/Integration/vnext_declaration_transport_v1_tests.jl` | `333ff3a2976736e13809b603cdcab61524658b7fb20d1b6506ccf188dea3b063` |
| `docs/implementation/UP1-04A-VNEXT-T0/static_qa.py` | `cd57913db629333d8a000834a2153a779393f2a1cea0ba67c7dd5699f7d97e78` |
| `src/GenomeV5/G1/DiffusionDeclarationV1.jl` | `14d26ee556029bd1fcf2477f3dbe9599622d37a3f5704d1c0bb1dd9ea31dbf1a` |
| `src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl` | `261516671151647bccb71f2fefd5f71cd2ed444f5eeba0bf90b29687d3a78f61` |
| `src/GenomeV5/G3/G3SourceFeedbackLawV1.jl` | `70b045dd3a1fcbfc60f58e0b742c296507343ffc3736aaefd8c2a40e212750d0` |

The recorded pre/post porcelain count is `304`/`304`; no worktree change is
attributable to this failed launch. A fresh post-attempt process inspection
found no `julia`, `juliaup`, or `desc` process, so no orphan Julia/DESC child
remains. This is process cleanup evidence only, not execution evidence.

The post-attempt static QA, JSON validation, and diff checks recorded by the
author all passed, but these checks cannot substitute for the missing Julia
stdout/stderr, exit code, and process identity.

## Required retry gate

The next attempt may be a single serialized focused launch after the H0 lane
is confirmed idle. It must use a task-specific variable such as `$childPid`,
never PowerShell's read-only `$PID`, and must capture the process identity
before waiting. A minimal launcher shape is:

```powershell
$psi = [System.Diagnostics.ProcessStartInfo]::new()
$psi.FileName = "julia"
$psi.Arguments = "--startup-file=no --project=. test/GenomeV5/Integration/vnext_declaration_transport_v1_tests.jl"
$psi.WorkingDirectory = (Get-Location).Path
$psi.UseShellExecute = $false
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$child = [System.Diagnostics.Process]::new()
$child.StartInfo = $psi
$null = $child.Start()
$childPid = $child.Id
$startedUtc = [DateTime]::UtcNow.ToString("o")
$stdoutText = $child.StandardOutput.ReadToEnd()
$stderrText = $child.StandardError.ReadToEnd()
$child.WaitForExit()
$exitCode = $child.ExitCode
```

Before launch, freeze and record the six input hashes and the pre-run dirty
snapshot. Afterward, write raw stdout/stderr bytes, their hashes, exit code,
PID/process identity, post-run dirty snapshot, and a process absence check.
Only that complete receipt can be reviewed as the focused test result. Do not
reuse this R1 attempt as a test run; T0 remains `accepted=false`, and T1,
provider, mesh, engineering, physical, B00/B04, search, and R01-R10 credit
remain blocked.
