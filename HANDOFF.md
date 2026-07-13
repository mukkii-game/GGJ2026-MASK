# HANDOFF.md — AI間の開発引き継ぎ

**作成日**: 2026-07-13  
**最終更新**: 2026-07-13 16:00（Composer 2.5 · Phase A 完了）  
**目的**: どのAI（モデル）が中断しても、別のAIがそのまま再開できるようにする

---

## 現在の状況（2026-07-13 Phase A 完了）

- **Phase A（システム変更）**: ✅ **完了・commit済み**（Sonnet中断分を Composer が完成）
- **Phase B（ステージ個別改修）**: ⬜ 未着手（S1フォーメーション、S2陣取り、S3/S4ボス等）
- **Phase C（スマホ対応）**: ⬜ Phase B の後
- 進行率: `PROGRESS.md` 参照
- 設計変更理由: `DESIGN_CHANGELOG.md` 参照

### Phase A で変わったこと（要約）

| 項目 | 変更 |
|------|------|
| 移動 | 滑らかのみ（グリッド/Gキー/炎ダッシュ廃止） |
| N / 左クリ | 自動走行のみ |
| ジャンプ | M/Space/Enter + 1P左クリ（2Pモード時無効） |
| 半キャラ | **左右接近のみ**（32〜52px） |
| かすり | 52〜64px（左右）/ 上下接近32〜64px |
| ロープ | **四辺バウンド** + ダッシュ1.5倍 + 連打速 |
| コーナーポスト | プレイヤー用無効 |
| パワーエサ | 20秒移動・敵全員弱り8秒（速度2倍削除） |

### 検証用 Godot

`C:\Program Files\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe`

```powershell
& "<上記exe>" --headless --path "e:\GodotProjects\GGJ2026-MASK" "res://Scenes/Levels/GameWrapper.tscn" --quit-after 600
```

headless で主要6シーン起動OK（invalid UID 警告・終了時 resource leak は無害）。

---

## 次にやること（Phase B）

1. **実プレイ確認**（Phase A の手触り：四辺ロープ、半キャラ左右限定、かすり幅）
2. S1 2体組フォーメーション / 湧き直し
3. S2 メロンナ陣取り（旧「ジャンプ足止め」は廃止済み）
4. S3 全面改修（怒り HP 75/50/25% トリガー案）
5. S4 イーロン（直角ピヨり・ショータイム演出）

---

## 重要ファイル

| ファイル | 内容 |
|----------|------|
| `Scenes/Player/Scripts/PlayerMain.gd` | 体当たり・ロープ・Phase A 定数 |
| `DESIGN_CHANGELOG.md` | 仕様変更の理由 |
| `docs/SPEC.md` | 正式仕様（B.0 / B.0.1 / B.5.1 更新済み） |
| `PROGRESS.md` | 進捗率 |

---

## 最終基準

**「指示を全部実装したか」ではなく「実際に遊んで面白いか」。**  
`NON_NEGOTIABLES.md` の核（体当たりのみ・半キャラ勝ち筋・ロープコード実装）は維持。
