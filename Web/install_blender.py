"""Install the pinned official build used to create reproducible derivative models."""
from pathlib import Path
import hashlib
import tarfile
import urllib.request

out=Path(__file__).resolve().parents[1]/'builds/tools';out.mkdir(parents=True,exist_ok=True)
name='blender-4.3.2-linux-x64.tar.xz'
path=out/name
with urllib.request.urlopen('https://download.blender.org/release/Blender4.3/'+name,timeout=180) as r,path.open('wb') as f:
    while block:=r.read(8*1024*1024): f.write(block)
assert hashlib.sha256(path.read_bytes()).hexdigest()=='4da1c956673c0485e63054e563ee69198cc8f80d8157dd7592dffc8a6a5592e6'
with tarfile.open(path) as tar: tar.extractall(out,filter='data')
path.unlink()
print(out/'blender-4.3.2-linux-x64/blender')
