// Node is already required by npm; no additional runtime or packages are needed.
import { existsSync, readFileSync, lstatSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { spawnSync } from 'node:child_process';

const home = process.env.HOME;
const mode = process.argv[2];
const read = path => JSON.parse(readFileSync(path, 'utf8'));
function capture(command, args, allowed = [0]) {
  const result = spawnSync(command, args, { encoding: 'utf8' });
  if (result.error || !allowed.includes(result.status)) {
    throw new Error(result.error?.message || result.stderr || `${command} exited ${result.status}`);
  }
  return result.stdout;
}
function run(command, args) {
  const result = spawnSync(command, args, { stdio: 'inherit' });
  if (result.signal === 'SIGINT' || result.status === 130) process.exit(130);
  if (result.error || result.status !== 0) throw new Error(`${command}: ${result.error?.message || `exit ${result.status}`}`);
}
async function each(items, action) {
  for (const item of items) {
    try { await action(item); }
    catch (error) { console.error(`[FAILED] ${item}: ${error.message}`); process.exitCode = 1; }
  }
}

try {
  if (mode === 'npm-check') {
    const outdated = JSON.parse(capture('npm', ['outdated', '--global', '--json'], [0, 1]) || '{}');
    if (outdated.error) throw new Error(JSON.stringify(outdated.error));
    for (const [name, info] of Object.entries(outdated)) {
      console.log(`${name}: ${info.current ?? 'missing'} -> ${info.wanted} (latest ${info.latest})`);
    }
    if (!Object.keys(outdated).length) console.log('All npm globals are up to date.');
  } else if (mode === 'npm-update') {
    const root = capture('npm', ['root', '--global']).trim();
    const packages = JSON.parse(capture('npm', ['ls', '--global', '--depth=0', '--json'])).dependencies || {};
    await each(Object.keys(packages), name => {
      if (packages[name].link || lstatSync(join(root, name)).isSymbolicLink() ||
          (name === 'npm' && process.execPath.includes('/Cellar/'))) {
        console.log(`[SKIP] ${name}: linked or Homebrew-owned package.`); return;
      }
      run('npm', ['update', '--global', '--', name]);
      console.log(`[OK] npm package: ${name}`);
    });
  } else if (mode.startsWith('corepack-')) {
    const root = process.env.COREPACK_HOME || join(process.env.XDG_CACHE_HOME || join(home, '.cache'), 'node/corepack');
    const state = join(root, 'lastKnownGood.json');
    if (!existsSync(state)) console.log('[SKIP] No activated Corepack package managers.');
    else {
      const defaults = read(state);
      await each(Object.keys(defaults).filter(name => ['pnpm', 'yarn'].includes(name)), name => {
        const current = defaults[name].split('+')[0];
        if (!/^\d+\.\d+\.\d+$/.test(current)) throw new Error('Nonstandard version; preserve it and update manually.');
        const major = current.split('.')[0];
        const versions = JSON.parse(capture('npm', ['view', `${name}@${major}`, 'version', '--json']));
        const latest = Array.isArray(versions) ? versions.at(-1) : versions;
        console.log(`${name}: ${current}; latest in major ${major}: ${latest}`);
        if (mode === 'corepack-update' && current !== latest) run('corepack', ['install', '--global', `${name}@${latest}`]);
      });
    }
  } else if (mode.startsWith('skills-')) {
    const candidates = [
      join(process.env.XDG_STATE_HOME || join(home, '.local/state'), 'skills/.skill-lock.json'),
      join(home, '.agents/.skill-lock.json'),
    ];
    const lockfile = candidates.find(existsSync);
    if (!lockfile) console.log('[SKIP] No tracked global skills.');
    else {
      const skills = read(lockfile).skills || {};
      const installed = Object.keys(skills).filter(name => /^[\w.-]+$/.test(name) && name !== '..' &&
        [join(home, '.agents/skills'), join(process.env.XDG_CONFIG_HOME || join(home, '.config'), 'agents/skills')]
          .some(root => existsSync(join(root, name, 'SKILL.md'))));
      const trees = new Map();
      await each(installed, async name => {
        const entry = skills[name];
        if (mode === 'skills-update') {
          run('npx', ['--yes', 'skills@latest', 'update', name, '--global', '--yes']);
          return;
        }
        // Never call `skills check`: some releases alias it to the mutating updater.
        if (entry.sourceType !== 'github' || !/^[\w.-]+\/[\w.-]+$/.test(entry.source) || !entry.skillPath || !entry.skillFolderHash) {
          console.log(`[MANUAL] ${name}: no supported read-only source check.`); return;
        }
        const key = `${entry.source}/${entry.ref || 'HEAD'}`;
        if (!trees.has(key)) {
          const response = await fetch(`https://api.github.com/repos/${entry.source}/git/trees/${encodeURIComponent(entry.ref || 'HEAD')}?recursive=1`, {
            headers: { Accept: 'application/vnd.github+json' }, signal: AbortSignal.timeout(30000),
          });
          if (!response.ok) throw new Error(`GitHub HTTP ${response.status}`);
          const tree = await response.json();
          if (tree.truncated) throw new Error('Incomplete GitHub tree; cannot determine updates.');
          trees.set(key, tree.tree);
        }
        const latest = trees.get(key).find(item => item.type === 'tree' && item.path === dirname(entry.skillPath));
        if (!latest) throw new Error('Upstream skill moved or disappeared; review manually.');
        console.log(`${name}: ${latest.sha === entry.skillFolderHash ? 'up to date' : 'update available'}`);
      });
      if (!installed.length) console.log('[SKIP] No tracked skills remain installed.');
    }
  } else throw new Error(`Unknown action: ${mode}`);
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
}
