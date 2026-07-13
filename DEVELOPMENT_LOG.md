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

### 2026-07-13: バランス第1弾・Ending修正・半キャラフラッシュ修正
- **変更内容**:
  1. ステージ本番パラメータ調整（S1: max6/spawn10s、S2ボスHP100、S3ボス120、S4ボス180）
  2. `Ending.tscn` の invalid unique_id（文字列）を数値に修正（S4クリア後遷移ブロッカー解消）
  3. `FlashPikaPika` の二重 start 呼び出しを修正
- **変更理由**: 半キャラDPS（30/秒）とボスHPの整合、エンディング到達不能バグの解消
- **影響範囲**: `Scripts/StageController.gd`, `Scenes/UI/Ending.tscn`, `Scenes/Player/Scripts/PlayerMain.gd`, `PROGRESS.md`
- **SPEC更新**: 不要（数値の正は StageController）
- **テスト**: headless で Title/GameWrapper/StageClear/Ending/StageIntro/QTE 起動確認

### 2026-07-13: トレーニングラベル・AudioManager・S4フォールバック修正
- **変更内容**:
  1. トレーニングモードの体当たり種別表示に `弱り(正面/半キャラ/かすり)` / `半キャラ無効(怒り)` を追加
  2. `AudioManager.max_players` 8→16（TD-09 暫定対処）
  3. `StageController._spawn_enemy_at` S4ボスHPフォールバック 250→180（`_setup_normal_params` と整合）
  4. `PlayerFireDashState` 維持判定を `Dash`/`Punch2` に統一（KI-13）
- **変更理由**: トレーニングでの状態確認を容易に。SE途切れ低減。パラメータ不整合の防御
- **影響範囲**: `PlayerMain.gd`, `AudioManager.gd`, `StageController.gd`, `PROGRESS.md`, `TECHNICAL_DEBT.md`
- **SPEC更新**: 不要（トレーニング表示はUI補助。数値は StageController が正）
- **テスト**: headless GameWrapper 起動確認

### 2026-07-13: 半キャラ連打復活・ロープダッシュ攻撃・敵の脅威付与・実害バグ修正・2P整合
- **変更内容**:
  1. **半キャラ連打の復活**（`PlayerMain.gd`）: `PUSH_KNOCKBACK` を 90→60 に戻す。`PAST_DESIGN_DECISIONS.md` #3 で「60が良い」と実証済みの値。90だと体当たり用AABB（中心差66以内）に対してノックバックが大きすぎ、毎ティック接触が切れて半キャラ連打による押し込みが成立していなかった。あわせてステージ4の半キャラ超反動を 150→90 に修正（正面の150pxより控えめにして連打を優先）。未使用の残骸定数 `BODY_PUSH_PIXELS` を削除。
  2. **ロープダッシュ攻撃**（没案#2の復活。`PlayerMain.gd`）: `rope_bounce_running`（ロープバウンド自動横断中、約800px/s）中にショルダー/かすりがヒットするとダメージ2倍。炎ダッシュ（`fire_dash_damage_mult`）と重複時は乗算せず高い方のみ採用。ヒット時にSE強化＋`hit_particles`強化（amount 40 / lifetime 0.8）。トレーニング表示は「ロープ(半キャラ)」「ロープ(かすり)」で区別。
  3. **初見導線**: ステージ1イントロに半キャラずらしの導線（「敵の真横に半分ずれてぶつかれ！一方的に押し込める」＋Gキー案内）を追加。ステージ2イントロの「ジャンプ中は止まる」表現を「ジャンプすると逃げ足が止まる」に明確化（`EnemyFleeState` の実装と一致する表現に）。
  4. **敵の脅威付与**（バランス第2弾）: `EnemyChaseState.move_speed` 80→140、検知半径（`DetectionShape`）87.4→120、`EnemyFleeState.move_speed` 600→440（`super_flee_speed`は1400のまま）。いずれも `Enemy.tscn` 側の同名オーバーライドも合わせて修正（@exportのためシーン側の値が優先されるため）。
  5. **AudioManagerプール拡張バグ**（KI-14/TD-09）: `play_sound()` の `available_player` 初期値が `audio_players[0]` で「新規作成」分岐に実質到達できず、全員再生中だと再生中の音を問答無用で上書きしていた。初期値を`null`にし、空き探索→新規作成→フォールバックの順に修正。
  6. **無敵期限の強制解除バグ**（KI-15）: `CharacterBase.after_damage_iframes()` の末尾 `invincible = false` が `set_invincible_for()` の期限管理を無視していた。同じ `_invincible_until_ms` 期限方式に統一し、より長い無敵が設定されていれば解除しないよう修正。
  7. **S3ボス正面ガード演出**（KI-16）: 敵側への赤フラッシュがトレーニングモード限定になっており、本番プレイでガード演出が一切出ていなかった。トレーニング/本番問わず、ボス側に青白フラッシュ（`Color(0.7, 0.9, 2.0)`）を常に出すよう修正（ダメージの赤と区別）。
  8. **2P整合**（KI-17/KI-18）: ロープバウンス解除判定の `Input.is_action_just_pressed("Dash")` が2Pでも1Pキーを見ていたのを `is_player_two` で `Punch2` に分岐。QTE（`qte_main_with_anim.gd`）の成功判定に `Punch2` を追加。
- **変更理由**: 「半キャラ連打」という中核の攻略ループが未実装同然だった（最優先で復旧）。ロープワークと戦闘を繋げる没案の復活でプレイの幅を広げる。敵が弱すぎ・検知が狭すぎて脅威になっていなかった問題の是正。実プレイに影響する既知バグ（SE上書き、無敵期限の早期解除、ボス側演出欠落、2Pの一部操作無効）の解消。
- **影響範囲**: `Scenes/Player/Scripts/PlayerMain.gd`, `Scripts/StageIntro.gd`, `Scenes/NPC's/Enemy/Scripts/States/EnemyChaseState.gd`, `Scenes/NPC's/Enemy/Scripts/States/EnemyFleeState.gd`, `Scenes/NPC's/Enemy/Enemy.tscn`, `Scripts/Managers/AudioManager.gd`, `Scripts/CharacterBase.gd`, `Scenes/qte_main_with_anim.gd`, `CLAUDE.md`, `docs/SPEC.md`, `TECHNICAL_DEBT.md`, `KNOWN_ISSUES.md`, `OPEN_QUESTIONS.md`
- **SPEC更新**: B.0（PUSH_KNOCKBACK 60、S4半キャラ超反動90、本文/表の90/60矛盾を60で統一）、B.0.1（新規: ロープダッシュ攻撃）、8.1（新規: 敵の速度・検知範囲の現行値）、B.5.1（2Pロープバウンス解除キー）、B.9（QTE入力にPunch2追記）、まとめ節のS3ガード演出更新
- **テスト**: headless（`GameWrapper.tscn` / `TitleScreen.tscn`）600フレーム実行でエラーなしを確認予定（本エントリ追記時点、詳細は本セッションの報告を参照）

---

### 2026-07-13: ステージ1クリア条件の可視化・正面衝突の誤学習防止ヒント（UI導線第2弾）
- **変更内容**:
  1. **ステージ1 生存敵数HUD**（`Scripts/GameUI.gd`, `Scripts/StageController.gd`, `Scripts/Managers/GameManager.gd`）: 画面右上に「敵 X体（最大Y体・全滅でクリア）」を常時表示（本番プレイのみ、S2〜4/トレーニングは非表示）。ステージ1の増援は`spawn_interval`ごとに際限なく補充される「無限湧き・場の同時数のみ上限あり」方式で、累計の「残り総数」は存在しないため、固定数ではなく現在の生存数＋同時上限＋「全滅でクリア」という実装と矛盾しない表現にした。
  2. **正面衝突の誤学習防止ヒント（ワンショット）**（`Scenes/Player/Scripts/PlayerMain.gd`, `Scripts/Managers/GameManager.gd`, `Scripts/GameUI.gd`）: ステージ1・本番プレイ限定で、正面衝突を累計3回起こした時点で「真正面は相打ち！半分ずれてぶつかれば一方的に押し込める！」を画面上部中央に3.5秒だけ一度表示。既に半キャラずらしを3回以上決めているプレイヤーには出さない（分かっている人に説教しない）。1プレイ（ステージ1再挑戦のたび）につき1回、`StageController._ready()`でカウンタをリセット。
- **変更理由**: Opus評価で指摘された「クリア条件が不透明（増援の仕組みが見えない）」「正面衝突を繰り返すと痛み分けが正解だと誤学習しかねない」への対処。既存の`body_contact_type_text`（トレーニング表示）と同じ「Autoload経由でHUDに通知」パターンを踏襲し、新規シーン/リソースは追加せず最小実装で対応。
- **影響範囲**: `Scripts/Managers/GameManager.gd`, `Scripts/StageController.gd`, `Scripts/GameUI.gd`, `Scenes/Player/Scripts/PlayerMain.gd`, `docs/SPEC.md`
- **SPEC更新**: §9.1（新規：ステージ1クリア条件の実際の仕組み）、§12（HUD/ヒットの追記）、B.11.1（新規：生存敵数HUD実装詳細）、B.11.2（新規：誤学習防止ヒント実装詳細）
- **テスト**: headless（`GameWrapper.tscn`）600フレーム実行でエラーなしを確認

### 2026-07-13: Phase A システム変更（Sonnet中断 → Composer完成）
- **変更内容**: グリッド/炎ダッシュ/コーナーポスト廃止、半キャラ左右限定、SEMI_CAR_MAX 52、四辺ロープバウンド、ロープダッシュ1.5倍、パワーエサ統一、ジャンプ多重バインド
- **変更理由**: Fable Phase A 設計（`DESIGN_CHANGELOG.md`）
- **影響範囲**: PlayerMain/States, PowerBait, ArenaMat, CornerPost, StageIntro, project.godot, SPEC, HANDOFF, TODO
- **SPEC更新**: B.0 / B.0.1 / B.5.1 / §3 / §5 / §6
- **テスト**: headless 主要6シーン ALL_OK

## 変更記録テンプレート

今後の変更時は以下のフォーマットで追記:

```
### YYYY-MM-DD: 変更の概要
- **変更内容**: 何を変えたか
- **変更理由**: なぜ変えたか
- **影響範囲**: どのファイルに触ったか
- **SPEC更新**: docs/SPEC.md のどこを更新したか
```
