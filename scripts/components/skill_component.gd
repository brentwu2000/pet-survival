## 特殊技能的冷卻與施放。
##
## 第一版每隻寵物**只有 1 個**特殊技能（規格書 §6）。
class_name SkillComponent
extends Node

signal skill_cast_started(skill: SkillData, target: Node3D)
signal skill_cast_finished()

@export var skill: SkillData

## public 的理由：FSM 的 CAST_SKILL 狀態要靠它判斷何時能離開。
var is_casting: bool = false

var _cooldown_left: float = 0.0


func _physics_process(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)


func can_cast(target: Node3D) -> bool:
	if skill == null or is_casting or not is_zero_approx(_cooldown_left):
		return false
	if not is_instance_valid(target):
		return false
	var body := get_parent() as Node3D
	return body.global_position.distance_squared_to(target.global_position) \
		<= skill.cast_range * skill.cast_range


func cast(target: Node3D) -> void:
	if not can_cast(target):
		return
	is_casting = true
	_cooldown_left = skill.cooldown
	skill_cast_started.emit(skill, target)

	await get_tree().create_timer(skill.cast_time).timeout
	if not is_inside_tree():
		return

	is_casting = false
	if is_instance_valid(target):
		var combat := get_parent().get_node_or_null("CombatComponent") as CombatComponent
		if combat != null:
			combat.deal_damage(target, skill.power, skill.element)
	skill_cast_finished.emit()
