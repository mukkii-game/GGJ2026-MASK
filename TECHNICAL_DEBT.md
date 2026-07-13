# TECHNICAL_DEBT.md — 技術的負債・仮実装

**最終更新**: 2026-07-13

大規模リファクタリングを目的化しない。面白さ・安定性・作業時間に寄与する範囲で対処する。

---

## TD-01: PlayerMain.gd が巨大すぎる（687行）

**現状**: 体当たり判定、マットクランプ、ロープバウンド、パワーエサ、2P処理、
カメラ制御、z_index制御、アニメ速度制御... すべてが1ファイルに集約。

**影響**: 変更時の影響範囲が広い。`_body_contact()` だけで150行超。

**対処案**（面白さに影響しない範囲で）:
- `_body_contact()` をヘルパークラスに切り出す
- パワーエサ処理を `PowerBaitEffect.gd` に分離
- ただし「動いているものを壊す」リスクがあるため、新機能追加時にのみ実施推奨

---

## TD-02: ステージパラメータがStageController.gdにハードコード

**現状**: `_setup_normal_params()` / `_setup_test_params()` に全ステージのHP・速度・行動パターンが直書き。

**影響**: ステージ追加時にコードを直接編集する必要がある。

**対処案**: JSONまたはResourceファイルに外出し。ただし4ステージしかないので優先度低。

---

## ~~TD-03: qte_main.gd（旧版QTE）がルートに残っている~~ → **修正済み**

`qte_main.gd` をシグナルベース（`qte_succeeded` / `qte_failed`）に書き換え済み。
`get_tree().quit()` を削除し、`queue_free()` に変更。StageControllerとの連携も整合。

---

## TD-04: 定数の散在

**現状**: マット範囲が3箇所に定義されている:
- `PlayerMain.gd`: `MAT_LEFT=280, MAT_RIGHT=1000, MAT_TOP=106, MAT_BOTTOM=614`
- `EnemyMain.gd`: `MAT_LEFT=296, MAT_RIGHT=984, MAT_TOP=106, MAT_BOTTOM=614`
- `StageController.gd`: `MAT_LEFT=296, MAT_RIGHT=984, ...`

**影響**: 値が微妙に異なる（プレイヤーの方が範囲が広い）。意図的かもしれないが未文書化。

**対処案**: 共通定数を1箇所（`GameManager` or 専用ファイル）にまとめる。

---

## TD-05: SpriteFramesのコード生成

**現状**: `StageController._apply_enemy_sprite()` で敵のSpriteFramesを毎回コードで生成。
l1/l2の2フレームアニメーション（Idle, Walk, Attack, Death）を手動構築。

**影響**: 新しい敵キャラ追加時にコードを書く必要がある。

**対処案**: .tres リソースとして事前に作成し、ステージ設定から参照。

---

## TD-06: 敵の行動パターンがenumの数値キャスト

**現状**: `_set_zako_behavior()` で `(1 if ... else 2) as EnemyMain.Behavior` のようにintをenum にキャスト。

**影響**: enum値が変わるとバグになる。

**対処案**: enum名で直接指定（`EnemyMain.Behavior.VerticalLoop`）。

---

## TD-07: Tween管理が場当たり的

**現状**: 各所で `create_tween()` を呼び、前のTweenがkillされないまま新しいTweenが走ることがある。
`PlayerJumpState` では `get_processed_tweens()` で全Tweenをkillする荒い対処。

**影響**: Tween競合によるアニメーション異常。

**対処案**: Tweenをメンバ変数に保持し、新規作成前に明示的にkill。

---

## TD-08: パワーエサの実装が仮

**現状**: `POWER_BAIT_GET` が `QuestSound.ogg` を流用。専用SEなし。
`apply_power_bait_speed()` / `apply_power_bait_enemy_immune()` は動作するが、
取得時のエフェクトやUI表示がない。

**影響**: プレイヤーがパワーエサを取ったことに気づきにくい。

**対処案**: 専用SE、取得時フラッシュ、UI表示を追加。

---

## TD-09: AudioManagerのサウンドプール上限

**現状**: `max_players = 8`。8同時再生を超えると最初のプレイヤーを再利用（再生中でも上書き）。

**影響**: 大量ヒット時に音が途切れる可能性。

**対処案**: 上限を増やすか、優先度で管理。

---

## TD-10: press_bar.gd がルート直下に存在

**現状**: `press_bar.gd` がプロジェクトルートに残っている。おそらくQTEの初期プロトタイプ。

**影響**: 不要ファイル。混乱の元。

**対処案**: 削除。
