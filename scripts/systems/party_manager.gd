## 探索隊伍（規格書 §5）。
##
## 硬規則：
## - Party 上限 **5**
## - 場上同時出戰 **1**
## - **玩家必須始終能擁有至少一隻可出戰寵物**
##
## 這三條寫成 const 與擋條件，不是可調數值——不要搬進 balance resource。
class_name PartyManager
extends RefCounted

const MAX_SIZE := 5

signal party_changed()

var _members: Array[PetInstance] = []
var _active_index: int = -1

var active_index: int:
	get: return _active_index

var active: PetInstance:
	get: return _members[_active_index] if _is_valid_index(_active_index) else null


func size() -> int:
	return _members.size()


func has_space() -> bool:
	return _members.size() < MAX_SIZE


func members() -> Array[PetInstance]:
	return _members.duplicate()


func at(index: int) -> PetInstance:
	return _members[index] if _is_valid_index(index) else null


## 可出戰（沒倒下）的數量。硬規則的判準就是這個不能變成 0。
func usable_count() -> int:
	var total := 0
	for instance: PetInstance in _members:
		if not instance.is_fainted:
			total += 1
	return total


## 隊伍滿了回傳 false——呼叫端要負責把寵物留在收藏裡（規格書 §10）。
func add(instance: PetInstance) -> bool:
	if instance == null or not has_space():
		return false
	if _members.any(func(m: PetInstance) -> bool: return m.instance_id == instance.instance_id):
		return false
	_members.append(instance)
	party_changed.emit()
	# 第一隻加入時自動出戰，玩家才不會落到 0 隻在場
	if _active_index < 0 and not instance.is_fainted:
		set_active(_members.size() - 1)
	return true


## 會讓玩家沒有任何可出戰寵物的移除一律擋掉（硬規則）。
func remove_at(index: int) -> bool:
	if not _is_valid_index(index):
		return false
	var removed := _members[index]
	if not removed.is_fainted and usable_count() <= 1:
		return false

	_members.remove_at(index)
	if _members.is_empty():
		_active_index = -1
	elif index == _active_index:
		_active_index = -1
		_activate_first_usable()
	elif index < _active_index:
		_active_index -= 1
	party_changed.emit()
	return true


## 切不過去回傳 false：空格子、倒下的寵物都擋掉。
func set_active(index: int) -> bool:
	if not _is_valid_index(index) or _members[index].is_fainted:
		return false
	if _active_index == index:
		return true
	_active_index = index
	EventBus.active_pet_changed.emit(index)
	return true


## 出戰寵物倒下時呼叫。自動換上下一隻還能打的。
func on_active_fainted() -> void:
	if active != null:
		active.current_hp = 0.0
	_active_index = -1
	_activate_first_usable()
	party_changed.emit()


func to_dict() -> Dictionary:
	var ids: Array[String] = []
	for instance: PetInstance in _members:
		ids.append(String(instance.instance_id))
	return {"active_index": _active_index, "pet_instance_ids": ids}


func _activate_first_usable() -> void:
	for i in _members.size():
		if not _members[i].is_fainted:
			set_active(i)
			return


func _is_valid_index(index: int) -> bool:
	return index >= 0 and index < _members.size()
