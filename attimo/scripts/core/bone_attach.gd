class_name BoneAttach
extends RefCounted
## Shared helper of the presentations that hang visuals on the Mannequin skeleton (HandPresentation, ArmEnergyPresentation): one
## BoneAttachment3D per bone, found again when it already exists so two presentations on the same bone share it.

## The skeleton node under the Mannequin scene root.
const SKELETON_PATH: NodePath = ^"Rig_Medium/Skeleton3D"


## The Skeleton3D under `mannequin`, or null without a mannequin or a skeleton.
static func skeleton_of(mannequin: Node3D) -> Skeleton3D:
	if mannequin == null:
		return null
	return mannequin.get_node_or_null(SKELETON_PATH) as Skeleton3D


## The BoneAttachment3D of `bone` on `skeleton`: the existing one, else a new one. Returns null when the bone does not exist.
static func attach(skeleton: Skeleton3D, bone: StringName) -> BoneAttachment3D:
	if skeleton == null or skeleton.find_bone(bone) < 0:
		return null
	var attachment_name: StringName = StringName("%sAttachment" % String(bone).replace(".", "_"))
	var existing: BoneAttachment3D = skeleton.get_node_or_null(NodePath(attachment_name)) as BoneAttachment3D
	if existing != null:
		return existing
	var attachment: BoneAttachment3D = BoneAttachment3D.new()
	attachment.name = attachment_name
	attachment.bone_name = bone
	skeleton.add_child(attachment)
	return attachment
