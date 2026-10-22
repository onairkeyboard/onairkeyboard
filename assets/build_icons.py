"""Builds OnAirKey icon assets from the SVG sources in assets/src.

Requires Inkscape on PATH. Produces:
  assets/png/*.png           exported bitmaps
  assets/onairkey.ico        application / EXE icon
  assets/tray-idle.ico       tray icon, idle state
  assets/tray-rec.ico        tray icon, recording state
  assets/logo.svg            wordmark for dark backgrounds, text converted to paths
  assets/logo-on-dark.svg    the same wordmark on its own dark plate (works on any background)
  assets/logo-light.svg      wordmark for light backgrounds
  assets/logo-ui.png         logo for the settings window header
  assets/bug-ui.png          bug icon of the "Report a bug" link (Ionicons, MIT)
"""

import struct
import subprocess
from pathlib import Path

ASSETS = Path(__file__).resolve().parent
SRC = ASSETS / "src"
PNG = ASSETS / "png"

# Small sizes use the simplified icon (the keycap face is unreadable below 48 px)
APP_SIZES = {16: "icon-small-rec", 20: "icon-small-rec", 24: "icon-small-rec",
             32: "icon-small-rec", 40: "icon-small-rec", 48: "icon-app",
             64: "icon-app", 128: "icon-app", 256: "icon-app"}
TRAY_SIZES = [16, 20, 24, 32, 40, 48]


def export_png(svg_name: str, size: int) -> Path:
    out = PNG / f"{svg_name}-{size}.png"
    subprocess.run(["inkscape", str(SRC / f"{svg_name}.svg"), "--export-type=png",
                    f"--export-filename={out}", "-w", str(size), "-h", str(size)],
                   check=True, capture_output=True)
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


def main() -> None:
    PNG.mkdir(exist_ok=True)

    write_ico(ASSETS / "onairkey.ico",
              {size: export_png(name, size) for size, name in APP_SIZES.items()})
    for state in ("idle", "rec"):
        write_ico(ASSETS / f"tray-{state}.ico",
                  {size: export_png(f"icon-small-{state}", size) for size in TRAY_SIZES})
    export_png("icon-app", 512)

    for logo in ("logo", "logo-on-dark", "logo-light"):
        subprocess.run(["inkscape", str(SRC / f"{logo}.svg"), "--export-text-to-path",
                        "--export-plain-svg", f"--export-filename={ASSETS / f'{logo}.svg'}"],
                       check=True, capture_output=True)
        subprocess.run(["inkscape", str(SRC / f"{logo}.svg"), "--export-type=png",
                        f"--export-filename={PNG / f'{logo}.png'}", "-h", "240"],
                       check=True, capture_output=True)

    # Logo shown in the settings window header (light window background)
    subprocess.run(["inkscape", str(SRC / "logo-light.svg"), "--export-type=png",
                    f"--export-filename={ASSETS / 'logo-ui.png'}", "-h", "64"],
                   check=True, capture_output=True)

    # Bug icon next to "Report a bug" in the header; 2x size, shown at 16 px
    subprocess.run(["inkscape", str(SRC / "icon-bug.svg"), "--export-type=png",
                    f"--export-filename={ASSETS / 'bug-ui.png'}", "-w", "32", "-h", "32"],
                   check=True, capture_output=True)


if __name__ == "__main__":
    main()
