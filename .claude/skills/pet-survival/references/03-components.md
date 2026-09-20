# Component 架構

規格書 §22：Pet 不要成為巨大單一 Script；Enemy 應盡可能重用 Health / Combat / Skill / Target。
**但不要為了 ECS 化而過度工程。**

## 設計原則

1. Component 是 `Node`，掛在 Pet / Enemy / Player 底下，用 `@onready` 取得。
2. Component **不知道**自己掛在誰身上的細節——只透過 parent 引用與 signal 溝通。
3. Component 之間**直接連 signal**，不繞 EventBus（EventBus 只給跨系統事件）。
4. 一個 component 一個責任。無法用一句話說清責任的，就是切錯了。
5. 不要為了「以後可能共用」而抽 component。目前確定共用的只有這四個。

## 共用矩陣

| Component | Player | Pet | Enemy | Building |
|-----------|:------:|:---:|:-----:|:--------:|
| HealthComponent | ✓ | ✓ | ✓ | ✓ |
| TargetComponent | | ✓ | ✓ | |
| CombatComponent | | ✓ | ✓ | |
| SkillComponent | | ✓ | ✓ | |

Player 只有 Health——因為**玩家不直接攻擊**（硬規則 1）。
Building 有 Health 是為了 Raid 敵人攻擊阻擋物（Phase 5，現在不做）。

## HealthComponent

責任：持有 HP、處理傷害與死亡、廣播變化。**不決定**誰能打誰、不播動畫。

```gdscript
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

var health_ratio: float:
    get: return current_health / max_health if max_health > 0.0 else 0.0

func _ready() -> void:
    current_health = max_health

func setup(new_max: float) -> void:
    # 由 PetData / EnemyData 注入，取代 @export 預設值
    max_health = new_max
    current_health = new_max
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
```

`health_ratio` 是捕捉系統的直接輸入（見 `05-capture-system.md`），捕捉率只讀它、不自己算。

## TargetComponent

責任：持有「當前目標是誰」與目標有效性驗證。**不移動、不攻擊。**

```gdscript
class_name TargetComponent
extends Node

signal target_changed(new_target: Node3D)
signal target_lost()

@export var detection_radius: float = 12.0
@export var scan_interval: float = 0.25      # 不要每 frame 掃，見 09 效能預算

var current_target: Node3D = null

var _scan_timer: float = 0.0
var _body: Node3D = null

func _ready() -> void:
    _body = get_parent() as Node3D
    _scan_timer = randf() * scan_interval     # 打散相位，避免 50 隻同 frame 掃描

func _physics_process(delta: float) -> void:
    _scan_timer -= delta
    if _scan_timer <= 0.0:
        _scan_timer = scan_interval
        _validate_target()

func set_target(target: Node3D) -> void:
    # 玩家下達 Attack Target 指令時走這裡（手動目標優先於自動搜尋）
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
```

**自動搜尋**（Wild Pet / Raid Enemy 用）不要每隻自己 `get_tree().get_nodes_in_group()`。
Phase 1 隻數少可以先這樣，Phase 6 前改成集中式註冊表 + 分批掃描（見 09）。

## CombatComponent

責任：普攻的冷卻、射程判定、傷害計算與送出。**不決定目標、不移動。**

```gdscript
class_name CombatComponent
extends Node

signal attack_started(target: Node3D)
signal attack_landed(target: Node3D, damage: float)

@export var attack_power: float = 10.0
@export var defense: float = 0.0
@export var attack_range: float = 2.0
@export var attack_cooldown: float = 1.0
@export var element: Element.Type = Element.Type.FIRE

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
    var d := attack_range
    return _body.global_position.distance_squared_to(target.global_position) <= d * d

func try_attack(target: Node3D) -> bool:
    if not can_attack() or not in_range(target):
        return false
    _cooldown_left = attack_cooldown
    attack_started.emit(target)
    deal_damage(target, attack_power, element)
    return true

func deal_damage(target: Node3D, power: float, atk_element: Element.Type) -> void:
    var hp := target.get_node_or_null("HealthComponent") as HealthComponent
    if hp == null:
        return
    var target_combat := target.get_node_or_null("CombatComponent") as CombatComponent
    var def := target_combat.defense if target_combat != null else 0.0
    var multiplier := 1.0
    if target_combat != null:
        multiplier = Database.element_table.get_multiplier(atk_element, target_combat.element)
    var damage := maxf(power * multiplier - def, 1.0)
    hp.take_damage(damage, _body)
    attack_landed.emit(target, damage)
```

**傷害公式只存在 `deal_damage` 這一處。** 屬性倍率一律問 `Database.element_table`
（硬規則 5：克制表必須資料化，禁止 `if element == ...`）。Element 細節見 `06-data-resources.md`。

`SkillComponent` 也呼叫這個 `deal_damage`，所以它是 public，不加底線。

## SkillComponent

責任：特殊技能的冷卻與施放。第一版每隻寵物**只有 1 個特殊技能**（規格書 §6）。

```gdscript
class_name SkillComponent
extends Node

signal skill_cast_started(skill: SkillData, target: Node3D)
signal skill_cast_finished()

@export var skill: SkillData

var is_casting: bool = false

var _cooldown_left: float = 0.0

func _physics_process(delta: float) -> void:
    _cooldown_left = maxf(_cooldown_left - delta, 0.0)

func can_cast(target: Node3D) -> bool:
    if skill == null or is_casting or not is_zero_approx(_cooldown_left):
        return false
    if not is_instance_valid(target):
        return false
    var d := skill.cast_range
    return get_parent().global_position.distance_squared_to(target.global_position) <= d * d

func cast(target: Node3D) -> void:
    if not can_cast(target):
        return
    is_casting = true
    _cooldown_left = skill.cooldown
    skill_cast_started.emit(skill, target)

    await get_tree().create_timer(skill.cast_time).timeout
    if not is_instance_valid(self):
        return

    is_casting = false
    if is_instance_valid(target):
        var combat := get_parent().get_node_or_null("CombatComponent") as CombatComponent
        if combat != null:
            combat.deal_damage(target, skill.power, skill.element)
    skill_cast_finished.emit()
```

`is_casting` 是 public 的理由：FSM 的 `CAST_SKILL` 狀態要靠它判斷何時能離開（見 `04-pet-ai-fsm.md`）。

## 組裝：從 PetData 注入

Component 的 `@export` 是**編輯器預設值**；執行期一律由 Data 注入，這才是「新增寵物 = 新增 .tres」。

```gdscript
class_name Pet
extends CharacterBody3D

@onready var health: HealthComponent = $HealthComponent
@onready var combat: CombatComponent = $CombatComponent
@onready var skills: SkillComponent = $SkillComponent
@onready var targeting: TargetComponent = $TargetComponent

var data: PetData = null

func setup(pet_data: PetData) -> void:
    data = pet_data
    health.setup(pet_data.max_hp)
    combat.attack_power = pet_data.attack
    combat.defense = pet_data.defense
    combat.element = pet_data.element
    skills.skill = pet_data.special_skill
```

Enemy 用同一批 component script，只換 `EnemyData`、layer/mask，AI 換成 `EnemyAI`。

## 檢查清單

- [ ] 沒有任何 component 直接呼叫 EventBus（跨系統事件才用）
- [ ] 沒有 component 同時管「決定打誰」和「怎麼打」
- [ ] 傷害計算只有 `CombatComponent.deal_damage` 一處
- [ ] 屬性倍率來自 `Database.element_table`，沒有散落的 `if element ==`
- [ ] Component 數值由 Data 注入，不是寫死在 .tscn
- [ ] Pet 與 Enemy 真的共用同一批 component script
- [ ] TargetComponent 的掃描有降頻與相位打散
