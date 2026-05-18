#!/usr/bin/env python3
"""
Generate the Kaggle submission cover image (560×280).
Composites mobile/assets/icon.png on an indigo→violet gradient
matching the app theme, with the ScorvoAI wordmark + tagline.

Run from repo root:
    python scripts/generate_cover.py
    # → docs/cover.png  (560 × 280, ready for Kaggle Media Gallery upload)

Requires: pillow  (pip install Pillow)
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

REPO = Path(__file__).resolve().parent.parent
ICON = REPO / "mobile" / "assets" / "icon.png"
OUT = REPO / "docs" / "cover.png"

W, H = 560, 280
INDIGO = (99, 102, 241)      # #6366f1
VIOLET = (139, 92, 246)      # #8b5cf6
WHITE = (255, 255, 255)
WHITE_DIM = (255, 255, 255, 200)


def gradient_bg(w: int, h: int) -> Image.Image:
    """Diagonal indigo→violet gradient matching AppColors.heroGradient."""
    img = Image.new("RGB", (w, h), INDIGO)
    px = img.load()
    # Diagonal interpolation: t = (x + y) / (w + h)
    denom = w + h
    for x in range(w):
        for y in range(h):
            t = (x + y) / denom
            r = round(INDIGO[0] * (1 - t) + VIOLET[0] * t)
            g = round(INDIGO[1] * (1 - t) + VIOLET[1] * t)
            b = round(INDIGO[2] * (1 - t) + VIOLET[2] * t)
            px[x, y] = (r, g, b)
    return img


def best_font(size: int) -> ImageFont.FreeTypeFont:
    """Pick the first font that exists locally — fall back to PIL default."""
    candidates = [
        "/usr/share/fonts/truetype/dejavu/DejaVu-Sans-Bold.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
        "C:/Windows/Fonts/segoeuib.ttf",
    ]
    for c in candidates:
        if Path(c).exists():
            return ImageFont.truetype(c, size)
    return ImageFont.load_default()


def main() -> None:
    if not ICON.exists():
        raise SystemExit(f"App icon not found at {ICON}")
    OUT.parent.mkdir(parents=True, exist_ok=True)

    # 1. Gradient background
    canvas = gradient_bg(W, H).convert("RGBA")

    # 2. Subtle dark vignette in bottom-right for depth
    vignette = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    vd = ImageDraw.Draw(vignette)
    for r in range(120, 0, -8):
        vd.ellipse(
            (W - r, H - r, W + r, H + r),
            fill=(11, 11, 24, max(0, 60 - r // 3)),
        )
    canvas = Image.alpha_composite(canvas, vignette)

    # 3. App icon, 200×200, left side, vertically centered
    icon = Image.open(ICON).convert("RGBA").resize((200, 200), Image.LANCZOS)
    canvas.alpha_composite(icon, (40, (H - 200) // 2))

    # 4. Text block on the right
    draw = ImageDraw.Draw(canvas)
    title_font = best_font(46)
    sub_font = best_font(17)
    foot_font = best_font(13)

    x = 270
    # Wordmark
    draw.text((x, 50), "ScorvoAI", fill=WHITE, font=title_font)
    # Brand positioning
    draw.text((x, 105), "AI Companion", fill=WHITE_DIM, font=sub_font)
    # The loop (memorable hook) — split across two lines for fit
    draw.text((x, 145), "Learn · Practice", fill=WHITE, font=sub_font)
    draw.text((x, 167), "Analyse · Improve", fill=WHITE, font=sub_font)
    # Exam list footer
    draw.text(
        (x, 215),
        "UPSC · SSC · IBPS · SBI · RRB",
        fill=(255, 255, 255, 160),
        font=foot_font,
    )

    # 5. "Built with Gemma 4" chip bottom-right
    chip_text = "Built with Gemma 4"
    chip_font = best_font(13)
    cw, ch = draw.textbbox((0, 0), chip_text, font=chip_font)[2:]
    cx, cy = W - cw - 24, H - ch - 20
    pad_x, pad_y = 10, 5
    draw.rounded_rectangle(
        (cx - pad_x, cy - pad_y, cx + cw + pad_x, cy + ch + pad_y),
        radius=10,
        fill=(0, 0, 0, 110),
        outline=(255, 255, 255, 160),
        width=1,
    )
    draw.text((cx, cy), chip_text, fill=(255, 255, 255, 255), font=chip_font)

    canvas.convert("RGB").save(OUT, "PNG", optimize=True)
    print(f"✓ Cover written to {OUT} ({W}×{H})")


if __name__ == "__main__":
    main()
