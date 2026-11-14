"""Godot 4.5.1 Web preview; preserve native renderer and all source assets."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import sys
import zipfile
import build_windows as common

ROOT = common.ROOT
OUT = common.OUT
EDITOR = OUT / 'tools/editor/Godot_v4.5.1-stable_linux.x86_64'


def install():
    with zipfile.ZipFile(common.download(common.EDITOR)) as archive:
        archive.extractall(EDITOR.parent)
    EDITOR.chmod(0o755)
    destination = Path.home() / '.local/share/godot/export_templates/4.5.1.stable'
    destination.mkdir(parents=True, exist_ok=True)
    templates = common.download(common.TEMPLATES)
    with zipfile.ZipFile(templates) as archive:
        for name in ('web_nothreads_debug.zip', 'web_nothreads_release.zip'):
            (destination / name).write_bytes(archive.read('templates/' + name))
    templates.unlink()


def package(source_commit=None):
    """Split large engine/pack files transparently for static hosting file limits."""
    export = OUT / 'web'
    dist = OUT / 'web-dist'
    if dist.exists():
        shutil.rmtree(dist)
    dist.mkdir(parents=True)
    manifest = {}
    for name in ('index.wasm', 'index.pck'):
        path = export / name
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        chunks = []
        with path.open('rb') as stream:
            while chunk := stream.read(16 * 1024 * 1024):
                filename = '%s-%s-%02d.bin' % (name, digest[:12], len(chunks))
                (dist / filename).write_bytes(chunk)
                chunks.append(filename)
        manifest[name] = {'size': path.stat().st_size, 'sha256': digest, 'chunks': chunks}
    for path in export.glob('*.js'):
        shutil.copyfile(path, dist / path.name)
    shell = (ROOT / 'tools/ci/web_shell.html').read_text(encoding='utf-8')
    (dist / 'index.html').write_text(shell, encoding='utf-8')
    (dist / 'pack-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    info = {'platform': 'web', 'engine': '4.5.1', 'source_commit': source_commit,
            'branch': os.environ.get('GITHUB_REF_NAME', 'work/audio-bank-web'),
            'workflow_run': ('https://github.com/%s/actions/runs/%s' %
                             (os.environ.get('GITHUB_REPOSITORY', 'vshgit/last-take'),
                              os.environ.get('GITHUB_RUN_ID', 'local'))),
            'manual_acceptance': 'ждёт проверки Дмитрия', 'files': manifest}
    (dist / 'BUILD-INFO.json').write_text(json.dumps(info, ensure_ascii=False, indent=2) + '\n')
    print('WEB_PACKAGE_READY', json.dumps({k: v['size'] for k, v in manifest.items()}))
    return dist


def build():
    if json.loads((ROOT / '.github/build-target.json').read_text())['platform'] != 'web':
        raise RuntimeError('Web is not the selected task target')
    common.run([EDITOR, '--headless', '--editor', '--path', ROOT / 'Source', '--import'], 'web-import')
    common.run([EDITOR, '--headless', '--path', ROOT / 'Source', '--audio-driver', 'Dummy', '--', '--qa'],
               'web-gameplay', required=common.MARKERS)
    export = OUT / 'web'
    export.mkdir(parents=True, exist_ok=True)
    common.run([EDITOR, '--headless', '--path', ROOT / 'Source', '--export-release', 'Web', export / 'index.html'], 'web-export')
    dist = package(os.environ['GITHUB_SHA'])
    shutil.make_archive(str(OUT / 'LastTake-Web'), 'zip', dist)


if __name__ == '__main__':
    {'install': install, 'build': build, 'package': lambda: package(os.environ.get('GITHUB_SHA'))}[sys.argv[1]]()
