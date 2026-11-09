"""Pinned Windows build. No asset generators; output stays outside Source."""
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'builds'
VERSION = '4.5.1'
BASE = 'https://github.com/godotengine/godot-builds/releases/download/4.5.1-stable/'
EDITOR = 'Godot_v4.5.1-stable_linux.x86_64.zip'
TEMPLATES = 'Godot_v4.5.1-stable_export_templates.tpz'
HASHES = {
    EDITOR: '02ec53d1cc7dbb9cc6355393c61b9ab43d1244751a124f10248a4802830788cd',
    TEMPLATES: '1998af37f1387684e2c211cdb483daf492fc64dc6b12096bddcdca25b6910c86',
}
MARKERS = ('V1_CHECKS_PASSED', 'SOUNDS_CHECKS_PASSED', 'GESTURE_REPLAYS_PASSED',
           'GESTURE_INPUT_CHECKS_PASSED', 'V09_CHECKS_PASSED', 'GAMEPLAY_CHECKS_PASSED')
TEARDOWN = []


def validate_log(text, returncode, required=()):
    if returncode:
        raise RuntimeError('Process returned exit code %s' % returncode)
    if re.search(r'SCRIPT ERROR|Assertion failed|Parse Error', text, re.MULTILINE):
        raise RuntimeError('Godot reported an error; inspect the saved log')
    missing = [m for m in required if not re.search(r'^' + re.escape(m) + r'\b', text, re.MULTILINE)]
    if missing:
        raise RuntimeError('Missing QA markers: ' + ', '.join(missing))
    diagnostics = []
    completed_at = max((text.find(m) + len(m) for m in required), default=len(text))
    for match in re.finditer(r'^ERROR:.*$', text, re.MULTILINE):
        line = match.group().strip()
        # Historical QA teardown diagnostics are retained, never broadly suppress ERROR.
        known = re.fullmatch(r'ERROR: \d+ resources still in use at exit \(run with --verbose for details\)\.', line)
        if not (known and tuple(required) == MARKERS and match.start() > completed_at):
            raise RuntimeError('Godot reported an error; inspect the saved log')
        diagnostics.append(line)
    return diagnostics


def run(command, name, timeout=600, required=()):
    log = OUT / 'logs' / (name + '.log')
    log.parent.mkdir(parents=True, exist_ok=True)
    print('Running ' + name, flush=True)
    with log.open('w', encoding='utf-8') as stream:
        try:
            result = subprocess.run([str(v) for v in command], cwd=ROOT, stdout=stream,
                                    stderr=subprocess.STDOUT, timeout=timeout)
        except subprocess.TimeoutExpired as error:
            raise RuntimeError(name + ' timed out') from error
    text = log.read_text(encoding='utf-8', errors='replace')
    try:
        diagnostics = validate_log(text, result.returncode, required)
    except RuntimeError:
        print(text[-10000:])
        raise
    print(name + ': passed', flush=True)
    for diagnostic in diagnostics:
        TEARDOWN.append(name + ': ' + diagnostic)
        print('Teardown diagnostic (recorded separately): ' + diagnostic, flush=True)


def target():
    config = json.loads((ROOT / '.github/build-target.json').read_text(encoding='utf-8'))
    if config['platform'] != 'windows':
        raise RuntimeError('Windows build disabled for target %s. Configure and test its own pipeline; do not substitute EXE.' % config['platform'])
    return config


def download(name):
    destination = OUT / 'tools' / name
    destination.parent.mkdir(parents=True, exist_ok=True)
    print('Downloading official ' + name, flush=True)
    digest = hashlib.sha256()
    with urllib.request.urlopen(BASE + name, timeout=180) as response, destination.open('wb') as stream:
        while block := response.read(8 * 1024 * 1024):
            stream.write(block)
            digest.update(block)
    if digest.hexdigest() != HASHES[name]:
        destination.unlink()
        raise RuntimeError('Official download SHA-256 mismatch: ' + name)
    return destination


def install():
    target()
    if sys.platform != 'linux':
        raise RuntimeError('Run the Godot editor/export stage on the Linux build runner')
    editor_dir = OUT / 'tools' / 'editor'
    with zipfile.ZipFile(download(EDITOR)) as archive:
        archive.extractall(editor_dir)
    (editor_dir / 'Godot_v4.5.1-stable_linux.x86_64').chmod(0o755)
    template_dir = Path(os.environ.get('XDG_DATA_HOME', str(Path.home() / '.local/share'))) / 'godot/export_templates/4.5.1.stable'
    template_dir.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(download(TEMPLATES)) as archive:
        for name in ('windows_release_x86_64.exe', 'windows_debug_x86_64.exe'):
            with archive.open('templates/' + name) as source, (template_dir / name).open('wb') as dest:
                shutil.copyfileobj(source, dest)
    # Do not retain the 1.3 GB multi-platform download after extracting Windows.
    (OUT / 'tools' / TEMPLATES).unlink()
    print('Godot ' + VERSION + ' and Windows templates verified and installed')


def build():
    config = target()
    editor = OUT / 'tools/editor/Godot_v4.5.1-stable_linux.x86_64'
    version = subprocess.check_output([str(editor), '--version'], text=True).strip()
    if not version.startswith(VERSION + '.stable.'):
        raise RuntimeError('Unexpected engine version: ' + version)
    run([editor, '--headless', '--editor', '--path', ROOT / 'Source', '--import'], 'import')
    run([editor, '--headless', '--path', ROOT / 'Source', '--audio-driver', 'Dummy', '--', '--qa'],
        'gameplay', required=MARKERS)
    package = OUT / 'LastTake-Windows'
    package.mkdir(parents=True, exist_ok=True)
    exe = package / 'LastTake.exe'
    run([editor, '--headless', '--path', ROOT / 'Source', '--export-release', 'Windows Desktop', exe], 'export')
    if not exe.is_file() or exe.stat().st_size < 1024 * 1024:
        raise RuntimeError('Windows export missing or unexpectedly small')
    sha = os.environ.get('GITHUB_SHA') or subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    run_id = os.environ.get('GITHUB_RUN_ID', 'local')
    attempt = os.environ.get('GITHUB_RUN_ATTEMPT', '1')
    repo = os.environ.get('GITHUB_REPOSITORY', 'vshgit/last-take')
    tag = 'test-%s-%s-%s' % (run_id, attempt, sha[:8])
    info = {'source_commit': sha, 'branch': os.environ.get('GITHUB_REF_NAME', 'local'),
            'engine': version, 'platform': 'windows-x86_64', 'preview_tag': tag,
            'workflow_run': 'https://github.com/%s/actions/runs/%s' % (repo, run_id),
            'automatic_checks': ['content', 'editor-import', 'editor-gameplay', 'export'],
            'teardown_diagnostics': list(TEARDOWN),
            'manual_acceptance': 'pending', 'manual_checks': config['manual_checks']}
    (package / 'BUILD-INFO.json').write_text(json.dumps(info, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    instructions = ['Last Take — тестовая сборка', 'Сборка: ' + tag, 'Commit: ' + sha, '',
                    'Проверка человеком ещё не выполнена.', '', *config['manual_checks']]
    (package / 'ПРОВЕРКА.txt').write_text('\n'.join(instructions) + '\n', encoding='utf-8-sig')
    shutil.copy2(ROOT / 'Launch-Compatibility.cmd', package)
    artifact_name = 'LastTake-Windows-' + tag + '.zip'
    (OUT / 'build.json').write_text(json.dumps({**info, 'zip': artifact_name}, indent=2) + '\n', encoding='utf-8')
    print('Export ready for native Windows verification')


def finish():
    if sys.platform != 'win32':
        raise RuntimeError('Native EXE smoke must run on Windows')
    info = json.loads((OUT / 'build.json').read_text(encoding='utf-8'))
    package = OUT / 'LastTake-Windows'
    # Release templates omit assertions; editor QA on Linux checked them before export.
    # This verifies the actual exported executable and PCK on native Windows.
    run([package / 'LastTake.exe', '--headless', '--audio-driver', 'Dummy', '--', '--qa'],
        'exported-smoke', required=MARKERS)
    info['automatic_checks'].append('native-windows-exported-smoke')
    info['teardown_diagnostics'].extend(TEARDOWN)
    (package / 'BUILD-INFO.json').write_text(json.dumps(info, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    artifact = OUT / info['zip']
    with zipfile.ZipFile(artifact, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for path in sorted(package.iterdir()):
            archive.write(path, 'LastTake-Windows/' + path.name)
    checksum = hashlib.sha256(artifact.read_bytes()).hexdigest()
    (OUT / 'SHA256SUMS.txt').write_text(checksum + '  ' + artifact.name + '\n', encoding='ascii')
    (OUT / 'build.json').write_text(json.dumps({**info, 'zip': artifact.name, 'sha256': checksum}, indent=2) + '\n', encoding='utf-8')
    print('Packaged ' + artifact.name)


if __name__ == '__main__':
    {'target': target, 'install': install, 'build': build, 'finish': finish}[sys.argv[1]]()
