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
EDITOR = 'Godot_v4.5.1-stable_win64.exe.zip'
TEMPLATES = 'Godot_v4.5.1-stable_export_templates.tpz'
HASHES = {
    EDITOR: 'defccc78669e644861b4247626b01ae362cd9f23975edf19c8bfd2eb1f6a1783',
    TEMPLATES: '1998af37f1387684e2c211cdb483daf492fc64dc6b12096bddcdca25b6910c86',
}
MARKERS = ('V1_CHECKS_PASSED', 'SOUNDS_CHECKS_PASSED', 'GESTURE_REPLAYS_PASSED',
           'GESTURE_INPUT_CHECKS_PASSED', 'V09_CHECKS_PASSED', 'GAMEPLAY_CHECKS_PASSED')


def validate_log(text, returncode, required=()):
    if returncode:
        raise RuntimeError('Process returned exit code %s' % returncode)
    if re.search(r'SCRIPT ERROR|Assertion failed|Parse Error|^ERROR:', text, re.MULTILINE):
        raise RuntimeError('Godot reported an error; inspect the saved log')
    missing = [m for m in required if not re.search(r'^' + re.escape(m) + r'\b', text, re.MULTILINE)]
    if missing:
        raise RuntimeError('Missing QA markers: ' + ', '.join(missing))


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
        validate_log(text, result.returncode, required)
    except RuntimeError:
        print(text[-10000:])
        raise
    print(name + ': passed', flush=True)


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
    if sys.platform != 'win32':
        raise RuntimeError('Run Windows installation on a Windows runner')
    editor_dir = OUT / 'tools' / 'editor'
    with zipfile.ZipFile(download(EDITOR)) as archive:
        archive.extractall(editor_dir)
    template_dir = Path(os.environ['APPDATA']) / 'Godot/export_templates/4.5.1.stable'
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
    editor = OUT / 'tools/editor/Godot_v4.5.1-stable_win64_console.exe'
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
    # Release templates omit GDScript assertions; gameplay assertions run in the editor above.
    # This separately verifies that the exported PCK contains the runnable game and its media.
    run([exe, '--headless', '--audio-driver', 'Dummy', '--', '--qa'], 'exported-smoke', required=MARKERS)
    sha = os.environ.get('GITHUB_SHA') or subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    run_id = os.environ.get('GITHUB_RUN_ID', 'local')
    attempt = os.environ.get('GITHUB_RUN_ATTEMPT', '1')
    repo = os.environ.get('GITHUB_REPOSITORY', 'vshgit/last-take')
    tag = 'test-%s-%s-%s' % (run_id, attempt, sha[:8])
    info = {'source_commit': sha, 'branch': os.environ.get('GITHUB_REF_NAME', 'local'),
            'engine': version, 'platform': 'windows-x86_64', 'preview_tag': tag,
            'workflow_run': 'https://github.com/%s/actions/runs/%s' % (repo, run_id),
            'automatic_checks': ['content', 'editor-import', 'editor-gameplay', 'export', 'exported-smoke'],
            'manual_acceptance': 'pending', 'manual_checks': config['manual_checks']}
    (package / 'BUILD-INFO.json').write_text(json.dumps(info, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    instructions = ['Last Take — тестовая сборка', 'Сборка: ' + tag, 'Commit: ' + sha, '',
                    'Проверка человеком ещё не выполнена.', '', *config['manual_checks']]
    (package / 'ПРОВЕРКА.txt').write_text('\n'.join(instructions) + '\n', encoding='utf-8-sig')
    shutil.copy2(ROOT / 'Launch-Compatibility.cmd', package)
    artifact = OUT / ('LastTake-Windows-' + tag + '.zip')
    with zipfile.ZipFile(artifact, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for path in sorted(package.iterdir()):
            archive.write(path, 'LastTake-Windows/' + path.name)
    checksum = hashlib.sha256(artifact.read_bytes()).hexdigest()
    (OUT / 'SHA256SUMS.txt').write_text(checksum + '  ' + artifact.name + '\n', encoding='ascii')
    (OUT / 'build.json').write_text(json.dumps({**info, 'zip': artifact.name, 'sha256': checksum}, indent=2) + '\n', encoding='utf-8')
    print('Packaged ' + artifact.name)


if __name__ == '__main__':
    {'target': target, 'install': install, 'build': build}[sys.argv[1]]()
