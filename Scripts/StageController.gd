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
## ザコの種類サイクル用インデックス（ステージごとの型配列を順番に消化）
var _reinforce_index: int = 0
## S1ウェーブ管理: 累計スポーン数・現在の同時数上限・上限引き上げタイマー
var _s1_spawned: int = 0
var _s1_cap: int = 1
var _s1_ramp_timer: float = 0.0
var _s1_phase: int = 0  # 0=1匹教習 1=やっちまえ後群れ
## ボス・トップロープ攻撃（低HPで最大2回）
var _top_rope_count: int = 0
var _top_rope_active: bool = false
var _top_rope_timer: float = 0.0
var _top_rope_shadow: Node2D = null
var _top_rope_boss: EnemyMain = null
var _top_rope_land_pos: Vector2 = Vector2.ZERO
const TOP_ROPE_AIR_SEC := 4.0
const TOP_ROPE_DAMAGE := 30
var _next_pack_id: int = 1
## S4ボスギミック（号令とロープ走行を交互）
var _gimmick_timer: float = 0.0
var _gimmick_toggle: bool = false
var _shout_pending: float = -1.0
const S4_GIMMICK_INTERVAL := 12.0
const S4_SHOUT_TELEGRAPH := 1.0
const S4_SHOUT_ANGRY_SEC := 4.0
const S4_ROPE_RUN_SPEED := 280.0
const S4_ROPE_RUN_SEC := 6.0
## S2ボスのポスト上待機（青ポールの上に立つ。実背景のポール位置に合わせて調整可）
const PERCH_POS_LEFT := Vector2(296.0, 52.0)
const PERCH_POS_RIGHT := Vector2(984.0, 52.0)
const PERCH_MIN_SEC := 4.0    # 最低これだけは待機
const PERCH_MAX_SEC := 20.0   # ザコが残っていてもこれで降臨
var _perch_timer: float = 0.0

## ザコ移動5種サイクル
const MOVE_STYLE_CYCLE := [
	EnemyMain.Behavior.SlowApproach,
	EnemyMain.Behavior.HorizontalLoop,
	EnemyMain.Behavior.VerticalLoop,
	EnemyMain.Behavior.SineWave,
	EnemyMain.Behavior.Yotayota,
]
## ステージごとのザコ種類サイクル（見た目流用）
## S1=ジョバーのみ / S2=ジョバー+ガブリ / S3=ヒートマン・デブ初出 / S4=混成
const STAGE_ZAKO_CYCLE := {
	1: [EnemyMain.EnemyType.Jobber],
	2: [EnemyMain.EnemyType.Jobber, EnemyMain.EnemyType.Gaburi],
	3: [EnemyMain.EnemyType.Heatman, EnemyMain.EnemyType.Jobber, EnemyMain.EnemyType.Debu, EnemyMain.EnemyType.Jobber],
	4: [EnemyMain.EnemyType.Jobber, EnemyMain.EnemyType.Gaburi, EnemyMain.EnemyType.Heatman],
}
## トレーニングモード：ダミー撃破後の復活待ち（>=0でカウント中、1.2秒で再スポーン）
var _training_respawn_timer: float = -1.0

# ステージごとのパラメータ
var stage_params: Dictionary = {}

# ボスHP0でQTE表示中
var qte_scene: PackedScene = preload("res://Scenes/qte_core.tscn")
var current_qte_boss: CharacterBase = null
var qte_node: Node2D = null
## QTE成功後のシーン遷移用（Timerノードで確実に実行・ポーズの影響も受けにくくする）
var _pending_clear_stage: int = 0
var _clear_timer: Timer = null

func _ready() -> void:
	AudioManager.play_battle_bgm()
	# 前ステージのクリア演出でフリーズしたままにならないよう解除
	GameManager.enemies_frozen = false
	# ステージ1誤学習防止ヒントのカウンタを毎ステージ開始時にリセット（KI: 正面衝突の誤学習対処）
	GameManager.reset_stage1_hint_tracking()
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
	
	# BGMは AudioManager（Autoload）で即再生。MainFloor 内プレイヤーは互換用で無効
	
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
		1:  # 雑魚マスク軍団（テスト＝一撃・少数）
			stage_params = {
				"initial_count": 1,
				"total_quota": 6,
				"cap_max": 3,
				"ramp_interval": 6.0,
				"enemy_hp": 2,
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
		1:  # 最初1匹教習→やっちまえで群れ。合計8体でクリア（ボスなし）
			stage_params = {
				"initial_count": 1,
				"total_quota": 8,
				"cap_max": 5,
				"ramp_interval": 8.0,
				"enemy_hp": 24,
				"behavior": 7  # SlowApproach
			}
		2:  # マスクメロンナ（足速く・近づくと距離取り・被弾で超高速離脱）。初期からザコ1体（ガブリ教材）
			stage_params = {
				"initial_count": 2,
				"max_minions": 3,
				"spawn_interval": 18.0,
				"boss_hp": 100,
				"boss_speed": 750.0,
				"minion_hp": 25,
				"behavior": 4  # Flee
			}
		3:  # ユニ帝仮面（ボス＋初期ザコ2体: ヒートマン/ジョバーを最初から見せる）
			stage_params = {
				"initial_count": 3,
				"max_count": 4,
				"spawn_interval": 14.0,
				"boss_hp": 120,
				"boss_speed": 400.0,
				"enemy_hp": 25,
				"behavior": 3  # RandomRange
			}
		4:  # 異論マスク（ボス＋初期ザコ2体: 号令・取り巻き周回が序盤から機能する）
			stage_params = {
				"initial_count": 3,
				"max_count": 4,
				"spawn_interval": 14.0,
				"boss_hp": 180,
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
	
	# S1: 1匹教習→やっちまえ群れ
	if GameManager.current_stage == 1:
		_update_stage1_waves(delta)
	else:
		# S2〜S4は従来どおり定期増援
		spawn_timer += delta
		var interval: float = stage_params.get("spawn_interval", 10.0)
		if spawn_timer >= interval:
			spawn_timer = 0.0
			_spawn_reinforcement()

	# S4ボスギミック
	if GameManager.current_stage == 4:
		_update_stage4_boss_gimmicks(delta)

	# S2〜S4ボス: ポスト上待機→降臨
	if GameManager.current_stage >= 2:
		_update_stage2_perch(delta)

	# ボス共通トップロープ攻撃（低HPで最大2回）
	if GameManager.current_stage >= 2:
		_update_boss_top_rope(delta)

	# 取り巻き周回
	_update_orbit_assignment()

	# クリア判定
	_check_stage_clear()

## S4ボス: 12秒ごとに「号令（予告1秒→全ザコ4秒強化）」と「ロープ走行（強い状態・直角カウンターの的）」を交互に
func _update_stage4_boss_gimmicks(delta: float) -> void:
	var boss := _find_alive_boss()
	if not boss or current_qte_boss != null:
		return
	# 号令の予告中: 時間が来たら発動
	if _shout_pending >= 0.0:
		_shout_pending -= delta
		if _shout_pending < 0.0:
			_do_shout()
		return
	if boss.is_in_down_state():
		return
	_gimmick_timer += delta
	if _gimmick_timer >= S4_GIMMICK_INTERVAL:
		_gimmick_timer = 0.0
		_gimmick_toggle = not _gimmick_toggle
		if _gimmick_toggle:
			_start_shout_telegraph(boss)
		elif not boss.rope_running:
			boss.start_rope_run(randi() % 2 == 0, S4_ROPE_RUN_SPEED, S4_ROPE_RUN_SEC)
			AudioManager.play_sound(AudioManager.PLAYER_ATTACK_SWING, 0, 3)

## 号令の予告: ボスが黄色く光り、警告SE。1秒後に全ザコ強化
func _start_shout_telegraph(boss: EnemyMain) -> void:
	_shout_pending = S4_SHOUT_TELEGRAPH
	if boss.sprite:
		var tw := boss.create_tween()
		tw.tween_property(boss.sprite, "modulate", Color(2.2, 2.0, 0.4, 1.0), 0.15)
		tw.tween_property(boss.sprite, "modulate", Color.WHITE, 0.6)
	AudioManager.play_sound(AudioManager.MASK_WARNING, 0, 2)

func _do_shout() -> void:
	var npcs = _get_npcs_node()
	if not npcs:
		return
	for child in npcs.get_children():
		var em := child as EnemyMain
		if em and not em.is_dead and not em.is_boss:
			em.set_angry_for(S4_SHOUT_ANGRY_SEC)

## S2: ポスト上のボスを監視。ザコ全滅（最低4秒待機後）or 20秒で山なりジャンプ降臨
func _update_stage2_perch(delta: float) -> void:
	var boss := _find_alive_boss()
	if not boss or not boss.is_perched:
		return
	_perch_timer += delta
	var zako_alive := 0
	var npcs = _get_npcs_node()
	if npcs:
		for child in npcs.get_children():
			var em := child as EnemyMain
			if em and not em.is_dead and not em.is_boss:
				zako_alive += 1
	if _perch_timer >= PERCH_MAX_SEC or (_perch_timer >= PERCH_MIN_SEC and zako_alive == 0):
		var subvp := get_node_or_null("../SubViewportContainer/SubViewport")
		var landing := Vector2(640.0, 360.0)
		if subvp:
			var main_floor := subvp.get_node_or_null("MainFloor")
			if main_floor:
				landing = _pick_empty_spot_on_mat(main_floor)
		boss.end_perch(landing)
		AudioManager.play_sound(AudioManager.PLAYER_ATTACK_SWING, 0, 2)

func _find_alive_boss() -> EnemyMain:
	var npcs = _get_npcs_node()
	if not npcs:
		return null
	for child in npcs.get_children():
		var em := child as EnemyMain
		if em and not em.is_dead and em.is_boss:
			return em
	return null

## 取り巻き周回の割り当て: ボス存命＆ザコ残り2体以下のとき、ザコにボスを周回させる
func _update_orbit_assignment() -> void:
	if GameManager.current_stage < 2:
		return
	var npcs = _get_npcs_node()
	if not npcs:
		return
	var boss: EnemyMain = null
	var zako: Array[EnemyMain] = []
	for child in npcs.get_children():
		var em := child as EnemyMain
		if not em or em.is_dead:
			continue
		if em.is_boss:
			boss = em
		else:
			zako.append(em)
	var enable: bool = boss != null and not boss.is_perched and zako.size() > 0 and zako.size() <= 2
	for z in zako:
		z.orbit_boss = boss if enable else null

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
		# ダウン状態の雑魚を1体（最初からダウン・移行条件は後でアルゴリズム）
		_spawn_training_down_enemy_at(base_pos + Vector2(80, 100))
		return
	var count: int = stage_params.get("initial_count", 1)
	var has_boss_stage: bool = GameManager.current_stage >= 2
	for i in range(count):
		var pos: Vector2 = spawn_points[i % spawn_points.size()]
		_spawn_enemy_at(pos, has_boss_stage and i == 0)

## S1: 最初1匹。倒すと「やっちまえー」→群れ突入
func _update_stage1_waves(delta: float) -> void:
	var quota: int = stage_params.get("total_quota", 8)
	var cap_max: int = stage_params.get("cap_max", 5)
	var alive := _get_alive_enemy_count()
	# 教習1匹を倒したら群れフェーズへ
	if _s1_phase == 0 and _s1_spawned >= 1 and alive == 0:
		_s1_phase = 1
		_s1_cap = mini(4, cap_max)
		_show_yatchimae_banner()
		# 一気に数体リングイン
		for _i in range(3):
			if _s1_spawned < quota:
				_spawn_enemy_at(spawn_points[randi() % spawn_points.size()], false)
	if _s1_phase >= 1 and _s1_cap < cap_max:
		_s1_ramp_timer += delta
		if _s1_ramp_timer >= float(stage_params.get("ramp_interval", 8.0)):
			_s1_ramp_timer = 0.0
			_s1_cap += 1
	if _s1_phase >= 1 and _s1_spawned < quota and alive < _s1_cap:
		# たまにペアで出す
		if randf() < 0.35 and _s1_spawned + 1 < quota:
			_spawn_zako_pack(2 if randf() < 0.7 else 3)
		else:
			_spawn_enemy_at(spawn_points[randi() % spawn_points.size()], false)

func _show_yatchimae_banner() -> void:
	GameManager.show_callout_world(Vector2(640, 200), "やっちまえー！！", Color(1.0, 0.35, 0.2, 1.0))
	AudioManager.play_sound(AudioManager.BLOODY_HIT, 0, -4)

## 確定仕様: ロープを走るのはボス＋ザコの左右/上下往復タイプ。移動5種で差別化
func _set_zako_behavior(enemy: EnemyMain, _pos: Vector2) -> void:
	var style: EnemyMain.Behavior = MOVE_STYLE_CYCLE[_reinforce_index % MOVE_STYLE_CYCLE.size()] as EnemyMain.Behavior
	enemy.behavior_type = style
	enemy.patrol_distance_override = 0.0
	enemy.patrol_speed_override = 0.0
	if style == EnemyMain.Behavior.HorizontalLoop:
		enemy.patrol_vertical = false
		enemy.patrol_distance_override = ROPE_PATROL_DISTANCE
		enemy.patrol_speed_override = ROPE_PATROL_SPEED
	elif style == EnemyMain.Behavior.VerticalLoop:
		enemy.patrol_vertical = true
		enemy.patrol_distance_override = ROPE_PATROL_DISTANCE
		enemy.patrol_speed_override = ROPE_PATROL_SPEED

## 2〜3人ペアでスポーン（横or縦）。吹き飛ばされると解散し、後で再整列は緩く追従
func _spawn_zako_pack(count: int) -> void:
	count = clampi(count, 2, 3)
	var pid: int = _next_pack_id
	_next_pack_id += 1
	var formation: int = 0 if randf() < 0.5 else 1
	var base: Vector2 = spawn_points[randi() % spawn_points.size()]
	for i in range(count):
		var offset := Vector2(float(i) * 56.0, 0.0) if formation == 0 else Vector2(0.0, float(i) * 52.0)
		_spawn_enemy_at(base + offset, false)
		# 直前スポーンの敵に pack 情報を付与
		var npcs = _get_npcs_node()
		if npcs and npcs.get_child_count() > 0:
			var last := npcs.get_child(npcs.get_child_count() - 1) as EnemyMain
			if last and not last.is_boss:
				last.pack_id = pid
				last.pack_slot = i
				last.pack_formation = formation

## ザコ種類のパラメータ適用
func _apply_zako_type_params(enemy: EnemyMain, type: EnemyMain.EnemyType) -> void:
	enemy.enemy_type = type
	match type:
		EnemyMain.EnemyType.Gaburi:
			# 小型・低HP（弱り常時は廃止。半キャラ／正面で気持ちよく倒せる）
			enemy.health = maxi(1, int(enemy.health * 0.55))
			_scale_enemy_speed(enemy, 0.85)
		EnemyMain.EnemyType.Heatman:
			_scale_enemy_speed(enemy, 1.1)
			enemy.anger_rate_mult = 1.4
		EnemyMain.EnemyType.Debu:
			enemy.health = maxi(2, enemy.health * 4)
			_scale_enemy_speed(enemy, 0.55)
		_:
			pass

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
		if randf() < 0.4 and current_count + 1 < max_count:
			_spawn_zako_pack(2 if randf() < 0.65 else 3)
		else:
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

## トレーニング用：ダウン状態で1体スポーン（リングインせず指定位置に配置）
func _spawn_training_down_enemy_at(pos: Vector2) -> void:
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
	enemy.is_down = true
	enemy.patrol_distance_override = 0.0
	enemy.patrol_speed_override = 0.0
	enemy.scale = Vector2(1, 1)
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
	var tex_path := _get_enemy_texture_path(1, false)
	_apply_enemy_sprite(enemy, tex_path)

## 敵をスポーン
func _spawn_enemy_at(pos: Vector2, is_boss: bool) -> void:
	if not enemy_scene:
		return
	var enemy := enemy_scene.instantiate() as EnemyMain
	if not enemy:
		return
	# ザコの種類をステージサイクルから決定（ボスは対象外）
	var zako_type: EnemyMain.EnemyType = EnemyMain.EnemyType.Jobber
	if not is_boss:
		zako_type = _next_zako_type()

	# ステージごとのパラメータ設定
	match GameManager.current_stage:
		1:  # 雑魚マスク
			enemy.health = stage_params.get("enemy_hp", 30)
			enemy.stage_number = 1
			enemy.is_boss = false
			enemy.use_qte_on_defeat = false
			_set_zako_behavior(enemy, pos)
			_s1_spawned += 1
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
				enemy.health = stage_params.get("boss_hp", 180)
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
	
	# ザコ種類のパラメータ（HP・速度）を適用（add_childの前＝max_health記録前）
	if not is_boss:
		_apply_zako_type_params(enemy, zako_type)

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
	
	# ステージ・ボス/雑魚に応じた絵を適用（res://Art/Sprites/）。ザコは種類ごとの色＋サイズ差
	var tex_path := _get_enemy_texture_path(GameManager.current_stage, is_boss)
	if not is_boss:
		tex_path = _get_zako_texture_path(zako_type)
	_apply_enemy_sprite(enemy, tex_path)
	if not is_boss:
		_apply_zako_type_visual(enemy, zako_type)
	else:
		_apply_boss_visual_scale(enemy)

	# S2〜S4ボスは開幕ポスト上待機
	if is_boss and GameManager.current_stage >= 2 and not GameManager.training_mode:
		_perch_timer = 0.0
		enemy.start_perch(PERCH_POS_LEFT if randf() < 0.5 else PERCH_POS_RIGHT)

## ボス共通: HP50%/25%付近でトップロープ攻撃（影→滞空→着地。くらうと痛い。かわすとボスダウン）
func _update_boss_top_rope(delta: float) -> void:
	if _top_rope_active:
		_top_rope_timer += delta
		if is_instance_valid(_top_rope_shadow):
			# 影を点滅
			_top_rope_shadow.modulate.a = 0.35 + 0.35 * absf(sin(_top_rope_timer * 8.0))
		if _top_rope_timer >= TOP_ROPE_AIR_SEC:
			_finish_top_rope_attack()
		return
	var boss := _find_alive_boss()
	if not boss or boss.is_perched or boss.awaiting_finisher or boss.is_in_down_state() or current_qte_boss != null:
		return
	if boss.rope_running:
		return
	var ratio := float(boss.health) / maxf(1.0, float(boss.max_health))
	var need := -1
	if _top_rope_count == 0 and ratio <= 0.5:
		need = 0
	elif _top_rope_count == 1 and ratio <= 0.25:
		need = 1
	if need < 0:
		return
	_start_top_rope_attack(boss)

func _start_top_rope_attack(boss: EnemyMain) -> void:
	_top_rope_active = true
	_top_rope_timer = 0.0
	_top_rope_boss = boss
	_top_rope_count += 1
	_top_rope_land_pos = Vector2(randf_range(MAT_LEFT + 80, MAT_RIGHT - 80), randf_range(MAT_TOP + 80, MAT_BOTTOM - 80))
	# ボスを一時退避（ポスト上）＋描画最優先
	boss.is_top_rope_aerial = true
	boss.start_perch(PERCH_POS_LEFT if boss.global_position.x < 640 else PERCH_POS_RIGHT)
	GameManager.show_callout(boss, "トップロープ！！", Color(1.0, 0.4, 0.2, 1.0))
	AudioManager.play_sound(AudioManager.MASK_WARNING, 0, 0)
	# 着地点の影
	_top_rope_shadow = Polygon2D.new()
	_top_rope_shadow.polygon = PackedVector2Array([
		Vector2(-36, -18), Vector2(36, -18), Vector2(36, 18), Vector2(-36, 18)
	])
	_top_rope_shadow.z_index = 5
	_top_rope_shadow.color = Color(0.05, 0.05, 0.05, 0.55)
	var parent: Node = boss.get_parent()
	if parent:
		parent.add_child(_top_rope_shadow)
		_top_rope_shadow.global_position = _top_rope_land_pos

func _finish_top_rope_attack() -> void:
	_top_rope_active = false
	if is_instance_valid(_top_rope_shadow):
		_top_rope_shadow.queue_free()
	_top_rope_shadow = null
	var boss := _top_rope_boss
	_top_rope_boss = null
	if not is_instance_valid(boss) or boss.is_dead:
		return
	boss.is_top_rope_aerial = false
	# 降臨
	boss.is_perched = false
	boss.z_index = 0
	boss.global_position = _top_rope_land_pos
	boss.velocity = Vector2.ZERO
	if boss.fsm:
		boss.fsm.force_change_state("enemy_idle_state")
	# 着地点付近のプレイヤーにダメージ / いなければボスがダウン
	var hit_player := false
	for node in get_tree().get_nodes_in_group("Player"):
		var p := node as CharacterBase
		if not is_instance_valid(p) or p.is_dead:
			continue
		if p.global_position.distance_to(_top_rope_land_pos) <= 70.0:
			hit_player = true
			if p.has_method("take_damage_from_enemy"):
				p.take_damage_from_enemy(TOP_ROPE_DAMAGE)
			elif p.has_method("_take_damage"):
				p._take_damage(TOP_ROPE_DAMAGE)
			GameManager.show_callout(p, "直撃！！", Color(1.0, 0.2, 0.2, 1.0))
	if hit_player:
		AudioManager.play_sound(AudioManager.BLOODY_HIT, 0, -1)
	else:
		GameManager.show_callout(boss, "空振り！", Color(0.5, 1.0, 0.5, 1.0))
		boss.enter_down(EnemyMain.GRAZE_DOWN_SEC)
		AudioManager.play_sound(AudioManager.PLAYER_ATTACK_SWING, 0, -2)

## ザコ種類ごとのスプライト（マスク色で差別化。小型同一顔は廃止）
func _get_zako_texture_path(type: EnemyMain.EnemyType) -> String:
	match type:
		EnemyMain.EnemyType.Heatman:
			return "res://Art/Sprites/m_man_r_l1.png"  # 赤マスク
		EnemyMain.EnemyType.Gaburi:
			return "res://Art/Sprites/m_man_b_l1.png"  # 青ベース＋後で体色変調
		_:
			return "res://Art/Sprites/m_man_b_l1.png"  # ジョバー／デブ

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

## ザコの種類をステージのサイクルから順番に取る
func _next_zako_type() -> EnemyMain.EnemyType:
	var cycle: Array = STAGE_ZAKO_CYCLE.get(GameManager.current_stage, [EnemyMain.EnemyType.Jobber])
	var t: EnemyMain.EnemyType = cycle[_reinforce_index % cycle.size()]
	_reinforce_index += 1
	return t

## ザコ見た目: 小型同一顔は廃止。色とサイズで差別化。ボスはデブ級サイズ
const BOSS_VISUAL_SCALE := 1.35

func _apply_zako_type_visual(enemy: EnemyMain, type: EnemyMain.EnemyType) -> void:
	var sprite := enemy.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if not sprite:
		return
	match type:
		EnemyMain.EnemyType.Gaburi:
			enemy.body_tint = Color(0.75, 1.15, 0.85, 1.0)
		EnemyMain.EnemyType.Heatman:
			enemy.body_tint = Color(1.1, 0.95, 0.95, 1.0)
		EnemyMain.EnemyType.Debu:
			sprite.scale *= BOSS_VISUAL_SCALE
			enemy.body_tint = Color(1.05, 1.0, 0.9, 1.0)
		_:
			enemy.body_tint = Color.WHITE
	sprite.modulate = enemy.body_tint

func _apply_boss_visual_scale(enemy: EnemyMain) -> void:
	var sprite := enemy.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite:
		sprite.scale *= BOSS_VISUAL_SCALE

func _scale_enemy_speed(enemy: EnemyMain, mult: float) -> void:
	var wander = enemy.get_node_or_null("FSM/enemy_wander_state")
	if wander and "move_speed" in wander:
		wander.move_speed *= mult
	var chase = enemy.get_node_or_null("FSM/enemy_chase_state")
	if chase and "move_speed" in chase:
		chase.move_speed *= mult

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
	# ステージ1: クリア条件＝合計 total_quota 体を倒し切る（倒すと即補充されるため「のこり総数」をHUDへ）
	if GameManager.current_stage == 1:
		var quota: int = stage_params.get("total_quota", 10)
		GameManager.stage1_alive_enemy_count = alive
		GameManager.stage1_remaining_total = quota - _s1_spawned + alive
		if _s1_spawned < quota:
			return  # まだ全部出し切っていない（倒しても即補充される段階）
	if alive == 0 and not stage_cleared:
		stage_cleared = true
		_on_stage_clear()

## ボスHP0：QTE開始
func _on_boss_defeated_for_qte(who: CharacterBase) -> void:
	if current_qte_boss != null or stage_cleared:
		return
	current_qte_boss = who
	who.is_dead = true  # 気絶扱いで動かさない
	# QTE中は敵全員を静止させる（FSMはis_deadを見ないため、凍結で確実に止める）。
	# 成功時は _on_stage_clear が frozen を立て直し、失敗時は _on_qte_failed で解除する
	GameManager.enemies_frozen = true
	if who is EnemyMain:
		var boss_em := who as EnemyMain
		boss_em.stop_rope_run()
		boss_em.velocity = Vector2.ZERO
	
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
	# 死亡フローを CharacterBase._die() に一元化（KI-05）。
	# マスク飛び演出＋1秒後に自動 queue_free されるので直接 free しない
	if current_qte_boss and is_instance_valid(current_qte_boss):
		current_qte_boss.is_dead = false  # _die() の二重実行ガードを通すため一旦戻す
		current_qte_boss._die()
	current_qte_boss = null
	qte_node = null
	stage_cleared = true
	# 残ザコは逃げ帰る
	_flee_remaining_zakos()
	
	# 画面フラッシュ＋ファンファーレを再生し、awaitを使わずタイマーでクリア画面へ（ステージ3後フリーズ対策）
	_play_clear_flash_and_fanfare()
	_on_stage_clear()

func _flee_remaining_zakos() -> void:
	var npcs = _get_npcs_node()
	if not npcs:
		return
	for child in npcs.get_children():
		var em := child as EnemyMain
		if em and not em.is_dead and not em.is_boss:
			em.behavior_type = EnemyMain.Behavior.Flee
			if em.fsm:
				em.fsm.force_change_state("enemy_flee_state")
			em.super_flee_remaining = 3.0

func _on_qte_failed() -> void:
	# QTE失敗＝HP1で再開
	GameManager.enemies_frozen = false
	if current_qte_boss and is_instance_valid(current_qte_boss):
		current_qte_boss.health = 1
		current_qte_boss.is_dead = false
		if current_qte_boss.healthbar:
			current_qte_boss.healthbar.value = current_qte_boss.health
		if current_qte_boss is EnemyMain:
			var bem := current_qte_boss as EnemyMain
			bem.awaiting_finisher = false
			bem.down_remaining = 0.0
			if bem.fsm:
				bem.fsm.force_change_state("enemy_idle_state")
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

## ステージクリア（Timerノードで1.2秒後に遷移。create_timer のコールバックが失われる不具合を避ける）
## 全ステージ共通：ステージクリア画面へ→キーで次へ（4の次はエンディング）
func _on_stage_clear() -> void:
	# クリア確定後は敵を止め、プレイヤーを無敵にする（遷移までの1.2秒間に被弾死しないように: KI-06）
	GameManager.enemies_frozen = true
	for node in get_tree().get_nodes_in_group("Player"):
		if node and node.has_method("set_invincible_for"):
			node.set_invincible_for(5.0)
	_pending_clear_stage = GameManager.current_stage
	if _clear_timer != null and is_instance_valid(_clear_timer):
		_clear_timer.queue_free()
	_clear_timer = Timer.new()
	_clear_timer.wait_time = 1.2
	_clear_timer.one_shot = true
	_clear_timer.process_callback = Timer.TIMER_PROCESS_PHYSICS
	_clear_timer.process_mode = PROCESS_MODE_ALWAYS
	add_child(_clear_timer)
	_clear_timer.timeout.connect(_on_clear_timer_timeout)
	_clear_timer.start()

func _on_clear_timer_timeout() -> void:
	var stage := _pending_clear_stage
	_pending_clear_stage = 0
	if _clear_timer and is_instance_valid(_clear_timer):
		_clear_timer.queue_free()
		_clear_timer = null
	GameManager.clear_stage(stage)
	get_tree().change_scene_to_file("res://Scenes/UI/StageClear.tscn")
