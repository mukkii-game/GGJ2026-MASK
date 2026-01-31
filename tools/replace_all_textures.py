#!/usr/bin/env python3
"""
1枚のPNGを、プレイヤー・敵・タイルシートの「全部」にコピーする。
使い方:
  python replace_all_textures.py <元になる1枚のPNGパス>
  python replace_all_textures.py Art/Sprites/WhiteTile32.png
  python replace_all_textures.py Scenes/Player/Sprite/Player_Idle1.png

※ 実行前にプロジェクトのバックアップを推奨。
※ Python と Pillow が必要: pip install Pillow
"""

import os
import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print("Pillow がありません。実行: pip install Pillow")
    sys.exit(1)

# プロジェクトルート（このスクリプトの親の親）
PROJECT_ROOT = Path(__file__).resolve().parent.parent
os.chdir(PROJECT_ROOT)

# コピー先フォルダ（プロジェクトルートからの相対パス）
PLAYER_SPRITES = PROJECT_ROOT / "Scenes/Player/Sprite"
ENEMY_SPRITES = PROJECT_ROOT / "Scenes/NPC's/Enemy/Sprites"
TILESHEET_PATH = PROJECT_ROOT / "Art/Sprites/TileSheet-Sheet.png"


def copy_to_all(source_path: Path, dry_run: bool = False, player_only: bool = False) -> None:
    """1枚の画像を、プレイヤー・敵・タイルシートの全PNGにコピーする。"""
    if not source_path.exists():
        print(f"エラー: 元画像が見つかりません: {source_path}")
        sys.exit(1)

    src = Image.open(source_path).convert("RGBA")
    src_size = src.size
    print(f"元画像: {source_path.name} サイズ: {src_size[0]}x{src_size[1]}" + (" (プレイヤーのみ)" if player_only else ""))

    count = 0
    folders = [PLAYER_SPRITES] if player_only else [PLAYER_SPRITES, ENEMY_SPRITES]

    # プレイヤー用（またはプレイヤー＋敵）スプライト
    for folder in folders:
        if not folder.exists():
            print(f"スキップ（フォルダなし）: {folder}")
            continue
        for f in folder.glob("*.png"):
            if f.resolve() == source_path.resolve():
                continue
            # プレイヤーのみモードで MoonKick は入れ替えない（攻撃エフェクトのため）
            if player_only and "moonkick" in f.name.lower():
                print(f"  スキップ（除外）: {f.relative_to(PROJECT_ROOT)}")
                continue
            try:
                # 既存ファイルと同じサイズにリサイズしてから保存（レイアウトを崩さない）
                ref = Image.open(f)
                w, h = ref.size
                ref.close()
                out = src.resize((w, h), Image.Resampling.LANCZOS)
                if not dry_run:
                    out.save(f)
                print(f"  OK: {f.relative_to(PROJECT_ROOT)} ({w}x{h})")
                count += 1
            except Exception as e:
                print(f"  NG: {f} - {e}")

    # タイルシート: 元の TileSheet-Sheet.png のサイズに、ソースをタイル状に敷き詰める（--player-only のときはスキップ）
    if not player_only and TILESHEET_PATH.exists():
        ref = Image.open(TILESHEET_PATH)
        tw, th = ref.size
        ref.close()
        # 1タイル = 32x32 想定。ソースを 32x32 にリサイズしてからタイル
        tile_w, tile_h = 32, 32
        out = Image.new("RGBA", (tw, th))
        tile_img = src.resize((tile_w, tile_h), Image.Resampling.LANCZOS)
        for y in range(0, th, tile_h):
            for x in range(0, tw, tile_w):
                out.paste(tile_img, (x, y))
        if not dry_run:
            out.save(TILESHEET_PATH)
        print(f"  OK: {TILESHEET_PATH.relative_to(PROJECT_ROOT)} (タイル {tw}x{th})")
        count += 1
    else:
        print(f"スキップ（ファイルなし）: {TILESHEET_PATH}")

    print(f"\n合計 {count} ファイルを書き換えました。" + (" (dry-run)" if dry_run else ""))


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        print("例: python replace_all_textures.py Art/Sprites/WhiteTile32.png")
        print("     python replace_all_textures.py --dry-run Scenes/Player/Sprite/Player_Idle1.png")
        sys.exit(0)

    dry_run = "--dry-run" in sys.argv
    player_only = "--player-only" in sys.argv
    args = [a for a in sys.argv[1:] if a not in ("--dry-run", "--player-only")]
    source = PROJECT_ROOT / args[0]
    copy_to_all(source, dry_run=dry_run, player_only=player_only)


if __name__ == "__main__":
    main()
