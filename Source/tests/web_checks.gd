extends RefCounted

static func run(g) -> void:
	var runtime = preload("res://web_runtime.gd")
	var shadows = [g.actor_bounce.shadow_enabled,g.doorway_spill.shadow_enabled,g.dynamics.window_light.shadow_enabled,g.projector_fill.shadow_enabled]
	var players: Array = [g.voice,g.question_audio] + g.soundscape.players
	var modes: Array = []
	for player in players: modes.append(player.playback_type)
	var native_mode: bool = g.web_mode
	g.web_mode = true
	runtime.configure(g)
	assert(g.voice.playback_type == AudioServer.PLAYBACK_TYPE_STREAM)
	assert(g.question_audio.playback_type == AudioServer.PLAYBACK_TYPE_STREAM)
	assert(g.soundscape.breath.playback_type == AudioServer.PLAYBACK_TYPE_STREAM)
	g.dynamics.update(g.clock)
	assert(not g.actor_bounce.shadow_enabled and not g.doorway_spill.shadow_enabled)
	assert(not g.dynamics.window_light.shadow_enabled and not g.projector_fill.shadow_enabled)
	assert(g.key_light.shadow_enabled == g.settings.shadows)
	g._start(true)
	var duration: float = g.voice_meta[g.voice_id].duration
	runtime.update_speech(g,duration - .1)
	assert(g.speaking,"Speech must not be skipped before the clip's duration")
	g._pause()
	var elapsed: float = g.speech_elapsed
	runtime.update_speech(g,100)
	assert(g.speech_elapsed == elapsed and g.speaking,"Pause must stop the fallback clock")
	g._resume()
	runtime.update_speech(g,1.2)
	assert(not g.speaking,"A missing finished signal must not freeze the game")
	g.phase_time = 1.0
	g._process(.01)
	assert(g.timer < 18 and g.phase == "question" and g.lives == 3)
	g._set_menu()
	g.web_mode = native_mode
	for i in range(players.size()): players[i].playback_type = modes[i]
	g.actor_bounce.shadow_enabled = shadows[0]
	g.doorway_spill.shadow_enabled = shadows[1]
	g.dynamics.window_light.shadow_enabled = shadows[2]
	g.projector_fill.shadow_enabled = shadows[3]
	print("WEB_RUNTIME_CHECKS_PASSED: light budget, streaming speech, stalled audio recovery, pause and answer timer")
