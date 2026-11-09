"""Check the current question bank, independently of historical file hashes."""
import collections
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def check(root=ROOT):
    source = root / 'Source'
    questions = json.loads((source / 'content.json').read_text(encoding='utf-8'))['questions']
    voices = json.loads((source / 'assets/audio/voice_meta.json').read_text(encoding='utf-8'))
    ids = [q['id'] for q in questions]
    if len(ids) != 216 or len(set(ids)) != 216:
        raise ValueError('Expected 216 unique question IDs')
    if collections.Counter(int(q['level']) for q in questions) != {1: 66, 2: 77, 3: 73}:
        raise ValueError('Unexpected level counts; update the test only for an agreed bank change')
    if collections.Counter(q['type'] for q in questions) != {'cards': 94, 'gesture': 37, 'frame': 69, 'audio': 16}:
        raise ValueError('Unexpected question category counts')
    checked = set()

    def media(relative):
        if not isinstance(relative, str) or not relative:
            raise ValueError('Empty media path')
        path = (source / relative.removeprefix('res://')).resolve()
        if not path.is_relative_to(source.resolve()) or not path.is_file():
            raise ValueError('Missing or invalid media: ' + relative)
        checked.add(path)

    for q in questions:
        media('assets/audio/' + q['voice_id'] + '.ogg')
        if q['voice_id'] not in voices:
            raise ValueError('Missing voice metadata: ' + q['id'])
        if q['type'] in ('cards', 'frame', 'audio'):
            if len(q['options']) != 3 or not 0 <= int(q['correct']) < 3:
                raise ValueError('Invalid answer: ' + q['id'])
            for i in range(3):
                media('assets/cards/q%02d_%d.jpg' % (int(q['asset_index']), i))
        if q['type'] == 'frame':
            media(q['image'])
        if q['type'] == 'audio':
            media(q['audio'])
    print(json.dumps({'questions': len(ids), 'media_paths': len(checked), 'result': 'passed'}))


if __name__ == '__main__':
    check()
