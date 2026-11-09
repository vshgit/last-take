extends RefCounted
static func run(g) -> void:
	var detector=preload("res://gesture_input.gd").new()
	for axis in [0,1]:
		detector.reset();detector.motion(0,0);var result=-1
		for i in range(1,21):
			detector.update(.025);var distance=sin(float(i)/20*PI)*.16
			var value=detector.motion(distance if axis==0 else 0,distance if axis==1 else 0)
			if value>=0:result=value
		assert(result==axis and detector.motion(0,0)==-1)
	for mode in ["jitter","pan","diagonal","slow"]:
		detector.reset();detector.motion(0,0)
		for i in range(1,61):
			detector.update(.05 if mode=="slow" else .01)
			var angle=sin(float(i)/60*PI)*(.02 if mode=="jitter" else .18)
			if mode=="pan":angle=float(i)*.004
			assert(detector.motion(angle,angle if mode=="diagonal" else 0)==-1,mode+" falsely answered")
	for q in g.question_pool:
		if q.type!="gesture":continue
		g.data.questions=[q];g.question_index=0;g._begin_question()
		assert(g.cards.is_empty() and g.speaking and g.projected_frame.visible)
		assert(g.projection_material.get_shader_parameter("frame_tex").resource_path.ends_with(q.id+".jpg"))
		g._look_motion(Vector2(0,-120));assert(g.phase=="question")
		g.voice.stop();g.speaking=false;g.phase_time=1;g._process(.01)
		var axis=0 if int(q.correct)==0 else 1
		for i in range(20):
			g._process(.025)
			g._look_motion(Vector2((12 if i<10 else -12) if axis==0 else 0,(12 if i<10 else -12) if axis==1 else 0))
		assert(g.phase=="correct","Gesture not routed into answer")
	g._start(true);g.voice.stop();g.speaking=false;g.phase_time=1;g._process(.01)
	assert(g.crosshair.is_visible_in_tree() and not g.hud.is_visible_in_tree())
	g._pause();assert(not g.crosshair.visible);g._resume()
	assert(g.data.intro.size()==3)
	for line in g.data.intro:assert(line.action!="gun")
	assert(g.has_node("KakVKinoPoster") and g.has_node("DetailedPopcorn"))
	assert(g.gun.has_node("FittedRightHand"))
	assert(g.key_light.omni_range<g.key_light.global_position.distance_to(g.actor.global_position+Vector3(0,1.6,0)))
	for walker in g.dynamics.passers:
		for mesh in walker.find_children("*","MeshInstance3D",true,false):assert(mesh.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)
	var min_pos=Vector3.INF;var max_pos=-Vector3.INF;g.phase="intro"
	for i in range(600):
		g.clock+=.0167;g.dynamics.update(g.clock);var p=g.dynamics.fly.position
		min_pos=min_pos.min(p);max_pos=max_pos.max(p)
		assert(g.key_light.light_energy>=2.8*.82)
	assert((max_pos-min_pos).y>.13 and (max_pos-min_pos).x>.15 and (max_pos-min_pos).z>.15)
	assert(not g.eyelids.visible)
	g._set_menu();g._update_camera(0);g.dynamics.update(g.clock)
	assert(g.dynamics.beam.visible and g.soundscape.film.playing)
	assert(g.camera.position.distance_to(g.dynamics.projector.position)<1.2)
	g._begin_victory();g.voice.stop();g.speaking=false
	g.phase_time=g.voice_meta.win.duration+1.79;g._process(.02)
	assert(g.shot and g.blood.droplets.size()==38)
	g._process(g.FALL_SECONDS);assert(g.phase=="victory" and not g.ending.visible)
	assert(absf(g.actor.rotation.z+1.40)<.01)
	for d in g.blood.droplets:assert(d.hit)
	g._process(1.9);assert(g.phase=="victory" and not g.ending.visible)
	g._process(.11);assert(g.phase=="ended")
	print("V09_CHECKS_PASSED: gestures, speech gating, projection, reticle, intro, fitted hand, poster, popcorn, face shadow, passers, fly, stable lamp, menu, blood, fall and 2-second hold")
