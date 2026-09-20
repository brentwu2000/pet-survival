## 所有存檔讀寫的唯一入口（規格書 §25）。
##
## 其他 gameplay script 不得自行呼叫 FileAccess。
## Phase 0 只驗證儲存空間可用性——Web 無痕模式下 user:// 的 IndexedDB 會失效，
## 必須優雅失敗而不是崩潰。實際的存檔結構在 Phase 1 隨 Party / Collection 一起長出來。
extends Node

const SAVE_PATH := "user://save_0.json"
const SAVE_VERSION := 1

signal save_completed(success: bool)
signal load_completed(success: bool)
signal save_unavailable()

var is_available: bool = true


func _ready() -> void:
	is_available = _probe_storage()
	if not is_available:
		push_warning("SaveManager: 儲存空間不可用（可能是瀏覽器無痕模式）")
		save_unavailable.emit()
	print("[SaveManager] storage available=%s" % is_available)


func has_save() -> bool:
	return is_available and FileAccess.file_exists(SAVE_PATH)


## 寫一個探針檔確認 user:// 真的可寫。
## Web 平台上 FileAccess.open 可能成功但 IndexedDB flush 失敗，所以要實際寫入再讀回。
func _probe_storage() -> bool:
	const PROBE_PATH := "user://.storage_probe"
	var writer := FileAccess.open(PROBE_PATH, FileAccess.WRITE)
	if writer == null:
		return false
	writer.store_string("ok")
	writer.close()

	var reader := FileAccess.open(PROBE_PATH, FileAccess.READ)
	if reader == null:
		return false
	var content := reader.get_as_text()
	reader.close()

	DirAccess.remove_absolute(PROBE_PATH)
	return content == "ok"
