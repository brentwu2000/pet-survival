# 主角可玩化 Prototype — 規格與現況

> **這份文件在 2026-09-13 依專案實際狀態改寫過。**
>
> 原版是照「專案從零開始」寫的，但實際進度已經超前：Milestone 1–5 全部完成，
> 捕捉 / Party / 戰鬥也已經做完並有測試。原版還引用了不存在的
> `GAME_PLAN.md`、`AGENTS.md` 與一套和現有結構不同的資料夾。
> 照原版走等於退回去重做已驗收的東西，所以改寫成「已完成的記在哪、還沒做的是什麼」。
>
> **權威順序不變**：`godot_pet_survival_game_plan_v0.1.md`（規格書）＞ `pet-survival` skill ＞ 本文件。

---

## 1. 主角正式設定

來源：**小朋友的實體積木作品**。設定圖在 `docs/references/player/player.png`。

| | |
|---|---|
| 暫名 | 黃色機器人（待小朋友命名） |
| 類型 | 探索機器生物 |
| 身高 | 約 1.2 倍頭身 |
| 性格 | 好奇、勇敢、活潑、樂於嘗試 |
| 主要能力 | 探索、指揮怪獸、捕捉、採集、建造 |
| **戰鬥方式** | **不直接攻擊**（由怪獸夥伴戰鬥） |
| 初始夥伴 | 蛋殼龍 |

外型特徵**必須保留**：

- 黃色方塊身體、矮胖比例、積木感
- **左右不對稱的眼睛**：一側灰色圓眼、一側藍色橫向機械元件
- 可大幅張開的嘴巴
- 細長機械手臂 + 大型黃色方塊拳頭

不得改成人類、一般機器人、科幻戰士或精緻機甲。

> 不對稱的眼睛是這隻角色**最好的方向線索**——`e` 和 `w` 看到的是不同的眼睛，
> 所以左右**不能互相鏡像**。這點在畫素材時要特別交代。

### 比例

設定圖：主角 1.2 頭身、蛋殼龍 0.8 頭身 → 主角約為夥伴的 1.5 倍。

實作對應（`PIXEL_SIZE = 0.025`，主角與寵物共用）：

| | 畫布內容高度 | 世界高度 |
|---|---|---|
| 主角 | 58 px | 1.45 m |
| 蛋殼龍 | 40 px | 1.00 m |

所有角色的最下方非透明像素都固定在 `y = 59`，旋轉鏡頭時才不會上下跳。

---

## 2. 主角的遊戲定位

主角負責：探索、移動、選擇目標、指揮怪獸、丟捕捉球、採集、建造。
怪獸負責主要戰鬥。

因此**永遠不要**實作：`PlayerAttack`、`PlayerWeapon`、`PlayerCombo`、`PlayerSkillTree`。
這是硬規則 1，不是本階段的限制。

---

## 3. 已完成（原版的 Milestone 1–6）

| 原 Milestone | 狀態 | 實際位置 |
|---|---|---|
| 1 Player Scene + WASD | ✅ | `scenes/player/player.tscn` / `player.gd` |
| 2 Orbit Camera（旋轉、縮放、pitch 限制） | ✅ | `scenes/player/orbit_camera.gd` |
| 3 Sprite Direction | ✅ | `scripts/utilities/sprite_direction.gd`（**主角與寵物共用**） |
| 4 Idle / Walk 切換 | ✅ | `player.gd._update_animation()`，依速度切換 |
| 5 蛋殼龍 Follow | ✅ | `scripts/ai/pet_ai.gd`（FSM 已含 CHASE / ATTACK） |
| 6 4 向 vs 8 向研究 | ✅ | **已定案 8 方向** |

原版「本階段不做」清單裡的捕捉、火焰喵戰鬥、Party 也都已完成，
見 `phase-1-progress.md`。

### 方向系統共用

原版 §11 要求「不要用不同邏輯分別計算主角與寵物方向」——這條已經落實：

```gdscript
SpriteDirection.index_for(char_forward, cam_forward, count)
```

`PlayerVisual` 與 `PetVisual` 都呼叫它，兩邊各寫一套的話轉鏡頭時會不同步，
而且很難察覺是哪裡不一致。4 / 8 方向的切換也在同一份裡。

---

## 4. 還沒做的

### 主角素材

第一輪只需要 **Idle** 與 **Walk**，各 8 方向 × 4 幀。

先不要做：`Attack`（永遠不做）、`Skill`、`Jump`、`Roll`、`Hit`、`Dead`、`Emotion`。

設定圖裡的「張嘴 / 互動」動作留到有對應玩法時再做。

素材未齊時 `PlayerVisual` 會顯示黃色膠囊頂替，不會變成隱形。

### Debug 顯示

原版 §22 要求的，還沒做：

```text
Player Position / Speed / Facing Direction / Sprite Direction
Pet Distance / Pet State / FPS
```

規格書把 Debug Metrics 排在 Phase 6，但**主角速度與寵物狀態**現在就有用——
調 follow 距離、確認方向判定都需要看到數字。

---

## 5. 驗收條件

- [x] Godot 專案正常啟動
- [x] Web Compatibility 不被破壞
- [x] 主角可 WASD 移動（相對鏡頭）
- [x] Camera 可旋轉、可 Zoom、有 pitch 上下限
- [x] 主角方向依視角正確切換
- [x] 蛋殼龍出現在世界並跟隨玩家
- [x] 蛋殼龍不會一直貼住玩家（`follow_distance` 內轉 IDLE）
- [x] 4 / 8 Direction 可以比較（已選 8）
- [x] 沒有加入玩家攻擊
- [x] 沒有新增第四隻怪獸
- [ ] **主角有正式 Idle / Walk 素材**（目前是膠囊頂替）
- [ ] 主角與蛋殼龍的比例在遊戲中目視確認過

---

## 6. 分工

原版寫「Claude 不寫程式，只做架構與 Review，由 Codex 實作」。
實際運作下來是反過來的，而且這樣比較有效：

| | 負責 |
|---|---|
| **Claude Code** | 程式、Scene、資料、測試、Web 匯出驗證、規格衝突回報 |
| **Codex** | **素材生成**——像素圖、特效、音效的程式化產生腳本 |

Codex 每次只給一個明確的素材任務，並且**限定它只能寫入哪些目錄**
（已經發生過它改到不該改的檔案的情況，所以每次都要在 brief 裡寫清楚禁止清單）。

素材交付後由 Claude 接進 Godot（建 `SpriteFrames` / 接節點 / 補測試）。

原始圖檔由使用者放在 **`docs/references/`**，Claude 負責分流。
`docs/` 有 `.gdignore`，不會被打包進 build。

---

## 7. 最重要的原則

這個專案是由國小六年級學生實作。AI 的工作是**幫學生把想法做出來**，
不是幫學生把整個專案做完。

每個 Milestone 完成後，學生應該能回答：

1. 這個功能是做什麼？
2. 我們為什麼要做它？
3. 它用了哪些條件？
4. 哪個數值改變會影響結果？
5. 我怎麼知道它成功了？
