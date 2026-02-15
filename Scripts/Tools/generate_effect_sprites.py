#!/usr/bin/env python3
"""キャラ絵からエフェクト用画像を生成（赤・白・青・黄：透明以外をその色で塗りつぶし）"""
import os
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print("Pillow が必要です: pip install Pillow")
    raise

# プロジェクトルート（このスクリプトから見て ../../）
ROOT = Path(__file__).resolve().parents[2]
SOURCE_DIRS = [
    ROOT / "Art" / "Sprites",
    ROOT / "Scenes" / "Player" / "Sprite",
    ROOT / "Scenes" / "NPC's" / "Enemy" / "Sprites",
]
OUTPUT_DIR = ROOT / "Art" / "Sprites" / "Effect"
ALPHA_THRESHOLD = 3  # 0-255

EFFECT_COLORS = {
    "red": (255, 51, 51, 255),
    "white": (255, 255, 255, 255),
    "blue": (64, 128, 255, 255),
    "yellow": (255, 255, 76, 255),
}


def process_image(path: Path) -> None:
    try:
        img = Image.open(path).convert("RGBA")
    except Exception as e:
        print(f"  skip {path.name}: {e}")
        return
    w, h = img.size
    pixels = img.load()
    for color_name, (r, g, b, a) in EFFECT_COLORS.items():
        out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        out_pix = out.load()
        for y in range(h):
            for x in range(w):
                _, _, _, alpha = pixels[x, y]
                if alpha > ALPHA_THRESHOLD:
                    out_pix[x, y] = (r, g, b, alpha)
        out_path = OUTPUT_DIR / f"effect_{color_name}_{path.stem}.png"
        out.save(out_path)
        print(f"  wrote {out_path.relative_to(ROOT)}")


def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    count = 0
    for dir_path in SOURCE_DIRS:
        if not dir_path.is_dir():
            continue
        for path in sorted(dir_path.glob("*.png")):
            if path.name.startswith("effect_"):
                continue
            print(f"Processing {path.relative_to(ROOT)}")
            process_image(path)
            count += 1
    print(f"Done. Processed {count} images.")


if __name__ == "__main__":
    main()
