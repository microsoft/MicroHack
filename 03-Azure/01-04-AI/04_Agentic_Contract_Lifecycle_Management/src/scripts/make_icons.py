"""Generate the Teams / M365 Copilot app icons for the CLM Assistant.

Writes two files next to the Teams manifest (src/manifest/):
  - color.png    192x192, full-colour app icon (brand gradient + contract glyph)
  - outline.png   32x32, transparent, single-colour white silhouette (Teams tints it)

These are branded placeholders so participants can zip the manifest without
having to design their own icons. Re-run after tweaking the design:
    python src/scripts/make_icons.py
"""
from pathlib import Path

from PIL import Image, ImageDraw

NAVY = (31, 42, 90)     # 1F2A5A  (matches images/banner.png)
BLUE = (15, 108, 189)   # 0F6CBD
WHITE = (255, 255, 255)

OUT_DIR = Path(__file__).resolve().parents[2] / "src" / "manifest"
SS = 4  # supersample factor for crisp anti-aliased edges


def _document_path(d: ImageDraw.ImageDraw, box, fold, radius, **kw):
    """Draw a page with a folded top-right corner inside `box`."""
    x0, y0, x1, y1 = box
    # main body (rounded) then knock the corner back in with the fold
    d.rounded_rectangle([x0, y0, x1, y1], radius=radius, **kw)
    # fold triangle: cover the top-right, then redraw as the turned corner
    d.polygon([(x1 - fold, y0), (x1, y0), (x1, y0 + fold)], fill=(0, 0, 0, 0))


def render(size: int, *, color: bool) -> Image.Image:
    S = size * SS
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    if color:
        # full-bleed vertical gradient background (navy -> blue)
        for y in range(S):
            t = y / (S - 1)
            r = int(NAVY[0] + (BLUE[0] - NAVY[0]) * t)
            g = int(NAVY[1] + (BLUE[1] - NAVY[1]) * t)
            b = int(NAVY[2] + (BLUE[2] - NAVY[2]) * t)
            d.line([(0, y), (S, y)], fill=(r, g, b, 255))

    # geometry for the page glyph (centred)
    pw, ph = int(S * 0.42), int(S * 0.54)
    px0 = (S - pw) // 2
    py0 = int(S * 0.20)
    px1, py1 = px0 + pw, py0 + ph
    fold = int(pw * 0.30)
    radius = int(pw * 0.10)

    page_fill = WHITE + (255,) if color else (0, 0, 0, 0)
    page_outline = None if color else WHITE + (255,)
    stroke = 0 if color else max(2, int(S * 0.035))

    # page body
    d.rounded_rectangle([px0, py0, px1, py1], radius=radius,
                        fill=page_fill, outline=page_outline, width=stroke)
    # blank the folded corner and draw the turn-down
    d.polygon([(px1 - fold, py0), (px1 + 2, py0), (px1 + 2, py0 + fold)],
              fill=(0, 0, 0, 0))
    if color:
        d.line([(px1 - fold, py0), (px1 - fold, py0 + fold)], fill=NAVY + (255,), width=max(1, SS))
        d.line([(px1 - fold, py0 + fold), (px1, py0 + fold)], fill=NAVY + (255,), width=max(1, SS))
        d.polygon([(px1 - fold, py0 + fold), (px1, py0 + fold), (px1 - fold, py0)],
                  fill=(214, 226, 245, 255))
    else:
        d.line([(px1 - fold, py0), (px1 - fold, py0 + fold), (px1, py0 + fold)],
               fill=WHITE + (255,), width=stroke, joint="curve")

    # text lines on the page
    line_col = NAVY + (255,) if color else WHITE + (255,)
    lw = max(2, int(S * (0.018 if color else 0.030)))
    lx0 = px0 + int(pw * 0.16)
    lx1 = px1 - int(pw * 0.16)
    for i, frac in enumerate((0.42, 0.55, 0.68)):
        ly = py0 + int(ph * frac)
        end = lx1 if i < 2 else lx0 + int((lx1 - lx0) * 0.55)
        d.line([(lx0, ly), (end, ly)], fill=line_col, width=lw)

    # check badge, bottom-right of the page
    br = int(pw * 0.34)
    bcx, bcy = px1 - int(pw * 0.02), py1 - int(ph * 0.02)
    if color:
        d.ellipse([bcx - br, bcy - br, bcx + br, bcy + br], fill=BLUE + (255,),
                  outline=WHITE + (255,), width=max(2, int(S * 0.012)))
    else:
        d.ellipse([bcx - br, bcy - br, bcx + br, bcy + br], outline=WHITE + (255,),
                  width=stroke)
    cw = max(2, int(S * (0.028 if color else 0.032)))
    d.line([(bcx - int(br * 0.45), bcy),
            (bcx - int(br * 0.05), bcy + int(br * 0.42)),
            (bcx + int(br * 0.55), bcy - int(br * 0.42))],
           fill=WHITE + (255,) if color else WHITE + (255,), width=cw, joint="curve")

    return img.resize((size, size), Image.LANCZOS)


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    color = render(192, color=True)
    outline = render(32, color=False)
    color.save(OUT_DIR / "color.png")
    outline.save(OUT_DIR / "outline.png")
    print(f"wrote {OUT_DIR / 'color.png'} {color.size}")
    print(f"wrote {OUT_DIR / 'outline.png'} {outline.size}")


if __name__ == "__main__":
    main()
