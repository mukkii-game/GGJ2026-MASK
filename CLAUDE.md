# CLAUDE.md — AI開発者向けプロジェクトガイド

**最終更新**: 2026-07-13 21:00（Fable クラウド引き渡し）

## このファイルの目的

あなた（AI）がこのプロジェクトで作業するときに、**最初に読むべきファイル**。
プロジェクトの全体像と、守るべきルールを把握してから作業を始めること。

---

## 読むべきファイルの順番

1. **`CLAUDE.md`**（このファイル）— 全体像・ルール・読む順
2. **`FABLE_HANDOFF.md`** — **クラウド/AI引き継ぎ統合文書（現状・未コミット・次タスク）**
3. **`HANDOFF.md`** — AI間短縮引き継ぎ
3. **`NON_NEGOTIABLES.md`** — 絶対に変えてはいけないゲームの核
4. **`GAME_SPEC.md`** — ゲーム仕様の概要（SPECの要約ではなく、遊びの意図）
5. **`CURRENT_IMPLEMENTATION.md`** — 今どこまで動いているか（コードとの照合用）
6. **`PAST_DESIGN_DECISIONS.md`** — 過去の検討経緯と没案（復活候補あり）
7. **`KNOWN_ISSUES.md`** — 既知のバグ・不具合
8. **`TECHNICAL_DEBT.md`** — 技術的負債・仮実装
9. **`OPEN_QUESTIONS.md`** — 未決定事項
10. **`DEVELOPMENT_LOG.md`** — 開発の流れ
11. **`docs/SPEC.md`** — 正式仕様書（実装の照合元）

---

## プロジェクト基本情報

| 項目 | 値 |
|------|-----|
| ゲーム名 | マスク面（Body-check Arena） |
| エンジン | **Godot 4.6**（gl_compatibility） |
| 言語 | GDScript |
| 解像度 | 1280×720（integer stretch） |
| リポジトリ | `https://github.com/mukkii-game/GGJ2026-MASK.git` |
| ブランチ | `godot`（メイン開発ブランチ） |
| メインシーン | `res://Scenes/Misc/TitleScreen.tscn` |
| Autoload | `GameManager`、`AudioManager` |

---

## 必須ルール

### 1. SPEC同期ルール（`.cursor/rules/spec-sync.mdc`）
**実装を変更したら、同じ会話内で `docs/SPEC.md` を更新する。**
- 体当たり・戦闘まわりを変更 → B.0 を更新
- ステージ・敵・QTE・UI・シーン遷移を変更 → 該当セクションを更新
- 定数・数値・パスを変更 → SPEC内の表を更新
- 「あとで書く」は禁止

### 2. 応答言語
日本語で応答すること。

### 3. コミットメッセージ
日本語で書くスタイル。docs系は英語プレフィックス（`docs:`）。

### 4. 変更時の記録
変更を加えたら、理由を `DEVELOPMENT_LOG.md` に追記すること。

### 5. 最終基準
「指示を全部実装したか」ではなく **「実際に遊んで面白いか」** が基準。

---

## プロジェクト構成（早見表）

```
GGJ2026-MASK/
├── Scenes/
│   ├── Player/Scripts/PlayerMain.gd    ← ★体当たり判定の全ロジック
│   ├── Player/Scripts/States/          ← FSMステート×7
│   ├── NPC's/Enemy/Scripts/EnemyMain.gd ← 敵AI・状態管理
│   ├── NPC's/Enemy/Scripts/States/     ← FSMステート×10（＋孤立ファイル2: EnemyChargeState/EnemyBounceState 未使用）
│   ├── Levels/                         ← ステージ・リング
│   ├── Interactables/                  ← コイン・コーナーポスト等
│   ├── UI/                             ← ステージ演出・クリア画面
│   └── Misc/                           ← タイトル・デス画面
├── Scripts/
│   ├── Managers/GameManager.gd         ← ★Autoload: ゲーム状態管理
│   ├── Managers/AudioManager.gd        ← ★Autoload: SE/BGM
│   ├── CharacterBase.gd                ← Player/Enemy共通基底
│   ├── StageController.gd              ← ステージ進行・敵スポーン・QTE
│   ├── ArenaMat.gd                     ← リング描画・ロープたわみ
│   └── DebugContactOverlay.gd          ← 体当たり判定可視化
├── docs/
│   ├── SPEC.md                         ← 正式仕様書
│   └── TASKS.md                        ← 開発タスクリスト
├── Art/                                ← アセット（一部Git未追跡）
└── project.godot                       ← Godot設定
```

---

## 重要：コードを読む前に知っておくべきこと

1. **体当たりが全て**。通常攻撃はない。`PlayerMain._body_contact()` がゲームの心臓。
2. **3種の接触**: 正面（両者ダメージ）、半キャラずらし（敵だけ）、かすり（敵だけ＋吹き飛び）。
3. **ロープ**: マットクランプ＋左右バウンド＋放物線飛ばし。Area2Dではなくコードで実装。
4. **FSM**: Player/Enemy ともに `FiniteStateMachine.gd` + `State.gd` ベース。
5. **2P対応**: `is_player_two` フラグで入力とスプライトを分岐。
6. **4ステージ**: 各ステージにボスと雑魚。ボス撃破時QTE。
7. **GameManager**: Autoloadでゲーム全体の状態を管理（ステージ・モード・フラグ）。
