# HANDOFF.md — AI間の開発引き継ぎ

**最終更新**: 2026-07-23（新戦闘方針v0.5）  
**★ 仕様の正は `docs/SPEC.md` v0.5 と `GAMEPLAY_DECISION_BRIEF.md`**

---

## 現在の状況

| 項目 | 状態 |
|------|------|
| 進行率 | **戦闘リデザイン実装済・AI検証PASS**（人間実プレイ未） |
| 実装済み | かすりダウン／フライングボディ／怒り後ろ半キャラ／エサ弱り／ボスHP0→ジャンプQTE／トップロープ／S1やっちまえ／移動5種／プレイヤー左右ロープ |
| 自動テスト | `sim=combat` 13/13・`sim=boss` 8/8 PASS |

---

## 次にやること

1. **人間の実プレイ**（半キャラ手触り・かすりダウン・赤の読みやすさ・トップロープ・S1流れ）
2. 数値微調整（弱り8s・ダウン5s・怒り周期・トップロープダメ）
3. 余裕があれば: クリア画面マスク破れ、ボス別QTE、SE

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
