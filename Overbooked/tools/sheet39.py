"""outline every new ui39/*_raw.png (outline_icon.py) and lay them all on a review sheet: python sheet39.py"""
import sys, os, subprocess, glob
from PIL import Image, ImageDraw
HERE = os.path.dirname(os.path.abspath(__file__))
D = os.path.join(HERE, "ui39")
names = sorted(os.path.basename(p)[:-8] for p in glob.glob(os.path.join(D, "*_raw.png")))
for n in names:
    raw, out = os.path.join(D, n + "_raw.png"), os.path.join(D, n + ".png")
    if os.path.exists(out) and os.path.getmtime(out) >= os.path.getmtime(raw):
        continue  # already outlined since the last render
    subprocess.run([sys.executable, os.path.join(HERE, "outline_icon.py"), os.path.join(D, n + "_raw.png"), os.path.join(D, n + ".png")], check=True, capture_output=True)
cols = 10
cell = 140
rows = (len(names) + cols - 1) // cols
sheet = Image.new("RGB", (cols * cell, rows * (cell + 18)), (232, 236, 244))
dr = ImageDraw.Draw(sheet)
for i, n in enumerate(names):
    im = Image.open(os.path.join(D, n + ".png")).resize((cell - 12, cell - 12), Image.LANCZOS)
    x, y = (i % cols) * cell, (i // cols) * (cell + 18)
    sheet.paste(im, (x + 6, y + 4), im)
    dr.text((x + 8, y + cell - 2), n, fill=(40, 40, 60))
sheet.save(os.path.join(D, "_sheet.png"))
print("sheet", len(names))
