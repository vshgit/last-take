extends RefCounted
## Browser adaptation only; native visuals and audio defaults are preserved.

static func configure(g) -> void:
	# Keep the main bulb's shadow; auxiliary shadow passes are too costly in WebGL.
	g.actor_bounce.shadow_enabled = false
	g.doorway_spill.shadow_enabled = false
	g.dynamics.window_light.shadow_enabled = false
	g.projector_fill.shadow_enabled = false
	# Long compressed speech/loops must not decode into WebAudio samples all at once.
	# Keep short effects on the Web sample path for low latency.
	for player in [g.voice,g.question_audio,g.soundscape.breath]:
		player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	for player in g.soundscape.players:
		if player.stream and player.stream.get_length() > 2.0:
			player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM

static func update_speech(g, delta: float) -> void:
	if not g.speaking or g.phase == "paused":
		return
	g.speech_elapsed += delta
	var duration: float = g.voice_meta.get(g.voice_id,{}).get("duration",0.0)
	if duration > 0 and g.speech_elapsed > duration + 1.0:
		# Some browser/audio failures never emit finished. Do not lock the whole quiz.
		g.voice.stop()
		g.speaking = false
		if not g.qa_mode:
			push_warning("Web speech completion timeout: " + g.voice_id)
