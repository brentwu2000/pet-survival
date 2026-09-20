# Godot 抓寵生存遊戲｜Prototype World 開發規格 v1

> 專案：國小六年級 Godot 遊戲專題\
> 階段：Player Prototype → Graybox World → Monster Vertical Slice\
> 使用：Claude Code + Codex\
> 本文件是目前世界地圖與第一段玩法的開發依據。

> **2026-09-20 校訂。** 原版寫成「專案從零開始」，引用了不存在的
> `GAME_PLAN.md` / `AGENTS.md`，並把 Combat / Capture / Party 排在本階段之後——
> 但那些**已經做完並驗收**（見 `docs/phase-1-progress.md`）。
> 本次只修過期引用與已知衝突，設計內容不動。
>
> **權威順序**：`docs/godot_pet_survival_game_plan_v0.1.md`（規格書）
> ＞ `pet-survival` skill ＞ `CLAUDE.md` ＞ 本文件。
>
> 進入本階段的前提（**2026-09-20 已達成**）：Phase 1 的 Basic HUD 收尾。

------------------------------------------------------------------------

## 1. 本階段目標

把小朋友畫的世界地圖先轉成「可走、可辨識區域、可放怪獸」的 Godot
灰盒地圖。

本階段完成後：

``` text
啟動遊戲
→ 黃色機器人出現在草原
→ 蛋殼龍跟隨玩家
→ 玩家可自由探索小型地圖
→ 可以辨識草原 / 水系學校 / 火系區 / 山區 / 聚落
→ 火焰喵可以配置在火系區
→ 潛水蛇可以配置在水系學校
→ 山區保留洞窟入口，但暫不開放
```

重點是驗證「世界結構與探索動線」，不是製作漂亮的大地圖。

------------------------------------------------------------------------

# 2. 原始設計來源

小朋友的手繪地圖必須保存：

``` text
docs/references/world/world_map_original_v1.jpg
```

這張圖是世界設計的 Source of Truth。**檔案已就位**（2026-09-20）。

> 照片是直向拍的，**要順時針旋轉 90°** 才是正確閱讀方向。

原圖是「地點清單」式的分格畫法，不是按比例的地理圖。格子內實際畫了：

| 原圖標示 | 內容 | 對應本文件區域 |
|---|---|---|
| **火山** | 火山錐 + 山頂火山口 + 一道岩漿流到山腳；旁邊有擦掉的貓臉草稿（火焰喵） | 火系區（§5.3） |
| **學校 1~4樓** | 主樓 + 側翼 + 屋頂小方塊，**明寫四層樓** | 水系學校（§5.2） |
| **山** ＋ **草原** | 山畫在草原正上方、同一格相連；草原散布石頭 | 山區（§5.4）＋草原（§5.1） |
| **山洞** | 有陰影線的小丘，另外獨立一格 | 山區的洞窟入口（§5.4） |
| **你家**、**村長** | 約十棟房子；一棟寫「你家」，另有火柴人標「村長」 | 聚落（§5.5） |
| （無標示） | 蝙蝠一隻 | 尚未命名，**本階段不做** |
| （無標示） | 三隻花紋蛇／蟲從地面鑽出 | 尚未命名，**本階段不做** |

由此產生三點與本文件原文的落差，已在各節標注：
**學校有四層樓**（§5.2）、**火系區的正式名稱是火山**（§5.3）、
**聚落有「你家」與「村長」**（§5.5）。

原圖唯一明確指定的相鄰關係是「**山緊鄰草原**」。
§4 的十字配置是本文件的推論，不是原圖指定，但不與原圖衝突。

AI 可以：

-   整理比例
-   簡化道路
-   建立 Graybox
-   調整技術上不合理的距離

AI 不可以：

-   擅自刪除主要區域
-   把學校改成其他屬性
-   擅自建立大型城市
-   把地圖改成完全不同的世界

------------------------------------------------------------------------

# 3. 第一版世界結構

第一版先拆成 5 個區域。

  區域       屬性        功能           第一版內容
  ---------- ----------- -------------- ------------------------------
  草原       草          起始探索區     玩家起點、蛋殼龍、木材、草地
  水系學校   水          水系探索區     學校、水池/積水、潛水蛇
  火系區     火          第一個危險區   火焰喵、焦土地表
  山區       地          後續探索入口   岩石、礦石、洞窟入口
  聚落       中立/安全   基地預留區     房屋輪廓、Base Core 預留位置

------------------------------------------------------------------------

# 4. Prototype 地圖配置

先使用非常小的測試地圖：

``` text
                    [ 山區 ]
                  ⛰ 岩石 / 洞窟
                       │
                       │
                       │
[ 火系區 ] ─────── [ 草原 ] ─────── [ 水系學校 ]
🔥 火焰喵            玩家起點           💧 潛水蛇
                       │
                       │
                       │
                    [ 聚落 ]
                     🏠 基地
```

這不是最終世界地圖，只是第一個可玩 Prototype。

------------------------------------------------------------------------

# 5. 區域設計

## 5.1 草原

用途：

-   玩家出生
-   教學
-   測試移動
-   測試 Camera
-   蛋殼龍 Follow
-   通往其他區域的中心

第一版只需要：

``` text
Grass Ground
少量 Tree Placeholder
Rock Placeholder
道路
```

不要加入大量裝飾。

------------------------------------------------------------------------

## 5.2 水系學校

小朋友已指定：

> **學校是水系區域。**

這是正式世界觀設定。

學校不是整棟泡在海底，而是「水系生態化」。

> **原圖寫「學校 1~4樓」。** 四層樓是小朋友的正式設定，要記著。
> 但**本階段只做外觀 Graybox，不做室內樓層**——室內是後續 Phase 的事。

第一版可表現：

``` text
School Building Graybox
藍色 / 水系地面提示
操場局部積水
小型水池
水流或水面 Placeholder
```

後續正式美術可加入：

-   被水淹過的操場
-   水池擴張
-   水系植物
-   潮濕走廊
-   水系怪獸
-   水滴粒子
-   藍色環境光

### 潛水蛇位置

潛水蛇優先放在：

``` text
School
└── Toilet / Restroom Area
```

特殊遭遇：

``` text
玩家靠近
→ Trigger
→ 水聲
→ 水面晃動
→ Splash
→ 潛水蛇出現
```

Prototype 階段先保留 Spawn Point，不必立即做完整事件。

------------------------------------------------------------------------

## 5.3 火系區

用途：

-   第一隻 Wild Pet
-   第一場怪獸戰鬥
-   第一個 Capture 測試

第一版：

``` text
焦土地面
Rock
少量火焰 Placeholder
FireCatSpawn
```

> **原圖把這區標成「火山」**，畫了火山錐、山頂火山口與一道流到山腳的岩漿。
> 這是區域的正式名稱與外型依據，Graybox 用一個圓錐 + 一條深色帶表示即可。
> 下面「不要先製作」指的是**不要做火山機制**（噴發、熔岩物理、傷害地形），
> 不是不准出現火山造型。

不要先製作：

-   火山噴發演出
-   熔岩物理
-   大型火焰 Shader
-   火焰傷害地形

火焰喵是這區最重要的內容。

------------------------------------------------------------------------

## 5.4 山區

第一版功能：

``` text
Rock
Ore Placeholder
Cave Entrance
```

洞窟入口先鎖住。

例如：

``` text
洞窟入口
→ Interaction
→ 顯示「之後再來探索」
```

不要在這一 Phase 建 Dungeon。

------------------------------------------------------------------------

## 5.5 聚落

聚落是未來 Base / Building 系統的入口。

> **原圖有一棟房子寫「你家」**——那就是玩家基地，對應規格書的 Base Core，
> 也符合硬規則「世界只有一個基地」。其餘房子只是輪廓，不是可進入的建築。
>
> 原圖另有標「**村長**」的火柴人。這是小朋友的設定，要保留記錄，
> 但 NPC 系統不在本階段（見 §19 Scope Lock）。

第一版只需要：

``` text
數棟簡單房屋 Graybox
道路
Base Core 預留區
```

不要製作：

-   NPC 系統
-   商店
-   完整室內
-   任務系統
-   建築升級

------------------------------------------------------------------------

# 6. 地圖尺寸

Prototype 目標不是大。

建議：

``` text
草原中心 → 每個主要區域
步行約 20～40 秒
```

整張 Prototype：

``` text
最遠端 → 最遠端
約 1～2 分鐘步行
```

最終正式世界才朝原本規劃的：

``` text
基地 → 地圖遠端
約 4～6 分鐘
```

發展。

------------------------------------------------------------------------

# 7. Graybox 原則

第一版全部使用 Godot Primitive：

``` text
PlaneMesh
BoxMesh
CylinderMesh
CSGBox3D（必要時）
```

區域可先使用不同 Material / 顏色辨識。

目的：

> 玩家不用看 UI，也大概知道自己進入另一個區域。

正式 Asset、模型、Shader、粒子全部延後。

------------------------------------------------------------------------

# 8. Scene Architecture

建議：

``` text
PrototypeWorld
├── Environment
├── NavigationRegion3D
│
├── Zones
│   ├── Grassland
│   ├── WaterSchool
│   ├── FireZone
│   ├── Mountain
│   └── Village
│
├── SpawnPoints
│   ├── PlayerSpawn
│   ├── EggshellDragonSpawn
│   ├── FireCatSpawn
│   └── WaterSnakeSpawn
│
├── Player
├── Pets
└── Debug
```

每個 Zone：

``` text
Zone
├── Ground
├── Props
├── Boundaries
├── SpawnPoints
└── TriggerArea（需要時）
```

------------------------------------------------------------------------

# 9. 建議檔案

``` text
res://

scenes/
    world/
        prototype_world.tscn
        zones/
            grassland.tscn
            water_school.tscn
            fire_zone.tscn
            mountain.tscn
            village.tscn

scripts/
    world/
        zone.gd

assets/
    world/
        prototype/

docs/
    references/
        world/
            world_map_original_v1.jpg

    PHASE_WORLD_PROTOTYPE.md
```

不要因為只有 Prototype 就把所有內容塞進一個巨大 Scene。

但也不要過度抽象成複雜 World Streaming System。

------------------------------------------------------------------------

# 10. 第一版 UI

保持非常簡單。

``` text
┌──────────────────────────────────────────────┐
│ Player HP                                    │
│                                              │
│                                              │
│                 GAME WORLD                   │
│                                              │
│                                              │
│ Pet: 蛋殼龍                         [互動 E] │
│ HP ███████                                   │
│                                              │
│       [1 蛋殼龍] [2 --] [3 --] [4 --] [5 --]│
└──────────────────────────────────────────────┘
```

只做：

-   Player HP
-   Active Pet + Pet HP
-   Party Slot 1～5
-   Context Interaction Prompt

暫時不做：

-   Mini Map
-   Quest List
-   Backpack Hotbar
-   Skill Bar
-   Compass
-   Chat
-   Mission Tracker

------------------------------------------------------------------------

# 11. 區域名稱提示

玩家進入新區域時可以短暫顯示：

``` text
草原
水系學校
火系區
山區
聚落
```

例如：

``` text
        水系學校
          💧
```

1～2 秒後淡出即可。

這可以幫助測試地圖辨識度。

------------------------------------------------------------------------

# 12. 第一段玩家動線

第一版不要強迫玩家照固定順序，但建議自然引導：

``` text
START
  ↓
草原
  ↓
學會移動 / Camera
  ↓
蛋殼龍跟隨
  ↓
看見左右兩條探索方向
  ├───────────────┐
  ↓               ↓
火系區          水系學校
火焰喵          潛水蛇
```

山區與聚落是視覺上的「未來內容」。

------------------------------------------------------------------------

# 13. 開發 Milestones

## Milestone W1 --- World Graybox

完成：

-   Prototype World
-   草原
-   水系學校
-   火系區
-   山區
-   聚落
-   基本道路

驗收：

``` text
玩家可以從草原走到全部五區。
```

------------------------------------------------------------------------

## Milestone W2 --- Navigation

完成：

-   NavigationRegion3D
-   可走區域
-   基本障礙物
-   Player Collision

驗收：

``` text
玩家不穿牆
蛋殼龍可以從草原跟到主要區域
```

------------------------------------------------------------------------

## Milestone W3 --- Zone System

完成簡單：

``` text
Zone ID
Zone Name
Zone Element
```

例如：

``` text
water_school
水系學校
WATER
```

玩家進入 Area3D：

``` text
Zone Entered
→ 顯示區域名稱
```

------------------------------------------------------------------------

## Milestone W4 --- Spawn Points

建立：

``` text
PlayerSpawn
EggshellDragonSpawn
FireCatSpawn
WaterSnakeSpawn
```

這時火焰喵與潛水蛇可以先使用 Placeholder。

------------------------------------------------------------------------

## Milestone W5 --- Minimal HUD

完成：

``` text
Player HP
Active Pet
Pet HP
Party Slots
Interaction Prompt
```

只求可用，不做正式 UI 美術。

------------------------------------------------------------------------

## Milestone W6 --- World Playtest

讓學生實際玩。

記錄：

-   哪個區域找不到？
-   哪條路太長？
-   哪兩區太像？
-   學校看起來有沒有「水系」感？
-   火系區是否容易辨認？
-   山區是否看得出不能進？
-   從草原到學校要多久？
-   從草原到火系區要多久？

根據測試調整 Graybox。

------------------------------------------------------------------------

# 14. 學生研究課題

## 研究題目

> **不同屬性的怪獸，應該住在什麼樣的環境？**

由學生回答：

### 水系學校

-   為什麼學校變成水系？
-   哪些地方有水？
-   哪些怪獸住在這裡？
-   潛水蛇為什麼會出現在這裡？

### 火系區

-   為什麼火焰喵住這裡？
-   地面應該長什麼樣？
-   玩家怎麼一眼知道這是危險區？

### 草原

-   為什麼適合當起始區？
-   蛋殼龍為什麼適合這裡？

### 山區

-   這裡可以取得什麼？
-   為什麼會有洞窟？

------------------------------------------------------------------------

# 15. Claude Code / Codex 分工

## Claude Code

負責：

``` text
閱讀原始地圖
檢查現有 Scene
規劃 World Scene
Zone API
Navigation 架構
Milestone 拆解
Code Review
Scope Review
```

## Codex

負責：

``` text
建立 Godot Scene
建立 Graybox
建立 Zone
建立 Spawn Point
Navigation
HUD
Debug
修正錯誤
```

流程：

``` text
Claude Plan
→ Codex Implement
→ Codex Test
→ Claude Review
→ 學生 Playtest
→ 修改
```

------------------------------------------------------------------------

# 16. 給 Claude 的開發 Prompt

``` text
請完整閱讀：

- docs/godot_pet_survival_game_plan_v0.1.md（權威規格）
- CLAUDE.md
- .claude/skills/pet-survival/
- docs/PHASE_PLAYER_PROTOTYPE.md
- docs/PHASE_WORLD_PROTOTYPE.md
- docs/phase-1-progress.md（已完成的東西，不要重做）
- docs/references/world/world_map_original_v1.jpg（照片要順時針轉 90°）

這張手繪圖是學生的原始世界設計，不要重新設計成另一張地圖。

目前正式設定：
- 草原是起始中心區。
- 學校是水系區域。
- 火系區放置火焰喵。
- 水系學校未來放置潛水蛇。
- 山區有洞窟入口，但本 Phase 不製作 Dungeon。
- 聚落是未來基地區。

請先只規劃 Milestone W1 — World Graybox。

輸出：
1. 現有專案與本規格的差異
2. 建議 Scene Tree
3. 要新增/修改的檔案
4. 五個 Zone 的 Graybox 配置
5. 地圖尺寸與相對位置
6. 給 Codex 的最小實作任務
7. 驗收方式

不要提前實作 Combat、Capture、Dungeon、Base Building 或正式美術。
```

------------------------------------------------------------------------

# 17. 給 Codex 的開發 Prompt

``` text
請先閱讀：

- docs/godot_pet_survival_game_plan_v0.1.md（權威規格）
- CLAUDE.md
- docs/PHASE_PLAYER_PROTOTYPE.md
- docs/PHASE_WORLD_PROTOTYPE.md
- docs/phase-1-progress.md
- Claude 的 W1 Implementation Plan

現在只執行：

Milestone W1 — World Graybox

要求：
1. 使用 Godot Primitive 建立 Prototype World。
2. 建立草原、水系學校、火系區、山區、聚落。
3. 草原作為中心與 Player Spawn。
4. 水系學校位於草原一側，必須能從 Graybox 視覺辨認。
5. 火系區位於另一側。
6. 山區建立不可進入的洞窟入口 Placeholder。
7. 聚落只建立簡單房屋輪廓。
8. 不使用正式 3D Asset。
9. 不實作 Combat。
10. 不實作 Capture。
11. 不實作 Dungeon。
12. 不實作 Base Building。
13. 不擴大 Scope。

完成後確認專案可以啟動（CLAUDE.md 列的 headless 測試全過），並依 CLAUDE.md 的規定回報。
```

------------------------------------------------------------------------

# 18. Phase 完成條件

只有以下全部成立，才離開 World Prototype：

-   [ ] 主角可以在 Prototype World 移動
-   [ ] Camera 正常
-   [ ] 蛋殼龍可以跟隨
-   [ ] 五個區域都可辨識
-   [ ] 學校明確呈現水系概念
-   [ ] 火系區可辨識
-   [ ] 山區洞窟存在但未開放
-   [ ] 聚落有基地預留空間
-   [ ] Spawn Points 已建立
-   [ ] 最小 HUD 可使用
-   [ ] 學生完成一次地圖 Playtest
-   [ ] 根據 Playtest 至少修改一次地圖

> **原文這裡寫「完成後才進入 Monster Combat → Capture → Party」，已經過期。**
> 戰鬥、捕捉、Party、切換出戰寵物在 Phase 1 就做完並驗收了
> （見 `docs/phase-1-progress.md`），照原文走等於退回去重做。

完成後才進入：

``` text
潛水蛇 學校廁所特殊遭遇（完整事件版）
→ 學校室內樓層（1~4 樓）
→ 山洞 Dungeon
→ Base Building
```

------------------------------------------------------------------------

# 19. Scope Lock

本階段禁止：

``` text
第四隻怪獸
完整 Dungeon
大型世界
World Streaming
NPC 任務
商店
正式基地建造
Raid
Boss Raid
進化
複雜背包
正式美術 Polish
```

目前目標只有：

> **讓小朋友畫的世界，第一次變成可以親自走進去探索的遊戲地圖。**
