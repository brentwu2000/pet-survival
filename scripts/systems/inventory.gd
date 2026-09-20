## 玩家持有的物品數量。Phase 1 只有捕捉球。
##
## 規格書 §21 只定義五個 autoload，**這個不是 autoload**——由 Game 持有。
## 呼叫端一律寫 `Game.inventory.consume(...)`。
class_name Inventory
extends RefCounted

signal count_changed(item_id: StringName, count: int)

var _counts: Dictionary = {}


func count(item_id: StringName) -> int:
	return _counts.get(item_id, 0)


func add(item_id: StringName, amount: int = 1) -> void:
	if amount <= 0:
		return
	_counts[item_id] = count(item_id) + amount
	count_changed.emit(item_id, _counts[item_id])


## 數量不足時回傳 false 且**不扣**——呼叫端要靠回傳值決定能不能繼續。
func consume(item_id: StringName, amount: int = 1) -> bool:
	if amount <= 0 or count(item_id) < amount:
		return false
	_counts[item_id] = count(item_id) - amount
	count_changed.emit(item_id, _counts[item_id])
	return true


func to_dict() -> Dictionary:
	var out: Dictionary = {}
	for key: StringName in _counts:
		out[String(key)] = _counts[key]
	return out


func from_dict(dict: Dictionary) -> void:
	_counts.clear()
	for key: String in dict:
		_counts[StringName(key)] = int(dict[key])
