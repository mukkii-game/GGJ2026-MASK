# SPEC: Body-check Arena（v0.3）

## 1. Game Definition
本作はトップダウン視点の体当たりアクションゲームである。  
通常攻撃は存在せず、キャラクター同士の**接触状態**を基本戦闘とする。

戦闘の主軸は以下の2点で構成される。
- 正面接触によるダメージ交換
- 「半キャラずらし」による一方的攻撃

---

## 2. Core Combat System

### 2.1 接触戦闘の基本ルール
- Player と Enemy が接触すると戦闘状態に入る
- 接触中は **0.5秒ごと（敵ごとに可変）** にダメージ処理が発生する
- ダメージは **交互に** 適用される（疑似ターン制）

### 2.2 接触中の移動制限
- 接触中、キャラクターは **前進または後退のみ可能**
- 横移動は不可
- 両者が前進入力を続けた場合、位置は固定される（押し合い）
- 一方のみが前進入力を行った場合、相手を押し込む

---

## 3. 半キャラずらし（主要メカニクス）

### 3.1 定義
- Player の中心線が Enemy の中心線から一定距離以上ずれて接触した状態を  
  **「半キャラ接触（Side）」** と定義する

### 3.2 半キャラ接触の効果
- Enemy のみがダメージを受ける
- Player はダメージを受けない
- Enemy は軽いノックバックを受ける
- Player が前進入力を維持している場合、連続して一方的攻撃が可能

### 3.3 正面接触（Front）
- 両者がダメージを受ける
- ダメージ処理は交互に行われる

---

## 4. ノックバック・境界処理
- 半キャラ接触時、Enemy は短距離ノックバックする
- 画面端に到達した場合：
  - 両者は強制的に弾かれ
  - 画面内のランダム位置に再配置される

---

## 5. 攻撃ボタン（コンテキスト依存）
攻撃ボタンは常に同じ効果を持たない。

| 状況 | 効果 |
|---|---|
| 飛び道具所持 | 飛び道具を投擲 |
| 通常状態 | 短時間の高速ダッシュ |
| ダッシュ中に敵接触 | ノックバック強化 |
| Enemy | 同様の行動を取る |

---

## 6. 移動仕様（レトロ量子化）
- 移動は **半キャラ単位の量子化移動**
- PCおよび敵は32x32ピクセル
- グリッドはその半分にするため：16px ステップ
- 見た目は PC-8801 世代のカクカク移動
- 内部的にアナログ速度を持ってもよいが、表示は量子化する

---

## 7. Enemy Specification

### 7.1 敵タイプ差
- 半キャラ接触のみ有効な敵
- 半キャラ接触が無効な敵
- 状態により半キャラ接触が無効になる敵

### 7.2 Status（状態）
Enemy は以下の状態（Status）を持つ。  
状態は見た目・挙動・ダメージ判定に影響する。

#### Normal
- 通常状態
- 半キャラ接触（Side）が有効
- 速度・攻撃力は基準値

#### Angry
- 見た目が赤色に変化
- 専用エフェクトが付与される
- 半キャラ接触（Side）は無効
- 正面接触（Front）のみ有効
- Enemy の移動速度が上昇
- Enemy のダメージ量が増加

#### Weak
- 見た目が青色に変化
- 専用エフェクトが付与される
- Enemy の移動速度が低下
- 半キャラずらしを満たさなくても一方的ダメージが成立する
- Player は正面接触でもダメージを受けない

---

## 8. Enemy AI
- 障害物回避なし
- Player 方向へ直線追尾、または決められた経路を巡回
- 移動は Player と同様に量子化される
- 特定条件で援軍を呼ぶ敵が存在する
  - 援軍は低HP・低速度・多数出現

---

## 9. Stage
- 壁 / ブロックは通行不可
- 左右上下にロープ判定を配置
  - 接触時、反射＋速度2倍
  - ダメージ補正ボーナスあり
  - 効果は一定時間で解除

---

## 10. Finisher QTE

### 発生条件
- Enemy HP が 0 になる
- または Enemy 固有条件達成

### 内容
- Enemy 専用の短時間 QTE
- 制限時間：数秒
- 入力は単純で即時理解可能なものとする

### 結果
- 成功：勝利
- 失敗：Enemy HP を一定量回復して戦闘再開

---

## 11. Win / Lose
- Win：敵全滅、またはゴール到達
- Lose：Player HP == 0

---

## 12. UI / FX（P1）
- HP表示（Player / Enemy）
- ヒット時フラッシュ / SE
- タイトル画面 / リトライ

---

## 13. Out of Scope（v0.3）
- ネット対戦
- キャラ選択
- 複雑な技コマンド
- ストーリー進行

---

## 付記：設計意図（非仕様）
- 「イース的半キャラずらし」を明確な勝ち筋にする
- 操作量よりも **位置と状態の理解**を重視する
- 押し合いを疑似ターン制で安全に表現する

---

# 実装ガイド（SPEC に基づく具体的な処理・アセット・変更箇所）

本ドキュメントは SPEC v0.3 を実装するために、**どの処理をどこで行うか**を具体的にまとめたものである。  
既存の Topdown Pixelart Starter を壊さず、追加・最小変更で進める前提。

---

## A. 実装の優先順と依存関係

| 順 | ブロック | 内容 | 依存 |
|---|----------|------|------|
| 1 | **接触判定の土台** | Front/Side 判定用 HitBox・HurtBox の追加と重なり検知 | なし |
| 2 | **接触戦闘** | 0.5秒ごとの交互ダメージ、接触中の移動制限 | 1 |
| 3 | **押し合い・ノックバック** | 前/後のみ移動、Side 時のノックバック | 2 |
| 4 | **HP・勝敗** | HP 表示の仕様合わせ、Win/Lose 表示の明確化 | 既存＋2 |
| 5 | **Enemy Status** | Normal/Angry/Weak、半キャラ有効/無効の分岐 | 2,3 |
| 6 | **Enemy 量子化移動** | 敵の 16px ステップ移動 | 既存 Chase |
| 7 | **ステージ・ロープ** | ロープ Area と反射・速度2倍・ダメージ補正 | 既存マップ |
| 8 | **Finisher QTE** | 敵撃破時 QTE、成功/失敗で HP 回復 | 4,5 |
| 9 | **UI/FX** | HP 表示統一、ヒットフラッシュ/SE、タイトル・リトライ | 既存 |

---

## B. SPEC セクション別の具体的な処理

### B.1 接触戦闘の土台（§2, §3 の前提）

**やること**

1. **Player に「接触用」の判定を追加（攻撃 Hitbox とは別）**
   - **FrontHitBox**: キャラの「正面」の幅（例: 中心から左右 8px 以内＝半キャラ）を矩形 Area2D で表現。  
     - 置き場所: `Player.tscn` の `CharacterBody2D` 直下、または `AnimatedSprite2D` 直下。  
     - 衝突レイヤー: 敵の HurtBox とだけ当たるようにする（例: layer=2, mask=4）。
   - **SideHitBox**: 正面以外の「横方向」の接触。  
     - 左右に細長い矩形を 2 つ、または 1 つの Area2D で左右に分けて検知してもよい。  
     - 判定: 「Player 中心と Enemy 中心の X 差分の絶対値が 閾値（例: 16）以上」なら Side。
   - 既存の `Punch_Hitbox` / `Kick_Hitbox` は**攻撃アクション用**のまま残す。

2. **Enemy に HurtBox を追加**
   - 置き場所: `Enemy.tscn` の `CharacterBody2D` 直下、または `AnimatedSprite2D` 直下。  
   - 1 つの Area2D + RectangleShape2D（キャラ全体を覆う程度）でよい。  
   - 衝突: Player の FrontHitBox / SideHitBox と当たるようにレイヤー設定。

3. **重なり検知でログ出力（デバッグ用）**
   - Player の FrontHitBox / SideHitBox の `body_entered`（または `area_entered`）で、  
     「Front 接触」「Side 接触」を判別して `print()` またはログ用シグナルで出力。  
   - 判別ロジック: 両者の `global_position.x` の差が閾値未満 → Front、以上 → Side。

**触るファイル・ノード**

| 対象 | ファイル | 変更内容 |
|------|----------|----------|
| Player シーン | `Scenes/Player/Player.tscn` | FrontHitBox, SideHitBox 用 Area2D＋CollisionShape2D を追加。必要ならスクリプトで「正面方向」に合わせてオフセット。 |
| Player スクリプト | 接触状態を保持するなら `PlayerMain.gd` または新規 `ContactState.gd` | 変数例: `var in_contact_with: Node2D = null`, `var is_side_contact: bool`。 |
| Enemy シーン | `Scenes/NPC's/Enemy/Enemy.tscn` | HurtBox 用 Area2D＋CollisionShape2D を追加。collision_layer/mask を Front/Side HitBox と合わせる。 |

---

### B.2 接触戦闘のルール（§2.1, §2.2, §3）

**やること**

1. **戦闘状態の開始**  
   - Player の FrontHitBox または SideHitBox が Enemy の HurtBox と重なった瞬間に「接触状態」に入る。  
   - 接触中は **0.5 秒（敵ごとに可変）タイマー** でダメージ処理。

2. **ダメージの交互適用（疑似ターン制）**  
   - 変数で「次にダメージを受けるのは Player か Enemy か」を保持。  
   - 0.5 秒ごとに: Front なら両者に 1 ダメージずつ交互に適用（先にどちらか決める）。  
   - Side なら Enemy のみダメージ（§3.2）。  
   - ダメージ量は仮値（例: 1）でよい。

3. **接触中の移動制限**  
   - 接触中は **前進・後退のみ**（横移動禁止）。  
   - 「前進」は、相手に向かう方向の入力のみ有効。  
   - 両者が前進入力 → 位置固定（押し合い）。  
   - 一方だけ前進 → 相手を押し込む（速度で少し移動させる、またはノックバックと統合）。

**触るファイル・ノード**

| 対象 | ファイル | 変更内容 |
|------|----------|----------|
| プレイヤー移動 | `Scenes/Player/Scripts/States/PlayerWalkState.gd` | `Move()` 内で「接触中か」を参照。接触中なら `input_dir` を「相手方向の前後」に射影したベクトルだけ使う。滑らか/グリッド両方の分岐で同じ制限をかける。 |
| ダメージ処理 | `Scripts/CharacterBase.gd` | `_take_damage(amount)` は既存のまま利用。呼び出し元で「0.5秒ごと」「交互」を実装。 |
| 接触タイマー・交互制御 | 新規推奨: `Scripts/ContactCombat.gd` または PlayerMain/EnemyMain にメソッド追加 | 0.5 秒タイマー、次の被弾側フラグ、Front/Side の判定結果を保持。Player–Enemy のペアごとに 1 つ管理するイメージ。 |
| 敵の移動 | `Scenes/NPC's/Enemy/Scripts/States/EnemyChaseState.gd` | 接触中は追尾せず、前後のみ移動するロジックを追加（後述 B.6 と併せて）。 |

---

### B.3 半キャラ接触の効果・ノックバック・境界（§3.2, §4）

**やること**

1. **Side 接触時**  
   - Enemy のみ `_take_damage(1)`（仮値）。  
   - Enemy に**短距離ノックバック**（速度ベクトルまたは `position += 方向 * 距離`）。  
   - Player はダメージなし。

2. **画面端**  
   - 両者が画面端に達したら、両者をいったん弾き、**画面内のランダム位置に再配置**。  
   - 画面範囲は `get_viewport_rect()` や Camera2D の範囲で取得。

**触るファイル・ノード**

| 対象 | ファイル | 変更内容 |
|------|----------|----------|
| ノックバック | EnemyMain または ContactCombat | Side 判定の直後に Enemy の `global_position += ノックバック方向 * 距離`。`move_and_slide()` を使う場合は `velocity` に加算。 |
| 境界処理 | 新規 `Scripts/BoundaryHandler.gd` または GameManager | 毎フレームまたはタイマーで Player/Enemy の位置をチェック。端を超えたら再配置。 |

---

### B.4 攻撃ボタンのコンテキスト（§5）

**やること**

- **通常**: 現状どおりダッシュ（既存の Dash）。  
- **ダッシュ中に敵接触**: ノックバック強化（ノックバック距離/速度を倍にするなど）。  
- **飛び道具**: v0.3 では Out of Scope なので未実装でよい。  
- **Enemy**: 同様に「通常＝移動/体当たり」「接触時＝押し合い」でよい。

**触るファイル**

- `PlayerWalkState.gd`: ダッシュ中に `in_contact_with != null` なら、ノックバック時に「強化フラグ」を渡す。  
- ノックバック処理側でそのフラグを見て距離を変える。

---

### B.5 移動仕様（§6）— 既存との整合

**現状**

- Player: 16px ステップのグリッド移動＋G で滑らか/カクカク切替（`PlayerWalkState.gd`, `PlayerMain.gd`）。  
- Enemy: 連続的な `velocity` + `move_and_slide()`（`EnemyChaseState.gd`）。

**やること**

- **Enemy の量子化**: `EnemyChaseState.gd` の `Update` で、Player と同様に「16px ステップ＋test_move」で移動するブロックを追加。  
  - 既存の `body.velocity` + `move_and_slide()` を、ステップ用の `position += step` に差し替え（接触中は B.2 の前後のみ制限をかける）。  
- **表示の量子化**: 既に 16px で止めているので、そのままでよい。

**触るファイル**

- `Scenes/NPC's/Enemy/Scripts/States/EnemyChaseState.gd`: 移動ロジックを 16px ステップ＋壁判定に変更。

---

### B.5.1 プレイヤー自動走行（Nボタン）とロープバウンド連携

**概要**

- プレイヤーは **Nボタン（`Punch` アクション、初期割り当て: Nキー/左クリック）** で「自動走行モード」に入る。  
- 自動走行中は、移動キー入力がない限り **一定方向に走り続ける**。  
- マット端のロープに触れると、SPEC §9 のとおり **ロープで跳ね返り（反対側へ自動移動）** し、その後も自動走行が継続する。

**入力仕様**

- **通常（滑らか）モード時**  
  - Idle 中に Nボタンを 1 回押す → プレイヤーの向いている左右方向に自動走行開始。  
  - Moving 中に Nボタンを押した場合も、停止中かつ方向入力がなければ同様に自動走行開始。  
  - **移動キー（十字キー／WASD など）を入れると、自動走行は解除される。**
- **カクカク（グリッド）モード時**  
  - 既存仕様どおり、Nボタン押しっぱなしで **炎ダッシュ状態（`PlayerFireDashState`）** を維持する。  
  - このモードでは Nボタンは自動走行のトリガーにはならない。

**ロープとの連携**

- Player がジャンプ中でない状態でマット端（上下左右）のロープ境界に達すると、`PlayerMain.gd` 側で  
  - `rope_bounce_running = true`  
  - `rope_bounce_direction` / `rope_bounce_target`  
  を設定し、**ロープバウンド用の自動移動**が開始される。  
- ロープバウンド中は `PlayerWalkState.gd` 側では移動を行わず、`PlayerMain.gd` の処理に任せる。  
- ロープバウンド終了後、`auto_run_direction` が有効であればそのまま自動走行を継続する。  
- プレイヤーが移動入力または Nボタン以外の操作を行った場合、  
  - ロープバウンドは既存どおり停止し、  
  - 自動走行も「移動キー入力」によって解除される。

**触るファイル**

- `Scenes/Player/Scripts/PlayerMain.gd`  
  - 変数 `start_auto_run`, `is_auto_running`, `rope_bounce_running` などを管理。  
  - `is_auto_running` は `WindEffect` ノードの可視状態制御に使用。
- `Scenes/Player/Scripts/States/PlayerIdleState.gd`  
  - Nボタン押下時に、通常モードでは `start_auto_run = true` を立てて `"Moving"` ステートへ遷移。  
  - グリッドモードでは `FireDash` へ遷移（従来どおり）。
- `Scenes/Player/Scripts/States/PlayerWalkState.gd`  
  - `auto_run_direction` による自動走行ロジックを実装。  
  - 移動キー入力時に自動走行を解除。  
  - `player_main.rope_bounce_running` が true の間は、移動処理を行わず PlayerMain 側のロープバウンド処理に委譲。

---

### B.6 Enemy 仕様（§7）— Status とタイプ

**やること**

1. **Status の定義**  
   - `EnemyMain.gd` に `enum Status { Normal, Angry, Weak }` と `var current_status: Status = Status.Normal` を追加。  
   - 見た目: `sprite.modulate` で Normal=白、Angry=赤、Weak=青など。

2. **半キャラの有効/無効**  
   - Angry: Side 接触ではダメージを与えない（Enemy が受けない）。Front のみ両者ダメージ。  
   - Weak: 半キャラを満たさなくても一方的ダメージ可。正面でも Player はダメージを受けない。  
   - 接触判定側（ContactCombat や HitBox コールバック）で、`enemy.current_status` を見て分岐。

3. **速度・攻撃力**  
   - Angry: `move_speed` 増、ダメージ量増（Enemy が与えるダメージを表す変数を増やす）。  
   - Weak: `move_speed` 減。

**触るファイル・ノード**

| 対象 | ファイル | 変更内容 |
|------|----------|----------|
| Enemy | `Scenes/NPC's/Enemy/Scripts/EnemyMain.gd` | Status 列挙、current_status、modulate 切り替え、速度・ダメージ係数。 |
| 接触戦闘 | ContactCombat またはダメージ適用箇所 | Status に応じた Side/Front の有効/無効と、誰がダメージを受けるかの分岐。 |

---

### B.7 Enemy AI（§8）

**やること**

- 障害物回避なし → 現状の直線追尾でよい。  
- 量子化移動 → B.5 で対応。  
- 援軍を呼ぶ敵: 特定 Enemy に「HP が一定以下で援軍スポーン」のスクリプトを追加。援軍は別シーンまたは同じ Enemy シーンを `instance()` して配置。低 HP・低速度・複数にする。

**触るファイル**

- 援軍用: 新規 `Scripts/EnemySpawner.gd` または EnemyMain にメソッド追加。  
- スポーン位置はマップまたはランダム。`MainFloor.tscn` / `Basement01.tscn` でスポーン用 Node2D を置いてもよい。

---

### B.8 Stage・ロープ（§9）

**やること**

- マップの左右上下に「ロープ」用 Area2D を配置。  
- 接触時: 反射（速度ベクトルを反転）＋速度 2 倍、ダメージ補正バフを一定時間付与。  
- 効果はタイマーで解除。

**触るファイル・ノード**

| 対象 | ファイル | 変更内容 |
|------|----------|----------|
| ロープ | 新規 `Scenes/Interactables/RopeArea.tscn` + `Scripts/RopeArea.gd` | Area2D、body_entered で Player/Enemy を取得。速度反転＋2倍、バフタイマー開始。 |
| マップ | `MainFloor.tscn` / `Basement01.tscn` | 四辺に RopeArea を配置。 |

---

### B.9 Finisher QTE（§10）

**やること**

1. **発生条件**: Enemy HP == 0（または固有条件）のとき、即座に死亡させず「QTE 状態」に遷移。  
2. **QTE 内容**: 短時間（数秒）で、単純なキー入力（例: 表示されたキーを押す）。  
3. **結果**: 成功 → 敵削除・勝利扱い。失敗 → Enemy HP を一定量回復し、戦闘再開。

**触るファイル・ノード**

| 対象 | ファイル | 変更内容 |
|------|----------|----------|
| 敵死亡 | `Scripts/CharacterBase.gd` の `_die()` または EnemyMain のオーバーライド | HP==0 でまず QTE 用シーン/ノードを表示。結果を待つ。 |
| QTE UI | 新規 `Scenes/UI/FinisherQTE.tscn` + スクリプト | ラベル＋タイマー＋入力検知。成功/失敗シグナルを emit。 |
| Enemy | EnemyMain | QTE 失敗時に HP 回復して Idle/Chase に戻す。 |

---

### B.10 Win / Lose（§11）

**やること**

- **Win**: 敵全滅またはゴール到達で VictoryScreen 表示。既存 `VictoryScreen.tscn` + `Reset.gd` を利用。  
- **Lose**: Player HP == 0 で DeathScreen。既存 `PlayerMain._die()` → DeathScreen 表示でよい。  
- 敵全滅の検知: 現在のシーンの Enemy 数を数える、または GameManager で「クリア条件」フラグを立てる。

**触るファイル**

- `Scripts/Managers/GameManager.gd`: 例: `var current_level_cleared: bool`、敵全滅時に true。  
- `Scenes/Levels/Basement01.tscn` 等: 敵が 0 になったら VictoryScreen を表示するトリガー（シグナルや _process で敵ノード数をチェック）。

---

### B.11 UI / FX（§12）

**やること**

- **HP 表示**: Player/Enemy とも既存の ProgressBar をそのまま利用。最大値・現在値を SPEC の HP 値に合わせる。  
- **ヒット時フラッシュ**: 既存の `CharacterBase.damage_effects()`（赤フラッシュ）を維持。  
- **SE**: 既存の `AudioManager`（BLOODY_HIT 等）をそのまま使用。  
- **タイトル画面・リトライ**: 既存の Restart/Escape/Enter でよい。必要ならタイトル用シーンを 1 つ追加。

---

## C. 必要アセット一覧（推奨）

| 種別 | 内容 | 既存/新規 | 備考 |
|------|------|-----------|------|
| **タイル** | マップ用 32x32 タイル | 既存 `Art/Sprites/TileSheet-Sheet.png` | 差し替え可。ロープ用タイルがあれば追加。 |
| **キャラ** | Player/Enemy 32x32 スプライト | 既存 | Status 用に赤/青の色変更は modulate で対応可。 |
| **エフェクト** | ヒットパーティクル | 既存 `Art/Particles/hit_particles.tscn` | そのまま利用。 |
| **UI** | HP バー、QTE 用ラベル | 既存＋新規 | QTE 用フォントは既存ピクセルフォントで可。 |
| **SE** | ヒット、ダッシュ、QTE 成功/失敗 | 既存＋必要なら追加 | `Art/Audio/Effects/` に配置。 |
| **ロープ** | 見た目（任意） | 新規 | 四角やラインの Sprite でよい。無くても Area のみで可。 |

---

## D. ファイル・場所別の変更一覧

| ファイル | 変更種別 | 具体的な内容 |
|----------|----------|----------------|
| `Scenes/Player/Player.tscn` | 追加 | FrontHitBox, SideHitBox 用 Area2D＋Shape。レイヤー設定。 |
| `Scenes/Player/Scripts/PlayerMain.gd` | 追加 | 接触フラグ・相手参照。必要なら G トグルはそのまま。 |
| `Scenes/Player/Scripts/States/PlayerWalkState.gd` | 変更 | 接触中は前後のみ移動に制限。ダッシュ中接触でノックバック強化。 |
| `Scenes/NPC's/Enemy/Enemy.tscn` | 追加 | HurtBox 用 Area2D＋CollisionShape2D。 |
| `Scenes/NPC's/Enemy/Scripts/EnemyMain.gd` | 追加・変更 | Status 列挙、current_status、modulate、速度・ダメージ係数。QTE 失敗時 HP 回復。 |
| `Scenes/NPC's/Enemy/Scripts/States/EnemyChaseState.gd` | 変更 | 16px ステップ移動。接触中は前後のみ。 |
| `Scripts/CharacterBase.gd` | 参照のみ | `_take_damage` は既存のまま。呼び出し元で 0.5 秒・交互を実装。 |
| 新規 `Scripts/ContactCombat.gd`（または類似） | 新規 | 0.5 秒タイマー、Front/Side 判定、交互ダメージ、ノックバック呼び出し。 |
| 新規 `Scripts/BoundaryHandler.gd`（任意） | 新規 | 画面端で両者を弾き、ランダム再配置。 |
| 新規 `Scenes/Interactables/RopeArea.tscn` + スクリプト | 新規 | ロープ接触で反射＋2倍＋バフ。 |
| 新規 `Scenes/UI/FinisherQTE.tscn` + スクリプト | 新規 | QTE 表示・入力・成功/失敗シグナル。 |
| `Scripts/Managers/GameManager.gd` | 追加 | レベルクリアフラグ、敵数カウント用の参照など（必要に応じて）。 |
| `Scenes/Levels/MainFloor.tscn` / `Basement01.tscn` | 追加 | ロープ用 Area。敵全滅時の Victory トリガー用ノード/スクリプト。 |

---

## E. 既存コードとの整合ポイント

1. **攻撃 Hitbox（Punch/Kick）**  
   - 現状: `PlayerAttackState` の `_on_hitbox_body_entered` で Enemy にダメージ。  
   - SPEC では「通常攻撃は存在せず、接触戦闘が主」。  
   - 方針: 接触戦闘を主軸にしつつ、Punch/Kick は「ダッシュや特殊アクション」として残すか、または無効化するかは仕様で決定。  
   - 実装時は、接触用 Front/Side HitBox と、攻撃用 Punch/Kick Hitbox の**レイヤーを分けて**混在させないようにする。

2. **Enemy の攻撃**  
   - 現状: `EnemyAttackState` で HitBox が有効になり Player にダメージ。  
   - SPEC では敵も「接触戦闘・押し合い」。  
   - 方針: 敵の「攻撃アニメ」は接触中のダメージタイミングに合わせて再生するか、または Chase 中は体当たりのみにして Attack 状態を接触に統合する。

3. **HP の初期値**  
   - Player: `Player.tscn` で `health = 200` 等。SPEC に合わせて調整。  
   - Enemy: `Enemy.tscn` で `health = 75`。こちらも SPEC のバランスに合わせる。

4. **シーン遷移**  
   - 既存の `AreaExit` + `next_scene` でゴール到達は実装済み。敵全滅時の Victory は、同じシーン内で敵数を監視して VictoryScreen を表示する形でよい。

---

以上を SPEC の「どこをどういじるか」の参照として使用できる。
