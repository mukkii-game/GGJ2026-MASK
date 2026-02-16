extends Control
## ステージクリア画面。倒したボスの顔を表示。右上1/4はモザイクで隠し、その上に「STAGE CLEAR!」とメッセージを表示。
## 何かキー/マウスで次へ（ステージ4の次はエンディング）

var _can_advance := false

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	set_process_input(true)
	# ステージ番号表示（右上1/4のモザイク上）
	var stage_label = get_node_or_null("FaceCover/TextPanel/VBox/StageNumber")
	if stage_label:
		stage_label.text = "STAGE " + str(GameManager.current_stage) + " CLEAR!"
	
	# ボス顔画像（ステージごと: iron_mask_title1〜4 を背景に使用）
	var texture_path := "res://Art/Sprites/iron_mask_title%d.png" % clampi(GameManager.current_stage, 1, 4)
	var tex: Texture2D = null
	if ResourceLoader.exists(texture_path):
		tex = load(texture_path) as Texture2D
	var boss_face = get_node_or_null("BossFace")
	if boss_face and tex:
		boss_face.texture = tex
	var blur_rect = get_node_or_null("FaceCover/BlurMosaicRect")
	if blur_rect and tex:
		blur_rect.texture = tex
	
	# 勝利メッセージ（右上1/4）：「〇〇のマスクを剥いだ！」
	var boss_name := _get_boss_name(GameManager.current_stage)
	var message_label = get_node_or_null("FaceCover/TextPanel/VBox/Message")
	if message_label:
		message_label.text = boss_name + "のマスクを剥いだ！"
	
	# 1秒間は進めない
	get_tree().create_timer(1.0).timeout.connect(_on_advance_allowed)

func _on_advance_allowed() -> void:
	_can_advance = true

func _input(event: InputEvent) -> void:
	_try_advance(event)

func _unhandled_input(event: InputEvent) -> void:
	# フォーカスで消費されていても未処理ならここで受け取る
	_try_advance(event)

func _try_advance(event: InputEvent) -> void:
	if not _can_advance:
		return
	var advance := false
	if event is InputEventKey and event.pressed and not event.echo:
		advance = true
	elif event is InputEventMouseButton and event.pressed:
		advance = true
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_select"):
		advance = true
	if advance:
		_next_stage()
		var vp := get_viewport()
		if vp:
			vp.set_input_as_handled()

func _get_boss_name(stage: int) -> String:
	match stage:
		1: return "雑魚マスク軍団"
		2: return "マスクメロンナちゃん"
		3: return "うに帝仮面"
		4: return "異論マスク"
		_: return "マスク"

func _next_stage() -> void:
	# 次のステージへ
	GameManager.load_next_stage()
