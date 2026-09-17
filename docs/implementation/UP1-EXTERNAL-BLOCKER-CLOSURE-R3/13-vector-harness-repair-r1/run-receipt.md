# Verification receipt

Command (serial, run twice):

```text
python -B -W ignore::DeprecationWarning -c "import os,sys,unittest; ..."
```

Both runs executed the complete focused discovery suite and exited 0. The
existing host privilege-limited symlink/reparse probe remains the only skip.

| run | Python PID | UTC start | UTC end | exit | raw stdout/stderr SHA-256 |
|---:|---:|---|---|---:|---|
| 1 | 25716 | 2026-09-17T01:01:55.7564816Z | 2026-09-17T01:01:56.9839414Z | 0 | `a788cd393626c72a4f805f4b6a6eff1dcbc5549cf5dff07bc56fe1d4d0069fec` |
| 2 | 68932 | 2026-09-17T01:02:07.6628434Z | 2026-09-17T01:02:08.9600846Z | 0 | `5bb99b13b3a29552dcd904b4ed0e2026f293f00dd9ced3158cc4dd71ab858558` |

Observed result for each run:

```text
Ran 24 tests in about 1 second
OK (skipped=1)
```

The machine vector receipt is [vector-receipt.json](vector-receipt.json).
This evidence closes only the software/prototype harness defect; it does not
close UP1 or any physical, engineering, authority, or publication claim.
