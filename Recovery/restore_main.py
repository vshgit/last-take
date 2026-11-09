from pathlib import Path
p=Path('game/LastTake/Source/main.gd');s=p.read_text()
s=s.replace('var retakes = 1','var lives = 3').replace('retakes = 1','lives = 3')
s=s.replace('var effects: AudioStreamPlayer','var effects: AudioStreamPlayer\nvar question_audio: AudioStreamPlayer')
s=s.replace('voice.finished.connect(func(): speaking = false)','voice.finished.connect(func(): speaking = false)\n\tquestion_audio = preload("res://question_audio.gd").new()\n\tadd_child(question_audio)')
s=s.replace('in ["cards","frame"]','in ["cards","frame","audio"]').replace('q%02d_%d.png','q%02d_%d.jpg')
s=s.replace('WINDOWS / 010     ·     58 ВОПРОСОВ В БАНКЕ     ·     11 ЗА СЕАНС     ·     1 ДУБЛЬ','WINDOWS / 1.0')
s=s.replace('retakes_label.text = "ЗАПАСНОЙ ДУБЛЬ: %d"%retakes','retakes_label.text = ""')
s=s.replace('_speak(q.voice_id,q.text)\n\tsubtitle.hide()','_speak(q.voice_id,q.text)\n\tquestion_audio.start_question(q)\n\tsubtitle.hide()')
for sig in ['func _set_menu() -> void:','func _start(skip: bool = false) -> void:','func _begin_question() -> void:','func _begin_victory() -> void:','func _die(reason: String) -> void:','func _finish(win: bool) -> void:','func _close_test() -> void:']:
 s=s.replace(sig,sig+'\n\tquestion_audio.stop_question()')
s=s.replace('voice.stream_paused = true','voice.stream_paused = true\n\tquestion_audio.stream_paused = true').replace('voice.stream_paused = false','voice.stream_paused = false\n\tquestion_audio.stream_paused = false')
s=s.replace('var correct = int(value) == int(q.correct)','question_audio.stop_question()\n\tvar correct = int(value) == int(q.correct)')
a=s.index('\telif retakes > 0:');b=s.index('\nfunc _die(',a)
s=s[:a]+'''\telse:
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
''' +s[b:]
s=s.replace('"Вторая ошибка. Сеанс окончен."','"Третья ошибка. Сеанс окончен."').replace('\t\t\t\t_die("timeout")','\t\t\t\t_lose_life("timeout")')
s=s.replace('''			question_index += 1
			if question_index >= data.questions.size():
				_begin_victory()
			else:
				_begin_question()''','\t\t\t_next_question()')
s=s.replace('_speak("retake","Нет, будет дубль…")','_speak("retake","Нет. Будет дубль.")').replace('if phase_time > 4.8 and retake_spoken and not speaking:\n\t\t\t_begin_question()','if phase_time > 4.8 and retake_spoken and not speaking:\n\t\t\t_next_question()')
s=s.replace('\t_update_camera(delta)\n','\tquestion_audio.update_mix(delta,speaking)\n\t_update_camera(delta)\n')
s=s.replace('''		"gesture":
			data.questions[0]=question_pool[50];_begin_question()''','''		"gesture","audio":
			for q in question_pool:
				if q.type == capture_mode:
					data.questions[0]=q;break
			_begin_question()''')
s=s.replace('question_pool.size() == 58','question_pool.size() == 216').replace('coverage.size() == 58','coverage.size() == 216').replace('selection.size() == 11','selection.size() == 21')
s=s.replace('var mix = {"cards":0,"frame":0,"gesture":0}','var mixes = [{"cards":0,"frame":0,"gesture":0},{"cards":0,"frame":0,"gesture":0},{"cards":0,"frame":0,"gesture":0,"audio":0}]')
s=s.replace('mix[q.type] += 1','mixes[int(q.level)-1][q.type] += 1\n\t\t\tassert(int(q.level) == selection.find(q)/7+1)').replace('assert(mix == bank.MIX)','assert(mixes == bank.LEVEL_MIXES)').replace('assert(card_count == 150)','assert(card_count == 537)')
a=s.index('\tassert(retakes == 1 and soundscape.street.playing)');b=s.index('\n\t# Every still',a)
s=s[:a]+'''\tassert(lives == 3 and soundscape.street.playing)
	var timer_before = timer
	_process(.25)
	assert(timer == timer_before)
	await preload("res://tests/v1_checks.gd").run(self)
''' +s[b:]
s=s.replace('retakes == 1','lives == 3').replace('correct_count == 11','correct_count == 21')
a=s.index('\tprint("GAMEPLAY_CHECKS_PASSED:');b=s.index('\n',a)
s=s[:a]+'\tprint("GAMEPLAY_CHECKS_PASSED: 216 questions, 500 randomized 3x7 sessions, all categories per level, 537 selectable cards, 3 lives, audio loops, 69 images and existing room/gesture/sound/ending checks")'+s[b:];p.write_text(s)
for f in ['project.godot','export_presets.cfg']:
 p=Path('game/LastTake/Source')/f;s=p.read_text().replace('0.10.0.0','1.0.0.0').replace('0.10.0','1.0.0').replace('"0.10"','"1.0"');p.write_text(s)
