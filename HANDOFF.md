# HANDOFF.md — AI間の開発引き継ぎ

**作成日**: 2026-07-13  
**最終更新**: 2026-07-13 13:15（デスクトップ側AI・Fable 5 自律作業中）  
**目的**: どのAI（モデル）が中断しても、別のAIがそのまま再開できるようにする

---

## 現在の状況（2026-07-13 13:15 時点）

- 進行率 **78%**（`PROGRESS.md` 参照・確度:中）
- 直近: バランス第1弾、Ending.tscnパースエラー修正、headless煙テスト（Title/GameWrapper/StageClear/Ending/StageIntro/QTE）
- **次**: 炎ダッシュ/2P/Angry-Weakの実プレイ確認、バランス第2弾（必要なら）
- 検証用 Godot: `C:\Program Files\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe`
  - headless 実行での動作確認方法:  
    `& "<上記exe>" --headless --path "e:\GodotProjects\GGJ2026-MASK" "res://Scenes/Levels/GameWrapper.tscn" --quit-after 600`
  - エラーが出ないこと（invalid UID 警告と終了時の resources still in use は無害）

## あなた（新しいAI）への指示

### 最初にやること

1. **`CLAUDE.md` を読む**（プロジェクト全体像と必須ルール）
2. **このファイルを最後まで読む**
3. **`TODO.md` を読む**（進行中タスク・完了済み・未着手・テスト結果）
4. 引き継ぎ文書群を順に読む（`CLAUDE.md` に記載の順番で）
5. **`docs/SPEC.md` を読む**（正式仕様書）
6. **実際のコードを読んで照合する**（文書を鵜呑みにしない）
7. `git log --oneline -10` で直近のコミットを確認してから作業を再開する

### 照合のポイント

- `CURRENT_IMPLEMENTATION.md` に書かれている内容が、実際のコードと一致しているか確認
- 特に `PlayerMain.gd` の `_body_contact()` を重点的に読むこと
- `docs/SPEC.md` の B.0 セクションと実際の定数値を突き合わせること
- 乖離があれば、**コードの方が正しい**（SPECが古い可能性がある）

### 過去仕様の扱い

- `PAST_DESIGN_DECISIONS.md` に没案が記録されている
- **過去の没案の方が面白そうな場合は復活を検討してよい**
- 今回の仕様も、ゲームが面白くなるならアレンジしてよい
- **ただし変更理由を `DEVELOPMENT_LOG.md` に記録すること**

### 最終基準

**「指示を全部実装したか」ではなく「実際に遊んで面白いか」が基準。**

面白さのために:
- 数値を変えてよい
- 演出を変えてよい
- 敵AIを変えてよい
- ステージ構成を変えてよい

面白さのために変えてはいけないもの:
- → `NON_NEGOTIABLES.md` を参照

### リファクタリングについて

大規模リファクタリングを目的化しない。以下の場合のみ実施:
- 新機能の追加に必要な場合
- バグ修正に必要な場合
- 安定性の向上に寄与する場合
- 作業時間の短縮に寄与する場合

「コードが綺麗になるだけ」のリファクタリングは行わない。

---

## プロジェクト基本情報

| 項目 | 値 |
|------|-----|
| エンジン | **Godot 4.6** |
| 言語 | GDScript |
| リポジトリ | `https://github.com/mukkii-game/GGJ2026-MASK.git` |
| ブランチ | `godot` |
| メインシーン | `res://Scenes/Misc/TitleScreen.tscn` |
| 解像度 | 1280×720 |

---

## デスクトップ側セットアップ

### 必要なもの
- **Godot 4.6**（4.5以下では動かない）
- Git
- Cursor

### 手順

```bash
# リポジトリが既にある場合
cd D:\Godot_Project\GGJ2026-MASK
git fetch origin
git checkout godot
git pull origin godot

# 新規の場合
git clone https://github.com/mukkii-game/GGJ2026-MASK.git
cd GGJ2026-MASK
git checkout godot
```

### アセット（Git未追跡の可能性）

以下のファイルはバイナリで `.gitignore` により除外されている可能性がある:
- `Art/Sprites/` — PNG画像（キャラ、マップ、エフェクト）
- `Art/Audio/` — SE, BGM（OGG, WAV, MP3）
- `Scenes/Player/Sprite/` — プレイヤーアニメーション

Godotで開いてリソースが赤い場合は、ノートPC側から手動コピーが必要。

---

## 未コミット変更

原則として **作業区切りごとにコミット・プッシュする運用**（2026-07-13 から）。
`git status` で未コミットが残っていたら、内容を確認して安全な単位でコミットすること。

---

## 重要ファイル（読む順）

| 順 | ファイル | 内容 |
|----|----------|------|
| 1 | `CLAUDE.md` | プロジェクト全体像・ルール |
| 2 | `HANDOFF.md` | この文書 |
| 3 | `NON_NEGOTIABLES.md` | 変えてはいけない核 |
| 4 | `GAME_SPEC.md` | 遊びの意図・ゲーム仕様概要 |
| 5 | `CURRENT_IMPLEMENTATION.md` | 実装状況マップ |
| 6 | `PAST_DESIGN_DECISIONS.md` | 設計判断の経緯・没案 |
| 7 | `KNOWN_ISSUES.md` | 既知のバグ |
| 8 | `TECHNICAL_DEBT.md` | 技術的負債 |
| 9 | `OPEN_QUESTIONS.md` | 未決定事項 |
| 10 | `DEVELOPMENT_LOG.md` | 開発の流れ |
| 11 | `docs/SPEC.md` | 正式仕様書 |

---

## 操作方法（動作確認用）

| 1P | アクション |
|----|-----------|
| WASD | 移動 |
| N | パンチ/自動走行/ダッシュ |
| M | ジャンプ |
| G | グリッド⇔滑らか切替 |
| E | 決定 |
| ESC | ポーズ |

タイトル画面の選択:
- **1P**: 通常プレイ
- **テスト**: 敵HP=2（一撃死、シーケンス確認用）
- **トレーニング**: 体当たり練習（敵3体＋ダウン1体、自動復活）
- **S1〜S4**: ステージ直接選択（テストモード）

---

## Cursorルール

`.cursor/rules/spec-sync.mdc` が設定されている:
- 実装変更時は同じ会話内で `docs/SPEC.md` を更新
- 「あとで書く」は禁止

---

## 最後に

このプロジェクトは **プロレスリングの体当たりアクション** です。
半キャラずらしで敵を一方的に削る気持ちよさ、
ロープに跳ね返りながら戦うダイナミックさ、
それがこのゲームの面白さの核です。

コードを読み、遊んで、面白くしてください。
