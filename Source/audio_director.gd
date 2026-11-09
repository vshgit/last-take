extends Node
## Positional room sounds and per-question tension. No UI countdown sounds.
const ROOT = "res://assets/audio/environment/"
const AMBIENCE_BUS = &"Ambience"
const AMBIENCE_VOLUME_DB = -10.0
var g
var players: Array[Node] = []
var film:AudioStreamPlayer3D
var slide:AudioStreamPlayer3D
var street: AudioStreamPlayer3D
var hum: AudioStreamPlayer3D
var fly: AudioStreamPlayer3D
var drip: AudioStreamPlayer3D
var cock: AudioStreamPlayer3D
var sniff: AudioStreamPlayer3D
var breath: AudioStreamPlayer
var footsteps: Array[AudioStreamPlayer3D] = []
var step_ids: Array[int] = [-1,-1]
var rng = RandomNumberGenerator.new()
var ambience_enabled = true
const DRIP_GAPS=[4.0,7.0,5.0,6.0]
var drip_gap_index=0
var next_drip=4.0
var next_sniff = 22.0
var breath_age = 0.0
var breath_duration = 0.0
var breath_gain = 0.0
var breath_fading = false
var late_breath_started = false
var gun_raised = false
var warning_age = 0.0
var cocked = false
var fly_gain = 0.0
var events: Array[Dictionary] = []

func build(game) -> void:
	g = game
	rng.randomize()
	street = spatial("StreetBehindGlass",g.dynamics,Vector3(-2.76,2.26,-.7),"city_behind_glass",-8,true)
	street.unit_size = 5
	hum = spatial("BulbHum",g.bulb_mesh,Vector3.ZERO,"bulb_hum",-9,true)
	fly = spatial("FlyWings",g.dynamics.fly,Vector3.ZERO,"fly_buzz",-80,true)
	drip = spatial("WaterImpact",g,Vector3(2.35,.055,-.45),"water_drop",-20)
	cock = spatial("HammerLatch",g.gun,Vector3.ZERO,"hammer_cock",-13)
	sniff = spatial("CinemaniacSniff",g.actor,Vector3(0,1.55,.10),"sniff_0",-8)
	breath = AudioStreamPlayer.new()
	breath.name = "PlayerBreathing"
	add_child(breath)
	players.append(breath)
	for i in range(g.dynamics.passers.size()):
		footsteps.append(spatial("ShoeContact%d"%i,g.dynamics.passers[i],Vector3(0,.02,0),"step_0",-17))
	film=spatial("FilmTransport",g.dynamics.projector,Vector3.ZERO,"film_transport",-7,true)
	slide=spatial("SlideChange",g.dynamics.projector,Vector3.ZERO,"slide_click",-10)
	# Keep the background reduction after gaze, lamp and menu volume updates.
	var ambience_bus = AudioServer.get_bus_index(AMBIENCE_BUS)
	if ambience_bus < 0:
		AudioServer.add_bus()
		ambience_bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(ambience_bus, AMBIENCE_BUS)
	AudioServer.set_bus_send(ambience_bus, &"Master")
	AudioServer.set_bus_volume_db(ambience_bus, AMBIENCE_VOLUME_DB)
	for p in [street, hum, fly, drip, film]:
		p.bus = AMBIENCE_BUS
	for p in footsteps:
		p.bus = AMBIENCE_BUS
	next_drip=g.clock+DRIP_GAPS[0]
	next_sniff = g.clock + rng.randf_range(18,34)
	set_ambience(g.settings.ambience)

func spatial(label: String, parent: Node3D, pos: Vector3, asset: String, db: float, loop: bool = false) -> AudioStreamPlayer3D:
	var p = AudioStreamPlayer3D.new()
	p.name = label
	parent.add_child(p)
	p.position = pos
	p.stream = load(ROOT+asset+".ogg")
	if loop:
		p.stream = p.stream.duplicate()
		p.stream.loop = true
	p.volume_db = db
	p.unit_size = 3.0
	p.max_distance = 16.0
	p.attenuation_filter_cutoff_hz = 6000
	players.append(p)
	return p

func slide_click() -> void:
	slide.play();record("slide_click")

func record(kind: String) -> void:
	if g.qa_mode:
		events.append({"kind":kind,"clock":g.clock,"phase":g.phase,"timer":g.timer,"passers":g.dynamics.passer_phases.duplicate()})

func set_ambience(enabled: bool) -> void:
	ambience_enabled = enabled
	for p in [street,hum,fly,film]:
		if enabled and not p.playing:p.play()
		elif not enabled:p.stop()
	if not enabled:
		drip.stop()
		for p in footsteps:p.stop()

func set_paused(value: bool) -> void:
	for p in players:p.stream_paused = value

func reset_session() -> void:
	set_paused(false)
	breath.stop()
	breath_gain = 0
	breath_duration = 0
	sniff.stop()
	cock.stop()
	next_sniff = g.clock+rng.randf_range(18,34)
	reset_question()

func reset_question() -> void:
	late_breath_started = false
	gun_raised = false
	warning_age = 0
	cocked = false
	breath_fading = true
	cock.stop()
	sniff.stop()

func breathe(waking: bool) -> void:
	breath.stop()
	breath.stream = load(ROOT+("breathing_wake" if waking else "breathing_late")+".ogg")
	breath_duration = breath.stream.get_length()
	breath_age = 0
	breath_gain = 0
	breath_fading = false
	breath.volume_db = -80
	breath.play()
	record("wake_breath" if waking else "late_breath")

func sniff_allowed() -> bool:
	# Reserve enough time for the entire longest sniff before the seven-second boundary.
	return g.phase == "question" and not g.speaking and g.timer >= 7.85

func stop_sniff() -> void:
	sniff.stop()

func update(delta: float) -> void:
	if g.phase == "paused":return
	var answering: bool = g.phase == "question" and not g.speaking and g.phase_time > .8
	if answering and g.timer < 7 and g.timer > 0 and not late_breath_started:
		late_breath_started = true
		breathe(false)
	if answering and g.timer <= 5 and g.timer > 0:
		if not gun_raised:
			gun_raised = true
			warning_age = 0
			record("gun_raise")
		else:
			warning_age += delta
		if warning_age >= 1.0 and not cocked:
			cocked = true
			cock.play()
			record("hammer_click")
	elif g.phase != "question":
		gun_raised = false
		if g.phase not in ["awakening","lookaround"]:breath_fading = true
	if g.speaking or g.phase != "question" or g.timer < 7:sniff.stop()
	if g.clock >= next_sniff:
		if sniff_allowed():
			sniff.stream = load(ROOT+"sniff_%d.ogg"%rng.randi_range(0,1))
			sniff.pitch_scale = rng.randf_range(.94,1.04)
			sniff.play()
			record("sniff")
			next_sniff = g.clock+rng.randf_range(18,36)
		else:
			next_sniff = g.clock+rng.randf_range(2,4)
	if breath_duration > 0:
		breath_age += delta
		var target = 0.0 if breath_fading else smoothstep(0,.22,breath_age)*(1.0-smoothstep(breath_duration-1.6,breath_duration,breath_age))
		breath_gain = move_toward(breath_gain,target,delta*(1.25 if target<breath_gain else 5.0))
		breath.volume_db = linear_to_db(maxf(.0001,breath_gain))-6
		if breath_age >= breath_duration or (breath_fading and breath_gain <= .001):
			breath.stop()
			breath_duration = 0
	# Gaze is measured against the bulb, not against screen pitch alone.
	var to_bulb: Vector3 = (g.bulb_mesh.global_position-g.camera.global_position).normalized()
	var alignment: float = (-g.camera.global_basis.z).dot(to_bulb)
	var gaze: float = smoothstep(.87,.98,alignment) if ambience_enabled else 0.0
	fly_gain = move_toward(fly_gain,gaze,delta*(2.8 if gaze>fly_gain else 1.5))
	fly.volume_db = linear_to_db(maxf(.0001,fly_gain))-8
	hum.volume_db = -9+linear_to_db(maxf(.15,g.key_light.light_energy/2.8))*.35
	film.volume_db=-5 if g.phase=="menu" else (-23 if g.speaking else -17)
	# Match each footfall to the zero crossing of the walking animation.
	for i in range(footsteps.size()):
		var walk:float=g.dynamics.passer_phases[i]
		var contact=int(floor(walk*3.4))
		if walk>=0:
			if step_ids[i] != contact and ambience_enabled:
				footsteps[i].stream = load(ROOT+"step_%d.ogg"%rng.randi_range(0,2))
				footsteps[i].pitch_scale = rng.randf_range(.94,1.06)
				footsteps[i].volume_db = rng.randf_range(-19,-16)
				footsteps[i].play()
				record("footstep_%d"%i)
			step_ids[i] = contact
		else:
			step_ids[i] = -1
	# One visible falling drop, then its impact. Irregular 4/7/5/6-second intervals.
	if g.clock >= next_drip:
		if ambience_enabled:
			drip.pitch_scale = rng.randf_range(.95,1.05)
			drip.play()
			record("drip")
		drip_gap_index=(drip_gap_index+1)%DRIP_GAPS.size()
		next_drip=g.clock+DRIP_GAPS[drip_gap_index]
	var until_drop: float = next_drip-g.clock
	for drop in g.water_drips:
		drop.visible = until_drop <= .74
		var fall = clampf(1.0-until_drop/.74,0,1)
		drop.position = Vector3(2.35,2.70*(1-fall*fall)+.02,-.45)

func shutdown() -> void:
	for p in players:
		p.stop()
		p.stream = null
