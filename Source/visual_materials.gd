extends RefCounted

static func skin(prefix: String) -> ShaderMaterial:
	var m = ShaderMaterial.new()
	m.shader = load("res://villain_skin.gdshader" if prefix=="cinemaniac" else "res://skin.gdshader")
	var color_path = "res://assets/character/villain_skin_cc0.png" if prefix == "cinemaniac" else "res://assets/character/player_skin_cc0.png"
	if not ResourceLoader.exists(color_path):
		color_path = "res://assets/character/"+prefix+"_skin_albedo.jpg"
	m.set_shader_parameter("skin_tex",load(color_path))
	var normal_path = "res://assets/character/player_skin_cc0_normal.png" if prefix == "player" else "res://assets/character/cinemaniac_skin_normal.jpg"
	if not ResourceLoader.exists(normal_path):
		normal_path = "res://assets/character/"+prefix+"_skin_normal.jpg"
	m.set_shader_parameter("skin_normal",load(normal_path))
	m.set_shader_parameter("tint",Color("e8e1da"))
	m.set_shader_parameter("normal_strength",.22 if prefix == "cinemaniac" else .38)
	return m

static func fabric(color: Color, dirty: float = .22) -> ShaderMaterial:
	var m=ShaderMaterial.new()
	m.shader=load("res://fabric.gdshader")
	m.set_shader_parameter("cloth_color",color)
	m.set_shader_parameter("grime_amount",dirty)
	return m

static func character(root: Node3D, prefix: String) -> void:
	for part in root.find_children("*","MeshInstance3D",true,false):
		var name = String(part.name).to_lower()
		if name in ["body","base"]:
			part.material_override=skin(prefix)
		elif "robe" in name or "shawl" in name or "cuff" in name:
			var cloth=ShaderMaterial.new();cloth.shader=load("res://robe.gdshader")
			cloth.set_shader_parameter("cloth_color",Color("918574"))
			part.material_override=cloth
			part.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		elif "boxershorts" in name:
			part.material_override=fabric(Color("56574f"),.10)
		elif "referencehairwisps" in name:
			continue
		elif name == "playertshirt":
			part.material_override=fabric(Color("56615f"),.08)
			part.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		else:
			for i in range(part.mesh.get_surface_count()):
				var original=part.mesh.surface_get_material(i)
				if not original is StandardMaterial3D:continue
				var m=original.duplicate()
				m.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
				if prefix=="cinemaniac" and "hair" in name and m.albedo_texture:
					var silver=ShaderMaterial.new();silver.shader=load("res://silver_hair.gdshader")
					silver.set_shader_parameter("hair_tex",m.albedo_texture)
					part.set_surface_override_material(i,silver)
					continue
				if "hair" in name or "eyebrow" in name:
					m.albedo_color=Color("595957") if "hair" in name else Color("403c37")
					m.roughness=.67
					m.metallic_specular=.25
					m.alpha_antialiasing_mode=BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE
				elif "eyelash" in name:
					m.alpha_antialiasing_mode=BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE
				elif "jeans" in name:
					m.albedo_color=Color("354d69") if prefix == "player" else Color("565447")
					m.roughness=.86
					m.normal_enabled=true
					m.normal_scale=.55
				elif "shoes" in name:
					m.roughness=.64
					m.normal_enabled=true
					m.normal_scale=.55
				elif "eyes" in name:
					m.roughness=.18
					m.metallic_specular=.55
				part.set_surface_override_material(i,m)

