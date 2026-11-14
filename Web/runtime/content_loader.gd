extends Node
## Browser adapter. No independent quiz rules: all answers/transitions remain in main.gd.
signal changed
var g
var manifest: Dictionary
var cache: Dictionary = {}
var queued: Dictionary = {}
var failures: Dictionary = {}
var queue: Array[String] = []
var busy = false
var epoch = 0
var prepare_ticket = 0
var viewports: Array[SubViewport] = []
var loading_label: Label
var retry_button: Button
var start_callback: JavaScriptObject
var pointer_callback: JavaScriptObject
var base_url = ""
var requested_paths: Array[String] = []
var completed_paths: Array[String] = []
var received_bytes = 0
var speech_elapsed = 0.0
var metrics_age = 0.0
var frames: Array[float] = []
var last_speaking_id = ""
var test_result: Dictionary = {}

func _ready() -> void:
	manifest = JSON.parse_string(FileAccess.get_file_as_string("res://media-manifest.json"))
	if OS.has_feature("web"):
		base_url = str(JavaScriptBridge.eval("new URL('.',location.href).href"))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--media-base="): base_url = arg.substr(13)

func configure() -> void:
	g.voice.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	g.question_audio.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	g.soundscape.breath.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	g.actor_bounce.shadow_enabled = false
	g.doorway_spill.shadow_enabled = false
	g.dynamics.window_light.shadow_enabled = false
	g.projector_fill.shadow_enabled = false
	loading_label = g._label("",24)
	loading_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	loading_label.position = Vector2(-280,-45)
	loading_label.size = Vector2(560,100)
	loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	loading_label.hide()
	retry_button = g._button("ПОВТОРИТЬ ЗАГРУЗКУ",_retry_question,g.ui)
	retry_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	retry_button.position = Vector2(-135,65)
	retry_button.hide()
	if OS.has_feature("web"):
		start_callback = JavaScriptBridge.create_callback(_start_from_gesture)
		pointer_callback = JavaScriptBridge.create_callback(_pointer_unlocked)
		var window = JavaScriptBridge.get_interface("window")
		window.lastTakeBegin = start_callback
		window.lastTakePointerUnlocked = pointer_callback
		JavaScriptBridge.eval("window.lastTakeGameReady=true;window.dispatchEvent(new Event('lasttake-ready'))")
		if bool(JavaScriptBridge.eval("new URLSearchParams(location.search).get('qa')==='1'")):
			g.qa_mode = true

func _start_from_gesture(_args: Array) -> void:
	g._start(false)

func _pointer_unlocked(_args: Array) -> void:
	if g.phase == "loading" and retry_button.visible: return
	if not g.qa_mode: g._pause()

func _retry_question() -> void:
	# Capture from the button's fresh user gesture, before the asynchronous request.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	g._begin_question()

func batch_static_room() -> void:
	# Merge static meshes sharing the same material into one draw surface. Keep named
	# source nodes (hidden), excluding every object subsequently moved/animated by game code.
	var excluded: Array = [g.door,g.dynamics.projector,g.dynamics.fly,g.projected_frame,
		g.bulb_mesh,g.dynamics.window_shadows,g.dynamics.beam,g.dynamics.window_beam]
	excluded.append_array(g.dynamics.passers)
	excluded.append_array(g.water_drips)
	var groups: Dictionary = {}
	for node in g.find_children("*","MeshInstance3D",true,false):
		var skip = false
		for dynamic in excluded:
			if dynamic == node or dynamic.is_ancestor_of(node): skip=true;break
		# Hiding a partially batched multi-surface/parent mesh would hide its remaining parts.
		if skip or not node.mesh or node.skin or node.mesh.get_surface_count()!=1 or node.get_child_count()>0: continue
		for surface in range(node.mesh.get_surface_count()):
			var material: Material = node.get_active_material(surface)
			if not material: continue
			var key = str(material.get_instance_id())+":"+str(node.cast_shadow)
			if not groups.has(key): groups[key]=[]
			groups[key].append([node,surface,material])
	for key in groups:
		var parts: Array = groups[key]
		if parts.size()<2: continue
		var surface = SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for part in parts:
			surface.append_from(part[0].mesh,part[1],g.global_transform.affine_inverse()*part[0].global_transform)
		var merged = MeshInstance3D.new()
		merged.name="WebStaticBatch"
		merged.mesh=surface.commit()
		merged.material_override=parts[0][2]
		merged.cast_shadow=parts[0][0].cast_shadow
		g.add_child(merged)
		for part in parts: part[0].visible=false

func cancel() -> void:
	epoch += 1
	prepare_ticket += 1
	if is_instance_valid(loading_label): loading_label.hide()
	if is_instance_valid(retry_button): retry_button.hide()

func clear_textures() -> void:
	for viewport in viewports: viewport.queue_free()
	viewports.clear()

func text_texture(text: String, slide: bool, variant: int = 0) -> Texture2D:
	var viewport = SubViewport.new()
	viewport.size = Vector2i(1024,640) if slide else Vector2i(512,320)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)
	viewports.append(viewport)
	var paper = ColorRect.new()
	paper.size = viewport.size
	paper.color = Color("d8cbb0")
	var material = ShaderMaterial.new()
	var shader = Shader.new()
	shader.code = "shader_type canvas_item; void fragment(){float n=fract(sin(dot(floor(UV*vec2(512.,320.)),vec2(12.9898,78.233)))*43758.5453);float edge=smoothstep(0.,.07,min(min(UV.x,1.-UV.x),min(UV.y,1.-UV.y)));COLOR=vec4(vec3(.82,.78,.67)*(0.87+0.10*edge+0.04*n),1.);}"
	material.shader = shader
	paper.material = material
	viewport.add_child(paper)
	var label = Label.new()
	label.text = text
	label.position = Vector2(40,45) if slide else Vector2(26,38)
	label.size = Vector2(viewport.size)-label.position*2
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font",g.serif)
	label.add_theme_font_size_override("font_size",36 if slide else (28 if text.length()>80 else 34))
	label.add_theme_color_override("font_color",Color("26251e"))
	viewport.add_child(label)
	if not slide:
		var number = Label.new()
		number.text = str(variant+1)
		number.position = Vector2(18,8)
		number.add_theme_font_override("font",g.font)
		number.add_theme_font_size_override("font_size",20)
		number.add_theme_color_override("font_color",Color("615e51"))
		viewport.add_child(number)
	return viewport.get_texture()

func projection_texture(q: Dictionary) -> Texture2D:
	if q.type == "frame": return cache[q.image]
	return text_texture(q.text,true)

func voice_stream(id: String) -> AudioStream:
	var path = "res://assets/audio/"+id+".ogg"
	if cache.has(path): return cache[path]
	if ResourceLoader.exists(path): return load(path)
	return null

func clip_stream(path: String) -> AudioStream:
	return cache.get(path)

func pause_loading() -> void:
	g.previous_phase = "loading"
	g.phase = "paused"
	g.pause_panel.show()
	loading_label.hide()
	retry_button.hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func resume_loading() -> void:
	prepare_ticket += 1
	g.phase = "loading"
	g.pause_panel.hide()
	g.settings_panel.hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	g._begin_question.call_deferred()

func prepare_current() -> bool:
	prepare_ticket += 1
	var my_ticket = prepare_ticket
	var my_epoch = epoch
	var index: int = g.question_index
	var q: Dictionary = g.data.questions[index]
	var id: String = q.id
	# Freeze the whole game, including elapsed speech clocks, during network wait.
	g.question_audio.stop_question()
	g.voice.stop()
	g.speaking = false
	g.phase = "loading"
	g.soundscape.set_paused(true)
	g.crosshair.hide()
	g.question_box.hide()
	loading_label.text = "Подготавливаем вопрос…"
	loading_label.show()
	retry_button.hide()
	_trim_window()
	for path in manifest.questions[id]:
		var success: bool = await ensure_asset(path,true)
		if my_ticket != prepare_ticket or my_epoch != epoch or index != g.question_index or id != g.data.questions[index].id: return false
		if g.phase == "paused": return false
		if not success:
			loading_label.text = "Не удалось загрузить вопрос. Проверь соединение и повтори."
			retry_button.show()
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			return false
	loading_label.hide()
	g.soundscape.set_paused(false)
	# Prefetch only the next two questions, never the full bank.
	_prefetch.call_deferred(my_epoch,index)
	return true

func _prefetch(my_epoch: int, index: int) -> void:
	for next in range(index+1,mini(index+3,g.data.questions.size())):
		if my_epoch != epoch or index != g.question_index or next >= g.data.questions.size(): return
		for path in manifest.questions[g.data.questions[next].id]:
			if my_epoch != epoch or index != g.question_index: return
			await ensure_asset(path,false)
	_trim_window()

func _trim_window() -> void:
	var keep: Dictionary = {}
	for index in range(g.question_index,mini(g.question_index+3,g.data.questions.size())):
		for path in manifest.questions[g.data.questions[index].id]: keep[path] = true
	for path in cache.keys():
		if not keep.has(path): cache.erase(path)
	for path in queue.duplicate():
		if not keep.has(path):
			queue.erase(path)
			queued.erase(path)
	changed.emit()

func ensure_asset(path: String, priority: bool) -> bool:
	if cache.has(path): return true
	if not queued.has(path):
		queued[path] = true
		failures.erase(path)
		if priority: queue.push_front(path)
		else: queue.push_back(path)
		_worker.call_deferred()
	while queued.has(path): await changed
	return cache.has(path)

func _worker() -> void:
	if busy: return
	busy = true
	while not queue.is_empty():
		var path: String = queue.pop_front()
		var entry: Dictionary = manifest.assets[path]
		var resource: Resource
		for attempt in range(3):
			var request = HTTPRequest.new()
			request.timeout = 20
			request.body_size_limit = int(entry.bytes)+1024
			add_child(request)
			requested_paths.append(path)
			if requested_paths.size()>512: requested_paths.pop_front()
			var err = request.request(base_url+entry.file)
			if err == OK:
				var result: Array = await request.request_completed
				var body: PackedByteArray = result[3]
				if result[0] == HTTPRequest.RESULT_SUCCESS and result[1] == 200 and body.size() == int(entry.bytes):
					var hashing = HashingContext.new()
					hashing.start(HashingContext.HASH_SHA256);hashing.update(body)
					if hashing.finish().hex_encode() == entry.sha256:
						resource = _decode(path,body)
						if resource: received_bytes += body.size()
			request.queue_free()
			if resource: break
			if attempt < 2: await get_tree().create_timer(.3*(attempt+1)).timeout
		if resource:
			cache[path] = resource
			completed_paths.append(path)
			if completed_paths.size()>512: completed_paths.pop_front()
		else: failures[path] = "download_or_hash_or_decode_failed"
		queued.erase(path)
		changed.emit()
	busy = false

func _decode(path: String, body: PackedByteArray) -> Resource:
	if path.ends_with(".ogg"): return AudioStreamOggVorbis.load_from_buffer(body)
	if path.ends_with(".mp3"):
		var audio = AudioStreamMP3.new()
		audio.data = body
		return audio
	var image = Image.new()
	var err = image.load_png_from_buffer(body) if path.ends_with(".png") else image.load_jpg_from_buffer(body)
	if err != OK: return null
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

func update_metrics(delta: float) -> void:
	if not is_instance_valid(g.voice): return
	if g.phase not in ["paused","loading"]:
		frames.append(delta)
		if frames.size()>600: frames.pop_front()
		if g.speaking:
			if last_speaking_id != g.voice_id:
				last_speaking_id = g.voice_id;speech_elapsed = 0
			speech_elapsed += delta
			if g.voice.stream and speech_elapsed > g.voice.stream.get_length()+2 and not g.voice.playing:
				g.speaking = false
	metrics_age += delta
	if metrics_age < 1: return
	metrics_age = 0
	var mean = 0.0
	for frame in frames: mean += frame
	if frames.size()>0: mean /= frames.size()
	var report = {"phase":g.phase,"id":g.data.questions[mini(g.question_index,g.data.questions.size()-1)].id,
		"question_index":g.question_index,"lives":g.lives,"timer":g.timer,"speaking":g.speaking,
		"fps":Engine.get_frames_per_second(),"mean_frame_ms":mean*1000,
		"draw_calls":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		"received_media_bytes":received_bytes,"cached_assets":cache.size(),"requests":requested_paths,
		"completed":completed_paths,"failures":failures,"bank_sha256":manifest.bank_sha256,"test":test_result}
	if OS.has_feature("web"): JavaScriptBridge.eval("window.lastTakeReport="+JSON.stringify(report))
