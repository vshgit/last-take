extends Node3D

const WINDOW_BOTTOM = 2.02
const PAVEMENT_HEIGHT = 1.97
var g
var projector: Node3D
var reels: Array[Node3D] = []
var lens: Node3D
var fly: Node3D
var wings: Array[MeshInstance3D] = []
var passers: Array[Node3D] = []
var glass: MeshInstance3D
var grate: Node3D
var window_light: SpotLight3D
var beam: MeshInstance3D
var window_beam:MeshInstance3D
var window_shadows:MeshInstance3D
var passer_phases:Array[float]=[-1.0,-1.0]
var passer_starts:Array[float]=[11.0,33.0]
var passer_durations:Array[float]=[1.05,1.20]
var motion_rng=RandomNumberGenerator.new()
var last_clock=0.0
var fly_target=Vector3.ZERO
var fly_velocity=Vector3.ZERO
var fly_change_at=0.0

func build(game) -> void:
	g=game
	motion_rng.randomize()
	_build_window()
	_build_projector()
	_build_bulb()

func _build_window() -> void:
	var frame_mat=g._mat(Color("333b36"),.72)
	for y in [2.0,2.56]:
		g._box(Vector3(.22,.065,1.64),Vector3(-2.69,y,-.7),frame_mat,self,true)
	for z in [-1.49,.09]:
		g._box(Vector3(.22,.56,.055),Vector3(-2.69,2.28,z),frame_mat,self,true)
	var glass_mat=g._mat(Color(.38,.47,.44,.19),.32)
	glass_mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	glass=g._box(Vector3(.008,.52,1.50),Vector3(-2.69,2.28,-.7),glass_mat,self)
	glass.name="CrackedGlass"
	window_shadows=MeshInstance3D.new();window_shadows.name="WindowPasserShadows"
	var shadow_quad=QuadMesh.new();shadow_quad.size=Vector2(1.50,.52);window_shadows.mesh=shadow_quad
	var shadow_material=ShaderMaterial.new();shadow_material.shader=load("res://window_shadows.gdshader")
	window_shadows.material_override=shadow_material;window_shadows.position=Vector3(-2.676,2.28,-.7);window_shadows.rotation.y=PI/2
	window_shadows.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(window_shadows)
	grate=Node3D.new()
	grate.name="ExteriorGrate"
	add_child(grate)
	grate.position.x=-2.84
	for i in range(9):
		g._box(Vector3(.025,.54,.022),Vector3(0,2.28,-1.42+i*.18),frame_mat,grate,true)
	for y in [2.10,2.47]:
		g._box(Vector3(.025,.025,1.5),Vector3(0,y,-.7),frame_mat,grate,true)
	var crack_mat=g._mat(Color(.65,.70,.65,.52),.6)
	crack_mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	var rng=RandomNumberGenerator.new()
	rng.seed=727
	for center in [Vector2(2.31,-.92),Vector2(2.14,-.28)]:
		for i in range(9):
			var a=i*TAU/9+rng.randf_range(-.18,.18)
			var last=center
			for j in range(1,5):
				var p=center+Vector2(sin(a),cos(a))*j*.065+Vector2(rng.randf_range(-.016,.016),rng.randf_range(-.014,.014))
				p.x=clampf(p.x,2.025,2.535)
				p.y=clampf(p.y,-1.445,.045)
				g._rod(Vector3(-2.681,last.x,last.y),Vector3(-2.681,p.x,p.y),.0008,crack_mat,self)
				if j==2:
					var branch=p+Vector2(sin(a+.6),cos(a+.6))*.07
					branch.x=clampf(branch.x,2.025,2.535)
					branch.y=clampf(branch.y,-1.445,.045)
					g._rod(Vector3(-2.681,p.x,p.y),Vector3(-2.681,branch.x,branch.y),.0006,crack_mat,self)
				last=p
	var paving=g._surface("concrete_floor_02",Color("64706e"),Vector3(2,3,1))
	g._box(Vector3(2,.12,7),Vector3(-3.75,PAVEMENT_HEIGHT-.06,-.2),paving,self,true)
	var outside=g._mat(Color("89989e"),.98)
	outside.emission_enabled=true
	outside.emission=Color("596b75")
	outside.emission_energy_multiplier=.5
	g._box(Vector3(.15,1.4,7),Vector3(-4.65,2.45,-.2),outside,self,true)
	for k in range(2):
		var walker=Node3D.new()
		walker.name="PassingLegs%d"%k
		add_child(walker)
		var cloth=g._mat(Color("151b20"),.94)
		for side in [-1,1]:
			var leg=Node3D.new()
			walker.add_child(leg)
			leg.position=Vector3(side*.10,.60,0)
			g._sphere(Vector3(.069,.32,.074),Vector3(0,-.27,0),cloth,leg)
			g._box(Vector3(.13,.09,.25),Vector3(0,-.55,-.045),g._mat(Color("111514"),.68),leg,true)
		for part in walker.find_children("*","MeshInstance3D",true,false):part.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		passers.append(walker)
	window_light=SpotLight3D.new()
	window_light.position=Vector3(-3.65,2.72,-.70)
	window_light.light_color=Color("a6bdcc")
	window_light.light_energy=1.4
	window_light.spot_range=6
	window_light.spot_angle=23
	window_light.shadow_enabled=true
	window_light.light_size=.10
	window_light.light_volumetric_fog_energy=2.5
	add_child(window_light)
	window_light.look_at(Vector3(-.35,.04,-.50))
	window_beam=MeshInstance3D.new();var shaft=CylinderMesh.new()
	var source=Vector3(-2.66,2.28,-.7);var destination=Vector3(-.35,.04,-.50)
	shaft.top_radius=.10;shaft.bottom_radius=.34;shaft.height=source.distance_to(destination);shaft.cap_top=false;shaft.cap_bottom=false
	window_beam.mesh=shaft;var material=ShaderMaterial.new();material.shader=load("res://projector_beam.gdshader");material.set_shader_parameter("strength",.010)
	window_beam.material_override=material;window_beam.position=(source+destination)*.5
	window_beam.quaternion=Quaternion(Vector3.DOWN,(destination-source).normalized());window_beam.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(window_beam)

func _build_projector() -> void:
	projector=load("res://assets/props/projector_v09.glb").instantiate()
	projector.name="FilmProjector"
	add_child(projector)
	projector.position=Vector3(.88,.867,.13)
	projector.scale=Vector3.ONE*.72
	projector.rotation.y=.22
	for n in ["ReelUpper","ReelRear"]:
		reels.append(projector.find_child(n,true,false))
	lens=projector.find_child("LensOrigin",true,false)
	g.projector_fill=SpotLight3D.new()
	add_child(g.projector_fill)
	g.projector_fill.global_position=lens.global_position
	g.projector_fill.light_color=Color("d1d5ce")
	g.projector_fill.light_energy=0
	g.projector_fill.spot_range=5.0
	g.projector_fill.spot_angle=21
	g.projector_fill.spot_attenuation=1.2
	g.projector_fill.shadow_enabled=true
	g.projector_fill.light_size=.025
	g.projector_fill.light_volumetric_fog_energy=4.0
	g.projector_fill.look_at(g.projected_frame.global_position)
	# A faint dust volume remains visible on the Compatibility fallback as well.
	beam=MeshInstance3D.new()
	var cone=CylinderMesh.new()
	var length=lens.global_position.distance_to(g.projected_frame.global_position)
	cone.top_radius=.025
	cone.bottom_radius=1.42
	cone.height=length
	cone.radial_segments=48
	cone.cap_top=false
	cone.cap_bottom=false
	beam.mesh=cone
	var m=ShaderMaterial.new()
	m.shader=load("res://projector_beam.gdshader")
	beam.material_override=m
	beam.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beam)
	beam.global_position=(lens.global_position+g.projected_frame.global_position)*.5
	beam.quaternion=Quaternion(Vector3.DOWN,(g.projected_frame.global_position-lens.global_position).normalized())
	beam.visible=false

func _build_bulb() -> void:
	var metal=g._mat(Color("282b27"),.55)
	var p=Vector3(0,2.40,1.55)
	g._rod(Vector3(0,2.75,1.55),p+Vector3(0,.10,0),.004,metal,self)
	g._cylinder(.024,.07,p+Vector3(0,.077,0),metal,self)
	var glow=g._mat(Color("ffe3b0"),.16)
	glow.emission_enabled=true
	glow.emission=Color("ffd392")
	glow.emission_energy_multiplier=4
	g.bulb_mesh=g._sphere(Vector3(.034,.052,.034),p,glow,self)
	g.bulb_mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.key_light=OmniLight3D.new()
	g.key_light.position=p
	g.key_light.light_color=Color("ffdbad")
	g.key_light.light_energy=2.8
	g.key_light.omni_range=3.35
	g.key_light.omni_attenuation=1.35
	g.key_light.shadow_enabled=true
	g.key_light.shadow_bias=.025
	g.key_light.shadow_normal_bias=.45
	g.key_light.light_size=.045
	g.key_light.light_indirect_energy=.30
	g.key_light.light_volumetric_fog_energy=.25
	add_child(g.key_light)
	fly=Node3D.new()
	fly.name="HouseFly"
	fly.position=p+Vector3(.15,.02,0)
	add_child(fly)
	g._sphere(Vector3(.003,.003,.006),Vector3.ZERO,g._mat(Color("17150f"),.7),fly)
	g._sphere(Vector3(.0025,.0026,.002),Vector3(0,.001,-.006),g._mat(Color("262016"),.5),fly)
	var wing=g._mat(Color(.62,.65,.57,.35),.18)
	wing.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	for side in [-1,1]:
		wings.append(g._sphere(Vector3(.006,.0004,.003),Vector3(side*.005,.002,-.001),wing,fly))

func update(clock:float) -> void:
	var delta=clampf(clock-last_clock,0,.1);last_clock=clock
	for i in range(reels.size()):reels[i].rotation.x=clock*(2.1 if i==0 else 1.35)
	var projecting=g.phase in ["question","correct","retake","menu","victory"]
	g.projected_frame.visible=projecting and g.phase!="menu";beam.visible=projecting
	g.projector_fill.light_energy=(.85+.012*sin(clock*43)) if projecting else 0.0
	beam.material_override.set_shader_parameter("strength",.085 if g.phase=="menu" else .030)
	var t=fmod(clock,19.7);var flicker=1.0
	if g.settings.flicker and t>17.8 and t<18.16:flicker=.89+.06*sin(t*79.0)
	g.key_light.light_energy=2.8*flicker;g.key_light.shadow_enabled=g.settings.shadows
	window_light.shadow_enabled=g.settings.shadows and not g.web_mode
	g.projector_fill.shadow_enabled=g.settings.shadows and not g.web_mode
	g.bulb_mesh.material_override.emission_energy_multiplier=4.0*flicker
	_update_fly(clock,delta)
	var blocked=0.0;var shadow_passage=-1.0
	for i in range(passers.size()):
		if clock>passer_starts[i]+passer_durations[i]:
			passer_starts[i]=clock+motion_rng.randf_range(36,58);passer_durations[i]=motion_rng.randf_range(.95,1.30)
		var walk=(clock-passer_starts[i])/passer_durations[i]
		passer_phases[i]=walk if walk>=0 and walk<1 else -1.0
		passers[i].visible=passer_phases[i]>=0
		if not passers[i].visible:continue
		shadow_passage=walk
		passers[i].position=Vector3(-3.12-i*.12,PAVEMENT_HEIGHT,lerpf(-1.95,.60,walk))
		for j in range(2):passers[i].get_child(j).rotation.x=sin(walk*TAU*1.7+j*PI)*.45
		blocked=maxf(blocked,sin(walk*PI)*.6)
	window_shadows.material_override.set_shader_parameter("passage",shadow_passage)
	window_beam.material_override.set_shader_parameter("strength",.010*(1.0-blocked))
func _update_fly(clock:float,delta:float) -> void:
	if clock>=fly_change_at or fly.position.distance_to(fly_target)<.035:
		fly_target=g.bulb_mesh.position+Vector3(motion_rng.randf_range(-.31,.31),motion_rng.randf_range(-.26,.21),motion_rng.randf_range(-.30,.30))
		if fly_target.distance_to(g.bulb_mesh.position)<.10:fly_target.x+=.14
		fly_change_at=clock+motion_rng.randf_range(.22,.62)
	var desired=(fly_target-fly.position).limit_length(.32)*4.0
	fly_velocity=fly_velocity.lerp(desired,1.0-exp(-delta*9));fly.position+=fly_velocity*delta
	fly.rotation.y=atan2(-fly_velocity.x,-fly_velocity.z)
	for i in range(wings.size()):wings[i].rotation.z=sin(clock*143+i*PI)*.75
