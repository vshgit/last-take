extends AudioStreamPlayer
## Independent from speech: looping does not block the answer timer.
func start_question(q: Dictionary) -> void:
	stop_question()
	if q.type != "audio": return
	stream = load(q.audio).duplicate()
	stream.loop = true
	volume_db = -24.0
	play()
func stop_question() -> void:
	stop()
	stream = null
	stream_paused = false
func update_mix(delta: float, speaking: bool) -> void:
	if playing:
		volume_db = move_toward(volume_db, -24.0 if speaking else -10.0, delta*18.0)
