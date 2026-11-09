"""Author beveled scene props in metres; export engine-ready meshes."""
import sys
sys.path.insert(0,'/usr/lib/python3.12/lib-dynload')
sys.path.append('/usr/lib/python3/dist-packages')
import bpy, math, random
from pathlib import Path
from mathutils import Vector
R=Path(__file__).resolve().parents[1]
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
random.seed(6006)
def pt(p):return (p[0],-p[2],p[1])
def material(name,color,rough=.6,metal=0,tex=None):
 m=bpy.data.materials.new(name);m.use_nodes=True
 n=m.node_tree.nodes;p=n.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal
 if tex:
  t=n.new('ShaderNodeTexImage');t.image=bpy.data.images.load(str(R/'assets/materials'/f'{tex}_diff.jpg'));m.node_tree.links.new(t.outputs['Color'],p.inputs['Base Color'])
  normal=n.new('ShaderNodeTexImage');normal.image=bpy.data.images.load(str(R/'assets/materials'/f'{tex}_nor_gl.jpg'));normal.image.colorspace_settings.name='Non-Color'
  bump=n.new('ShaderNodeNormalMap');bump.inputs['Strength'].default_value=.38;m.node_tree.links.new(normal.outputs['Color'],bump.inputs['Color']);m.node_tree.links.new(bump.outputs['Normal'],p.inputs['Normal'])
 return m
wood=material('AgedOak',(.32,.25,.17),.76,tex='wood_planks_dirt')
metal=material('EnamelMetal',(.075,.085,.077),.43,.58)
steel=material('BrushedSteel',(.24,.26,.25),.38,.8)
rust=material('OxidizedSteel',(.18,.11,.065),.8,.45)
black=material('BlackRubber',(.012,.014,.012),.9)
brass=material('OldBrass',(.27,.21,.11),.42,.76)
paper=material('OldCardboard',(.30,.25,.15),.96)
def finish(o,name,mat,bevel=.005,smooth=False):
 o.name=name;o.data.materials.append(mat)
 if bevel:
  mod=o.modifiers.new('Rounded manufactured edges','BEVEL');mod.width=bevel;mod.segments=3
  bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
 if smooth:
  for p in o.data.polygons:p.use_smooth=True
 else:
  norm=o.modifiers.new('Weighted surface normals','WEIGHTED_NORMAL');norm.keep_sharp=True
 return o
def box(name,pos,size,mat=metal,bev=.005):
 bpy.ops.mesh.primitive_cube_add(size=1,location=pt(pos));o=bpy.context.object;o.dimensions=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 return finish(o,name,mat,bev)
def cyl(name,pos,radius,depth,mat=metal,axis=(0,1,0),verts=32):
 bpy.ops.mesh.primitive_cylinder_add(vertices=verts,radius=radius,depth=depth,location=pt(pos));o=bpy.context.object;o.rotation_mode='QUATERNION';o.rotation_quaternion=Vector((0,0,1)).rotation_difference(Vector(pt(axis)))
 return finish(o,name,mat,.0015,True)
def rod(name,a,b,r,mat=metal):
 d=Vector(b)-Vector(a);return cyl(name,(Vector(a)+Vector(b))*.5,r,d.length,mat,d.normalized())
def tube(name,points,r,mat):
 c=bpy.data.curves.new(name,'CURVE');c.dimensions='3D';c.resolution_u=8;c.bevel_depth=r;c.bevel_resolution=2
 s=c.splines.new('POLY');s.points.add(len(points)-1)
 for v,p in zip(s.points,points):v.co=(*pt(p),1)
 o=bpy.data.objects.new(name,c);bpy.context.collection.objects.link(o);o.data.materials.append(mat)
 bpy.context.view_layer.objects.active=o;o.select_set(True);bpy.ops.object.convert(target='MESH');o.select_set(False);return o
# Table: same working height, 38 cm closer, six individual boards.
for j in range(6):
 z=-.175+j*.205
 ob=box('TableBoard_%02d'%j,(0,.807,z),(2.32,.106,.202),wood,.009)
 for x in [-1.04,1.04]:
  cyl('RecessedNail',(x,.861,z+.055),.0065,.0015,steel)
for x in [-1.03,1.03]:
 for z in [-.14,.80]:
  box('SquareSteelLeg',(x,.365,z),(.052,.73,.052),metal,.006)
  box('RubberFoot',(x,.025,z),(.067,.05,.067),black,.008)
 box('EndApron',(x,.71,.33),(.045,.17,1.03),wood,.005)
 rod('CrossBrace',(x,.20,-.14),(x,.67,.80),.013,rust)
for z in [-.15,.81]:box('TableApron',(0,.724,z),(2.12,.15,.035),wood,.004)
# Old galvanized pipes, brackets, valves, joints and an electrical box.
for x in [-2.48,2.48]:
 rod('ServicePipe',(x,2.53,-3.4),(x,2.53,2.7),.031,metal)
 for z in [-3,-1.4,.2,1.8]:
  cyl('PipeCoupling',(x,2.53,z),.041,.08,rust,(0,0,1))
  box('PipeWallBracket',(x,2.53,z),(.15,.032,.04),steel,.003)
box('FuseBox',(-2.54,1.3,-2.5),(.16,.40,.29),metal,.015)
for y in [1.20,1.28,1.36]:box('FuseBoxVent',(-2.451,y,-2.5),(.003,.009,.18),black,.001)
rod('VerticalConduit',(-2.52,1.51,-2.5),(-2.52,2.53,-2.5),.012,rust)
for i in range(12):
 z=-2.6+(i%3)*.13;y=.59+(i//3)*.052
 cyl('FilmTin',(2.15,y,z),.16,.044,steel)
 cyl('FilmTinLip',(2.15,y+.021,z),.164,.008,metal)
for i in range(55):
 x=random.choice([-1,1])*random.uniform(1.8,2.5);z=random.uniform(-3.2,2.6)
 ob=box('PlasterDebris',(x,.006,z),(random.uniform(.015,.07),.012,random.uniform(.02,.08)),paper,.002);ob.rotation_euler[2]=random.random()*6
# Original prop mesh, no external models copied.
bpy.ops.object.select_all(action='DESELECT')
for o in list(bpy.context.scene.objects):
 if o.type=='MESH':
  bpy.context.view_layer.objects.active=o;o.select_set(True)
  bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.cube_project(cube_size=1.1);bpy.ops.object.mode_set(mode='OBJECT');o.select_set(False)
# Batch static geometry by material: the scene needs only a handful of draw calls.
for material_item in list(bpy.data.materials):
 objects=[o for o in bpy.context.scene.objects if o.type=='MESH' and len(o.data.materials)==1 and o.data.materials[0]==material_item]
 if not objects:continue
 bpy.ops.object.select_all(action='DESELECT')
 for o in objects:
  o.select_set(True);bpy.context.view_layer.objects.active=o
  for modifier in list(o.modifiers):bpy.ops.object.modifier_apply(modifier=modifier.name)
 bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();objects[0].name=material_item.name
bpy.ops.object.select_all(action='SELECT')
(R/'assets/props').mkdir(exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(R/'assets/props/room_props.glb'),export_format='GLB',use_selection=True,export_apply=True,export_animations=False)
print('PROP_GEOMETRY_READY')
