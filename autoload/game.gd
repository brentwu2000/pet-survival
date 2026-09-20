## Session 狀態、World 入口、高階流程（規格書 §21）。
##
## 規格書明確警告：**避免變成 God Object**。
## Game 只負責**持有**狀態物件與它們的生命週期，邏輯留在各自的 class 裡。
## 呼叫端一律寫 `Game.party.set_active(...)`、`Game.inventory.consume(...)`。
##
## 規格書 §21 只定義五個 autoload——PartyManager / Inventory / PetCollection
## 都**不是** autoload，掛在這裡。
extends Node

var party: PartyManager = null
var collection: PetCollection = null
var inventory: Inventory = null
var capture: CaptureSystem = null

## 目前的世界與玩家，由 World 場景在 _ready 時登記。
var world: Node3D = null
var player: CharacterBody3D = null

var _next_instance_index: int = 0


func _ready() -> void:
	new_session()


## 重置所有 session 狀態。讀檔與「開新遊戲」都從這裡開始。
func new_session() -> void:
	party = PartyManager.new()
	collection = PetCollection.new()
	inventory = Inventory.new()
	capture = CaptureSystem.new()
	_next_instance_index = 0


## instance_id 必須全域唯一且存檔後仍穩定（見 PetInstance）。
func next_instance_id() -> StringName:
	_next_instance_index += 1
	return StringName("pet_%d" % _next_instance_index)


## 建立一隻新寵物並放進收藏；Party 有空位就一併加入。
## 回傳是否進了 Party（規格書 §10：Party 未滿時可選擇加入）。
func acquire_pet(species_id: StringName, level: int = 1) -> PetInstance:
	var data: PetData = Database.get_pet(species_id)
	if data == null:
		return null
	var instance := PetInstance.create_from(data, next_instance_id(), level)
	collection.add(instance)
	party.add(instance)
	return instance


func register_world(world_node: Node3D, player_node: CharacterBody3D) -> void:
	world = world_node
	player = player_node
