# Godot 抓寵生存遊戲｜三隻怪獸實作規劃 v1

> 適用：國小六年級 Godot 專題\
> 階段：Monster Prototype / Capture Vertical Slice\
> 核心原則：**第一個完整抓寵循環完成前，不增加第四隻怪獸。**

## 1. 三隻核心怪獸

  ----------------------------------------------------------------------------------
  怪獸           屬性           定位           核心特色               第一階段用途
  -------------- -------------- -------------- ---------------------- --------------
  蛋殼龍         草             防禦 / 控制    蛋殼、恐龍、藤蔓       Starter Pet

  潛水蛇         水             特殊 / 遠程    藏在馬桶、水流、漩渦   特殊野生遭遇

  火焰喵         火             敏捷 / 近戰    火焰、快速爪擊、爆發   第一隻可捕捉
                                                                      Wild Pet
  ----------------------------------------------------------------------------------


> **v1 修訂（實作後回饋）：第一隻可捕捉的 Wild Pet 由火焰喵改為潛水蛇。**
> 原因：蛋殼龍是 Grass，火焰喵是 Fire，Fire 克 Grass 1.5x，實測蛋殼龍 12.4 秒被打死，
> 連「削弱到可以丟球」都做不到（硬規則 4）。改成 Grass 克 Water 的潛水蛇後 6.4 秒獲勝。
> 火焰喵維持 Fire，改為後期才該挑戰的硬對手。詳見 `phase-1-progress.md`。
>
> **v1.1 修訂（2026-09-14，使用者決定）：第一階段的流程改成「抓兩隻」。**
> 蛋殼龍抓潛水蛇 → 切換成潛水蛇 → 用潛水蛇（Water 克 Fire）打火焰喵並捕捉。
> 「馬桶靠近才出現」的特殊遭遇（§14 step 15）**移出第一階段**，潛水蛇在第一階段是一般野怪。
> §1 表格的「第一階段用途」、§14、§15 以此為準。

### 蛋殼龍

玩家初始怪獸，也是第一隻完整實作的怪獸。普通攻擊為「咬擊」，特殊技能為「藤蔓衝擊」。所有方向素材、動畫、PetData、AI
與戰鬥 Component 先以它建立製作 Pipeline。

### 火焰喵

第一隻可捕捉 Wild
Pet。用來驗證完整流程：`戰鬥 → 削弱 HP → 丟球 → 捕捉 → 加入 Party → 切換出戰`。

### 潛水蛇

特殊遭遇怪獸。平常只看到馬桶，玩家靠近後觸發水面變化，潛水蛇才出現。用來研究
Trigger、Event、Spawn 與特殊遭遇設計。

## 2. 下一階段目標

現在停止增加新怪獸，把三張設定圖轉成真正可玩的 Godot 角色。

``` text
小朋友原始設計
→ 怪獸 Concept
→ 遊戲角色定稿
→ 方向素材
→ 動作素材
→ AnimatedSprite3D
→ PetData
→ Pet AI
→ Combat
→ Capture
→ Party
```

第一個完整里程碑：

``` text
玩家帶著蛋殼龍
→ 發現火焰喵
→ 指定目標
→ 蛋殼龍追擊與自動攻擊
→ 火焰喵 HP 降低
→ 玩家丟捕捉球
→ 捕捉成功
→ 火焰喵加入 Party
→ 玩家切換火焰喵出戰
```

## 3. 第一個技術研究：4 方向還是 8 方向？

遊戲採用 3D 世界 + 2D 怪獸 + AnimatedSprite3D，Camera
可以旋轉。因此第一個研究問題是：

> **2D 怪獸放在可以旋轉的 3D 世界中，需要幾個方向才自然？**

第一輪只製作蛋殼龍的 **8 Direction Idle**，放入 Godot 後讓 Camera
繞角色旋轉 360°，記錄不自然的角度，再與 4 Direction 比較。

如果 4 向已足夠自然，就採 4 向降低後續素材成本；若旋轉時跳向明顯，再採 8
向。

## 4. 怪獸動畫製作順序

### Stage A --- Direction Test

只做 `Idle`，驗證 Sprite3D、Camera Rotation 與方向判定。

### Stage B --- Gameplay Prototype

製作： - Idle：4 frames - Walk：6 frames - Attack：6 frames

做到這裡就先停止美術，進 Godot 驗證玩法。

### Stage C --- Combat Polish

玩法成立後再補： - Skill - Hit - Dead

### Stage D --- Special

最後才做： - Capture - Spawn - Evolution - Special Encounter

## 5. Godot Pet Scene

``` text
Pet (CharacterBody3D)
├── Visual
│   └── AnimatedSprite3D
├── NavigationAgent3D
├── HealthComponent
├── TargetComponent
├── CombatComponent
├── SkillComponent
├── PetAI
├── Hurtbox
└── SelectionIndicator
```

不要替蛋殼龍、火焰喵、潛水蛇各寫一整套戰鬥程式。使用共用 `Pet` Scene
搭配不同 `PetData` 產生差異。

## 6. PetData

怪獸資料使用 Godot `Resource`：

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

蛋殼龍第一版測試值：

``` text
ID              eggshell_dragon
Name            蛋殼龍
Element         Grass
Role            Tank / Control
HP              100
Attack          15
Defense         20
Move Speed      3.5
Basic Attack    咬擊
Special Skill   藤蔓衝擊
Capture         Normal
```

這些只是實驗起點，不是最終平衡值。

## 7. Pet AI

第一版只需要：

``` text
IDLE
FOLLOW
CHASE
ATTACK
CAST_SKILL
RETURN
DEAD
```

流程：

``` text
FOLLOW
→ 玩家指定 Target
→ CHASE
→ 進入攻擊距離
→ ATTACK
→ 敵人死亡
→ RETURN
→ FOLLOW
```

第一版不要加入情緒、飢餓、工作、自動採集、個性 AI 或群體戰術。

## 8. Starter：蛋殼龍

完成條件：

-   [ ] 顯示在 3D 世界
-   [ ] 正確切換方向
-   [ ] Idle / Walk / Attack
-   [ ] 跟隨玩家
-   [ ] 接受 Target
-   [ ] Chase
-   [ ] Attack
-   [ ] 敵人扣 HP
-   [ ] 敵人死亡後 Return
-   [ ] 回到 Follow

驗收：玩家不直接攻擊，蛋殼龍能依照玩家指定目標完成一次戰鬥。

## 9. Wild Pet：火焰喵

蛋殼龍戰鬥成立後才開始。第一版狀態：

``` text
IDLE
ALERT
CHASE
ATTACK
HIT
DEAD
```

先完成蛋殼龍與火焰喵互相戰鬥，再加入 Capture。

## 10. Capture System

捕捉是目前最高優先級 Gameplay Feature。

第一版捕捉率考慮：

``` text
Target HP
+ Species Capture Difficulty
+ Capture Ball Power
```

HP 越低，Capture Chance 越高。

成功：野生怪獸從世界移除，建立 Pet Instance，加入 Collection；Party
有空位則加入 Party。

失敗：消耗 Capture Ball，野生怪獸繼續戰鬥。

## 11. Party

-   Party 最多 5 隻
-   場上只能 1 隻
-   PC 使用 1--5 切換
-   Starter 為蛋殼龍
-   捕捉火焰喵後可以切換出戰

第一個完整驗收：捕捉火焰喵後，蛋殼龍退場、火焰喵出場，並能繼續戰鬥。

## 12. 潛水蛇特殊遭遇

``` text
普通馬桶
→ Player Enter Trigger
→ 水面晃動
→ Splash
→ 潛水蛇出現
→ Alert
→ 戰鬥 / 捕捉
```

## 13. 學生研究課題

**題目：2D 怪獸放在可以旋轉的 3D 世界中，需要畫幾個方向才自然？**

研究方式： 1. 猜測 4 方向或 8 方向哪個比較自然。 2.
同一隻蛋殼龍製作兩種版本。 3. Camera 旋轉 360°。 4.
記錄奇怪角度、素材張數與製作時間。 5. 比較玩家是否感覺得到差異。 6.
根據效果與成本決定正式方案。

研究重點不是「8 向一定比較好」，而是：

> **增加一倍素材成本，得到的畫面改善值不值得？**

## 14. 實作順序

``` text
01 蛋殼龍 8 Direction Idle
02 Godot Direction Test
03 決定 4 / 8 Direction
04 蛋殼龍 Walk
05 蛋殼龍 Attack
06 建立共用 Pet Scene
07 PetData
08 Follow AI
09 Target / Chase / Attack
10 火焰喵 Wild Pet
11 Wild Combat
12 Capture System ★
13 Party
14 切換蛋殼龍 / 潛水蛇 ★（v1.1：原為火焰喵）
15 潛水蛇打火焰喵並捕捉（v1.1：取代「潛水蛇 Special Encounter」，特殊遭遇移出第一階段）
```

## 15. 第一階段完成條件

v1.1 修訂版（2026-09-14）：

``` text
玩家進入世界
→ 蛋殼龍跟隨
→ 找到潛水蛇
→ 指定攻擊
→ 蛋殼龍自動戰鬥（Grass 克 Water）
→ 潛水蛇低 HP
→ 玩家丟球
→ 捕捉成功
→ 潛水蛇加入 Party
→ 玩家切換潛水蛇
→ 找到火焰喵，指定攻擊
→ 潛水蛇自動戰鬥（Water 克 Fire）
→ 火焰喵低 HP
→ 玩家丟球
→ 捕捉成功，火焰喵加入 Party
```

原版最後三步「探索時發現馬桶 → 靠近 → 潛水蛇出現」移出第一階段。

## 16. Scope Lock

以下三件事完成前：

-   蛋殼龍可以正常戰鬥
-   潛水蛇、火焰喵可以捕捉並加入 Party（v1.1）
-   玩家可以切換蛋殼龍 / 潛水蛇（v1.1）

不要提前開發： - 第四隻怪獸 - 完整進化系統 - 大型地圖 - 完整基地系統 -
Raid / Boss Raid - Tech Tree - Pet Equipment - IV / Personality / Random
Trait

目前最重要的不是「怪獸很多」，而是：

> **第一隻怪獸好不好操作、第一場戰鬥好不好理解、第一次捕捉有沒有成就感。**
