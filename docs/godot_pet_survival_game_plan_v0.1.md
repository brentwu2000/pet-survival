# Godot 抓寵生存建造遊戲 --- AI 開發規格 v0.1

> 用途：提供給 Codex / Claude Code / Gemini CLI / Cursor 等 AI Coding
> Agent 作為專案初始規格。
>
> 原則：先完成「抓寵」核心循環，再依序加入 Build、基地、探索內容與
> Raid。不要提前實作未進入當前 Phase 的大型系統。

------------------------------------------------------------------------

## 1. 專案定位

### 遊戲類型

2.5D 抓寵 × 生存建造 × 基地防守。

### 平台

-   第一階段：PC Web
-   後續：Mobile Web
-   單機
-   單一存檔

### 核心體驗優先順序

1.  抓寵
2.  Build / 隊伍組合
3.  建基地
4.  探索
5.  大型防守

### 一句話定義

玩家從一隻初始寵物開始，在固定但具有隨機內容的世界中探索、戰鬥、捕捉新寵物，組成最多五隻的隊伍，建立唯一據點，最終利用寵物組合與基地配置抵禦不斷升級的敵人襲擊。

------------------------------------------------------------------------

## 2. 技術方向

-   Engine：Godot 4.x
-   Language：GDScript
-   Renderer：Compatibility
-   世界：3D
-   角色：2D 手繪角色置於 3D 世界
-   角色 Visual：Sprite3D / AnimatedSprite3D
-   Camera：可旋轉 Orbit Camera
-   Input 第一階段：WASD + 滑鼠
-   AI：FSM
-   遊戲資料：Godot Resource 資料驅動
-   Web 優先，避免依賴 Desktop-only 行為

### 開發原則

1.  Gameplay 與資料分離。
2.  寵物、技能、建築、敵人不得大量 hard-code。
3.  Pet / Enemy 共用 Health、Combat、Target 等 Component。
4.  系統之間優先使用清楚的 API / Signal，不建立大量跨 Scene 直接引用。
5.  不要過早設計大型框架。
6.  每個 Phase 必須先可玩、可測試，再進下一 Phase。
7.  Placeholder 美術優先，正式美術不得阻塞 Gameplay。
8.  Web 效能是核心限制之一。
9.  第一個核心技術目標不是基地，而是完整抓寵循環。

------------------------------------------------------------------------

## 3. Core Gameplay Loop

長期循環：

探索 → 遭遇野生寵物 → 寵物戰鬥 → 削弱目標 → 捕捉 → 調整五寵隊伍 →
收集資源 → 建造基地 → 科技 / 成長 → Threat 提升 → 夜間可能發生 Raid →
基地防守 → 前往更危險區域

最重要的短循環：

找寵 → 打寵 → 抓寵 → 換 Build → 尋找更強或更適合隊伍的寵物

------------------------------------------------------------------------

## 4. 玩家

玩家不是主要戰鬥單位。

### 玩家負責

-   移動
-   探索
-   鎖定敵人
-   指定寵物攻擊目標
-   切換出戰寵物
-   使用捕捉球
-   互動
-   建造
-   戰術指揮

### 玩家第一版不做

-   普通攻擊
-   武器系統
-   裝備系統
-   主動技能樹
-   複雜 RPG Build

### 玩家成長

玩家升級主要增加 Max HP。

### 死亡

玩家死亡： - 回 Base Core 重生 - 不掉材料 - 不掉寵物 - 不掉經驗 -
不掉任何物品

死亡成本主要是探索時間。

------------------------------------------------------------------------

## 5. 寵物 Party

### 探索隊伍

-   Party 上限：5 隻
-   場上同時出戰：1 隻
-   其餘為備戰
-   PC 可使用 1\~5 快捷鍵切換
-   換下的寵物回到隊伍
-   新寵物進場

玩家必須始終能擁有至少一隻可出戰寵物。

遊戲開始固定提供 Starter Pet；MVP 不需要御三家選擇。

------------------------------------------------------------------------

## 6. 寵物資料

第一版同種寵物能力固定。

暫不實作： - IV - 個體值 - 性格 - 隨機天賦 - 寵物裝備

第一版支援： - Level - EXP - Element - HP - Attack - Defense - Move
Speed - Basic Attack - Special Skill - Evolution 資料預留

每隻寵物第一版只有：

-   普攻
-   1 個特殊技能

### PetData 建議

``` gdscript
class_name PetData
extends Resource

@export var id: StringName
@export var display_name: String
@export var element: Element.Type

@export var max_hp: float
@export var attack: float
@export var defense: float
@export var move_speed: float

@export var basic_attack: SkillData
@export var special_skill: SkillData

@export var capture_difficulty: float
```

新增寵物應以新增 `.tres` Resource 為主，而不是修改核心戰鬥程式。

------------------------------------------------------------------------

## 7. 屬性

第一版五種：

-   Fire
-   Water
-   Grass
-   Electric
-   Ground

倍率：

-   克制：1.5x
-   普通：1.0x
-   被克：0.75x

克制表必須資料化，不要散落 `if element == ...`。

建議建立 ElementTable / ElementDatabase。

未來可擴充 Ice / Light / Dark 等，不修改 Combat 核心。

------------------------------------------------------------------------

## 8. 戰鬥

類型：

即時 + 鎖定目標後半自動戰鬥。

玩家不是直接攻擊者。

### 基本流程

1.  玩家鎖定野生寵物 / 敵人
2.  下達 Attack Target
3.  出戰寵物 Chase
4.  到達攻擊距離
5.  自動 Basic Attack
6.  Special Skill 依規則施放
7.  玩家可換寵
8.  目標低血量時玩家可嘗試捕捉

### 指令

第一版寵物至少支援：

-   Attack Target
-   Follow
-   Stay
-   Defend
-   Retreat

------------------------------------------------------------------------

## 9. Pet AI FSM

第一版不要做 Behaviour Tree。

狀態：

``` text
IDLE
FOLLOW
CHASE
ATTACK
CAST_SKILL
RETURN
DEFEND
DEAD
```

典型探索流程：

``` text
FOLLOW
  ↓ target assigned
CHASE
  ↓ in attack range
ATTACK
  ↓ skill available
CAST_SKILL
  ↓
ATTACK
  ↓ target dead / command cancelled
FOLLOW
```

基地守衛以 DEFEND 為主要狀態。

AI FSM 與 Visual Animation 儘量分離。

------------------------------------------------------------------------

## 10. 捕捉

捕捉是最高優先 Gameplay System。

方式：

降低野生寵物 HP → 玩家使用捕捉球 → 計算成功率 → 成功加入收藏 / Party →
失敗則球消耗，戰鬥繼續

### 捕捉因素

-   Target Current HP %
-   Pet Rarity / Capture Difficulty
-   Capture Ball Power

概念：

``` text
capture_rate =
ball_power
× hp_modifier
× rarity_modifier
```

設計方向：

-   HP 越低成功率越高
-   高稀有度越難
-   高級球提高成功率
-   普通情況不要輕易達到 100%
-   特殊球未來可以提供保證捕捉

### 捕捉失敗

-   捕捉球消耗
-   目標不消失
-   目標繼續戰鬥

### 捕捉成功

-   播放捕捉 Feedback
-   移除世界中的野生 Pet Entity
-   建立玩家 Pet Instance Data
-   加入收藏
-   Party 未滿時可選擇加入 Party

------------------------------------------------------------------------

## 11. 世界

世界採：

固定主地圖 + 隨機內容。

主地圖從基地到最遠區域步行約 4\~6 分鐘。

第一版區域概念：

-   草原
-   森林
-   礦區
-   遺跡
-   Boss 區
-   洞窟入口

固定： - 地形 - 主要區域 - 主要 Landmark

可隨機： - 野生寵物 Spawn - 資源 - 寶箱 - 部分事件 - 稀有寵物

探索內容長期包含：

-   野生寵物
-   Boss
-   敵對人類
-   寶箱
-   洞窟
-   遺跡
-   隨機事件

------------------------------------------------------------------------

## 12. Dungeon

洞窟使用獨立 Scene。

``` text
World
→ Cave Entrance
→ Dungeon Scene
→ 清怪 / 寶箱 / 特殊寵物
→ Exit
→ World
```

不要第一版做無縫地下世界。

------------------------------------------------------------------------

## 13. 資源

MVP 採輕量資源系統。

主要資源：

-   Wood
-   Stone
-   Ore

第一版不要建立大型加工生產鏈。

------------------------------------------------------------------------

## 14. 基地

世界永遠只有一個主要基地。

基地由 Base Core 定義。

### Base Core 負責

-   基地中心
-   玩家重生點
-   可建築範圍
-   Base Level
-   守衛容量
-   Raid 最終目標

### 守衛

基地等級提升可增加守衛數量。

最終上限：

20 隻基地防守寵物。

具體每級容量留給 Balance Data，不要 hard-code 在 UI。

------------------------------------------------------------------------

## 15. 建造

形式：

3D Grid 自由建造。

流程：

``` text
Select Building
→ Ghost Preview
→ Grid Snap
→ Rotation
→ Placement Validation
→ Confirm
→ Consume Resources
→ Spawn Building
```

必須支援：

-   Grid Snap
-   Ghost Preview
-   可 / 不可建造 Feedback
-   Rotation
-   Collision Validation
-   Wall Auto Snap
-   Floor / 同類建築連續鋪設能力預留
-   Door Snap to Wall
-   Demolish
-   拆除返還部分材料

MVP 建築：

-   Base Core
-   Wall
-   Gate
-   Chest
-   Workbench
-   Defense Structure

第一版不做：

-   完整房屋
-   屋頂
-   多樓層
-   室內 / 室外判定

------------------------------------------------------------------------

## 16. Threat

使用全局 Threat Level。

Threat 可因以下行為增加：

-   建造 / 基地發展
-   玩家 Level
-   捕捉稀有寵物
-   科技解鎖
-   Boss 擊殺

概念階段：

``` text
Low Threat
→ 野獸

Medium Threat
→ 敵對人類 / 寵物

High Threat
→ Elite

Very High Threat
→ Boss Raid
```

Threat 長期持續成長，支撐無限防守 End Game。

------------------------------------------------------------------------

## 17. 日夜

1 個遊戲日 = 現實 24 分鐘。

初始可暫定：

-   Day：16 分鐘
-   Dusk：2 分鐘
-   Night：6 分鐘

時間比例必須配置化。

夜晚有機率 Raid，不是每晚保證 Raid。

Raid 機率與強度受 Threat 影響。

------------------------------------------------------------------------

## 18. Raid

Raid 前提供預警。

初始設計：

-   60 秒準備時間
-   UI 顯示倒數
-   顯示敵人主要來襲方向
-   玩家可以回基地調整守衛

### Enemy Raid 行為

敵人從預設 World Spawn Point / Raid Spawn Region 產生。

最終目標：

Base Core。

基本決策：

``` text
有敵對 Pet
→ 交戰

前往 Core 的路徑被建築阻擋
→ 攻擊阻擋物

可通行
→ 朝 Base Core 移動
```

後續可加入不同 Raid Enemy Role。

------------------------------------------------------------------------

## 19. 效能目標

第一個壓力測試：

-   Friendly：20
-   Enemy：30
-   總戰鬥 AI：50

Web 版本必須提早測試。

若效能不足，優先檢查：

-   Navigation 更新頻率
-   AI Tick Frequency
-   Target Search Frequency
-   Physics
-   Collision Layer
-   Animation
-   Sprite3D
-   Path Recalculation
-   大量 Signal / Node Process
-   Spawn / Free 頻率

必要時使用：

-   AI 分級 Tick
-   距離式更新頻率
-   Object Pool
-   分批 Target Scan
-   避免每個 AI 每 frame 做昂貴搜尋

------------------------------------------------------------------------

## 20. Scene / Folder Architecture

``` text
res://

autoload/
    game.gd
    save_manager.gd
    database.gd
    event_bus.gd
    time_manager.gd

scenes/
    world/
        world.tscn
        dungeon.tscn

    player/
        player.tscn

    pets/
        pet.tscn

    enemies/
        enemy.tscn

    base/
        base_core.tscn

    buildings/
        wall.tscn
        gate.tscn
        chest.tscn
        workbench.tscn
        defense_structure.tscn

    systems/
        raid_director.tscn
        spawn_manager.tscn
        build_manager.tscn

    ui/
        hud.tscn
        pet_party.tscn
        capture_ui.tscn
        build_ui.tscn

resources/
    pets/
    skills/
    buildings/
    enemies/
    items/
    balance/

scripts/
    components/
    ai/
    combat/
    data/
    utilities/
```

這是初始方向，不要求 AI 為了符合資料夾而過度抽象。

------------------------------------------------------------------------

## 21. Autoload

### Game

負責： - Session 狀態 - World 狀態入口 - 高階流程

避免變成 God Object。

### Database

集中存取： - PetData - SkillData - BuildingData - EnemyData - ItemData

### SaveManager

所有存檔透過 SaveManager。

其他 Gameplay Script 不應自行到處寫 FileAccess。

### EventBus

適合跨系統事件，例如：

``` text
pet_captured
active_pet_changed
pet_died
raid_warning
raid_started
raid_finished
threat_changed
day_changed
base_level_changed
```

不要所有區域內部事件都強制經過 Global EventBus。

### TimeManager

管理： - World Time - Day - Dusk - Night - Day Count

------------------------------------------------------------------------

## 22. Component Architecture

Pet 不要成為巨大單一 Script。

概念：

``` text
Pet
├── CharacterBody3D
├── Visual
│   └── AnimatedSprite3D
├── NavigationAgent3D
├── HealthComponent
├── CombatComponent
├── SkillComponent
├── TargetComponent
├── PetAI
├── Hurtbox
└── SelectionIndicator
```

Enemy 應盡可能重用：

-   HealthComponent
-   CombatComponent
-   SkillComponent
-   TargetComponent

但不要為了 ECS 化而過度工程。

------------------------------------------------------------------------

## 23. 2D Character in 3D World

角色存在於真正 3D 世界。

Visual 使用：

-   Sprite3D 或
-   AnimatedSprite3D

第一版至少準備四方向：

-   Front
-   Back
-   Left
-   Right

Camera 旋轉後，角色視覺方向必須根據：

-   Character Forward
-   Camera Direction

選擇正確動畫。

未來可升級八方向。

------------------------------------------------------------------------

## 24. Camera

Orbit Camera。

PC：

-   WASD：玩家移動
-   滑鼠：選擇 / 操作
-   滑鼠拖曳：Camera Rotate
-   Wheel：Zoom
-   1\~5：切換 Pet

Camera 追蹤玩家。

第一版先不要實作 Mobile Controls。

------------------------------------------------------------------------

## 25. Save

第一版單存檔。

至少保存：

``` text
player
    level
    hp
    position

party
    active_index
    pet_instance_ids

pets
    instance_id
    species_id
    level
    exp
    hp

base
    level
    buildings
    defender_pet_ids

world
    threat
    day_count
    world_time
    defeated_bosses
    persistent_world_state

technology
    unlocked_ids
```

Web 存檔必須由 SaveManager 統一處理。

Save Data 必須有：

``` text
save_version
```

方便未來 migration。

------------------------------------------------------------------------

# 26. 開發 Phase

## Phase 0 --- Project Bootstrap

目標：

可以在 Web Export 跑起空世界。

完成：

-   Godot Project
-   Compatibility Renderer
-   Folder Structure
-   Input Map
-   Game
-   Database
-   EventBus
-   SaveManager Skeleton
-   Test World
-   Orbit Camera
-   Player Movement

完成條件：

玩家可以在 Web Build 中使用 WASD 移動與旋轉 Camera。

------------------------------------------------------------------------

## Phase 1 --- Catching Vertical Slice

這是第一個最重要 Milestone。

只做：

-   Player
-   Starter Pet
-   3 種 Placeholder Wild Pet
-   PetData
-   SkillData
-   Health
-   Target
-   Combat
-   Pet FSM
-   Wild Pet AI
-   Capture Ball
-   Capture Formula
-   PartyManager
-   5 Pet Party
-   Active Pet Switching
-   Basic HUD

完整流程：

``` text
玩家帶 Starter 出門
→ 找到 Wild Pet
→ 指定攻擊
→ Starter 自動戰鬥
→ Wild Pet HP 降低
→ 玩家使用 Capture Ball
→ 捕捉判定
→ 捕捉成功
→ Wild Pet 加入玩家
→ 玩家將新 Pet 設為 Active
→ 新 Pet 出場
→ 使用新 Pet 繼續戰鬥
```

Phase 1 完成前：

不要開始 Raid。

不要開始完整基地。

不要開始科技樹。

不要開始大量世界內容。

------------------------------------------------------------------------

## Phase 2 --- Build Validation

加入：

-   5 Elements
-   Element Table
-   Damage Multiplier
-   Special Skill
-   Pet EXP
-   Pet Level
-   3\~5 種可玩 Pet
-   1 Boss
-   Party UI

目標：

驗證不同寵物與屬性是否真的會讓玩家想換隊伍。

------------------------------------------------------------------------

## Phase 3 --- Exploration + Resources

加入：

-   主世界雛形
-   Biome
-   Wood
-   Stone
-   Ore
-   Resource Gathering
-   Treasure
-   Random Pet Spawn
-   Boss Area
-   Dungeon Entrance
-   1 Dungeon

------------------------------------------------------------------------

## Phase 4 --- Base Building

加入：

-   Base Core
-   Build Mode
-   Grid
-   Ghost
-   Snap
-   Rotate
-   Collision Validation
-   Wall
-   Gate
-   Chest
-   Workbench
-   Defense Structure
-   Demolish
-   Resource Cost
-   Base Level

------------------------------------------------------------------------

## Phase 5 --- Raid Loop

加入：

-   TimeManager
-   24 Minute Day
-   Threat
-   Defender Assignment
-   RaidDirector
-   Raid Warning
-   Enemy Spawn
-   Enemy AI
-   Base Core Targeting
-   Wall Attacking
-   Raid Win / Loss
-   Boss Raid

完成後完整 Loop：

``` text
Explore
→ Catch
→ Build Party
→ Gather
→ Build Base
→ Threat
→ Raid Warning
→ Configure Defenders
→ Defend
→ Recover
→ Explore
```

------------------------------------------------------------------------

## Phase 6 --- Web Optimization

壓力測試：

``` text
20 Friendly
+
30 Enemy
=
50 Active Combat AI
```

建立 Debug Metrics：

-   FPS
-   Active AI
-   Navigation updates/sec
-   Target scans/sec
-   Projectiles
-   Damage events/sec

優化完成後才大量增加內容。

------------------------------------------------------------------------

# 27. MVP Content Target

MVP：

-   1 主世界
-   1 Dungeon
-   5\~8 Pet Species
-   5 Elements
-   1\~2 Boss
-   3 Main Resources
-   約 6 Buildings
-   至少 2 Capture Ball Tier
-   Player Level
-   Pet Level
-   Base Level
-   Threat
-   Day/Night
-   Raid
-   Boss Raid
-   20 Base Defenders
-   30 Raid Enemy Stress Test
-   Web Save

------------------------------------------------------------------------

# 28. 第一批 Script 開發順序

建議：

``` text
01 player.gd
02 orbit_camera.gd
03 pet_data.gd
04 skill_data.gd
05 health_component.gd
06 target_component.gd
07 combat_component.gd
08 skill_component.gd
09 pet_ai.gd
10 wild_pet_ai.gd
11 party_manager.gd
12 capture_system.gd
13 capture_ball.gd
14 hud.gd
```

第一批完成後立即 Playtest。

------------------------------------------------------------------------

# 29. 第一個 Playable

只需要：

-   一塊簡單 3D Ground
-   Player Placeholder
-   Starter Placeholder
-   3 種 Wild Pet Placeholder
-   HP UI
-   Capture Ball
-   Party UI

不需要：

-   正式美術
-   正式地圖
-   基地
-   日夜
-   Raid
-   科技
-   完整音效

成功條件：

玩家可以完整完成：

**探索 → 指定目標 → 寵物戰鬥 → 降低 HP → 丟球 → 捕捉 → 加入隊伍 → 換寵 →
再戰鬥**

------------------------------------------------------------------------

# 30. AI Coding Agent 工作規則

AI 在修改此專案時遵守：

1.  先閱讀本文件。
2.  不自行擴大 Scope。
3.  優先完成目前 Phase。
4.  不因「未來可能需要」建立複雜抽象。
5.  Gameplay Data 優先 Resource 化。
6.  共用能力使用 Component，但避免過度 ECS。
7.  不把 Pet / Player / Enemy 寫成巨大 God Script。
8.  新系統需說明其責任與依賴。
9.  修改既有 API 前先搜尋所有引用。
10. 每個核心系統需能獨立測試。
11. 每完成一個 Milestone 必須先確認可執行。
12. Web Compatibility 是必要條件。
13. 不實作玩家普通攻擊。
14. 玩家戰鬥核心是「指揮寵物」。
15. 探索 Party 最多 5 隻，但同時只出戰 1 隻。
16. 基地守衛最終上限 20。
17. 不改變「抓寵 \> Build \> 建基地 \> 探索 \>
    防守」的產品優先順序，除非需求文件更新。
18. 不要擅自加入飢餓、口渴、睡眠等 Survival Meter。
19. 世界永遠只有一個主要基地。
20. 第一階段只要求 PC Web，不要提前增加 Mobile UI 複雜度。

------------------------------------------------------------------------

# 31. AI 開始專案時的第一個任務

請先執行 Phase 0 + Phase 1。

第一個交付目標：

> 建立一個最小 Godot Web Prototype。玩家可 WASD 移動、旋轉鏡頭，擁有一隻
> Starter Pet；世界存在三種 Wild Pet。玩家可鎖定 Wild Pet 並命令 Starter
> 自動追擊與攻擊。目標低血量後玩家可使用 Capture Ball，依 HP、稀有度與
> Ball Power 計算捕捉率。成功後 Pet 加入最多五隻的 Party，玩家可切換
> Active Pet，並使用新捕捉的 Pet 繼續戰鬥。

驗收前不要開始 Base / Raid。

------------------------------------------------------------------------

# 32. 核心設計不可違反事項

-   玩家不直接攻擊。
-   初始一定有 Starter Pet。
-   探索 Party 最多 5。
-   同時出戰 1 Pet。
-   捕捉需要先透過 Pet 戰鬥削弱目標。
-   捕捉失敗會消耗 Ball。
-   捕捉失敗後戰鬥繼續。
-   五種初始 Element。
-   克制 1.5x。
-   被克 0.75x。
-   世界固定、內容部分隨機。
-   只有一個基地。
-   玩家死亡回基地且完全不掉物品。
-   無 Hunger。
-   一日 24 分鐘。
-   夜晚有機率 Raid。
-   Threat 影響 Raid。
-   Raid 前有預警。
-   Base Defender 最終最多 20。
-   Web 第一階段目標 20 Friendly + 30 Enemy 同屏。
-   第一優先永遠是「抓寵是否有趣」。

------------------------------------------------------------------------

## 文件狀態

Version：0.1\
Status：Ready for Implementation\
Current Target：Phase 0 → Phase 1 Catching Vertical Slice
