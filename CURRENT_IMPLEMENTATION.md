# CURRENT_IMPLEMENTATION.md — 現在の実装状況

**最終更新**: 2026-07-13（コード読み取りによる照合）

**警告**: このファイルは引き継ぎ時点のスナップショット。実装を変更したら更新すること。
また、このファイルを鵜呑みにせず、**必ず実際のコードと照合**すること。

---

## 実装済み（動いている）

### 体当たり戦闘 ★コアシステム
- [x] 正方形AABB（64×64）による接触判定（`PlayerMain._body_contact()`）
- [x] 3種の体当たり: 正面 / 半キャラずらし / かすり
- [x] ずれ（alignment_diff）による自動分岐
- [x] 敵方向への十字入力判定（`pressing_toward_ok`）
- [x] 正面: 両者ダメージ（P:8, E:10）＋ 120px ノックバック＋ 0.3秒クールダウン
- [x] 半キャラ: 敵のみダメージ（6/tick）＋ 60px ノックバック＋ 0.2秒間隔連続ヒット
- [x] かすり: 敵のみダメージ（6）＋ 90px 斜めノックバック＋バレリーナ回転＋ 0.4秒クールダウン
- [x] ノックバックはX軸 or Y軸のみ（イース風。`_axis_knockback()`）
- [x] ノックバック中の無敵フレーム
- [x] 炎ダッシュ時のダメージ倍率（与/被ともに2倍）
- [x] 半キャラずらし時の白ピカピカエフェクト（`FlashPikaPika.gd`）
- [x] 正面衝突時の赤フラッシュ
- [x] かすり時の黄フラッシュ
- [x] トレーニングモード時の判定種別表示（「正面」「半キャラ」「かすり」）

### リング・ロープ
- [x] マット内クランプ（`MAT_LEFT=280, MAT_RIGHT=1000, MAT_TOP=106, MAT_BOTTOM=614`）
- [x] 左右ロープ跳ね返り（`rope_bounce_running`、約800px/s）
- [x] ロープたわみ演出（`ArenaMat.gd`の`bend_rope()`）
- [x] ノックバックでマット外→放物線飛ばし（`PlayerRopeLaunchedState` / `EnemyLaunchedState`）
- [x] カクカクモード時マット色変更（黒グレー）

### プレイヤー
- [x] 滑らか移動（`move_and_slide()`）
- [x] グリッド移動（32pxステップ、`STEP_SIZE=32`）
- [x] Gキーで移動モードトグル
- [x] 自動走行（Nボタン→向いている方向に走り続け、ロープで跳ね返る）
- [x] ダッシュ（N+方向→短時間加速）
- [x] ジャンプ（M→小ジャンプ。空中は体当たり無効、着地で敵踏みダメージ）
- [x] コーナーポストジャンプ（大ジャンプ、6回転、着地で高ダメージ）
- [x] 炎ダッシュ（カクカクモード時Nボタン押し続け。赤く光る。与/被ダメ2倍）
- [x] パワーエサ（速度2倍 or 敵ダメージ無効）
- [x] 2P対応（テンキー＋マウス。専用スプライト `m_man_gr_l1/l2`）
- [x] 死亡時マスク飛び演出（`MaskFlyAway.gd`）
- [x] 空中z_index制御（飛んでいるとき前面、下ロープ手前で背面）
- [x] 敵接触後のアニメ速度変更（2倍速）

### 敵AI
- [x] 5種の行動パターン（Idle / VerticalLoop / HorizontalLoop / RandomRange / Flee）
- [x] プレイヤー検知→チェース移行
- [x] 3状態: Normal / Angry / Weak
- [x] Angry: HP40%以下 or 15秒経過で自動移行。速い、半キャラ無効
- [x] Weak: かすり/踏み後8秒。遅い、どの角度でも一方的ダメージ
- [x] ボス被弾→超高速離脱（`super_flee_remaining`で2.5秒）
- [x] 敵同士の重なり防止（`_push_apart_from_other_enemies()`）
- [x] リングイン演出（画面端から走り込み→山なりジャンプ）
- [x] ダウン状態（動かず赤フラッシュ）
- [x] ステージ3ボス: 正面無敵＋振り向きディレイ
- [x] 空中攻撃ノックバック（ランダム方向＋回転）
- [x] ロープ飛ばし（`EnemyLaunchedState`）

### ステージ・進行
- [x] 4ステージ構成（`StageController.gd`でパラメータ管理）
- [x] ステージごとのボス/雑魚HP・速度・行動パターン設定
- [x] 雑魚の定期増援スポーン
- [x] ボス撃破時QTE（`qte_core.tscn`）
- [x] QTE成功→画面フラッシュ＋ファンファーレ→ステージクリア画面
- [x] QTE失敗→ボスHP20%回復→戦闘続行
- [x] クリア→次ステージ or エンディング
- [x] テストモード（敵HP=2で一撃死）
- [x] トレーニングモード（3体＋ダウン1体、撃破後自動復活）

### UI・シーン遷移
- [x] タイトル画面（1P/2P/テスト/トレーニング/ステージ直接選択/エンディング直接）
- [x] ステージ登場演出（`StageIntro.tscn`）
- [x] ステージクリア画面（`StageClear.tscn`）
- [x] デス画面（コンティニュー/タイトル/終了の3択）
- [x] エンディング画面
- [x] ポーズメニュー（ESC→4択）
- [x] HPバー（色変化: 緑→黄→赤点滅）
- [x] ESC終了確認ダイアログ（タイトル画面）

### オーディオ
- [x] AudioManager（Autoload、プール方式）
- [x] ヒットSE（BLOODY_HIT, PLAYER_ATTACK_HIT）
- [x] 攻撃スイングSE
- [x] コイン取得SE
- [x] パワーエサ取得SE（QuestSound流用）
- [x] スタートジングル、決定音（ファイルがあれば再生）
- [x] クリアファンファーレ（ファイルがあれば再生）

### デバッグ・開発支援
- [x] 体当たり判定可視化（`DebugContactOverlay.gd`、トレーニング時常時表示）
- [x] `GameManager.enemies_frozen`（敵停止フラグ）

---

## SPEC.mdに書かれているが未実装

- [ ] 接触中の移動制限（前後のみ。SPEC B.2）— **現状は制限なし**
- [ ] 敵の量子化移動（16pxステップ。SPEC B.5）— **敵はmove_and_slide()のまま**
- [ ] 飛び道具投擲（SPEC §5）— Out of Scope扱い
- [ ] Enemy HurtBox（Area2D）（SPEC B.1）— **体当たりはArea2Dではなくコードで判定**
- [ ] Player FrontHitBox / SideHitBox（Area2D）（SPEC B.1）— 同上
- [ ] ContactCombat.gd（独立した戦闘管理スクリプト）（SPEC B.2）— **PlayerMain.gdに統合**
- [ ] BoundaryHandler.gd（境界処理スクリプト）（SPEC B.3）— **PlayerMain.gdに統合**

### 補足
SPEC B.1〜B.3で「Area2Dで判定」「別スクリプトで管理」と書かれている部分は、
実装段階で**PlayerMain._body_contact()に一元化**された。
これは意図的な設計判断であり、現状の実装の方が正しい。
SPECのこれらのセクションは初期計画であり、B.0が現行実装を反映している。

---

## 実装されているがSPEC.mdに記載が薄い/無い部分

- **コーナーポストジャンプ**: 四隅のポストから大ジャンプ（6回転＋高ダメージ）。SPEC B.0で言及あるがセクション不足
- **パワーエサ**: 速度2倍 or 敵ダメージ無効。SPECに記載なし
- **自動走行（Nボタン）**: B.5.1で記載あるが、ロープバウンド連携の実装詳細が薄い
- **観客システム**: `Audience.gd` / `AudienceMember.gd`でリング外に観客を配置。SPECに記載なし
- **敵スプライトの動的生成**: `StageController._apply_enemy_sprite()`でSpriteFramesをコードで生成。SPECに記載なし
- **半キャラずらし時の白ピカピカ演出**: `FlashPikaPika.gd`。SPECに記載なし
- **カクカクモード時の視覚変化**: マット色変更・観客色変更。SPECに記載なし
- **敵の重なり防止**: `_push_apart_from_other_enemies()`。SPECに記載なし
- **ステージ3ボスの振り向きディレイ**: `BOSS3_FLIP_DELAY`。SPECに記載なし
- **トレーニングモード**: ダミー敵3体（Normal/Angry/Weak）＋ダウン1体。SPECに記載なし

---

## ファイル⇔機能マッピング

| 機能 | 主要ファイル |
|------|-------------|
| 体当たり判定 | `Scenes/Player/Scripts/PlayerMain.gd` → `_body_contact()` |
| ノックバック・マットクランプ | 同上 → `_physics_process()` |
| ロープバウンド | 同上 + `Scripts/ArenaMat.gd` |
| プレイヤー移動 | `Scenes/Player/Scripts/States/PlayerWalkState.gd` |
| ジャンプ | `Scenes/Player/Scripts/States/PlayerJumpState.gd` |
| 炎ダッシュ | `Scenes/Player/Scripts/States/PlayerFireDashState.gd` |
| ロープ飛ばし(P) | `Scenes/Player/Scripts/States/PlayerRopeLaunchedState.gd` |
| 敵AI・状態 | `Scenes/NPC's/Enemy/Scripts/EnemyMain.gd` |
| ステージ進行・スポーン | `Scripts/StageController.gd` |
| QTE | `Scenes/qte_core.tscn` + `Scenes/qte_main.gd`（シグナルベースに修正済み。StageControllerから呼ばれる） |
| ゲーム全体管理 | `Scripts/Managers/GameManager.gd` |
| タイトル画面 | `Scripts/TitleScreen.gd` |
| デス画面 | `Scripts/Reset.gd` |
| ポーズ | `Scripts/GameWrapperPause.gd` |
| 死亡マスク飛び | `Scripts/MaskFlyAway.gd` |
| 白ピカピカ | `Scripts/FlashPikaPika.gd` |
| デバッグ表示 | `Scripts/DebugContactOverlay.gd` |
| 観客 | `Scripts/Audience.gd` + `Scripts/AudienceMember.gd` |
