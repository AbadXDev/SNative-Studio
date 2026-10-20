#!/usr/bin/env python3
"""Prepare the distributable copy of scripts/build_ipa_from_nsp.py.

The nxnative checkout is never a valid target: a copy whose engine root still
contains .git is refused, and the write happens only after the two PATH lines
match this script exactly once. Run it on the copy created by bundle_engine.sh.
"""

import os
import sys
from pathlib import Path

ORIGINAL_TOOL = (
    "TOOL_PATHS = ['/opt/homebrew/bin', '/usr/local/bin', "
    "'/usr/local/share/dotnet', os.path.expanduser('~/.dotnet')]   "
    "# GUI apps such as Spyder do not get the shell's PATH\n"
)
ORIGINAL_ENV = (
    "    env = dict(os.environ, PATH=os.pathsep.join(TOOL_PATHS + "
    "[os.environ.get('PATH', '/usr/bin:/bin:/usr/sbin:/sbin')]))\n"
)
PATCHED_ENV = (
    "    env = dict(os.environ, PATH=os.pathsep.join(snative_tool_paths(TOOL_PATHS) + "
    "[os.environ.get('PATH', '/usr/bin:/bin:/usr/sbin:/sbin')]))\n"
)
MARKER = "def snative_tool_paths(base):\n"
FUNCTION = '''def snative_tool_paths(base):
    # SNative Studio: packaged tool directories. Not part of the nxnative checkout.
    # SNATIVE_TOOL_PATH is prepended for this process only. An earlier dotnet whose
    # major version is not 10 does not hide a later .NET SDK 10; that directory stays
    # on PATH after the SDK 10 directory, so its other tools remain reachable.
    extra = [p for p in os.environ.get('SNATIVE_TOOL_PATH', '').split(os.pathsep) if p]
    if not extra:
        return list(base)
    paths = extra + [p for p in base if p and p not in extra]

    def sdk_major(directory):
        binary = os.path.join(directory, 'dotnet')
        if not os.path.isfile(binary) or not os.access(binary, os.X_OK):
            return None
        try:
            out = subprocess.check_output([binary, '--version'], text=True, stderr=subprocess.DEVNULL, timeout=15)
        except (OSError, subprocess.SubprocessError):
            return None
        parts = out.split()
        token = parts[0] if parts else ''
        head = token.split('.', 1)[0]
        return head if head.isdigit() else None

    majors = [sdk_major(directory) for directory in paths]
    try:
        good = majors.index('10')
    except ValueError:
        return paths
    blocked = {index for index, major in enumerate(majors[:good]) if major not in (None, '10')}
    if not blocked:
        return paths
    moved = [directory for index, directory in enumerate(paths) if index in blocked]
    kept_indexes = [index for index in range(len(paths)) if index not in blocked]
    kept = [paths[index] for index in kept_indexes]
    at = next(position for position, index in enumerate(kept_indexes) if majors[index] == '10') + 1
    return kept[:at] + moved + kept[at:]
'''


def fail(message):
    print(f'prepare_distributable_script: {message}', file=sys.stderr)
    raise SystemExit(1)


def prepare(path):
    script = Path(path)
    if script.name != 'build_ipa_from_nsp.py' or script.parent.name != 'scripts':
        fail(f'refusing an unexpected script path: {script}')
    root = script.parent.parent
    if (root / '.git').exists():
        fail(f'refusing to modify a git checkout: {root}')
    try:
        text = script.read_text(encoding='utf-8')
    except OSError as error:
        fail(f'cannot read {script}: {error}')
    if not text.startswith('#!/usr/bin/env python3\n'):
        fail('the script does not start with the expected Python shebang')
    if '\r\n' in text or '\r' in text:
        fail('the script does not use Unix line endings')

    tool_line = ORIGINAL_TOOL.rstrip('\n')
    original_env_line = ORIGINAL_ENV.rstrip('\n')
    patched_env_line = PATCHED_ENV.rstrip('\n')
    lines = text.splitlines()
    tool_count = lines.count(tool_line)
    original_env_count = lines.count(original_env_line)
    patched_env_count = lines.count(patched_env_line)
    marker_count = text.count(MARKER)
    if marker_count == 1 and original_env_count == 0 and patched_env_count == 1 and tool_count == 1:
        return False
    if marker_count or patched_env_count or original_env_count != 1 or tool_count != 1:
        fail('the PATH lines are not the expected nxnative text; the copy was left unchanged')
    if 'subprocess' not in text or 'os.pathsep' not in text:
        fail('the script does not import the modules the PATH change uses')

    updated_lines = []
    for line in lines:
        if line == tool_line:
            updated_lines.append(tool_line)
            updated_lines.append('')
            updated_lines.extend(FUNCTION.rstrip('\n').splitlines())
            updated_lines.append('')
        elif line == original_env_line:
            updated_lines.append(patched_env_line)
        else:
            updated_lines.append(line)
    updated = '\n'.join(updated_lines) + '\n'
    if updated.count(MARKER) != 1 or updated.splitlines().count(patched_env_line) != 1 or original_env_line in updated.splitlines():
        fail('the prepared text is not unique; the copy was left unchanged')
    temporary = script.with_name(script.name + '.snative-tmp')
    try:
        temporary.write_text(updated, encoding='utf-8')
        os.replace(temporary, script)
    except OSError as error:
        fail(f'cannot write {script}: {error}')
    return True


def main(argv):
    if len(argv) != 2:
        fail('usage: prepare_distributable_script.py <copy of scripts/build_ipa_from_nsp.py>')
    prepare(argv[1])


if __name__ == '__main__':
    main(sys.argv)
