"""Promote an explicitly accepted preview; never silently rebuild tested binaries."""
import hashlib
import json
import os
from pathlib import Path
import re

from publish_preview import ROOT, OUT, api, gh


def validate_request(request):
    if not re.fullmatch(r'v\d+\.\d+\.\d+', request['version'] or ''):
        raise ValueError('Release version must be vMAJOR.MINOR.PATCH')
    if not request.get('accepted_by'):
        raise ValueError('Record who explicitly accepted this build')
    if not re.fullmatch(r'[0-9a-f]{40}', request['source_commit'] or ''):
        raise ValueError('An exact accepted source commit is required')
    if not re.fullmatch(r'test-\d+-\d+-[0-9a-f]{8}', request['preview_tag'] or ''):
        raise ValueError('Select a preview produced by Windows CI')


def source_fingerprints(repo, sha):
    tree = api('repos/%s/git/trees/%s' % (repo, sha))['tree']
    names = ('Source', 'Launch-Compatibility.cmd')
    result = {x['path']: x['sha'] for x in tree if x['path'] in names}
    if set(result) != set(names):
        raise RuntimeError('Game source tree or compatibility launcher is missing')
    return result


def main():
    request = json.loads((ROOT / '.github/release-request.json').read_text(encoding='utf-8'))
    if request['version'] is None:
        print('No accepted release requested; nothing published.')
        return
    validate_request(request)
    if os.environ['GITHUB_REF_NAME'] != 'main':
        raise RuntimeError('Accepted releases can only be published from main')
    repo, current = os.environ['GITHUB_REPOSITORY'], os.environ['GITHUB_SHA']
    if source_fingerprints(repo, current) != source_fingerprints(repo, request['source_commit']):
        raise RuntimeError('Game files differ from the accepted preview; build and test again')
    # A repeated request for an existing version must be inspected, never overwritten.
    preview = api('repos/%s/releases/tags/%s' % (repo, request['preview_tag']))
    if preview['draft'] or not preview['prerelease']:
        raise RuntimeError('The requested preview is not a published pre-release')
    target = OUT / 'accepted'
    target.mkdir(parents=True, exist_ok=True)
    gh('release', 'download', request['preview_tag'], '--repo', repo, '--dir', str(target),
       '--pattern', 'build.json', '--pattern', 'LastTake-Windows-*.zip', '--pattern', 'SHA256SUMS.txt')
    info = json.loads((target / 'build.json').read_text(encoding='utf-8'))
    if info['source_commit'] != request['source_commit'] or info['preview_tag'] != request['preview_tag']:
        raise RuntimeError('Preview provenance does not match the accepted request')
    if info['platform'] != 'windows-x86_64':
        raise RuntimeError('Only Windows publication is implemented here')
    filename = info['zip']
    if Path(filename).name != filename or not re.fullmatch(r'LastTake-Windows-test-[\w-]+\.zip', filename):
        raise RuntimeError('Invalid preview asset name')
    artifact = target / filename
    digest = hashlib.sha256(artifact.read_bytes()).hexdigest()
    if digest != info['sha256']:
        raise RuntimeError('Preview ZIP checksum mismatch')
    acceptance = {**request, 'published_from_commit': current, 'sha256': digest,
                  'method': 'the exact accepted preview ZIP, not rebuilt'}
    (target / 'ACCEPTANCE.json').write_text(json.dumps(acceptance, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    notes = target / 'notes.md'
    notes.write_text('Принятая Windows-сборка ' + request['version'] + '.\n\n'
                     'Приёмка: ' + request['accepted_by'] + '.\n\n'
                     'Исходный commit сборки: `' + request['source_commit'] + '`.\n\n'
                     'Опубликован тот же ZIP, который проверял пользователь; повторной сборки не было.\n', encoding='utf-8')
    gh('release', 'create', request['version'], str(artifact), str(target / 'build.json'),
       str(target / 'SHA256SUMS.txt'), str(target / 'ACCEPTANCE.json'),
       '--repo', repo, '--target', current, '--latest', '--title', 'Last Take ' + request['version'] + ' — Windows',
       '--notes-file', str(notes))
    published = api('repos/%s/releases/tags/%s' % (repo, request['version']))
    asset = next(a for a in published['assets'] if a['name'] == filename)
    if published['draft'] or published['prerelease'] or asset['size'] != artifact.stat().st_size:
        raise RuntimeError('Accepted release publication is incomplete')
    if asset.get('digest') and asset['digest'] != 'sha256:' + digest:
        raise RuntimeError('Accepted release checksum mismatch')
    print('Published and verified: ' + published['html_url'])


if __name__ == '__main__':
    main()
