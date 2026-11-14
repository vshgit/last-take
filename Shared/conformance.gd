extends RefCounted
## The same scenarios execute against actual Source and adapted Web game methods.
static func wait_question(g) -> void:
	var started = Time.get_ticks_msec()
	while g.phase == "loading":
		assert(Time.get_ticks_msec()-started < 45000,"Question preparation timed out")
		await g.get_tree().process_frame

static func silence(g) -> void:
	g.voice.stop();g.speaking=false;g.phase_time=1

static func feedback(g) -> void:
	if g.phase == "retake":
		g.phase_time=2;g._process(.01)
		assert(g.retake_spoken and g.voice_id=="retake")
	silence(g);g.phase_time=6;g._process(.01)
	await wait_question(g)

static func run(g, scenarios: Array) -> int:
	g.set_process(false)
	g.qa_mode=true
	var executed = 0
	for scenario in scenarios:
		if scenario.name == "network_wait_and_retry": continue
		g._start(true)
		await wait_question(g)
		if scenario.has("start_question_index"):
			g.question_index=int(scenario.start_question_index)
			g._begin_question()
			await wait_question(g)
		for event in scenario.events:
			var q: Dictionary = g.data.questions[mini(g.question_index,20)]
			match event:
				"answer_during_speech":
					assert(g.speaking)
					g._answer(int(q.correct))
				"pause": g._pause()
				"advance_clock": g._process(40)
				"answer_while_paused": g._answer(int(q.correct))
				"wrong":
					silence(g)
					g._answer((int(q.correct)+1)%q.options.size())
				"timeout":
					silence(g);g.timer=.001;g._process(.1)
				"feedback": await feedback(g)
		for key in scenario.expected:
			assert(g.get(key)==scenario.expected[key],scenario.name+": "+key)
		executed+=1
	# Selection is the shared, unchanged GDScript rather than another implementation.
	var bank = load("res://question_bank.gd")
	var rng = RandomNumberGenerator.new();rng.seed=1729
	for trial in range(100):
		var selected: Array = bank.make_session(g.question_pool,rng)
		assert(selected.size()==21 and bank.ids(selected).size()==21)
		var unique: Dictionary={}
		for q in selected: unique[q.id]=true
		assert(unique.size()==21)
	print("SHARED_RULES_PASSED: ",executed," event scenarios and 100 unchanged-bank sessions")
	return executed
