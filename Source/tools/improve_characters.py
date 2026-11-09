"""Refine the existing CC0 meshes; retain the original rig and facial morphs."""
import sys
sys.path.insert(0,'/usr/lib/python3.12/lib-dynload')
sys.path.append('/usr/lib/python3/dist-packages')
import bpy, math, bmesh, argparse
from mathutils import Vector, kdtree
from pathlib import Path
R=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('--base-characters',type=Path,default=R.parent/'ArtSource/base_characters')
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
SOURCE=args.base_characters
def clean():
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def mat(name,col):
 m=bpy.data.materials.new(name);m.diffuse_color=(*col,1);m.use_nodes=True;m.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(*col,1);return m
def active(obj):
 bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
def smooth(obj):
 for p in obj.data.polygons:p.use_smooth=True
def solidify(obj,thickness):
 active(obj);m=obj.modifiers.new('Fabric thickness','SOLIDIFY');m.thickness=thickness;m.offset=0;bpy.ops.object.modifier_apply(modifier=m.name)
def mesh_object(name,verts,faces,material):
 me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update();ob=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(ob);ob.data.materials.append(material);smooth(ob)
 active(ob);bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(island_margin=.02);bpy.ops.object.mode_set(mode='OBJECT');return ob
def assign_rig(obj,body,rig):
 kd=kdtree.KDTree(len(body.data.vertices))
 for v in body.data.vertices:kd.insert(v.co,v.index)
 kd.balance();groups={g.index:obj.vertex_groups.new(name=g.name) for g in body.vertex_groups}
 for v in obj.data.vertices:
  _,ind,_=kd.find(v.co)
  for gr in body.data.vertices[ind].groups:
   if gr.group in groups:groups[gr.group].add([v.index],gr.weight,'REPLACE')
 mod=obj.modifiers.new('Follow original rig','ARMATURE');mod.object=rig
 obj.parent=rig;obj.matrix_parent_inverse=rig.matrix_world.inverted()
clean();bpy.ops.import_scene.gltf(filepath=str(SOURCE/'cinemaniac.glb'))
body=bpy.data.objects['Body'];rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
rig.animation_data.action=None
for pb in rig.pose.bones:pb.matrix_basis.identity()
bpy.context.view_layer.update()
robe_mat=mat('RobeTailoring',(.24,.28,.25))
for name in ['Bathrobe','RobeShoulders']:
 ob=bpy.data.objects.get(name)
 if not ob:continue
 if name=='Bathrobe':
  bpy.data.objects.remove(ob,do_unlink=True)
  continue
 # Clothing is fixed to this character: keep the skeleton, but discard unused
 # garment fitting morphs so Catmull-Clark can round the collar and sleeves.
 if ob.data.shape_keys:ob.shape_key_clear()
 active(ob)
 if ob.data.has_custom_normals:bpy.ops.mesh.customdata_custom_splitnormals_clear()
 ob.data.materials.clear();ob.data.materials.append(robe_mat)
 if name=='RobeShoulders':
  # The original suit's pointed lapels sit inside the new shawl collar.
  # Remove those panels before rounding the remaining shoulder/sleeve mesh.
  bm=bmesh.new();bm.from_mesh(ob.data)
  remove=[]
  for f in bm.faces:
   x,y,z=f.calc_center_median()
   if (abs(x)<.16 and y<-.02) or (abs(x)<.14 and z>1.445):remove.append(f)
  bmesh.ops.delete(bm,geom=remove,context='FACES')
  bm.to_mesh(ob.data);bm.free()
 smooth(ob)
 if not ob.data.shape_keys:
  active(ob);mod=ob.modifiers.new('Smooth cloth silhouette','SUBSURF');mod.levels=1;bpy.ops.object.modifier_apply(modifier=mod.name)
  solidify(ob,.003)
# A soft inner sleeve follows the body's exact weights. It closes the gap
# between the old sleeve's shoulder opening and the continuous outer wrap.
lining_verts=[];lining_faces=[];lining_map={}
for poly in body.data.polygons:
 center=sum((body.data.vertices[k].co for k in poly.vertices),Vector())/len(poly.vertices)
 if not (.14<abs(center.x)<.50 and 1.06<center.z<1.445):continue
 face=[]
 for k in poly.vertices:
  if k not in lining_map:
   v=body.data.vertices[k];lining_map[k]=len(lining_verts);lining_verts.append(tuple(v.co+v.normal*.014))
  face.append(lining_map[k])
 lining_faces.append(face)
ob=mesh_object('RobeSleeveLining',lining_verts,lining_faces,robe_mat);assign_rig(ob,body,rig)
# One continuous wrap from hem through shoulders to neck. The old straight
# top edge and separate suit fronts left shelves and holes in close-ups.
profile=[(.39,.30,.19,.205),(.66,.28,.195,.195),(.91,.25,.19,.18),(1.08,.225,.185,.16),(1.28,.245,.18,.145),(1.40,.24,.17,.13),(1.47,.095,.10,.085)]
def section(z):
 for a,b in zip(profile,profile[1:]):
  if z<=b[0]:
   t=max(0,min(1,(z-a[0])/(b[0]-a[0])));t=t*t*(3-2*t)
   return tuple(a[k]+(b[k]-a[k])*t for k in [1,2,3])
 return profile[-1][1:]
verts=[];faces=[];rows=55;cols=80;open_angle=math.radians(20)
for i in range(rows):
 z=.39+(1.47-.39)*i/(rows-1);rx,front,back=section(z)
 for j in range(cols):
  a=open_angle+(math.tau-2*open_angle)*j/(cols-1)
  fold=(math.sin(a*18+z*1.6)*.0035+math.sin(a*29-z*2)*.0015)*max(.15,min(1,(1.5-z)*1.4))
  radius=front if math.cos(a)>=0 else back
  verts.append((math.sin(a)*(rx+fold),-math.cos(a)*(radius+fold),z+math.sin(a*6)*.002*(1-i/(rows-1))))
for i in range(rows-1):
 for j in range(cols-1):
  a=i*cols+j;faces.append((a,a+1,a+cols+1,a+cols))
ob=mesh_object('Bathrobe',verts,faces,robe_mat);solidify(ob,.0025);assign_rig(ob,body,rig)
# Flat shawl lapels follow the actual open edge of the wrap.
for side in [-1,1]:
 verts=[];faces=[]
 for i in range(31):
  t=i/30;z=1.47-t*.55;rx,fp,bp=section(z);x=side*(rx*math.sin(open_angle)+.012);front=fp*math.cos(open_angle)
  for j in range(6):
   u=j/5;w=.055*(.85+.15*math.sin(t*math.pi));verts.append((x+side*(u-.5)*w,-front-.003-math.sin(u*math.pi)*.006,z))
 for i in range(30):
  for j in range(5):a=i*6+j;faces.append((a,a+1,a+7,a+6))
 ob=mesh_object('ShawlLapel',verts,faces,robe_mat);solidify(ob,.004);assign_rig(ob,body,rig)
# Sewn patch pockets with rolled upper edge.
for side in [-1,1]:
 verts=[];faces=[]
 for i in range(13):
  v=i/12
  for j in range(13):
   u=j/12;x=side*(.155+(u-.5)*.115);z=.88-v*.135;rx,fp,bp=section(z);front=fp*math.sqrt(max(.1,1-(x/rx)**2))+.003+math.sin(u*math.pi)*math.sin(v*math.pi)*.006
   verts.append((x,-front,z))
 for i in range(12):
  for j in range(12):a=i*13+j;faces.append((a,a+1,a+14,a+13))
 ob=mesh_object('RobePocket',verts,faces,robe_mat);solidify(ob,.0025);assign_rig(ob,body,rig)
for ob in bpy.context.scene.objects:
 if ob.type=='MESH':smooth(ob)
# Export animations from NLA tracks; leave facial targets intact.
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(R/'assets/character/cinemaniac.glb'),export_format='GLB',use_selection=True,export_animations=True,export_morph=True,export_skins=True)
clean();bpy.ops.import_scene.gltf(filepath=str(SOURCE/'player.glb'))
shirt=bpy.data.objects['PlayerTShirt']
if shirt.data.shape_keys:shirt.shape_key_clear()
active(shirt)
if shirt.data.has_custom_normals:bpy.ops.mesh.customdata_custom_splitnormals_clear()
# Cotton has volume and folds, unlike the old skin-tight copied torso.
used={v for p in shirt.data.polygons for v in p.vertices}
for i in used:
 v=shirt.data.vertices[i];x,y,z=v.co
 wrinkle=.004*math.sin(x*64+z*40)+.002*math.sin(z*101-x*19)
 amp=max(0,min(1,(1.20-z)/.25))
 v.co+=v.normal*(.009+wrinkle*amp)
smooth(shirt);solidify(shirt,.002)
for ob in bpy.context.scene.objects:
 if ob.type=='MESH':smooth(ob)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(R/'assets/character/player.glb'),export_format='GLB',use_selection=True,export_animations=False,export_morph=True,export_skins=True)
print('CHARACTER_GEOMETRY_READY')
