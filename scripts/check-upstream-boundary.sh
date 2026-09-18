#!/usr/bin/env bash
# toolhub: the fork may differ from UPSTREAM_BASE only inside the integration allowance. Runs in `npm run lint`.
#
# The allowance has three tiers:
#   1. allowed_re — fork-owned namespace and files the operator widened the allowance for (A9, A10, A15).
#   2. capped     — upstream files editable up to 25 changed lines each.
#   3. semantic   — package.json / package-lock.json / locales: additions only, checked by structure not line count.
set -euo pipefail
base="${TOOLHUB_BASE:-$(cat UPSTREAM_BASE)}"
fail=0; err() { echo "boundary: $*" >&2; fail=1; }

# Fork-owned namespace, plus: .nvmrc + TESTING.md (Task 1 fork-owned), BACKLOG.md (A16),
# and the three upstream files the operator authorised by recorded decision —
# scripts/generate-blog.mjs (A9), docs/.vitepress/config.mts (A10), Dockerfile (A15).
allowed_re='^(src/pages/x-[a-z0-9-]+\.html|src/pages/_x-template\.html|src/js/logic/x-.*|src/js/config/tools-ext\.ts|src/tests/x-.*|src/tests/fixtures/x-.*|NOTICE\.md|UPSTREAM_BASE|DECISIONS\.md|BACKLOG\.md|TESTING\.md|\.nvmrc|docker-compose\.yml|deploy\.sh|deploy/.*|e2e/.*|playwright\.config\.ts|docs/specs/.*|scripts/check-upstream-boundary\.sh|scripts/check-ext-i18n\.mjs|scripts/generate-blog\.mjs|docs/\.vitepress/config\.mts|Dockerfile)$'
capped='src/js/config/tools.ts src/js/main.ts vite.config.ts nginx.conf eslint.config.mjs vitest.config.ts src/tests/setup.ts'

for f in $(git diff --name-only "$base"); do
  [[ "$f" =~ $allowed_re ]] && continue
  case " $capped package.json package-lock.json public/locales/en/tools.json public/locales/de/tools.json " in
    *" $f "*) ;;
    *) err "$f is outside the extension namespace and the integration allowance" ;;
  esac
done

for f in $capped; do
  n=$(git diff --numstat "$base" -- "$f" | awk '{print $1+$2}'); n=${n:-0}
  [ "$n" -le 25 ] || err "$f: $n > 25 changed lines"
done

# package-lock.json: semantic, not line-based — no existing node_modules/<name>.version may change.
lockbase=$(mktemp)
git show "$base:package-lock.json" > "$lockbase" 2>/dev/null || : > "$lockbase"
node - "$lockbase" package-lock.json <<'JS' || fail=1
const fs = require('fs'); const [b, c] = process.argv.slice(2).map(p => { try { return JSON.parse(fs.readFileSync(p, 'utf8')).packages || {}; } catch { return {}; } });
let bad = 0;
for (const [k, v] of Object.entries(b)) if (k.startsWith('node_modules/') && c[k] && c[k].version !== v.version) { console.error(`boundary: package-lock.json: ${k} ${v.version} -> ${c[k].version}`); bad = 1; }
process.exit(bad);
JS
rm -f "$lockbase"

# package.json: only additions to dependencies/devDependencies/scripts; no upstream version changes.
node - "$base" <<'JS' || fail=1
const { execSync } = require('child_process'); const fs = require('fs');
const base = JSON.parse(execSync(`git show ${process.argv[2]}:package.json`, { encoding: 'utf8' })); const cur = JSON.parse(fs.readFileSync('package.json', 'utf8'));
let bad = 0;
for (const sec of ['dependencies', 'devDependencies']) for (const [k, v] of Object.entries(base[sec] || {})) if (cur[sec]?.[k] !== v) { console.error(`boundary: package.json ${sec}.${k} changed/removed`); bad = 1; }
for (const k of Object.keys(base)) if (!['dependencies', 'devDependencies', 'scripts'].includes(k) && JSON.stringify(base[k]) !== JSON.stringify(cur[k])) { console.error(`boundary: package.json top-level "${k}" changed`); bad = 1; }
process.exit(bad);
JS

# locales: everything except the ext subtree must be identical to base.
for lang in en de; do
  node - "$base" "public/locales/$lang/tools.json" <<'JS' || fail=1
const { execSync } = require('child_process'); const fs = require('fs'); const [sha, p] = process.argv.slice(2);
const strip = (o) => { const c = { ...o }; delete c.ext; return JSON.stringify(c); };
const b = JSON.parse(execSync(`git show ${sha}:${p}`, { encoding: 'utf8' })); const c = JSON.parse(fs.readFileSync(p, 'utf8'));
if (strip(b) !== strip(c)) { console.error(`boundary: ${p}: changes outside the ext key`); process.exit(1); }
JS
done
[ "$fail" -eq 0 ] && echo "boundary: clean against $base"
exit "$fail"
