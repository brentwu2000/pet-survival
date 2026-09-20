## 捕捉率的設計旋鈕（規格書 §10）。
##
## 規格書只規定**形狀**：HP 越低越容易、稀有度越高越難、普通情況不到 100%。
## 具體數值是設計要調的，所以放 Resource 不放 script（見 06-data-resources.md）。
##
## 形狀不可改（單調遞減、上限 < 1.0），數值隨便調。
class_name CaptureBalance
extends Resource

@export_group("HP Modifier")
## 滿血時的乘數。不是 0——留一點僥倖空間比硬性禁止手感好。
@export_range(0.0, 1.0, 0.05) var hp_modifier_at_full: float = 0.3
## 殘血時的乘數。
@export_range(0.0, 1.0, 0.05) var hp_modifier_at_empty: float = 1.0

@export_group("Rarity Modifier")
## capture_difficulty = 0（最好抓）時的乘數。
@export_range(0.0, 1.0, 0.05) var rarity_modifier_at_easy: float = 1.0
## capture_difficulty = 1（最難抓）時的乘數。
@export_range(0.0, 1.0, 0.05) var rarity_modifier_at_hard: float = 0.25


func hp_modifier(health_ratio: float) -> float:
	return lerpf(hp_modifier_at_empty, hp_modifier_at_full, clampf(health_ratio, 0.0, 1.0))


func rarity_modifier(capture_difficulty: float) -> float:
	return lerpf(rarity_modifier_at_easy, rarity_modifier_at_hard,
		clampf(capture_difficulty, 0.0, 1.0))
