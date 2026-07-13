# DEVELOPMENT_LOG.md — 開発ログ

**最終更新**: 2026-07-13

コミットログから再構成した開発の流れ。今後の変更時にも追記すること。

---

## 開発タイムライン（コミットログベース）

### Phase 1: ベーステンプレート（ForlornU TopdownStarter）
- Godot 4.2+ の2D PixelArt TopDown スターターキットをベースに開始
- FSM（FiniteStateMachine + State）、キャラクター基底、クエストシステムが含まれていた
- プレイヤーは Idle / Walk / Attack / Death の4ステートのみ

### Phase 2: 体当たり戦闘の構築
- 通常攻撃を廃止し、体当たり（接触）を主軸に変更
- `PlayerMain._body_contact()` を新規実装
- 正面 / 半キャラずらし / かすり の3種判定を追加
- ノックバックをイース風（X or Y軸のみ）に限定
- 各種定数（ダメージ、ノックバック量、クールダウン）を調整

### Phase 3: リング・ロープの実装
- マット内クランプ（`MAT_LEFT/RIGHT/TOP/BOTTOM`）
- 左右ロープ跳ね返り（自動移動）
- ロープたわみ演出（`ArenaMat.gd`）
- ロープ飛ばし（放物線移動 `PlayerRopeLaunchedState` / `EnemyLaunchedState`）
- リングとロープの見た目調整 (`e92fe65`)

### Phase 4: 敵AI・ステージ構成
- 5種の行動パターン（Idle, VerticalLoop, HorizontalLoop, RandomRange, Flee）
- 3状態（Normal, Angry, Weak）の自動遷移
- 4ステージのボス/雑魚パラメータ設定
- ステージ3ボス（ユニ帝仮面）: 正面無敵＋振り向きディレイ
- リングイン演出
- 雑魚の定期増援スポーン

### Phase 5: UI・メニュー
- ポーズメニュー (`3c26d72`)
- メニュー修正、走り速度調整 (`9496ace`)
- タイトル画面（1P/2P/テスト/トレーニング/ステージ直接選択）
- デス画面（3択）
- ステージクリア画面
- ESC終了確認ダイアログ

### Phase 6: 演出・エフェクト
- 死亡マスク飛び演出（`MaskFlyAway.gd`）
  - 敵が拡大しながら死ぬように (`dbe9b31`)
- 半キャラずらし時の白ピカピカ（`FlashPikaPika.gd`）
- かすり時のバレリーナ回転
- 空中攻撃の緑フラッシュ
- 観客システム（`Audience.gd`）

### Phase 7: バランス調整・バグ修正
- ジャンプ中のプライオリティ修正 (`4a1072e`)
- ユニ帝仮面を弱く、後ろを取りやすく (`814ccea`)
- SPEC.mdを現行戦闘メカニクスに更新 (`c8d8915`)

---

## 引き継ぎ時点の状態（2026-07-13）

- ブランチ: `godot`
- HEAD: `c8d8915`
- 未コミット変更:
  - `Scenes/Player/Scripts/PlayerMain.gd`（staged）
  - `Scripts/DebugContactOverlay.gd`（unstaged）
- ゲームは起動〜4ステージクリア〜エンディングまで通しでプレイ可能
- テストモード、トレーニングモード、2Pモードも動作
- 主な課題: SPEC.mdとコードの一部乖離、技術的負債（PlayerMain肥大化）

---

## 変更記録

### 2026-07-13: SPEC乖離修正・バグ修正・引き継ぎ文書整備
- **変更内容**:
  1. SPEC.md の PUSH_KNOCKBACK を 60→90 に修正（コードの実値に合わせる）
  2. SPEC.md のプレイヤー反動を 12→6 に修正（`PUSH_PLAYER_KNOCKBACK_HALFCAR` の実値）
  3. SPEC.md §9 にプレイヤー/敵のマット範囲差を明記
  4. `qte_main.gd` をシグナルベースに書き換え（`get_tree().quit()` を除去）
  5. `DebugContactOverlay.gd` の `draw_line` に線幅パラメータを渡すよう修正
  6. `EnemyMain.gd` のMAT定数コメントを意図的差異と明示
  7. KNOWN_ISSUES.md の修正済み項目を更新
- **変更理由**: SPEC-コード乖離の解消、既知バグの修正、引き継ぎ品質向上
- **影響範囲**: `docs/SPEC.md`, `Scenes/qte_main.gd`, `Scripts/DebugContactOverlay.gd`, `Scenes/NPC's/Enemy/Scripts/EnemyMain.gd`, `KNOWN_ISSUES.md`, `CURRENT_IMPLEMENTATION.md`
- **SPEC更新**: B.0 半キャラずらしのノックバック値、§9 マット範囲、定数一覧

### 2026-07-13: 残骸スクリプトのパースエラー修正
- **変更内容**:
  1. `press_bar.gd` 30行目の全角不正文字を除去
  2. `Scenes/result_label.gd` の `_ready()` 重複定義と未定義参照を修正
  3. `Scenes/kancho.gd` の末尾無効テキストを除去
- **変更理由**: Godotエディタのパースエラー回避。スクリプト監査で発見
- **影響範囲**: `press_bar.gd`, `Scenes/result_label.gd`, `Scenes/kancho.gd`（いずれもゲーム本体では未使用）
- **SPEC更新**: 不要

### 2026-07-13: 既知バグ一括修正（KI-02/03/05/06/11/12）・パワーエサFB・残骸削除
- **変更内容**:
  1. KI-02: `CharacterBase` に `register_motion_tween()`/`kill_motion_tweens()` を追加し、ジャンプ・ロープ飛ばしステートの「全Tween一括kill」を自分の移動系Tweenのみのkillに変更
  2. KI-03: 未使用の上ロープ矯正ロジック（`_rope_correction_velocity` 等）を削除。上下ロープはクランプのみで確定
  3. KI-05: QTE成功時のボス消滅を `CharacterBase._die()` に一元化（マスク飛び演出→1秒後に自動free）
  4. KI-06: ステージクリア確定後 `enemies_frozen=true`＋プレイヤー5秒無敵。次ステージ開始時に解除。`set_invincible_for()` を期限管理方式に変更
  5. KI-11（新規発見）: 存在しないアクション `AttackPunch`/`AttackKick` の毎フレーム参照を除去。通常攻撃（Attacking）遷移を削除し、グリッドモード時のNボタン（2Pは左クリック）＝炎ダッシュ遷移を Idle/Walk に実装
  6. KI-12（新規発見）: `PlayerMain._ready()` のカメラ付け替えを `call_deferred` 化（add_child失敗の解消）
  7. TD-08: パワーエサ取得時に効果色フラッシュ＋効果名ポップアップを表示
  8. TD-10: 残骸ファイル削除（`press_bar.gd`, `Scenes/qte_main.gd`, `Scenes/result_label.gd`, `Scenes/kancho.gd`）
- **変更理由**: 既知バグの解消と、コアの気持ちよさに直結するフィードバック強化。KI-11 は「炎ダッシュが1Pで一度も発動できていなかった」実質的な機能欠落の修正
- **影響範囲**: `Scripts/CharacterBase.gd`, `Scripts/StageController.gd`, `Scripts/PowerBait.gd`, `Scenes/Player/Scripts/PlayerMain.gd`, `Scenes/Player/Scripts/States/PlayerJumpState.gd`・`PlayerRopeLaunchedState.gd`・`PlayerIdleState.gd`・`PlayerWalkState.gd`, `Scenes/NPC's/Enemy/Scripts/EnemyMain.gd`, `Scenes/NPC's/Enemy/Scripts/States/EnemyLaunchedState.gd`
- **SPEC更新**: §5（攻撃ボタン）、B.5.1（自動走行/炎ダッシュ入力）、B.10（Win/Loseのクリア時フリーズ・死亡一元化）
- **テスト**: Godot 4.7 headless で `GameWrapper.tscn` 600フレーム実行しエラーゼロを確認。実プレイ確認は未実施（TODO.md参照）

### 2026-07-13: 敵状態（Angry/Weak）のゲームプレイ効果を実装
- **変更内容**:
  1. `EnemyMain` に `state_speed_mult()` / `state_damage_mult()` / `is_shoulder_immune()` / `is_weak_state()` を追加
  2. Angry: 半キャラずらし無効（ダメージ・敵ノックバックなし、プレイヤーだけ45px弾き返し＋トレーニング時「半キャラ無効(怒り)」表示）、移動1.35倍、敵攻撃1.5倍
  3. Weak: 移動0.5倍、正面衝突でもプレイヤー無傷（一方的ダメージ）、弱り中の敵攻撃はダメージ0、ステージ3ボスの正面ガードも無効
  4. 時間経過起因の怒りを波状化（15秒経過→8秒間怒り→タイマーリセットで通常へ）。HP40%以下起因の怒りは継続
  5. 逃走ボス（ステージ2）は怒りで加速しない（追いつけなくなるため。弱りの減速のみ適用）
- **変更理由**: GAME_SPEC・SPEC §7.2・CURRENT_IMPLEMENTATION に「実装済み」と記載されていたが、実際は見た目の色変化のみでゲームプレイ効果が未実装だった（ドキュメントとコードの重大な乖離）。「かすり→弱り→押し込み」の攻略ループを成立させるコア仕様のため実装
- **影響範囲**: `Scenes/NPC's/Enemy/Scripts/EnemyMain.gd`, `Scenes/Player/Scripts/PlayerMain.gd`, `Scenes/NPC's/Enemy/Scripts/States/EnemyAttackState.gd`・`EnemyChaseState.gd`・`EnemyWanderState.gd`・`EnemyPatrolState.gd`・`EnemyFleeState.gd`
- **SPEC更新**: §7.2 Status（Angry/Weakの効果・発生条件・実装箇所を明記）
- **テスト**: headless 600フレーム実行でエラーなし。実プレイでの体感バランスは未検証

---

## 変更記録テンプレート

今後の変更時は以下のフォーマットで追記:

```
### YYYY-MM-DD: 変更の概要
- **変更内容**: 何を変えたか
- **変更理由**: なぜ変えたか
- **影響範囲**: どのファイルに触ったか
- **SPEC更新**: docs/SPEC.md のどこを更新したか
```
