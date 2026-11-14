"""Validate actual PCK contents and every deferred media file, with shared source hashes."""
import hashlib
import json
from pathlib import Path
import struct
import subprocess

root=Path(__file__).resolve().parents[1];out=root/'builds';dist=out/'web-dist'
info=json.loads((dist/'BUILD-INFO.json').read_text())
base_info=json.loads((root/'Web/BASE.json').read_text())
assert subprocess.check_output(['git','rev-parse','HEAD:Source'],cwd=root,text=True).strip()==base_info['source_tree'], 'Windows Source tree changed; review the prototype base'
manifest=json.loads((dist/'media-manifest.json').read_text())
assert info['bank_sha256']==hashlib.sha256((root/'Source/content.json').read_bytes()).hexdigest()==manifest['bank_sha256']
rules=json.loads((root/'Shared/rules.json').read_text());bank=json.loads((root/'Source/content.json').read_text())
assert bank['session_rules']['mixes']==rules['level_mixes']
assert rules['lives']==bank['session_rules']['lives']==3
assert rules['session_size']==rules['levels']*rules['questions_per_level']==21
for path,e in manifest['assets'].items():
    content=(dist/e['file']).read_bytes()
    assert len(content)==e['bytes'] and hashlib.sha256(content).hexdigest()==e['sha256'],path
data=next(dist.glob('*.pck')).read_bytes();assert data[:4]==b'GDPC'
version,=struct.unpack_from('<I',data,4);assert version==3
base,directory=struct.unpack_from('<QQ',data,24);count,=struct.unpack_from('<I',data,directory);pos=directory+4
names=[]
for _ in range(count):
    size,=struct.unpack_from('<I',data,pos);pos+=4
    name=data[pos:pos+size].rstrip(b'\0').decode();pos+=size
    offset,length=struct.unpack_from('<QQ',data,pos);pos+=16
    md5=data[pos:pos+16];pos+=16
    flags,=struct.unpack_from('<I',data,pos);pos+=4
    assert not flags and hashlib.md5(data[base+offset:base+offset+length]).digest()==md5,name
    assert not name.startswith('assets/cards/'),name
    assert not (name.startswith('assets/projection/text/') and name not in ['assets/projection/text/blank.jpg.import']),name
    names.append(name)
assert not any(name in names for name in ['assets/character/cinemaniac.glb.import','assets/character/cinemaniac_v09.glb.import'])
proof=json.loads((out/'web-source-proof.json').read_text())
assert all(hashlib.sha256((root/'Source'/path).read_bytes()).hexdigest()==sha for path,sha in proof['source_files'].items())
assert info['initial_file_bytes']<30_000_000,'Initial payload budget exceeded'
print('WEB_PACKAGE_CHECKS_PASSED',json.dumps({'pck_entries':count,'bank_questions':len(bank['questions']),
    'deferred_assets':len(manifest['assets']),'initial_file_bytes':info['initial_file_bytes'],'Source_unchanged':True}))
