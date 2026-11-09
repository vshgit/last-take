extends RefCounted
const LEVEL_SIZE = 7
const SESSION_SIZE = 21
const LEVEL_MIXES = [
	{"cards":2,"frame":3,"gesture":2},
	{"cards":2,"frame":3,"gesture":2},
	{"cards":2,"frame":2,"gesture":1,"audio":2},
]
static func _shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for i in range(items.size()-1,0,-1):
		var j = rng.randi_range(0,i)
		var item = items[i]
		items[i] = items[j]
		items[j] = item
static func ids(items: Array) -> Array:
	var result: Array = []
	for q in items: result.append(q.id)
	return result
static func make_session(pool: Array, rng: RandomNumberGenerator, previous: Array = []) -> Array:
	var selected: Array = []
	for level in range(1,4):
		var block: Array = []
		var topics: Array = []
		var mix: Dictionary = LEVEL_MIXES[level-1]
		for kind in mix:
			var fresh: Array = []
			var repeats: Array = []
			for q in pool:
				if int(q.level) != level or q.type != kind: continue
				if q.id in previous: repeats.append(q)
				else: fresh.append(q)
			_shuffle(fresh,rng)
			_shuffle(repeats,rng)
			var bucket = fresh + repeats
			assert(bucket.size() >= int(mix[kind]))
			var chosen = 0
			for candidates in [fresh,repeats]:
				for q in candidates:
					if chosen >= int(mix[kind]): break
					if q.topic not in topics:
						block.append(q);topics.append(q.topic);chosen += 1
			for q in bucket:
				if chosen >= int(mix[kind]): break
				if q.id not in ids(block): block.append(q);chosen += 1
		assert(block.size() == LEVEL_SIZE)
		_shuffle(block,rng)
		selected.append_array(block)
	assert(selected.size() == SESSION_SIZE)
	return selected
