# SPEC: Body-check Arena（v0.4 / 実装反映: 2026-07-17 確定仕様v1.0）

> **v0.4 の大枠**（詳細は各セクション。検討経緯は `GAME_DESIGN_BRUSHUP.md` ★★確定仕様v1.0）:
> 敵状態は **普通/弱り/強い＋ダウン**。弱り化は「半キャラ累計3発」が主ルート。弱り敵への正面は**ブラスト**（大ダメージ40・撃破で場外へ・生存でリング内ダウン）。
> 強い敵は半キャラ・正面とも弾かれ、**空中頭突き（走行中ジャンプ）だけが通る**。ダウン敵にはジャンプ着地**プレス**。
> **向き規則**: 敵の方を向いていない接触は一方的被弾。**ロープを走るのはボスのみ**（S4・直角カウンターで転ばせる）。ザコは4種（ジョバー/ガブリ/ヒートマン/デブ）。

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

### 3.1 正面衝突（Front / ズレ 0〜31）— v0.4で敵状態・向きにより分岐
- **判定条件**: ズレが **32未満**、または半キャラ/かすりに該当しない接触。0.3秒のクールダウンが発生する。
- **分岐（優先順）**:
  1. **敵が弱り（青）→ 正面ブラスト**: 敵だけ **40ダメージ**（走行倍率で変動）・プレイヤー無傷。撃破なら**場外へ吹っ飛んで撃破**（`fly_out_visual` + `KILL_MASK` SE）。耐えたら**リング内ランダム地点へ吹き飛び→ダウン**（`blast_to_down`）。
  2. **S3ボスの正面ガード**: 従来どおり（敵無傷・プレイヤー20ダメ＋200pxノックバック）。
  3. **敵が強い（赤）**: 敵は無傷。**プレイヤーだけ8ダメージ＋160pxノックバック**（青白フラッシュ＝弾かれた表現）。
  4. **向き規則（プレイヤーが敵の方を向いていない）**: 正面位置でも**一方的被弾**（プレイヤー8ダメ×敵状態倍率＋120pxノックバック。敵は無傷）。「向いている」= 敵方向への十字入力 or `facing_dir`（直近の移動方向）と敵方向の dot > 0.5。
  5. **通常（普通の敵・向いている）**: 両者ダメージ（Player 8 / Enemy 10×倍率）＋両者120pxノックバック（従来どおり）。

### 3.2 半キャラずらし（Shoulder Tackle / ズレ 32〜51・左右接近のみ）
- **判定条件**: **左右からの接近**に限り、ズレが **32以上 52未満** かつ、プレイヤーが敵の方向へ十字入力を入れている場合。
- **上下からの接近**で同程度のズレは **かすり** として扱う（Phase A）。
- **効果（ダメージ）**:
  - **Enemy のみ**が一方的にダメージを受ける。（1回 6ダメージ）
- プレイヤーが押し込み続ければ、0.2秒間隔で連続ヒットする（`apply_repeat_contact_damage()` で短い無敵のみ）。
- **走行中（ロープ往復 or Nダッシュ）は連打間隔が半減（0.1秒）**＝足の速さぶん殴打回数が増える（確定仕様P3。威力倍率はロープ中1.25倍まで＝`ROPE_DASH_DAMAGE_MULT`）。
- **弱り蓄積（確定仕様P4）**: 通常状態の敵に半キャラを**累計3発**当てると **弱り（青）8秒** になる（`notify_halfcar_hit()`、カウンタはダウン・弱り化でリセット）。→ 弱り正面ブラスト（§3.1-1）へ繋ぐのが基本コンボ。
- 毎 tick で `PLAYER_ATTACK_HIT` を再生（通常 vol 0、走行系は vol 2）。
- **効果（ノックバック）**:
  - Enemy は接触した軸方向（Xのみ、またはYのみ）へ弾き飛ばされる（60px）。
  - Player は反動として軽く後退する（6px）。連続で押し込みながらの攻撃（追撃）が可能。

### 3.3 かすり（Graze / ズレ 52〜63）
- **判定条件**: ズレが **52以上 64未満**（左右接近時）または **上下接近で32以上64未満** かつ、プレイヤーが敵の方向へ十字入力を入れている場合。
- **効果（ダメージ）**:
  - **Enemy のみ**がダメージを受ける。（1回 6ダメージ）
  - 0.4秒のクールダウンが発生し、連続ヒットはしない。
- **効果（ノックバック）**:
  - 接触軸とは関係なく、両者が斜め方向（X・Y両方）に弾き飛ばされる（90px）。縦軸で回転しながら移動する演出が入る。
- **v0.4**: かすりは「狙ってもそう成功しないレア技」の位置づけ。**状態変化なし**（旧: かすりで弱り化→廃止。弱り化は半キャラ蓄積§3.2へ移管）。半キャラ狙いがかすりばかりになる場合は将来削除も検討。

### 3.4 空中頭突き（走行中ジャンプ・確定仕様P7）
- **発動**: 走行中（Nダッシュ or ロープ往復）にジャンプ → 走行方向へ**速度420px/s・持続0.5秒**の低空頭突き（E・本多式）。入力では曲がれない。
- **効果**: 最初に触れた敵に **20ダメージ**。**強い（赤）敵にも通る唯一の直接技**。命中した敵は**リング内ランダム地点へ吹き飛び→ダウン**（強化解除）。KOなら**そのまま場外へ**。命中したらその場で着地。
- ダウン中・リングイン中・ロープ飛ばされ中・吹き飛び中の敵には当たらない。

### 3.5 プレス（ダウン敵へのジャンプ着地・確定仕様P6）
- **ダウン（寝）中の敵**の上にジャンプで着地すると **30ダメージ**。KOなら**場外へ吹っ飛ぶ**。生存時はダウンが少し延長（最低1.2秒）。
- ダウン中の敵は通常の体当たり判定から**除外**される（プレス/頭突きの追撃対象）。
- 立っている敵への着地は従来どおり（2倍ダメージ＋踏み→弱り化＋ランダム吹き飛ばし）。

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
| 通常 | Nボタン（2Pは左クリック）＝短時間ダッシュ / 停止中なら自動走行 |
| ジャンプ | M / Space / Enter（1Pは左クリックも可・2Pモード時は無効） / 2Pは右クリック |
| ダッシュ中に敵接触 | ノックバック強化 |
| Enemy | 体当たりのみ |

---

## 6. 移動仕様（レトロ量子化）
- PC/Enemy の基準サイズは 32x32 ピクセル（見た目は2倍スケールのSpriteもあり）
- Player は **滑らか移動（move_and_slide）** のみ（Phase A でグリッド/炎ダッシュを廃止）
- Enemy は基本は滑らか移動（`move_and_slide()`）だが、最終的に量子化に寄せる余地あり（TODO）

---

## 7. Enemy Specification

### 7.1 敵タイプ（v0.4 ザコ図鑑・`EnemyMain.EnemyType`）

| タイプ | 見た目 | HP（S1基準27に対し） | 特徴 | 初出 |
|---|---|---|---|---|
| Jobber（ジョバー） | 青マスク `m_man_b` | 基準値 | ずっと普通状態。半キャラ3発→青→正面ブラストの教材 | S1 |
| Gaburi（ガブリ） | 青髪 `m_man_g`・小型0.75倍 | 基準×0.6 | **常時弱り（青）**。正面一発で場外へ飛ぶ「気持ちいい係」。速度0.9倍 | S2 |
| Heatman（ヒートマン） | 赤マスク `m_man_r` | 基準値 | **無被弾10秒で自己強化（10秒で自然冷却）**の周期。被弾でタイマーリセット。頭突きダウンで解除。速度1.1倍 | S3 |
| Debu（デブ） | 青マスク・大型1.35倍 | 基準×5（=125） | 鈍足0.55倍。半キャラだけだと長い→弱り正面→ダウン→プレスのコンボ場 | S3 |

- 種類はステージごとの固定サイクルで出現（`StageController.STAGE_ZAKO_CYCLE`）: S1=Jobberのみ / S2=Jobber,Gaburi交互 / S3=Heatman,Jobber,Debu,Jobber / S4=Jobber,Gaburi,Heatman
- **取り巻き周回**: ボス存命＆ザコ残り2体以下のとき、ザコはボスの周囲（半径110px・1.6rad/s）を回る衛星になる（S2〜）

### 7.2 Status（状態）
Enemy は以下の状態（Status）を持つ。  
状態は見た目・挙動・ダメージ判定に影響する。

#### Normal
- 通常状態
- 半キャラ接触（Side）が有効
- 速度・攻撃力は基準値

#### Angry（=「強い」・v0.4）
- 見た目がマゼンタ系に変化（`STATE_ANGRY_MODULATE`）
- **半キャラ接触は無効**：プレイヤーだけ軽く弾き返される（30px）
- **正面接触も無効（v0.4）**：敵は無傷、プレイヤーだけ8ダメ＋160pxノックバック（§3.1-3）
- **通る技: 空中頭突き（§3.4）のみ**。ダウンさせれば強化解除。他の答え＝ジャンプ回避で時間切れ待ち／パワーエサ
- 移動速度 **1.35倍**・敵攻撃のダメージ **1.5倍**
- **発生条件（v0.4で個体トリガー制に変更。旧「全ザコHP40%/15秒周期の自動怒り」は廃止）**:
  - ヒートマン: 無被弾10秒で発熱（10秒で自然冷却）
  - S4ボスの号令: 全ザコが4秒強化（予告1秒付き）
  - S4ボスのロープ走行中（`rope_running`）
  - S3ボス: HP40%以下（従来どおり継続）

#### Weak（=「弱り」）
- 見た目が青色に変化（`STATE_WEAK_MODULATE`）
- 移動速度 **0.5倍**
- **正面接触＝ブラスト**（§3.1-1: 敵だけ40ダメ・撃破で場外・生存でダウン）。プレイヤーは正面でも無傷
- 弱り中の敵の攻撃はダメージ0。ステージ3ボスの正面ガードも弱り中は無効
- 発生条件（v0.4）: **半キャラ累計3発**（主ルート）／踏みつけ／パワーエサ（敵全員）／**ダウンから起き上がった直後2秒**。持続8秒。ガブリは常時弱り

#### Down（ダウン・寝 / 付随状態・v0.4で本実装）
- スプライト90度回転＝横倒れ・赤め表示。**3秒**で起き上がり→**2秒弱り**（起き上がりの隙）
- 通常の体当たり判定から除外。**プレス（§3.5）・追撃の対象**（無敵ではない）
- 発生条件: 弱り正面ブラストで生存／空中頭突き命中／直角カウンター（S4ボス）
- ダウンに入ると強化解除・半キャラ蓄積カウントもリセット

判定箇所: `PlayerMain._body_contact()`（`is_shoulder_immune()` / `is_weak_state()` / `is_in_down_state()`）、
`EnemyMain._update_enemy_state()` / `notify_halfcar_hit()` / `enter_down()` / `blast_to_down()`、
`PlayerJumpState`（頭突き・プレス）、各移動ステート（`state_speed_mult()`）。

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

### 9.0 ステージ構成と光るアクション（v0.4）

| 面 | ザコ構成（サイクル） | ボスギミック | その面で光るアクション |
|---|---|---|---|
| S1 | ジョバーのみ。**1体ずつ登場→約10秒毎に同時数+1（最大4）→倒すと即補充。合計10体でクリア** | なし（撃破ノルマ） | 半キャラ3発→青→正面ブラストの基本ループ |
| S2 | ジョバー＋ガブリ交互 | メロンナ: **開幕は青ポール上で待機**（当たり判定なし・`is_perched`）→ザコ全滅（最低4秒）or 20秒で山なりジャンプ降臨→逃走→コーナー追い詰め | 正面ブラスト・ガブリ場外ボウリング・終盤の取り巻き周回 |
| S3 | ヒートマン→ジョバー→デブ→ジョバー | うに帝: 正面ガード・鈍足・HP40%怒り（従来） | ジャンプ回避・頭突き→プレス・デブのフルコンボ |
| S4 | ジョバー→ガブリ→ヒートマン | 異論マスク: **12秒毎に「号令」と「ロープ走行」を交互**に実施 | 直角カウンター・総力戦 |

- **号令**: 予告1秒（ボス黄フラッシュ＋`MASK_WARNING` SE）→ 全ザコ4秒強化
- **ボスのロープ走行**: 速度280（強い1.35倍で実効378）・6秒間または直角カウンターまで。**走行中はどんな接触もプレイヤーが一方的にやられる**（12ダメ＋160px弾き）。**走行軸と直角方向から敵方向へ押しながら当てると「直角カウンター」**＝15ダメ＋吹き飛びダウン＋強化解除
- **ロープを走るのはボスだけ**（v0.4確定。旧: ザコ35%ロープ往復→廃止）

### 9.1 ステージ1のクリア条件（v0.4: 撃破ノルマ方式）
- `StageController._setup_normal_params()`: `initial_count: 1`, `total_quota: 10`, `cap_max: 4`, `ramp_interval: 10.0`
- 開幕は**1体だけ**登場。約10秒ごとに同時出現数の上限が+1（最大4）され、**倒すと即座に次が補充**される（`_update_stage1_waves()`）
- 累計スポーンは `total_quota`（10体）で打ち止め。**クリア条件＝ノルマ全員撃破**（出し切った後、場の生存数0）
- HUDは「のこり敵 X体」（`GameManager.stage1_remaining_total` = ノルマ − 撃破済み）を右上に表示
- ステージ2〜4はボス撃破（HP0→Finisher QTE成功）がクリア条件（`use_qte_on_defeat = true`）で従来どおり

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
- ステージ1限定：撃破ノルマHUD（`Scripts/GameUI.gd`）。「のこり敵 X体」を画面右上に表示（v0.4。本番プレイのみ。トレーニング/S2〜4は非表示）
- ステージ1限定：正面衝突の誤学習防止ヒント（`Scripts/Managers/GameManager.gd` / `Scripts/GameUI.gd`）。1プレイにつき一度だけ画面上部中央に3.5秒表示
- **BGM（v0.4暫定）**: タイトル画面・ステージクリア画面は**無音**（`AudioManager.stop_bgm()`。専用曲は後日用意）。戦闘BGMはステージ開始時に再生
- コーナーポストの重ね絵（黄ポリゴン＋`cormar_top.png`）は**削除済み**（背景の青ポールのみ。`MainFloor.tscn`）
- **技名ポップアップ（v0.4・設計原則#6「技名を出すと快感が倍化」）**: 大技が決まった敵の頭上に実況風の技名を表示して浮かせフェード（`GameManager.show_callout()`）
  - 「ブラスト！」（弱り正面・生存ダウン時）／「場外KO！」（撃破場外・赤系）／「ヘッドバット！」（空中頭突き・橙）／「ボディプレス！」（ダウン敵プレス・紫）／「カウンター！」（直角カウンター・緑）

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

> **v0.4 注意**: 本節の分岐説明は v0.3 時点のもの。v0.4 で正面ブロックは §3.1 の5分岐（弱りブラスト/S3ガード/強い弾き/向き規則/通常）に拡張され、
> 半キャラに弱り蓄積（§3.2）、頭突き（§3.4）・プレス（§3.5）・ボスロープ走行と直角カウンター（§9.0）が追加された。**§3・§7・§9が正**。

**実装場所**: `Scenes/Player/Scripts/PlayerMain.gd` の `_body_contact()`

現在の体当たりは **正面**・**かすり**・**半キャラずらし（ショルダータックル）** の3種。

#### 前提・共通

- **接触判定**: 正方形AABB。中心間距離が両軸とも `2 * (BODY_CONTACT_HALF + 1)` 以下で重なりとみなす。  
  - `BODY_CONTACT_HALF = 32`（1辺64の箱）。
- **入力**: 敵方向への「上下左右いずれか」の入力を `pressing_toward_ok` で判定。ロープ／走行加速中は進行方向で代用可（`_is_pressing_toward_enemy()`）。
- **ずれ（alignment_diff）**:
  - プレイヤー→敵が **左右方向** なら: プレイヤーと敵の **Y座標の差** の絶対値。
  - プレイヤー→敵が **上下方向** なら: **X座標の差** の絶対値。
- **閾値（ずれ＝alignment_diff）**:
  - **32未満**: 正面（半分以上が敵と向かい合っている）。
  - **32以上52未満**（左右接近のみ）: 半キャラずらし。
  - **52以上64未満**（左右接近）または **上下接近で32以上64未満**: かすり。
  - **64以上**: 当たってない（体当たり処理しない）。

---

#### 1. 正面体当たり

**判定条件**

- ずれが **`alignment_diff < 32`**（半分以上が敵と向かい合っている）、  
  または敵方向を押していない（`pressing_toward_ok == false`）。

**ダメージ**

- **両方** 被弾。
- 敵へ: `BODY_DAMAGE_DEALT = 10`（ロープダッシュ中は2倍）。
- プレイヤーへ: `BODY_DAMAGE_TAKEN = 8`。
- 間隔: `body_contact_cooldown` で 0.3 秒（`BODY_CONTACT_INTERVAL`）。

**特例: ステージ3 ユニ帝仮面の正面無敵**

- 敵がステージ3ボスで、プレイヤーが敵の「正面側」にいるときは **正面ガード** 扱い。敵は被弾なし。プレイヤーのみ 20 ダメージ ＋ 200px ノックバック。

**弾け方（通常の正面）**

- **両方** が「敵から離れる方向」にノックバック。量は `BODY_PUSH_PIXELS_FRONTAL = 120`。ステージ4の異論マスクは 150。マット外ならそれぞれ `trigger_rope_launch()`。軸は X軸のみ or Y軸のみ。

---

#### 2. 半キャラずらし（ショルダータックル）

**判定条件**

- 敵方向に十字入力している（`pressing_toward_ok == true`）。
- **左右からの接近**（`horizontal_approach == true`）。
- ずれが **`32 <= alignment_diff < 52`**。

**ダメージ**

- **敵のみ** 被弾。プレイヤーは被弾しない。
- 1回あたり: `PUSH_DAMAGE_PER_TICK = 6`（ロープダッシュ中は2倍）。
- 間隔: 通常 `0.2` 秒。ロープダッシュ中は `0.2/2` 秒。

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
- ずれが **`52 <= alignment_diff < 64`**（左右接近）、または **上下接近で `32 <= alignment_diff < 64`**。

**挙動**

- **敵のみ** ダメージ（1回あたり 6。ロープダッシュ中は2倍）。
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
| SEMI_CAR_MAX | 52 | 半キャラの上限（左右接近・ずれ 32〜52 未満＝半キャラ、52〜64 未満＝かすり） |
| ROPE_DASH_DAMAGE_MULT | **1.25**（v0.4で2.0→1.25。威力より連打回数で差を付ける） | ロープバウンド中の体当たりダメージ倍率 |
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
  - **かすり**: 敵方向入力＋ずれ **52〜63**（左右）または上下接近で **32〜63** → 敵だけダメージ（6）、両者を斜めに 90px すっ飛ばす。繋がらない（0.4 秒クールダウン）。  
  - **ずれ 64dot 以上**: 当たってない（体当たり処理しない）。
- **ノックバック**: どちらも **X 軸だけ** または **Y 軸だけ**（イース風）。正面は両者 120px。ショルダーは敵 60px・自分反動 6（縦横同じ）。ステージ4異論マスクは正面150px・ショルダー90px。マット外ならロープ飛ばされ。
- **ロープダッシュ攻撃**（B.0.1）: ロープバウンド中（`rope_bounce_running`）の体当たりダメージ **2倍**、連打間隔 **1/2倍**。
- **特例**: ステージ3 ユニ帝仮面の正面無敵＝正面側から当たると敵は無傷、自分だけ 20 ダメージ＋200px ノックバック。ボス側には常に「ガードされた」ことが伝わる青白フラッシュ（`Color(0.7, 0.9, 2.0)`）が出る（2026-07-13修正: 以前はトレーニングモード限定の赤フラッシュしかなく、本番プレイではボス側に演出が出ていなかった）。

---

### B.0.1 ロープダッシュ攻撃（Phase A 更新）

**実装場所**: `PlayerMain._body_contact()` — `_get_body_damage_mult()` / `_get_push_damage_interval()`

- **発動条件**: `rope_bounce_running == true`（上下左右いずれかのロープに触れて反対側へ自動移動中）。
- **効果**: ダメージ **2倍**、半キャラ連打間隔 **0.2/2 秒**。SE・パーティクル強化（`damage_mult > 1.5` 相当）。
- **ロープ跳ね返り**: **上下左右** のロープ端で反対側までバウンド。`ArenaMat.bend_rope()` で四辺たわみ演出。
- **入力代用**: ロープ／走行加速中（`rope_bounce_running` / `is_run_dashing` / `is_auto_running`）は進行方向を敵方向入力として半キャラ・かすり判定に使用（`_is_pressing_toward_enemy()`）。
- **正面ノックバック**: ロープ加速中も敵ノックバックは必ず実行（Phase A エンバグ修正: 以前は `rope_bounce_running` 分岐の `else` 内にのみノックバックがあり、加速中は SE だけ鳴って敵が飛ばされなかった）。
- **演出**: 半キャラ tick ごとに `PLAYER_ATTACK_HIT`（通常 vol 0 / 加速 vol 2）。`apply_repeat_contact_damage()` で 0.2 秒（ロープ時 0.1 秒）無敵と同期。`hit_particles` を強化（`amount = 40` / `lifetime = 0.8`。通常のショルダーは20/0.4、かすりは16/0.3）。
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

**入力仕様（Phase A 更新）**

- Nボタン（2Pは左クリック）＝自動走行（グリッド/炎ダッシュは廃止）。
- ジャンプ: M / Space / Enter。1Pのみ左クリックも可（`JumpClick1P`）。**2Pモード中は1Pの左クリックジャンプを無効**（2Pの左クリック＝Punch2 と衝突しない）。
- 移動キー入力で自動走行解除。

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
- `Scenes/Player/Scripts/States/PlayerIdleState.gd` / `PlayerWalkState.gd`  
  - Nボタン＝自動走行。`PlayerMain.wants_jump()` でジャンプ入力を統一。

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
    - **上下左右** いずれかの端到達で `rope_bounce_running` を立て、反対側へ自動移動  
    - バウンド速度: `480*2/1.2 ≒ 800`
  - `Scripts/ArenaMat.gd` でロープの見た目たわみ（`bend_rope(left/right/top/bottom)`）
- **BGM**: `AudioManager.play_battle_bgm()`（SubViewport 外・Autoload）
- **ロープ飛ばされ（放物線）**
  - Player: `PlayerRopeLaunchedState.gd`（`LAUNCH_DURATION=1.2`、回転＋放物線）  
  - Enemy: `EnemyLaunchedState.gd`
- 上下ロープも左右と同様に **跳ね返り自動移動** を行う（Phase A で復活・維持）

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
- **BGM（2026-07-13）**: `AudioManager` の専用 `BGMPlayer` で管理（Autoload・シーン外）。  
  - タイトル: `MainThemeNew.mp3` ループ（`_ready` 即再生）  
  - ステージIntro: `Intro.mp3`（非ループ）→ 終了でゴング SE  
  - バトル: `MainThemeNew.mp3` ループ（`StageController._ready` 先頭で即再生）  
  - エンディング: `Ending.mp3`（なければ `MainTheme.mp3`）  
  - MainFloor 内 `BGMFromOffset` は互換ノードのみ（再生しない）
- **タイトル画面（現行）**: `Scenes/Misc/TitleScreen.tscn` + `Scripts/TitleScreen.gd`
  - 1P / 2P / テストを上下で選択し、選択中は強調表示。
  - ESCで終了確認（はい/いいえ）を表示。
- **ポーズ（現行）**: `Scenes/Levels/GameWrapper.tscn` に `Scripts/GameWrapperPause.gd` を付与
  - ESCでポーズし、縦4択（バトルに戻る / ステージ開始から / タイトルから / やめる）。

### B.11.1 ステージ1 HUD：生存敵数表示（クリア条件の不透明さ対策）

**背景**: §9.1 の通り、ステージ1の増援は無限湧き（累計上限なし・場の同時数のみ`max_count`で制限）で、クリアは「場の生存数が0になった瞬間」。プレイヤーからは「あと何体倒せばいいか」が見えず不透明だった。

**やること**

1. `Scripts/StageController.gd` の `_check_stage_clear()` で、ステージ1のときだけ毎フレーム `GameManager.stage1_alive_enemy_count`（現在の生存数）と `GameManager.stage1_max_concurrent_enemy_count`（`stage_params.max_count`、同時出現の上限）を更新する。
2. `Scripts/Managers/GameManager.gd` に上記2変数を追加（StageController→GameUIの橋渡し用。既存の`body_contact_type_text`と同じ「Autoload経由でHUDへ通知」パターンを踏襲）。
3. `Scripts/GameUI.gd` の `_ready()` で、`training_mode` でなく `current_stage == 1` のときだけ `Stage1EnemyLabel` を生成（画面右上・`offset_left/top/right/bottom = 820/8/1270/56`）。`_process()` で毎フレーム `"敵 %d体（最大%d体・全滅でクリア）"` を表示する。
   - 「残り〇体」ではなく「現在の生存数＋同時上限＋全滅でクリア」という表現にしたのは、累計の残数が存在しない（無限湧き）ため、固定総数を示すと実装と矛盾する誤情報になるから。

### B.11.2 ステージ1限定：正面衝突の誤学習防止ヒント（ワンショット）

**背景**: 正面衝突は痛み分け（両者ダメージ）だが、半キャラずらしは一方的に押し込める。プレイヤーが正面衝突を繰り返すと「痛み分けが正解」と誤学習しかねない。

**やること**

1. `Scenes/Player/Scripts/PlayerMain.gd` の `_body_contact()`：
   - 「通常の正面衝突」分岐（`stage3_front_guard` が false のとき）で `GameManager.notify_stage1_front_collision()` を呼ぶ。
   - 半キャラずらしの成功ヒット（`_push_damage_timer <= 0` で実ダメージが入るとき）で `GameManager.notify_stage1_shoulder_tackle()` を呼ぶ（ヒント抑制の判定用）。
2. `Scripts/Managers/GameManager.gd` に `notify_stage1_front_collision()` / `notify_stage1_shoulder_tackle()` / `reset_stage1_hint_tracking()` を追加。
   - ステージ1・本番プレイ（`training_mode == false`）限定。正面衝突が累計3回に達した時点で、そのプレイ中まだ半キャラずらしを3回以上決めていなければ `front_collision_hint_text` / `front_collision_hint_timer(=3.5)` をセットして一度だけ表示（既に3回以上決めているプレイヤーには出さない）。
   - `Scripts/StageController.gd` の `_ready()` で `reset_stage1_hint_tracking()` を呼び、ステージ再挑戦のたびにカウンタをリセット（1プレイにつき1回の制御）。
3. `Scripts/GameUI.gd` に `Stage1HintLabel` を追加（画面上部中央・`offset_left/top/right/bottom = 140/40/1140/90`）。`_process()` で `front_collision_hint_timer` を減算し、0より大きい間だけ表示。テキスト：「真正面は相打ち！半分ずれてぶつかれば一方的に押し込める！」
4. HUDラベルのフォントは既存の `pixelized_label` 系と同じ `m3x6.ttf` を流用しつつ、背景色（観客席・マット等）に依存せず読めるよう `outline_size=3` を付けたLabelSettingsをGameUI.gd側で生成（新規`.tres`は追加していない）。

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
