extends Node

#NOTE this class is attached to the death_screen and victory_screen scene that shows up when the player dies
#it handles the logic for resetting the level or quitting the game

func _process(_delta):
	if Input.is_action_just_pressed("Restart") or Input.is_action_just_pressed("Enter"):
		restart()
	if Input.is_action_just_pressed("Escape"):
		get_tree().quit()

#When the player dies and wishes to reset, go back to title
func restart():
	GameManager.load_title()
