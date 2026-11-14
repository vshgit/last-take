"""Publish a uniquely identified test archive, verify GitHub's uploaded asset metadata."""
from pathlib import Path
import hashlib
import json
import os
import subprocess

root=Path(__file__).resolve().parents[1];out=root/'builds';repo=os.environ['GITHUB_REPOSITORY'];sha=os.environ['GITHUB_SHA']
tag='web-prototype-'+os.environ['GITHUB_RUN_ID']+'-'+os.environ['GITHUB_RUN_ATTEMPT']+'-'+sha[:8]
archive=out/'LastTake-Web-prototype.zip';digest=hashlib.sha256(archive.read_bytes()).hexdigest()
(out/'SHA256SUMS.txt').write_text(digest+'  '+archive.name+'\n')
notes=out/'web-release-notes.md';notes.write_text('''Проверочный Web-прототип, не принятый порт. Windows Source не изменён.

Source: `'''+sha+'`. Godot 4.5.1, Blender 4.3.2.\n\n'+'''Начальная сцена и динамический текст включены в PCK; речь вопросов, изображения и пользовательские аудиофрагменты подгружаются по запросу текущего и двух следующих вопросов. Банк и правила — из существующего Source.

Native HTTP-проверки не доказывают WebGL/FPS/слышимость на компьютере пользователя. Ссылка Pages при доступной настройке появится в следующем job. Архив нужно разместить по HTTP(S), двойной щелчок по HTML не запускает игру.

ZIP SHA-256: `'''+digest+'`.\n')
subprocess.run(['gh','release','create',tag,str(archive),str(out/'web-dist/BUILD-INFO.json'),str(out/'SHA256SUMS.txt'),
                '--repo',repo,'--target',sha,'--title','Web-прототип — '+sha[:8],'--notes-file',str(notes),'--prerelease','--latest=false'],check=True)
r=json.loads(subprocess.check_output(['gh','api','repos/'+repo+'/releases/tags/'+tag],text=True))
asset=next(a for a in r['assets'] if a['name']==archive.name)
assert asset['state']=='uploaded' and asset['size']==archive.stat().st_size and asset['digest']=='sha256:'+digest
print('WEB_RELEASE_VERIFIED',r['html_url'])
with open(os.environ['GITHUB_OUTPUT'],'a') as f: f.write('release_url='+r['html_url']+'\n')
