## QTEミニゲーム仕様（`qte_main_2.gd`）

このドキュメントは、シーン `Scenes/qte_main_2.tscn` とスクリプト `qte_main_2.gd` によって実装されている  
リング型QTEミニゲームの**「現在の実装仕様」**をまとめたものである。

---

### 1. 概要

- **目的**: 画面中央付近に表示されるリング／ゲージに合わせて、指定タイミングでボタン（`ui_accept`）を押すシンプルなQTE。
- **結果判定**:
  - 判定はアニメーションの進行度（0〜1）と、ターゲット値 `t_target` の距離で行う。
  - 判定結果は文字列で `"perfect"`, `"good"`, `"miss"`, `"timeout"` の4種類。
- **外部連携**:
  - QTEの完了時に `signal finished(result: String)` を発火し、外側のゲームロジックへ結果を通知する。
  - QTEの開始／終了タイミングは外部（呼び出し元）からメソッドで制御する。

---

### 2. ノード構成（`Scenes/qte_main_2.tscn`）

- ルート: `Node2D`（名前: `qte_main2`）
  - `RingOuter: TextureRect` … 外側リングの見た目用。
  - `RingInner: TextureRect` … 内側リングの見た目用。
  - `HitZone: TextureRect` … タイミングの「当たりゾーン」表示用。
  - `ResultLabel: Label` … `PERFECT` / `GOOD` / `MISS` / `TIME OUT` を表示。
  - `AnimationPlayer` … QTE演出／進行度の基準となるアニメーションを管理。
  - `SFX: AudioStreamPlayer2D` … 効果音再生用（現状スクリプトからの直接制御はなし）。

---

### 3. スクリプト仕様（`qte_main_2.gd`）

#### 3.1 シグナル

- **`signal finished(result: String)`**
  - QTEが終了したタイミングで発火する。
  - `result` には以下のいずれかが入る。
    - `"perfect"`
    - `"good"`
    - `"miss"`
    - `"timeout"`

#### 3.2 内部状態変数

- **`var active := false`**
  - QTE入力受付中かどうか。
  - `true` の間だけ `_unhandled_input()` でボタン入力を受け付ける。

- **`var resolved := false`**
  - このQTEがすでに結果確定済みかどうか。
  - `true` の場合は、入力・タイムアウトともに二重処理を行わない。

#### 3.3 調整用パラメータ

- **`var t_target := 0.5`**
  - 判定の「理想タイミング」を 0〜1 の正規化時間で指定。
  - `0.5` の場合、アニメーションのちょうど中間地点がベストタイミングとなる。

- **`var perfect_window := 0.03`**
  - **PERFECT判定**の許容誤差（0〜1 の正規化時間）。
  - 実装コメント上は「厳しめ」として扱われる小さめの値。

- **`var good_window := 0.08`**
  - **GOOD判定**の許容誤差。
  - `perfect_window` より広く、「多少ズレても成功」とみなすゆるめの範囲。

---

### 4. ライフサイクルと外部からの使い方

#### 4.1 QTE開始フロー

1. **`start_qte()` を呼び出す**
   - `visible = true` でQTE UIを表示。
   - `resolved = false`, `active = false` にリセット。
   - `ResultLabel` のテキストを空にする。
   - `AnimationPlayer` で `"qte_in"` アニメーションを再生し、導入演出を開始。

2. **`qte_begin()` が呼ばれる**
   - 通常は `AnimationPlayer` のアニメーションイベント（Call Method Track）等から呼び出す想定。
   - `active = true` とし、プレイヤー入力を受け付け開始。
   - ループ用アニメーション `"qte_loop"` を再生し、当たり判定の基準となる時間経過を進める。

#### 4.2 入力受付（ボタン判定）

- **入力検知**: `_unhandled_input(event)` を使用。
  - `active == true` かつ `resolved == false` のときのみ処理。
  - `event.is_action_pressed("ui_accept")` でボタン押下を検知。
  - 押された瞬間に `_judge_and_finish()` を呼び出し、結果を確定する。

#### 4.3 判定ロジック（`_judge_and_finish()`）

1. フラグ更新
   - `resolved = true`
   - `active = false`

2. 時間の正規化
   - `dur = anim.current_animation_length`
   - `pos = anim.current_animation_position`
   - `t` を下記のように計算する。
     - `t = clamp(pos / dur, 0.0, 1.0)`（`dur > 0` の場合）
   - `t` は現在のアニメーション進行度（0〜1）を表す。

3. 距離計算
   - `d = abs(t - t_target)`
   - 進行度 `t` が `t_target` からどれくらいズレていたかを距離 `d` として取得。

4. 判定分岐
   - `d <= perfect_window` の場合
     - 表示テキスト: `"PERFECT"`
     - シグナル: `finished.emit("perfect")`
     - アニメーション: `"qte_perfect"` を再生（※実際のアニメーション名との対応はシーン側で調整が必要）。
   - `elif d <= good_window` の場合
     - 表示テキスト: `"GOOD"`
     - シグナル: `finished.emit("good")`
     - アニメーション: `"qte_good"` を再生。
   - それ以外
     - 表示テキスト: `"MISS"`
     - シグナル: `finished.emit("miss")`
     - アニメーション: `"qte_miss"` を再生。

#### 4.4 タイムアウト処理（`qte_timeout()`）

- 外部で用意したタイマー等から、受付時間切れ時に呼び出すことを想定。
- すでに `resolved == true` であれば何もしない（二重決着防止）。
- まだ未確定の場合:
  - `resolved = true`
  - `active = false`
  - 表示テキスト: `"TIME OUT"`
  - シグナル: `finished.emit("timeout")`
  - アニメーション: `"qte_miss"` を再生（失敗演出として共通利用）。

#### 4.5 後片付け（`cleanup()`）

- `visible = false` とし、QTE UI全体を非表示にするだけのシンプルな後処理。
- 実際のシーン遷移や結果反映（敵撃破／再戦など）は、`finished` シグナルを受け取った外側のロジック側で行う。

---

### 5. チューニング・拡張ポイント

- **判定の厳しさ調整**
  - `t_target`, `perfect_window`, `good_window` をスクリプト上で変更することで、  
    判定タイミングやPERFECT/GOOD範囲を容易に調整可能。

- **アニメーション名と実装の対応**
  - 現在のシーンファイル (`Scenes/qte_main_2.tscn`) では  
    `"qte_success"`, `"qte_fail"`, `"qte_in"`, `"qte_loop"`, `"qte_out"` などが定義されている。  
  - スクリプト側では `"qte_perfect"`, `"qte_good"`, `"qte_miss"` を再生しようとしているため、  
    実際の運用ではアニメーション名の整理（リネーム or スクリプト修正）が必要になる。

- **演出追加**
  - `SFX` ノードを利用して、結果ごとに異なるSEを再生するなどの拡張が容易。
  - `ResultLabel` の色・フォント・アニメーションを変えることで、視覚的フィードバックを強化可能。

---

### 6. 外部から見たインターフェースまとめ

- **公開メソッド**
  - `start_qte()` … QTE UIの表示と導入アニメ開始。
  - `qte_begin()` … 入力受付開始＋ループアニメ開始。
  - `qte_timeout()` … タイムアウト時の強制失敗処理。
  - `cleanup()` … QTE終了後の非表示処理。

- **シグナル**
  - `finished(result: String)`
    - `"perfect"`, `"good"`, `"miss"`, `"timeout"` のいずれかで結果通知。

この仕様に従って、Finisher QTE やイベントシーンから `qte_main_2` を呼び出すことで、  
現在実装されているタイミング入力型ミニゲームを安全に再利用できる。

