## 跨系統事件匯流排（規格書 §21）。
##
## 判準：發送方與接收方**互相不該知道對方存在**時，才用 EventBus。
## Pet 內部 component 之間直接連 signal 就好，不要繞全域。
extends Node

signal pet_captured(instance_id: StringName, species_id: StringName)
signal active_pet_changed(slot: int)
signal pet_died(instance_id: StringName)

signal raid_warning(seconds: float, direction: Vector3)
signal raid_started()
signal raid_finished(won: bool)

signal threat_changed(new_threat: float)
signal day_changed(day_count: int)
signal base_level_changed(new_level: int)
