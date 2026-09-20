## 捕捉（規格書 §10）。**最高優先的 Gameplay System。**
##
## 硬規則：
## 1. 必須**先透過寵物戰鬥削弱目標**——滿血時成功率很低（由 hp_modifier 保證）
## 2. 失敗：**球消耗、目標不消失、戰鬥繼續**
## 3. 普通情況**不要輕易達到 100%**
##
## 不是 autoload（規格書 §21 只有五個）——由 Game 持有，呼叫端寫 `Game.capture.…`。
class_name CaptureSystem
extends RefCounted

## 普通球永遠打不到 100%（硬規則 3）。這是規則不是數值，所以是 const 不進 balance。
const MAX_RATE := 0.95

## --- 演出節奏 ---
## 判定早就算完了，這段只決定「演多久」。球的動畫與怪獸的縮放都讀同一組常數，
## 所以兩邊一定同步——分開寫兩份就會慢慢對不上。
## 球從玩家手上飛到目標的時間。
## 規格書 §26 說 Phase 1 不做球的飛行——那是為了不讓球的物理卡住捕捉流程的驗收。
## 驗收已經走通了，現在補上拋物線只是加回饋，不影響任何判定。
const THROW_SECONDS := 0.34
const ABSORB_SECONDS := 0.35
const SHAKE_SECONDS := 0.45
const MIN_SHAKES := 1
const MAX_SHAKES := 3

## 判定結果。UI 要靠 rate 顯示「這一球有幾成把握」。
signal capture_attempted(target: Pet, ball: BallData, success: bool, rate: float)
signal capture_rejected(reason: StringName)


## capture_rate = ball_power × hp_modifier × rarity_modifier（規格書 §10）
##
## 形狀不可改（HP 越低越容易、稀有度越高越難、有上限）；
## 數值全部來自 BallData 與 CaptureBalance，這裡不得出現 hard-code 的平衡值。
static func calculate_rate(target: Pet, ball: BallData) -> float:
	if target == null or ball == null:
		return 0.0
	var balance: CaptureBalance = Database.capture_balance
	if balance == null or target.data == null:
		return 0.0
	if ball.guaranteed:
		return 1.0

	var rate := (ball.power
		* balance.hp_modifier(target.health.health_ratio)
		* balance.rarity_modifier(target.data.capture_difficulty))
	return clampf(rate, 0.0, MAX_RATE)


## 搖幾下。成功一律搖滿；失敗時**成功率越高搖越多**，演出「就差一點」。
## 這是純表現，不影響結果——結果在呼叫這支之前就已經決定了。
static func shake_count(success: bool, rate: float) -> int:
	if success:
		return MAX_SHAKES
	return clampi(int(roundf(rate * MAX_SHAKES)), MIN_SHAKES, MAX_SHAKES)


static func sequence_seconds(shakes: int) -> float:
	return THROW_SECONDS + ABSORB_SECONDS + shakes * SHAKE_SECONDS


func attempt_capture(target: Pet, ball: BallData) -> bool:
	var reason := _rejection_reason(target, ball)
	if not reason.is_empty():
		capture_rejected.emit(reason)
		return false

	# 無論成敗都消耗（硬規則 2）
	Game.inventory.consume(ball.id)

	var rate := calculate_rate(target, ball)
	var success := randf() < rate

	# 成敗都要被吸進球裡，失敗才會有「跑出來」可演。
	# 這支同步排好整段演出，所以就算沒有人在聽 capture_attempted，
	# 節點也一定會被正確處理。
	target.play_capture_sequence(success, shake_count(success, rate))

	capture_attempted.emit(target, ball, success, rate)

	if success:
		_on_success(target)
	# 失敗：狀態完全不動。目標不消失、HP 不變、FSM 不變、戰鬥繼續。
	return success


func _rejection_reason(target: Pet, ball: BallData) -> StringName:
	if ball == null:
		return &"no_ball_data"
	if not is_instance_valid(target):
		return &"no_target"
	if target.ai.behaviour != PetAI.Behaviour.WILD:
		return &"not_wild"
	if target.health.is_dead:
		return &"target_dead"
	if Game.inventory.count(ball.id) <= 0:
		return &"out_of_balls"
	return &""


## 順序必須是「建 instance → 進收藏 → emit → queue_free」。
## 反過來的話監聽者會拿到已釋放的節點。
func _on_success(target: Pet) -> void:
	# 捕捉成功 = 以滿血加入（create_from 預設滿血）。
	# 曾經存「捕捉當下的殘血」，但 Phase 1 沒有任何回血手段，
	# 剛抓到的寵物永遠只能以殘血上場，驗收流程「抓潛水蛇 → 切換 → 打火焰喵」會必輸。
	var instance := PetInstance.create_from(
		target.data, Game.next_instance_id())

	Game.collection.add(instance)
	# Party 滿了就只進收藏，不跳「要替換誰」的 UI（MVP 不需要）
	Game.party.add(instance)

	EventBus.pet_captured.emit(instance.instance_id, target.data.id)
	# 節點的移除由 play_capture_sequence 演完再做，這裡不碰。
