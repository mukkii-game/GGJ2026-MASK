extends Control
## ステージクリア画面。倒したボスの顔と「STAGE CLEAR!」を表示。マスク脱がされた設定で右側の顔はモザイク＋「見せられないよ！」で隠す。

var _can_advance := false

func _ready() -> void:
	# ステージ番号表示
	var stage_label = get_node_or_null("StageNumber")
	if stage_label:
		stage_label.text = "STAGE " + str(GameManager.current_stage) + " CLEAR!"
	
	# ボス顔画像（ステージごと: iron_mask_title1〜4）
	var boss_face = get_node_or_null("BossFace")
	var texture_path := "res://Art/Sprites/iron_mask_title%d.png" % clampi(GameManager.current_stage, 1, 4)
	if boss_face and ResourceLoader.exists(texture_path):
		boss_face.texture = load(texture_path) as Texture2D
	
	# 勝利メッセージ
	var message_label = get_node_or_null("Message")
	if message_label:
		var message := ""
		match GameManager.current_stage:
			1:
				message = "雑魚マスク軍団を倒した！"
			2:
				message = "マスクメロンナを追い詰めた！"
			3:
				message = "ユニ帝仮面の弱点を見抜いた！"
			4:
				message = "異論マスクをコーナー技で撃破！"
		message_label.text = message
	
	# 1秒間は進めない
	get_tree().create_timer(1.0).timeout.connect(_on_advance_allowed)

func _on_advance_allowed() -> void:
	_can_advance = true

func _input(event: InputEvent) -> void:
	if not _can_advance:
		return
	if event is InputEventKey and event.pressed:
		_next_stage()
		var vp = get_viewport()
		if vp:
			vp.set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		_next_stage()
		var vp = get_viewport()
		if vp:
			vp.set_input_as_handled()

func _next_stage() -> void:
	# 次のステージへ
	GameManager.load_next_stage()
