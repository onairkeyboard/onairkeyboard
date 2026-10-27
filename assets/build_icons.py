"""Builds the icon and logo assets from the SVG sources in assets/src.

Requires Inkscape on PATH. Produces:
  assets/app.ico               application / EXE icon (red keycap)
  assets/tray-idle-light.ico   tray icon, idle, light taskbar (black keycap)
  assets/tray-idle-dark.ico    tray icon, idle, dark taskbar (white keycap)
  assets/tray-rec.ico          tray icon, recording (red keycap)
  ui/logo-bright.svg           logos of the window (light and dark theme), copied from assets/src
  ui/logo-dark.svg
  assets/png/*.png             bitmaps for the website and the GitHub social preview
"""

import re
import shutil
import struct
import subprocess
from pathlib import Path

ASSETS = Path(__file__).resolve().parent
SRC = ASSETS / "src"
PNG = ASSETS / "png"

# The icon sources are 1000 px canvases with the keycap at 100..900 px. Small sizes crop the
# margin, so the keycap fills the tray slot like the other icons; larger ones keep a little.
AREA_TIGHT = "100:100:900:900"
AREA_ICON = "48:48:952:952"
ICO_SIZES = [16, 20, 24, 32, 40, 48, 64, 128, 256]
TRAY_SIZES = [16, 20, 24, 32, 40, 48]
TRAY_ICONS = {"tray-idle-light": "icon-black", "tray-idle-dark": "icon-white-contrast",
              "tray-rec": "icon-red"}
ICON_COLORS = ["black", "blue", "green", "red", "white", "white-contrast", "yellow"]
LOGOS = ["logo-bright", "logo-dark", "logo-mono-bright", "logo-mono-dark"]

SOCIAL_SIZE = (1280, 640)


def inkscape(source: Path, *args: str) -> None:
    subprocess.run(["inkscape", str(source), "--export-background-opacity=0", *args],
                   check=True, capture_output=True)


def export_icon(svg_name: str, size: int) -> Path:
    out = PNG / f"{svg_name}-{size}.png"
    area = AREA_TIGHT if size <= 24 else AREA_ICON
    inkscape(SRC / f"{svg_name}.svg", "--export-type=png", f"--export-area={area}",
             f"--export-filename={out}", "-w", str(size), "-h", str(size))
    return out


def write_ico(path: Path, pngs: dict[int, Path]) -> None:
    """ICO container with embedded PNG images (supported since Windows Vista)."""
    images = [(size, png.read_bytes()) for size, png in sorted(pngs.items())]
    header = struct.pack("<HHH", 0, 1, len(images))
    offset = 6 + 16 * len(images)
    entries, data = b"", b""
    for size, blob in images:
        dim = 0 if size >= 256 else size  # 0 means 256 in the ICO directory
        entries += struct.pack("<BBBBHHII", dim, dim, 0, 0, 1, 32, len(blob), offset)
        data += blob
        offset += len(blob)
    path.write_bytes(header + entries + data)


def framed_logo(logo: Path, out: Path, size: tuple[int, int], background: str,
                radius: float, margin: tuple[float, float]) -> None:
    """SVG with the logo centred on a (rounded) plate; margin is a fraction of each side."""
    w, h = size
    mx, my = margin
    inner = logo.read_text(encoding="utf-8")
    inner = re.sub(r"<\?xml[^>]*\?>", "", inner)
    for _ in ("width", "height"):
        inner = re.sub(r"(<svg\b[^>]*?)\s(width|height)=\"[^\"]*\"", r"\1", inner, count=1)
    inner = inner.replace("<svg", f'<svg x="{w * mx:g}" y="{h * my:g}" '
                                  f'width="{w * (1 - 2 * mx):g}" height="{h * (1 - 2 * my):g}"', 1)
    out.write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" '
                   f'viewBox="0 0 {w} {h}"><rect width="{w}" height="{h}" rx="{radius:g}" '
                   f'fill="{background}"/>{inner}</svg>', encoding="utf-8")


def main() -> None:
    PNG.mkdir(exist_ok=True)

    write_ico(ASSETS / "app.ico", {size: export_icon("icon-red", size) for size in ICO_SIZES})
    for ico, svg_name in TRAY_ICONS.items():
        write_ico(ASSETS / f"{ico}.ico", {size: export_icon(svg_name, size) for size in TRAY_SIZES})
    for color in ICON_COLORS:
        export_icon(f"icon-{color}", 512)

    for logo in LOGOS:
        inkscape(SRC / f"{logo}.svg", "--export-area-drawing", "--export-plain-svg",
                 f"--export-filename={PNG / f'{logo}.svg'}")
        inkscape(SRC / f"{logo}.svg", "--export-type=png", "--export-area-drawing",
                 f"--export-filename={PNG / f'{logo}.png'}", "-h", "300")

    # Logos of the window: the page picks one by the theme and scales the vector itself
    for name in ("logo-bright.svg", "logo-dark.svg"):
        shutil.copyfile(SRC / name, ASSETS.parent / "ui" / name)

    # GitHub social preview: the logo on white, inside the safe area
    social = PNG / "social-preview.svg"
    framed_logo(PNG / "logo-bright.svg", social, SOCIAL_SIZE, "#ffffff", radius=0, margin=(0.12, 0.2))
    inkscape(social, "--export-type=png", f"--export-filename={PNG / 'social-preview.png'}")
    social.unlink()


if __name__ == "__main__":
    main()
