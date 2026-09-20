# Codex 素材任務：設定集五隻的 8 方向 Idle

> 分工依 `docs/PHASE_PLAYER_PROTOTYPE.md` §6：Codex 負責素材的**程式化生成腳本**，
> 接進 Godot（`SpriteFrames` / 節點 / 測試）由 Claude Code 另外處理。
> 這份 brief 只有一個任務，請不要順手做第二件事。

## 先讀

- `CLAUDE.md`
- `tools/README.md`——既有素材的尺寸與對齊規範，這次必須完全沿用
- `tools/gen_placeholder_sprites.py`——Phase 1 三隻的生成腳本，作為寫法範本
- `docs/references/monsters/*_設定集.png`——五隻的配色與剪影依據（人看，腳本不讀）

## 產出

新檔 `tools/gen_monster_sprites.py`，產生 **5 隻 × 8 方向 × 4 幀 = 160 張** PNG：

```
assets/pets/container_beast/idle_<dir>_<frame>.png
assets/pets/earth_armor_dragon/idle_<dir>_<frame>.png
assets/pets/storm_bat/idle_<dir>_<frame>.png
assets/pets/mech_kid/idle_<dir>_<frame>.png
assets/pets/island_tentacle/idle_<dir>_<frame>.png
```

**這次只做 idle**，不做 walk / attack / skill / death——跟現有三隻的進度一致。

附 `--contact-sheet` 選項，輸出 `tools/monster_contact_sheet.png`（只進 `tools/`，不進 `assets/`）。

## 硬約束（與既有素材完全一致，不得放寬）

1. 在 **32×32 整數網格**上繪製，再以 `Image.Resampling.NEAREST` 放大到 **64×64**。
2. RGBA 透明背景，**alpha 只有 0 或 255**，無抗鋸齒。
3. 每張圖**最下方的非透明像素固定在 y=59**（由 0 起算）。所有方向、所有幀、所有角色都一樣。
4. 方向順序 `s, se, e, ne, n, nw, w, sw`。`s` 面向鏡頭、`n` 背對、`e` 朝畫面右方；
   `sw / w / nw` 由 `se / e / ne` 水平鏡像產生。
5. 4 幀呼吸為 低→中→高→中（既有腳本用 `breath = (1, 0, -1, 0)[frame]`），
   幀 1 與幀 3 相同是刻意的，0→1→2→3→0 可無縫循環。
6. 呼吸只動上半身，**接地部位固定不動**。
7. 不使用亂數、不下載任何素材、不讀取設定圖。相同環境重跑必須產生位元相同的檔案。
8. Python 3.10+ 與 Pillow，與既有腳本相同。

## 五隻的外觀

配色與剪影以 `docs/references/monsters/<名稱>_設定集.png` 的**最終型**（Lv.36）為準，
不要畫初始型或成長型。三視圖那一列是主要參考。

| id | 名稱 | 剪影與配色 | 方向線索 |
|---|---|---|---|
| `container_beast` | 容器獸 | 白色蛇身盤繞一只藍色半透明水甕，背脊一排藍白尖鰭，甕內有水與氣泡 | 甕口朝向、蛇頭轉向；背面只見蛇背與鰭，甕口不可見 |
| `earth_armor_dragon` | 大地甲龍 | 沙褐色厚重四足獸，低伏；背上兩排橘紅赭色尖銳岩板，白色獠牙與腳爪 | 岩板排列透視、頭部朝向；背面只見岩板與尾 |
| `storm_bat` | 風雷蝙蝠 | 深藍黑小蝙蝠，紫紅漸層翼膜，胸口黃色閃電紋，黃色大眼與大耳 | 翼展形狀、閃電紋是否可見、耳朵角度；背面無臉、無閃電紋 |
| `mech_kid` | 機械小人 | 白色方頭（兩點黑眼＋一字嘴）、灰色軀幹、黃色頸環、藍與粉紅方塊組成的四肢、側面耳機狀圓盤 | 臉、耳機圓盤、彩色方塊的左右位置；背面無臉，只見背部面板 |
| `island_tentacle` | 浮島觸手怪 | 漂浮的倒三角岩島，頂面草皮，三根褐色帶深色斑點的長頸自草皮伸出，各有一隻圓眼；島底有碎岩繞行 | 三頭的朝向與前後遮擋、草皮邊緣透視；背面三頭朝外、不見眼睛 |

## 浮空生物怎麼處理 baseline

`storm_bat` 與 `island_tentacle` 在設定上是浮空的，但**第 3 條約束不放寬**——
bbox 不一致會讓牠們在 Godot 裡上下跳動。做法：

- `storm_bat`：讓**後足或尾端**落在 y=59，翼與身體在上方浮動。
- `island_tentacle`：讓**島底最下緣的碎岩**落在 y=59，島體與三頭在上方浮動。

不要畫影子——3D 世界自己有光影，2D 影子會打架。

## 禁止寫入

只能新增 / 修改這些路徑：

```
tools/gen_monster_sprites.py
tools/monster_contact_sheet.png
tools/README.md                      （追加本次說明，保留既有內容）
assets/pets/container_beast/
assets/pets/earth_armor_dragon/
assets/pets/storm_bat/
assets/pets/mech_kid/
assets/pets/island_tentacle/
```

**其他一律不准碰**，尤其是：

- `tools/gen_placeholder_sprites.py`、`tools/gen_player_sprites.py`、`tools/gen_capture_*.py`
  ——既有素材重跑必須維持一致，改了會污染 Phase 1 三隻
- `assets/pets/{eggshell_dragon,flame_cat,diving_snake}/`、`assets/player/`、`assets/fx/`、`assets/sfx/`
- 任何 `.gd` / `.tres` / `.tscn` / `.godot/`——接進遊戲是另一個任務
- `docs/`（本檔除外，也不需要改本檔）

## 自我檢查（請在腳本裡驗，每次執行都跑）

- [ ] 160 張全部存在，尺寸都是 64×64
- [ ] 每張的 alpha 值只有 `{0, 255}`
- [ ] 每張最下方非透明像素的 y 座標 == 59
- [ ] 同一隻的 8 方向 × 4 幀，內容高度一致（bbox 高度相同）
- [ ] `sw / w / nw` 確實是 `se / e / ne` 的水平鏡像
- [ ] 連續執行兩次，所有輸出檔的雜湊相同

## 回報

完成後請回報：腳本路徑、產出張數、contact sheet 路徑、自我檢查結果，
以及任何你為了滿足約束而做的取捨（例如浮空生物的接地部位選了哪裡）。
