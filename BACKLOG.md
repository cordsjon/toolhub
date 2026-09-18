# toolhub — Backlog

> Source of truth for feature work, bugs, and ideation for the gated tool box at
> `https://poster.getaccess.cloud/tools/`.
> Spec: [docs/specs/2026-09-10-toolhub-design.md](docs/specs/2026-09-10-toolhub-design.md)
> (US-TH-01 … US-TH-07). Decisions: [DECISIONS.md](DECISIONS.md).
> Ideation stories describe intent + open questions; spec + plan come later.

---

## Ready

### US-TH-08: Harvested Image and Text & Dev tools (10 pages)

**Spec:** [docs/specs/2026-09-17-ext-tools-harvest-addendum.md](docs/specs/2026-09-17-ext-tools-harvest-addendum.md)
— full acceptance criteria AC-01…AC-09 there. **Status:** specced, not started.

As a user, I want colour, QR, and the everyday text-shaping utilities in the same grid, so
that the chores I currently do on a public tool site happen inside the gate, offline, on
files that never leave the browser.

**Origin.** Competitor survey of `https://aisubtools.xyz/` (2026-09-17, 40 tools). Triage
against the base spec: **11 already specced** (US-TH-04/05/06 — not re-storied), **10
harvested** (this story), **8 deferred**, **9 rejected**. The site's 6-section SEO content
template was deliberately _not_ harvested — toolhub is Simple Mode behind a deny-by-default
gate, so crawlers get a 302 and marketing prose would serve nobody.

**Scope — 10 new pages, filling two currently-empty `ExtCategory` slots:**

| Category     | Pages                                                                                                        |
| ------------ | ------------------------------------------------------------------------------------------------------------ |
| `Image`      | `x-color-convert`, `x-gradient-css`, `x-qr-code`                                                             |
| `Text & Dev` | `x-xml-format`, `x-case-convert`, `x-text-count`, `x-line-tools`, `x-markdown-html`, `x-byte-size`, `x-cron` |

Both categories exist in `src/js/config/tools-ext.ts` with `tools: []` and are filtered out
of the grid by `tools.ts` today — this story is what makes them render.

**Dependencies.** Requires US-TH-01 (fork bootstrap + boundary checker), US-TH-02 (gate),
US-TH-03 (grid/registry wiring). **Independent of US-TH-04/05/06** — no shared module, so it
can land before, after, or alongside them. Where it and US-TH-06 both write into
`src/js/logic/x-devtools/`, the files are disjoint.

**One new dependency only:** `qrcode-generator@2.0.4` (MIT, zero transitive deps, published
2025-08-07 — verified against the npm registry 2026-09-17). Chosen over `qrcode@1.5.4`, which
pulls `yargs`/`pngjs`/`dijkstrajs` for a Node CLI this site never runs. Must pass the deps
registry gate before the import is written. Everything else reuses packages already in
`package.json` — `marked@^16.4.2` + `dompurify@^3.4.12` for `x-markdown-html` (confirmed
present 2026-09-17), platform APIs for the rest. `x-cron` ships its own field parser.

**Why these 10 and not the other 30** — the rejections worth remembering:

- **Never ship:** encrypt/decrypt text (home-rolled crypto UI invites misuse), password
  generator + strength checker (operator uses a password manager; `zxcvbn` is ~800 KB of
  misleading advice), fancy-text generator (unicode homoglyphs, accessibility-hostile).
- **Constraint violation:** SEO audit, HTTP status checker, IP/geo lookup — all need a server
  round-trip or a third-party API, which the base spec puts out of scope for v1 and which
  would fail the US-TH-04 AC-06 no-egress assertion.
- **Already owned elsewhere:** HTML template generator → PosterEngine `/html-editor`.
- **Deferred pending a stated need:** PNG background remover (needs a ~5 MB ML model to be
  any good), EAN/UPC barcode, timezone converter (overlaps `x-timestamp`), CRC32 (belongs
  inside `x-hash`), CSS minifier, MIME checker, unicode conversion, random string generator.

**Effort note.** The per-tool cost here is one logic module, not a page: `_x-template.html`
is a placeholder scaffold (`__NAME__`/`__SUBTITLE__`/`__SLUG__`/`__CAMEL__`) with a wired
`<main id="x-tool-root">` mount and i18n keys pre-namespaced under `tools:ext.<camel>.*`.
Nine of the ten tools are pure string/number transforms. `x-qr-code` is the only one with a
real library and a canvas/SVG export path.

**Gotchas that will bite the implementer:**

- `check-ext-i18n.mjs` runs **inside `npm run build`** — a missing German key is a build
  failure, not a lint warning. DE strings are mandatory and operator-reviewed (decision A2).
- Field order `href, name, …` in each new `ExtTool` is load-bearing:
  `scripts/generate-static-tool-links.mjs` regex-matches `href` then `name`.
- `check-upstream-boundary.sh` whitelists only `x-`-prefixed paths and caps upstream-owned
  files at 25 changed lines. Only `public/locales/{en,de}/tools.json` (additions under `ext`)
  and `package.json` (one dep) may be touched.

---

## Ideation

**Upstream SEO metadata is stale and mis-attributed (2026-09-17).** Not part of US-TH-08,
flagged during its survey. The inherited tool pages carry upstream's identity:
`src/pages/merge-pdf.html:30` has `rel="canonical" href="https://www.bentopdf.com/merge-pdf"`
and titles still read `| BentoPDF`, across ~125 pages. Inert while the gate is closed
(crawlers get a 302 to `/login`), so this is **not urgent** — but if the gate ever opens to
any public surface, every page would be telling Google that bentopdf.com is the original.
Needs its own US when/if a public-surface decision is made. The prerequisite question is
strategic, not technical: **is the toolhub a private utility belt, or an acquisition funnel?**
The base spec's deny-by-default gate says private; nothing should change until that's revisited.

**Harvest source archived (2026-09-17).** aisubtools.xyz measurements — 40 tools,
client-side JS + ~3,800 words of SEO prose per page, no analytics — recorded in the US-TH-08
addendum's "Provenance" section rather than a separate research file, since the only
durable output was the triage table.
