## 玩家能對寵物下的指令（規格書 §8）。
##
## 指令**設定意圖**，FSM **決定當下狀態**——兩者不要混為一談。
## 例如 ATTACK_TARGET 是意圖，實際狀態會在 CHASE / ATTACK / CAST_SKILL 之間走。
class_name PetCommand
extends RefCounted

enum Type {
	ATTACK_TARGET,  ## 攻擊指定目標
	FOLLOW,         ## 跟隨玩家（探索預設）
	STAY,           ## 原地待命，不主動接敵
	DEFEND,         ## 駐守，反擊進入範圍者
	RETREAT,        ## 脫離戰鬥回到玩家身邊
}
