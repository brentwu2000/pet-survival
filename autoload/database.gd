## 所有 *Data Resource 的集中查詢點（規格書 §21）。
##
## 唯讀——不存放任何執行期可變狀態。
## 查不到 id 一律 push_error 並回傳 null，不靜默失敗。
extends Node

var element_table: Resource = null
var capture_balance: Resource = null

var _pets: Dictionary = {}
var _skills: Dictionary = {}
var _buildings: Dictionary = {}
var _enemies: Dictionary = {}
var _items: Dictionary = {}

func _ready() -> void:
	const ELEMENT_TABLE_PATH := "res://resources/balance/element_table.tres"
	if ResourceLoader.exists(ELEMENT_TABLE_PATH):
		element_table = load(ELEMENT_TABLE_PATH)

	const CAPTURE_BALANCE_PATH := "res://resources/balance/capture_balance.tres"
	if ResourceLoader.exists(CAPTURE_BALANCE_PATH):
		capture_balance = load(CAPTURE_BALANCE_PATH)

	_pets = _load_dir("res://resources/pets/")
	_skills = _load_dir("res://resources/skills/")
	_buildings = _load_dir("res://resources/buildings/")
	_enemies = _load_dir("res://resources/enemies/")
	_items = _load_dir("res://resources/items/")

	# Phase 0 驗收：Web build 必須看得到這行，確認匯出後目錄掃描仍有效。
	print("[Database] pets=%d skills=%d buildings=%d enemies=%d items=%d" % [
		_pets.size(), _skills.size(), _buildings.size(), _enemies.size(), _items.size()])


func get_pet(id: StringName) -> Resource:
	return _lookup(_pets, id, "pet")


func get_skill(id: StringName) -> Resource:
	return _lookup(_skills, id, "skill")


func get_building(id: StringName) -> Resource:
	return _lookup(_buildings, id, "building")


func get_enemy(id: StringName) -> Resource:
	return _lookup(_enemies, id, "enemy")


func get_item(id: StringName) -> Resource:
	return _lookup(_items, id, "item")


func all_pets() -> Array:
	return _pets.values()


func _lookup(table: Dictionary, id: StringName, kind: String) -> Resource:
	var data: Resource = table.get(id)
	if data == null:
		push_error("Database: unknown %s id '%s'" % [kind, id])
	return data


## 用 ResourceLoader.list_directory 而非 DirAccess：
## 匯出後 DirAccess 看到的是 .remap / .import 過的檔案，會掃不到東西。
func _load_dir(path: String) -> Dictionary:
	var result: Dictionary = {}
	for file: String in ResourceLoader.list_directory(path):
		if not file.ends_with(".tres"):
			continue
		var res: Resource = load(path + file)
		if res == null or not "id" in res:
			push_error("Database: %s has no id field" % file)
			continue
		if res.id in result:
			push_error("Database: duplicate id '%s' in %s" % [res.id, path])
		result[res.id] = res
	return result
