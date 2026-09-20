# Orbit Camera 與 Input

規格書 §24。第一版**只做 PC**，不實作 Mobile Controls（硬規則：不提前增加 Mobile UI 複雜度）。

## 操作對照（規格書 §24）

| 輸入 | 行為 |
|------|------|
| WASD | 玩家移動（相對鏡頭方向） |
| 滑鼠移動 | 指標 / hover |
| 滑鼠左鍵 | 選擇目標、下指令 |
| 滑鼠拖曳 | Camera 旋轉 |
| 滾輪 | Zoom |
| 1~5 | 切換 Active Pet |
| E | 互動 |
| Q | 丟捕捉球 |
| Esc | 暫停 |

「滑鼠拖曳旋轉」與「左鍵選擇」會衝突，本專案約定：
**左鍵 = 選擇 / 指令；中鍵或右鍵拖曳 = 旋轉鏡頭。** 這是規格書沒指定的實作選擇，可調整。

## Input Map（Phase 0 就要設好）

Project Settings → Input Map。動作名固定如下，**程式中不得出現字面字串以外的別名**：

```
move_forward     W,  Up
move_back        S,  Down
move_left        A,  Left
move_right       D,  Right

camera_orbit     Mouse Middle,  Mouse Right
camera_zoom_in   Mouse Wheel Up
camera_zoom_out  Mouse Wheel Down

select           Mouse Left
throw_ball       Q
interact         E
pause            Escape

pet_slot_1       1
pet_slot_2       2
pet_slot_3       3
pet_slot_4       4
pet_slot_5       5
```

規格書 §26 Phase 0 明列 Input Map 是完成項——**在寫 player.gd 之前先設好**，
否則會寫出一堆 `Input.is_key_pressed(KEY_W)` 之類無法重新綁定的程式碼。

## Player 移動（相對鏡頭）

WASD 必須相對**鏡頭**方向，不是玩家自身朝向——orbit camera 轉了之後 W 要往螢幕上方走。

```gdscript
class_name Player
extends CharacterBody3D

@export var move_speed: float = 5.0
@export var rotation_speed: float = 12.0

@onready var _camera_rig: OrbitCamera = get_node("../OrbitCamera")

func _physics_process(delta: float) -> void:
    if not is_on_floor():
        velocity += get_gravity() * delta

    var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    # 取鏡頭的水平朝向，忽略俯仰
    var basis := _camera_rig.global_basis
    var forward := -Vector3(basis.z.x, 0.0, basis.z.z).normalized()
    var right := Vector3(basis.x.x, 0.0, basis.x.z).normalized()
    var dir := (right * input.x + forward * -input.y).normalized()

    velocity.x = dir.x * move_speed
    velocity.z = dir.z * move_speed
    move_and_slide()

    if dir.length_squared() > 0.01:
        _face_direction(dir, delta)

func _face_direction(dir: Vector3, delta: float) -> void:
    var target_yaw := atan2(dir.x, dir.z)
    rotation.y = lerp_angle(rotation.y, target_yaw, rotation_speed * delta)
```

`Input.get_vector()` 的 y 分量：`move_forward` 是負值，所以乘 `-input.y`。
**這個負號寫反的症狀是前後顛倒**——實測一次就知道。

玩家的朝向（`rotation.y`）會被 `PetVisual` 的四方向計算讀取（見 `07`），所以要平滑更新。

## OrbitCamera

```gdscript
class_name OrbitCamera
extends Node3D

@export var target: Node3D                    # 追蹤玩家
@export var distance: float = 10.0
@export var min_distance: float = 4.0
@export var max_distance: float = 20.0
@export var zoom_step: float = 1.0
@export var min_pitch_deg: float = -60.0
@export var max_pitch_deg: float = -15.0
@export var start_pitch_deg: float = -35.0
@export var orbit_sensitivity: float = 0.005
@export var follow_smoothing: float = 10.0

@onready var _camera: Camera3D = $Camera3D

var _yaw: float = 0.0        # 弧度
var _pitch: float = 0.0      # 弧度
var _is_orbiting: bool = false

func _ready() -> void:
    # 對外的 @export 一律用「度」（編輯器好調），內部一律用弧度。
    # 不要就地把同一個變數 deg_to_rad()——重跑 _ready 會二次轉換。
    _pitch = deg_to_rad(start_pitch_deg)

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("camera_orbit"):
        _is_orbiting = true
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    elif event.is_action_released("camera_orbit"):
        _is_orbiting = false
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    elif event is InputEventMouseMotion and _is_orbiting:
        _yaw -= event.relative.x * orbit_sensitivity
        _pitch = clampf(_pitch - event.relative.y * orbit_sensitivity,
                        deg_to_rad(min_pitch_deg), deg_to_rad(max_pitch_deg))
    elif event.is_action_pressed("camera_zoom_in"):
        distance = clampf(distance - zoom_step, min_distance, max_distance)
    elif event.is_action_pressed("camera_zoom_out"):
        distance = clampf(distance + zoom_step, min_distance, max_distance)

func _process(delta: float) -> void:
    if target == null:
        return
    # 平滑跟隨，避免玩家移動時鏡頭僵硬
    global_position = global_position.lerp(target.global_position,
                                           minf(follow_smoothing * delta, 1.0))
    rotation = Vector3(_pitch, _yaw, 0.0)
    _camera.position = Vector3(0.0, 0.0, distance)
```

結構：`OrbitCamera (Node3D)` 負責旋轉，子節點 `Camera3D` 只在 local -Z 上退開 `distance`。
這樣 `_camera_rig.global_basis` 就是乾淨的鏡頭朝向，給玩家移動與 sprite 方向用。

- `min_pitch_deg` / `max_pitch_deg` 是**負值**（往下看），俯視角遊戲不要讓玩家把鏡頭轉到地平線以下
- 用 `_unhandled_input` 不用 `_input`——UI 吃掉的事件不該再觸發鏡頭
- 跟隨放 `_process`（視覺），移動放 `_physics_process`；輕微延遲是刻意的手感

## 滑鼠點選目標

```gdscript
const SELECT_MASK := 1 << 8      # layer 9 Selectable（bit index = layer - 1）

func _unhandled_input(event: InputEvent) -> void:
    if not event.is_action_pressed("select"):
        return
    var target := _pick_under_mouse()
    if target != null:
        _command_active_pet_to_attack(target)

func _pick_under_mouse() -> Node3D:
    var cam := get_viewport().get_camera_3d()
    var mouse := get_viewport().get_mouse_position()
    var from := cam.project_ray_origin(mouse)
    var to := from + cam.project_ray_normal(mouse) * 1000.0

    var space := get_world_3d().direct_space_state
    var query := PhysicsRayQueryParameters3D.create(from, to)
    query.collision_mask = SELECT_MASK
    query.collide_with_areas = true
    var hit := space.intersect_ray(query)
    if hit.is_empty():
        return null
    return hit.collider as Node3D
```

- **`intersect_ray` 回傳空 Dictionary 代表沒打中**，先 `is_empty()` 再取 `collider`
- 可被點選的東西要掛在 layer 9（Selectable），見 `01-project-conventions.md`
- collision layer 的 mask 是**位元**：layer 9 → `1 << 8`。寫成 `1 << (layer - 1)` 別數錯

## 切換 Active Pet

```gdscript
func _unhandled_input(event: InputEvent) -> void:
    for i in 5:
        if event.is_action_pressed("pet_slot_%d" % (i + 1)):
            Game.party.set_active(i)
            return
```

規格書 §5：換下的寵物回到隊伍、新寵物進場。
硬規則 2：**玩家必須始終能擁有至少一隻可出戰寵物**——`set_active` 要擋掉切到空 slot / 死亡寵物。

## 不要做的事

- **不做 Mobile 觸控 / 虛擬搖桿**（規格書 §24、硬規則 20）
- **不做玩家普攻的輸入**（硬規則 1：玩家不直接攻擊）
- 不做按鍵重新綁定 UI（Input Map 已經讓它成為可能，但 MVP 不需要介面）

## 檢查清單

- [ ] 所有輸入走 Input Map action，沒有裸的 `KEY_*` 判斷
- [ ] WASD 相對鏡頭方向，鏡頭轉了之後方向正確
- [ ] `Input.get_vector` 的 y 負號驗證過（前後沒顛倒）
- [ ] 鏡頭 pitch 有上下限
- [ ] 鏡頭輸入用 `_unhandled_input`，UI 不會誤觸
- [ ] `intersect_ray` 有檢查 `is_empty()`
- [ ] 點選 mask 用 `1 << (layer - 1)` 且對應 layer 9
- [ ] 沒有任何 Mobile 控制
- [ ] 沒有玩家攻擊輸入
