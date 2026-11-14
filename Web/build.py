"""Reproducible browser staging of the existing Godot project; Source stays untouched."""
import argparse
import gzip
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'builds'
STAGE = OUT / 'web-source'
DIST = OUT / 'web-dist'
sys.path.insert(0, str(ROOT / 'tools/ci'))
import build_windows as common


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def replace_once(text, old, new):
    if text.count(old) != 1:
        raise ValueError('Upstream code changed; review Web hook: '+old[:100])
    return text.replace(old, new, 1)


def install():
    import zipfile
    editor = OUT / 'tools/editor'
    editor.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(common.download(common.EDITOR)) as z:
        z.extractall(editor)
    (editor / 'Godot_v4.5.1-stable_linux.x86_64').chmod(0o755)
    target = Path.home() / '.local/share/godot/export_templates/4.5.1.stable'
    target.mkdir(parents=True, exist_ok=True)
    templates = common.download(common.TEMPLATES)
    with zipfile.ZipFile(templates) as z:
        for name in ['web_nothreads_debug.zip', 'web_nothreads_release.zip']:
            (target / name).write_bytes(z.read('templates/'+name))
    templates.unlink()


def stage(blender):
    original = ROOT / 'Source'
    source_hashes = {str(p.relative_to(original)): digest(p) for p in original.rglob('*')
                     if p.is_file() and '.godot' not in p.parts}
    OUT.mkdir(exist_ok=True)
    if STAGE.exists(): shutil.rmtree(STAGE)
    if DIST.exists(): shutil.rmtree(DIST)
    STAGE.mkdir(); DIST.mkdir()
    for p in original.iterdir():
        if p.suffix in ['.gd', '.gdshader', '.tscn', '.godot']:
            shutil.copyfile(p, STAGE / p.name)
    shutil.copytree(ROOT / 'Web/runtime', STAGE / 'web')
    shutil.copytree(ROOT / 'Shared', STAGE / 'shared')
    # The one editable bank remains in Source until Windows acceptance.
    shutil.copyfile(original / 'content.json', STAGE / 'content.json')
    content = json.loads((original/'content.json').read_text())
    core_voices = {x['id'] for group in ['intro', 'lines'] for x in content[group]}
    assets = STAGE / 'assets'
    for p in original.rglob('*'):
        if not p.is_file() or p.suffix == '.import' or '.godot' in p.parts: continue
        rel = p.relative_to(original)
        s = str(rel)
        keep = (s in ['assets/sans.ttf', 'assets/serif.ttf', 'assets/audio/voice_meta.json']
                or s.startswith('assets/audio/environment/')
                or (s.startswith('assets/audio/') and p.stem in core_voices)
                or s in ['assets/audio/paper.ogg', 'assets/audio/shot.ogg']
                or s.startswith('assets/materials/')
                or s in ['assets/character/villain_skin_cc0.png','assets/character/player_skin_cc0.png',
                         'assets/character/player_skin_cc0_normal.png','assets/character/cinemaniac_skin_normal.jpg']
                or s in ['assets/projection/text/blank.jpg', 'assets/projection/nosferatu.png',
                         'assets/projection/kak_v_kino.png']
                or s.startswith('assets/projection/poster_'))
        if keep:
            dest = STAGE / rel; dest.parent.mkdir(parents=True, exist_ok=True)
            if p.suffix in ['.jpg', '.png']:
                with Image.open(p) as im:
                    im.thumbnail((512,512), Image.Resampling.LANCZOS)
                    im.save(dest)
            else: shutil.copyfile(p, dest)
    # Derive only the active GLBs. Source names/rigs/morphs remain available to GDScript.
    inputs = OUT / 'web-model-inputs'; models = OUT / 'web-models'
    inputs.mkdir(exist_ok=True)
    files = [p for p in original.glob('assets/**/*.glb')
             if p.name not in ['cinemaniac.glb','cinemaniac_v09.glb','projector_v07.glb']]
    model_key = hashlib.sha256((digest(ROOT/'Web/derive_models.py') + ''.join(digest(p) for p in files)).encode()).hexdigest()
    if not (models / 'key.txt').exists() or (models/'key.txt').read_text() != model_key:
        if inputs.exists(): shutil.rmtree(inputs)
        inputs.mkdir()
        for p in files:
            dest = inputs / p.relative_to(original); dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(p, dest)
        common.run([blender,'-b','--python',ROOT/'Web/derive_models.py','--',inputs,models], 'web-model-derivation', timeout=900)
        (models/'key.txt').write_text(model_key)
    for p in models.glob('assets/**/*.glb'):
        dest = STAGE / p.relative_to(models); dest.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(p,dest)

    manifest = {'bank_sha256': digest(original/'content.json'), 'schema': 1, 'questions': {}, 'assets': {}}
    media = DIST/'media'; media.mkdir()
    for q in content['questions']:
        refs = ['res://assets/audio/'+q['voice_id']+'.ogg']
        if q['type']=='frame': refs.append(q['image'])
        if q['type']=='audio': refs.append(q['audio'])
        manifest['questions'][q['id']] = refs
        for ref in refs:
            if ref in manifest['assets']: continue
            p = original / ref.removeprefix('res://'); sha = digest(p)
            name = sha + p.suffix.lower()
            shutil.copyfile(p, media / name)
            manifest['assets'][ref] = {'file':'media/'+name, 'sha256':sha, 'bytes':p.stat().st_size}
    (STAGE/'media-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,separators=(',',':')))
    (DIST/'media-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')

    p=STAGE/'main.gd'; text=p.read_text()
    # Original QA runs on Source; the asynchronous staging uses shared scenarios below.
    text=text[:text.index('func _run_checks() -> void:')]+'''func _run_checks() -> void:
\tawait preload("res://web/checks.gd").run(self)
'''
    text=replace_once(text,'var data: Dictionary','var web_content\nvar data: Dictionary')
    text=replace_once(text,'func _ready() -> void:\n', 'func _ready() -> void:\n\tweb_content = preload("res://web/content_loader.gd").new()\n\tweb_content.g = self\n\tadd_child(web_content)\n')
    text=replace_once(text,'\t_set_menu()\n\tfor arg', '\t_set_menu()\n\tweb_content.configure()\n\tfor arg')
    text=replace_once(text,'\tpreload("res://scene_details.gd").build(self)','\tpreload("res://scene_details.gd").build(self)\n\tweb_content.batch_static_room()')
    text=replace_once(text,'\tvoice.stream = load("res://assets/audio/"+id+".ogg")','\tvoice.stream = web_content.voice_stream(id)')
    text=replace_once(text,'func _begin_question() -> void:\n', 'func _begin_question() -> void:\n\tif not await web_content.prepare_current():\n\t\treturn\n\t_begin_question_ready()\n\nfunc _begin_question_ready() -> void:\n')
    text=replace_once(text,'load("res://assets/cards/q%02d_%d.jpg"%[int(q.asset_index),i])', 'web_content.text_texture(q.options[i],false,i)')
    start=text.index('func _project_question('); end=text.index('func _reset_gesture()',start)
    text=text[:start]+'''func _project_question(q:Dictionary) -> void:
\tvar texture:Texture2D = web_content.projection_texture(q)
\tprojection_material.set_shader_parameter("frame_tex",texture)
\tvar aspect = float(texture.get_width())/texture.get_height()
\tprojection_material.set_shader_parameter("content_scale",Vector2(minf(1,aspect/1.5),minf(1,1.5/aspect)))
\tprojection_material.set_shader_parameter("show_frame",true)
\tdynamics.update(clock);soundscape.slide_click()
'''+text[end:]
    text=replace_once(text,'func _clear_cards() -> void:\n','func _clear_cards() -> void:\n\tif web_content: web_content.clear_textures()\n')
    text=replace_once(text,'func _start(skip: bool = false) -> void:\n','func _start(skip: bool = false) -> void:\n\tweb_content.cancel()\n')
    text=replace_once(text,'func _set_menu() -> void:\n','func _set_menu() -> void:\n\tif web_content: web_content.cancel()\n')
    text=replace_once(text,'func _pause() -> void:\n','func _pause() -> void:\n\tif phase == "loading":\n\t\tweb_content.pause_loading()\n\t\treturn\n')
    text=replace_once(text,'func _resume() -> void:\n','func _resume() -> void:\n\tif phase == "paused" and previous_phase == "loading":\n\t\tweb_content.resume_loading()\n\t\treturn\n')
    text=replace_once(text,'func _process(delta: float) -> void:\n','func _process(delta: float) -> void:\n\tif web_content: web_content.update_metrics(delta)\n\tif phase == "loading": return\n')
    # The adapted asynchronous loader has its own conformance runner; original QA runs on Source separately.
    text=text[:text.index('func _run_checks() -> void:')]+'''func _run_checks() -> void:
\tawait preload("res://web/checks.gd").run(self)
'''
    text=text.replace('s.radial_segments = 20','s.radial_segments = 10').replace('s.rings = 12','s.rings = 5')
    p.write_text(text)
    p=STAGE/'question_audio.gd'; p.write_text(p.read_text().replace('load(q.audio).duplicate()', 'get_parent().web_content.clip_stream(q.audio).duplicate()'))
    p=STAGE/'audio_director.gd'; p.write_text(replace_once(p.read_text(),'\tp.volume_db = db','\tp.playback_type = AudioServer.PLAYBACK_TYPE_STREAM\n\tp.volume_db = db'))
    p=STAGE/'scene_details.gd';text=p.read_text()
    for name in ['ssao','ssil','sdfgi','volumetric_fog']: text=text.replace('env.'+name+'_enabled = true','env.'+name+'_enabled = false')
    text=text.replace('env.ambient_light_energy = .045','env.ambient_light_energy = .22')
    p.write_text(text)
    p=STAGE/'room_dynamics.gd';text=p.read_text().replace('window_light.shadow_enabled=g.settings.shadows;g.projector_fill.shadow_enabled=g.settings.shadows','window_light.shadow_enabled=false;g.projector_fill.shadow_enabled=false')
    p.write_text(text)
    p=STAGE/'project.godot';text=p.read_text().replace('renderer/rendering_method="forward_plus"','renderer/rendering_method="forward_plus"\nrenderer/rendering_method.web="gl_compatibility"').replace('msaa_3d=2','msaa_3d=0').replace('atlas_size=4096','atlas_size=1024')
    text=text.replace('[application]','[application]\nrun/max_fps=60').replace('window/stretch/mode="canvas_items"','window/stretch/mode="viewport"').replace('[audio]','[audio]\ndriver/output_latency.web=100')
    p.write_text(text)
    (STAGE/'export_presets.cfg').write_text('''[preset.0]
name="Web"
platform="Web"
runnable=true
export_filter="all_resources"
include_filter="content.json,media-manifest.json,assets/audio/voice_meta.json,shared/*.json"
exclude_filter=""
[preset.0.options]
variant/extensions_support=false
variant/thread_support=false
vram_texture_compression/for_desktop=true
vram_texture_compression/for_mobile=false
html/export_icon=false
html/canvas_resize_policy=2
html/focus_canvas_on_start=true
progressive_web_app/enabled=false
''')
    assert source_hashes == {str(p.relative_to(original)): digest(p) for p in original.rglob('*') if p.is_file() and '.godot' not in p.parts}, 'Source changed during staging'
    (OUT/'web-source-proof.json').write_text(json.dumps({'source_files':source_hashes,'bank_sha256':manifest['bank_sha256'],'source_unchanged':True},indent=2)+'\n')
    return manifest


def package(source_commit):
    export=OUT/'web-export'
    prefix='game-'+source_commit[:12]
    for p in export.iterdir():
        if p.suffix=='.html' or p.suffix=='.png': continue
        name=p.name.replace('index.',prefix+'.',1)
        if p.suffix=='.wasm':
            (DIST/(name+'.gz')).write_bytes(gzip.compress(p.read_bytes(),mtime=0))
        elif p.name=='index.js':
            text=p.read_text(); anchor='GodotAudio.ctx=ctx;'
            text=replace_once(text,anchor,anchor+'window.lastTakeAudio=ctx;')
            (DIST/name).write_text(text)
        else: shutil.copyfile(p,DIST/name)
    payload=sum(p.stat().st_size for p in DIST.iterdir() if p.is_file())
    info={'source_commit':source_commit,'engine':'4.5.1','bank_sha256':digest(ROOT/'Source/content.json'),
          'initial_file_bytes':payload, 'pck_bytes':(export/'index.pck').stat().st_size,
          'wasm_gzip_bytes':(DIST/(prefix+'.wasm.gz')).stat().st_size,
          'deferred_media_bytes':sum(p.stat().st_size for p in (DIST/'media').iterdir()),
          'models':json.loads((OUT/'web-models/model-report.json').read_text()),
          'manual_acceptance':'pending','source_unchanged':True}
    (DIST/'BUILD-INFO.json').write_text(json.dumps(info,indent=2)+'\n')
    html=(ROOT/'Web/shell.html').read_text().replace('__PREFIX__',prefix).replace('__PCK_SIZE__',str(info['pck_bytes'])).replace('__WASM_SIZE__',str((export/'index.wasm').stat().st_size)).replace('__INITIAL_MB__',str(round(payload/1e6,1)))
    (DIST/'index.html').write_text(html)
    (DIST/'.nojekyll').touch()
    info['initial_file_bytes']=sum(p.stat().st_size for p in DIST.iterdir() if p.is_file())
    (DIST/'BUILD-INFO.json').write_text(json.dumps(info,indent=2)+'\n')
    print('WEB_PROTOTYPE_PACKAGE',json.dumps({k:v for k,v in info.items() if k!='models'}),flush=True)
    shutil.make_archive(str(OUT/'LastTake-Web-prototype'),'zip',DIST)
    return info


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--install',action='store_true');parser.add_argument('--stage-only',action='store_true');parser.add_argument('--blender',default='blender');parser.add_argument('--godot',default=str(OUT/'tools/editor/Godot_v4.5.1-stable_linux.x86_64'));args=parser.parse_args()
    if args.install: install()
    manifest=stage(args.blender)
    if not args.stage_only:
        common.run([args.godot,'--headless','--editor','--path',STAGE,'--import'],'web-prototype-import')
        common.run([sys.executable,ROOT/'Web/check_native.py','--godot',args.godot],'web-http-conformance',timeout=240)
        export=OUT/'web-export';export.mkdir(exist_ok=True)
        common.run([args.godot,'--headless','--path',STAGE,'--export-debug','Web',export/'index.html'],'web-prototype-export')
        package(os.environ.get('GITHUB_SHA',subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()))
