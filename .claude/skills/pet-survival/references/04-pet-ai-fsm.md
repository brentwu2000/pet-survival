# Pet AI FSM

規格書 §9：**第一版不要做 Behaviour Tree。** 用 FSM。
規格書 §9：**AI FSM 與 Visual Animation 儘量分離**——FSM 決定「在做什麼」，Visual 監聽狀態自己決定播什麼。

## 狀態

```
IDLE        無指令、無目標，待命
FOLLOW      跟隨玩家（探索時的預設狀態）
CHASE       朝目標移動直到進入攻擊距離
ATTACK      在射程內執行普攻
CAST_SKILL  施放特殊技能（不可被普攻打斷）
RETURN      脫離過遠，返回玩家 / 駐守點
DEFEND      駐守原地，只打進入範圍的敵人（基地守衛主狀態）
DEAD        死亡
```

## 轉換圖

探索主流程（規格書 §9）：

```
FOLLOW
  ↓ 玩家下達 Attack Target
CHASE
  ↓ 進入 attack_range
ATTACK
  ↓ skill 可用且在 cast_range
CAST_SKILL
  ↓ 施放結束
ATTACK
  ↓ 目標死亡 / 指令取消
FOLLOW
```

其他必要邊：

```
任何狀態  → DEAD          HealthComponent.died
CHASE     → RETURN        離玩家超過 leash_distance
ATTACK    → CHASE         目標脫離 attack_range
RETURN    → FOLLOW        回到玩家附近
FOLLOW    → IDLE          玩家靜止且無目標（省 Navigation 開銷）
IDLE      → FOLLOW        玩家移動超過 follow_distance
DEFEND    → ATTACK/CHASE  敵人進入 defend_radius
```

**DEAD 是終態**——不要做復活轉換，Pet 死亡由上層（PartyManager）處理。

## 指令（規格書 §8）

第一版寵物至少支援五種指令。指令**設定意圖**，FSM **決定當下狀態**——兩者不要混為一談。

```gdscript
class_name PetCommand

enum Type {
    ATTACK_TARGET,   # 攻擊指定目標
    FOLLOW,          # 跟隨玩家（預設）
    STAY,            # 原地待命，不主動接敵
    DEFEND,          # 駐守，反擊進入範圍者
    RETREAT,         # 脫離戰鬥回到玩家身邊
}
```

## 實作

單一 script + `match`，不要為八個狀態各開一個 Node class——那是 Phase 1 不需要的抽象。

```gdscript
class_name PetAI
extends Node

signal state_changed(from: State, to: State)

enum State { IDLE, FOLLOW, CHASE, ATTACK, CAST_SKILL, RETURN, DEFEND, DEAD }

@export var follow_distance: float = 3.0
@export var leash_distance: float = 20.0
@export var move_speed: float = 4.0

var state: State = State.IDLE
var command: PetCommand.Type = PetCommand.Type.FOLLOW
var follow_anchor: Node3D = null          # 探索時是玩家，駐守時是駐守點

@onready var _body: CharacterBody3D = get_parent()
@onready var _nav: NavigationAgent3D = _body.get_node("NavigationAgent3D")
@onready var _health: HealthComponent = _body.get_node("HealthComponent")
@onready var _combat: CombatComponent = _body.get_node("CombatComponent")
@onready var _skills: SkillComponent = _body.get_node("SkillComponent")
@onready var _targeting: TargetComponent = _body.get_node("TargetComponent")

func _ready() -> void:
    _health.died.connect(_on_died)
    _targeting.target_lost.connect(_on_target_lost)
    _nav.path_desired_distance = 0.5
    _nav.target_desired_distance = 1.0
    _change_state(State.FOLLOW)

func _physics_process(delta: float) -> void:
    match state:
        State.IDLE:       _tick_idle()
        State.FOLLOW:     _tick_follow()
        State.CHASE:      _tick_chase()
        State.ATTACK:     _tick_attack()
        State.CAST_SKILL: _tick_cast()
        State.RETURN:     _tick_return()
        State.DEFEND:     _tick_defend()
        State.DEAD:       pass

    if state != State.DEAD:
        if not _body.is_on_floor():
            _body.velocity += _body.get_gravity() * delta
        _body.move_and_slide()

func _change_state(next: State) -> void:
    if state == next:
        return
    var prev := state
    state = next
    state_changed.emit(prev, next)      # Visual 監聽這個決定動畫

func issue_command(cmd: PetCommand.Type, target: Node3D = null) -> void:
    command = cmd
    match cmd:
        PetCommand.Type.ATTACK_TARGET:
            _targeting.set_target(target)
            _change_state(State.CHASE)
        PetCommand.Type.FOLLOW:
            _targeting.clear_target()
            _change_state(State.FOLLOW)
        PetCommand.Type.STAY:
            _targeting.clear_target()
            _change_state(State.IDLE)
        PetCommand.Type.DEFEND:
            _change_state(State.DEFEND)
        PetCommand.Type.RETREAT:
            _targeting.clear_target()
            _change_state(State.RETURN)
```

### 各狀態

```gdscript
func _tick_idle() -> void:
    _body.velocity = Vector3.ZERO
    if command == PetCommand.Type.FOLLOW and _too_far_from_anchor(follow_distance):
        _change_state(State.FOLLOW)

func _tick_follow() -> void:
    if _targeting.has_valid_target():
        _change_state(State.CHASE)
        return
    if not _too_far_from_anchor(follow_distance):
        _change_state(State.IDLE)
        return
    _move_towards(follow_anchor.global_position)

func _tick_chase() -> void:
    if not _targeting.has_valid_target():
        _change_state(State.FOLLOW)
        return
    if _too_far_from_anchor(leash_distance):
        _change_state(State.RETURN)
        return
    var target := _targeting.current_target
    if _combat.in_range(target):
        _change_state(State.ATTACK)
        return
    _move_towards(target.global_position)

func _tick_attack() -> void:
    _body.velocity = Vector3.ZERO
    var target := _targeting.current_target
    if not _targeting.has_valid_target():
        _change_state(State.FOLLOW)
        return
    if not _combat.in_range(target):
        _change_state(State.CHASE)
        return
    if _skills.can_cast(target):
        _change_state(State.CAST_SKILL)
        _skills.cast(target)
        return
    _combat.try_attack(target)

func _tick_cast() -> void:
    _body.velocity = Vector3.ZERO
    if not _skills.is_casting:
        _change_state(State.ATTACK)

func _tick_return() -> void:
    if not _too_far_from_anchor(follow_distance):
        _change_state(State.FOLLOW)
        return
    _move_towards(follow_anchor.global_position)

func _tick_defend() -> void:
    if _targeting.has_valid_target():
        var target := _targeting.current_target
        if _combat.in_range(target):
            _tick_attack()
        else:
            _move_towards(target.global_position)
        return
    _body.velocity = Vector3.ZERO

func _on_died() -> void:
    _body.velocity = Vector3.ZERO
    _change_state(State.DEAD)

func _on_target_lost() -> void:
    if state in [State.CHASE, State.ATTACK]:
        _change_state(State.FOLLOW)

func _too_far_from_anchor(d: float) -> bool:
    if follow_anchor == null:
        return false
    return _body.global_position.distance_squared_to(follow_anchor.global_position) > d * d
```

### 移動（Navigation）

```gdscript
func _move_towards(destination: Vector3) -> void:
    _nav.target_position = destination
    if _nav.is_navigation_finished():
        _body.velocity.x = 0.0
        _body.velocity.z = 0.0
        return
    var next := _nav.get_next_path_position()   # 每 physics frame 必須呼叫一次
    var dir := (next - _body.global_position).normalized()
    _body.velocity.x = dir.x * move_speed
    _body.velocity.z = dir.z * move_speed
```

**Navigation 注意事項：**
- `get_next_path_position()` 依官方文件「必須每個 physics frame 呼叫一次」以更新內部路徑邏輯
- 不要每 frame 重設 `target_position` 到會抖動的值；目標移動小於 `path_desired_distance` 時可略過
- **Y 軸不要交給 Navigation**，重力由 `move_and_slide()` 處理，`velocity.y` 別被覆寫

### 避讓（Avoidance）——Phase 6 才開

50 隻 AI 全開 RVO 在 Web 上很貴。要開的話：

```gdscript
func _ready() -> void:
    _nav.avoidance_enabled = true
    _nav.radius = 0.5
    _nav.velocity_computed.connect(_on_velocity_computed)

func _move_towards(destination: Vector3) -> void:
    # ... 算出 desired
    _nav.set_velocity(desired)       # 不直接寫 _body.velocity

func _on_velocity_computed(safe_velocity: Vector3) -> void:
    _body.velocity.x = safe_velocity.x
    _body.velocity.z = safe_velocity.z
    _body.move_and_slide()
```

開了 avoidance 就**不要**同時在 `_physics_process` 尾端呼叫 `move_and_slide()`，會 double move。

## Wild Pet AI

野生寵物的差異：沒有 `follow_anchor`（用 spawn 點當駐守錨），預設 `IDLE`，
被攻擊或玩家寵物進入偵測範圍才轉 `CHASE`。狀態機共用，只換初始 command 與 anchor。

```gdscript
class_name WildPetAI
extends PetAI

@export var spawn_marker: Node3D

func _ready() -> void:
    super()                                   # 先跑 PetAI._ready() 的連線與初始化
    follow_anchor = spawn_marker
    command = PetCommand.Type.DEFEND
    _change_state(State.IDLE)
    _health.damaged.connect(_on_damaged)

func _on_damaged(_amount: float, source: Node) -> void:
    if source is Node3D and not _targeting.has_valid_target():
        _targeting.set_target(source)   # 反擊
```

**捕捉相關**：野生寵物被捕捉成功時直接 `queue_free()`（規格書 §10：移除世界中的野生 Pet Entity）。
捕捉失敗**不改變 FSM 狀態**——戰鬥繼續（硬規則 4）。

## Enemy AI（Phase 5，現在不做）

Raid 敵人的決策（規格書 §18）：

```
有敵對 Pet 在交戰距離  → 交戰
前往 Core 的路徑被建築阻擋 → 攻擊阻擋物
可通行                → 朝 Base Core 移動
```

可用同一個 FSM，加一個 `ATTACK_STRUCTURE` 狀態，`follow_anchor` 設為 Base Core。
**Phase 1 不要先寫。**

## 分級 Tick（Phase 6 才需要，但現在別寫死成無法降頻）

效能目標是 50 個同時作戰的 AI（規格書 §19）。現在要留的餘地：

- **狀態轉換判斷**可以降頻（0.1~0.2s），**移動**必須每 physics frame
- `TargetComponent.scan_interval` 已經是降頻掃描且相位打散
- 預留一個 `ai_tick_interval`，Phase 6 依距離玩家遠近分級（近 = 每 frame、中 = 每 3 frame、遠 = 每 10 frame）

判準：現在**不要**實作分級系統，但**不要**把「每 frame 執行」的假設寫進邏輯（例如用 `delta` 累加而非假設固定 frame）。

## 檢查清單

- [ ] 沒有 Behaviour Tree（第一版明確不做）
- [ ] FSM 不直接呼叫動畫——只 emit `state_changed`，Visual 自己監聽
- [ ] `CAST_SKILL` 期間不會被普攻打斷
- [ ] DEAD 是終態，沒有復活邊
- [ ] `get_next_path_position()` 每 physics frame 呼叫
- [ ] `velocity.y` 只由重力與 `move_and_slide()` 決定，Navigation 不碰
- [ ] 開 avoidance 時沒有 double `move_and_slide()`
- [ ] 距離比較用 `distance_squared_to`
- [ ] 邏輯用 `delta` 累加，沒有假設固定 frame rate
