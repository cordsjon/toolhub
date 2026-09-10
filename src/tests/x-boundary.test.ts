import { describe, it, expect, beforeAll } from 'vitest';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, writeFileSync, mkdirSync, cpSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { tmpdir } from 'node:os';

const SCRIPT = 'scripts/check-upstream-boundary.sh';
const REPO_ROOT = resolve(__dirname, '../..');

const git = (cwd: string, ...args: string[]) => {
  // CC_ALLOW_WHOLE_INDEX: these are throwaway fixture repos created inside this
  // test, so committing the whole index is the intent. Scoped to this spawn only.
  const r = spawnSync('git', args, {
    cwd,
    encoding: 'utf8',
    env: { ...process.env, CC_ALLOW_WHOLE_INDEX: '1' },
  });
  if (r.status !== 0) throw new Error(`git ${args.join(' ')}: ${r.stderr}`);
  return r.stdout.trim();
};

const write = (root: string, rel: string, body: string) => {
  const abs = join(root, rel);
  mkdirSync(join(abs, '..'), { recursive: true });
  writeFileSync(abs, body);
};

const BASE_LOCALE = JSON.stringify({
  categories: { popularTools: 'Popular Tools' },
  mergePdf: { name: 'Merge PDF' },
});

/**
 * A throwaway repo whose base commit stands in for UPSTREAM_BASE. The real
 * script is copied in so the test exercises the shipped file, not a fixture.
 */
function makeRepo(): { repo: string; base: string } {
  const repo = mkdtempSync(join(tmpdir(), 'boundary-'));
  git(repo, 'init', '-q');
  git(repo, 'config', 'user.email', 't@t');
  git(repo, 'config', 'user.name', 't');

  write(
    repo,
    'nginx.conf',
    Array.from({ length: 30 }, (_, i) => `# ${i}`).join('\n') + '\n'
  );
  write(
    repo,
    'package.json',
    JSON.stringify(
      {
        name: 'f',
        version: '1.0.0',
        scripts: { build: 'x' },
        dependencies: { left: '1.0.0' },
      },
      null,
      2
    )
  );
  write(
    repo,
    'package-lock.json',
    JSON.stringify(
      { packages: { 'node_modules/a': { version: '1.0.0' } } },
      null,
      2
    )
  );
  write(repo, 'public/locales/en/tools.json', BASE_LOCALE);
  write(repo, 'public/locales/de/tools.json', BASE_LOCALE);
  write(repo, 'README.md', 'base\n');

  mkdirSync(join(repo, 'scripts'), { recursive: true });
  cpSync(join(REPO_ROOT, SCRIPT), join(repo, SCRIPT));

  git(repo, 'add', '-A');
  git(repo, 'commit', '-qm', 'base');
  return { repo, base: git(repo, 'rev-parse', 'HEAD') };
}

function run(mutate: (repo: string) => void) {
  const { repo, base } = makeRepo();
  mutate(repo);
  return spawnSync('bash', [SCRIPT], {
    cwd: repo,
    encoding: 'utf8',
    env: { ...process.env, TOOLHUB_BASE: base },
  });
}

describe('check-upstream-boundary', () => {
  beforeAll(() => {
    // The script must exist before any case runs; a missing file would make
    // every "exit 1" assertion pass for the wrong reason.
    const r = spawnSync('bash', ['-n', SCRIPT], {
      cwd: REPO_ROOT,
      encoding: 'utf8',
    });
    expect(r.status, `${SCRIPT} must parse: ${r.stderr}`).toBe(0);
  });

  it('(a) accepts a new extension page', () => {
    const r = run((repo) =>
      write(repo, 'src/pages/x-foo.html', '<!doctype html>\n')
    );
    expect(r.stderr).toBe('');
    expect(r.status).toBe(0);
  });

  it('(b) rejects an edit to an unrelated upstream file', () => {
    const r = run((repo) => write(repo, 'README.md', 'changed\n'));
    expect(r.status).toBe(1);
    expect(r.stderr).toContain('README.md');
  });

  it('(c) rejects a version change to an existing lockfile package', () => {
    const r = run((repo) =>
      write(
        repo,
        'package-lock.json',
        JSON.stringify(
          { packages: { 'node_modules/a': { version: '1.0.1' } } },
          null,
          2
        )
      )
    );
    expect(r.status).toBe(1);
    expect(r.stderr).toContain('package-lock.json: node_modules/a');
  });

  it('(d) accepts a newly added lockfile package', () => {
    const r = run((repo) =>
      write(
        repo,
        'package-lock.json',
        JSON.stringify(
          {
            packages: {
              'node_modules/a': { version: '1.0.0' },
              'node_modules/b': { version: '2.0.0' },
            },
          },
          null,
          2
        )
      )
    );
    expect(r.stderr).toBe('');
    expect(r.status).toBe(0);
  });

  it('(e) rejects a capped file exceeding 25 changed lines', () => {
    const r = run((repo) =>
      write(
        repo,
        'nginx.conf',
        Array.from({ length: 30 }, (_, i) => `# ${i}`).join('\n') +
          '\n' +
          Array.from({ length: 26 }, (_, i) => `# add ${i}`).join('\n') +
          '\n'
      )
    );
    expect(r.status).toBe(1);
    expect(r.stderr).toContain('nginx.conf: 26 > 25');
  });

  it('(f) rejects a locale change outside the ext subtree', () => {
    const r = run((repo) =>
      write(
        repo,
        'public/locales/en/tools.json',
        JSON.stringify({
          categories: { popularTools: 'RENAMED' },
          mergePdf: { name: 'Merge PDF' },
        })
      )
    );
    expect(r.status).toBe(1);
    expect(r.stderr).toContain('outside the ext key');
  });

  it('(g) accepts an addition inside the ext subtree', () => {
    const r = run((repo) =>
      write(
        repo,
        'public/locales/en/tools.json',
        JSON.stringify({
          categories: { popularTools: 'Popular Tools' },
          mergePdf: { name: 'Merge PDF' },
          ext: { common: { copy: 'Copy' } },
        })
      )
    );
    expect(r.stderr).toBe('');
    expect(r.status).toBe(0);
  });
});
