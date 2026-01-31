# TASKS: P0 Vertical Slice

## P0-01 Movement（30–45min）
- [ ] Player の量子化移動（32pxステップ）
- [ ] Enemy の直線追尾（量子化）

## P0-02 HitBoxes（30–45min）
- [ ] Player に FrontHitBox / SideHitBox を追加
- [ ] Enemy に HurtBox を追加
- [ ] 重なり検知でログ出力

## P0-03 Contact Combat（45–60min）
- [ ] Front 接触：Player/Enemy 両方にダメージ
- [ ] Side 接触：Enemy のみダメージ
- [ ] ダメージ量は仮値（例：1）

## P0-04 Push & Knockback（30–45min）
- [ ] 接触中は前/後のみ移動
- [ ] Side 成功時に Enemy を軽くノックバック

## P0-05 HP & Win/Lose（30–45min）
- [ ] Player/Enemy に HP を持たせる
- [ ] Enemy HP == 0 → Win 表示
- [ ] Player HP == 0 → Lose 表示
