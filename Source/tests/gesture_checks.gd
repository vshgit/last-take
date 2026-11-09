extends RefCounted
const Detector=preload("res://gesture_input.gd")

static func replay(axis:int,direction:float,amplitude:float,duration:float,fps:int,cross:float) -> void:
	var d=Detector.new();d.motion(0,0);d.update(3.0)
	var answers:Array=[]
	var steps=maxi(6,roundi(duration*fps))
	for i in range(steps+1):
		var t=float(i)/steps
		var stroke=(t*2.0 if t<=.5 else 1.0-(t-.5)*1.30)*amplitude*direction
		var p=Vector2.ZERO;p[axis]=stroke;p[1-axis]=stroke*cross
		d.update(duration/steps)
		var answer=d.motion(p.x,p.y)
		if answer>=0:answers.append(answer)
	assert(answers==[axis],"Gesture replay failed: %s"%str([axis,direction,amplitude,duration,fps,cross,answers]))

static func send(g,event:InputEventMouseMotion) -> void:
	if DisplayServer.get_name()=="headless":g._look_motion(event.screen_relative)
	else:g._unhandled_input(event)

static func run(g) -> void:
	var total=0
	for axis in [0,1]:
		for direction in [-1.0,1.0]:
			for amplitude in [.08,.16,.38]:
				for duration in [.28,.60,1.30]:
					for fps in [30,60,144]:
						for cross in [0.0,.3,.5]:
							replay(axis,direction,amplitude,duration,fps,cross);total+=1
	for kind in ["jitter","diagonal","pan","slow","interrupted"]:
		var d=Detector.new();d.motion(0,0)
		for i in range(160):
			var t=float(i)/159.0
			var amount=sin(t*PI)*.20
			var p=Vector2(amount,0)
			if kind=="jitter":p=Vector2(sin(i*2)*.009,cos(i*1.7)*.009)
			if kind=="diagonal":p.y=amount
			if kind=="pan":p.x=t*.4
			d.update(.06 if kind=="slow" else .01)
			if kind=="interrupted" and i==80:d.update(1.0)
			assert(d.motion(p.x,p.y)==-1,"False answer: "+kind)
	print("GESTURE_REPLAYS_PASSED: ",total," positive replays; jitter, diagonal, pan, slow and interrupted motion rejected")
	var question:Dictionary={}
	for q in g.question_pool:
		if q.type=="gesture":question=q.duplicate(true);break
	for axis in [0,1]:
		for start in [Vector2.ZERO,Vector2(-1.15,-1.22),Vector2(1.15,1.35)]:
			for window_scale in [.5,1.0,2.0]:
				question.correct=axis;g.data.questions=[question];g.question_index=0
				g._begin_question();g.voice.stop();g.speaking=false;g.phase_time=1
				g.yaw=start.x;g.pitch=start.y;g._reset_gesture()
				Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
				for i in range(24):
					g._process(.025)
					var motion=Vector2.ZERO;motion[axis]=10 if i<12 else -10
					var event=InputEventMouseMotion.new();event.screen_relative=motion;event.relative=motion*window_scale
					send(g,event)
				assert(g.phase=="correct","Input failed at camera boundary / viewport scale")
	g.data.questions=[question];g.question_index=0;g._begin_question()
	for i in range(24):g._look_motion(Vector2(0,10 if i<12 else -10))
	assert(g.phase=="question" and not g.gesture_ready,"Speech must block answers")
	g.voice.stop();g.speaking=false;g.phase_time=1;g._arm_gesture()
	g._look_motion(Vector2(0,80));g._pause();g._resume()
	assert(not g.gesture_ready,"Pause must clear unfinished gesture")
	print("GESTURE_INPUT_CHECKS_PASSED: both axes, camera bounds, viewport scale, speech and pause")
