# キャラ・マップのテクスチャ変更手順

## 1. キャラのテクスチャを変える

### プレイヤー（Player）

**画像の場所**

- `Scenes/Player/Sprite/` フォルダ内の PNG

**使われているファイル（例）**

| アニメ | ファイル名 |
|--------|------------|
| Idle | Player_Idle1.png, Player_Idle2.png, Player_Idle3.png |
| Walk | Player_walk1.png, Player_walk2.png |
| Attack | Player_attack1.png ～ Player_attack6.png |
| Dash | Player_Dash1.png ～ Player_Dash4.png |
| Death | Player_Death1.png ～ Player_Death4.png |
| MoonKick | Player_MoonKick1.png ～ Player_MoonKick3.png |

**手順（絵だけ差し替える場合）**

1. 既存の PNG をバックアップ（別フォルダにコピー）。
2. 新しい絵を **同じファイル名・同じサイズ（32×32）** で保存し、`Scenes/Player/Sprite/` に上書き。
3. Godot を開いたままなら、シーンを再読み込みするかプロジェクトを再スキャン（F5 で実行し直すなど）すると反映される。

**別名の画像を使う場合**

- Godot で `Scenes/Player/Player.tscn` を開く。
- シーンツリーで **AnimatedSprite2D** を選択。
- インスペクタの **Sprite Frames** を開き、各アニメのフレームで「使う画像」を新しいテクスチャに差し替える。

---

### 敵（Enemy）

**画像の場所**

- `Scenes/NPC's/Enemy/Sprites/` フォルダ内の PNG（Enemy01.png ～ Enemy22.png）

**手順**

1. 既存 PNG をバックアップ。
2. 新しい絵を **同じファイル名・同じサイズ** で `Scenes/NPC's/Enemy/Sprites/` に上書き。
3. 敵のアニメ（Idle / Walk / Attack / Death）は、Enemy.tscn の SpriteFrames でどの画像を何番目に使うか決まっている。並びを変えたい場合は Godot で `Enemy.tscn` → AnimatedSprite2D → Sprite Frames を編集。

---

## 2. マップを白いマットに変える

**使われている画像**

- `Art/Sprites/TileSheet-Sheet.png`  
  → TileSet（`Art/TileMap.tres`）が **32×32 のタイル**として切り出して使用。

**方法 A：画像の差し替え（推奨）**

1. 現在の `TileSheet-Sheet.png` のサイズを確認する（Godot で開くか、エクスプローラーでプロパティ表示）。  
   - 例：横 320px × 縦 192px なら、タイルは 10×6 個など。
2. 同じサイズの画像を用意する。  
   - 白一色でも、薄いグレーのマット風でも可。  
   - 各 32×32 が 1 タイルなので、「白い床」「壁」など役割ごとに色を分けてもよい。
3. 既存の `TileSheet-Sheet.png` をバックアップしてから、新しい画像を **同じファイル名** で `Art/Sprites/TileSheet-Sheet.png` に上書き。
4. Godot でプロジェクトを再読み込み（または F5 で実行）。マップが新しいタイルで表示される。

**方法 B：白 1 タイルだけ使う場合**

1. 32×32 の白い PNG を 1 枚用意（例：`Art/Sprites/WhiteTile.png`）。
2. Godot で **Art/TileMap.tres** を開く。
3. TileSet エディタで「ソース」のテクスチャを、その白画像に差し替え。
4. 既存マップは「タイル ID」で参照しているため、タイルの並びや数が変わると、レイアウトがずれることがある。  
   - 白 1 種類だけにする場合は、マップを開いて「使うタイル」をすべてその白タイルに塗り直す必要がある。

**白タイル用サンプル画像**

- プロジェクトに `Art/Sprites/WhiteTile32.png` を用意してある場合は、TileSet のソースをそれにすると、白マット用の 1 タイルとして使える（上記方法 B）。
