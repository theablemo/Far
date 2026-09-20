#!/usr/bin/env python3
"""Compose README artwork from Far's icon and unmodified native UI fixtures.

Requires macOS and Pillow. No network access or application monitoring is used.
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
MEDIA = ROOT / "docs" / "media"
FONT = "/System/Library/Fonts/Avenir Next.ttc"
FOREST = "#20503e"
INK = "#183b30"
MUTED = "#52685f"
PAPER = "#edf7f0"


def font(size, weight="regular"):
    return ImageFont.truetype(FONT, size, index={"bold": 0, "medium": 5, "regular": 7}[weight])


def center_text(draw, text, y, face, fill, width=830):
    box = draw.textbbox((0, 0), text, font=face)
    draw.text(((width - (box[2] - box[0])) / 2, y), text, font=face, fill=fill, anchor="lt")


def hero():
    canvas = Image.new("RGB", (1660, 560), PAPER)
    draw = ImageDraw.Draw(canvas)
    draw.text((102, 75), "Far", font=font(160, "bold"), fill=INK, anchor="lt")
    draw.text((110, 280), "Make room for a screen break.", font=font(47, "medium"), fill=INK, anchor="lt")
    draw.text((112, 381), "A quiet menu bar companion for macOS.", font=font(32), fill=MUTED, anchor="lt")
    icon = Image.open(ROOT / "Resources" / "FarIconSource.png").convert("RGBA")
    icon.thumbnail((350, 350), Image.Resampling.LANCZOS)
    canvas.paste(icon, (1205, 99), icon)
    canvas.save(MEDIA / "hero.png", optimize=True)


def preview_frame(filename, step):
    canvas = Image.new("RGBA", (830, 466), "#f3f6f4")
    draw = ImageDraw.Draw(canvas)
    labels = ["A moment to finish.", "A little room to rest.", "Back when you’re ready."]
    center_text(draw, labels[step], 34, font(26, "medium"), INK)
    fixture = Image.open(MEDIA / "fixtures" / filename).convert("RGBA")
    # Keep the actual rendered UI pixels at native size: this is a composition,
    # not a redraw, mockup, or screen recording.
    x, y = (830 - fixture.width) // 2, 86 + (298 - fixture.height) // 2
    shadow = Image.new("RGBA", canvas.size)
    shadow.paste((32, 80, 62, 34), (x, y + 10), fixture.getchannel("A"))
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(15)))
    canvas.alpha_composite(fixture, (x, y))
    draw = ImageDraw.Draw(canvas)
    steps = ["Countdown", "Look away", "Carry on"]
    centers = [238, 415, 592]
    for i, (label, cx) in enumerate(zip(steps, centers)):
        fill = FOREST if i == step else "#84958c"
        face = font(16, "medium" if i == step else "regular")
        box = draw.textbbox((0, 0), label, font=face)
        draw.text((cx - (box[2] - box[0]) / 2, 393), label, font=face, fill=fill, anchor="lt")
        if i == step:
            draw.line((cx - 17, 417, cx + 17, 417), fill=FOREST, width=2)
    center_text(draw, "Synthetic native UI preview. Timing accelerated.", 443, font(12), MUTED)
    return canvas.convert("RGB")


def preview():
    filenames = ["countdown-light.png", "rest-light.png", "completion-light.png"]
    frames = [preview_frame(name, i) for i, name in enumerate(filenames)]
    frames[1].save(MEDIA / "break-preview.png", optimize=True)
    frames[0].save(
        MEDIA / "break-flow.gif", save_all=True, append_images=frames[1:],
        duration=[2500, 3200, 2500], loop=0, disposal=2, optimize=True,
    )


if __name__ == "__main__":
    MEDIA.mkdir(parents=True, exist_ok=True)
    hero()
    preview()
