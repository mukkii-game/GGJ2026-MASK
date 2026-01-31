extends CharacterBase
class_name PlayerMain

@onready var fsm = $FSM as FiniteStateMachine
const DEATH_SCREEN = preload("res://Scenes/Misc/DeathScreen.tscn")

## false=滑らか（初期） / true=カクカク。Gキーでトグル
var use_grid_movement := false

func _process(_delta):
	super(_delta)
	if Input.is_action_just_pressed("ToggleGridMove"):
		use_grid_movement = not use_grid_movement

func _die():
	super() #calls _die() on base-class CharacterBase
	
	fsm.force_change_state("Die")
	var death_scene = DEATH_SCREEN.instantiate()
	add_child(death_scene)
