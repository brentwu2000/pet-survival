## 捕捉球（規格書 §10、§27）。
class_name BallData
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""

## 捕捉率的乘數。規格書 §10：高級球提高成功率。
@export_range(0.0, 2.0, 0.05) var power: float = 1.0

## 特殊球保證捕捉。規格書把它列為「未來可以提供」，MVP 不做球，但欄位先留。
@export var guaranteed: bool = false
