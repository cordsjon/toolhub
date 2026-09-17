# Addendum: harvested extension tools (US-TH-08)

> **Addendum to** `docs/specs/2026-09-10-toolhub-design.md`. That spec's decisions,
> constraints, out-of-scope list and integration allowance apply unchanged. This file adds
> **one** story, US-TH-08, and does not restate or amend anything in the base spec.
> Source of the candidate list: competitor survey of `https://aisubtools.xyz/` (2026-09-17).

## Provenance and what was actually harvested

`aisubtools.xyz` is a WordPress/GeneratePress site offering 40 client-side tools
(measured 2026-09-17: `curl` → HTTP 200, 63,444 bytes; a sampled tool page
`/hex-to-rgb-converter-online/` → 105,608 bytes, 12 inline `<script>` blocks, **0** POST
forms, ~3,814 words of body text, no analytics or ad scripts). Its architecture is the same
as this fork's — per-tool page, client-side JS, no server round-trip — so nothing about the
_mechanism_ is new to us.

Two things were deliberately **not** harvested:

- **Its content template.** Every tool page applies a rigid 6-section SEO structure
  (pain points → advantages → step-by-step with the widget embedded mid-page → audience →
  FAQ → closing), placing ~1,500 words before the interactive element. toolhub is built in
  Simple Mode behind a deny-by-default auth gate, so crawlers receive a 302 to `/login`;
  marketing prose on these pages would serve no reader and no crawler. Tool pages stay bare.
- **Its inventory as a whole.** 40 candidates were triaged against this spec's constraints.
  Result: **11 already specced**, 10 harvested here, 8 deferred, 9 rejected (detail below).
  Copying the list wholesale would have added crypto, SEO and network tools that either
  violate the client-side-only constraint or dilute a private toolbox with novelty.

## Triage of the 40 candidates

### Already covered by the base spec — NOT re-storied (11)

| Candidate                 | Already specced as                   |
| ------------------------- | ------------------------------------ |
| image compressor          | `x-image` compress, US-TH-04 AC-02   |
| image converter           | `x-image` convert, US-TH-04 AC-02    |
| base64 encoder/decoder    | `x-base64`, US-TH-06 AC-01           |
| base64 image→text decoder | `x-base64` file mode, US-TH-06 AC-01 |
| URL encoder/decoder       | `x-url-encode`, US-TH-06 AC-01       |
| JSON formatter/validator  | `x-json-format`, US-TH-06 AC-01      |
| JSON↔CSV converter        | `x-csv-convert`, US-TH-05 AC-02      |
| MD5 generator             | `x-hash`, US-TH-06 AC-01             |
| SHA-256 calculator        | `x-hash`, US-TH-06 AC-01             |
| UUID v4 generator         | `x-uuid`, US-TH-06 AC-01             |
| Unix timestamp converter  | `x-timestamp`, US-TH-06 AC-01        |

No collision check was skipped: the 126 existing `src/pages/*.html` were grepped for every
candidate keyword and every match is PDF-scoped (`compress-pdf`, `image-to-pdf`,
`pdf-to-csv`, `adjust-colors`, …). The harvested tools below are genuinely new pages, not
duplicates of upstream PDF tools.

### Rejected (9) — with the reason, so they are not revisited by accident

| Candidate                       | Reason                                                                  |
| ------------------------------- | ----------------------------------------------------------------------- |
| encrypt/decrypt text            | A home-rolled crypto UI invites real misuse. Never ship.                |
| password strength check         | `zxcvbn` is ~800 KB and its advice misleads more than it helps.         |
| random password generator       | Operator uses a password manager; adds risk, not capability.            |
| fancy text generator            | Unicode homoglyph novelty — accessibility-hostile, no professional use. |
| HTML website template generator | PosterEngine `/html-editor` already owns this surface.                  |
| website SEO audit               | Requires server-side fetch — base spec, out of scope for v1.            |
| HTTP status checker             | Cross-origin fetch is CORS-blocked; would need a proxy.                 |
| IP/geo lookup                   | Third-party geo API — violates the no-egress assertion, US-TH-04 AC-06. |
| robots.txt / sitemap generator  | No use for a gated private toolbox.                                     |

### Deferred (8) — revisit only on a stated need

`png-background-remover` (a usable version needs a ~5 MB ML segmentation model; naive
chroma-key produces poor edges), `barcode EAN/UPC` (no stated product-barcode need),
`time-zone-converter` (overlaps `x-timestamp`'s ISO/local/UTC), `crc32` (belongs as one more
algorithm inside `x-hash`, not a page), `css-minifier` (needs a real parser for modest
payoff), `file-mime-type-checker` (low frequency), `unicode-conversion` (overlaps
`x-url-encode`/`x-base64` escaping), `random-string-generator` (overlaps `x-uuid` bulk mode).

## US-TH-08: harvested Image and Text & Dev tools

As a user, I want colour, QR, and the everyday text-shaping utilities in the same grid, so
that the chores I currently do on a public tool site happen inside the gate, offline, on
files that never leave the browser.

**Depends on:** US-TH-01 (fork bootstrap + boundary checker), US-TH-02 (gate), US-TH-03
(grid/registry wiring). **Independent of** US-TH-04/05/06 — no shared module, so it may be
implemented before, after or alongside them. Where this story and US-TH-06 both touch
`src/js/logic/x-devtools/`, they add disjoint files.

**Ten pages, all following the base spec's extension pattern** — `src/pages/x-<slug>.html`
generated from `_x-template.html` (substituting `__NAME__`, `__SUBTITLE__`, `__SLUG__`,
`__CAMEL__`), one logic module, one `ExtTool` entry in `src/js/config/tools-ext.ts`,
i18n keys under `tools:ext.<camel>.*` in both `en` and `de`.

### Acceptance criteria

- **AC-01 — Image category (3 pages).** `x-color-convert` converts between HEX (3- and
  6-digit), RGB/RGBA, HSL/HSLA and CSS named colours, in every direction, with a live swatch
  preview and a copy button per output format; a 3-digit shorthand (`#abc`) expands
  correctly (`#aabbcc`) and is covered by a test. `x-gradient-css` builds `linear-gradient`
  and `radial-gradient` with 2–8 stops (add, remove, reposition, recolour), angle or shape
  control, a live preview box, and emits the `background-image` declaration. `x-qr-code`
  renders a QR from text or a URL to canvas with selectable error-correction level (L/M/Q/H)
  and module size, and downloads as PNG or SVG.
- **AC-02 — Text & Dev category (7 pages).** `x-xml-format` (pretty-print, minify, validate
  with line and column on error), `x-case-convert` (camel, Pascal, snake, SCREAMING_SNAKE,
  kebab, Title, sentence, lower, upper), `x-text-count` (characters with and without spaces,
  words, lines, paragraphs, plus reading time at a stated words-per-minute), `x-line-tools`
  (dedupe, sort asc/desc, reverse order, strip blank lines, trim whitespace, add/remove line
  numbers — composable in one pass, order of operations shown in the UI), `x-markdown-html`
  (Markdown → HTML using the already-bundled `marked`, sanitised through the already-bundled
  `dompurify`, with a rendered preview and a copy-source button), `x-byte-size` (B/KB/MB/GB/TB
  and KiB/MiB/GiB/TiB, with the decimal-vs-binary distinction stated in the UI, not implied),
  `x-cron` (parse a 5-field expression to prose and list the next 5 fire times in local time
  and UTC; reject a 6-field or `@reboot` expression with a message naming the supported form).
- **AC-03 — Pure logic, no DOM.** Every tool's transformation logic lives in
  `src/js/logic/x-devtools/*.ts` (Text & Dev) or `src/js/logic/x-image/*.ts` (Image) as
  functions that take and return values with no DOM access, imported by a thin page module
  that owns all DOM wiring. This is the base spec's US-TH-06 AC-02 rule applied unchanged.
- **AC-04 — Dependencies.** Only **one** new dependency: `qrcode-generator` for `x-qr-code`
  (npm `qrcode-generator@2.0.4`, MIT, **zero transitive dependencies**, last published
  2025-08-07 — verified against the npm registry 2026-09-17; chosen over `qrcode@1.5.4`,
  which pulls `yargs`, `pngjs` and `dijkstrajs` for a Node CLI this site does not use). It is
  registered through the deps registry before the import is written, and added to
  `NOTICE.md`. Every other tool in this story uses either platform APIs or a package already
  in `package.json` — confirmed present 2026-09-17: `marked@^16.4.2` and
  `dompurify@^3.4.12` for `x-markdown-html`. `x-cron` implements its own field parser; no
  cron dependency is added.
- **AC-05 — Tests.** Vitest covers every pure function with at least one positive and one
  negative case, including: 3-digit HEX expansion; an out-of-range RGB value (`rgb(300,0,0)`)
  rejected rather than clamped silently; a gradient with the minimum (2) and maximum (8)
  stops; XML with an unclosed tag reporting a line and column; each case-conversion direction
  on an input containing digits and a leading underscore; `x-line-tools` with two operations
  composed; decimal-vs-binary byte conversion asserted against known values (1 KB = 1000 B,
  1 KiB = 1024 B); a 6-field cron rejected. A red/green check confirms at least one test
  fails when its transformation is bypassed — per the base spec's standard, an assertion that
  cannot fail is not evidence.
- **AC-06 — Untrusted input.** Adversarial fixture per category, asserted in the Playwright
  suite: `x-markdown-html` is given `[x](javascript:alert(1))` and `<img src=x
onerror=alert(1)>` and the rendered preview contains neither an executable `javascript:`
  href nor a surviving `onerror` attribute; `x-xml-format` and `x-case-convert` are given
  `<script>alert(1)</script>` and show it as literal text. No dialog opens in any case. This
  is the one place in this story where output is rendered as HTML rather than text, so it is
  the one place sanitisation is load-bearing.
- **AC-07 — Privacy assertion.** The network assertion of US-TH-04 AC-06 applies unchanged
  and must pass for a tool from each category in this story. Both categories are in its
  **zero cross-origin** class: Image tools here are pure computation (no WASM codec, unlike
  US-TH-04's `x-image`), and Text & Dev tools never had an egress allowance. Any cross-origin
  request from a US-TH-08 page fails the assertion.
- **AC-08 — Boundary and i18n gates stay green.** `scripts/check-upstream-boundary.sh`
  passes: all new files match the allowed `x-` pattern
  (`src/pages/x-*.html`, `src/js/logic/x-*`, `src/tests/x-*`,
  `src/js/config/tools-ext.ts`), and the only upstream-owned files touched are
  `public/locales/{en,de}/tools.json` (additions under `ext` only) and `package.json`
  (one dependency added). `scripts/check-ext-i18n.mjs` passes: every new `ext.*` key exists
  in **both** `en` and `de` — German strings written by the implementer, reviewed by the
  operator (a native speaker) before merge, per base-spec decision A2.
- **AC-09 — Grid.** All ten tools appear in the grid under `Image` and `Text & Dev`, both
  categories now render (they are currently filtered out by `tools.ts` for having
  `tools: []`), and `scripts/generate-static-tool-links.mjs` regenerates
  `src/partials/tool-links-static.html` to include them. Field order `href, name, …` in each
  new `ExtTool` is preserved — that script regex-matches `href` then `name`, so the order is
  load-bearing (per the header comment in `tools-ext.ts`).

### Exit condition

The operator opens each of the ten pages on the live gated site, performs one real conversion
per page, and `npm run build` (which runs `check-ext-i18n`) plus
`scripts/check-upstream-boundary.sh`, `npm run test` and `npm run test:e2e` are green.

### Explicitly out of scope for US-TH-08

Marketing or SEO copy on tool pages (see "Provenance" above); the 8 deferred and 9 rejected
candidates; any tool requiring a server round-trip or third-party API; opening the auth gate
to crawlers; the `rel=canonical` / `| BentoPDF` title cleanup inherited from upstream (a real
issue, but pre-existing and independent of this story — it belongs in its own US, and only
matters if the gate ever opens).
