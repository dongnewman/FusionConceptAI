# Input fingerprint R2 canonicalization

The preimage is `input_fingerprint_preimage.json`. Its first line is the canonical JSON payload used for the fingerprint. Recalculation rules are:

1. Decode the file as UTF-8.
2. Remove exactly one terminal LF (`0A`) introduced by the repository text artifact; no other whitespace is removed.
3. Parse JSON only to audit the payload; the hash input is the exact resulting bytes.
4. Serialization is Python `json.dumps(payload, sort_keys=True, separators=(',', ':'))`: lexicographic UTF-8 JSON key order, compact comma/colon separators, no indentation, no added spaces, no CRLF, and no terminal newline.
5. SHA-256 of those canonical bytes must be `840922caac204df3d66ce3419868390c2fda8e79c3792cc4e074af2887edd9a5`.

The payload includes branch, HEAD, index SHA-256, six owner working SHA-256 and filtered working OID tuples, three dirty AD56 factory working SHA-256 and filtered working OID tuples, and probe/loader/module SHA-256 values. It intentionally excludes timestamps, status counts, output hashes, and any authority result.
