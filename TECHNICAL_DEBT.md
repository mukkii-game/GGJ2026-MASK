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

## TD-07: Tween管理が場当たり的 → **大部分対処済み（2026-07-13）**

**対処済み**: `CharacterBase.register_motion_tween()` / `kill_motion_tweens()` を導入。
移動・回転系Tweenはキャラごとに登録され、ステート切替時に自分のTweenだけkillされる。
`get_processed_tweens()` の全killは排除済み（KI-02参照）。

**残り**: modulate系フラッシュのTweenは登録外（フラッシュ同士の競合は許容範囲）。

---

## TD-08: パワーエサの実装が仮 → **一部対処済み（2026-07-13）**

**対処済み**: 取得時にプレイヤーが効果色でフラッシュ（速度2倍＝青、敵弱り＝緑）し、
頭上に「スピード2倍！」「敵全員よわり！」のポップアップが浮かんでフェードアウトする
（`PowerBait._show_pickup_feedback()`）。

**残り**: 専用SEなし（`POWER_BAIT_GET` が `QuestSound.ogg` を流用のまま。音声アセット待ち）。

---

## TD-09: AudioManagerのサウンドプール上限

**現状**: ~~`max_players = 8`~~ → **2026-07-13 に 16 に拡張**。16同時再生を超えると最初のプレイヤーを再利用（再生中でも上書き）。

**影響**: 大量ヒット時に音が途切れる可能性は低減。根本的な優先度管理は未実装。

**残り**: 優先度キュー（低優先SEのドロップ）が必要なら別途検討。

---

## ~~TD-10: press_bar.gd がルート直下に存在~~ → **修正済み（2026-07-13）**

残骸ファイルを削除: `press_bar.gd` / `Scenes/qte_main.gd` / `Scenes/result_label.gd` / `Scenes/kancho.gd`
（いずれも .tscn から未参照であることを確認済み。QTEの実体は `Scenes/qte_main_with_anim.gd`）
