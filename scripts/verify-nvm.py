"""Verify lazy NVM selection without loading NVM or touching installed runtimes."""
from pathlib import Path
import os
import subprocess
import tempfile

config = Path(__file__).resolve().parents[1] / 'config/zsh/nvm.zsh'
if not config.exists():
    config = Path(__file__).resolve().parents[1] / 'nvm.zsh'
with tempfile.TemporaryDirectory() as directory:
    home = Path(directory)
    nvm = home / '.nvm'
    (nvm / 'alias').mkdir(parents=True)
    (nvm / 'nvm.sh').write_text('echo "NVM should stay lazy" >&2; return 99\n')
    for version in ['24.9.0', '24.18.0', '24.21.0', '24.2.1', '240.1.0']:
        (nvm / 'versions/node' / ('v' + version) / 'bin').mkdir(parents=True)
    for alias, expected in [('24', '24.21.0'), ('24.2', '24.2.1'), ('v24.18.0', '24.18.0'), ('24.18.0', '24.18.0')]:
        (nvm / 'alias/default').write_text(alias)
        result = subprocess.run(['/bin/zsh', '-fc', 'source "$1"; print -r -- "$path[1]"', 'check', str(config)],
                                env=dict(os.environ, HOME=str(home)), capture_output=True, text=True, check=True)
        assert result.stdout.strip() == str(nvm / 'versions/node' / ('v' + expected) / 'bin'), result
        assert not result.stderr, result
print('PASS: newest NVM major/minor selection, numeric ordering, exact pins, and lazy loading.')

# The shell's default Java uses the managed JDK, but explicit project choices win.
zshenv = config.parents[2] / 'zshenv' if config.parent.name == 'zsh' else config.parent / 'zshenv'
for prefix in ['/opt/homebrew', '/usr/local']:
    java_home = Path(prefix) / 'opt/openjdk@21/libexec/openjdk.jdk/Contents/Home'
    if (java_home / 'bin/java').exists():
        clean = dict(os.environ)
        clean.pop('JAVA_HOME', None)
        result = subprocess.run(['/bin/zsh', '-fc', 'source "$1"; print -r -- "$JAVA_HOME"', 'check', str(zshenv)],
                                env=clean, capture_output=True, text=True, check=True)
        assert result.stdout.strip() == str(java_home), result
        break
result = subprocess.run(['/bin/zsh', '-fc', 'source "$1"; print -r -- "$JAVA_HOME"', 'check', str(zshenv)],
                        env=dict(os.environ, JAVA_HOME='/project-selected-jdk'), capture_output=True, text=True, check=True)
assert result.stdout.strip() == '/project-selected-jdk', result
print('PASS: managed Java 21 default and explicit project override.')
