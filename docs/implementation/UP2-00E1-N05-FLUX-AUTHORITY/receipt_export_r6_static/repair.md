# Receipt export R6 static repair after focused R2

Focused R2 is immutable: it produced a valid 22402-byte envelope but exited 1 when the source-hash forgery control called merge directly on a JSON3.Object. The exact raw logs, exit, envelope, and failure receipt remain under receipt_export_focused_r2/.

This test-only repair converts the file-read JSON3 object recursively to typed NamedTuples, mutates only those typed values, serializes each forged envelope, and re-reads it with JSON3 before passing it to the same five-argument trusted checker. The valid path still passes the original file-read JSON3 object.

No exporter/checker, production source, or old archive was changed. No Julia/DESC was run; a fresh independent static precheck is required before focused R3.
