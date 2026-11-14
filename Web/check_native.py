"""Exercise the Web adapter over real HTTP on native Godot, not as a WebGL claim."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import argparse
import subprocess
import threading
import re
import json

parser=argparse.ArgumentParser();parser.add_argument('--godot',required=True);args=parser.parse_args()
root=Path(__file__).resolve().parents[1]
server=ThreadingHTTPServer(('127.0.0.1',0),partial(SimpleHTTPRequestHandler,directory=str(root/'builds/web-dist')))
threading.Thread(target=server.serve_forever,daemon=True).start()
command=[args.godot,'--headless','--path',str(root/'builds/web-source'),'--audio-driver','Dummy','--','--qa',
         '--media-base=http://127.0.0.1:'+str(server.server_port)+'/']
try:
    result=subprocess.run(command,capture_output=True,text=True,timeout=180)
    (root/'builds/logs/web-prototype-qa.log').write_text(result.stdout+result.stderr)
    output=result.stdout+result.stderr
    marker=output.find('WEB_PROTOTYPE_CHECKS_PASSED')
    unexpected=[m.group() for m in re.finditer(r'^ERROR:.*$',output,re.M)
                if not (m.start()>marker>=0 and re.fullmatch(r'ERROR: [248] resources still in use at exit \(run with --verbose for details\)\.',m.group()))]
    if result.returncode or 'SCRIPT ERROR' in output or 'Assertion failed' in output or marker<0 or unexpected:
        print(output)
        raise SystemExit('Web adapter HTTP conformance failed')
    print('\n'.join(line for line in output.splitlines() if 'PASSED' in line))
    print('TEARDOWN_DIAGNOSTICS',json.dumps(re.findall(r'^ERROR:.*$',output,re.M)))
finally: server.shutdown()
