## 持有 HP、處理傷害與死亡、廣播變化。
##
## **不決定**誰能打誰、不播動畫。Player / Pet / Enemy / Building 共用。
class_name HealthComponent
extends Node

signal damaged(amount: float, source: Node)
signal healed(amount: float)
signal health_changed(current: float, maximum: float)
signal died()

@export var max_health: float = 100.0
@export var invulnerable: bool = false

var current_health: float = 0.0
var is_dead: bool = false

## 捕捉率的直接輸入（見 05-capture-system.md）——捕捉系統只讀它，不自己算。
var health_ratio: float:
	get: return current_health / max_health if max_health > 0.0 else 0.0


func _ready() -> void:
	current_health = max_health


## 由 PetData / EnemyData 注入，取代 @export 的編輯器預設值。
## `current` 省略 = 滿血；換寵時由 PetInstance 帶入上次離場時的 HP。
func setup(new_max: float, current: float = -1.0) -> void:
	max_health = new_max
	current_health = new_max if current < 0.0 else clampf(current, 0.0, new_max)
	is_dead = is_zero_approx(current_health)
	health_changed.emit(current_health, max_health)


func take_damage(amount: float, source: Node = null) -> void:
	if is_dead or invulnerable or amount <= 0.0:
		return
	current_health = maxf(current_health - amount, 0.0)
	damaged.emit(amount, source)
	health_changed.emit(current_health, max_health)
	if is_zero_approx(current_health):
		is_dead = true
		died.emit()


func heal(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	current_health = minf(current_health + amount, max_health)
	healed.emit(amount)
	health_changed.emit(current_health, max_health)
