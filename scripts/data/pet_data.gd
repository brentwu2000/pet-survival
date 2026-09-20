## 寵物的**種族**資料（規格書 §6）。唯讀，不存檔。
##
## 執行期的 level / exp / current_hp 屬於 PetInstance，不在這裡。
## 這條 Data / Instance 界線讓「調平衡數值不會弄壞舊存檔」。
##
## 規格書 §6 明列第一版**不做**：IV、個體值、性格、隨機天賦、寵物裝備。
## 不要因為「Resource 加欄位很便宜」就先加——加了就會有人去讀它。
class_name PetData
extends Resource

## 唯一識別碼，與檔名主體一致（pet_flame_cat.tres -> &"flame_cat"）。
@export var id: StringName = &""
@export var display_name: String = ""
@export var element: Element.Type = Element.Type.FIRE

@export_group("Base Stats")
@export var max_hp: float = 100.0
## Phase 2（規格書 §26：Element / Damage / Skill / EXP / Level）的成長數值。
## **Phase 1 不讀它**——普攻威力來自 basic_attack.power、技能威力來自 skill.power。
## 不要在 Phase 1 硬給它一個用途，那會變成之後升級系統要拆掉的東西。
@export var attack: float = 10.0
@export var defense: float = 5.0
@export var move_speed: float = 4.0

@export_group("Combat")
## 普攻。提供射程 / 冷卻 / 屬性 / 動畫名。
## **傷害來自上面的 attack 數值**（那是之後會隨等級成長的），不讀 basic_attack.power。
@export var basic_attack: SkillData
## 第一版每隻只有 1 個特殊技能（規格書 §6）。
@export var special_skill: SkillData

@export_group("Capture")
@export_range(0.0, 1.0, 0.05) var capture_difficulty: float = 0.5

@export_group("Visual")
@export var sprite_frames: SpriteFrames
@export var visual_scale: float = 1.0
