"""Generate the repo hero banner (images/banner.png)."""
import pathlib

from PIL import Image, ImageDraw, ImageFont

W, H = 1600, 480
NAVY = (31, 42, 90)      # 1F2A5A
BLUE = (15, 108, 189)    # 0F6CBD
LIGHT = (234, 241, 251)  # EAF1FB

# Diagonal-ish horizontal gradient navy -> blue
img = Image.new("RGB", (W, H), NAVY)
px = img.load()
for x in range(W):
    t = x / (W - 1)
    r = int(NAVY[0] + (BLUE[0] - NAVY[0]) * t)
    g = int(NAVY[1] + (BLUE[1] - NAVY[1]) * t)
    b = int(NAVY[2] + (BLUE[2] - NAVY[2]) * t)
    for y in range(H):
        px[x, y] = (r, g, b)
draw = ImageDraw.Draw(img)

# subtle accent bar
draw.rectangle([0, 0, W, 8], fill=BLUE)
draw.rectangle([0, H - 8, W, H], fill=(255, 255, 255))

FONT_REG = "C:/Windows/Fonts/segoeui.ttf"
FONT_BOLD = "C:/Windows/Fonts/segoeuib.ttf"
FONT_SEMI = "C:/Windows/Fonts/seguisb.ttf"
f_kicker = ImageFont.truetype(FONT_SEMI, 30)
f_title = ImageFont.truetype(FONT_BOLD, 74)
f_title2 = ImageFont.truetype(FONT_BOLD, 74)
f_sub = ImageFont.truetype(FONT_REG, 34)
f_chip = ImageFont.truetype(FONT_SEMI, 26)

M = 90
y = 78
draw.text((M, y), "MICROSOFT FOUNDRY MICROHACK", font=f_kicker, fill=(150, 200, 245))
y += 52
draw.text((M, y), "Agentic AI Hacks", font=f_title, fill=(255, 255, 255))
y += 82
draw.text((M, y), "Contract Lifecycle Management", font=f_title2, fill=(215, 232, 250))
y += 104
draw.text((M, y), "Multi-model, multi-agent CLM on Microsoft Foundry \u2014 grounded, traced, evaluated & shipped.",
          font=f_sub, fill=(230, 238, 250))

# chips
chips = ["4.5 hours", "5 challenges + bonus", "Multi-model GPT", "Foundry IQ \u00b7 MCP \u00b7 Teams"]
cy = 372
cx = M
for c in chips:
    tb = draw.textbbox((0, 0), c, font=f_chip)
    cw = tb[2] - tb[0]
    pad = 22
    draw.rounded_rectangle([cx, cy, cx + cw + pad * 2, cy + 46], radius=23,
                           fill=(255, 255, 255, 255))
    draw.text((cx + pad, cy + 8), c, font=f_chip, fill=NAVY)
    cx += cw + pad * 2 + 18

_out = pathlib.Path("images/banner.png")
_out.parent.mkdir(parents=True, exist_ok=True)
img.save(_out)
print("wrote", _out, img.size)
