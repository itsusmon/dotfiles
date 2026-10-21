"""Run without network access or touching real installed tools."""
import json
import os
import pty
import re
import select
from pathlib import Path
import shutil
import subprocess
import sys
import signal
import tempfile
import time
import contextlib
import importlib.util
import io
from unittest.mock import patch

scripts = Path(__file__).resolve().parent
node = shutil.which('node')
nvim = shutil.which('nvim')

with tempfile.TemporaryDirectory(prefix='update checks ') as directory:
    root = Path(directory)
    home = root / 'home'
    home.mkdir()
    tools = root / 'bin'
    tools.mkdir()
    log = root / 'commands.jsonl'
    fake = root / 'fake-tool'
    fake.write_text(f'#!{sys.executable}\n' + '''
import json, os, pathlib, signal, subprocess, sys, time
name = pathlib.Path(sys.argv[0]).name
args = sys.argv[1:]
key = ' '.join([name, *args])
with open(os.environ['UPDATE_TEST_LOG'], 'a') as f:
    f.write(json.dumps([name, *args]) + '\\n')
if name == 'brew': assert os.environ.get('HOMEBREW_NO_ASK') == '1', 'Homebrew would prompt'
if key == os.environ.get('UPDATE_TEST_BLOCK'):
    signal.signal(signal.SIGINT, signal.SIG_IGN)
    if os.environ.get('UPDATE_TEST_STUBBORN'): signal.signal(signal.SIGTERM, signal.SIG_IGN)
    print('INPUT READY', flush=True)
    assert input() == 'continue', 'Background worker lost terminal input'
    child = subprocess.Popen([sys.executable, '-c',
        'import signal,time; signal.signal(signal.SIGINT,signal.SIG_IGN); '
        'signal.signal(signal.SIGTERM,signal.SIG_IGN); '
        'print("DESCENDANT READY",flush=True); time.sleep(60)'])
    pathlib.Path(os.environ['UPDATE_TEST_PIDS']).write_text(json.dumps([os.getpid(),child.pid]))
    print('PARENT READY', flush=True)
    time.sleep(60)
output = json.loads(os.environ.get('UPDATE_TEST_OUTPUT', '{}')).get(key)
if output is not None: print(output)
elif name == 'uname':
    time.sleep(float(os.environ.get('UPDATE_TEST_DELAY', '0')))
    print('Darwin')
if name == 'sudo': sys.exit(subprocess.call(args))
sys.exit(json.loads(os.environ.get('UPDATE_TEST_STATUS', '{}')).get(key, 0))
''')
    fake.chmod(0o755)
    for utility in ['dirname', 'readlink', 'cat', 'awk', 'sort', 'sed', 'env', 'mktemp', 'cp', 'mv', 'rm', 'rmdir', 'tr', 'tail', 'tee']:
        (tools / utility).symlink_to(shutil.which(utility))
    env = dict(os.environ, HOME=str(home), PATH=str(tools), NVM_DIR=str(home / '.nvm'),
               XDG_CONFIG_HOME=str(home / '.config'), XDG_DATA_HOME=str(home / '.local/share'),
               XDG_STATE_HOME=str(home / '.local/state'), XDG_CACHE_HOME=str(home / '.cache'),
               CARGO_HOME=str(home / '.cargo'), UPDATE_TEST_LOG=str(log), TMPDIR=str(root))
    env.pop('COREPACK_HOME', None)
    (tools / 'uname').symlink_to(fake)
    launcher = tools / 'update with spaces'
    launcher.symlink_to(scripts / 'bin/update')

    def run(args=(), statuses=None, outputs=None, command=None, delay=0):
        log.write_text('')
        result = subprocess.run(command or ['/bin/bash', str(launcher), *args], env=dict(env,
            UPDATE_TEST_STATUS=json.dumps(statuses or {}), UPDATE_TEST_OUTPUT=json.dumps(outputs or {}),
            UPDATE_TEST_DELAY=str(delay)),
            capture_output=True, text=True, timeout=20)
        calls = [json.loads(line) for line in log.read_text().splitlines()]
        if command is None and result.returncode in (0, 1, 130):
            assert re.fullmatch(r'⏱ Total time: \d+m [0-5]?\ds', result.stdout.splitlines()[-1]), result
        return result, calls

    result, _ = run(delay=1.1)
    duration = re.search(r'⏱ Total time: (\d+)m (\d+)s', result.stdout)
    assert duration and int(duration[1]) * 60 + int(duration[2]) >= 1, result
    assert result.returncode == 0 and '0 failed' in result.stdout, result
    assert 'App Store' not in result.stdout, result
    assert 'Command Line Tools updates' not in result.stdout, result
    for name in ['brew', 'rustup', 'android', 'nextdns', 'mas', 'softwareupdate', 'sudo', 'git']:
        (tools / name).symlink_to(fake)
    result, calls = run(statuses={'brew update': 7, 'android update': 9})
    assert result.returncode == 1 and '2 failed' in result.stdout, result
    assert ['android', 'sdk', 'update'] in calls and ['rustup', 'update'] in calls, calls
    assert 'exit 7' in result.stderr and 'exit 9' in result.stderr, result
    assert ['brew', 'upgrade', '--cask', '--greedy'] in calls and ['mas', 'upgrade'] in calls, calls
    result, calls = run(statuses={'brew upgrade --cask --greedy': 8, 'mas upgrade': 9})
    assert result.returncode == 1 and '2 failed' in result.stdout, result
    assert ['rustup', 'update'] in calls and ['mas', 'upgrade'] in calls, calls
    for name, owner in [('android', 'Caskroom'), ('nextdns', 'Cellar')]:
        managed = root / owner / name / '1.0' / name
        managed.parent.mkdir(parents=True)
        managed.write_bytes(fake.read_bytes())
        managed.chmod(0o755)
        (tools / name).unlink()
        (tools / name).symlink_to(managed)
    result, calls = run()
    assert result.returncode == 0 and ['android', 'sdk', 'update'] in calls, (result, calls)
    assert ['android', 'update'] not in calls and ['nextdns', 'upgrade'] not in calls, calls
    for name in ['android', 'nextdns']:
        (tools / name).unlink()
        (tools / name).symlink_to(fake)
    noise = '\n'.join(f'installer noise {i}' for i in range(100))
    result, _ = run(outputs={'brew update': noise})
    assert 'installer noise' not in result.stdout, result
    log_dir = Path(result.stdout.split('📄 Logs: ')[1].splitlines()[0])
    assert (log_dir / '01-homebrew-metadata.log').read_text().strip() == noise
    assert not (log_dir / 'index.txt').exists()
    assert (log_dir / '03-homebrew-desktop-apps.log').is_file()
    assert not any(p.stem.isdigit() for p in log_dir.iterdir())
    filenames = sorted(p.name for p in log_dir.iterdir())
    assert [int(name.split('-')[0]) for name in filenames] == list(range(1, len(filenames) + 1)), filenames
    result, _ = run(statuses={'brew update': 7}, outputs={'brew update': noise + '\nnetwork failure'})
    assert 'network failure' in result.stderr and 'installer noise 0\n' not in result.stderr, result
    result, _ = run(['--verbose'], outputs={'brew update': 'visible detail'})
    assert 'visible detail' in result.stdout, result
    result, _ = run(['--check'], outputs={'rustup check': 'Rust update available', 'brew outdated --verbose --greedy': 'app: 1 -> 2', 'mas outdated': 'Store app: 1 -> 2'})
    assert all(text in result.stdout for text in ['Rust update available', 'app: 1 -> 2', 'Store app: 1 -> 2']), result
    result, calls = run(['--check'], {'rustup check': 100})
    assert result.returncode == 0, result
    assert ['mas', 'outdated'] in calls, calls
    assert all(call in [['uname', '-s'], ['brew', 'outdated', '--verbose', '--greedy'],
                       ['rustup', 'check'], ['softwareupdate', '--list'], ['mas', 'outdated']] for call in calls), calls
    clt = 'Command Line Tools for Xcode-26.4'
    clt_next = 'Command Line Tools for Xcode-26.5'
    listing = f"""Software Update Tool
* Label: macOS Golden Gate 27.1-26B42
    Title: macOS Golden Gate, Version: 27.1, Action: restart
* Label: {clt}
    Title: Command Line Tools for Xcode, Version: 26.4
* Label: Safari26.1
* Label: macOS Command Line Tools for Xcode-Fake
"""
    result, calls = run(outputs={'softwareupdate --list': listing})
    assert result.returncode == 0, result
    assert ['softwareupdate', '--install', clt] in calls, calls
    assert [call for call in calls if call[:2] == ['softwareupdate', '--install']] == [['softwareupdate', '--install', clt]], calls
    assert ['sudo', str(tools / 'softwareupdate'), '--install', clt] in calls, calls
    assert 'macOS Golden Gate' not in result.stdout, result
    result, calls = run(['--check'], outputs={'softwareupdate --list': listing})
    assert clt in result.stdout and 'macOS Golden Gate' not in result.stdout, result
    assert not any(call[0] == 'sudo' or '--install' in call for call in calls), calls
    result, calls = run(statuses={f'softwareupdate --install {clt}': 8},
                        outputs={'softwareupdate --list': listing + f'* Label: {clt_next}\n'})
    assert result.returncode == 1 and ['softwareupdate', '--install', clt_next] in calls and ['mas', 'upgrade'] in calls, (result, calls)
    result, calls = run(statuses={'softwareupdate --list': 7})
    assert result.returncode == 1 and not any('--install' in call for call in calls), (result, calls)
    result, calls = run(['--dry-run'])
    assert result.returncode == 0 and calls == [['uname', '-s']], (result, calls)
    result, calls = run(statuses={'brew update': 130})
    assert result.returncode == 130 and not any(call[0] == 'android' for call in calls), (result, calls)
    for stubborn, verbose in [('', True), ('1', True), ('1', False)]:
        log.write_text('')
        pid_file = root / 'blocked-pids.json'
        pid_file.unlink(missing_ok=True)
        pid, terminal = pty.fork()
        if pid == 0:
            os.execve('/bin/bash', ['/bin/bash', str(launcher), *(['--verbose'] if verbose else [])], dict(env,
                UPDATE_TEST_BLOCK='brew update', UPDATE_TEST_STUBBORN=stubborn,
                UPDATE_TEST_PIDS=str(pid_file)))
        output = b''
        step_output = b''
        sent_input = interrupted = False
        status = None
        deadline = time.monotonic() + 8
        try:
            while time.monotonic() < deadline:
                if select.select([terminal], [], [], 0.05)[0]:
                    try: output += os.read(terminal, 65536)
                    except OSError: break
                if verbose:
                    step_output = output
                else:
                    step_output = b''.join(p.read_bytes() for p in root.glob('update.*/01-homebrew-metadata.log'))
                if b'INPUT READY' in step_output and not sent_input:
                    os.write(terminal, b'continue\n')
                    sent_input = True
                if pid_file.exists() and all(marker in step_output for marker in [b'DESCENDANT READY', b'PARENT READY']) and not interrupted:
                    os.write(terminal, b'\x03')
                    interrupted = True
                    deadline = time.monotonic() + 5
                done, value = os.waitpid(pid, os.WNOHANG)
                if done: status = value; break
            if status is None:
                done, value = os.waitpid(pid, os.WNOHANG)
                if done: status = value
            assert interrupted and status is not None, output.decode(errors='replace')
            assert os.waitstatus_to_exitcode(status) == 130, output.decode(errors='replace')
            assert b'Cancelled; no further updates will run.' in output, output
            assert '⏱ Total time:'.encode() in output, output
            for descendant in json.loads(pid_file.read_text()):
                state = subprocess.run(['/bin/ps', '-p', str(descendant), '-o', 'stat='], capture_output=True, text=True)
                assert not state.stdout.strip() or state.stdout.strip().startswith('Z'), (descendant, state.stdout)
            calls = [json.loads(line) for line in log.read_text().splitlines()]
            assert calls == [['uname', '-s'], ['brew', 'update']], calls
        finally:
            try: os.killpg(pid, signal.SIGKILL)
            except ProcessLookupError: pass
            if status is None: os.waitpid(pid, 0)
            os.close(terminal)
    result, _ = run(['--check', '--dry-run'])
    assert result.returncode == 2, result
    plugin = home / '.zsh/zsh-autosuggestions'
    (plugin / '.git').mkdir(parents=True)
    result, calls = run(outputs={f'git -C {plugin} status --porcelain': ' M customized.zsh'})
    assert result.returncode == 1 and not any('pull' in call for call in calls), (result, calls)
    fzf = home / '.fzf'
    (fzf / '.git').mkdir(parents=True)
    (fzf / 'bin').mkdir()
    (fzf / 'bin/fzf').write_text('original binary')
    (fzf / 'install').write_text('#!/bin/bash\nrm "$HOME/.fzf/bin/fzf"\nexit 5\n')
    (fzf / 'install').chmod(0o755)
    result, _ = run()
    assert result.returncode == 1 and (fzf / 'bin/fzf').read_text() == 'original binary', result

    (tools / 'python3').symlink_to(fake)
    python_update = ['python3', str(scripts / 'update-python.py'), 'update']
    result, calls = run(statuses={' '.join(python_update): 17})
    assert python_update in calls and ['mas', 'upgrade'] in calls and 'exit 17' in result.stderr, (result, calls)
    result, calls = run(['--check'])
    assert ['python3', str(scripts / 'update-python.py'), 'check'] in calls and python_update not in calls, calls
    (tools / 'python3').unlink()

    if node:
        for name in ['npm', 'npx', 'corepack']:
            (tools / name).symlink_to(fake)
        helper = [node, str(scripts / 'update-node.mjs')]
        result, _ = run(command=helper + ['npm-check'], statuses={'npm outdated --global --json': 1},
                        outputs={'npm outdated --global --json': '{"foo":{"current":"1","wanted":"2","latest":"2"}}'})
        assert result.returncode == 0 and 'foo: 1 -> 2' in result.stdout, result
        result, _ = run(command=helper + ['npm-check'], statuses={'npm outdated --global --json': 1},
                        outputs={'npm outdated --global --json': '{"error":{"code":"E401"}}'})
        assert result.returncode == 1, result
        packages = root / 'global packages'
        for name in ['bad', 'good']:
            (packages / name).mkdir(parents=True)
        result, calls = run(command=helper + ['npm-update'], statuses={'npm update --global -- bad': 8}, outputs={
            'npm root --global': str(packages),
            'npm ls --global --depth=0 --json': '{"dependencies":{"bad":{},"good":{},"linked":{"link":true}}}',
        })
        assert result.returncode == 1 and ['npm', 'update', '--global', '--', 'good'] in calls, (result, calls)
        assert not any(call[-1] == 'linked' for call in calls), calls
        skill = home / '.agents/skills/kept/SKILL.md'
        skill.parent.mkdir(parents=True)
        skill.write_text('kept')
        lock = Path(env['XDG_STATE_HOME']) / 'skills/.skill-lock.json'
        lock.parent.mkdir(parents=True)
        entry = {'sourceType': 'github', 'source': 'owner/repo', 'skillPath': 'skills/kept/SKILL.md', 'skillFolderHash': 'old'}
        lock.write_text(json.dumps({'skills': {'kept': entry, 'removed': entry}}))
        result, calls = run(command=helper + ['skills-update'])
        assert result.returncode == 0 and calls == [['npx', '--yes', 'skills@latest', 'update', 'kept', '--global', '--yes']], (result, calls)
        source = 'process.argv[2]="skills-check"; globalThis.fetch=async()=>({ok:true,json:async()=>({tree:[{type:"tree",path:"skills/kept",sha:"new"}]})}); await import(' + json.dumps((scripts / 'update-node.mjs').as_uri()) + ');'
        result, calls = run(command=[node, '--input-type=module', '-e', source])
        assert result.returncode == 0 and 'kept: update available' in result.stdout and not calls, (result, calls)
        assert lock.exists() and skill.read_text() == 'kept'
    else:
        print('SKIP: Node helper checks (Node not installed).')

    if nvim:
        stub = root / 'check.lua'
        mason_setup = """
package.loaded['mason-registry']={update=function(cb) cb(true) end,
get_installed_packages=function() return {{name='fake-tool',
get_installed_version=function() return '1' end,get_latest_version=function() return '2' end}} end}
vim.api.nvim_create_user_command('MasonInstall', function(opts)
  if not opts.args:find('--quiet',1,true) then vim.api.nvim_err_write('x bin/\\n') end
  if vim.env.UPDATE_TEST_MASON_FAIL == '1' then vim.cmd('cquit 1') end
end, {nargs='+'})
"""
        for component, setup, expected in [
            ('lazy', "package.loaded.lazy={update=function() end}; package.loaded['lazy.core.config']={plugins={bad={_={tasks={{has_errors=function() return true end,output=function() return 'network failure' end}}}}}}", 1),
            ('treesitter', "package.loaded['nvim-treesitter']={update=function() return {wait=function() return false end} end}", 1),
            ('mason', "package.loaded['mason-registry']={update=function(cb) cb(false) end}", 1),
            ('lazy', "package.loaded.lazy={update=function() end}; package.loaded['lazy.core.config']={plugins={}}", 0),
            ('mason', mason_setup, 0),
            ('mason', "vim.env.UPDATE_TEST_MASON_FAIL='1';" + mason_setup, 1),
        ]:
            stub.write_text(f'vim.env.UPDATE_MODE="update"; vim.env.UPDATE_NVIM_COMPONENT="{component}"; {setup}; dofile({json.dumps(str(scripts / "update-nvim.lua"))})')
            result, _ = run(command=[nvim, '--headless', '-u', 'NONE', '-i', 'NONE', '-c', f'lua dofile({json.dumps(str(stub))})'])
            assert result.returncode == expected, result
    else:
        print('SKIP: Neovim helper checks (Neovim not installed).')
spec = importlib.util.spec_from_file_location('update_python', scripts / 'update-python.py')
python_helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(python_helper)
packages = json.dumps([{'name': 'idna', 'version': '3.19'}, {'name': 'urllib3', 'version': '1.26.20'}])
for tls, version, constrained, managed in [('LibreSSL 2.8.3', (2, 8, 3), True, False), ('OpenSSL 3.0.0', (3, 0, 0), False, False), ('OpenSSL 3.0.0', (3, 0, 0), False, True)]:
    for mode in ['check', 'update']:
        calls = []
        def pip_call(command):
            calls.append(command)
            assert '--break-system-packages' not in command
            if 'install' in command:
                assert ('--user' in command) == (not managed) and command[-3:] == ['--', 'idna', 'urllib3'], command
                assert ('--constraint' in command) == constrained, command
                if constrained:
                    assert Path(command[command.index('--constraint') + 1]).read_text() == 'urllib3<2\n'
                assert ('--dry-run' in command) == (mode == 'check'), command
                if mode == 'check':
                    Path(command[command.index('--report') + 1]).write_text(json.dumps({
                        'install': [{'metadata': {'name': 'idna', 'version': '3.20'}}]}))
            return 0
        output = io.StringIO()
        with patch.object(sys, 'prefix', str(Path.home() / '.local/share/python') if managed else sys.base_prefix), patch.object(python_helper.ssl, 'OPENSSL_VERSION', tls), \
             patch.object(python_helper.ssl, 'OPENSSL_VERSION_INFO', version), \
             patch.object(subprocess, 'check_output', return_value=packages) as listing, \
             patch.object(subprocess, 'check_call', side_effect=pip_call), contextlib.redirect_stdout(output):
            python_helper.main(mode)
        assert ('--user' in listing.call_args.args[0]) == (not managed) and '--exclude-editable' in listing.call_args.args[0]
        assert (calls[-1][-1] == 'check') == (mode == 'update'), calls
        if mode == 'check': assert 'idna: 3.19 -> 3.20' in output.getvalue(), output.getvalue()
with patch.object(sys, 'prefix', '/active-venv'), patch.object(subprocess, 'check_output') as listing, \
     contextlib.redirect_stdout(io.StringIO()):
    python_helper.main('update')
    listing.assert_not_called()
with patch.object(sys, 'prefix', sys.base_prefix), patch.object(subprocess, 'check_output', return_value='[]'), \
     patch.object(subprocess, 'check_call') as install, contextlib.redirect_stdout(io.StringIO()):
    python_helper.main('update')
    install.assert_not_called()
print('PASS: compact logs, report visibility, terminal Ctrl-C, descendant cleanup, stdin, Homebrew auto-confirmation, missing tools, failure continuation, read-only checks, Python runtime compatibility, and helper errors.')
