## 普攻的冷卻、射程判定、傷害計算與送出。
##
## **不決定目標**（TargetComponent 的事）、**不移動**（AI 的事）。
## 全專案的傷害公式只存在 deal_damage 這一處。
class_name CombatComponent
extends Node

signal attack_started(target: Node3D)
signal attack_landed(target: Node3D, damage: float)

@export var attack_power: float = 10.0
@export var defense: float = 0.0
@export var attack_range: float = 2.0
@export var attack_cooldown: float = 1.0

## 本體屬性 = **防禦側**。別人打過來時，用它查自己被克不被克。
## 來自 PetData.element（種族屬性）。
@export var element: Element.Type = Element.Type.FIRE
## 普攻的屬性 = **攻擊側**。來自 basic_attack.element。
## 兩者分開的理由：一隻 Water 的寵物可以有 Fire 的招式，
## 合在一起會讓「防禦屬性」被普攻的屬性蓋掉。
@export var attack_element: Element.Type = Element.Type.FIRE

## 傷害下限：再不利也至少打 1 點，避免出現永遠打不死的對局。
const MIN_DAMAGE := 1.0

## 防禦的遞減常數。防禦不是直接扣傷害，而是按 K/(K+defense) 打折。
##
## 原本是線性的 `power - defense`，但蛋殼龍 DEF 20 對上威力 14~18 的攻擊時，
## 只要不是克制方就會被扣成負數、一律落到 MIN_DAMAGE，等於「非克制 = 完全無傷」。
## 改成遞減之後防禦仍然有感，但不會出現硬牆。
const DEFENSE_K := 100.0

var _cooldown_left: float = 0.0
var _body: Node3D = null


func _ready() -> void:
	_body = get_parent() as Node3D


func _physics_process(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)


func can_attack() -> bool:
	return is_zero_approx(_cooldown_left)


func in_range(target: Node3D) -> bool:
	if not is_instance_valid(target):
		return false
	# 用 distance_squared_to 省一次開根號（09 的「成本為零」項目）。
	return _body.global_position.distance_squared_to(target.global_position) \
		<= attack_range * attack_range


func try_attack(target: Node3D) -> bool:
	if not can_attack() or not in_range(target):
		return false
	_cooldown_left = attack_cooldown
	attack_started.emit(target)
	deal_damage(target, attack_power, attack_element)
	return true


## SkillComponent 也呼叫這支，所以是 public。
## 屬性倍率一律問 Database.element_table（硬規則 5），這裡不得出現 if element == ...
func deal_damage(target: Node3D, power: float, atk_element: Element.Type) -> void:
	var hp := target.get_node_or_null("HealthComponent") as HealthComponent
	if hp == null:
		return

	var target_combat := target.get_node_or_null("CombatComponent") as CombatComponent
	var target_defense := target_combat.defense if target_combat != null else 0.0

	# 防禦側一律讀 target_combat.element（種族屬性），不是牠普攻的屬性。
	var multiplier := ElementTable.NORMAL
	if target_combat != null and Database.element_table != null:
		multiplier = Database.element_table.get_multiplier(atk_element, target_combat.element)

	var mitigation := DEFENSE_K / (DEFENSE_K + maxf(target_defense, 0.0))
	var damage := maxf(power * multiplier * mitigation, MIN_DAMAGE)
	hp.take_damage(damage, _body)
	attack_landed.emit(target, damage)
