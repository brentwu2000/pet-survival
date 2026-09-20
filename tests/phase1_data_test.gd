## Phase 1 資料層 headless 檢查。
##
## 用「跑一個場景」而不是 `--script`：`--script` 模式不會註冊 autoload 的全域識別字，
## 任何引用 `Database` 的 script 都會編譯失敗（症狀是 @onready 變成 null 而非明顯報錯）。
##
##   godot --headless --path <專案> res://tests/phase1_data_test.tscn
##
## 全部通過 exit 0，有失敗則 exit 為失敗數。
extends Node

## 只是為了讓下面的斷言讀起來清楚，不是產品常數。
const MIN_DAMAGE_PROBE := 1.0

var _fail := 0


func _ready() -> void:
	_check_database()
	_check_element_table()
	_check_new_pets()
	await _check_pet_setup()
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
	print("TEST %s %-36s got=%s want=%s" % ["OK  " if ok else "FAIL", label, got, want])


func _check_database() -> void:
	print("TEST --- Database ---")
	_check("all_pets().size()", Database.all_pets().size(), 8)
	_check("eggshell_dragon.display_name", Database.get_pet(&"eggshell_dragon").display_name, "蛋殼龍")
	_check("flame_cat.max_hp", Database.get_pet(&"flame_cat").max_hp, 70.0)
	_check("flame_cat.element", Database.get_pet(&"flame_cat").element, Element.Type.FIRE)
	_check("diving_snake.element", Database.get_pet(&"diving_snake").element, Element.Type.WATER)
	_check("vine_crash.power", Database.get_skill(&"vine_crash").power, 30.0)
	_check("element_table loaded", Database.element_table != null, true)


## 硬規則 5：倍率只有 1.5 / 1.0 / 0.75 三個值。
func _check_element_table() -> void:
	print("TEST --- ElementTable ---")
	var t: ElementTable = Database.element_table
	var F := Element.Type.FIRE
	var W := Element.Type.WATER
	var G := Element.Type.GRASS
	var E := Element.Type.ELECTRIC
	var D := Element.Type.GROUND
	var S := Element.Type.STEEL
	_check("Fire->Grass 克制", t.get_multiplier(F, G), 1.5)
	_check("Grass->Fire 被克", t.get_multiplier(G, F), 0.75)
	_check("Fire->Fire 同屬", t.get_multiplier(F, F), 1.0)
	_check("Water->Fire 克制", t.get_multiplier(W, F), 1.5)
	_check("Grass->Water 克制", t.get_multiplier(G, W), 1.5)
	_check("Grass->Ground 克制", t.get_multiplier(G, D), 1.5)
	_check("Ground->Fire 克制", t.get_multiplier(D, F), 1.5)
	_check("Ground->Electric 克制", t.get_multiplier(D, E), 1.5)
	_check("Electric->Water 克制", t.get_multiplier(E, W), 1.5)
	_check("Electric->Ground 被克", t.get_multiplier(E, D), 0.75)
	_check("Electric->Grass 無關", t.get_multiplier(E, G), 1.0)
	_check("Steel->Grass 克制", t.get_multiplier(S, G), 1.5)
	_check("Steel->Ground 克制", t.get_multiplier(S, D), 1.5)
	_check("Fire->Steel 克制", t.get_multiplier(F, S), 1.5)
	_check("Electric->Steel 克制", t.get_multiplier(E, S), 1.5)
	_check("Steel->Fire 被克", t.get_multiplier(S, F), 0.75)
	_check("Steel->Electric 被克", t.get_multiplier(S, E), 0.75)
	_check("Steel->Steel 同屬", t.get_multiplier(S, S), 1.0)
	_check("Steel->Water 無關", t.get_multiplier(S, W), 1.0)


func _check_pet_setup() -> void:
	print("TEST --- Pet.setup 注入 ---")
	var scene: PackedScene = load("res://scenes/pets/pet.tscn")

	# add_child 之前就 setup —— 資料要先暫存，等 _ready 才套用
	var dragon: Pet = scene.instantiate()
	dragon.setup(Database.get_pet(&"eggshell_dragon"))
	add_child(dragon)
	await get_tree().process_frame

	_check("health.max_health", dragon.health.max_health, 100.0)
	_check("combat.attack_power", dragon.combat.attack_power, 15.0)
	_check("combat.defense", dragon.combat.defense, 20.0)
	_check("attack_range (來自 bite)", dragon.combat.attack_range, 2.0)
	_check("attack_cooldown (來自 bite)", dragon.combat.attack_cooldown, 1.2)
	_check("skills.skill.id", dragon.skills.skill.id, &"vine_crash")
	_check("move_speed", dragon.move_speed, 3.5)
	_check("sprite_frames 已載入", dragon.visual.sprite.sprite_frames != null, true)

	# add_child 之後才 setup
	var cat: Pet = scene.instantiate()
	add_child(cat)
	cat.setup(Database.get_pet(&"flame_cat"))
	await get_tree().process_frame
	_check("cat.max_health", cat.health.max_health, 70.0)

	print("TEST --- 攻擊屬性與防禦屬性必須分開 ---")
	# 兩者若共用同一個欄位，防禦屬性會被普攻的屬性蓋掉。
	_check("cat 防禦屬性 = FIRE", cat.combat.element, Element.Type.FIRE)
	_check("cat 攻擊屬性 = FIRE", cat.combat.attack_element, Element.Type.FIRE)
	_check("dragon 防禦屬性 = GRASS", dragon.combat.element, Element.Type.GRASS)
	_check("dragon 攻擊屬性 = GRASS", dragon.combat.attack_element, Element.Type.GRASS)

	print("TEST --- 傷害 = power × 倍率 × 100/(100+DEF) ---")
	# 火焰喵 Fire 爪擊(18) 打 蛋殼龍(Grass 防禦, DEF 20)：18 × 1.5 × 100/120 = 22.5
	cat.combat.deal_damage(dragon, cat.combat.attack_power, cat.combat.attack_element)
	_check("18×1.5×100/120=22.5  dragon->77.5", dragon.health.current_health, 77.5)
	# 蛋殼龍 Grass 咬擊(15) 打 火焰喵(Fire 防禦, DEF 8)：15 × 0.75 × 100/108 = 10.4167
	dragon.combat.deal_damage(cat, dragon.combat.attack_power, dragon.combat.attack_element)
	_check("15×0.75×100/108=10.42  cat->59.58", cat.health.current_health, 59.5833333)
	# 遞減公式不會把傷害壓成負的，但 0 威力仍要被 MIN_DAMAGE 接住
	dragon.combat.deal_damage(cat, 0.0, dragon.combat.attack_element)
	_check("MIN_DAMAGE 夾住 ->58.58", cat.health.current_health, 58.5833333)
	# 防禦是遞減不是硬牆：高防禦仍然會被非克制屬性打到超過下限
	var before: float = dragon.health.current_health
	dragon.combat.deal_damage(dragon, 14.0, Element.Type.WATER)   # Water -> Grass 被克 0.75
	_check("高 DEF 被非克制打到 > MIN_DAMAGE",
		before - dragon.health.current_health > MIN_DAMAGE_PROBE, true)

	# Phase 1 三隻的屬性必須互不重複，否則驗收流程的克制關係會走不通。
	# 只看這三隻，不掃 all_pets()——設定集新增的怪獸允許屬性重複
	# （大地甲龍與浮島觸手怪同為地面，設定集就是這樣畫的）。
	var elements: Array = []
	for id: StringName in [&"flame_cat", &"diving_snake", &"eggshell_dragon"]:
		elements.append((Database.get_pet(id) as PetData).element)
	elements.sort()
	_check("Phase 1 三隻屬性互不重複", elements,
		[Element.Type.FIRE, Element.Type.WATER, Element.Type.GRASS])

	print("TEST --- 死亡 ---")
	cat.health.take_damage(9999.0)
	_check("is_dead", cat.health.is_dead, true)
	_check("current_health", cat.health.current_health, 0.0)
	_check("health_ratio", cat.health.health_ratio, 0.0)


## 設定集落地的五隻（`docs/references/monsters/*_設定集.png`）。
## 資料與八方向 Idle 素材必須一起載入。
func _check_new_pets() -> void:
	print("TEST --- 設定集五隻 ---")
	var expected := {
		&"container_beast": [Element.Type.WATER, "容器獸", &"water_jet", &"water_guard"],
		&"earth_armor_dragon": [Element.Type.GROUND, "大地甲龍", &"rock_charge", &"earth_quake"],
		&"storm_bat": [Element.Type.ELECTRIC, "風雷蝙蝠", &"thunder_shock", &"electro_storm"],
		&"mech_kid": [Element.Type.STEEL, "機械小人", &"metal_bash", &"assemble_shift"],
		&"island_tentacle": [Element.Type.GROUND, "浮島觸手怪", &"rock_shot", &"rock_summon"],
	}
	for id: StringName in expected:
		var want: Array = expected[id]
		var pet: PetData = Database.get_pet(id)
		_check("%s 有載入" % id, pet != null, true)
		if pet == null:
			continue
		_check("%s.element" % id, pet.element, want[0])
		_check("%s.display_name" % id, pet.display_name, want[1])
		_check("%s 普攻" % id, pet.basic_attack != null and pet.basic_attack.id == want[2], true)
		_check("%s 特殊技" % id, pet.special_skill != null and pet.special_skill.id == want[3], true)
		# 技能屬性必須跟本體一致——克制表是照攻擊屬性算的。
		_check("%s 普攻屬性一致" % id, pet.basic_attack.element, pet.element)
		_check("%s SpriteFrames" % id, pet.sprite_frames != null, true)
		if pet.sprite_frames == null:
			continue
		_check("%s 八方向" % id, pet.sprite_frames.get_animation_names().size(), 8)
		for direction: String in SpriteDirection.names_for(8):
			var animation := StringName("idle_%s" % direction)
			_check("%s/%s 四幀" % [id, animation], pet.sprite_frames.get_frame_count(animation), 4)
			_check("%s/%s 循環" % [id, animation], pet.sprite_frames.get_animation_loop(animation), true)
			for frame in 4:
				var texture := pet.sprite_frames.get_frame_texture(animation, frame)
				_check("%s/%s/%d 圖片" % [id, animation, frame],
					texture.resource_path if texture != null else "",
					"res://assets/pets/%s/idle_%s_%d.png" % [id, direction, frame])

	# 機械小人是第一隻鋼系：確認新屬性真的走得通克制表。
	var mech: PetData = Database.get_pet(&"mech_kid")
	var table: ElementTable = Database.element_table
	_check("機械小人 -> 草 克制", table.get_multiplier(mech.element, Element.Type.GRASS), 1.5)
	_check("火 -> 機械小人 克制", table.get_multiplier(Element.Type.FIRE, mech.element), 1.5)
