"""Publish CI output using the runner's short-lived token, and persist its status."""
import base64
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import urllib.parse

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'builds'


def gh(*args, payload=None):
    result = subprocess.run(['gh', *args], input=None if payload is None else json.dumps(payload),
                            text=True, encoding='utf-8', stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE, check=False)
    if result.returncode:
        raise RuntimeError('GitHub CLI operation failed: ' + result.stderr.strip())
    return result.stdout


def api(path, payload=None):
    args = ['api', path]
    if payload is not None:
        args += ['--method', 'PUT', '--input', '-']
    return json.loads(gh(*args, payload=payload))


def record_status(success, release_url=None):
    repo, branch, source = (os.environ[k] for k in ('GITHUB_REPOSITORY', 'GITHUB_REF_NAME', 'GITHUB_SHA'))
    endpoint = 'repos/%s' % repo
    ref = api(endpoint + '/git/ref/heads/' + urllib.parse.quote(branch, safe=''))
    if ref['object']['sha'] != source:
        print('Branch moved; keeping the newer task status. This build remains linked in its release/run.')
        return
    path = '/contents/docs/STATUS.md'
    current = api(endpoint + path + '?ref=' + urllib.parse.quote(branch, safe=''))
    text = base64.b64decode(current['content']).decode('utf-8')
    run_url = 'https://github.com/%s/actions/runs/%s' % (repo, os.environ['GITHUB_RUN_ID'])
    block = '\n'.join([
        '<!-- ci-preview:start -->', '## Последняя автоматическая попытка Windows', '',
        '- Исходный commit: `' + source + '`.', '- Ветка: `' + branch + '`.',
        '- Проверки и журнал: ' + run_url + '.',
        '- Статус: ' + ('автопроверки и сборка прошли; **ждёт проверки Дмитрия**.' if success else '**автоматическая сборка не завершена; нужна диагностика агента**.'),
        '- Проверочная публикация: ' + (release_url or 'не выдана') + '.',
        '- Эта запись не является ручной приёмкой и не закрывает продуктовую задачу.',
        '<!-- ci-preview:end -->',
    ])
    pattern = r'<!-- ci-preview:start -->.*?<!-- ci-preview:end -->'
    text = re.sub(pattern, lambda _: block, text, flags=re.DOTALL) if re.search(pattern, text, re.DOTALL) else text.rstrip() + '\n\n' + block + '\n'
    api(endpoint + path, {'message': 'docs: record Windows CI result for ' + source[:8],
                         'branch': branch, 'sha': current['sha'],
                         'content': base64.b64encode(text.encode('utf-8')).decode('ascii')})
    print('Saved build result in docs/STATUS.md on ' + branch)


def publish():
    repo = os.environ['GITHUB_REPOSITORY']
    info = json.loads((OUT / 'build.json').read_text(encoding='utf-8'))
    if info['source_commit'] != os.environ['GITHUB_SHA']:
        raise RuntimeError('Refusing to publish a build of a different commit')
    tag, sha = info['preview_tag'], info['source_commit']
    notes = OUT / 'release-notes.md'
    notes.write_text('\n'.join([
        'Тестовая Windows-сборка. **Ждёт проверки Дмитрия.**', '',
        'Ветка: `' + info['branch'] + '`. Исходный commit: `' + sha + '`.',
        'Godot: `' + info['engine'] + '`. [Автопроверки и журнал](' + info['workflow_run'] + ').', '',
        'Скачать ZIP, распаковать и запустить `LastTake.exe`. Внутри есть `BUILD-INFO.json` и инструкция.', '',
        *['- ' + line for line in info['manual_checks']], '',
        'Headless-проверки не подтверждают внешний вид, слышимость и управление на реальном компьютере.',
        '', 'Диагностика завершения Godot (отдельно от результатов игровых проверок):',
        *(['- ' + line for line in info.get('teardown_diagnostics', [])] or ['- Не зарегистрирована.']),
    ]) + '\n', encoding='utf-8')
    gh('release', 'create', tag, str(OUT / info['zip']), str(OUT / 'build.json'), str(OUT / 'SHA256SUMS.txt'),
       '--repo', repo, '--target', sha, '--prerelease', '--latest=false',
       '--title', 'Windows — проверка %s (%s)' % (os.environ['GITHUB_RUN_NUMBER'], sha[:8]),
       '--notes-file', str(notes))
    published = api('repos/%s/releases/tags/%s' % (repo, tag))
    asset = next(a for a in published['assets'] if a['name'] == info['zip'])
    if published['draft'] or not published['prerelease'] or asset['state'] != 'uploaded':
        raise RuntimeError('Preview publication is incomplete')
    if asset['size'] != (OUT / info['zip']).stat().st_size:
        raise RuntimeError('Published ZIP size mismatch')
    if asset.get('digest') and asset['digest'] != 'sha256:' + info['sha256']:
        raise RuntimeError('Published ZIP checksum mismatch')
    url = published['html_url']
    summary = os.environ.get('GITHUB_STEP_SUMMARY')
    if summary:
        with open(summary, 'a', encoding='utf-8') as stream:
            stream.write('## Готово к проверке Дмитрием\n\n[Скачать Windows-сборку](' + url + ')\n\nCommit: `' + sha + '`\n')
    print('Published and verified: ' + url)
    record_status(True, url)


if __name__ == '__main__':
    if sys.argv[1:] == ['failed']:
        record_status(False)
    else:
        publish()
