## 玩家捕捉到的所有寵物（規格書 §10：「加入收藏」）。
##
## 收藏沒有上限；有上限的是 Party（5 隻）。
class_name PetCollection
extends RefCounted

signal pet_added(instance: PetInstance)

var _pets: Dictionary = {}   ## StringName -> PetInstance


func add(instance: PetInstance) -> void:
	if instance == null or instance.instance_id.is_empty():
		push_error("PetCollection.add: instance 無效")
		return
	if _pets.has(instance.instance_id):
		push_error("PetCollection.add: instance_id 重複 '%s'" % instance.instance_id)
		return
	_pets[instance.instance_id] = instance
	pet_added.emit(instance)


func get_pet(instance_id: StringName) -> PetInstance:
	var instance: PetInstance = _pets.get(instance_id)
	if instance == null:
		push_error("PetCollection: unknown instance_id '%s'" % instance_id)
	return instance


func all() -> Array[PetInstance]:
	var out: Array[PetInstance] = []
	for instance: PetInstance in _pets.values():
		out.append(instance)
	return out


func size() -> int:
	return _pets.size()
