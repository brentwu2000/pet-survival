## 玩家鏡頭（規格書 §24）。
##
## 結構：OrbitCamera (Node3D) 負責旋轉，子節點 Camera3D 只在 local -Z 退開 distance。
## 這樣 global_basis 就是乾淨的鏡頭朝向，給玩家移動與 sprite 四方向判定共用。
class_name OrbitCamera
extends Node3D

@export var target: Node3D

@export_group("Zoom")
@export var distance: float = 10.0
@export var min_distance: float = 4.0
@export var max_distance: float = 20.0
@export var zoom_step: float = 1.0

@export_group("Orbit")
## 對外一律用「度」（編輯器好調），內部一律用弧度。
@export var min_pitch_deg: float = -60.0
@export var max_pitch_deg: float = -15.0
@export var start_pitch_deg: float = -35.0
@export var orbit_sensitivity: float = 0.005
@export var follow_smoothing: float = 10.0

@onready var _camera: Camera3D = $Camera3D

var _yaw: float = 0.0
var _pitch: float = 0.0
var _is_orbiting: bool = false


func _ready() -> void:
	# 不要就地把同一個變數 deg_to_rad()——重跑 _ready 會二次轉換。
	_pitch = deg_to_rad(start_pitch_deg)
	if target != null:
		global_position = target.global_position


## 用 _unhandled_input 不用 _input：UI 吃掉的事件不該再觸發鏡頭。
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("camera_orbit"):
		_is_orbiting = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_released("camera_orbit"):
		_is_orbiting = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseMotion and _is_orbiting:
		var motion := event as InputEventMouseMotion
		_yaw -= motion.relative.x * orbit_sensitivity
		_pitch = clampf(
			_pitch - motion.relative.y * orbit_sensitivity,
			deg_to_rad(min_pitch_deg),
			deg_to_rad(max_pitch_deg))
	elif event.is_action_pressed("camera_zoom_in"):
		distance = clampf(distance - zoom_step, min_distance, max_distance)
	elif event.is_action_pressed("camera_zoom_out"):
		distance = clampf(distance + zoom_step, min_distance, max_distance)


## 跟隨放 _process（視覺），移動放 _physics_process；輕微延遲是刻意的手感。
func _process(delta: float) -> void:
	if target == null:
		return
	global_position = global_position.lerp(
		target.global_position, minf(follow_smoothing * delta, 1.0))
	rotation = Vector3(_pitch, _yaw, 0.0)
	_camera.position = Vector3(0.0, 0.0, distance)
