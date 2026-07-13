# SPEC: Body-check Arena（v0.3 / 実装反映: 2026-02-11）

## 1. Game Definition
本作はトップダウン視点の体当たりアクションゲームである。  
通常攻撃は存在せず、キャラクター同士の**接触状態**を基本戦闘とする。

戦闘の主軸は以下の2点で構成される。
- 正面接触によるダメージ交換
- 「半キャラずらし」による一方的攻撃

---

## 2. Core Combat System (現行実装準拠)

本作はトップダウン視点の体当たりアクションゲームである。
通常攻撃は存在せず、キャラクター同士の**接触状態（位置取りと入力）**を基本戦闘とする。

### 2.1 接触判定の基本ルール
- Player と Enemy の接触判定は **64x64ピクセルの正方形AABB**（中心から±32）で行われる。
- 接触時の「Playerの押し込み入力」と「縦横のズレ（Alignment Difference）」によって、発生する事象が3種類（正面、半キャラ、かすり）に分岐する。

### 2.2 ズレ（Alignment Diff）の定義
- プレイヤーから敵への方向が「主に横方向」の場合、**Y座標の差の絶対値** をズレとする。
- 「主に縦方向」の場合、**X座標の差の絶対値** をズレとする。

---

## 3. 体当たりの種類と効果（主要メカニクス）

### 3.1 正面衝突（Front / ズレ 0〜31）
- **判定条件**: ズレが **32未満**（半分以上が向かい合っている）、**または** プレイヤーが敵の方向へ十字入力を入れていない場合。
- **効果（ダメージ）**: 
  - **両者**がダメージを受ける。（Player: 8, Enemy: 10 / FireDash等の倍率により変動）
  - 0.3秒のクールダウンが発生する。
- **効果（ノックバック）**:
  - 両者が接触軸に対して反対方向に大きく弾き飛ばされる（120px）。処理中は無敵状態となる。

### 3.2 半キャラずらし（Shoulder Tackle / ズレ 32〜57）
- **判定条件**: ズレが **32以上 58未満**（半分以下が向かい合っている）かつ、プレイヤーが敵の方向へ十字入力を入れている場合。
- **効果（ダメージ）**:
  - **Enemy のみ**が一方的にダメージを受ける。（1回 6ダメージ）
  - プレイヤーが押し込み続ければ、0.2秒間隔で連続ヒットする。
- **効果（ノックバック）**:
  - Enemy は接触した軸方向（Xのみ、またはYのみ）へ弾き飛ばされる（60px）。
  - Player は反動として軽く後退する（6px）。連続で押し込みながらの攻撃（追撃）が可能。

### 3.3 かすり（Graze / ズレ 58〜63）
- **判定条件**: ズレが **58以上 64未満**（ほんのわずかに接触している）かつ、プレイヤーが敵の方向へ十字入力を入れている場合。
- **効果（ダメージ）**:
  - **Enemy のみ**がダメージを受ける。（1回 6ダメージ）
  - 0.4秒のクールダウンが発生し、連続ヒットはしない。
- **効果（ノックバック）**:
  - 接触軸とは関係なく、両者が斜め方向（X・Y両方）に弾き飛ばされる（90px）。縦軸で回転しながら移動する演出が入る。

※ズレが **64以上** の場合は、グラフィックが重なっていても体当たり判定としては処理されない。

---

## 4. ノックバック・境界処理
- ノックバックは原則として **X軸のみ、またはY軸のみ** に限定される（※かすりを除く）。
- 半キャラ接触時、Enemy は短距離ノックバックする（ロープ方向などへ押し込むことも可能）。
- **ロープ・マット外への弾き飛ばされ**:
  - ノックバックによって対象者がマット（設定された画面内移動範囲）外へ弾き出された場合、「ロープ飛ばされ（Rope Launched）」状態に移行する。
  - 放物線を描いて空を飛び、中心に向かってランダムに着地・再配置される。この間メイン判定は無い（無敵またはすり抜け）。

---

## 5. 攻撃ボタン（コンテキスト依存）
攻撃ボタンは常に同じ効果を持たない。**通常攻撃（パンチ/キックでダメージ）は存在しない**（NON_NEGOTIABLES #1。旧 Attacking ステートへの遷移は 2026-07-13 に削除済み）。

| 状況 | 効果 |
|---|---|
| 飛び道具所持 | 飛び道具を投擲（Out of Scope） |
| 通常（滑らか）モード | Nボタン（2Pは左クリック）＝短時間ダッシュ / 停止中なら自動走行 |
| グリッド（カクカク）モード | Nボタン（2Pは左クリック）押し続け＝炎ダッシュ（与/被ダメ2倍） |
| ダッシュ中に敵接触 | ノックバック強化 |
| Enemy | 体当たりのみ |

---

## 6. 移動仕様（レトロ量子化）
- PC/Enemy の基準サイズは 32x32 ピクセル（見た目は2倍スケールのSpriteもあり）
- Player は **グリッド移動（32px ステップ）** と **滑らか移動（move_and_slide）** を切替可能
  - 1P のみ **Gキー**で切替（`GameManager.use_grid_mode`）
  - グリッド移動は `PlayerWalkState.gd` の `STEP_SIZE = 32`
- Enemy は基本は滑らか移動（`move_and_slide()`）だが、最終的に量子化に寄せる余地あり（TODO）

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
- 見た目がマゼンタ系に変化（`STATE_ANGRY_MODULATE`）
- **半キャラ接触（Side）は無効**：ダメージ・敵ノックバックなし。プレイヤーだけ軽く弾き返される（45px）。トレーニング時は「半キャラ無効(怒り)」と表示
- 正面接触（Front）・かすり・踏みは有効（かすり/踏みで Weak に落とせる＝怒り対策）
- 移動速度 **1.35倍**（`state_speed_mult()`。ただし逃走ボス＝ステージ2は加速しない）
- 敵攻撃のダメージ **1.5倍**（`state_damage_mult()`）
- 発生条件: HP40%以下（継続）、または 15秒経過（**8秒間だけ怒り、その後タイマーリセットで通常に戻る波状**）

#### Weak
- 見た目が青色に変化（`STATE_WEAK_MODULATE`）
- 移動速度 **0.5倍**
- **Player は正面接触でもダメージを受けない**（一方的ダメージ）
- 弱り中の敵の攻撃はダメージ0
- ステージ3ボスの正面ガードも弱り中は無効
- 発生条件: かすり／踏みつけ後 8秒、またはパワーエサ（敵全員弱り）

※上記のゲームプレイ効果は 2026-07-13 に実装（それまでは見た目の色変化のみで、半キャラ無効・速度変化・一方的ダメージは機能していなかった）。
判定箇所: `PlayerMain._body_contact()`（`is_shoulder_immune()` / `is_weak_state()`）、
`EnemyAttackState.deal_damage_to_player()`、各移動ステート（`state_speed_mult()`）。

---

## 8. Enemy AI
- 障害物回避なし
- Player 方向へ直線追尾、または決められた経路を巡回
- 移動は Player と同様に量子化される
- 特定条件で援軍を呼ぶ敵が存在する
  - 援軍は低HP・低速度・多数出現

### 8.1 現行実装の速度・検知範囲（2026-07-13 バランス調整）

| 項目 | 実装場所 | 旧値 | 新値 |
|------|----------|------|------|
| 追尾速度（Chase） | `EnemyChaseState.move_speed`（`Enemy.tscn` でも同値にオーバーライド） | 80 | **140** |
| 検知半径（DetectionArea） | `Enemy.tscn` の `DetectionShape`（CircleShape2D） | 87.4371 | **120** |
| 逃走速度（Flee・ステージ2ボス） | `EnemyFleeState.move_speed`（`Enemy.tscn` でも同値にオーバーライド） | 600 | **440**（プレイヤー通常速480で追いつける値） |
| 逃走時の被弾後超高速（Flee） | `EnemyFleeState.super_flee_speed` | 1400 | 1400（変更なし） |

**変更理由**: 敵が遅すぎ・検知範囲が狭すぎてプレイヤーに脅威を与えられていなかったため、追尾速度と検知半径を引き上げ。逃走速度は600だとプレイヤー通常速（480）で追いつけず理不尽だったため440に減速（Angry状態でも加速しない仕様は維持＝§7.2参照）。

**注意**: ステージ3ボスは `StageController._spawn_enemy_at()` でスポーン時に `chase`/`wander` の `move_speed` を **0.5倍**にする特殊処理があるため、実効速度は上記の半分（Chaseなら70）になる。

---

## 9. Stage
- 壁 / ブロックは通行不可
- リング（マット）内の移動範囲を固定し、**ロープ外には出られない**（クランプ）
  - Player のマット範囲（`PlayerMain.gd`）：左 280 / 右 1000 / 上 106 / 下 614  
  - Enemy のマット範囲（`EnemyMain.gd`）：左 296 / 右 984 / 上 106 / 下 614（片側 16px 狭い＝敵がロープ端に張り付かない）
- 左右ロープ接触時のみ「ロープ跳ね返り」演出
  - Player はロープ端に触れたら反対側へ自動移動（`rope_bounce_running`）
  - ロープバウンド速度は **約800px/s**（以前より減速）
- ノックバック等でマット外へ出た場合は「ロープ飛ばされ（放物線）」へ遷移（`RopeLaunched`）
  - 見た目の回転・放物線は `PlayerRopeLaunchedState.gd` / `EnemyLaunchedState.gd`

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

**現行実装の整理**: 判定・ダメージ・弾け方など実装が変わった場合は、**B.0 をはじめ該当セクションに都度 SPEC.md を更新**して、仕様と実装の乖離を防ぐ。

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

### B.0 体当たりの現行実装（判定条件・ダメージ・弾け方）

**実装場所**: `Scenes/Player/Scripts/PlayerMain.gd` の `_body_contact()`

現在の体当たりは **正面**・**かすり**・**半キャラずらし（ショルダータックル）** の3種。

#### 前提・共通

- **接触判定**: 正方形AABB。中心間距離が両軸とも `2 * (BODY_CONTACT_HALF + 1)` 以下で重なりとみなす。  
  - `BODY_CONTACT_HALF = 32`（1辺64の箱）。
- **入力**: 敵方向への「上下左右いずれか」の入力を `pressing_toward_ok`（十字のいずれか＋敵方向に押している）で判定。
- **ずれ（alignment_diff）**:
  - プレイヤー→敵が **左右方向** なら: プレイヤーと敵の **Y座標の差** の絶対値。
  - プレイヤー→敵が **上下方向** なら: **X座標の差** の絶対値。
- **閾値（ずれ＝alignment_diff）**:
  - **32未満**: 正面（半分以上が敵と向かい合っている）。
  - **32以上58未満**: 半キャラずらし（半分以下が向かい合っている）。
  - **58以上64未満**: かすり（ほんのちょっとだけ向かい合った）。
  - **64以上**: 当たってない（体当たり処理しない）。

---

#### 1. 正面体当たり

**判定条件**

- ずれが **`alignment_diff < 32`**（半分以上が敵と向かい合っている）、  
  または敵方向を押していない（`pressing_toward_ok == false`）。

**ダメージ**

- **両方** 被弾。
- 敵へ: `BODY_DAMAGE_DEALT = 10`（`fire_dash_damage_mult` を乗算）。ステージ4コーナージャンプ特攻時は 50。
- プレイヤーへ: `BODY_DAMAGE_TAKEN = 8`（`fire_dash_damage_taken_mult` を乗算）。
- 間隔: `body_contact_cooldown` で 0.3 秒（`BODY_CONTACT_INTERVAL`）。

**特例: ステージ3 ユニ帝仮面の正面無敵**

- 敵がステージ3ボスで、プレイヤーが敵の「正面側」にいるときは **正面ガード** 扱い。敵は被弾なし。プレイヤーのみ 20 ダメージ ＋ 200px ノックバック。

**弾け方（通常の正面）**

- **両方** が「敵から離れる方向」にノックバック。量は `BODY_PUSH_PIXELS_FRONTAL = 120`。ステージ4の異論マスクは 150。マット外ならそれぞれ `trigger_rope_launch()`。軸は X軸のみ or Y軸のみ。

---

#### 2. 半キャラずらし（ショルダータックル）

**判定条件**

- 敵方向に十字入力している（`pressing_toward_ok == true`）。
- ずれが **`32 <= alignment_diff < 58`**（半分以下が向かい合っている＝半キャラずらし）。

**ダメージ**

- **敵のみ** 被弾。プレイヤーは被弾しない。
- 1回あたり: `PUSH_DAMAGE_PER_TICK = 6`（`fire_dash_damage_mult` を乗算）。
- 間隔: `PUSH_DAMAGE_INTERVAL = 0.2` 秒。
- 特例: ステージ4の異論マスクにコーナージャンプ特攻が成立しているときは 1回だけ 50 ダメージ。

**弾け方**

- **敵**: 敵から離れる方向にノックバック。量は `PUSH_KNOCKBACK = 60`（**縦横とも同じ**。以前は縦だけ 0.67 倍だったが、縦のほうが当たり続けて見えるため廃止。2026-07-13: 90→60 に再修正。理由は定数一覧直後の補足を参照）。  
  - ステージ4の異論マスクは 90（2026-07-13: 150→90。正面のノックバック150pxより控えめにして半キャラの連打しやすさを優先）。  
  - ノックバック先がマット外なら `trigger_rope_launch()`（ロープ飛ばされ）。
- **プレイヤー**: 反動で敵から離れる方向に **6**（`PUSH_PLAYER_KNOCKBACK_HALFCAR`。縦横とも同じ）。マット外ならロープ飛ばされ。
- **軸**: ノックバックは **X軸のみ** または **Y軸のみ**（イース風。`_axis_knockback()` で `to_enemy` の長い軸に合わせる）。

---

#### 3. かすり

**判定条件**

- 敵方向に十字入力している（`pressing_toward_ok == true`）。
- ずれが **`58 <= alignment_diff < 64`**（58〜63ドット＝ほんのちょっとだけ向かい合った）。

**挙動**

- **敵のみ** ダメージ（1回あたり 6、半キャラずらしと同様。コーナージャンプ特攻時は 50）。
- **両者** が斜めにすっ飛ばされて離れる：ノックバックは **X,Y 両方** ずれた方向（`-to_enemy` 方向）に `KASURI_KNOCKBACK_DIAGONAL = 90`。**一定時間（0.28秒）で移動**し、その間スプライトを縦軸で約2回転（バレリーナのように）させる。繋がらない（`KASURI_COOLDOWN = 0.4` 秒で連打防止）。
- 軸は同上（Xのみ or Yのみ）。

**64ドット以上のずれ**

- 当たってない扱い。体当たりのダメージ・ノックバックは発生しない（`alignment_diff >= 64` でその敵はスキップ）。

---

#### 定数一覧（PlayerMain.gd）

| 定数名 | 値 | 意味 |
|--------|-----|------|
| BODY_CONTACT_HALF | 32 | 接触用AABBの半幅（64×64） |
| HALF_OVERLAP_DIST | 32 | 正面／半キャラの境（ずれ 32 未満＝正面） |
| SEMI_CAR_MAX | 58 | 半キャラの上限（ずれ 32〜58 未満＝半キャラ、58〜64 未満＝かすり） |
| BODY_CONTACT_MAX_ALIGNMENT | 64 | ずれ 64 以上＝当たってない |
| KASURI_KNOCKBACK_DIAGONAL | 90 | かすり時の斜めノックバック量（X,Y 両方・離れる方向） |
| KASURI_COOLDOWN | 0.4 | かすり後の連打防止（秒） |
| BODY_DAMAGE_DEALT | 10 | 正面で敵に与えるダメージ |
| BODY_DAMAGE_TAKEN | 8 | 正面でプレイヤーが受けるダメージ |
| BODY_PUSH_PIXELS_FRONTAL | 120 | 正面時のノックバック量 |
| PUSH_KNOCKBACK | 60 | ショルダー時の敵ノックバック量 |
| PUSH_DAMAGE_INTERVAL | 0.2 | ショルダー連続ダメージ間隔（秒） |
| PUSH_DAMAGE_PER_TICK | 6 | ショルダー1回あたりダメージ |
| BODY_CONTACT_INTERVAL | 0.3 | 正面のダメージ間隔（秒） |

**補足（2026-07-13: PUSH_KNOCKBACK 90→60 に再修正）**: `PAST_DESIGN_DECISIONS.md` #3 のとおり、`PUSH_KNOCKBACK` は元々60→90→60と経緯があった値。90だと体当たり用AABB（中心差66以内で接触判定）に対してノックバック距離が大きすぎ、1回当てるたびに毎ティック接触が切れて「半キャラ連打で押し込み続ける」という設計意図（§3.2・付記の「イース的半キャラずらしを明確な勝ち筋にする」）が成立していなかった。60に戻すことで連打が復活する。

---

#### 現状のアクション体当たりの仕様（まとめ）

- **キャラ・コリジョン**: キャラ絵は 64×64（スプライト 2 倍のみ、ルート scale 1）。体当たり判定も **64×64 の正方形**（中心から ±32）。
- **接触の種類**: **3 種類**。  
  - **正面**: ずれ **32dot 未満**（半分以上が敵と向かい合っている）→ **両方**ダメージ・ノックバック（0.3 秒ごと。敵に 10、自分に 8）。  
  - **半キャラずらし**: 敵方向入力＋ずれ **32 以上 58 未満**（半分以下が向かい合っている）→ 敵だけダメージ・ノックバック（0.2 秒ごと 6、ロープまで連打可）。  
  - **かすり**: 敵方向入力＋ずれ **58〜63**（ほんのちょっとだけ向かい合った）→ 敵だけダメージ（6）、両者を斜めに 90px すっ飛ばす。繋がらない（0.4 秒クールダウン）。  
  - **ずれ 64dot 以上**: 当たってない（体当たり処理しない）。
- **ノックバック**: どちらも **X 軸だけ** または **Y 軸だけ**（イース風）。正面は両者 120px。ショルダーは敵 60px・自分反動 6（縦横同じ）。ステージ4異論マスクは正面150px・ショルダー90px。マット外ならロープ飛ばされ。
- **ロープダッシュ攻撃**（2026-07-13追加。B.0.1参照）: ロープバウンド自動移動中（`rope_bounce_running`）にショルダー/かすりでヒットすると、ダメージが**2倍**（炎ダッシュと重複時は乗算せず高い方のみ）。SEとヒットパーティクル強化つき。
- **特例**: ステージ3 ユニ帝仮面の正面無敵＝正面側から当たると敵は無傷、自分だけ 20 ダメージ＋200px ノックバック。ボス側には常に「ガードされた」ことが伝わる青白フラッシュ（`Color(0.7, 0.9, 2.0)`）が出る（2026-07-13修正: 以前はトレーニングモード限定の赤フラッシュしかなく、本番プレイではボス側に演出が出ていなかった）。

---

### B.0.1 ロープダッシュ攻撃（没案#2の復活・2026-07-13追加）

**実装場所**: `PlayerMain._body_contact()`（半キャラずらし／かすりのダメージ計算部）

`PAST_DESIGN_DECISIONS.md` #11-2「ロープダッシュ攻撃：ロープバウンド中の体当たりにダメージボーナス」の復活案。

- **発動条件**: `rope_bounce_running == true`（ロープに触れて反対側へ自動横断中、約800px/s）の間にショルダーずらし、またはかすりが成立したとき。
- **効果**: そのヒットのダメージが**2倍**（`PUSH_DAMAGE_PER_TICK` を基準に計算）。
  - `fire_dash_damage_mult`（炎ダッシュ）と重複する場合は、**高い方のみを採用**（乗算はしない。`maxf(fire_dash_damage_mult, 2.0)`）。
- **演出**: ヒット時に `AudioManager.play_sound(AudioManager.PLAYER_ATTACK_HIT, 0, 2)` を再生し、`hit_particles` を強化（`amount = 40` / `lifetime = 0.8`。通常のショルダーは20/0.4、かすりは16/0.3）。
- **トレーニング表示**: `GameManager.body_contact_type_text` を「ロープ(半キャラ)」「ロープ(かすり)」として区別表示（通常の「半キャラ」「かすり」「弱り(〜)」より優先）。
- **狙い**: ロープワークと半キャラずらしという2つのコアメカニクスを繋げ、「跳ね返りながら押し込む」というプロレスらしい立ち回りへのインセンティブを作る。

---

#### キャラの見た目・当たり判定のサイズ（現行実装）

- **キャラの見た目**: スプライト scale (2, 2) のみ。32px 画像 → **64×64** で表示。ルート scale は **1**（拡大なし）。
- **移動用コリジョン**: ルート scale 1 のまま。Player は円 r=32（直径 64）、Enemy はカプセル等。ワールドでも 64 前後。
- **体当たり用**: コードで **半幅 32 ＝ 64×64**（`BODY_CONTACT_HALF = 32`）。キャラ絵 64×64 と一致。

**まとめ**

| 対象 | スプライト scale | ルート scale | 見た目 | 移動コリジョン（ワールド） | 体当たり（ワールド） |
|------|------------------|---------------|--------|----------------------------|----------------------|
| Player | (2, 2) | (1, 1) | 64×64 | 円 r=32（直径 64） | 64×64 |
| Enemy | (2, 2) | (1, 1) | 64×64 | カプセル等・同様 | 64×64 |

スプライトの元画像はおおむね 32×32 ピクセル想定。半キャラ＝32px。

**移動・壁用の当たり判定（CharacterBody2D）**

| 対象 | シーン | 形状 | サイズ（ローカル） | オフセット |
|------|--------|------|--------------------|------------|
| Player | `Player.tscn` | CircleShape2D | radius = 32 | (0, 14) |
| Enemy | `Enemy.tscn` | CapsuleShape2D | radius = 16, height = 32 | (0, 14) |

ルート scale 1.25 をかけると、ワールドでは Player の円は実質 r=40 程度。

**体当たり用の判定（ダメージ・ノックバック）**

- **判定形状**: 正方形 AABB。**中心から ±32**（半幅 32、1 辺 64）。キャラ 64×64 に合わせている。
- **中心**: Player は `global_position`、Enemy も `global_position`。
- コード上は `PlayerMain.BODY_CONTACT_HALF == 32` をプレイヤー・敵とも同じ値で使用（`_body_contact()` 内）。
- 移動用の Circle/Capsule とは別で、体当たりだけこの 64×64 で判定。

**トレーニングモードでの当たり判定表示**

- `Scripts/DebugContactOverlay.gd` が体当たり用の 64×64 を描画。
- `GameManager.training_mode == true` のとき **常時表示** し、**線のみ**（枠線）で描画。プレイヤー＝赤、敵＝緑。

---

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

- Player: 32px ステップのグリッド移動＋G で滑らか/カクカク切替（`PlayerWalkState.gd`, `PlayerMain.gd`）。  
- Enemy: 連続的な `velocity` + `move_and_slide()`（各 Enemy ステート）。

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
  - Idle 中に Nボタン（2Pは左クリック）を 1 回押す → プレイヤーの向いている左右方向に自動走行開始。  
  - Moving 中に Nボタンを押した場合も、停止中かつ方向入力がなければ同様に自動走行開始。  
  - **移動キー（十字キー／WASD など）を入れると、自動走行は解除される。**
- **カクカク（グリッド）モード時**  
  - Nボタン（2Pは左クリック）押しっぱなしで **炎ダッシュ状態（`PlayerFireDashState`）** を維持する（Idle/Moving どちらからでも遷移）。  
  - このモードでは Nボタンは自動走行のトリガーにはならない。
- **補足（2026-07-13 修正）**: 旧コードは存在しないアクション名 `AttackPunch`/`AttackKick` を参照しており、1P では Attacking 遷移も FireDash 遷移も発動していなかった。現在は Idle/Walk 両ステートで上記入力仕様どおりに動作し、通常攻撃（Attacking）への遷移は削除された。
- **補足（2026-07-13 追記）**: `PlayerFireDashState` の維持判定は **`Dash`（1P）/ `Punch2`（2P）** を参照する（Idle/Walk の遷移トリガーと同一）。旧実装の `Punch` 参照は入力マップ上 Nキーが `Dash`/`Punch` 両方に割り当てられていたため表面化しにくかった。

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
- **2P対応（2026-07-13修正）**: ロープバウンス解除判定の「新しくキーを押したか」チェックで、ダッシュ系ボタンは 1P=`Dash` / 2P=`Punch2` を見る（以前は2Pでも `Dash`＝1PのNキーを見ており、2P操作では解除判定が働いていなかった）。

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

**現行実装（実装優先で更新済み）**

- ロープは Area2D ではなく、**マット内クランプ＋専用ステート/自動移動**で実装。
- **左右ロープ跳ね返り（Player）**
  - `Scenes/Player/Scripts/PlayerMain.gd`  
    - `MAT_LEFT/MAT_RIGHT/MAT_TOP/MAT_BOTTOM` でクランプ  
    - 左右端到達で `rope_bounce_running` を立て、反対側へ自動移動  
    - バウンド速度: `480*2/1.2 ≒ 800`
  - `Scripts/ArenaMat.gd` でロープの見た目たわみ（`bend_rope(left/right)`）
- **ロープ飛ばされ（放物線）**
  - Player: `PlayerRopeLaunchedState.gd`（`LAUNCH_DURATION=1.2`、回転＋放物線）  
  - Enemy: `EnemyLaunchedState.gd`
- 上下ロープは「跳ね返り自動移動」は行わず、範囲クランプのみ（見た目は `ArenaMat.tscn` のロープ）

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

**現行実装の入力（`Scenes/qte_main_with_anim.gd`）**: `ui_accept` / `Punch` / `Punch2`（2P用。2026-07-13追加） / `Kick` / `Dash` / `Enter` のいずれかの押下でその瞬間の重なり判定を見て成功/失敗を判定する。以前は `Punch2` が入っておらず、2Pがボス撃破QTEに参加できなかった。

---

### B.10 Win / Lose（§11）

**やること**

- **Win（現行）**: `StageController.gd` がステージクリア時に `Scenes/UI/StageClear.tscn` へ遷移。  
  - クリア確定〜遷移までの1.2秒間は `GameManager.enemies_frozen = true`＋全プレイヤー5秒無敵（クリア後の被弾死防止。次ステージの `StageController._ready()` で解除）。  
  - QTE成功時のボス消滅は `CharacterBase._die()` に一元化（マスク飛び演出→1秒後に自動 `queue_free`）。  
  - `StageClear.gd` で 1秒後に入力受付し、キー/クリックで `GameManager.load_next_stage()` を呼ぶ。  
  - `load_next_stage()` は `StageIntro.tscn` →（入力で）`GameWrapper.tscn` へ遷移。ステージ4の次は `Ending.tscn`。
- **Lose（現行）**: Player HP==0 で `PlayerMain._die()` が `Scenes/Misc/DeathScreen.tscn` を表示。
  - DeathScreen は **コンティニュー / タイトルに戻る / 終了する** を上下で選択（`Scripts/Reset.gd`）。

**触るファイル**

- `Scripts/Managers/GameManager.gd`: 例: `var current_level_cleared: bool`、敵全滅時に true。  
- `Scenes/Levels/Basement01.tscn` 等: 敵が 0 になったら VictoryScreen を表示するトリガー（シグナルや _process で敵ノード数をチェック）。

---

### B.11 UI / FX（§12）

**やること**

- **HP 表示**: Player/Enemy とも既存の ProgressBar をそのまま利用。最大値・現在値を SPEC の HP 値に合わせる。  
- **ヒット時フラッシュ**: 既存の `CharacterBase.damage_effects()`（赤フラッシュ）を維持。  
- **SE**: 既存の `AudioManager`（BLOODY_HIT 等）をそのまま使用。  
- **タイトル画面（現行）**: `Scenes/Misc/TitleScreen.tscn` + `Scripts/TitleScreen.gd`
  - 1P / 2P / テストを上下で選択し、選択中は強調表示。
  - ESCで終了確認（はい/いいえ）を表示。
- **ポーズ（現行）**: `Scenes/Levels/GameWrapper.tscn` に `Scripts/GameWrapperPause.gd` を付与
  - ESCでポーズし、縦4択（バトルに戻る / ステージ開始から / タイトルから / やめる）。

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
| `Scripts/ArenaMat.gd` / `Scenes/Levels/ArenaMat.tscn` | 変更 | ロープ見た目（たわみ）・マット/ロープ描画。 |
| `Scenes/Player/Scripts/PlayerMain.gd` | 変更 | マット内クランプ、左右ロープバウンド（約800）、空中z_indexを地上より前面に。 |
| `Scenes/Levels/GameWrapper.tscn` + `Scripts/GameWrapperPause.gd` | 追加 | ESCポーズ＋縦4択メニュー。 |
| `Scenes/UI/StageClear.tscn` + `Scripts/StageClear.gd` | 変更 | クリア画面の入力受付を安定化（_unhandled_input等）。 |
| `Scenes/Misc/DeathScreen.tscn` + `Scripts/Reset.gd` | 変更 | ゲームオーバーを縦3択＋上下選択に変更。 |
| `Scripts/MaskFlyAway.gd` / `Scripts/CharacterBase.gd` | 変更 | 死亡マスク飛び演出の歪み修正（global_transform継承＋倍率拡大）。 |
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
