# 捕捉系統

規格書 §10 開宗明義：**捕捉是最高優先 Gameplay System。**
規格書 §29 的成功條件、§31 的第一個交付目標，核心都是這條流程。這是整個 Phase 1 的重點。

## 硬規則

1. 捕捉**必須先透過寵物戰鬥削弱目標**——不能直接對滿血野寵丟球就抓到
2. 失敗：**球消耗、目標不消失、戰鬥繼續**
3. 普通情況**不要輕易達到 100%**
4. 高稀有度越難、HP 越低越容易、高級球提高成功率

## 公式

規格書 §10 的概念式：

```
capture_rate = ball_power × hp_modifier × rarity_modifier
```

具體實作（三個 modifier 的形狀是設計旋鈕，數值放 balance resource，**不要 hard-code 在 script**）：

```gdscript
class_name CaptureSystem
extends Node

const MAX_RATE := 0.95        # 普通球永遠打不到 100%（硬規則 3）

static func calculate_rate(target: Node3D, ball: BallData) -> float:
    var health := target.get_node_or_null("HealthComponent") as HealthComponent
    var pet := target as WildPet
    if health == null or pet == null:
        return 0.0

    var hp_mod := _hp_modifier(health.health_ratio)
    var rarity_mod := _rarity_modifier(pet.data.capture_difficulty)
    var rate := ball.power * hp_mod * rarity_mod

    if ball.guaranteed:
        return 1.0            # 特殊球保證捕捉（規格書預留）
    return clampf(rate, 0.0, MAX_RATE)

static func _hp_modifier(ratio: float) -> float:
    # 滿血 0.3、殘血 1.0。曲線讓「打到殘血」有明顯回報
    return lerpf(1.0, 0.3, ratio)

static func _rarity_modifier(difficulty: float) -> float:
    # capture_difficulty 0.0(易) ~ 1.0(難)
    return lerpf(1.0, 0.25, difficulty)
```

**滿血也不是 0**——留一點僥倖空間比硬性禁止手感好，但 `0.3 × rarity` 對稀有寵已經很低了。
數值全部可調；形狀（單調遞減、無上限 1.0）不可改。

## 完整流程

```
玩家選中野生寵物
  ↓ 指定 Starter 攻擊
Pet FSM: CHASE → ATTACK
  ↓ 野寵 HP 下降
玩家按下 throw_ball
  ↓
CaptureSystem 檢查前置條件
  ↓ 通過
球飛出（拋物線）→ 命中 → 進入捕捉判定動畫
  ↓
calculate_rate() → randf() 判定
  ├── 成功 → 播成功 feedback → queue_free 野寵 → 建立 PetInstance
  │            → 加入收藏 → Party 未滿則詢問是否加入 → EventBus.pet_captured
  └── 失敗 → 播失敗 feedback → 球消耗 → 野寵繼續戰鬥（FSM 不變）
```

## CaptureSystem 主體

```gdscript
signal capture_attempted(target: Node3D, success: bool, rate: float)

func attempt_capture(target: Node3D, ball: BallData) -> bool:
    if not _can_attempt(target, ball):
        return false

    Game.inventory.consume_ball(ball.id)        # 無論成敗都消耗（硬規則 2）

    var rate := calculate_rate(target, ball)
    var success := randf() < rate
    capture_attempted.emit(target, success, rate)

    if success:
        _on_capture_success(target as WildPet)
    # 失敗：什麼都不做。目標不消失、FSM 不變、戰鬥繼續。
    return success

func _can_attempt(target: Node3D, ball: BallData) -> bool:
    if not is_instance_valid(target) or not target is WildPet:
        return false
    var health := target.get_node_or_null("HealthComponent") as HealthComponent
    if health == null or health.is_dead:
        return false
    return Game.inventory.get_ball_count(ball.id) > 0

func _on_capture_success(wild: WildPet) -> void:
    var instance := PetInstance.create_from(wild.data, wild.level)
    Game.collection.add(instance)
    EventBus.pet_captured.emit(instance.instance_id, wild.data.id)
    if Game.party.has_space():
        Game.party.add(instance)         # 或彈 UI 讓玩家選，見下
    wild.queue_free()                      # 移除世界中的野生 Pet Entity
```

**注意順序**：先建立 instance、先 emit、最後才 `queue_free()`。
反過來會讓監聽者拿到已釋放的節點。

## PetInstance vs PetData

這是資料驅動的關鍵切分（詳見 `06-data-resources.md`）：

| | PetData (`.tres`) | PetInstance (執行期) |
|---|---|---|
| 內容 | 種族固定值：base HP / Attack / 技能 / 稀有度 | 這一隻的 level / exp / current_hp / instance_id |
| 數量 | 每種寵物一個 | 每隻捕捉到的寵物一個 |
| 存檔 | 不存（隨遊戲版本） | 存（見 `10-save-system.md`） |
| 修改 | 只在編輯器 | 執行期 |

規格書 §6：**第一版同種寵物能力固定**——沒有 IV、性格、隨機天賦。
所以 PetInstance 只需要 `instance_id / species_id / level / exp / current_hp`（正好對應存檔結構）。

```gdscript
class_name PetInstance
extends RefCounted

var instance_id: StringName
var species_id: StringName
var level: int = 1
var exp: int = 0
var current_hp: float = 0.0

var data: PetData:
    get: return Database.get_pet(species_id)

static func create_from(pet_data: PetData, lv: int = 1) -> PetInstance:
    var inst := PetInstance.new()
    inst.instance_id = StringName("pet_%d" % Game.next_instance_id())
    inst.species_id = pet_data.id
    inst.level = lv
    inst.current_hp = pet_data.max_hp
    return inst
```

`instance_id` 必須**全域唯一且存檔後仍穩定**——存檔用它引用 party 與 base defender。

## 捕捉球

```gdscript
class_name BallData
extends Resource

@export var id: StringName
@export var display_name: String
@export_range(0.0, 2.0, 0.05) var power: float = 1.0
@export var guaranteed: bool = false      # 特殊球，MVP 不做
@export var scene: PackedScene
```

MVP 至少兩個 tier（規格書 §27）：`ball_basic` (power 1.0)、`ball_great` (power 1.5)。

球的飛行：Phase 1 用最簡單的做法——`Area3D` + 手動拋物線，或直接省略飛行過程立即判定。
**不要**為了球的物理表現卡住捕捉流程的驗收。規格書：Placeholder 優先。

## Party 加入規則

```gdscript
const MAX_PARTY_SIZE := 5       # 硬規則 3

func has_space() -> bool:
    return party.size() < MAX_PARTY_SIZE
```

- Party 滿了 → Pet 進收藏，不進 Party（**不要**跳出「要替換誰」的複雜 UI，MVP 不需要）
- Party 未滿 → 直接加入（Phase 1 簡化）；Phase 2 有 Party UI 後再讓玩家選
- **任何時刻玩家都必須至少有一隻可出戰寵物**（硬規則 2）——移出 Party 的操作要擋住最後一隻

## Phase 1 驗收流程

規格書 §29 的成功條件，逐步對照：

- [ ] 玩家帶 Starter 出門
- [ ] 找到 Wild Pet（3 種 placeholder）
- [ ] 點選並指定攻擊
- [ ] Starter 自動追擊、自動戰鬥
- [ ] Wild Pet HP 降低（HUD 看得到）
- [ ] 玩家使用 Capture Ball
- [ ] 捕捉判定依 HP / 稀有度 / Ball Power 計算
- [ ] 捕捉失敗：球減少、野寵還在、繼續打
- [ ] 捕捉成功：野寵消失、加入 Party
- [ ] 玩家用數字鍵把新 Pet 設為 Active
- [ ] 舊 Pet 收回、新 Pet 出場
- [ ] 用新 Pet 繼續戰鬥

**這 12 步全部走通 = Phase 1 完成。走不通就不要碰 Phase 2 以後的任何東西。**

## 檢查清單

- [ ] 捕捉率是 HP / 稀有度 / 球威力三者的乘積
- [ ] 普通球的率有 `MAX_RATE` 上限，達不到 100%
- [ ] 失敗時球有消耗、目標沒消失、FSM 沒被打斷
- [ ] 成功時的順序是「建 instance → emit → queue_free」
- [ ] 數值來自 `BallData` / `PetData.capture_difficulty`，沒有 hard-code
- [ ] Party 上限 5 有被強制
- [ ] 玩家不可能落到 0 隻可出戰寵物
