#!/usr/bin/env node
// toolhub: every ext.* key present in en/tools.json must exist in de/tools.json. Runs in `npm run build`.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const argv = process.argv.slice(2);
const localesIdx = argv.indexOf('--locales');
const LOCALES_DIR =
  localesIdx >= 0
    ? argv[localesIdx + 1]
    : path.resolve(
        path.dirname(fileURLToPath(import.meta.url)),
        '../public/locales'
      );

function flatten(obj, prefix = '') {
  const out = {};
  for (const [k, v] of Object.entries(obj ?? {})) {
    const key = prefix ? `${prefix}.${k}` : k;
    if (v && typeof v === 'object' && !Array.isArray(v))
      Object.assign(out, flatten(v, key));
    else out[key] = v;
  }
  return out;
}
const load = (lang) =>
  JSON.parse(
    fs.readFileSync(path.join(LOCALES_DIR, lang, 'tools.json'), 'utf8')
  );
const en = flatten(load('en').ext, 'ext');
const de = flatten(load('de').ext, 'ext');
const missing = Object.keys(en).filter((k) => !(k in de));
if (missing.length) {
  console.error(
    `check-ext-i18n: ${missing.length} ext key(s) present in en but missing in de:\n  ${missing.join('\n  ')}`
  );
  process.exit(1);
}
console.log(
  `check-ext-i18n: ${Object.keys(en).length} ext key(s) present in both en and de`
);
