# Preserved failed/aborted attempt history

Before this integration, a prior worker left `acceptance_integration/x.txt` (7 bytes, SHA256 `cd2eca3535741f27a8ae40c31b0c41d4057a7a7b912b33b9aed86485d1c84676`). It was not a test result or acceptance evidence. The exact pre-removal bytes/hash and removal reason are recorded in `aborted_artifact_removal.json`; the file was removed after the freeze. No other prior integration artifact was present in the directory.

The first JSON parse command used an incorrect relative path and returned exit 1; its raw output and exit are preserved as `json_parse.stdout.log` and `json_parse.exit`. A corrected repository-root command was rerun and returned exit 0; its output and exit are `json_parse_retry.stdout.log` and `json_parse_retry.exit`. This was a documentation command-path failure only and is not runtime evidence.
