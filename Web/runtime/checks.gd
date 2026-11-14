extends RefCounted

static func run(g) -> void:
	assert(is_instance_valid(g.skeleton) and g.skeleton.find_bone("hand_r")>=0 and g.skeleton.find_bone("head")>=0)
	assert(is_instance_valid(g.gun_target) and is_instance_valid(g.player_body))
	assert(g.dynamics.reels.size()==2 and is_instance_valid(g.dynamics.lens))
	var contract = preload("res://shared/conformance.gd")
	var scenarios: Array = JSON.parse_string(FileAccess.get_file_as_string("res://shared/scenarios.json"))
	var count: int = await contract.run(g,scenarios)
	var provider = g.web_content
	# Check the normal prefetch window after all in-flight transfers settle.
	g._start(true)
	await contract.wait_question(g)
	await g.get_tree().process_frame
	while provider.busy: await g.get_tree().process_frame
	var allowed: Dictionary = {}
	for index in range(3):
		for asset in provider.manifest.questions[g.data.questions[index].id]: allowed[asset]=true
	for asset in provider.cache: assert(allowed.has(asset),"Media cache escaped current+two-next window")
	# A real missing HTTP resource exercises failure, timer freeze and same-ID retry.
	g._start(true)
	await contract.wait_question(g)
	while provider.busy: await g.get_tree().process_frame
	provider.cache.clear()
	var q: Dictionary = g.data.questions[0]
	var path: String = provider.manifest.questions[q.id][0]
	var original: Dictionary = provider.manifest.assets[path].duplicate(true)
	provider.manifest.assets[path].file="media/intentional-conformance-404.ogg"
	g._begin_question()
	while not provider.retry_button.visible: await g.get_tree().process_frame
	var held_timer: float = g.timer
	g._process(40)
	assert(g.phase=="loading" and g.lives==3 and g.question_index==0 and g.timer==held_timer)
	g._pause();assert(g.phase=="paused" and g.previous_phase=="loading")
	provider.manifest.assets[path]=original
	g._resume()
	await contract.wait_question(g)
	# resume_loading schedules preparation; wait until it actually enters/exits loading.
	await g.get_tree().process_frame
	await contract.wait_question(g)
	assert(g.phase=="question" and g.lives==3 and g.data.questions[0].id==q.id and g.timer==18)
	# One actual image and one user audio question, including pause and stop.
	for kind in ["frame","audio"]:
		var sample: Dictionary
		for item in g.question_pool:
			if item.type==kind: sample=item;break
		provider.cancel();g.data.questions=[sample];g.question_index=0;g.lives=3
		g._begin_question();await contract.wait_question(g)
		assert(g.cards.size()==3)
		if kind=="frame": assert(provider.cache.has(sample.image))
		if kind=="audio":
			assert(g.question_audio.playing and g.question_audio.stream.loop)
			g._pause();assert(g.question_audio.stream_paused)
			g._resume();assert(not g.question_audio.stream_paused)
		contract.silence(g);g._answer(int(sample.correct))
		assert(not g.question_audio.playing)
	provider.test_result={"passed":true,"event_scenarios":count+1,"image_and_user_audio":true,"real_http_404_retry":true}
	print("WEB_PROTOTYPE_CHECKS_PASSED: shared rules, real HTTP failure/retry, pause, image, audio and bounded window")
	g.set_process(true)
	g._set_menu()
	if not OS.has_feature("web"):
		provider.cache.clear()
		await g._close_test()
