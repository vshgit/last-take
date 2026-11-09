"""Blender 4.0.2: retain original body rig and replace the distorted right-hand surface with a fitted grip."""
import sys
sys.path.insert(0,'/usr/lib/python3.12/lib-dynload');sys.path.append('/usr/lib/python3/dist-packages')
import bpy,bmesh,math
from mathutils import Vector
from pathlib import Path
R=Path(__file__).resolve().parents[1]
def clean():bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
clean();bpy.ops.import_scene.gltf(filepath=str(R/'assets/character/cinemaniac.glb'))
for body in [o for o in bpy.context.scene.objects if o.type=='MESH' and o.vertex_groups]:
 groups={g.index:g.name for g in body.vertex_groups};remove=set()
 for v in body.data.vertices:
  w=sum(g.weight for g in v.groups if groups[g.group]=='hand_r' or (groups[g.group].endswith('_r') and any(groups[g.group].startswith(x) for x in ['index_','middle_','ring_','pinky_','thumb_'])))
  if w>(.52 if body.name=='Body' else .25):remove.add(v.index)
 if remove:
  bm=bmesh.new();bm.from_mesh(body.data);bm.verts.ensure_lookup_table();bmesh.ops.delete(bm,geom=[f for f in bm.faces if any(v.index in remove for v in f.verts)],context='FACES');bm.to_mesh(body.data);bm.free()
bpy.ops.object.select_all(action='SELECT');bpy.ops.export_scene.gltf(filepath=str(R/'assets/character/cinemaniac_v09.glb'),export_format='GLB',use_selection=True,export_animations=True,export_morph=True,export_skins=True)
clean()
def pt(p):return Vector((p[0],-p[2],p[1]))
def material(name,c,rough):
 m=bpy.data.materials.new(name);m.use_nodes=True;n=m.node_tree.nodes.get('Principled BSDF');n.inputs['Base Color'].default_value=(*c,1);n.inputs['Roughness'].default_value=rough;return m
skin=material('HandSkin',(.34,.205,.145),.66);nail=material('FingerNails',(.43,.32,.27),.48);crease=material('SkinCreases',(.24,.13,.09),.84);parts=[]
def ellipsoid(name,p,s,mat=skin):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=14,radius=1,location=pt(p));o=bpy.context.object;o.name=name;o.scale=(s[0],s[2],s[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(mat)
 for f in o.data.polygons:f.use_smooth=True
 return o
def tube(name,points,radii,mat=skin,join=True):
 p=[Vector(x) for x in points];verts=[];faces=[];count=0
 for i in range(len(p)-1):
  a=p[max(0,i-1)];b=p[i];c=p[i+1];d=p[min(len(p)-1,i+2)]
  for j in range(8):
   t=j/8;v=.5*(2*b+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t)
   tangent=(-a+c)+2*(2*a-5*b+4*c-d)*t+3*(-a+3*b-3*c+d)*t*t;tangent.normalize()
   side=tangent.cross(Vector((0,1,0))).normalized();up=side.cross(tangent).normalized();r=radii[i]*(1-t)+radii[i+1]*t
   for k in range(16):verts.append(pt(v+(side*math.cos(k*math.tau/16)+up*math.sin(k*math.tau/16))*r))
   if count:
    for k in range(16):x=(count-1)*16+k;y=(count-1)*16+(k+1)%16;faces.append((x,y,y+16,x+16))
   count+=1
 faces.append(tuple(range(15,-1,-1)));faces.append(tuple((count-1)*16+k for k in range(16)))
 me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update();o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o);o.data.materials.append(mat)
 for f in me.polygons:f.use_smooth=True
 if join:parts.append(o)
 return o
parts.extend([ellipsoid('PalmBack',(-.027,-.008,-.023),(.014,.041,.046)),ellipsoid('Heel',(-.020,-.008,-.055),(.020,.031,.027)),ellipsoid('Thenar',(-.018,.020,-.036),(.016,.022,.026))])
tube('Wrist',[(-.0176,-.004,-.112),(-.0176,-.004,-.088),(-.021,-.008,-.057)],[.023,.023,.026])
fingers={
'Middle':([(-.025,.004,.010),(-.020,.002,.029),(.001,.001,.031),(.024,.000,.021),(.027,-.001,-.004)],[.010,.0095,.009,.0085,.007]),
'Ring':([(-.026,-.015,.005),(-.020,-.017,.025),(.001,-.018,.027),(.023,-.019,.018),(.026,-.019,-.007)],[.0095,.009,.0085,.008,.0065]),
'Pinky':([(-.025,-.033,-.004),(-.020,-.034,.016),(.001,-.035,.021),(.021,-.035,.011),(.024,-.034,-.008)],[.008,.0075,.007,.0065,.0057]),
'Index':([(-.023,.025,.013),(-.018,.024,.035),(-.004,.020,.054),(.015,.014,.051),(.014,.008,.030)],[.0097,.009,.008,.0072,.0062]),
'Thumb':([(-.016,.023,-.051),(.008,.026,-.039),(.025,.028,-.023),(.027,.025,-.004),(.026,.022,.009)],[.014,.012,.011,.009,.008])}
for name,(p,r) in fingers.items():tube(name,p,r)
bpy.ops.object.select_all(action='DESELECT')
for o in parts:o.select_set(True)
bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();hand=parts[0];hand.name='FittedRightHand'
m=hand.modifiers.new('ContinuousSkin','REMESH');m.mode='VOXEL';m.voxel_size=.00085;bpy.ops.object.modifier_apply(modifier=m.name)
m=hand.modifiers.new('SoftSkin','SMOOTH');m.factor=.75;m.iterations=4;bpy.ops.object.modifier_apply(modifier=m.name)
tex=bpy.data.textures.new('Fine pores','CLOUDS');tex.noise_scale=.0014;m=hand.modifiers.new('FineSkin','DISPLACE');m.texture=tex;m.strength=.00012;bpy.ops.object.modifier_apply(modifier=m.name)
for f in hand.data.polygons:f.use_smooth=True
for name,(p,r) in fingers.items():
 a=Vector(p[-2]);b=Vector(p[-1]);direction=(b-a).normalized();loc=b-direction*.004+Vector((r[-1]*.85,0,0));ellipsoid(name+'Nail',loc,(.0008,r[-1]*.64,.006),nail)
 if name in ['Middle','Ring','Pinky']:
  for offset in [-.0018,.0018]:
   pts=[tuple(Vector(p[2])+Vector((dx,offset+dy,.0082))) for dx,dy in [(-.004,-.001),(-.002,0),(0,.0003),(.002,0),(.004,-.001)]];tube(name+'Crease',pts,[.00023]*5,crease,False)
# A rolled cloth cuff closes the sleeve at the replacement wrist.
mat=material('RobeCuff',(.24,.28,.25),.94);verts=[];faces=[];cols=64;rows=13
for j in range(rows):
 t=j/(rows-1);z=-.162+.086*t;rx=.044*(1-t)+.030*t;ry=.052*(1-t)+.034*t
 for i in range(cols):
  a=i*math.tau/cols;fold=.0015*math.sin(a*7+t*2)+.001*math.sin(t*math.pi*3)
  verts.append(pt((-.0176+(rx+fold)*math.cos(a),-.004+(ry+fold)*math.sin(a),z)))
for j in range(rows-1):
 for i in range(cols):
  a=j*cols+i;b=j*cols+(i+1)%cols;faces.append((a,b,b+cols,a+cols))
me=bpy.data.meshes.new('RolledCuff');me.from_pydata(verts,[],faces);me.update();cuff=bpy.data.objects.new('RolledCuff',me);bpy.context.collection.objects.link(cuff);cuff.data.materials.append(mat)
for face in me.polygons:face.use_smooth=True
bpy.context.view_layer.objects.active=cuff;cuff.select_set(True);m=cuff.modifiers.new('FabricThickness','SOLIDIFY');m.thickness=.003;m.offset=0;bpy.ops.object.modifier_apply(modifier=m.name)
bpy.ops.object.select_all(action='SELECT');bpy.ops.export_scene.gltf(filepath=str(R/'assets/props/gripping_hand_v09.glb'),export_format='GLB',use_selection=True,export_apply=True,export_animations=False)
print('FITTED_HAND_READY',len(hand.data.polygons))
