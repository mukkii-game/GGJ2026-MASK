extends Node

var money = 0

## グリッドモード（G/右クリックでトグル）。true=カクカク移動・マットグレー・観客青
var use_grid_mode: bool = false
## 敵を全員止める（体当たりテスト用）。true の間は敵は移動しない
var enemies_frozen: bool = false

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
## トレーニング用：体当たり種別表示（正面/半キャラ/かすり）。表示秒数>0の間ラベルに出す
var body_contact_type_text: String = ""
var body_contact_type_timer: float = 0.0

## ステージ1 HUD：場に生存している敵の数（毎フレーム StageController が更新。本番プレイのみ意味を持つ）
var stage1_alive_enemy_count: int = 0
## ステージ1 HUD：同時出現数の上限（StageController が stage_params から設定）
var stage1_max_concurrent_enemy_count: int = 0

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
	get_tree().reload_current_scene()

## ステージクリア処理
func clear_stage(stage_num: int):
	if stage_num >= 1 and stage_num <= 4:
		stage_cleared[stage_num - 1] = true

## 次のステージへ（登場画面へ遷移）
func load_next_stage():
	current_stage += 1
	if current_stage <= 4:
		# 次のステージ登場画面へ
		get_tree().change_scene_to_file("res://Scenes/UI/StageIntro.tscn")
	else:
		# エンディングへ
		get_tree().change_scene_to_file("res://Scenes/UI/Ending.tscn")

## タイトルへ戻る
func load_title():
	current_stage = 1
	stage_cleared = [false, false, false, false]
	training_mode = false
	get_tree().change_scene_to_file("res://Scenes/Misc/TitleScreen.tscn")

## ステージ1の誤学習防止ヒント判定用カウンタをリセット（StageController._ready から毎ステージ開始時に呼ぶ）
func reset_stage1_hint_tracking() -> void:
	stage1_front_collision_count = 0
	stage1_shoulder_tackle_count = 0
	stage1_hint_shown = false
	front_collision_hint_text = ""
	front_collision_hint_timer = 0.0
	# HUD用カウンタも初期化（再プレイ時に前回の値が一瞬表示されるのを防ぐ。cap=0の間はHUD非表示）
	stage1_alive_enemy_count = 0
	stage1_max_concurrent_enemy_count = 0

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
