extends Node
## ステージ管理スクリプト。敵の増援、クリア判定、BGM再生、ボス撃破QTEを行う。

@export var enemy_scene: PackedScene = preload("res://Scenes/NPC's/Enemy/Enemy.tscn")
@export var spawn_points: Array[Vector2] = [
	Vector2(400, 200),
	Vector2(880, 200),
	Vector2(640, 360),
	Vector2(400, 520),
	Vector2(880, 520)
]

var spawn_timer: float = 0.0
var stage_cleared: bool = false
var initial_spawn_done: bool = false  # 初期配置完了前はクリア判定しない

# ステージごとのパラメータ
var stage_params: Dictionary = {}

# ボスHP0でQTE表示中
var qte_scene: PackedScene = preload("res://Scenes/qte_core.tscn")
var current_qte_boss: CharacterBase = null
var qte_node: Node2D = null

func _ready() -> void:
	# 既存の敵を全て削除（SubViewport内のNPCsを直接参照）
	await get_tree().process_frame
	var npcs = _get_npcs_node()
	if npcs:
		for child in npcs.get_children():
			child.queue_free()
	
	# BGM再生
	var bgm_path := "res://Art/Audio/MainTheme.mp3"
	if ResourceLoader.exists(bgm_path):
		var bgm_player := AudioStreamPlayer.new()
		bgm_player.stream = load(bgm_path) as AudioStream
		bgm_player.autoplay = true
		add_child(bgm_player)
	
	# ステージパラメータを設定
	_setup_stage_params()
	
	# 初期配置
	await get_tree().create_timer(0.1).timeout
	_spawn_initial_enemies()
	initial_spawn_done = true

func _setup_stage_params() -> void:
	if GameManager.test_mode:
		_setup_test_params()
	else:
		_setup_normal_params()

## テストモード：簡単バランス、シーケンス確認用
func _setup_test_params() -> void:
	match GameManager.current_stage:
		1:  # 雑魚マスク軍団（テスト）
			stage_params = {
				"initial_count": 3,
				"max_count": 8,
				"spawn_interval": 10.0,
				"enemy_hp": 50,
				"enemy_speed": 300.0,
				"behavior": 3  # RandomRange
			}
		2:  # マスクメロンナ（テスト）
			stage_params = {
				"initial_count": 1,
				"max_minions": 3,
				"spawn_interval": 20.0,
				"boss_hp": 150,
				"boss_speed": 600.0,
				"minion_hp": 50,
				"behavior": 4  # Flee
			}
		3:  # ユニ帝仮面（テスト）
			stage_params = {
				"initial_count": 1,
				"boss_hp": 180,
				"boss_speed": 400.0,
				"behavior": 3  # RandomRange
			}
		4:  # 異論マスク（テスト）
			stage_params = {
				"initial_count": 1,
				"boss_hp": 350,
				"boss_speed": 200.0,
				"behavior": 3  # RandomRange
			}

## 本番モード（スタート）：SPEC準拠・個性は出るがイージー寄り
func _setup_normal_params() -> void:
	match GameManager.current_stage:
		1:  # 雑魚マスク軍団（1面は弱め）
			stage_params = {
				"initial_count": 3,
				"max_count": 5,
				"spawn_interval": 14.0,
				"enemy_hp": 45,
				"enemy_speed": 300.0,
				"behavior": 3  # RandomRange
			}
		2:  # マスクメロンナ（2面も弱め・逃げる・雑魚少なめ）
			stage_params = {
				"initial_count": 1,
				"max_minions": 2,
				"spawn_interval": 22.0,
				"boss_hp": 140,
				"boss_speed": 600.0,
				"minion_hp": 45,
				"behavior": 4  # Flee
			}
		3:  # ユニ帝仮面（正面無敵・反撃・ショルダーのみ有効）
			stage_params = {
				"initial_count": 1,
				"boss_hp": 240,
				"boss_speed": 400.0,
				"behavior": 3  # RandomRange
			}
		4:  # 異論マスク（高HP・超反動・コーナージャンプ特攻）
			stage_params = {
				"initial_count": 1,
				"boss_hp": 350,
				"boss_speed": 200.0,
				"behavior": 3  # RandomRange
			}

func _process(delta: float) -> void:
	if stage_cleared:
		return
	
	# ステージ1,2の増援システム
	if GameManager.current_stage == 1 or GameManager.current_stage == 2:
		spawn_timer += delta
		var interval: float = stage_params.get("spawn_interval", 10.0)
		if spawn_timer >= interval:
			spawn_timer = 0.0
			_spawn_reinforcement()
	
	# クリア判定
	_check_stage_clear()

## 初期配置（ステージ1は全員雑魚、2〜4は最初の1体がボス）
func _spawn_initial_enemies() -> void:
	var count: int = stage_params.get("initial_count", 1)
	var has_boss_stage: bool = GameManager.current_stage >= 2
	for i in range(count):
		var pos: Vector2 = spawn_points[i % spawn_points.size()]
		_spawn_enemy_at(pos, has_boss_stage and i == 0)

## 増援
func _spawn_reinforcement() -> void:
	var npcs = _get_npcs_node()
	var current_count := npcs.get_child_count() if npcs else 0
	var max_count: int = 0
	
	if GameManager.current_stage == 1:
		max_count = stage_params.get("max_count", 8)
	elif GameManager.current_stage == 2:
		max_count = 1 + stage_params.get("max_minions", 5)
	
	if current_count < max_count:
		var random_point := spawn_points[randi() % spawn_points.size()]
		_spawn_enemy_at(random_point, false)

## 敵をスポーン
func _spawn_enemy_at(pos: Vector2, is_boss: bool) -> void:
	if not enemy_scene:
		return
	var enemy := enemy_scene.instantiate() as EnemyMain
	if not enemy:
		return
	
	# ステージごとのパラメータ設定
	match GameManager.current_stage:
		1:  # 雑魚マスク
			enemy.health = stage_params.get("enemy_hp", 30)
			enemy.behavior_type = stage_params.get("behavior", 3)
			enemy.stage_number = 1
			enemy.is_boss = false
			enemy.use_qte_on_defeat = false
		2:  # マスクメロンナ
			if is_boss:
				enemy.health = stage_params.get("boss_hp", 100)
				enemy.behavior_type = 4  # Flee（逃げる）
				enemy.stage_number = 2
				enemy.is_boss = true
				enemy.use_qte_on_defeat = true
			else:
				enemy.health = stage_params.get("minion_hp", 30)
				enemy.behavior_type = 3
				enemy.stage_number = 2
				enemy.is_boss = false
				enemy.use_qte_on_defeat = false
		3:  # ユニ帝仮面
			enemy.health = stage_params.get("boss_hp", 120)
			enemy.behavior_type = stage_params.get("behavior", 3)
			enemy.stage_number = 3
			enemy.is_boss = true
			enemy.use_qte_on_defeat = true
		4:  # 異論マスク
			enemy.health = stage_params.get("boss_hp", 250)
			enemy.behavior_type = stage_params.get("behavior", 3)
			enemy.stage_number = 4
			enemy.is_boss = true
			enemy.use_qte_on_defeat = true
	
	enemy.scale = Vector2(1.25, 1.25)
	
	# ボスのみ：HP0でQTE開始
	if enemy.use_qte_on_defeat:
		enemy.defeated_for_qte.connect(_on_boss_defeated_for_qte)
	
	# SubViewport内のMainFloorに追加
	var subvp := get_node_or_null("../SubViewportContainer/SubViewport")
	if subvp:
		var main_floor := subvp.get_node_or_null("MainFloor")
		if main_floor:
			var npcs := main_floor.get_node_or_null("NPCs")
			if npcs:
				npcs.add_child(enemy)
				enemy.global_position = pos
			else:
				main_floor.add_child(enemy)
				enemy.global_position = pos

## SubViewport内のNPCsノードを取得（敵はここに追加されている）
func _get_npcs_node() -> Node:
	var subvp := get_node_or_null("../SubViewportContainer/SubViewport")
	if not subvp:
		return null
	var main_floor := subvp.get_child(0)
	if not main_floor:
		return null
	return main_floor.get_node_or_null("NPCs")

## 生存している敵の数を取得（SubViewport内のNPCsの子を直接数える）
func _get_alive_enemy_count() -> int:
	var npcs = _get_npcs_node()
	if not npcs:
		return 0
	var alive := 0
	for child in npcs.get_children():
		var cb = child as CharacterBase
		if is_instance_valid(cb) and not cb.is_dead:
			alive += 1
	return alive

## クリア判定（全敵撃破＝雑魚のみのステージはそのまま、ボスステージはQTE成功後にクリア）
func _check_stage_clear() -> void:
	if not initial_spawn_done or current_qte_boss != null:
		return
	var alive := _get_alive_enemy_count()
	if alive == 0 and not stage_cleared:
		stage_cleared = true
		_on_stage_clear()

## ボスHP0：QTE開始
func _on_boss_defeated_for_qte(who: CharacterBase) -> void:
	if current_qte_boss != null or stage_cleared:
		return
	current_qte_boss = who
	who.is_dead = true  # 気絶扱いで動かさない
	
	qte_node = qte_scene.instantiate() as Node2D
	if qte_node:
		qte_node.set("wait_for_start", true)
	var root := get_tree().current_scene
	if root and qte_node:
		root.add_child(qte_node)
		if qte_node.has_method("start_qte"):
			qte_node.start_qte()
		if qte_node.has_signal("qte_succeeded"):
			qte_node.qte_succeeded.connect(_on_qte_succeeded)
		if qte_node.has_signal("qte_failed"):
			qte_node.qte_failed.connect(_on_qte_failed)

func _on_qte_succeeded() -> void:
	if current_qte_boss and is_instance_valid(current_qte_boss):
		current_qte_boss.queue_free()
	current_qte_boss = null
	qte_node = null
	stage_cleared = true
	
	# 画面フラッシュ＋ファンファーレでクリア画面へ
	await _play_clear_flash_and_fanfare()
	_on_stage_clear()

func _on_qte_failed() -> void:
	if current_qte_boss and is_instance_valid(current_qte_boss):
		var restore := ceili(current_qte_boss.max_health * 0.2)
		restore = maxi(restore, 1)
		current_qte_boss.health = restore
		current_qte_boss.is_dead = false
		if current_qte_boss.healthbar:
			current_qte_boss.healthbar.value = current_qte_boss.health
	current_qte_boss = null
	# qte_node は2秒後に自分で queue_free

## QTE成功時：画面フラッシュ＋ファンファーレ再生
func _play_clear_flash_and_fanfare() -> void:
	var root := get_tree().current_scene
	if not root:
		return
	
	# フラッシュ用の白いColorRectを最前面に追加
	var flash := ColorRect.new()
	flash.color = Color(0, 0, 0, 0)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.anchor_left = 0.0
	flash.anchor_top = 0.0
	flash.anchor_right = 1.0
	flash.anchor_bottom = 1.0
	flash.offset_left = 0
	flash.offset_top = 0
	flash.offset_right = 0
	flash.offset_bottom = 0
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(flash)
	
	# ファンファーレ再生（QuestSound or coin_pick を代用）
	var fanfare_path := "res://Art/Audio/Effects/QuestSound.ogg"
	if not ResourceLoader.exists(fanfare_path):
		fanfare_path = "res://Art/Audio/Effects/coin_pick.ogg"
	if ResourceLoader.exists(fanfare_path):
		var se := AudioStreamPlayer.new()
		se.stream = load(fanfare_path) as AudioStream
		root.add_child(se)
		se.play()
	
	# フラッシュ：白に一瞬→フェードアウト
	var tween := flash.create_tween()
	tween.tween_property(flash, "color", Color(1, 1, 1, 1), 0.15)
	tween.tween_property(flash, "color", Color(1, 1, 1, 0), 0.5)
	tween.tween_callback(flash.queue_free)
	await tween.finished

## ステージクリア
func _on_stage_clear() -> void:
	await get_tree().create_timer(1.0).timeout
	GameManager.clear_stage(GameManager.current_stage)
	get_tree().change_scene_to_file("res://Scenes/UI/StageClear.tscn")
