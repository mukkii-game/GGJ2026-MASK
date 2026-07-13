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

---

## 重大度: 低

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
