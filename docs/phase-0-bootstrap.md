# Phase 0 — Project Bootstrap 完成紀錄

規格書 §26 Phase 0 完成條件：**玩家可以在 Web Build 中使用 WASD 移動與旋轉 Camera。**

## 驗收結果

| 項目 | 狀態 |
|------|------|
| Renderer = Compatibility | ✅ 瀏覽器 console：`OpenGL ES 3.0 (WebGL 2.0) - Compatibility` |
| 資料夾結構（規格書 §20） | ✅ `autoload/ scenes/ resources/ scripts/` |
| Input Map | ✅ 16 個 action，無裸 `KEY_*` 判斷 |
| 5 個 autoload | ✅ EventBus / Database / SaveManager / TimeManager / Game |
| Test World | ✅ 60×60 地面 + DirectionalLight3D + ProceduralSky |
| Orbit Camera | ✅ 中鍵/右鍵拖曳旋轉、滾輪縮放、平滑跟隨 |
| Player WASD 相對鏡頭 | ✅ headless 注入輸入測過 7 組方向全數正確 |
| **Web Build 實際跑起來** | ✅ 本機 HTTP server，console 無紅字 |

`[Database] pets=0 …` 在 Web build 印得出來，代表匯出後 `ResourceLoader.list_directory()`
的目錄掃描機制可用（Phase 1 放入 `.tres` 後數字要跟著變，這是下一次的驗收點）。

## 建出來的東西

```
autoload/
  event_bus.gd      規格書 §21 的 9 個跨系統 signal
  database.gd       *Data Resource 集中查詢，唯讀
  save_manager.gd   存檔唯一入口；_probe_storage() 偵測無痕模式
  time_manager.gd   Day/Dusk/Night 推進（is_running 預設 false，Phase 5 才打開）
  game.gd           只持有 world / player，不實作邏輯（避免 God Object）

scenes/
  world/world.tscn    world.gd
  player/player.tscn  player.gd + orbit_camera.gd
```

Collision layer 已在 Project Settings 命名完成（1 World … 10 BuildBlocker），
**後期勿改**。Player = layer 2 / mask 1|5。

## 指令

```bash
GODOT="/c/Users/b/Downloads/Godot_v4.6.3-stable_win64.exe/Godot_v4.6.3-stable_win64_console.exe"

# 匯入 + 檢查 script 錯誤
"$GODOT" --headless --path . --import

# 直接跑（headless，看 autoload 的 print）
"$GODOT" --headless --path . --quit-after 120

# Web 匯出
"$GODOT" --headless --path . --export-release "Web" "$(pwd -W)/build/web/index.html"

# 本機測試（直接開 file:// 不會動）
cd build/web && python -m http.server 8099 --bind 127.0.0.1
```

## 這次踩到的坑（下次別再踩）

### 1. 手寫 `.tscn` 的 Node 型別 `@export` 要加 `node_paths`

`@export var target: Node3D` 在場景檔裡不能只寫 `target = NodePath("../Player")`，
node 行必須宣告：

```
[node name="OrbitCamera" type="Node3D" parent="." node_paths=PackedStringArray("target")]
target = NodePath("../Player")
```

少了它 → 屬性靜默變成 `null`，**不會有任何錯誤訊息**。
症狀：OrbitCamera 停在原點不跟隨，攝影機與地面共平面，畫面只剩天空。

### 2. `_get` 是 `Object` 的虛擬函式，不能拿來當私有 helper

```
Parse Error: The function signature doesn't match the parent.
Parent signature is "_get(StringName) -> Variant".
```

私有 helper 改名 `_lookup`。同理要避開 `_set` / `_notification` / `_init`。

### 3. Web 匯出先用單執行緒

`variant/thread_support=false`。多執行緒需要伺服器送
`Cross-Origin-Opener-Policy: same-origin` + `Cross-Origin-Embedder-Policy: require-corp`，
在控制得了 header 之前不要開。

### 4. `index.wasm` 約 37 MB

本機測試沒問題，之後要真的部署再處理壓縮（Phase 6）。

## 下一步：Phase 1

照《三隻怪獸實作規劃》§14 實作順序。目前卡在 **01–05 是美術素材**
（蛋殼龍 8 Direction Idle → Direction Test → 決定 4/8 向 → Walk → Attack），
程式端可以先用 placeholder sprite 平行推進 06–09：

```
06 共用 Pet Scene      07 PetData / SkillData / ElementTable
08 Follow AI           09 Target / Chase / Attack
```

規格書 §28 的 script 順序（`pet_data.gd` → `skill_data.gd` → `health_component.gd`
→ `target_component.gd` → `combat_component.gd` → …）與上面一致，前一支沒跑起來就不開下一支。
