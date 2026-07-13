# HANDOFF.md — AI間の開発引き継ぎ

**最終更新**: 2026-07-13 21:00（クラウド Fable 引き渡し前）  
**★ クラウド側 Fable はまず `FABLE_HANDOFF.md` を読むこと（全 .md 統合版）**

---

## 現在の状況

| 項目 | 状態 |
|------|------|
| 進行率 | **85%**（`PROGRESS.md`） |
| リモート最新 | `ef6c2ed` Phase A 完了 |
| ローカル | **11ファイル未コミット**（ノックバック/SE/BGM/HPバー）→ `FABLE_HANDOFF.md` §1 |
| Phase B | 未着手（実プレイ確認後） |

### 未コミットのホットフィックス（要 commit）

- ロープ加速中ノックバック不発（Phase A エンバグ）修正
- 半キャラ連打 SE 毎 tick 化 + `apply_repeat_contact_damage`
- BGM 即再生（`AudioManager` BGMPlayer）
- リング左下謎 HP バー削除

---

## 次にやること

1. **commit + push**（上記未コミット分）
2. **実プレイ確認**（四辺ロープ / 半キャラ / BGM / 2P）
3. **Phase B**: S1 フォーメーション → S2 陣取り → S3/S4 ボス改修

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
