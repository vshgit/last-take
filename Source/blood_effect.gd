extends Node3D
var g
var droplets:Array[Dictionary]=[]
var stains:Array[Node3D]=[]
var age=-1.0
var material:StandardMaterial3D
var rng=RandomNumberGenerator.new()
func build(game) -> void:
	g=game;material=g._mat(Color("6b0d0a"),.53);material.cull_mode=BaseMaterial3D.CULL_DISABLED;rng.seed=909
func reset() -> void:
	age=-1;droplets.clear()
	for n in stains:
		if is_instance_valid(n):n.queue_free()
	stains.clear()
	for n in get_children():n.queue_free()
func burst(origin:Vector3) -> void:
	reset();age=0
	for i in range(38):
		var target=Vector3(clampf(origin.x+rng.randfn(.10,.24),-2.50,-1.0),clampf(origin.y+rng.randfn(.02,.20),.85,2.15),-3.512)
		if i%3==0:target.x=rng.randf_range(-1.40,-1.07)
		var on_door=target.x>=-2.55 and target.x<=-1.51 and target.y<2.15
		if on_door:target.z=-3.298
		var radius=rng.randf_range(.004,.010)
		var node=g._sphere(Vector3(radius,radius*.7,radius),origin,material,self)
		node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		droplets.append({"node":node,"start":origin,"target":target,"duration":rng.randf_range(.13,.29),"hit":false,"radius":radius,"door":on_door})
func update(delta:float) -> void:
	if age<0:return
	age+=delta
	for d in droplets:
		if d.hit:continue
		var t=clampf(age/d.duration,0,1)
		d.node.position=d.start.lerp(d.target,t)+Vector3(0,sin(t*PI)*.035,0)
		if t>=1:
			d.hit=true;d.node.hide();_stain(d.target,d.radius*rng.randf_range(2,4.5),d.door)
func _stain(pos:Vector3,radius:float,on_door:bool) -> void:
	var mesh=SurfaceTool.new();mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	var outline:Array[Vector3]=[]
	for i in range(13):
		var a=i*TAU/13;var r=radius*rng.randf_range(.65,1.25)
		outline.append(Vector3(cos(a)*r,sin(a)*r*.8,0))
	for i in range(13):
		for v in [Vector3.ZERO,outline[i],outline[(i+1)%13]]:mesh.add_vertex(v)
	mesh.generate_normals()
	var stain=MeshInstance3D.new();stain.mesh=mesh.commit();stain.material_override=material
	var parent:Node3D=g.door if on_door else self
	parent.add_child(stain);stain.global_position=pos
	stain.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if on_door:stains.append(stain)
	if rng.randf()<.23:g._rod(Vector3(0,-radius*.3,.001),Vector3(0,-rng.randf_range(.025,.10),.001),.0018,material,stain)
