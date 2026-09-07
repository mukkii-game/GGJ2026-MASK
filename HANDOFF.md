# HANDOFF.md — AI間の開発引き継ぎ（短縮版）

**最終更新**: 2026-09-07（Claude Code Sonnet 5）
**★ 詳しい引き継ぎは `FABLE_HANDOFF.md`（本書はその要約）**
**★ 仕様の正は `docs/SPEC.md` v0.5 と `GAMEPLAY_DECISION_BRIEF.md`**（2026-07-23 新戦闘方針。それ以前の仕様書は古い）

---

## 現在の状況

| 項目 | 状態 |
|------|------|
| リモート最新 | `a8d66a3`（死亡断末魔SE・トップロープ演出強化） |
| 未コミット | **あり**（2026-09-07セッション分。号令・直角カウンター削除＋トップロープ接近バグ修正。下記参照。コミットはユーザー指示待ち） |
| 方針 | **Godot / GDScriptのまま継続**（Web移行・別AIツール移行は検討したが見送り。理由は`FABLE_HANDOFF.md`冒頭参照） |
| 仕様の核（v0.5） | 半キャラで削り、かすりで寝かせ（5秒ダウン）、ジャンプで潰す（フライングボディ）。赤（怒り）は後ろ半キャラかかすりで凌ぐ。ボスはHP0でダウン→ジャンプ→QTE |
| 自動テスト | `Godot4.7 --headless --path . -- stage=N sim=combat/boss/clear/pause`（`Scripts/Dev/CombatSim.gd`） |
| ⚠️ 進捗率ドキュメント | `PROGRESS.md`（07-17時点）・`KNOWN_ISSUES.md`（07-13時点）は**v0.5改修前で古い**。数値は参考程度にし、実際の状態は `git log` と `DEVELOPMENT_LOG.md` の日付を見て判断すること |
| ⚠️ docs/SPEC.md | v0.5改修時に全面更新されておらず旧記述が広範に残る。気づいた齟齬は都度直すこと |

### 2026-09-07に修正した内容（未コミット）
- v0.4時代のS4専用ギミック「号令」「直角カウンター」を削除（v0.5の「怒りは後ろ半キャラのみ」ルールと矛盾していたため）
- 副次的に発見した実バグを修正: ボス共通トップロープ攻撃で、接近先ポストがマット範囲外にあるためクランプと競合し接近フェーズが完了しないことがあった（`EnemyMain.top_rope_sequence_active`で解消）
- 詳細は `DEVELOPMENT_LOG.md`（2026-09-07）と `FABLE_HANDOFF.md` 冒頭を参照

---

## 次にやること

1. **人間の実プレイ確認**（`PLAYTEST_GUIDE.md` に沿って一通りプレイ）— 半キャラの手触り、かすりダウンの分かりやすさ、赤（怒り）の見分けやすさ、トップロープ演出、S1の流れ
2. 実プレイで見つかった問題を `DEVELOPMENT_LOG.md` に追記しつつ修正
3. 余裕があれば: クリア画面マスク破れ演出、ボス別QTE、SE厚み（`GAMEPLAY_DECISION_BRIEF.md`「後回し」参照）

---

## 重要ファイル

| ファイル | 内容 |
|----------|------|
| **`FABLE_HANDOFF.md`** | **引き継ぎ統合文書（入口・最新の正）** |
| `GAMEPLAY_DECISION_BRIEF.md` | **v0.5新戦闘方針の採用方針（2026-07-23）** |
| `PLAYTEST_GUIDE.md` | プレイテスター向け操作・流れ・ヒント（配布用） |
| `Scenes/Player/Scripts/PlayerMain.gd` | 体当たり・ロープ |
| `Scripts/StageController.gd` | ステージ進行・ボス・QTE |
| `Scripts/Managers/AudioManager.gd` | SE + BGM |
| `docs/SPEC.md` | 正式仕様（v0.5） |
| `NON_NEGOTIABLES.md` | 変えてはいけない核 |

---

## 起動方法

- **実プレイ**: Godotエディタで `res://Scenes/Misc/TitleScreen.tscn` を再生
- **書き出し版exeは古いコードを内蔵しているので使わないこと**（`E:\GodotProjects\GodotMask(.console).exe`）

```powershell
& "C:\Program Files\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe" `
  --headless --path "e:\GodotProjects\GGJ2026-MASK" `
  -- stage=1 sim=combat
```

---

## 最終基準

**「実際に遊んで面白いか」** — `NON_NEGOTIABLES.md` の核は維持。
