# W4 local-input discovery — independent review R3

Conclusion: `pass_limited`  
Claim ceiling: `discovery_only/preparation_only`  
Formal/gate credit: none

## Scope

The frozen repository-only scope excludes `.git`, `reviews/**`, and `local_input_discovery/**` from the scan universe while including the W1/W2/W3 main packages. This is consistent with the discovery contract: assessor/self artifacts cannot become discovered inputs, and the three upstream packages remain eligible for metadata observation. The raw scan contains zero `reviews/` hits. No home/credential store, network, S3, Julia, DESC, solver, or recomputation was used.

## Independent checks

- PID `103592`, exit `0`: raw `metadata_scan_r2.jsonl` contains 2,810 records, with exact partition `1,864 candidates + 946 excluded = 2,810`.
- All 2,810 paths exist, are inside the repository, have matching byte lengths and SHA-256 values, and have no duplicate paths. Candidate counts are W1=51, W2=9, W3=47; current hashes are not stale.
- Candidate/excluded type, producer, authority, signature-verification-feasibility, test-only, and promotion fields pass independent checks. No record has production or usable promotion enabled.
- The 26-ID W1/W2/W3 crosswalk is lossless: W1=10, W2=11, W3=5, with zero duplicate source IDs and unchanged digest.
- Sensitive-path rules covered identity/private-key names, secret/token/credential/password names, and key/certificate extensions. 9,127 repository paths were checked; there were zero hits and no sensitive content was opened.
- PID `46848`, exit `0`, validator stdout/stderr/combined raw hashes match its receipt. The current source manifest has 54 files, its exact set matches the filesystem, 25 archive files remain preserved, and no `.pyc`/`__pycache__` was found. JSON artifacts parse uniquely.

## Boundary

The result supports the refreshed metadata partition and unchanged typed-absence bookkeeping only. It does not establish an external witness, authority endpoint, G2 mapping, signed four-axis source binding, S3 authority, environment provenance, or binary provenance. No new real input, upstream register mutation, AD, or gate credit is present.
