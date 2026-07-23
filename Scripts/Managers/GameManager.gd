extends Node

var money = 0

## グリッドモード（G/右クリックでトグル）。true=カクカク移動・マットグレー・観客青
var use_grid_mode: bool = false
## 敵を全員止める（体当たりテスト用）。true の間は敵は移動しない
var enemies_frozen: bool = false

## ゲームオーバー時: 敵をその場で待機（Idle）に固定。移動・攻撃しない
func freeze_battle_for_game_over() -> void:
	enemies_frozen = true
	AudioManager.stop_all_sfx()
	var tree := get_tree()
	if tree == null:
		return
	for node in tree.get_nodes_in_group("Enemy"):
		var em := node as EnemyMain
		if not is_instance_valid(em) or em.is_dead:
			continue
		em.velocity = Vector2.ZERO
		em.player_in_range = false
		if em.rope_running:
			em.stop_rope_run()
		em.is_top_rope_aerial = false
		em.top_rope_height = 0.0
		if em.has_method("end_top_rope_flight"):
			em.end_top_rope_flight()
		if em.fsm:
			em.fsm.force_change_state("enemy_idle_state")
		if em.sprite and em.sprite.has_method("play"):
			# Idle アニメはステート Enter で再生される
			pass

## 二人用モードかどうか（タイトル画面で設定）
var two_player_mode: bool = false

## 現在のステージ（1〜4）
var current_stage: int = 1
## 各ステージのクリア状態
var stage_cleared: Array[bool] = [false, false, false, false]
## テストモード（true=簡単バランス、false=本番バランス）
var test_mode: bool = false
## トレーニングモード（中央に動かず攻撃しない敵1体・倒したら復活）
var training_mode: bool = false
## タイトルのステージ直接選択で開始したか（true=そのステージクリア後はタイトルへ戻る）
var single_stage_mode: bool = false
## トレーニング用：体当たり種別表示（正面/半キャラ/かすり）。表示秒数>0の間ラベルに出す
var body_contact_type_text: String = ""
var body_contact_type_timer: float = 0.0

## ステージ1 HUD：場に生存している敵の数（毎フレーム StageController が更新。本番プレイのみ意味を持つ）
var stage1_alive_enemy_count: int = 0
## ステージ1 HUD：同時出現数の上限（StageController が stage_params から設定）※v0.4以降は未使用
var stage1_max_concurrent_enemy_count: int = 0
## ステージ1 HUD：のこり撃破数（合計ノルマ − 撃破済み。0でクリア）
var stage1_remaining_total: int = 0

## 誤学習への介入ヒント（ステージ1・本番プレイ限定・KI対応）：正面衝突を累計3回起こしたら一度だけ表示
var stage1_front_collision_count: int = 0
var stage1_shoulder_tackle_count: int = 0
var stage1_hint_shown: bool = false
var front_collision_hint_text: String = ""
var front_collision_hint_timer: float = 0.0

#NOTE This class is our game manager and handles the players money and loading scenes
#These functions can be called globally from anywhere

## 開発用: `godot --headless ... -- stage=N [sim=combat|boss]` で起動すると
## 該当ステージのGameWrapperを直接開く（自動テスト用）。sim指定時はCombatSimを注入
var _dev_sim: bool = false
func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("stage="):
			current_stage = clampi(int(arg.get_slice("=", 1)), 1, 4)
			call_deferred("_dev_load_game_wrapper")
		elif arg.begins_with("sim="):
			_dev_sim = true

func _dev_load_game_wrapper() -> void:
	get_tree().change_scene_to_file.call_deferred("res://Scenes/Levels/GameWrapper.tscn")
	if _dev_sim:
		var sim_script := load("res://Scripts/Dev/CombatSim.gd")
		if sim_script:
			var sim: Node = (sim_script as GDScript).new()
			sim.name = "CombatSim"
			get_tree().root.add_child.call_deferred(sim)

func reset_money():
	money = 0

func add_money(addmoney : int):
	money += addmoney

func load_next_level(next_scene : PackedScene):
	get_tree().change_scene_to_packed(next_scene)

func load_same_level():
	AudioManager.unmute_sfx()
	enemies_frozen = false
	get_tree().reload_current_scene()

## ステージクリア処理
func clear_stage(stage_num: int):
	if stage_num >= 1 and stage_num <= 4:
		stage_cleared[stage_num - 1] = true

## 次のステージへ（登場画面へ遷移）。ステージ直接選択時はタイトルへ戻る
func load_next_stage():
	if single_stage_mode:
		load_title()
		return
	current_stage += 1
	if current_stage <= 4:
		# 次のステージ登場画面へ
		get_tree().change_scene_to_file("res://Scenes/UI/StageIntro.tscn")
	else:
		# エンディングへ
		get_tree().change_scene_to_file("res://Scenes/UI/Ending.tscn")

## タイトルへ戻る
func load_title():
	AudioManager.unmute_sfx()
	enemies_frozen = false
	current_stage = 1
	stage_cleared = [false, false, false, false]
	training_mode = false
	single_stage_mode = false
	get_tree().change_scene_to_file("res://Scenes/Misc/TitleScreen.tscn")

## 技名ポップアップ（実況風・確定仕様 設計原則#6）: 大技が決まった位置に技名を出して浮かせフェード
## anchor のいるワールド（SubViewport内）に直接追加するので、ゲーム画面内に正しく出る
func show_callout(anchor: Node2D, text: String, color: Color = Color(1.0, 0.85, 0.2, 1.0)) -> void:
	if not is_instance_valid(anchor):
		return
	var parent := anchor.get_parent()
	if not parent:
		return
	_spawn_callout_label(parent, anchor.global_position + Vector2(-140.0, -100.0), text, color)

## ワールド座標に技名／煽りを出す（やっちまえ等）
func show_callout_world(pos: Vector2, text: String, color: Color = Color(1.0, 0.85, 0.2, 1.0)) -> void:
	var parent: Node = get_tree().current_scene
	var players := get_tree().get_nodes_in_group("Player")
	if players.size() > 0 and is_instance_valid(players[0]) and players[0].get_parent():
		parent = players[0].get_parent()
	if not parent:
		return
	_spawn_callout_label(parent, pos + Vector2(-160.0, -40.0), text, color)

func _spawn_callout_label(parent: Node, pos: Vector2, text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.z_index = 2500
	label.add_theme_font_size_override("font_size", 34)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color(color.r * 0.6, color.g * 0.5, color.b * 0.1, 1.0))
	label.add_theme_constant_override("outline_size", 8)
	parent.add_child(label)
	label.position = pos
	label.size = Vector2(320.0, 40.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tw := label.create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "position:y", label.position.y - 46.0, 1.0)
	tw.tween_property(label, "modulate:a", 0.0, 1.0).set_delay(0.45)
	tw.chain().tween_callback(label.queue_free)

## ステージ1の誤学習防止ヒント判定用カウンタをリセット（StageController._ready から毎ステージ開始時に呼ぶ）
func reset_stage1_hint_tracking() -> void:
	stage1_front_collision_count = 0
	stage1_shoulder_tackle_count = 0
	stage1_hint_shown = false
	front_collision_hint_text = ""
	front_collision_hint_timer = 0.0
	# HUD用カウンタも初期化（再プレイ時に前回の値が一瞬表示されるのを防ぐ。0の間はHUD非表示）
	stage1_alive_enemy_count = 0
	stage1_max_concurrent_enemy_count = 0
	stage1_remaining_total = 0

## ステージ1・本番プレイでの正面衝突を記録。累計3回で「半キャラずらし」を促すヒントを一度だけ表示する。
## ただしすでに半キャラずらしを3回以上決めているプレイヤーには出さない（分かっている人に説教しない）。
func notify_stage1_front_collision() -> void:
	if training_mode or current_stage != 1 or stage1_hint_shown:
		return
	stage1_front_collision_count += 1
	if stage1_front_collision_count >= 3:
		stage1_hint_shown = true
		if stage1_shoulder_tackle_count < 3:
			front_collision_hint_text = "真正面は相打ち！半分ずれてぶつかれば一方的に押し込める！"
			front_collision_hint_timer = 3.5

## ステージ1での半キャラずらし成功を記録（誤学習ヒント抑制の判定用）
func notify_stage1_shoulder_tackle() -> void:
	if current_stage != 1:
		return
	stage1_shoulder_tackle_count += 1
