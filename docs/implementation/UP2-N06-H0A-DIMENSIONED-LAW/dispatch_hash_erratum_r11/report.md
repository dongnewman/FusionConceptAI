# H0-A dispatch hash erratum R11

This additive record corrects the runner identity used for the next gate. A 63-character runner SHA appeared in the preceding dispatch/evidence transcription. The runner on disk was checked directly with `Get-FileHash -Algorithm SHA256`; its complete 64-character SHA-256 is:

`da4c41517badd8c99f5f10e55c9219e2450afb223798eb7f7b4db2048ce293dc`

The R10 evidence record is preserved unchanged. Its runner field is retained as historical input; this erratum does not overwrite or reinterpret prior focused evidence. The R11 protected runner identity is the complete live 64-character value above, and its byte count is 299. No Julia/DESC execution occurred while producing this erratum.

Status: `erratum_recorded`; `accepted=false`; `review_pending=true`.
