extends CharacterBase
class_name EnemyMain

## 移動パターン: Idle / 上下ロープ / 左右ロープ / 旧ランダム / 逃走 / サイン波 / ヨタヨタ / ゆっくり接近
enum Behavior { Idle, VerticalLoop, HorizontalLoop, RandomRange, Flee, SineWave, Yotayota, SlowApproach }

## 敵の状態（攻略性向上）：通常・怒り（=強い）・弱り
enum EnemyState { Normal, Angry, Weak }

## 敵タイプ（確定仕様v1.0）: Jobber=白ザコ / Gaburi=常時弱り小型 / Heatman=無被弾で自己強化 / Debu=大型高HP
enum EnemyType { Jobber, Gaburi, Heatman, Debu }

## 敵のマット範囲（PlayerMainより片側16px狭い＝敵がロープ端に張り付かない）
const MAT_LEFT := 296.0
const MAT_RIGHT := 984.0
const MAT_TOP := 138.0
const MAT_BOTTOM := 614.0
const BODY_HALF := 32.0

@onready var fsm = $FSM as FiniteStateMachine
var player_in_range = false
## 突進攻撃時ダメージ倍率（1.0＝通常）
var charge_damage_mult := 1.0
## Patrol状態で上下=true／左右=false（VerticalLoop / HorizontalLoop 用）
var patrol_vertical := false
## ロープ間往復用：>0 のとき Patrol の patrol_distance として使用
var patrol_distance_override: float = 0.0
## ロープ間往復用：>0 のとき Patrol の move_speed として使用（プレイヤーより少し遅い程度）
var patrol_speed_override: float = 0.0

## 向いている左右（1=右, -1=左）。Turn() で更新。
var facing_dir_sign: int = 1
## Turn() 内で使う経過時間（ステージ3ボスの左右反転ディレイ用）
var _turn_delta: float = 0.0
var _boss_flip_timer: float = 0.0
const BOSS3_FLIP_DELAY := 1.0

@export var behavior_type: Behavior = Behavior.Idle
@export var attack_node : Node
@export var chase_node : Node

## ステージ番号（特殊処理用）
var stage_number: int = 1
## ボスキャラか（特殊行動用）
var is_boss: bool = false
## トレーニング用ダミー（動かず攻撃しない・プレイヤー検知でチェースに移行しない）
var is_training_dummy: bool = false
## ダウン状態で開始（動かず攻撃せず・赤フラッシュのまま。移行条件は後でアルゴリズム）
var is_down: bool = false
## リングイン着地目標（スポーン時に設定すると右端から走り込み→山なりジャンプでここに着地）
var ring_in_landing_pos: Vector2 = Vector2.ZERO
## 敵の状態（通常／怒り／弱り）。トレーニングダミーはスポーン時に固定され変動しない
var enemy_state: EnemyState = EnemyState.Normal
## 怒り：残りHPがこの割合以下で発生（アルゴリズム・HP起因は継続）
const ANGRY_HP_RATIO := 0.4
## 怒り：スポーンからこの秒数経過でも発生（アルゴリズム）
const ANGRY_TIME_SEC := 15.0
## 時間経過起因の怒りはこの秒数だけ続き、その後タイマーがリセットされて通常に戻る（波状の怒り）
const ANGRY_TIME_DURATION := 8.0
## 弱り：パワーエサのみ（アイテム限定）
const WEAK_DURATION_SEC := 8.0
var _state_timer: float = 0.0
var _weak_until: float = 0.0

## ===== 新方針: 状態経済 =====
## 敵タイプ（見た目流用。攻略差は移動パターン＋怒り）
var enemy_type: EnemyType = EnemyType.Jobber
## 強い（Angry）の明示タイマー
var _angry_until: float = 0.0
## ザコの周期怒り（ランダム間隔で赤化）
const ZAKO_ANGER_MIN_GAP := 10.0
const ZAKO_ANGER_MAX_GAP := 16.0
const ZAKO_ANGER_DURATION := 7.0
const BOSS_ANGER_DURATION := 9.0
var _anger_cycle_timer: float = 0.0
var _next_anger_gap: float = 12.0
## うに帝は怒り発生が早い
var anger_rate_mult: float = 1.0
## ヒートマン互換（発熱は怒り周期に統合しつつ残す）
const HEAT_IGNITE_SEC := 10.0
const HEAT_DURATION_SEC := 10.0
var _heat_timer: float = 0.0
var halfcar_hit_count: int = 0
## かすりダウン秒数 / 通常ダウン
const GRAZE_DOWN_SEC := 2.5
const DOWN_DURATION_SEC := 2.5
const WAKEUP_WEAK_SEC := 0.0
var down_remaining: float = 0.0
## ボスHP0後、ジャンプ待ち
var awaiting_finisher: bool = false
## ペア編隊
var pack_id: int = -1
var pack_slot: int = 0
var pack_formation: int = 0  # 0=横 1=縦
var pack_spacing: float = 56.0
## サイン波用
var _sine_phase: float = 0.0
var _sine_axis_horizontal: bool = true
## ヨタヨタ用
var _yota_dir: Vector2 = Vector2.RIGHT
var _yota_move_left: float = 0.0
var _yota_pause_left: float = 0.0
## 怒り湯気
var _steam_particles: GPUParticles2D = null
## 取り巻き周回: 対象ボス（StageControllerが設定。ボス存命＆ザコ残少で周回移動）
var orbit_boss: EnemyMain = null
var _orbit_angle: float = 0.0
const ORBIT_RADIUS := 110.0
const ORBIT_ANGULAR_SPEED := 1.6
## ポスト上待機（S2ボス）: 実際の青ポールの上に立ち、降りてくるまで当たり判定なし
var is_perched: bool = false
var _perch_pos := Vector2.ZERO
## ボスのロープ走行（S4）: この間は強い扱い＋直角カウンター対象
var rope_running: bool = false
## ロープ走行の軸（true=左右往復）。直角カウンター判定に使う
var rope_run_horizontal: bool = true
var _rope_run_remaining: float = 0.0
## 怒り時の色（真っ赤・読みやすさ優先）
const STATE_ANGRY_MODULATE := Color(2.2, 0.25, 0.2, 1.0)
## 弱り時の色
const STATE_WEAK_MODULATE := Color(0.5, 0.6, 1.4, 1.0)
## ザコタイプの体色ベース（通常時の modulate に乗算）
var body_tint := Color.WHITE
## 被弾後この秒数だけ超高速で離脱（FleeStateで使用）
var super_flee_remaining: float = 0.0
## プレイヤーと接したあとこの秒数だけモーション2倍速
var _player_contact_timer: float = 0.0
const PLAYER_CONTACT_SPEED_SEC := 2.0
## 空中攻撃ノックバックのティーン中（押し離し・クランプをスキップ）
var _aerial_knockback_animating: bool = false

func _process(delta: float) -> void:
	_turn_delta = delta
	if super_flee_remaining > 0.0:
		super_flee_remaining = maxf(0.0, super_flee_remaining - delta)
	if _player_contact_timer > 0.0:
		_player_contact_timer = maxf(0.0, _player_contact_timer - delta)
	_weak_until = maxf(0.0, _weak_until - delta)
	_angry_until = maxf(0.0, _angry_until - delta)
	# ザコ周期怒り（Gaburi以外）。うに帝は anger_rate_mult で早め
	if not is_training_dummy and not is_dead and not is_boss and enemy_type != EnemyType.Gaburi:
		if _angry_until <= 0.0 and _weak_until <= 0.0 and not is_in_down_state() and not awaiting_finisher:
			_anger_cycle_timer += delta * anger_rate_mult
			if _anger_cycle_timer >= _next_anger_gap:
				_anger_cycle_timer = 0.0
				_next_anger_gap = randf_range(ZAKO_ANGER_MIN_GAP, ZAKO_ANGER_MAX_GAP)
				set_angry_for(ZAKO_ANGER_DURATION)
	# ヒートマン: 無被弾が続くと発熱（強い化）
	if enemy_type == EnemyType.Heatman and not is_training_dummy and not is_dead:
		if _angry_until <= 0.0 and _weak_until <= 0.0 and not is_in_down_state():
			_heat_timer += delta
			if _heat_timer >= HEAT_IGNITE_SEC:
				_heat_timer = 0.0
				_ignite()
	# ボス（うに帝）: 高頻度で怒り（ポスト上の高みの見物中は発動しない）
	if is_boss and stage_number == 3 and not is_dead and not awaiting_finisher and not is_perched:
		if _angry_until <= 0.0 and _weak_until <= 0.0 and not is_in_down_state():
			_anger_cycle_timer += delta * 1.6
			if _anger_cycle_timer >= 8.0:
				_anger_cycle_timer = 0.0
				set_angry_for(BOSS_ANGER_DURATION)
	# 異論マスクも怒り周期（ポスト上は発動しない）
	if is_boss and stage_number == 4 and not is_dead and not awaiting_finisher and not is_perched:
		if _angry_until <= 0.0 and _weak_until <= 0.0 and not is_in_down_state() and not rope_running:
			_anger_cycle_timer += delta * 1.4
			if _anger_cycle_timer >= 9.0:
				_anger_cycle_timer = 0.0
				set_angry_for(BOSS_ANGER_DURATION)
	_update_steam_effect()
	# ボスのロープ走行: 時間切れで停止（直角カウンターでも停止する）
	if rope_running and not is_dead:
		_rope_run_remaining -= delta
		if _rope_run_remaining <= 0.0:
			stop_rope_run()
	if not is_training_dummy:
		_state_timer += delta
		_update_enemy_state()
	# 取り巻き周回: 通常移動系ステートならチェースに寄せて周回移動させる
	if orbit_active() and fsm and fsm.current_state:
		var _sn := String(fsm.current_state.name).to_lower()
		if _sn == "enemy_idle_state" or _sn == "enemy_patrol_state" or _sn == "enemy_wander_state":
			fsm.force_change_state("enemy_chase_state")
	super._process(delta)
	if is_dead or GameManager.enemies_frozen:
		return
	# トップロープ滞空中は StageController がマット平面座標と擬似高さを制御
	if is_top_rope_aerial:
		velocity = Vector2.ZERO
		apply_top_rope_visual_height()
		if sprite:
			sprite.speed_scale = 4.0
			sprite.modulate = body_tint
		return
	var in_ring_in: bool = fsm.current_state and fsm.current_state.name.to_lower() == "enemy_ring_in_state"
	var in_down: bool = fsm.current_state and fsm.current_state.name.to_lower() == "enemy_down_state"
	# ノックバックティーン中は押し離しをスキップ（半キャラずらしで飛ばす距離が短くならないように）
	var in_knockback_stun: bool = knockback_stun_remaining > 0.0
	if not in_ring_in and not _aerial_knockback_animating and not in_down and not in_knockback_stun:
		_push_apart_from_other_enemies()
	# 状態に応じた色。半キャラずらしヒット中は敵の絵自体を白く（modulate で毎フレーム上書き）
	var now := Time.get_ticks_msec() / 1000.0
	if sprite and now < halfcar_white_until and not in_down:
		sprite.modulate = Color(2.0, 2.0, 2.0, 1.0)
	elif sprite and in_down:
		# ダウン中は赤めを維持（かすり黄フラッシュの「白に戻す」Tweenで消えて見えないのを防ぐ）
		sprite.modulate = Color(1.4, 0.4, 0.4, 1.0)
	elif sprite and is_perched:
		# 高みの見物: 赤／青にならない通常色
		sprite.modulate = body_tint
	elif sprite and not invincible and knockback_stun_remaining <= 0.0:
		sprite.modulate = _get_state_modulate()
	# アニメ速度：ポスト上は超ゆっくり／飛んでいるとき4倍速／接触直後2倍速
	if sprite:
		if is_perched:
			sprite.speed_scale = 0.2
		elif fsm.current_state and fsm.current_state.name.to_lower() == "enemy_launched_state":
			sprite.speed_scale = 4.0
		elif _player_contact_timer > 0.0:
			sprite.speed_scale = 2.0
		else:
			sprite.speed_scale = 1.0
	# ポスト上待機中は位置を固定（FSMが動かそうとしても毎フレーム戻す）・マットクランプもしない
	if is_perched:
		velocity = Vector2.ZERO
		global_position = _perch_pos
		return
	# 敵が絶対にロープ外に出ないようにクランプ（リングイン・空中ノックバック・ダウン・ノックバック中はスキップ）
	if not in_ring_in and not _aerial_knockback_animating and not in_down and not in_knockback_stun:
		global_position.x = clampf(global_position.x, MAT_LEFT, MAT_RIGHT)
		global_position.y = clampf(global_position.y, MAT_TOP, MAT_BOTTOM)

func Turn() -> void:
	if not sprite:
		return
	# flipped_horizontal を考慮した基準方向（+1=右を向く）
	var base_dir := -1 if flipped_horizontal == true else 1
	
	# ステージ3ボスだけは左右反転を少し遅らせる（怒り中はさらに長く＝後ろが取りやすい）
	if is_boss and stage_number == 3:
		var flip_delay: float = BOSS3_FLIP_DELAY
		if enemy_state == EnemyState.Angry:
			flip_delay = BOSS3_FLIP_DELAY * 1.8
		var move_dir := 0
		if velocity.x < -0.1:
			move_dir = -1
		elif velocity.x > 0.1:
			move_dir = 1
		
		if move_dir != 0 and move_dir != facing_dir_sign:
			_boss_flip_timer += _turn_delta
			if _boss_flip_timer >= flip_delay:
				facing_dir_sign = move_dir
				_boss_flip_timer = 0.0
		else:
			_boss_flip_timer = 0.0
		
		if facing_dir_sign != 0:
			sprite.scale.x = base_dir * float(facing_dir_sign) * absf(sprite.scale.x)
		return
	
	# 通常敵: 速度方向に即座に向きを変える（従来どおり）
	if velocity.x < -0.1:
		sprite.scale.x = -base_dir * absf(sprite.scale.x)
		facing_dir_sign = -1
	elif velocity.x > 0.1:
		sprite.scale.x = base_dir * absf(sprite.scale.x)
		facing_dir_sign = 1

## 敵同士が重なっていたら互いにずらす（マット内にクランプ）。重なり判定は少し緩めに。
func _push_apart_from_other_enemies() -> void:
	var my_pos := global_position
	for node in get_tree().get_nodes_in_group("Enemy"):
		if node == self or not is_instance_valid(node):
			continue
		var other := node as CharacterBase
		if not other or other.is_dead:
			continue
		if other is EnemyMain and ((other as EnemyMain).is_rope_launched() or (other as EnemyMain).is_perched):
			continue
		var o_pos := other.global_position
		var dx := my_pos.x - o_pos.x
		var dy := my_pos.y - o_pos.y
		# 実際に重なっている時だけずらす（1.5倍の距離＝60ドット以内）
		var overlap_threshold := BODY_HALF * 1.5
		if absf(dx) >= overlap_threshold or absf(dy) >= overlap_threshold:
			continue
		# 重なっている：中心間ベクトルで互いに半分ずつずらす
		var dist := Vector2(dx, dy).length()
		if dist < 0.01:
			dist = 0.01
		var away := Vector2(dx, dy) / dist
		var overlap := overlap_threshold - dist
		if overlap <= 0:
			continue
		var push := away * (overlap * 0.5)
		var new_my := my_pos + push
		var new_other := o_pos - push
		new_my.x = clampf(new_my.x, MAT_LEFT, MAT_RIGHT)
		new_my.y = clampf(new_my.y, MAT_TOP, MAT_BOTTOM)
		global_position = new_my
		# ダウン中の敵は動かさない
		if other is EnemyMain and (other as EnemyMain).is_in_down_state():
			break
		new_other.x = clampf(new_other.x, MAT_LEFT, MAT_RIGHT)
		new_other.y = clampf(new_other.y, MAT_TOP, MAT_BOTTOM)
		other.global_position = new_other
		break

func _ready():
	super()
	if get("flash_effect_white_texture") == null and ResourceLoader.exists("res://Art/Sprites/Effect/effect_white_m_man_r_l1.png"):
		set("flash_effect_white_texture", load("res://Art/Sprites/Effect/effect_white_m_man_r_l1.png") as Texture2D)
	took_damage.connect(_on_took_damage)
	await get_tree().process_frame
	# ポスト上待機で開始（S2ボス: StageControllerがadd_child直後にstart_perchを呼ぶ）
	if is_perched:
		fsm.force_change_state("enemy_idle_state")
		return
	# ダウン状態で開始（トレーニング用デモ：動かず・赤フラッシュのまま。自動では起き上がらない）
	if is_down:
		down_remaining = 999999.0
		fsm.force_change_state("enemy_down_state")
		return
	# リングイン着地目標が設定されていれば右端から走り込み→山なりジャンプ（最優先）
	if ring_in_landing_pos != Vector2.ZERO:
		fsm.force_change_state("enemy_ring_in_state")
		ring_in_landing_pos = Vector2.ZERO
		return
	match behavior_type:
		Behavior.Idle:
			fsm.force_change_state("enemy_idle_state")
		Behavior.VerticalLoop:
			patrol_vertical = true
			fsm.force_change_state("enemy_patrol_state")
		Behavior.HorizontalLoop:
			patrol_vertical = false
			fsm.force_change_state("enemy_patrol_state")
		Behavior.RandomRange, Behavior.Yotayota, Behavior.SineWave, Behavior.SlowApproach:
			fsm.force_change_state("enemy_wander_state")
		Behavior.Flee:
			fsm.force_change_state("enemy_flee_state")

func _get_state_modulate() -> Color:
	var base: Color
	match enemy_state:
		EnemyState.Angry:
			var pulse := 0.15 * sin(Time.get_ticks_msec() / 90.0)
			base = Color(STATE_ANGRY_MODULATE.r + pulse, STATE_ANGRY_MODULATE.g, STATE_ANGRY_MODULATE.b, 1.0)
		EnemyState.Weak:
			base = STATE_WEAK_MODULATE
		_:
			base = body_tint
	return base

## 弱り＝パワーエサ（タイマー）のみ。強い＝怒りタイマー / ロープ走行 / S3ボス低HP
func _update_enemy_state() -> void:
	if _weak_until > 0.0:
		enemy_state = EnemyState.Weak
		return
	if _angry_until > 0.0 or rope_running:
		enemy_state = EnemyState.Angry
		return
	if is_boss and stage_number == 3:
		var hp_ratio := float(health) / maxf(1.0, float(max_health))
		if hp_ratio <= ANGRY_HP_RATIO:
			enemy_state = EnemyState.Angry
			return
	enemy_state = EnemyState.Normal

## 状態による移動速度倍率（Angry=速い / Weak=遅い）。各ステートの移動処理で乗算する
func state_speed_mult() -> float:
	match enemy_state:
		EnemyState.Angry:
			return 1.35
		EnemyState.Weak:
			return 0.5
		_:
			return 1.0

## 状態による与ダメージ倍率（Angry=1.5倍）。EnemyAttackState で乗算する
func state_damage_mult() -> float:
	return 1.5 if enemy_state == EnemyState.Angry else 1.0

## 半キャラずらしが「通常角度では無効」か（Angry中。後ろ半キャラとかすりは別判定）
func is_shoulder_immune() -> bool:
	return enemy_state == EnemyState.Angry

## 弱り中か（タイマーを即時参照。状態更新前でも正しい）
func is_weak_state() -> bool:
	return _weak_until > 0.0

## プレイヤーが敵の背後から半キャラを狙っているか（facing の反対側）
func is_rear_approach_from(player_pos: Vector2) -> bool:
	var facing: int = facing_dir_sign
	if facing == 0:
		facing = 1
	var side: float = signf(player_pos.x - global_position.x)
	if absf(side) < 0.01:
		return false
	return int(side) == -facing

## かすり → 5秒ダウン（弱りではない）
func notify_graze_hit() -> void:
	if awaiting_finisher or is_dead:
		return
	GameManager.show_callout(self, "かすりダウン！", Color(1.0, 0.9, 0.3, 1.0))
	enter_down(GRAZE_DOWN_SEC)

## ジャンプ踏み（弱り化は廃止）
func notify_stepped_on() -> void:
	pass

## 指定秒数だけ弱り状態にする（パワーエサ）。赤は解除
func set_weak_for(duration_sec: float) -> void:
	clear_angry()
	_weak_until = maxf(_weak_until, duration_sec)
	_update_enemy_state()

## 半キャラ蓄積弱りは廃止（互換のため空）
func notify_halfcar_hit() -> void:
	pass

## 指定秒数だけ強い（Angry）状態にする
func set_angry_for(duration_sec: float) -> void:
	if _weak_until > 0.0:
		return
	_angry_until = maxf(_angry_until, duration_sec)

## 強い状態を強制解除
func clear_angry() -> void:
	_angry_until = 0.0
	_heat_timer = 0.0

## ヒートマン発熱
func _ignite() -> void:
	set_angry_for(HEAT_DURATION_SEC)
	if sprite:
		var tw := create_tween()
		tw.tween_property(sprite, "modulate", Color(2.4, 0.4, 0.2, 1.0), 0.1)
		tw.tween_property(sprite, "modulate", Color.WHITE, 0.2)
	AudioManager.play_sound(AudioManager.BLOODY_HIT, 0, -6)

## ダウン（寝）状態に入る
func enter_down(duration_sec: float = DOWN_DURATION_SEC) -> void:
	if is_dead:
		return
	down_remaining = duration_sec
	halfcar_hit_count = 0
	clear_angry()
	if rope_running:
		rope_running = false
		patrol_speed_override = 0.0
		_rope_run_remaining = 0.0
	fsm.force_change_state("enemy_down_state")

## ボスHP0: 死亡せずダウンし、ジャンプ待ち
func enter_finisher_down() -> void:
	if awaiting_finisher:
		return
	awaiting_finisher = true
	health = 0
	if healthbar:
		healthbar.value = 0
	is_dead = false
	enter_down(99.0)
	GameManager.show_callout(self, "フィニッシュ待ち！", Color(1.0, 0.75, 0.2, 1.0))

## ジャンプ追撃でQTEへ
func request_finisher_qte() -> void:
	if not is_boss:
		return
	awaiting_finisher = false
	defeated_for_qte.emit(self)

func _update_steam_effect() -> void:
	var want_steam: bool = enemy_state == EnemyState.Angry and not is_dead and not is_in_down_state() and not is_perched
	if want_steam:
		if _steam_particles == null or not is_instance_valid(_steam_particles):
			_steam_particles = GPUParticles2D.new()
			_steam_particles.name = "AngrySteam"
			_steam_particles.amount = 18
			_steam_particles.lifetime = 0.7
			_steam_particles.explosiveness = 0.05
			_steam_particles.randomness = 0.4
			_steam_particles.position = Vector2(0, -28)
			var mat := ParticleProcessMaterial.new()
			mat.direction = Vector3(0, -1, 0)
			mat.spread = 35.0
			mat.initial_velocity_min = 20.0
			mat.initial_velocity_max = 55.0
			mat.gravity = Vector3(0, -40, 0)
			mat.scale_min = 1.5
			mat.scale_max = 3.0
			mat.color = Color(1.0, 0.55, 0.35, 0.7)
			_steam_particles.process_material = mat
			add_child(_steam_particles)
		_steam_particles.emitting = true
	elif _steam_particles and is_instance_valid(_steam_particles):
		_steam_particles.emitting = false

## 弱り正面ブラスト／吹き飛ばし→ダウン
const BLAST_DOWN_TWEEN_DURATION := 0.45
func blast_to_down(from_dir: Vector2 = Vector2.ZERO) -> void:
	if is_dead:
		return
	_aerial_knockback_animating = true
	var base_angle: float = from_dir.angle() if from_dir.length() > 0.1 else randf() * TAU
	var angle: float = base_angle + randf_range(-0.6, 0.6)
	var dist: float = randf_range(150.0, 300.0)
	var target: Vector2 = global_position + Vector2(cos(angle), sin(angle)) * dist
	target.x = clampf(target.x, MAT_LEFT + 20.0, MAT_RIGHT - 20.0)
	target.y = clampf(target.y, MAT_TOP + 20.0, MAT_BOTTOM - 20.0)
	velocity = Vector2.ZERO
	knockback_stun_remaining = BLAST_DOWN_TWEEN_DURATION + 0.1
	set_invincible_for(BLAST_DOWN_TWEEN_DURATION + 0.2)
	var sprite_node := sprite
	var spin_from: float = sprite_node.rotation_degrees if sprite_node else 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "global_position", target, BLAST_DOWN_TWEEN_DURATION)
	if sprite_node:
		tw.tween_property(sprite_node, "rotation_degrees", spin_from + 1080.0, BLAST_DOWN_TWEEN_DURATION)
	tw.chain().tween_callback(_on_blast_to_down_done)
	register_motion_tween(tw)
	z_index = 100

func _on_blast_to_down_done() -> void:
	_aerial_knockback_animating = false
	z_index = 0
	if sprite and is_instance_valid(sprite):
		sprite.rotation_degrees = 0.0
	global_position.x = clampf(global_position.x, MAT_LEFT, MAT_RIGHT)
	global_position.y = clampf(global_position.y, MAT_TOP, MAT_BOTTOM)
	enter_down()

## 場外KO演出: SE＋技名のみ。吹っ飛び本体は _die() のマスク飛び（拡大しながら飛ぶ）に一本化
## （旧: 本体コピーの直線吹っ飛びは「直線で飛ぶのは無くす」指示で廃止 2026-07-17）
func fly_out_visual(_dir: Vector2) -> void:
	AudioManager.play_sound(AudioManager.KILL_MASK, 0, 0)
	GameManager.show_callout(self, "場外KO！", Color(1.0, 0.4, 0.3, 1.0))

## ボスのロープ走行を開始（S4: 走行中は強い扱い。直角カウンターで停止＋ダウン）
func start_rope_run(vertical: bool, speed: float, duration_sec: float) -> void:
	if is_dead or is_in_down_state():
		return
	rope_running = true
	rope_run_horizontal = not vertical
	patrol_vertical = vertical
	patrol_speed_override = speed
	_rope_run_remaining = duration_sec
	fsm.force_change_state("enemy_patrol_state")

func stop_rope_run() -> void:
	if not rope_running:
		return
	rope_running = false
	patrol_speed_override = 0.0
	_rope_run_remaining = 0.0
	if not is_dead and not is_in_down_state() and fsm:
		fsm.force_change_state("enemy_idle_state")

## ポスト上待機を開始（S2ボス等）。降りてくるまで当たり判定なし・不動・高みの見物
func start_perch(pos: Vector2) -> void:
	is_perched = true
	_perch_pos = pos
	velocity = Vector2.ZERO
	global_position = pos
	z_index = 20  # ロープ・背景より手前に立って見せる
	clear_angry()
	_weak_until = 0.0
	enemy_state = EnemyState.Normal
	if sprite:
		sprite.modulate = body_tint
		sprite.speed_scale = 0.2
		sprite.rotation = 0.0
	if fsm and fsm.current_state:
		fsm.force_change_state("enemy_idle_state")

## ポスト上待機を終了して、リングインの山なりジャンプで指定位置へ降臨
func end_perch(landing: Vector2) -> void:
	if not is_perched:
		return
	is_perched = false
	z_index = 0
	ring_in_landing_pos = landing
	if fsm:
		fsm.force_change_state("enemy_ring_in_state")
		ring_in_landing_pos = Vector2.ZERO

## 取り巻き周回が有効か（ボス存命・自分はザコ）
func orbit_active() -> bool:
	return is_instance_valid(orbit_boss) and not orbit_boss.is_dead and not is_boss

## 周回の目標位置（ボス中心の円周上を回る）
func orbit_target_pos(delta: float) -> Vector2:
	_orbit_angle += ORBIT_ANGULAR_SPEED * delta
	return orbit_boss.global_position + Vector2(cos(_orbit_angle), sin(_orbit_angle)) * ORBIT_RADIUS

## リングイン演出中（スポーン〜着地まで）は true。この間は当たり判定なし・敵として認識しない
func is_ring_in_effect_only() -> bool:
	return fsm.current_state and fsm.current_state.name.to_lower() == "enemy_ring_in_state"

## ロープ飛ばし中（一変向で回転して飛んでいる間）は true。この間は当たり判定なし
func is_rope_launched() -> bool:
	return fsm.current_state and fsm.current_state.name.to_lower() == "enemy_launched_state"

## ダウン状態か（動かず攻撃せず・赤フラッシュのまま）
func is_in_down_state() -> bool:
	return fsm.current_state and fsm.current_state.name.to_lower() == "enemy_down_state"

## ダウン中は描画を最奥に
func is_downed_for_draw() -> bool:
	return is_in_down_state()

## ボスがダメージを受けたら超高速離脱フラグを立てる。ヒートマンは被弾で発熱タイマーがリセットされる
func _on_took_damage(_amount: int) -> void:
	if is_boss:
		super_flee_remaining = 2.5
	_heat_timer = 0.0

# 攻撃後は必ずIdleに戻す
func finished_attacking():
	charge_damage_mult = 1.0
	fsm.change_state(attack_node, "enemy_idle_state")

func _on_detection_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		if GameManager.enemies_frozen:
			return
		if is_training_dummy or is_perched or is_dead:
			return  # ダミー・ポスト上待機・気絶(QTE)中は攻撃・接近しない
		# リングイン中は最優先で入場のみ。ダウン中・リングイン中はプレイヤー検知でチェースに移行しない
		if fsm.current_state:
			var sn: String = String(fsm.current_state.name).to_lower()
			if sn == "enemy_ring_in_state" or sn == "enemy_down_state":
				return
		_player_contact_timer = PLAYER_CONTACT_SPEED_SEC
		player_in_range = true
		# アイドル/パトロール/ワンダー中ならプレイヤーに接近して攻撃（チェース）へ
		if fsm.current_state:
			var state_name: StringName = fsm.current_state.name
			if state_name in ["enemy_idle_state", "enemy_patrol_state", "enemy_wander_state"]:
				fsm.force_change_state("enemy_chase_state")

func _on_detection_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		player_in_range = false

func _die():
	# ヤラレ声はここで一度だけ（半キャラ連打死は damage_effects を通らないため）
	if not is_dead:
		AudioManager.play_sound(AudioManager.ENEMY_HIT, 0, -10)
	super() #calls _die() on base-class CharacterBase

## 空中（飛ばされ・ブラスト吹き飛び・トップロープ滞空）は手前
func is_airborne_for_draw() -> bool:
	if is_top_rope_aerial or is_perched:
		return true
	if _aerial_knockback_animating:
		return true
	if fsm and fsm.current_state:
		var sn: String = String(fsm.current_state.name).to_lower()
		if sn == "enemy_launched_state" or sn == "enemy_ring_in_state":
			return true
	return false
	fsm.force_change_state("enemy_death_state")

## ロープまでノックされたときに呼ぶ。大きくジャンプして画面内のどこかに着地する
func trigger_rope_launch() -> void:
	if is_dead:
		return
	# ブラスト/空中ノックバック演出の途中で飛ばされた場合、演出Tweenのコールバックが
	# killされてフラグ類が残留しないよう防御的にリセット（レビュー指摘#9）
	if _aerial_knockback_animating:
		_aerial_knockback_animating = false
		var body_shape_node := get_node_or_null("BodyCollider") as CollisionShape2D
		if body_shape_node:
			body_shape_node.disabled = false
		collision_mask = 3
		z_index = 0
		if sprite and is_instance_valid(sprite):
			sprite.rotation_degrees = 0.0
	fsm.force_change_state("enemy_launched_state")

## 空中攻撃で踏まれたとき：かすり同様の距離でランダム方向にティーン＋回転（緑フラッシュは呼び元で実施）
const AERIAL_KNOCKBACK_DIST := 90.0
const AERIAL_KNOCKBACK_TWEEN_DURATION := 0.28
const AERIAL_KNOCKBACK_SPIN_DEGREES := 720.0

func trigger_aerial_knockback() -> void:
	_aerial_knockback_animating = true
	var dir := Vector2(cos(randf() * TAU), sin(randf() * TAU))
	var target_pos := global_position + dir * AERIAL_KNOCKBACK_DIST
	var body_shape_node := get_node_or_null("BodyCollider") as CollisionShape2D
	var sprite_node := sprite if sprite else get_node_or_null("AnimatedSprite2D")
	velocity = Vector2.ZERO
	knockback_stun_remaining = AERIAL_KNOCKBACK_TWEEN_DURATION + 0.1
	set_invincible_for(0.6)
	var spin_from: float = sprite_node.rotation_degrees if sprite_node else 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "global_position", target_pos, AERIAL_KNOCKBACK_TWEEN_DURATION)
	if sprite_node:
		tw.tween_property(sprite_node, "rotation_degrees", spin_from + AERIAL_KNOCKBACK_SPIN_DEGREES, AERIAL_KNOCKBACK_TWEEN_DURATION)
	tw.tween_callback(_on_aerial_knockback_done)
	register_motion_tween(tw)
	if body_shape_node:
		body_shape_node.disabled = true
	collision_mask = 1
	z_index = 100

func _on_aerial_knockback_done() -> void:
	_aerial_knockback_animating = false
	var body_shape_node := get_node_or_null("BodyCollider") as CollisionShape2D
	var sprite_node := sprite if sprite else get_node_or_null("Node2D")
	if body_shape_node:
		body_shape_node.disabled = false
	collision_mask = 3
	z_index = 0
	if sprite_node and is_instance_valid(sprite_node):
		sprite_node.rotation_degrees = 0.0
	if _is_outside_mat(global_position) and has_method("trigger_rope_launch"):
		set_invincible_for(1.0)
		trigger_rope_launch()
	else:
		global_position.x = clampf(global_position.x, MAT_LEFT, MAT_RIGHT)
		global_position.y = clampf(global_position.y, MAT_TOP, MAT_BOTTOM)

func _is_outside_mat(p: Vector2) -> bool:
	return p.x < MAT_LEFT or p.x > MAT_RIGHT or p.y < MAT_TOP or p.y > MAT_BOTTOM
