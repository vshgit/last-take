#!/usr/bin/env python3
"""Validate the recovered baseline and all question media without Godot or network."""
import collections
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main():
    failures = []
    manifest = json.loads((ROOT / 'docs/ORIGINAL_FILES.json').read_text())
    verified = 0
    for item in manifest:
        if item['status'] == 'preserved_in_original_windows_zip':
            continue
        path = ROOT / item['path']
        if not path.is_file():
            failures.append('Missing original: ' + item['path'])
        elif hashlib.sha256(path.read_bytes()).hexdigest() != item.get('public_sha256', item['sha256']):
            failures.append('Changed original: ' + item['path'])
        else:
            verified += 1
    source = ROOT / 'Source'
    data = json.loads((source / 'content.json').read_text())
    questions = data['questions']
    ids = [q['id'] for q in questions]
    if len(ids) != 216 or len(set(ids)) != 216:
        failures.append('Expected 216 unique question IDs')
    levels = collections.Counter(int(q['level']) for q in questions)
    kinds = collections.Counter(q['type'] for q in questions)
    if levels != {1: 66, 2: 77, 3: 73}:
        failures.append('Unexpected level counts: ' + str(levels))
    if kinds != {'cards': 94, 'gesture': 37, 'frame': 69, 'audio': 16}:
        failures.append('Unexpected question type counts: ' + str(kinds))
    voice_meta = json.loads((source / 'assets/audio/voice_meta.json').read_text())
    checked_media = set()

    def media(relative):
        if not isinstance(relative, str) or not relative:
            failures.append('Invalid media path: ' + repr(relative))
            return
        relative = relative.removeprefix('res://')
        checked_media.add(relative)
        if not (source / relative).is_file():
            failures.append('Missing media: ' + relative)

    for q in questions:
        media('assets/audio/' + q['voice_id'] + '.ogg')
        if q['voice_id'] not in voice_meta:
            failures.append('Missing voice metadata: ' + q['id'])
        if q['type'] in ('cards', 'frame', 'audio'):
            if len(q['options']) != 3 or not 0 <= int(q['correct']) < 3:
                failures.append('Invalid options/answer: ' + q['id'])
            for i in range(len(q['options'])):
                media('assets/cards/q%02d_%d.jpg' % (int(q['asset_index']), i))
        if q['type'] == 'frame':
            media(q['image'])
        if q['type'] == 'audio':
            media(q['audio'])
    for message in failures:
        print('FAIL:', message)
    print(json.dumps({'original_files_verified': verified, 'questions': len(ids),
                      'levels': dict(levels), 'types': dict(kinds),
                      'distinct_media_paths_checked': len(checked_media),
                      'failures': len(failures)}, ensure_ascii=False))
    return 1 if failures else 0


if __name__ == '__main__':
    raise SystemExit(main())
