## 執行期的「這一隻寵物」（規格書 §6、§25）。
##
## 與 PetData 的界線是資料驅動的關鍵：
## PetData 是**種族**的固定值（不存檔，隨遊戲版本走），
## PetInstance 是**這一隻**的狀態（存檔，靠 species_id 引用回 PetData）。
## 這條線劃清楚，調平衡數值就不會弄壞舊存檔。
##
## 規格書 §6：第一版同種寵物能力固定——沒有 IV、性格、隨機天賦。
## 所以欄位只有這幾個，正好對應存檔結構。
class_name PetInstance
extends RefCounted

## 全域唯一且存檔後仍穩定——存檔用它引用 party 與 base defender。
var instance_id: StringName = &""
var species_id: StringName = &""
var level: int = 1
var exp: int = 0
var current_hp: float = 0.0

var data: PetData:
	get: return Database.get_pet(species_id)

var is_fainted: bool:
	get: return current_hp <= 0.0


static func create_from(pet_data: PetData, new_instance_id: StringName,
		lv: int = 1) -> PetInstance:
	var instance := PetInstance.new()
	instance.instance_id = new_instance_id
	instance.species_id = pet_data.id
	instance.level = lv
	instance.current_hp = pet_data.max_hp
	return instance


func to_dict() -> Dictionary:
	return {
		"instance_id": String(instance_id),
		"species_id": String(species_id),
		"level": level,
		"exp": exp,
		"hp": current_hp,
	}


static func from_dict(dict: Dictionary) -> PetInstance:
	var instance := PetInstance.new()
	instance.instance_id = StringName(dict.get("instance_id", ""))
	instance.species_id = StringName(dict.get("species_id", ""))
	instance.level = int(dict.get("level", 1))
	instance.exp = int(dict.get("exp", 0))
	instance.current_hp = float(dict.get("hp", 0.0))
	return instance
