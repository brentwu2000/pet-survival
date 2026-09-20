# World Prototype 進度

規格：`PHASE_WORLD_PROTOTYPE.md`（Milestone W1–W6）。原始地圖：
`references/world/world_map_original_v1.jpg`（照片要順時針轉 90°）。

## W1 — World Graybox：完成（2026-09-20）

驗收：`tests/world_zones_test.tscn`，全綠。

### 佈局

```
                    [山區 44×44]
                  山峰 / 礦石 / 洞窟入口
                       (0, -52)
                          │ 邊對邊相接
[火山 44×44] ──── [草原 60×60] ──── [水系學校 44×44]
  (-52, 0)          玩家起點 (0,0)         (52, 0)
                          │
                    [聚落 44×44]
                       (0, 52)
```

**四區邊對邊貼著草原**：草原半徑 30 + 區域半徑 22 = 52，中間不留空隙、沒有道路。
區塊之間不該有一條跟兩邊都不一樣的帶子（使用者回饋，見下方「調整紀錄」）。

**尺寸先做小**（使用者決定，2026-09-20）：中心→各區中心 52 公尺，
以 `Player.move_speed = 5` 計算約 **10 秒**。文件 §6 寫的是 20~40 秒——
那是一大片空灰盒，走起來只會無聊。等 W6 讓小朋友實際走過再決定要不要拉長。

### 各區內容（全部 Godot primitive）

| 區域 | 屬性 | 灰盒 | Spawn Point |
|---|---|---|---|
| 草原 | Grass | 綠地、6 棵樹、4 顆石頭 | `PlayerSpawn`、`EggshellDragonSpawn` |
| 水系學校 | Water | **四層樓校舍**（腰帶分層）、側翼、屋頂、廁所棟、操場積水、水池 | `WaterSnakeSpawn`（廁所前） |
| 火山 | Fire | 焦土、火山錐 + 山頂岩漿口 + 流到山腳的岩漿、焦黑岩石 | `FireCatSpawn` |
| 山區 | Ground | 三座山峰、洞窟入口（進不去）、礦石 | `CaveEntranceMarker` |
| 聚落 | 中立 | 五棟房子、**「你家」**（較大、顏色不同）、Base Core 預留空地 | `BaseCoreSpawn`、`HomeDoorSpawn` |

四層樓、火山、你家都是照原圖來的（見 `PHASE_WORLD_PROTOTYPE.md` §2 的判讀表）。

### 實作決定

- **原地擴充 `world.tscn`，沒有另開 `prototype_world.tscn`**（使用者決定）。
  文件 §9 寫的是新檔名，但八個測試全都載入 `world.tscn`，換檔名等於八個檔案跟著改，
  Player / HUD / Camera 的接線也要複製一份。偏離已記在這裡。
- 五區各自是 `scenes/world/zones/*.tscn`，掛在 `world.tscn` 的 `Zones` 底下。
  **不要塞進一個巨大 Scene**（文件 §9），但也不做 World Streaming。
- `.tscn` 是用產生器寫出來的（五份結構一致，不會漏掉某個 sub_resource id）。
  之後直接在編輯器裡調——這是灰盒，本來就該用眼睛擺。
- `scripts/world/zone.gd` **只有資料**（id / 名稱 / 屬性），沒有任何行為。
  進出偵測與區域名稱提示是 W3。
- 底層地板（碰撞 + NavigationMesh）放大到 220×220 蓋住整張地圖。
  區域自己的地面是**零厚度的 `PlaneMesh`**，全部貼在 `y = 0.02`——
  有厚度就會看到側面，交界會變成一塊一塊疊上去的木板。
- 大型道具（校舍、側翼、廁所、火山、山峰、洞窟口、房子、樹幹、石頭、礦石）
  都包成 `StaticBody3D`（layer 1 World / mask 0）。
  積水、水池、岩漿、Base Core 空地、樹冠**不擋**——踩得過去或在頭頂上。
  圓錐（火山 / 山峰）用圓柱碰撞近似，半徑取底部的六成，不然山腳會擋掉一大圈空氣。
  洞窟「鎖住」的做法就是它本身是一面實心牆。
- **野生寵物住在屬性對應的區域**（原本排在 W4，提前做）：
  潛水蛇 → 水系學校的廁所旁、火焰喵 → 火山區。`world.gd` 讀 Spawn Point 的節點路徑，
  不寫死座標。**「走錯邊會打不贏」這件事因此在地圖上成立**——
  蛋殼龍（Grass）往東去學校抓潛水蛇（Water）打得贏，往西遇到火焰喵（Fire）會輸。

### W1 調整紀錄（使用者實際走過之後）

上面寫的是**現在的狀態**；這裡記為什麼變成這樣，免得之後有人又改回去。

| 回饋 | 原本 | 改成 |
|---|---|---|
| 「區域交界像木板」 | 每區地面是 8 公分厚的 `BoxMesh`，看得到側面 | 零厚度 `PlaneMesh`，全部貼在 `y = 0.02` |
| 「物件要碰撞擋住」 | 純視覺，可以穿過校舍與火山 | 大型道具全部包成 `StaticBody3D` |
| 「小怪要放到對應地區」 | 兩隻都生在草原的寫死座標 | 讀各區的 Spawn Point |
| 「區塊間的奇怪連結要移除」 | 四區離草原 10 公尺，中間鋪 8 公尺寬的道路 | 四區內移到 ±52 邊對邊相接，`Roads` 整組刪掉 |

### 連帶要改的測試

小怪搬家之後，四個測試裡寫死的座標全部失效（寵物 leash 只有 20 公尺，
目標在五十公尺外就只會轉身回家）。改成**從目標的實際位置推算**，
並且把玩家與出戰寵物一起挪過去——只挪玩家的話寵物要自己跑半張地圖。

順手修掉 `capture_test` 那兩個長期失敗：**不是產品的 bug，是測試的取樣時機**。
球的拋物線是在十幾個 `_check` 之後才開始取樣的，而 `print` 到主控台每次要好幾毫秒，
加起來就吃掉了拋物線的前段，`flight[0]` 錄到的是「球已經飛到一半」。
改成**按下 Q 之後先錄軌跡再做檢查**，並且等 `attempts` 真的有東西才抓特效節點
（`Input.parse_input_event` 是排進下一幀才處理的，等一幀會抓到上一段測試留下的舊特效）。

## W2 — Navigation：完成（2026-09-20）

驗收：`tests/navigation_test.tscn`，全綠。

原本的 `NavigationRegion3D` 是一張手寫的四頂點平面網格，**它不知道任何牆**，
寵物算出來的路會穿過校舍再被碰撞擋住卡在牆邊。現在改成烤出來的網格。

### 離線烤，不在執行期烤

`tools/bake_navmesh.tscn`：

```bash
"$GODOT" --headless --path "$(pwd -W)" res://tools/bake_navmesh.tscn
```

結果存成 `resources/world/world_navmesh.res`（500 個多邊形），`world.tscn` 直接引用。
**改完地圖要重跑這支**，不然寵物還是照舊地圖走。

執行期烤一次要花時間，在 Web 上就是載入畫面多卡一下；地圖是灰盒又不會動態改變，
烤好的結果進版控就好。

### 來源幾何是「碰撞形狀」不是「Mesh」

`PARSED_GEOMETRY_STATIC_COLLIDERS`：**玩家撞得到什麼，寵物就該繞過什麼**，
兩邊用同一份資料才不會不一致。Player 與 Pet 是 `CharacterBody3D`，不會被算進去。

掃描的根節點明確指定成 World（`parse_source_geometry_data`），
不靠 `NavigationRegion3D` 自己猜——道具掛在 `Zones` 底下，不是 region 的子節點。

參數：`cell_size 0.25`、**`agent_radius 0.9`**、`agent_height 1.6`、
`agent_max_climb 0.3`、`agent_max_slope 45`。

`agent_radius` 是**寵物會不會卡牆角**的關鍵：它決定可走區域從牆面往內縮多少。
寵物的碰撞膠囊只有 0.35，但路徑如果貼著牆角切，牠就會一路磨著牆走。
這張地圖沒有窄門或走廊，路離牆遠一點只有好處。
搭配 `NavigationAgent3D.path_desired_distance` 從 0.5 調到 0.9，
讓牠早一點切到下一個路徑點，不要走到牆角才轉。

### 封閉建築的室內會留下一塊「孤島」navmesh

Recast **不會**把封閉建築的室內挖掉——四面被牆圍住的那塊多邊形確實存在，
`map_get_closest_point()` 找得到它。但從外面走不進去，這正是我們要的結果。

所以測試要驗的是**到不了**（`map_get_path` 的終點沒有落在室內），
不是「那裡不是可走區域」。第一版測試就是寫錯判準，誤判成 bug。

### 卡牆角的實測

`navigation_test` 有一條專門守這件事：寵物丟在校舍**正北**、玩家站**正南**，
中間隔著 26 × 14 的建築，唯一的路是繞過去——卡住就到不了。

## 還沒做（留給後面的 Milestone）

- 區域名稱提示（進入區域時淡出顯示）、洞窟的「之後再來探索」提示是 **W3**
- 其餘 Spawn Point（`PlayerSpawn` / `EggshellDragonSpawn` / `BaseCoreSpawn`）
  還沒接上——玩家與 Starter 目前還是照 `world.tscn` 的原始擺法出生（剛好都在草原中心）

## 下一步

W3 — Zone System：進入區域時顯示區域名稱（`Zone` 目前只有資料，沒有 Area3D）。
