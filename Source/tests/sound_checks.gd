extends RefCounted

static func count_kind(sound, kind: String) -> int:
	var count = 0
	for e in sound.events:
		if e.kind == kind:count += 1
	return count

static func run(g) -> void:
	var sound = g.soundscape
	g._start(true)
	g.voice.stop()
	g.speaking = false
	g.phase_time = 1
	sound.events.clear()
	g.timer = 7.1
	g._process(.05)
	assert(count_kind(sound,"late_breath")==0)
	g._process(.10)
	assert(count_kind(sound,"late_breath")==1 and sound.breath.playing)
	assert(not sound.gun_raised and not sound.sniff_allowed())
	for i in range(38):g._process(.05)
	assert(not sound.gun_raised and count_kind(sound,"hammer_click")==0)
	g._process(.10)
	assert(sound.gun_raised and count_kind(sound,"gun_raise")==1)
	var initial_ik: float = g.arm_ik.interpolation
	for i in range(10):g._process(.05)
	assert(g.arm_ik.interpolation>initial_ik and g.arm_ik.interpolation<1.0)
	assert(count_kind(sound,"hammer_click")==0)
	for i in range(14):g._process(.05)
	assert(g.arm_ik.interpolation>.95 and count_kind(sound,"hammer_click")==1)
	for i in range(12):g._process(.05)
	assert(count_kind(sound,"late_breath")==1 and count_kind(sound,"hammer_click")==1)
	assert(not g.hud.is_visible_in_tree() and not g.fps_label.visible)
	# Pause freezes the hidden timer, warning motion and every independent sound player.
	await g.get_tree().physics_frame
	await g.get_tree().physics_frame
	var active_players: Array[Node] = []
	for player in sound.players:
		if player.playing:active_players.append(player)
	g._pause()
	var frozen_clock: float = g.clock
	var frozen_timer: float = g.timer
	var frozen_age: float = sound.warning_age
	g._process(2)
	assert(g.clock==frozen_clock and g.timer==frozen_timer and sound.warning_age==frozen_age)
	for player in active_players:assert(player.stream_paused,"Pause failed for "+player.name)
	g._resume()
	for player in sound.players:assert(not player.stream_paused)
	# Answering fades breathing; another question re-arms both tension events.
	g._answer(int(g.data.questions[0].correct))
	for i in range(20):g._process(.05)
	assert(sound.breath_gain<.01 and not sound.gun_raised)
	g._begin_question()
	g.voice.stop();g.speaking=false;g.phase_time=1;g.timer=6.9
	g._process(.01)
	assert(count_kind(sound,"late_breath")==2)
	# No sniff on any opening frame or during speech; no clip crosses seven seconds.
	for state in ["awakening","lookaround","emerge","intro","correct","retake","death","victory","ended"]:
		g.phase=state;g.timer=18;sound.next_sniff=g.clock
		sound.update(.01)
		assert(not sound.sniff.playing)
	g.phase="question";g.speaking=true;sound.next_sniff=g.clock;sound.update(.01)
	assert(not sound.sniff.playing)
	g.speaking=false
	for remaining in [7.0,7.5,6.99,5.0,.2]:
		g.timer=remaining;sound.next_sniff=g.clock;sound.update(.01)
		assert(not sound.sniff.playing)
	g.timer=12;sound.next_sniff=g.clock;sound.update(.01)
	assert(sound.sniff.playing and count_kind(sound,"sniff")==1)
	g.timer=6.9;sound.update(.01)
	assert(not sound.sniff.playing)
	# Simulate one minute of the room; footfall timestamps must match visible walkers.
	g.phase="lookaround";g.speaking=false;sound.events.clear();sound.next_drip=g.clock+4
	for i in range(3600):
		g.clock+=1.0/60
		g.dynamics.update(g.clock)
		sound.update(1.0/60)
	var last_drip = -1.0
	var drops = 0
	var steps = 0
	for e in sound.events:
		if e.kind=="drip":
			if last_drip>=0:assert(e.clock-last_drip>=3.99 and e.clock-last_drip<=7.04)
			last_drip=e.clock;drops+=1
		if String(e.kind).begins_with("footstep_"):
			var who=int(String(e.kind).right(1))
			assert(e.passers[who]>=0 and e.passers[who]<1)
			steps+=1
	assert(drops>=9 and drops<=12 and steps>=4 and steps<=24)
	# Fly is silent in a normal view and fades up only when actually facing the bulb.
	g.pitch=-.13;g.yaw=0;g._update_camera(0)
	for i in range(60):sound.update(1.0/60)
	assert(sound.fly_gain<.001)
	g.pitch=1.35;g._update_camera(0)
	for i in range(60):sound.update(1.0/60)
	assert(sound.fly_gain>.85)
	g.pitch=-.13;g._update_camera(0)
	for i in range(60):sound.update(1.0/60)
	assert(sound.fly_gain<.001)
	g._set_ambience(false)
	assert(not sound.street.playing and not sound.hum.playing and not sound.fly.playing)
	g._set_ambience(true)
	assert(sound.street.playing and sound.hum.playing)
	assert(g.dynamics.projector.position.x>.5)
	assert(g.has_node("BrokenCactusPot") and g.has_node("PlayerChair/BodyFittedBindings"))
	print("SOUNDS_CHECKS_PASSED: hidden HUD; 7-second breathing; slow 5-second gun raise; single cock click; reset; fade; all-audio pause; sniff exclusions; 60-second drip/footstep cadence; gaze fly; right projector; fitted bindings; broken cactus")
