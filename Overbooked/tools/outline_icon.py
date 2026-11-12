"""Gives a Blender-rendered icon the house outline + soft shadow, centred on a 256 canvas.
python outline_icon.py ui/hammer14_raw.png ui/hammer14.png"""
import sys
from PIL import Image, ImageFilter, ImageChops
src, dst = sys.argv[1], sys.argv[2]
im = Image.open(src).convert("RGBA")
bb = im.getbbox()
im = im.crop(bb)
S = 4
side = 256 * S
pad = int(side * 0.1)
k = (side - 2 * pad) / max(im.size)
im = im.resize((int(im.size[0] * k), int(im.size[1] * k)), Image.LANCZOS)
canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
ox, oy = (side - im.size[0]) // 2, (side - im.size[1]) // 2
layer = Image.new("RGBA", (side, side), (0, 0, 0, 0))
layer.paste(im, (ox, oy), im)
a = layer.getchannel("A").point(lambda v: 255 if v > 40 else 0)
ol = a.filter(ImageFilter.MaxFilter(2 * 12 * S // 2 + 1 if False else 41))
ol = ol.filter(ImageFilter.GaussianBlur(2))
shadow = ol.filter(ImageFilter.GaussianBlur(6 * S))
sh = Image.new("RGBA", (side, side), (20, 10, 30, 0))
sh.putalpha(shadow.point(lambda v: int(v * 0.35)))
canvas.alpha_composite(sh, (0, 6 * S))
ink = Image.new("RGBA", (side, side), (46, 34, 58, 255))
ink.putalpha(ol)
canvas.alpha_composite(ink)
canvas.alpha_composite(layer)
canvas.resize((256, 256), Image.LANCZOS).save(dst)
print("ok", dst)
