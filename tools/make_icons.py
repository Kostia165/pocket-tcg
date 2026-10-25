"""usage: python -I make_icons.py <charizard.png> <out_dir>"""
import sys
from PIL import Image, ImageDraw

src = Image.open(sys.argv[1]).convert("RGBA")
src = src.crop(src.getbbox())  # trim transparent border
out = sys.argv[2]

def fit(img, box):
    s = box / max(img.size)
    return img.resize((round(img.width * s), round(img.height * s)), Image.LANCZOS)

def background(size):
    # warm radial glow on dark blue-grey, matching the game's colours
    bg = Image.new("RGBA", (size, size), (27, 29, 36, 255))
    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(glow)
    for i in range(60, 0, -1):
        r = size * 0.48 * i / 60
        a = int(150 * (1 - i / 60) ** 1.5)
        d.ellipse([size / 2 - r, size / 2 - r, size / 2 + r, size / 2 + r], fill=(255, 120, 40, a))
    return Image.alpha_composite(bg, glow)

def paste_center(base, img):
    base.alpha_composite(img, ((base.width - img.width) // 2, (base.height - img.height) // 2))

# Main / legacy icon: rounded square with Charizard filling most of it.
icon = background(512)
paste_center(icon, fit(src, 430))
mask = Image.new("L", (512, 512), 0)
ImageDraw.Draw(mask).rounded_rectangle([0, 0, 511, 511], radius=96, fill=255)
icon.putalpha(mask)
icon.save(f"{out}/icon.png")

# Adaptive icon: the launcher crops to a circle/squircle, so keep Charizard in the inner ~60%.
fg = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
paste_center(fg, fit(src, 270))
fg.save(f"{out}/icon_foreground.png")
background(432).save(f"{out}/icon_background.png")
print("ok")
