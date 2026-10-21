import os
from pathlib import Path
import subprocess
import tempfile

script = Path(__file__).parent / 'bin' / 'cycle'
with tempfile.TemporaryDirectory() as directory:
    tools = Path(directory)
    for name, body in {
        'stat': 'echo 1700000000',
        'date': 'if [ "$1" = +%s ]; then echo 1700864000; else echo "Nov 14 2023 22:13"; fi',
        'ioreg': 'printf "%s\\n" "$CYCLE_FIXTURE"',
    }.items():
        executable = tools / name
        executable.write_text('#!/bin/bash\n' + body + '\n')
        executable.chmod(0o755)
    env = dict(os.environ, PATH=f'{tools}:/usr/bin:/bin')
    for prefix in ['    ', '    | ']:
        env['CYCLE_FIXTURE'] = f'{prefix}"CycleCount" = 20\n{prefix}"CycleCount" = 99'
        result = subprocess.run([str(script)], env=env, capture_output=True, text=True)
        assert result.returncode == 0, result.stderr
        assert 'Battery cycles: 20\n' in result.stdout, result.stdout
        assert 'Cycles/day:     2\n' in result.stdout, result.stdout
        assert 'Time/cycle:     0w 0d 12h 0m 0s\n' in result.stdout, result.stdout
    env['CYCLE_FIXTURE'] = '  | "CycleCount" = 0'
    result = subprocess.run([str(script)], env=env, capture_output=True, text=True)
    assert result.returncode == 0 and 'Time/cycle:     N/A' in result.stdout, result
    env['CYCLE_FIXTURE'] = '  | "Other" = 20'
    result = subprocess.run([str(script)], env=env, capture_output=True, text=True)
    assert result.returncode != 0 and 'could not read battery cycle count' in result.stderr
print('PASS: cycle parses old/new ioreg output, uses the first match, and handles zero/missing counts')
