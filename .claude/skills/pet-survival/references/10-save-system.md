# 存檔系統

規格書 §25：第一版**單存檔**。所有存檔透過 SaveManager，
**其他 Gameplay Script 不應自行到處寫 FileAccess。**
Save Data 必須有 `save_version` 方便未來 migration。

## 存檔結構（規格書 §25）

```
save_version

player
    level
    hp
    position

party
    active_index
    pet_instance_ids

pets                       ← 收藏中的所有寵物
    instance_id
    species_id
    level
    exp
    hp

base
    level
    buildings
    defender_pet_ids

world
    threat
    day_count
    world_time
    defeated_bosses
    persistent_world_state

technology
    unlocked_ids
```

**只存 Instance，不存 Data。** `species_id` 引用 `PetData`，讀檔時從 `Database` 查回來。
這樣調整寵物平衡數值不會讓舊存檔壞掉——這是 `06-data-resources.md` 那條 Data/Instance
界線的直接回報。

Phase 1 只需要 `save_version` / `player` / `party` / `pets` 四段，其餘留空但**欄位先定義好**。

## SaveManager

```gdscript
# autoload/save_manager.gd
extends Node

const SAVE_PATH := "user://save_0.json"
const SAVE_VERSION := 1

signal save_completed(success: bool)
signal load_completed(success: bool)
signal save_unavailable()          # Web 無痕模式等情況

var is_available: bool = true

func _ready() -> void:
    is_available = _probe_storage()
    if not is_available:
        push_warning("SaveManager: 儲存空間不可用（可能是瀏覽器無痕模式）")
        save_unavailable.emit()

func save_game() -> bool:
    if not is_available:
        save_unavailable.emit()
        return false

    var data := {
        "save_version": SAVE_VERSION,
        "player": Game.player_state.to_dict(),
        "party": Game.party.to_dict(),
        "pets": Game.collection.to_dict(),
        "base": Game.base_state.to_dict(),
        "world": Game.world_state.to_dict(),
        "technology": Game.tech_state.to_dict(),
    }

    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file == null:
        push_error("SaveManager: 無法開啟存檔 (%s)" % error_string(FileAccess.get_open_error()))
        save_completed.emit(false)
        return false
    file.store_string(JSON.stringify(data, "\t"))
    file.close()
    save_completed.emit(true)
    return true

func load_game() -> bool:
    if not FileAccess.file_exists(SAVE_PATH):
        load_completed.emit(false)
        return false

    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if file == null:
        push_error("SaveManager: 無法讀取存檔")
        load_completed.emit(false)
        return false
    var text := file.get_as_text()
    file.close()

    var parsed: Variant = JSON.parse_string(text)
    if not parsed is Dictionary:
        push_error("SaveManager: 存檔格式損毀")
        load_completed.emit(false)
        return false

    var data: Dictionary = parsed
    data = _migrate(data)
    if data.is_empty():
        load_completed.emit(false)
        return false

    Game.player_state.from_dict(data.get("player", {}))
    Game.collection.from_dict(data.get("pets", {}))
    Game.party.from_dict(data.get("party", {}))
    Game.base_state.from_dict(data.get("base", {}))
    Game.world_state.from_dict(data.get("world", {}))
    Game.tech_state.from_dict(data.get("tech", {}))
    load_completed.emit(true)
    return true

func has_save() -> bool:
    return FileAccess.file_exists(SAVE_PATH)

func delete_save() -> void:
    if FileAccess.file_exists(SAVE_PATH):
        DirAccess.remove_absolute(SAVE_PATH)

func _probe_storage() -> bool:
    var probe := "user://.probe"
    var f := FileAccess.open(probe, FileAccess.WRITE)
    if f == null:
        return false
    f.store_8(1)
    f.close()
    DirAccess.remove_absolute(probe)
    return true
```

## Migration

`save_version` 存在的唯一理由就是這個。**現在就把架子搭好**，之後加一個 case 即可：

```gdscript
func _migrate(data: Dictionary) -> Dictionary:
    var version: int = data.get("save_version", 0)
    if version > SAVE_VERSION:
        push_error("SaveManager: 存檔版本 %d 比遊戲版本 %d 新" % [version, SAVE_VERSION])
        return {}       # 拒絕載入，不要嘗試硬讀

    while version < SAVE_VERSION:
        match version:
            0:
                data = _migrate_0_to_1(data)
            # 1: data = _migrate_1_to_2(data)
            _:
                push_error("SaveManager: 沒有 v%d 的 migration" % version)
                return {}
        version += 1
        data["save_version"] = version
    return data

func _migrate_0_to_1(data: Dictionary) -> Dictionary:
    return data     # v0 是開發期存檔，先原樣通過
```

規則：
- **未來版本的存檔一律拒絕載入**，不要試著硬讀
- migration 是**單向遞增**，一次一版，不跳號
- 每次改動存檔結構就 `SAVE_VERSION += 1` 並補一個 `_migrate_N_to_N+1`

## Web 存檔的特殊性

官方文件（4.6 Web 匯出）：

> User-level file persistence (`user://`) requires browser support for IndexedDB cookies.
> Third-party cookies must be enabled when games run in iframes.
> Incognito/private mode prevents persistence entirely.

實務後果：

1. **無痕模式完全無法存檔。** `_probe_storage()` 就是為了提早發現，
   而不是等玩家玩兩小時後按存檔才炸。偵測到就在 UI 明確告知。
2. **iframe 內執行需要第三方 cookie。** 如果之後要嵌到別的網站（itch.io 等），這會是問題。
3. **IndexedDB 寫入是非同步的。** Godot 會處理 flush，但**不要在 `_notification(NOTIFICATION_WM_CLOSE_REQUEST)`
   裡才第一次存檔**——瀏覽器分頁關閉時不保證跑得完。改成關鍵節點自動存檔。

### 自動存檔時機

不要靠玩家手動存。建議在這些節點呼叫 `save_game()`：

- 捕捉成功後
- Party 變更後
- 進出 Dungeon
- 每個遊戲日結束（TimeManager 的 `day_changed`）
- Raid 結束
- 玩家死亡重生後

規格書 §4：玩家死亡**完全不掉東西**——存檔時機不能變成懲罰機制。

## 序列化慣例

每個可存檔的狀態物件自己實作 `to_dict()` / `from_dict()`，SaveManager 只負責組裝與檔案 I/O。

```gdscript
class_name PetInstance
extends RefCounted

func to_dict() -> Dictionary:
    return {
        "instance_id": String(instance_id),
        "species_id": String(species_id),
        "level": level,
        "exp": exp,
        "hp": current_hp,
    }

func from_dict(d: Dictionary) -> void:
    instance_id = StringName(d.get("instance_id", ""))
    species_id = StringName(d.get("species_id", ""))
    level = int(d.get("level", 1))
    exp = int(d.get("exp", 0))
    current_hp = float(d.get("hp", 0.0))
```

要點：
- `StringName` 要轉成 `String` 才能進 JSON，讀回來再轉；
  JSON 沒有 StringName 型別，直接塞會變成 `Object` 序列化失敗
- 所有 `from_dict` 用 `d.get(key, default)`，**不要用 `d[key]`**——缺欄位就當機的存檔很難救
- 數字讀回來要明確 `int()` / `float()`，JSON 一律是 float
- `Vector3` 存成 `{"x":.., "y":.., "z":..}` 或 `[x, y, z]`，不要依賴 `str2var`

## 為什麼是 JSON 而不是 `ResourceSaver`

`ResourceSaver` / `.tres` 存檔在讀取時會實例化任意類別，是已知的安全風險，
且會把 Data 與 Instance 的界線弄糊。JSON 純資料、可讀、跨版本安全，MVP 規模的效能完全足夠。

`FileAccess.open_encrypted_with_pass()` 是選項，但單機遊戲的存檔加密只是防君子；
**MVP 不做**，需要時再加。

## 檢查清單

- [ ] 只有 SaveManager 呼叫 `FileAccess`，其他 script 一律沒有
- [ ] 存檔含 `save_version`
- [ ] migration 架子已搭好，未來版本的存檔會被拒絕
- [ ] 只存 Instance，沒有存 PetData 的數值
- [ ] `_probe_storage()` 有跑，無痕模式會提早告知玩家
- [ ] 有自動存檔時機，不是只靠關閉分頁時存
- [ ] `from_dict` 全部用 `.get(key, default)`
- [ ] `StringName` 有轉 `String` 再進 JSON
- [ ] **在真實 Web build 驗證過：存檔 → 重整頁面 → 資料還在**
