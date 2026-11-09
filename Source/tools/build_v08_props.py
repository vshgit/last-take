"""Generate body-fitted rope and the broken cactus pot. Blender 4.0+.
Coordinates are in Godot metres. Ropes follow mesh cross sections plus chair.
"""
import sys
sys.path.insert(0, '/usr/lib/python3.12/lib-dynload')
sys.path.append('/usr/lib/python3/dist-packages')
import bpy, math, random, json
from pathlib import Path
from mathutils import Vector
R = Path(__file__).resolve().parents[1]
rng = random.Random(808)
def pt(p): return Vector((p[0], -p[2], p[1]))
def clean():
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
def mat(name, color, rough=.9):
    m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
    n=m.node_tree.nodes.get('Principled BSDF'); n.inputs['Base Color'].default_value=(*color,1); n.inputs['Roughness'].default_value=rough
    return m
def mesh(name, verts, faces, material, smooth=False):
    data=bpy.data.meshes.new(name); data.from_pydata([pt(p) for p in verts],[],faces);data.update()
    ob=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(ob);data.materials.append(material)
    for face in data.polygons:face.use_smooth=smooth
    return ob
def tube(name, points, radius, material):
    c=bpy.data.curves.new(name,'CURVE');c.dimensions='3D';c.bevel_depth=radius;c.bevel_resolution=1;c.resolution_u=1
    s=c.splines.new('POLY');s.points.add(len(points)-1)
    for v,p in zip(s.points,points):v.co=(*pt(p),1)
    ob=bpy.data.objects.new(name,c);bpy.context.collection.objects.link(ob);c.materials.append(material)
    bpy.ops.object.select_all(action='DESELECT');ob.select_set(True);bpy.context.view_layer.objects.active=ob;bpy.ops.object.convert(target='MESH')
def ellipsoid(name, center, scale, material, segments=16):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=8,location=pt(center));o=bpy.context.object;o.name=name;o.scale=(scale[0],scale[2],scale[1]);o.data.materials.append(material)
    for f in o.data.polygons:f.use_smooth=True
    return o
def batch_export(filename):
    for m in list(bpy.data.materials):
        obs=[o for o in bpy.context.scene.objects if o.type=='MESH' and len(o.data.materials)==1 and o.data.materials[0]==m]
        if not obs:continue
        bpy.ops.object.select_all(action='DESELECT')
        for ob in obs:ob.select_set(True)
        bpy.context.view_layer.objects.active=obs[0];bpy.ops.object.join();obs[0].name=m.name
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=str(R/'assets/props'/filename),export_format='GLB',use_selection=True,export_animations=False,export_apply=True)
clean()
bpy.ops.import_scene.gltf(filepath=str(R/'assets/character/player.glb'))
triangles=[]
for ob in list(bpy.context.scene.objects):
    if ob.type!='MESH':continue
    me=ob.to_mesh();me.calc_loop_triangles()
    points=[]
    for v in me.vertices:
        p=ob.matrix_world@v.co;points.append((p.x,p.z,-p.y))
    for f in me.loop_triangles:triangles.append([points[i] for i in f.vertices])
    ob.to_mesh_clear()
clean()
rope=mat('FrayedHemp',(.36,.265,.15));fiber=mat('HempFibres',(.49,.38,.22))
def section(axis, value, predicate=lambda p:True):
    points=[]
    for tri in triangles:
        for a,b in zip(tri,tri[1:]+tri[:1]):
            if (a[axis]-value)*(b[axis]-value)<0:
                t=(value-a[axis])/(b[axis]-a[axis]);p=tuple(a[j]+t*(b[j]-a[j]) for j in range(3))
                if predicate(p):points.append(p)
    return points
def hull(points):
    points=sorted(set((round(p[0],6),round(p[1],6)) for p in points))
    def cross(a,b,c):return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])
    low=[];up=[]
    for p in points:
        while len(low)>1 and cross(low[-2],low[-1],p)<=0:low.pop()
        low.append(p)
    for p in reversed(points):
        while len(up)>1 and cross(up[-2],up[-1],p)<=0:up.pop()
        up.append(p)
    return low[:-1]+up[:-1]
rope_specs=[]
def binding(name, axis, value, anchors, predicate=lambda p:True):
    axes=[i for i in range(3) if i!=axis]
    pts=section(axis,value,predicate)
    assert len(pts)>6,(name,len(pts))
    outline=hull([(p[axes[0]],p[axes[1]]) for p in pts]+anchors)
    # Offset each hull edge by rope radius; intersection gives a taut outer path.
    expanded=[]
    for i,p in enumerate(outline):
        prev=Vector(outline[i-1]);here=Vector(p);nxt=Vector(outline[(i+1)%len(outline)])
        a=(here-prev).normalized();b=(nxt-here).normalized();na=Vector((a.y,-a.x));nb=Vector((b.y,-b.x));bis=(na+nb).normalized()
        expanded.append(here+bis*.008/max(.25,bis.dot(na)))
    path=[]
    for i,a in enumerate(expanded):
        b=expanded[(i+1)%len(expanded)];steps=max(1,int((b-a).length/.008))
        for j in range(steps):
            p=a.lerp(b,j/steps);v=[0.,0.,0.];v[axis]=value;v[axes[0]]=p.x;v[axes[1]]=p.y;path.append(Vector(v))
    path.append(path[0]);tube(name,path,.0058,rope)
    distance=0.;twines=[[],[],[]]
    for i,p in enumerate(path):
        tangent=(path[(i+1)%len(path)]-path[i-1]).normalized()
        n=Vector((0,1,0)) if axis==1 else Vector((0,0,1));side=tangent.cross(n).normalized()
        if i:distance+=(p-path[i-1]).length
        for k in range(3):
            angle=distance*math.tau/.032+k*math.tau/3
            twines[k].append(p+(n*math.cos(angle)+side*math.sin(angle))*.0046)
    for k,twine in enumerate(twines):tube(name+'Twine'+str(k),twine,.0018,fiber)
    rope_specs.append(dict(name=name,axis=axis,position=value,body_intersections=len(pts),hull_points=len(outline),clearance_m=.008,rope_radius_m=.0064))
for y in [.825,.844,.863,1.005,1.024]:
    binding('TorsoToBack',1,y,[(-.318,1.935),(.318,1.935),(-.318,1.99),(.318,1.99)])
for z in [1.435,1.456,1.477]:
    binding('ThighsToSeat',2,z,[(-.32,.475),(.32,.475),(-.32,.545),(.32,.545)])
for side in [-1,1]:
    for y in [.285,.305,.325]:
        binding('CalfToChairLeg',1,y,[(side*.29+dx,1.36+dz) for dx in [-.0275,.0275] for dz in [-.0275,.0275]],lambda p,s=side:p[0]*s>0 and p[2]<1.6)
# Tie wrists together and to the rear slat; actual mesh wrist cross section.
for y in [.625,.644,.663]:
    binding('WristsToBack',1,y,[(-.115,1.982),(.115,1.982)],lambda p:p[2]>1.82 and abs(p[0])<.19)
for x,y,z in [(.327,.55,1.456),(.325,.85,1.97),(-.29,.305,1.393)]:
    for k in range(3):
        tube('BindingKnot',[(x+.013*math.cos(t),y+.009*math.sin(t),z+(k-1)*.012) for t in [j*math.tau/20 for j in range(21)]],.0058,rope)
    tube('ShortRopeTail',[(x,y,z),(x+.023,y-.035,z+.017),(x+.018,y-.075,z+.020)],.0056,rope)
batch_export('player_ropes_v08.glb')
(R/'assets/props/rope_fit.json').write_text(json.dumps(rope_specs,indent=2))
clean()
clay=mat('TerracottaOutside',(.34,.12,.055));inside=mat('TerracottaBrokenEdge',(.51,.245,.12));soil=mat('DampPottingSoil',(.055,.038,.022));soil2=mat('DrySoilGrains',(.105,.072,.04));green=mat('CactusRibs',(.12,.225,.085));dark=mat('CactusFurrows',(.065,.14,.045));spine=mat('CactusSpines',(.64,.59,.40))
# Irregular soil spill with clumps and fine gravel, on the floor rather than a disc.
outline=[(math.cos(i*math.tau/64)*rng.uniform(.23,.35),.001,math.sin(i*math.tau/64)*rng.uniform(.20,.30)) for i in range(64)]
verts=[(0,.023,0)];faces=[]
for ring in range(1,7):
    t=ring/6
    for x,y,z in outline:verts.append((x*t,.001+(1-t)**1.5*.026+rng.uniform(0,.003)*(1-t),z*t))
for i in range(64):faces.append((0,1+(i+1)%64,1+i))
for ring in range(5):
    for i in range(64):
        a=1+ring*64+i;b=1+ring*64+(i+1)%64;c=1+(ring+1)*64+(i+1)%64;d=1+(ring+1)*64+i;faces.append((a,b,c,d))
mesh('SpilledSoil',verts,faces,soil,True)
for i in range(240):
    a=rng.uniform(0,math.tau);r=rng.random()**.6*.34;s=rng.uniform(.003,.013)
    ellipsoid('SoilClump',(math.cos(a)*r,s*.35,math.sin(a)*r),(s,s*.5,s*.8),soil if i%3 else soil2,8)
# Curved pot wall shards, with real thickness and pale fracture edges.
for k in range(7):
    a0=rng.uniform(0,math.tau);span=rng.uniform(.35,1.1);height=rng.uniform(.05,.135);verts=[];faces=[]
    for thickness in [0,.007]:
        for y,r in [(0,.061), (height,.061+height*.32)]:
            for j in range(9):
                a=a0+span*j/8;verts.append(((r-thickness)*math.cos(a),y,(r-thickness)*math.sin(a)))
    for j in range(8):
        faces.extend([(j,j+1,j+10,j+9),(j+18,j+27,j+28,j+19),(j+9,j+10,j+28,j+27)])
    faces.extend([(0,9,27,18),(8,26,35,17)])
    ob=mesh('BrokenPotShard',verts,faces,clay);ob.data.materials.append(inside)
    for i,f in enumerate(ob.data.polygons):
        if i%3 or i>=24:f.material_index=1
    ob.rotation_euler=(rng.uniform(.65,1.65),rng.uniform(-.8,.8),rng.uniform(0,math.tau));ob.location=pt((rng.uniform(-.22,.23),0,rng.uniform(-.18,.25)))
    bpy.context.view_layer.update();minz=min((ob.matrix_world@Vector(c)).z for c in ob.bound_box);ob.location.z+=.005-minz
ellipsoid('RootBall',(.045,.059,-.027),(.068,.053,.056),soil)
# Fallen barrel cactus: ribbed continuous surface, diagonal body lying on soil.
axis=Vector((.76,.19,.62)).normalized();base=Vector((.045,.059,-.027));side=axis.cross(Vector((0,1,0))).normalized();up=side.cross(axis).normalized();verts=[]
for j in range(17):
    f=j/16;radius=.068*(math.sin(math.pi*f)**.38 if j not in [0,16] else .10)
    for i in range(96):
        a=i*math.tau/96;r=radius*(1+.13*math.cos(a*12));p=base+axis*f*.235+(side*math.cos(a)+up*math.sin(a))*r;verts.append(tuple(p))
faces=[]
for j in range(16):
    for i in range(96):faces.append((j*96+i,j*96+(i+1)%96,(j+1)*96+(i+1)%96,(j+1)*96+i))
ob=mesh('FallenRibbedCactus',verts,faces,green,True);ob.data.materials.append(dark)
for j,f in enumerate(ob.data.polygons):
    if j%8 in [3,4]:f.material_index=1
for j in range(2,15,2):
    f=j/16;r=.068*math.sin(math.pi*f)**.38*1.13
    for i in range(12):
        a=i*math.tau/12;n=side*math.cos(a)+up*math.sin(a);p=base+axis*f*.235+n*r
        ellipsoid('Areole',tuple(p),(.0023,.0023,.0023),spine,8)
        for k in [-1,0,1]:tube('Spine',[p,p+n*.012+axis*k*.006],.00045,spine)
for i in range(8):
    a=i*math.tau/8;p=base-axis*.015+side*math.cos(a)*.03+up*math.sin(a)*.03
    tube('ExposedRoot',[p,p-axis*.035+Vector((0,-.025,0)),p-axis*.06+side*.015+Vector((0,-.045,0))],.0013,soil2)
batch_export('broken_cactus_v08.glb')
print('V08_PROPS_BUILT',len(rope_specs),'fitted rope wraps')
