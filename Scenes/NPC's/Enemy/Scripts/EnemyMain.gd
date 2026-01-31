extends CharacterBase
class_name EnemyMain

@onready var fsm = $FSM as FiniteStateMachine
var player_in_range = false

@export var attack_node : Node
@export var chase_node : Node

# 攻撃後は必ずIdleに戻す（一定時間追従はChase側のタイマーで制御）
func finished_attacking():
	fsm.change_state(attack_node, "enemy_idle_state")

# プレイヤーが範囲内に入ったら一定時間追従（Chase）に切り替え
func _on_detection_area_body_entered(body):
	if body.is_in_group("Player"):
		player_in_range = true
		var cs = fsm.current_state.name if fsm.current_state else ""
		if cs != "enemy_death_state" and cs != "enemy_attack_state":
			fsm.force_change_state("enemy_chase_state")

#Return to idle when player leaves our proximity
func _on_detection_area_body_exited(body):
	if body.is_in_group("Player"):
		player_in_range = false
		fsm.change_state(chase_node, "enemy_idle_state")
		
func _die():
	super() #calls _die() on base-class CharacterBase
	fsm.force_change_state("enemy_death_state")
	
	
