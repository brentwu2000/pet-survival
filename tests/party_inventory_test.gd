## Step A 檢查：資料型別與狀態容器（Inventory / PetCollection / PartyManager）。
##
##   godot --headless --path <專案> res://tests/party_inventory_test.tscn
extends Node

var _fail := 0


func _ready() -> void:
	_check_database()
	_check_inventory()
	_check_instance()
	_check_collection()
	_check_party()
	await _check_world_wiring()
	print("TEST ===== %s (%d failures) =====" % ["ALL PASS" if _fail == 0 else "FAILED", _fail])
	get_tree().quit(_fail)


func _check(label: String, got: Variant, want: Variant) -> void:
	var ok: bool = false
	if typeof(got) == TYPE_FLOAT and typeof(want) == TYPE_FLOAT:
		ok = is_equal_approx(got, want)
	else:
		ok = got == want
	if not ok:
		_fail += 1
	print("TEST %s %-38s got=%s want=%s" % ["OK  " if ok else "FAIL", label, got, want])


func _check_database() -> void:
	print("TEST --- Database ---")
	_check("capture_balance 載入", Database.capture_balance != null, true)
	_check("ball_basic.power", Database.get_item(&"ball_basic").power, 1.0)
	_check("ball_great.power", Database.get_item(&"ball_great").power, 1.5)
	var balance: CaptureBalance = Database.capture_balance
	_check("滿血 hp_modifier", balance.hp_modifier(1.0), 0.3)
	_check("殘血 hp_modifier", balance.hp_modifier(0.0), 1.0)
	_check("hp_modifier 單調遞減", balance.hp_modifier(0.2) > balance.hp_modifier(0.8), true)
	_check("難抓的 rarity_modifier 較低",
		balance.rarity_modifier(0.6) < balance.rarity_modifier(0.1), true)


func _check_inventory() -> void:
	print("TEST --- Inventory ---")
	var inventory := Inventory.new()
	_check("初始數量 0", inventory.count(&"ball_basic"), 0)
	inventory.add(&"ball_basic", 3)
	_check("add 之後", inventory.count(&"ball_basic"), 3)
	_check("consume 成功", inventory.consume(&"ball_basic"), true)
	_check("consume 後剩 2", inventory.count(&"ball_basic"), 2)
	_check("數量不足時 consume 失敗", inventory.consume(&"ball_basic", 5), false)
	_check("失敗時不會扣", inventory.count(&"ball_basic"), 2)


func _check_instance() -> void:
	print("TEST --- PetInstance ---")
	var data: PetData = Database.get_pet(&"eggshell_dragon")
	var instance := PetInstance.create_from(data, &"pet_1")
	_check("species_id", instance.species_id, &"eggshell_dragon")
	_check("初始滿血", instance.current_hp, data.max_hp)
	_check("沒倒下", instance.is_fainted, false)
	_check("data getter 查得回種族資料", instance.data.display_name, "蛋殼龍")
	instance.current_hp = 0.0
	_check("HP 0 = 倒下", instance.is_fainted, true)

	var restored := PetInstance.from_dict(instance.to_dict())
	_check("存檔往返 instance_id", restored.instance_id, instance.instance_id)
	_check("存檔往返 hp", restored.current_hp, instance.current_hp)


func _check_collection() -> void:
	print("TEST --- PetCollection ---")
	var collection := PetCollection.new()
	var data: PetData = Database.get_pet(&"flame_cat")
	collection.add(PetInstance.create_from(data, &"a"))
	collection.add(PetInstance.create_from(data, &"b"))
	_check("size", collection.size(), 2)
	_check("查得回來", collection.get_pet(&"a").species_id, &"flame_cat")


func _check_party() -> void:
	print("TEST --- PartyManager（硬規則）---")
	var party := PartyManager.new()
	var data: PetData = Database.get_pet(&"flame_cat")

	var changed: Array[int] = []
	EventBus.active_pet_changed.connect(func(slot: int) -> void: changed.append(slot))

	var made: Array[PetInstance] = []
	for i in 6:
		made.append(PetInstance.create_from(data, StringName("p%d" % i)))

	_check("第 1 隻加入成功", party.add(made[0]), true)
	_check("第 1 隻自動出戰", party.active_index, 0)
	_check("EventBus.active_pet_changed 有發", changed, [0] as Array[int])

	for i in range(1, 5):
		party.add(made[i])
	_check("Party 上限 5", party.size(), 5)
	_check("第 6 隻加不進去", party.add(made[5]), false)
	_check("加不進去之後還是 5", party.size(), 5)

	_check("切到 slot 2", party.set_active(2), true)
	_check("active_index", party.active_index, 2)
	_check("切到不存在的 slot 失敗", party.set_active(9), false)

	made[3].current_hp = 0.0
	_check("切到倒下的寵物失敗", party.set_active(3), false)
	_check("倒下的可以被移出", party.remove_at(3), true)
	_check("移出後剩 4", party.size(), 4)

	# 只剩一隻能打時，不可以把牠移掉（硬規則：玩家必須始終有可出戰寵物）
	var solo := PartyManager.new()
	var only := PetInstance.create_from(data, &"only")
	solo.add(only)
	_check("最後一隻不能被移除", solo.remove_at(0), false)
	_check("仍然有 1 隻", solo.size(), 1)
	_check("usable_count", solo.usable_count(), 1)

	# 出戰寵物倒下 -> 自動換上下一隻
	var pair := PartyManager.new()
	var first := PetInstance.create_from(data, &"f")
	var second := PetInstance.create_from(data, &"s")
	pair.add(first)
	pair.add(second)
	_check("出戰的是第一隻", pair.active_index, 0)
	pair.on_active_fainted()
	_check("倒下後自動換到第二隻", pair.active_index, 1)
	_check("倒下的那隻 is_fainted", first.is_fainted, true)


func _check_world_wiring() -> void:
	print("TEST --- World 開局 ---")
	var world: Node3D = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	await get_tree().physics_frame

	_check("開局有捕捉球", Game.inventory.count(&"ball_basic"), 10)
	_check("Starter 在收藏裡", Game.collection.size(), 1)
	_check("Starter 在 Party 裡", Game.party.size(), 1)
	_check("Starter 就是出戰中", Game.party.active.species_id, &"eggshell_dragon")
	_check("場上的 Pet 綁到同一個 instance",
		world.starter.instance, Game.party.active)
	_check("Party 還有空位", Game.party.has_space(), true)
