# H0-A receipt erratum R14

This append-only erratum corrects one hash field in the preserved R13 evidence manifest. The R13 manifest recorded the source after SHA as the 48-character value:

f40e626bcdb8c981bb9355db558a0e758fdcc5b98681b251

The live source file and the R13/R14 source identity are the complete 64-character SHA-256:

f40e626bcdb8c981bb9355dbde49dc7f9302f5db558a0e758fdcc5b98681b251

The original R13 manifest is not overwritten. R14 uses the complete live value for its before hash and records this correction separately. No Julia/DESC execution occurred while producing this erratum.

Status: erratum_recorded; accepted=false; review_pending=true.
