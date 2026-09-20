# GDScript（Godot 4.6）

本檔的用途是**擋住 3.x 污染**。網路上（含大量 AI 生成的 Godot 教材）仍充斥 Godot 3.x API，
照抄會直接編譯失敗，或更糟——能跑但行為錯誤。寫本專案的 GDScript 時以本檔為準。

## 檔案骨架

固定順序：`class_name` → `extends` → 常數 → signal → `@export` → 一般變數 → `@onready` → 生命週期 → public → private。

```gdscript
class_name HealthComponent
extends Node

signal damaged(amount: float, source: Node)
signal died()
signal health_changed(current: float, maximum: float)

@export var max_health: float = 100.0
@export var invulnerable: bool = false

var current_health: float = 0.0
var _is_dead: bool = false

func _ready() -> void:
    current_health = max_health

func take_damage(amount: float, source: Node = null) -> void:
    if _is_dead or invulnerable:
        return
    current_health = maxf(current_health - amount, 0.0)
    damaged.emit(amount, source)
    health_changed.emit(current_health, max_health)
    if is_zero_approx(current_health):
        _die()

func _die() -> void:
    _is_dead = true
    died.emit()
```

## 靜態型別是強制的

規格書要求資料驅動 + 元件共用，兩者都靠型別才能安全重構。

```gdscript
var speed := 5.0                      # ✅ 推斷為 float
var pet_data: PetData = null          # ✅ 明確標註
@export var skill: SkillData          # ✅
func take_damage(amount: float) -> void:   # ✅ 參數與回傳都標
var stuff = get_node("X")             # ❌ 無型別
```

- 用 `:=` 讓編譯器推斷，只在推斷不出來（`null` 初始、Resource 型別）時寫完整標註
- `Array[PetData]` / `Dictionary` 要標元素型別：`var party: Array[PetInstance] = []`
- 把 Project Settings → Debug → GDScript 的 `untyped_declaration` 警告開成 Warning

## CharacterBody3D 與重力 —— 最常被寫錯的地方

```gdscript
class_name Player
extends CharacterBody3D

const SPEED := 5.0

func _physics_process(delta: float) -> void:
    if not is_on_floor():
        velocity += get_gravity() * delta     # ✅ 4.3+ 內建，回傳 Vector3
    var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var dir := (transform.basis * Vector3(input.x, 0.0, input.y)).normalized()
    velocity.x = dir.x * SPEED
    velocity.z = dir.z * SPEED
    move_and_slide()                          # ✅ 無參數
```

**三個絕不可犯的錯：**

1. **不要重新宣告 `velocity`。** `CharacterBody3D` 已內建 `velocity: Vector3`，
   寫 `var velocity := Vector3.ZERO` 會報 `Member "velocity" redefined`。
2. **沒有全域 `gravity` 變數。** 用 `get_gravity()`（`PhysicsBody3D` 方法，回傳 Vector3，
   已計入 Area3D 的重力覆寫與世界重力）。備援：`ProjectSettings.get_setting("physics/3d/default_gravity")`。
3. **`move_and_slide()` 不吃參數。** 3.x 的 `move_and_slide(velocity, Vector3.UP)` 在 4.x 是錯的；
   4.x 直接讀寫 `self.velocity`，向上方向設在 `up_direction` 屬性。

其他常用：`is_on_floor()`、`up_direction`（預設 `Vector3.UP`）、`floor_snap_length`（預設 0.1）、
`motion_mode`（`MOTION_MODE_GROUNDED` / `MOTION_MODE_FLOATING`）。

## Signal

```gdscript
signal pet_captured(instance_id: StringName, species_id: StringName)

# 連接
health.died.connect(_on_died)
health.damaged.connect(_on_damaged.bind(extra_arg))
area.body_entered.connect(_on_body_entered, CONNECT_ONE_SHOT)

# 發送
pet_captured.emit(&"pet_0007", &"flamepup")

# 檢查 / 斷開
if health.died.is_connected(_on_died):
    health.died.disconnect(_on_died)
```

- 一律用 callable 語法，不要 `connect("died", self, "_on_died")`（3.x）
- signal 名用過去式，參數標型別
- 節點被 `queue_free()` 時連線自動斷開，不需手動清理

## @export

```gdscript
@export var max_health: float = 100.0
@export_range(0.0, 1.0, 0.01) var capture_difficulty: float = 0.5
@export var element: Element.Type = Element.Type.FIRE
@export var basic_attack: SkillData
@export var pet_scene: PackedScene
@export_flags_3d_physics var detect_mask: int = 0
@export_group("Combat")
@export var attack_range: float = 2.0
@export_storage var _runtime_only: int = 0      # 4.4+：會存檔但編輯器不顯示
```

`@onready` 一律加型別，並用完整路徑：

```gdscript
@onready var sprite: AnimatedSprite3D = $Visual/AnimatedSprite3D
@onready var nav: NavigationAgent3D = $NavigationAgent3D
@onready var health: HealthComponent = $HealthComponent
```

## 物理：RigidBody3D

專案中 RigidBody 的用途有限（捕捉球拋物線、可能的掉落物），但一旦用到就容易踩 3.x 陷阱：

```gdscript
# ❌ 3.x（4.x 完全不存在）
body.mode = RigidBody3D.RIGID
body.mode = RigidBody3D.CHARACTER
body.friction = 0.2
body.bounciness = 0.5

# ✅ 4.6
body.freeze = true
body.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC   # 或 FREEZE_MODE_STATIC
var mat := PhysicsMaterial.new()
mat.friction = 0.2
mat.bounce = 0.5                                        # 注意是 bounce，不是 bounciness
body.physics_material_override = mat

body.apply_central_impulse(dir * force)                 # 瞬間
body.apply_central_force(dir * force)                   # 持續（放 _physics_process）
```

## Raycast（滑鼠選取、視線判定會大量用到）

```gdscript
func raycast(from: Vector3, to: Vector3, mask: int) -> Dictionary:
    var space := get_world_3d().direct_space_state
    var query := PhysicsRayQueryParameters3D.create(from, to)
    query.collision_mask = mask
    query.collide_with_areas = false
    query.exclude = [self]
    return space.intersect_ray(query)   # 空 Dictionary 代表沒打中
```

回傳的 key：`position`、`normal`、`collider`、`collider_id`、`rid`、`shape`、`face_index`。
**務必先判斷 `if result.is_empty(): return`**，直接 `result.collider` 會在沒打中時出錯。

## await / Timer

```gdscript
await get_tree().create_timer(0.5).timeout
await get_tree().process_frame
await animation_player.animation_finished
```

不要用 3.x 的 `yield(...)`。`await` 之後節點可能已被 free，續行前檢查 `is_instance_valid(self)`。

## 常見數學工具

```gdscript
maxf(a, b)  minf(a, b)  clampf(v, lo, hi)      # float 專用，比泛型版快
absf(v)     is_zero_approx(v)  is_equal_approx(a, b)
lerpf(a, b, t)
a.distance_to(b)        # 比 (a-b).length() 直觀
a.distance_squared_to(b)  # 比距離用於「誰比較近」時用這個，省一次開根號
```

## 效能寫法（Web 有 50 AI 的預算，見 09）

```gdscript
# ❌ 每 frame 開根號比大小
if pos.distance_to(target) < range:
# ✅
if pos.distance_squared_to(target) < range * range:

# ❌ 每 frame get_node
func _physics_process(_d): $Visual/AnimatedSprite3D.play("run")
# ✅ @onready 快取

# ❌ 每 frame 遍歷全場找目標
get_tree().get_nodes_in_group("enemy")
# ✅ 分批 / 降頻掃描，見 04 的分級 Tick
```

## 檢查清單

- [ ] 沒有重新宣告 `velocity`
- [ ] 重力用 `get_gravity()`，不是不存在的全域 `gravity`
- [ ] `move_and_slide()` 沒帶參數
- [ ] 所有 signal 用 callable 語法連接、`.emit()` 發送
- [ ] 所有函式參數與回傳都有型別標註
- [ ] `@onready` 有型別標註
- [ ] 沒有 `yield` / `export var` / `onready var` 等 3.x 語法
- [ ] `intersect_ray` 結果先檢查 `is_empty()`
- [ ] 熱路徑用 `distance_squared_to`
