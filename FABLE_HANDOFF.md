# 引き継ぎ文書 — 次の開発者/AIへ

**作成/更新**: 2026-09-07（Claude Code Sonnet 5）
**宛先**: 次にこのプロジェクトを担当する開発者 or AI（Antigravity / Cursor 等、ツール不問）
**ブランチ**: `godot`（origin/godot からの最新pullはHEAD = `a8d66a3`。以下は未コミット）
**未コミット変更**:
- `PLAYTEST_GUIDE.md`（新規）、`AGENTS.md` / `CLAUDE.md`（軽微な追記）— 別セッションの作業と思われる。中身確認済み・無害
- `docs/SPEC.md` / `DEVELOPMENT_LOG.md` / `FABLE_HANDOFF.md` / `HANDOFF.md`（本書含む） / `StageController.gd` / `PlayerMain.gd` / `EnemyMain.gd` / `CombatSim.gd` — **本セッションでの号令・直角カウンター削除＋トップロープバグ修正**（下記参照）。コミットはユーザー指示待ち

> ## 重要な意思決定（2026-09-07）
> - ユーザーは「別AI/別ツールへの引き継ぎ」と「Web版への移行」を検討したが、**Godotのまま続行**する方針で確定。
> - 理由: `_body_contact()` のAABB判定・FSM・ロープ物理・20以上のtscnシーン・SE/BGM管理を含む実装がすでに厚く、Web移植は事実上ゼロからの再実装になる。トークン消費は言語ではなく試行錯誤の回数で決まるため、移植による手戻りリスクの方が大きいと判断。
> - よって次の担当AIは **Godot 4.6〜4.7 / GDScript** のまま作業を続けること。
>
> ## ⚠️ ドキュメントの鮮度に注意
> - `PROGRESS.md`（2026-07-17更新）と `KNOWN_ISSUES.md`（2026-07-13更新）は、**2026-07-23の「新戦闘方針v0.5」大改修より前**の内容。数値・進行率はそのまま信用しないこと。
> - **現在の仕様の正**: `docs/SPEC.md`（v0.5）と `GAMEPLAY_DECISION_BRIEF.md`。
> - 状況把握は「これらstaleな%表記」より「`git log` の日付と `DEVELOPMENT_LOG.md` の直近エントリ」を優先すること。
> - `docs/SPEC.md`自体もv0.5改修時に全面更新されておらず、v0.4以前の記述が広範に残っている（2026-09-07時点で判明）。§9.0のS4部分（号令・直角カウンター）は矛盾に気づいて削除・修正済みだが、**他の節にも同様の齟齬が残っている可能性がある**。コードと食い違う記述を見つけたら都度SPEC.mdを直すこと。
>
> ## 2026-09-07の修正（このセッションで実施）
> - v0.4時代のS4専用ギミック「号令」「直角カウンター」を削除（v0.5の「怒りは後ろ半キャラのみ」という統一ルールと矛盾していたため）。`StageController.gd`・`PlayerMain.gd`から関連コードを除去、`docs/SPEC.md`§9.0/§7/§8を修正
> - その過程で発見した**実バグ**を修正: ボス共通のトップロープ攻撃で、接近先ポスト（Y=52）がマット範囲（Y=138〜614）外にあるためマットクランプと競合し、**接近フェーズが完了しないことがあった**。`EnemyMain.top_rope_sequence_active`フラグで解消（詳細は`DEVELOPMENT_LOG.md`2026-09-07を参照）
> - `Scripts/Dev/CombatSim.gd`の`sim=boss`テストを、削除した旧ギミックのテストからトップロープ攻撃の検証に置き換え。`sim=combat`13/13・`sim=boss`（S2/S3/S4）各7/7で全PASS確認済み
> - 未整理のまま残した点: `EnemyMain.gd`の`rope_running`/`start_rope_run()`関連は号令ギミックの名残で、現在は死んだコード（実害なし）

---

## §0. 60秒で把握すること

| 項目 | 内容 |
|------|------|
| ゲーム | 2Dトップダウン・**体当たりのみ**のプロレスアクション「マスク面」 |
| エンジン | Godot **4.6〜4.7** / GDScript / 1280×720 |
| 現行仕様 | **v0.5「新戦闘方針」**（2026-07-23〜）。旧v1.0（3発弱り→ブラスト）は**廃止済み** |
| 直近完了 | 死亡断末魔SE・トップロープ演出強化（`a8d66a3`、2026-07-24） |
| 次フェーズ | 人間の実プレイ確認 → 見つかった問題を都度修正 |
| 絶対ルール | 実装変更 → **同会話内で `docs/SPEC.md` 更新**（`.cursor/rules/spec-sync.mdc`）、`DEVELOPMENT_LOG.md` に理由を追記 |
| 最終基準 | 「指示を全部実装したか」ではなく **「実際に遊んで面白いか」** |

---

## §1. Git 状態（2026-09-07 時点）

```
HEAD: a8d66a3（2026-07-24 15:13、origin/godot と同期済み）
```

未コミット（別セッションが作業中と思われる。内容確認済み・無害）:

| ファイル | 内容 |
|----------|------|
| `PLAYTEST_GUIDE.md`（新規） | プレイテスター配布用ガイド（操作・流れ・ヒント） |
| `AGENTS.md` / `CLAUDE.md` | 読む順リストに `PLAYTEST_GUIDE.md` を追加する軽微な編集 |
| `DEVELOPMENT_LOG.md` | 上記追加の記録 |

### 直近の開発の流れ（`c587bd6` 以降・新しい順の要約）

`c587bd6 feat: 新戦闘方針v0.5＋描画順/SE/ヤラレ声/ザコ見た目修正` を起点に、以下を積み重ね済み:

- ゲームオーバー凍結・クリアゴング遅延・登場吹き出し
- 開始ゴング（カーン）追加、SE音量調整（複数回）
- ボス「高みの見物」演出＋くるくる降臨
- 連続ジャンプ台・ロープぽよーん音
- ダウン時間短縮（ボディアタック延長は廃止）
- かすり判定帯を半分にして半キャラへ寄せる調整
- 怒り敵の頭上に赤字「ウガー！」表示
- タイトル画面のバグ2件修正（ステージ選択が常に1になる／マウスクリックで常に1P開始になる二重起動）
- 死亡断末魔SE・トップロープ接近/回転/影2倍・ザコ巻き込み（最新 `a8d66a3`）

詳細と日付は `DEVELOPMENT_LOG.md`（末尾が最新）を参照。

---

## §2. 現行仕様（v0.5「新戦闘方針」）の核

出典: `GAMEPLAY_DECISION_BRIEF.md`（2026-07-23、採用・実装中）

> 半キャラで削り、かすりで寝かせ、ジャンプで潰す。赤は後ろか、かすりか、ジャンプで凌ぐ。ボスはHP0ダウン→ジャンプ→QTE。

| 接触 | 結果 |
|------|------|
| 正面 | 両者ダメ＋小ノックバック |
| 半キャラ | 一方的ダメ＋ノックバック連打。**ザコはこれだけで倒してよい** |
| かすり | 両者スピン。敵のみ**5秒ダウン** → ジャンプでフライングボディ（大ダメ） |
| 非押し込み接触 | 敵の一方的攻撃として被ダメ |

- **ジャンプ**: ダウン中の敵の上＝フライングボディ（大ダメ）／非ダウン敵の上＝**自分が吹き飛ぶ**／敵タックル中は回避に使える
- **赤（怒り）**: 真っ赤＋湯気。**後ろからの半キャラのみ有効**（通常半キャラはこちらが被ダメ）。かすりは通常通り可能。時間で解除
- **弱り（青）**: パワーエサ取得時のみ発生（15〜20秒に1回）。速度0.5・攻撃0・正面から一方的大ダメ
- **ボス**: HP0で死亡せずダウン → プレイヤーがジャンプ攻撃 → QTE。成功でクリア、失敗でHP=1で再開。低HPでトップロープ攻撃（影から逃げれば回避、外すとボスが隙を見せる）
- **廃止済み**（v1.0からの変更点）: 空中頭突き、立ち踏み弱り、半キャラ3発弱り→ブラストのコンボループ

数値初期値（弱り8s、かすりダウン5.0s、フライングボディ40、赤持続ザコ7s/ボス9s等）は `GAMEPLAY_DECISION_BRIEF.md` 末尾の表を参照。

---

## §3. コードの心臓部

```
PlayerMain._body_contact()     ← 体当たり全ロジック（正面/半キャラ/かすり）
PlayerMain._physics_process()  ← ロープ左右バウンド（プレイヤーは左右のみ）・マットクランプ
StageController.gd             ← ステージ進行・敵スポーン・ボスQTE
GameManager.gd                 ← Autoload：モード・ステージ・HUD用カウンタ・技名/ウガー表示
AudioManager.gd                ← Autoload：SE プール + BGMPlayer
EnemyMain.gd                   ← 敵AI・赤(怒り)/弱り・かすりダウン・移動5種
ArenaMat.gd                    ← リング描画・ロープたわみ
Scripts/Dev/CombatSim.gd       ← headless自動テスト本体（sim=combat/boss/clear/pause）
```

---

## §4. 次にやること

### 最優先

1. **人間の実プレイ確認**（`PLAYTEST_GUIDE.md` に沿って一通り）
   - 半キャラの手触り、かすりダウンの分かりやすさ
   - 赤（怒り）の見分けやすさ・「後ろ半キャラのみ有効」の伝わりやすさ
   - トップロープ演出（影・巻き込み）
   - タイトル画面のステージ選択・クリック挙動（直近2件のバグ修正の再発確認）
2. 実プレイで見つかった問題を `DEVELOPMENT_LOG.md` に追記しながら随時修正

### 後回し（`GAMEPLAY_DECISION_BRIEF.md` 末尾より）

- クリア画面のマスク破れ演出
- ボス別QTE（現在は全ボスでメロン用QTEを流用）
- SE厚み

### ドキュメント整備（着手できる余裕があれば）

- `PROGRESS.md` / `KNOWN_ISSUES.md` はv0.5改修前の内容のまま。v0.5移行後の状態に合わせて棚卸しすると次の担当者が楽になる

---

## §5. 変えてはいけない核（`NON_NEGOTIABLES.md`）

1. **通常攻撃なし** — 体当たりのみ
2. **半キャラずらしが勝ち筋** — 削除・無効化禁止
3. **位置取りゲーム** — コンボより相対位置
4. **プロレスリング世界観**
5. **トップダウン2D**

---

## §6. 環境・検証

### リポジトリ

```bash
git clone https://github.com/mukkii-game/GGJ2026-MASK.git
cd GGJ2026-MASK
git checkout godot
```

### Godot（実行ファイル）

```
C:\Program Files\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe
```

### 実プレイ確認（メインシーン）

Godotエディタで開いて `res://Scenes/Misc/TitleScreen.tscn` を再生。

### headless自動テスト（`Scripts/Dev/CombatSim.gd`）

```powershell
& "C:\Program Files\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe" `
  --headless --path "E:\GodotProjects\GGJ2026-MASK" `
  -- stage=1 sim=combat
```

`sim=` は `combat` / `boss` / `clear` / `pause` を指定可能。`stage=N` でステージ指定。

- invalid UID 警告・終了時 resource leak は無害
- headless ≠ 実プレイ。SE/BGM/手触りはGodotエディタ or エクスポートで確認
- **書き出し版exe（`E:\GodotProjects\GodotMask(.console).exe`）は古いコードを内蔵しているので使わないこと**

### Autoload

- `GameManager` — ゲーム状態
- `AudioManager` — SE + BGM

---

## §7. 全 .md ファイル地図

| ファイル | 役割 | 信頼度 / 注意 |
|----------|------|----------------|
| **本書（`FABLE_HANDOFF.md`）** | **引き継ぎの入口。最新の正** | ★最新 |
| `HANDOFF.md` | AI間短縮引き継ぎ | 本書と同時に更新済み |
| `CLAUDE.md` / `AGENTS.md` | AI向けプロジェクトガイド・読む順 | 安定 |
| `docs/SPEC.md` | **正式仕様書（v0.5・実装の照合元）** | ★コード変更時必ず同期 |
| `GAMEPLAY_DECISION_BRIEF.md` | **v0.5新戦闘方針の採用方針** | ★現行仕様の根拠 |
| `NON_NEGOTIABLES.md` | 変えてはいけない核 | 絶対 |
| `GAME_SPEC.md` | ゲーム意図・遊びの設計思想 | 安定 |
| `PLAYTEST_GUIDE.md` | プレイテスター向け操作・流れ・ヒント | 配布用・最新 |
| `PROGRESS.md` | 進行率・残作業分解 | **⚠️ v0.5改修前（07-17時点）で古い** |
| `TODO.md` | タスクチェックリスト | 古い（Phase A完了時点） |
| `DEVELOPMENT_LOG.md` | 変更履歴（日次・commit理由） | ★都度追記・最新まで反映されている |
| `KNOWN_ISSUES.md` | バグ一覧 KI-xx | **⚠️ v0.5改修前（07-13時点）で古い** |
| `OPEN_QUESTIONS.md` | 未決定 OQ-xx | 古い可能性あり |
| `TECHNICAL_DEBT.md` | TD-xx 技術的負債 | 参照用 |
| `PAST_DESIGN_DECISIONS.md` | 没案・検討経緯 | 参照用 |

---

## §8. 次の担当者への作業開始チェックリスト

```
[ ] git pull（origin/godot が最新）
[ ] CLAUDE.md → NON_NEGOTIABLES.md → 本書 → GAMEPLAY_DECISION_BRIEF.md → docs/SPEC.md
[ ] git log --oneline -20 で直近の変更を把握（PROGRESS.md/KNOWN_ISSUES.mdの数値は信用しない）
[ ] Godotエディタで Title → StageIntro → GameWrapper を通しプレイ（PLAYTEST_GUIDE.md参照）
[ ] 問題あれば DEVELOPMENT_LOG + SPEC 更新 → コミット（ユーザー指示時のみ）
```

---

## §9. 連絡事項

- **日本語**で応答・commitメッセージ（docsは`docs:`プレフィックス可）
- **commitはユーザー指示時のみ**
- 実装変更 → **同会話内SPEC同期** + **DEVELOPMENT_LOG追記**
- 数値・面白さは実プレイフィードバック優先
- ツール移行（Antigravity/Cursor等）を検討する場合も、**Godot/GDScriptのまま**が前提（本書冒頭参照）
- 作業を始める前に必ず `git log` と `git status` で最新状態を確認すること（本セッションでも、古いドキュメントを鵜呑みにして一度誤った前提で作業しかけた）

---

*End of FABLE_HANDOFF.md — 詳細仕様は `docs/SPEC.md` + `GAMEPLAY_DECISION_BRIEF.md`、変更理由は `DEVELOPMENT_LOG.md`*
