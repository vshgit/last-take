"""Blender build step: derivative GLBs only; preserve names, rigs and morph targets."""
import bpy
import json
import math
from pathlib import Path
import sys

args = sys.argv[sys.argv.index('--') + 1:]
source, destination = map(Path, args)
report = []
for filename in sorted(source.rglob('*.glb')):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(filename))
    before = after = 0
    skipped = []
    for obj in list(bpy.data.objects):
        if obj.type != 'MESH':
            continue
        obj.data.calc_loop_triangles()
        triangles = len(obj.data.loop_triangles)
        before += triangles
        if obj.data.shape_keys:
            skipped.append(obj.name)
        elif triangles > 800:
            # Preserve fine silhouettes on visible features; bound secondary meshes.
            limit = 5000 if 'base' in obj.name.lower() else 1800
            if 'robe' in obj.name.lower(): limit = 3500
            ratio = min(1.0, limit / triangles)
            if ratio < 1:
                bpy.context.view_layer.objects.active = obj
                modifier = obj.modifiers.new('WebDerivative', 'DECIMATE')
                modifier.ratio = ratio
                modifier.use_collapse_triangulate = True
                bpy.ops.object.modifier_apply(modifier=modifier.name)
        obj.data.calc_loop_triangles()
        after += len(obj.data.loop_triangles)
    for image in bpy.data.images:
        if image.size[0] > 512 or image.size[1] > 512:
            factor = 512 / max(image.size)
            image.scale(max(1, int(image.size[0]*factor)), max(1, int(image.size[1]*factor)))
    output = destination / filename.relative_to(source)
    output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(output), export_format='GLB',
                              export_yup=True, export_animations=True,
                              export_skins=True, export_morph=True,
                              export_image_format='AUTO', export_keep_originals=False)
    report.append({'path': str(filename.relative_to(source)), 'triangles_before': before,
                   'triangles_after': after, 'morph_meshes_preserved': skipped,
                   'source_bytes': filename.stat().st_size, 'derived_bytes': output.stat().st_size})
(destination / 'model-report.json').write_text(json.dumps(report, indent=2)+'\n')
print('WEB_MODELS_DERIVED', json.dumps(report))
