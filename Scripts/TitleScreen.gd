extends Control
## タイトル画面。キーまたはクリックでゲーム開始。
## タイトル画像は title_original.png を参照（なければ title.png → icon.png）。

@export var next_scene: String = "res://Scenes/Levels/GameWrapper.tscn"

func _ready() -> void:
	var tex_rect = get_node_or_null("TextureRect")
	if not tex_rect:
		return
	var path := "res://Art/Icons/title_original.png"
	if ResourceLoader.exists(path):
		tex_rect.texture = load(path) as Texture2D
	elif ResourceLoader.exists("res://Art/Icons/title.png"):
		tex_rect.texture = load("res://Art/Icons/title.png") as Texture2D

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		_start_game()
		var vp = get_viewport()
		if vp:
			vp.set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		_start_game()
		var vp = get_viewport()
		if vp:
			vp.set_input_as_handled()

func _start_game() -> void:
	get_tree().change_scene_to_file(next_scene)
