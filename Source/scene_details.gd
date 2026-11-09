extends RefCounted

static func wallpaper(g, ceiling: bool = false) -> ShaderMaterial:
	var material = ShaderMaterial.new()
	material.shader = load("res://wallpaper.gdshader")
	material.set_shader_parameter("plaster",load("res://assets/materials/concrete_wall_006_diff.jpg"))
	material.set_shader_parameter("plaster_normal",load("res://assets/materials/concrete_wall_006_nor_gl.jpg"))
	material.set_shader_parameter("ceiling",ceiling)
	return material

static func build(g) -> void:
	var world = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("080807")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("8c9aab")
	env.ambient_light_energy = .045
	env.ssao_enabled = true
	env.ssao_radius = .55
	env.ssao_intensity = 1.35
	env.ssil_enabled = true
	env.ssil_intensity = .35
	env.sdfgi_enabled = true
	env.sdfgi_cascades = 4
	env.sdfgi_min_cell_size = .20
	env.sdfgi_use_occlusion = true
	env.sdfgi_read_sky_light = false
	env.sdfgi_energy = .40
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = .012
	env.volumetric_fog_albedo = Color("8a9087")
	env.volumetric_fog_length = 12
	env.volumetric_fog_ambient_inject = .0
	env.glow_enabled = true
	env.glow_intensity = .32
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	world.environment = env
	g.add_child(world)
	var wall = wallpaper(g)
	var ceiling = wallpaper(g,true)
	var floor_mat = g._surface("concrete_floor_02",Color("8a8072"),Vector3(4,4,1))
	var wood = g._surface("wood_planks_dirt",Color("8b7560"),Vector3(1.6,1,1))
	wood.roughness = .42
	var metal = g._mat(Color("272824"),.45)
	var rust = g._mat(Color("4c3e30"),.9)
	g._box(Vector3(5.4,.16,7),Vector3(0,-.08,-.1),floor_mat)
	g._box(Vector3(.16,2.8,7),Vector3(2.7,1.4,-.1),wall)
	# A real opening through the basement wall; exterior geometry can be seen through it.
	g._box(Vector3(.16,2.02,7),Vector3(-2.7,1.01,-.1),wall)
	g._box(Vector3(.16,.26,7),Vector3(-2.7,2.67,-.1),wall)
	g._box(Vector3(.16,.52,2.15),Vector3(-2.7,2.28,-2.525),wall)
	g._box(Vector3(.16,.52,3.35),Vector3(-2.7,2.28,1.725),wall)
	g._box(Vector3(5.4,2.8,.16),Vector3(0,1.4,-3.6),wall)
	g._box(Vector3(5.4,.15,7),Vector3(0,2.82,-.1),ceiling)
	# Broken plaster follows the ceiling; only the torn edges curl downward.
	var rng = RandomNumberGenerator.new()
	rng.seed = 411
	for i in range(22):
		var sheet=SurfaceTool.new()
		sheet.begin(Mesh.PRIMITIVE_TRIANGLES)
		var outline: Array[Vector3]=[]
		var radius=rng.randf_range(.07,.22)
		for j in range(9):
			var angle=j*TAU/9
			var r=radius*rng.randf_range(.65,1.15)
			outline.append(Vector3(cos(angle)*r,-maxf(0,cos(angle))*.018,sin(angle)*r))
		for j in range(9):
			for v in [Vector3.ZERO,outline[(j+1)%9],outline[j]]:
				sheet.add_vertex(v)
		sheet.generate_normals()
		var flake=MeshInstance3D.new()
		flake.mesh=sheet.commit()
		flake.material_override=g._mat(Color("514e45"))
		flake.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flake.position=Vector3(rng.randf_range(-2.5,2.5),2.743,rng.randf_range(-3.3,2.7))
		g.add_child(flake)
	# Closed door; it opens after the final sequence.
	g._box(Vector3(1.15,2.25,.14),Vector3(-2.0,1.125,-3.45),metal)
	g.door = Node3D.new()
	g.door.position = Vector3(-2.55,0,-3.34)
	g.add_child(g.door)
	g._box(Vector3(1.04,2.15,.07),Vector3(.52,1.075,0),wood,g.door)
	g._sphere(Vector3(.035,.035,.04),Vector3(.91,1.05,.07),metal,g.door)
	# Supplied reference poster textures on the right wall.
	for i in range(3):
		var poster = MeshInstance3D.new()
		var quad = QuadMesh.new()
		quad.size = Vector2(.65,.98)
		poster.mesh = quad
		var mat = g._mat(Color("b5a38c"))
		mat.albedo_texture = load("res://assets/projection/poster_%d.jpg"%i)
		poster.material_override = mat
		poster.position = Vector3(2.60,1.62,-2.7+i*.83)
		poster.rotation.y = -PI/2
		g.add_child(poster)
	# Low sideboard and a few metal film cans.
	g._box(Vector3(.6,.56,1.7),Vector3(2.22,.28,-1.8),wood)
	for i in range(7):
		g._cylinder(.18,.045,Vector3(2.15,.59+i*.045,-2.08),metal)
	# Modelled table and projector share a consistent real-world scale.
	var props = load("res://assets/props/room_props.glb").instantiate()
	props.name = "DetailedRoomProps"
	g.add_child(props)
	for part in props.find_children("*","MeshInstance3D",true,false):
		for i in range(part.mesh.get_surface_count()):
			var source = part.mesh.surface_get_material(i)
			if not source is StandardMaterial3D:continue
			var material = source.duplicate()
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			if "AgedOak" in String(source.resource_name):
				material.albedo_color = Color("85765e")
				material.roughness = .82
				material.normal_scale = .3
			elif "Steel" in String(source.resource_name):
				material.roughness = .54
			part.set_surface_override_material(i,material)
	var water = g._mat(Color(.12,.11,.09,.30),.16)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var popcorn=load("res://assets/props/popcorn_v09.glb").instantiate()
	popcorn.name="DetailedPopcorn";g.add_child(popcorn)
	var mount=Node3D.new();mount.name="KakVKinoPoster";mount.position=Vector3(2.598,1.52,.48);mount.rotation.y=-PI/2;g.add_child(mount)
	var tilted=Node3D.new();tilted.rotation.z=deg_to_rad(-4.5);mount.add_child(tilted)
	g._box(Vector3(.72,1.08,.002),Vector3.ZERO,g._mat(Color("c7b99b")),tilted)
	var picture=MeshInstance3D.new();var paper=QuadMesh.new();paper.size=Vector2(.72,1.08);picture.mesh=paper;picture.position.z=.002
	var printed=g._mat(Color("e0d1b6"),.98);printed.albedo_texture=load("res://assets/projection/kak_v_kino.png");printed.metallic_specular=.05;picture.material_override=printed;tilted.add_child(picture)
	var tape=g._mat(Color(.57,.52,.38,.48),.82);tape.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	for p in [Vector3(-.25,.49,.006),Vector3(.28,.48,.006),Vector3(-.28,-.49,.006),Vector3(.29,-.48,.006)]:
		var strip=g._box(Vector3(.065,.17,.001),p,tape,tilted);strip.rotation.z=deg_to_rad(-22 if p.x<0 else 24)
	# The projected still is scene geometry, not an overlay.
	g.projected_frame = MeshInstance3D.new()
	var screen_quad = QuadMesh.new()
	screen_quad.size = Vector2(2.58,1.72)
	g.projected_frame.mesh = screen_quad
	g.projection_material = ShaderMaterial.new()
	g.projection_material.shader = load("res://projection.gdshader")
	g.projection_material.set_shader_parameter("frame_tex",load("res://assets/projection/nosferatu.png"))
	g.projected_frame.material_override = g.projection_material
	g.projected_frame.position = Vector3(.30,1.56,-3.505)
	g.projected_frame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(g.projected_frame)
	g.projected_frame.visible = false
	g.dynamics = preload("res://room_dynamics.gd").new()
	g.add_child(g.dynamics)
	g.dynamics.build(g)
	var cactus = load("res://assets/props/broken_cactus_v08.glb").instantiate()
	cactus.name = "BrokenCactusPot"
	cactus.position = Vector3(1.70,0,1.0)
	g.add_child(cactus)
	for part in cactus.find_children("*","MeshInstance3D",true,false):
		for surface in range(part.mesh.get_surface_count()):
			var original = part.mesh.surface_get_material(surface)
			if not original is StandardMaterial3D:continue
			var name = String(original.resource_name)
			if name in ["DampPottingSoil","DrySoilGrains"]:
				var textured = g._surface("concrete_floor_02",Color("81715f"),Vector3.ONE*7)
				textured.uv1_triplanar = true
				textured.uv1_world_triplanar = true
				textured.normal_scale = .15
				textured.roughness_texture = null
				textured.roughness = 1.0
				textured.metallic_specular = .06
				part.set_surface_override_material(surface,textured)
			elif "Terracotta" in name:
				var clay = g._mat(Color("ae7957") if name == "TerracottaBrokenEdge" else Color("855236"),.95)
				clay.metallic_specular = .1
				part.set_surface_override_material(surface,clay)
	# Only static architecture contributes to GI. Reels, people and the fly stay dynamic.
	for part in g.find_children("*","MeshInstance3D",true,false):
		if g.dynamics.is_ancestor_of(part) or part == g.projected_frame:continue
		part.gi_mode = GeometryInstance3D.GI_MODE_STATIC
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# Falling water and a damp patch below the leak.
	for i in range(1):
		var drop = g._sphere(Vector3(.004,.018,.004),Vector3(2.35,2.3,-.45),g._mat(Color("777f7d"),.13))
		g.water_drips.append(drop)
	g._cylinder(.31,.002,Vector3(2.35,.003,-.45),water)

static func chair(g) -> void:
	var wood = g._surface("wood_planks_dirt",Color("66523c"),Vector3.ONE)
	var rope = g._mat(Color("a58c62"),.96)
	var chair = Node3D.new()
	chair.name = "PlayerChair"
	g.add_child(chair)
	g._box(Vector3(.64,.07,.62),Vector3(0,.51,1.67),wood,chair)
	for x in [-.29,.29]:
		for z in [1.36,1.96]:
			g._box(Vector3(.055,.51,.055),Vector3(x,.255,z),wood,chair)
		g._box(Vector3(.055,1.05,.055),Vector3(x,.84,1.96),wood,chair)
	for y in [.65,.91,1.17]:
		g._box(Vector3(.6,.09,.045),Vector3(0,y,1.96),wood,chair)
	var fitted_rope = load("res://assets/props/player_ropes_v08.glb").instantiate()
	fitted_rope.name = "BodyFittedBindings"
	chair.add_child(fitted_rope)
