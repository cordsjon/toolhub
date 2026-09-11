# NOTICE — third-party sources in toolhub

toolhub is a fork of **BentoPDF** (AGPL-3.0) and is itself distributed under AGPL-3.0 (`LICENSE`, preserved from upstream).
Every deployed revision links to its own source in the page footer: `Source: https://github.com/cordsjon/toolhub/tree/<full sha>`.

| Project  | Licence  | Upstream                               | Pinned revision                                                  | Derived files                                                                                                        |
| -------- | -------- | -------------------------------------- | ---------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| BentoPDF | AGPL-3.0 | https://github.com/alam00000/bentopdf  | `597e36904e8ccacc0af98463589805cb9ee910d2` (see `UPSTREAM_BASE`) | everything outside the `x-`/`ext` namespace; `src/pages/_x-template.html` is derived from `src/pages/merge-pdf.html` |
| it-tools | GPL-3.0  | https://github.com/CorentinTh/it-tools | `d505845f918e946ec300af7b36efc107e2f66e9e`                       | (none yet — the tools epic adds `src/js/logic/x-devtools/*` with per-file source citations)                          |

GPL-3.0 code is combined into this AGPL-3.0 work under GPLv3 §13; the combined work stays AGPL-3.0.

## Cross-origin module paths permitted by the privacy assertion (US-TH-04 AC-06)

(none yet — the tools epic enumerates the exact `cdn.jsdelivr.net` paths of the PyMuPDF, Ghostscript and CoherentPDF WASM modules here.)
