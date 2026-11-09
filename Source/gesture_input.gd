extends RefCounted

# Deliberate stroke and reversal, using unclamped mouse travel.
const START_DISTANCE = .018
const MIN_STROKE = .070
const MIN_RETURN = .040
const RETURN_FRACTION = .50
const AXIS_DOMINANCE = 1.65
const MIN_DURATION = .10
const MAX_DURATION = 1.80
const MAX_IDLE = .65
var elapsed = 0.0
var committed = false
var initialized = false
var origin = Vector2.ZERO
var last = Vector2.ZERO
var started_at = 0.0
var moved_at = 0.0
var axis = -1
var direction = 1.0
var peak = 0.0
var cross_min = 0.0
var cross_max = 0.0

func reset() -> void:
	elapsed=0;committed=false;initialized=false;axis=-1
	origin=Vector2.ZERO;last=Vector2.ZERO;peak=0;cross_min=0;cross_max=0
	started_at=0;moved_at=0

func _restart(point:Vector2) -> void:
	origin=point;last=point;axis=-1;peak=0;cross_min=0;cross_max=0
	started_at=elapsed;moved_at=elapsed;initialized=true

func update(delta:float) -> void:
	elapsed+=delta
	if initialized and not committed:
		if elapsed-moved_at>MAX_IDLE or (axis>=0 and elapsed-started_at>MAX_DURATION):
			_restart(last)

func motion(yaw:float,pitch:float) -> int:
	if committed:return -1
	var point=Vector2(yaw,pitch)
	if not initialized:
		_restart(point)
		return -1
	if point.distance_squared_to(last)<.0000000001:return -1
	last=point;moved_at=elapsed
	var travel=point-origin
	if axis<0:
		if travel.length()<START_DISTANCE:return -1
		if absf(travel.x)>absf(travel.y)*AXIS_DOMINANCE:axis=0
		elif absf(travel.y)>absf(travel.x)*AXIS_DOMINANCE:axis=1
		else:
			_restart(point)
			return -1
		direction=signf(travel[axis]);started_at=elapsed
	var forward=travel[axis]*direction
	var lateral=travel[1-axis]
	peak=maxf(peak,forward)
	cross_min=minf(cross_min,lateral);cross_max=maxf(cross_max,lateral)
	if cross_max-cross_min>maxf(MIN_STROKE,peak)/AXIS_DOMINANCE:
		_restart(point)
		return -1
	if peak>=MIN_STROKE and peak-forward>=maxf(MIN_RETURN,peak*RETURN_FRACTION) and elapsed-started_at>=MIN_DURATION:
		committed=true
		return axis
	return -1
