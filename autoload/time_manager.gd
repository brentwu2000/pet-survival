## World Time / Day / Dusk / Night 的推進與廣播（規格書 §17、§21）。
##
## 只負責推進時間與廣播，**不直接改 gameplay 狀態**。
## Raid 由 RaidDirector 監聽本節點自行決定（Phase 5）。
extends Node

enum Phase { DAY, DUSK, NIGHT }

## 一日 = 現實 24 分鐘（硬規則 9）。比例必須配置化，不得散落在各系統。
const DAY_LENGTH_SECONDS := 24.0 * 60.0
const PHASE_RATIO := {
	Phase.DAY: 16.0 / 24.0,
	Phase.DUSK: 2.0 / 24.0,
	Phase.NIGHT: 6.0 / 24.0,
}

signal phase_changed(phase: Phase)

## 目前這一天已經過的秒數。
var time_of_day: float = 0.0
var day_count: int = 1
var current_phase: Phase = Phase.DAY

## Phase 0 的 Test World 不需要時間推進；Phase 5 接上 Raid 時才打開。
var is_running: bool = false


func _process(delta: float) -> void:
	if not is_running:
		return

	time_of_day += delta
	if time_of_day >= DAY_LENGTH_SECONDS:
		time_of_day -= DAY_LENGTH_SECONDS
		day_count += 1
		EventBus.day_changed.emit(day_count)

	var phase := _phase_at(time_of_day)
	if phase != current_phase:
		current_phase = phase
		phase_changed.emit(phase)


func normalized_time() -> float:
	return time_of_day / DAY_LENGTH_SECONDS


func _phase_at(seconds: float) -> Phase:
	var t := seconds / DAY_LENGTH_SECONDS
	if t < PHASE_RATIO[Phase.DAY]:
		return Phase.DAY
	if t < PHASE_RATIO[Phase.DAY] + PHASE_RATIO[Phase.DUSK]:
		return Phase.DUSK
	return Phase.NIGHT
