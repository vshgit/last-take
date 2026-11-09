"""Original 16 mm projector and a prop revolver. Blender 4.0+, metres, Y-up export."""
import sys
sys.path.insert(0,'/usr/lib/python3.12/lib-dynload')
sys.path.append('/usr/lib/python3/dist-packages')
import bpy, math, random
from pathlib import Path
from mathutils import Vector
R=Path(__file__).resolve().parents[1]
def clean():
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def pt(p):return Vector((p[0],-p[2],p[1]))
def mat(name,c,rough=.5,metal=0):
 m=bpy.data.materials.new(name);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*c,1);p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal;return m
def finish(o,name,m,bevel=.002,smooth=False):
 o.name=name;o.data.materials.append(m)
 if bevel:
  mod=o.modifiers.new('Machined edge','BEVEL');mod.width=bevel;mod.segments=3;bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
 o.data.use_auto_smooth=True
 for p in o.data.polygons:p.use_smooth=True
 if not smooth:
  mod=o.modifiers.new('Weighted normals','WEIGHTED_NORMAL');mod.keep_sharp=True;bpy.ops.object.modifier_apply(modifier=mod.name)
 return o
def box(name,pos,size,m,bev=.002):
 bpy.ops.mesh.primitive_cube_add(size=1,location=pt(pos));o=bpy.context.object;o.dimensions=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);return finish(o,name,m,bev)
def cyl(name,pos,r,h,m,axis=(1,0,0),verts=48):
 bpy.ops.mesh.primitive_cylinder_add(vertices=verts,radius=r,depth=h,location=pt(pos));o=bpy.context.object;o.rotation_mode='QUATERNION';o.rotation_quaternion=Vector((0,0,1)).rotation_difference(pt(axis));return finish(o,name,m,min(.0015,r*.1),True)
def beam(name,a,b,width,thick,m):
 d=pt(b)-pt(a);bpy.ops.mesh.primitive_cube_add(size=1,location=(pt(a)+pt(b))*.5);o=bpy.context.object;o.dimensions=(thick,width,d.length);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.rotation_mode='QUATERNION';o.rotation_quaternion=Vector((0,0,1)).rotation_difference(d.normalized());return finish(o,name,m,.002)
def curve(name,points,r,m):
 c=bpy.data.curves.new(name,'CURVE');c.dimensions='3D';c.bevel_depth=r;c.bevel_resolution=2;s=c.splines.new('POLY');s.points.add(len(points)-1)
 for v,p in zip(s.points,points):v.co=(*pt(p),1)
 o=bpy.data.objects.new(name,c);bpy.context.collection.objects.link(o);o.data.materials.append(m);bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o;bpy.ops.object.convert(target='MESH');return o
def ring(name,pos,r,thick,m):
 bpy.ops.mesh.primitive_torus_add(major_segments=64,minor_segments=8,major_radius=r,minor_radius=thick,location=pt(pos));o=bpy.context.object;o.rotation_euler[1]=math.pi/2;return finish(o,name,m,0,True)
def group(name,pos,objects):
 o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);o.location=pt(pos);bpy.context.view_layer.update()
 for child in objects:
  world=child.matrix_world.copy();child.parent=o;child.matrix_world=world
 return o
def batch():
 for m in list(bpy.data.materials):
  for parent in {o.parent for o in bpy.context.scene.objects if o.type=='MESH'}:
   obs=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.parent==parent and len(o.data.materials)==1 and o.data.materials[0]==m]
   if not obs:continue
   bpy.ops.object.select_all(action='DESELECT')
   for o in obs:o.select_set(True)
   bpy.context.view_layer.objects.active=obs[0];bpy.ops.object.join();obs[0].name=m.name
def export(name):
 batch();bpy.ops.object.select_all(action='SELECT');bpy.ops.export_scene.gltf(filepath=str(R/'assets/props'/name),export_format='GLB',use_selection=True,export_apply=True,export_animations=False)
clean()
enamel=mat('ProjectorEnamel',(.16,.28,.245),.69,.4);edge=mat('PaintEdge',(.30,.39,.35),.65,.5)
alloy=mat('ReelAlloy',(.48,.51,.48),.39,.85);steel=mat('MechanismSteel',(.23,.25,.24),.34,.85)
black=mat('Bakelite',(.014,.019,.017),.38);film=mat('FilmStock',(.055,.039,.026),.7)
glass=mat('CoatedLens',(.055,.105,.11),.08,.45);rust=mat('Oxide',(.16,.085,.04),.9,.2)
box('CastBase',(0,.035,.065),(.37,.07,.57),enamel,.018)
for x in [-.13,.13]:
 for z in [-.14,.29]:cyl('LevelFoot',(x,.013,z),.024,.025,black,(0,1,0))
box('MotorHousing',(-.015,.265,.10),(.275,.37,.38),enamel,.035)
box('LowerHousing',(-.015,.115,.10),(.285,.10,.41),enamel,.012)
box('ServiceCover',(.132,.27,.11),(.012,.29,.30),edge,.008)
for i in range(12):box('CoolingSlot',(-.02,.15+i*.018,.295),(.18,.005,.006),black,.001)
for y in [.15,.38]:
 for z in [-.02,.23]:cyl('Screw',(.143,y,z),.005,.004,steel)
cyl('MotorCover',(.15,.15,.14),.079,.023,black)
ring('MotorRing',(.163,.15,.14),.067,.004,steel)
for i in range(8):box('MotorVent',(.164,.104+i*.013,.14),(.004,.004,.104),black,.001)
beam('RearReelArm',(0,.34,.21),(0,.405,.54),.064,.025,enamel)
beam('UpperReelArm',(0,.39,-.07),(0,.78,-.20),.065,.027,enamel)
for p in [(0,.34,.21),(0,.39,-.07)]:cyl('ArmPivot',p,.035,.048,alloy)
def reel(name,center,r,roll):
 before=set(bpy.context.scene.objects);c=Vector(center)
 cyl('FilmSpool',center,roll,.026,film)
 for off in [-.020,.020]:
  cc=c+Vector((off,0,0));ring('SpoolRim',cc,r,.0055,alloy);ring('InnerRim',cc,r-.009,.0025,steel)
  cyl('SpoolHub',cc,.031,.007,alloy)
  for i in range(5):
   a=i*math.tau/5+.18;d=Vector((0,math.sin(a),math.cos(a)));beam('FlatSpoke',cc+d*.025,cc+d*(r-.006),.027,.006,alloy)
 for radius in [roll-.003,roll-.007,roll-.011]:ring('FilmWinding',c+Vector((.014,0,0)),radius,.0007,steel)
 cyl('AxleCap',c+Vector((.033,0,0)),.012,.025,black)
 group(name,center,[o for o in bpy.context.scene.objects if o not in before])
reel('ReelUpper',(0,.79,-.20),.185,.128)
reel('ReelRear',(0,.405,.57),.14,.063)
# Exposed film gate, capstan rollers and narrow film path on the operator side.
box('GatePlate',(.155,.253,-.13),(.02,.28,.20),steel,.007)
for y,z,r in [(.40,-.09,.028),(.35,-.18,.024),(.32,-.07,.018),(.15,-.11,.025),(.11,-.20,.022),(.19,-.23,.019)]:
 cyl('FilmRoller',(.18,y,z),r,.032,alloy);cyl('RollerPin',(.20,y,z),r*.24,.006,black)
curve('FilmPath',[(.177,.76,-.08),(.177,.40,-.062),(.177,.35,-.155),(.177,.30,-.155),(.177,.18,-.155),(.177,.15,-.084),(.177,.095,-.185),(.177,.07,.03),(.01,.34,.57)],.0033,film)
box('FilmGate',(.192,.26,-.17),(.041,.106,.04),black,.006)
for y in [.215,.305]:cyl('GateScrew',(.215,y,-.17),.004,.004,alloy)
for r,h,z in [(.047,.045,-.235),(.039,.065,-.285),(.042,.014,-.325)]:cyl('LensHousing',(.14,.255,z),r,h,black,(0,0,1))
for z in [-.282,-.287,-.292,-.297,-.302]:cyl('FocusKnurl',(.14,.255,z),.040,.0015,steel,(0,0,1))
cyl('LensGlass',(.14,.255,-.334),.034,.002,glass,(0,0,1))
group('LensOrigin',(.14,.255,-.336),[])
for y,z in [(.12,-.02),(.08,.25),(.30,.24)]:
 cyl('ControlKnob',(.18,y,z),.019,.032,black);cyl('KnobCentre',(.198,y,z),.004,.003,alloy)
curve('CarryHandle',[(-.08,.452,.05),(-.08,.49,.05),(.08,.49,.05),(.08,.452,.05)],.009,black)
curve('PowerCable',[(-.09,.10,.30),(-.18,.02,.41),(-.32,.01,.54),(-.35,.01,.70),(-.43,-.02,.76)],.005,black)
random.seed(707)
for i in range(32):
 box('PaintChip',(.142,random.uniform(.15,.38),random.uniform(-.02,.25)),(.001,random.uniform(.001,.004),random.uniform(.003,.014)),rust,.0003)
export('projector_v07.glb')
clean()
steel=mat('BluedSteel',(.055,.071,.077),.3,.8);edge=mat('MachinedSteel',(.21,.23,.24),.28,.88);black=mat('Bore',(.003,.004,.005),.8);wood=mat('WalnutGrip',(.11,.048,.023),.6);screw=mat('GripScrew',(.38,.39,.37),.35,.85)
box('GripCore',(0,-.009,-.008),(.026,.084,.043),steel,.007)
for side in [-1,1]:
 ob=box('GripPanel',(side*.015,-.01,-.01),(.007,.079,.043),wood,.006);ob.rotation_euler[0]=.13
 cyl('GripScrew',(side*.02,-.008,-.008),.003,.003,screw)
 for j in range(13):box('Checkering',(side*.019,-.035+j*.004,-.01),(.001,.0008,.028),black,.0002)
box('Receiver',(0,.036,.008),(.030,.040,.077),steel,.008)
cyl('Cylinder',(0,.051,.020),.024,.043,steel,(0,0,1))
for i in range(6):
 a=i*math.tau/6;cyl('Chamber',(math.cos(a)*.014,.051+math.sin(a)*.014,.043),.005,.002,black,(0,0,1),20)
cyl('Barrel',(0,.056,.107),.011,.132,steel,(0,0,1))
cyl('MuzzleLip',(0,.056,.174),.0115,.004,edge,(0,0,1));cyl('MuzzleBore',(0,.056,.177),.007,.001,black,(0,0,1))
cyl('EjectorRod',(.011,.037,.103),.003,.115,steel,(0,0,1))
box('FrontSight',(0,.071,.158),(.003,.010,.012),edge,.001)
box('RearSight',(0,.072,-.005),(.014,.006,.012),edge,.001)
box('Hammer',(0,.065,-.042),(.009,.021,.020),steel,.003)
curve('TriggerGuard',[(0,.026,.035),(0,.013,.055),(0,-.012,.054),(0,-.020,.025),(0,-.009,.006)],.0025,steel)
curve('Trigger',[(0,.024,.029),(0,.005,.027),(0,-.004,.021)],.002,edge)
for side in [-1,1]:
 for y,z in [(.04,-.018),(.021,.002)]:cyl('FrameScrew',(side*.017,y,z),.002,.0015,screw)
export('revolver_v07.glb')
print('EQUIPMENT_READY')
