# TODO.md — 作業状態（AI引き継ぎ用）

**最終更新**: 2026-07-13 21:00（クラウド Fable 引き渡し前）  
**進行率は `PROGRESS.md`。** 統合引き継ぎは **`FABLE_HANDOFF.md`**

---

## 完了済み — Phase A（2026-07-13 Composer）

- [x] **グリッド/炎ダッシュ/Gキー廃止** — 滑らか移動のみ、N＝自動走行
- [x] **コーナーポスト（プレイヤー）廃止** — S4特攻50削除
- [x] **半キャラ左右限定 / 上下はかすり** — `horizontal_approach` 分岐
- [x] **かすり帯拡大** — SEMI_CAR_MAX 58→52
- [x] **ロープ四辺バウンド + たわみ** — top/bottom 追加
- [x] **ロープダッシュ** — commit 時 1.5倍 → **ホットフィックスで 2.0倍復帰**（未 commit）
- [x] **パワーエサ統一** — 20秒移動・敵全員弱り8秒（速度2倍削除）
- [x] **ジャンプ多重バインド** — M/Space/Enter + 1P左クリ（2Pモード時無効）
- [x] **SPEC / DESIGN_CHANGELOG / HANDOFF 同期**
- [x] **headless 主要6シーン** — ALL_OK

## 進行中（Phase B 前）

- [ ] **未コミット分を commit + push**（ノックバック/SE/BGM/HPバー — 詳細 `FABLE_HANDOFF.md` §1）
- [ ] **ホットフィックス実プレイ確認**: ロープ加速ノックバック、半キャラSE毎tick、BGM即再生、四辺ロープ
- [ ] **Phase A 実プレイ確認**: 半キャラ（左右のみ）、かすり52px帯、パワーエサ
- [ ] **2P操作確認**: 左クリ＝自動走行、右クリ＝ジャンプ
- [ ] **通しプレイ** S1→S4→エンディング

## 未着手 — Phase B（優先順）

- [ ] S1: 2体組フォーメーション / 湧き直し
- [ ] S2: メロンナ陣取り・降臨・追い詰め（旧ジャンプ足止めは廃止済み）
- [ ] S3: 全面改修（怒り HP 75/50/25% 案）
- [ ] S4: イーロン（直角ピヨり・ショータイム）
- [ ] ボスエサ争奪AI + 予兆吹き出し

## 未着手 — その他

- [ ] OQ-04: ダウン敵復活条件
- [ ] OQ-06: エンディング充実
- [ ] Phase C: スマホ対応

## 実行済みテスト

- ✅ headless: Title / GameWrapper / StageClear / Ending / StageIntro / DeathScreen — ALL_OK（Phase A後）
- ⚠️ 実プレイ（目視・操作）は Phase A 後未実施

## 変更してはいけないもの

- `NON_NEGOTIABLES.md` の核
- 体当たり3種 + `_body_contact()` AABB方式
- ロープ: コードクランプ + 自動バウンド（Area2D不可）

## 参照

- 設計変更理由: `DESIGN_CHANGELOG.md`
- 正式仕様: `docs/SPEC.md` B.0 / B.0.1 / B.5.1
