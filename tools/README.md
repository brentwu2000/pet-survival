# 8 方向 Idle placeholder

這批素材用於比較「可旋轉 360° 的 3D 世界中，2D 怪獸需要 4 向還是 8 向」。
**這是 placeholder，正式素材會取代它。**

需要 Python 3.10 以上與 Pillow（已用 Python 3.12、Pillow 12.3 驗證）：

```powershell
python -m pip install pillow
python tools/gen_placeholder_sprites.py
```

可選擇一併產生方便檢查全部方向、全部幀的總覽：

```powershell
python tools/gen_placeholder_sprites.py --contact-sheet
```

總覽位於 `tools/placeholder_contact_sheet.png`，每四列為一隻怪獸，列由上至下為幀 0–3。
灰線對齊腳底；總覽背景不會寫入角色素材。腳本以自身位置定位專案，也可從其他工作目錄執行。

輸出至 `assets/pets/{eggshell_dragon,flame_cat,diving_snake}/idle_<dir>_<frame>.png`。
三隻怪獸各 8 方向 × 4 幀，共 96 張。方向依序為 `s, se, e, ne, n, nw, w, sw`：
`s` 為面向鏡頭、`n` 為背對鏡頭，`e` 朝畫面右方；`sw/w/nw` 分別鏡像 `se/e/ne`。

每張 64×64、RGBA 透明背景。在 32×32 整數網格繪製後以 NEAREST 放大，沒有抗鋸齒，
alpha 只有 0 或 255。所有方向、幀與角色的最下方非透明像素都在 y=59（由 0 起算），
呼吸僅移動上半身，腳或馬桶底部固定。4 幀為低、中、高、中，可循環播放；第 1 與 3 幀相同是刻意設計。
不使用亂數、不下載素材；相同環境重跑會覆寫同名 PNG 並產生相同結果。

| 怪獸 | 剪影與配色 | 方向線索 |
| --- | --- | --- |
| 蛋殼龍 | 寬厚奶油色蛋殼、綠色恐龍、藤葉 | 口鼻投影與雙眼／單眼／無臉、背脊與尾巴位置 |
| 火焰喵 | 小型乳白橘紅貓、尖耳、火焰尾 | 斜角口鼻與眼睛、耳距、背紋與尾巴遮擋 |
| 潛水蛇 | 固定白色淺灰馬桶（水箱、座口與底座）、藍蛇張嘴露牙、白眼、淡色腹部與淡藍水花 | 正面雙眼與座口；側面單眼、水箱在後；背面只露後腦與背脊；斜角同步轉動馬桶與蛇頭 |

配色參考 `assets/monster_concepts/` 的設定圖；腳本純程式繪製，不讀寫或依賴設定圖。
潛水蛇以馬桶為本體與固定基座，4 幀僅蛇頭上下呼吸與水花變化，馬桶本身不動。

在 Godot 中使用 NEAREST，所有 SpriteFrames 保持相同置中與 offset。
可用同一圈鏡頭軌跡比較 8 向與只保留 `s/e/n/w` 的 4 向版本，記錄突兀角度及方向切换感；
本腳本僅產生圖片，不修改 Godot 場景、資源或方向選擇邏輯。


## 捕捉特效 placeholder

需要 Python 3.10+ 與 Pillow：

```powershell
python -m pip install pillow
python tools/gen_capture_fx.py
```

執行後產生 19 張 RGBA 透明背景 PNG，以及中性灰背景總覽圖 `tools/capture_fx_contact_sheet.png`。

| 路徑 / 檔名 | 幀数 | 尺寸 | 表現 |
| --- | --- | --- | --- |
| `assets/fx/ball/ball_basic_0.png` ～ `ball_basic_3.png` | 4 | 32×32 | 紅白球 |
| `assets/fx/ball/ball_great_0.png` ～ `ball_great_3.png` | 4 | 32×32 | 藍白球、金色按鈕 |
| `assets/fx/success/success_0.png` ～ `success_5.png` | 6 | 64×64 | 暖色亮點、擴張星芒與光環、消散殘光 |
| `assets/fx/fail/fail_0.png` ～ `fail_4.png` | 5 | 64×64 | 冷色裂縫、裂球爆開、煙塵下沉消散 |

球以正 → 左傾 → 正 → 右傾循環，底部固定在 y=27（從 0 起算）；第 0、2 幀相同。成功與失敗依編號順播一次，末幀皆非空白。

球在 16×16、特效在 32×32 整數網格繪製，以 NEAREST 放大兩倍。硬邊、無抗鋸齒，alpha 僅有 0 / 255；消散透過減少像素與降低色彩亮度呈現。搖晃使用逐列整數位移，不做旋轉。

純 Python + Pillow 繪製，無下載、無亂數，同環境重跑結果一致。腳本只寫入 `assets/fx/` 與上述總覽圖。素材已接進 `resources/fx/capture_fx_frames.tres`，由 `scenes/fx/capture_effect.tscn` 播放。

## Capture SFX placeholders

Requires Python 3.10+ and only the standard library; no packages or downloads.

```powershell
python tools/gen_capture_sfx.py
```

Paths are relative to the script, so it also runs from other working directories.
It overwrites five WAVs in `assets/sfx/capture/` and `tools/capture_sfx_report.txt`.
Synthesis uses fixed-seed LCG noise and no external audio or random module.
Repeated runs in the same Python environment produce identical bytes.

| File | Duration (seconds) | Playback cue and sound |
| --- | --- | --- |
| `throw.wav` | 0.18 | Ball throw: short noise whoosh sweeping from high to low. |
| `land.wav` | 0.15 | Ball landing: low thump followed by a quieter bounce. |
| `shake.wav` | 0.10 | Each shake: dry, short midrange click, suitable for 1-3 repeats. |
| `success.wav` | 0.90 | Capture success: bright ascending C5-E5-G5-C6 major arpeggio with a short reverb tail. |
| `fail.wav` | 0.50 | Capture failure: mellow descending G3-C3 notes and soft air; disappointment rather than an error alarm. |

All files are 44100 Hz, mono, signed 16-bit PCM WAV. Each has a 2 ms fade at
both ends, zero endpoints, and peak normalization to approximately -3 dBFS.
Individual notes also have short attack/release envelopes. The script reads
back each WAV using wave and checks format, PCM bytes, nonzero RMS and no clipping.
The plain-text report lists decoded duration, sample count, peak and RMS in dBFS
(full-scale reference: 32768). This generates assets only; playback wiring is separate.


## Yellow robot player Idle / Walk placeholders

Requires Python 3.10+ and Pillow. Run from any working directory:

```powershell
python tools/gen_player_sprites.py
```

Draws on a 32x32 grid and enlarges with NEAREST. Torso layers move by integer
output pixels. No randomness, downloads or antialiasing; repeat runs are identical.

- Output: `assets/player/yellow_robot/{idle,walk}_<dir>_<frame>.png`, 64 PNGs.
- Directions: `s, se, e, ne, n, nw, w, sw`. s faces the camera, e faces right,
  n faces away, w faces left. Four frames (0-3) per action and direction.
- Playback order: 0, 1, 2, 3, repeat.
- Each image: 64x64 RGBA, transparent background, alpha only 0 or 255.
  Content height is exactly 58 px, spanning y=2 through y=59 in every frame.
- Front: gray round eye at screen left, blue beam at screen right. e shows the
  gray eye; w shows the blue beam. No image mirroring. n has no eyes or mouth;
  rear diagonals show only the edge of the side-mounted component.
- Idle: feet stay fixed, torso breathes by 1 px, arms sway gently.
- Walk: alternating strides and opposing arm swings, torso moves by 2 px.
  Frames 0/2 have both feet down; 1/3 lift alternating feet. A fixed bottom
  y=59 conflicts with both feet leaving that baseline: these are passing poses,
  not fully airborne poses. Head/studs stay fixed to preserve exact bbox height.
- Overview: `tools/player_contact_sheet.png`, neutral gray, eight direction
  columns and eight rows (Idle 0-3 followed by Walk 0-3).

The generator validates dimensions, bbox and alpha on every run. This delivery
only generates art; connecting the assets to gameplay is a separate task.

## 新增五隻怪獸：8 方向 Idle placeholder

依 `docs/codex-brief-monster-sprites.md` 與 `docs/references/monsters/` 的
最終型（Lv.36）設定圖，以 Python 3.10+ / Pillow 純程式繪製：

```powershell
python tools/gen_monster_sprites.py --contact-sheet
```

不加 `--contact-sheet` 時僅生成角色 PNG。腳本依自身位置定位專案，可從其他工作目錄執行。

| 名稱 | 輸出目錄（位於 `assets/pets/`） | 外觀與方向線索 |
| --- | --- | --- |
| 容器獸 | `container_beast/` | 白蛇盤繞藍水甕、藍白背鰭、水紋與氣泡；側面突出蛇吻，背面以背鰭遮住甕口 |
| 大地甲龍 | `earth_armor_dragon/` | 沙褐四足、兩排赭紅岩板、白色獠牙與爪；側面長吻與尾，背面岩甲與尾 |
| 風雷蝙蝠 | `storm_bat/` | 深藍身體、紫紅分色翼膜、黃眼與胸口閃電；側面壓縮翼展，背面無臉與閃電 |
| 機械小人 | `mech_kid/` | 白方頭、黑眼與一字嘴、灰軀幹、黃頸環、藍粉方塊四肢、圓盤耳機；斜面露出頭部側板，背面露面板 |
| 浮島觸手怪 | `island_tentacle/` | 草皮倒三角岩島、三根斑點長頸與單眼、浮岩；各方向改變頭頸遮擋，背面無眼 |

每隻輸出 `idle_<dir>_<frame>.png`，8 方向 × 4 幀，共 **160 張**。
方向為 `s, se, e, ne, n, nw, w, sw`；後三方向分別鏡像 `ne, e, se`。
32×32 整數網格繪製後以 NEAREST 放大至 64×64，RGBA 透明背景，alpha 僅 0 / 255。
無亂數、無下載，不讀取設定圖；水甕的透明質感以實色高光及水紋表現。

全部素材非透明範圍由 y=6 至 y=59，高度 54 px。
為同時滿足固定 bbox 與呼吸，頭頂／最高鰭／岩板尖端保持高度，
頸、身體、翼膜或草皮隨低→中→高→中伸縮，幀 1 與 3 相同。
腳底與盤蛇底部固定；蝙蝠以後足、浮島以最下方碎岩固定 y=59，不畫影子。
左右鏡像也會鏡像彩色零件，沿用此次任務的鏡像規格。

總覽為 `tools/monster_contact_sheet.png`：8 方向欄，每隻依序占 4 列（幀 0–3），
灰線標示底線，背景不寫入角色 PNG。

每次執行都驗證 160 張的格式、尺寸、alpha、底線、同角色內容高度、
底部固定、水平鏡像、三個不同呼吸姿勢及中間幀一致。
另獨立生成兩次並比對 PNG SHA-256，寫檔後讀回檢查位元與解碼內容。
已實際連跑兩次（第二次從 `tools/` 執行），160 張與總覽的 SHA-256 均一致。

素材生成腳本只負責圖片。後續已完成遊戲接線：
`resources/pets/frames/frames_<id>.tres` 為每隻提供 8 方向、4 幀、6 FPS 循環動畫，
五份 PetData 已引用各自的 SpriteFrames。
`scenes/world/world.tscn` 的 `wild_spawns` 配置種族與出生點：
容器獸在水系學校、大地甲龍與風雷蝙蝠在山區、機械小人在聚落、浮島觸手怪在草原。
未製作的動作沿用 PetVisual 的方向 Idle fallback。
`tests/monster_integration_test.tscn` 驗證實際生成、可選取、出生點可抵達與各動作八方向 fallback。
