extends Node3D

var data: Dictionary
var question_pool: Array = []
var question_rng = RandomNumberGenerator.new()
var previous_question_ids: Array = []
var voice_meta: Dictionary
var camera: Camera3D
var actor: Node3D
var skeleton: Skeleton3D
var outfit_skeletons: Array[Skeleton3D] = []
var face_meshes: Array[MeshInstance3D] = []
var animation: AnimationPlayer
var face_details: Node3D
var gun: Node3D
var arm_ik: SkeletonIK3D
var gun_target: Node3D
var key_light: OmniLight3D
var actor_bounce: SpotLight3D
var dynamics: Node3D
var grip_local = Transform3D.IDENTITY
var hand_modifier: SkeletonModifier3D
var eyelids: ColorRect
var eyelid_material: ShaderMaterial
const CORNER = Vector3(-1.80,0,-2.45)
const SHADOW_START = Vector3(-2.28,0,-3.08)
const EYE_OPEN_SECONDS = 2.8
const LOOK_SECONDS = 3.0
const EMERGE_SECONDS = 1.8
var bulb_mesh: MeshInstance3D
var door: Node3D
var voice: AudioStreamPlayer3D
var soundscape: Node
var effects: AudioStreamPlayer
var question_audio: AudioStreamPlayer
var phase = "menu"
var previous_phase = ""
var paused_animation_speed = 1.0
var clock = 0.0
var phase_time = 0.0
var intro_index = 0
var question_index = 0
var correct_count = 0
var lives = 3
var timer = 18.0
var next_tick = 18
var voice_id = ""
var web_pointer_callback: JavaScriptObject
var web_start_callback: JavaScriptObject
var web_mode = OS.has_feature("web")
var speech_elapsed = 0.0
var speaking = false
var retake_spoken = false
var shot = false
var death_reason = ""
var yaw = 0.0
var pitch = -0.13
var nod_amount = 0.0
var hovering = -1
var cards: Array[StaticBody3D] = []
var card_root: Node3D
var blink_time = 0.0
var blink_at = 2.3
var projected_frame: MeshInstance3D
var projection_material: ShaderMaterial
var projector_fill: SpotLight3D
var water_drips: Array[MeshInstance3D] = []
var muzzle_flash: OmniLight3D
var shot_flash_time = 0.0
var player_body: Node3D
var settings = {"volume":0.8,"flicker":true,"motion":true,"shadows":true,"ambience":true}
var font: Font
var serif: Font
var ui: Control
var menu: Control
var hud: Control
var question_box: Control
var question_label: Label
var category_label: Label
var timer_label: Label
var progress_label: Label
var retakes_label: Label
var subtitle: Label
var speaker_label: Label
var hint_label: Label
var hover_label: Label
var ending: Control
var ending_title: Label
var ending_copy: Label
var pause_panel: Control
var settings_panel: Control
var fade: ColorRect
var crosshair: Control
var status_label: Label
var fps_label: Label
var screenshot_path = ""
var qa_mode = false
var capture_mode = "question"
var gesture_input=preload("res://gesture_input.gd").new()
var gesture_ready=false
var gesture_cursor=Vector2.ZERO
var blood:Node3D
var doorway_spill:OmniLight3D
var victory_shot_at=-1.0
const FALL_SECONDS=1.05
const VICTORY_HOLD_SECONDS=2.0

func _ready() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string("res://content.json"))
	question_pool = data.questions.duplicate(true)
	question_rng.randomize()
	data.questions = preload("res://question_bank.gd").make_session(question_pool,question_rng)
	if FileAccess.file_exists("res://assets/audio/voice_meta.json"):
		voice_meta = JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/voice_meta.json"))
	font = load("res://assets/sans.ttf")
	serif = load("res://assets/serif.ttf")
	_build_room()
	_build_actor()
	actor_bounce=SpotLight3D.new();actor_bounce.name="TorsoReflectedLight"
	actor_bounce.position=Vector3(-.45,1.18,-.25);add_child(actor_bounce)
	actor_bounce.look_at(CORNER+Vector3(0,.90,.10))
	actor_bounce.light_color=Color("d3c4ac");actor_bounce.light_energy=.75
	actor_bounce.spot_range=4.1;actor_bounce.spot_angle=22
	actor_bounce.spot_angle_attenuation=1.6;actor_bounce.spot_attenuation=1.2
	actor_bounce.light_size=.35;actor_bounce.light_volumetric_fog_energy=0
	actor_bounce.shadow_enabled=true
	blood=preload("res://blood_effect.gd").new();add_child(blood);blood.build(self)
	doorway_spill=OmniLight3D.new();doorway_spill.position=Vector3(-1.8,1.9,-2.9)
	doorway_spill.omni_range=2.2;doorway_spill.light_color=Color("c5c9ba");doorway_spill.light_energy=0
	doorway_spill.shadow_enabled=true;add_child(doorway_spill)
	_build_player_body()
	_build_audio()
	_build_ui()
	camera = Camera3D.new()
	add_child(camera)
	camera.current = true
	camera.position = Vector3(0,1.40,1.55)
	camera.rotation.x = pitch
	camera.fov = 55
	camera.near = 0.025
	camera.far = 35
	_set_menu()
	if web_mode:
		preload("res://web_runtime.gd").configure(self)
		web_pointer_callback = JavaScriptBridge.create_callback(_web_pointer_unlocked)
		web_start_callback = JavaScriptBridge.create_callback(_web_begin)
		JavaScriptBridge.get_interface("window").lastTakePointerUnlocked = web_pointer_callback
		JavaScriptBridge.get_interface("window").lastTakeBegin = web_start_callback
		JavaScriptBridge.eval("document.addEventListener('pointerlockchange',()=>{if(!document.pointerLockElement)window.lastTakePointerUnlocked();});")
		JavaScriptBridge.eval("window.lastTakeGameReady=true;window.dispatchEvent(new Event('lasttake-ready'));")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			screenshot_path = arg.substr(10)
			qa_mode = true
		if arg.begins_with("--capture-mode="):
			capture_mode = arg.substr(15)
		if arg == "--qa":
			qa_mode = true
	if qa_mode and screenshot_path == "":
		_run_checks.call_deferred()
	if screenshot_path != "":
		_capture.call_deferred()

func _mat(color: Color, roughness: float = 0.85) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m

func _surface(name: String, tint: Color, repeat: Vector3) -> StandardMaterial3D:
	var m = _mat(tint)
	m.albedo_texture = load("res://assets/materials/"+name+"_diff.jpg")
	m.normal_enabled = true
	m.normal_texture = load("res://assets/materials/"+name+"_nor_gl.jpg")
	m.normal_scale = 0.7
	m.roughness_texture = load("res://assets/materials/"+name+"_rough.jpg")
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.uv1_scale = repeat
	return m

func _box(size: Vector3, pos: Vector3, material: Material, parent: Node3D = null, shadow: bool = false) -> MeshInstance3D:
	var m = MeshInstance3D.new()
	var shape = BoxMesh.new()
	shape.size = size
	m.mesh = shape
	m.material_override = material
	m.position = pos
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent != null else self).add_child(m)
	return m

func _cylinder(radius: float, height: float, pos: Vector3, material: Material, parent: Node3D = null) -> MeshInstance3D:
	var m = MeshInstance3D.new()
	var shape = CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = height
	shape.radial_segments = 16
	m.mesh = shape
	m.material_override = material
	m.position = pos
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent != null else self).add_child(m)
	return m

func _sphere(size: Vector3, pos: Vector3, material: Material, parent: Node3D = null) -> MeshInstance3D:
	var m = MeshInstance3D.new()
	var s = SphereMesh.new()
	s.radius = 1
	s.height = 2
	s.radial_segments = 20
	s.rings = 12
	m.mesh = s
	m.scale = size
	m.material_override = material
	m.position = pos
	(parent if parent != null else self).add_child(m)
	return m

func _rod(a: Vector3, b: Vector3, radius: float, material: Material, parent: Node3D = null) -> MeshInstance3D:
	var m = _cylinder(radius,a.distance_to(b),(a+b)*0.5,material,parent)
	m.quaternion = Quaternion(Vector3.UP,(b-a).normalized())
	return m

func _build_room() -> void:
	preload("res://scene_details.gd").build(self)

func _sign(text: String, size: Vector2, pos: Vector3, color: Color) -> void:
	_box(Vector3(size.x+.045,size.y+.045,.025),pos-Vector3(0,0,.016),_mat(Color("202a25")))
	var label = Label3D.new()
	label.text = text
	label.font = font
	label.font_size = 48
	var longest = 1
	for line in text.split("\n"):
		longest = maxi(longest,line.length())
	label.pixel_size = minf(size.x/(float(longest)*48*.62),size.y/(float(text.count("\n")+1)*60.0))
	label.position = pos
	label.modulate = color
	label.no_depth_test = false
	label.shaded = true
	label.outline_size = 0
	add_child(label)

func _build_actor() -> void:
	actor = Node3D.new()
	actor.name = "Cinemaniac"
	actor.position = Vector3(0,0,-1.10)
	actor.scale = Vector3.ONE*1.08
	add_child(actor)
	var base = load("res://assets/character/cinemaniac_v10.glb").instantiate()
	actor.add_child(base)
	skeleton = _find_skeleton(base)
	animation = _find_animation(base)
	if animation:
		var names = animation.get_animation_list()
		for a in names:
			if String(a).ends_with("idle_breathe"):
				animation.get_animation(a).loop_mode = Animation.LOOP_LINEAR
				animation.play(a)
	_collect_faces(base)
	preload("res://visual_materials.gd").character(base,"cinemaniac")
	_build_face_details()
	gun = load("res://assets/props/revolver_v07.glb").instantiate()
	gun.name = "HeldRevolver"
	var fitted_hand=load("res://assets/props/gripping_hand_v09.glb").instantiate()
	fitted_hand.name="FittedRightHand";gun.add_child(fitted_hand)
	preload("res://visual_materials.gd").character(fitted_hand,"cinemaniac")
	actor.add_child(gun)
	if skeleton:
		var hand = skeleton.get_bone_global_rest(skeleton.find_bone("hand_r"))
		var middle = skeleton.get_bone_global_rest(skeleton.find_bone("middle_01_r")).origin
		var index = skeleton.get_bone_global_rest(skeleton.find_bone("index_01_r")).origin
		var pinky = skeleton.get_bone_global_rest(skeleton.find_bone("pinky_01_r")).origin
		var front = (middle-hand.origin).normalized()
		var up = (index-pinky).normalized()
		up = (up-front*up.dot(front)).normalized()
		var right = up.cross(front).normalized()
		var grip_rest = Transform3D(Basis(right,up,front),(index+pinky)*.5+right*.013-front*.023+up*.010)
		grip_local = hand.affine_inverse()*grip_rest
		gun_target = Node3D.new()
		actor.add_child(gun_target)
		arm_ik = SkeletonIK3D.new()
		arm_ik.root_bone = "upperarm_r"
		arm_ik.tip_bone = "hand_r"
		skeleton.add_child(arm_ik)
		arm_ik.target_node = arm_ik.get_path_to(gun_target)
		arm_ik.override_tip_basis = true
		arm_ik.use_magnet = true
		arm_ik.magnet = Vector3(-.55,1.25,.20)
		arm_ik.interpolation = 0
		arm_ik.start()
		hand_modifier = preload("res://hand_grip.gd").new()
		skeleton.add_child(hand_modifier)
		hand_modifier.configure(skeleton)
	muzzle_flash = OmniLight3D.new()
	muzzle_flash.light_color = Color("ffd39a")
	muzzle_flash.light_energy = 0
	muzzle_flash.omni_range = 2.5
	gun.add_child(muzzle_flash)
	muzzle_flash.position = Vector3(0,.056,.180)
	if skeleton:
		skeleton.skeleton_updated.connect(_position_gun)

func _position_gun() -> void:
	if not is_instance_valid(gun):return
	var hand_index = skeleton.find_bone("hand_r")
	if hand_index < 0:return
	# One fixed palm-local transform. The revolver cannot drift away from the hand.
	gun.global_transform = skeleton.global_transform*skeleton.get_bone_global_pose(hand_index)*grip_local
	if is_instance_valid(face_details):
		var head = skeleton.find_bone("head")
		face_details.global_transform = skeleton.global_transform*skeleton.get_bone_global_pose(head)*skeleton.get_bone_global_rest(head).affine_inverse()

func _build_face_details() -> void:
	face_details = Node3D.new()
	actor.add_child(face_details)
	var frame = _mat(Color("262b2b"),.27)
	for side in [-1,1]:
		var center = Vector3(side*.033,1.585,.151)
		var lens=MeshInstance3D.new();var quad=QuadMesh.new();quad.size=Vector2(.050,.029)
		lens.mesh=quad;lens.position=center+Vector3(0,0,.001)
		var reflection=ShaderMaterial.new();reflection.shader=load("res://glasses.gdshader")
		lens.material_override=reflection;lens.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		face_details.add_child(lens)
		var previous = Vector3.ZERO
		for i in range(33):
			var a = float(i)*TAU/32
			var p = center+Vector3(signf(cos(a))*pow(absf(cos(a)),.48)*.028,signf(sin(a))*pow(absf(sin(a)),.48)*.017,0)
			if i > 0:
				_rod(previous,p,.0018,frame,face_details)
			previous = p
		_rod(Vector3(side*.067,1.589,.149),Vector3(side*.085,1.593,.025),.0018,frame,face_details)
	_rod(Vector3(-.005,1.589,.151),Vector3(.005,1.589,.151),.0017,frame,face_details)

func _begin_victory() -> void:
	question_audio.stop_question()
	phase = "victory"
	phase_time = 0
	victory_shot_at=-1
	projection_material.set_shader_parameter("frame_tex",load("res://assets/projection/text/blank.jpg"))
	projection_material.set_shader_parameter("content_scale",Vector2.ONE)
	projection_material.set_shader_parameter("show_frame",true)
	shot = false
	_clear_cards()
	question_box.hide()
	timer_label.hide()
	status_label.hide()
	crosshair.hide()
	hover_label.hide()
	hint_label.text = ""
	_speak("win","Окей. Ты свободен.")

func _victory_aiming() -> bool:
	return phase_time >= float(voice_meta.get("win",{}).get("duration",3.0))+.25

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found = _find_skeleton(child)
		if found:
			return found
	return null

func _find_animation(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found = _find_animation(child)
		if found:
			return found
	return null

func _collect_faces(node: Node) -> void:
	if node is MeshInstance3D:
		face_meshes.append(node)
	for child in node.get_children():
		_collect_faces(child)

func _tint_model(node: Node, asset: String) -> void:
	if node is MeshInstance3D:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if asset.begins_with("hair") else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		for surface in range(node.mesh.get_surface_count()):
			var original = node.mesh.surface_get_material(surface)
			if original is StandardMaterial3D:
				var material = original.duplicate()
				if asset == "hair_short02":
					material.albedo_color = Color("969b98")
				elif asset == "clothing_shirt":
					material.albedo_color = Color("66828c")
				elif asset == "clothing_jacket":
					material.albedo_color = Color("29332f")
				elif asset == "clothing_jeans":
					material.albedo_color = Color("383e37")
				material.roughness = .86
				node.set_surface_override_material(surface,material)
	for child in node.get_children():
		_tint_model(child,asset)

func _blend_shape(name: String, value: float) -> void:
	for mesh in face_meshes:
		var i = mesh.find_blend_shape_by_name(name)
		if i >= 0:
			mesh.set_blend_shape_value(i,value)

func _build_player_body() -> void:
	player_body = load("res://assets/character/player.glb").instantiate()
	player_body.name = "BoundPlayer"
	add_child(player_body)
	preload("res://scene_details.gd").chair(self)
	preload("res://visual_materials.gd").character(player_body,"player")

func _build_audio() -> void:
	voice = AudioStreamPlayer3D.new()
	actor.add_child(voice)
	voice.position = Vector3(0,1.57,.16)
	voice.unit_size = 5
	voice.max_distance = 15
	voice.volume_db = -3
	voice.finished.connect(func(): speaking = false)
	question_audio = preload("res://question_audio.gd").new()
	add_child(question_audio)
	soundscape = preload("res://audio_director.gd").new()
	add_child(soundscape)
	soundscape.build(self)
	effects = AudioStreamPlayer.new()
	add_child(effects)
	AudioServer.set_bus_volume_db(0,linear_to_db(settings.volume))

func _set_ambience(enabled: bool) -> void:
	settings.ambience = enabled
	soundscape.set_ambience(enabled)

func _effect(id: String, volume: float = -8.0) -> void:
	effects.stop()
	effects.stream = load("res://assets/audio/"+id+".ogg")
	effects.volume_db = volume
	effects.play()

func _speak(id: String, text: String) -> void:
	soundscape.stop_sniff()
	voice.stop()
	voice_id = id
	speech_elapsed = 0.0
	subtitle.text = text
	subtitle.visible = true
	speaker_label.visible = true
	voice.stream = load("res://assets/audio/"+id+".ogg")
	speaking = voice.stream != null
	if speaking:
		voice.play()

func _label(text: String, size: int, color: Color = Color("d5d3bd"), parent: Node = null) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size",size)
	l.add_theme_color_override("font_color",color)
	l.add_theme_constant_override("outline_size",3)
	l.add_theme_color_override("font_outline_color",Color(0,0,0,.6))
	(parent if parent != null else ui).add_child(l)
	return l

func _button(text: String, callback: Callable, parent: Node) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(270,48)
	b.add_theme_font_size_override("font_size",15)
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color("b9bc9f")
	normal.content_margin_left = 20
	normal.content_margin_right = 20
	var hovered = normal.duplicate()
	hovered.bg_color = Color("dfdec5")
	b.add_theme_stylebox_override("normal",normal)
	b.add_theme_stylebox_override("hover",hovered)
	b.add_theme_color_override("font_color",Color("18241e"))
	b.add_theme_color_override("font_hover_color",Color("18241e"))
	b.pressed.connect(callback)
	parent.add_child(b)
	return b

func _build_ui() -> void:
	var canvas = CanvasLayer.new()
	add_child(canvas)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme = Theme.new()
	theme.default_font = font
	ui.theme = theme
	canvas.add_child(ui)
	var vignette = ColorRect.new()
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader = Shader.new()
	shader.code = "shader_type canvas_item; void fragment(){vec2 p=(UV-vec2(.5))*vec2(1.2,1.0);float a=smoothstep(.24,.79,length(p))*.70;COLOR=vec4(0.0,0.015,0.01,a);}"
	var shader_material = ShaderMaterial.new()
	shader_material.shader = shader
	vignette.material = shader_material
	ui.add_child(vignette)
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(menu)
	var gradient = Gradient.new()
	gradient.colors = PackedColorArray([Color(0.015,.025,.025,.86),Color(0.015,.025,.025,.45),Color(0.015,.025,.025,0)])
	gradient.offsets = PackedFloat32Array([0,.35,1])
	var gradient_texture = GradientTexture2D.new()
	gradient_texture.gradient = gradient
	gradient_texture.fill_from = Vector2(0,0)
	gradient_texture.fill_to = Vector2(1,0)
	var shade = TextureRect.new()
	shade.texture = gradient_texture
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(shade)
	var copy = VBoxContainer.new()
	copy.position = Vector2(85,155)
	copy.size = Vector2(510,420)
	copy.add_theme_constant_override("separation",20)
	menu.add_child(copy)
	_label("ОН УЖЕ ВЫБРАЛ ТЕБЯ",12,Color("929c85"),copy)
	var title = _label("LAST\nTAKE",76,Color("c4c6ad"),copy)
	title.add_theme_font_override("font",serif)
	_label("Ты смотрел тысячи фильмов.\nОн хочет знать, что ты запомнил.",18,Color("a6ad97"),copy)
	_button("НАЧАТЬ СЕАНС     →",_start,copy)
	_button("НАСТРОЙКИ",func(): settings_panel.show(),copy)
	var edition = _label("WINDOWS / 1.0",11,Color("8c977e"),menu)
	edition.position = Vector2(85,660)
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(hud)
	var brand = _label("ПОСЛЕДНИЙ ДУБЛЬ",13,Color("c5c8ad"),hud)
	brand.position = Vector2(32,26)
	progress_label = _label("ВОПРОС 01 / 11",12,Color("9fa98e"),hud)
	progress_label.position = Vector2(32,53)
	retakes_label = _label("ЗАПАСНОЙ ДУБЛЬ: 1",12,Color("b5ad88"),hud)
	retakes_label.position = Vector2(32,78)
	var pause_hint = _label("ESC  ПАУЗА",11,Color("929d85"),hud)
	pause_hint.position = Vector2(1130,30)
	question_box = VBoxContainer.new()
	question_box.position = Vector2(205,100)
	question_box.size = Vector2(870,140)
	hud.add_child(question_box)
	category_label = _label("",11,Color("ba9771"),question_box)
	category_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	question_label = _label("",27,Color("dedcc5"),question_box)
	question_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	question_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	question_label.custom_minimum_size = Vector2(870,100)
	timer_label = _label("18",43,Color("c9c8a9"),hud)
	timer_label.position = Vector2(1160,91)
	crosshair=preload("res://reticle.gd").new();crosshair.mouse_filter=Control.MOUSE_FILTER_IGNORE
	crosshair.position=Vector2(640,360);ui.add_child(crosshair);crosshair.hide()
	speaker_label = _label("КИНОМАН",11,Color("b39569"),hud)
	speaker_label.position = Vector2(300,554)
	speaker_label.size.x = 680
	speaker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle = _label("",22,Color("dedbc3"),hud)
	subtitle.position = Vector2(220,580)
	subtitle.size = Vector2(840,105)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label = _label("",12,Color("a8b096"),hud)
	hint_label.position = Vector2(150,680)
	hint_label.size.x = 980
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hover_label = _label("",19,Color("e0ddbd"),hud)
	hover_label.position = Vector2(190,624)
	hover_label.size = Vector2(900,50)
	hover_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label = _label("",15,Color("c17c59"),hud)
	status_label.position = Vector2(300,315)
	status_label.size.x = 680
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fps_label = _label("",11,Color("99aa8d"))
	fps_label.position = Vector2(32,690)
	fps_label.hide()
	pause_panel = _panel("АНТРАКТ")
	var pause_buttons = pause_panel.get_node("Buttons")
	_button("ПРОДОЛЖИТЬ",_resume,pause_buttons)
	_button("НАСТРОЙКИ",func(): settings_panel.show(),pause_buttons)
	_button("В ГЛАВНОЕ МЕНЮ",_set_menu,pause_buttons)
	_button("ВЫХОД ИЗ ИГРЫ",func(): get_tree().quit(),pause_buttons)
	settings_panel = _panel("НАСТРОЙКИ")
	var settings_box = settings_panel.get_node("Buttons")
	var volume = HSlider.new()
	volume.min_value = 0
	volume.max_value = 1
	volume.step = .05
	volume.value = .8
	volume.custom_minimum_size = Vector2(270,40)
	settings_box.add_child(_make_setting_label("ГРОМКОСТЬ"))
	settings_box.add_child(volume)
	volume.value_changed.connect(func(value): AudioServer.set_bus_volume_db(0,linear_to_db(maxf(value,.001))))
	for item in [["flicker","Мерцание лампочки"],["motion","Дыхание и покачивание камеры"],["shadows","Динамические тени"]]:
		var check = CheckButton.new()
		check.text = item[1]
		check.button_pressed = true
		settings_box.add_child(check)
		check.toggled.connect(func(value): settings[item[0]] = value)
	var ambience_check = CheckButton.new()
	ambience_check.text = "Звуки улицы и комнаты"
	ambience_check.button_pressed = settings.ambience
	settings_box.add_child(ambience_check)
	ambience_check.toggled.connect(_set_ambience)
	_button("ГОТОВО",func(): settings_panel.hide(),settings_box)
	ending = _panel("СЕАНС ОКОНЧЕН")
	ending_title = ending.get_node("Title")
	var ending_buttons = ending.get_node("Buttons")
	ending_copy = _label("",17,Color("a9b296"),ending_buttons)
	ending_copy.custom_minimum_size = Vector2(520,150)
	ending_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ending_copy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_button("ЕЩЁ ОДИН ДУБЛЬ",func(): _start(true),ending_buttons)
	_button("В ГЛАВНОЕ МЕНЮ",_set_menu,ending_buttons)
	fade = ColorRect.new()
	fade.color = Color(0,0,0,0)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(fade)
	eyelids = ColorRect.new()
	eyelids.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	eyelids.mouse_filter = Control.MOUSE_FILTER_IGNORE
	eyelid_material = ShaderMaterial.new()
	eyelid_material.shader = load("res://eyelids.gdshader")
	eyelids.material = eyelid_material
	ui.add_child(eyelids)
	eyelids.hide()

func _make_setting_label(text: String) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size",12)
	return label

func _panel(title: String) -> Control:
	var root = ColorRect.new()
	root.color = Color(.018,.03,.026,.97)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(root)
	var heading = _label(title,45,Color("c5c8ac"),root)
	heading.name = "Title"
	heading.add_theme_font_override("font",serif)
	heading.position = Vector2(280,105)
	heading.size.x = 720
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var buttons = VBoxContainer.new()
	buttons.name = "Buttons"
	buttons.position = Vector2(380,210)
	buttons.size = Vector2(520,420)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation",18)
	root.add_child(buttons)
	root.hide()
	return root

func _set_menu() -> void:
	question_audio.stop_question()
	crosshair.hide()
	blood.reset()
	_reset_gesture()
	phase = "menu"
	soundscape.reset_session()
	effects.stream_paused = false
	voice.stop()
	speaking = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu.show()
	hud.hide()
	ending.hide()
	pause_panel.hide()
	settings_panel.hide()
	fade.color.a = 0
	_clear_cards()
	projection_material.set_shader_parameter("show_frame",false)
	actor.rotation = Vector3.ZERO
	actor.position = CORNER
	eyelids.hide()
	dynamics.update(clock)
	if animation:
		animation.speed_scale = 1

func _start(skip: bool = false) -> void:
	question_audio.stop_question()
	blood.reset()
	_reset_gesture()
	soundscape.reset_session()
	effects.stream_paused = false
	voice.stream_paused = false
	question_audio.stream_paused = false
	data.questions = preload("res://question_bank.gd").make_session(question_pool,question_rng,previous_question_ids)
	previous_question_ids = preload("res://question_bank.gd").ids(data.questions)
	phase = "awakening"
	phase_time = 0
	intro_index = 0
	question_index = 0
	correct_count = 0
	lives = 3
	timer = 18
	shot = false
	yaw = 0
	pitch = -.13
	actor.position = SHADOW_START
	actor.rotation = Vector3.ZERO
	gun_target.position = Vector3(-.24,1.25,.46)
	projection_material.set_shader_parameter("show_frame",false)
	if animation:
		animation.speed_scale = 1
	door.rotation.y = 0
	menu.hide()
	ending.hide()
	pause_panel.hide()
	hud.hide()
	question_box.hide()
	timer_label.hide()
	status_label.hide()
	hover_label.hide()
	crosshair.hide()
	_update_hud()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hint_label.text = "ENTER — пропустить вступление    ·    Мышь — осмотреться"
	voice.stop()
	speaking = false
	subtitle.hide()
	speaker_label.hide()
	fade.color.a = 0
	_clear_cards()
	if skip:
		actor.position = CORNER
		_begin_question()
		return
	eyelid_material.set_shader_parameter("openness",0.0)
	eyelids.show()
	soundscape.breathe(true)

func _intro_line() -> void:
	phase_time = 0
	if intro_index >= data.intro.size():
		_begin_question()
		return
	var line = data.intro[intro_index]
	_speak(line.id,line.text)

func _clear_cards() -> void:
	if is_instance_valid(card_root):
		card_root.queue_free()
	cards.clear()
	hovering = -1

func _begin_question() -> void:
	question_audio.stop_question()
	_reset_gesture()
	soundscape.reset_question()
	if animation:
		animation.speed_scale = 1
	phase = "question"
	eyelids.hide()
	phase_time = 0
	timer = 18
	next_tick = 18
	retake_spoken = false
	status_label.hide()
	hover_label.hide()
	question_box.show()
	timer_label.show()
	crosshair.show()
	yaw = 0
	pitch = -.13
	var q = data.questions[question_index]
	question_label.text = q.text
	category_label.text = q.category.to_upper()
	_update_hud()
	_clear_cards()
	_project_question(q)
	if q.type in ["cards","frame","audio"]:
		card_root = Node3D.new()
		add_child(card_root)
		for i in range(q.options.size()):
			var body = StaticBody3D.new()
			body.position = Vector3((float(i)-1)*.35,.861,.54)
			body.rotation.y = [-.055,.025,-.035][i]
			body.set_meta("answer",i)
			card_root.add_child(body)
			var card = preload("res://cardboard.gd").build(self,load("res://assets/cards/q%02d_%d.jpg"%[int(q.asset_index),i]),i)
			body.add_child(card)
			var collision = CollisionShape3D.new()
			var box = BoxShape3D.new()
			box.size = Vector3(.31,.025,.20)
			collision.shape = box
			body.add_child(collision)
			cards.append(body)
		hint_label.text = "Наведи взгляд и нажми ЛКМ    ·    Или выбери ответ клавишами 1–%d"%q.options.size()
	_effect("paper",-13)
	_speak(q.voice_id,q.text)
	question_audio.start_question(q)
	subtitle.hide()
	speaker_label.hide()

func _update_hud() -> void:
	progress_label.text = "ВОПРОС %02d / %02d"%[mini(question_index+1,data.questions.size()),data.questions.size()]
	retakes_label.text = ""

func _project_question(q:Dictionary) -> void:
	var path:String=q.image if q.type=="frame" else "res://assets/projection/text/"+q.id+".jpg"
	var texture:Texture2D=load(path)
	projection_material.set_shader_parameter("frame_tex",texture)
	var aspect=float(texture.get_width())/texture.get_height()
	projection_material.set_shader_parameter("content_scale",Vector2(minf(1,aspect/1.5),minf(1,1.5/aspect)))
	projection_material.set_shader_parameter("show_frame",true)
	dynamics.update(clock);soundscape.slide_click()
func _reset_gesture() -> void:
	gesture_ready=false;gesture_cursor=Vector2.ZERO;gesture_input.reset()
func _arm_gesture() -> void:
	if not gesture_ready:
		gesture_cursor=Vector2.ZERO;gesture_input.reset();gesture_input.motion(0,0);gesture_ready=true
func _gesture_answering() -> bool:
	return phase=="question" and not speaking and phase_time>.8 and data.questions[question_index].type=="gesture"

func _answer(value: Variant) -> void:
	if phase != "question" or speaking or phase_time < .7:
		return
	var q = data.questions[question_index]
	if int(value) < 0 or int(value) >= q.options.size():
		return
	question_audio.stop_question()
	var correct = int(value) == int(q.correct)
	question_box.hide()
	timer_label.hide()
	hover_label.hide()
	crosshair.hide()
	if correct:
		correct_count += 1
		phase = "correct"
		phase_time = 0
		status_label.text = "ПРИНЯТО"
		status_label.show()
		var line = data.lines[1+question_index%3]
		_speak(line.id,line.text)
	else:
		_lose_life("wrong_v1")

func _lose_life(reason: String) -> void:
	question_audio.stop_question()
	_reset_gesture()
	lives = maxi(0,lives-1)
	if lives == 0:
		_die(reason)
		return
	phase = "retake"
	phase_time = 0
	retake_spoken = false
	if animation: animation.speed_scale = 0
	voice.stop()
	speaking = false
	subtitle.hide()
	speaker_label.hide()
	status_label.hide()

func _next_question() -> void:
	question_audio.stop_question()
	question_index += 1
	if question_index >= data.questions.size(): _begin_victory()
	else: _begin_question()

func _die(reason: String) -> void:
	question_audio.stop_question()
	phase = "death"
	phase_time = 0
	death_reason = reason
	shot = false
	question_box.hide()
	timer_label.hide()
	crosshair.hide()
	hover_label.hide()
	status_label.hide()
	var caption = "Время вышло. Титры." if reason == "timeout" else "Третья ошибка. Сеанс окончен."
	_speak(reason,caption)

func _finish(win: bool) -> void:
	question_audio.stop_question()
	phase = "ended"
	voice.stop()
	speaking = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.hide()
	ending.show()
	fade.color.a = 0
	ending_title.text = "ИЗБРАННЫЙ" if win else "ТИТРЫ"
	var explanation = "«Окей. Ты свободен»." if win else data.questions[question_index].fact
	ending_copy.text = explanation

func _pause() -> void:
	_reset_gesture()
	crosshair.hide()
	if not phase in ["awakening","lookaround","emerge","question","intro","correct","retake","victory","death"]:
		return
	previous_phase = phase
	eyelids.hide()
	phase = "paused"
	voice.stream_paused = true
	question_audio.stream_paused = true
	effects.stream_paused = true
	soundscape.set_paused(true)
	if animation:
		paused_animation_speed = animation.speed_scale
		animation.speed_scale = 0
	pause_panel.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _resume() -> void:
	_reset_gesture()
	if phase != "paused":
		return
	effects.stream_paused = false
	soundscape.set_paused(false)
	phase = previous_phase
	eyelids.visible = phase == "awakening"
	voice.stream_paused = false
	question_audio.stream_paused = false
	if animation:
		animation.speed_scale = paused_animation_speed
	pause_panel.hide()
	settings_panel.hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _web_pointer_unlocked(_args: Array) -> void:
	if not qa_mode:
		_pause()

func _web_begin(_args: Array) -> void:
	_start(false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(voice) and not qa_mode:
		_pause()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if settings_panel.visible:
				settings_panel.hide()
			elif phase == "paused":
				_resume()
			else:
				_pause()
		elif event.keycode == KEY_ENTER and phase in ["awakening","lookaround","emerge","intro"]:
			voice.stop()
			speaking = false
			fade.color.a = 0
			_begin_question()
		elif phase == "question":
			if data.questions[question_index].type in ["cards","frame","audio"] and event.keycode >= KEY_1 and event.keycode <= KEY_3:
				_answer(event.keycode-KEY_1)
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look_motion(event.screen_relative)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and hovering >= 0:
		_answer(hovering)

func _look_motion(relative:Vector2) -> void:
	yaw=clampf(yaw-relative.x*.0017,-1.15,1.15)
	pitch=clampf(pitch-relative.y*.0017,-1.22,1.35)
	if _gesture_answering():
		_arm_gesture()
		gesture_cursor-=relative*.0017
		var answer=gesture_input.motion(gesture_cursor.x,gesture_cursor.y)
		if answer>=0:_answer(answer)

func _process(delta: float) -> void:
	if not is_instance_valid(camera):
		return
	if phase == "paused":
		return
	if web_mode:
		preload("res://web_runtime.gd").update_speech(self,delta)
	if screenshot_path!="" and capture_mode=="window":clock=dynamics.passer_starts[0]+.5-delta
	clock += delta
	phase_time += delta
	if _gesture_answering():
		_arm_gesture()
		gesture_input.update(delta)
	else:_reset_gesture()
	blood.update(delta)
	crosshair.visible=phase in ["lookaround","emerge","intro","question","correct","retake"]
	doorway_spill.light_energy=smoothstep(.1,1.4,phase_time-victory_shot_at)*.65 if phase=="victory" and shot else 0.0
	shot_flash_time = maxf(0,shot_flash_time-delta)
	muzzle_flash.light_energy = 7.0 if shot_flash_time > 0 else 0.0
	if phase == "awakening":
		eyelid_material.set_shader_parameter("openness",smoothstep(.25,EYE_OPEN_SECONDS,phase_time))
		if phase_time >= EYE_OPEN_SECONDS:
			eyelids.hide()
			phase = "lookaround"
			phase_time = 0
	elif phase == "lookaround":
		if phase_time >= LOOK_SECONDS:
			phase = "emerge"
			phase_time = 0
	elif phase == "emerge":
		if phase_time >= EMERGE_SECONDS:
			phase = "intro"
			intro_index = 0
			_intro_line()
	elif phase == "intro":
		var id = data.intro[intro_index].id
		var duration = voice_meta.get(id,{}).get("duration",4.0)
		if phase_time > duration+.35 and not speaking and not (screenshot_path != "" and capture_mode in ["face","gun"]):
			intro_index += 1
			_intro_line()
	elif phase == "question":
		if not speaking and phase_time > .8:
			timer -= delta
			if timer <= 0:
				_lose_life("timeout")
		timer_label.text = "—" if speaking else "%02d"%maxi(0,ceili(timer))
		timer_label.add_theme_color_override("font_color",Color("df795c") if timer <= 5 else Color("c9c8a9"))
	elif phase == "correct":
		if phase_time > 2 and not speaking:
			_next_question()
	elif phase == "retake":
		if phase_time >= 2 and not retake_spoken:
			retake_spoken = true
			_speak("retake","Нет. Будет дубль.")
		if phase_time > 4.8 and retake_spoken and not speaking:
			_next_question()
	elif phase == "death":
		if phase_time >= voice_meta.get(death_reason,{}).get("duration",2.5)+.45 and not shot:
			shot = true
			_effect("shot",-2)
			shot_flash_time = .055
			fade.color = Color(1,.82,.55,.9)
			create_tween().tween_property(fade,"color",Color(0,0,0,1),.22)
		if shot and phase_time > voice_meta.get(death_reason,{}).get("duration",2.5)+1.25:
			_finish(false)
	elif phase == "victory":
		var speech_end = voice_meta.get("win",{}).get("duration",3.0)
		if screenshot_path != "" and capture_mode == "victory":
			phase_time = minf(phase_time,speech_end+1.35)
		if phase_time >= speech_end+1.8 and not speaking and not shot:
			shot = true
			victory_shot_at=phase_time
			blood.burst(skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone("head")).origin)
			shot_flash_time = .065
			_effect("shot",-2)
			subtitle.hide()
			speaker_label.hide()
		if shot:
			door.rotation.y = lerpf(door.rotation.y,-1.1,delta*.6)
		if shot and phase_time-victory_shot_at>=FALL_SECONDS+VICTORY_HOLD_SECONDS:
			_finish(true)

	question_audio.update_mix(delta,speaking)
	_update_camera(delta)
	dynamics.update(clock)
	soundscape.update(delta)
	_update_actor(delta)
	_update_hover()
	if fps_label.visible:
		fps_label.text = "%d FPS  ·  Godot / %s"%[Engine.get_frames_per_second(),RenderingServer.get_current_rendering_method()]

func _update_actor(delta: float) -> void:
	actor.visible = phase not in ["awakening","lookaround"]
	if animation:
		var clip = "walk" if phase == "emerge" else "idle_breathe"
		if not String(animation.current_animation).ends_with(clip):
			for name in animation.get_animation_list():
				if String(name).ends_with(clip):
					animation.get_animation(name).loop_mode = Animation.LOOP_LINEAR
					animation.play(name,.25)
					break
	var target = CORNER
	if phase in ["awakening","lookaround"]:
		target = SHADOW_START
	elif phase == "emerge":
		target = SHADOW_START.lerp(CORNER,smoothstep(0,EMERGE_SECONDS,phase_time))
	if phase == "victory" and shot:
		var fall=smoothstep(0,FALL_SECONDS,phase_time-victory_shot_at)
		target=CORNER+Vector3(.10,.14,-.25)*fall
		actor.rotation.z=-1.40*fall
		if animation:animation.speed_scale=0
	actor.position=target
	actor.rotation.y = atan2(-actor.position.x,1.55-actor.position.z)
	var raise = (phase == "question" and soundscape.gun_raised) or phase == "death" or (phase == "intro" and data.intro[intro_index].action == "gun") or (phase == "victory" and _victory_aiming())
	if arm_ik:
		var palm = Vector3(-.28,1.43,.55)
		var aim = actor.to_local(Vector3(0,1.4,1.55) if screenshot_path != "" else camera.global_position)
		if phase == "victory" and _victory_aiming():
			palm = Vector3(-.24,1.54,.10)
			aim = Vector3(0,1.58,.11)
		var desired = Basis.looking_at((aim-palm).normalized(),Vector3.UP,true)
		gun_target.basis = desired*grip_local.basis.inverse()
		gun_target.position = palm-gun_target.basis*grip_local.origin
		arm_ik.interpolation = move_toward(arm_ik.interpolation,1.0 if raise else 0.0,delta*(1.0 if phase == "question" else 2.2))
	# Sync identical skeletons so clothing follows the body's native idle animation.
	if skeleton:
		for other in outfit_skeletons:
			for i in range(other.get_bone_count()):
				var source_index = skeleton.find_bone(other.get_bone_name(i))
				if source_index >= 0:
					other.set_bone_global_pose_override(i,skeleton.get_bone_global_pose(source_index),1.0,true)
	blink_time += delta
	var blink = maxf(0,1-absf(blink_time-blink_at)/.09)
	if blink_time > blink_at+.11:
		blink_time = 0
		blink_at = randf_range(2.4,5.1)
	_blend_shape("blink_left",blink)
	_blend_shape("blink_right",blink)
	_blend_shape("frown",.85 if phase == "retake" else .16)
	var amount = 0.0
	if speaking and voice_id in voice_meta:
		var envelope = voice_meta[voice_id].envelope
		var frame = int(voice.get_playback_position()*25)
		if frame >= 0 and frame < envelope.size():
			amount = float(envelope[frame])*.85
	nod_amount = lerpf(nod_amount,amount,minf(1,delta*18))
	_blend_shape("mouth_open",nod_amount)

func _update_camera(_delta: float) -> void:
	# Looking down moves the eye slightly forward of the collar, as a neck pivot would.
	var lean = smoothstep(.38,1.15,-pitch)
	camera.position = Vector3(0,1.40+lean*.025,1.55-lean*.16)
	camera.rotation = Vector3(clampf(pitch,-1.22,1.35),yaw,0)
	camera.fov = 55
	if phase == "menu":
		camera.global_position=dynamics.projector.to_global(Vector3(-1.35,.40,.05))
		camera.look_at(dynamics.projector.to_global(Vector3(0,.43,-.30)));camera.fov=53
	if phase=="victory":
		var focus=CORNER+Vector3(.05,1.55,0)
		if shot:focus=focus.lerp(Vector3(-.75,.62,-3.0),smoothstep(0,FALL_SECONDS,phase_time-victory_shot_at))
		camera.look_at(focus)
	if settings.motion and phase not in ["menu","retake","ended"]:
		camera.position.y += sin(clock*1.25)*.0025
		camera.rotation.z = sin(clock*.7)*.0015
	if screenshot_path != "" and capture_mode == "gun":
		camera.global_position = gun.global_position+gun.global_basis.x*.38+gun.global_basis.z*.10+gun.global_basis.y*.12
		camera.look_at(gun.global_position+gun.global_basis.y*.025)
		camera.fov=48
	if screenshot_path!="" and capture_mode in ["model","villain","portrait","model_warning"]:
		camera.global_position=actor.to_global(Vector3(.08,.95,2.65))
		camera.look_at(actor.to_global(Vector3(0,.88,0)));camera.fov=43
		if capture_mode=="portrait":
			camera.global_position=actor.to_global(Vector3(.13,1.60,.82))
			camera.look_at(actor.to_global(Vector3(0,1.59,.02)));camera.fov=35

func _update_hover() -> void:
	if phase != "question" or data.questions[question_index].type not in ["cards","frame","audio"]:
		hovering = -1
		return
	var center = get_viewport().get_visible_rect().size*.5
	var origin = camera.project_ray_origin(center)
	var direction = camera.project_ray_normal(center)
	var query = PhysicsRayQueryParameters3D.create(origin,origin+direction*10)
	var result = get_world_3d().direct_space_state.intersect_ray(query)
	hovering = -1
	if not result.is_empty() and result.collider.has_meta("answer"):
		hovering = int(result.collider.get_meta("answer"))
	for i in range(cards.size()):
		cards[i].position.y = lerpf(cards[i].position.y,.864 if i == hovering else .861,.2)
	if hovering >= 0:
		hover_label.text = "%d · %s"%[hovering+1,data.questions[question_index].options[hovering]]
		hover_label.show()
	else:
		hover_label.hide()

func _capture() -> void:
	_start(true)
	voice.stop()
	speaking=false
	match capture_mode:
		"model","villain","portrait","model_warning":
			timer=4.9 if capture_mode=="model_warning" else 18;phase_time=1
			if capture_mode!="villain":
				var fill=OmniLight3D.new();fill.light_energy=1.3;fill.omni_range=4
				actor.add_child(fill);fill.position=Vector3(-.65,1.9,1)
		"menu":_set_menu()
		"body":pitch=-1.22
		"body_left":
			pitch=-1.22
			yaw=1.15
		"body_right":
			pitch=-1.22
			yaw=-1.15
		"question":
			data.questions[0]=question_pool[0];_begin_question()
		"cards":pitch=-.56
		"cactus":
			yaw=-1.15
			pitch=-.72
		"projector":
			yaw=-.50
			pitch=-.12
		"warning":
			timer=5.0
			phase_time=1
			yaw=.42
		"window":
			yaw=1.15
			pitch=.40
			clock=dynamics.passer_starts[0]
		"bulb":pitch=1.35
		"frame":
			for q in question_pool:
				if q.type=="frame":
					data.questions[0]=q
					break
			_begin_question()
		"gun","face":
			phase="question";timer=4.9;phase_time=1
			if capture_mode=="face":yaw=.42
			if capture_mode=="gun":
				var fill=OmniLight3D.new();fill.light_energy=1.1;fill.omni_range=1.5
				gun.add_child(fill);fill.position=Vector3(.30,.20,.10)
		"gesture","audio":
			for q in question_pool:
				if q.type == capture_mode:
					data.questions[0]=q;break
			_begin_question()
		"modern":
			data.questions[0]=question_pool[40];_begin_question()
		"poster":yaw=-1.15;pitch=.04
		"popcorn":yaw=.40;pitch=-.48
		"aftermath":
			_begin_victory();phase_time=voice_meta.win.duration+1.79
		"victory":
			_begin_victory()
			phase_time=voice_meta.win.duration+.15
		"opening":
			_start(false)
			phase_time=.0
		"lookaround":
			_start(false)
			phase="lookaround"
			eyelids.hide()
	voice.stop()
	speaking=false
	if capture_mode not in ["question","cards","frame","menu"]:
		hud.hide()
	await get_tree().create_timer(1.4 if capture_mode=="opening" else 2.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(screenshot_path)
	print("CAPTURE_SAVED ",screenshot_path)
	await _close_test()

func _close_test() -> void:
	question_audio.stop_question()
	set_process(false)
	voice.stop()
	soundscape.shutdown()
	effects.stop()
	voice.stream = null
	effects.stream = null
	var tree=get_tree()
	tree.create_timer(.20).timeout.connect(tree.quit)
	queue_free()

func _run_checks() -> void:
	var bank = preload("res://question_bank.gd")
	assert(is_instance_valid(skeleton) and is_instance_valid(player_body))
	assert(question_pool.size() == 225)
	assert(soundscape.street.playing and settings.ambience,"Room ambience should start by default")
	var pool_ids = bank.ids(question_pool)
	var unique_ids: Dictionary = {}
	for q in question_pool:
		assert(q.id not in unique_ids)
		unique_ids[q.id] = true
		assert(voice_meta.has(q.voice_id) and voice_meta[q.voice_id].duration > 0)
		assert(ResourceLoader.exists("res://assets/audio/"+q.voice_id+".ogg"))
		if q.type in ["cards","frame","audio"]:
			assert(q.options.size() == 3)
			assert(int(q.correct) >= 0 and int(q.correct) < q.options.size())
			for i in range(q.options.size()):
				var texture = load("res://assets/cards/q%02d_%d.jpg"%[int(q.asset_index),i])
				assert(texture is Texture2D and texture.get_width() == 1024 and texture.get_height() == 640,"An answer card failed to load")
		if q.type == "frame":
			assert(q.options.size() == 3 and ResourceLoader.exists(q.image))
	var rng = RandomNumberGenerator.new()
	rng.seed = 40727
	var previous: Array = []
	var coverage: Dictionary = {}
	for run_index in range(500):
		var selection = bank.make_session(question_pool,rng,previous)
		assert(selection.size() == 21)
		var mixes = [{"cards":0,"frame":0,"gesture":0},{"cards":0,"frame":0,"gesture":0},{"cards":0,"frame":0,"gesture":0,"audio":0}]
		var seen: Dictionary = {}
		for q in selection:
			assert(q.id not in seen and q.id in pool_ids)
			seen[q.id] = true
			coverage[q.id] = true
			mixes[int(q.level)-1][q.type] += 1
			assert(int(q.level) == selection.find(q)/7+1)
		assert(mixes == bank.LEVEL_MIXES)
		var current_ids = bank.ids(selection)
		assert(current_ids != previous,"Restart kept the same question order")
		if not previous.is_empty():
			var old_sorted = previous.duplicate()
			var new_sorted = current_ids.duplicate()
			old_sorted.sort()
			new_sorted.sort()
			assert(old_sorted != new_sorted,"Restart kept the same question set")
		previous = current_ids
	assert(coverage.size() == 225,"Some questions are never selected")
	# Force the same RNG seed twice: the previous-set guard must still work.
	rng.seed = 19
	var first = bank.make_session(question_pool,rng)
	rng.seed = 19
	var second = bank.make_session(question_pool,rng,bank.ids(first))
	var first_ids = bank.ids(first)
	var second_ids = bank.ids(second)
	first_ids.sort()
	second_ids.sort()
	assert(first_ids != second_ids)
	# The smaller cards must remain selectable at their new table positions.
	var camera_before = camera.transform
	var card_count = 0
	for q in question_pool:
		if q.type not in ["cards","frame","audio"]:continue
		data.questions = [q]
		question_index = 0
		_begin_question()
		voice.stop()
		speaking = false
		await get_tree().physics_frame
		await get_tree().physics_frame
		assert(cards.size() == q.options.size())
		for i in range(cards.size()):
			camera.look_at(cards[i].global_position,Vector3.UP)
			_update_hover()
			assert(hovering == i,"A card is unreachable from the seated camera")
			assert(absf(cards[i].position.x)+.16 < 1.16 and cards[i].position.z+.11 < .95)
			card_count += 1
	camera.transform = camera_before
	assert(card_count == 564)
	# Full opening: no rules until eyes are open, three seconds have passed, and entrance ends.
	_start(false)
	_process(EYE_OPEN_SECONDS-.01)
	assert(phase=="awakening" and not speaking)
	_process(.02)
	assert(phase=="lookaround" and not eyelids.visible and not speaking)
	_process(2.99)
	assert(phase=="lookaround" and actor.position==SHADOW_START and not actor.visible and not speaking)
	_process(.011)
	assert(phase=="emerge" and not speaking)
	_process(EMERGE_SECONDS+.01)
	assert(phase=="intro" and speaking and actor.position==CORNER)
	_pause()
	var frozen=clock
	_process(.5)
	assert(clock==frozen)
	_resume()
	assert(phase=="intro")
	for line in data.intro:assert(line.action!="scare")
	var reel_angle=dynamics.reels[0].rotation.x
	dynamics.update(clock+.5)
	assert(dynamics.reels[0].rotation.x!=reel_angle)
	assert(not projected_frame.visible and projector_fill.light_energy==0)
	assert(dynamics.grate.position.x<dynamics.glass.position.x)
	assert(is_equal_approx(dynamics.WINDOW_BOTTOM-dynamics.PAVEMENT_HEIGHT,.05))
	assert(bulb_mesh.global_position.distance_to(Vector3(0,2.4,1.55))<.001)
	pitch=-1.22
	_update_camera(0)
	assert(camera.position.z<=1.40 and camera.near<=.03)
	_position_gun()
	var attached=skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone("hand_r"))*grip_local
	assert(gun.global_position.distance_to(attached.origin)<.0001)
	assert(hand_modifier.curls.size()==15)
	_start(true)
	var first_order = bank.ids(data.questions)
	_start(true)
	assert(bank.ids(data.questions) != first_order)
	assert(lives == 3 and soundscape.street.playing)
	var timer_before = timer
	_process(.25)
	assert(timer == timer_before)
	await preload("res://tests/v1_checks.gd").run(self)

	# Every still must display its own image and three matching cards.
	for q in question_pool:
		if q.type != "frame":
			continue
		data.questions = [q]
		question_index = 0
		_begin_question()
		dynamics.update(clock)
		assert(cards.size() == 3 and projection_material.get_shader_parameter("show_frame"))
		assert(projected_frame.visible and projector_fill.light_energy>0)
		assert(projection_material.get_shader_parameter("frame_tex").resource_path == q.image)
		voice.stop()
		speaking = false
		phase_time = 1
		lives = 3
		_answer(3)
		assert(phase == "question" and lives == 3)
	_start(true)
	for i in range(data.questions.size()):
		voice.stop()
		speaking = false
		phase_time = 1
		var q = data.questions[i]
		_answer(int(q.correct))
		assert(phase == "correct")
		voice.stop()
		speaking = false
		phase_time = 3
		_process(.01)
	assert(phase == "victory" and correct_count == 21 and not shot)
	voice.stop()
	speaking = false
	phase_time = voice_meta.win.duration+.9
	_process(.1)
	assert(_victory_aiming() and not shot)
	_process(1)
	assert(shot)
	_process(3.1)
	assert(phase == "ended")
	assert(soundscape.street.playing)
	await preload("res://tests/sound_checks.gd").run(self)
	preload("res://tests/gesture_checks.gd").run(self)
	preload("res://tests/v09_checks.gd").run(self)
	preload("res://tests/web_checks.gd").run(self)
	print("GAMEPLAY_CHECKS_PASSED: 225 questions, 500 randomized 3x7 sessions, all categories per level, 564 selectable cards, 3 lives, audio loops, 70 images and existing room/gesture/sound/ending checks")
	await _close_test()
