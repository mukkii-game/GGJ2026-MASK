# KNOWN_ISSUES.md — 既知のバグ・不具合

**最終更新**: 2026-07-13

---

## 重大度: 高

### ~~KI-01: qte_main.gd が失敗時にゲーム終了する~~ → **修正済み**
- `qte_main.gd` をシグナルベース（`qte_succeeded` / `qte_failed`）に書き換え済み
- `get_tree().quit()` を削除し、`queue_free()` に変更

### KI-02: Tween一括killによる副作用
- **場所**: `PlayerJumpState.gd` の `Enter()` / `Exit()`
- **内容**: `get_tree().get_processed_tweens()` で**全ての**アクティブTweenをkillしている
- **影響**: ジャンプ開始/終了時に、他のノード（敵のノックバック、UIアニメーション等）のTweenも巻き込む可能性
- **対処案**: 自分が作ったTweenだけをkillするように変更

---

## 重大度: 中

### KI-03: 上ロープのバウンドが不安定
- **場所**: `PlayerMain.gd` の `_physics_process()`
- **内容**: 上下ロープは跳ね返り自動移動を行わず、クランプのみ。ただし `_rope_correction_velocity` と `ROPE_TOP_CORRECTION_SPEED` が定義されており、上ロープ矯正用の仕組みが残っている
- **影響**: 上端に張り付く挙動が起こり得る
- **対処案**: 上下バウンドを左右と同様に実装するか、矯正ロジックを整理

### ~~KI-04: PUSH_KNOCKBACK の値がSPECと乖離~~ → **修正済み**
- SPEC.md をコードの実値（`PUSH_KNOCKBACK=90`, `PUSH_PLAYER_KNOCKBACK_HALFCAR=6`）に更新済み

### KI-05: 敵死亡後のqueue_free競合
- **場所**: `CharacterBase._die()` / `StageController._on_qte_succeeded()`
- **内容**: `_die()` は1秒後に `queue_free()`、QTE成功時も `current_qte_boss.queue_free()`
- **影響**: タイミング次第で二重freeやnull参照の可能性（is_instance_validで概ね防いでいるが）
- **対処案**: 死亡フローの一元化

### KI-06: ステージクリア後の入力が残る
- **場所**: `StageController._on_stage_clear()` / `StageClear.gd`
- **内容**: クリア判定後もプレイヤーは操作可能。Timer(1.2秒)で画面遷移するまでの間に体当たりが発生する
- **影響**: クリア後に死亡する可能性（レアケース）
- **対処案**: クリア判定後にプレイヤーを無敵にするか、入力を無効化

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
