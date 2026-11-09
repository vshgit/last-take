extends SkeletonModifier3D

var curls: Dictionary = {}
var opposed_thumb = Quaternion.IDENTITY
var thumb_index = -1

func configure(s: Skeleton3D) -> void:
	# Flexion is expressed in each bone's own rest basis, so the grip follows IK.
	var width = (s.get_bone_global_rest(s.find_bone("index_01_r")).origin-s.get_bone_global_rest(s.find_bone("pinky_01_r")).origin).normalized()
	for finger in ["middle","ring","pinky","index","thumb"]:
		for joint in range(1,4):
			var i = s.find_bone("%s_0%d_r"%[finger,joint])
			if i < 0:continue
			var axis = s.get_bone_global_rest(i).basis.inverse()*width
			var angle = [1.05,1.32,.75][joint-1]
			if finger == "index":angle=[.42,.85,.60][joint-1]
			if finger == "thumb":angle=[.30,.65,.55][joint-1]
			curls[i] = Quaternion(axis.normalized(),angle)
	# The thumb opposes the fingers; bending it about the other fingers' axis alone
	# leaves it sticking above the receiver.
	thumb_index=s.find_bone("thumb_01_r")
	var thumb=s.get_bone_global_rest(thumb_index)
	var wrist=s.get_bone_global_rest(s.find_bone("hand_r")).origin
	var middle=s.get_bone_global_rest(s.find_bone("middle_01_r")).origin
	var index=s.get_bone_global_rest(s.find_bone("index_01_r")).origin
	var pinky=s.get_bone_global_rest(s.find_bone("pinky_01_r")).origin
	var front=(middle-wrist).normalized()
	var up=(width-front*width.dot(front)).normalized()
	var right=up.cross(front).normalized()
	var target=(index+pinky)*.5-right*.007+up*.026+front*.010
	var turn=Quaternion(thumb.basis.y.normalized(),(target-thumb.origin).normalized())
	var parent_rest=s.get_bone_global_rest(s.get_bone_parent(thumb_index))
	opposed_thumb=(parent_rest.basis.inverse()*Basis(turn)*thumb.basis).get_rotation_quaternion()

func _process_modification() -> void:
	var s = get_skeleton()
	if not s:return
	for i in curls:
		s.set_bone_pose_rotation(i,s.get_bone_rest(i).basis.get_rotation_quaternion()*curls[i])
	if thumb_index>=0:s.set_bone_pose_rotation(thumb_index,opposed_thumb)
