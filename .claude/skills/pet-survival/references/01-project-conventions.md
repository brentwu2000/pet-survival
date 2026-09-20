# 專案慣例

## 資料夾（規格書 §20）

```
res://
autoload/
    game.gd            Session 狀態、World 入口、高階流程
    save_manager.gd    全部存檔讀寫
    database.gd        *Data Resource 集中查詢
    event_bus.gd       跨系統事件
    time_manager.gd    World Time / Day / Dusk / Night

scenes/
    world/       world.tscn  dungeon.tscn
    player/      player.tscn
    pets/        pet.tscn
    enemies/     enemy.tscn
    base/        base_core.tscn
    buildings/   wall.tscn  gate.tscn  chest.tscn  workbench.tscn  defense_structure.tscn
    systems/     raid_director.tscn  spawn_manager.tscn  build_manager.tscn
    ui/          hud.tscn  pet_party.tscn  capture_ui.tscn  build_ui.tscn

resources/
    pets/  skills/  buildings/  enemies/  items/  balance/

scripts/
    components/  ai/  combat/  data/  utilities/
```

> 規格書原文：「這是初始方向，不要求 AI 為了符合資料夾而過度抽象。」
> 資料夾是收納，不是架構義務。不要為了填滿它而生出不需要的檔案。

## 命名

| 對象 | 規則 | 例 |
|------|------|-----|
| 檔案 | `snake_case.gd` | `health_component.gd` |
| class_name | `PascalCase` | `HealthComponent` |
| Node | `PascalCase` | `NavigationAgent3D`、`Hurtbox` |
| signal | 過去式，描述**已發生**的事 | `pet_captured`、`died` |
| 常數 | `SCREAMING_SNAKE` | `MAX_PARTY_SIZE` |
| 私有成員 | 前綴 `_` | `_cached_targets` |
| Resource 檔 | `snake_case.tres` | `pet_flamepup.tres` |

只有一份的 gameplay 概念一律加 `class_name`，讓靜態型別能派上用場。

## Autoload 職責邊界

五個 autoload，各自的界線比它們的功能更重要。

### Game
Session 狀態、World 載入入口、Phase 級的高階流程。
**規格書明確警告：避免變成 God Object。** 判準：任何「某系統自己就能決定」的邏輯不進 Game。

### Database
所有 `PetData` / `SkillData` / `BuildingData` / `EnemyData` / `ItemData` 的集中查詢點。
- 啟動時掃描 `res://resources/` 建立 `id -> Resource` 索引
- **唯讀**。不存放任何執行期可變狀態（那是 Game / 各系統的事）
- 查不到 id 要 `push_error` 並回傳 `null`，不要靜默失敗

### SaveManager
**所有**存檔讀寫的唯一入口。其他 gameplay script **不得**自行呼叫 `FileAccess`。詳見 `10-save-system.md`。

### EventBus
跨系統事件。訊號清單見下。
**不要把區域內部事件也塞進來**——Pet 內部 component 之間直接連 signal 就好，不必繞全域。
判準：發送方與接收方**互相不該知道對方存在**時，才用 EventBus。

### TimeManager
World Time、Day / Dusk / Night 階段、Day Count。
只負責推進與廣播時間，**不直接改 gameplay 狀態**（Raid 由 RaidDirector 監聽 TimeManager 自行決定）。

## Autoload 只有五個——其他系統掛在 Game 底下

規格書 §21 只定義五個 autoload。**不要再發明新的**（`Inventory`、`PartyManager`、
`CaptureSystem` 都**不是** autoload）。這類系統物件由 `Game` 持有並公開：

```gdscript
# autoload/game.gd
extends Node

var party: PartyManager          # 五寵隊伍
var collection: PetCollection    # 已捕捉的所有寵物
var inventory: Inventory         # 捕捉球、資源
var player_state: PlayerState
var base_state: BaseState
var world_state: WorldState
var tech_state: TechState
```

呼叫端一律寫 `Game.party.add(...)`、`Game.inventory.consume_ball(...)`。

這樣既避免 autoload 數量失控，又讓 `Game` 維持在「持有狀態物件」而非「實作所有邏輯」——
規格書警告的 God Object 是後者，不是前者。**邏輯放在各自的 class 裡，`Game` 只負責持有與生命週期。**

## EventBus 訊號

```gdscript
# autoload/event_bus.gd
extends Node

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

新增訊號時：一律標註參數型別；名稱用過去式；同時更新本檔與 SKILL.md。

## Collision Layer（早期定案，後期勿改）

規格書 §Physics best practice：「Set collision layers early — 之後再改會破壞既有設定」。

| # | 名稱 | 用途 |
|---|------|------|
| 1 | World | 靜態地形、環境碰撞 |
| 2 | Player | |
| 3 | PetFriendly | 玩家寵物 + 基地守衛 |
| 4 | Enemy | 野生寵物 + Raid 敵人 |
| 5 | Building | 玩家建築；Raid 敵人的可破壞阻擋物 |
| 6 | Interactable | 資源節點、寶箱、洞窟入口 |
| 7 | Hurtbox | 受擊判定 Area3D |
| 8 | Hitbox | 傷害判定 Area3D |
| 9 | Selectable | 滑鼠點選 raycast 專用 |
| 10 | BuildBlocker | 建造合法性驗證 |

典型設定：

```
Player      layer 2      mask 1|5
Pet         layer 3      mask 1|5
Enemy       layer 4      mask 1|5
Building    layer 5|10   mask 1
Hurtbox     layer 7      mask 8
Hitbox      layer 8      mask 7
```

在 Project Settings → Layer Names → 3D Physics **把名字填進去**，別讓後續維護者看數字猜。

## 第一批 script 開發順序（規格書 §28）

嚴格照這個順序，前一支沒能跑就不要開下一支：

```
01 player.gd              08 skill_component.gd
02 orbit_camera.gd        09 pet_ai.gd
03 pet_data.gd            10 wild_pet_ai.gd
04 skill_data.gd          11 party_manager.gd
05 health_component.gd    12 capture_system.gd
06 target_component.gd    13 capture_ball.gd
07 combat_component.gd    14 hud.gd
```

**第一批完成後立即 Playtest**，不要累積到全部寫完才跑。

## Phase 0 完成條件

- [ ] Renderer 改為 Compatibility（見 `09-web-performance.md`）
- [ ] 資料夾結構建立
- [ ] Input Map 設定完成（見 `08-camera-input.md`）
- [ ] 5 個 autoload skeleton 註冊完成
- [ ] Test World：一塊 3D Ground + 光照
- [ ] Orbit Camera 可拖曳旋轉、滾輪縮放
- [ ] Player WASD 移動（相對 camera 方向）
- [ ] **Web Export 實際跑起來**，不是只在編輯器裡動

最後一項是 Phase 0 真正的驗收點——規格書第 9 條原則：Web 效能是核心限制之一，要提早測。
