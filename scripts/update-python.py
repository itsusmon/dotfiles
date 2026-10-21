"""Upgrade user packages or the dedicated default environment with pip's resolver."""
import json
from pathlib import Path
import re
import ssl
import subprocess
import sys
import tempfile


def main(mode):
    managed = Path(sys.prefix) == Path.home() / '.local/share/python'
    if sys.prefix != sys.base_prefix and not managed:
        print('[SKIP] Python virtual environment is active; project packages left untouched.')
        return
    pip = [sys.executable, '-m', 'pip', '--disable-pip-version-check', '--no-input']
    scope = [] if managed else ['--user']
    packages = json.loads(subprocess.check_output(
        pip + ['list', *scope, '--exclude-editable', '--format=json'], text=True))
    if not packages:
        print('No Python user packages installed.')
        return
    names = [package['name'] for package in packages]
    if not all(re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._-]*', name) for name in names):
        raise ValueError('Invalid package name returned by pip.')
    # Keep all user packages in one resolution so their requirements are considered together.
    with tempfile.TemporaryDirectory(prefix='update-python-') as directory:
        install = pip + ['install', *scope, '--upgrade']
        if not ssl.OPENSSL_VERSION.startswith('OpenSSL ') or ssl.OPENSSL_VERSION_INFO < (1, 1, 1):
            constraints = Path(directory) / 'constraints.txt'
            constraints.write_text('urllib3<2\n')
            install += ['--constraint', str(constraints)]
            print('[SKIP] urllib3 2.x requires OpenSSL 1.1.1+; keeping a compatible version.', flush=True)
        if mode == 'check':
            report = Path(directory) / 'report.json'
            subprocess.check_call(install + ['--dry-run', '--report', str(report), '--quiet', '--', *names])
            updates = json.loads(report.read_text())['install']
            current = {p['name'].lower().replace('_', '-'): p['version'] for p in packages}
            for update in updates:
                package = update['metadata']
                old = current.get(package['name'].lower().replace('_', '-'), 'new dependency')
                print(f"{package['name']}: {old} -> {package['version']}")
            if not updates:
                print('Python user packages are up to date within runtime compatibility limits.')
        else:
            subprocess.check_call(install + ['--', *names])
            subprocess.check_call(pip + ['check'])


if __name__ == '__main__':
    try:
        main(sys.argv[1])
    except subprocess.CalledProcessError as error:
        sys.exit(error.returncode if error.returncode >= 0 else 128 - error.returncode)
