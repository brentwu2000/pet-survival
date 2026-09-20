## 換寵的球演出：收回進球、從球裡跑出來。
##
## 用的是捕捉那一套素材（`capture_fx_frames.tres`）與音效——
## **球就是同一顆球**，沒有理由另外做一份；玩家也才會把「抓進去」和「放出來」
## 認成同一件事的兩個方向。
##
## **純表現層**：節點的替換、HP、目標接手早就在 World 做完了，這裡只負責演。
## 演完自己 `queue_free()`。
class_name SummonEffect
extends Node3D

enum Mode {
	## 球從玩家手上飛到定點 → 開球 → 寵物跑出來。節點放在**定點**。
	SUMMON,
	## 球一直在玩家手上 → 寵物被吸過來縮進去 → 球收起來。節點放在**手上**。
	RECALL,
}

## 與 CaptureEffect 用同一份素材與音效。
const FRAMES_PATH := "res://resources/fx/capture_fx_frames.tres"
const SFX_DIR := "res://assets/sfx/capture/"
const PIXEL_SIZE := 0.025

## 球停在多高。與 `CaptureEffect.REST_Y` 一致，兩種演出的球才會在同一個高度。
const REST_Y := 0.38
## 拋物線最高點比直線高多少。
const ARC_HEIGHT := 1.1
## 球飛過去 / 飛回來的時間。
## **寵物什麼時候彈出來也是看它**——World 把這個值當成 `Pet.play_summon()` 的延遲。
const FLY_SECONDS := 0.3
## 開球的星芒比球大，往上挪一點才會以球為中心散開。
const BURST_LIFT := 0.25
## 收回時球關起來的時間。
const CLOSE_SECONDS := 0.12

## --- 收回光束 ---
## 一條從球口張開到寵物身上的光錐。**沒有它就只是「寵物縮小然後不見」**，
## 看不出牠是被收進球裡的。
const BEAM_COLOR := Color(1.0, 0.62, 0.35)
## 球那端細、寵物那端粗——光是從球口射出去罩住寵物。
const BEAM_BALL_RADIUS := 0.045
const BEAM_PET_RADIUS := 0.34
## 光束打開的時間。要比收回本身快很多，才像「先射出光、再把牠吸回來」。
const BEAM_OPEN_SECONDS := 0.07
## 光束瞄準寵物身上的高度（不是腳底）。
const BEAM_AIM_HEIGHT := 0.45

## 由 spawn 端在 add_child 之前設定。
var ball_id: StringName = &"ball_basic"
var mode: Mode = Mode.SUMMON
## 玩家的手在哪（世界座標）。SUMMON 的球從這裡丟出去；RECALL 的球本來就在這裡。
var hand_position: Vector3 = Vector3.ZERO
## RECALL 專用：光束要照的那隻寵物。牠會一邊被吸過來一邊縮小，光束每幀跟著牠。
var target: Node3D = null

var _beam: MeshInstance3D = null
var _beam_mesh: CylinderMesh = null
var _beam_material: StandardMaterial3D = null
## 光束的長度比例（0 = 還沒射出去，1 = 已經罩住寵物）。由 tween 推。
var _beam_reach: float = 0.0
## 光束剛射出去時的長度。之後用「現在／當初」算光錐要收多細。
var _beam_span_max: float = 0.0

@onready var sprite: AnimatedSprite3D = $AnimatedSprite3D
@onready var audio: AudioStreamPlayer3D = $AudioStreamPlayer3D


func _ready() -> void:
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.shaded = false
	sprite.double_sided = false
	sprite.pixel_size = PIXEL_SIZE

	if ResourceLoader.exists(FRAMES_PATH):
		sprite.sprite_frames = load(FRAMES_PATH)


## **必須由 spawn 端在設好 global_position 與 hand_position 之後呼叫。**
## 理由同 CaptureEffect：`_ready()` 是 add_child 當下跑的，那時位置還沒設。
func start() -> void:
	_run()


func _run() -> void:
	var rest := Vector3(0.0, REST_Y, 0.0)
	var hand := to_local(hand_position)
	_play(ball_id)

	if mode == Mode.SUMMON:
		_play_sfx(&"throw")
		await _fly(hand, rest)
		if not is_inside_tree():
			return
		# 球落地 = 開球，寵物同一刻彈出來（World 用 FLY_SECONDS 對齊）
		_play_sfx(&"success")
		await _burst()
		queue_free()
		return

	# RECALL：球不動，**待在玩家手上**等怪被吸回來（節點就放在手上）。
	# 球飛出去接怪看起來像是又要抓一次，方向感是反的。
	sprite.position = Vector3.ZERO
	_play_sfx(&"throw")

	# 先射出光束罩住寵物，再讓牠沿著光被吸回來
	_build_beam()
	var open := create_tween()
	open.tween_property(self, "_beam_reach", 1.0, BEAM_OPEN_SECONDS)

	await get_tree().create_timer(Pet.RECALL_SECONDS).timeout
	if not is_inside_tree():
		return
	# 怪進球了，光束收掉、球關起來
	_clear_beam()
	_play_sfx(&"land")
	var close := create_tween()
	close.tween_property(sprite, "scale", Vector3.ZERO,
		CLOSE_SECONDS).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	await close.finished
	queue_free()


## 光束每幀重算：寵物正在被吸過來，長度與粗細都要跟著變。
func _process(_delta: float) -> void:
	if _beam == null:
		return
	if not is_instance_valid(target):
		_clear_beam()
		return

	var from := global_position
	var to := target.global_position + Vector3(0.0, BEAM_AIM_HEIGHT, 0.0)
	var full := to - from
	if _beam_span_max <= 0.0:
		_beam_span_max = maxf(full.length(), 0.01)

	var span := full * _beam_reach
	var length := span.length()
	if length < 0.01:
		_beam.visible = false
		return

	_beam.visible = true
	_beam_mesh.height = length
	# 寵物越靠近球，罩住牠的那端越細——光錐跟著牠一起收回球口，
	# 不然長度縮到最後會變成球口一坨胖胖的光。
	var closeness := clampf(full.length() / _beam_span_max, 0.0, 1.0)
	_beam_mesh.top_radius = lerpf(
		BEAM_BALL_RADIUS, BEAM_PET_RADIUS, closeness * _beam_reach)
	# CylinderMesh 的軸是 +Y，所以要自己組一組「+Y 指向 span」的 basis
	_beam.global_transform = Transform3D(_basis_towards(span), from + span * 0.5)


## 組一組 +Y 對準 `direction` 的 basis。
func _basis_towards(direction: Vector3) -> Basis:
	var y := direction.normalized()
	# 方向剛好垂直時 cross 會退化成零向量，換一個參考軸
	var reference := Vector3.UP if absf(y.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var x := y.cross(reference).normalized()
	return Basis(x, y, x.cross(y).normalized())


func _build_beam() -> void:
	_beam_mesh = CylinderMesh.new()
	_beam_mesh.bottom_radius = BEAM_BALL_RADIUS
	_beam_mesh.top_radius = BEAM_BALL_RADIUS
	_beam_mesh.radial_segments = 8
	_beam_mesh.rings = 0

	_beam_material = StandardMaterial3D.new()
	_beam_material.albedo_color = BEAM_COLOR
	_beam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# 加法混合才有「發光」感；關背面剔除，從任何角度看都是實心的一道光
	_beam_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_beam_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	_beam = MeshInstance3D.new()
	_beam.name = "Beam"
	_beam.mesh = _beam_mesh
	_beam.material_override = _beam_material
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.visible = false
	add_child(_beam)


func _clear_beam() -> void:
	if _beam == null:
		return
	_beam.queue_free()
	_beam = null


## 一條拋物線：直線插值 + 一條 sin 弧線，最高點在中間。
func _fly(from: Vector3, to: Vector3) -> void:
	sprite.position = from
	var tween := create_tween()
	tween.tween_method(
		func(t: float) -> void:
			sprite.position = from.lerp(to, t) + Vector3.UP * ARC_HEIGHT * sin(PI * t),
		0.0, 1.0, FLY_SECONDS)
	await tween.finished


## 開球的星芒。素材不齊就安靜結束，不要卡住換寵的演出。
func _burst() -> void:
	if not _play(&"success"):
		return
	sprite.position.y = REST_Y + BURST_LIFT
	await sprite.animation_finished


## 音檔還沒進來就安靜播完，不要噴錯。
func _play_sfx(sfx_name: StringName) -> void:
	var path := "%s%s.wav" % [SFX_DIR, sfx_name]
	if not ResourceLoader.exists(path):
		return
	audio.stream = load(path)
	audio.play()


func _play(anim: StringName) -> bool:
	if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(anim):
		return false
	sprite.play(anim)
	return true
