# FABLE 引き継ぎ — クラウドデスクトップ統合文書

**作成**: 2026-07-13 21:00（デスクトップ Composer 2.5）  
**宛先**: Claude Fable（クラウド側 AI）  
**ブランチ**: `godot`（リモート同期済みの最終 commit は `ef6c2ed`）  
**⚠️ 未コミット変更あり** — 下記「§2」を必読

---

## §0. 60秒で把握すること

| 項目 | 内容 |
|------|------|
| ゲーム | 2Dトップダウン・**体当たりのみ**のプロレスアクション「マスク面」 |
| エンジン | Godot **4.6〜4.7** / GDScript / 1280×720 |
| 進行率 | **約 85%**（コードは厚い・**人間の実プレイ検証が最大ボトルネック**） |
| 直近完了 | Phase A（システム簡素化）commit `ef6c2ed` |
| 直近作業（未 commit） | ロープ加速ノックバック・半キャラSE・BGM即再生・謎HPバー削除 |
| 次フェーズ | **Phase B**（S1〜S4 個別改修）— 実プレイ確認後 |
| 絶対ルール | 実装変更 → **同会話内で `docs/SPEC.md` 更新**（`.cursor/rules/spec-sync.mdc`） |
| 最終基準 | 「指示を全部実装したか」ではなく **「実際に遊んで面白いか」** |

---

## §1. Git 状態（2026-07-13 時点）

### リモート最新 commit

```
ef6c2ed feat: Phase A システム変更完了（Sonnet中断分を完成）
```

### ⚠️ ローカル未コミット（11ファイル）

**push 前に commit 推奨。** Fable が pull しただけでは以下は入らない。

| ファイル | 内容 |
|----------|------|
| `Scenes/Player/Player.tscn` | リング左下の謎HPバー（Camera2D/ProgressBar 残骸）削除 |
| `Scenes/Player/Scripts/PlayerMain.gd` | ロープ加速中ノックバック不発修正、ROPE_DASH 2.0 復帰、加速時入力代用、半キャラSE |
| `Scripts/CharacterBase.gd` | `apply_repeat_contact_damage()`（半キャラ連打用短無敵） |
| `Scripts/Managers/AudioManager.gd` | BGM 専用プレイヤー（Autoload） |
| `Scripts/TitleScreen.gd` | タイトル即 BGM |
| `Scripts/StageIntro.gd` | Intro BGM を AudioManager 経由 |
| `Scripts/StageController.gd` | バトル開始即 BGM |
| `Scripts/Ending.gd` | エンディング BGM を AudioManager 経由 |
| `Scripts/BGMFromOffset.gd` | 無効化（二重再生防止） |
| `docs/SPEC.md` | 上記反映 |
| `DEVELOPMENT_LOG.md` | 変更記録追記 |

### 推奨 commit メッセージ案

```
fix: ロープ加速ノックバック・半キャラSE・BGM即再生・謎HPバー削除

Phase A エンバグ（ロープ中正面ノックバック不発）と SE/BGM 体感問題を修正。
AudioManager に BGM 統合。SPEC/DEVELOPMENT_LOG 同期。
```

---

## §2. Phase A（commit 済）vs ホットフィックス（未 commit）

### Phase A で確定したこと（`ef6c2ed` / `DESIGN_CHANGELOG.md`）

- グリッド / Gキー / **炎ダッシュ廃止** → 滑らか移動 + N＝自動走行
- コーナーポスト（プレイヤー）廃止
- 半キャラ **左右接近のみ**（Y差 32〜52px）、上下接近はかすり
- `SEMI_CAR_MAX` = **52**
- ロープ **四辺バウンド** + `ArenaMat` 四辺たわみ
- パワーエサ：移動20秒・**敵全員弱り8秒**（速度2倍削除）
- ジャンプ：M/Space/Enter + 1P左クリ（2Pモード時1P左クリ無効）

### ホットフィックスで **Phase A から戻した / 上書きした** 点（コード優先）

| 項目 | Phase A commit | 現ワーキングツリー |
|------|----------------|-------------------|
| ロープダッシュ倍率 | 1.5倍 | **2.0倍**（`ROPE_DASH_DAMAGE_MULT`） |
| ロープ加速中正面ノックバック | **不発バグ**（else 分岐ミス） | **常時実行**に修正 |
| 半キャラ SE | 加速時のみ / 間欠 | **毎 tick** `PLAYER_ATTACK_HIT` + 短無敵 |
| BGM | SubViewport 内・遅延 | **AudioManager 即再生** |
| 上下ロープ | 四辺実装済み | 維持（SPEC B.8 記述修正済み） |

→ **`docs/SPEC.md` B.0 / B.0.1 / B.8 / B.11` が現行の正。**  
→ `DESIGN_CHANGELOG.md` の「1.5倍」は **意図変更前の記録**。Fable は SPEC とコードを正とし、必要なら CHANGELOG に追記。

---

## §3. コードの心臓部

```
PlayerMain._body_contact()     ← 体当たり全ロジック（正面/半キャラ/かすり）
PlayerMain._physics_process()  ← ロープ四辺バウンド・マットクランプ
StageController.gd             ← ステージ進行・敵スポーン・QTE
GameManager.gd                 ← Autoload：モード・ステージ・HUD用カウンタ
AudioManager.gd                ← Autoload：SE プール + BGMPlayer
EnemyMain.gd                   ← 敵 AI・Angry/Weak・クランプ
ArenaMat.gd                    ← リング描画・ロープたわみ
```

### 体当たり定数（現行・`PlayerMain.gd`）

| 定数 | 値 | 意味 |
|------|-----|------|
| HALF_OVERLAP_DIST | 32 | ずれ32未満＝正面 |
| SEMI_CAR_MAX | 52 | 半キャラ上限（左右接近） |
| BODY_CONTACT_MAX_ALIGNMENT | 64 | 64以上＝非接触 |
| ROPE_DASH_DAMAGE_MULT | **2.0** | ロープバウンド中ダメ倍率 |
| PUSH_DAMAGE_INTERVAL | 0.2 | 半キャラ連打間隔（ロープ時 /2） |
| PUSH_KNOCKBACK | 60 | 半キャラ敵ノックバック |

### BGM（2026-07-13 修正後）

| 画面 | 曲 | 呼び出し |
|------|-----|----------|
| タイトル | MainThemeNew.mp3 ループ | `TitleScreen._ready` → `AudioManager.play_battle_bgm()` |
| StageIntro | Intro.mp3 1回 | `AudioManager.play_intro_bgm()` |
| バトル | MainThemeNew.mp3 ループ | `StageController._ready` 先頭 |
| エンディング | Ending.mp3（なければ MainTheme.mp3） | `AudioManager.play_ending_bgm()` |

MainFloor 内 `BGMFromOffset` は **再生しない**（互換ノードのみ）。

---

## §4. 進行率・次にやること

**現在: 85%**（`PROGRESS.md`）— ホットフィックス後も **実プレイ未** のため据え置き推奨。

### 最優先（Phase B の前）

1. **未 commit 11ファイルを commit + push**
2. **実プレイ確認**（ユーザー or Fable が Godot で目視）
   - 四辺ロープ跳ね返り
   - 半キャラ左右のみ / かすり 52〜64
   - ロープ加速中の敵ノックバック + SE
   - タイトル〜バトル BGM が即鳴るか
   - 2P：左クリ＝走行、右クリ＝ジャンプ
3. 問題なければ **Phase B** 着手

### Phase B（未着手・優先順）

1. S1：2体組フォーメーション / 湧き直し
2. S2：メロンナ陣取り・降臨・追い詰め
3. S3：全面改修（怒り HP 75/50/25% 案）
4. S4：イーロン（直角ピヨり・ショータイム）
5. ボスエサ争奪 AI + 予兆吹き出し

### 将来・保留（ユーザー指示）

- **2P + NPC モード** — 最後に入れる（未実装・記録のみ）
- **Phase C** — スマホ対応（Phase B 後）

---

## §5. 変えてはいけない核（`NON_NEGOTIABLES.md`）

1. **通常攻撃なし** — 体当たりのみ
2. **半キャラずらしが勝ち筋** — 削除・無効化禁止
3. **位置取りゲーム** — コンボより相対位置
4. **プロレスリング世界観**
5. **トップダウン2D**

---

## §6. 既知問題・未決定（要約）

### 再現待ち / 監視

- **KI-19**: 「ボス倒してもクリア画面に行かない」— 現 HEAD では headless で S2〜S4 OK。旧ビルド or QTE失敗の可能性
- **KI-20**: ボス紹介画像（書き文字あり版）— 対応済み記録あり

### 未決定（`OPEN_QUESTIONS.md`）

| ID | 内容 | メモ |
|----|------|------|
| OQ-01 | プレイヤー/敵マット幅差 | 意図的か要確認 |
| OQ-02 | 上下ロープ跳ね返り | **→ Phase A で四辺実装済み。OQ-02 は実質解決（A→B）** |
| OQ-04 | ダウン敵復活条件 | 未実装 |
| OQ-06 | エンディング充実 | 簡素のまま |
| OQ-08 | ステージ別 BGM | 未実装 |
| OQ-09 | docs/TASKS.md 陳腐化 | 要整理 |

### 技術的負債（触るなら慎重に）

- **TD-01**: `PlayerMain.gd` 巨大化
- **TD-04**: マット定数が3箇所に散在
- **TD-02**: ステージパラメータ直書き

---

## §7. 環境・検証

### リポジトリ

```bash
git clone https://github.com/mukkii-game/GGJ2026-MASK.git
cd GGJ2026-MASK
git checkout godot
# ⚠️ 未 commit 分は push 後に pull
```

### Godot（デスクトップ実績）

```
C:\Program Files\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe
```

### headless 煙テスト

```powershell
& "C:\Program Files\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe" `
  --headless --path "E:\GodotProjects\GGJ2026-MASK" `
  "res://Scenes/Levels/GameWrapper.tscn" --quit-after 600
```

- invalid UID 警告・終了時 resource leak は **無害**
- headless ≠ 実プレイ。SE/BGM/手触りは Godot エディタ or エクスポートで確認

### Autoload

- `GameManager` — ゲーム状態
- `AudioManager` — SE + **BGM**

### メインシーン

- `res://Scenes/Misc/TitleScreen.tscn`

---

## §8. 全 .md ファイル地図（21ファイル）

読む順番は **`CLAUDE.md`** に記載。Fable は以下を使い分ける。

| ファイル | 役割 | 信頼度 / 注意 |
|----------|------|----------------|
| **`FABLE_HANDOFF.md`** | **本書。クラウド引き継ぎの入口** | ★最新意図 |
| `HANDOFF.md` | AI間短縮引き継ぎ | 要更新（本書へ誘導） |
| `CLAUDE.md` | AI向けプロジェクトガイド・読む順 | 安定 |
| `docs/HANDOFF.md` | 環境構築・クローン手順（長文） | §3 未コミット記述は古い |
| `docs/SPEC.md` | **正式仕様書（実装の照合元）** | ★コード変更時必ず同期 |
| `NON_NEGOTIABLES.md` | 変えてはいけない核 | 絶対 |
| `GAME_SPEC.md` | ゲーム意図・遊びの設計思想 | 安定 |
| `DESIGN_CHANGELOG.md` | 仕様変更の「なぜ」 | Phase A 中心。1.5倍は旧 |
| `CURRENT_IMPLEMENTATION.md` | 実装スナップショット | **⚠️ Phase A 前の記述残存（グリッド/炎ダッシュ等）。コード優先** |
| `PROGRESS.md` | 進行率・残作業分解 | 85% |
| `TODO.md` | タスクチェックリスト | Phase A 完了済み |
| `DEVELOPMENT_LOG.md` | 変更履歴（日次） | ★ホットフィックス追記済 |
| `KNOWN_ISSUES.md` | バグ一覧 KI-xx | 大部分修正済み |
| `OPEN_QUESTIONS.md` | 未決定 OQ-xx | OQ-02 は outdated |
| `PAST_DESIGN_DECISIONS.md` | 没案・検討経緯 | 参照用 |
| `TECHNICAL_DEBT.md` | TD-xx 技術的負債 | 参照用 |
| `docs/TASKS.md` | 初期タスクリスト | **陳腐化（OQ-09）** |
| `README.md` | リポジトリ概要 | |
| `docs/MAP_CHANGE.md` | マップ編集手順 | |
| `docs/TEXTURE_CHANGE.md` | テクスcha差替手順 | |
| `tools/README_replace_textures.md` | ツール説明 | |

---

## §9. Fable 向け作業開始チェックリスト

```
[ ] git pull（push 後）
[ ] 未コミット分が必要ならローカル patch / cherry-pick 確認
[ ] CLAUDE.md → NON_NEGOTIABLES.md → 本書 → docs/SPEC.md B.0
[ ] Godot で Title → StageIntro → GameWrapper 通し
[ ] 実プレイでホットフィックス3点確認（ノックバック / 半キャラSE / BGM）
[ ] 問題あれば DEVELOPMENT_LOG + SPEC 更新 → commit
[ ] Phase B 着手前に PROGRESS.md / TODO.md 更新
```

---

## §10. 直近 DEVELOPMENT_LOG 要約（未 commit 含む）

| 日付 | 内容 |
|------|------|
| 07-13 | Phase A 完了（commit ef6c2ed） |
| 07-13 | 謎HPバー削除（Player.tscn Camera2D/ProgressBar） |
| 07-13 | ロープ加速ノックバック不発・SE差修正（Phase A エンバグ） |
| 07-13 | 半キャラ連打 SE 間欠修正（`apply_repeat_contact_damage`） |
| 07-13 | BGM 開始遅延修正（AudioManager BGMPlayer） |

---

## §11. 連絡事項

- **日本語**で応答・commit メッセージ（docs は `docs:` プレフィックス可）
- **commit はユーザー指示時のみ**（未 commit 状態で引き渡し中）
- 実装変更 → **同会話内 SPEC 同期** + **DEVELOPMENT_LOG 追記**
- 数値・面白さは実プレイフィードバック優先。Phase B は Fable 設計どおり進めてよい

---

*End of FABLE_HANDOFF.md — 詳細仕様は `docs/SPEC.md`、変更理由は `DESIGN_CHANGELOG.md` + `DEVELOPMENT_LOG.md`*
