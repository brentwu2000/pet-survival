## 主角的視覺容器（規格書 §23、PHASE_PLAYER_PROTOTYPE §6）。
##
## 方向判定和寵物共用 `SpriteDirection`——兩邊各寫一套的話，
## 轉鏡頭時主角和夥伴會不同步，而且很難察覺是哪裡不一致。
class_name PlayerVisual
extends Node3D

const FRAMES_PATH := "res://resources/player/frames_yellow_robot.tres"
## 和寵物同一個值，主角與夥伴的比例才對得上。
const PIXEL_SIZE := 0.025

## 已定案 8 方向；4 方向模式保留只當比較工具。
@export_enum("4 方向:4", "8 方向:8") var direction_count: int = 8

@onready var sprite: AnimatedSprite3D = $AnimatedSprite3D
## 素材還沒進來時頂替用的膠囊，有素材就自動隱藏。
@onready var placeholder: MeshInstance3D = $Placeholder

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

	if ResourceLoader.exists(FRAMES_PATH):
		sprite.sprite_frames = load(FRAMES_PATH)
	placeholder.visible = sprite.sprite_frames == null
	_refresh()


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


## 由 player.gd 依速度決定 idle / walk。
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
	# 依序退回：base_方向 -> base -> idle_方向 -> idle
	for candidate: StringName in [
		StringName("%s_%s" % [_anim_base, suffix]),
		_anim_base,
		StringName("idle_%s" % suffix),
		&"idle",
	]:
		if sprite.sprite_frames.has_animation(candidate):
			sprite.play(candidate)
			return
