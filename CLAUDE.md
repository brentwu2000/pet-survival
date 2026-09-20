# Pet Survival

Godot 4.6 抓寵 × 生存建造 × 基地防守。2.5D（3D 世界 + Sprite3D 角色），GDScript，Web 優先。

## 開始工作前

1. 讀 `docs/godot_pet_survival_game_plan_v0.1.md`——這是**權威規格**，規格書 §30 第 1 條就是「先閱讀本文件」
2. 使用 `pet-survival` skill（`.claude/skills/pet-survival/`）——規格的可執行版本：
   Godot 4.6 具體 API、程式碼樣板、各系統檢查清單
3. 衝突時以規格書為準，並回報衝突

外部參考 skill（`godomaster` 中文通用查詢、`godot-composition` / `godot-state-machine-advanced` /
`godot-resource-data-patterns` / `godot-rpg-stats` / `godot-combat-system` / `godot-ability-system` /
`godot-navigation-pathfinding` / `godot-camera-systems` / `godot-input-handling` /
`godot-signal-architecture` / `godot-autoload-architecture` / `godot-gdscript-mastery` /
`godot-platform-web` / `godot-performance-optimization`）只是 Godot 4.x 通用作法，
**權威低於規格書與 `pet-survival` skill**，不得用來覆寫下方「絕不可違反」。來源與清單見 `docs/external-skills.md`。

## 絕不可違反

- **玩家不直接攻擊**——沒有普攻 / 武器 / 裝備。玩家的角色是「指揮寵物」
- 探索 Party 上限 **5**，同時出戰 **1**
- 捕捉必須先靠寵物戰鬥削弱目標；失敗消耗球、目標不消失、戰鬥繼續
- 克制倍率 1.5 / 1.0 / 0.75，且**必須資料化**（禁止 `if element == ...`）
- **無 Hunger / Thirst / Sleep**
- 世界只有一個基地；玩家死亡完全不掉東西
- Web Compatibility renderer 是必要條件

## 工作方式

- **不擴大 Scope。** 只做當前 Phase。目前是 **Phase 0 → Phase 1（Catching Vertical Slice）**
- 不為「未來可能需要」建立抽象
- 新增寵物 / 技能 / 建築 = 新增 `.tres`，不動核心程式
- 共用能力走 Component（Pet 與 Enemy 共用 Health / Combat / Skill / Target），但不要 ECS 化
- 改既有 API 前先 grep 所有引用
- 每個 Milestone 先確認**可執行**再往下

## 現況

**Phase 0 已完成並驗收**（Web build 實跑過，見 `docs/phase-0-bootstrap.md`）：
renderer 已改為 Compatibility、資料夾與 Input Map 建立、5 個 autoload 就緒、
Test World + Orbit Camera + Player WASD 可動。

進行中：**Phase 1（Catching Vertical Slice）**。實作順序見
`docs/Godot抓寵遊戲_三隻怪獸實作規劃_v1.md` §14 與規格書 §28，進度見 `docs/phase-1-progress.md`。
已完成資料層、四個 Component、共用 Pet Scene、PetAI FSM、滑鼠指揮、
以及 Party / Inventory / PetCollection 狀態容器。
捕捉系統（§10）、切換出戰寵物（§14 step 14）、Basic HUD 已完成，驗收流程定案為
「蛋殼龍抓潛水蛇 → 切換潛水蛇 → 打火焰喵並捕捉」（規劃書 §15 v1.1，馬桶特殊遭遇移出 Phase 1）。
方向系統**定案 8 方向**，正式素材每個動作都要 8 套。

進行中：**World Prototype**（`docs/PHASE_WORLD_PROTOTYPE.md`，進度見 `docs/phase-world-progress.md`）。
**W1 Graybox / W2 Navigation 已完成**——五區直接擴充在 `world.tscn` 的 `Zones` 底下，
沒有另開 scene；navmesh 離線烤成 `resources/world/world_navmesh.res`。
下一步是 W3（區域名稱提示）。
小朋友的手繪世界地圖在 `docs/references/world/world_map_original_v1.jpg`——
**照片要順時針轉 90°** 才是正確方向。

`PartyManager` / `Inventory` / `PetCollection` **不是 autoload**——由 `Game` 持有，
呼叫端寫 `Game.party.…`。規格書 §21 只定義五個 autoload，不要再發明新的。

## 原始設定圖

使用者把所有原始圖檔放在 **`docs/references/`**（`monsters/`、`player/`），由我分流到該去的地方。

改怪獸或主角的名稱 / 技能 / 外觀前，**先看設定圖**——那是小朋友的原始設計，
是命名與外觀的依據（例如潛水蛇的本體是馬桶，不是只有蛇）。

`docs/` 有 `.gdignore`，Godot 不會掃描也不會打包。
**參考資料不要放進 `assets/`**——設定圖曾經佔掉整個 build 的 86%（1.95 MB / 2.27 MB），
而且沒有任何程式引用它們。`assets/` 只放真正會在執行期載入的素材。

改動 `.gd` / `.tres` / `.tscn` 後跑：

```bash
GODOT="/c/Users/b/Downloads/Godot_v4.6.3-stable_win64.exe/Godot_v4.6.3-stable_win64_console.exe"
# 新增 class_name 之後一定要先 import，否則會噴 Identifier not declared
"$GODOT" --headless --import --path "$(pwd -W)"
"$GODOT" --headless --path "$(pwd -W)" res://tests/phase1_data_test.tscn
"$GODOT" --headless --path "$(pwd -W)" res://tests/direction_test.tscn
"$GODOT" --headless --path "$(pwd -W)" res://tests/pet_ai_test.tscn
"$GODOT" --headless --path "$(pwd -W)" res://tests/party_inventory_test.tscn
"$GODOT" --headless --path "$(pwd -W)" res://tests/capture_test.tscn
"$GODOT" --headless --path "$(pwd -W)" res://tests/switch_test.tscn
"$GODOT" --headless --path "$(pwd -W)" res://tests/hud_test.tscn
"$GODOT" --headless --path "$(pwd -W)" res://tests/world_zones_test.tscn
"$GODOT" --headless --path "$(pwd -W)" res://tests/navigation_test.tscn
```

**改動地圖（`scenes/world/zones/` 或 `world.tscn` 的道具）後要重烤 navmesh**，
不然寵物還是照舊地圖找路：

```bash
"$GODOT" --headless --path "$(pwd -W)" res://tools/bake_navmesh.tscn
```

測試一律用「跑一個場景」，**不要用 `--script`**（不註冊 autoload 全域識別字，會讓行程卡死）。

**解析錯誤也會讓 headless 行程永遠不結束**——`_ready()` 的 coroutine 死掉就沒人呼叫 `quit()`。
跑測試時輸出不要接 pipe（會被緩衝看不到錯誤），導到檔案再看，並用 `timeout` 保護。

驗證 Web build 時：匯出後要 **Ctrl+Shift+R 硬重新整理**（Chrome 會快取 `index.pck`），
而且**視窗必須在前景**——隱藏分頁的 rAF 被節流到接近零，遊戲會慢到看起來像壞掉。
