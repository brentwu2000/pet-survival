## 世界的一個區域（`PHASE_WORLD_PROTOTYPE.md` §5、W3）。
##
## **W1 只有資料，沒有行為。** 進出偵測、區域名稱提示是 W3 的事，
## 現在放進來只是讓每個 Graybox Scene 自己說得出「我是誰、我什麼屬性」。
##
## 區域屬性用 `Element.Type`，和寵物共用同一套 enum——
## 「水系學校放水系怪獸」這件事之後才好用資料判斷，不用再寫一張對照表。
class_name Zone
extends Node3D

## 與檔名一致（water_school.tscn -> &"water_school"）。
@export var zone_id: StringName = &""
@export var display_name: String = ""
## 中立區域（聚落）沒有屬性，留 false。
@export var has_element: bool = true
@export var element: Element.Type = Element.Type.GRASS
