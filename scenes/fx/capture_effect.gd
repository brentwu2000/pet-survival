## 捕捉的視覺回饋（規格書 §10：「播放捕捉 Feedback」）。
##
## 判定在 CaptureSystem 就已經算完了——這裡只是把結果演出來，
## 純表現層，不影響任何 gameplay 結果。
##
## 節奏常數全部讀 CaptureSystem，和 Pet 的縮放共用同一組，兩邊才不會慢慢對不上。
class_name CaptureEffect
extends Node3D

const FRAMES_PATH := "res://resources/fx/capture_fx_frames.tres"
const SFX_DIR := "res://assets/sfx/capture/"
const PIXEL_SIZE := 0.025

## 球最後停在多高。
const REST_Y := 0.38
## 沒有投擲起點時（例如測試直接生特效）改成從這個高度落下。
const DROP_FROM_Y := 1.5
## 拋物線的最高點比直線高多少。
const ARC_HEIGHT := 1.1

## 由 spawn 端在 add_child 之前設定。
var ball_id: StringName = &"ball_basic"
var success: bool = false
var shakes: int = CaptureSystem.MAX_SHAKES
## 投擲起點（世界座標）。沒設就退化成從正上方落下。
var throw_from: Vector3 = Vector3.ZERO
var has_throw_origin: bool = false

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


## **必須由 spawn 端在設好位置與 throw_from 之後呼叫。**
##
## 不在 _ready() 自動跑的理由：_ready() 是在 add_child() 當下執行的，
## 而 global_position 得先進樹才能設。如果在 _ready() 就算拋物線，
## 會拿到還沒設定的 throw_from 與還在原點的自己——球就永遠不會飛。
func start() -> void:
	_run()


func _run() -> void:
	var has_ball := _play(ball_id)
	_throw()
	_play_sfx(&"throw")

	await get_tree().create_timer(CaptureSystem.THROW_SECONDS).timeout
	if not is_inside_tree():
		return
	_play_sfx(&"land")

	# 怪獸被吸進去
	await get_tree().create_timer(CaptureSystem.ABSORB_SECONDS).timeout

	# 每搖一下響一次。搖幾下由判定結果決定，所以聲音也在說「差多少」。
	for i in shakes:
		if not is_inside_tree():
			return
		_play_sfx(&"shake")
		await get_tree().create_timer(CaptureSystem.SHAKE_SECONDS).timeout
	if not is_inside_tree():
		return

	_play_sfx(&"success" if success else &"fail")

	if not _play(&"success" if success else &"fail"):
		await get_tree().create_timer(0.4).timeout
		queue_free()
		return

	if has_ball:
		# 星芒 / 煙塵比球大，往上挪一點才會以球為中心散開
		sprite.position.y = REST_Y + 0.25
	await sprite.animation_finished
	queue_free()


## 從玩家手上畫一條拋物線飛到目標身上。
func _throw() -> void:
	var rest := Vector3(0.0, REST_Y, 0.0)

	if not has_throw_origin:
		# 退化路徑：從正上方落下。TRANS_BOUNCE 給重量感，比線性下墜好。
		sprite.position = Vector3(0.0, DROP_FROM_Y, 0.0)
		var drop := create_tween()
		drop.tween_property(sprite, "position", rest, CaptureSystem.THROW_SECONDS)
		drop.set_ease(Tween.EASE_OUT)
		drop.set_trans(Tween.TRANS_BOUNCE)
		return

	var start := to_local(throw_from)
	sprite.position = start
	var tween := create_tween()
	# 直線插值 + 一條 sin 弧線，最高點在中間
	tween.tween_method(
		func(t: float) -> void:
			sprite.position = start.lerp(rest, t) + Vector3.UP * ARC_HEIGHT * sin(PI * t),
		0.0, 1.0, CaptureSystem.THROW_SECONDS)


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
