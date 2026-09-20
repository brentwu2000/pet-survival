# Phase 1 — Catching Vertical Slice 進度

驗收流程（規格書 §26，唯一標準）：

```text
玩家帶 Starter 出門 → 找到 Wild Pet → 指定攻擊 → Starter 自動戰鬥
→ Wild Pet HP 降低 → 丟捕捉球 → 捕捉成功 → 加入 Party → 切換出戰 → 繼續戰鬥
```

具體化（規劃書 §15 v1.1，2026-09-14 使用者決定）：

```text
蛋殼龍削弱潛水蛇 → 捕捉 → 按 2 切換潛水蛇 → 潛水蛇（Water 克 Fire）打火焰喵 → 捕捉火焰喵
```

## 已完成

對照規劃書 §14 實作順序：

| # | 項目 | 狀態 |
|---|------|------|
| 01 | 蛋殼龍 8 Direction Idle | ✅ placeholder（三隻各 8 向 × 4 幀，共 96 張） |
| 02 | Godot Direction Test | ✅ 程式面驗證完成；**主觀判斷待人眼繞鏡頭 360°** |
| 03 | 決定 4 / 8 Direction | ✅ **定案 8 方向** |
| 04–05 | 蛋殼龍 Walk / Attack | ⬜ 美術（8 方向 × 每個動作） |
| 06 | 共用 Pet Scene | ✅ `scenes/pets/pet.tscn` |
| 07 | PetData / SkillData / ElementTable | ✅ |
| 08 | Follow AI | ✅ |
| 09 | Target / Chase / Attack | ✅ 含滑鼠指定目標 |
| 10–11 | 火焰喵 Wild Pet / Wild Combat | ✅ 反擊已通 |
| 12 | Capture System ★ | ✅ |
| 13 | Party | 🔸 容器完成，UI 未做（併入 Basic HUD） |
| 14 | 切換出戰寵物 ★ | ✅ 數字鍵 1~5，HP 跟著 PetInstance 走 |
| 15 | 潛水蛇打火焰喵並捕捉 | ✅ `switch_test` 整段真打走通（v1.1 取代「潛水蛇 Special Encounter」，特殊遭遇移出第一階段） |
| — | Basic HUD | ⬜ **下一步，Phase 1 最後一項** |

### 資料層

```
scripts/data/
  element.gd         5 種屬性的 enum（只有 enum，克制關係不在這裡）
  element_table.gd   克制表 Resource，1.5 / 1.0 / 0.75
  pet_data.gd        種族資料（Data，不存檔）
  skill_data.gd      技能資料

resources/
  balance/element_table.tres
  skills/   skill_bite / vine_crash / claw / ember_burst / water_jet / whirlpool
  pets/     pet_eggshell_dragon / pet_flame_cat / pet_diving_snake
  pets/frames/  frames_*.tres（SpriteFrames，8 方向 × 4 幀）
```

克制關係（`element_table.tres`）：

```
Fire     → Grass
Water    → Fire
Grass    → Water, Ground
Electric → Water
Ground   → Fire, Electric
```

> **SpriteFrames 不能放在 `resources/pets/` 直接底下**——`Database._load_dir()` 會把
> 那一層的每個 `.tres` 當成 PetData，掃到沒有 `id` 欄位的東西就 `push_error`。
> 放在 `resources/pets/frames/` 子目錄，`list_directory` 不會遞迴進去。

### PetAI FSM（規格書 §9）

```
scripts/ai/
  pet_command.gd   ATTACK_TARGET / FOLLOW / STAY / DEFEND / RETREAT
  pet_ai.gd        IDLE FOLLOW CHASE ATTACK CAST_SKILL RETURN DEFEND DEAD
```

單一 script + `match`，**沒有 Behaviour Tree**（規格書 §9 明確不做），
也沒有為八個狀態各開一個 Node class。

`behaviour` 這個 export 決定玩家寵物還是野生寵物：

| | FOLLOWER | WILD |
|---|---|---|
| 初始狀態 | FOLLOW | IDLE |
| anchor | 玩家 | spawn 點 Marker3D |
| 接敵 | 玩家下 ATTACK_TARGET | 被打就反擊（`HealthComponent.damaged`） |
| layer | 3 PetFriendly + 9 Selectable | 4 Enemy + 9 Selectable |

> skill 的 `04-pet-ai-fsm.md` 建議用 `WildPetAI extends PetAI`。這裡改用一個 export，
> 因為差別只有初始 command 與 anchor，不值得多一個子類別＋多一個 `.tscn` 要同步。
> Phase 5 的 Enemy AI 真的需要新狀態時再抽子類別。

**FSM 裡沒有任何 `sprite.play()`**——只 emit `state_changed`，`PetVisual` 監聽後自己決定播什麼。

`NavigationAgent3D` 的 `avoidance_enabled` 目前是**關的**。開了就必須改用
`velocity_computed` 回呼，不能同時在 `_physics_process` 尾端呼叫 `move_and_slide()`，
否則會 double move。那是 Phase 6 的事。

### 玩家指揮（硬規則 1：玩家不直接攻擊）

`player.gd` 的左鍵不是攻擊，是**指定目標讓寵物去打**：raycast 只打 layer 9 Selectable，
點空地等於取消指令回到跟隨。`active_pet` 目前由 World 指派，PartyManager 落地後改由它維護。

### 狀態容器（Capture 的前置，步驟 A）

```
scripts/data/
  pet_instance.gd      執行期的「這一隻」——存檔存它，不存 PetData
  ball_data.gd         捕捉球
  capture_balance.gd   捕捉率的設計旋鈕

scripts/systems/
  inventory.gd         物品數量（Phase 1 只有球）
  pet_collection.gd    捕捉到的所有寵物，無上限
  party_manager.gd     探索隊伍，上限 5、同時出戰 1

resources/
  items/ball_basic.tres  ball_great.tres
  balance/capture_balance.tres
```

> `scripts/systems/` 不在規格書 §20 的資料夾清單裡。規格書原文：
> 「這是初始方向，不要求 AI 為了符合資料夾而過度抽象。」
> 這三個是 gameplay 狀態物件，塞進 components / ai / data 都不對，所以另開一層。

**這三個都不是 autoload**（規格書 §21 只定義五個）。由 `Game` 持有：

```gdscript
Game.party.set_active(2)
Game.inventory.consume(&"ball_basic")
Game.acquire_pet(&"flame_cat")     # 建 instance -> 進收藏 -> Party 有位就加入
```

`Game` 只持有與管生命週期，邏輯在各自的 class 裡——規格書警告的 God Object 是後者。

PartyManager 把三條硬規則寫成 `const` 與擋條件，**不是可調數值、不進 balance resource**：

| 硬規則 | 實作 |
|---|---|
| Party 上限 5 | `MAX_SIZE`，第 6 隻 `add()` 回傳 false |
| 同時出戰 1 | 單一 `_active_index` |
| 玩家必須始終有可出戰寵物 | `remove_at()` 會擋掉「移掉之後 `usable_count()` 變 0」；出戰寵物倒下時 `on_active_fainted()` 自動換下一隻 |

開局流程：World 發 10 顆捕捉球，Starter 走完整路徑
（建 PetInstance → 進收藏 → 進 Party → 自動出戰），不再是直接生一個節點。

### Component（規格書 §22）

```
scripts/components/
  health_component.gd   HP / 傷害 / 死亡；health_ratio 是捕捉率的直接輸入
  target_component.gd   當前目標與有效性；降頻 0.25s + 相位打散
  combat_component.gd   普攻冷卻、射程、**全專案唯一的傷害公式**
  skill_component.gd    特殊技能冷卻與施放
```

傷害公式（只存在 `CombatComponent.deal_damage`）：

```
damage = max(power × element_multiplier × 100/(100 + defense), 1.0)
```

普攻的 `power` **來自 `basic_attack.power`**（射程 / 冷卻 / 屬性也是），技能的來自 `skill.power`。

屬性倍率一律問 `Database.element_table`，程式裡沒有任何 `if element == ...`。

### Pet Scene

```
Pet (CharacterBody3D)   layer 3|9 (PetFriendly|Selectable), mask 1|5
├── CollisionShape3D
├── Visual (PetVisual)
│   └── AnimatedSprite3D
├── NavigationAgent3D
├── HealthComponent
├── CombatComponent
├── SkillComponent
└── TargetComponent
```

`pet.gd` 是 Orchestrator，只做組裝：`setup(PetData)` 把數值注入各 component。
**新增一隻寵物只要新增 `.tres`，不動任何 `.gd`。**

`World` 開場放 Starter（蛋殼龍）與兩隻 Wild Pet（火焰喵、潛水蛇）。

## 方向系統

素材與程式都用羅盤命名：`s`（面向鏡頭）`se e ne n`（背對鏡頭）`nw w sw`。

**已定案：8 方向。** 正式素材（Walk / Attack / Skill / Hit / Dead）都要做 8 套。
`PetVisual.direction_count` 的 4 方向模式保留下來只當比較工具，不是正式設定。

程式面已驗證鏡頭繞一圈的對應是單調且正確的：

```
camera_yaw   0°  45°  90° 135° 180° 225° 270° 315°
animation     s   se    e   ne    n   nw    w   sw
```

**還沒驗證的是左右有沒有相反**——這要人眼看。如果繞鏡頭時覺得左右顛倒，
把 `pet_visual.gd` 的 `_compute_direction_index()` 裡 `angle` 前面的負號拿掉即可。

## 測試

```bash
GODOT="/c/Users/b/Downloads/Godot_v4.6.3-stable_win64.exe/Godot_v4.6.3-stable_win64_console.exe"
PROJ="$(pwd -W)"

"$GODOT" --headless --path "$PROJ" res://tests/phase1_data_test.tscn  # 資料、克制表、注入、傷害
"$GODOT" --headless --path "$PROJ" res://tests/direction_test.tscn    # 鏡頭相對方向對應
"$GODOT" --headless --path "$PROJ" res://tests/pet_ai_test.tscn       # FSM、leash、指揮 raycast、反擊、死亡
"$GODOT" --headless --path "$PROJ" res://tests/party_inventory_test.tscn  # 物品、收藏、隊伍硬規則
"$GODOT" --headless --path "$PROJ" res://tests/capture_test.tscn      # 捕捉率、前置條件、成功/失敗、Q 鍵
"$GODOT" --headless --path "$PROJ" res://tests/switch_test.tscn       # 驗收流程：抓潛水蛇 → 切換 → 打火焰喵 → 捕捉
```

全過 exit 0，有失敗則 exit 為失敗數。

> **不要用 `--script` 跑測試。** `--script` 模式不會註冊 autoload 的全域識別字，
> 任何引用 `Database` 的 script 會編譯失敗；症狀是 `@onready` 拿到 null、
> GDScript 執行期錯誤中斷函式、`quit()` 沒被呼叫，於是整個行程**卡住不結束**。
> 一律用「跑一個場景」的方式。

## 美術 placeholder

`tools/gen_placeholder_sprites.py`（Pillow，純程式繪製、無亂數、可重跑）產出
`assets/pets/<id>/idle_<dir>_<frame>.png`，共 96 張。
細節與總覽圖見 `tools/README.md` 與 `tools/placeholder_contact_sheet.png`。

正式素材進來時直接覆蓋同名檔案即可，`frames_*.tres` 不用改。

## 平衡與屬性（已解決）

### 第一隻可捕捉的 Wild Pet 改為潛水蛇

原本的問題：蛋殼龍是 Grass、火焰喵是 Fire，Fire 克 Grass 1.5x，
實測蛋殼龍 12.4 秒被打死——連「削弱到可以丟球」都做不到（硬規則 4）。

中間曾試過把火焰喵改成 Water，但那會讓**潛水蛇不再是唯一的水系**，
而且和牠的名字、素材、技能全部矛盾。最後採用的是：

**第一隻可捕捉的 Wild Pet 換成潛水蛇（Water）**，火焰喵維持 Fire 不動。

- 三隻屬性回到 Grass / Fire / Water **互不重複**（`phase1_data_test` 有測試守著）
- 火焰喵克 Grass，改為後期才該挑戰的硬對手——放在離出生點更遠的地方
- 規劃書 §1 已加修訂註記

### 減傷公式改成遞減

線性的 `power − defense` 有硬牆問題：蛋殼龍 DEF 20 對上威力 14~18 的攻擊，
只要不是克制方就會被扣成負數、一律落到 `MIN_DAMAGE`，等於「非克制 = 完全無傷」。
潛水蛇打蛋殼龍每下都只有 1 點，第一場只掉 3 點血，完全沒有張力。

現在是：

```gdscript
const DEFENSE_K := 100.0
mitigation = DEFENSE_K / (DEFENSE_K + defense)
damage     = max(power × element_multiplier × mitigation, MIN_DAMAGE)
```

防禦仍然有感（DEF 20 減 16.7%、DEF 8 減 7.4%），但不會變成硬牆。

| 對戰 | 線性（舊） | 遞減（現在） |
|---|---|---|
| vs 潛水蛇（第一隻可捕捉） | 勝，剩 97/100，6.4s | **勝，剩 73.8/100，4.0s** |
| vs 火焰喵（後期硬對手） | 敗，12.4s | 敗，8.0s |

`DEFENSE_K` 是單一常數，要調回線性或改 K 值都只動 `combat_component.gd` 一行。

### 攻擊屬性與防禦屬性已分離

`CombatComponent` 原本只有一個 `element`，同時當攻擊屬性與防禦屬性用，
而 `basic_attack.element` 又會覆寫它——等於**寵物的防禦屬性會被自己普攻的屬性蓋掉**。
已拆成兩個欄位：

```gdscript
@export var element: Element.Type         # 防禦側，來自 PetData.element
@export var attack_element: Element.Type  # 攻擊側，來自 basic_attack.element
```

`deal_damage(target, power, atk_element)` 的防禦側一律讀 `target_combat.element`。

### `PetData.attack` 的定位

普攻威力來自 `basic_attack.power`、技能威力來自 `skill.power`，
所以 `attack` 在 Phase 1 **不被讀取**。這不是遺漏——它是
規格書 §26 Phase 2（Element / Damage / Skill / EXP / **Level**）的成長數值。
Phase 1 硬給它一個用途，反而會變成之後升級系統要拆掉的東西。

## 素材與設定圖的對照

設定圖（`assets/monster_concepts/`）是小朋友的原始設計，是命名與外觀的依據。
對照後修正過兩處：

| | 設定圖 | 曾經寫錯成 |
|---|---|---|
| 火焰喵技能 | 爪擊 / 火焰爆發 | 快速爪擊 / 烈焰爆發 |
| 潛水蛇技能 | 水彈 / 漩渦噴射 | 水流噴射 / 漩渦 |

**潛水蛇的關鍵特徵是馬桶**——設定圖裡牠的本體就是一個白色馬桶，藍色蛇頭從馬桶口探出來，
三視圖（正面 / 側面 / 背面 / 俯視）全部以馬桶為基座。第一版 placeholder 漏掉了馬桶，
只畫了藍蛇加水流，已重做。

新增怪獸或改素材前**先看設定圖**，不要憑名字猜。

## 玩家回饋（SelectionIndicator / 血條）

原本「點了怪獸沒反應」完全無法判斷原因，因為指令成功與失敗在畫面上長得一模一樣。
現在：

- **腳下圓盤**（`scenes/pets/selection_indicator.gd`，規格書 §22 的 SelectionIndicator）
  青色 = 出戰中的自家寵物、紅色 = 玩家指定的攻擊目標
- **頭頂血條**（`scenes/pets/health_bar.gd`）滿血自動隱藏，掉血才出現，
  顏色綠 → 黃 → 紅。捕捉系統看的就是這條（規格書 §10：HP 越低捕捉率越高）
- `PetAI.command_rejected(reason)` 訊號，指令無法執行時發出（目前先 print，HUD 落地後改畫面提示）

> **圓盤不要用細圓環。** 第一版用 `TorusMesh`（內 0.42 / 外 0.55），
> 在正常鏡頭距離下只有 1~2 像素寬，**實際上完全看不到**，還誤以為程式沒生效。
> 改成半透明實心圓盤（`CylinderMesh`）才看得出來。
> 顏色也不能只靠色相：綠色圓圈畫在深綠地面上等於沒畫。

## 已修：點怪獸「完全沒反應」

回報的症狀是點了潛水蛇，寵物不出發。根因有三個疊在一起：

1. **屍體留在 Selectable 層**——死掉的寵物沒有關掉碰撞，raycast 照樣打得到，
   所以玩家會對著一具屍體一直點
2. **對已死目標下指令會靜默失敗**——`issue_command` 照樣進 `CHASE`，
   下一個 frame 被 `_tick_chase` 踢回 `IDLE`。狀態閃一下就回來，畫面上完全看不出差別
3. **`current_target` 沒有被清掉**，屍體會一直掛在目標欄位上

修法：

- `Pet._on_died()` 立刻把 `collision_layer` / `collision_mask` 歸零並關掉光圈
- 野生寵物屍體淡出 1.2 秒後 `queue_free()`；玩家的寵物留在場上等 PartyManager（規格書 §5）
- `PetAI.issue_command(ATTACK_TARGET)` 先驗證目標可攻擊，不通過就發 `command_rejected` 並保持原狀態
- `_tick_chase` / `_tick_attack` 目標失效時呼叫 `clear_target()`

`pet_ai_test` 有完整的迴歸覆蓋（屍體離開 Selectable、raycast 打不到、指令被拒、狀態不閃、屍體被移除）。

## ⚠️ 在瀏覽器裡驗證的兩個陷阱

這兩個都讓我一度誤判「程式沒生效」，**驗證 Web build 前一定要先排除**：

### 1. Chrome 會快取 `index.pck`

重新匯出之後直接 F5 或重新導向，載到的可能還是**舊的 build**。
必須 **Ctrl+Shift+R 硬重新整理**。我有兩次「在瀏覽器確認過」其實看的是舊版本。

### 2. 分頁不在前景 = 遊戲幾乎停住

Chrome 對隱藏分頁把 `requestAnimationFrame` 節流到接近零。實測：

```js
document.visibilityState  // "hidden"
```

此時 Godot 每秒只拿到極少的 frame，`_physics_process` 受
`max_physics_steps_per_frame` 限制無法補回來，遊戲時間變成正常速度的一小部分。
表現出來就是「寵物走得超級慢」甚至「完全不動」。

**這不是 bug，是 Web 平台行為**（`09-web-performance.md` 已列出「背景分頁暫停」）。
但症狀很像程式壞掉，所以測 Web build 時**務必讓視窗在前景**。
Headless 跑出來的移動速度是精準的 3.50 m/s、2.2 秒進入攻擊距離。

## 捕捉系統（規格書 §10）

```
capture_rate = ball_power × hp_modifier × rarity_modifier    上限 0.95
```

`CaptureSystem` 由 `Game` 持有（`Game.capture`），不是 autoload。
`MAX_RATE = 0.95` 是 **const 不是可調數值**——硬規則 3「普通情況不要輕易達到 100%」。

硬規則對照：

| 規則 | 實作 |
|---|---|
| 必須先靠戰鬥削弱 | 滿血 `hp_modifier` 只有 0.3，殘血才 1.0 |
| 失敗：球消耗、目標不消失、戰鬥繼續 | 失敗分支什麼都不做，FSM 完全不碰 |
| 普通球到不了 100% | `clampf(rate, 0, MAX_RATE)` |
| 成功要移除野寵 | 順序固定「建 instance → 進收藏 → emit → `queue_free()`」 |

成功後**以滿血加入**。曾經存「捕捉當下的殘血」，但 Phase 1 沒有任何回血手段，
剛抓到的寵物只能殘血上場，驗收流程「抓潛水蛇 → 切換 → 打火焰喵」會必輸。
之後有基地回血（Phase 4）時可以再改回來，只動 `CaptureSystem._on_success` 一處。

操作：先左鍵指定目標讓寵物打，再按 **Q** 丟球。丟球的對象就是寵物正在打的那隻，
所以「必須先削弱」在操作層面也自然成立。

Phase 1 **不做球的飛行**，按 Q 立即判定。
skill 明說「不要為了球的物理表現卡住捕捉流程的驗收」。

### 捕捉回饋（規格書 §10「播放捕捉 Feedback」）

判定在 `CaptureSystem` 就算完了，特效**純表現層**，不影響任何 gameplay 結果。

```
scenes/fx/capture_effect.tscn     球搖晃 -> 成功星芒 / 失敗煙塵，播完自己 queue_free
resources/fx/capture_fx_frames.tres
assets/fx/ball/     ball_basic / ball_great 各 4 幀搖晃（32×32）
assets/fx/success/  6 幀 金色星芒外擴（64×64）
assets/fx/fail/     5 幀 灰色煙塵下沉（64×64）
```

流程：

```
按 Q → 判定（瞬間算完）
  → 球從玩家胸口畫拋物線飛向目標（0.34s）        ♪ throw
  → 落地                                      ♪ land
  → 怪獸縮小淡出被吸進球裡（0.35s）  ← 成功與失敗都會被吸進去
  → 球搖 N 下（每下 0.45s）                     ♪ shake ×N
  → 成功：金色星芒，怪獸 queue_free()             ♪ success（上行明亮）
    失敗：灰色煙塵，怪獸彈回來繼續戰鬥              ♪ fail（下行低沉）
```

**球的拋物線**：規格書 §26 說 Phase 1 不做球的飛行——那是為了不讓球的物理卡住捕捉流程的驗收。
驗收已經走通了，所以現在補上只是加回饋，不影響任何判定。
用 `tween_method` 做直線插值 + 一條 sin 弧線，沒有引入物理。
沒有投擲起點時（例如測試直接生特效）會退化成從正上方落下。

**音效**（`assets/sfx/capture/`，`tools/gen_capture_sfx.py` 純 Python 標準函式庫合成，無亂數可重跑）：

| | 長度 | 用途 |
|---|---|---|
| `throw.wav` | 0.18s | 破空 |
| `land.wav` | 0.15s | 球落地 |
| `shake.wav` | 0.10s | 每搖一下響一次——所以**聲音也在說「差多少」** |
| `success.wav` | 0.90s | 上行明亮琶音 |
| `fail.wav` | 0.50s | 下行低沉 |

全部 44100 Hz / 單聲道 / 16-bit，峰值 -3 dBFS 無削波。
用 `AudioStreamPlayer3D` 播（有距離衰減）。音檔缺席時 `_play_sfx()` 直接 return，不噴錯。

> Web 的音訊 autoplay 限制：首次玩家互動前不能播聲音。
> 捕捉必須先點目標再按 Q，一定有過互動，所以這條在捕捉流程上不成問題。
> 但**開場音樂或環境音**之後要做的話，就得先處理這個限制。

**成敗都要先被吸進去**，失敗才會有「跑出來」可演。
第一版只有成功會吸，失敗時球在一隻從沒被吸進去的怪旁邊爆開，讀起來不成立。

搖幾下由判定結果決定（`CaptureSystem.shake_count()`，純表現不影響結果）：
成功一律搖滿 3 下；失敗時**成功率越高搖越多**（rate 0.9 → 3 下、0.67 → 2 下、0.1 → 1 下），
演出「就差一點」。

被吸進球裡的期間怪獸 `invulnerable = true` 且離開碰撞層，
所以不會被自家寵物繼續打、也點不到。失敗彈出來後全部還原——測試有守著
（碰撞層還原、不再無敵、FSM 恢復運作、HP 全程沒被動過）。

> **節奏常數只有一份**，在 `CaptureSystem`（`THROW_SECONDS` / `ABSORB_SECONDS` / `SHAKE_SECONDS`）。
> 球的動畫與怪獸的縮放都讀它，分開寫兩份就會慢慢對不上。

### 踩到的兩個坑

**1. `_ready()` 不能拿來啟動需要外部座標的演出**

`_ready()` 是在 `add_child()` **當下**執行的，但 `global_position` 得先進樹才能設。
第一版在 `_ready()` 就算拋物線，拿到的是還沒設定的 `throw_from` 與還在原點的自己，
結果球永遠走「從正上方落下」的退化路徑——**畫面上完全沒有投擲動作**。

改成由 spawn 端明確呼叫 `CaptureEffect.start()`：

```gdscript
effect.throw_from = ...        # 進樹前設好純資料
add_child(effect)
effect.global_position = ...   # 進樹後才能設
effect.start()                 # 最後才啟動演出
```

**2. 測試只驗「屬性有被設上」= 假通過**

當時的測試檢查 `has_throw_origin == true`、`throw_from` 在玩家身上——
兩條都過，但球根本沒飛。**驗輸入不等於驗行為。**
現在改成取樣球的實際飛行路徑：起點在玩家、終點在目標、
而且中點高度明顯高於起訖連線（證明是弧線不是直線）。

**3. 測試不要用 frame 數當計時器**

headless 沒有 vsync，process frame 跑得比 60fps 快很多，
「等 240 frame」換算成秒數是錯的，會把好的功能判成失敗。
改用 `Time.get_ticks_msec()` 的真實時間預算（`_wait_for()`）。

> 特效找不到素材時會靜默退化成等長的空白，**不會卡住捕捉流程**——
> 測試有守著這條（素材還沒進來時我就是這樣先把邏輯做完的）。

成功用暖色星芒、失敗用冷色煙塵，刻意讓兩者一眼分得出來。
球的飛行仍然沒做（規格書 §26 Phase 1 不做，skill 也明說不要為球的物理卡住驗收）。

### 捕捉難度已下調

原本 `rarity_modifier_at_hard = 0.25`，潛水蛇（`capture_difficulty` 0.6）殘血用普通球只有 55%。
改成 **0.45** 之後：

| | capture_difficulty | 殘血 × 普通球 | 殘血 × 高級球 |
|---|---|---|---|
| 蛋殼龍 / 火焰喵（普通） | 0.5 | 72.5% | 95%（上限） |
| 潛水蛇（偏高） | 0.6 | **67%** | 95%（上限） |
| 滿血的潛水蛇 | — | 20.1% | 30.2% |

**調的是 `CaptureBalance` 的曲線，不是各怪的 `capture_difficulty`**——
這樣設定圖的「普通 / 普通 / 偏高」相對關係還在，之後要再調也只動一個 `.tres`。

## 切換出戰寵物（§14 step 14）

```
按 1~5 → Player.switch_to_slot() → PartyManager.set_active()
       → EventBus.active_pet_changed → World._on_active_pet_changed()
       → 舊節點收回、新節點在原地出場、接手舊寵物的目標
```

- **場上節點一律跟著 PartyManager 走。** 開局、按數字鍵、出戰寵物倒下，全部是同一條路——
  World 不再直接生 Starter，而是 `acquire_pet` 觸發 `active_pet_changed` 生出來
- Player 只改 Party 狀態，**不碰節點**；World 只聽訊號，**不讀按鍵**
- World 只看 `Game.party.active`，不信任訊號的 slot 參數（別的 PartyManager 也會發同一個訊號）

### HP 跟著 PetInstance 走

`Pet.bind_instance()`：出場時 `health.setup(max_hp, instance.current_hp)`，
之後每次 `health_changed` 都寫回 `instance.current_hp`。收回前 `unbind_instance()` 斷開。
換出去再換回來不會補血——`switch_test` 守著。

### 倒下

出戰寵物的 `died` 以 `CONNECT_DEFERRED` 接到 `PartyManager.on_active_fainted()`——
不要在 `take_damage` 的 call stack 裡生節點。自動換上下一隻可出戰的，屍體淡出 1.2 秒。
全隊倒光時沒有下一隻可換，屍體留在場上（重生回 Base Core 是 Phase 4 的事）。

### 對戰實測（headless 真打）

| 對戰 | 結果 |
|---|---|
| 蛋殼龍 vs 潛水蛇（第一隻） | 勝，剩 73.8/100，2.9s |
| 潛水蛇（滿血）vs 火焰喵（第二隻） | 勝，剩 50.7/80，2.2s——射程 7 對 1.8 |

潛水蛇只要 HP 低於約 30 就會輸給火焰喵，這也是捕捉改成滿血加入的原因。

## Basic HUD（規格書 §26 Phase 1 最後一項）— 已完成

`scenes/ui/hud.tscn`（CanvasLayer，掛在 `world.tscn` 底下），四個東西：

| 位置 | 內容 |
|---|---|
| 畫面上方正中 | 目標面板：名字（屬性）、HP 數字、血條。沒有目標時整個隱藏 |
| 畫面下方正中 | Party 五格：`1 蛋殼龍 100/100` + 血條。出戰的亮黃框、倒下的調暗、空格顯示 `--` |
| 五格右邊 | `捕捉球 ×10` |
| 五格上方 | 提示訊息，2.2 秒後淡出 |

### HUD 只讀狀態、只聽 signal

不改任何 gameplay 狀態，整棵樹都是 `MOUSE_FILTER_IGNORE`——
**左鍵是「指定目標」的 raycast，被 Control 吃掉就會變成點了沒反應。**

接線：

```
Game.inventory.count_changed   -> 球數
Game.party.party_changed       -> 五格
EventBus.active_pet_changed    -> 五格（誰出戰）
Player.active_pet_node_changed -> 改聽新出戰寵物的 health / targeting / command_rejected
  └─ health_changed            -> 只更新出戰那一格（不整排重畫）
  └─ target_changed / lost     -> 目標面板
Game.capture.capture_attempted -> 捕捉成功 / 失敗提示
Game.capture.capture_rejected  -> 不能丟球的理由
Player.switch_rejected         -> 不能切換的理由
```

`World._ready()` 呼叫 `_hud.bind_player(_player)`（Signal Up, Call Down）。
HUD **不自己去 `Game.player` 撈**——子節點的 `_ready()` 比 World 早，那時還沒人登記玩家。
而且要在 `Game.inventory.add()` 與 `acquire_pet()` **之前**接好，開局的球數與 Starter 才會顯示。

### print 改成畫面提示

`Player` 原本四處 `print` 的訊息改成訊號，中文只留在 HUD 的 `REASON_TEXT`：

| 來源 | 理由代號 | 畫面上 |
|---|---|---|
| `PetAI.command_rejected` | `invalid_target` | 那個目標不能打 |
| `CaptureSystem.capture_rejected` | `no_target` / `not_wild` / `target_dead` / `out_of_balls` | 不能丟球：… |
| `Player.switch_rejected`（新增） | `empty_slot` / `fainted` | 不能切到第 N 格：… |

**理由代號由 gameplay 端定義，翻成人話是 UI 的事**——中文不要散回那些 system 裡。

### 血條顏色共用

`scripts/utilities/hp_gradient.gd`：頭頂血條（`PetHealthBar`）與 HUD 血條（`HudHpBar`）
讀同一組綠→黃→紅。分開寫兩份會慢慢對不上，玩家會看到同一隻寵物兩條血條顏色不一樣。

### 踩到的兩個坑

1. **新增 `class_name` 之後要先 `--headless --import`**，否則跑場景會噴
   `Identifier "X" not declared`。更糟的是：**解析錯誤會讓 headless 行程永遠不結束**
   （`_ready` 的 coroutine 死掉，沒有人呼叫 `quit()`），看起來就像卡死。
2. **headless 的 viewport 只有 64×64**，HUD 一定超出畫面——
   不要用「在不在螢幕裡」當佈局測試的判準，要驗錨點關係（置中、貼邊）。

## 換寵演出（喚出 / 收回）

`scenes/fx/summon_effect.tscn`（`SummonEffect`）＋ `Pet.play_summon()` / `play_recall_and_free()`。

```
按 2
├─ 收回：球留在玩家手上 → 舊寵物被吸過去、一路縮小（0.26s）→ 球關起來
└─ 喚出：球從玩家手上飛到定點（0.3s）→ 落地開球 + 星芒 → 新寵物彈出來（0.28s）
```

**收回時球不會飛出去接怪**——球飛出去看起來像「又要抓一次」，方向感是反的。
球待在手上、怪被吸回來，才讀得出「收回來」。收回的球因此把 FX 節點放在手上，
喚出的球則放在定點。

- **球就是捕捉那顆球**：共用 `resources/fx/capture_fx_frames.tres` 與 `assets/sfx/capture/`，
  沒有新素材。玩家才會把「抓進去」和「放出來」認成同一件事的兩個方向
- 縮放進出用的是和「捕捉失敗彈出球」同一套 `TRANS_BACK`
- 時間刻意比捕捉短——換寵在戰鬥中會一直發生，拖太久會卡手感
- 開局的 Starter 走同一條路（World 生 Starter 與按數字鍵是同一個流程），所以一進遊戲就看得到

### 演出不擋 gameplay

球飛過去的 0.3 秒內，新寵物**已經存在、AI 也在跑**，只是還看不見。
這是刻意的：換寵的戰鬥時序（接手舊寵物的目標、立刻繼續打）是 `switch_test` 守著的行為，
不要為了動畫去動它。收回則相反——縮小中的舊寵物立刻關掉碰撞與 AI，不該還能打人或被打。

### 測試這種「演出」要注意

`Input.parse_input_event()` 是**排進下一幀**才處理的，tween 不一定已經走過一步。
不能在按下去的同一幀就斷定「它在縮小」，要用 `_wait_for` 等一小段。
這條讓一個正確的演出被判成失敗過。

## 下一步

Phase 1 到此收尾，接著是 `PHASE_WORLD_PROTOTYPE.md` 的 Milestone W1（World Graybox）。
