## 技能資料（規格書 §6、§8）。唯讀，不存檔。
class_name SkillData
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var element: Element.Type = Element.Type.FIRE

@export_group("Combat")
@export var power: float = 20.0
@export var cooldown: float = 5.0
## 施法期間 FSM 停在 CAST_SKILL。
@export var cast_time: float = 0.5
@export var cast_range: float = 6.0

@export_group("Visual")
@export var animation_name: StringName = &"skill"
@export var effect_scene: PackedScene
