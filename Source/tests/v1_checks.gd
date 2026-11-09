extends RefCounted
static func silence(g) -> void:
	g.voice.stop();g.speaking=false;g.phase_time=1
static func advance_after_feedback(g) -> void:
	if g.phase == "retake":
		g.phase_time=2;g._process(.01)
		assert(g.retake_spoken and g.voice_id == "retake")
	silence(g);g.phase_time=6;g._process(.01)
static func run(g) -> void:
	g._start(true)
	g._answer(-1);g._answer(3)
	assert(g.lives==3 and g.phase=="question")
	g._answer((int(g.data.questions[0].correct)+1)%g.data.questions[0].options.size())
	assert(g.lives==3,"Answer during speech")
	silence(g);g._pause();g._answer(0);g._process(100)
	assert(g.lives==3 and g.phase=="paused")
	g._resume()
	for attempt in range(3):
		silence(g)
		var q = g.data.questions[g.question_index]
		g._answer((int(q.correct)+1)%q.options.size())
		assert(g.lives==2-attempt)
		if attempt<2:
			assert(g.phase=="retake")
			g._answer(int(q.correct));assert(g.lives==2-attempt)
			advance_after_feedback(g)
			assert(g.phase=="question" and g.question_index==attempt+1)
			assert(g.data.questions[g.question_index].id!=q.id)
			assert(g.timer==18 and g.speaking)
		else: assert(g.phase=="death" and g.death_reason=="wrong_v1")
	g._start(true);assert(g.lives==3 and g.question_index==0)
	for attempt in range(3):
		silence(g);g.timer=.001;g._process(.1)
		assert(g.lives==2-attempt)
		if attempt<2: advance_after_feedback(g)
		else: assert(g.phase=="death" and g.death_reason=="timeout")
	g._start(true)
	for i in range(21):
		silence(g)
		var q = g.data.questions[i]
		assert(int(q.level)==i/7+1)
		g._answer((int(q.correct)+1)%q.options.size() if i in [6,13] else int(q.correct))
		advance_after_feedback(g)
		if i in [6,13]: assert(g.lives==2 if i==6 else g.lives==1)
	assert(g.phase=="victory" and g.lives==1 and g.correct_count==19)
	g._start(true);g.question_index=20;g._begin_question();silence(g)
	var last = g.data.questions[20]
	g._answer((int(last.correct)+1)%last.options.size());advance_after_feedback(g)
	assert(g.phase=="victory" and g.lives==2)
	var audio_count=0
	for q in g.question_pool:
		if q.type!="audio": continue
		audio_count+=1;g.data.questions=[q];g.question_index=0;g.lives=3;g._begin_question()
		assert(g.cards.size()==3 and g.question_audio.playing and g.question_audio.stream.loop)
		assert(g.projected_frame.visible)
		assert(g.projection_material.get_shader_parameter("frame_tex").resource_path.ends_with(q.id+".jpg"))
		var remaining=g.timer;g._process(.25);assert(g.timer==remaining)
		silence(g);g._process(.25);assert(g.timer<remaining and g.question_audio.playing)
		g._pause();assert(g.question_audio.stream_paused)
		var held=g.question_audio.get_playback_position();g._process(.25)
		assert(g.question_audio.get_playback_position()==held)
		g._resume();assert(not g.question_audio.stream_paused)
		g._answer(3);assert(g.question_audio.playing and g.lives==3)
		g._answer(int(q.correct));assert(not g.question_audio.playing and g.question_audio.stream==null)
		g._begin_question();silence(g);g._answer((int(q.correct)+1)%3)
		assert(g.lives==2 and not g.question_audio.playing)
		g._begin_question();silence(g);g.lives=1;g.timer=.001;g._process(.1)
		assert(g.phase=="death" and not g.question_audio.playing)
		g._begin_question();g._set_menu();assert(not g.question_audio.playing)
		g.data.questions=[q];g.question_index=0;g._begin_question();g._start(false)
		assert(not g.question_audio.playing and g.lives==3)
	assert(audio_count==16)
	var sample:Dictionary
	for q in g.question_pool:
		if q.type=="audio":sample=q;break
	g.data.questions=[sample];g.question_index=0;g._begin_question();silence(g)
	g.question_audio.seek(maxf(0,g.question_audio.stream.get_length()-.1))
	await g.get_tree().create_timer(.5).timeout
	assert(g.question_audio.playing and g.phase=="question" and g.question_index==0)
	assert(g.question_audio.get_playback_position()<1.5)
	g._set_menu();assert(not g.hud.visible and not g.retakes_label.is_visible_in_tree())
	print("V1_CHECKS_PASSED: three lives, wrong/timeout progression, level boundaries, terminal and last-question errors, all 16 audio projections, pause, stream wrap and cleanup")
