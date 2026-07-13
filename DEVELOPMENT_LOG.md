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
