## 寵物的視覺容器（規格書 §23）。
##
## 方向判定的核心是**角色朝向相對於鏡頭朝向**，不是角色的世界朝向——
## Camera 可以繞角色轉，所以同一個世界朝向在不同鏡頭角度要播不同方向的圖。
##
## 規格書 §9：AI FSM 與 Visual Animation 儘量分離。
## FSM 只 emit state_changed，由這裡決定播什麼。**FSM 裡不得出現 sprite.play()。**
class_name PetVisual
extends Node3D

## 1 像素等於多少公尺。全專案統一：64px 的素材 = 1.6 公尺高。
const PIXEL_SIZE := 0.025

## 規劃書 §13 的研究題：「2D 怪獸放在可旋轉的 3D 世界，需要幾個方向才自然？」
##
## **已定案：8 方向。** 正式素材（Walk / Attack / Skill / Hit / Dead）都要做 8 套。
## 4 方向模式保留下來只當比較工具，不要拿它當正式設定。
@export_enum("4 方向:4", "8 方向:8") var direction_count: int = 8

@onready var sprite: AnimatedSprite3D = $AnimatedSprite3D

var _body: Node3D = null
var _direction_index: int = 0
var _anim_base: StringName = &"idle"


func _ready() -> void:
	_body = get_parent() as Node3D

	# 逐項理由見 07-sprite3d-visuals.md。alpha_cut 設錯的症狀是
	# 「角色在某些角度互相閃爍/消失」，而且很難聯想到原因。
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.shaded = false
	sprite.double_sided = false
	sprite.pixel_size = PIXEL_SIZE

	# FSM 只說「在做什麼」，播什麼動畫由這裡決定（規格書 §9）。
	var ai := _body.get_node_or_null("PetAI") as PetAI
	if ai != null:
		ai.state_changed.connect(_on_ai_state_changed)


func _on_ai_state_changed(_from: PetAI.State, to: PetAI.State) -> void:
	match to:
		PetAI.State.IDLE, PetAI.State.DEFEND:
			set_animation(&"idle")
		PetAI.State.FOLLOW, PetAI.State.CHASE, PetAI.State.RETURN:
			set_animation(&"walk")
		PetAI.State.ATTACK:
			set_animation(&"attack")
		PetAI.State.CAST_SKILL:
			set_animation(&"skill")
		PetAI.State.DEAD:
			set_animation(&"death")


## 視覺放 _process 不放 _physics_process：跟畫面更新對齊，且省物理 tick。
func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or _body == null:
		return
	var index := SpriteDirection.index_for(
		_body.global_basis.z, camera.global_basis.z, direction_count)
	if index != _direction_index:
		_direction_index = index
		_refresh()


func setup(frames: SpriteFrames, visual_scale: float) -> void:
	sprite.sprite_frames = frames
	scale = Vector3.ONE * visual_scale
	_refresh()


## 由 PetAI 的 state_changed 驅動（PetAI 落地後接上）。
func set_animation(base: StringName) -> void:
	if _anim_base == base:
		return
	_anim_base = base
	_refresh()


func _refresh() -> void:
	if sprite.sprite_frames == null:
		return
	var names := SpriteDirection.names_for(direction_count)
	var suffix := names[_direction_index % names.size()]
	# Placeholder 階段允許動畫不齊（規劃書 §4：素材先做 idle，玩法不等美術）。
	# 依序退回：base_方向 -> base -> idle_方向 -> idle。
	# 少了最後兩層的話，只有 idle 素材時一切換成 walk 就再也不會更新方向。
	for candidate: StringName in [
		StringName("%s_%s" % [_anim_base, suffix]),
		_anim_base,
		StringName("idle_%s" % suffix),
		&"idle",
	]:
		if sprite.sprite_frames.has_animation(candidate):
			sprite.play(candidate)
			return
