"""Run the shared event scenarios against the untouched Windows game."""
from pathlib import Path
import subprocess
import argparse
import re

root=Path(__file__).resolve().parents[1];parser=argparse.ArgumentParser();parser.add_argument('--godot',required=True);args=parser.parse_args()
r=subprocess.run([args.godot,'--headless','--path',str(root/'Source'),'--audio-driver','Dummy','--script',str(root/'Shared/native_runner.gd'),'--','--scenarios='+str(root/'Shared/scenarios.json')],capture_output=True,text=True,timeout=120)
text=r.stdout+r.stderr;(root/'builds/logs/shared-native.log').write_text(text)
marker=text.find('SHARED_RULES_PASSED')
errors=[m.group() for m in re.finditer(r'^ERROR:.*$',text,re.M) if not(m.start()>marker>=0 and m.group()=='ERROR: 2 resources still in use at exit (run with --verbose for details).')]
if r.returncode or marker<0 or 'SCRIPT ERROR' in text or 'Assertion failed' in text or errors:
    print(text);raise SystemExit('Native shared contract failed')
print('\n'.join(line for line in text.splitlines() if 'PASSED' in line))
print('TEARDOWN_DIAGNOSTICS',re.findall(r'^ERROR:.*$',text,re.M))
