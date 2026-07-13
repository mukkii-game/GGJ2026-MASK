# 引き継ぎ文書: マスク面（GGJ2026-MASK）

**作成日**: 2026-07-13  
**目的**: ノートPC → デスクトップPCの Cursor 環境への開発引き継ぎ

> **2026-07-13 更新**: クラウド Fable 向けの最新統合版は **`FABLE_HANDOFF.md`**（Git 状態・未コミット・全 .md 地図）。本書は環境構築の詳細用。

---

## 1. プロジェクト概要

| 項目 | 内容 |
|------|------|
| **ゲーム名** | マスク面（Body-check Arena） |
| **ジャンル** | 2D トップダウン体当たりアクション（プロレスリング設定） |
| **エンジン** | **Godot 4.6**（Forward Plus / gl_compatibility） |
| **解像度** | 1280×720（integer stretch） |
| **リポジトリ** | `https://github.com/mukkii-game/GGJ2026-MASK.git` |
| **ブランチ** | `godot`（メイン開発ブランチ） |
| **バージョン** | 1.5 |
| **ライセンス** | MIT（ベース: ForlornU TopdownStarter） |

### ゲーム内容

通常攻撃は存在しない。**体当たり（接触）**が唯一の戦闘手段。
- **正面衝突**: 両者ダメージ＋大ノックバック
- **半キャラずらし**: 敵のみダメージ＋連続ヒット可能（イース風）
- **かすり**: 敵のみダメージ＋両者斜めに吹き飛び

ロープバウンド・ロープ飛ばされ・Finisher QTE・4ステージ構成・2P対戦対応。

---

## 2. デスクトップでの環境構築手順

### 2.1 リポジトリのクローン

```bash
git clone https://github.com/mukkii-game/GGJ2026-MASK.git
cd GGJ2026-MASK
git checkout godot
```

### 2.2 Godot のバージョン

**Godot 4.6** が必要。`project.godot` に `config/features=PackedStringArray("4.6", ...)` と記載あり。  
4.5 以下では正常に開けない可能性がある。

### 2.3 アセット（Git未追跡）

以下のフォルダは `.gitignore` でバイナリが除外されている可能性がある。  
ノートPC側から **手動コピー** するか、共有ドライブ等で同期すること。

| フォルダ | 内容 |
|----------|------|
| `Art/Sprites/` | キャラ・マップ用 PNG |
| `Art/Audio/` | BGM・SE（WAV等） |
| `Scenes/Player/Sprite/` | プレイヤーアニメーション PNG |
| `.godot/` | エディタキャッシュ（Godot が自動再生成するので不要） |

**確認方法**: Godot でプロジェクトを開き、リソースが赤い（missing）場合は上記フォルダが不足している。

### 2.4 Cursor ルール

`.cursor/rules/spec-sync.mdc` が設定済み。  
**ルール内容**: 実装を変更したら **同じ会話内で `docs/SPEC.md` を更新すること**（必須）。

---

## 3. 未コミットの変更（要注意）

現在、以下の2ファイルに未コミット変更がある:

| ファイル | 状態 | 内容 |
|----------|------|------|
| `Scenes/Player/Scripts/PlayerMain.gd` | **staged** (M) | 体当たり処理・マットクランプ等の変更 |
| `Scripts/DebugContactOverlay.gd` | **unstaged** ( M) | デバッグ表示の変更 |

### 引き継ぎ前にやること

デスクトップに引き継ぐ前に、ノートPC側で以下のいずれかを実施:

**方法A: コミットして push（推奨）**
```bash
git add -A
git commit -m "WIP: 体当たり処理とデバッグ表示の変更"
git push origin godot
```

**方法B: stash して push（作業途中の場合）**
```bash
git stash push -m "laptop-wip-2026-07-13"
git push origin godot
# デスクトップ側で:
git pull origin godot
git stash pop  # ← stash は push できないので手動コピーが必要
```

**方法C: patch ファイルで持っていく**
```bash
git diff HEAD > ~/laptop-wip.patch
# デスクトップ側で:
git apply laptop-wip.patch
```

---

## 4. プロジェクト構成

```
GGJ2026-MASK/
├── project.godot              # エントリポイント: TitleScreen.tscn
├── Scenes/
│   ├── Player/                # プレイヤーシーン・スクリプト・スプライト
│   │   ├── Player.tscn
│   │   ├── Scripts/
│   │   │   ├── PlayerMain.gd          # ★最重要: 体当たり判定の全ロジック
│   │   │   └── States/                # FSM ステート（7種）
│   │   └── Sprite/
│   ├── NPC's/Enemy/           # 敵シーン・スクリプト
│   │   ├── Enemy.tscn
│   │   └── Scripts/
│   │       ├── EnemyMain.gd           # 敵AI・状態・行動パターン
│   │       └── States/                # FSM ステート（12種）
│   ├── Levels/                # ステージ
│   │   ├── GameWrapper.tscn           # ゲーム本体のラッパー（ポーズ対応）
│   │   ├── ArenaMat.tscn              # リング（マット・ロープ描画）
│   │   ├── MainFloor.tscn             # ステージ1
│   │   └── Basement01.tscn           # ステージ2
│   ├── Interactables/         # コイン・コーナーポスト・パワーエサ等
│   ├── Misc/                  # タイトル・デス画面・設定
│   ├── UI/                    # ステージ演出・クリア・エンディング
│   └── qte_core.tscn          # Finisher QTE
├── Scripts/
│   ├── FSM/                   # FSM 基盤（FiniteStateMachine.gd / State.gd）
│   ├── Managers/
│   │   ├── GameManager.gd            # ★ Autoload: 2P・ステージ・トレーニング管理
│   │   └── AudioManager.gd           # ★ Autoload: SE・BGM
│   ├── CharacterBase.gd              # Player/Enemy の共通基底
│   ├── StageController.gd            # ステージ進行制御
│   └── DebugContactOverlay.gd        # 体当たり判定の可視化
├── Art/                       # フォント・シェーダー・パーティクル
├── docs/
│   ├── SPEC.md                # ★仕様書（これが正）
│   ├── TASKS.md               # 開発タスクリスト
│   ├── MAP_CHANGE.md          # マップ編集ガイド
│   ├── TEXTURE_CHANGE.md      # テクスチャ差し替え手順
│   └── HANDOFF.md             # ← この文書
├── tools/                     # テクスチャ一括置換スクリプト
└── .cursor/rules/             # Cursor AI ルール
```

---

## 5. 重要ファイル早見表

| 優先度 | ファイル | 役割 |
|--------|----------|------|
| ★★★ | `docs/SPEC.md` | **仕様の正本**。実装変更時は必ず同期 |
| ★★★ | `Scenes/Player/Scripts/PlayerMain.gd` | 体当たり判定の全ロジック（`_body_contact()`） |
| ★★★ | `Scripts/Managers/GameManager.gd` | Autoload。ステージ管理・2P・トレーニングモード |
| ★★ | `Scenes/NPC's/Enemy/Scripts/EnemyMain.gd` | 敵AI・行動パターン・状態管理 |
| ★★ | `Scripts/CharacterBase.gd` | Player/Enemy 共通の HP・ダメージ・死亡処理 |
| ★★ | `Scripts/ArenaMat.gd` | リングの描画・ロープのたわみ演出 |
| ★ | `Scripts/StageController.gd` | ステージクリア・遷移制御 |
| ★ | `docs/TASKS.md` | 残タスク一覧 |

---

## 6. 操作方法

### 1P（WASD）
| キー | アクション |
|------|-----------|
| WASD | 移動 |
| N | パンチ / 自動走行開始（滑らかモード時） |
| M | キック / ジャンプ |
| G | グリッド移動⇔滑らか移動の切替 |
| E | 決定 |
| R | リスタート |
| ESC | ポーズ |

### 2P（テンキー方向キー＋マウス）
| 入力 | アクション |
|------|-----------|
| テンキー矢印 | 移動 |
| 左クリック | パンチ |
| 右クリック | キック / ジャンプ |

---

## 7. ゲームフロー

```
TitleScreen (1P/2P/テスト選択)
  → StageIntro (ステージ名表示)
    → GameWrapper + ArenaMat (対戦)
      → 敵HP==0 → Finisher QTE → 成功: StageClear / 失敗: 戦闘続行
      → プレイヤーHP==0 → DeathScreen (コンティニュー/タイトル/終了)
    → StageClear → 次ステージの StageIntro → ...
      → 全ステージクリア → Ending
```

---

## 8. 体当たり判定の仕組み（コア知識）

`PlayerMain.gd` の `_body_contact()` が全てを処理する。

### 判定フロー
1. 64×64 の正方形AABB で接触チェック（`BODY_CONTACT_HALF = 32`）
2. プレイヤーの十字入力方向と敵位置の関係で **ずれ（alignment_diff）** を算出
3. ずれ値で3種に分岐:

| ずれ | 種類 | 敵ダメ | 自ダメ | ノックバック |
|------|------|--------|--------|-------------|
| 0〜31 | 正面 | 10 | 8 | 両者 120px |
| 32〜57 | 半キャラ | 6/tick | 0 | 敵 60px, 自 12px |
| 58〜63 | かすり | 6 | 0 | 両者 斜め 90px |
| 64+ | 非接触 | - | - | - |

### 特例
- ステージ3ボス: 正面側から当たるとプレイヤーだけ20ダメージ+200pxノックバック
- ステージ4ボス: コーナージャンプ特攻で50ダメージ、ノックバック150px
- 炎ダッシュ中: 与ダメ・被ダメに倍率がかかる

---

## 9. 直近の開発履歴（コミットログ）

| コミット | 内容 |
|----------|------|
| `c8d8915` | docs: SPEC.md を現行戦闘メカニクスに更新 |
| `814ccea` | ユニ帝仮面を弱くした、後ろを取りやすく |
| `dbe9b31` | 敵が拡大しながら死ぬようにした |
| `4a1072e` | ジャンプ中のプライオリティ修正 |
| `9496ace` | メニュー直し、走り速度抑えめに |
| `3c26d72` | ポーズメニュー作る |
| `e92fe65` | リングとロープの見た目調整 |

---

## 10. 残タスク（`docs/TASKS.md` より）

**P0 Vertical Slice** — 全て未完了:
- [ ] Player の量子化移動（32px ステップ）
- [ ] Enemy の直線追尾（量子化）
- [ ] Player に FrontHitBox / SideHitBox を追加
- [ ] Enemy に HurtBox を追加
- [ ] Front/Side 接触のダメージ処理
- [ ] 接触中の前後のみ移動制限
- [ ] Side 成功時の Enemy ノックバック
- [ ] HP / Win / Lose 表示

> **注**: TASKS.md は初期計画のもの。実際の実装は SPEC.md の B.0〜B.11 に詳細がある。体当たり判定・ロープ・QTE・ステージ・UI 等は **既に実装済み** の部分が多い。

---

## 11. Cursor で開発する際のルール

1. **SPEC 同期ルール**（`.cursor/rules/spec-sync.mdc`）  
   体当たり・戦闘・ステージ・敵・QTE・UI・シーン遷移・定数を変更したら、**同じ会話内で `docs/SPEC.md` を更新する**。「あとで書く」は禁止。

2. **応答言語**  
   ユーザールールで「Always respond in Japanese」が設定済み。

3. **コミットメッセージ**  
   日本語で書くスタイル（例: `ユニ帝仮面を弱くした`）。docs 系は英語プレフィックス（`docs:`）。

---

## 12. 既知の注意点

- **バイナリアセット**: PNG/WAV 等は Git LFS 未使用。クローンだけでは画像・音声が欠ける可能性あり。ノートPCから手動コピーすること。
- **Godot バージョン**: 4.6 必須。README には「4.2+」と書いてあるが、それはベーステンプレートの話。
- **ルート scale**: Player/Enemy のルートは scale (1,1)。スプライトだけ (2,2) にしている。ルート scale を変えると体当たり判定がずれるので注意。
- **トレーニングモード**: `GameManager.training_mode` で体当たり判定の可視化（`DebugContactOverlay.gd`）が有効になる。テスト時に便利。

---

## 13. デスクトップ側チェックリスト

- [ ] リポジトリを clone & checkout godot
- [ ] Godot 4.6 をインストール
- [ ] アセットフォルダ（Sprites / Audio）をノートPCからコピー
- [ ] 未コミット変更を反映（commit & push、patch、または手動コピー）
- [ ] Godot でプロジェクトを開き、TitleScreen が表示されることを確認
- [ ] F5 で実行し、タイトル → ステージ1 → 体当たり が動作することを確認
- [ ] Cursor で開き、`.cursor/rules/` が認識されていることを確認
