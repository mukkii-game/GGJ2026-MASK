extends Node
## ステージ管理スクリプト。敵の増援、クリア判定、BGM再生、ボス撃破QTEを行う。

@export var enemy_scene: PackedScene = preload("res://Scenes/NPC's/Enemy/Enemy.tscn")
var _player_scene: PackedScene = preload("res://Scenes/Player/Player.tscn")
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
## トレーニングモード：ダミー撃破後の復活待ち（>=0でカウント中、1.2秒で再スポーン）
var _training_respawn_timer: float = -1.0

# ステージごとのパラメータ
var stage_params: Dictionary = {}

# ボスHP0でQTE表示中
var qte_scene: PackedScene = preload("res://Scenes/qte_core.tscn")
var current_qte_boss: CharacterBase = null
var qte_node: Node2D = null



func _ready() -> void:
	# 既存の敵を全て削除（SubViewport内のNPCsを直接参照）
	await get_tree().process_frame
	# 2P: 2P/テスト時は毎回新規生成して追加（シーン由来に依存しない）
	var subvp := get_node_or_null("../SubViewportContainer/SubViewport")
	if subvp and subvp.get_child_count() > 0 and _player_scene:
		var floor_root := subvp.get_child(0)
		var show_2p := GameManager.two_player_mode or GameManager.test_mode
		var old_p2: Node = floor_root.get_node_or_null("Player2")
		if old_p2:
			old_p2.queue_free()
		var player2: Node = _player_scene.instantiate()
		player2.set("is_player_two", true)
		player2.position = Vector2(840, 360)
		player2.scale = Vector2(1, 1)
		player2.name = "Player2"
		player2.visible = show_2p
		player2.process_mode = PROCESS_MODE_INHERIT if show_2p else PROCESS_MODE_DISABLED
		floor_root.add_child(player2)
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
	# 出現時に雑魚と重なってダメージを食わないよう、全プレイヤーに短時間無敵
	for node in get_tree().get_nodes_in_group("Player"):
		if node and node.has_method("set_invincible_for"):
			node.set_invincible_for(2.0)

func _setup_stage_params() -> void:
	if GameManager.training_mode:
		stage_params = { "initial_count": 1 }
		return
	if GameManager.test_mode:
		_setup_test_params()
	else:
		_setup_normal_params()

## テストモード：一撃で死ぬ（シーケンス確認用）
func _setup_test_params() -> void:
	match GameManager.current_stage:
		1:  # 雑魚マスク軍団（テスト＝一撃）
			stage_params = {
				"initial_count": 2,
				"max_count": 6,
				"spawn_interval": 12.0,
				"enemy_hp": 2,
				"enemy_speed": 300.0,
				"behavior": 3  # RandomRange
			}
		2:  # マスクメロンナ（テスト＝一撃）
			stage_params = {
				"initial_count": 1,
				"max_minions": 2,
				"spawn_interval": 20.0,
				"boss_hp": 2,
				"boss_speed": 600.0,
				"minion_hp": 2,
				"behavior": 4  # Flee
			}
		3:  # ユニ帝仮面（テスト＝一撃）
			stage_params = {
				"initial_count": 1,
				"max_count": 4,
				"spawn_interval": 14.0,
				"boss_hp": 2,
				"boss_speed": 400.0,
				"enemy_hp": 2,
				"behavior": 3  # RandomRange
			}
		4:  # 異論マスク（テスト＝一撃）
			stage_params = {
				"initial_count": 1,
				"max_count": 4,
				"spawn_interval": 14.0,
				"boss_hp": 2,
				"boss_speed": 200.0,
				"enemy_hp": 2,
				"behavior": 3  # RandomRange
			}

## 本番モード（スタート）：全ステージで雑魚を定期的に落とす・敵HPは半分
func _setup_normal_params() -> void:
	match GameManager.current_stage:
		1:  # 雑魚マスク軍団（雑魚のみ・数発で死ぬ）
			stage_params = {
				"initial_count": 2,
				"max_count": 7,
				"spawn_interval": 11.0,
				"enemy_hp": 27,
				"enemy_speed": 300.0,
				"behavior": 3  # RandomRange
			}
		2:  # マスクメロンナ（足速く・近づくと距離取り・被弾で超高速離脱）
			stage_params = {
				"initial_count": 1,
				"max_minions": 3,
				"spawn_interval": 18.0,
				"boss_hp": 110,
				"boss_speed": 750.0,
				"minion_hp": 25,
				"behavior": 4  # Flee
			}
		3:  # ユニ帝仮面（ボスはランダム移動・雑魚／ときどきロープ往復）
			stage_params = {
				"initial_count": 1,
				"max_count": 4,
				"spawn_interval": 14.0,
				"boss_hp": 130,
				"boss_speed": 400.0,
				"enemy_hp": 25,
				"behavior": 3  # RandomRange
			}
		4:  # 異論マスク（同上）
			stage_params = {
				"initial_count": 1,
				"max_count": 4,
				"spawn_interval": 14.0,
				"boss_hp": 200,
				"boss_speed": 200.0,
				"enemy_hp": 25,
				"behavior": 3  # RandomRange
			}

func _process(delta: float) -> void:
	if stage_cleared:
		return
	
	if GameManager.training_mode:
		var alive := _get_alive_enemy_count()
		if alive == 0:
			if _training_respawn_timer < 0.0:
				_training_respawn_timer = 0.0
			_training_respawn_timer += delta
			if _training_respawn_timer >= 1.2:
				var center := Vector2(640.0, 360.0)
				if spawn_points.size() >= 3:
					center = spawn_points[2]
				_spawn_training_enemy_at(center, EnemyMain.EnemyState.Normal)
				_training_respawn_timer = -1.0
		return
	
	# 全ステージで雑魚を定期的に落とす
	spawn_timer += delta
	var interval: float = stage_params.get("spawn_interval", 10.0)
	if spawn_timer >= interval:
		spawn_timer = 0.0
		_spawn_reinforcement()
	
	# クリア判定
	_check_stage_clear()

func _input(_event: InputEvent) -> void:
	if stage_cleared:
		return




## 初期配置（ステージ1は全員雑魚、2〜4は最初の1体がボス）
func _spawn_initial_enemies() -> void:
	if GameManager.training_mode:
		var base_pos := Vector2(640.0, 360.0)
		var subvp := get_node_or_null("../SubViewportContainer/SubViewport")
		if subvp:
			var main_floor := subvp.get_node_or_null("MainFloor")
			if main_floor:
				var player := main_floor.get_node_or_null("Player") as Node2D
				if player:
					base_pos = player.global_position
		# 通常・怒り・弱りの3体をプレイヤー位置からずらして配置
		var offsets: Array[Vector2] = [Vector2(-130, 0), Vector2(0, 0), Vector2(130, 0)]
		var states: Array[EnemyMain.EnemyState] = [EnemyMain.EnemyState.Normal, EnemyMain.EnemyState.Angry, EnemyMain.EnemyState.Weak]
		for i in range(3):
			_spawn_training_enemy_at(base_pos + offsets[i], states[i])
		return
	var count: int = stage_params.get("initial_count", 1)
	var has_boss_stage: bool = GameManager.current_stage >= 2
	for i in range(count):
		var pos: Vector2 = spawn_points[i % spawn_points.size()]
		_spawn_enemy_at(pos, has_boss_stage and i == 0)

## 増援（雑魚を定期的に落とす）
func _spawn_reinforcement() -> void:
	if GameManager.training_mode:
		return
	var npcs = _get_npcs_node()
	var current_count := npcs.get_child_count() if npcs else 0
	var max_count: int = 0
	
	match GameManager.current_stage:
		1:
			max_count = stage_params.get("max_count", 8)
		2:
			max_count = 1 + stage_params.get("max_minions", 5)
		3, 4:
			max_count = stage_params.get("max_count", 4)
	
	if current_count < max_count:
		var random_point := spawn_points[randi() % spawn_points.size()]
		_spawn_enemy_at(random_point, false)

## トレーニング用：1体スポーン（画面右端からリングインして landing_pos に着地、通常・怒り・弱りを固定）
func _spawn_training_enemy_at(landing_pos: Vector2, state: EnemyMain.EnemyState) -> void:
	if not enemy_scene:
		return
	var enemy := enemy_scene.instantiate() as EnemyMain
	if not enemy:
		return
	enemy.health = 200
	enemy.stage_number = 1
	enemy.is_boss = false
	enemy.use_qte_on_defeat = false
	enemy.behavior_type = EnemyMain.Behavior.Idle
	enemy.is_training_dummy = true
	enemy.patrol_distance_override = 0.0
	enemy.patrol_speed_override = 0.0
	enemy.enemy_state = state
	enemy.ring_in_landing_pos = landing_pos
	enemy.scale = Vector2(1, 1)
	var from_right: bool = randf() >= 0.5
	var spawn_x: float = RING_IN_SPAWN_RIGHT if from_right else RING_IN_SPAWN_LEFT
	var subvp := get_node_or_null("../SubViewportContainer/SubViewport")
	if subvp:
		var main_floor := subvp.get_node_or_null("MainFloor")
		if main_floor:
			var npcs := main_floor.get_node_or_null("NPCs")
			if npcs:
				npcs.add_child(enemy)
				enemy.global_position = Vector2(spawn_x, (MAT_TOP + MAT_BOTTOM) * 0.5)
			else:
				main_floor.add_child(enemy)
				enemy.global_position = Vector2(spawn_x, (MAT_TOP + MAT_BOTTOM) * 0.5)
	var tex_path := _get_enemy_texture_path(1, false)
	_apply_enemy_sprite(enemy, tex_path)

## 敵をスポーン
func _spawn_enemy_at(pos: Vector2, is_boss: bool) -> void:
	if not enemy_scene:
		return
	var enemy := enemy_scene.instantiate() as EnemyMain
	if not enemy:
		return
	
	# ステージごとのパラメータ設定
	match GameManager.current_stage:
		1:  # 雑魚マスク（いままでどおり＋ときどきロープ往復）
			enemy.health = stage_params.get("enemy_hp", 30)
			enemy.stage_number = 1
			enemy.is_boss = false
			enemy.use_qte_on_defeat = false
			_set_zako_behavior(enemy, pos)
		2:  # マスクメロンナ
			if is_boss:
				enemy.health = stage_params.get("boss_hp", 100)
				enemy.behavior_type = 4 as EnemyMain.Behavior  # Flee
				enemy.stage_number = 2
				enemy.is_boss = true
				enemy.use_qte_on_defeat = true
			else:
				enemy.health = stage_params.get("minion_hp", 30)
				enemy.stage_number = 2
				enemy.is_boss = false
				enemy.use_qte_on_defeat = false
				_set_zako_behavior(enemy, pos)
		3:  # ユニ帝仮面（ボスはRandomRange・雑魚／ときどきロープ往復）
			if is_boss:
				enemy.health = stage_params.get("boss_hp", 120)
				enemy.stage_number = 3
				enemy.is_boss = true
				enemy.use_qte_on_defeat = true
				enemy.behavior_type = stage_params.get("behavior", 3) as EnemyMain.Behavior
			else:
				enemy.health = stage_params.get("enemy_hp", 25)
				enemy.stage_number = 3
				enemy.is_boss = false
				enemy.use_qte_on_defeat = false
				_set_zako_behavior(enemy, pos)
		4:  # 異論マスク（同上・バトル中は iron_mask_title4 は使わない＝前後用）
			if is_boss:
				enemy.health = stage_params.get("boss_hp", 250)
				enemy.stage_number = 4
				enemy.is_boss = true
				enemy.use_qte_on_defeat = true
				enemy.behavior_type = stage_params.get("behavior", 3) as EnemyMain.Behavior
			else:
				enemy.health = stage_params.get("enemy_hp", 25)
				enemy.stage_number = 4
				enemy.is_boss = false
				enemy.use_qte_on_defeat = false
				_set_zako_behavior(enemy, pos)
	
	# ステージ3ボスだけは移動速度を半分に落とす
	if GameManager.current_stage == 3 and enemy.is_boss:
		var wander = enemy.get_node_or_null("FSM/enemy_wander_state")
		if wander and "move_speed" in wander:
			wander.move_speed *= 0.5
		var chase = enemy.get_node_or_null("FSM/enemy_chase_state")
		if chase and "move_speed" in chase:
			chase.move_speed *= 0.5
	
	enemy.scale = Vector2(1, 1)
	
	# ボスのみ：HP0でQTE開始
	if enemy.use_qte_on_defeat:
		enemy.defeated_for_qte.connect(_on_boss_defeated_for_qte)
	
	# SubViewport内のMainFloorに追加（雑魚は画面右端からリングイン）
	var subvp := get_node_or_null("../SubViewportContainer/SubViewport")
	if subvp:
		var main_floor := subvp.get_node_or_null("MainFloor")
		if main_floor:
			var spawn_pos := pos
			if not is_boss:
				enemy.ring_in_landing_pos = _pick_empty_spot_on_mat(main_floor)
				var from_right: bool = randf() >= 0.5
				spawn_pos = Vector2(RING_IN_SPAWN_RIGHT if from_right else RING_IN_SPAWN_LEFT, (MAT_TOP + MAT_BOTTOM) * 0.5)
			var npcs := main_floor.get_node_or_null("NPCs")
			if npcs:
				npcs.add_child(enemy)
				enemy.global_position = spawn_pos
			else:
				main_floor.add_child(enemy)
				enemy.global_position = spawn_pos
	
	# ステージ・ボス/雑魚に応じた絵を適用（res://Art/Sprites/）
	var tex_path := _get_enemy_texture_path(GameManager.current_stage, is_boss)
	_apply_enemy_sprite(enemy, tex_path)

## リングイン：画面右端／左端スポーン位置（マットより外側・右端か左端から走り込む）
const MAT_LEFT := 296.0
const MAT_RIGHT := 984.0
const MAT_TOP := 106.0
const MAT_BOTTOM := 614.0
const RING_IN_SPAWN_RIGHT := 1110.0
const RING_IN_SPAWN_LEFT := 186.0
const RING_IN_MIN_DIST := 90.0

## 雑魚：いままでどおり or ときどき上下/左右ロープ間を死ぬまで往復（プレイヤーより少し遅い速度）
const ROPE_PATROL_DISTANCE := 344.0  # マット半幅
const ROPE_PATROL_SPEED := 260.0     # プレイヤーより少し速い

## マット内で他キャラと被らない空き位置を1つ返す（雑魚・トレーニングのリングイン着地用）
func _pick_empty_spot_on_mat(main_floor: Node) -> Vector2:
	var obstacles: Array[Vector2] = []
	var player := main_floor.get_node_or_null("Player") as Node2D
	if player:
		obstacles.append(player.global_position)
	var npcs := main_floor.get_node_or_null("NPCs")
	if npcs:
		for c in npcs.get_children():
			if c is CharacterBase and not (c as CharacterBase).is_dead:
				obstacles.append(c.global_position)
	for _attempt in range(25):
		var p := Vector2(randf_range(MAT_LEFT + 50, MAT_RIGHT - 50), randf_range(MAT_TOP + 50, MAT_BOTTOM - 50))
		var ok := true
		for o in obstacles:
			if p.distance_to(o) < RING_IN_MIN_DIST:
				ok = false
				break
		if ok:
			return p
	return Vector2((MAT_LEFT + MAT_RIGHT) * 0.5, (MAT_TOP + MAT_BOTTOM) * 0.5)

func _set_zako_behavior(enemy: EnemyMain, _pos: Vector2) -> void:
	if randf() < 0.35:  # 35%でロープ往復
		enemy.behavior_type = (1 if randi() % 2 == 0 else 2) as EnemyMain.Behavior  # VerticalLoop or HorizontalLoop
		enemy.patrol_distance_override = ROPE_PATROL_DISTANCE
		enemy.patrol_speed_override = ROPE_PATROL_SPEED
	else:
		enemy.behavior_type = stage_params.get("behavior", 3) as EnemyMain.Behavior
		enemy.patrol_distance_override = 0.0
		enemy.patrol_speed_override = 0.0

## ステージ・ボス/雑魚に応じた敵スプライトパス（SPEC: zako/melon_chan/uni_chan/elon_musk）
func _get_enemy_texture_path(stage: int, is_boss: bool) -> String:
	match stage:
		1:  # 雑魚マスク zako_mask
			return "res://Art/Sprites/m_man_b_l1.png"
		2:  # マスクメロンナ melon_chan / 雑魚はzako
			return "res://Art/Sprites/panna_chan_l1.png" if is_boss else "res://Art/Sprites/m_man_b_l1.png"
		3:  # ユニ帝仮面 uni_chan / 雑魚はzako
			return "res://Art/Sprites/unity_chan_l1.png" if is_boss else "res://Art/Sprites/m_man_b_l1.png"
		4:  # 異論マスク（gr_mask_l1 / gr_mask_l2）
			return "res://Art/Sprites/gr_mask_l1.png"
		_:
			return "res://Art/Sprites/m_man_b_l1.png"

## 敵のAnimatedSprite2Dにl1/l2の2パターンでSpriteFramesを適用
func _apply_enemy_sprite(enemy: EnemyMain, texture_path: String) -> void:
	if not ResourceLoader.exists(texture_path):
		return
	var tex_l1 := load(texture_path) as Texture2D
	if not tex_l1:
		return
	var tex_l2: Texture2D = null
	var l2_path := texture_path.replace("_l1.png", "_l2.png")
	if ResourceLoader.exists(l2_path):
		tex_l2 = load(l2_path) as Texture2D
	if not tex_l2:
		tex_l2 = tex_l1
	var sprite := enemy.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if not sprite:
		return
	var sf := SpriteFrames.new()
	var dur := 0.5
	sf.add_animation("Idle")
	sf.add_frame("Idle", tex_l1, dur)
	sf.add_frame("Idle", tex_l2, dur)
	sf.add_animation("Walk")
	sf.add_frame("Walk", tex_l1, dur)
	sf.add_frame("Walk", tex_l2, dur)
	sf.add_animation("Attack")
	sf.add_frame("Attack", tex_l1, dur)
	sf.add_frame("Attack", tex_l2, dur)
	sf.add_animation("Death")
	sf.add_frame("Death", tex_l1, 1.0)
	sf.add_frame("Death", tex_l2, 1.0)
	sf.set_animation_loop("Idle", true)
	sf.set_animation_loop("Walk", true)
	sf.set_animation_loop("Attack", false)
	sf.set_animation_loop("Death", false)
	sf.set_animation_speed("Idle", 5.0)
	sf.set_animation_speed("Walk", 5.0)
	sf.set_animation_speed("Attack", 4.0)
	sf.set_animation_speed("Death", 5.0)
	sprite.sprite_frames = sf
	sprite.play("Idle")

## SubViewport内のNPCsノードを取得（敵はここに追加されている）
func _get_npcs_node() -> Node:
	var subvp := get_node_or_null("../SubViewportContainer/SubViewport")
	if not subvp:
		return null
	var main_floor := subvp.get_child(0)
	if not main_floor:
		return null
	return main_floor.get_node_or_null("NPCs")

## SubViewport内のプレイヤーを取得（出現時無敵用）
func _get_player() -> CharacterBase:
	var subvp := get_node_or_null("../SubViewportContainer/SubViewport")
	if not subvp:
		return null
	var main_floor := subvp.get_child(0)
	if not main_floor:
		return null
	return main_floor.get_node_or_null("Player") as CharacterBase

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
	if GameManager.training_mode:
		return  # トレーニングはクリアしない
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
	
	# 画面フラッシュ＋ファンファーレを再生し、awaitを使わずタイマーでクリア画面へ（ステージ3後フリーズ対策）
	_play_clear_flash_and_fanfare()
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

## QTE成功時：画面フラッシュ＋ファンファーレ再生（awaitなし・遷移は_on_stage_clearのタイマーで）
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
	
	# クリア時：勝利っぽいBGM（clear_fanfare.ogg があれば使用、なければ QuestSound）
	var fanfare_path := "res://Art/Audio/Effects/clear_fanfare.ogg"
	if not ResourceLoader.exists(fanfare_path):
		fanfare_path = "res://Art/Audio/Effects/QuestSound.ogg"
	if not ResourceLoader.exists(fanfare_path):
		fanfare_path = "res://Art/Audio/Effects/coin_pick.ogg"
	if ResourceLoader.exists(fanfare_path):
		var se := AudioStreamPlayer.new()
		se.stream = load(fanfare_path) as AudioStream
		root.add_child(se)
		se.play()
	
	# フラッシュ：白に一瞬→フェードアウト（コールバックで削除、awaitしない）
	var tween := flash.create_tween()
	tween.tween_property(flash, "color", Color(1, 1, 1, 1), 0.15)
	tween.tween_property(flash, "color", Color(1, 1, 1, 0), 0.5)
	tween.tween_callback(flash.queue_free)

## ステージクリア（タイマーコールバックで遷移。フラッシュ約0.65秒＋余裕で1.2秒後に遷移）
func _on_stage_clear() -> void:
	get_tree().create_timer(1.2).timeout.connect(func() -> void:
		GameManager.clear_stage(GameManager.current_stage)
		get_tree().change_scene_to_file("res://Scenes/UI/StageClear.tscn")
	)
