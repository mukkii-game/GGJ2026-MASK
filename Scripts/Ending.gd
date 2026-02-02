extends Control
## エンディング画面。「ボタンを押して終了」→ 任意入力でタイトルへ。

@onready var bgm_player: AudioStreamPlayer = null

func _ready() -> void:
	# 主人公（よめんのぼす / godot_man）の絵を表示（gr_mask_l1.png）
	var godot_face = get_node_or_null("GodotMask")
	if godot_face:
		var path := "res://Art/Sprites/gr_mask_l1.png"
		if ResourceLoader.exists(path):
			godot_face.texture = load(path) as Texture2D
	
	# エンディング曲を再生（なければMainTheme.mp3）
	bgm_player = AudioStreamPlayer.new()
	add_child(bgm_player)
	var ending_path := "res://Art/Audio/Ending.mp3"
	if ResourceLoader.exists(ending_path):
		bgm_player.stream = load(ending_path) as AudioStream
		bgm_player.play()
	elif ResourceLoader.exists("res://Art/Audio/MainTheme.mp3"):
		bgm_player.stream = load("res://Art/Audio/MainTheme.mp3") as AudioStream
		bgm_player.play()
	
	# ボタン押下で終了
	var btn = get_node_or_null("ExitButton")
	if btn:
		btn.pressed.connect(_back_to_title)

func _input(event: InputEvent) -> void:
	var vp := get_viewport()
	# なんか入力で終了（キー・マウス・ジョイパッドなど）
	if event is InputEventKey and event.pressed:
		_back_to_title()
		if vp:
			vp.set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		_back_to_title()
		if vp:
			vp.set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed:
		_back_to_title()
		if vp:
			vp.set_input_as_handled()

func _back_to_title() -> void:
	if bgm_player:
		bgm_player.stop()
	GameManager.load_title()
