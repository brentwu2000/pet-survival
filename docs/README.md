# 文件索引

| 文件 | 權威層級 | 內容 |
|------|----------|------|
| [`godot_pet_survival_game_plan_v0.1.md`](godot_pet_survival_game_plan_v0.1.md) | **1（最高）** | AI 開發規格 v0.1。§1–25 系統設計、§26 開發 Phase、§28 Script 開發順序、§30 Agent 工作規則、§32 不可違反事項 |
| [`Godot抓寵遊戲_三隻怪獸實作規劃_v1.md`](Godot抓寵遊戲_三隻怪獸實作規劃_v1.md) | 2 | Phase 1 的怪獸落地計畫：蛋殼龍 / 火焰喵 / 潛水蛇、素材製作順序、14 步實作順序、Scope Lock |
| `../.claude/skills/pet-survival/` | 2 | 規格的可執行版本：Godot 4.6 API、程式碼樣板、各系統檢查清單（11 篇） |
| [`phase-0-bootstrap.md`](phase-0-bootstrap.md) | 紀錄 | Phase 0 驗收結果、匯出/測試指令、踩過的坑 |
| [`phase-1-progress.md`](phase-1-progress.md) | 紀錄 | Phase 1 進度、資料層/Component/Pet Scene、方向系統、HUD、換寵演出、測試指令 |
| [`phase-world-progress.md`](phase-world-progress.md) | 紀錄 | World Prototype 進度：W1 五區 Graybox 的佈局、尺寸、實作決定 |
| [`PHASE_PLAYER_PROTOTYPE.md`](PHASE_PLAYER_PROTOTYPE.md) | 2 | 主角「黃色機器人」設定、比例、已完成/未完成的 Milestone、分工 |
| [`PHASE_WORLD_PROTOTYPE.md`](PHASE_WORLD_PROTOTYPE.md) | 2 | **下一階段**：Prototype World Graybox。五個區域、Milestone W1–W6、Scope Lock |
| `references/` | 素材 | 使用者放原始設定圖的地方（`monsters/`、`player/`、`world/`）。有 `.gdignore`，不進 build |
| [`codex-brief-monster-sprites.md`](codex-brief-monster-sprites.md) | 任務書 | 給 Codex 的素材 brief：設定集五隻的 8 方向 Idle、硬約束、禁止寫入清單 |
| [`external-skills.md`](external-skills.md) | 3（最低） | 外部 Godot skill 包的來源、授權、選用理由 |

衝突時一律以層級 1 為準，並回報衝突。

## 目前進度

**Phase 0 / Phase 1 已完成** → 進行中：**World Prototype**（W1 Graybox 完成，下一步 W2 Navigation）

Phase 1 完成條件（規格書 §26 + 三隻怪獸規劃 §15 v1.1）：

```text
玩家進入世界 → 蛋殼龍跟隨
→ 找到潛水蛇 → 指定攻擊 → 蛋殼龍自動戰鬥（Grass 克 Water）
→ 潛水蛇低 HP → 丟球 → 捕捉成功 → 加入 Party
→ 切換潛水蛇 → 找到火焰喵 → 指定攻擊（Water 克 Fire）
→ 火焰喵低 HP → 丟球 → 捕捉成功，火焰喵加入 Party
```

先抓潛水蛇再打火焰喵——蛋殼龍是 Grass，單挑火焰喵（Fire 克 Grass）會輸。
「探索時發現馬桶 → 靠近 → 潛水蛇出現」的特殊遭遇已移出 Phase 1。

## 兩份規劃書怎麼一起看

規格書講**整個遊戲**（含 Phase 2–6 的建造 / Raid / Web 優化）；
三隻怪獸規劃只講**現在這個 Phase** 要做的怪獸與素材。

- 要知道「這個系統該長什麼樣」→ 查規格書
- 要知道「這週該做哪一步」→ 查三隻怪獸規劃 §14 實作順序
- 要知道「現在不准碰什麼」→ 三隻怪獸規劃 §16 Scope Lock

## 已知待辦

- `capture_test` 有 **2 個既有失敗**（球的拋物線起點取樣），與 HUD 無關，待查
- 蛋殼龍的 Walk / Attack 素材還沒有（規劃書 §14 step 04–05）。方向系統**已定案 8 方向**，每個動作都要 8 套
- `index.wasm` 約 37 MB，正式部署前要處理（Phase 6）
