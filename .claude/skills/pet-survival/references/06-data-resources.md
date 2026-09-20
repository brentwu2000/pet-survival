# 資料驅動與 Resource

規格書開發原則 1：**Gameplay 與資料分離。**
原則 2：**寵物、技能、建築、敵人不得大量 hard-code。**
§6：**新增寵物應以新增 `.tres` Resource 為主，而不是修改核心戰鬥程式。**

判準：加一隻新寵物如果需要動到任何 `.gd`，就是設計錯了。

## Data vs Instance

| | Data（`.tres`，唯讀） | Instance（執行期） |
|---|---|---|
| PetData | 種族的 base 數值、技能、稀有度 | PetInstance：level / exp / current_hp |
| SkillData | 技能的威力、冷卻、射程 | 無（冷卻狀態在 SkillComponent） |
| BuildingData | 建築的成本、HP、尺寸 | Building 節點 |
| EnemyData | 敵人 base 數值 | Enemy 節點 |

Data 不存檔（隨遊戲版本走），Instance 才存檔。這條界線劃清楚，`10-save-system.md` 就簡單很多。

## PetData

規格書 §6 給的骨架，補上型別與註解：

```gdscript
class_name PetData
extends Resource

@export var id: StringName                        # 唯一，等同檔名
@export var display_name: String
@export var element: Element.Type

@export_group("Base Stats")
@export var max_hp: float = 100.0
@export var attack: float = 10.0
@export var defense: float = 5.0
@export var move_speed: float = 4.0

@export_group("Skills")
@export var basic_attack: SkillData
@export var special_skill: SkillData               # 第一版每隻只有 1 個

@export_group("Capture")
@export_range(0.0, 1.0, 0.05) var capture_difficulty: float = 0.5

@export_group("Visual")
@export var sprite_frames: SpriteFrames            # 四方向動畫，見 07
@export var scale: float = 1.0

@export_group("Evolution")
@export var evolves_into: StringName = &""         # 資料預留，MVP 不實作
@export var evolve_level: int = 0
```

規格書 §6 明列**第一版不做**：IV、個體值、性格、隨機天賦、寵物裝備。
不要因為「Resource 加欄位很便宜」就先加——加了就會有人去讀它。

## Element 與克制表

硬規則 5：**克制表必須資料化，禁止 `if element == ...` 散落各處。**

```gdscript
class_name Element

enum Type { FIRE, WATER, GRASS, ELECTRIC, GROUND }

const NAMES := {
    Type.FIRE: "Fire", Type.WATER: "Water", Type.GRASS: "Grass",
    Type.ELECTRIC: "Electric", Type.GROUND: "Ground",
}
```

```gdscript
class_name ElementTable
extends Resource

const SUPER_EFFECTIVE := 1.5
const NORMAL := 1.0
const NOT_EFFECTIVE := 0.75

# attacker -> Array[Type]，被這個屬性克制的目標
@export var strong_against: Dictionary = {}

func get_multiplier(attacker: Element.Type, defender: Element.Type) -> float:
    if defender in strong_against.get(attacker, []):
        return SUPER_EFFECTIVE
    if attacker in strong_against.get(defender, []):
        return NOT_EFFECTIVE
    return NORMAL
```

第一版五種的克制關係（存成 `resources/balance/element_table.tres`）：

```
Fire     → Grass
Water    → Fire
Grass    → Water, Ground
Electric → Water
Ground   → Fire, Electric
```

**擴充 Ice / Light / Dark 時只改 enum 與 .tres，不動 CombatComponent**——這就是規格書
「未來可擴充，不修改 Combat 核心」的意思。

倍率常數只有三個值（1.5 / 1.0 / 0.75，硬規則 5），不要引入 2.0 / 0.5 或無效 0.0。

## SkillData

```gdscript
class_name SkillData
extends Resource

@export var id: StringName
@export var display_name: String
@export var element: Element.Type

@export var power: float = 20.0
@export var cooldown: float = 5.0
@export var cast_time: float = 0.5        # 施法期間 FSM 停在 CAST_SKILL
@export var cast_range: float = 6.0

@export_group("Visual")
@export var animation_name: StringName = &"skill"
@export var effect_scene: PackedScene
```

## Database autoload

```gdscript
# autoload/database.gd
extends Node

var element_table: ElementTable = null

var _pets: Dictionary = {}       # StringName -> PetData
var _skills: Dictionary = {}
var _buildings: Dictionary = {}
var _enemies: Dictionary = {}
var _items: Dictionary = {}

func _ready() -> void:
    element_table = load("res://resources/balance/element_table.tres")
    _pets = _load_dir("res://resources/pets/")
    _skills = _load_dir("res://resources/skills/")
    _buildings = _load_dir("res://resources/buildings/")
    _enemies = _load_dir("res://resources/enemies/")
    _items = _load_dir("res://resources/items/")

func get_pet(id: StringName) -> PetData:
    var d: PetData = _pets.get(id)
    if d == null:
        push_error("Database: unknown pet id '%s'" % id)
    return d

func get_skill(id: StringName) -> SkillData:
    var d: SkillData = _skills.get(id)
    if d == null:
        push_error("Database: unknown skill id '%s'" % id)
    return d

func all_pets() -> Array:
    return _pets.values()

func _load_dir(path: String) -> Dictionary:
    var result := {}
    for file in ResourceLoader.list_directory(path):
        if not file.ends_with(".tres"):
            continue
        var res := load(path + file)
        if res == null or not "id" in res:
            push_error("Database: %s has no id field" % file)
            continue
        if res.id in result:
            push_error("Database: duplicate id '%s'" % res.id)
        result[res.id] = res
    return result
```

規則：
- Database **唯讀**，不放任何執行期可變狀態
- 查不到一律 `push_error` + 回傳 `null`，**不要靜默失敗**（否則資料打錯字會變成難查的空指標）
- id 用 `StringName`（`&"flamepup"`）不用 `String`——比較快，且明示是識別碼

> **為什麼是 `ResourceLoader.list_directory()` 而不是 `DirAccess`**
>
> 官方文件（4.6）：`ResourceLoader.list_directory(path) -> PackedStringArray`
> 「回傳的資源檔名是**匯出前在編輯器看到的原始檔名**」——所以匯出後仍拿得到 `.tres`。
> `DirAccess` 在匯出後看到的是 `.remap` / `.import` 過的實際檔案，會掃不到東西。
> 目錄項目結尾帶 `/`，回傳**順序不保證**（跨 OS 不同），所以不要依賴順序。
>
> 儘管如此，**Phase 0 的 Web build 仍要實際驗證一次 Database 有載到東西**（印出 `all_pets().size()`）。
> 若真的失效，退路是明確 manifest：一份 `@export var all_pets: Array[PetData]` 的 `.tres`。

## 命名與檔案

```
resources/
  pets/       pet_flamepup.tres   pet_aquafin.tres   pet_leafcub.tres
  skills/     skill_ember.tres    skill_bubble.tres
  balance/    element_table.tres  capture_balance.tres
  items/      ball_basic.tres     ball_great.tres
```

`id` 欄位與檔名主體一致（`pet_flamepup.tres` → `id = &"flamepup"`），方便對照與除錯。

## 平衡數值放哪

規格書 §14：「具體每級容量留給 Balance Data，不要 hard-code 在 UI」。
延伸成通則——**任何遊戲設計師會想調的數字都進 `resources/balance/`**：

- 捕捉率的 modifier 曲線端點
- 每級基地守衛容量
- Threat 各階段門檻
- 日夜時長比例（規格書 §17：「時間比例必須配置化」）
- Pet 升級曲線

不進 balance 的：程式結構常數（`MAX_PARTY_SIZE = 5`、`MAX_RATE = 0.95`）——那些是硬規則，
寫成 `const` 且不可調才是正確的表達。

## 檢查清單

- [ ] 新增一隻寵物只需要新增 `.tres`，不動任何 `.gd`
- [ ] 沒有任何地方寫 `if element == Element.Type.FIRE`
- [ ] 倍率只有 1.5 / 1.0 / 0.75 三個值
- [ ] PetData 沒有偷偷加入 IV / 性格 / 天賦欄位
- [ ] Database 是唯讀的，沒有執行期狀態
- [ ] 查不到 id 有 `push_error`
- [ ] id 用 `StringName`
- [ ] Database 的載入方式在 **Web build** 驗證過
- [ ] 設計師會調的數字在 `resources/balance/`，硬規則寫成 `const`
