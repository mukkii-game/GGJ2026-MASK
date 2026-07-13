# KNOWN_ISSUES.md — 既知のバグ・不具合

**最終更新**: 2026-07-13

---

## 重大度: 高

### KI-01: qte_main.gd が失敗時にゲーム終了する
- **場所**: `Scenes/qte_main.gd` の `exit_sequence()`
- **内容**: `get_tree().quit()` を呼んでいる。これはスタンドアロンテスト用の古いコード
- **影響**: `qte_main.gd` はルートに残っているが、`StageController.gd` は `qte_core.tscn` を直接使うため、**実際には発火しない**。ただしシーンを間違えて使うと問題
- **対処案**: `qte_main.gd` を削除するか、`exit_sequence()` を修正

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

### KI-04: PUSH_KNOCKBACK の値がSPECと乖離している可能性
- **場所**: `PlayerMain.gd`
- **内容**: コード上は `PUSH_KNOCKBACK = 90.0` だが、SPEC B.0では「60px」と記載。未コミット変更で値が変わっている可能性
- **影響**: SPEC.mdとコードの乖離（spec-syncルール違反）
- **対処案**: 実際の値を確認し、SPEC.mdを更新

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

### KI-08: collision_maskの不統一
- **場所**: `PlayerRopeLaunchedState.Exit()` vs `PlayerMain._ready()`
- **内容**: RopeLaunched Exit時に `collision_mask = 1` だが、`_ready()` でも `collision_mask = 1`。正常時は3（layer 1+2）のはず
- **影響**: ロープ飛ばし後にlayer 2の壁をすり抜け続ける可能性
- **対処案**: Exit時に元の値（3 or 1）を正しく復元

### KI-09: StageControllerのMAT定数がEnemyMainと微妙に異なる
- **場所**: `StageController.gd` と `EnemyMain.gd`
- **内容**: StageControllerの `MAT_LEFT=296, MAT_RIGHT=984`、EnemyMainの `MAT_LEFT=296, MAT_RIGHT=984`、PlayerMainの `MAT_LEFT=280, MAT_RIGHT=1000`
- **影響**: プレイヤーと敵のマット範囲が微妙に異なる（プレイヤーの方が広い）
- **対処案**: 意図的ならSPECに明記。意図的でなければ統一
