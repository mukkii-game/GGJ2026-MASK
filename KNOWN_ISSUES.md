# KNOWN_ISSUES.md — 既知のバグ・不具合

**最終更新**: 2026-07-13（デスクトップ側AIによる修正反映）

---

## 重大度: 高

### ~~KI-01: qte_main.gd が失敗時にゲーム終了する~~ → **修正済み**
- `qte_main.gd` をシグナルベース（`qte_succeeded` / `qte_failed`）に書き換え済み
- その後、未使用の残骸だったため削除（実際に使われているのは `qte_main_with_anim.gd`）

### ~~KI-02: Tween一括killによる副作用~~ → **修正済み（2026-07-13）**
- `CharacterBase` に `register_motion_tween()` / `kill_motion_tweens()` を追加
- 移動・回転系Tween（ノックバック・かすり回転・空中ノックバック等）は作成時に登録し、
  ジャンプ/ロープ飛ばしのステート Enter/Exit では**自分の登録済みTweenだけ**をkillする方式に変更
- `get_processed_tweens()` の全killは全箇所から排除（PlayerJumpState / PlayerRopeLaunchedState / EnemyLaunchedState）

### KI-11: 存在しないアクション名によるエラースパム → **修正済み（2026-07-13）**
- `PlayerIdleState` / `PlayerWalkState` が存在しない `AttackPunch` / `AttackKick` を毎フレーム参照していた
- 影響: 1P では Attacking / FireDash 遷移が一切発動せず、ログにエラーが毎フレーム出ていた
- 修正: 通常攻撃（Attacking）遷移を削除（NON_NEGOTIABLES #1 準拠）。
  グリッドモード時の Nボタン（2Pは左クリック）＝炎ダッシュ遷移を Idle/Walk 両方に実装（SPEC B.5.1 準拠）

### ~~KI-13: FireDashState が誤った hold アクションを参照~~ → **修正済み（2026-07-13）**
- `PlayerFireDashState` が維持判定に `Punch` を使っていた（遷移は `Dash` / `Punch2`）
- Nキーが `Punch`/`Dash` 両方に割り当てられていたため実害は出にくかったが、入力変更時に即 Idle 復帰する潜在バグ
- 修正: 1P=`Dash`、2P=`Punch2` に統一

---

## 重大度: 中

### ~~KI-03: 上ロープのバウンドが不安定~~ → **修正済み（2026-07-13）**
- 未使用の上ロープ矯正ロジック（`_rope_correction_velocity` / `ROPE_TOP_CORRECTION_*` / `ROPE_BOTTOM_BOUNCE`）を削除
- 上下ロープは「クランプのみ」で確定（OQ-02 は選択肢A採用）

### ~~KI-04: PUSH_KNOCKBACK の値がSPECと乖離~~ → **修正済み**
- SPEC.md をコードの実値（`PUSH_KNOCKBACK=90`, `PUSH_PLAYER_KNOCKBACK_HALFCAR=6`）に更新済み

### ~~KI-05: 敵死亡後のqueue_free競合~~ → **修正済み（2026-07-13）**
- QTE成功時の `current_qte_boss.queue_free()` 直呼びをやめ、`CharacterBase._die()` に一元化
- ボスもマスク飛び演出→1秒後に自動 `queue_free` される（クリア遷移は1.2秒後なので競合しない）

### ~~KI-06: ステージクリア後の入力が残る~~ → **修正済み（2026-07-13）**
- `_on_stage_clear()` で `GameManager.enemies_frozen = true`＋全プレイヤーを5秒無敵に
- 次ステージの `StageController._ready()` で `enemies_frozen` を解除
- あわせて `set_invincible_for()` を「期限管理方式」に変更（短い無敵が長い無敵を打ち消さない）

### KI-12: PlayerMain._ready() のカメラ付け替えがエラーを出す → **修正済み（2026-07-13）**
- `_ready()` 中の `add_child()` が「親がセットアップ中」で失敗していた
- `add_child.call_deferred()` + `set_deferred()` に変更

### KI-14: AudioManagerのプール拡張コードが到達不能 → **修正済み（2026-07-13）**
- `play_sound()` の `available_player` 初期値が `audio_players[0]` だったため、「空きが無ければ新規作成」の分岐が実質発火せず、全員再生中だと再生中の音を問答無用で上書きしていた
- 修正: 初期値を `null` にし、空き探索→上限未満なら新規作成→それでも無ければ `audio_players[0]` にフォールバックの順に変更（TD-09参照）

### KI-15: after_damage_iframes() が無敵期限を無視して強制解除 → **修正済み（2026-07-13）**
- `CharacterBase.after_damage_iframes()` の末尾で `invincible = false` を無条件に実行しており、`set_invincible_for()` で長い無敵（例: ロープ飛ばされ後の1.5秒無敵）を設定していても、被弾フラッシュの演出（約0.5秒）が終わった時点で無敵が解除されてしまっていた
- 修正: `set_invincible_for()` と同じ期限管理方式（`_invincible_until_ms`）を使い、自分より後により長い無敵期限が設定されていたら解除しないように変更

### KI-16: ステージ3ボスの正面ガード演出が本番で出ない → **修正済み（2026-07-13）**
- `PlayerMain._body_contact()` のステージ3正面ガード処理で、敵側への赤フラッシュが `GameManager.training_mode` の分岐内にしかなく、本番プレイではボス側に「ガードされた」ことが伝わる演出が一切出ていなかった
- 修正: トレーニングモードに関係なく、ボス側に青白系フラッシュ（`Color(0.7, 0.9, 2.0)`）を常に出すよう変更。ダメージの赤フラッシュと区別するため専用色にした

### KI-17: ロープバウンス解除判定が2Pでも1Pのキーを見ていた → **修正済み（2026-07-13）**
- `PlayerMain._process()` のロープバウンス解除判定で `Input.is_action_just_pressed("Dash")` が固定で使われており、2P（`is_player_two`）でも1Pの `Dash`（Nキー）を見ていた
- 修正: 他の移動キーと同じパターンで `is_player_two` なら `Punch2` を見るよう分岐

### KI-18: QTEの入力判定に2P用アクションが無かった → **修正済み（2026-07-13）**
- `qte_main_with_anim.gd` のQTE成功判定が `Punch` / `Kick` / `Dash` / `Enter` / `ui_accept` のみを見ており、2P専用の `Punch2` が含まれていなかった
- 修正: `Input.is_action_just_pressed("Punch2")` を追加（`project.godot` に定義済みであることを確認済み）

### KI-19: 「ボスを倒してもクリア画面に行かない」報告 → **現行HEADで再現せず（2026-07-13調査）**
- ユーザー報告。ステージ不明（S2〜S4のいずれか）
- headless実機シミュレーション（ボスHP0→QTE success_game()→シーン遷移監視）で S2/S3/S4 全て `CLEARED_OK` を確認。
  `defeated_for_qte` → QTE起動 → `qte_succeeded` → `_on_qte_succeeded()`（雑魚残数と無関係に無条件でクリア）→ 1.2秒後 StageClear.tscn 遷移のパイプラインは現行コードで正常
- 有力仮説: (a) 報告が本日の修正前のビルド（KI-05: QTE成功時のqueue_free競合がまさにこの症状を起こしうる）、
  (b) QTEが実は失敗していた（FAIL→ボスHP20%回復で戦闘続行。「倒したのに何も起きない」ように見える）
- 再現情報待ち: どのステージか / QTE画面は出たか / SUCCESS!とFAIL...のどちらが表示されたか / 1P・2Pどちらか

### ~~KI-20: かすりトドメ時のボス位置クランプ漏れ~~ → **修正済み（2026-07-17）**
- かすり分岐の敵移動Tweenに `_clamp_enemy_to_mat` のコールバックを追加（半キャラ/正面と同じ扱いに）

### ~~KI-21: ロープ走行中に逆さ向きのまま走る（旧F-5）~~ → **修正済み（2026-07-17）**
- 原因: かすりの縦軸回転Tween中にロープ跳ね返りが始まると、回転が中途半端な角度のまま残っていた
- 修正: ロープ跳ね返り開始時に `kill_motion_tweens()`＋スプライト回転を0にリセット（`PlayerMain._physics_process`）

### KI-22: 開発時の注意 — `GodotMask.exe` は古いコードを内蔵した書き出し版
- `E:\GodotProjects\GodotMask(.console).exe` はゲームのエクスポート版で、**PCK内に古いスクリプトを内蔵**している
- これで `--path` 起動すると存在しないはずのエラー（AttackPunch等）が出て混乱する。**テストは素のGodotエディタバイナリ（4.7）で行うこと**
- 例: `Godot_v4.7_console.exe --headless --path . -- stage=1 sim=combat`（自動テストは `Scripts/Dev/CombatSim.gd`）

---

## 重大度: 低

### KI-23: S4ボスギミックのサイクル空振り（低・未修正）
- `StageController._update_stage4_boss_gimmicks()`: ロープ走行の番なのにボスがまだ走行中（ダウン等で遅延した場合）だと、その12秒サイクルは何も起きずタイマーだけリセットされる
- 通常は走行6秒＜間隔12秒なので発生しない。演出頻度が体感で不安定になるだけで実害なし

### KI-24: 実プレイ確認事項 — S1で「3発弱り→ブラスト」教習が半キャラ連打で流される可能性（レビュー指摘）
- ジョバーHP27に対し半キャラ6ダメ/tickなので、グラインドだけで約1秒で倒せてブラストを使わずに済む
- 確定仕様の「手なり救済（正面/連打でも押し切れる）」の意図通りではあるが、ブラストの快感を見せたいなら S1のtickダメ減 or HP増を実プレイで判断

### KI-07: 2Pカメラの残骸
- **場所**: `PlayerMain._ready()`
- **内容**: 2P側は `cam.enabled = false` で無効化しているが、Camera2Dノード自体は残る
- **影響**: なし（機能しない）

### ~~KI-08: collision_maskの不統一~~ → **確認済み: 意図的**
- `PlayerMain._ready()` で `collision_mask = 1` に設定（ロープ外壁 layer 2 を無効化）
- `PlayerRopeLaunchedState.Exit()` も `collision_mask = 1` に復元
- これは意図的（ロープ外の壁をすり抜けるため）。問題なし

### ~~KI-10: press_bar.gd / result_label.gd / kancho.gd のパースエラー~~ → **修正済み**
- `press_bar.gd` 30行目の全角不正文字を除去
- `result_label.gd` の `_ready()` 重複定義と未定義参照を修正
- `kancho.gd` の末尾の無効テキストを除去
- いずれもゲーム本体では未使用の残骸ファイル

### ~~KI-09: MAT定数の差異~~ → **確認済み: 意図的**
- Player: `MAT_LEFT=280, MAT_RIGHT=1000`（幅720）
- Enemy: `MAT_LEFT=296, MAT_RIGHT=984`（幅688、片側16px狭い）
- 敵がロープ端に張り付かないための設計。SPEC §9 と EnemyMain コメントに明記済み
