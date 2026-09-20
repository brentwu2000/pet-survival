# 外部 Skill 資源（來源與使用規則）

> 權威順序：`godot_pet_survival_game_plan_v0.1.md`（本資料夾）（規格書）＞ `pet-survival` skill ＞ 本頁列出的外部 skill。
> 外部 skill 只是 **Godot 4.x 通用參考**，不得覆寫規格書的「絕不可違反」條款
> （玩家不直接攻擊、Party 上限 5 / 出戰 1、克制倍率必須資料化、無 Hunger/Thirst/Sleep、單一基地、Compatibility renderer）。

## 來源

| 來源 | 授權 | 安裝內容 |
|------|------|----------|
| [Aetik-yue/GodoMaster](https://github.com/Aetik-yue/GodoMaster) | MIT | `godomaster`（1 個 skill，21 篇中文參考） |
| [thedivergentai/gd-agentic-skills](https://github.com/thedivergentai/gd-agentic-skills) | LGPL-3.0（見 `.claude/skills/LICENSE-gd-agentic-skills.txt`） | 99 個中選 14 個 |

兩者皆為 Claude Code skill 包，安裝位置：`.claude/skills/`。
`.claude/.gdignore` 已加入，避免 Godot 把 skill 內的 `.gd` 範例當成專案腳本掃描。

## 已安裝：godomaster（中文，涵蓋面廣）

21 篇參考：專案設定 / 編輯器 / GDScript / 節點場景 / 2D / 3D / 物理 / 動畫 / UI / 音訊 /
輸入 / 匯出 / 效能 / 檔案 IO / Shader / 網路 / 測試 / 架構工具 / 在地化 / AI 行為 / 資產管線。
當作「快速查 API 與慣例」用。

## 已安裝：gd-agentic-skills 精選 14 個

對應 Phase 0 → Phase 1（Catching Vertical Slice）實際會碰到的系統：

| Skill | 對應規格系統 |
|-------|--------------|
| `godot-composition` | Component 模式（Pet / Enemy 共用 Health / Combat / Skill / Target）；附 `health_component.gd`、`hit_box_component.gd` 等範例 |
| `godot-state-machine-advanced` | Pet AI FSM（skill ref `04-pet-ai-fsm.md`） |
| `godot-resource-data-patterns` | `.tres` 資料化（新增寵物 / 技能 / 建築不動核心程式） |
| `godot-rpg-stats` | 屬性、克制倍率資料化、傷害公式 |
| `godot-combat-system` | Hitbox / Hurtbox、DamageData、傷害計算 |
| `godot-ability-system` | 技能、冷卻 |
| `godot-navigation-pathfinding` | 寵物跟隨 / 追敵（NavigationAgent3D） |
| `godot-camera-systems` | 2.5D 相機 |
| `godot-input-handling` | InputMap、指令輸入 |
| `godot-signal-architecture` | Signal Up / Call Down |
| `godot-autoload-architecture` | Autoload 單例與初始化順序 |
| `godot-gdscript-mastery` | GDScript 4.x 靜態型別、`@onready`、`await` 等地雷 |
| `godot-platform-web` | **Web 優先**：Compatibility / WebGL 2.0、JavaScriptBridge、localStorage、體積優化 |
| `godot-performance-optimization` | Profiler、物件池、DrawCall |

### 刻意未安裝（需要時再抓）

避免 skill 清單膨脹，以下等到對應 Phase 再裝：

`godot-genre-survival`、`godot-genre-tower-defense`（基地防守 / Raid）、`godot-inventory-system`、
`godot-save-load-systems`、`godot-3d-world-building`（GridMap 建造）、`godot-export-builds`、
`godot-testing-patterns`、`godot-physics-3d`、`godot-scene-management`、`godot-project-foundations`、
`godot-particles`、`godot-tweening`、`godot-ui-theming`、`godot-monte-carlo-balancer`（數值平衡）、
`godot-debugging-profiling`、`godot-master`（9 MB 全集合，不建議）。

補裝方式：

```bash
git clone --depth 1 https://github.com/thedivergentai/gd-agentic-skills.git
cp -r gd-agentic-skills/skills/<skill-name> .claude/skills/
```
