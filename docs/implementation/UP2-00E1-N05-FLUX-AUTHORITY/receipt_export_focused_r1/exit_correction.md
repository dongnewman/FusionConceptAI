# Focused R1 exit artifact correction

The authoritative real process exit is `1`, recorded in
`process_receipt.json`, `run_summary.json`, and the runner stderr/stdout. The
preserved `exit.txt` bytes are `31 60 6e` (`1` followed by literal PowerShell
backtick-n), so that file is metadata-corrupt and is not used as the exit
source. It is retained unchanged to preserve the raw attempt; no rerun or
replacement exit artifact was made. The failure classification remains
`program_exception` with no receipt generated.
