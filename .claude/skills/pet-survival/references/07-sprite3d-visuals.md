# 2D 角色置於 3D 世界

規格書 §23：角色存在於**真正的 3D 世界**，Visual 用 `Sprite3D` / `AnimatedSprite3D`。
第一版至少四方向：Front / Back / Left / Right。**Camera 旋轉後，動畫方向必須根據
Character Forward 與 Camera Direction 一起決定。** 未來升級八方向。

## 節點配置

```
Pet (CharacterBody3D)
└── Visual (Node3D)                 ← 純視覺容器，AI 不碰
    └── AnimatedSprite3D
```

把 sprite 包一層 `Visual` 的理由：之後要加陰影 decal、選取光圈、狀態圖示時有地方掛，
而且 FSM 只跟 `Visual` 說話，不直接操作 sprite 節點。

## AnimatedSprite3D 設定（4.6）

```gdscript
@onready var sprite: AnimatedSprite3D = $Visual/AnimatedSprite3D

func _ready() -> void:
    sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
    sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
    sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST   # 像素風才用
    sprite.shaded = false
    sprite.double_sided = false
    sprite.pixel_size = 0.01
```

逐項理由：

| 屬性 | 值 | 為什麼 |
|------|-----|--------|
| `billboard` | `BILLBOARD_FIXED_Y` | 只繞 Y 軸面向鏡頭。用 `BILLBOARD_ENABLED` 角色會在鏡頭俯仰時整個仰躺 |
| `alpha_cut` | `ALPHA_CUT_DISCARD` | **關鍵**。預設 `ALPHA_CUT_DISABLED` 是 alpha blending，50 隻角色會有嚴重的透明排序錯誤（互相穿插閃爍）。DISCARD 讓 sprite 正常寫入 depth buffer |
| `texture_filter` | `NEAREST` | 像素美術必須；手繪高解析度圖則保留預設 linear mipmap |
| `shaded` | `false` | 手繪角色不吃 3D 光照，避免在不同時段變黑（日夜系統會有大幅光照變化） |
| `double_sided` | `false` | billboard 永遠面向鏡頭，背面不會被看到，關掉省一半 fragment |
| `pixel_size` | 依素材 | 決定 1 像素等於多少公尺。全專案統一，寫進常數 |

`alpha_cut` 這一項如果設錯，症狀是「角色在某些角度互相閃爍/消失」，而且很難聯想到原因。

## 四方向選擇

核心是**角色朝向相對於鏡頭朝向**，不是角色的世界朝向。

```gdscript
class_name PetVisual
extends Node3D

enum Facing { FRONT, BACK, LEFT, RIGHT }

@onready var sprite: AnimatedSprite3D = $AnimatedSprite3D

var _camera: Camera3D = null
var _facing: Facing = Facing.FRONT
var _anim_base: StringName = &"idle"

const DIR_SUFFIX := {
    Facing.FRONT: "front", Facing.BACK: "back",
    Facing.LEFT: "left", Facing.RIGHT: "right",
}

func _ready() -> void:
    _camera = get_viewport().get_camera_3d()

func _process(_delta: float) -> void:
    # 視覺放 _process 不放 _physics_process：跟畫面更新對齊，且省物理 tick
    var body := get_parent() as Node3D
    var new_facing := _compute_facing(body.global_basis.z, _camera.global_basis.z)
    if new_facing != _facing:
        _facing = new_facing
        _refresh()

func set_animation(base: StringName) -> void:
    if _anim_base == base:
        return
    _anim_base = base
    _refresh()

func _refresh() -> void:
    var anim := StringName("%s_%s" % [_anim_base, DIR_SUFFIX[_facing]])
    if sprite.sprite_frames.has_animation(anim):
        sprite.play(anim)
    else:
        sprite.play(_anim_base)     # 沒有方向版本就退回無方向動畫

static func _compute_facing(char_forward: Vector3, cam_forward: Vector3) -> Facing:
    # 都壓到 XZ 平面
    var f := Vector2(char_forward.x, char_forward.z).normalized()
    var c := Vector2(cam_forward.x, cam_forward.z).normalized()
    # 角色朝向相對鏡頭的夾角
    var angle := f.angle_to(c)
    # 分成四象限：面向鏡頭 = FRONT
    if absf(angle) < PI * 0.25:
        return Facing.FRONT
    if absf(angle) > PI * 0.75:
        return Facing.BACK
    return Facing.LEFT if angle > 0.0 else Facing.RIGHT
```

> `LEFT` / `RIGHT` 誰是誰取決於美術的繪製慣例與 `Camera3D` 的 `-Z` 前向。
> **實作後一定要在編輯器裡繞一圈鏡頭目視確認**，如果左右相反就把最後一行的 `>` 改成 `<`——
> 這比推導座標系快，而且不會推錯。

### 八方向升級路徑

把 `Facing` 改成 8 個值、`_compute_facing` 改成 `int(round(angle / (PI/4))) % 8` 查表即可。
`set_animation()` 的介面不變，**呼叫端完全不用改**——這是把方向邏輯關在 `PetVisual` 裡的回報。

## 動畫與 FSM 的分離

規格書 §9：**AI FSM 與 Visual Animation 儘量分離。**
FSM 只 emit `state_changed`，`PetVisual` 監聽後自己決定播什麼：

```gdscript
func _ready() -> void:
    var ai := get_parent().get_node("PetAI") as PetAI
    ai.state_changed.connect(_on_state_changed)

func _on_state_changed(_from: PetAI.State, to: PetAI.State) -> void:
    match to:
        PetAI.State.IDLE, PetAI.State.DEFEND:
            set_animation(&"idle")
        PetAI.State.FOLLOW, PetAI.State.CHASE, PetAI.State.RETURN:
            set_animation(&"walk")
        PetAI.State.ATTACK:
            set_animation(&"attack")
        PetAI.State.CAST_SKILL:
            set_animation(&"skill")
        PetAI.State.DEAD:
            set_animation(&"death")
```

**FSM 裡不得出現 `sprite.play()`。** 一旦出現，日後改動畫就得動 AI 邏輯。

## SpriteFrames 命名慣例

每隻寵物一份 `SpriteFrames`，動畫名為 `{動作}_{方向}`：

```
idle_front    idle_back    idle_left    idle_right
walk_front    walk_back    walk_left    walk_right
attack_front  attack_back  attack_left  attack_right
skill_front   ...
death                       ← 死亡可以只做一個方向，_refresh() 有 fallback
```

Placeholder 階段允許只有 `idle` / `walk` 兩個無方向動畫——`_refresh()` 的 fallback 會接住。
**不要為了湊齊 16 個動畫而卡住 Phase 1。**

## Y 軸排序與地面貼合

- Sprite 的原點預設在中心。角色要「站」在地面上，把 `AnimatedSprite3D` 的
  `offset.y` 設為 `texture_height / 2 * pixel_size`，或直接在 `Visual` 上位移。
- `ALPHA_CUT_DISCARD` 已經處理 depth，**不需要**手動調 `render_priority` 或 `no_depth_test`。
- 如果角色會被地形穿插，檢查的是 sprite 底部位置，不是 billboard 設定。

## Web 效能注意

- 50 隻角色 = 50 個 `AnimatedSprite3D`。`shaded = false` + `double_sided = false` 幫助很大。
- 所有寵物的 sprite 若能共用同一張 atlas，draw call 會大幅下降（Phase 6 的優化項）。
- `_process` 裡的方向計算很便宜，但**遠處的角色可以降頻甚至跳過**——Phase 6 再做。

## 檢查清單

- [ ] `billboard = BILLBOARD_FIXED_Y`（不是 `BILLBOARD_ENABLED`）
- [ ] `alpha_cut = ALPHA_CUT_DISCARD`
- [ ] `shaded = false`、`double_sided = false`
- [ ] 方向計算用「角色朝向 vs 鏡頭朝向」，不是角色世界朝向
- [ ] 左右方向在編輯器繞鏡頭目視驗證過
- [ ] FSM 裡沒有任何 `sprite.play()`
- [ ] 缺方向動畫時有 fallback，不會噴錯
- [ ] `pixel_size` 全專案統一
