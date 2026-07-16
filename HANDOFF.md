# HANDOFF.md — AI間の開発引き継ぎ

**最終更新**: 2026-07-17（Fable 5・確定仕様v1.0 実装完了）  
**★ 仕様の正は `docs/SPEC.md` v0.4 と `GAME_DESIGN_BRUSHUP.md` ★★確定仕様v1.0**

---

## 現在の状況

| 項目 | 状態 |
|------|------|
| 進行率 | **90%**（`PROGRESS.md`） |
| リモート最新 | `f960494`（確定仕様v1.0＋技名ポップアップ。未コミット無し） |
| 実装済み | 状態経済（3発弱り→ブラスト→ダウン→プレス）・強い敵と頭突き・向き規則・ザコ4種・S4号令/ロープ走行/直角カウンター・取り巻き周回・技名表示 |
| 自動テスト | `Godot4.7 --headless --path . -- stage=N sim=combat/boss/clear`（全PASS・`Scripts/Dev/CombatSim.gd`） |

---

## 次にやること

1. **人間の実プレイ確認**（半キャラ連打の手触り／ブラストの爽快感／頭突きの誘導しやすさ／S4ボス走行の理不尽感）
2. **バランス第2弾**（弱り8秒・ダウン3秒・発熱10秒・号令12秒間隔などの初期値調整）
3. S5〜S10拡張レール（`GAME_DESIGN_BRUSHUP.md` §5）は実プレイ確認後

---

## 重要ファイル

| ファイル | 内容 |
|----------|------|
| **`FABLE_HANDOFF.md`** | **クラウド引き継ぎ統合文書（入口）** |
| `Scenes/Player/Scripts/PlayerMain.gd` | 体当たり・ロープ |
| `Scripts/Managers/AudioManager.gd` | SE + BGM |
| `docs/SPEC.md` | 正式仕様 |
| `DESIGN_CHANGELOG.md` | 変更理由 |
| `NON_NEGOTIABLES.md` | 変えてはいけない核 |

---

## 検証用 Godot

```powershell
& "C:\Program Files\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe" `
  --headless --path "e:\GodotProjects\GGJ2026-MASK" `
  "res://Scenes/Levels/GameWrapper.tscn" --quit-after 600
```

---

## 最終基準

**「実際に遊んで面白いか」** — `NON_NEGOTIABLES.md` の核は維持。
