---
name: pet-survival
description: Pet Survival 專案（Godot 4.6 / GDScript / 3D + Sprite3D / Web 優先）的開發規範與參考。撰寫或修改本專案任何 .gd、.tscn、.tres，設計 Pet/Enemy/Component/FSM/捕捉/建造/Raid 系統，處理 Web 匯出與效能，或討論 Phase 進度時使用。
---

# Pet Survival 開發 Skill

抓寵 × 生存建造 × 基地防守。權威規格為 `docs/godot_pet_survival_game_plan_v0.1.md`；
本 skill 是它的**可執行版本**——把規格轉成 Godot 4.6 的具體 API、程式碼樣板與檢查清單。

**兩者衝突時，以規格書為準，並回報衝突。**

## 環境事實（勿憑記憶推測）

| 項目 | 值 |
|------|-----|
| Godot | **4.6**（`config/features` 已鎖 4.6） |
| 語言 | GDScript，全面靜態型別 |
| 世界 | 真 3D；角色為 2D Sprite3D |
| Renderer | **Compatibility**（Web 唯一可行）。已設定並在 Web build 驗證過，見 `docs/phase-0-bootstrap.md` |
| 3D 物理 | Jolt Physics |
| 目標平台 | 第一階段 PC Web，單機，單一存檔 |
| 當前 Phase | Phase 0 已完成 → **Phase 1（Catching Vertical Slice）** |

## 硬規則（不可違反，違反即為 bug）

來自規格書 §30 / §32。動手前逐條對照：

1. **玩家不直接攻擊**——沒有普攻、武器、裝備。玩家的戰鬥核心是「指揮寵物」。
2. 開局固定給 Starter Pet；玩家**任何時刻**都必須至少有一隻可出戰寵物。
3. 探索 Party 上限 **5**，同時出戰 **1**。
4. 捕捉必須**先透過寵物戰鬥削弱目標**；失敗消耗球、目標不消失、戰鬥繼續。
5. 五種 Element：Fire / Water / Grass / Electric / Ground。克制 **1.5x**、普通 **1.0x**、被克 **0.75x**。克制表**必須資料化**，禁止 `if element == ...` 散落各處。
6. 世界永遠只有**一個**基地，由 Base Core 定義。Base Defender 最終上限 **20**。
7. 玩家死亡回 Base Core 重生，**完全不掉任何東西**。死亡成本只有時間。
8. **無 Hunger / Thirst / Sleep**——不要擅自加入任何 Survival Meter。
9. 一日 = 現實 **24 分鐘**（Day 16 / Dusk 2 / Night 6，比例需配置化）。夜晚**有機率** Raid，非保證；Raid 前必有 60 秒預警。
10. Threat 影響 Raid 機率與強度，且長期持續成長。
11. Web Compatibility 是必要條件。效能目標：**20 Friendly + 30 Enemy = 50 AI** 同屏。
12. 產品優先序不可改動：**抓寵 > Build > 建基地 > 探索 > 防守**。

## 工作規則

- **不自行擴大 Scope。** 只做當前 Phase。Phase 1 未驗收前，不碰 Raid / 完整基地 / 科技樹 / 大量世界內容。
- **不為「未來可能需要」建立抽象。** 規格書明說：不要過早設計大型框架。
- **Gameplay 與資料分離。** 新增寵物 / 技能 / 建築 = 新增 `.tres`，**不是**改核心程式。
- **共用能力走 Component**（Pet 與 Enemy 共用 Health / Combat / Skill / Target），但不要 ECS 化。
- **不寫 God Script。** Pet / Player / Enemy 都不得成為單一巨大 script。
- 系統間用清楚的 API / Signal，不建立大量跨 Scene 直接引用。
- **修改既有 API 前先 grep 所有引用。**
- 每個 Milestone 必須先確認**可執行**再往下。
- Placeholder 美術優先，正式美術不得阻塞 Gameplay。

## 路由表

| 任務 | 參考 |
|------|------|
| 資料夾 / 命名 / Autoload 職責 / EventBus 事件清單 / script 開發順序 | `references/01-project-conventions.md` |
| 寫任何 GDScript：型別、signal、@export、CharacterBody3D、重力、物理 | `references/02-gdscript-4x.md` |
| Health / Target / Combat / Skill Component 的介面與實作 | `references/03-components.md` |
| Pet FSM、Wild Pet AI、Enemy AI、指令、Navigation、分級 Tick | `references/04-pet-ai-fsm.md` |
| 捕捉球、捕捉率公式、成功/失敗流程、Party 加入 | `references/05-capture-system.md` |
| PetData / SkillData / ElementTable、Database autoload、Resource 設計 | `references/06-data-resources.md` |
| Sprite3D / AnimatedSprite3D、四方向、Camera 相對朝向、Billboard | `references/07-sprite3d-visuals.md` |
| Orbit Camera、Input Map、滑鼠選取 raycast | `references/08-camera-input.md` |
| Compatibility renderer、Web 匯出、效能預算、Object Pool、Debug Metrics | `references/09-web-performance.md` |
| SaveManager、存檔結構、save_version migration、Web 存檔位置 | `references/10-save-system.md` |

## Quick Reference

### 資料夾結構（規格書 §20）

```
res://
  autoload/    game.gd  save_manager.gd  database.gd  event_bus.gd  time_manager.gd
  scenes/      world/  player/  pets/  enemies/  base/  buildings/  systems/  ui/
  resources/   pets/  skills/  buildings/  enemies/  items/  balance/
  scripts/     components/  ai/  combat/  data/  utilities/
```

命名：檔案 `snake_case`、class_name `PascalCase`、node `PascalCase`、signal 過去式（`pet_captured`）。

### Autoload 職責邊界

| Autoload | 負責 | 禁止 |
|----------|------|------|
| `Game` | Session 狀態、World 入口、高階流程 | 變成 God Object |
| `Database` | 所有 `*Data` Resource 的集中查詢 | 存放執行期可變狀態 |
| `SaveManager` | **全部**存檔讀寫 | 其他 script 自行 `FileAccess` |
| `EventBus` | 跨系統事件 | 區域內部事件也硬塞進來 |
| `TimeManager` | World Time / Day / Dusk / Night / Day Count | 直接改 gameplay 狀態 |

### EventBus 事件（規格書 §21）

```gdscript
signal pet_captured(instance_id: StringName, species_id: StringName)
signal active_pet_changed(slot: int)
signal pet_died(instance_id: StringName)
signal raid_warning(seconds: float, direction: Vector3)
signal raid_started()
signal raid_finished(won: bool)
signal threat_changed(new_threat: float)
signal day_changed(day_count: int)
signal base_level_changed(new_level: int)
```

### Collision Layer 規劃（專案約定，**早期定案、後期勿改**）

```
1 World         靜態地形、環境
2 Player
3 PetFriendly   玩家寵物 + 基地守衛
4 Enemy         野生寵物 + Raid 敵人
5 Building      玩家建築（Raid 敵人的可破壞阻擋物）
6 Interactable  資源節點、寶箱、洞窟入口
7 Hurtbox       受擊判定（Area3D）
8 Hitbox        傷害判定（Area3D）
9 Selectable    滑鼠點選 raycast 專用
10 BuildBlocker 建造合法性驗證
```

### Pet 節點組成（規格書 §22）

```
Pet (CharacterBody3D)          layer 3, mask 1|5
├── CollisionShape3D
├── Visual (Node3D)
│   └── AnimatedSprite3D       billboard = Y-Billboard
├── NavigationAgent3D
├── HealthComponent
├── CombatComponent
├── SkillComponent
├── TargetComponent
├── PetAI                       FSM
├── Hurtbox (Area3D)           layer 7, mask 8
└── SelectionIndicator (Node3D)
```

Enemy 重用 Health / Combat / Skill / Target，只換 AI 與 layer/mask。

### Node 生命週期

```
_init()            物件建立（尚未進樹）
_enter_tree()      進入 scene tree
_ready()           子節點全部就緒（由下往上）
_process(delta)    每 frame ── 視覺、UI
_physics_process   每 physics tick ── 移動、AI、戰鬥
_exit_tree()       離開 scene tree
```

### Phase 進度

| Phase | 內容 | 狀態 |
|-------|------|------|
| 0 | Bootstrap：資料夾、Input Map、5 個 autoload skeleton、Test World、Orbit Camera、Player 移動、**跑得起 Web Build** | ✅ 完成 |
| 1 | **Catching Vertical Slice**：Starter + 3 種 Wild Pet + Component + FSM + 捕捉 + Party + HUD | 進行中 |
| 2 | Element / Damage / Skill / EXP / Level / Boss / Party UI | 鎖定 |
| 3 | 世界 / Biome / 資源 / Dungeon | 鎖定 |
| 4 | Base Core / Build Mode / Grid / 6 建築 | 鎖定 |
| 5 | TimeManager / Threat / RaidDirector / Raid Loop | 鎖定 |
| 6 | Web 壓力測試 50 AI + Debug Metrics | 鎖定 |

Phase 1 的驗收流程是唯一標準：
**探索 → 指定目標 → 寵物自動戰鬥 → 降 HP → 丟球 → 捕捉 → 加入隊伍 → 換寵 → 再戰鬥**

### Godot 4.6 易錯點（大量網路範例仍是 3.x）

```gdscript
# ❌ 3.x 寫法                          # ✅ 4.6
var velocity := Vector3.ZERO           # CharacterBody3D 已內建 velocity，重宣告會編譯錯誤
velocity.y -= gravity * delta          # velocity += get_gravity() * delta
move_and_slide(velocity, UP)           # move_and_slide()   ← 無參數，直接讀寫 self.velocity
rigid.mode = RigidBody3D.RIGID         # rigid.freeze / rigid.freeze_mode
rigid.friction = 0.2                   # rigid.physics_material_override.friction
rigid.bounciness = 0.5                 # rigid.physics_material_override.bounce
yield(t, "timeout")                    # await t.timeout
connect("died", self, "_on_died")      # died.connect(_on_died)
emit_signal("died")                    # died.emit()
export var hp := 10                    # @export var hp := 10
onready var s = $Sprite                # @onready var s: AnimatedSprite3D = $Visual/AnimatedSprite3D
```

細節與更多樣板見 `references/02-gdscript-4x.md`。
