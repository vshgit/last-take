"""Blender 4.0.2: reference-guided villain, preserving CC0 rig and face morphs.
The supplied portrait/turnaround guide proportions and clothing; not photogrammetry.
"""
import bpy,bmesh,math,random
from pathlib import Path
from mathutils import Vector,kdtree
R=Path(__file__).resolve().parents[1]
ART=R.parent/'ArtSource/character-v10';ART.mkdir(parents=True,exist_ok=True)
random.seed(410)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(R/'assets/character/cinemaniac_v09.glb'))
body=bpy.data.objects['Body'];rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
rig.animation_data.action=None
for bone in rig.pose.bones:bone.matrix_basis.identity()
bpy.context.view_layer.update()

def active(o):
 bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
def material(name,c):
 m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=(*c,1)
 m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(*c,1)
 m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.9
 return m
cloth=material('AgedBeigeTerry',(.34,.29,.22))
shortmat=material('GreyCotton',(.12,.125,.11))
slippermat=material('WornSlippers',(.07,.06,.045))
hairmat=material('SilverStrands',(.08,.09,.08))
for o in list(bpy.context.scene.objects):
 if o.type=='MESH' and any(x in o.name.lower() for x in ['robe','shawl','shoes']):bpy.data.objects.remove(o,do_unlink=True)

# Preserve facial targets while shaping a leaner, older jaw and cheek profile.
def shape(co):
 x,y,z=co;v=Vector(co)
 if 1.47<z<1.62 and y<-.06:
  cheek=math.exp(-((z-1.553)/.031)**2)*math.exp(-((abs(x)-.052)/.032)**2)
  v.x-=math.copysign(.0035*cheek,x);v.y+=.0020*cheek
  nose=math.exp(-((z-1.568)/.032)**2)*math.exp(-(x/.014)**2)
  v.y-=.0025*nose
  jaw=math.exp(-((z-1.49)/.024)**2)
  v.x*=1.0+.035*jaw;v.z-=.002*jaw
 return v
if body.data.shape_keys:
 for block in body.data.shape_keys.key_blocks:
  for v in block.data:v.co=shape(v.co)
else:
 for v in body.data.vertices:v.co=shape(v.co)
body.data.update()
kd=kdtree.KDTree(len(body.data.vertices))
for v in body.data.vertices:kd.insert(v.co,v.index)
kd.balance()

def smooth(o):
 for p in o.data.polygons:p.use_smooth=True
def mesh(name,verts,faces,mat):
 me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update()
 ob=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(ob)
 ob.data.materials.append(mat);smooth(ob)
 return ob
def modifier(o,name,kind,**values):
 active(o);m=o.modifiers.new(name,kind)
 for k,v in values.items():setattr(m,k,v)
 bpy.ops.object.modifier_apply(modifier=m.name)
def bind(o,mode='nearest',bone=None):
 groups={g.name:o.vertex_groups.new(name=g.name) for g in body.vertex_groups}
 source_names={g.index:g.name for g in body.vertex_groups}
 levels=[(.88,'pelvis'),(.97,'spine_01'),(1.06,'spine_02'),(1.30,'spine_03'),(1.47,'neck_01')]
 for v in o.data.vertices:
  if bone:
   groups[bone].add([v.index],1,'REPLACE')
  elif mode=='torso':
   z=v.co.z;weights=[('pelvis',1)]
   for (za,a),(zb,b) in zip(levels,levels[1:]):
    if za<=z<=zb:
     t=(z-za)/(zb-za);weights=[(a,1-t),(b,t)];break
   if z>levels[-1][0]:weights=[('neck_01',1)]
   for n,w in weights:groups[n].add([v.index],w,'REPLACE')
  else:
   _,idx,_=kd.find(v.co)
   for g in body.data.vertices[idx].groups:
    groups[source_names[g.group]].add([v.index],g.weight,'REPLACE')
 m=o.modifiers.new('Original character rig','ARMATURE');m.object=rig
 o.parent=rig;o.matrix_parent_inverse=rig.matrix_world.inverted()
def cloth_mesh(name,verts,faces,mode='torso',thickness=.003):
 o=mesh(name,verts,faces,cloth)
 if thickness:modifier(o,'Terry thickness','SOLIDIFY',thickness=thickness,offset=0.0)
 bind(o,mode);return o

# The shoulder follows the anatomical surface. Continuous fitted arm lofts
# are added below, preserving smooth skin weights through each elbow.
verts=[];faces=[];mapping={}
group_names={g.index:g.name for g in body.vertex_groups}
normals={}
def coordinate_key(v):return tuple(round(c,5) for c in v.co)
for v in body.data.vertices:
 key=coordinate_key(v);normals[key]=normals.get(key,Vector())+v.normal
for key in normals:normals[key].normalize()
for p in body.data.polygons:
 c=sum((body.data.vertices[k].co for k in p.vertices),Vector())/len(p.vertices)
 if not (1.012<c.z<1.455):continue
 if abs(c.x)<.066 and c.y<-.015:continue
 hand=sum(g.weight for k in p.vertices for g in body.data.vertices[k].groups if 'hand' in group_names[g.group] or any(x in group_names[g.group] for x in ['thumb','index_','middle_','ring_','pinky_']))/len(p.vertices)
 if hand>.20:continue
 face=[]
 for k in p.vertices:
  if k not in mapping:
   v=body.data.vertices[k];x,y,z=v.co
   loose=.024+.017*min(1,max(0,(abs(x)-.15)/.20))
   folds=.003*math.sin(z*69+x*13)+.002*math.sin(y*91+z*27)
   mapping[k]=len(verts);verts.append(tuple(v.co+normals[coordinate_key(v)]*(loose+folds)))
  face.append(mapping[k])
 faces.append(face)
top=mesh('RobeContinuousSleeves',verts,faces,cloth)
bm=bmesh.new();bm.from_mesh(top.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.0001);bm.to_mesh(top.data);bm.free()
modifier(top,'Soft tailoring','SUBSURF',levels=1)
modifier(top,'Terry thickness','SOLIDIFY',thickness=.003,offset=0.0)
bind(top)

profile=[(.39,.305,.207,.198),(.64,.295,.205,.193),(.91,.265,.193,.18),(1.09,.23,.182,.16),(1.27,.235,.167,.145),(1.39,.225,.142,.12),(1.46,.093,.09,.077)]
def section(z):
 for a,b in zip(profile,profile[1:]):
  if z<=b[0]:
   t=max(0,min(1,(z-a[0])/(b[0]-a[0])));t=t*t*(3-2*t)
   return tuple(a[k]+(b[k]-a[k])*t for k in [1,2,3])
 return profile[-1][1:]
def wrap_point(z,a):
 rx,front,back=section(z)
 f=(.005*math.sin(a*19+z*2)+.002*math.sin(a*31-z*7))*max(.2,min(1,(1.5-z)*1.4))
 return (math.sin(a)*(rx+f),-math.cos(a)*((front if math.cos(a)>=0 else back)+f),z)
rows=65;cols=97;gap=math.radians(24);verts=[];faces=[]
for i in range(rows):
 z=.39+1.07*i/(rows-1)
 for j in range(cols):verts.append(wrap_point(z,gap+(math.tau-2*gap)*j/(cols-1)))
for i in range(rows-1):
 for j in range(cols-1):
  a=i*cols+j;faces.append((a,a+1,a+cols+1,a+cols))
cloth_mesh('RobeOpenWrap',verts,faces)
for side in [-1,1]:
 verts=[];faces=[]
 for i in range(45):
  z=1.46-.65*i/44;x,y,_=wrap_point(z,gap)
  for j in range(8):
   u=j/7;w=.065*(1-.20*i/44)
   verts.append((side*(x+(u-.5)*w),y-.006-.009*math.sin(u*math.pi),z))
 for i in range(44):
  for j in range(7):a=i*8+j;faces.append((a,a+1,a+9,a+8))
 cloth_mesh('ShawlLapel',verts,faces,thickness=.005)
 verts=[];faces=[]
 for i in range(13):
  z=.89-.15*i/12
  for j in range(13):
   a=side*(.57+.42*j/12);x,y,_=wrap_point(z,a)
   verts.append((x,y-.004-.008*math.sin(j/12*math.pi)*math.sin(i/12*math.pi),z))
 for i in range(12):
  for j in range(12):a=i*13+j;faces.append((a,a+1,a+14,a+13))
 cloth_mesh('RobePatchPocket',verts,faces)

def tube(name,points,radii,mat,bone=None,mode='torso',sides=8):
 verts=[];faces=[]
 for i,p in enumerate(points):
  p=Vector(p);t=(Vector(points[min(i+1,len(points)-1)])-Vector(points[max(0,i-1)])).normalized()
  u=t.cross(Vector((0,0,1)))
  if u.length<.01:u=t.cross(Vector((0,1,0)))
  u.normalize();v=t.cross(u).normalized()
  for j in range(sides):verts.append(tuple(p+radii[i]*(u*math.cos(j*math.tau/sides)+v*math.sin(j*math.tau/sides))))
 for i in range(len(points)-1):
  for j in range(sides):a=i*sides+j;b=i*sides+(j+1)%sides;faces.append((a,b,b+sides,a+sides))
 faces.extend([tuple(reversed(range(sides))),tuple((len(points)-1)*sides+j for j in range(sides))])
 ob=mesh(name,verts,faces,mat);bind(ob,mode,bone);return ob

# Continuous arm lofts with a smooth tangent through the elbow. The proximal
# cap sits inside the shoulder; the only open end is the wrist cuff.
def catmull(a,b,c,d,t):
 return .5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t)
for side,suffix in [(-1,'r'),(1,'l')]:
 shoulder=rig.data.bones['upperarm_'+suffix].head_local.copy()
 elbow=rig.data.bones['lowerarm_'+suffix].head_local.copy()
 wrist=rig.data.bones['hand_'+suffix].head_local.copy()
 start=shoulder+Vector((-side*.045,0,.008))
 def center(t):
  if t<=.5:return catmull(start,start,elbow,wrist,t*2)
  return catmull(start,elbow,wrist,wrist,(t-.5)*2)
 rows=49;cols=32;verts=[];faces=[]
 for i in range(rows):
  t=i/(rows-1);p=center(t)
  tangent=(center(min(1,t+.002))-center(max(0,t-.002))).normalized()
  u=tangent.cross(Vector((0,1,0))).normalized();v=tangent.cross(u).normalized()
  radius=.100*(1-t)+.078*t+.008*math.exp(-((t-.50)/.17)**2)
  for j in range(cols):
   a=j*math.tau/cols
   fold=.0025*math.sin(a*7+t*10)+.002*math.sin(t*45)*math.sin(a*3)
   verts.append(tuple(p+(radius+fold)*(u*math.cos(a)+v*math.sin(a))))
 for i in range(rows-1):
  for j in range(cols):a=i*cols+j;b=i*cols+(j+1)%cols;faces.append((a,b,b+cols,a+cols))
 faces.append(tuple(reversed(range(cols))))
 ob=mesh('RobeTailoredSleeve_'+suffix,verts,faces,cloth)
 bind(ob,bone='upperarm_'+suffix)
 for group in ob.vertex_groups:group.remove(list(range(len(verts))))
 for i in range(rows):
  t=i/(rows-1);blend=max(0,min(1,(t-.34)/.32));blend=blend*blend*(3-2*blend)
  clavicle=max(0,1-t/.18)*.65
  ids=list(range(i*cols,(i+1)*cols))
  for name,w in [('upperarm_'+suffix,(1-blend)*(1-clavicle)),('lowerarm_'+suffix,blend),('clavicle_'+suffix,clavicle*(1-blend))]:
   if w>0:ob.vertex_groups[name].add(ids,w,'REPLACE')

# Belt rests around the back; two slack ends hang beside the open front.
neck=[wrap_point(1.456,gap+(math.tau-2*gap)*i/70) for i in range(71)]
tube('ShawlRolledNeck',neck,[.012]*71,cloth)
points=[wrap_point(.925+.007*math.sin(i*.2),.65+(math.tau-1.3)*i/75) for i in range(76)]
tube('RobeBackBelt',points,[.011]*len(points),cloth)
for side in [-1,1]:
 x,y,z=wrap_point(.925,.65*side)
 points=[(x+side*.008*math.sin(i*.5),y-.01,.925-i*.009) for i in range(33)]
 tube('RobeBeltEnd',points,[.009]*33,cloth)
 points=[(x+.014*math.cos(i*math.tau/24),y-.014+.009*math.sin(i*math.tau/24),z+.009*math.sin(i*math.tau/24)) for i in range(25)]
 tube('RobeBeltKnot',points,[.008]*25,cloth)

# Keep the original shorts rig, but remove trouser legs and recolor cotton.
for o in list(bpy.context.scene.objects):
 if o.type=='MESH' and 'jeans' in o.name.lower():
  if o.data.shape_keys:o.shape_key_clear()
  bm=bmesh.new();bm.from_mesh(o.data)
  bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),dist=.00001,plane_co=(0,0,.68),plane_no=(0,0,1),clear_inner=True,clear_outer=False)
  bm.to_mesh(o.data);bm.free();o.name='BoxerShorts'
  o.data.materials.clear();o.data.materials.append(shortmat)
  for v in o.data.vertices:
   if v.co.z<.79:v.co+=v.normal*(.009*(.79-v.co.z)/.11)
  smooth(o)

# Slippers share the foot bones, leaving ankles and heels exposed.
for side,suffix in [(-1,'r'),(1,'l')]:
 for name,center,scale in [('SlipperSole',(side*.186,-.075,.008),(.073,.145,.016)),('SlipperUpper',(side*.189,-.134,.043),(.071,.090,.048))]:
  bpy.ops.mesh.primitive_uv_sphere_add(segments=32,ring_count=16,radius=1,location=center)
  o=bpy.context.object;o.name=name;o.scale=scale
  bpy.ops.object.transform_apply(location=True,rotation=True,scale=True);o.data.materials.append(slippermat);smooth(o);bind(o,bone='foot_'+suffix)

# Swept silver hair, with a receding front and a small irregular silhouette.
hair_roots=[]
for o in bpy.context.scene.objects:
 if o.type=='MESH' and 'hair_short' in o.name.lower():
  if o.data.shape_keys:o.shape_key_clear()
  for v in o.data.vertices:
   x,y,z=v.co
   front=max(0,min(1,(-y-.07)/.09));high=max(0,min(1,(z-1.59)/.08))
   v.co.y+=.023*front;v.co.z+=.007*high+.028*front*(1-high*.4)
   if v.co.z>1.69:hair_roots.append(v.co.copy())
  smooth(o)
wisps=[]
for i in range(110):
 root=random.choice(hair_roots).copy();root.z-=.003
 direction=Vector((.45,.6,.25)).normalized();length=random.uniform(.014,.034)
 points=[root+direction*length*t+Vector((.001*math.sin(t*5+i),0,.004*math.sin(t*math.pi))) for t in [0,.25,.5,.75,1]]
 wisps.append(tube('SilverHairWisp',points,[.00065,.0006,.0005,.0003,.0001],hairmat,bone='head',sides=4))
active(wisps[0])
for o in wisps:o.select_set(True)
bpy.ops.object.join();bpy.context.object.name='ReferenceHairWisps'

# The robe is permanent clothing. Cull covered arm skin, while retaining
# shoulders near the open neck and the visible wrist/left hand. This also
# avoids skin breaking through a sleeve during strong IK bends.
covered=set()
for v in body.data.vertices:
 arm=sum(g.weight for g in v.groups if 'upperarm' in group_names[g.group] or 'lowerarm' in group_names[g.group])
 hand=sum(g.weight for g in v.groups if 'hand' in group_names[g.group])
 if arm>.25 and hand<.35 and abs(v.co.x)>.19 and v.co.z>1.025:covered.add(v.index)
bm=bmesh.new();bm.from_mesh(body.data);bm.verts.ensure_lookup_table()
bmesh.ops.delete(bm,geom=[f for f in bm.faces if all(v.index in covered for v in f.verts)],context='FACES')
bm.to_mesh(body.data);bm.free()

bpy.ops.object.select_all(action='SELECT')
bpy.ops.wm.save_as_mainfile(filepath=str(ART/'cinemaniac_v10.blend'))
bpy.ops.export_scene.gltf(filepath=str(R/'assets/character/cinemaniac_v10.glb'),export_format='GLB',use_selection=True,export_animations=True,export_morph=True,export_skins=True)
print('VILLAIN_V10_READY')
