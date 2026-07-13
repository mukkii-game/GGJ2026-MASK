extends Control
## ステージ登場画面。ステージ番号、ボス顔、ボス名を表示。Intro.mp3を再生。

@onready var bgm_player: AudioStreamPlayer = null
var _can_advance := false

func _ready() -> void:
	# GameManagerのcurrent_stageを参照してステージ情報を設定
	var stage_data := _get_stage_data(GameManager.current_stage)
	
	# ステージ番号表示
	var stage_label = get_node_or_null("StageNumber")
	if stage_label:
		stage_label.text = "STAGE " + str(GameManager.current_stage)
	
	# 敵名（ボス名）は表示しない
	var boss_label = get_node_or_null("BossName")
	if boss_label:
		boss_label.visible = false
	
	# ボス顔画像
	var boss_face = get_node_or_null("BossFace")
	if boss_face and ResourceLoader.exists(stage_data["boss_texture"]):
		boss_face.texture = load(stage_data["boss_texture"]) as Texture2D
	
	# ステージ4: ボス（iron_mask_title4）の顔にぴかぴかエフェクト
	var face_sparkle = get_node_or_null("FaceSparkle")
	if face_sparkle:
		face_sparkle.visible = GameManager.current_stage == 4
		if GameManager.current_stage == 4:
			_start_face_sparkle(face_sparkle)
	
	# ボス説明表示（DescriptionPanel 内の Description に設定、1秒後にパネル表示）
	var desc_label = get_node_or_null("DescriptionPanel/Description")
	if desc_label:
		desc_label.text = stage_data.get("description", "")
	
	# Intro.mp3を再生。終了時にプロレス風ゴングを1回長めに鳴らす
	bgm_player = AudioStreamPlayer.new()
	add_child(bgm_player)
	var intro_path := "res://Art/Audio/Intro.mp3"
	if ResourceLoader.exists(intro_path):
		bgm_player.stream = load(intro_path) as AudioStream
		bgm_player.finished.connect(_on_intro_finished)
		bgm_player.play()
	
	# 1秒間は進めない
	get_tree().create_timer(1.0).timeout.connect(_on_advance_allowed)

func _get_stage_data(stage: int) -> Dictionary:
	match stage:
		1:
			return {
				"boss_texture": "res://Art/Sprites/iron_mask_title1.png",
				"description": "弱いが数が多い！\nどんどん増援が来るぞ！\n敵の真横に半分ずれてぶつかれ！一方的に押し込める\nロープに触れると反対側まで走れる！"
			}
		2:
			return {
				"boss_texture": "res://Art/Sprites/iron_mask_title2.png",
				"description": "すばしっこい逃げ足！\nコーナーを取って追い詰めろ！\n雑魚を召喚してくる！"
			}
		3:
			return {
				"boss_texture": "res://Art/Sprites/iron_mask_title3.png",
				"description": "正面は無敵！反撃が痛い！\n半キャラずらしのショルダータックルで攻撃！"
			}
		4:
			return {
				"boss_texture": "res://Art/Sprites/iron_mask_title4.png",
				"description": "高HP！攻撃すると大きく吹っ飛ぶ！\n直角に当ててピヨらせ、半キャラで追い込め！"
			}
		_:
			return {
				"boss_texture": "res://Art/Sprites/m_man_b_l1.png",
				"description": ""
			}

func _on_advance_allowed() -> void:
	_can_advance = true
	var desc_panel = get_node_or_null("DescriptionPanel")
	if desc_panel:
		desc_panel.visible = true

## Intro終了時：カーンというプロレス風ゴングを1回長めに再生
func _on_intro_finished() -> void:
	var path_ogg := "res://Art/Audio/Effects/gong.ogg"
	var path_wav := "res://Art/Audio/Effects/gong.wav"
	var stream: AudioStream = null
	if ResourceLoader.exists(path_ogg):
		stream = load(path_ogg) as AudioStream
	elif ResourceLoader.exists(path_wav):
		stream = load(path_wav) as AudioStream
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

func _input(event: InputEvent) -> void:
	if not _can_advance:
		return
	if event is InputEventKey and event.pressed:
		_start_battle()
		var vp = get_viewport()
		if vp:
			vp.set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		_start_battle()
		var vp = get_viewport()
		if vp:
			vp.set_input_as_handled()

func _start_face_sparkle(node: Control) -> void:
	# 顔の上でぴかぴか（モジュレート＋スケールのループ）
	var tween := create_tween().set_loops()
	tween.tween_property(node, "modulate", Color(1, 1, 1, 0.35), 0.12)
	tween.tween_property(node, "modulate", Color(1, 1, 1, 1), 0.12)
	tween.tween_property(node, "scale", Vector2(1.2, 1.2), 0.08)
	tween.tween_property(node, "scale", Vector2(1.0, 1.0), 0.08)

func _start_battle() -> void:
	# BGMを停止
	if bgm_player:
		bgm_player.stop()
	# バトル開始
	get_tree().change_scene_to_file("res://Scenes/Levels/GameWrapper.tscn")
