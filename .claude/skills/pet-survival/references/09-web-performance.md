# Web 匯出與效能

規格書開發原則 8：**Web 效能是核心限制之一。**
硬規則：Web Compatibility 是必要條件。目標 **20 Friendly + 30 Enemy = 50 AI** 同屏。

## Renderer：Compatibility（已設定）

`project.godot` 現在是：

```
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
config/features=PackedStringArray("4.6", "GL Compatibility")
```

Web build 已驗證 console 印出 `OpenGL ES 3.0 (WebGL 2.0) - Compatibility`。
**不要改回 Forward+。** 官方文件（4.6 Web 匯出）明確寫著：

> Forward+/Mobile are not supported on the web platform, as these rendering methods are
> designed around modern low-level graphics APIs.
> Godot does not support WebGPU, which is a prerequisite for allowing Forward+/Mobile
> to run on the web platform.

Web 只有 **WebGL 2.0 / Compatibility** 一條路。這不是效能取捨，是**能不能跑**的問題。

改法：Project Settings → Rendering → Renderer → Rendering Method 改為 `Compatibility`，
重開編輯器。**越早改越好**——Forward+ 專屬效果（SDFGI、SSIL、Volumetric Fog）一旦用上再拔會很痛。

Compatibility 下**不可用**：SDFGI、SSAO/SSIL、SSR、Volumetric Fog、部分 GI。
照明規劃要建立在這個前提上，不要先在 Forward+ 調好畫面再說。

## Web 平台限制（規格書沒寫但會撞到）

| 限制 | 影響 | 對策 |
|------|------|------|
| 預設單執行緒 | 多執行緒匯出需 `Cross-Origin-Opener-Policy: same-origin` + `Cross-Origin-Embedder-Policy: require-corp` 兩個 header | Phase 0 先用單執行緒；要開多緒得控制得了伺服器 header |
| 音訊預設 sample-based | 不支援 audio effect bus 效果 | 音效設計不要依賴 bus effect |
| 音訊 autoplay 限制 | 首次互動前不能播聲音 | 開場要有一次玩家點擊 |
| `user://` 依賴 IndexedDB | **無痕模式完全無法存檔** | SaveManager 要能優雅失敗，見 `10` |
| 背景分頁暫停 | 遊戲被凍結 | 回到前景時的 delta 可能極大，要 clamp |
| 低階網路不可用 | 只有 HTTP / WebSocket / WebRTC | 本專案單機，暫時無影響 |
| 滑鼠捕捉需主動輸入事件 | `MOUSE_MODE_CAPTURED` 不能憑空呼叫 | OrbitCamera 在按鍵事件中呼叫，符合要求 |

## 效能預算

規格書 §19 的壓力測試目標：

```
Friendly：20
Enemy：  30
總戰鬥 AI：50
```

規格書 §19 列出效能不足時的**檢查順序**（照這個順序查，不要亂猜）：

1. Navigation 更新頻率
2. AI Tick Frequency
3. Target Search Frequency
4. Physics
5. Collision Layer
6. Animation
7. Sprite3D
8. Path Recalculation
9. 大量 Signal / Node Process
10. Spawn / Free 頻率

## 現在就要做對的事（成本為零）

這些不是優化，是**避免寫出之後改不動的東西**：

- `TargetComponent.scan_interval` 降頻 + 相位打散（已在 `03` 實作）
- 距離比較用 `distance_squared_to`
- `@onready` 快取節點，不在 `_process` 裡 `get_node`
- AI 邏輯用 `delta` 累加，**不假設固定 frame rate**——否則之後無法降頻
- 視覺放 `_process`、移動與 AI 放 `_physics_process`，別混
- Sprite3D 設定：`shaded = false`、`double_sided = false`（見 `07`）
- Collision layer 一開始就分乾淨，讓 mask 能真正縮小檢查範圍

## Phase 6 才做的優化（現在不要寫）

規格書 §19 列的手段：

### 分級 AI Tick

```gdscript
# 概念：依距離玩家的遠近決定 tick 頻率
# 近 (<15m)  每 physics frame
# 中 (<35m)  每 3 frame
# 遠 (>=35m) 每 10 frame
```

移動仍要每 frame（否則會抖），**降頻的是狀態判斷與目標搜尋**。

### 分批 Target Scan

50 隻各自 `get_tree().get_nodes_in_group()` 是 50 次全場遍歷。
改法：SpawnManager 維護一份註冊表，每 frame 只讓其中 N 隻做搜尋，輪流跑完。

### Object Pool

規格書點名 Spawn / Free 頻率。候選：捕捉球、技能特效、傷害數字、投射物。
**Pet / Enemy 本身在 MVP 規模不需要 pool**，50 隻是常駐的。

### Navigation 節流

`NavigationAgent3D` 的路徑重算是主要開銷。目標移動距離小於 `path_desired_distance` 時
不要重設 `target_position`。

## Debug Metrics（規格書 §26 Phase 6）

壓力測試前要能看到這些數字，否則優化是瞎猜：

```
FPS
Active AI 數量
Navigation updates / sec
Target scans / sec
Projectiles 數量
Damage events / sec
```

建議做成一個 `DebugOverlay` CanvasLayer，用 `Engine.get_frames_per_second()` 與各系統回報的計數器。
**Phase 6 才做**，但計數器的埋點可以在寫各系統時順手留 hook。

## 匯出檢查

Phase 0 的完成條件是**Web build 實際跑起來**，不是編輯器裡能動。每次 Phase 結束都重跑一次：

- [ ] Rendering Method = Compatibility
- [ ] 匯出範本已安裝，Web preset 建立完成
- [ ] 匯出後用 `godot --path . --export-release "Web" build/index.html` 或編輯器匯出
- [ ] **用本機 HTTP server 開啟**（直接開 `file://` 不會動）
- [ ] Console 沒有紅字
- [ ] `Database.all_pets().size()` 印出正確數量（見 `06` 的目錄掃描注意事項）
- [ ] 存檔寫入後重整頁面仍在（IndexedDB 正常）
- [ ] FPS 記錄下來，與上一個 Phase 比較

編輯器的 Web preview 與實際部署行為不同，**以實際 HTTP server 的結果為準**。

## 何時該優化

規格書 §26 Phase 6：**「優化完成後才大量增加內容。」**

反過來也成立——**Phase 1~5 不要為效能扭曲設計**。
現在的任務是把抓寵循環做對，不是讓 3 隻寵物跑到 500 FPS。

唯一例外是上面「成本為零」那一節：那些不是優化，是不要挖坑。

## 檢查清單

- [x] `project.godot` 的 renderer 已改為 Compatibility
- [ ] 沒有使用 Forward+ 專屬的渲染效果
- [ ] AI 邏輯沒有假設固定 frame rate
- [ ] 熱路徑沒有 `get_node` / `get_nodes_in_group`
- [ ] 每個 Phase 結束都跑過真實 Web build
- [ ] Phase 6 之前沒有提前寫分級 tick / object pool
