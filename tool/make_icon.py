"""Renders the Shop-it app icon (Windows .ico + Android launcher PNGs).

Run from the repo root: python tool/make_icon.py   (needs Pillow)
"""
from PIL import Image, ImageDraw

S = 2048  # master size; everything is drawn here and downsampled
LIME = (191, 224, 79)
LIME_DEEP = (134, 170, 18)
BG_TOP = (44, 52, 36)
BG_BOT = (22, 25, 18)


def master():
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    # background: rounded square with vertical gradient
    grad = Image.new("RGBA", (S, S))
    gd = ImageDraw.Draw(grad)
    for y in range(S):
        t = y / (S - 1)
        gd.line([(0, y), (S, y)], fill=tuple(
            int(BG_TOP[i] + (BG_BOT[i] - BG_TOP[i]) * t) for i in range(3)) + (255,))
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, S - 1, S - 1], radius=int(S * 0.225), fill=255)
    img.paste(grad, (0, 0), mask)

    d = ImageDraw.Draw(img)
    w = int(S * 0.062)  # stroke width

    def line(pts, color=LIME):
        d.line(pts, fill=color, width=w, joint="curve")
        for x, y in (pts[0], pts[-1]):
            d.ellipse([x - w / 2, y - w / 2, x + w / 2, y + w / 2], fill=color)

    # bag body: tapered tote, rounded joins
    d = ImageDraw.Draw(img)
    top, bot = S * 0.40, S * 0.80
    pts = [(S * 0.22, top), (S * 0.78, top), (S * 0.70, bot), (S * 0.30, bot)]
    line(pts + [pts[0]])
    # round the outer corners of the polyline
    for x, y in pts:
        d.ellipse([x - w / 2, y - w / 2, x + w / 2, y + w / 2], fill=LIME)
    # handle: wide arc whose ends sit inside the bag
    d.arc([S * 0.34, S * 0.17, S * 0.66, S * 0.63], 180, 360, fill=LIME, width=w)
    for x in (S * 0.34 + w / 2 - 1, S * 0.66 - w / 2 + 1):
        d.ellipse([x - w / 2, S * 0.40 - w / 2, x + w / 2, S * 0.40 + w / 2], fill=LIME)

    # check mark inside the bag
    line([(S * 0.40, S * 0.615), (S * 0.475, S * 0.69), (S * 0.60, S * 0.545)], LIME)
    return img


def main():
    m = master()
    # Windows: multi-size ico
    sizes = [16, 24, 32, 48, 64, 128, 256]
    m.save("windows/runner/resources/app_icon.ico", sizes=[(s, s) for s in sizes])
    # Android launcher icons
    for d, px in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
        m.resize((px, px), Image.LANCZOS).save(
            f"android/app/src/main/res/mipmap-{d}/ic_launcher.png")
    m.resize((96, 96), Image.LANCZOS).save("assets/app_icon.png")
    m.resize((512, 512), Image.LANCZOS).save("tool/icon_preview.png")


main()
