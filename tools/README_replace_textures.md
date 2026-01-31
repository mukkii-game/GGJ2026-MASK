# 1枚のPNGを全テクスチャに一括コピーする

## 準備

1. **Python** が入っていること
2. **Pillow** を入れる: `pip install Pillow`
3. **元になる1枚のPNG** を用意する  
   - 例: 白いマット用なら 32×32 の白い画像を用意する。  
     - 手動: ペイントなどで 32×32 を白で塗って `Art/Sprites/WhiteTile32.png` で保存。  
     - または Pillow で作成（プロジェクトルートで）:  
       `python -c "from PIL import Image; Image.new('RGBA',(32,32),(255,255,255,255)).save('Art/Sprites/WhiteTile32.png')"`  
   - 既存のどれか1枚を「全員これにする」なら、そのファイルパスを指定すればよい

## 実行

プロジェクトルート（`GGJ2026-MASK`）で:

```bash
# 白タイルなど「1枚」を全員にコピー（Art/Sprites/WhiteTile32.png を事前に用意）
python tools/replace_all_textures.py Art/Sprites/WhiteTile32.png

# 既存の Player_Idle1.png の絵を、プレイヤー・敵・タイルシート全部にコピー
python tools/replace_all_textures.py Scenes/Player/Sprite/Player_Idle1.png
```

**書き換え前に確認だけしたい場合（実際には保存しない）:**

```bash
python tools/replace_all_textures.py --dry-run Art/Sprites/WhiteTile32.png
```

## 何が書き換わるか

- `Scenes/Player/Sprite/` 内の **全 PNG**（Player_Idle1, Player_walk1 など）
- `Scenes/NPC's/Enemy/Sprites/` 内の **全 PNG**（Enemy01 ～ Enemy22）
- `Art/Sprites/TileSheet-Sheet.png`（マップ用タイルシート）  
  → 元画像を 32×32 にリサイズして、現在のシートサイズにタイル状に敷き詰める

元画像と**同じファイル**は上書きしない。サイズは「既存の各ファイルのサイズ」に合わせてリサイズしてから保存するので、Godot の参照はそのまま使える。

## 注意

- **実行前にプロジェクト（または Sprite フォルダ）のバックアップを取ること。**
- 実行後、Godot でプロジェクトを開き直すか F5 で実行すると反映される。
