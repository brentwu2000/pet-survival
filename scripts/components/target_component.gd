## 持有「當前目標是誰」與目標有效性驗證。
##
## **不移動、不攻擊。** 移動是 AI 的事，攻擊是 CombatComponent 的事。
class_name TargetComponent
extends Node

signal target_changed(new_target: Node3D)
signal target_lost()

@export var detection_radius: float = 12.0
## 不要每 frame 掃描，見 09-web-performance.md 的效能預算。
@export var scan_interval: float = 0.25

var current_target: Node3D = null

var _scan_timer: float = 0.0
var _body: Node3D = null


func _ready() -> void:
	_body = get_parent() as Node3D
	# 打散相位，避免 50 隻在同一 frame 掃描。
	_scan_timer = randf() * scan_interval


func _physics_process(delta: float) -> void:
	_scan_timer -= delta
	if _scan_timer <= 0.0:
		_scan_timer = scan_interval
		_validate_target()


## 玩家下達 Attack Target 指令走這裡（手動目標優先於自動搜尋）。
func set_target(target: Node3D) -> void:
	if current_target == target:
		return
	current_target = target
	target_changed.emit(target)


func clear_target() -> void:
	if current_target == null:
		return
	current_target = null
	target_lost.emit()


func has_valid_target() -> bool:
	if not is_instance_valid(current_target):
		return false
	var hp := current_target.get_node_or_null("HealthComponent") as HealthComponent
	return hp == null or not hp.is_dead


func distance_to_target() -> float:
	if not has_valid_target():
		return INF
	return _body.global_position.distance_to(current_target.global_position)


func _validate_target() -> void:
	if current_target != null and not has_valid_target():
		clear_target()
