extends Node
## 開発用・headless戦闘シミュレーション（確定仕様v1.0の自動テスト）
## 起動: godot --headless --path . -- stage=1 sim=combat   （S1で基本メカニクス）
##       godot --headless --path . -- stage=4 sim=boss     （S4ボスのロープ走行・直角カウンター）
## 本番プレイでは絶対にロードされない（GameManagerがコマンドライン引数を見たときだけ生成）

var mode: String = "combat"
var results: Array[String] = []
var _fail_count: int = 0

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("sim="):
			mode = arg.get_slice("=", 1)
	_run()

func _run() -> void:
	await get_tree().create_timer(2.0).timeout
	match mode:
		"boss":
			await _run_boss_tests()
		"clear":
			await _run_clear_tests()
		_:
			await _run_combat_tests()
	print("========== [SIM] RESULTS ==========")
	for r in results:
		print("[SIM] " + r)
	print("[SIM] TOTAL: %d tests, %d failed" % [results.size(), _fail_count])
	print("========== [SIM] END ==========")
	get_tree().quit()

func _check(name: String, ok: bool, detail: String = "") -> void:
	if ok:
		results.append("PASS: " + name)
	else:
		_fail_count += 1
		results.append("FAIL: " + name + ("  (" + detail + ")" if detail != "" else ""))

func _wait_until(cond: Callable, timeout: float) -> bool:
	var t := 0.0
	while t < timeout:
		if cond.call():
			return true
		await get_tree().create_timer(0.05).timeout
		t += 0.05
	return bool(cond.call())

func _find_player() -> PlayerMain:
	for node in get_tree().get_nodes_in_group("Player"):
		var p := node as PlayerMain
		if p and not p.is_player_two:
			return p
	return null

func _find_zakos(exclude: Array = []) -> Array[EnemyMain]:
	var out: Array[EnemyMain] = []
	for node in get_tree().get_nodes_in_group("Enemy"):
		var e := node as EnemyMain
		if e and not e.is_dead and not e.is_boss and not exclude.has(e):
			if e.is_ring_in_effect_only() or e.is_rope_launched():
				continue
			out.append(e)
	return out

## テスト対象を確実に「接地・通常ステート」に戻す
func _ground(e: EnemyMain, pos: Vector2) -> void:
	e.kill_motion_tweens()
	e._aerial_knockback_animating = false
	e.knockback_stun_remaining = 0.0
	if e.is_rope_launched() or e.is_ring_in_effect_only() or e.is_in_down_state():
		e.down_remaining = 0.0
		e.fsm.force_change_state("enemy_idle_state")
	e.global_position = pos
	if e.sprite:
		e.sprite.rotation_degrees = 0.0

## 増援スポーンを止める（テストの撹乱防止）
func _stop_reinforcements() -> void:
	for c in get_tree().current_scene.get_children():
		if c.get_script() != null and String((c.get_script() as Script).resource_path).ends_with("StageController.gd"):
			c.set("stage_params", (c.get("stage_params") as Dictionary).merged({"spawn_interval": 999999.0}, true))
			return

func _find_boss() -> EnemyMain:
	for node in get_tree().get_nodes_in_group("Enemy"):
		var e := node as EnemyMain
		if e and not e.is_dead and e.is_boss:
			return e
	return null

func _release_all() -> void:
	for a in ["MoveLeft", "MoveRight", "MoveUp", "MoveDown", "Jump", "Dash"]:
		Input.action_release(a)

## テスト対象以外の敵を隅に退避（凍結中なので動かない）。プレイヤーの残存無敵も解除
func _isolate(player: PlayerMain, keep: Array) -> void:
	for e in _find_zakos([]):
		if not keep.has(e):
			e.kill_motion_tweens()
			e.global_position = Vector2(330, 140)
	player.kill_motion_tweens()
	player.rope_bounce_running = false
	player.invincible = false
	player._invincible_until_ms = 0
	player.body_contact_cooldown = 0.0

## ============ S1: 基本メカニクス ============
func _run_combat_tests() -> void:
	var player := _find_player()
	_check("プレイヤー取得", player != null)
	if not player:
		return
	# 敵の着地（リングイン完了）を待つ
	await _wait_until(func() -> bool:
		return _find_zakos().filter(func(e: EnemyMain) -> bool: return not e.is_ring_in_effect_only()).size() >= 2, 10.0)
	var zakos := _find_zakos().filter(func(e: EnemyMain) -> bool: return not e.is_ring_in_effect_only())
	_check("ザコ2体以上着地", zakos.size() >= 2, "landed=%d" % zakos.size())
	if zakos.size() < 2:
		return
	GameManager.enemies_frozen = true
	_stop_reinforcements()
	player.set_invincible_for(0.01)

	# --- TEST 1: 向き規則（P2）: 向いていない接触＝一方的被弾・敵は無傷 ---
	var e1: EnemyMain = zakos[0]
	_release_all()
	_isolate(player, [e1])
	player.facing_dir = Vector2.RIGHT
	var php0: int = player.health
	var ehp0: int = e1.health
	_ground(e1, Vector2(640, 360))
	player.global_position = Vector2(690, 360)  # 敵はプレイヤーの左＝facingと逆
	await get_tree().create_timer(0.5).timeout
	_check("向き規則: プレイヤーだけ被弾", player.health < php0 and e1.health == ehp0,
		"php %d->%d ehp %d->%d" % [php0, player.health, ehp0, e1.health])

	# --- TEST 2: 半キャラ蓄積（P4）: 3発で弱り（青）化 ---
	var e2: EnemyMain = zakos[1]
	_isolate(player, [e2])
	e2.health = 200  # 弱り前に死なないように
	_ground(e2, Vector2(640, 300))
	player.global_position = Vector2(566, 340)  # 左からy+40ずらし
	Input.action_press("MoveRight")
	var became_weak := await _wait_until(func() -> bool: return e2.is_weak_state(), 3.0)
	Input.action_release("MoveRight")
	_check("半キャラ3発→弱り化", became_weak, "hits=%d hp=%d" % [e2.halfcar_hit_count, e2.health])
	_check("半キャラでHP減少", e2.health < 200, "hp=%d" % e2.health)

	# --- TEST 3: 弱り正面ブラスト（P5）: 大ダメージ＋撃破なら場外 ---
	if became_weak:
		_isolate(player, [e2])
		e2.health = 30  # ブラスト40で即死する体力に
		_ground(e2, Vector2(800, 500))
		player.global_position = Vector2(710, 500)  # 左から正面（yズレ0）
		player.facing_dir = Vector2.RIGHT
		Input.action_press("MoveRight")
		var blasted := await _wait_until(func() -> bool: return (not is_instance_valid(e2)) or e2.is_dead, 3.0)
		Input.action_release("MoveRight")
		_check("弱り正面ブラストで撃破", blasted,
			("hp=%d weak=%s" % [e2.health, str(e2.is_weak_state())]) if is_instance_valid(e2) else "freed")

	# --- TEST 4: ダウン→プレス（P6） ---
	var zk := _find_zakos([])
	if zk.size() >= 1:
		var e3: EnemyMain = zk[0]
		_isolate(player, [e3])
		e3.health = 200
		_ground(e3, Vector2(500, 500))
		e3.enter_down(10.0)
		await get_tree().create_timer(0.3).timeout
		_check("enter_downでダウン状態", e3.is_in_down_state())
		var hp_before: int = e3.health
		_release_all()
		player.global_position = Vector2(500, 500)
		player.fsm.force_change_state("Jump")
		await get_tree().create_timer(1.5).timeout
		_check("ダウン敵へのプレスで大ダメージ", e3.health <= hp_before - 30 or e3.is_dead,
			"hp %d->%d" % [hp_before, e3.health])

		# --- TEST 5: 起き上がり弱り（ダウンは凍結中カウント停止のため一時解除して確認） ---
		e3.down_remaining = 0.1
		GameManager.enemies_frozen = false
		var woke_weak := await _wait_until(func() -> bool: return (not e3.is_in_down_state()) and e3.is_weak_state(), 2.0)
		GameManager.enemies_frozen = true
		_check("起き上がり直後2秒弱り", woke_weak)

	# --- TEST 6: 空中頭突き（P7）: 命中で吹き飛び→ダウン。強い敵にも通る ---
	var zk2 := _find_zakos([])
	if zk2.size() >= 1:
		var e4: EnemyMain = zk2[zk2.size() - 1]
		_isolate(player, [e4])
		e4.health = 200
		e4.set_angry_for(10.0)  # 強い状態でも通ることを確認
		_ground(e4, Vector2(640, 200))
		_release_all()
		player.global_position = Vector2(480, 200)
		player.pending_headbutt_dir = Vector2.RIGHT
		player.fsm.force_change_state("Jump")
		var downed := await _wait_until(func() -> bool: return e4.is_in_down_state() or e4.is_dead, 2.5)
		_check("空中頭突き: 強い敵をダウンさせる", downed,
			"hp=%d angry=%s state=%s" % [e4.health, str(e4.is_shoulder_immune()), (e4.fsm.current_state.name if e4.fsm.current_state else "?")])
		if downed and not e4.is_dead:
			_check("頭突きダウンで強化解除", not e4.is_shoulder_immune())

	# --- TEST 7: ヒートマン発熱（自己強化）と半キャラ弾き ---
	var zk3 := _find_zakos([])
	if zk3.size() >= 1:
		var e5: EnemyMain = zk3[0]
		_isolate(player, [e5])
		_ground(e5, Vector2(640, 420))
		e5.health = 200
		e5.enemy_type = EnemyMain.EnemyType.Heatman
		e5._weak_until = 0.0
		e5._heat_timer = 9.7  # 発熱直前まで進める
		var ignited := await _wait_until(func() -> bool: return e5.is_shoulder_immune(), 2.0)
		_check("ヒートマン: 無被弾で自己強化", ignited)
		if ignited:
			# 強い敵に正面: プレイヤーだけ弾かれてダメージ、敵は無傷
			var php1: int = player.health
			var ehp1: int = e5.health
			_ground(e5, Vector2(640, 420))
			player.global_position = Vector2(580, 420)
			player.facing_dir = Vector2.RIGHT
			Input.action_press("MoveRight")
			await get_tree().create_timer(0.6).timeout
			Input.action_release("MoveRight")
			_check("強い敵に正面: プレイヤーだけ被弾", player.health < php1 and e5.health == ehp1,
				"php %d->%d ehp %d->%d" % [php1, player.health, ehp1, e5.health])

	_release_all()
	GameManager.enemies_frozen = false

## ============ クリア導線E2E: 撃破→(QTE)→StageClear遷移 ============
func _run_clear_tests() -> void:
	var stage: int = GameManager.current_stage
	_stop_reinforcements()
	if stage == 1:
		# S1: 全ザコ撃破→クリア
		await _wait_until(func() -> bool: return _find_zakos().size() >= 1, 10.0)
		for e in _find_zakos([]):
			e.use_qte_on_defeat = false
			e._take_damage(9999)
		# リングイン中の敵も含めて全滅させる
		await get_tree().create_timer(0.5).timeout
		for node in get_tree().get_nodes_in_group("Enemy"):
			var e2 := node as EnemyMain
			if e2 and not e2.is_dead:
				e2._take_damage(9999)
	else:
		var ok := await _wait_until(func() -> bool: return _find_boss() != null, 10.0)
		_check("S%d ボス出現" % stage, ok)
		if not ok:
			return
		var boss := _find_boss()
		# 弱り正面ブラスト経由でHP0に落とす（実戦経路に近い形）
		boss.set_weak_for(10.0)
		boss.health = 10
		boss._take_damage(40)  # QTEボスは defeated_for_qte が発火するはず
		var qte_shown := await _wait_until(func() -> bool: return get_tree().root.find_child("qte_core", true, false) != null or _find_qte() != null, 5.0)
		_check("S%d QTE表示" % stage, qte_shown)
		var qte := _find_qte()
		if qte and qte.has_signal("qte_succeeded"):
			qte.emit_signal("qte_succeeded")
		else:
			results.append("SKIP: S%d QTEノード直接成功発火（未発見）" % stage)
	var cleared := await _wait_until(func() -> bool:
		var cs := get_tree().current_scene
		return cs != null and String(cs.scene_file_path).contains("StageClear"), 8.0)
	_check("S%d クリア画面へ遷移" % stage, cleared,
		String(get_tree().current_scene.scene_file_path) if get_tree().current_scene else "?")

func _find_qte() -> Node:
	var root := get_tree().current_scene
	if not root:
		return null
	for c in root.get_children():
		if c.has_signal("qte_succeeded"):
			return c
	return null

## ============ S4: ボスギミック ============
func _run_boss_tests() -> void:
	var player := _find_player()
	_check("プレイヤー取得", player != null)
	if not player:
		return
	var boss_found := await _wait_until(func() -> bool: return _find_boss() != null, 10.0)
	_check("S4ボス出現", boss_found)
	if not boss_found:
		return
	var boss := _find_boss()
	GameManager.enemies_frozen = false
	_stop_reinforcements()
	player.set_invincible_for(0.01)

	# --- TEST B1: ロープ走行開始（強い扱い） ---
	boss.start_rope_run(false, 280.0, 12.0)  # 左右往復
	await get_tree().create_timer(0.3).timeout
	_check("ボスがロープ走行中", boss.rope_running)
	_check("走行中は強い状態", boss.is_shoulder_immune())

	# --- TEST B2: 直角カウンター: 走行軸と直角に押し当てる→ダウン＋強化解除 ---
	_release_all()
	var countered := false
	for _attempt in range(80):  # 最大4秒間、毎フレーム位置を合わせて上入力
		if boss.is_in_down_state():
			countered = true
			break
		player.global_position = Vector2(boss.global_position.x, boss.global_position.y + 50.0)
		player.facing_dir = Vector2.UP
		Input.action_press("MoveUp")
		await get_tree().create_timer(0.05).timeout
	Input.action_release("MoveUp")
	_check("直角カウンター: ボスがダウン", countered or boss.is_in_down_state())
	_check("直角カウンター: ロープ走行停止", not boss.rope_running)
	if boss.is_in_down_state():
		_check("直角カウンター: 強化解除", not boss.is_shoulder_immune() or boss.is_weak_state())

	# --- TEST B3: 号令: 全ザコが一時強化される ---
	var sc := get_tree().current_scene.get_node_or_null("StageController")
	if sc == null:
		# GameWrapper構成でのStageController探索
		for c in get_tree().current_scene.get_children():
			if c.get_script() != null and String(c.get_script().resource_path).ends_with("StageController.gd"):
				sc = c
				break
	if sc:
		var zakos := _find_zakos([])
		if zakos.size() > 0:
			sc.call("_do_shout")
			await get_tree().create_timer(0.2).timeout
			var all_angry := true
			for z in _find_zakos([]):
				if z.enemy_type != EnemyMain.EnemyType.Gaburi and not z.is_shoulder_immune():
					all_angry = false
			_check("号令: ザコ全体が強化", all_angry)
		else:
			results.append("SKIP: 号令テスト（ザコ不在）")
	else:
		results.append("SKIP: 号令テスト（StageController未発見）")
